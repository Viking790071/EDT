#Region Public

// Checks whether changing data is denied when a user edits it interactively or when data is 
// imported from the ImportRestrictionCheckNode exchange plan node programmatically.
// This function requires a preliminary setup of the FillDataSourcesForPeriodClosingCheck procedure 
// from the PeriodClosingDatesOverridable module.
//
// Parameters:
//  DataOrFullName - CatalogObject,
//                        DocumentObject,
//                        ChartOfCharacteristicTypesObject,
//                        ChartOfAccountsObject,
//                        ChartOfCalculationTypesObject,
//                        BusinessProcessObject,
//                        TaskObject,
//                        ExchangePlanObject,
//                        InformationRegisterRecordSet,
//                        AccumulationRegisterRecordSet,
//                        AccountingRegisterRecordSet,
//                        CalculationRegisterRecordSet - a data item or record set to be checked.
//                      - String - the full name of a metadata object whose data is to be checked in the database.
//                                 Example: "Document.PurchaseInvoice".
//                                 In this case, in the DataID parameter, specify the data to be 
//                                 read and checked.
//
//  DataID - CatalogRef,
//                        DocumentRef,
//                        ChartOfCharacteristicTypesRef,
//                        ChartOfAccountsRef,
//                        ChartOfCalculationTypesRef,
//                        BusinessProcessRef,
//                        TaskRef,
//                        ExchangePlanRef,
//                        Filter - a reference to a data item or a record set filter to be checked.
//                                       The value to be checked will be received from the database.
//                      - Undefined - do not get data from the database and check object data in 
//                                       DataOrFullName instead.
//
//  ErrorDescription    - Null      - (default value) period-end closing data is not required.
//                    - String    - (return value) - return a text description of available period-end closing dates.
//                    - Structure - (return value) - return a structural description of available 
//                                  period-end closing dates. See the PeriodClosingDates.PeriodEndClosingFound function.
//
//  ImportRestrictionCheckNode - Undefined, ExchangePlansRef - if Undefined, check period-end 
//                                closing; otherwise check data import from the exchange plan node.
//
// Returns:
//  Boolean - True if changing data is denied.
//
// Call options:
//   DataChangesDenied(CatalogObject...)         - checks data in a passed object or record set.
//   DataChangesDenied(String, CatalogRef...) - checks data retrieved from the database by the full 
//      metadata object name and reference or by a record set filter.
//   DataChangesDenied(CatalogObject..., CatalogRef...) - simultaneously checks data in a passed 
//      object and data in the database (in other words, before and after writing to the infobase if 
//      the check is performed before writing the object).
//
Function DataChangesDenied(DataOrFullName, DataID = Undefined,
	ErrorDescription = Null, ImportRestrictionCheckNode = Undefined) Export
	
	PeriodClosingCheck = ImportRestrictionCheckNode = Undefined;
	
	If TypeOf(DataOrFullName) = Type("String") Then
		If TypeOf(DataID) = Type("Filter") Then
			DataManager = Common.ObjectManagerByFullName(DataOrFullName);
			Source = DataManager.CreateRecordSet();
			For Each FilterItem In DataID Do
				Source.Filter[FilterItem.Name].Set(FilterItem.Value, FilterItem.Use);
			EndDo;
			Source.Read();
		ElsIf Not ValueIsFilled(DataID) Then
			Return False;
		Else
			Source = DataID.GetObject();
		EndIf;
		
		If PeriodClosingDatesInternal.SkipClosingDatesCheck(Source,
				PeriodClosingCheck, ImportRestrictionCheckNode, "") Then
			Return False;
		EndIf;
		
		Return PeriodClosingDatesInternal.DataChangesDenied(DataOrFullName,
			DataID, ErrorDescription, ImportRestrictionCheckNode);
	EndIf;
	
	ObjectVersion = "";
	If PeriodClosingDatesInternal.SkipClosingDatesCheck(DataOrFullName,
			 PeriodClosingCheck, ImportRestrictionCheckNode, ObjectVersion) Then
		Return False;
	EndIf;
	
	Source      = DataOrFullName;
	ID = DataID;
	
	If ObjectVersion = "OldVersion" Then
		Source = Metadata.FindByType(DataOrFullName).FullName();
		
	ElsIf ObjectVersion = "NewVersion" Then
		ID = Undefined;
	EndIf;
	
	Return PeriodClosingDatesInternal.DataChangesDenied(Source,
		ID, ErrorDescription, ImportRestrictionCheckNode);
	
EndFunction

// Checks the import restriction for a data item or the Data record set.
// It check both old and new data versions.
// Preliminary setup of the DataForPeriodClosingCheck procedure from the 
// PeriodEndClosingDatesOverridable module is required.
//
// Parameters:
//  Data              - CatalogObject,
//                        DocumentObject,
//                        ChartOfCharacteristicTypesObject,
//                        ChartOfAccountsObject,
//                        ChartOfCalculationTypesObject,
//                        BusinessProcessObject,
//                        TaskObject,
//                        ExchangePlanObject,
//                        ObjectDeletion,
//                        InformationRegisterRecordSet,
//                        AccumulationRegisterRecordSet,
//                        AccountingRegisterRecordSet,
//                        CalculationRegisterRecordSet - a data item or a record set.
//
//  ImportRestrictionCheckNode  - ExchangePlanRef - a node to be checked.
//
//  Cancel               - Boolean - the return value. True if import is restricted.
//
//  ErrorDescription      - Null      - (default value) - period-end closing data is not required.
//                      - String    - (return value) - return a text description of available period-end closing dates.
//                      - Structure - (return value) - return a structural description of available 
//                                    period-end closing dates. See the PeriodClosingDates.PeriodEndClosingFound function.
//
Procedure CheckDataImportRestrictionDates(Data, ImportRestrictionCheckNode, Cancel, ErrorDescription = Null) Export
	
	If TypeOf(Data) = Type("ObjectDeletion") Then
		MetadataObject = Data.Ref.Metadata();
	Else
		MetadataObject = Data.Metadata();
	EndIf;
	
	DataSources = PeriodClosingDatesInternal.DataSourcesForPeriodClosingCheck();
	If DataSources.Get(MetadataObject.FullName()) = Undefined Then
		Return; // Restrictions by dates are not defined for this object type.
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("PeriodClosingCheck",    False);
	AdditionalParameters.Insert("ImportRestrictionCheckNode", ImportRestrictionCheckNode);
	AdditionalParameters.Insert("ErrorDescription",              ErrorDescription);
	AdditionalParameters.Insert("InformAboutPeriodEnd",            False);
	
	IsRegister = Common.IsRegister(MetadataObject);
	
	PeriodClosingDatesInternal.CheckDataImportRestrictionDates(Data,
		Cancel, IsRegister, IsRegister, TypeOf(Data) = Type("ObjectDeletion"), AdditionalParameters);
	
	ErrorDescription = AdditionalParameters.ErrorDescription;
	
EndProcedure

// The OnReadAtServer form event handler, which is embedded into item forms of catalogs, documents, 
// register records, and other objects to lock the form if data changes are denied.
//
// Parameters:
//  Form               - ClientApplicationForm - an item form of an object or a register record form.
//
//  CurrentObject       - CatalogObject,
//                        DocumentObject,
//                        ChartOfCharacteristicTypesObject,
//                        ChartOfAccountsObject,
//                        ChartOfCalculationTypesObject,
//                        BusinessProcessObject,
//                        TaskObject,
//                        ExchangePlanObject,
//                        InformationRegisterRecordManager,
//                        AccumulationRegisterRecordManager,
//                        AccountingRegisterRecordManager,
//                        CalculationRegisterRecordManager - a record manager.
//
// Returns:
//  Boolean - True if programmatic period-end closing check was skipped.
//
Function ObjectOnReadAtServer(Form, CurrentObject) Export
	
	MetadataObject = Metadata.FindByType(TypeOf(CurrentObject));
	FullName = MetadataObject.FullName();
	
	EffectiveDates = PeriodClosingDatesInternal.EffectiveClosingDates();
	DataSources = EffectiveDates.DataSources.Get(FullName);
	If DataSources = Undefined Then
		Return False;
	EndIf;
	
	If Common.IsRegister(MetadataObject) Then
		// Converting a record manager to a record set with a single record.
		DataManager = Common.ObjectManagerByFullName(FullName);
		Source = DataManager.CreateRecordSet();
		For each FilterItem In Source.Filter Do
			FilterItem.Set(CurrentObject[FilterItem.Name], True);
		EndDo;
		FillPropertyValues(Source.Add(), CurrentObject);
	Else
		Source = CurrentObject;
	EndIf;
	
	If PeriodClosingDatesInternal.SkipClosingDatesCheck(Source,
			True, Undefined, "") Then
		Return True;
	EndIf;
	
	If DataChangesDenied(Source) Then
		Form.ReadOnly = True;
	EndIf;
	
	Return False;
	
EndFunction

// Adds a string of data source details required for the period-end closing check.
// This procedure is used in the FillDataSourcesForPeriodClosingCheck procedure of the 
// PeriodClosingDatesOverridable common module.
// 
// Parameters:
//  Data      - ValueTable - this parameter is passed to the FillDataSourcesForPeriodClosingCheck procedure.
//  Table     - String - a full name of a metadata object, for example, "Document.PurchaseInvoice".
//  DataField    - String - a name of an object attribute or tabular section, for example: "Date", "Goods.ShipmentDate".
//  Section      - String - a name of a predefined item of ChartOfCharacteristicTypesRef.ClosingDatesSections.
//  ObjectField - String - a name of an object attribute or tabular section attribute, for example: "Company", "Goods.Warehouse".
//
Procedure AddRow(Data, Table, DateField, Section = "", ObjectField = "") Export
	
	NewRow = Data.Add();
	NewRow.Table     = Table;
	NewRow.DateField    = DateField;
	NewRow.Section      = Section;
	NewRow.ObjectField = ObjectField;
	
EndProcedure

// Finds period-end closing dates by data to be checked for a specified user or exchange plan node.
// 
//
// Parameters:
//  DataToCheck - ValueTable - a return  value of the DataTemplateToCheck function of the 
//                      PeriodClosingDates common module.
//
//  DataDetails    - Undefined - period-end closing message text is not generated.
//                    - Structure - with the following properties:
//                      * NewVersion - Boolean - if True, generate a period-end closing message for 
//                                   a new version, otherwise generate it for an old version.
//                      * Data - Reference, Object - a reference or a data object for getting a 
//                                   presentation to be used in a period-end closing message.
//                               - RecordSet - a register record set for getting a presentation to 
//                                   be used in a period-end closing message.
//                               - Structure - with properties for a period-end closing message:
//                                   * Register - String - a full register name.
//                                   *         - RecordSet - a register record set.
//                                   * Filter - Filter - a record set filter.
//                               - String - a prepared data presentation, which will be used in a 
//                                 period-end closing message.
//
//  ErrorDescription    - Null      - (default value) period-end closing data is not required.
//                    - String    - (return value) - return a text description of available period-end closing dates.
//                    - Structure - (return value) - return structural details of the detected period-end closing:
//                        * DataPresentation - String - a data presentation used in the error title.
//                        * ErrorTitle    - String - a string similar to the following one:
//                                                "Order 10 dated 01/01/2017 cannot be changed in the closed period."
//                        * PeriodEnds - ValueTable - detected period-end closing as a table with columns:
//                          ** Date - Date - a checked date.
//                          ** Section          -  String       -  a section name where period end 
//                                                 closing is searched, if a string is blank, date valid for all sections is searched.
//                          ** Object          - AnyRef  - a reference to the object, in which period-end closing date was searched.
//                                             - Undefined - searching for a date valid for all objects.
//                          ** PeriodEndClosingDate     - Date        - a detected period-end closing date.
//                          ** CommonDate       - Boolean       -  if True, then a detected 
//                                                 period-end closing date is valid for all sections, not only for the searched section.
//                          ** ForAllObjects - Boolean       - if True, then the detected period-end 
//                                                 closing date is valid for all objects, not only for the searched object.
//                          ** Addressee - DefinedType.PeriodClosingAddressee - a user or an 
//                                                 exchange plan node, for which the detected period-end closing date is specified.
//                          ** Details        - String - a string similar to the following one:
//                            "Date 01/01/2017 of the "Application warehouse" object of the 
//                            "Warehouse accounting" section is within the range of period-end closing for all users (common period-end closing date is set)".
//
//  ImportRestrictionCheckNode - Undefined - check data change.
//                              - ExchangePlansRef.<Exchange plan name> - check data import for the 
//                                specified node.
//
// Returns:
//  Boolean - if True, then at least one period-end closing is detected.
//
Function PeriodEndClosingFound(Val DataToCheck,
                                    DataDetails = Undefined,
                                    ErrorDescription = Null,
                                    ImportRestrictionCheckNode = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(DataToCheck) = Type("Structure") Then
		EffectiveDates   = DataToCheck.EffectiveDates;
		DataToCheck = DataToCheck.DataToCheck;
	Else
		EffectiveDates = PeriodClosingDatesInternal.EffectiveClosingDates();
	EndIf;
	
	RestrictionUsed = ?(ImportRestrictionCheckNode = Undefined,
		EffectiveDates.PeriodClosingUsed,
		EffectiveDates.ImportRestrictionUsed);
	
	If Not RestrictionUsed Then
		Return False;
	EndIf;
	
	SectionsProperties = EffectiveDates.SectionsProperties;
	BlankSection = PeriodClosingDatesInternal.EmptyRef(
		Type("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	
	ErrorTitle =
		NStr("ru = 'Ошибка в функции PeriodEndClosingFound общего модуля PeriodClosingDates.'; en = 'An error occurred in the PeriodEndClosingFound function of the PeriodClosingDates common module.'; pl = 'Błąd PeriodEndClosingFound w funkcji PeriodClosingDatesogólnego modułu.';es_ES = 'Error en la función PeriodEndClosingFound del módulo común PeriodClosingDates.';es_CO = 'Error en la función PeriodEndClosingFound del módulo común PeriodClosingDates.';tr = 'İşlev hatası DeğişiklikYasağıTarihinin genel modülünün VeriDeğişiklikYasağıBulunmuştur.';it = 'Si è verificato un errore della funzione PeriodEndClosingFound del modulo generale PeriodClosingDates.';de = 'Fehler in der Funktion GefundenVerbotDatenänderung des allgemeinen Moduls DatenÄnderungsverbot.'")
		+ Chars.LF
		+ Chars.LF;
	
	// Adjusting data to match the embedding option.
	For Each Row In DataToCheck Do
		
		If Row.Section = Undefined Then
			Row.Section = BlankSection;
		EndIf;
		
		SectionProperties = SectionsProperties.Sections.Get(Row.Section);
		If SectionProperties = Undefined Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'В параметре DataToCheck указан несуществующий раздел ""%1"".'; en = 'The DataToCheck parameter contains a section that does not exist: ""%1.""'; pl = 'W DataToCheck parametrze jest wskazany nieistniejący rozdział: ""%1.""';es_ES = 'En el parámetro DataToCheck está indicada la sección ""%1"".';es_CO = 'En el parámetro DataToCheck está indicada la sección ""%1"".';tr = 'DataToCheck parametresinde mevcut olmayan ""%1"" bölüm belirtilmiştir.';it = 'Il parametro DataToCheck contiene una sezione non esistente: ""%1.""';de = 'Der Parameter DatenZurVerifizierung enthält einen nicht existierenden Abschnitt ""%1"".'"),
				Row.Section);
		EndIf;
		
		If SectionsProperties.NoSectionsAndObjects Then
			Row.Section = BlankSection;
			Row.Object = BlankSection;
		Else
			If ValueIsFilled(SectionsProperties.SingleSection) Then
				Row.Section = SectionsProperties.SingleSection;
			Else
				Row.Section = SectionProperties.Ref;
			EndIf;
			
			If SectionsProperties.AllSectionsWithoutObjects
			 Or Not ValueIsFilled(Row.Object) Then
				
				Row.Object = Row.Section;
			EndIf;
		EndIf;
		
	EndDo;
	
	// Collapsing unnecessary rows to reduce the number of checks and messages.
	SectionsAndObjects = DataToCheck.Copy();
	SectionsAndObjects.GroupBy("Section, Object");
	Filter = New Structure("Section, Object");
	SectionsAndObjects.Columns.Add("Date",
		New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	
	For Each SectionAndObject In SectionsAndObjects Do
		FillPropertyValues(Filter, SectionAndObject);
		Rows = DataToCheck.FindRows(Filter);
		MinDate = Undefined;
		For Each Row In Rows Do
			CurrentDate = BegOfDay(Row.Date);
			If MinDate = Undefined Then
				MinDate = CurrentDate;
			EndIf;
			If CurrentDate < MinDate Then
				MinDate = CurrentDate;
			EndIf;
		EndDo;
		SectionAndObject.Date = MinDate;
	EndDo;
	DataToCheck = SectionsAndObjects;
	
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
	
	PeriodEndClosing = DataToCheck.Copy(New Array);
	PeriodEndClosing.Columns.Add("Recipient");
	PeriodEndClosing.Columns.Add("Data");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ImportRestrictionCheckNode", ImportRestrictionCheckNode);
	
	// Search for period-end closing.
	If ImportRestrictionCheckNode = Undefined Then
		Sections = EffectiveDates.ForUsers.Sections;
		User = Users.AuthorizedUser();
		UserGroups = EffectiveDates.UserGroups.Get(User);
		If UserGroups = Undefined Then
			UserGroups = New Array;
		EndIf;
		AdditionalParameters.Insert("User",       User);
		AdditionalParameters.Insert("UserGroups", UserGroups);
	Else
		Sections = EffectiveDates.ForInfobases.Sections;
		AdditionalParameters.Insert("BlankExchangePlanNode",
			Common.ObjectManagerByRef(ImportRestrictionCheckNode).EmptyRef());
	EndIf;
	
	For Each Data In DataToCheck Do
		RestrictionSection = Data.Section;
		RestrictionObject = Data.Object;
		
		Objects = Sections.Get(RestrictionSection);
		Recipients = Undefined;
		PeriodEndClosingDate = Undefined;
		
		If Objects <> Undefined Then
			Recipients = Objects.Get(RestrictionObject);
			If Recipients <> Undefined Then
				// Search for a section and object.
				PeriodEndClosingDate = FindPeriodEndClosingDate(Recipients, RestrictionSection, RestrictionObject, AdditionalParameters);
			EndIf;
			If PeriodEndClosingDate = Undefined Then
				RestrictionObject = RestrictionSection;
				Recipients = Objects.Get(RestrictionObject);
				If Recipients <> Undefined Then
					// Search for a section and any object.
					PeriodEndClosingDate = FindPeriodEndClosingDate(Recipients, RestrictionSection, RestrictionObject, AdditionalParameters);
				EndIf;
			EndIf;
		EndIf;
		If PeriodEndClosingDate = Undefined Then
			RestrictionSection = BlankSection;
			RestrictionObject = RestrictionSection;
			Objects = Sections.Get(RestrictionSection);
			If Objects = Undefined Then
				Continue;
			EndIf;
			Recipients = Objects.Get(RestrictionObject);
			If Recipients = Undefined Then
				Continue;
			EndIf;
			// Search for any section and any object (common date).
			PeriodEndClosingDate = FindPeriodEndClosingDate(Recipients, RestrictionSection, RestrictionObject, AdditionalParameters);
			If PeriodEndClosingDate = Undefined Then
				Continue;
			EndIf;
		EndIf;
		
		If PeriodEndClosingDate < Data.Date Then
			Continue;
		EndIf;
		
		If ImportRestrictionCheckNode = Undefined Then
			Recipient = User;
		Else
			Recipient = ImportRestrictionCheckNode;
		EndIf;
		
		Row = PeriodEndClosing.Add();
		Row.Data  = Data;
		Row.Section  = RestrictionSection;
		Row.Object  = RestrictionObject;
		Row.Recipient = Recipient;
		Row.Date    = PeriodEndClosingDate;
	EndDo;
	
	If TypeOf(DataDetails)  = Type("Structure")
	   AND TypeOf(ErrorDescription) <> Type("Null")
	   AND PeriodEndClosing.Count() > 0 Then
		
		ErrorDescription = PeriodEndMessage(PeriodEndClosing, DataDetails, SectionsProperties,
			ImportRestrictionCheckNode <> Undefined, TypeOf(ErrorDescription) = Type("Structure"));
	EndIf;
	
	Return PeriodEndClosing.Count() > 0;
	
EndFunction

// Returns an empty value table (with columns Date, Section, and Object) for filling in and passing 
// to the PeriodEndClosingFound function of the PeriodClosingDates common module.
// 
//
// Returns:
//  ValueTable - a table with columns:
//   * Date - Date - a date without time to be checked for subordination to the specified period-end 
//                       closing.
//
//   * Section - String - one of the section names specified in the OnFillPeriodClosingDatesSections 
//                       procedure of the PeriodClosingDatesOverridable common module.
//                       
//
//   * Object - Ref - one of the object types specified for the section in the 
//                       OnFillPeriodClosingDatesSections procedure of the 
//                       PeriodClosingDatesOverridable common module.
//
Function DataToCheckTemplate() Export
	
	DataToCheck = New ValueTable;
	
	DataToCheck.Columns.Add(
		"Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	
	DataToCheck.Columns.Add(
		"Section", New TypeDescription("String,ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	
	DataToCheck.Columns.Add(
		"Object", Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections.Type);
	
	Return DataToCheck;
	
EndFunction

// Updates chart of characteristic types PeriodClosingDatesSections according to the details in metadata.
// Used for calling common data (SaaS mode) from the update handler upon changing the section 
// content of period-end closing dates or section properties in the procedure.
// OnFillPeriodClosingDatesSections of the PeriodClosingDatesOverridable common module.
//
Procedure UpdatePeriodClosingDatesSections() Export
	
	PeriodClosingDatesInternal.UpdatePeriodClosingDatesSections();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// BeforeWrite event subscription handler for checking period-end closing.
//
// Parameters:
//  Source - CatalogObject,
//               ChartOfCharacteristicTypesObject,
//               ChartOfAccountsObject,
//               ChartOfCalculationTypesObject,
//               BusinessProcessObject,
//               TaskObject,
//               ExchangePlanObject - a data object passed to the BeforeWrite event subscription.
//
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure CheckPeriodEndClosingDateBeforeWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	CheckPeriodClosingDates(Source, Cancel);
	
EndProcedure

// BeforeWrite event subscription handler for checking period-end closing.
//
// Parameters:
//  Source - DocumentObject - a data object passed to the BeforeWrite event subscription.
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//  WriteMode - Boolean - a parameter passed to the BeforeWrite event subscription.
//  PostingMode - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure CheckPeriodEndClosingDateBeforeWriteDocument(Source, Cancel, WriteMode, PostingMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	Source.AdditionalProperties.Insert("WriteMode", WriteMode);
	
	CheckPeriodClosingDates(Source, Cancel);
	
EndProcedure

// BeforeWrite event subscription handler for checking period-end closing.
//
// Parameters:
//  Source - InformationRegisterRecordSet - AccumulationRegisterRecordsSet - a record set passed to 
//               the BeforeWrite event subscription.
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//  Replacing - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure CheckPeriodEndClosingDateBeforeWriteRecordSet(Source, Cancel, Overwrite) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	CheckPeriodClosingDates(Source, Cancel, True, Overwrite);
	
EndProcedure

// BeforeWrite event subscription handler for checking period-end closing.
//
// Parameters:
//  Source - AccountingRegisterRecordSet - a record set passed to the BeforeWrite event subscription.
//                
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//  WriteMode - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure CheckPeriodEndClosingDateBeforeWriteAccountingRegisterRecordSet(
		Source, Cancel, WriteMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	CheckPeriodClosingDates(Source, Cancel, True);
	
EndProcedure

// BeforeWrite event subscription handler for checking period-end closing.
//
// Parameters:
//  Source - CalculationRegisterRecordSet - a record set passed to the BeforeWrite event 
//                 subscription.
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//  Replacing - Boolean - a parameter passed to the BeforeWrite event subscription.
//  WriteOnly - Boolean - a parameter passed to the BeforeWrite event subscription.
//  WriteActualActionPeriod - Boolean - a parameter passed to the BeforeWrite event subscription.
//  WriteRecalculations - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure CheckPeriodEndClosingDateBeforeWriteCalculationRegisterRecordSet(
		Source,
		Cancel,
		Overwrite,
		WriteOnly,
		WriteActualActionPeriod,
		WriteRecalculations) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	CheckPeriodClosingDates(Source, Cancel, True, Overwrite);
	
EndProcedure

// BeforeDelete event subscription handler for checking period-end closing.
//
// Parameters:
//  Source - CatalogObject,
//               DocumentObject,
//               ChartOfCharacteristicTypesObject,
//               ChartOfAccountsObject,
//               ChartOfCalculationTypesObject,
//               BusinessProcessObject,
//               TaskObject,
//               ExchangePlanObject - a data object passed to the BeforeWrite event subscription.
//
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure CheckPeriodEndClosingDateBeforeDelete(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.DeletionMark Then
		Return;
	EndIf;
	
	CheckPeriodClosingDates(Source, Cancel, , , True);
	
EndProcedure

#EndRegion

#Region Private

// For procedures CheckPeriodEndClosingDate*.
Procedure CheckPeriodClosingDates(
		Source, Cancel, SourceRegister = False, Overwrite = True, Delete = False)
	
	PeriodClosingDatesInternal.CheckDataImportRestrictionDates(
		Source, Cancel, SourceRegister, Overwrite, Delete);
	
EndProcedure

// For the PeriodEndClosingFound function.
Function FindPeriodEndClosingDate(Recipients, RestrictionSection, RestrictionObject, AdditionalParameters)
	
	PeriodEndClosingDate = Undefined;
	
	If AdditionalParameters.ImportRestrictionCheckNode = Undefined Then
		Recipient = AdditionalParameters.User;
		PeriodEndClosingDate = Recipients.Get(Recipient);
		If PeriodEndClosingDate = Undefined Then
			For Each Folder In AdditionalParameters.UserGroups Do
				Date = Recipients.Get(Folder);
				If PeriodEndClosingDate = Undefined Then
					PeriodEndClosingDate = Date;
					Recipient = Folder;
				ElsIf Date <> Undefined AND PeriodEndClosingDate < Date Then
					PeriodEndClosingDate = Date;
					Recipient = Folder;
				EndIf;
			EndDo;
			If PeriodEndClosingDate = Undefined Then
				Recipient = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
				PeriodEndClosingDate = Recipients.Get(Recipient);
			EndIf;
		EndIf;
	Else
		Recipient = AdditionalParameters.ImportRestrictionCheckNode;
		PeriodEndClosingDate = Recipients.Get(Recipient);
		If PeriodEndClosingDate = Undefined Then
			Recipient = AdditionalParameters.BlankExchangePlanNode;
			PeriodEndClosingDate = Recipients.Get(Recipient);
		EndIf;
		If PeriodEndClosingDate = Undefined Then
			Recipient = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases;
			PeriodEndClosingDate = Recipients.Get(Recipient);
		EndIf;
	EndIf;
	
	Return PeriodEndClosingDate;
	
EndFunction

// For the PeriodEndClosingFound function.
Function PeriodEndMessage(PeriodEnds,
                           DataDetails,
                           SectionsProperties,
                           SearchImportRestrictions,
                           StructuralDetails)
	
	NewVersion = DataDetails.NewVersion;
	Text = DataPresentation(DataDetails.Data);
	
	If StructuralDetails Then
		ErrorDescription = New Structure;
		ErrorDescription.Insert("DataPresentation", Text);
		ErrorDescription.Insert("PeriodEnds", New ValueTable);
		Columns = ErrorDescription.PeriodEnds.Columns;
		Columns.Add("Date",            New TypeDescription("Date",,,,,New DateQualifiers(DateFractions.Date)));
		Columns.Add("Section",          New TypeDescription("String",,,,New StringQualifiers(100, AllowedLength.Variable)));
		Columns.Add("Object",          Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections.Type);
		Columns.Add("PeriodEndClosingDate",     New TypeDescription("Date",,,,,New DateQualifiers(DateFractions.Date)));
		Columns.Add("SingleDate",       New TypeDescription("Boolean"));
		Columns.Add("ForAllObjects", New TypeDescription("Boolean"));
		Columns.Add("Recipient",         Metadata.DefinedTypes.PeriodEndClosingTarget.Type);
		Columns.Add("Details",        New TypeDescription("String",,,,New StringQualifiers(1000,AllowedLength.Variable)));
	EndIf;
	
	If ValueIsFilled(Text) Then
		If SearchImportRestrictions Then
			If NewVersion Then
				Template = NStr("ru = '%1 невозможно загрузить в запрещенный период.'; en = '%1 cannot be imported to the restricted period.'; pl = '%1 niemożliwe jest pobranie w niedozwolony okres.';es_ES = '%1 es necesario subir en el período restringido.';es_CO = '%1 es necesario subir en el período restringido.';tr = '%1 yasaklanmış dönemde yüklenemez.';it = '%1 non può essere importato nel periodo vietato.';de = '%1 kann während eines verbotenen Zeitraums nicht heruntergeladen werden.'");
			Else
				Template = NStr("ru = '%1 в запрещенном периоде невозможно заменить загружаемыми данными.'; en = '%1 cannot be replaced with the data being imported in the restricted period.'; pl = '%1 w zakazanym okresie jest niemożliwa zmiana pobieranymi danymi.';es_ES = '%1 en el período restringido es imposible reemplazar por los datos cargados.';es_CO = '%1 en el período restringido es imposible reemplazar por los datos cargados.';tr = '%1 yasaklanmılş dönemde yüklenen veriler ile doldurulamaz.';it = '%1 non può essere sostituito con la data di importazione nel periodo vietato.';de = '%1 kann während eines verbotenen Zeitraums nicht durch herunterladbare Daten ersetzt werden.'");
			EndIf;
		Else
			If NewVersion Then
				Template = NStr("ru = '%1 невозможно поместить в запрещенный период.'; en = '%1 cannot be within the restricted period.'; pl = '%1 jest niemożliwe umieścić w niedozwolonym okresie.';es_ES = '%1 es imposible subir en el período restringido.';es_CO = '%1 es imposible subir en el período restringido.';tr = '%1 yasaklanmış dönemde yerleştirilemez.';it = '%1 non può essere nel periodo vietato.';de = '%1 kann nicht in einen verbotenen Zeitraum versetzt werden.'");
			Else
				Template = NStr("ru = '%1 в запрещенном периоде невозможно изменить.'; en = '%1 cannot be changed in the restricted period.'; pl = '%1 w niedozwolonym okresie jest niemożliwe zmienić.';es_ES = '%1 en el período restringido es imposible cambiar.';es_CO = '%1 en el período restringido es imposible cambiar.';tr = '%1 yasaklanmış dönemde değiştirilemez.';it = '%1 non può essere modificato nel periodo vietato.';de = '%1 kann in einem verbotenen Zeitraum nicht geändert werden.'");
			EndIf;
		EndIf;
		Text = StringFunctionsClientServer.SubstituteParametersToString(Template, Text) + Chars.LF + Chars.LF;
	EndIf;
	
	BlankSection = PeriodClosingDatesInternal.EmptyRef(
		Type("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	
	If StructuralDetails Then
		ErrorDescription.Insert("ErrorTitle", TrimAll(Text));
	EndIf;
	ErrorText = Text;
	
	For Each Prohibition In PeriodEnds Do
		Text = "";
		CheckSSL = Prohibition.Data;
		If Prohibition.Section = Prohibition.Object Then
			If Prohibition.Section = BlankSection Then
				Text = Text + NStr("ru = 'Дате %1'; en = 'Date %1'; pl = 'Data %1';es_ES = 'Fecha %1';es_CO = 'Fecha %1';tr = 'Tarih %1';it = 'Data %1';de = 'Datum %1'");
			Else
				Text = Text + NStr("ru = 'Дате %1 по разделу ""%2""'; en = 'Date %1 by the ""%2"" section'; pl = 'Data %1 według sekcji ""%2""';es_ES = 'Fecha %1 por la sección ""%2""';es_CO = 'Fecha %1 por la sección ""%2""';tr = '""%1"" bölümüne göre tarih %2';it = 'Data %1 secondo la sezione ""%2""';de = 'Datum %1 nach dem ""%2"" Abschnitt'");
			EndIf;
		ElsIf ValueIsFilled(SectionsProperties.SingleSection) Then
			Text = Text + NStr("ru = 'Дате %1 по объекту ""%3""'; en = 'Date %1 by the ""%3"" object'; pl = 'Data %1 według obiektu ""%3""';es_ES = 'Fecha %1 por el objeto ""%3""';es_CO = 'Fecha %1 por el objeto ""%3""';tr = '""%1"" nesneye göre tarih %3';it = 'Data %1 secondo l''oggetto ""%3""';de = 'Datum %1 nach dem ""%3"" Objekt'");
		Else
			Text = Text + NStr("ru = 'Дате %1 по объекту ""%3"" раздела ""%2""'; en = 'Date %1 by the ""%3"" object of the ""%2"" section'; pl = 'Data %1 według obiektu ""%3"" w sekcji ""%2""';es_ES = 'Fecha %1 por el objeto ""%3"" de la sección ""%2""';es_CO = 'Fecha %1 por el objeto ""%3"" de la sección ""%2""';tr = '""%1"" bölümün ""%3"" nesneye göre tarih %2';it = 'Data %1 secondo l''oggetto ""%3"" della sezione ""%2""';de = 'Datum %1 durch das ""%3"" Objekt des ""%2"" Abschnitts'");
		EndIf;
		If SearchImportRestrictions Then
			Text = Text + " " + NStr("ru = 'соответствует запрет загрузки данных'; en = 'data import restriction matches'; pl = 'odpowiada zakaz eksportowania danych';es_ES = 'corresponde la restricción de cargo de datos';es_CO = 'corresponde la restricción de cargo de datos';tr = 'veri içeri aktarılmasının yasaklanmasına karşılık gelir';it = 'corrispondenze alla restrizione di importazione dati';de = 'entspricht dem Verbot des Datenladens'") + " ";
		Else
			Text = Text + " " + NStr("ru = 'соответствует запрет изменения данных'; en = 'period-end closing corresponds'; pl = 'odpowiada zapobieganiu zmianom danych';es_ES = 'prevención de cambio de datos coincidentes';es_CO = 'prevención de cambio de datos coincidentes';tr = 'veri değişikliklerinin yasaklanmasına karşılık gelir';it = 'data di chiusura di fine periodo corrisponde';de = 'entspricht dem Verbot von Datenänderung'") + " ";
		EndIf;
		If Prohibition.Recipient = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers Then
			Text = Text + NStr("ru = 'для всех пользователей'; en = 'for all users'; pl = 'dla wszystkich użytkowników';es_ES = 'para todos usuarios';es_CO = 'para todos usuarios';tr = 'tüm kullanıcılar için';it = 'per tutti gli utenti';de = 'für alle Benutzer'");
			
		ElsIf Prohibition.Recipient = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
			Text = Text + NStr("ru = 'для всех информационных баз'; en = 'for all infobases'; pl = 'dla wszystkich baz informacyjnych';es_ES = 'para todas infobases';es_CO = 'para todas infobases';tr = 'tüm Infobase''ler için';it = 'per tutti i database di informazioni';de = 'für alle infobases'");
			
		ElsIf TypeOf(Prohibition.Recipient) = Type("CatalogRef.UserGroups")
		      OR TypeOf(Prohibition.Recipient) = Type("CatalogRef.ExternalUsersGroups") Then
			Text = Text + NStr("ru = 'для группы пользователей ""%4""'; en = 'for the ""%4"" user group'; pl = 'dla grupy użytkowników ""%4""';es_ES = 'para el grupo de usuarios ""%4""';es_CO = 'para el grupo de usuarios ""%4""';tr = '""%4"" kullanıcı grubu için';it = 'per i gruppi utente ""%4""';de = 'für die Benutzergruppe ""%4""'");
			
		ElsIf TypeOf(Prohibition.Recipient) = Type("CatalogRef.Users")
		      OR TypeOf(Prohibition.Recipient) = Type("CatalogRef.ExternalUsers") Then
			Text = Text + NStr("ru = 'для пользователя ""%4""'; en = 'for user ""%4""'; pl = 'dla użytkownika ""%4""';es_ES = 'para el usuario ""%4""';es_CO = 'para el usuario ""%4""';tr = '""%4"" kullanıcısı için';it = 'per l''utente ""%4""';de = 'für den Benutzer ""%4""'");
			
		ElsIf ValueIsFilled(Prohibition.Recipient) Then
			Text = Text + NStr("ru = 'для информационной базы ""%4""'; en = 'for the ""%4"" infobase'; pl = 'dla baz informacyjnych ""%4""';es_ES = 'para la infobase ""%4""';es_CO = 'para la infobase ""%4""';tr = '""%4"" Infobase için';it = 'per l''infobase ""%4""';de = 'für die ""%4"" Infobase'");
		Else
			Text = Text + NStr("ru = 'для всех информационных баз ""%6""'; en = 'for all infobases ""%6""'; pl = 'dla wszystkich baz informacyjnych ""%6""';es_ES = 'para todas infobases ""%6""';es_CO = 'para todas infobases ""%6""';tr = '""%6"" Infobase''ler için';it = 'per tutti i database di informazioni ""%6""';de = 'für alle Infobases ""%6""'");
		EndIf;
		Text = Text + " " + NStr("ru = 'по %5'; en = 'by %5'; pl = 'według %5';es_ES = 'por %5';es_CO = 'por %5';tr = '%5 göre';it = 'tramite %5';de = 'durch %5'");
		If Not SectionsProperties.NoSectionsAndObjects Then
			If ValueIsFilled(Prohibition.Section) Then
				If Prohibition.Object = Prohibition.Section Then
					Text = Text + " " + NStr("ru = '(запрет установлен на раздел ""%2"")'; en = '(section ""%2"" is restricted)'; pl = '(ustawiono zakaz dla sekcji ""%2"" )';es_ES = '(sección ""%2"" está prohibida)';es_CO = '(sección ""%2"" está prohibida)';tr = '(""%2"" bölümü kısıtlı)';it = '(sezione ""%2"" è limitata)';de = '(Abschnitt ""%2"" ist verboten)'");
				ElsIf ValueIsFilled(SectionsProperties.SingleSection) Then
					Text = Text + " " + NStr("ru = '(запрет установлен на объект ""%3"")'; en = '(object ""%3""  is restricted)'; pl = '(ustawiono zakaz dla obiektu ""%3"")';es_ES = '(objeto ""%3"" está prohibido)';es_CO = '(objeto ""%3"" está prohibido)';tr = '(""%3"" nesnesi kısıtlı)';it = '(oggetto ""%3"" è limitata)';de = '(Objekt ""%3"" ist verboten)'");
				Else
					Text = Text + " " + NStr("ru = '(запрет установлен на объект ""%3"" раздела ""%2"")'; en = '(object ""%3"" of section ""%2"" is restricted)'; pl = '(ustawiono zakaz dla obiektu ""%3"" sekcji ""%2"")';es_ES = '(objeto ""%3"" de la sección ""%2"" está prohibido)';es_CO = '(objeto ""%3"" de la sección ""%2"" está prohibido)';tr = '(""%2"" bölümünün ""%3"" nesnesi kısıtlı)';it = '(oggetto ""%3"" della sezione ""%2"" è limitato)';de = '(Objekt ""%3"" von Abschnitt ""%2"" ist verboten)'");
				EndIf;
			Else
				Text = Text + " " + NStr("ru = '(установлена общая дата запрета)'; en = '(common period-end closing date is set)'; pl = '(ustawiono wspólną datę zamknięcia)';es_ES = '(fecha de cierre común está establecida)';es_CO = '(fecha de cierre común está establecida)';tr = '(ortak dönem sonu kapanış tarihi belirlendi)';it = '(la data di chiusura generale fine periodo è impostato)';de = '(gemeinsames Abschlussdatum ist festgelegt)'");
			EndIf;
		EndIf;
		Text = StrReplace(Text, "%1", Format(CheckSSL.Date, "DLF=D"));
		Text = StrReplace(Text, "%2", CheckSSL.Section);
		Text = StrReplace(Text, "%3", CheckSSL.Object);
		Text = StrReplace(Text, "%4", Prohibition.Recipient);
		Text = StrReplace(Text, "%5", Format(Prohibition.Date, "DLF=D"));
		Text = StrReplace(Text, "%6", Prohibition.Recipient.Metadata().Presentation());
		
		ErrorText = ErrorText + Text + Chars.LF + Chars.LF;
		
		If StructuralDetails Then
			ErrorDescriptionString = ErrorDescription.PeriodEnds.Add();
			ErrorDescriptionString.Date        = CheckSSL.Date;
			ErrorDescriptionString.Section      = SectionsProperties.Sections.Get(CheckSSL.Section).Name;
			ErrorDescriptionString.Object      = ?(CheckSSL.Object = CheckSSL.Section, Undefined, CheckSSL.Object);
			ErrorDescriptionString.PeriodEndClosingDate = Prohibition.Date;
			ErrorDescriptionString.SingleDate   = ?(ValueIsFilled(Prohibition.Section), False, True);
			If Prohibition.Section = Prohibition.Object Then
				ErrorDescriptionString.ForAllObjects = True;
			Else
				ErrorDescriptionString.ForAllObjects = False;
			EndIf;
			ErrorDescriptionString.Recipient  = Prohibition.Recipient;
			ErrorDescriptionString.Details = Text;
		EndIf;
	EndDo;
	
	If Not StructuralDetails Then
		ErrorDescription = TrimR(ErrorText);
	EndIf;
	
	Return ErrorDescription;
	
EndFunction

// For the PeriodEndMessage function.
Function DataPresentation(Data)
	
	If TypeOf(Data) = Type("String") Then
		Return TrimAll(Data);
	EndIf;
	
	If TypeOf(Data) = Type("Structure") Then
		IsRegister = True;
		If TypeOf(Data.Register) = Type("String") Then
			MetadataObject = Metadata.FindByFullName(Data.Register);
		Else
			MetadataObject = Metadata.FindByType(TypeOf(Data.Register));
		EndIf;
	Else
		MetadataObject = Metadata.FindByType(TypeOf(Data));
		IsRegister = Common.IsRegister(MetadataObject);
	EndIf;
	
	If MetadataObject = Undefined Then
		Return "";
	EndIf;
	
	If IsRegister Then
		DataPresentation = MetadataObject.Presentation();
		
		FieldsCount = 0;
		For each FilterItem In Data.Filter Do
			If FilterItem.Use Then
				FieldsCount = FieldsCount + 1;
			EndIf;
		EndDo;
		
		If FieldsCount = 1 Then
			DataPresentation = DataPresentation
				+ " " + NStr("ru = 'с полем'; en = 'with field'; pl = 'z polem';es_ES = 'con el campo';es_CO = 'con el campo';tr = 'alan ile';it = 'con campo';de = 'mit Feld'")  + " " + String(Data.Filter);
			
		ElsIf FieldsCount > 1 Then
			DataPresentation = DataPresentation
				+ " " + NStr("ru = 'с полями'; en = 'with fields'; pl = 'z polami';es_ES = 'con los campos';es_CO = 'con los campos';tr = 'alanlar ile';it = 'con campi';de = 'mit Feldern'") + " " + String(Data.Filter);
		EndIf;
	ElsIf Metadata.Documents.Contains(MetadataObject) Then
		DataPresentation = String(Data);
	Else
		DataPresentation = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)", String(Data), MetadataObject.Presentation());
	EndIf;
		
	Return DataPresentation;
	
EndFunction

#EndRegion
