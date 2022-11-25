
#Region Public

Function GetParameterPresentationStructure(ParametersTable, ParameterName) Export

	FilterStructure = New Structure("Field", ParameterName);	
	
	ParametersRows = ParametersTable.FindRows(FilterStructure);
	
	If ParametersRows.Count() = 0 Then
		Raise NStr("en = 'An invalid parameter. It is missing in the parameters list.'; ru = 'Недопустимый параметр. Данный параметр отсутствует в списке параметров.';pl = 'Błędny parametr. Nie ma go na liście parametrów.';es_ES = 'Un parámetro no válido. Está ausente en la lista de parámetros.';es_CO = 'Un parámetro no válido. Está ausente en la lista de parámetros.';tr = 'Geçersiz parametre. Parametreler listesinde yok.';it = 'Parametro invalido. Manca nell''elenco dei parametri.';de = 'Ein ungültiger Parameter. Er ist in der Parameterliste nicht vorhanden.'");
	ElsIf ParametersRows.Count() > 1 Then
		Raise NStr("en = 'A duplicate parameter in the parameters list.'; ru = 'Повторяющийся параметр в списке параметров.';pl = 'Zduplikowany parametr na liście parametrów.';es_ES = 'Un parámetro duplicado en la lista de parámetros.';es_CO = 'Un parámetro duplicado en la lista de parámetros.';tr = 'Parametreler listesinde tekrarlayan parametre.';it = 'Parametro duplicato nell''elenco dei parametri.';de = 'Ein verdoppelter Parameter in der Parameterliste.'");		
	EndIf;
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("ParameterName"   , ParametersRows[0].Field);
	ReturnStructure.Insert("ParameterSynonym", ParametersRows[0].Synonym);
	ReturnStructure.Insert("ValueType"		 , ParametersRows[0].ValueType);
	
	Return ReturnStructure;
	
EndFunction 

Function GetAdditionalParameterType(ParameterName) Export

	Return WorkWithArbitraryParametersServerCall.GetAdditionalParameterType(ParameterName);

EndFunction

Function ValueArrayPresentationOLD(Value) Export

	Presentation = "";
	IsValueList = (TypeOf(Value) = Type("ValueList"));
	IsArray		= (TypeOf(Value) = Type("Array"));
	
	If IsValueList Or IsArray Then 
		
		FirstElem = True;
		
		For Each Element In Value Do
			
			If IsValueList And  Not Element.Check Then
				Continue;
			EndIf;
			
			If FirstElem Then
				PresentTemplate = "%1";
				FirstElem = False;
			Else
				PresentTemplate = "; %1";				
			EndIf;
			
			Presentation = Presentation + StrTemplate(PresentTemplate, ?(IsValueList, Element.Value, Element));
			
		EndDo;
		
		Return Presentation;	
	Else
		Return Value;
	EndIf; 
	
EndFunction

Function ListSelectionIsAvailable(TableRowCondition) Export

	Return TableRowCondition = DataCompositionComparisonType.InList
		Or TableRowCondition = DataCompositionComparisonType.InListByHierarchy
		Or TableRowCondition = DataCompositionComparisonType.NotInList
		Or TableRowCondition = DataCompositionComparisonType.NotInListByHierarchy;

EndFunction 

Procedure SetAvailableComparasingTypesList(CurrentData, ChoiceData, StandardProcessing) Export

	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.ValuePresentation) Then
		Value = CurrentData.ValuePresentation;
	Else
		Value = CurrentData.ValueType.AdjustValue("");
	EndIf;
	
	ArrayComparison = New ValueList;
	
	If WorkWithArbitraryParametersServerCall.IsReference(Value) Or CurrentData.ValueType.Types().Count() > 1 Then
		
		ArrayComparison.Add(DataCompositionComparisonType.Equal);
		ArrayComparison.Add(DataCompositionComparisonType.NotEqual);
		
		ArrayComparison.Add(DataCompositionComparisonType.InList);
		ArrayComparison.Add(DataCompositionComparisonType.NotInList);
		ArrayComparison.Add(DataCompositionComparisonType.InListByHierarchy);
		ArrayComparison.Add(DataCompositionComparisonType.NotInListByHierarchy);
		ArrayComparison.Add(DataCompositionComparisonType.InHierarchy);
		ArrayComparison.Add(DataCompositionComparisonType.NotInHierarchy);
		
		ArrayComparison.Add(DataCompositionComparisonType.Filled);
		ArrayComparison.Add(DataCompositionComparisonType.NotFilled);
		
	ElsIf TypeOf(Value) = Type("Boolean") Then
		
		ArrayComparison.Add(DataCompositionComparisonType.Equal);
		ArrayComparison.Add(DataCompositionComparisonType.NotEqual);
		
	ElsIf TypeOf(Value) = Type("Number") Then
		
		ArrayComparison.Add(DataCompositionComparisonType.Equal);
		ArrayComparison.Add(DataCompositionComparisonType.NotEqual);
		ArrayComparison.Add(DataCompositionComparisonType.Greater);
		ArrayComparison.Add(DataCompositionComparisonType.GreaterOrEqual);
		ArrayComparison.Add(DataCompositionComparisonType.Less);
		ArrayComparison.Add(DataCompositionComparisonType.LessOrEqual);
		ArrayComparison.Add(DataCompositionComparisonType.Filled);
		ArrayComparison.Add(DataCompositionComparisonType.NotFilled);
		
	ElsIf TypeOf(Value) = Type("String") Then
		
		ArrayComparison.Add(DataCompositionComparisonType.Equal);
		ArrayComparison.Add(DataCompositionComparisonType.NotEqual);
		ArrayComparison.Add(DataCompositionComparisonType.BeginsWith);
		ArrayComparison.Add(DataCompositionComparisonType.Contains);
		ArrayComparison.Add(DataCompositionComparisonType.NotContains);
		ArrayComparison.Add(DataCompositionComparisonType.Like);
		ArrayComparison.Add(DataCompositionComparisonType.NotLike);
		ArrayComparison.Add(DataCompositionComparisonType.Filled);
		ArrayComparison.Add(DataCompositionComparisonType.NotFilled);
		
	ElsIf TypeOf(Value) = Type("Date") Then
		
		ArrayComparison.Add(DataCompositionComparisonType.Equal);
		ArrayComparison.Add(DataCompositionComparisonType.NotEqual);
		ArrayComparison.Add(DataCompositionComparisonType.Greater);
		ArrayComparison.Add(DataCompositionComparisonType.GreaterOrEqual);
		ArrayComparison.Add(DataCompositionComparisonType.Less);
		ArrayComparison.Add(DataCompositionComparisonType.Filled);
		ArrayComparison.Add(DataCompositionComparisonType.NotFilled);
		
	EndIf;
	
	ChoiceData = ArrayComparison;
	StandardProcessing = False;
	
EndProcedure 

Procedure CopyRowProcessing(Object, TabSectionName, NewRow) Export

	EntriesTabSection = Object[TabSectionName];
	CurrentConnectionKey = NewRow.ConnectionKey;
	NewRow.ConnectionKey = 0;
	
	DriveClientServer.FillConnectionKey(EntriesTabSection, NewRow, "ConnectionKey");

	// Filters copying
	EntriesFiltersRowsFilter = New Structure("EntryConnectionKey", CurrentConnectionKey);
	EntriesFiltersRowsToCopy = Object.EntriesFilters.FindRows(EntriesFiltersRowsFilter);
	
	
	For Each EntryFilterRow In EntriesFiltersRowsToCopy Do
		
		CurrentFilterRowConnectionKey = EntryFilterRow.ValuesConnectionKey;
		
		NewEntryFilterRow = Object.EntriesFilters.Add();
		NewEntryFilterRow.EntryConnectionKey = NewRow.ConnectionKey;
		
		FillPropertyValues(NewEntryFilterRow, EntryFilterRow, , "ValuesConnectionKey, EntryConnectionKey");
		
		DriveClientServer.FillConnectionKey(Object.EntriesFilters, NewEntryFilterRow, "ValuesConnectionKey");  
		
		// Values copying
		FilterValuesRowsFilter = New Structure("ConnectionKey, MetadataName", EntryFilterRow.ValuesConnectionKey, "EntriesFilters");
		FilterValuesRowsToCopy = Object.ParametersValues.FindRows(FilterValuesRowsFilter);
		
		For Each ValueRow In FilterValuesRowsToCopy Do
			
			NewValueRow = Object.ParametersValues.Add();
			FillPropertyValues(NewValueRow, ValueRow, , "ConnectionKey");
			
			NewValueRow.ConnectionKey = NewEntryFilterRow.ValuesConnectionKey;
			
		EndDo;
	EndDo;
	
	// Synonyms copying
	SynonymsRowsFilter = New Structure("ConnectionKey", CurrentConnectionKey);
	SynonymsRowsToCopy = Object.ElementsSynonyms.FindRows(SynonymsRowsFilter);
	
	For Each SynonymRow In SynonymsRowsToCopy Do
		
		NewSynonymRow = Object.ElementsSynonyms.Add();
		FillPropertyValues(NewSynonymRow, SynonymRow, , "ConnectionKey");
		
		NewSynonymRow.ConnectionKey = NewRow.ConnectionKey;
		
	EndDo;
	
	// Default accounts copying
	DefaultAccountsFilter = New Structure("EntryConnectionKey", CurrentConnectionKey);
	DefaultAccountsRowsToCopy = Object.EntriesDefaultAccounts.FindRows(DefaultAccountsFilter);
	
	For Each DefaultAccountsRow In DefaultAccountsRowsToCopy Do
		
		NewDefaultAccountsRow = Object.EntriesDefaultAccounts.Add();
		FillPropertyValues(NewDefaultAccountsRow, DefaultAccountsRow, , "EntryConnectionKey");
		
		NewDefaultAccountsRow.EntryConnectionKey = NewRow.ConnectionKey;
		
	EndDo;
	
EndProcedure

#Region ObjectSynonymsTabularSection 

Function GetAttributeSynonym(SynonymTS, FieldName, ConnectionKey) Export

	Filter = New Structure("MetadataName, ConnectionKey", FieldName, ConnectionKey);
	
	FilteredRows 	= SynonymTS.FindRows(Filter);	
	RowsCount		= FilteredRows.Count();
		
	If RowsCount = 0 Then
		Return "";
	Else 		
		SynonymRow = FilteredRows[0];
		Return SynonymRow.Synonym;		
	EndIf;
	
EndFunction

Function GetValuesByConnectionKey(TabularSection, TabSectionName, ConnectionKey) Export 

	Filter = New Structure("MetadataName, ConnectionKey", TabSectionName, ConnectionKey);
	
	FilteredRows = TabularSection.FindRows(Filter);	
	
	Values = New Array;
	
	For Each TableRow In FilteredRows Do		
		Values.Add(TableRow.Value); 
	EndDo;	

	Return Values;
	
EndFunction 

Procedure DeleteRowsByConnectionKey(TabularSection, FieldName, ConnectionKey) Export
		
	Filter = New Structure("MetadataName, ConnectionKey", FieldName, ConnectionKey);
	
	FilteredRows = TabularSection.FindRows(Filter);	
	
	For Each TableRow In FilteredRows Do		
		TabularSection.Delete(TableRow);		
	EndDo;

EndProcedure

Procedure DeleteAllRowsByConnectionKey(TabularSection, ConnectionKey, KeyAttributeName) Export
		
	Filter = New Structure(KeyAttributeName, ConnectionKey);
	
	FilteredRows = TabularSection.FindRows(Filter);	
	
	For Each TableRow In FilteredRows Do		
		TabularSection.Delete(TableRow);		
	EndDo;

EndProcedure

Procedure ClearFiltersAndValuesByConnectionKey(CurrentObject, ConnectionKey) Export
	
	TabSectionFilters =	CurrentObject.EntriesFilters;
	TabSectionValues  =	CurrentObject.ParametersValues;

	FilterRowsFilter = New Structure("EntryConnectionKey", ConnectionKey);	
	FilteredRows = CurrentObject.EntriesFilters.FindRows(FilterRowsFilter);	
	
	For Each TableRow In FilteredRows Do		
		
		TabSectionFilters.Delete(TableRow);
		
		ValuesRowsFilters = New Structure("ConnectionKey, MetadataName", TableRow.ValuesConnectionKey, "EntriesFilters");
		ValuesRows = TabSectionValues.FindRows(ValuesRowsFilters);
		
		For Each ValueRow In ValuesRows Do
			TabSectionValues.Delete(ValueRow);
		EndDo;
		
	EndDo;

EndProcedure

Procedure ClearEntriesDefaultAccountsByConnectionKey(CurrentObject, ConnectionKey) Export
	
	FilterRowsFilter = New Structure("EntryConnectionKey", ConnectionKey);
	FilteredRows = CurrentObject.EntriesDefaultAccounts.FindRows(FilterRowsFilter);
	
	For Each TableRow In FilteredRows Do
		
		CurrentObject.EntriesDefaultAccounts.Delete(TableRow);
		
	EndDo;
	
EndProcedure

Procedure UpdateObjectSynonymsTS(CurrentObject, FieldName, ConnectionKey, Synonym, DrCr = Undefined) Export 

	SynonymTS = CurrentObject.ElementsSynonyms;
	
	Filter = New Structure("MetadataName, ConnectionKey", FieldName, ConnectionKey);
	
	FilteredRows	= SynonymTS.FindRows(Filter);
	RowsCount		= FilteredRows.Count();
	
	If RowsCount = 0 Then
		
		NewSynonymRow = SynonymTS.Add();
		
		FillPropertyValues(NewSynonymRow, Filter);
		NewSynonymRow.Synonym	= Synonym;
		NewSynonymRow.DrCr		= DrCr;
		
	ElsIf RowsCount = 1 Then
		
		SynonymRow = FilteredRows[0];
		
		FillPropertyValues(SynonymRow, Filter);
		SynonymRow.Synonym	= Synonym;
		SynonymRow.DrCr		= DrCr;
		
	Else
		
		While RowsCount > 1 Do
			SynonymTS.Delete(FilteredRows[RowsCount - 1]);
			RowsCount = RowsCount - 1;
		EndDo;
		
		SynonymRow = FilteredRows[0];
		
		FillPropertyValues(SynonymRow, Filter);
		SynonymRow.Synonym	= Synonym;
		SynonymRow.DrCr		= DrCr;
	
	EndIf;
	
EndProcedure

#EndRegion

#Region ListChoice

Function FilterSelectionParameters(CurrentData, ParametersValuesTable, TabSectionName = "EntriesFilters") Export

	Value = GetValuesByConnectionKey(ParametersValuesTable, TabSectionName, CurrentData.ValuesConnectionKey);               
	
	Result = New Structure();
	
	Result.Insert("Presentation"						, NStr("en = 'Select values'; ru = 'Выберите значения';pl = 'Wybierz wartości';es_ES = 'Seleccionar los valores';es_CO = 'Seleccionar los valores';tr = 'Değer seç';it = 'Selezionare valori';de = 'Werte auswählen'"));
	Result.Insert("ValuesForSelection"					, ReportsClientServer.ValuesByList(Value));
	Result.Insert("ValuesForSelectionFilled"			, True);
	Result.Insert("QuickChoice"							, False);
	Result.Insert("RestrictSelectionBySpecifiedValues"	, False);
	Result.Insert("TypeDescription"						, CurrentData.ValueType);
	
	Condition  = DataCompositionComparisonType.InList;
	
	ChoiceOfGroupsAndItems = False;
	
	// Standard parameters of the form.
	Result.Insert("CloseOnChoice"			, True);
	Result.Insert("CloseOnOwnerClose"		, True);
	Result.Insert("Filter"					, New Structure);
	Result.Insert("ChoiceFoldersAndItems"	, ChoiceOfGroupsAndItems);
	Result.Insert("MultipleChoice"			, False);
	Result.Insert("ChoiceMode"				, True);
	Result.Insert("WindowOpeningMode"		, FormWindowOpeningMode.LockOwnerWindow);
	Result.Insert("EnableStartDrag"			, False);
		
	Result.Insert("Value"			, CurrentData.ValueType.AdjustValue(""));
	Result.Insert("Marked"			, ReportsClientServer.ValuesByList(Value));
	Result.Insert("ChoiceParameters", New Array);
	Result.Insert("UniqueKey"		, New UUID);
	
	Return Result;
	
EndFunction

Function ValueArrayPresentation(Value) Export
	
	Presentation = "";
	IsValueList = (TypeOf(Value) = Type("ValueList"));
	IsArray		= (TypeOf(Value) = Type("Array"));
	
	If IsValueList Or IsArray Then 
		
		FirstElem = True;
		
		For Each Element In Value Do
			
			If IsValueList And  Not Element.Check Then
				Continue;
			EndIf;
			
			If FirstElem Then
				PresentTemplate = "%1";
				FirstElem = False;
			Else
				PresentTemplate = "; %1";				
			EndIf;
			
			Presentation = Presentation + StrTemplate(PresentTemplate, ?(IsValueList, Element.Value, Element));
			
		EndDo;
		
		Return Presentation;	
	Else
		Return Value;
	EndIf; 


EndFunction 

Procedure SaveValueListByConnectionKey(TabularSection, ValueList, ParentTabSectionName, ConnectionKey, KeyAttributeName, ChangeEmptyValues = False) Export

	DeleteRowsByConnectionKey(TabularSection, ParentTabSectionName, ConnectionKey);
	
	For Each ValueListElement In ValueList Do
		
		If Not ValueListElement.Check Then
			Continue;	
		EndIf;
		
		NewValue = TabularSection.Add();
		NewValue.MetadataName		= ParentTabSectionName;
		NewValue[KeyAttributeName]	= ConnectionKey;
		
		If ChangeEmptyValues And Not ValueIsFilled(ValueListElement.Value) Then
			NewValue.Value = Undefined;
		Else
			NewValue.Value = ValueListElement.Value;
		EndIf;
		
	EndDo;

EndProcedure

Procedure ProcessMultipleToSingleValue(TabularSection, ParentTabSectionName, CurrentRow) Export

	Filter = New Structure("MetadataName, ConnectionKey", ParentTabSectionName, CurrentRow.ValuesConnectionKey);
	
	FilteredRows 	= TabularSection.FindRows(Filter);	
	RowsCount		= FilteredRows.Count();

	If RowsCount = 0 Then
		Return;
	EndIf;
	
	While RowsCount > 1 Do
		TabularSection.Delete(FilteredRows[RowsCount - 1]);
		RowsCount = RowsCount - 1;
	EndDo;
	
	CurrentRow.ValuePresentation = FilteredRows[0].Value;
	
EndProcedure

#EndRegion

#Region AccountingSourceDocumentsInput

Procedure InputAccountingSourceDocuments(AdditionalParameters) Export 
	
	If AdditionalParameters = Undefined
		Or Not AdditionalParameters.Property("TypesOfAccounting")
		Or AdditionalParameters.TypesOfAccounting.Count() = 0 Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("InputAccountingSourceDocumentsEnd",
		WorkWithArbitraryParametersClient,
		AdditionalParameters);
	
	QueryMessage = NStr("en = 'The list of Accounting source documents is required for posting the company documents. 
		|Do you want to specify it now?'; 
		|ru = 'Для проведения документов организации необходимо указать список первичных бухгалтерских документов. 
		|Указать его сейчас?';
		|pl = 'Lista źródłowych dokumentów księgowych jest wymagana do zatwierdzenia dokumentów firmy. 
		|Czy chcesz określić ją teraz?';
		|es_ES = 'La lista de documentos de fuente de la contabilidad es necesaria para contabilizar los documentos de la empresa. 
		|¿Quiere especificarla ahora?';
		|es_CO = 'La lista de documentos de fuente de la contabilidad es necesaria para contabilizar los documentos de la empresa. 
		|¿Quiere especificarla ahora?';
		|tr = 'İş yeri belgelerinin kaydedilmesi için Muhasebe kaynak belgeleri listesi gerekli. 
		|Şimdi belirtmek ister misiniz?';
		|it = 'L''elenco dei documenti fonte di contabilità è richiesto per la pubblicazione dei documenti aziendali.
		|Indicarlo adesso?';
		|de = 'Die Liste von Buchhaltungsquelldokumente sind für Buchung der Firmendokumenten erforderlich. 
		|Möchten Sie diese jetzt angeben?'");
	
	ShowQueryBox(Notification, QueryMessage, QuestionDialogMode.YesNo);
	
EndProcedure

Procedure InputAccountingSourceDocumentsEnd(QueryResult, AdditionalParameters) Export

	If QueryResult = DialogReturnCode.Yes Then
		
		FormParameters = New Structure;
		FormParameters.Insert("NewRecord"		, True);
		FormParameters.Insert("Period"			, AdditionalParameters.Period);
		FormParameters.Insert("Company"			, AdditionalParameters.Company);
		FormParameters.Insert("TypeOfAccounting", AdditionalParameters.TypesOfAccounting[0]);
		
		OpenForm("InformationRegister.AccountingSourceDocuments.Form.InputData",
			FormParameters,
			ThisObject,
			,
			,
			,
			New NotifyDescription("AfterCloseAccountingSourceDocuments", ThisObject, AdditionalParameters),
			FormWindowOpeningMode.LockOwnerWindow);
				
	Else
			
		AdditionalParameters.TypesOfAccounting.Delete(0);
		If AdditionalParameters.TypesOfAccounting.Count() > 0 Then
			InputAccountingSourceDocuments(AdditionalParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure AfterCloseAccountingSourceDocuments(Result,AdditionalParameters) Export
	
	If AdditionalParameters.TypesOfAccounting.Count() > 0 Then
		AdditionalParameters.TypesOfAccounting.Delete(0);
	EndIf;
	
	If AdditionalParameters.TypesOfAccounting.Count() > 0 Then
		InputAccountingSourceDocuments(AdditionalParameters);
	Else
		Notify("InputAccountingSourceDocuments", AdditionalParameters);
	EndIf;
	
EndProcedure

#EndRegion

Function CheckTabSectionRowFilling(TabSectionRow, AttributesToCheck) Export
	
	AttributesArray = StrSplit(AttributesToCheck, ",", False);
	
	For Each Attribute In AttributesArray Do
		
		If ValueIsFilled(TabSectionRow[TrimAll(Attribute)]) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;		

EndFunction 

Procedure ClearTabSectionRow(TabSectionRow, Val AttributesToCheck) Export
	
	If TypeOf(AttributesToCheck) = Type("String") Then
		AttributesArray = StrSplit(AttributesToCheck, ",", False);
	Else
		
		AttributesArray = New Array;
		
		For Each Item In AttributesToCheck Do
			
			If TypeOf(Item) = Type("String") And Item <> "DataSource" Then
				AttributesArray.Add(Item);
			ElsIf TypeOf(Item) = Type("Structure") And Item.Field <> "DataSource" Then
				AttributesArray.Add(Item);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For Each Attribute In AttributesArray Do
		
		If TypeOf(Attribute) = Type("Structure") Then
			
			If Attribute.DeleteRow Then
				
				Attribute.TabSection.Delete(Attribute.Row);
				
			Else
				
				AttributeField = TrimAll(Attribute.Field);
				Attribute.Row[AttributeField] = Undefined;
				If AttributeField = "ParameterName" Then
					Attribute.Row["ParameterSynonym"] = Undefined;
				Else
					Attribute.Row[StrTemplate("%1Synonym", AttributeField)] = Undefined;
				EndIf;
				
			EndIf;
			
		Else
			
			AttributeField = TrimAll(Attribute);
			TabSectionRow[AttributeField]							= Undefined;
			TabSectionRow[StrTemplate("%1Synonym", AttributeField)] = Undefined;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillFormulaParameters(CurrentRow, FieldName, AttributeSynonym, ChoiceFormParameters) Export

	If Not ValueIsFilled(CurrentRow[FieldName]) Or CurrentRow[FieldName] <> AttributeSynonym Then 
		// this is regular attribute selection
		ChoiceFormParameters.Insert("FormulaMode"  	   , False);
		ChoiceFormParameters.Insert("SwitchFormulaMode", 0);	
	Else
		// this is formula
		ChoiceFormParameters.Insert("FormulaMode"  	   , True);
		ChoiceFormParameters.Insert("SwitchFormulaMode", 1);			
	EndIf;
	ChoiceFormParameters.Insert("ModeSwitchAllowed", True);

EndProcedure

Procedure ClearObjectEntries(ComplexTypeOfEntries, Object) Export

	EntriesTabName = ?(ComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	Object[EntriesTabName].Clear();
	Object.EntriesFilters.Clear();
	
	ParamFilter = New Structure("MetadataName", "EntriesFilters");
	ParamValuesToDelete = Object.ParametersValues.FindRows(ParamFilter);
	
	For Each ValueToDelete In ParamValuesToDelete Do
		Object.ParametersValues.Delete(ValueToDelete);		
	EndDo;
		
EndProcedure

Function GetExcludedFields() Export
	ExcludedFieldsArray = New Array;
	
	ExcludedFieldsArray.Add("PARENT");
	
	Return ExcludedFieldsArray;
	
EndFunction

Function FieldsArrayFillCheckProcessing(CheckingObject, FieldsArray, ClearMessages = True) Export
	
	EmptyFields = New Array;
	
	For Each Field In FieldsArray Do
		
		If Not ValueIsFilled(CheckingObject[Field.Name]) Then
			EmptyFields.Add(Field);
		EndIf;
		
	EndDo;
	
	If ClearMessages Then
		ClearMessages();
	EndIf;
	
	TemplateText = NStr("en = '%1 is required.'; ru = 'Укажите %1.';pl = '%1 jest wymagane.';es_ES = 'Se requiere ""%1"".';es_CO = 'Se requiere ""%1"".';tr = '%1 gerekli.';it = '%1 richiesto.';de = '""%1"" ist benötigt.'");
	For Each Field In EmptyFields Do
		
		If Field.Property("RowCount") Then
			FieldPath = StrTemplate("%1[%2].%3", Field.ObjectName, Field.RowCount, Field.Name);
		Else
			FieldPath = StrTemplate("%1.%2", Field.ObjectName, Field.Name);
		EndIf;
		
		CommonClientServer.MessageToUser(StrTemplate(TemplateText, Field.Synonym), , FieldPath);
		
	EndDo;
	
	Return EmptyFields.Count() = 0;
	
EndFunction

Function CheckAccountsValidation(CheckingObject, CheckingAttribute = "") Export
	
	ErrorFields = New Array;
	
	WorkWithArbitraryParametersServerCall.CheckDefaultAccountValidation(CheckingObject, ErrorFields);
	
	If CheckingAttribute = "ChartOfAccounts" Then
		WorkWithArbitraryParametersServerCall.CheckAccountsValueChartOfAccountsValidation(CheckingObject, ErrorFields);
	Else
		WorkWithArbitraryParametersServerCall.CheckAccountsValueValidation(CheckingObject, ErrorFields);
	EndIf;
	
	ClearMessages();
	
	For Each Field In ErrorFields Do
		
		If Field.Property("RowCount") Then
			FieldPath = StrTemplate("%1[%2].%3", Field.ObjectName, Field.RowCount, Field.Name);
		Else
			FieldPath = StrTemplate("%1.%2", Field.ObjectName, Field.Name);
		EndIf;
		
		CommonClientServer.MessageToUser(Field.Text, , FieldPath);
		
	EndDo;
	
	Return ErrorFields.Count() = 0;
	
EndFunction

Function CheckAccountsValueValidation(CheckingObject, StartDate, EndDate) Export
	
	ErrorFields = New Array;
	
	WorkWithArbitraryParametersServerCall.CheckAccountsValueValidation(CheckingObject, ErrorFields);
	
	ClearMessages();
	
	For Each Field In ErrorFields Do
		
		If Field.Property("RowCount") Then
			FieldPath = StrTemplate("%1[%2].%3", Field.ObjectName, Field.RowCount, Field.Name);
		Else
			FieldPath = StrTemplate("%1.%2", Field.ObjectName, Field.Name);
		EndIf;
		
		CommonClientServer.MessageToUser(Field.Text, , FieldPath);
		
	EndDo;
	
	Return ErrorFields.Count() = 0;
	
EndFunction

Function CheckTemplateFieldsData(CheckingObject, CheckingData, CheckType, FieldsStructure) Export
	
	FieldsToRemoveData = New Array;
	
	If StrFind(CheckingData, ".") = 0 Then
		CheckingDataValue = CheckingData;
	Else
		
		CheckingDataArray = StrSplit(CheckingData, ".");
		CheckingDataSource = CheckingDataArray[0];
		If CheckingDataSource = "AccountingEntriesData" Then
			CheckingDataValue = CheckingDataSource;
		Else
			CheckingDataValue = CheckingDataArray[1];
		EndIf;
		
	EndIf;
	
	If CheckType = "DataSource" Then
		
		For Each Field In FieldsStructure.Row Do
			
			If TypeOf(CheckingObject[Field]) <> Type("String") Then
				Continue;
			EndIf;
			
			If StrFind(CheckingObject[Field], CheckingDataValue) Then
				FieldsToRemoveData.Add(Field);
			EndIf;
			
		EndDo;
		
	ElsIf CheckType = "DocumentType" Then
		
		For Each Row In CheckingObject.Parameters Do
			For Each Field In FieldsStructure.Parameters Do
				
				If StrFind(Row[Field], CheckingDataValue) Then
					FieldsToRemoveData.Add(New Structure ("TabName, Field, Row", "Parameters", Field, Row));
				EndIf;
				
			EndDo;
		EndDo;
		
		For Each Row In CheckingObject.Entries Do
			For Each Field In FieldsStructure.Entries Do
				
				If StrFind(Row[Field], CheckingDataValue) Then
					FieldsToRemoveData.Add(New Structure ("TabName, Field, Row", "Entries", Field, Row));
				EndIf;
				
			EndDo;
		EndDo;
		
		For Each Row In CheckingObject.EntriesSimple Do
			For Each Field In FieldsStructure.EntriesSimple Do
				
				If StrFind(Row[Field], CheckingDataValue) Then
					FieldsToRemoveData.Add(New Structure ("TabName, Field, Row", "EntriesSimple", Field, Row));
				EndIf;
				
			EndDo;
		EndDo;
		
		For Each Row In CheckingObject.EntriesFilters Do
			For Each Field In FieldsStructure.EntriesFilters Do
				
				If StrFind(Row[Field], CheckingDataValue) Then
					FieldsToRemoveData.Add(New Structure ("TabName, Field, Row", "EntriesFilters", Field, Row));
				EndIf;
				
			EndDo;
		EndDo;
		
		For Each Row In CheckingObject.EntriesDefaultAccounts Do
			For Each Field In FieldsStructure.EntriesDefaultAccounts Do
				
				If StrFind(Row[Field], CheckingDataValue) Then
					FieldsToRemoveData.Add(New Structure ("TabName, Field, Row", "EntriesDefaultAccounts", Field, Row));
				EndIf;
				
			EndDo;
		EndDo;
		
	EndIf;
	
	Return FieldsToRemoveData;
	
EndFunction

#EndRegion