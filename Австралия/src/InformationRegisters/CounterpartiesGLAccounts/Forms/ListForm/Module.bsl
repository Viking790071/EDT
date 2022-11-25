
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") Then
		Items.ShowRelevantSettings.Visible = Parameters.Filter.Count();
	EndIf;
	
	If Parameters.Filter.Property("Counterparty") Then
		Counterparty = Parameters.Filter.Counterparty;
	ElsIf Parameters.Filter.Property("Contract") Then
		Contract = Parameters.Filter.Contract;
		Counterparty = Contract.Owner;
	ElsIf Parameters.Filter.Property("Company") Then
		Company = Parameters.Filter.Company;
	EndIf;
	
	SetContractVisible();
	
EndProcedure

&AtClient
Procedure ShowRelevantSettingsOnChange(Item)
	ShowRelevantSettingsOnChangeAtServer();
EndProcedure

&AtServer
Procedure ShowRelevantSettingsOnChangeAtServer()
	
	FilterItems = List.Filter.Items;
	FilterItems.Clear();
	
	If ShowRelevantSettings Then
		
		If ValueIsFilled(Counterparty) Then
			
			CounterpartyArray = New Array();
			CounterpartyArray.Add(Catalogs.Counterparties.EmptyRef());
			CounterpartyArray.Add(Counterparty);
			
			GroupList = GLAccountsInDocuments.GetHigherGroupList(Counterparty);
			For Each Item In GroupList Do
				CounterpartyArray.Add(Item);
			EndDo;
			
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Counterparty");
			FilterItem.ComparisonType = DataCompositionComparisonType.InList;
			FilterItem.RightValue = CounterpartyArray;
			
		EndIf;
		
		If ValueIsFilled(Company) Then
			
			CompanyArray = New Array();
			CompanyArray.Add(Catalogs.Companies.EmptyRef());
			CompanyArray.Add(Company);
			
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Company");
			FilterItem.ComparisonType = DataCompositionComparisonType.InList;
			FilterItem.RightValue = CompanyArray;
			
		EndIf;
	Else
		
		If ValueIsFilled(Counterparty) Then
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Counterparty");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = Counterparty;
		EndIf;
		
		If ValueIsFilled(Contract) Then
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Contract");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = Contract;
		EndIf;
		
		If ValueIsFilled(Company) Then
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Company");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = Company;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetContractVisible()
	
	VisibleFlag = Constants.UseContractsWithCounterparties.Get();
	
	If ValueIsFilled(Counterparty) Then
		AttributesValues = Common.ObjectAttributesValues(Counterparty, "IsFolder, DoOperationsByContracts");
		If AttributesValues.IsFolder Then
			VisibleFlag = False;	
		Else
			VisibleFlag = VisibleFlag AND AttributesValues.DoOperationsByContracts;
		EndIf;
	EndIf;
	
	Items.Contract.Visible = VisibleFlag;
	
EndProcedure

#EndRegion
