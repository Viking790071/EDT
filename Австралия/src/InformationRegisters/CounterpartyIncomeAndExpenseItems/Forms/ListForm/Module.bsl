
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsFilterSet = False;
	
	If Parameters.Property("Filter") And Parameters.Filter.Count() Then
		
		IsFilterSet = True;
		
		Parameters.Filter.Property("Company", Company);
		Parameters.Filter.Property("Counterparty", Counterparty);
		
		If Parameters.Filter.Property("Contract") Then
			Contract = Parameters.Filter.Contract;
			Counterparty = Contract.Owner;
		EndIf;
		
	EndIf;
	
	Items.ShowRelevantSettings.Visible = IsFilterSet;
	
	FormManagement();
	
EndProcedure

#EndRegion 

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowRelevantSettingsOnChange(Item)
	FormManagement();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FormManagement()
	
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
	
	CanUseContracts = Constants.UseContractsWithCounterparties.Get();
	
	If CanUseContracts And ValueIsFilled(Counterparty) Then
		
		AttributesValues = Common.ObjectAttributesValues(Counterparty, "IsFolder, DoOperationsByContracts");
		If AttributesValues.IsFolder Then
			CanUseContracts = False;
		Else
			CanUseContracts = AttributesValues.DoOperationsByContracts;
		EndIf;
		
	EndIf;
	
	Items.Contract.Visible = CanUseContracts;
	
EndProcedure

#EndRegion
