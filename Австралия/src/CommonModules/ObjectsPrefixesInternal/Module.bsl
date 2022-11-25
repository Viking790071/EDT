////////////////////////////////////////////////////////////////////////////////
// Object Prefixes subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Internal

// Changes an infobase prefix.
// Additionally, allows to process data to continue numbering.
//
// Parameters:
//  Parameters - Structure - procedure parameters:
//   * NewIBPrefix - String - a new infobase prefix.
//   * ContinueNumbering - Boolean - shows whether it is required to continue numbering.
//  ResultAddress - String - the address of the temporary storage where the procedure puts its 
//                                result.
//
Procedure ChangeIBPrefix(Parameters, ResultAddress = "") Export
	
	// A constant containing the prefix is supplied together with the Data exchange subsystem.
	// Procedure execution makes no sense without it.
	If Not Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		Return;
	EndIf;
	
	NewIBPrefix = Parameters.NewIBPrefix;
	ContinueNumbering = Parameters.ContinueNumbering;
	
	BeginTransaction();
	
	Try
		
		If ContinueNumbering Then
			ProcessDataToContinueNumbering(NewIBPrefix);
		EndIf;
		
		// Set the constant last to have an access to its previous value.
		PrefixConstantName = "DistributedInfobaseNodePrefix";
		Constants[PrefixConstantName].Set(NewIBPrefix);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		WriteLogEvent(EventLogEventReassignObjectsPrefixes(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			
		Raise NStr("ru = 'Не удалось изменить префикс.'; en = 'Cannot change the prefix.'; pl = 'Nie udało się zmienić prefiksu.';es_ES = 'No se ha podido cambiar el prefijo.';es_CO = 'No se ha podido cambiar el prefijo.';tr = 'Önek değiştirilemedi.';it = 'Impossibile modificare il prefisso.';de = 'Das Präfix konnte nicht geändert werden.'");
		
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Returns whether the company or object date is changed.
//
// Parameters:
//  Reference - a reference to an infobase object.
//  DateAfterChange - an object date after change.
//  CompanyAfterChange - an object company after change.
// 
//  Returns:
//   True - an object company was changed or a new object date was set in another periodicity 
//            interval in comparison with the previous date value.
//   False - the company and the document date were not changed.
//
Function ObjectDateOrCompanyChanged(Ref, Val DateAfterChange, Val CompanyAfterChange) Export
	
	FullTableName = Ref.Metadata().FullName();
	QueryText = "
	|SELECT
	|	ObjectHeader.Date                                AS Date,
	|	ISNULL(ObjectHeader.[CompanyAttributeName].Prefix, """") AS CompanyPrefixBeforeChange
	|FROM
	|	" + FullTableName + " AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[CompanyAttributeName]", ObjectsPrefixesEvents.CompanyAttributeName(FullTableName));
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	CompanyPrefixAfterChange = Undefined;
	ObjectsPrefixesEvents.OnDetermineCompanyPrefix(CompanyAfterChange, CompanyPrefixAfterChange);
	
	// If a blank reference to a company is specified.
	CompanyPrefixAfterChange = ?(CompanyPrefixAfterChange = False, "", CompanyPrefixAfterChange);
	
	Return Selection.CompanyPrefixBeforeChange <> CompanyPrefixAfterChange
		OR Not ObjectDatesOfSamePeriod(Selection.Date, DateAfterChange, Ref);
	//
EndFunction

// Returns whether the object company is changed.
//
// Parameters:
//  Reference - a reference to an infobase object.
//  CompanyAfterChange - an object company after change.
//
//  Returns:
//   True - the object company was changed. False - the company was not changed.
//
Function ObjectCompanyChanged(Ref, Val CompanyAfterChange) Export
	
	FullTableName = Ref.Metadata().FullName();
	QueryText = "
	|SELECT
	|	ISNULL(ObjectHeader.[CompanyAttributeName].Prefix, """") AS CompanyPrefixBeforeChange
	|FROM
	|	" + FullTableName + " AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[CompanyAttributeName]", ObjectsPrefixesEvents.CompanyAttributeName(FullTableName));
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	CompanyPrefixAfterChange = Undefined;
	ObjectsPrefixesEvents.OnDetermineCompanyPrefix(CompanyAfterChange, CompanyPrefixAfterChange);
	
	// If a blank reference to a company is specified.
	CompanyPrefixAfterChange = ?(CompanyPrefixAfterChange = False, "", CompanyPrefixAfterChange);
	
	Return Selection.CompanyPrefixBeforeChange <> CompanyPrefixAfterChange;
	
EndFunction

// Identifies whether two dates of a metadata object are equal.
// Dates are considered to be equal if they belong to the same period of time: Year, Month, Day, and etc.
//
// Parameters:
//  Date1 - the first date for comparison.
// Date2 – the second date for comparison.
// ObjectMetadata – metadata of an object for which a function value is to be got.
// 
//  Returns:
//   True - object dates of the same period; False - object dates of different periods.
//
Function ObjectDatesOfSamePeriod(Val Date1, Val Date2, Ref) Export
	
	ObjectMetadata = Ref.Metadata();
	
	If DocumentNumberPeriodicityYear(ObjectMetadata) Then
		
		DateDiff = BegOfYear(Date1) - BegOfYear(Date2);
		
	ElsIf DocumentNumberPeriodicityQuarter(ObjectMetadata) Then
		
		DateDiff = BegOfQuarter(Date1) - BegOfQuarter(Date2);
		
	ElsIf DocumentNumberPeriodicityMonth(ObjectMetadata) Then
		
		DateDiff = BegOfMonth(Date1) - BegOfMonth(Date2);
		
	ElsIf DocumentNumberPeriodicityDay(ObjectMetadata) Then
		
		DateDiff = BegOfDay(Date1) - BegOfDay(Date2);
		
	Else // DocumentNumberPeriodicityUndefined
		
		DateDiff = 0;
		
	EndIf;
	
	Return DateDiff = 0;
	
EndFunction

Function MetadataUsingPrefixesDetails(DiagnosticsMode = False) Export
	
	Result = NewMetadataUsingPrefixesDetails();

	// Filling a metadata table.
	DataSeparationEnabled = Common.DataSeparationEnabled();
	For Each Subscription In Metadata.EventSubscriptions Do
		
		IBPrefixUsed = False;
		CompanyPrefixUsed = False;
		If Upper(Subscription.Handler) = Upper("ObjectsPrefixesEvents.SetInfobaseAndCompanyPrefix") Then
			IBPrefixUsed = True;
			CompanyPrefixUsed = True;
		ElsIf Upper(Subscription.Handler) = Upper("ObjectsPrefixesEvents.SetInfobasePrefix") Then
			IBPrefixUsed = True;
		ElsIf Upper(Subscription.Handler) = Upper("ObjectsPrefixesEvents.SetCompanyPrefix") Then
			CompanyPrefixUsed = True;
		Else
			// Skipping subscriptions not related to prefixation.
			Continue;
		EndIf;
		
		For Each SourceType In Subscription.Source.Types() Do
			
			SourceMetadata = Metadata.FindByType(SourceType);
			FullObjectName = SourceMetadata.FullName();
			
			// Skipping already added objects (if several subscriptions are assigned by mistake) and objects 
			// matching shared data in case of separated mode.
			If Not DiagnosticsMode Then
				
				If Result.Find(FullObjectName, "FullName") <> Undefined Then
					Continue;
				ElsIf DataSeparationEnabled Then
					
					If Common.SubsystemExists("StandardSubsystems.SaaS") Then
						ModuleSaaS = Common.CommonModule("SaaS");
						IsSeparatedMetadataObject = ModuleSaaS.IsSeparatedMetadataObject(FullObjectName);
					Else
						IsSeparatedMetadataObject = False;
					EndIf;
					
					If Not IsSeparatedMetadataObject Then
						Continue;
					EndIf;
					
				EndIf;
				
			EndIf;
			
			ObjectDetails = Result.Add();
			ObjectDetails.Name = SourceMetadata.Name;
			ObjectDetails.FullName = FullObjectName;
			ObjectDetails.IBPrefixUsed = IBPrefixUsed;
			ObjectDetails.CompanyPrefixUsed = CompanyPrefixUsed;
		
			// Possible data types with a code or number.
			ObjectDetails.IsCatalog             = Common.IsCatalog(SourceMetadata);
			ObjectDetails.IsChartOfCharacteristicTypes = Common.IsChartOfCharacteristicTypes(SourceMetadata);
			ObjectDetails.IsDocument               = Common.IsDocument(SourceMetadata);
			ObjectDetails.IsBusinessProcess          = Common.IsBusinessProcess(SourceMetadata);
			ObjectDetails.IsTask                 = Common.IsTask(SourceMetadata);
			
			ObjectDetails.SubscriptionName = Subscription.Name;
			
			Characteristics = New Structure("CodeLength, NumberLength", 0, 0);
			FillPropertyValues(Characteristics, SourceMetadata);
			
			If Characteristics.CodeLength = 0 AND Characteristics.NumberLength = 0 Then
				
				If Not DiagnosticsMode Then
					
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Ошибка внедрения подсистемы ""%1"" для объекта метаданных ""%2"".'; en = 'An error occurred while implementing the ""%1"" subsystem for the ""%2"" metadata object.'; pl = 'Błąd implementacji podsystemu ""%1"" dla obiektu metadanych ""%2"".';es_ES = 'Error de integrar el subsistema ""%1"" para el objeto de metadatos ""%2"".';es_CO = 'Error de integrar el subsistema ""%1"" para el objeto de metadatos ""%2"".';tr = '%2Meta veri nesnesi için %1alt sistemi uygulama hatası.';it = 'Si è verificato un errore durante l''implementazione del sottosistema ""%1"" per l''oggetto metadati ""%2"".';de = 'Fehler bei der Implementierung des Subsystems ""%1"" für das Metadatenobjekt ""%2"".'"),
						Metadata.Subsystems.StandardSubsystems.Subsystems.ObjectsPrefixes, FullObjectName);
						
				EndIf;
				
			Else
				
				If ObjectDetails.IsCatalog Or ObjectDetails.IsChartOfCharacteristicTypes Then
					ObjectDetails.HasCode = True;
				Else
					ObjectDetails.HasNumber = True;
				EndIf;
				
			EndIf;
			
			// Defining a number periodicity for a document and business process.
			NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Nonperiodical;
			If ObjectDetails.IsDocument Then
				NumberPeriodicity = SourceMetadata.NumberPeriodicity;
			ElsIf ObjectDetails.IsBusinessProcess Then
				If SourceMetadata.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Year Then
					NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year;
				ElsIf SourceMetadata.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Day Then
					NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day;
				ElsIf SourceMetadata.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Quarter Then
					NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter;
				ElsIf SourceMetadata.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Month Then
					NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month;
				ElsIf SourceMetadata.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Nonperiodical Then
					NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Nonperiodical;
				EndIf;
			EndIf;
			ObjectDetails.NumberPeriodicity = NumberPeriodicity;
			
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Determines whether the AfterDataImport event handler is to be executed upon exchange in DIB.
//
// Parameters:
//  NewBPrefix - String - it is intended for computing new item codes (numbers) after the prefix is changed.
//  DataAnalysisMode - Boolean - if True, data is not changed, the function defines which data is 
//                                changed and how. If False - object changes are recorded to the 
//                                infobase.
//
// Returns:
//   ValueTable - information on objects whose numbers or codes are to be changed (see the 
//                     ObjectsPrefixesInternal.MetadataUsingPrefixesDetails function).
//
Function ProcessDataToContinueNumbering(Val NewIBPrefix = "", DataAnalysisMode = False)
	
	MetadataUsingPrefixesDetails = MetadataUsingPrefixesDetails();
	
	SupplementStringWithZerosOnLeft(NewIBPrefix, 2);
	
	Result = NewMetadataUsingPrefixesDetails();
	Result.Columns.Add("Ref");
	Result.Columns.Add("Number");
	Result.Columns.Add("NewNumber");
	
	CurrentIBPrefix = "";
	ObjectsPrefixesEvents.OnDetermineInfobasePrefix(CurrentIBPrefix);
	SupplementStringWithZerosOnLeft(CurrentIBPrefix, 2);
	
	For Each ObjectDetails In MetadataUsingPrefixesDetails Do
		
		If Not DataAnalysisMode Then
			// Setting an exclusive lock for data types being read and changed.
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(ObjectDetails.FullName);
			DataLock.Lock();
		EndIf;
		
		ObjectDataForLastItemRenumbering = OneKindObjectDataForLastItemsRenumbering(
			ObjectDetails, CurrentIBPrefix);
		
		If ObjectDataForLastItemRenumbering.IsEmpty() Then
			Continue;
		EndIf;
		
		ObjectSelection = ObjectDataForLastItemRenumbering.Select();
		While ObjectSelection.Next() Do
			
			NewResultString = Result.Add();
			FillPropertyValues(NewResultString, ObjectDetails);
			FillPropertyValues(NewResultString, ObjectSelection);
			NewResultString.NewNumber = StrReplace(NewResultString.Number, CurrentIBPrefix + "-", NewIBPrefix + "-");
			
			If Not DataAnalysisMode Then
				RenumberingObject = NewResultString.Ref.GetObject();
				RenumberingObject[?(NewResultString.HasNumber, "Number", "Code")] = NewResultString.NewNumber;
				InfobaseUpdate.WriteData(RenumberingObject, True, False);
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function DocumentNumberPeriodicityYear(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year;
	
EndFunction

Function DocumentNumberPeriodicityQuarter(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter;
	
EndFunction

Function DocumentNumberPeriodicityMonth(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month;
	
EndFunction

Function DocumentNumberPeriodicityDay(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day;
	
EndFunction

Function OneKindObjectDataForLastItemsRenumbering(Val ObjectDetails, Val PreviousPrefix = "")
	
	FullObjectName = ObjectDetails.FullName;
	HasNumber = ObjectDetails.HasNumber;
	CompanyPrefixUsed = ObjectDetails.CompanyPrefixUsed;
	
	Query = New Query;
	
	BatchQueryText = New Array;
	Separator =
	"
	|;
	|/////////////////////////////////////////////////////////////
	|";

	QueryText =
	"SELECT
	|	SelectionByDateNumber.Ref AS Ref,
	|	&CompanyFieldName AS Organization,
	|	&CodeNumberFieldName AS Number
	|INTO SelectionByDateNumber
	|FROM
	|	&TableName AS SelectionByDateNumber
	|WHERE
	|	&ConditionByDate AND &CodeNumberFieldName LIKE &Prefix
	|
	|INDEX BY
	|	Number,
	|	Organization";
	
	QueryText = StrReplace(QueryText, "&ConditionByDate", ?(HasNumber, "SelectionByDateNumber.Date >= &Date", "TRUE"));
	QueryText = StrReplace(QueryText, "&CodeNumberFieldName", "SelectionByDateNumber." + ?(HasNumber, "Number", "Code"));
	QueryText = StrReplace(QueryText, "&TableName", FullObjectName);
	
	CompanyFieldName = ?(CompanyPrefixUsed,
		"SelectionByDateNumber." + ObjectsPrefixesEvents.CompanyAttributeName(FullObjectName), "Undefined");
	QueryText = StrReplace(QueryText, "&CompanyFieldName", CompanyFieldName);
	
	BatchQueryText.Add(QueryText);
	
	QueryText =
	"SELECT
	|	MaxCodes.Organization AS Organization,
	|	MAX(MaxCodes.Number) AS Number
	|INTO MaxCodes
	|FROM
	|	SelectionByDateNumber AS MaxCodes
	|
	|GROUP BY
	|	MaxCodes.Organization
	|
	|INDEX BY
	|	Number,
	|	Organization";
	BatchQueryText.Add(QueryText);
	
	QueryText =
	"SELECT
	|	SelectionByDateNumber.Organization AS Organization,
	|	SelectionByDateNumber.Number AS Number,
	|	MAX(SelectionByDateNumber.Ref) AS Ref
	|FROM
	|	SelectionByDateNumber AS SelectionByDateNumber
	|		INNER JOIN MaxCodes AS MaxCodes
	|		ON (MaxCodes.Number = SelectionByDateNumber.Number
	|				AND MaxCodes.Organization = SelectionByDateNumber.Organization)
	|
	|GROUP BY
	|	SelectionByDateNumber.Organization,
	|	SelectionByDateNumber.Number";
	BatchQueryText.Add(QueryText);
	
	Query.Text = StrConcat(BatchQueryText, Separator);
	
	If HasNumber Then
		// Selecting data from the beginning of the current year.
		FromDate = BegOfDay(BegOfYear(CurrentSessionDate()));
		Query.SetParameter("Date", BegOfDay(FromDate));
	EndIf;
	
	// Processing objects created only in the current infobase.
	Prefix = "%[Prefix]-%";
	Prefix = StrReplace(Prefix, "[Prefix]", PreviousPrefix);
	Query.SetParameter("Prefix", Prefix);
	
	Return Query.Execute();
	
EndFunction

Function NewMetadataUsingPrefixesDetails()
	
	TypesDetailsString = New TypeDescription("String");
	TypesDetailsBoolean = New TypeDescription("Boolean");
	
	Result = New ValueTable;
	Result.Columns.Add("Name",                            TypesDetailsString);
	Result.Columns.Add("FullName",                      TypesDetailsString);
	
	Result.Columns.Add("HasCode",                        TypesDetailsBoolean);
	Result.Columns.Add("HasNumber",                      TypesDetailsBoolean);
	Result.Columns.Add("IsCatalog",                  TypesDetailsBoolean);
	Result.Columns.Add("IsChartOfCharacteristicTypes",      TypesDetailsBoolean);
	Result.Columns.Add("IsDocument",                    TypesDetailsBoolean);
	Result.Columns.Add("IsBusinessProcess",               TypesDetailsBoolean);
	Result.Columns.Add("IsTask",                      TypesDetailsBoolean);
	Result.Columns.Add("IBPrefixUsed",          TypesDetailsBoolean);
	Result.Columns.Add("CompanyPrefixUsed", TypesDetailsBoolean);
	
	Result.Columns.Add("NumberPeriodicity");
	
	Result.Columns.Add("SubscriptionName", TypesDetailsString);
	
	Return Result;
	
EndFunction

Procedure SupplementStringWithZerosOnLeft(Row, StringLength)
	
	Row = StringFunctionsClientServer.SupplementString(Row, StringLength, "0", "Left");
	
EndProcedure

Function EventLogEventReassignObjectsPrefixes()
	
	Return NStr("ru = 'Префиксация объектов.Изменение префикса информационной базы'; en = 'Objects prefixes.Infobase prefix change'; pl = 'Prefiks obiektu.Zmiana prefiksu bazy informacyjnej';es_ES = 'Vuelta a colocar el prefijo del objeto.Cambio del prefijo de la infobase';es_CO = 'Vuelta a colocar el prefijo del objeto.Cambio del prefijo de la infobase';tr = 'Nesne öneki. Veritabanı öneki değişikliği';it = 'Impostazione di prefissi degli oggetti. Modifica del prefisso dell''infobase';de = 'Objektpräfixierung. Infobase-Präfixänderung'",
		CommonClientServer.DefaultLanguageCode());
	
EndFunction

#EndRegion