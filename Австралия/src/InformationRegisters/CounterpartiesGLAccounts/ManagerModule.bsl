#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetCounterpartiesDefaultGLAccounts() Export
	
	ReturnStructure = GetCounterpartiesGLAccountEmptyStructure();
	
	Query = New Query();
	Query.Text = "SELECT 
	|	CounterpartiesGLAccounts.AccountsReceivable AS AccountsReceivable,
	|	CounterpartiesGLAccounts.AdvancesReceived AS AdvancesReceived,
	|	CounterpartiesGLAccounts.AccountsPayable AS AccountsPayable,
	|	CounterpartiesGLAccounts.AdvancesPaid AS AdvancesPaid,
	|	CounterpartiesGLAccounts.DiscountAllowed AS DiscountAllowed,
	|	CounterpartiesGLAccounts.DiscountReceived AS DiscountReceived,
	|	CounterpartiesGLAccounts.ThirdPartyPayer AS ThirdPartyPayer
	|FROM
	|	InformationRegister.CounterpartiesGLAccounts AS CounterpartiesGLAccounts
	|WHERE
	|	CounterpartiesGLAccounts.Company = VALUE(Catalog.Companies.EmptyRef)
	|	AND CounterpartiesGLAccounts.TaxCategory = VALUE(Enum.VATTaxationTypes.EmptyRef)
	|	AND CounterpartiesGLAccounts.Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|	AND CounterpartiesGLAccounts.Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef)";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(ReturnStructure, Selection);
	EndIf;;
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Region Private

Function GetCounterpartiesGLAccountEmptyStructure()
	
	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("AccountsReceivable",	EmptyGLAccount);
	ReturnStructure.Insert("AdvancesReceived",		EmptyGLAccount);
	ReturnStructure.Insert("AccountsPayable",		EmptyGLAccount);
	ReturnStructure.Insert("AdvancesPaid",			EmptyGLAccount);
	ReturnStructure.Insert("DiscountAllowed",		EmptyGLAccount);
	ReturnStructure.Insert("DiscountReceived",		EmptyGLAccount);
	ReturnStructure.Insert("ThirdPartyPayer",		EmptyGLAccount);
		
	Return ReturnStructure; 
	
EndFunction

#EndRegion

#EndIf