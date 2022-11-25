
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
	|	DefaultAccountsTypesFilters.FilterSynonym AS FilterSynonym
	|FROM
	|	Catalog.DefaultAccountsTypes.Filters AS DefaultAccountsTypesFilters
	|WHERE
	|	DefaultAccountsTypesFilters.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DefaultAccountsTypesAccounts.AccountReferenceName AS AccountReferenceName
	|FROM
	|	Catalog.DefaultAccountsTypes.Accounts AS DefaultAccountsTypesAccounts
	|WHERE
	|	DefaultAccountsTypesAccounts.Ref = &Ref";
	
	Query.SetParameter("Ref", CurrentRef);
	
	QueryResult = Query.ExecuteBatch();
	
	FiltersTable.Load(QueryResult[0].Unload());
	AccountsTable.Load(QueryResult[1].Unload());
	
EndProcedure

#EndRegion