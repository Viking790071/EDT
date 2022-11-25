
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DoOperationsByContracts = True;
	Counterparty = Undefined;
	
	For Each Row In Object.Filters Do
		
		If TypeOf(Row.Value) = Type("CatalogRef.Counterparties") And ValueIsFilled(Row.Value) Then
			
			FillCounterpartyAttributes(Row.Value);
			
		EndIf;
		
	EndDo;
	
	SetAccountAdjustValue();
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtServer
Procedure DefaultAccountTypeOnChangeAtServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultAccountsTypes.Company AS Company,
	|	DefaultAccountsTypes.TypeOfAccounting AS TypeOfAccounting,
	|	DefaultAccountsTypes.ChartOfAccounts AS ChartOfAccounts
	|FROM
	|	Catalog.DefaultAccountsTypes AS DefaultAccountsTypes
	|WHERE
	|	DefaultAccountsTypes.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DefaultAccountsTypesFilters.FilterName AS FilterName,
	|	DefaultAccountsTypesFilters.FilterSynonym AS FilterSynonym,
	|	DefaultAccountsTypesFilters.SavedValueType AS SavedValueType
	|FROM
	|	Catalog.DefaultAccountsTypes.Filters AS DefaultAccountsTypesFilters
	|WHERE
	|	DefaultAccountsTypesFilters.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DefaultAccountsTypesAccounts.AccountReferenceName AS AccountReferenceName,
	|	CASE
	|		WHEN CatalogChartsOfAccounts.ChartOfAccounts = VALUE(Enum.ChartsOfAccounts.FinancialChartOfAccounts)
	|			THEN VALUE(ChartOfAccounts.FinancialChartOfAccounts.EmptyRef)
	|		WHEN CatalogChartsOfAccounts.ChartOfAccounts = VALUE(Enum.ChartsOfAccounts.MasterChartOfAccounts)
	|			THEN VALUE(ChartOfAccounts.MasterChartOfAccounts.EmptyRef)
	|		WHEN CatalogChartsOfAccounts.ChartOfAccounts = VALUE(Enum.ChartsOfAccounts.PrimaryChartOfAccounts)
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		Else UNDEFINED
	|	END AS Account
	|FROM
	|	Catalog.DefaultAccountsTypes.Accounts AS DefaultAccountsTypesAccounts
	|		LEFT JOIN Catalog.ChartsOfAccounts AS CatalogChartsOfAccounts
	|		ON DefaultAccountsTypesAccounts.Ref.ChartOfAccounts = CatalogChartsOfAccounts.Ref
	|WHERE
	|	DefaultAccountsTypesAccounts.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.DefaultAccountType);
	
	QueryResults = Query.ExecuteBatch();
	
	SelectionDetailRecords = QueryResults[0].Select();
	SelectionDetailRecords.Next();
	
	FillPropertyValues(Object, SelectionDetailRecords);
	
	Object.Filters.Clear();
	
	DoOperationsByContracts = True;
	Counterparty = Undefined;
	
	SelectionDetailRecords = QueryResults[1].Select();
	
	While SelectionDetailRecords.Next() Do
		
		NewRow = Object.Filters.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		
		TypeDescription = SelectionDetailRecords.SavedValueType.Get();
		NewRow.Value = TypeDescription.AdjustValue(Undefined);
		
	EndDo;
	
	Object.Accounts.Load(QueryResults[2].Unload());
	
	SetAccountAdjustValue();
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure DefaultAccountTypeOnChange(Item)
	
	DefaultAccountTypeOnChangeAtServer();
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	For Each Row In Object.Filters Do
		
		If TypeOf(Row.Value) = Type("CatalogRef.CounterpartyContracts")
			And ValueIsFilled(Row.Value)
			And Counterparty <> Row.Value.Company Then
			
			Row.Value = Catalogs.CounterpartyContracts.EmptyRef();
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	CompanyOnChangeAtServer();
	
	CurrentData = Items.Filters.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CurrentData.Value) = Type("CatalogRef.CounterpartyContracts") Then
		
		SetChoiceParametersContract(True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFilters

&AtClient
Procedure FiltersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure FiltersBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure FiltersValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.Filters.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CurrentData.Value) = Type("CatalogRef.CounterpartyContracts") Then
		
		FormParameters = GetChoiceFormParameters(CurrentData.Value);
		
		StandardProcessing = False;
		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm",
			FormParameters,
			Item,
			,
			,
			,
			New NotifyDescription("AfterSelectCounterpartyContracts", ThisObject));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FiltersValueOnChange(Item)
	
	CurrentData = Items.Filters.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CurrentData.Value) <> Type("CatalogRef.Counterparties") Then
		Return;
	EndIf;
		
	If ValueIsFilled(CurrentData.Value) Then
		
		AfterSelectCounterpartyServer(CurrentData.Value);
	
	Else
		
		Counterparty = Undefined;
		DoOperationsByContracts = True;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure FiltersOnActivateRow(Item)
	
	CurrentData = Items.Filters.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	IsContract = TypeOf(CurrentData.Value) = Type("CatalogRef.CounterpartyContracts");
	
	Items.FiltersValue.ReadOnly = IsContract And Not DoOperationsByContracts;
	
	SetChoiceParametersContract(IsContract);

	If IsContract Then
		Items.FiltersValue.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
	Else
		Items.FiltersValue.ChoiceHistoryOnInput = ChoiceHistoryOnInput.Auto;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAccounts

&AtClient
Procedure AccountsAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.ChartOfAccounts) Then
		StandardProcessing = False;
		
		CommonClientServer.MessageToUser(Nstr("en = 'The chart of accounts is not filled in.'; ru = 'Не указан план счетов.';pl = 'Plan kont nie jest wypełniony.';es_ES = 'El diagrama de cuentas no está rellenado.';es_CO = 'El diagrama de cuentas no está rellenado.';tr = 'Hesap planı doldurulmadı.';it = 'Il piano dei conti non è compilato.';de = 'Der Kontenplan ist nicht aufgefüllt.'"));
	EndIf;
	
	If Items.AccountsAccount.TypeRestriction = New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts") Then
		
		FormParameters = GetChoiceAccountsParameters();
		
		StandardProcessing = False;
		
		OpenForm("ChartOfAccounts.MasterChartOfAccounts.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
	
EndProcedure

&AtClient
Procedure AccountsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure AccountsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetChoiceAccountsParameters()
	
	FixedSettings = New DataCompositionSettings;
	
	FilterItem = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ChartOfAccounts");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Object.ChartOfAccounts;
	FilterItem.Use = True;
	
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	If ValueIsFilled(Object.Company) Then
		FilterItem = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("Companies.Company");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = Object.Company;
		FilterItem.Use = True;
		
		FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FixedSettings", FixedSettings);
	
	Return FormParameters;
	
EndFunction

&AtClient
Function GetChoiceFormParameters(Contract)
	
	FormParameters = New Structure;
	
	If ValueIsFilled(Counterparty) Then
		
		FormParameters.Insert("Counterparty"			, Counterparty);
		FormParameters.Insert("ControlContractChoice"	, DoOperationsByContracts);
		
	Else
		
		FormParameters.Insert("DoOperationsByContracts"	, True);
		
	EndIf;
	
	If ValueIsFilled(Object.Company) Then
		FormParameters.Insert("Company", Object.Company);
	EndIf;	
	
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;	
	
EndFunction	

&AtClient
Procedure AfterSelectCounterpartyContracts(Result, AddParameters) Export 
	
	If ValueIsFilled(Result) Then
		AfterSelectCounterpartyContractsServer(Result);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterSelectCounterpartyContractsServer(Contract) Export 
	
	Counterparty			= Common.ObjectAttributeValue(Contract, "Owner");
	DoOperationsByContracts = Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts");
	
	For Each Row In Object.Filters Do
		
		If TypeOf(Row.Value) = Type("CatalogRef.Counterparties") Then
			
			Row.Value = Counterparty;
			
		EndIf;
		
	EndDo;	
			
EndProcedure

&AtServer
Procedure AfterSelectCounterpartyServer(CurrentCounterparty)
	
	FillCounterpartyAttributes(CurrentCounterparty);
	
	EmptyElement = Catalogs.CounterpartyContracts.EmptyRef();
	
	For Each Row In Object.Filters Do
		
		If TypeOf(Row.Value) = Type("CatalogRef.CounterpartyContracts")
			And ValueIsFilled(Row.Value)
			And Counterparty <> Row.Value.Owner Then
			
			Row.Value = EmptyElement;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillCounterpartyAttributes(CurrentCounterparty)
	
	Counterparty = CurrentCounterparty;
	DoOperationsByContracts = Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts");
	
EndProcedure

&AtServer
Procedure SetAccountAdjustValue()
	
	If Not ValueIsFilled(Object.ChartOfAccounts) Then
		Return;
	EndIf;
	
	If AccountingApprovalServer.GetMasterByChartOfAccounts(Object.ChartOfAccounts) Then
		TypeDescription = New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts");
	Else
		TypeDescription = New TypeDescription("ChartOfAccountsRef.PrimaryChartOfAccounts");
	EndIf;
	
	Items.AccountsAccount.TypeRestriction = TypeDescription;
	
EndProcedure

&AtClient
Procedure SetChoiceParametersContract(IsContract)
	
	If Not IsContract Then
		
		Items.FiltersValue.ChoiceParameters = New FixedArray(New Array);
		Return;
		
	EndIf;
	
	NewArray = New Array();
	
	If ValueIsFilled(Counterparty) Then
		
		NewChoiceParameter = New ChoiceParameter("Filter.Owner", Counterparty);
		NewArray.Add(NewChoiceParameter);
		
	EndIf;	
	
	If ValueIsFilled(Object.Company) Then
		
		NewChoiceParameter = New ChoiceParameter("Filter.Company", Object.Company);
		NewArray.Add(NewChoiceParameter);
		
	EndIf;
	
	Items.FiltersValue.ChoiceParameters = New FixedArray(NewArray)
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	Items.Company.ReadOnly = (ValueIsFilled(Object.DefaultAccountType)
		And ValueIsFilled(Object.DefaultAccountType.Company));
	
EndProcedure

#EndRegion
