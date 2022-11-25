
#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterTypeOfAccountingOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List,
		"TypeOfAccounting",
		FilterTypeOfAccounting,
		ValueIsFilled(FilterTypeOfAccounting));

EndProcedure

&AtClient
Procedure FilterChartOfAccountsOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List,
		"ChartOfAccounts",
		FilterChartOfAccounts,
		ValueIsFilled(FilterChartOfAccounts));
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("FillFiltersAndAccounts", 0.1, True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FillFiltersAndAccounts() Export
	
	FiltersTable.Clear();
	AccountsTable.Clear();
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillFiltersAndAccountsAtServer(CurrentData.Ref);
	
EndProcedure	

&AtServer
Procedure FillFiltersAndAccountsAtServer(CurrentRef) 
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultAccountsFilters.FilterSynonym AS FilterSynonym,
	|	DefaultAccountsFilters.Value AS Value
	|FROM
	|	Catalog.DefaultAccounts.Filters AS DefaultAccountsFilters
	|WHERE
	|	DefaultAccountsFilters.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DefaultAccountsAccounts.Account AS Account,
	|	DefaultAccountsAccounts.AccountReferenceName AS AccountReferenceName
	|FROM
	|	Catalog.DefaultAccounts.Accounts AS DefaultAccountsAccounts
	|WHERE
	|	DefaultAccountsAccounts.Ref = &Ref";
	
	Query.SetParameter("Ref", CurrentRef);
	
	QueryResult = Query.ExecuteBatch();
	
	FiltersTable.Load(QueryResult[0].Unload());
	AccountsTable.Load(QueryResult[1].Unload());
	
EndProcedure

#EndRegion