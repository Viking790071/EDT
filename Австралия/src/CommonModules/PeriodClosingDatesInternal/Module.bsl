#Region Internal

// Returns the possibility to check period-end closing.
Function PeriodEndClosingChecked(MetadataObject) Export
	
	Return DataSourcesForPeriodClosingCheck().Get(MetadataObject.FullName()) <> Undefined;
	
EndFunction

// Returns properties of the embedding option.
Function SectionsProperties() Export
	
	Return SessionParameters.ValidPeriodClosingDates.SectionsProperties;
	
EndFunction

// Enables or disables period-end closing check as of the current session.
//
Procedure SkipPeriodClosingCheck(Ignore = True) Export
	
	SessionParameters.SkipPeriodClosingCheck = Ignore;
	
EndProcedure

// Shows that it is required to update a version of period-end closing dates after changing data in 
// the import mode or updates the version (import upon the infobase update).
//
// Called from the OnWrite event of PeriodClosingDates and UserGroupsContents registers.
//
Procedure UpdatePeriodClosingDatesVersionOnDataImport(Object) Export
	
	SetPrivilegedMode(True);
	
	If ValueIsFilled(Object.DataExchange.Sender) Then
		SessionParameters.UpdatePeriodClosingDatesVersionAfterImportData = True;
	Else
		UpdatePeriodClosingDatesVersion();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("SkipPeriodClosingCheck",
		"PeriodClosingDatesInternal.SessionParametersSetting");
	
	Handlers.Insert("ValidPeriodClosingDates",
		"PeriodClosingDatesInternal.SessionParametersSetting");
	
	Handlers.Insert("UpdatePeriodClosingDatesVersionAfterImportData",
		"PeriodClosingDatesInternal.SessionParametersSetting");
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.Version = "*";
	Handler.Procedure = "PeriodClosingDatesInternal.UpdatePeriodClosingDatesSections";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "PeriodClosingDatesInternal.SetInitialPeriodEndClosingDate";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.12";
	Handler.Procedure = "PeriodClosingDatesInternal.ReplaceUndefinedWithEnumerationValues";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.3.2";
	Handler.Procedure = "PeriodClosingDatesInternal.DeleteBlankClosingDatesByDefault";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.51";
	Handler.Procedure = "PeriodClosingDatesInternal.FillClosingDatesUsage";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.55";
	Handler.Procedure = "PeriodClosingDatesInternal.SetRelativeClosingDates";
	
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.Version = "2.4.1.1";
	Handler.Procedure = "PeriodClosingDatesInternal.ClearPredefinedItemsInClosingDatesSections";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.Procedure = "PeriodClosingDatesInternal.ReplaceClosingDatesSectionsWithNewOnes";
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToMaster. 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	If RecordSetOnlyWithImportRestrictionDates(DataItem) Then
		ItemSend = DataItemSend.Ignore;
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave. 
Procedure OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient) Export
	
	If RecordSetOnlyWithImportRestrictionDates(DataItem) Then
		ItemSend = DataItemSend.Ignore;
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster. 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender) Export
	
	// Standard data processor cannot be overridden.
	If GetItem = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	If RecordSetOnlyWithImportRestrictionDates(DataItem) Then
		GetItem = DataItemReceive.Ignore;
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave. 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender) Export
	
	// Standard data processor cannot be overridden.
	If GetItem = DataItemReceive.Ignore Then
		Return;
	EndIf;
	
	If RecordSetOnlyWithImportRestrictionDates(DataItem) Then
		GetItem = DataItemReceive.Ignore;
	EndIf;
	
EndProcedure

// Event handlers of the ReportsOptions subsystem.

// See ReportsOptionsOverridable.CustomizeReportOptions. 
Procedure OnSetUpReportsOptions(Settings) Export
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.ImportRestrictionDates);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.PeriodClosingDates);
	
EndProcedure

// Event handlers of the Users subsystem.

// See SSLSubsystemsIntegration.AfterUserGroupsUpdate. 
Procedure AfterUserGroupsUpdate(ItemsToChange, ModifiedGroups) Export
	
	UpdatePeriodClosingDatesVersion();
	
EndProcedure

// Events handlers of the SaaSTechnology library.

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingReferenceComparisonOnImport. 
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	// Separated data contains only references with the supplied UUIDs specified in the 
	// OnFillPeriodClosingDateSections procedure of the PeriodClosingDatesOverridable common module.
	// 
	Types.Add(Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Main procedures and functions.

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	If ParameterName = "ValidPeriodClosingDates" Then
		Value = SessionParameterValueEffectivePeriodClosingDates();
		SessionParameters.ValidPeriodClosingDates = Value;
		SpecifiedParameters.Add("ValidPeriodClosingDates");
		LastCheck = PeriodClosingDatesInternalCached.LastCheckOfEffectiveClosingDatesVersion();
		LastCheck.Date = CurrentSessionDate();
		
	ElsIf ParameterName = "SkipPeriodClosingCheck" Then
		SessionParameters.SkipPeriodClosingCheck = False;
		SpecifiedParameters.Add("SkipPeriodClosingCheck");
		
	ElsIf ParameterName = "UpdatePeriodClosingDatesVersionAfterImportData" Then
		SessionParameters.UpdatePeriodClosingDatesVersionAfterImportData = False;
		SpecifiedParameters.Add("UpdatePeriodClosingDatesVersionAfterImportData");
	EndIf;
	
EndProcedure

// Handler of the PeriodClosingDatesVersionUpdateAfterDataImport subscription to the OnWrite event 
// of any exchange plan.
//
Procedure PeriodClosingDatesVersionUpdateAfterDataImportOnWrite(Source, Cancel) Export
	
	SetPrivilegedMode(True);
	
	If SessionParameters.UpdatePeriodClosingDatesVersionAfterImportData Then
		UpdatePeriodClosingDatesVersion();
		SessionParameters.UpdatePeriodClosingDatesVersionAfterImportData = False;
	EndIf;
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

// Updates a version of period-end closing dates after change.
Procedure UpdatePeriodClosingDatesVersion() Export
	
	SetPrivilegedMode(True);
	Constants.PeriodClosingDatesVersion.Set(New UUID);
	
	LastCheck = PeriodClosingDatesInternalCached.LastCheckOfEffectiveClosingDatesVersion();
	LastCheck.Date = '00010101';
	
EndProcedure

// Returns a period-end closing date calculated according to the details of a relative period-end closing date.
//
// Parameters:
//  PeriodEndClosingDateDetails - String - contains details of a relative period-end closing date.
//  PeriodEndClosingDate - Date - an absolute date received from the register.
//  BegOfDay - Date - a current session date as of the beginning of the day.
//                      - Undefined - calculate automatically.
//
Function PeriodEndClosingDateByDetails(PeriodEndClosingDateDetails, PeriodEndClosingDate, BegOfDay = '00010101') Export
	
	If Not ValueIsFilled(PeriodEndClosingDateDetails) Then
		Return PeriodEndClosingDate;
	EndIf;
	
	If Not ValueIsFilled(BegOfDay) Then
		BegOfDay = BegOfDay(CurrentSessionDate());
	EndIf;
	
	Days = 60*60*24;
	PermissionDaysCount = 0;
	
	PeriodEndClosingDateOption    = StrGetLine(PeriodEndClosingDateDetails, 1);
	DaysCountAsString = StrGetLine(PeriodEndClosingDateDetails, 2);
	
	If ValueIsFilled(DaysCountAsString) Then
		TypeDetails = New TypeDescription("Number");
		PermissionDaysCount = TypeDetails.AdjustValue(DaysCountAsString);
	EndIf;
	
	If PeriodEndClosingDateOption = "EndOfLastYear" Then
		CurrentPeriodEndClosingDate    = BegOfYear(BegOfDay)          - Days;
		PreviousPeriodEndClosingDate = BegOfYear(CurrentPeriodEndClosingDate) - Days;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastQuarter" Then
		CurrentPeriodEndClosingDate    = BegOfQuarter(BegOfDay)          - Days;
		PreviousPeriodEndClosingDate = BegOfQuarter(CurrentPeriodEndClosingDate) - Days;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastMonth" Then
		CurrentPeriodEndClosingDate    = BegOfMonth(BegOfDay)          - Days;
		PreviousPeriodEndClosingDate = BegOfMonth(CurrentPeriodEndClosingDate) - Days;
		
	ElsIf PeriodEndClosingDateOption = "EndOfLastWeek" Then
		CurrentPeriodEndClosingDate    = BegOfWeek(BegOfDay)          - Days;
		PreviousPeriodEndClosingDate = BegOfWeek(CurrentPeriodEndClosingDate) - Days;
		
	ElsIf PeriodEndClosingDateOption = "PreviousDay" Then
		CurrentPeriodEndClosingDate    = BegOfDay(BegOfDay)          - Days;
		PreviousPeriodEndClosingDate = BegOfDay(CurrentPeriodEndClosingDate) - Days;
	Else
		Return '00030303'; // Unknown format.
	EndIf;
	
	If ValueIsFilled(CurrentPeriodEndClosingDate) Then
		PermissionPeriod = CurrentPeriodEndClosingDate + PermissionDaysCount * Days;
		If Not BegOfDay > PermissionPeriod Then
			CurrentPeriodEndClosingDate = PreviousPeriodEndClosingDate;
		EndIf;
	EndIf;
	
	Return CurrentPeriodEndClosingDate;
	
EndFunction

// Searches for period-end closing dates and data import restriction dates for the object.
//
// Parameters:
//  Source - CatalogObject,
//                    ChartOfCharacteristicTypesObject,
//                    ChartOfAccountsObject,
//                    ChartOfCalculationTypesObject,
//                    BusinessProcessObject,
//                    TaskObject,
//                    ExchangePlanObject,
//                    DocumentObject - a data object.
//                  - InformationRegisterRecordSet,
//                    AccumulationRegisterRecordSet,
//                    AccountingRegisterRecordSet,
//                    CalculationRegisterRecordSet - a record set.
//                  - ObjectDeletion - object deletion upon importing.
//
//  Cancel           - Boolean - (return value) True will be set if the object fails period-end 
//                    closing date check.
//
//  SourceRegister - Boolean - False - a source is a register, otherwise, an object.
//
//  Replacing       - Boolean - if a source is a register and adding is carried out, specify False.
//                    
//
//  Delete - Boolean - if a source is an object and an object is being deleted, specify True.
//                    
//
//  AdditionalParameters - Undefined - parameters specified below have initial values.
//                          - Structure - with the following properties:
//    * PeriodClosingCheck - Boolean - an initial value is set to True, if you set it to False, 
//                                    period-end closing check for users will be skipped.
//    * ImportRestrictionCheckNode - Undefined - (initial value) check data change.
//                                  - ExchangePlansRef.<Exchange plan name> - check data import for 
//                                    the specified node.
//    * ErrorDescription              - Null -      (default value) period-end closing data is not required.
//                                  - String    - (return value) - return a text description of available period-end closing dates.
//                                  - Structure - (return value) - return a structural description 
//                                                of available period-end closing dates. See the PeriodClosingDates.PeriodEndClosingFound function.
//    * InformAboutPeriodEnd            -Boolean - an initial value True. If False, filled 
//                                    ErrorDescription is neither sent to a user nor written to the 
//                                    event log.
//
Procedure CheckDataImportRestrictionDates(Source,
		Cancel, SourceRegister, Overwrite, Delete, AdditionalParameters = Undefined) Export
	
	PeriodClosingCheck    = True;
	ImportRestrictionCheckNode = Undefined;
	ErrorDescription              = "";
	InformAboutPeriodEnd            = True;
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		AdditionalParameters.Property("PeriodClosingCheck",    PeriodClosingCheck);
		AdditionalParameters.Property("ImportRestrictionCheckNode", ImportRestrictionCheckNode);
		AdditionalParameters.Property("ErrorDescription",              ErrorDescription);
		AdditionalParameters.Property("InformAboutPeriodEnd",            InformAboutPeriodEnd);
	EndIf;
	
	ObjectVersion = "";
	If SkipClosingDatesCheck(Source, PeriodClosingCheck,
			ImportRestrictionCheckNode, ObjectVersion) Then
		Return;
	EndIf;
	
	DataChangesDenied = False;
	
	If NOT SourceRegister
	   AND NOT Source.IsNew()
	   AND NOT Delete Then
	
		If DataChangesDenied(
				?(ObjectVersion <> "OldVersion", Source, Source.Metadata().FullName()),
				?(ObjectVersion <> "NewVersion",  Source.Ref, Undefined),
				ErrorDescription,
				ImportRestrictionCheckNode) Then
			
			DataChangesDenied = True;
		EndIf;
		
	ElsIf SourceRegister AND Overwrite Then
		
		If DataChangesDenied(
				?(ObjectVersion <> "OldVersion", Source, Source.Metadata().FullName()),
				?(ObjectVersion <> "NewVersion",  Source.Filter, Undefined),
				ErrorDescription,
				ImportRestrictionCheckNode) Then
			
			DataChangesDenied = True;
		EndIf;
		
	ElsIf TypeOf(Source) = Type("ObjectDeletion") Then
		
		If ObjectVersion <> "NewVersion"
		   AND DataChangesDenied(
				Source.Metadata().FullName(),
				Source.Ref,
				ErrorDescription,
				ImportRestrictionCheckNode) Then
			
			DataChangesDenied = True;
		EndIf;
		
	Else
		// Executed if:
		//     NOT SourceRegister AND Source.IsNew()
		// OR SourceRegister AND NOT Replacing
		// OR NOT SourceRegister  AND Delete.
		If ObjectVersion <> "OldVersion"
		   AND DataChangesDenied(
				Source,
				,
				ErrorDescription,
				ImportRestrictionCheckNode) Then
			
			DataChangesDenied = True;
		EndIf;
	EndIf;
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		AdditionalParameters.Insert("PeriodClosingCheck",    PeriodClosingCheck);
		AdditionalParameters.Insert("ImportRestrictionCheckNode", ImportRestrictionCheckNode);
		AdditionalParameters.Insert("ErrorDescription",              ErrorDescription);
		AdditionalParameters.Insert("InformAboutPeriodEnd",            InformAboutPeriodEnd);
	EndIf;
	
	If DataChangesDenied Then
		Cancel = True;
	EndIf;
	
	If Not (DataChangesDenied AND InformAboutPeriodEnd) Then
		Return;
	EndIf;
	
	CommonClientServer.MessageToUser(ErrorDescription);
	
	WriteLogEvent(
		?(ImportRestrictionCheckNode <> Undefined,
			NStr("ru = 'Даты запрета изменения.Найдены запреты загрузки'; en = 'Period-end closing dates.Data import restrictions are found'; pl = 'Zmień datę zamknięcia. Znaleziono zakazy importu';es_ES = 'Cambiar la fecha de cierre.Prohibiciones de importación encontradas';es_CO = 'Cambiar la fecha de cierre.Prohibiciones de importación encontradas';tr = 'Kapanış tarihini değiştir. İçe aktarma yasakları bulundu';it = 'Date di chiusura di fine periodo. Trovate restrizioni di importazione dati';de = 'Ändern Sie das Abschlussdatum. Importverbote werden gefunden'",
			     CommonClientServer.DefaultLanguageCode()),
			NStr("ru = 'Даты запрета изменения.Найдены запреты изменения'; en = 'Period-end closing dates.Period-end closing is found'; pl = 'Zmień datę zamknięcia. Znaleziono zakazy zmian.';es_ES = 'Cambiar la fecha de cierre.Prohibiciones de cambios encontradas';es_CO = 'Cambiar la fecha de cierre.Prohibiciones de cambios encontradas';tr = 'Kapanış tarihini değiştir. Değişiklik yasakları bulundu';it = 'Date di chiusura di fine periodo. Trovata chiusura di fine periodo';de = 'Ändern Sie das Abschlussdatum. Änderungsverbote werden gefunden'",
			     CommonClientServer.DefaultLanguageCode())),
		EventLogLevel.Error,
		,
		,
		ErrorDescription,
		EventLogEntryTransactionMode.Transactional);
	
EndProcedure

// Checks whether period-end closing or data import restriction need to be checked.
Function SkipClosingDatesCheck(Object,
                                     PeriodClosingCheck,
                                     ImportRestrictionCheckNode,
                                     ObjectVersion) Export
	
	If TypeOf(Object) <> Type("ObjectDeletion")
	   AND Object.AdditionalProperties.Property("SkipPeriodClosingCheck") Then
		
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	If SessionParameters.SkipPeriodClosingCheck Then
		Return True;
	EndIf;
	SetPrivilegedMode(False);
	
	If PeriodEndClosingNotUsed(PeriodClosingCheck, ImportRestrictionCheckNode) Then
		Return True;
	EndIf;
	
	If InfobaseUpdate.InfobaseUpdateInProgress()
	 Or InfobaseUpdate.IsCallFromUpdateHandler() Then
		
		Return True;
	EndIf;
	
	PeriodClosingDatesOverridable.BeforeCheckPeriodClosing(
		Object, PeriodClosingCheck, ImportRestrictionCheckNode, ObjectVersion);
	
	Return PeriodClosingCheck    = False          // DO NOT check period-end closing.
	      AND ImportRestrictionCheckNode = Undefined; // DO NOT check import restriction.
	
EndFunction

// See PeriodClosingDates.DataChangesDenied. 
Function DataChangesDenied(Data, DataID, ErrorDescription, ImportRestrictionCheckNode) Export
	
	SetPrivilegedMode(True);
	
	PeriodEndFound = False;
	EffectiveDates = EffectiveClosingDates();
	
	RestrictionDatesByObjectsNotSpecified = ?(ImportRestrictionCheckNode = Undefined,
		EffectiveDates.ForUsers.RestrictionDatesByObjectsNotSpecified,
		EffectiveDates.ForInfobases.RestrictionDatesByObjectsNotSpecified);
	
	// Check an old object version or a record set.
	If DataID <> Undefined Then
		DataDetails = New Structure;
		DataDetails.Insert("NewVersion", False);
		
		// Data - a table name required for the DataID property of the Filter type and when source data has 
		// the ObjectDeletion type.
		
		If TypeOf(DataID) = Type("Filter") Then
			DataDetails.Insert("Data", New Structure);
			DataDetails.Data.Insert("Register", Data);
			DataDetails.Data.Insert("Filter", DataID);
		Else
			DataDetails.Insert("Data", DataID);
		EndIf;
		
		DataToCheck = DataToCheckFromDatabase(Data,
			DataID, EffectiveDates, RestrictionDatesByObjectsNotSpecified);
		
		DataAndDates = New Structure;
		DataAndDates.Insert("EffectiveDates",   EffectiveDates);
		DataAndDates.Insert("DataToCheck", DataToCheck);
		
		PeriodEndFound = PeriodClosingDates.PeriodEndClosingFound(DataAndDates,
			DataDetails, ErrorDescription, ImportRestrictionCheckNode);
	EndIf;
	
	// Check a new object version or a record set.
	If Not PeriodEndFound AND TypeOf(Data) <> Type("String") Then
		
		DataDetails = New Structure;
		DataDetails.Insert("NewVersion", True);
		DataDetails.Insert("Data", Data);
		
		DataToCheck = DataForCheckFromObject(Data,
			EffectiveDates, RestrictionDatesByObjectsNotSpecified);
		
		DataAndDates = New Structure;
		DataAndDates.Insert("EffectiveDates",   EffectiveDates);
		DataAndDates.Insert("DataToCheck", DataToCheck);
		
		PeriodEndFound = PeriodClosingDates.PeriodEndClosingFound(DataAndDates,
			DataDetails, ErrorDescription, ImportRestrictionCheckNode);
	EndIf;
	
	Return PeriodEndFound;
	
EndFunction

// Returns effective period-end closing dates considering the version after changes.
Function EffectiveClosingDates() Export
	
	LastCheck = PeriodClosingDatesInternalCached.LastCheckOfEffectiveClosingDatesVersion();
	
	EffectiveDates = SessionParameters.ValidPeriodClosingDates;
	
	If CurrentSessionDate() > (LastCheck.Date + 5) Then
		If EffectiveDates.BegOfDay <> BegOfDay(CurrentSessionDate())
		 Or EffectiveDates.Version <> Constants.PeriodClosingDatesVersion.Get() Then
			
			SetSafeModeDisabled(True);
			SetPrivilegedMode(True);
			
			ParametersToClear = New Array;
			ParametersToClear.Add("ValidPeriodClosingDates");
			SessionParameters.Clear(ParametersToClear);
			
			SetPrivilegedMode(False);
			SetSafeModeDisabled(False);
			
			EffectiveDates = SessionParameters.ValidPeriodClosingDates;
		EndIf;
		LastCheck.Date = CurrentSessionDate();
	EndIf;
	
	Return EffectiveDates;
	
EndFunction

// Returns data sources filled in the FillDataSourcesForPeriodClosingCheck procedure of the 
// PeriodClosingDatesOverridable common module.
//
Function DataSourcesForPeriodClosingCheck() Export
	
	Return SessionParameters.ValidPeriodClosingDates.DataSources;
	
EndFunction

// Returns a null reference of the specified type.
Function EmptyRef(RefType) Export
	
	Types = New Array;
	Types.Add(RefType);
	TypesDetails = New TypeDescription(Types);
	
	Return TypesDetails.AdjustValue(Undefined);
	
EndFunction

Function ErrorTextImportRestrictionDatesNotImplemented() Export
	
	Return NStr("ru = 'Даты запрета загрузки данных прошлых периодов из других программ
	                   |не предусмотрены ни для одного плана обмена.'; 
	                   |en = 'Data import restriction dates of previous periods from other applications 
	                   |are not available for any exchange plan.'; 
	                   |pl = 'Daty zakazu pobierania danych poprzednich okresów z innych programów 
	                   |nie są przewidziane dla żadnego planu wymiany.';
	                   |es_ES = 'Las fechas de restricción de cargo de datos de los períodos anteriores de otros programas
	                   |no están previstas para ningún plan de cambio.';
	                   |es_CO = 'Las fechas de restricción de cargo de datos de los períodos anteriores de otros programas
	                   |no están previstas para ningún plan de cambio.';
	                   |tr = 'Hiç bir alışveriş planı için diğer programlardan geçmiş dönemlerin 
	                   |veri içeri aktarma yasağı tarihleri öngörülmemiştir.';
	                   |it = 'Date di restrizione all''importazione di dati dei periodi precedenti da altre applicazioni 
	                   |non sono previste per nessun piano di scambio.';
	                   |de = 'Für den Download von Daten vergangener Perioden aus anderen
	                   |Programmen für einen Austauschplan gibt es keine Termine.'");
	
EndFunction

Function IsPeriodClosingAddressee(PeriodEndAddressee) Export
	
	Return TypeOf(PeriodEndAddressee) = Type("CatalogRef.Users")
	    Or TypeOf(PeriodEndAddressee) = Type("CatalogRef.UserGroups")
	    Or TypeOf(PeriodEndAddressee) = Type("CatalogRef.ExternalUsers")
	    Or TypeOf(PeriodEndAddressee) = Type("CatalogRef.ExternalUsersGroups")
	    Or PeriodEndAddressee = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
	
EndFunction

Function CalculatedPeriodClosingDates() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	PeriodClosingDates.Comment AS Comment
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates";
	Table = Query.Execute().Unload();
	
	BegOfDay = BegOfDay(CurrentSessionDate());
	For Each Row In Table Do
		Row.PeriodEndClosingDate = PeriodEndClosingDateByDetails(Row.PeriodEndClosingDateDetails,
			Row.PeriodEndClosingDate , BegOfDay);
	EndDo;
	
	Return Table;
	
EndFunction

// Updates chart of characteristic types PeriodClosingDatesSections according to the details in metadata.
Procedure UpdatePeriodClosingDatesSections() Export
	
	If Common.DataSeparationEnabled()
	   AND Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	SectionsProperties = SectionsProperties();
	BlankSection = ChartsOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef();
	
	SectionsRefsArray = New Array;
	
	For Each SectionDetails In SectionsProperties.Sections Do
		If TypeOf(SectionDetails.Key) = Type("String")
		 Or Not ValueIsFilled(SectionDetails.Key) Then
			Continue;
		EndIf;
		SectionProperties = SectionDetails.Value;
		SectionsRefsArray.Add(SectionProperties.Ref);
		
		Object = SectionProperties.Ref.GetObject();
		Write = False;
		
		If Object = Undefined Then
			Object = ChartsOfCharacteristicTypes.PeriodClosingDatesSections.CreateItem();
			Object.SetNewObjectRef(SectionProperties.Ref);
			Write = True;
		EndIf;
		
		If Object.Description <> SectionProperties.Presentation Then
			Object.Description = SectionProperties.Presentation;
			Write = True;
		EndIf;
		
		If Object.DeletionMark Then
			Object.DeletionMark = False;
			Write = True;
		EndIf;
		
		If ValueIsFilled(Object.DeleteNewRef) Then
			Object.DeleteNewRef = BlankSection;
			Write = True;
		EndIf;
		
		ObjectsTypes = New Array;
		If SectionProperties.ObjectsTypes.Count() = 0 Then
			ObjectsTypes.Add(TypeOf(BlankSection));
		Else
			For Each TypeProperties In SectionProperties.ObjectsTypes Do
				ObjectsTypes.Add(TypeOf(TypeProperties.EmptyRef));
			EndDo;
		EndIf;
		If Object.ValueType.Types().Count() <> ObjectsTypes.Count() Then
			Object.ValueType = New TypeDescription(ObjectsTypes);
			Write = True;
		Else
			For Each Type In ObjectsTypes Do
				If Not Object.ValueType.ContainsType(Type) Then
					Object.ValueType = New TypeDescription(ObjectsTypes);
					Write = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		If Write Then
			InfobaseUpdate.WriteObject(Object, False);
		EndIf;
	EndDo;
	
	// Mark not predefined obsolete sections for deletion.
	Query = New Query;
	Query.SetParameter("Sections", SectionsRefsArray);
	Query.Text =
	"SELECT
	|	Sections.Ref AS Ref,
	|	Sections.PredefinedDataName AS PredefinedDataName,
	|	Sections.DeleteNewRef AS DeleteNewRef
	|FROM
	|	ChartOfCharacteristicTypes.PeriodClosingDatesSections AS Sections
	|WHERE
	|	NOT Sections.DeletionMark
	|	AND NOT Sections.Ref IN (&Sections)
	|	AND Sections.PredefinedDataName = """"";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If ValueIsFilled(Selection.DeleteNewRef)
		   AND Common.DataSeparationEnabled() Then
			Continue;
		EndIf;
		Object = Selection.Ref.GetObject();
		Object.DeletionMark = True;
		InfobaseUpdate.WriteData(Object, False);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Filling handler of the common initial period-end closing date before 1980.
Procedure SetInitialPeriodEndClosingDate() Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	RecordSet.Read();
	
	If RecordSet.Count() <> 0 Then
		Return;
	EndIf;
	
	BlankSection = EmptyRef(Type("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	
	Record = RecordSet.Add();
	Record.User = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
	Record.Section       = BlankSection;
	Record.Object       = BlankSection;
	Record.PeriodEndClosingDate  = '19791231';
	Record.Comment  = "(" + NStr("ru = 'По умолчанию'; en = 'Default'; pl = 'Domyślnie';es_ES = 'Por defecto';es_CO = 'Por defecto';tr = 'Varsayılan';it = 'Predefinito';de = 'Standard'") + ")";
	
	InfobaseUpdate.WriteData(RecordSet);
	
EndProcedure

// The update handler replaces the Undefined value of the User dimension of the PeriodClosingDates 
// information register with the Enum.ClosingDatesPurposesTypes.ForAllUsers value.
// 
//
Procedure ReplaceUndefinedWithEnumerationValues() Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	RecordSet.Filter.User.Set(Undefined);
	RecordSet.Read();
	If RecordSet.Count() > 0 Then
		Table = RecordSet.Unload();
		RecordSet.Filter.User.Set(Enums.PeriodClosingDatesPurposeTypes.ForAllUsers);
		Table.FillValues(Enums.PeriodClosingDatesPurposeTypes.ForAllUsers, "User");
		RecordSet.Load(Table);
		InfobaseUpdate.WriteData(RecordSet);
	EndIf;
	
EndProcedure

// Update handler deletes blank period-end closing dates specified for all users or exchange plans, 
// i.e. "Default" as period-end closing dates are blank by default.
// 
//
Procedure DeleteBlankClosingDatesByDefault() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("EmptyDate", '00000000');
	Query.Text =
	"SELECT
	|	PeriodClosingDates.Section,
	|	PeriodClosingDates.Object,
	|	PeriodClosingDates.User
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	PeriodClosingDates.User IN (VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers), VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases))
	|	AND PeriodClosingDates.PeriodEndClosingDate = &EmptyDate
	|	AND PeriodClosingDates.PeriodEndClosingDateDetails = """"";
	
	DataExported = Query.Execute().Unload();
	
	If DataExported.Count() > 0 Then
		RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
		BeginTransaction();
		Try
			For each Row In DataExported Do
				FillPropertyValues(RecordManager, Row);
				RecordManager.Read();
				If RecordManager.Selected() Then
					RecordManager.Write();
				EndIf;
			EndDo;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

// Update handler fills in constants of period-end closing date usage according to the set dates.
// 
//
Procedure FillClosingDatesUsage() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	PeriodClosingDates.User AS Recipient
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates";
	
	PeriodClosingUsed = False;
	ImportRestrictionUsed = False;
	
	UsersTypes = New Array;
	UsersTypes.Add(Type("CatalogRef.Users"));
	UsersTypes.Add(Type("CatalogRef.UserGroups"));
	UsersTypes.Add(Type("CatalogRef.ExternalUsers"));
	UsersTypes.Add(Type("CatalogRef.ExternalUsersGroups"));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.Recipient = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers Then
			PeriodClosingUsed = True;
			
		ElsIf Selection.Recipient = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
			ImportRestrictionUsed = True;
		
		ElsIf UsersTypes.Find(TypeOf(Selection.Recipient)) <> Undefined Then
			PeriodClosingUsed = True;
			
		ElsIf ExchangePlans.AllRefsType().ContainsType(TypeOf(Selection.Recipient)) Then
			ImportRestrictionUsed = True;
		EndIf;
	EndDo;
	
	If PeriodClosingUsed Then
		Constants.UsePeriodClosingDates.Set(True);
	EndIf;
	
	If ImportRestrictionUsed Then
		Constants.UseImportForbidDates.Set(True);
	EndIf;
	
EndProcedure

// Handler sets the saving value '00020202' for relative period-end closing dates.
Procedure SetRelativeClosingDates() Export
	
	Lock = New DataLock;
	Lock.Add("InformationRegister.PeriodClosingDates");
	BeginTransaction();
	Try
		Lock.Lock();
		RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
		RecordSet.Read();
		HasChanges = False;
		For Each Record In RecordSet Do
			
			If ValueIsFilled(Record.PeriodEndClosingDateDetails)
			   AND Record.PeriodEndClosingDate <> '00020202' Then
				
				Record.PeriodEndClosingDate = '00020202';
				HasChanges = True;
			EndIf;
		EndDo;
		If HasChanges Then
			InfobaseUpdate.WriteData(RecordSet);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Handler converts a chart of characteristic types to period-end closing date sections.
Procedure ClearPredefinedItemsInClosingDatesSections() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	ChartOfCharacteristicTypes.PeriodClosingDatesSections AS Sections
	|WHERE
	|	Sections.PredefinedDataName <> """"";
	
	If Query.Execute().IsEmpty() Then
		Return;
	EndIf;
	
	SectionsProperties = SectionsProperties();
	PredefinedItemNames =
		Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections.GetPredefinedNames();
	
	Lock = New DataLock;
	Lock.Add("ChartOfCharacteristicTypes.PeriodClosingDatesSections");
	
	Query.Text =
	"SELECT
	|	Sections.Ref AS Ref,
	|	Sections.PredefinedDataName AS PredefinedDataName
	|FROM
	|	ChartOfCharacteristicTypes.PeriodClosingDatesSections AS Sections
	|WHERE
	|	Sections.PredefinedDataName <> """"";
	
	BeginTransaction();
	Try
		Lock.Lock();
		UpdatePeriodClosingDatesSections();
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			Object = Selection.Ref.GetObject();
			If PredefinedItemNames.Find(Selection.PredefinedDataName) <> Undefined Then
				Prefix = "Delete";
				If Not StrStartsWith(Selection.PredefinedDataName, Prefix) Then
					Object.DeletionMark = True;
				Else
					SoughtName = Mid(Selection.PredefinedDataName, StrLen(Prefix) + 1);
					SectionProperties = SectionsProperties.Sections.Get(SoughtName);
					
					If SectionProperties = Undefined Then
						Object.DeletionMark = True;
						
					ElsIf Selection.Ref <> SectionProperties.Ref Then
						Object.DeleteNewRef = SectionProperties.Ref;
						Object.Description = "(" + NStr("ru = 'не используется'; en = 'not used'; pl = 'nie używane';es_ES = 'no se usa';es_CO = 'no se usa';tr = 'kullanılmaz';it = 'non usato';de = 'wird nicht benutzt'") + ") " + SectionProperties.Presentation;
					EndIf;
				EndIf;
			ElsIf SectionsProperties.Sections.Get(Selection.Ref) = Undefined Then
				Object.DeletionMark = True;
			EndIf;
			Object.PredefinedDataName = "";
			InfobaseUpdate.WriteData(Object, False);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Handler replaces sections of period-end closing dates in the register with the new ones.
Procedure ReplaceClosingDatesSectionsWithNewOnes() Export
	
	Lock = New DataLock;
	Lock.Add("InformationRegister.PeriodClosingDates");
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Sections.Ref AS Ref,
	|	Sections.DeleteNewRef AS DeleteNewRef
	|FROM
	|	ChartOfCharacteristicTypes.PeriodClosingDatesSections AS Sections
	|		INNER JOIN InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|		ON (PeriodClosingDates.Section = Sections.Ref)
	|			AND (Sections.DeleteNewRef <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef))";
	
	BeginTransaction();
	Try
		Lock.Lock();
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			OldRecords = InformationRegisters.PeriodClosingDates.CreateRecordSet();
			OldRecords.Filter.Section.Set(Selection.Ref);
			OldRecords.Read();
			NewRecords = InformationRegisters.PeriodClosingDates.CreateRecordSet();
			NewRecords.Filter.Section.Set(Selection.DeleteNewRef);
			NewRecords.Read();
			If NewRecords.Count() > 0 Then
				OldRecords.Clear();
				InfobaseUpdate.WriteData(OldRecords, False);
			Else
				For Each OldRecord In OldRecords Do
					NewRecord = NewRecords.Add();
					FillPropertyValues(NewRecord, OldRecord);
					NewRecord.Section = Selection.DeleteNewRef;
					If OldRecord.Section = OldRecord.Object Then
						NewRecord.Object = Selection.DeleteNewRef;
					EndIf;
				EndDo;
				OldRecords.Clear();
				InfobaseUpdate.WriteData(OldRecords, False);
				InfobaseUpdate.WriteData(NewRecords, False);
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For the SkipClosingDatesCheck procedure.
Function PeriodEndClosingNotUsed(PeriodClosingCheck, ImportRestrictionCheckNode)
	
	If InfobaseUpdate.InfobaseUpdateRequired() Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	EffectiveClosingDates = EffectiveClosingDates();
	
	If (Not EffectiveClosingDates.PeriodClosingUsed
	      Or PeriodClosingCheck = False)
	   AND (Not EffectiveClosingDates.ImportRestrictionUsed
	      Or ImportRestrictionCheckNode = Undefined) Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// For the ChangeOrImportRestricted function.
Function DataToCheckFromDatabase(Data, DataID, EffectiveDates, RestrictionDatesByObjectsNotSpecified)
	
	If TypeOf(DataID) = Type("Filter") Then
		If TypeOf(Data) = Type("String") Then
			MetadataObject = Metadata.FindByFullName(Data);
		Else
			MetadataObject = Data.Metadata();
		EndIf;
	Else
		MetadataObject = DataID.Metadata();
	EndIf;
	
	Table = MetadataObject.FullName();
	DataSources = ReceiveDataSources(EffectiveDates, Table);
	
	DataToCheck = PeriodClosingDates.DataToCheckTemplate();
	Query = New Query;
	If RestrictionDatesByObjectsNotSpecified Then
		Query.Text = DataSources.QueryTextDatesOnly;
	Else
		Query.Text = DataSources.QueryText;
	EndIf;
	If DataSources.IsRegister Then
		InsertParametersAndFilterCriterion(Query, DataID);
	Else
		Query.SetParameter("Ref", DataID);
	EndIf;
	QueryResults = Query.ExecuteBatch();
	For Each DataSource In DataSources.Content Do
		Selection = QueryResults[DataSources.Content.Find(DataSource)].Select();
		While Selection.Next() Do
			Row = DataToCheck.Add();
			FillPropertyValues(Row, Selection);
			Row.Section = DataSource.Section;
		EndDo;
	EndDo;
	
	Return DataToCheck;
	
EndFunction

// For the DataToCheckFromDatabase procedure.
// Converts Filter to the condition of query language and inserts into the query.
//
// Parameters:
//  Query            - Query.
//
//  Filter - InformationRegisterRecordsSet.Filter,
//                       AccumulationRegisterRecordSet.Filter,
//                       AccountingRegisterRecordSet.Filter,
//                       CalculationRegisterRecordSet.Filter.
//
//  TableAlias - String - a register alias in the query.
//
//  FilterCriterionPlace - String - a condition place ID in a query, for example, &FilterCriterion.
//                       
//
// Returns:
//  String.
//
Procedure InsertParametersAndFilterCriterion(Query,
                                          Filter,
                                          TableAlias = "CurrentTable",
                                          FilterCriterionPlace = "&FilterCriterion")
	
	Condition = "";
	For each FilterItem In Filter Do
		
		If FilterItem.Use Then
			If NOT IsBlankString(Condition) Then
				Condition = Condition + Chars.LF + "AND ";
			EndIf;
			Query.SetParameter(FilterItem.Name, FilterItem.Value);
			Condition = Condition
				+ TableAlias + "." + FilterItem.Name + " = &" + FilterItem.Name;
		EndIf;
	EndDo;
	Condition = ?(ValueIsFilled(Condition), Condition, "True");
	Query.Text = StrReplace(Query.Text, FilterCriterionPlace, Condition);
	
EndProcedure

// For the ChangeOrImportRestricted function.
Function DataForCheckFromObject(Data, EffectiveDates, RestrictionDatesByObjectsNotSpecified)
	
	FieldsValues = New Structure;
	MetadataObject = Data.Metadata();
	Table = MetadataObject.FullName();
	DataSources = ReceiveDataSources(EffectiveDates, Table);
	
	DataToCheck = PeriodClosingDates.DataToCheckTemplate();
	NoObject = RestrictionDatesByObjectsNotSpecified;
	
	If DataSources.IsRegister Then
		FieldsValues = Data.Unload(, DataSources.RegisterFields);
		FieldsValues.GroupBy(DataSources.RegisterFields);
		If FieldsValues.Columns.Find("Recorder") <> Undefined
		   AND Data.Filter.Find("Recorder") <> Undefined
		   AND Common.IsInformationRegister(MetadataObject) Then
			FieldsValues.FillValues(Data.Filter.Recorder.Value, "Recorder");
		EndIf;
		For Each Row In FieldsValues Do
			For Each DataSource In DataSources.Content Do
				AddDataString(Row, Row, DataSource, DataToCheck, NoObject);
			EndDo;
		EndDo;
	Else
		For Each DataSource In DataSources.Content Do
			
			If Not ValueIsFilled(DataSource.DateField.TabularSection)
			   AND Not ValueIsFilled(DataSource.ObjectField.TabularSection) Then
				
				AddDataString(Data, Data, DataSource, DataToCheck, NoObject);
				
			ElsIf Not ValueIsFilled(DataSource.DateField.TabularSection) Then
				
				If NoObject Then
					AddDataString(Data, , DataSource, DataToCheck, NoObject);
				Else
					DateString = New Structure("Value", FieldValue(Data, DataSource.DateField));
					Field = DataSource.ObjectField.Name;
					ObjectValues = Data[DataSource.ObjectField.TabularSection].Unload(, Field);
					ObjectValues.GroupBy(Field);
					For Each ObjectString In ObjectValues Do
						AddDataString(DateString, ObjectString, DataSource, DataToCheck);
					EndDo;
				EndIf;
				
			ElsIf Not ValueIsFilled(DataSource.ObjectField.TabularSection) Then
				
				If Not NoObject Then
					ObjectString = New Structure("Value", FieldValue(Data, DataSource.ObjectField));
				EndIf;
				Field = DataSource.DateField.Name;
				DateValues = Data[DataSource.DateField.TabularSection].Unload(, Field);
				DateValues.GroupBy(Field);
				For Each DateString In DateValues Do
					AddDataString(DateString, ObjectString, DataSource, DataToCheck, NoObject);
				EndDo;
			
			ElsIf DataSource.DateField.TabularSection = DataSource.ObjectField.TabularSection Then
				
				If NoObject Then
					Fields = DataSource.DateField.Name;
				Else
					Fields = DataSource.DateField.Name + "," + DataSource.ObjectField.Name;
				EndIf;
				Values = Data[DataSource.DateField.TabularSection].Unload(, Fields);
				Values.GroupBy(Fields);
				For Each Row In Values Do
					AddDataString(Row, Row, DataSource, DataToCheck, NoObject);
				EndDo;
			Else
				Field = DataSource.DateField.Name;
				DateValues = Data[DataSource.DateField.TabularSection].Unload(, Field);
				DateValues.GroupBy(Field);
				
				If Not NoObject Then
					Field = DataSource.ObjectField.Name;
					ObjectValues = Data[DataSource.ObjectField.TabularSection].Unload(, Field);
					ObjectValues.GroupBy(Field);
				EndIf;
				
				For Each DateString In DateValues Do
					DateString = New Structure("Value", FieldValue(DateString, DataSource.DateField));
					If NoObject Then
						AddDataString(DateString, , DataSource, DataToCheck, NoObject);
					Else
						For Each ObjectString In ObjectValues Do
							AddDataString(DateString, ObjectString, DataSource, DataToCheck);
						EndDo;
					EndIf;
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	Return DataToCheck;
	
EndFunction

// For procedures DataToCheckFromDatabase, DataForCheckFromObject.
Function ReceiveDataSources(EffectiveDates, Table)
	
	DataSources = EffectiveDates.DataSources.Get(Table);
	
	If DataSources = Undefined
	 Or DataSources.Count() = 0 Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для проверки запрета изменения не найдены
			           |источники данных для таблицы ""%1"".'; 
			           |en = 'Data sources for the ""%1"" table are not found 
			           |for checking period-end closing.'; 
			           |pl = 'Nie znaleziono źródeł danych dla tabeli ""%1""
			           |do zmiany kontroli zakazu.';
			           |es_ES = 'Fuentes de datos para la tabla ""%1""
			           |para revisar la prohibición de cambios no encontradas.';
			           |es_CO = 'Fuentes de datos para la tabla ""%1""
			           |para revisar la prohibición de cambios no encontradas.';
			           |tr = 'Değişiklik yasak kontrolü için tablo ""%1"" 
			           |veri kaynakları bulunamadı.';
			           |it = 'Nessuna fonte trovata per la tabella ""%1"" per 
			           |il controllo della chiusura di fine periodo.';
			           |de = 'Datenquellen für die Tabelle ""%1""
			           |zum Ändern der Verbotskontrolle wurden nicht gefunden.'"),
			Table);
	EndIf;
	
	Return DataSources;
	
EndFunction

// For the DataForCheckFromObject procedure.
Procedure AddDataString(DateString, ObjectString, DataSource, DataToCheck, NoObject = False)
	
	NewRow = DataToCheck.Add();
	NewRow.Section = DataSource.Section;
	NewRow.Date = FieldValue(DateString, DataSource.DateField);
	
	If NoObject Or Not ValueIsFilled(DataSource.ObjectField.Name) Then
		Return;
	EndIf;
	
	NewRow.Object = FieldValue(ObjectString, DataSource.ObjectField);
	
EndProcedure

// For the AddDataString procedure.
Function FieldValue(FieldsValues, Field)
	
	If TypeOf(FieldsValues) = Type("Structure") Then
		Return FieldsValues.Value;
	EndIf;
	
	If Not ValueIsFilled(Field.Path) Then
		Return FieldsValues[Field.Name];
	EndIf;
	
	ValueTable = New ValueTable;
	ValueTable.Columns.Add("CurrentRef", Field.Type);
	ValueTable.Add().CurrentRef = FieldsValues[Field.Name];
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CurrentTable.CurrentRef AS CurrentRef
	|INTO CurrentTable
	|FROM
	|	&ValueTable AS CurrentTable
	|;
	|SELECT
	|	ISNULL(CurrentTable.CurrentRef." + Field.Path + ", UNDEFINED) AS AttributeValue
	|FROM
	|	CurrentTable AS CurrentTable";
	Query.SetParameter("ValueTable", ValueTable);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.AttributeValue;
	
EndFunction

// For the SessionParametersSetting procedure .
Function SessionParameterValueEffectivePeriodClosingDates()
	
	// Priorities of period-end closing dates.
	// 1. For a section, object, and user.
	// 2. For a section, object, and user group.
	// 3. For a section, object, and any user.
	// 4. For a section, any object (object = section), and user.
	// 5. For a section, any object (object = section), and user group.
	// 6. For a section, any object (object = section), and any user.
	// 7. For any section (blank section), any object (object = section), and user.
	// 8. For any section (blank section), any object (object = section), and user group.
	// 9. For any section (blank section), any object (object = section), and any user.
	
	// Priorities of import restriction dates.
	// 1. For a section, object, and node.
	// 2. For a section, object, and any node.
	// 3. For a section, any object (object = section), and node.
	// 4. For a section, any object (object = section), and any node.
	// 5. For any section (blank section), any object (object = section), and node.
	// 6. For any section (blank section), any object (object = section), and any node.
	
	BegOfDay = BegOfDay(CurrentSessionDate());
	
	EffectiveDates = New Structure;
	EffectiveDates.Insert("BegOfDay", BegOfDay);
	
	AddresseesTypes = Metadata.DefinedTypes.PeriodEndClosingTarget.Type.Types();
	NodesAddresseesTypes = New Array;
	UsersAddresseesTypes = New Array;
	For each AddresseesType In AddresseesTypes Do
		MetadataObject = Metadata.FindByType(AddresseesType);
		If Metadata.ExchangePlans.Contains(MetadataObject) Then
			NodesAddresseesTypes.Add(AddresseesType);
		ElsIf AddresseesType <> Type("EnumRef.PeriodClosingDatesPurposeTypes") Then
			UsersAddresseesTypes.Add(AddresseesType);
		EndIf;
	EndDo;
	
	EffectiveDates.Insert("SectionsProperties", CurrentSectionsProperties(NodesAddresseesTypes));
	
	If Common.SeparatedDataUsageAvailable() Then
		QueryResults = PeriodClosingDatesRequest().ExecuteBatch();
		
		ConstantValues = QueryResults[0].Unload()[0];
		EffectiveDates.Insert("Version",                      ConstantValues.PeriodClosingDatesVersion);
		EffectiveDates.Insert("PeriodClosingUsed", ConstantValues.UsePeriodClosingDates);
		EffectiveDates.Insert("ImportRestrictionUsed",  ConstantValues.UseImportForbidDates);
		
		DataExported = QueryResults[1].Unload(QueryResultIteration.ByGroups);
		UserGroups = New Map;
		For Each Row In DataExported.Rows Do
			UserGroups.Insert(Row.User,
				New FixedArray(Row.Rows.UnloadColumn("UsersGroup")));
		EndDo;
		EffectiveDates.Insert("UserGroups", New FixedMap(UserGroups));
		
		EffectiveDates.Insert("ForUsers",     SetDates(QueryResults[2], BegOfDay));
		EffectiveDates.Insert("ForInfobases", SetDates(QueryResults[3], BegOfDay));
	Else
		EffectiveDates.Insert("Version", New UUID("00000000-0000-0000-0000-000000000000"));
		EffectiveDates.Insert("PeriodClosingUsed", False);
		EffectiveDates.Insert("ImportRestrictionUsed",  False);
		EffectiveDates.Insert("UserGroups", New FixedMap(New Map));
		SetDates = New Structure;
		SetDates.Insert("Sections", New FixedMap(New Map));
		SetDates.Insert("RestrictionDatesByObjectsNotSpecified", True);
		EffectiveDates.Insert("ForUsers",     New FixedStructure(SetDates));
		EffectiveDates.Insert("ForInfobases", New FixedStructure(SetDates));
	EndIf;
	
	If EffectiveDates.ForUsers.Sections.Count() = 0 Then
		EffectiveDates.PeriodClosingUsed = False;
	EndIf;
	
	If EffectiveDates.ForInfobases.Sections.Count() = 0
	 Or NodesAddresseesTypes.Count() = 0 Then
		
		EffectiveDates.ImportRestrictionUsed = False;
	EndIf;
	
	EffectiveDates.Insert("DataSources", 
		CurrentDataSourceForPeriodClosingCheck(EffectiveDates.SectionsProperties));
	
	Return New FixedStructure(EffectiveDates);
	
EndFunction

// For the SessionParameterValueEffectivePeriodClosingDates procedure.

Function PeriodClosingDatesRequest()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Constants.PeriodClosingDatesVersion AS PeriodClosingDatesVersion,
	|	Constants.UseImportForbidDates AS UseImportForbidDates,
	|	Constants.UsePeriodClosingDates AS UsePeriodClosingDates
	|FROM
	|	Constants AS Constants
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UserGroupCompositions.User AS User,
	|	UserGroupCompositions.UsersGroup AS UsersGroup
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		INNER JOIN InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|		ON UserGroupCompositions.UsersGroup = PeriodClosingDates.User
	|			AND (UserGroupCompositions.UsersGroup <> UserGroupCompositions.User)
	|TOTALS BY
	|	User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	(PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|			OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
	|			OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
	|			OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
	|			OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups))
	|TOTALS BY
	|	Section,
	|	Object
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	PeriodClosingDates.User <> UNDEFINED
	|	AND PeriodClosingDates.User <> VALUE(Enum.PeriodClosingDatesPurposeTypes.EmptyRef)
	|	AND PeriodClosingDates.User <> VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.ExternalUsersGroups)
	|TOTALS BY
	|	Section,
	|	Object";
	
	Return Query;
	
EndFunction

Function SetDates(QueryResult, BegOfDay)
	
	DataExported = QueryResult.Unload(QueryResultIteration.ByGroups);
	
	Sections = New Map;
	RestrictionDatesByObjectsNotSpecified = True;
	
	For Each Section In DataExported.Rows Do
		Objects = New Map;
		For Each Object In Section.Rows Do
			Recipients = New Map;
			For Each Recipient In Object.Rows Do
				Recipients.Insert(Recipient.User, PeriodEndClosingDateByDetails(
					Recipient.PeriodEndClosingDateDetails, Recipient.PeriodEndClosingDate, BegOfDay));
			EndDo;
			Objects.Insert(Object.Object, New FixedMap(Recipients));
			If Object.Object <> Section.Section Then
				RestrictionDatesByObjectsNotSpecified = False;
			EndIf;
		EndDo;
		Sections.Insert(Section.Section, New FixedMap(Objects));
	EndDo;
	
	SetDates = New Structure;
	SetDates.Insert("Sections", New FixedMap(Sections));
	SetDates.Insert("RestrictionDatesByObjectsNotSpecified", RestrictionDatesByObjectsNotSpecified);
	
	Return New FixedStructure(SetDates);
	
EndFunction

Function CurrentSectionsProperties(NodesAddresseesTypes)
	
	Properties = New Structure;
	Properties.Insert("UseExternalUsers", False);
	
	PeriodClosingDatesOverridable.InterfaceSetup(Properties);
	
	Properties.Insert("ImportRestrictionDatesImplemented", NodesAddresseesTypes.Count() > 0);
	
	EmptyNodesRefs = New Array;
	
	For Each NodesAddresseesType In NodesAddresseesTypes Do
		EmptyNodeRef = EmptyRef(NodesAddresseesType);
		EmptyNodesRefs.Add(EmptyNodeRef);
	EndDo;
	
	Properties.Insert("EmptyExchangePlansNodesRefs", New FixedArray(EmptyNodesRefs));
	
	SectionsProperties = ChartsOfCharacteristicTypes.PeriodClosingDatesSections.ClosingDatesSectionsProperties();
	
	For Each KeyAndValue In SectionsProperties Do
		Properties.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	Return New FixedStructure(Properties);
	
EndFunction

Function CurrentDataSourceForPeriodClosingCheck(SectionsProperties)
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return New FixedMap(New Map);
	EndIf;
	
	DataSources = New ValueTable;
	DataSources.Columns.Add("Table",     New TypeDescription("String"));
	DataSources.Columns.Add("DateField",    New TypeDescription("String"));
	DataSources.Columns.Add("Section",      New TypeDescription("String"));
	DataSources.Columns.Add("ObjectField", New TypeDescription("String"));
	DataSources.Indexes.Add("Table");
	
	SSLSubsystemsIntegration.OnFillDataSourcesForPeriodClosingCheck(DataSources);
	PeriodClosingDatesOverridable.FillDataSourcesForPeriodClosingCheck(DataSources);
	
	Sources = New Map;
	Tables = DataSources.Copy(, "Table");
	Tables.GroupBy("Table");
	
	ErrorTitle =
		NStr("ru = 'Ошибка в процедуре FillDataSourcesForPeriodClosingCheck
		           |общего модуля PeriodClosingDatesOverridable.'; 
		           |en = 'An error occurred in the FillDataSourcesForPeriodClosingCheck procedure
		           |of the PeriodClosingDatesOverridable common module.'; 
		           |pl = 'Błąd FillDataSourcesForPeriodClosingCheck w procedurze
		           |ogólnego PeriodClosingDatesOverridable modułu.';
		           |es_ES = 'Error en el procedimiento FillDataSourcesForPeriodClosingCheck
		           |del módulo común PeriodClosingDatesOverridable.';
		           |es_CO = 'Error en el procedimiento FillDataSourcesForPeriodClosingCheck
		           |del módulo común PeriodClosingDatesOverridable.';
		           |tr = 'Prosedür hatası Genel modülün
		           |DeğişiklikYasağKontrolüİçinVeriKaynaklarınıDoldur DeğişiklikYasağıTarihleriYenidenBelirlenen.';
		           |it = 'Si è verificato un errore nella procedure FillDataSourcesForPeriodClosingCheck
		           |del modulo generale PeriodClosingDatesOverridable.';
		           |de = 'Fehler bei der Vorgehensweise FillDataSourcesForPeriodClosingCheck
		           |des allgemeinen Moduls PeriodClosingDatesOverridable.'")
		+ Chars.LF
		+ Chars.LF;
	
	For Each Row In Tables Do
		TableSources = New Structure;
		Try
			If StrStartsWith(Upper(Row.Table), Upper("AccumulationRegister"))
				Or StrStartsWith(Upper(Row.Table), Upper("AccountingRegister"))
				Or StrStartsWith(Upper(Row.Table), Upper("InformationRegister")) Then
				ItemType = Type(StrReplace(Row.Table, ".", "RecordKey."));
				IsRegister = True;
			Else
				ItemType = Type(StrReplace(Row.Table, ".", "Ref."));
				IsRegister = False;
			EndIf;
			MetadataObject = Metadata.FindByType(ItemType);
		Except
			IsRegister = Undefined;
			MetadataObject = Metadata.FindByFullName(Row.Table);
		EndTry;
		If MetadataObject = Undefined Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для проверки запрета изменения в источнике данных неверно указана таблица
				           |""%1"".'; 
				           |en = 'The ""%1"" table
				           | is specified incorrectly in the data source to check period-end closing.'; 
				           |pl = 'Nieprawidłowo jest wskazana tabela dla weryfikacji zakazu zmiany w źródle danych
				           |""%1"".';
				           |es_ES = 'Para comprobar la restricción de cambio en la fuente de datos está indicada incorrectamente la tabla
				           |""%1"".';
				           |es_CO = 'Para comprobar la restricción de cambio en la fuente de datos está indicada incorrectamente la tabla
				           |""%1"".';
				           |tr = 'Değişiklik yasağı kontrolü için veri kaynağında 
				           |""%1"" tablosu yanlış belirtilmiştir.';
				           |it = 'La tabella ""%1""
				           | è specificata in modo errato nella fonte di dati per il controllo della chiusura di fine periodo.';
				           |de = 'Um das Verbot von Änderungen in der Datenquelle zu überprüfen, wurde die Tabelle
				           |""%1"" falsch angegeben.'"),
				Row.Table);
		EndIf;
		If IsRegister = Undefined Then
			IsRegister = Common.IsRegister(MetadataObject);
		EndIf;
		TableSources.Insert("IsRegister", IsRegister);
		
		TableDataSources = DataSources.FindRows(New Structure("Table", Row.Table));
		SourcesContent = New Array;
		RegisterFields = New Map;
		QueryText = "";
		QueryTextDatesOnly = "";
		
		For Each Row In TableDataSources Do
			SectionProperties = SectionsProperties.Sections.Get(Row.Section);
			If SectionProperties = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Для проверки запрета изменения в источнике данных указан несуществующий
					           |раздел ""%1"" для таблицы ""%2"".'; 
					           |en = 'Non-existing
					           |section ""%1"" is specified in the data source for the ""%2"" table to check period-end closing.'; 
					           |pl = 'Dla weryfikacji zakazu zmiany w źródle danych jest wskazany nie istniejący 
					           |rozdział ""%1"" dla tabeli ""%2"".';
					           |es_ES = 'Para comprobar la restricción de cambio en la fuente de datos está indicada la sección
					           |inexistente ""%1"" para la tabla ""%2"".';
					           |es_CO = 'Para comprobar la restricción de cambio en la fuente de datos está indicada la sección
					           |inexistente ""%1"" para la tabla ""%2"".';
					           |tr = 'Dönem sonu kapanış kontrolü için ""%2"" tablosunun veri kaynağında
					           |var olmayan ""%1"" bölümü belirtildi.';
					           |it = 'È stata indicata
					           |la sezione non esistente ""%1"" nella fonte di dati per la tabella ""%2"" per il controllo della chiusura di fine periodo.';
					           |de = 'Um das Verbot von Änderungen in der Datenquelle zu überprüfen, wird ein nicht vorhandener
					           |Abschnitt ""%1"" für die Tabelle ""%2"" angezeigt.'"),
					Row.Section, Row.Table);
			EndIf;
			Source = New Structure;
			Source.Insert("Section",      Row.Section);
			Source.Insert("DateField",    TableField(Row, "DateField",    MetadataObject, IsRegister));
			Source.Insert("ObjectField", TableField(Row, "ObjectField", MetadataObject, IsRegister));
			If IsRegister Then
				RegisterFields.Insert(Source.DateField.Name, True);
				If ValueIsFilled(Source.ObjectField.Name) Then
					AddQueryTextForRegister(QueryText, Row.Table, Source);
					RegisterFields.Insert(Source.ObjectField.Name, True);
				Else
					AddQueryTextDatesOnlyForRegister(QueryText, Row.Table, Source);
				EndIf;
				AddQueryTextDatesOnlyForRegister(QueryTextDatesOnly, Row.Table, Source);
			Else
				If ValueIsFilled(Source.ObjectField.Name) Then
					AddQueryText(QueryText, Row.Table, Source);
				Else
					AddQueryTextDatesOnly(QueryText, Row.Table, Source);
				EndIf;
				AddQueryTextDatesOnly(QueryTextDatesOnly, Row.Table, Source);
			EndIf;
			SourcesContent.Add(New FixedStructure(Source));
		EndDo;
		TableSources.Insert("Content", New FixedArray(SourcesContent));
		TableSources.Insert("QueryText", QueryText);
		TableSources.Insert("QueryTextDatesOnly", QueryTextDatesOnly);
		If IsRegister Then
			Fields = "";
			For Each KeyAndValue In RegisterFields Do
				Fields = Fields + "," + KeyAndValue.Key;
			EndDo;
			TableSources.Insert("RegisterFields", Mid(Fields, 2));
		EndIf;
		Sources.Insert(Row.Table, New FixedStructure(TableSources));
	EndDo;
	
	Return New FixedMap(Sources);
	
EndFunction

// For the CurrentDataSourcesForPeriodClosingCheck function.

Function TableField(Source, FieldKind, MetadataObject, IsRegister)
	
	Properties = New Structure("Name, Type, TabularSection, Path, NameAndPath");
	
	Field = Source[FieldKind];
	Fields = StrSplit(Field, ".", False);
	
	If Fields.Count() = 0 Then
		If FieldKind = "DateField" Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для проверки запрета изменения 
				           |в источнике данных для таблицы ""%1""
				           |не задано поле даты.'; 
				           |en = 'Date field is not specified in the data source for
				           |the ""%1"" table for checking
				           |the period-end closing.'; 
				           |pl = 'Dla weryfikacji zakazu zmiany 
				           |w źródle danych dla tabeli ""%1""
				           |nie jest określono pole daty.';
				           |es_ES = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido el campo de la fecha.';
				           |es_CO = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido el campo de la fecha.';
				           |tr = 'Dönem sonu kapanışının kontrolü için
				           |""%1"" tablosunun veri kaynağında
				           |tarih alanı belirtilmemiş.';
				           |it = 'Il campo data non è indicato nella fonte dei dati
				           |per la tabella ""%1"" per il controllo
				           |della chiusura del periodo.';
				           |de = 'Für die Tabelle ""%1""
				           |ist das Datumsfeld nicht angegeben, um zu überprüfen, ob die Datenquelle nicht geändert werden kann
				           |.'"),
				Source.Table);
		Else
			Return New FixedStructure(Properties);
		EndIf;
		
	ElsIf NOT ValueIsFilled(Fields[0]) Then
		If FieldKind = "DateField" Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для проверки запрета изменения 
				           |в источнике данных для таблицы ""%1""
				           |неверно задано поле даты: ""%2""'; 
				           |en = 'To check the period-end closing
				           |in the data source for the ""%1"" table,
				           |the date field is incorrect: ""%2""'; 
				           |pl = 'Dla weryfikacji zakazu zmiany 
				           |w źródle danych dla tabeli ""%1""
				           |nieprawidłowo określono pole daty: ""%2""';
				           |es_ES = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo de la fecha: ""%2""';
				           |es_CO = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo de la fecha: ""%2""';
				           |tr = '""%1"" tablosu için veri kaynağında
				           |dönem sonu kapanışını kontrol etmek için
				           |veri alanı yanlış belirtilmiş: ""%2""';
				           |it = 'Per il controllo della chiusura
				           |di fine periodo il campo data nella fonte
				           |per la tabella ""%1"" non è corretto: ""%2""';
				           |de = 'Um das Verbot von Änderungen
				           |in der Datenquelle für die Tabelle ""%1""
				           |zu überprüfen, ist das Datumsfeld falsch: ""%2""'"),
				Source.Table, Field);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для проверки запрета изменения 
				           |в источнике данных для таблицы ""%1""
				           |неверно задано поле объекта: ""%2""'; 
				           |en = 'To check the period-end closing
				           |in the data source for the ""%1"" table,
				           |the object field is incorrect: ""%2""'; 
				           |pl = 'Dla weryfikacji zakazu zmiany 
				           |w źródle danych dla tabeli ""%1""
				           | jest nieprawidłowo określono pole obiektu ""%2"".';
				           |es_ES = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo del objeto: ""%2""';
				           |es_CO = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo del objeto: ""%2""';
				           |tr = '""%1"" tablosu için veri kaynağında
				           |değişiklik yasağını kontrol etmek için
				           |veri alanı yanlış belirtilmiştir: ""%2""';
				           |it = 'Per il controllo della chiusura
				           |di fine periodo il campo oggetto nella fonte
				           |per la tabella ""%1"" non è corretto: ""%2""';
				           |de = 'Um das Verbot von Änderungen
				           |in der Datenquelle für die Tabelle ""%1""
				           |zu überprüfen, ist das Objektfeld falsch: ""%2""'"),
				Source.Table, Field);
		EndIf;
	EndIf;
	
	If IsRegister
	 Or MetadataObject.TabularSections.Find(Fields[0]) = Undefined Then
		
		Properties.NameAndPath = Field;
		Properties.Name = Fields[0];
		PointPosition = StrFind(Field, ".");
		If PointPosition > 0 Then
			Properties.Path = Mid(Field, PointPosition + 1);
		EndIf;
		If ValueIsFilled(Properties.Path) Then
			Properties.Type = FieldType(MetadataObject, Properties.Name);
		EndIf;
		Return New FixedStructure(Properties);
	EndIf;
	
	If Fields.Count() = 1 Then
		If FieldKind = "DateField" Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для проверки запрета изменения 
				           |в источнике данных для таблицы ""%1""
				           |неверно задано поле даты:
				           |не задано поле заданной табличной части ""%2"".'; 
				           |en = 'To check the period-end closing
				           |in the data source for the ""%1"" table,
				           |the date field is incorrect:
				           |the field of specified tabular section ""%2"" is not set.'; 
				           |pl = 'Dla weryfikacji zakazu zmiany 
				           |w źródle danych dla tabeli ""%1""
				           |nieprawidłowo określono pole daty: 
				           | nie określono pole określonej części tabelarycznej""%2""';
				           |es_ES = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo de la fecha:
				           |no está establecido el campo de la parte de tabla establecida ""%2"".';
				           |es_CO = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo de la fecha:
				           |no está establecido el campo de la parte de tabla establecida ""%2"".';
				           |tr = '""%1"" tablosunun
				           |veri kaynağında dönem sonu kapanış kontrolü için
				           |tarih alanı yanlış:
				           |Belirtilen ""%2"" tablo bölümünün alanı belirtilmemiş.';
				           |it = 'Per il controllo della chiusura
				           |di fine periodo nella fonte dei dati per la tabella ""%1""
				           |il campo data non è corretto:
				           |il campo della sezione tabellare indicata ""%2"" non è impostato.';
				           |de = 'Um das Verbot von Änderungen
				           |in der Datenquelle für die Tabelle ""%1""
				           |zu überprüfen, ist das Datumsfeld falsch:
				           |das Feld des angegebenen Tabellenteils ""%2"" ist nicht angegeben.'"),
				Source.Table, Fields[0]);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для проверки запрета изменения 
				           |в источнике данных для таблицы ""%1""
				           |неверно задано поле объекта:
				           |не задано поле заданной табличной части ""%2"".'; 
				           |en = 'To check the period-end closing
				           |in the data source for the ""%1"" table,
				           |the object field is incorrect:
				           |the field of specified tabular section ""%2"" is not set.'; 
				           |pl = 'Dla weryfikacji zakazu zmiany 
				           |w źródle danych dla tabeli ""%1""
				           | jest nieprawidłowo określono pole obiektu:
				           | nie określono pole określonej części tabelarycznej ""%2"".';
				           |es_ES = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo del objeto:
				           |no está establecido el campo de la parte de tabla establecida ""%2"".';
				           |es_CO = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo del objeto:
				           |no está establecido el campo de la parte de tabla establecida ""%2"".';
				           |tr = '""%1"" tablosunun
				           |veri kaynağında dönem sonu kapanış kontrolü için
				           |nesne alanı yanlış:
				           |Belirtilen ""%2"" tablo bölümünün alanı belirtilmemiş.';
				           |it = 'Per il controllo della chiusura
				           |di fine periodo nella fonte dei tati per la tabella ""%1""
				           |il campo oggetto non è corretto:
				           |il campo della sezione tabellare indicata ""%2"" non è impostato.';
				           |de = 'Um das Verbot von Änderungen
				           |in der Datenquelle für die Tabelle ""%1""
				           |zu überprüfen, ist das Objektfeld falsch:
				           |das Feld des angegebenen Tabellenteils ""%2"" ist nicht angegeben.'"),
				Source.Table, Fields[0]);
		EndIf;
	ElsIf NOT ValueIsFilled(Fields[1]) Then
		If FieldKind = "DateField" Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для проверки запрета изменения 
				           |в источнике данных для таблицы ""%1""
				           |неверно задано поле даты:
				           |неверно задано поле заданной табличной части ""%2"".'; 
				           |en = 'To check the period-end closing
				           |in the data source for the ""%1"" table,
				           |the date field is incorrect:
				           |the field of specified tabular section ""%2"" is incorrect.'; 
				           |pl = 'Dla weryfikacji zakazu zmiany 
				           |w źródle danych dla tabeli ""%1""
				           |nieprawidłowo określono pole daty: 
				           | nieprawidłowo określono pole określonej części tabelarycznej""%2""';
				           |es_ES = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido el campo de la fecha:
				           |no está establecido el campo de la parte de tabla establecida ""%2"".';
				           |es_CO = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido el campo de la fecha:
				           |no está establecido el campo de la parte de tabla establecida ""%2"".';
				           |tr = '""%1"" tablosunun
				           |veri kaynağında dönem sonu kapanış kontrolü için
				           |tarih alanı yanlış:
				           |Belirtilen ""%2"" tablo bölümünün alanı yanlış.';
				           |it = 'Per il controllo della chiusura
				           |di fine periodo nella fonte dei dati per la tabella ""%1""
				           |il campo data non è corretto:
				           |il campo della sezione tabellare indicata ""%2"" non è corretto.';
				           |de = 'Um das Verbot von Änderungen
				           |in der Datenquelle für die Tabelle ""%1""
				           |zu überprüfen, ist das Datumsfeld falsch:
				           |das Feld des angegebenen Tabellenteils ""%2"" ist falsch angegeben.'"),
				Source.Table, Fields[0]);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для проверки запрета изменения 
				           |в источнике данных для таблицы ""%1""
				           |неверно задано поле объекта:
				           |неверно задано поле заданной табличной части ""%2"".'; 
				           |en = 'To check the period-end closing
				           |in the data source for the ""%1"" table,
				           |the object field is incorrect:
				           |the field of the specified tabular section ""%2"" is incorrect.'; 
				           |pl = 'Dla weryfikacji zakazu zmiany 
				           |w źródle danych dla tabeli ""%1""
				           | jest nieprawidłowo określono pole obiektu:
				           | nie prawidłowo określono pole określonej części tabelarycznej ""%2"".';
				           |es_ES = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo del objeto:
				           |no está establecido el campo de la parte de tabla establecida ""%2"".';
				           |es_CO = 'Para comprobar la restricción de cambio 
				           |en la fuente de datos para la tabla ""%1""
				           |no está establecido correctamente el campo del objeto:
				           |no está establecido el campo de la parte de tabla establecida ""%2"".';
				           |tr = '""%1"" tablosunun
				           |veri kaynağında dönem sonu kapanış kontrolü için
				           |nesne alanı yanlış:
				           |Belirtilen ""%2"" tablo bölümünün alanı yanlış.';
				           |it = 'Per il controllo della chiusura
				           |di fine periodo nella fonte dei dati per la tabella ""%1""
				           |il campo oggetto non è corretto:
				           |il campo della sezione tabellare indicata ""%2"" non è corretto.';
				           |de = 'Um das Verbot von Änderungen
				           |in der Datenquelle für die Tabelle ""%1""
				           |zu überprüfen, ist das Objektfeld falsch:
				           |das Feld des angegebenen Tabellenteils ""%2"" ist falsch angegeben.'"),
				Source.Table, Fields[0]);
		EndIf;
	EndIf;
	
	Properties.TabularSection = Fields[0];
	Properties.Name = Fields[1];
	
	PointPosition = StrFind(Field, ".");
	Properties.NameAndPath = Mid(Field, PointPosition + 1);
	
	PointPosition = StrFind(Properties.NameAndPath, ".");
	If PointPosition > 0 Then
		Properties.Path = Mid(Properties.NameAndPath, PointPosition + 1);
	EndIf;
	
	If ValueIsFilled(Properties.Path) Then
		Properties.Type = FieldType(MetadataObject, Properties.Name, Properties.TabularSection);
	EndIf;
	
	Return New FixedStructure(Properties);
	
EndFunction

Function FieldType(MetadataObject, FieldName, TabularSectionName = "")
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	&FieldName AS CurrentField
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	FALSE";
	
	Query.Text = StrReplace(Query.Text, "&FieldName", "CurrentTable." + FieldName);
	Query.Text = StrReplace(Query.Text, "&CurrentTable", MetadataObject.FullName()
		+ ?(ValueIsFilled(TabularSectionName), "." + TabularSectionName, ""));
	
	Return New TypeDescription(Query.Execute().Unload().Columns["CurrentField"].ValueType,, "Null");
	
EndFunction

Procedure AddQueryText(QueryText, Table, Source)
	
	If Not ValueIsFilled(Source.DateField.TabularSection)
	   AND Not ValueIsFilled(Source.ObjectField.TabularSection)
	 Or Source.DateField.TabularSection = Source.ObjectField.TabularSection Then
		
		If Source.DateField.TabularSection = Source.ObjectField.TabularSection Then
			CurrentTable = Table + "." + Source.DateField.TabularSection;
		Else
			CurrentTable = Table;
		EndIf;
		
		Text =
		"SELECT
		|	CAST(&DateField AS DATE) AS Date,
		|	ISNULL(&ObjectField, UNDEFINED) AS Object
		|FROM
		|	&Table AS CurrentTable
		|WHERE
		|	CurrentTable.Ref = &Ref";
		Text = StrReplace(Text, "&Table",     CurrentTable);
		Text = StrReplace(Text, "&DateField",    "CurrentTable." + Source.DateField.NameAndPath);
		Text = StrReplace(Text, "&ObjectField", "CurrentTable." + Source.ObjectField.NameAndPath);
	Else
		If ValueIsFilled(Source.DateField.TabularSection) Then
			DateFieldsTable = Table + "." + Source.DateField.TabularSection;
		Else
			DateFieldsTable = Table;
		EndIf;
		
		If ValueIsFilled(Source.ObjectField.TabularSection) Then
			ObjectFieldsTable = Table + "." + Source.ObjectField.TabularSection;
		Else
			ObjectFieldsTable = Table;
		EndIf;
		
		Text =
		"SELECT
		|	CAST(&DateField AS DATE) AS Date,
		|	ISNULL(&ObjectField, UNDEFINED) AS Object
		|FROM
		|	DateTable AS DateFieldsTable
		|		LEFT JOIN ObjectTable AS ObjectFieldsTable
		|		ON DateFieldsTable.Ref = ObjectFieldsTable.Ref
		|WHERE
		|	DateFieldsTable.Ref = &Ref";
		Text = StrReplace(Text, "DateTable",    DateFieldsTable);
		Text = StrReplace(Text, "ObjectTable", ObjectFieldsTable);
		Text = StrReplace(Text, "&DateField",    "DateFieldsTable."    + Source.DateField.NameAndPath);
		Text = StrReplace(Text, "&ObjectField", "ObjectFieldsTable." + Source.ObjectField.NameAndPath);
	EndIf;
	
	AddQueryTextToPackage(QueryText, Text);
	
EndProcedure

Procedure AddQueryTextDatesOnly(QueryText, Table, Source)
	
	If Not ValueIsFilled(Source.DateField.TabularSection) Then
		Text =
		"SELECT
		|	CAST(&DateField AS DATE) AS Date
		|FROM
		|	&Table AS CurrentTable
		|WHERE
		|	CurrentTable.Ref = &Ref";
		Text = StrReplace(Text, "&Table", Table);
		Text = StrReplace(Text, "&DateField", "CurrentTable." + Source.DateField.NameAndPath);
	Else
		Text =
		"SELECT TOP 1
		|	CAST(&DateField AS DATE) AS Date
		|FROM
		|	&Table AS CurrentTable
		|WHERE
		|	CurrentTable.Ref = &Ref
		|
		|ORDER BY
		|	Date";
		Text = StrReplace(Text, "&Table", Table + "." + Source.DateField.TabularSection);
		Text = StrReplace(Text, "&DateField", "CurrentTable." + Source.DateField.NameAndPath);
	EndIf;
	
	AddQueryTextToPackage(QueryText, Text);
	
EndProcedure

Procedure AddQueryTextForRegister(QueryText, Table, Source)
	
	Text =
	"SELECT DISTINCT
	|	CAST(&DateField AS DATE) AS Date,
	|	ISNULL(&ObjectField, UNDEFINED) AS Object
	|FROM
	|	&Table AS CurrentTable
	|WHERE
	|	&FilterCriterion";
	
	Text = StrReplace(Text, "&Table", Table);
	Text = StrReplace(Text, "&DateField",    "CurrentTable." + Source.DateField.NameAndPath);
	Text = StrReplace(Text, "&ObjectField", "CurrentTable." + Source.ObjectField.NameAndPath);
	
	AddQueryTextToPackage(QueryText, Text);
	
EndProcedure

Procedure AddQueryTextDatesOnlyForRegister(QueryText, Table, Source)
	
	Text =
	"SELECT TOP 1
	|	CAST(&DateField AS DATE) AS Date
	|FROM
	|	&Table AS CurrentTable
	|WHERE
	|	&FilterCriterion
	|
	|ORDER BY
	|	Date";
	
	Text = StrReplace(Text, "&Table", Table);
	Text = StrReplace(Text, "&DateField", "CurrentTable." + Source.DateField.NameAndPath);
	
	AddQueryTextToPackage(QueryText, Text);
	
EndProcedure

Procedure AddQueryTextToPackage(QueriesPackageText, QueryText)
	
	If Not ValueIsFilled(QueriesPackageText) Then
		QueriesPackageText = QueryText;
		Return;
	EndIf;
	
	QueriesPackageText = QueriesPackageText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|" + QueryText;
	
EndProcedure

// For procedures OnSendDataToMaster, OnSendDataToMaster.
// OnReceiveDataFromMaster, OnReceiveDataFromSlave.
//
Function RecordSetOnlyWithImportRestrictionDates(DataItem)
	
	If TypeOf(DataItem) <> Type("InformationRegisterRecordSet.PeriodClosingDates") Then
		Return False;
	EndIf;
	
	If Not DataItem.Filter.User.Use Then
		Raise
			NStr("ru = 'Выгрузка или загрузка записей регистра сведений ""Даты запрета изменения""
			           |допускается только в разрезе измерения Пользователь.'; 
			           |en = 'You can export and import records of the ""Period-end closing dates"" 
			           |information register only by the User dimension.'; 
			           |pl = 'Eksportowanie lub pobieranie wpisów rejestru danych ""Daty zakazu zmiany ""
			           |jest dopuszczalne tylko w przekroju pomiaru Użytkownik.';
			           |es_ES = 'La subida o descarga de los registros del registro de información ""Las fechas de prohibir los cambios""
			           |se admite solo para la dimensión Usuario.';
			           |es_CO = 'La subida o descarga de los registros del registro de información ""Las fechas de prohibir los cambios""
			           |se admite solo para la dimensión Usuario.';
			           |tr = '""Değişiklik yasaklanma tarihi"" 
			           |kayıt bilgilerini dışa aktarma veya yükleme yalnızca Kullanıcı boyut bölümünde izin verilir.';
			           |it = 'È possibile esportare e importare le registrazioni del registro di informazioni ""Date di chiusura fine periodo"" 
			           |solo dalla dimensione Utente.';
			           |de = 'Das Hochladen oder Herunterladen von Datensätzen der Informationen zu den ""Datum des Änderungsverbots""
			           |ist nur im Kontext der Dimension Benutzer zulässig.'");
	EndIf;
	
	Return Not IsPeriodClosingAddressee(DataItem.Filter.User.Value);
	
EndFunction

#EndRegion
