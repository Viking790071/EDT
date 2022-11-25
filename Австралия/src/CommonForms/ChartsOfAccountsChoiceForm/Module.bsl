#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	Parameters.Property("ChartOfAccounts"		, ChartOfAccounts);
	Parameters.Property("CurrentValue"			, Account);
	Parameters.Property("FillAccounts"			, FillAccounts);
	Parameters.Property("AttributeName"			, AttributeName);
	Parameters.Property("Company"				, Company);
	Parameters.Property("TypeOfAccounting"		, TypeOfAccounting);
	Parameters.Property("DataSource"			, DataSource);
	Parameters.Property("DocumentType"			, DocumentType);
	Parameters.Property("DefaultAccountType"	, DefaultAccountType);
	Parameters.Property("AccountReferenceName"	, AccountReferenceName);
	Parameters.Property("BeginOfPeriod"			, BeginOfPeriod);
	Parameters.Property("EndOfPeriod"			, EndOfPeriod);
	Parameters.Property("NameAdding"			, NameAdding);
	
	Parameters.Property("ItemName"				, ItemName);
	Parameters.Property("LineNumber"			, LineNumber);
	Parameters.Property("FieldName"				, FieldName);
	
	Parameters.Property("CurrentAnalyticalDimensionsSetValue", AnalyticalDimensionsSet);
	
	If Parameters.Property("FiltersArray") Then
		
		For Each FilterRow In Parameters.FiltersArray Do
			NewRow = Filters.Add();
			FillPropertyValues(NewRow, FilterRow);
		EndDo;
		
	EndIf;
	
	If ValueIsFilled(DefaultAccountType) Then
		ChoiceType = 1;
	EndIf;
	
	SetAccountReferenceNameList();

	AccountSynonym = Account;
	
	ChartOfAccountsUseAnalyticalDimensions = ChartOfAccounts.UseAnalyticalDimensions;
	
	If Parameters.Property("AttributeName") Then
		
		If ChartOfAccountsUseAnalyticalDimensions Then
			Title = NStr("en = 'Select account and analytical dimensions'; ru = 'Выберите счет и аналитические измерения';pl = 'Wybierz konto i wymiary analityczne';es_ES = 'Seleccione la cuenta y las dimensiones analíticas';es_CO = 'Seleccione la cuenta y las dimensiones analíticas';tr = 'Hesap ve analitik boyut seç';it = 'Selezionare conto e dimensioni analitiche';de = 'Konto und analytische Messungen auswählen'");
		Else
			Title = NStr("en = 'Select account'; ru = 'Выберите счет';pl = 'Wybierz konto';es_ES = 'Seleccionar la cuenta';es_CO = 'Seleccionar la cuenta';tr = 'Hesap seç';it = 'Seleziona conto';de = 'Konto auswählen'");
		EndIf;
		
		AttributeID = Parameters.AttributeID;
		
	EndIf;
	
	For Each Item In Parameters.CurrentAnalyticalDimensions Do
		
		NewRow = AnalyticalDimensions.Add();
		FillPropertyValues(NewRow, Item);
		NewRow.AnalyticalDimensionTypeDescription = NewRow.AnalyticalDimensionType.ValueType;
		
	EndDo;
	
	CurrentAnalyticalDimensions.Load(AnalyticalDimensions.Unload());
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
	ChoiceTypeTemp = Not ChoiceType = 1;
	ThisObject.AttachIdleHandler("ChangeVisible", 0.01, True);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	IsMaster = AccountingApprovalServerCall.GetMasterByChartOfAccounts(ChartOfAccounts);
	
	ChoiceFormParameters = New Structure;
	
	If ChoiceType = 0 Then
		
		FixedSettings = New DataCompositionSettings;
		
		FilterOrGroup = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterOrGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItem = FilterOrGroup.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("EndDate");
		FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
		FilterItem.RightValue = BeginOfPeriod;
		FilterItem.Use = True;
		
		FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
		FilterItem = FilterOrGroup.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("EndDate");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = Date(1,1,1);
		FilterItem.Use = True;
		
		FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		
		If ValueIsFilled(Company) Then
		
			FilterItem = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Companies.Company");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = Company;
			FilterItem.Use = True;
			
			FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
			
		EndIf;
		
		ChoiceFormParameters.Insert("FixedSettings"		, FixedSettings);
		ChoiceFormParameters.Insert("CurrentValue"		, Account);
		ChoiceFormParameters.Insert("ChartOfAccounts"	, ChartOfAccounts);
		
	EndIf;
		
	AddParameters = New Structure;
	AddParameters.Insert("Field"	, Account);
	AddParameters.Insert("IsMaster"	, IsMaster);
	
	FormID = StrTemplate("ChartOfAccounts.%1.ChoiceForm", ?(IsMaster, "MasterChartOfAccounts", "PrimaryChartOfAccounts"));
	
	OpenForm(FormID,
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AccountChoiceEnding", ThisObject, AddParameters),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AccountClearing(Item, StandardProcessing)
	
	AccountSynonym = "";
	
	AnalyticalDimensionsSet = Undefined;
	
	AnalyticalDimensions.Clear();
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure DefaultAccountTypeOnChange(Item)

	DefaultAccountTypeOnChangeAtServer();
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure DefaultAccountTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentRow"		, DefaultAccountType);
	FormParameters.Insert("Company"			, Company);
	FormParameters.Insert("TypeOfAccounting", TypeOfAccounting);
	FormParameters.Insert("ChartOfAccounts"	, ChartOfAccounts);
		
	OpenForm("Catalog.DefaultAccountsTypes.ChoiceForm",
		FormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("DefaultAccountTypeStartChoiceEnd", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ChoiceTypeOnChange(Item)
	
	If ChoiceType = 0 Then
		DefaultAccountType		= Undefined;
		AccountReferenceName	= "";
		Filters.Clear();
		
	Else
		Account			= Undefined;
		AccountSynonym	= "";
	EndIf;
	
	AnalyticalDimensionsSet = Undefined;
	AnalyticalDimensions.Clear();
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEntries

&AtClient
Procedure FiltersValueSynonymStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Filters.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"			, DataSource);
	ChoiceFormParameters.Insert("DocumentType"			, DocumentType);
	ChoiceFormParameters.Insert("FillByTypeDescription"	, True);
	ChoiceFormParameters.Insert("AttributeName"			, "DefaultAccountFilter");
	ChoiceFormParameters.Insert("AttributeNameType"		, GetSynonymByType(CurrentData.TypeDescription, CurrentData.FilterSynonym));
	ChoiceFormParameters.Insert("AttributeID"			, "DefaultAccountFilter");
	ChoiceFormParameters.Insert("CurrentValue"			, CurrentData.Value);
	ChoiceFormParameters.Insert("TypeDescription"		, CurrentData.TypeDescription);
	ChoiceFormParameters.Insert("Company"				, Company);
	ChoiceFormParameters.Insert("ExcludedFields"		, WorkWithArbitraryParametersClient.GetExcludedFields());
	ChoiceFormParameters.Insert("DrCr"					, CurrentData.DrCr);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AttributesChoiceEnding", ThisObject, New Structure("Filter", True)),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServerNoContext
Function GetSynonymByType(TypeDescription, CurrentSynonym)
	
	Result = Lower(CurrentSynonym);
	
	Types = TypeDescription.Types();
	
	If Types.Count() = 1 Then
		MetadataObject = Metadata.FindByType(Types[0]);
		
		If MetadataObject <> Undefined And Not Metadata.Enums.Contains(MetadataObject) Then
			Result = MetadataObject.ObjectPresentation;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure AnalyticalDimensionsAnalyticalDimensionValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.AnalyticalDimensions.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"			, DataSource);
	ChoiceFormParameters.Insert("ModeSwitchAllowed"		, True);
	ChoiceFormParameters.Insert("ValueModeSwitchAllowed", True);
	ChoiceFormParameters.Insert("ValueMode"				, TypeOf(CurrentData.AnalyticalDimensionValue) <> Type("String"));
	ChoiceFormParameters.Insert("SwitchFormulaMode"		, ?(ChoiceFormParameters.ValueMode, 2, 0));
	ChoiceFormParameters.Insert("DocumentType"			, DocumentType);
	ChoiceFormParameters.Insert("FillByTypeDescription"	, True);
	ChoiceFormParameters.Insert("AttributeName"			, "AnalyticalDimensionValue");
	ChoiceFormParameters.Insert("CurrentValue"			, CurrentData.AnalyticalDimensionValue);
	ChoiceFormParameters.Insert("AttributeNameType"		, String(CurrentData.AnalyticalDimensionType));
	ChoiceFormParameters.Insert("AttributeID"			, "AnalyticalDimensionValue");
	ChoiceFormParameters.Insert("TypeDescription"		, CurrentData.AnalyticalDimensionTypeDescription);
	ChoiceFormParameters.Insert("ExcludedFields"		, WorkWithArbitraryParametersClient.GetExcludedFields());
	ChoiceFormParameters.Insert("DrCr"					, CurrentData.DrCr);
	
	AdditionalParameters = New Structure("AnalyticalDimension", True);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AttributesChoiceEnding", ThisObject, AdditionalParameters),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAnalyticalDimensions

&AtClient
Procedure AnalyticalDimensionsSetOnChange(Item)
	
	GetEntriesDimensionsAtServer(AnalyticalDimensionsSet);
	FormManagement();
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionsAnalyticalDimensionValueSynonymOnChange(Item)
	
	CurrentData = Items.AnalyticalDimensions.CurrentData;
	
	If Not ValueIsFilled(CurrentData.AnalyticalDimensionValueSynonym) Then
		CurrentData.AnalyticalDimensionValue = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionsAnalyticalDimensionValueSynonymOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, Items.AnalyticalDimensions.CurrentData.AnalyticalDimensionValue);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Fill(Command)
	
	FieldsArray = New Array;
	FieldsArray.Add(New Structure("Name, Synonym, ObjectName", "DocumentType", NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"), "Object"));
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(ThisObject, FieldsArray) Then
		Return;
	EndIf;
	
	FillAtServer();
	
EndProcedure

&AtClient
Procedure Confirm(Command)
	
	ResultStructure = New Structure("Field, Synonym, DrCr, DefaultAccountType, AccountReferenceName, AnalyticalDimensions");
	
	AnalyticalDimensionsArray = New Array;
	For Each Row In AnalyticalDimensions Do
		
		RowStructure = New Structure("AnalyticalDimensionType, DrCr, AnalyticalDimensionValue, AnalyticalDimensionValueSynonym");
		FillPropertyValues(RowStructure, Row);
		
		AnalyticalDimensionsArray.Add(RowStructure);
		
	EndDo;
	
	ResultStructureAnalyticalDimensions = New Structure;
	ResultStructureAnalyticalDimensions.Insert("Field"					, AnalyticalDimensionsSet);
	ResultStructureAnalyticalDimensions.Insert("AnalyticalDimensions"	, AnalyticalDimensionsArray);
	ResultStructureAnalyticalDimensions.Insert("NameAdding"				, NameAdding);
	ResultStructureAnalyticalDimensions.Insert("Synonym"				, FieldSynonym);
	ResultStructureAnalyticalDimensions.Insert("DrCr"					, Undefined);
	
	ResultStructure.Insert("AnalyticalDimensions", ResultStructureAnalyticalDimensions);
	
	If ChoiceType = 1 And Not CheckFieldsFilling() Then
		
		ResultStructure.Insert("DefaultAccount", True);
		
		ResultStructure.Synonym					= StrTemplate("%1 - %2", DefaultAccountType, AccountReferenceName);
		ResultStructure.DefaultAccountType		= DefaultAccountType;
		ResultStructure.AccountReferenceName	= AccountReferenceName;
		
		FiltersArray = New Array;
		
		For Each Row In Filters Do
			
			RowStructure = New Structure("LineNumber, FilterName, FilterSynonym, Value, ValueSynonym, TypeDescription, DrCr");
			FillPropertyValues(RowStructure, Row);
			
			FiltersArray.Add(RowStructure);
		EndDo;
		
		ResultStructure.Insert("FiltersArray", FiltersArray);
		
		NotifyChoice(ResultStructure);
		
	ElsIf ChoiceType = 0 Then
		
		ResultStructure.Field	= Account;
		ResultStructure.Synonym = AccountSynonym;
		
		NotifyChoice(ResultStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillFilters(Command)
	
	FieldsArray = New Array;
	FieldsArray.Add(New Structure("Name, Synonym, ObjectName", "DocumentType", NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"), "Object"));
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(ThisObject, FieldsArray) Then
		Return;
	EndIf;
	
	FillDefaultParametersInTable();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetTooltip(AttributeID, ChartOfAccountsUseAnalyticalDimensions, ChoiseType)
	Return MessagesToUserClientServer.GetTooltip(AttributeID, ChartOfAccountsUseAnalyticalDimensions, ChoiseType);
EndFunction

&AtClient
Procedure FormManagement()
	
	Default = ChoiceType = 1;
	
	Items.Account.Visible = Not Default;
	
	Items.TypeOfAccounting.Visible 		= Default;
	Items.DefaultAccountType.Visible 	= Default;
	Items.AccountReferenceName.Visible 	= Default;
	
	Items.Filters.Visible = Default;
	
	Items.GroupAnalyticalDimensions.Visible	 = ChartOfAccountsUseAnalyticalDimensions;
	Items.AnalyticalDimensionsSet.ReadOnly	 = Not Default;
	
	Items.DecorationFormTooltip.Title = GetTooltip(AttributeID, ChartOfAccountsUseAnalyticalDimensions, ChoiceType);
	
	Items.AnalyticalDimensionsFill.Enabled = ValueIsFilled(AnalyticalDimensionsSet);
	
	Items.FiltersFillFilters.Enabled = ValueIsFilled(DefaultAccountType);
	
EndProcedure

&AtClient
Function CheckFieldsFilling()

	Cancel = False;
	
	If Not ValueIsFilled(DefaultAccountType) Then
		CommonClientServer.MessageToUser(NStr("en = 'Default account type is a required field.'; ru = 'Заполните поле ""Тип счета по умолчанию"".';pl = 'Typ konta domyślnego jest polem wymaganym.';es_ES = 'El tipo de cuenta por defecto es un campo obligatorio.';es_CO = 'El tipo de cuenta por defecto es un campo obligatorio.';tr = 'Varsayılan hesap türü zorunlu bir alandır.';it = 'Tipo di conto predefinito è un campo richiesto.';de = 'Standardkontotyp ist ein Pflichtfeld.'"),
			,
			"DefaultAccountType",
			,
			Cancel);
	EndIf;

	If Not ValueIsFilled(AccountReferenceName) Then
		CommonClientServer.MessageToUser(NStr("en = 'Account reference name is a required field.'; ru = 'Заполните поле ""Ссылочное имя счета"".';pl = 'Nazwa referencyjna konta jest polem wymaganym.';es_ES = 'El nombre de referencia de la cuenta es un campo obligatorio.';es_CO = 'El nombre de referencia de la cuenta es un campo obligatorio.';tr = 'Hesap referans adı gerekli bir alandır.';it = 'Nome di riferimento conto è un campo richiesto.';de = 'Kontoreferenzname ist ein Pflichtfeld.'"),
			,
			"AccountReferenceName",
			,
			Cancel);
	EndIf;
	
	Return Cancel;
	
EndFunction

&AtClient
Procedure AttributesChoiceEnding(ClosingResult, AdditionalParameters) Export

	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	If AdditionalParameters.Property("Filter") Then
		
		CurrentData = Items.Filters.CurrentData;
		
		CurrentData.Value			= ClosingResult.Field;
		CurrentData.ValueSynonym	= ClosingResult.Synonym;
		CurrentData.DrCr			= ClosingResult.DrCr;
		
	ElsIf AdditionalParameters.Property("AnalyticalDimension") Then
		
		CurrentData = Items.AnalyticalDimensions.CurrentData;
		
		CurrentData.AnalyticalDimensionValue 		= ClosingResult.Field;
		CurrentData.AnalyticalDimensionValueSynonym	= ClosingResult.Synonym;
		CurrentData.DrCr							= ClosingResult.DrCr;
		
	Else
		Account			= ClosingResult.Field;
		AccountSynonym	= ClosingResult.Synonym;
		AccountDrCr		= ClosingResult.DrCr;
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountChoiceEnding(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult <> Undefined Then
		
		Account = ClosingResult;
		AccountSynonym = String(ClosingResult);
		
		If AdditionalParameters.IsMaster Then
			GetEntriesDimensionsAtServer(Account);
		EndIf;

		FormManagement();
	EndIf;
	
EndProcedure

&AtServer
Procedure DefaultAccountTypeOnChangeAtServer()

	SetAccountReferenceNameList();
	FillDefaultAccountTypeFilters();
	
EndProcedure

&AtServer
Procedure SetAccountReferenceNameList()
	
	AccountReferenceNameList = GetAccountReferenceNameList(DefaultAccountType);
	
	Items.AccountReferenceName.ChoiceList.LoadValues(AccountReferenceNameList);
	
EndProcedure

&AtServerNoContext
Function GetAccountReferenceNameList(DefaultAccountType)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultAccountsTypesAccounts.AccountReferenceName AS AccountReferenceName
	|FROM
	|	Catalog.DefaultAccountsTypes.Accounts AS DefaultAccountsTypesAccounts
	|WHERE
	|	DefaultAccountsTypesAccounts.Ref = &DefaultAccountType";
	
	Query.SetParameter("DefaultAccountType", DefaultAccountType);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload().UnloadColumn("AccountReferenceName");
	
EndFunction

&AtServer
Procedure FillDefaultAccountTypeFilters()
	
	CurrentFilters.Load(Filters.Unload());
	
	Filters.Clear();
	
	DefaultAccountFilters = DefaultAccountType.Filters;
	
	For Each Row In DefaultAccountFilters Do
		NewRow = Filters.Add();
		
		FillPropertyValues(NewRow, Row);
		
		FoundRows = CurrentFilters.FindRows(New Structure("FilterSynonym", NewRow.FilterSynonym));
		If FoundRows.Count() > 0 Then
			FillPropertyValues(NewRow, FoundRows[0]);
		EndIf;
		
		NewRow.TypeDescription = Row.SavedValueType.Get();
	EndDo;
	
EndProcedure

&AtServer
Procedure FillDefaultParametersInTable()
	
	WorkWithArbitraryParameters.FillDefaultParametersInTable(DataSource, DocumentType, Filters);
	
EndProcedure

&AtClient
Procedure DefaultAccountTypeStartChoiceEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		DefaultAccountType = Result;
		DefaultAccountTypeOnChangeAtServer();
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtServer
Procedure FillAtServer()
	
	TempTable = New ValueTable;
	TempTable.Columns.Add("TypeDescription");
	TempTable.Columns.Add("Value");
	TempTable.Columns.Add("ValueSynonym");
	TempTable.Columns.Add("DrCr");
	
	For Each Row In AnalyticalDimensions Do
		
		NewRow = TempTable.Add();
		NewRow.TypeDescription	 = Row.AnalyticalDimensionTypeDescription;
		NewRow.Value			 = Row.AnalyticalDimensionValue;
		NewRow.ValueSynonym		 = Row.AnalyticalDimensionValueSynonym;
		
	EndDo;
	
	WorkWithArbitraryParameters.FillDefaultParametersInTable(DataSource, DocumentType, TempTable);
	
	For Count = 0 To TempTable.Count() - 1 Do
		
		RowTemp = TempTable[Count];
		
		Row									= AnalyticalDimensions[Count];
		Row.AnalyticalDimensionValue		= RowTemp.Value;
		Row.AnalyticalDimensionValueSynonym = RowTemp.ValueSynonym;
		Row.DrCr							= RowTemp.DrCr;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeVisible()
	
	Default = ChoiceType = 1;
	
	If Default <> ChoiceTypeTemp Then
		
		Items.Account.Visible = Not ChoiceTypeTemp;
		
		Items.TypeOfAccounting.Visible 		= ChoiceTypeTemp;
		Items.DefaultAccountType.Visible 	= ChoiceTypeTemp;
		Items.AccountReferenceName.Visible 	= ChoiceTypeTemp;
		
		Items.Filters.Visible = ChoiceTypeTemp;
		
		ChoiceTypeTemp = Not ChoiceTypeTemp;
		
		ThisObject.AttachIdleHandler("ChangeVisible", 0.01, True);
		
	Else
		
		FormManagement();
		
	EndIf;
	
	If ValueIsFilled(LineNumber) And AnalyticalDimensions.Count() >= LineNumber Then
		ThisObject.CurrentItem = Items[ItemName];
		
		Items.AnalyticalDimensions.CurrentRow = LineNumber -1;
		Items.AnalyticalDimensions.CurrentItem = Items[FieldName];
	ElsIf ValueIsFilled(ItemName) Then
		
		ThisObject.CurrentItem = Items[ItemName];
		
	ElsIf ValueIsFilled(Account) Then
		ThisObject.CurrentItem = Items.Account;
	ElsIf ValueIsFilled(DefaultAccountType) Then
		ThisObject.CurrentItem = Items.DefaultAccountType;
	EndIf;
	
EndProcedure

&AtServer
Procedure GetEntriesDimensionsAtServer(DimensionSet)
	
	If TypeOf(DimensionSet) = Type("ChartOfAccountsRef.MasterChartOfAccounts") Then
		AnalyticalDimensionsSet = Common.ObjectAttributeValue(DimensionSet, "AnalyticalDimensionsSet");
	EndIf;
	
	CurrentAnalyticalDimensions.Load(AnalyticalDimensions.Unload());
	
	AnalyticalDimensions.Clear();
	
	For Each Row In DimensionSet.AnalyticalDimensions Do
		
		NewRow = AnalyticalDimensions.Add();
		NewRow.AnalyticalDimensionType				 = Row.AnalyticalDimension;
		NewRow.AnalyticalDimensionTypeDescription	 = NewRow.AnalyticalDimensionType.ValueType;
		NewRow.AnalyticalDimensionValue				 = "";
		
		FoundRows = CurrentAnalyticalDimensions.FindRows(New Structure("AnalyticalDimensionType", NewRow.AnalyticalDimensionType));
		If FoundRows.Count() > 0 Then
			FillPropertyValues(NewRow, FoundRows[0]);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FiltersValueSynonymClearing(Item, StandardProcessing)
	Items.Filters.CurrentData.Value = Undefined;
EndProcedure

#EndRegion