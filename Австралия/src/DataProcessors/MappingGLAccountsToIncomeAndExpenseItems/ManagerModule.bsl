#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure SaveMapping(ProcedureParameters, StorageAddress) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	#Region QueryText
	
	Query.Text =
	"SELECT
	|	CAST(Mapping.GLAccount AS ChartOfAccounts.PrimaryChartOfAccounts) AS GLAccount,
	|	CAST(Mapping.IncomeAndExpenseItem AS Catalog.IncomeAndExpenseItems) AS IncomeAndExpenseItem
	|INTO TT_Mapping
	|FROM
	|	&Mapping AS Mapping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CAST(DefaultItemTable.DefaultGLAccount AS Catalog.DefaultGLAccounts) AS DefaultGLAccount,
	|	CAST(DefaultItemTable.DefaultIncomeAndExpenseItem AS Catalog.DefaultIncomeAndExpenseItems) AS DefaultIncomeAndExpenseItem
	|INTO TT_DefaultItemTable
	|FROM
	|	&DefaultItemTable AS DefaultItemTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CAST(DefaultItemTable.GLAccount AS ChartOfAccounts.PrimaryChartOfAccounts) AS GLAccount,
	|	CAST(DefaultItemTable.DefaultIncomeAndExpenseItem AS Catalog.DefaultIncomeAndExpenseItems) AS DefaultIncomeAndExpenseItem
	|INTO TT_GLAccountDefaultItemTable
	|FROM
	|	&OtherDefaultItemTable AS DefaultItemTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Period AS Period,
	|	TT_Mapping.GLAccount AS GLAccount,
	|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem
	|FROM
	|	TT_Mapping AS TT_Mapping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	IncomeAndExpenses.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON IncomeAndExpenses.GLAccount = TT_Mapping.GLAccount
	|			AND IncomeAndExpenses.IncomeAndExpenseItem <> TT_Mapping.IncomeAndExpenseItem
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	IncomeAndExpensesBudget.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.IncomeAndExpensesBudget AS IncomeAndExpensesBudget
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON IncomeAndExpensesBudget.GLAccount = TT_Mapping.GLAccount
	|			AND IncomeAndExpensesBudget.IncomeAndExpenseItem <> TT_Mapping.IncomeAndExpenseItem
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	FixedAssetParameters.Recorder AS Recorder
	|FROM
	|	InformationRegister.FixedAssetParameters AS FixedAssetParameters
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON FixedAssetParameters.GLExpenseAccount = TT_Mapping.GLAccount
	|			AND FixedAssetParameters.ExpenseItem <> TT_Mapping.IncomeAndExpenseItem
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	FinancialResult.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.FinancialResult AS FinancialResult
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON FinancialResult.GLAccount = TT_Mapping.GLAccount
	|			AND FinancialResult.IncomeAndExpenseItem <> TT_Mapping.IncomeAndExpenseItem
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	FinancialResultForecast.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.FinancialResultForecast AS FinancialResultForecast
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON FinancialResultForecast.GLAccount = TT_Mapping.GLAccount
	|			AND FinancialResultForecast.IncomeAndExpenseItem <> TT_Mapping.IncomeAndExpenseItem
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CompensationPlan.Recorder AS Recorder
	|FROM
	|	InformationRegister.CompensationPlan AS CompensationPlan
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON CompensationPlan.GLExpenseAccount = TT_Mapping.GLAccount
	|			AND CompensationPlan.IncomeAndExpenseItem <> TT_Mapping.IncomeAndExpenseItem
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	NULL
	// begin Drive.FullVersion
	|	,PredeterminedOverheadRates.Recorder AS Recorder
	|FROM
	|	InformationRegister.PredeterminedOverheadRates AS PredeterminedOverheadRates
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON PredeterminedOverheadRates.OverheadsGLAccount = TT_Mapping.GLAccount
	|			AND PredeterminedOverheadRates.ExpenseItem <> TT_Mapping.IncomeAndExpenseItem
	// end Drive.FullVersion 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CounterpartiesGLAccounts.Company AS Company,
	|	CounterpartiesGLAccounts.TaxCategory AS TaxCategory,
	|	CounterpartiesGLAccounts.Counterparty AS Counterparty,
	|	CounterpartiesGLAccounts.Contract AS Contract,
	|	ISNULL(MappingDiscountAllowed.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS DiscountAllowedItem,
	|	ISNULL(MappingDiscountReceived.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS DiscountReceivedItem
	|FROM
	|	InformationRegister.CounterpartiesGLAccounts AS CounterpartiesGLAccounts
	|		LEFT JOIN InformationRegister.CounterpartyIncomeAndExpenseItems AS CounterpartyIncomeAndExpenseItems
	|		ON CounterpartiesGLAccounts.Company = CounterpartyIncomeAndExpenseItems.Company
	|			AND CounterpartiesGLAccounts.TaxCategory = CounterpartyIncomeAndExpenseItems.TaxCategory
	|			AND CounterpartiesGLAccounts.Counterparty = CounterpartyIncomeAndExpenseItems.Counterparty
	|			AND CounterpartiesGLAccounts.Contract = CounterpartyIncomeAndExpenseItems.Contract
	|		LEFT JOIN TT_Mapping AS MappingDiscountAllowed
	|		ON CounterpartiesGLAccounts.DiscountAllowed = MappingDiscountAllowed.GLAccount
	|		LEFT JOIN TT_Mapping AS MappingDiscountReceived
	|		ON CounterpartiesGLAccounts.DiscountReceived = MappingDiscountReceived.GLAccount
	|WHERE
	|	CounterpartyIncomeAndExpenseItems.Company IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	CounterpartyIncomeAndExpenseItems.Company,
	|	CounterpartyIncomeAndExpenseItems.TaxCategory,
	|	CounterpartyIncomeAndExpenseItems.Counterparty,
	|	CounterpartyIncomeAndExpenseItems.Contract,
	|	CounterpartyIncomeAndExpenseItems.DiscountAllowedItem,
	|	CounterpartyIncomeAndExpenseItems.DiscountReceivedItem
	|FROM
	|	InformationRegister.CounterpartyIncomeAndExpenseItems AS CounterpartyIncomeAndExpenseItems
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductGLAccounts.Company AS Company,
	|	ProductGLAccounts.Product AS Product,
	|	ProductGLAccounts.ProductCategory AS ProductCategory,
	|	ProductGLAccounts.StructuralUnit AS StructuralUnit,
	|	ISNULL(MappingCOGS.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS COGSItem,
	|	CASE
	|		WHEN ISNULL(MappingExpense.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
	|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|		ELSE ISNULL(MappingExpense.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
	|	END AS ExpenseItem,
	|	ISNULL(MappingPurchaseReturn.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS PurchaseReturnItem,
	|	ISNULL(MappingRevenue.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS RevenueItem,
	|	ISNULL(MappingSalesReturn.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS SalesReturnItem,
	|	ISNULL(MappingCostOfSalesItem.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS CostOfSalesItem
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		LEFT JOIN InformationRegister.ProductIncomeAndExpenseItems AS ProductIncomeAndExpenseItems
	|		ON ProductGLAccounts.Company = ProductIncomeAndExpenseItems.Company
	|			AND ProductGLAccounts.Product = ProductIncomeAndExpenseItems.Product
	|			AND ProductGLAccounts.ProductCategory = ProductIncomeAndExpenseItems.ProductCategory
	|			AND ProductGLAccounts.StructuralUnit = ProductIncomeAndExpenseItems.StructuralUnit
	|		LEFT JOIN TT_Mapping AS MappingCOGS
	|		ON ProductGLAccounts.COGS = MappingCOGS.GLAccount
	|		LEFT JOIN TT_Mapping AS MappingExpense
	|		ON ProductGLAccounts.Inventory = MappingExpense.GLAccount
	|		LEFT JOIN TT_Mapping AS MappingPurchaseReturn
	|		ON ProductGLAccounts.PurchaseReturn = MappingPurchaseReturn.GLAccount
	|		LEFT JOIN TT_Mapping AS MappingRevenue
	|		ON ProductGLAccounts.Revenue = MappingRevenue.GLAccount
	|		LEFT JOIN TT_Mapping AS MappingSalesReturn
	|		ON ProductGLAccounts.SalesReturn = MappingSalesReturn.GLAccount
	|		LEFT JOIN TT_Mapping AS MappingCostOfSalesItem
	|		ON ProductGLAccounts.CostOfSales = MappingCostOfSalesItem.GLAccount
	|WHERE
	|	ProductIncomeAndExpenseItems.Company IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	ProductIncomeAndExpenseItems.Company,
	|	ProductIncomeAndExpenseItems.Product,
	|	ProductIncomeAndExpenseItems.ProductCategory,
	|	ProductIncomeAndExpenseItems.StructuralUnit,
	|	ProductIncomeAndExpenseItems.COGSItem,
	|	ProductIncomeAndExpenseItems.ExpenseItem,
	|	ProductIncomeAndExpenseItems.PurchaseReturnItem,
	|	ProductIncomeAndExpenseItems.RevenueItem,
	|	ProductIncomeAndExpenseItems.SalesReturnItem,
	|	ProductIncomeAndExpenseItems.CostOfSalesItem
	|FROM
	|	InformationRegister.ProductIncomeAndExpenseItems AS ProductIncomeAndExpenseItems
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DefaultItemTable.DefaultIncomeAndExpenseItem AS DefaultIncomeAndExpenseItem,
	|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem
	|FROM
	|	TT_DefaultItemTable AS TT_DefaultItemTable
	|		INNER JOIN Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|			INNER JOIN TT_Mapping AS TT_Mapping
	|			ON DefaultGLAccounts.GLAccount = TT_Mapping.GLAccount
	|				AND (TT_Mapping.IncomeAndExpenseItem <> VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
	|		ON TT_DefaultItemTable.DefaultGLAccount = DefaultGLAccounts.Ref
	|		INNER JOIN Catalog.DefaultIncomeAndExpenseItems AS DefaultIncomeAndExpenseItems
	|		ON TT_DefaultItemTable.DefaultIncomeAndExpenseItem = DefaultIncomeAndExpenseItems.Ref
	|			AND (DefaultIncomeAndExpenseItems.IncomeAndExpenseItem <> TT_Mapping.IncomeAndExpenseItem)
	|
	|UNION ALL
	|
	|SELECT
	|	TT_DefaultItemTable.DefaultIncomeAndExpenseItem,
	|	TT_Mapping.IncomeAndExpenseItem
	|FROM
	|	TT_GLAccountDefaultItemTable AS TT_DefaultItemTable
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON TT_DefaultItemTable.GLAccount = TT_Mapping.GLAccount
	|			AND (TT_Mapping.IncomeAndExpenseItem <> VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
	|		INNER JOIN Catalog.DefaultIncomeAndExpenseItems AS DefaultIncomeAndExpenseItems
	|		ON TT_DefaultItemTable.DefaultIncomeAndExpenseItem = DefaultIncomeAndExpenseItems.Ref
	|			AND (DefaultIncomeAndExpenseItems.IncomeAndExpenseItem <> TT_Mapping.IncomeAndExpenseItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BankCharges.Ref AS Ref,
	|	TT_Mapping.IncomeAndExpenseItem AS ExpenseItem
	|FROM
	|	Catalog.BankCharges AS BankCharges
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON BankCharges.GLExpenseAccount = TT_Mapping.GLAccount
	|			AND (BankCharges.GLExpenseAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|			AND (BankCharges.ExpenseItem <> TT_Mapping.IncomeAndExpenseItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EarningAndDeductionTypes.Ref AS Ref,
	|	TT_Mapping.IncomeAndExpenseItem AS ExpenseItem
	|FROM
	|	Catalog.EarningAndDeductionTypes AS EarningAndDeductionTypes
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON EarningAndDeductionTypes.GLExpenseAccount = TT_Mapping.GLAccount
	|			AND (EarningAndDeductionTypes.GLExpenseAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|			AND (EarningAndDeductionTypes.IncomeAndExpenseItem <> TT_Mapping.IncomeAndExpenseItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EstimatesTemplatesExpenses.Ref AS Ref,
	|	EstimatesTemplatesExpenses.LineNumber AS LineNumber,
	|	EstimatesTemplatesExpenses.GLExpenseAccount AS GLExpenseAccount,
	|	ISNULL(TT_Mapping.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS ExpenseItem,
	|	EstimatesTemplatesExpenses.CalculationMethod AS CalculationMethod,
	|	EstimatesTemplatesExpenses.Value AS Value,
	|	EstimatesTemplatesExpenses.Currency AS Currency,
	|	EstimatesTemplatesExpenses.ConnectionKey AS ConnectionKey
	|FROM
	|	Catalog.EstimatesTemplates.Expenses AS EstimatesTemplatesExpenses
	|		LEFT JOIN TT_Mapping AS TT_Mapping
	|		ON EstimatesTemplatesExpenses.GLExpenseAccount = TT_Mapping.GLAccount
	|			AND (EstimatesTemplatesExpenses.GLExpenseAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|			AND (EstimatesTemplatesExpenses.ExpenseItem <> TT_Mapping.IncomeAndExpenseItem)
	|
	|ORDER BY
	|	Ref,
	|	LineNumber
	|TOTALS BY
	|	Ref";
	
	#EndRegion 
	
	Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
	Query.Text = Query.Text + GetQueryTextForInventoryRegisters();
	Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
	Query.Text = Query.Text + GetQueryTextForProfitEstimation();
	
	Query.SetParameter("Mapping", ProcedureParameters.MappingTable);
	Query.SetParameter("Period", 
		?(Constants.EachGLAccountIsMappedToIncomeAndExpenseItem.Get(), CurrentSessionDate(), DriveServer.GetDefaultDate()));
	Query.SetParameter("DefaultItemTable", GetDefaultItemTable());
	Query.SetParameter("OtherDefaultItemTable", GetOtherDefaultItemTable());
	
	QueryResult = Query.ExecuteBatch();
	
	RecordSet = InformationRegisters.MappingGLAccountsToIncomeAndExpenseItems.CreateRecordSet();
	RecordSet.Load(QueryResult[3].Unload());
	
	InfobaseUpdate.WriteRecordSet(RecordSet);
	
	NumberOfRelatedRegisters = 6;
	// begin Drive.FullVersion
	NumberOfRelatedRegisters = 7;
	// end Drive.FullVersion 
	
	For QueryNumber = 4 To NumberOfRelatedRegisters + 3 Do
		
		Selection = QueryResult[QueryNumber].Select();
		
		While Selection.Next() Do
			
			Query.Text = GetQueryText(QueryNumber);
			Query.SetParameter("Recorder", Selection.Recorder);
			
			RegisterManager = GetRegisterManager(QueryNumber);
			
			RecordSet = RegisterManager.CreateRecordSet();
			RecordSet.Filter.Recorder.Set(Selection.Recorder);
			RecordSet.Load(Query.Execute().Unload());
			
			InfobaseUpdate.WriteRecordSet(RecordSet);
			
		EndDo;
		
	EndDo;
	
	For QueryNumber = 11 To 12 Do
		
		RegisterManager = GetRegisterManager(QueryNumber);
		
		RecordSet = RegisterManager.CreateRecordSet();
		RecordSet.Load(QueryResult[QueryNumber].Unload());
		InfobaseUpdate.WriteRecordSet(RecordSet);
		
	EndDo;
	
	Selection = QueryResult[13].Select();
	While Selection.Next() Do
		
		CatalogObject = Selection.DefaultIncomeAndExpenseItem.GetObject();
		If CatalogObject = Undefined Then
			Continue;
		EndIf;
		
		CatalogObject.IncomeAndExpenseItem = Selection.IncomeAndExpenseItem;
		
		InfobaseUpdate.WriteObject(CatalogObject);
		
	EndDo;
	
	For QueryNumber = 14 To 15 Do
		
		Selection = QueryResult[QueryNumber].Select();
		While Selection.Next() Do
			
			CatalogObject = Selection.Ref.GetObject();
			If CatalogObject = Undefined Then
				Continue;
			EndIf;
			
			If QueryNumber = 14 Then
				CatalogObject.ExpenseItem = Selection.ExpenseItem;
			Else
				CatalogObject.IncomeAndExpenseItem = Selection.ExpenseItem;
			EndIf;
			
			InfobaseUpdate.WriteObject(CatalogObject);
			
		EndDo;
		
	EndDo;
	
	Selection = QueryResult[16].Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
		
		CatalogObject = Selection.Ref.GetObject();
		If CatalogObject = Undefined Then
			Continue;
		EndIf;
		
		CatalogObject.Expenses.Clear();
		
		SelectionExpenses = Selection.Select();
		While SelectionExpenses.Next() Do
			FillPropertyValues(CatalogObject.Expenses.Add(), SelectionExpenses);
		EndDo;
		
		InfobaseUpdate.WriteObject(CatalogObject);
		
	EndDo;
	
	For QueryNumber = 17 To 25 Do
		
		Query.Text = GetQueryText(QueryNumber);
		RegisterManager = GetRegisterManager(QueryNumber);
		
		Selection = QueryResult[QueryNumber].Select();
		While Selection.Next() Do
			
			Query.SetParameter("Recorder", Selection.Recorder);
			Query.SetParameter("Date", Common.ObjectAttributeValue(Selection.Recorder, "Date"));
			
			RecordSet = RegisterManager.CreateRecordSet();
			RecordSet.Filter.Recorder.Set(Selection.Recorder);
			RecordSet.Load(Query.Execute().Unload());
			
			InfobaseUpdate.WriteRecordSet(RecordSet);
			
		EndDo;
		
	EndDo;
	
	Query.Text = GetQueryText(26);
	Selection = QueryResult[26].Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		If DocObject = Undefined Then
			Continue;
		EndIf;
		
		Query.SetParameter("Ref", Selection.Ref);
		DocMappingTable = Query.Execute().Unload();
		
		For Each Line In DocObject.Estimate Do
			
			DocMappingLine = DocMappingTable.Find(Line.Products, "GLAccount");
			If DocMappingLine <> Undefined Then
				Line.Products = DocMappingLine.IncomeAndExpenseItem;
			EndIf;
			
		EndDo;
		
		InfobaseUpdate.WriteObject(DocObject);
		
	EndDo;
	
	DocumentsAttributesMapping(TempTablesManager);
	
	BeginTransaction();
	
	Try
		
		Constants.UseDefaultTypeOfAccounting.Set(ProcedureParameters.UseDefaultTypeOfAccounting);
		Constants.EachGLAccountIsMappedToIncomeAndExpenseItem.Set(True);
		Constants.EachProfitEstimationGLAccountIsMappedToIncomeAndExpenseItem.Set(True);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Procedure SaveProfitEstimationMapping(ProcedureParameters, StorageAddress) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	CAST(Mapping.GLAccount AS ChartOfAccounts.PrimaryChartOfAccounts) AS GLAccount,
	|	CAST(Mapping.IncomeAndExpenseItem AS Catalog.IncomeAndExpenseItems) AS IncomeAndExpenseItem
	|INTO TT_Mapping
	|FROM
	|	&Mapping AS Mapping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Period AS Period,
	|	TT_Mapping.GLAccount AS GLAccount,
	|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem
	|FROM
	|	TT_Mapping AS TT_Mapping";
	
	Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
	Query.Text = Query.Text + GetQueryTextForProfitEstimation();
	
	Query.SetParameter("Mapping", ProcedureParameters.MappingTable);
	Query.SetParameter("Period", CurrentSessionDate());
	
	QueryResult = Query.ExecuteBatch();
	
	RecordSet = InformationRegisters.MappingGLAccountsToIncomeAndExpenseItems.CreateRecordSet();
	RecordSet.Load(QueryResult[1].Unload());
	
	InfobaseUpdate.WriteRecordSet(RecordSet);
	
	Query.Text = GetQueryText(26);
	Selection = QueryResult[2].Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		If DocObject = Undefined Then
			Continue;
		EndIf;
		
		Query.SetParameter("Ref", Selection.Ref);
		DocMappingTable = Query.Execute().Unload();
		
		For Each Line In DocObject.Estimate Do
			
			DocMappingLine = DocMappingTable.Find(Line.Products, "GLAccount");
			If DocMappingLine <> Undefined Then
				Line.Products = DocMappingLine.IncomeAndExpenseItem;
			EndIf;
			
		EndDo;
		
		InfobaseUpdate.WriteObject(DocObject);
		
	EndDo;
	
	Constants.EachProfitEstimationGLAccountIsMappedToIncomeAndExpenseItem.Set(True);
	
EndProcedure

#EndRegion

#Region Private

Function GetQueryText(QueryNumber)
	
	If QueryNumber = 4 Then
		
		Return
		"SELECT
		|	IncomeAndExpenses.Period AS Period,
		|	IncomeAndExpenses.Recorder AS Recorder,
		|	IncomeAndExpenses.LineNumber AS LineNumber,
		|	IncomeAndExpenses.Active AS Active,
		|	IncomeAndExpenses.Company AS Company,
		|	IncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
		|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
		|	IncomeAndExpenses.BusinessLine AS BusinessLine,
		|	IncomeAndExpenses.SalesOrder AS SalesOrder,
		|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	IncomeAndExpenses.AmountIncome AS AmountIncome,
		|	IncomeAndExpenses.AmountExpense AS AmountExpense,
		|	IncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	IncomeAndExpenses.OfflineRecord AS OfflineRecord,
		|	IncomeAndExpenses.GLAccount AS GLAccount
		|FROM
		|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
		|		INNER JOIN TT_Mapping AS TT_Mapping
		|		ON (IncomeAndExpenses.Recorder = &Recorder)
		|			AND IncomeAndExpenses.GLAccount = TT_Mapping.GLAccount";
		
	ElsIf QueryNumber = 5 Then
		
		Return
		"SELECT
		|	IncomeAndExpensesBudget.Period AS Period,
		|	IncomeAndExpensesBudget.Recorder AS Recorder,
		|	IncomeAndExpensesBudget.LineNumber AS LineNumber,
		|	IncomeAndExpensesBudget.Active AS Active,
		|	IncomeAndExpensesBudget.Company AS Company,
		|	IncomeAndExpensesBudget.PlanningPeriod AS PlanningPeriod,
		|	IncomeAndExpensesBudget.StructuralUnit AS StructuralUnit,
		|	IncomeAndExpensesBudget.BusinessLine AS BusinessLine,
		|	IncomeAndExpensesBudget.SalesOrder AS SalesOrder,
		|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	IncomeAndExpensesBudget.AmountIncome AS AmountIncome,
		|	IncomeAndExpensesBudget.AmountExpense AS AmountExpense,
		|	IncomeAndExpensesBudget.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	IncomeAndExpensesBudget.GLAccount AS GLAccount
		|FROM
		|	AccumulationRegister.IncomeAndExpensesBudget AS IncomeAndExpensesBudget
		|		INNER JOIN TT_Mapping AS TT_Mapping
		|		ON (IncomeAndExpensesBudget.Recorder = &Recorder)
		|			AND IncomeAndExpensesBudget.GLAccount = TT_Mapping.GLAccount";
		
	ElsIf QueryNumber = 6 Then
		
		Return
		"SELECT
		|	FixedAssetParameters.Period AS Period,
		|	FixedAssetParameters.Recorder AS Recorder,
		|	FixedAssetParameters.LineNumber AS LineNumber,
		|	FixedAssetParameters.Active AS Active,
		|	FixedAssetParameters.Company AS Company,
		|	FixedAssetParameters.PresentationCurrency AS PresentationCurrency,
		|	FixedAssetParameters.FixedAsset AS FixedAsset,
		|	FixedAssetParameters.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
		|	FixedAssetParameters.CostForDepreciationCalculation AS CostForDepreciationCalculation,
		|	FixedAssetParameters.ApplyInCurrentMonth AS ApplyInCurrentMonth,
		|	TT_Mapping.IncomeAndExpenseItem AS ExpenseItem,
		|	FixedAssetParameters.StructuralUnit AS StructuralUnit,
		|	FixedAssetParameters.BusinessLine AS BusinessLine,
		|	FixedAssetParameters.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
		|	FixedAssetParameters.GLExpenseAccount AS GLExpenseAccount
		|FROM
		|	InformationRegister.FixedAssetParameters AS FixedAssetParameters
		|		INNER JOIN TT_Mapping AS TT_Mapping
		|		ON (FixedAssetParameters.Recorder = &Recorder)
		|			AND FixedAssetParameters.GLExpenseAccount = TT_Mapping.GLAccount";
		
	ElsIf QueryNumber = 7 Then
		
		Return
		"SELECT
		|	FinancialResult.Period AS Period,
		|	FinancialResult.Recorder AS Recorder,
		|	FinancialResult.LineNumber AS LineNumber,
		|	FinancialResult.Active AS Active,
		|	FinancialResult.Company AS Company,
		|	FinancialResult.PresentationCurrency AS PresentationCurrency,
		|	FinancialResult.StructuralUnit AS StructuralUnit,
		|	FinancialResult.BusinessLine AS BusinessLine,
		|	FinancialResult.SalesOrder AS SalesOrder,
		|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	FinancialResult.AmountIncome AS AmountIncome,
		|	FinancialResult.AmountExpense AS AmountExpense,
		|	FinancialResult.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	FinancialResult.GLAccount AS GLAccount
		|FROM
		|	AccumulationRegister.FinancialResult AS FinancialResult
		|		INNER JOIN TT_Mapping AS TT_Mapping
		|		ON (FinancialResult.Recorder = &Recorder)
		|			AND FinancialResult.GLAccount = TT_Mapping.GLAccount";
		
	ElsIf QueryNumber = 8 Then
		
		Return
		"SELECT
		|	FinancialResultForecast.Period AS Period,
		|	FinancialResultForecast.Recorder AS Recorder,
		|	FinancialResultForecast.LineNumber AS LineNumber,
		|	FinancialResultForecast.Active AS Active,
		|	FinancialResultForecast.Company AS Company,
		|	FinancialResultForecast.PlanningPeriod AS PlanningPeriod,
		|	FinancialResultForecast.StructuralUnit AS StructuralUnit,
		|	FinancialResultForecast.BusinessLine AS BusinessLine,
		|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	FinancialResultForecast.AmountIncome AS AmountIncome,
		|	FinancialResultForecast.AmountExpense AS AmountExpense,
		|	FinancialResultForecast.GLAccount AS GLAccount
		|FROM
		|	AccumulationRegister.FinancialResultForecast AS FinancialResultForecast
		|		INNER JOIN TT_Mapping AS TT_Mapping
		|		ON (FinancialResultForecast.Recorder = &Recorder)
		|			AND FinancialResultForecast.GLAccount = TT_Mapping.GLAccount";
		
	ElsIf QueryNumber = 9 Then
		
		Return
		"SELECT
		|	CompensationPlan.Period AS Period,
		|	CompensationPlan.Recorder AS Recorder,
		|	CompensationPlan.LineNumber AS LineNumber,
		|	CompensationPlan.Active AS Active,
		|	CompensationPlan.Company AS Company,
		|	CompensationPlan.Employee AS Employee,
		|	CompensationPlan.EarningAndDeductionType AS EarningAndDeductionType,
		|	CompensationPlan.Currency AS Currency,
		|	CompensationPlan.Amount AS Amount,
		|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	CompensationPlan.Actuality AS Actuality,
		|	CompensationPlan.GLExpenseAccount AS GLExpenseAccount
		|FROM
		|	InformationRegister.CompensationPlan AS CompensationPlan
		|		INNER JOIN TT_Mapping AS TT_Mapping
		|		ON (CompensationPlan.Recorder = &Recorder)
		|			AND CompensationPlan.GLExpenseAccount = TT_Mapping.GLAccount";
		
	// begin Drive.FullVersion
	ElsIf QueryNumber = 10 Then
		
		Return
		"SELECT
		|	PredeterminedOverheadRates.Period AS Period,
		|	PredeterminedOverheadRates.Recorder AS Recorder,
		|	PredeterminedOverheadRates.LineNumber AS LineNumber,
		|	PredeterminedOverheadRates.Active AS Active,
		|	PredeterminedOverheadRates.Company AS Company,
		|	PredeterminedOverheadRates.Owner AS Owner,
		|	PredeterminedOverheadRates.CostDriver AS CostDriver,
		|	PredeterminedOverheadRates.BusinessUnit AS BusinessUnit,
		|	TT_Mapping.IncomeAndExpenseItem AS ExpenseItem,
		|	PredeterminedOverheadRates.Rate AS Rate,
		|	PredeterminedOverheadRates.OverheadsGLAccount AS OverheadsGLAccount
		|FROM
		|	InformationRegister.PredeterminedOverheadRates AS PredeterminedOverheadRates
		|		INNER JOIN TT_Mapping AS TT_Mapping
		|		ON (PredeterminedOverheadRates.Recorder = &Recorder)
		|			AND PredeterminedOverheadRates.OverheadsGLAccount = TT_Mapping.GLAccount";
	// end Drive.FullVersion
		
	ElsIf QueryNumber = 17 Then
		
		Return
		"SELECT
		|	Inventory.Period AS Period,
		|	Inventory.Recorder AS Recorder,
		|	Inventory.LineNumber AS LineNumber,
		|	Inventory.Active AS Active,
		|	Inventory.RecordType AS RecordType,
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.CostObject AS CostObject,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	Inventory.Quantity AS Quantity,
		|	Inventory.Amount AS Amount,
		|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
		|	Inventory.CorrGLAccount AS CorrGLAccount,
		|	Inventory.ProductsCorr AS ProductsCorr,
		|	Inventory.CharacteristicCorr AS CharacteristicCorr,
		|	Inventory.BatchCorr AS BatchCorr,
		|	Inventory.OwnershipCorr AS OwnershipCorr,
		|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
		|	Inventory.Specification AS Specification,
		|	Inventory.SpecificationCorr AS SpecificationCorr,
		|	Inventory.CorrSalesOrder AS CorrSalesOrder,
		|	Inventory.SourceDocument AS SourceDocument,
		|	Inventory.Department AS Department,
		|	Inventory.Responsible AS Responsible,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.FixedCost AS FixedCost,
		|	Inventory.ProductionExpenses AS ProductionExpenses,
		|	Inventory.Return AS Return,
		|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
		|	Inventory.OfflineRecord AS OfflineRecord,
		|	Inventory.SalesRep AS SalesRep,
		|	Inventory.Counterparty AS Counterparty,
		|	Inventory.Currency AS Currency,
		|	Inventory.SalesOrder AS SalesOrder,
		|	Inventory.CostObjectCorr AS CostObjectCorr,
		|	Inventory.DeleteCostObject AS DeleteCostObject,
		|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	Inventory.GLAccount AS GLAccount,
		|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN Inventory.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN Inventory.Recorder REFS Document.CreditNote
		|			THEN CASE
		|					WHEN Inventory.Amount > 0
		|							OR Inventory.OfflineRecord
		|						THEN ISNULL(TT_Mapping.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|					ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				END
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON Inventory.CorrGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	Inventory.Recorder = &Recorder";
		
	ElsIf QueryNumber = 18 Then
		
		Return
		"SELECT
		|	InventoryCostLayer.Period AS Period,
		|	InventoryCostLayer.Recorder AS Recorder,
		|	InventoryCostLayer.LineNumber AS LineNumber,
		|	InventoryCostLayer.Active AS Active,
		|	InventoryCostLayer.RecordType AS RecordType,
		|	InventoryCostLayer.Company AS Company,
		|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
		|	InventoryCostLayer.Products AS Products,
		|	InventoryCostLayer.Characteristic AS Characteristic,
		|	InventoryCostLayer.Batch AS Batch,
		|	InventoryCostLayer.Ownership AS Ownership,
		|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
		|	InventoryCostLayer.CostObject AS CostObject,
		|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
		|	InventoryCostLayer.CostLayer AS CostLayer,
		|	InventoryCostLayer.Quantity AS Quantity,
		|	InventoryCostLayer.Amount AS Amount,
		|	InventoryCostLayer.SourceRecord AS SourceRecord,
		|	InventoryCostLayer.VATRate AS VATRate,
		|	InventoryCostLayer.Responsible AS Responsible,
		|	InventoryCostLayer.Department AS Department,
		|	InventoryCostLayer.SourceDocument AS SourceDocument,
		|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
		|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
		|	InventoryCostLayer.CorrGLAccount AS CorrGLAccount,
		|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
		|	InventoryCostLayer.SalesRep AS SalesRep,
		|	InventoryCostLayer.Counterparty AS Counterparty,
		|	InventoryCostLayer.Currency AS Currency,
		|	InventoryCostLayer.SalesOrder AS SalesOrder,
		|	InventoryCostLayer.CorrCostObject AS CorrCostObject,
		|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	InventoryCostLayer.CorrProducts AS CorrProducts,
		|	InventoryCostLayer.GLAccount AS GLAccount,
		|	InventoryCostLayer.CorrCharacteristic AS CorrCharacteristic,
		|	InventoryCostLayer.CorrBatch AS CorrBatch,
		|	InventoryCostLayer.CorrOwnership AS CorrOwnership,
		|	InventoryCostLayer.CorrSpecification AS CorrSpecification,
		|	InventoryCostLayer.Specification AS Specification,
		|	InventoryCostLayer.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN InventoryCostLayer.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON InventoryCostLayer.CorrGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	InventoryCostLayer.Recorder = &Recorder";
		
	ElsIf QueryNumber = 19 Then
		
		Return
		"SELECT
		|	LandedCosts.Period AS Period,
		|	LandedCosts.Recorder AS Recorder,
		|	LandedCosts.LineNumber AS LineNumber,
		|	LandedCosts.Active AS Active,
		|	LandedCosts.RecordType AS RecordType,
		|	LandedCosts.Company AS Company,
		|	LandedCosts.PresentationCurrency AS PresentationCurrency,
		|	LandedCosts.Products AS Products,
		|	LandedCosts.Characteristic AS Characteristic,
		|	LandedCosts.Batch AS Batch,
		|	LandedCosts.Ownership AS Ownership,
		|	LandedCosts.StructuralUnit AS StructuralUnit,
		|	LandedCosts.CostObject AS CostObject,
		|	LandedCosts.InventoryAccountType AS InventoryAccountType,
		|	LandedCosts.CostLayer AS CostLayer,
		|	LandedCosts.Amount AS Amount,
		|	LandedCosts.SourceRecord AS SourceRecord,
		|	LandedCosts.VATRate AS VATRate,
		|	LandedCosts.Responsible AS Responsible,
		|	LandedCosts.Department AS Department,
		|	LandedCosts.SourceDocument AS SourceDocument,
		|	LandedCosts.CorrSalesOrder AS CorrSalesOrder,
		|	LandedCosts.CorrStructuralUnit AS CorrStructuralUnit,
		|	LandedCosts.CorrGLAccount AS CorrGLAccount,
		|	LandedCosts.RIMTransfer AS RIMTransfer,
		|	LandedCosts.SalesRep AS SalesRep,
		|	LandedCosts.Counterparty AS Counterparty,
		|	LandedCosts.Currency AS Currency,
		|	LandedCosts.SalesOrder AS SalesOrder,
		|	LandedCosts.CorrCostObject AS CorrCostObject,
		|	LandedCosts.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	LandedCosts.CorrProducts AS CorrProducts,
		|	LandedCosts.GLAccount AS GLAccount,
		|	LandedCosts.CorrCharacteristic AS CorrCharacteristic,
		|	LandedCosts.CorrBatch AS CorrBatch,
		|	LandedCosts.CorrOwnership AS CorrOwnership,
		|	LandedCosts.CorrSpecification AS CorrSpecification,
		|	LandedCosts.Specification AS Specification,
		|	LandedCosts.IncomeAndExpenseItem AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN LandedCosts.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.LandedCosts AS LandedCosts
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON LandedCosts.CorrGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	LandedCosts.Recorder = &Recorder";
		
	ElsIf QueryNumber = 20 Then
		
		Return
		"SELECT DISTINCT
		|	Inventory.Period AS Period,
		|	Inventory.Recorder AS Recorder,
		|	Inventory.LineNumber AS LineNumber,
		|	Inventory.Active AS Active,
		|	Inventory.RecordType AS RecordType,
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.CostObject AS CostObject,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	Inventory.Quantity AS Quantity,
		|	Inventory.Amount AS Amount,
		|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
		|	Inventory.CorrGLAccount AS CorrGLAccount,
		|	Inventory.ProductsCorr AS ProductsCorr,
		|	Inventory.CharacteristicCorr AS CharacteristicCorr,
		|	Inventory.BatchCorr AS BatchCorr,
		|	Inventory.OwnershipCorr AS OwnershipCorr,
		|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
		|	Inventory.Specification AS Specification,
		|	Inventory.SpecificationCorr AS SpecificationCorr,
		|	Inventory.CorrSalesOrder AS CorrSalesOrder,
		|	Inventory.SourceDocument AS SourceDocument,
		|	Inventory.Department AS Department,
		|	Inventory.Responsible AS Responsible,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.FixedCost AS FixedCost,
		|	Inventory.ProductionExpenses AS ProductionExpenses,
		|	Inventory.Return AS Return,
		|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
		|	Inventory.OfflineRecord AS OfflineRecord,
		|	Inventory.SalesRep AS SalesRep,
		|	Inventory.Counterparty AS Counterparty,
		|	Inventory.Currency AS Currency,
		|	Inventory.SalesOrder AS SalesOrder,
		|	Inventory.CostObjectCorr AS CostObjectCorr,
		|	Inventory.DeleteCostObject AS DeleteCostObject,
		|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	Inventory.GLAccount AS GLAccount,
		|	CASE
		|		WHEN Inventory.GLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping1.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN Inventory.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping2.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping1
		|		ON Inventory.GLAccount = TT_Mapping1.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_Mapping2
		|		ON Inventory.CorrGLAccount = TT_Mapping2.GLAccount
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON Inventory.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
		|		ON Inventory.Recorder = GoodsIssueProducts.Ref
		|			AND Inventory.Products = GoodsIssueProducts.Products
		|			AND Inventory.Characteristic = GoodsIssueProducts.Characteristic
		|			AND Inventory.Batch = GoodsIssueProducts.Batch
		|WHERE
		|	Inventory.Recorder = &Recorder";
		
	ElsIf QueryNumber = 21 Then
		
		Return
		"SELECT
		|	InventoryCostLayer.Period AS Period,
		|	InventoryCostLayer.Recorder AS Recorder,
		|	InventoryCostLayer.LineNumber AS LineNumber,
		|	InventoryCostLayer.Active AS Active,
		|	InventoryCostLayer.RecordType AS RecordType,
		|	InventoryCostLayer.Company AS Company,
		|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
		|	InventoryCostLayer.Products AS Products,
		|	InventoryCostLayer.Characteristic AS Characteristic,
		|	InventoryCostLayer.Batch AS Batch,
		|	InventoryCostLayer.Ownership AS Ownership,
		|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
		|	InventoryCostLayer.CostObject AS CostObject,
		|	InventoryCostLayer.CostLayer AS CostLayer,
		|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
		|	InventoryCostLayer.Quantity AS Quantity,
		|	InventoryCostLayer.Amount AS Amount,
		|	InventoryCostLayer.SourceRecord AS SourceRecord,
		|	InventoryCostLayer.VATRate AS VATRate,
		|	InventoryCostLayer.Responsible AS Responsible,
		|	InventoryCostLayer.Department AS Department,
		|	InventoryCostLayer.SourceDocument AS SourceDocument,
		|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
		|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
		|	InventoryCostLayer.CorrGLAccount AS CorrGLAccount,
		|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
		|	InventoryCostLayer.SalesRep AS SalesRep,
		|	InventoryCostLayer.Counterparty AS Counterparty,
		|	InventoryCostLayer.Currency AS Currency,
		|	InventoryCostLayer.SalesOrder AS SalesOrder,
		|	InventoryCostLayer.CorrCostObject AS CorrCostObject,
		|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	InventoryCostLayer.CorrProducts AS CorrProducts,
		|	InventoryCostLayer.GLAccount AS GLAccount,
		|	InventoryCostLayer.CorrCharacteristic AS CorrCharacteristic,
		|	InventoryCostLayer.CorrBatch AS CorrBatch,
		|	InventoryCostLayer.CorrOwnership AS CorrOwnership,
		|	InventoryCostLayer.CorrSpecification AS CorrSpecification,
		|	InventoryCostLayer.Specification AS Specification,
		|	CASE
		|		WHEN InventoryCostLayer.GLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping1.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN InventoryCostLayer.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping2.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
		|		LEFT JOIN TT_Mapping AS TT_Mapping1
		|		ON InventoryCostLayer.GLAccount = TT_Mapping1.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_Mapping2
		|		ON InventoryCostLayer.CorrGLAccount = TT_Mapping2.GLAccount
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON InventoryCostLayer.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
		|		ON InventoryCostLayer.Recorder = GoodsIssueProducts.Ref
		|			AND InventoryCostLayer.Products = GoodsIssueProducts.Products
		|			AND InventoryCostLayer.Characteristic = GoodsIssueProducts.Characteristic
		|			AND InventoryCostLayer.Batch = GoodsIssueProducts.Batch
		|WHERE
		|	InventoryCostLayer.Recorder = &Recorder";
		
	ElsIf QueryNumber = 22 Then
		
		Return
		"SELECT
		|	LandedCosts.Period AS Period,
		|	LandedCosts.Recorder AS Recorder,
		|	LandedCosts.LineNumber AS LineNumber,
		|	LandedCosts.Active AS Active,
		|	LandedCosts.RecordType AS RecordType,
		|	LandedCosts.Company AS Company,
		|	LandedCosts.PresentationCurrency AS PresentationCurrency,
		|	LandedCosts.Products AS Products,
		|	LandedCosts.Characteristic AS Characteristic,
		|	LandedCosts.Batch AS Batch,
		|	LandedCosts.Ownership AS Ownership,
		|	LandedCosts.StructuralUnit AS StructuralUnit,
		|	LandedCosts.CostObject AS CostObject,
		|	LandedCosts.CostLayer AS CostLayer,
		|	LandedCosts.InventoryAccountType AS InventoryAccountType,
		|	LandedCosts.Amount AS Amount,
		|	LandedCosts.SourceRecord AS SourceRecord,
		|	LandedCosts.VATRate AS VATRate,
		|	LandedCosts.Responsible AS Responsible,
		|	LandedCosts.Department AS Department,
		|	LandedCosts.SourceDocument AS SourceDocument,
		|	LandedCosts.CorrSalesOrder AS CorrSalesOrder,
		|	LandedCosts.CorrStructuralUnit AS CorrStructuralUnit,
		|	LandedCosts.CorrGLAccount AS CorrGLAccount,
		|	LandedCosts.RIMTransfer AS RIMTransfer,
		|	LandedCosts.SalesRep AS SalesRep,
		|	LandedCosts.Counterparty AS Counterparty,
		|	LandedCosts.Currency AS Currency,
		|	LandedCosts.SalesOrder AS SalesOrder,
		|	LandedCosts.CorrCostObject AS CorrCostObject,
		|	LandedCosts.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	LandedCosts.CorrProducts AS CorrProducts,
		|	LandedCosts.GLAccount AS GLAccount,
		|	LandedCosts.CorrCharacteristic AS CorrCharacteristic,
		|	LandedCosts.CorrBatch AS CorrBatch,
		|	LandedCosts.CorrOwnership AS CorrOwnership,
		|	LandedCosts.CorrSpecification AS CorrSpecification,
		|	LandedCosts.Specification AS Specification,
		|	CASE
		|		WHEN LandedCosts.GLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping1.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN LandedCosts.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping2.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.LandedCosts AS LandedCosts
		|		LEFT JOIN TT_Mapping AS TT_Mapping1
		|		ON LandedCosts.GLAccount = TT_Mapping1.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_Mapping2
		|		ON LandedCosts.CorrGLAccount = TT_Mapping2.GLAccount
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON LandedCosts.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
		|		ON LandedCosts.Recorder = GoodsIssueProducts.Ref
		|			AND LandedCosts.Products = GoodsIssueProducts.Products
		|			AND LandedCosts.Characteristic = GoodsIssueProducts.Characteristic
		|			AND LandedCosts.Batch = GoodsIssueProducts.Batch
		|WHERE
		|	LandedCosts.Recorder = &Recorder";
		
	ElsIf QueryNumber = 23 Then
		
		Return
		"SELECT
		|	Inventory.Period AS Period,
		|	Inventory.Recorder AS Recorder,
		|	Inventory.LineNumber AS LineNumber,
		|	Inventory.Active AS Active,
		|	Inventory.RecordType AS RecordType,
		|	Inventory.Company AS Company,
		|	Inventory.PresentationCurrency AS PresentationCurrency,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.Ownership AS Ownership,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.CostObject AS CostObject,
		|	Inventory.InventoryAccountType AS InventoryAccountType,
		|	Inventory.Quantity AS Quantity,
		|	Inventory.Amount AS Amount,
		|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
		|	Inventory.CorrGLAccount AS CorrGLAccount,
		|	Inventory.ProductsCorr AS ProductsCorr,
		|	Inventory.CharacteristicCorr AS CharacteristicCorr,
		|	Inventory.BatchCorr AS BatchCorr,
		|	Inventory.OwnershipCorr AS OwnershipCorr,
		|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
		|	Inventory.Specification AS Specification,
		|	Inventory.SpecificationCorr AS SpecificationCorr,
		|	Inventory.CorrSalesOrder AS CorrSalesOrder,
		|	Inventory.SourceDocument AS SourceDocument,
		|	Inventory.Department AS Department,
		|	Inventory.Responsible AS Responsible,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.FixedCost AS FixedCost,
		|	Inventory.ProductionExpenses AS ProductionExpenses,
		|	Inventory.Return AS Return,
		|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
		|	Inventory.OfflineRecord AS OfflineRecord,
		|	Inventory.SalesRep AS SalesRep,
		|	Inventory.Counterparty AS Counterparty,
		|	Inventory.Currency AS Currency,
		|	Inventory.SalesOrder AS SalesOrder,
		|	Inventory.CostObjectCorr AS CostObjectCorr,
		|	Inventory.DeleteCostObject AS DeleteCostObject,
		|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	Inventory.GLAccount AS GLAccount,
		|	CASE
		|		WHEN Inventory.GLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN TT_Mapping1.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping1.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN Inventory.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN TT_Mapping2.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping2.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping1
		|		ON Inventory.GLAccount = TT_Mapping1.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_Mapping2
		|		ON Inventory.CorrGLAccount = TT_Mapping2.GLAccount
		|WHERE
		|	Inventory.Recorder = &Recorder";
		
	ElsIf QueryNumber = 24 Then
		
		Return
		"SELECT
		|	InventoryCostLayer.Period AS Period,
		|	InventoryCostLayer.Recorder AS Recorder,
		|	InventoryCostLayer.LineNumber AS LineNumber,
		|	InventoryCostLayer.Active AS Active,
		|	InventoryCostLayer.RecordType AS RecordType,
		|	InventoryCostLayer.Company AS Company,
		|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
		|	InventoryCostLayer.Products AS Products,
		|	InventoryCostLayer.Characteristic AS Characteristic,
		|	InventoryCostLayer.Batch AS Batch,
		|	InventoryCostLayer.Ownership AS Ownership,
		|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
		|	InventoryCostLayer.CostObject AS CostObject,
		|	InventoryCostLayer.CostLayer AS CostLayer,
		|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
		|	InventoryCostLayer.Quantity AS Quantity,
		|	InventoryCostLayer.Amount AS Amount,
		|	InventoryCostLayer.SourceRecord AS SourceRecord,
		|	InventoryCostLayer.VATRate AS VATRate,
		|	InventoryCostLayer.Responsible AS Responsible,
		|	InventoryCostLayer.Department AS Department,
		|	InventoryCostLayer.SourceDocument AS SourceDocument,
		|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
		|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
		|	InventoryCostLayer.CorrGLAccount AS CorrGLAccount,
		|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
		|	InventoryCostLayer.SalesRep AS SalesRep,
		|	InventoryCostLayer.Counterparty AS Counterparty,
		|	InventoryCostLayer.Currency AS Currency,
		|	InventoryCostLayer.SalesOrder AS SalesOrder,
		|	InventoryCostLayer.CorrCostObject AS CorrCostObject,
		|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	InventoryCostLayer.CorrProducts AS CorrProducts,
		|	InventoryCostLayer.GLAccount AS GLAccount,
		|	InventoryCostLayer.CorrCharacteristic AS CorrCharacteristic,
		|	InventoryCostLayer.CorrBatch AS CorrBatch,
		|	InventoryCostLayer.CorrOwnership AS CorrOwnership,
		|	InventoryCostLayer.CorrSpecification AS CorrSpecification,
		|	InventoryCostLayer.Specification AS Specification,
		|	CASE
		|		WHEN InventoryCostLayer.GLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN TT_Mapping1.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping1.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN InventoryCostLayer.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN TT_Mapping2.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping2.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
		|		LEFT JOIN TT_Mapping AS TT_Mapping1
		|		ON InventoryCostLayer.GLAccount = TT_Mapping1.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_Mapping2
		|		ON InventoryCostLayer.CorrGLAccount = TT_Mapping2.GLAccount
		|WHERE
		|	InventoryCostLayer.Recorder = &Recorder";
		
	ElsIf QueryNumber = 25 Then
		
		Return
		"SELECT
		|	LandedCosts.Period AS Period,
		|	LandedCosts.Recorder AS Recorder,
		|	LandedCosts.LineNumber AS LineNumber,
		|	LandedCosts.Active AS Active,
		|	LandedCosts.RecordType AS RecordType,
		|	LandedCosts.Company AS Company,
		|	LandedCosts.PresentationCurrency AS PresentationCurrency,
		|	LandedCosts.Products AS Products,
		|	LandedCosts.Characteristic AS Characteristic,
		|	LandedCosts.Batch AS Batch,
		|	LandedCosts.Ownership AS Ownership,
		|	LandedCosts.StructuralUnit AS StructuralUnit,
		|	LandedCosts.CostObject AS CostObject,
		|	LandedCosts.CostLayer AS CostLayer,
		|	LandedCosts.InventoryAccountType AS InventoryAccountType,
		|	LandedCosts.Amount AS Amount,
		|	LandedCosts.SourceRecord AS SourceRecord,
		|	LandedCosts.VATRate AS VATRate,
		|	LandedCosts.Responsible AS Responsible,
		|	LandedCosts.Department AS Department,
		|	LandedCosts.SourceDocument AS SourceDocument,
		|	LandedCosts.CorrSalesOrder AS CorrSalesOrder,
		|	LandedCosts.CorrStructuralUnit AS CorrStructuralUnit,
		|	LandedCosts.CorrGLAccount AS CorrGLAccount,
		|	LandedCosts.RIMTransfer AS RIMTransfer,
		|	LandedCosts.SalesRep AS SalesRep,
		|	LandedCosts.Counterparty AS Counterparty,
		|	LandedCosts.Currency AS Currency,
		|	LandedCosts.SalesOrder AS SalesOrder,
		|	LandedCosts.CorrCostObject AS CorrCostObject,
		|	LandedCosts.CorrInventoryAccountType AS CorrInventoryAccountType,
		|	LandedCosts.CorrProducts AS CorrProducts,
		|	LandedCosts.GLAccount AS GLAccount,
		|	LandedCosts.CorrCharacteristic AS CorrCharacteristic,
		|	LandedCosts.CorrBatch AS CorrBatch,
		|	LandedCosts.CorrOwnership AS CorrOwnership,
		|	LandedCosts.CorrSpecification AS CorrSpecification,
		|	LandedCosts.Specification AS Specification,
		|	CASE
		|		WHEN LandedCosts.GLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN TT_Mapping1.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping1.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS IncomeAndExpenseItem,
		|	CASE
		|		WHEN LandedCosts.CorrGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN TT_Mapping2.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping2.IncomeAndExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef))
		|	END AS CorrIncomeAndExpenseItem
		|FROM
		|	AccumulationRegister.LandedCosts AS LandedCosts
		|		LEFT JOIN TT_Mapping AS TT_Mapping1
		|		ON LandedCosts.GLAccount = TT_Mapping1.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_Mapping2
		|		ON LandedCosts.CorrGLAccount = TT_Mapping2.GLAccount
		|WHERE
		|	LandedCosts.Recorder = &Recorder";
		
	ElsIf QueryNumber = 26 Then
		
		Return
		"SELECT
		|	TT_Mapping.GLAccount AS GLAccount,
		|	TT_Mapping.IncomeAndExpenseItem AS IncomeAndExpenseItem
		|FROM
		|	Document.SalesOrder.Estimate AS SalesOrderEstimate
		|		INNER JOIN TT_Mapping AS TT_Mapping
		|		ON SalesOrderEstimate.Products = TT_Mapping.GLAccount
		|WHERE
		|	SalesOrderEstimate.Ref = &Ref";
		
	EndIf;
	
EndFunction

Function GetRegisterManager(QueryNumber)
	
	If QueryNumber = 4 Then
		Return AccumulationRegisters.IncomeAndExpenses;
		
	ElsIf QueryNumber = 5 Then
		Return AccumulationRegisters.IncomeAndExpensesBudget;
		
	ElsIf QueryNumber = 6 Then
		Return InformationRegisters.FixedAssetParameters;
		
	ElsIf QueryNumber = 7 Then
		Return AccumulationRegisters.FinancialResult;
		
	ElsIf QueryNumber = 8 Then
		Return AccumulationRegisters.FinancialResultForecast;
		
	ElsIf QueryNumber = 9 Then
		Return InformationRegisters.CompensationPlan;
		
	// begin Drive.FullVersion
	ElsIf QueryNumber = 10 Then
		Return InformationRegisters.PredeterminedOverheadRates;
	// end Drive.FullVersion
	ElsIf QueryNumber = 11 Then
		Return InformationRegisters.CounterpartyIncomeAndExpenseItems;
		
	ElsIf QueryNumber = 12 Then
		Return InformationRegisters.ProductIncomeAndExpenseItems;
		
	ElsIf QueryNumber = 17 Or QueryNumber = 20 Or QueryNumber = 23 Then
		Return AccumulationRegisters.Inventory;
		
	ElsIf QueryNumber = 18 Or QueryNumber = 21 Or QueryNumber = 24 Then
		Return AccumulationRegisters.InventoryCostLayer;
		
	ElsIf QueryNumber = 19 Or QueryNumber = 22 Or QueryNumber = 25 Then
		Return AccumulationRegisters.LandedCosts;
		
	EndIf;
	
EndFunction

Function GetDefaultItemTable()
	
	ItemTable = New ValueTable;
	ItemTable.Columns.Add("DefaultGLAccount", New TypeDescription("CatalogRef.DefaultGLAccounts"));
	ItemTable.Columns.Add("DefaultIncomeAndExpenseItem", New TypeDescription("CatalogRef.DefaultIncomeAndExpenseItems"));
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.BankFeesExpenseAccount;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.BankFees;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.CostOfSales;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.CostOfSales;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.DiscountAllowed;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.DiscountAllowed;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.DiscountReceived;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.DiscountReceived;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.Expenses;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.Expenses;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.ForeignCurrencyExchangeLoss;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.FXExpenses;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.ForeignCurrencyExchangeGain;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.FXIncome;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.InterestExpensesOnLoansBorrowed;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.InterestExpenses;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.InterestIncome;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.InterestIncome;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.OtherIncome;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.OtherIncome;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.PayrollExpenses;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.PayrollExpenses;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.CommissionExpensesOnLoansBorrowed;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.LoanCommissionExpenses;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.CommissionIncomeOnLoansLent;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.LoanCommissionIncome;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.Expenses;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.DepreciationCharge;
	
	NewRow = ItemTable.Add();
	NewRow.DefaultGLAccount = Catalogs.DefaultGLAccounts.PurchaseCostDiscrepancies;
	NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.PurchaseCostDiscrepancies;
	
	Return ItemTable;
	
EndFunction

Procedure DocumentsAttributesMapping(TempTablesManager)
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("Undefined", Catalogs.IncomeAndExpenseItems.EmptyRef());
	Query.SetParameter("GLAccountCostOfSales", Common.ObjectAttributeValue(Catalogs.LinesOfBusiness.Other, "GLAccountCostOfSales"));
	Query.SetParameter("GLAccountRevenueFromSales", Common.ObjectAttributeValue(Catalogs.LinesOfBusiness.Other, "GLAccountRevenueFromSales"));
	Query.SetParameter("EmptyAccount", ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef());
	Query.SetParameter("FeeExpensesGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses"));
	Query.SetParameter("Revenue", Catalogs.DefaultIncomeAndExpenseItems.GetItem("Revenue"));
	
	TypeOfAccounts = New Array;
	TypeOfAccounts.Add(Enums.GLAccountsTypes.CostOfSales);
	TypeOfAccounts.Add(Enums.GLAccountsTypes.Expenses);
	TypeOfAccounts.Add(Enums.GLAccountsTypes.IndirectExpenses);
	TypeOfAccounts.Add(Enums.GLAccountsTypes.OtherExpenses);
	TypeOfAccounts.Add(Enums.GLAccountsTypes.OtherIncome);
	TypeOfAccounts.Add(Enums.GLAccountsTypes.Revenue);
	Query.SetParameter("TypeOfAccounts", TypeOfAccounts);
	
	For QueryNumber = 0 To 57 Do
		Query.Text = DocumentsAttributesQueryText(QueryNumber);
		
		If IsBlankString(Query.Text) Then
			Continue;
		EndIf;
		
		QueryResult = Query.Execute();
		
		SelectionDoc = QueryResult.Select(QueryResultIteration.ByGroups);
		While SelectionDoc.Next() Do
			
			DocumentObj = SelectionDoc.DocumentRef.GetObject();
			If SelectionDoc.Mark = 0 Then
				TabularSection = DocumentObj[SelectionDoc.TabularSection];
				TabularSection.Clear();
				
				Selection = SelectionDoc.Select();
				While Selection.Next() Do
					NewRow = TabularSection.Add();
					FillPropertyValues(NewRow, Selection,,"LineNumber");
				EndDo;
			Else
				Selection = SelectionDoc.Select();
				If Selection.Next() Then
					FillPropertyValues(DocumentObj, Selection);
				EndIf;
			EndIf;
			
			InfobaseUpdate.WriteObject(DocumentObj,,,DocumentWriteMode.Write);
			
		EndDo;
	EndDo;
	
EndProcedure

Function DocumentsAttributesQueryText(QueryNumber)
	
	// Mark = 0 - only in TabularSection
	// Mark = 1 - only in Head
	
	Text = "";
	
	If QueryNumber = 0 Then
		
		Text = "SELECT DISTINCT
		|	AccountSalesFromConsigneeInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.AccountSalesFromConsignee.Inventory AS AccountSalesFromConsigneeInventory
		|		LEFT JOIN TT_Mapping AS TT_MappingRevenue
		|		ON AccountSalesFromConsigneeInventory.RevenueGLAccount = TT_MappingRevenue.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON AccountSalesFromConsigneeInventory.COGSGLAccount = TT_MappingCOGS.GLAccount
		|WHERE
		|	(CASE
		|				WHEN AccountSalesFromConsigneeInventory.RevenueGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingRevenue.IncomeAndExpenseItem, &Undefined)
		|			END <> AccountSalesFromConsigneeInventory.RevenueItem
		|			OR CASE
		|				WHEN AccountSalesFromConsigneeInventory.COGSGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> AccountSalesFromConsigneeInventory.COGSItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountSalesFromConsigneeInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN AccountSalesFromConsigneeInventory.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingRevenue.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	CASE
		|		WHEN AccountSalesFromConsigneeInventory.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS COGSItem,
		|	AccountSalesFromConsigneeInventory.LineNumber AS LineNumber,
		|	AccountSalesFromConsigneeInventory.Products AS Products,
		|	AccountSalesFromConsigneeInventory.Characteristic AS Characteristic,
		|	AccountSalesFromConsigneeInventory.Batch AS Batch,
		|	AccountSalesFromConsigneeInventory.Quantity AS Quantity,
		|	AccountSalesFromConsigneeInventory.MeasurementUnit AS MeasurementUnit,
		|	AccountSalesFromConsigneeInventory.Price AS Price,
		|	AccountSalesFromConsigneeInventory.Amount AS Amount,
		|	AccountSalesFromConsigneeInventory.VATRate AS VATRate,
		|	AccountSalesFromConsigneeInventory.VATAmount AS VATAmount,
		|	AccountSalesFromConsigneeInventory.Total AS Total,
		|	AccountSalesFromConsigneeInventory.TransmissionPrice AS TransmissionPrice,
		|	AccountSalesFromConsigneeInventory.TransmissionAmount AS TransmissionAmount,
		|	AccountSalesFromConsigneeInventory.TransmissionVATAmount AS TransmissionVATAmount,
		|	AccountSalesFromConsigneeInventory.BrokerageAmount AS BrokerageAmount,
		|	AccountSalesFromConsigneeInventory.BrokerageVATAmount AS BrokerageVATAmount,
		|	AccountSalesFromConsigneeInventory.SalesOrder AS SalesOrder,
		|	AccountSalesFromConsigneeInventory.ConnectionKey AS ConnectionKey,
		|	AccountSalesFromConsigneeInventory.SerialNumbers AS SerialNumbers,
		|	AccountSalesFromConsigneeInventory.ConnectionKeySerialNumbers AS ConnectionKeySerialNumbers,
		|	AccountSalesFromConsigneeInventory.SalesRep AS SalesRep,
		|	AccountSalesFromConsigneeInventory.InventoryTransferredGLAccount AS InventoryTransferredGLAccount,
		|	AccountSalesFromConsigneeInventory.VATOutputGLAccount AS VATOutputGLAccount,
		|	AccountSalesFromConsigneeInventory.RevenueGLAccount AS RevenueGLAccount,
		|	AccountSalesFromConsigneeInventory.COGSGLAccount AS COGSGLAccount,
		|	AccountSalesFromConsigneeInventory.Ownership AS Ownership,
		|	AccountSalesFromConsigneeInventory.Project AS Project
		|FROM
		|	Document.AccountSalesFromConsignee.Inventory AS AccountSalesFromConsigneeInventory
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON AccountSalesFromConsigneeInventory.Ref = TT_Refs.DocumentRef
		|		LEFT JOIN TT_Mapping AS TT_MappingRevenue
		|		ON AccountSalesFromConsigneeInventory.RevenueGLAccount = TT_MappingRevenue.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON AccountSalesFromConsigneeInventory.COGSGLAccount = TT_MappingCOGS.GLAccount
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 1 Then
		
		Text = "SELECT DISTINCT
		|	AccountSalesToConsignorInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
		|		LEFT JOIN TT_Mapping AS TT_MappingRevenue
		|		ON (ISNULL(AccountSalesToConsignorInventory.Products.BusinessLine.GLAccountRevenueFromSales, &EmptyAccount) = TT_MappingRevenue.GLAccount)
		|WHERE
		|	CASE
		|			WHEN ISNULL(AccountSalesToConsignorInventory.Products.BusinessLine.GLAccountRevenueFromSales, &EmptyAccount) = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_MappingRevenue.IncomeAndExpenseItem, &Undefined)
		|		END <> AccountSalesToConsignorInventory.RevenueItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountSalesToConsignorInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN ISNULL(AccountSalesToConsignorInventory.Products.BusinessLine.GLAccountRevenueFromSales, &EmptyAccount) = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingRevenue.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	AccountSalesToConsignorInventory.LineNumber AS LineNumber,
		|	AccountSalesToConsignorInventory.Products AS Products,
		|	AccountSalesToConsignorInventory.Characteristic AS Characteristic,
		|	AccountSalesToConsignorInventory.Batch AS Batch,
		|	AccountSalesToConsignorInventory.Quantity AS Quantity,
		|	AccountSalesToConsignorInventory.MeasurementUnit AS MeasurementUnit,
		|	AccountSalesToConsignorInventory.Price AS Price,
		|	AccountSalesToConsignorInventory.Amount AS Amount,
		|	AccountSalesToConsignorInventory.VATRate AS VATRate,
		|	AccountSalesToConsignorInventory.VATAmount AS VATAmount,
		|	AccountSalesToConsignorInventory.Total AS Total,
		|	AccountSalesToConsignorInventory.SalesOrder AS SalesOrder,
		|	AccountSalesToConsignorInventory.ReceiptPrice AS ReceiptPrice,
		|	AccountSalesToConsignorInventory.AmountReceipt AS AmountReceipt,
		|	AccountSalesToConsignorInventory.ReceiptVATAmount AS ReceiptVATAmount,
		|	AccountSalesToConsignorInventory.PurchaseOrder AS PurchaseOrder,
		|	AccountSalesToConsignorInventory.BrokerageAmount AS BrokerageAmount,
		|	AccountSalesToConsignorInventory.BrokerageVATAmount AS BrokerageVATAmount,
		|	AccountSalesToConsignorInventory.Customer AS Customer,
		|	AccountSalesToConsignorInventory.DateOfSale AS DateOfSale,
		|	AccountSalesToConsignorInventory.SerialNumbers AS SerialNumbers,
		|	AccountSalesToConsignorInventory.ConnectionKey AS ConnectionKey,
		|	AccountSalesToConsignorInventory.SalesRep AS SalesRep,
		|	AccountSalesToConsignorInventory.Ownership AS Ownership,
		|	AccountSalesToConsignorInventory.Project AS Project
		|FROM
		|	Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
		|		LEFT JOIN TT_Mapping AS TT_MappingRevenue
		|		ON (ISNULL(AccountSalesToConsignorInventory.Products.BusinessLine.GLAccountRevenueFromSales, &EmptyAccount) = TT_MappingRevenue.GLAccount)
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON AccountSalesToConsignorInventory.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 2 Then
		
		Text = "SELECT
		|	BankReconciliation.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN BankReconciliation.ServiceChargeAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN BankReconciliation.InterestEarnedAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingIncome.IncomeAndExpenseItem, &Undefined)
		|	END AS IncomeItem
		|FROM
		|	Document.BankReconciliation AS BankReconciliation
		|		LEFT JOIN TT_Mapping AS TT_MappingExpense
		|		ON BankReconciliation.ServiceChargeAccount = TT_MappingExpense.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingIncome
		|		ON BankReconciliation.InterestEarnedAccount = TT_MappingIncome.GLAccount
		|WHERE
		|	(CASE
		|				WHEN BankReconciliation.ServiceChargeAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|			END <> BankReconciliation.ExpenseItem
		|			OR CASE
		|				WHEN BankReconciliation.InterestEarnedAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingIncome.IncomeAndExpenseItem, &Undefined)
		|			END <> BankReconciliation.IncomeItem)
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 3 Then
		
		Text = "SELECT DISTINCT
		|	BudgetIncomings.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.Budget.Incomings AS BudgetIncomings
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON BudgetIncomings.Account = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN BudgetIncomings.Account = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> BudgetIncomings.IncomeItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BudgetIncomings.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Incomings"" AS TabularSection,
		|	CASE
		|		WHEN BudgetIncomings.Account = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS IncomeItem,
		|	BudgetIncomings.LineNumber AS LineNumber,
		|	BudgetIncomings.PlanningDate AS PlanningDate,
		|	BudgetIncomings.Account AS Account,
		|	BudgetIncomings.Amount AS Amount,
		|	BudgetIncomings.CorrAccount AS CorrAccount,
		|	BudgetIncomings.BusinessLine AS BusinessLine,
		|	BudgetIncomings.StructuralUnit AS StructuralUnit,
		|	BudgetIncomings.SalesOrder AS SalesOrder,
		|	BudgetIncomings.Comment AS Comment
		|FROM
		|	Document.Budget.Incomings AS BudgetIncomings
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON BudgetIncomings.Account = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON BudgetIncomings.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 4 Then
		
		Text = "SELECT DISTINCT
		|	BudgetExpenses.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.Budget.Expenses AS BudgetExpenses
		|		LEFT JOIN TT_Mapping AS TT_MappingExpenses
		|		ON BudgetExpenses.Account = TT_MappingExpenses.GLAccount
		|WHERE
		|	CASE
		|			WHEN BudgetExpenses.Account = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_MappingExpenses.IncomeAndExpenseItem, &Undefined)
		|		END <> BudgetExpenses.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BudgetExpenses.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Expenses"" AS TabularSection,
		|	CASE
		|		WHEN BudgetExpenses.Account = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingExpenses.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	BudgetExpenses.LineNumber AS LineNumber,
		|	BudgetExpenses.PlanningDate AS PlanningDate,
		|	BudgetExpenses.Account AS Account,
		|	BudgetExpenses.CorrAccount AS CorrAccount,
		|	BudgetExpenses.Amount AS Amount,
		|	BudgetExpenses.BusinessLine AS BusinessLine,
		|	BudgetExpenses.StructuralUnit AS StructuralUnit,
		|	BudgetExpenses.SalesOrder AS SalesOrder,
		|	BudgetExpenses.Comment AS Comment
		|FROM
		|	Document.Budget.Expenses AS BudgetExpenses
		|		LEFT JOIN TT_Mapping AS TT_MappingExpenses
		|		ON BudgetExpenses.Account = TT_MappingExpenses.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON BudgetExpenses.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 5 Then
		
		Text = "SELECT
		|	CashReceipt.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN CashReceipt.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS IncomeItem
		|FROM
		|	Document.CashReceipt AS CashReceipt
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CashReceipt.Correspondence = TT_Mapping.GLAccount
		|WHERE
		|	CashReceipt.OperationKind <> VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
		|	AND CASE
		|			WHEN CashReceipt.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> CashReceipt.IncomeItem
		|
		|UNION ALL
		|
		|SELECT
		|	CashReceipt.Ref,
		|	1,
		|	&Revenue
		|FROM
		|	Document.CashReceipt AS CashReceipt
		|WHERE
		|	CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
		|	AND &Revenue <> CashReceipt.IncomeItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 6 Then
		
		Text = "SELECT
		|	CashVoucher.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN CashVoucher.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem
		|FROM
		|	Document.CashVoucher AS CashVoucher
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CashVoucher.Correspondence = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN CashVoucher.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> CashVoucher.ExpenseItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	// begin Drive.FullVersion
	ElsIf QueryNumber = 7 Then
		
		Text = "SELECT DISTINCT
		|	CostAllocationCosts.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.CostAllocation.Costs AS CostAllocationCosts
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CostAllocationCosts.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN CostAllocationCosts.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> CostAllocationCosts.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CostAllocationCosts.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Costs"" AS TabularSection,
		|	CASE
		|		WHEN CostAllocationCosts.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CostAllocationCosts.LineNumber AS LineNumber,
		|	CostAllocationCosts.GLExpenseAccount AS GLExpenseAccount,
		|	CostAllocationCosts.SalesOrder AS SalesOrder,
		|	CostAllocationCosts.Amount AS Amount,
		|	CostAllocationCosts.ConnectionKey AS ConnectionKey
		|FROM
		|	Document.CostAllocation.Costs AS CostAllocationCosts
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CostAllocationCosts.GLExpenseAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON CostAllocationCosts.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	// end Drive.FullVersion
	ElsIf QueryNumber = 8 Then
		
		Text = "SELECT
		|	CreditNote.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN CreditNote.GLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem
		|FROM
		|	Document.CreditNote AS CreditNote
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CreditNote.GLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CreditNote.OperationKind <> VALUE(Enum.OperationTypesCreditNote.SalesReturn)
		|	AND CASE
		|			WHEN CreditNote.GLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> CreditNote.ExpenseItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 9 Then
		
		Text = "SELECT DISTINCT
		|	CreditNoteInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.CreditNote.Inventory AS CreditNoteInventory
		|		INNER JOIN Document.CreditNote AS CreditNote
		|		ON CreditNoteInventory.Ref = CreditNote.Ref
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CreditNoteInventory.SalesReturnGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON CreditNoteInventory.COGSGLAccount = TT_MappingCOGS.GLAccount
		|WHERE
		|	CreditNote.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
		|	AND (CASE
		|				WHEN CreditNoteInventory.SalesReturnGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> CreditNoteInventory.SalesReturnItem
		|			OR CASE
		|				WHEN CreditNoteInventory.COGSGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> CreditNoteInventory.COGSItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CreditNoteInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN CreditNoteInventory.SalesReturnGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS SalesReturnItem,
		|	CASE
		|		WHEN CreditNoteInventory.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS COGSItem,
		|	CreditNoteInventory.LineNumber AS LineNumber,
		|	CreditNoteInventory.Amount AS Amount,
		|	CreditNoteInventory.Batch AS Batch,
		|	CreditNoteInventory.Characteristic AS Characteristic,
		|	CreditNoteInventory.ConnectionKey AS ConnectionKey,
		|	CreditNoteInventory.CostOfGoodsSold AS CostOfGoodsSold,
		|	CreditNoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	CreditNoteInventory.InitialAmount AS InitialAmount,
		|	CreditNoteInventory.InitialPrice AS InitialPrice,
		|	CreditNoteInventory.InitialQuantity AS InitialQuantity,
		|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
		|	CreditNoteInventory.Order AS Order,
		|	CreditNoteInventory.Price AS Price,
		|	CreditNoteInventory.Products AS Products,
		|	CreditNoteInventory.Quantity AS Quantity,
		|	CreditNoteInventory.SerialNumbers AS SerialNumbers,
		|	CreditNoteInventory.Total AS Total,
		|	CreditNoteInventory.VATAmount AS VATAmount,
		|	CreditNoteInventory.VATRate AS VATRate,
		|	CreditNoteInventory.SalesDocument AS SalesDocument,
		|	CreditNoteInventory.GoodsReceipt AS GoodsReceipt,
		|	CreditNoteInventory.SalesRep AS SalesRep,
		|	CreditNoteInventory.InventoryGLAccount AS InventoryGLAccount,
		|	CreditNoteInventory.VATOutputGLAccount AS VATOutputGLAccount,
		|	CreditNoteInventory.COGSGLAccount AS COGSGLAccount,
		|	CreditNoteInventory.SalesReturnGLAccount AS SalesReturnGLAccount,
		|	CreditNoteInventory.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
		|	CreditNoteInventory.Shipped AS Shipped,
		|	CreditNoteInventory.BundleProduct AS BundleProduct,
		|	CreditNoteInventory.BundleCharacteristic AS BundleCharacteristic,
		|	CreditNoteInventory.CostShare AS CostShare,
		|	CreditNoteInventory.Taxable AS Taxable,
		|	CreditNoteInventory.SalesTaxAmount AS SalesTaxAmount,
		|	CreditNoteInventory.Ownership AS Ownership,
		|	CreditNoteInventory.Project AS Project
		|FROM
		|	Document.CreditNote.Inventory AS CreditNoteInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CreditNoteInventory.SalesReturnGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON CreditNoteInventory.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON CreditNoteInventory.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 10 Then
		
		Text = "SELECT
		|	CustomsDeclaration.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN CustomsDeclaration.OtherDutyGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem
		|FROM
		|	Document.CustomsDeclaration AS CustomsDeclaration
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CustomsDeclaration.OtherDutyGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN CustomsDeclaration.OtherDutyGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> CustomsDeclaration.ExpenseItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 11 Then
		
		Text = "SELECT
		|	DebitNote.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN DebitNote.GLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS IncomeItem
		|FROM
		|	Document.DebitNote AS DebitNote
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON DebitNote.GLAccount = TT_Mapping.GLAccount
		|WHERE
		|	DebitNote.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
		|	AND CASE
		|			WHEN DebitNote.GLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> DebitNote.IncomeItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 12 Then
		
		Text = "SELECT DISTINCT
		|	DebitNoteInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.DebitNote.Inventory AS DebitNoteInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON DebitNoteInventory.PurchaseReturnGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN DebitNoteInventory.PurchaseReturnGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> DebitNoteInventory.PurchaseReturnItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DebitNoteInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN DebitNoteInventory.PurchaseReturnGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS PurchaseReturnItem,
		|	DebitNoteInventory.LineNumber AS LineNumber,
		|	DebitNoteInventory.Amount AS Amount,
		|	DebitNoteInventory.Batch AS Batch,
		|	DebitNoteInventory.Characteristic AS Characteristic,
		|	DebitNoteInventory.ConnectionKey AS ConnectionKey,
		|	DebitNoteInventory.InitialAmount AS InitialAmount,
		|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
		|	DebitNoteInventory.InitialQuantity AS InitialQuantity,
		|	DebitNoteInventory.InitialPrice AS InitialPrice,
		|	DebitNoteInventory.Order AS Order,
		|	DebitNoteInventory.Price AS Price,
		|	DebitNoteInventory.Products AS Products,
		|	DebitNoteInventory.Quantity AS Quantity,
		|	DebitNoteInventory.SerialNumbers AS SerialNumbers,
		|	DebitNoteInventory.Total AS Total,
		|	DebitNoteInventory.VATAmount AS VATAmount,
		|	DebitNoteInventory.VATRate AS VATRate,
		|	DebitNoteInventory.SupplierInvoice AS SupplierInvoice,
		|	DebitNoteInventory.GoodsIssue AS GoodsIssue,
		|	DebitNoteInventory.InventoryGLAccount AS InventoryGLAccount,
		|	DebitNoteInventory.VATInputGLAccount AS VATInputGLAccount,
		|	DebitNoteInventory.PurchaseReturnGLAccount AS PurchaseReturnGLAccount,
		|	DebitNoteInventory.Ownership AS Ownership,
		|	DebitNoteInventory.Project AS Project
		|FROM
		|	Document.DebitNote.Inventory AS DebitNoteInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON DebitNoteInventory.PurchaseReturnGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON DebitNoteInventory.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 13 Then
		
		Text = "SELECT DISTINCT
		|	EmploymentContract.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.EmploymentContract.EarningsDeductions AS EmploymentContract
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON EmploymentContract.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	EmploymentContract.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
		|	AND CASE
		|			WHEN EmploymentContract.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> EmploymentContract.ExpenseItem
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	EmploymentContract.Ref AS DocumentRef
		|FROM
		|	Document.EmploymentContract.EarningsDeductions AS EmploymentContract
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON EmploymentContract.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	EmploymentContract.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
		|	AND CASE
		|			WHEN EmploymentContract.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> EmploymentContract.IncomeItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	EmploymentContract.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""EarningsDeductions"" AS TabularSection,
		|	CASE
		|		WHEN EmploymentContract.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN EmploymentContract.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingIncome.IncomeAndExpenseItem, &Undefined)
		|	END AS IncomeItem,
		|	EmploymentContract.LineNumber AS LineNumber,
		|	EmploymentContract.EarningAndDeductionType AS EarningAndDeductionType,
		|	EmploymentContract.Amount AS Amount,
		|	EmploymentContract.Currency AS Currency,
		|	EmploymentContract.GLExpenseAccount AS GLExpenseAccount,
		|	EmploymentContract.ConnectionKey AS ConnectionKey
		|FROM
		|	Document.EmploymentContract.EarningsDeductions AS EmploymentContract
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON EmploymentContract.GLExpenseAccount = TT_Mapping.GLAccount
		|			AND EmploymentContract.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
		|		LEFT JOIN TT_Mapping AS TT_MappingIncome
		|		ON EmploymentContract.GLExpenseAccount = TT_Mapping.GLAccount
		|			AND EmploymentContract.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON EmploymentContract.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 14 Then
		
		Text = "SELECT DISTINCT
		|	ExpenseReportExpenses.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.ExpenseReport.Expenses AS ExpenseReportExpenses
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ExpenseReportExpenses.InventoryGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN ExpenseReportExpenses.InventoryGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> ExpenseReportExpenses.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ExpenseReportExpenses.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Expenses"" AS TabularSection,
		|	CASE
		|		WHEN ExpenseReportExpenses.InventoryGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	ExpenseReportExpenses.LineNumber AS LineNumber,
		|	ExpenseReportExpenses.Products AS Products,
		|	ExpenseReportExpenses.MeasurementUnit AS MeasurementUnit,
		|	ExpenseReportExpenses.Quantity AS Quantity,
		|	ExpenseReportExpenses.Price AS Price,
		|	ExpenseReportExpenses.Amount AS Amount,
		|	ExpenseReportExpenses.VATRate AS VATRate,
		|	ExpenseReportExpenses.VATAmount AS VATAmount,
		|	ExpenseReportExpenses.Total AS Total,
		|	ExpenseReportExpenses.SalesOrder AS SalesOrder,
		|	ExpenseReportExpenses.StructuralUnit AS StructuralUnit,
		|	ExpenseReportExpenses.BusinessLine AS BusinessLine,
		|	ExpenseReportExpenses.IncomingDocumentDate AS IncomingDocumentDate,
		|	ExpenseReportExpenses.IncomingDocumentNumber AS IncomingDocumentNumber,
		|	ExpenseReportExpenses.Content AS Content,
		|	ExpenseReportExpenses.TotalPresentationCur AS TotalPresentationCur,
		|	ExpenseReportExpenses.VATAmountPresentationCur AS VATAmountPresentationCur,
		|	ExpenseReportExpenses.ExchangeRate AS ExchangeRate,
		|	ExpenseReportExpenses.Multiplicity AS Multiplicity,
		|	ExpenseReportExpenses.DeductibleTax AS DeductibleTax,
		|	ExpenseReportExpenses.Supplier AS Supplier,
		|	ExpenseReportExpenses.Project AS Project,
		|	ExpenseReportExpenses.InventoryGLAccount AS InventoryGLAccount,
		|	ExpenseReportExpenses.VATInputGLAccount AS VATInputGLAccount,
		|	ExpenseReportExpenses.RegisterExpense AS RegisterExpense
		|FROM
		|	Document.ExpenseReport.Expenses AS ExpenseReportExpenses
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ExpenseReportExpenses.InventoryGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON ExpenseReportExpenses.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 15 Then
		
		Text = "SELECT DISTINCT
		|	FixedAssetDepreciationChangesFixedAssets.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.FixedAssetDepreciationChanges.FixedAssets AS FixedAssetDepreciationChangesFixedAssets
		|		LEFT JOIN TT_Mapping AS TT_MappingExpense
		|		ON FixedAssetDepreciationChangesFixedAssets.GLExpenseAccount = TT_MappingExpense.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingRevaluation
		|		ON FixedAssetDepreciationChangesFixedAssets.RevaluationAccount = TT_MappingRevaluation.GLAccount
		|WHERE
		|	(CASE
		|				WHEN FixedAssetDepreciationChangesFixedAssets.GLExpenseAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|			END <> FixedAssetDepreciationChangesFixedAssets.ExpenseItem
		|			OR CASE
		|				WHEN FixedAssetDepreciationChangesFixedAssets.RevaluationAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingRevaluation.IncomeAndExpenseItem, &Undefined)
		|			END <> FixedAssetDepreciationChangesFixedAssets.RevaluationItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FixedAssetDepreciationChangesFixedAssets.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""FixedAssets"" AS TabularSection,
		|	CASE
		|		WHEN FixedAssetDepreciationChangesFixedAssets.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN FixedAssetDepreciationChangesFixedAssets.RevaluationAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingRevaluation.IncomeAndExpenseItem, &Undefined)
		|	END AS RevaluationItem,
		|	FixedAssetDepreciationChangesFixedAssets.LineNumber AS LineNumber,
		|	FixedAssetDepreciationChangesFixedAssets.FixedAsset AS FixedAsset,
		|	FixedAssetDepreciationChangesFixedAssets.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
		|	FixedAssetDepreciationChangesFixedAssets.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
		|	FixedAssetDepreciationChangesFixedAssets.CostForDepreciationCalculation AS CostForDepreciationCalculation,
		|	FixedAssetDepreciationChangesFixedAssets.ApplyInCurrentMonth AS ApplyInCurrentMonth,
		|	FixedAssetDepreciationChangesFixedAssets.GLExpenseAccount AS GLExpenseAccount,
		|	FixedAssetDepreciationChangesFixedAssets.BusinessLine AS BusinessLine,
		|	FixedAssetDepreciationChangesFixedAssets.StructuralUnit AS StructuralUnit,
		|	FixedAssetDepreciationChangesFixedAssets.CostForDepreciationCalculationBeforeChanging AS CostForDepreciationCalculationBeforeChanging,
		|	FixedAssetDepreciationChangesFixedAssets.RevaluationAccount AS RevaluationAccount,
		|	FixedAssetDepreciationChangesFixedAssets.Project AS Project,
		|	CASE
		|		WHEN FixedAssetDepreciationChangesFixedAssets.GLExpenseAccount.TypeOfAccount IN (&TypeOfAccounts)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterExpense,
		|	CASE
		|		WHEN FixedAssetDepreciationChangesFixedAssets.RevaluationAccount.TypeOfAccount IN (&TypeOfAccounts)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterRevaluation
		|FROM
		|	Document.FixedAssetDepreciationChanges.FixedAssets AS FixedAssetDepreciationChangesFixedAssets
		|		LEFT JOIN TT_Mapping AS TT_MappingExpense
		|		ON FixedAssetDepreciationChangesFixedAssets.GLExpenseAccount = TT_MappingExpense.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingRevaluation
		|		ON FixedAssetDepreciationChangesFixedAssets.RevaluationAccount = TT_MappingRevaluation.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON FixedAssetDepreciationChangesFixedAssets.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 16 Then
		
		Text = "SELECT DISTINCT
		|	FixedAssetRecognitionFixedAssets.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.FixedAssetRecognition.FixedAssets AS FixedAssetRecognitionFixedAssets
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON FixedAssetRecognitionFixedAssets.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN FixedAssetRecognitionFixedAssets.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> FixedAssetRecognitionFixedAssets.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FixedAssetRecognitionFixedAssets.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""FixedAssets"" AS TabularSection,
		|	CASE
		|		WHEN FixedAssetRecognitionFixedAssets.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	FixedAssetRecognitionFixedAssets.LineNumber AS LineNumber,
		|	FixedAssetRecognitionFixedAssets.FixedAsset AS FixedAsset,
		|	FixedAssetRecognitionFixedAssets.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
		|	FixedAssetRecognitionFixedAssets.AccrueDepreciation AS AccrueDepreciation,
		|	FixedAssetRecognitionFixedAssets.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
		|	FixedAssetRecognitionFixedAssets.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
		|	FixedAssetRecognitionFixedAssets.GLExpenseAccount AS GLExpenseAccount,
		|	FixedAssetRecognitionFixedAssets.StructuralUnit AS StructuralUnit,
		|	FixedAssetRecognitionFixedAssets.BusinessLine AS BusinessLine,
		|	FixedAssetRecognitionFixedAssets.Project AS Project,
		|	CASE
		|		WHEN FixedAssetRecognitionFixedAssets.GLExpenseAccount.TypeOfAccount IN (&TypeOfAccounts)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterExpense
		|FROM
		|	Document.FixedAssetRecognition.FixedAssets AS FixedAssetRecognitionFixedAssets
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON FixedAssetRecognitionFixedAssets.GLExpenseAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON FixedAssetRecognitionFixedAssets.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 17 Then
		
		Text = "SELECT
		|	ForeignCurrencyExchange.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN ISNULL(BankCharges.GLExpenseAccount, &EmptyAccount) = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem
		|FROM
		|	Document.ForeignCurrencyExchange AS ForeignCurrencyExchange
		|		LEFT JOIN Catalog.BankCharges AS BankCharges
		|		ON ForeignCurrencyExchange.BankCharge = BankCharges.Ref
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (ISNULL(BankCharges.GLExpenseAccount, &EmptyAccount) = TT_Mapping.GLAccount)
		|WHERE
		|	CASE
		|			WHEN ISNULL(BankCharges.GLExpenseAccount, &EmptyAccount) = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> ForeignCurrencyExchange.ExpenseItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 18 Then
		
		Text = "SELECT DISTINCT
		|	GoodsIssueProducts.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.GoodsIssue.Products AS GoodsIssueProducts
		|		LEFT JOIN TT_Mapping AS TT_MappingRevenue
		|		ON GoodsIssueProducts.RevenueGLAccount = TT_MappingRevenue.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON GoodsIssueProducts.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingPurchaseReturn
		|		ON GoodsIssueProducts.PurchaseReturnGLAccount = TT_MappingPurchaseReturn.GLAccount
		|WHERE
		|	(CASE
		|				WHEN GoodsIssueProducts.RevenueGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingRevenue.IncomeAndExpenseItem, &Undefined)
		|			END <> GoodsIssueProducts.RevenueItem
		|			OR CASE
		|				WHEN GoodsIssueProducts.COGSGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> GoodsIssueProducts.COGSItem
		|			OR CASE
		|				WHEN GoodsIssueProducts.PurchaseReturnGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingPurchaseReturn.IncomeAndExpenseItem, &Undefined)
		|			END <> GoodsIssueProducts.PurchaseReturnItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GoodsIssueProducts.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Products"" AS TabularSection,
		|	CASE
		|		WHEN GoodsIssueProducts.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingRevenue.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	CASE
		|		WHEN GoodsIssueProducts.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS COGSItem,
		|	CASE
		|		WHEN GoodsIssueProducts.PurchaseReturnGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingPurchaseReturn.IncomeAndExpenseItem, &Undefined)
		|	END AS PurchaseReturnItem,
		|	GoodsIssueProducts.LineNumber AS LineNumber,
		|	GoodsIssueProducts.Products AS Products,
		|	GoodsIssueProducts.Characteristic AS Characteristic,
		|	GoodsIssueProducts.Batch AS Batch,
		|	GoodsIssueProducts.Quantity AS Quantity,
		|	GoodsIssueProducts.MeasurementUnit AS MeasurementUnit,
		|	GoodsIssueProducts.Contract AS Contract,
		|	GoodsIssueProducts.Order AS Order,
		|	GoodsIssueProducts.SerialNumbers AS SerialNumbers,
		|	GoodsIssueProducts.ConnectionKey AS ConnectionKey,
		|	GoodsIssueProducts.SalesInvoice AS SalesInvoice,
		|	GoodsIssueProducts.SupplierInvoice AS SupplierInvoice,
		|	GoodsIssueProducts.DebitNote AS DebitNote,
		|	GoodsIssueProducts.SalesRep AS SalesRep,
		|	GoodsIssueProducts.Price AS Price,
		|	GoodsIssueProducts.Amount AS Amount,
		|	GoodsIssueProducts.Total AS Total,
		|	GoodsIssueProducts.VATAmount AS VATAmount,
		|	GoodsIssueProducts.VATRate AS VATRate,
		|	GoodsIssueProducts.InitialAmount AS InitialAmount,
		|	GoodsIssueProducts.InitialQuantity AS InitialQuantity,
		|	GoodsIssueProducts.InventoryGLAccount AS InventoryGLAccount,
		|	GoodsIssueProducts.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	GoodsIssueProducts.InventoryTransferredGLAccount AS InventoryTransferredGLAccount,
		|	GoodsIssueProducts.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
		|	GoodsIssueProducts.GoodsInTransitGLAccount AS GoodsInTransitGLAccount,
		|	GoodsIssueProducts.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
		|	GoodsIssueProducts.PurchaseReturnGLAccount AS PurchaseReturnGLAccount,
		|	GoodsIssueProducts.RevenueGLAccount AS RevenueGLAccount,
		|	GoodsIssueProducts.COGSGLAccount AS COGSGLAccount,
		|	GoodsIssueProducts.ConsumptionGLAccount AS ConsumptionGLAccount,
		|	GoodsIssueProducts.BundleProduct AS BundleProduct,
		|	GoodsIssueProducts.BundleCharacteristic AS BundleCharacteristic,
		|	GoodsIssueProducts.CostShare AS CostShare,
		|	GoodsIssueProducts.Ownership AS Ownership,
		|	GoodsIssueProducts.Project AS Project
		|FROM
		|	Document.GoodsIssue.Products AS GoodsIssueProducts
		|		LEFT JOIN TT_Mapping AS TT_MappingRevenue
		|		ON GoodsIssueProducts.RevenueGLAccount = TT_MappingRevenue.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON GoodsIssueProducts.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingPurchaseReturn
		|		ON GoodsIssueProducts.PurchaseReturnGLAccount = TT_MappingPurchaseReturn.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON GoodsIssueProducts.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 19 Then
		
		Text = "SELECT DISTINCT
		|	GoodsIssueProductsOwnership.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.GoodsIssue.ProductsOwnership AS GoodsIssueProductsOwnership
		|		LEFT JOIN TT_Mapping AS TT_MappingRevenue
		|		ON GoodsIssueProductsOwnership.RevenueGLAccount = TT_MappingRevenue.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON GoodsIssueProductsOwnership.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingPurchaseReturn
		|		ON GoodsIssueProductsOwnership.PurchaseReturnGLAccount = TT_MappingPurchaseReturn.GLAccount
		|WHERE
		|	(CASE
		|				WHEN GoodsIssueProductsOwnership.RevenueGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingRevenue.IncomeAndExpenseItem, &Undefined)
		|			END <> GoodsIssueProductsOwnership.RevenueItem
		|			OR CASE
		|				WHEN GoodsIssueProductsOwnership.COGSGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> GoodsIssueProductsOwnership.COGSItem
		|			OR CASE
		|				WHEN GoodsIssueProductsOwnership.PurchaseReturnGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingPurchaseReturn.IncomeAndExpenseItem, &Undefined)
		|			END <> GoodsIssueProductsOwnership.PurchaseReturnItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GoodsIssueProductsOwnership.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""ProductsOwnership"" AS TabularSection,
		|	CASE
		|		WHEN GoodsIssueProductsOwnership.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingRevenue.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	CASE
		|		WHEN GoodsIssueProductsOwnership.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS COGSItem,
		|	CASE
		|		WHEN GoodsIssueProductsOwnership.PurchaseReturnGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingPurchaseReturn.IncomeAndExpenseItem, &Undefined)
		|	END AS PurchaseReturnItem,
		|	GoodsIssueProductsOwnership.LineNumber AS LineNumber,
		|	GoodsIssueProductsOwnership.Products AS Products,
		|	GoodsIssueProductsOwnership.Characteristic AS Characteristic,
		|	GoodsIssueProductsOwnership.Batch AS Batch,
		|	GoodsIssueProductsOwnership.Quantity AS Quantity,
		|	GoodsIssueProductsOwnership.MeasurementUnit AS MeasurementUnit,
		|	GoodsIssueProductsOwnership.Contract AS Contract,
		|	GoodsIssueProductsOwnership.Order AS Order,
		|	GoodsIssueProductsOwnership.SalesInvoice AS SalesInvoice,
		|	GoodsIssueProductsOwnership.SupplierInvoice AS SupplierInvoice,
		|	GoodsIssueProductsOwnership.DebitNote AS DebitNote,
		|	GoodsIssueProductsOwnership.SalesRep AS SalesRep,
		|	GoodsIssueProductsOwnership.Price AS Price,
		|	GoodsIssueProductsOwnership.Amount AS Amount,
		|	GoodsIssueProductsOwnership.Total AS Total,
		|	GoodsIssueProductsOwnership.VATAmount AS VATAmount,
		|	GoodsIssueProductsOwnership.VATRate AS VATRate,
		|	GoodsIssueProductsOwnership.InitialAmount AS InitialAmount,
		|	GoodsIssueProductsOwnership.InitialQuantity AS InitialQuantity,
		|	GoodsIssueProductsOwnership.InventoryGLAccount AS InventoryGLAccount,
		|	GoodsIssueProductsOwnership.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	GoodsIssueProductsOwnership.InventoryTransferredGLAccount AS InventoryTransferredGLAccount,
		|	GoodsIssueProductsOwnership.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
		|	GoodsIssueProductsOwnership.GoodsInTransitGLAccount AS GoodsInTransitGLAccount,
		|	GoodsIssueProductsOwnership.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
		|	GoodsIssueProductsOwnership.PurchaseReturnGLAccount AS PurchaseReturnGLAccount,
		|	GoodsIssueProductsOwnership.RevenueGLAccount AS RevenueGLAccount,
		|	GoodsIssueProductsOwnership.COGSGLAccount AS COGSGLAccount,
		|	GoodsIssueProductsOwnership.BundleProduct AS BundleProduct,
		|	GoodsIssueProductsOwnership.BundleCharacteristic AS BundleCharacteristic,
		|	GoodsIssueProductsOwnership.CostShare AS CostShare,
		|	GoodsIssueProductsOwnership.Ownership AS Ownership,
		|	GoodsIssueProductsOwnership.SerialNumber AS SerialNumber
		|FROM
		|	Document.GoodsIssue.ProductsOwnership AS GoodsIssueProductsOwnership
		|		LEFT JOIN TT_Mapping AS TT_MappingRevenue
		|		ON GoodsIssueProductsOwnership.RevenueGLAccount = TT_MappingRevenue.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON GoodsIssueProductsOwnership.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingPurchaseReturn
		|		ON GoodsIssueProductsOwnership.PurchaseReturnGLAccount = TT_MappingPurchaseReturn.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON GoodsIssueProductsOwnership.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 20 Then
		
		Text = "SELECT DISTINCT
		|	GoodsReceiptProducts.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.GoodsReceipt.Products AS GoodsReceiptProducts
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON GoodsReceiptProducts.COGSGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	GoodsReceiptProducts.Ref.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
		|	AND CASE
		|			WHEN GoodsReceiptProducts.COGSGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> GoodsReceiptProducts.SalesReturnItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GoodsReceiptProducts.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Products"" AS TabularSection,
		|	CASE
		|		WHEN GoodsReceiptProducts.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS SalesReturnItem,
		|	GoodsReceiptProducts.LineNumber AS LineNumber,
		|	GoodsReceiptProducts.Products AS Products,
		|	GoodsReceiptProducts.Characteristic AS Characteristic,
		|	GoodsReceiptProducts.Batch AS Batch,
		|	GoodsReceiptProducts.Quantity AS Quantity,
		|	GoodsReceiptProducts.MeasurementUnit AS MeasurementUnit,
		|	GoodsReceiptProducts.Contract AS Contract,
		|	GoodsReceiptProducts.Order AS Order,
		|	GoodsReceiptProducts.SerialNumbers AS SerialNumbers,
		|	GoodsReceiptProducts.ConnectionKey AS ConnectionKey,
		|	GoodsReceiptProducts.SupplierInvoice AS SupplierInvoice,
		|	GoodsReceiptProducts.SalesDocument AS SalesDocument,
		|	GoodsReceiptProducts.BasisDocument AS BasisDocument,
		|	GoodsReceiptProducts.CreditNote AS CreditNote,
		|	GoodsReceiptProducts.InventoryGLAccount AS InventoryGLAccount,
		|	GoodsReceiptProducts.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	GoodsReceiptProducts.InventoryTransferredGLAccount AS InventoryTransferredGLAccount,
		|	GoodsReceiptProducts.GoodsReceivedNotInvoicedGLAccount AS GoodsReceivedNotInvoicedGLAccount,
		|	GoodsReceiptProducts.GoodsInvoicedNotDeliveredGLAccount AS GoodsInvoicedNotDeliveredGLAccount,
		|	GoodsReceiptProducts.GoodsInTransitGLAccount AS GoodsInTransitGLAccount,
		|	GoodsReceiptProducts.COGSGLAccount AS COGSGLAccount,
		|	GoodsReceiptProducts.Price AS Price,
		|	GoodsReceiptProducts.DiscountPercent AS DiscountPercent,
		|	GoodsReceiptProducts.DiscountAmount AS DiscountAmount,
		|	GoodsReceiptProducts.Amount AS Amount,
		|	GoodsReceiptProducts.VATRate AS VATRate,
		|	GoodsReceiptProducts.VATAmount AS VATAmount,
		|	GoodsReceiptProducts.Total AS Total,
		|	GoodsReceiptProducts.InitialAmount AS InitialAmount,
		|	GoodsReceiptProducts.InitialQuantity AS InitialQuantity,
		|	GoodsReceiptProducts.CostOfGoodsSold AS CostOfGoodsSold,
		|	GoodsReceiptProducts.SalesRep AS SalesRep,
		|	GoodsReceiptProducts.CrossReference AS CrossReference,
		|	GoodsReceiptProducts.Ownership AS Ownership,
		|	GoodsReceiptProducts.Project AS Project
		|FROM
		|	Document.GoodsReceipt.Products AS GoodsReceiptProducts
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON GoodsReceiptProducts.COGSGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON GoodsReceiptProducts.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 21 Then
		
		Text = "SELECT
		|	InventoryIncrease.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN InventoryIncrease.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS IncomeItem,
		|	CASE
		|		WHEN InventoryIncrease.Correspondence.TypeOfAccount IN (&TypeOfAccounts)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterIncome
		|FROM
		|	Document.InventoryIncrease AS InventoryIncrease
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON InventoryIncrease.Correspondence = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN InventoryIncrease.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> InventoryIncrease.IncomeItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 22 Then
		
		Text = "SELECT DISTINCT
		|	InventoryTransferInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON InventoryTransferInventory.ConsumptionGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	InventoryTransferInventory.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
		|	AND CASE
		|			WHEN InventoryTransferInventory.ConsumptionGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> InventoryTransferInventory.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTransferInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN InventoryTransferInventory.ConsumptionGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	InventoryTransferInventory.LineNumber AS LineNumber,
		|	InventoryTransferInventory.Products AS Products,
		|	InventoryTransferInventory.Characteristic AS Characteristic,
		|	InventoryTransferInventory.Batch AS Batch,
		|	InventoryTransferInventory.Quantity AS Quantity,
		|	InventoryTransferInventory.Reserve AS Reserve,
		|	InventoryTransferInventory.MeasurementUnit AS MeasurementUnit,
		|	InventoryTransferInventory.SalesOrder AS SalesOrder,
		|	InventoryTransferInventory.BusinessLine AS BusinessLine,
		|	InventoryTransferInventory.Cost AS Cost,
		|	InventoryTransferInventory.Amount AS Amount,
		|	InventoryTransferInventory.SerialNumbers AS SerialNumbers,
		|	InventoryTransferInventory.ConnectionKey AS ConnectionKey,
		|	InventoryTransferInventory.InventoryGLAccount AS InventoryGLAccount,
		|	InventoryTransferInventory.InventoryToGLAccount AS InventoryToGLAccount,
		|	InventoryTransferInventory.ConsumptionGLAccount AS ConsumptionGLAccount,
		|	InventoryTransferInventory.SignedOutEquipmentGLAccount AS SignedOutEquipmentGLAccount,
		|	InventoryTransferInventory.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	InventoryTransferInventory.BusinessUnit AS BusinessUnit,
		|	InventoryTransferInventory.Ownership AS Ownership,
		|	InventoryTransferInventory.Project AS Project
		|FROM
		|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON InventoryTransferInventory.ConsumptionGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON InventoryTransferInventory.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 23 Then
		
		Text = "SELECT DISTINCT
		|	InventoryTransferInventoryOwnership.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.InventoryTransfer.InventoryOwnership AS InventoryTransferInventoryOwnership
		|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
		|		ON InventoryTransferInventoryOwnership.Ownership = CatalogInventoryOwnership.Ref
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (CASE
		|				WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|						OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
		|					THEN InventoryTransferInventoryOwnership.InventoryReceivedGLAccount
		|				WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
		|					THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount
		|				ELSE InventoryTransferInventoryOwnership.InventoryGLAccount
		|			END = TT_Mapping.GLAccount)
		|WHERE
		|	InventoryTransferInventoryOwnership.Ref.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
		|	AND CASE
		|			WHEN CASE
		|					WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|							OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
		|						THEN InventoryTransferInventoryOwnership.InventoryReceivedGLAccount
		|					WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
		|						THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount
		|					ELSE InventoryTransferInventoryOwnership.InventoryGLAccount
		|				END = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> InventoryTransferInventoryOwnership.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTransferInventoryOwnership.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""InventoryOwnership"" AS TabularSection,
		|	CASE
		|		WHEN CASE
		|				WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|						OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
		|					THEN InventoryTransferInventoryOwnership.InventoryReceivedGLAccount
		|				WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
		|					THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount
		|				ELSE InventoryTransferInventoryOwnership.InventoryGLAccount
		|			END = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	InventoryTransferInventoryOwnership.LineNumber AS LineNumber,
		|	InventoryTransferInventoryOwnership.Products AS Products,
		|	InventoryTransferInventoryOwnership.Characteristic AS Characteristic,
		|	InventoryTransferInventoryOwnership.Batch AS Batch,
		|	InventoryTransferInventoryOwnership.Quantity AS Quantity,
		|	InventoryTransferInventoryOwnership.Reserve AS Reserve,
		|	InventoryTransferInventoryOwnership.MeasurementUnit AS MeasurementUnit,
		|	InventoryTransferInventoryOwnership.SalesOrder AS SalesOrder,
		|	InventoryTransferInventoryOwnership.BusinessLine AS BusinessLine,
		|	InventoryTransferInventoryOwnership.Cost AS Cost,
		|	InventoryTransferInventoryOwnership.Amount AS Amount,
		|	InventoryTransferInventoryOwnership.InventoryGLAccount AS InventoryGLAccount,
		|	InventoryTransferInventoryOwnership.InventoryToGLAccount AS InventoryToGLAccount,
		|	InventoryTransferInventoryOwnership.ConsumptionGLAccount AS ConsumptionGLAccount,
		|	InventoryTransferInventoryOwnership.SignedOutEquipmentGLAccount AS SignedOutEquipmentGLAccount,
		|	InventoryTransferInventoryOwnership.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	InventoryTransferInventoryOwnership.BusinessUnit AS BusinessUnit,
		|	InventoryTransferInventoryOwnership.Ownership AS Ownership,
		|	InventoryTransferInventoryOwnership.SerialNumber AS SerialNumber,
		|	InventoryTransferInventoryOwnership.BatchCorr AS BatchCorr
		|FROM
		|	Document.InventoryTransfer.InventoryOwnership AS InventoryTransferInventoryOwnership
		|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
		|		ON InventoryTransferInventoryOwnership.Ownership = CatalogInventoryOwnership.Ref
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (CASE
		|				WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|						OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
		|					THEN InventoryTransferInventoryOwnership.InventoryReceivedGLAccount
		|				WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
		|					THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount
		|				ELSE InventoryTransferInventoryOwnership.InventoryGLAccount
		|			END = TT_Mapping.GLAccount)
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON InventoryTransferInventoryOwnership.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 24 Then
		
		Text = "SELECT
		|	InventoryWriteOff.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN InventoryWriteOff.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem
		|FROM
		|	Document.InventoryWriteOff AS InventoryWriteOff
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON InventoryWriteOff.Correspondence = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN InventoryWriteOff.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> InventoryWriteOff.ExpenseItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 25 Then
		
		Text = "SELECT
		|	LoanContract.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN LoanContract.CostAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS InterestIncomeItem
		|FROM
		|	Document.LoanContract AS LoanContract
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON LoanContract.CostAccount = TT_Mapping.GLAccount
		|WHERE
		|	LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
		|	AND CASE
		|			WHEN LoanContract.CostAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> LoanContract.InterestIncomeItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 26 Then
		
		Text = "SELECT
		|	LoanContract.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN LoanContract.CostAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS InterestIncomeItem,
		|	CASE
		|		WHEN LoanContract.CommissionGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCommission.IncomeAndExpenseItem, &Undefined)
		|	END AS CommissionIncomeItem
		|FROM
		|	Document.LoanContract AS LoanContract
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON LoanContract.CostAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCommission
		|		ON LoanContract.CommissionGLAccount = TT_MappingCommission.GLAccount
		|WHERE
		|	LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
		|	AND (CASE
		|				WHEN LoanContract.CostAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> LoanContract.InterestIncomeItem
		|			OR CASE
		|				WHEN LoanContract.CommissionGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCommission.IncomeAndExpenseItem, &Undefined)
		|			END <> LoanContract.CommissionExpenseItem)
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 27 Then
		
		Text = "SELECT
		|	LoanContract.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN LoanContract.CostAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS InterestExpenseItem,
		|	CASE
		|		WHEN LoanContract.CommissionGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCommission.IncomeAndExpenseItem, &Undefined)
		|	END AS CommissionExpenseItem
		|FROM
		|	Document.LoanContract AS LoanContract
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON LoanContract.CostAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCommission
		|		ON LoanContract.CommissionGLAccount = TT_MappingCommission.GLAccount
		|WHERE
		|	LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|	AND (CASE
		|				WHEN LoanContract.CostAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> LoanContract.InterestExpenseItem
		|			OR CASE
		|				WHEN LoanContract.CommissionGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCommission.IncomeAndExpenseItem, &Undefined)
		|			END <> LoanContract.CommissionIncomeItem)
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	// begin Drive.FullVersion
	ElsIf QueryNumber = 28 Then
		
		Text = "SELECT DISTINCT
		|	ManufacturingOverheadsRates.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.ManufacturingOverheadsRates.Rates AS ManufacturingOverheadsRates
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ManufacturingOverheadsRates.GLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN ManufacturingOverheadsRates.GLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> ManufacturingOverheadsRates.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ManufacturingOverheadsRates.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Rates"" AS TabularSection,
		|	CASE
		|		WHEN ManufacturingOverheadsRates.GLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	ManufacturingOverheadsRates.LineNumber AS LineNumber,
		|	ManufacturingOverheadsRates.Activity AS Activity,
		|	ManufacturingOverheadsRates.BusinessUnit AS BusinessUnit,
		|	ManufacturingOverheadsRates.CostDriver AS CostDriver,
		|	ManufacturingOverheadsRates.GLAccount AS GLAccount,
		|	ManufacturingOverheadsRates.Rate AS Rate
		|FROM
		|	Document.ManufacturingOverheadsRates.Rates AS ManufacturingOverheadsRates
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ManufacturingOverheadsRates.GLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON ManufacturingOverheadsRates.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	// end Drive.FullVersion
	ElsIf QueryNumber = 29 Then
		
		Text = "SELECT DISTINCT
		|	OpeningBalanceEntry.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.OpeningBalanceEntry.FixedAssets AS OpeningBalanceEntry
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON OpeningBalanceEntry.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN OpeningBalanceEntry.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> OpeningBalanceEntry.DepreciationChargeItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OpeningBalanceEntry.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""FixedAssets"" AS TabularSection,
		|	CASE
		|		WHEN OpeningBalanceEntry.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS DepreciationChargeItem,
		|	OpeningBalanceEntry.LineNumber AS LineNumber,
		|	OpeningBalanceEntry.FixedAsset AS FixedAsset,
		|	OpeningBalanceEntry.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
		|	OpeningBalanceEntry.AccrueDepreciation AS AccrueDepreciation,
		|	OpeningBalanceEntry.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
		|	OpeningBalanceEntry.CurrentOutputQuantity AS CurrentOutputQuantity,
		|	OpeningBalanceEntry.CurrentDepreciationAccrued AS CurrentDepreciationAccrued,
		|	OpeningBalanceEntry.FixedAssetCurrentCondition AS FixedAssetCurrentCondition,
		|	OpeningBalanceEntry.StructuralUnit AS StructuralUnit,
		|	OpeningBalanceEntry.GLExpenseAccount AS GLExpenseAccount,
		|	OpeningBalanceEntry.BusinessLine AS BusinessLine,
		|	CASE
		|		WHEN OpeningBalanceEntry.GLExpenseAccount.TypeOfAccount IN (&TypeOfAccounts)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterDepreciationCharge
		|FROM
		|	Document.OpeningBalanceEntry.FixedAssets AS OpeningBalanceEntry
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON OpeningBalanceEntry.GLExpenseAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON OpeningBalanceEntry.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 30 Then
		
		Text = "SELECT DISTINCT
		|	OtherExpenses.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.OtherExpenses.Expenses AS OtherExpenses
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON OtherExpenses.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN OtherExpenses.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> OtherExpenses.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OtherExpenses.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Expenses"" AS TabularSection,
		|	CASE
		|		WHEN OtherExpenses.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	OtherExpenses.LineNumber AS LineNumber,
		|	OtherExpenses.GLExpenseAccount AS GLExpenseAccount,
		|	OtherExpenses.BusinessLine AS BusinessLine,
		|	OtherExpenses.SalesOrder AS SalesOrder,
		|	OtherExpenses.Amount AS Amount,
		|	OtherExpenses.Counterparty AS Counterparty,
		|	OtherExpenses.Contract AS Contract,
		|	OtherExpenses.Project AS Project,
		|	OtherExpenses.RegisterExpense AS RegisterExpense
		|FROM
		|	Document.OtherExpenses.Expenses AS OtherExpenses
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON OtherExpenses.GLExpenseAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON OtherExpenses.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 31 Then
		
		Text = "SELECT
		|	PaymentExpense.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN PaymentExpense.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN ISNULL(PaymentExpense.BankCharge.GLExpenseAccount, &EmptyAccount) = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|	END AS BankFeeExpenseItem
		|FROM
		|	Document.PaymentExpense AS PaymentExpense
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PaymentExpense.Correspondence = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingExpense
		|		ON (ISNULL(PaymentExpense.BankCharge.GLExpenseAccount, &EmptyAccount) = TT_MappingExpense.GLAccount)
		|WHERE
		|	(CASE
		|				WHEN PaymentExpense.Correspondence = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> PaymentExpense.ExpenseItem
		|			OR CASE
		|				WHEN ISNULL(PaymentExpense.BankCharge.GLExpenseAccount, &EmptyAccount) = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|			END <> PaymentExpense.BankFeeExpenseItem)
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 32 Then
		
		Text = "SELECT DISTINCT
		|	PaymentExpensePaymentDetails.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.PaymentExpense.PaymentDetails AS PaymentExpensePaymentDetails
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PaymentExpensePaymentDetails.DiscountReceivedGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN PaymentExpensePaymentDetails.DiscountReceivedGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> PaymentExpensePaymentDetails.DiscountReceivedIncomeItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PaymentExpensePaymentDetails.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""PaymentDetails"" AS TabularSection,
		|	CASE
		|		WHEN PaymentExpensePaymentDetails.DiscountReceivedGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS DiscountReceivedIncomeItem,
		|	PaymentExpensePaymentDetails.LineNumber AS LineNumber,
		|	PaymentExpensePaymentDetails.Contract AS Contract,
		|	PaymentExpensePaymentDetails.AdvanceFlag AS AdvanceFlag,
		|	PaymentExpensePaymentDetails.Document AS Document,
		|	PaymentExpensePaymentDetails.SettlementsAmount AS SettlementsAmount,
		|	PaymentExpensePaymentDetails.ExchangeRate AS ExchangeRate,
		|	PaymentExpensePaymentDetails.Multiplicity AS Multiplicity,
		|	PaymentExpensePaymentDetails.PaymentAmount AS PaymentAmount,
		|	PaymentExpensePaymentDetails.VATRate AS VATRate,
		|	PaymentExpensePaymentDetails.VATAmount AS VATAmount,
		|	PaymentExpensePaymentDetails.Order AS Order,
		|	PaymentExpensePaymentDetails.PlanningDocument AS PlanningDocument,
		|	PaymentExpensePaymentDetails.TypeOfAmount AS TypeOfAmount,
		|	PaymentExpensePaymentDetails.EPDAmount AS EPDAmount,
		|	PaymentExpensePaymentDetails.SettlementsEPDAmount AS SettlementsEPDAmount,
		|	PaymentExpensePaymentDetails.ExistsEPD AS ExistsEPD,
		|	PaymentExpensePaymentDetails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
		|	PaymentExpensePaymentDetails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
		|	PaymentExpensePaymentDetails.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
		|	PaymentExpensePaymentDetails.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
		|	PaymentExpensePaymentDetails.DiscountReceivedGLAccount AS DiscountReceivedGLAccount,
		|	PaymentExpensePaymentDetails.VATInputGLAccount AS VATInputGLAccount,
		|	PaymentExpensePaymentDetails.Item AS Item,
		|	PaymentExpensePaymentDetails.Project AS Project
		|FROM
		|	Document.PaymentExpense.PaymentDetails AS PaymentExpensePaymentDetails
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PaymentExpensePaymentDetails.DiscountReceivedGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON PaymentExpensePaymentDetails.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 33 Then
		
		Text = "SELECT
		|	PaymentReceipt.Ref AS DocumentRef,
		|	1 AS Mark,
		|	UNDEFINED AS ExpenseItem,
		|	CASE
		|		WHEN PaymentReceipt.Correspondence = &EmptyAccount
		|			OR NOT PaymentReceipt.OperationKind IN (VALUE(Enum.OperationTypesPaymentReceipt.Other),
		|													VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase))
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS IncomeItem,
		|	CASE
		|		WHEN ISNULL(PaymentReceipt.BankCharge.GLExpenseAccount, &EmptyAccount) = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|	END AS BankFeeExpenseItem
		|FROM
		|	Document.PaymentReceipt AS PaymentReceipt
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PaymentReceipt.Correspondence = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingExpense
		|		ON (ISNULL(PaymentReceipt.BankCharge.GLExpenseAccount, &EmptyAccount) = TT_MappingExpense.GLAccount)
		|WHERE
		|	(CASE
		|				WHEN PaymentReceipt.Correspondence = &EmptyAccount
		|						OR NOT PaymentReceipt.OperationKind IN (VALUE(Enum.OperationTypesPaymentReceipt.Other),
		|													VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase))
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> PaymentReceipt.IncomeItem
		|			OR CASE
		|				WHEN ISNULL(PaymentReceipt.BankCharge.GLExpenseAccount, &EmptyAccount) = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|			END <> PaymentReceipt.BankFeeExpenseItem)
		|
		|UNION ALL
		|
		|SELECT
		|	PaymentReceipt.Ref,
		|	1,
		|	CASE
		|		WHEN &FeeExpensesGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END,
		|	UNDEFINED,
		|	CASE
		|		WHEN ISNULL(PaymentReceipt.BankCharge.GLExpenseAccount, &EmptyAccount) = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|	END
		|FROM
		|	Document.PaymentReceipt AS PaymentReceipt
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (&FeeExpensesGLAccount = TT_Mapping.GLAccount)
		|		LEFT JOIN TT_Mapping AS TT_MappingExpense
		|		ON (ISNULL(PaymentReceipt.BankCharge.GLExpenseAccount, &EmptyAccount) = TT_MappingExpense.GLAccount)
		|WHERE
		|	PaymentReceipt.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
		|	AND PaymentReceipt.POSTerminal.WithholdFeeOnPayout
		|	AND (CASE
		|				WHEN &FeeExpensesGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> PaymentReceipt.ExpenseItem
		|			OR CASE
		|				WHEN ISNULL(PaymentReceipt.BankCharge.GLExpenseAccount, &EmptyAccount) = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingExpense.IncomeAndExpenseItem, &Undefined)
		|			END <> PaymentReceipt.BankFeeExpenseItem)
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 34 Then
		
		Text = "SELECT DISTINCT
		|	PaymentReceiptPaymentDetails.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.PaymentReceipt.PaymentDetails AS PaymentReceiptPaymentDetails
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PaymentReceiptPaymentDetails.DiscountAllowedGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN PaymentReceiptPaymentDetails.DiscountAllowedGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> PaymentReceiptPaymentDetails.DiscountAllowedExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PaymentReceiptPaymentDetails.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""PaymentDetails"" AS TabularSection,
		|	CASE
		|		WHEN PaymentReceiptPaymentDetails.DiscountAllowedGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS DiscountAllowedExpenseItem,
		|	PaymentReceiptPaymentDetails.LineNumber AS LineNumber,
		|	PaymentReceiptPaymentDetails.Contract AS Contract,
		|	PaymentReceiptPaymentDetails.AdvanceFlag AS AdvanceFlag,
		|	PaymentReceiptPaymentDetails.Document AS Document,
		|	PaymentReceiptPaymentDetails.SettlementsAmount AS SettlementsAmount,
		|	PaymentReceiptPaymentDetails.ExchangeRate AS ExchangeRate,
		|	PaymentReceiptPaymentDetails.Multiplicity AS Multiplicity,
		|	PaymentReceiptPaymentDetails.PaymentAmount AS PaymentAmount,
		|	PaymentReceiptPaymentDetails.VATRate AS VATRate,
		|	PaymentReceiptPaymentDetails.VATAmount AS VATAmount,
		|	PaymentReceiptPaymentDetails.Order AS Order,
		|	PaymentReceiptPaymentDetails.PlanningDocument AS PlanningDocument,
		|	PaymentReceiptPaymentDetails.TypeOfAmount AS TypeOfAmount,
		|	PaymentReceiptPaymentDetails.EPDAmount AS EPDAmount,
		|	PaymentReceiptPaymentDetails.SettlementsEPDAmount AS SettlementsEPDAmount,
		|	PaymentReceiptPaymentDetails.ExistsEPD AS ExistsEPD,
		|	PaymentReceiptPaymentDetails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
		|	PaymentReceiptPaymentDetails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
		|	PaymentReceiptPaymentDetails.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
		|	PaymentReceiptPaymentDetails.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
		|	PaymentReceiptPaymentDetails.DiscountAllowedGLAccount AS DiscountAllowedGLAccount,
		|	PaymentReceiptPaymentDetails.Item AS Item,
		|	PaymentReceiptPaymentDetails.ThirdPartyPayerGLAccount AS ThirdPartyPayerGLAccount,
		|	PaymentReceiptPaymentDetails.ThirdPartyCustomer AS ThirdPartyCustomer,
		|	PaymentReceiptPaymentDetails.ThirdPartyCustomerContract AS ThirdPartyCustomerContract,
		|	PaymentReceiptPaymentDetails.Project AS Project,
		|	PaymentReceiptPaymentDetails.VATOutputGLAccount AS VATOutputGLAccount
		|FROM
		|	Document.PaymentReceipt.PaymentDetails AS PaymentReceiptPaymentDetails
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PaymentReceiptPaymentDetails.DiscountAllowedGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON PaymentReceiptPaymentDetails.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 35 Then
		
		Text = "SELECT DISTINCT
		|	PayrollEarningsDeductions.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.Payroll.EarningsDeductions AS PayrollEarningsDeductions
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PayrollEarningsDeductions.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	PayrollEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
		|	AND PayrollEarningsDeductions.GLExpenseAccount.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.IndirectExpenses), VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.Revenue))
		|	AND CASE
		|			WHEN PayrollEarningsDeductions.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> PayrollEarningsDeductions.ExpenseItem
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	PayrollEarningsDeductions.Ref
		|FROM
		|	Document.Payroll.EarningsDeductions AS PayrollEarningsDeductions
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PayrollEarningsDeductions.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	PayrollEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
		|	AND PayrollEarningsDeductions.GLExpenseAccount.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Revenue), VALUE(Enum.GLAccountsTypes.OtherIncome))
		|	AND CASE
		|			WHEN PayrollEarningsDeductions.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> PayrollEarningsDeductions.IncomeItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PayrollEarningsDeductions.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""EarningsDeductions"" AS TabularSection,
		|	CASE
		|		WHEN PayrollEarningsDeductions.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN PayrollEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
		|			THEN ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN PayrollEarningsDeductions.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		WHEN PayrollEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
		|			THEN ISNULL(TT_MappingIncome.IncomeAndExpenseItem, &Undefined)
		|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|	END AS IncomeItem,
		|	PayrollEarningsDeductions.LineNumber AS LineNumber,
		|	PayrollEarningsDeductions.Employee AS Employee,
		|	PayrollEarningsDeductions.Position AS Position,
		|	PayrollEarningsDeductions.EarningAndDeductionType AS EarningAndDeductionType,
		|	PayrollEarningsDeductions.StartDate AS StartDate,
		|	PayrollEarningsDeductions.EndDate AS EndDate,
		|	PayrollEarningsDeductions.DaysWorked AS DaysWorked,
		|	PayrollEarningsDeductions.HoursWorked AS HoursWorked,
		|	PayrollEarningsDeductions.Size AS Size,
		|	PayrollEarningsDeductions.Amount AS Amount,
		|	PayrollEarningsDeductions.GLExpenseAccount AS GLExpenseAccount,
		|	PayrollEarningsDeductions.BusinessLine AS BusinessLine,
		|	PayrollEarningsDeductions.SalesOrder AS SalesOrder,
		|	PayrollEarningsDeductions.ManualCorrection AS ManualCorrection,
		|	PayrollEarningsDeductions.Indicator1 AS Indicator1,
		|	PayrollEarningsDeductions.Presentation1 AS Presentation1,
		|	PayrollEarningsDeductions.Value1 AS Value1,
		|	PayrollEarningsDeductions.Indicator2 AS Indicator2,
		|	PayrollEarningsDeductions.Presentation2 AS Presentation2,
		|	PayrollEarningsDeductions.Value2 AS Value2,
		|	PayrollEarningsDeductions.Indicator3 AS Indicator3,
		|	PayrollEarningsDeductions.Presentation3 AS Presentation3,
		|	PayrollEarningsDeductions.Value3 AS Value3,
		|	PayrollEarningsDeductions.TypeOfAccount AS TypeOfAccount,
		|	PayrollEarningsDeductions.Project AS Project,
		|	CASE
		|		WHEN PayrollEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
		|				AND PayrollEarningsDeductions.GLExpenseAccount.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.IndirectExpenses), VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.Revenue))
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterExpense,
		|	CASE
		|		WHEN PayrollEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
		|				AND PayrollEarningsDeductions.GLExpenseAccount.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Revenue), VALUE(Enum.GLAccountsTypes.OtherIncome))
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterIncome
		|FROM
		|	Document.Payroll.EarningsDeductions AS PayrollEarningsDeductions
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON PayrollEarningsDeductions.GLExpenseAccount = TT_Mapping.GLAccount
		|			AND PayrollEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
		|			AND PayrollEarningsDeductions.GLExpenseAccount.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.IndirectExpenses), VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.Revenue))
		|		LEFT JOIN TT_Mapping AS TT_MappingIncome
		|		ON PayrollEarningsDeductions.GLExpenseAccount = TT_MappingIncome.GLAccount
		|			AND PayrollEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
		|			AND PayrollEarningsDeductions.GLExpenseAccount.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Revenue), VALUE(Enum.GLAccountsTypes.OtherIncome))
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON PayrollEarningsDeductions.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 36 Then
		
		Text = "SELECT DISTINCT
		|	ProductReturnInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.ProductReturn.Inventory AS ProductReturnInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ProductReturnInventory.RevenueGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN ProductReturnInventory.RevenueGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> ProductReturnInventory.RevenueItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductReturnInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN ProductReturnInventory.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	ProductReturnInventory.LineNumber AS LineNumber,
		|	ProductReturnInventory.Products AS Products,
		|	ProductReturnInventory.Characteristic AS Characteristic,
		|	ProductReturnInventory.Batch AS Batch,
		|	ProductReturnInventory.Quantity AS Quantity,
		|	ProductReturnInventory.MeasurementUnit AS MeasurementUnit,
		|	ProductReturnInventory.Price AS Price,
		|	ProductReturnInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	ProductReturnInventory.Amount AS Amount,
		|	ProductReturnInventory.VATRate AS VATRate,
		|	ProductReturnInventory.VATAmount AS VATAmount,
		|	ProductReturnInventory.Total AS Total,
		|	ProductReturnInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|	ProductReturnInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
		|	ProductReturnInventory.ConnectionKey AS ConnectionKey,
		|	ProductReturnInventory.SerialNumbers AS SerialNumbers,
		|	ProductReturnInventory.RevenueGLAccount AS RevenueGLAccount,
		|	ProductReturnInventory.VATOutputGLAccount AS VATOutputGLAccount
		|FROM
		|	Document.ProductReturn.Inventory AS ProductReturnInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ProductReturnInventory.RevenueGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON ProductReturnInventory.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 37 Then
		
		Text = "SELECT DISTINCT
		|	ProductReturnInventoryOwnership.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.ProductReturn.InventoryOwnership AS ProductReturnInventoryOwnership
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ProductReturnInventoryOwnership.RevenueGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN ProductReturnInventoryOwnership.RevenueGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> ProductReturnInventoryOwnership.RevenueItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductReturnInventoryOwnership.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""InventoryOwnership"" AS TabularSection,
		|	CASE
		|		WHEN ProductReturnInventoryOwnership.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	ProductReturnInventoryOwnership.LineNumber AS LineNumber,
		|	ProductReturnInventoryOwnership.Products AS Products,
		|	ProductReturnInventoryOwnership.Characteristic AS Characteristic,
		|	ProductReturnInventoryOwnership.Batch AS Batch,
		|	ProductReturnInventoryOwnership.Quantity AS Quantity,
		|	ProductReturnInventoryOwnership.MeasurementUnit AS MeasurementUnit,
		|	ProductReturnInventoryOwnership.Price AS Price,
		|	ProductReturnInventoryOwnership.Amount AS Amount,
		|	ProductReturnInventoryOwnership.VATRate AS VATRate,
		|	ProductReturnInventoryOwnership.VATAmount AS VATAmount,
		|	ProductReturnInventoryOwnership.Total AS Total,
		|	ProductReturnInventoryOwnership.RevenueGLAccount AS RevenueGLAccount,
		|	ProductReturnInventoryOwnership.VATOutputGLAccount AS VATOutputGLAccount,
		|	ProductReturnInventoryOwnership.Ownership AS Ownership,
		|	ProductReturnInventoryOwnership.SerialNumber AS SerialNumber
		|FROM
		|	Document.ProductReturn.InventoryOwnership AS ProductReturnInventoryOwnership
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ProductReturnInventoryOwnership.RevenueGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON ProductReturnInventoryOwnership.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 38 Then
		
		Text = "SELECT
		|	RetailRevaluation.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN RetailRevaluation.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	UNDEFINED AS IncomeItem
		|FROM
		|	Document.RetailRevaluation AS RetailRevaluation
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON RetailRevaluation.Correspondence = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN RetailRevaluation.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> RetailRevaluation.ExpenseItem
		|	AND RetailRevaluation.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
		|
		|UNION ALL
		|
		|SELECT
		|	RetailRevaluation.Ref,
		|	1,
		|	UNDEFINED,
		|	CASE
		|		WHEN RetailRevaluation.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END
		|FROM
		|	Document.RetailRevaluation AS RetailRevaluation
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON RetailRevaluation.Correspondence = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN RetailRevaluation.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> RetailRevaluation.IncomeItem
		|	AND RetailRevaluation.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 39 Then
		
		Text = "SELECT DISTINCT
		|	SalesInvoiceInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SalesInvoiceInventory.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON SalesInvoiceInventory.COGSGLAccount = TT_MappingCOGS.GLAccount
		|WHERE
		|	(CASE
		|				WHEN SalesInvoiceInventory.RevenueGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> SalesInvoiceInventory.RevenueItem
		|			OR CASE
		|				WHEN SalesInvoiceInventory.COGSGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> SalesInvoiceInventory.COGSItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesInvoiceInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN SalesInvoiceInventory.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	CASE
		|		WHEN SalesInvoiceInventory.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS COGSItem,
		|	SalesInvoiceInventory.LineNumber AS LineNumber,
		|	SalesInvoiceInventory.Products AS Products,
		|	SalesInvoiceInventory.ProductsTypeInventory AS ProductsTypeInventory,
		|	SalesInvoiceInventory.Characteristic AS Characteristic,
		|	SalesInvoiceInventory.Batch AS Batch,
		|	SalesInvoiceInventory.Quantity AS Quantity,
		|	SalesInvoiceInventory.Reserve AS Reserve,
		|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
		|	SalesInvoiceInventory.Price AS Price,
		|	SalesInvoiceInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	SalesInvoiceInventory.Amount AS Amount,
		|	SalesInvoiceInventory.VATRate AS VATRate,
		|	SalesInvoiceInventory.VATAmount AS VATAmount,
		|	SalesInvoiceInventory.Total AS Total,
		|	SalesInvoiceInventory.Order AS Order,
		|	SalesInvoiceInventory.GoodsIssue AS GoodsIssue,
		|	SalesInvoiceInventory.Content AS Content,
		|	SalesInvoiceInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|	SalesInvoiceInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
		|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
		|	SalesInvoiceInventory.SerialNumbers AS SerialNumbers,
		|	SalesInvoiceInventory.SalesRep AS SalesRep,
		|	SalesInvoiceInventory.Specification AS Specification,
		|	SalesInvoiceInventory.InventoryGLAccount AS InventoryGLAccount,
		|	SalesInvoiceInventory.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
		|	SalesInvoiceInventory.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
		|	SalesInvoiceInventory.VATOutputGLAccount AS VATOutputGLAccount,
		|	SalesInvoiceInventory.RevenueGLAccount AS RevenueGLAccount,
		|	SalesInvoiceInventory.COGSGLAccount AS COGSGLAccount,
		|	SalesInvoiceInventory.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	SalesInvoiceInventory.BundleProduct AS BundleProduct,
		|	SalesInvoiceInventory.BundleCharacteristic AS BundleCharacteristic,
		|	SalesInvoiceInventory.CostShare AS CostShare,
		|	SalesInvoiceInventory.Taxable AS Taxable,
		|	SalesInvoiceInventory.SalesTaxAmount AS SalesTaxAmount,
		|	SalesInvoiceInventory.DeliveryStartDate AS DeliveryStartDate,
		|	SalesInvoiceInventory.DeliveryEndDate AS DeliveryEndDate,
		|	SalesInvoiceInventory.Project AS Project,
		|	SalesInvoiceInventory.ActualQuantity AS ActualQuantity,
		|	SalesInvoiceInventory.InvoicedQuantity AS InvoicedQuantity,
		|	SalesInvoiceInventory.DropShipping AS DropShipping
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SalesInvoiceInventory.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON SalesInvoiceInventory.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON SalesInvoiceInventory.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 40 Then
		
		Text = "SELECT DISTINCT
		|	SalesInvoiceInventoryOwnership.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.SalesInvoice.InventoryOwnership AS SalesInvoiceInventoryOwnership
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SalesInvoiceInventoryOwnership.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON SalesInvoiceInventoryOwnership.COGSGLAccount = TT_MappingCOGS.GLAccount
		|WHERE
		|	(CASE
		|				WHEN SalesInvoiceInventoryOwnership.RevenueGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> SalesInvoiceInventoryOwnership.RevenueItem
		|			OR CASE
		|				WHEN SalesInvoiceInventoryOwnership.COGSGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> SalesInvoiceInventoryOwnership.COGSItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesInvoiceInventoryOwnership.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""InventoryOwnership"" AS TabularSection,
		|	CASE
		|		WHEN SalesInvoiceInventoryOwnership.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	CASE
		|		WHEN SalesInvoiceInventoryOwnership.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS COGSItem,
		|	SalesInvoiceInventoryOwnership.LineNumber AS LineNumber,
		|	SalesInvoiceInventoryOwnership.Products AS Products,
		|	SalesInvoiceInventoryOwnership.Characteristic AS Characteristic,
		|	SalesInvoiceInventoryOwnership.Batch AS Batch,
		|	SalesInvoiceInventoryOwnership.Quantity AS Quantity,
		|	SalesInvoiceInventoryOwnership.Reserve AS Reserve,
		|	SalesInvoiceInventoryOwnership.MeasurementUnit AS MeasurementUnit,
		|	SalesInvoiceInventoryOwnership.Price AS Price,
		|	SalesInvoiceInventoryOwnership.Amount AS Amount,
		|	SalesInvoiceInventoryOwnership.VATRate AS VATRate,
		|	SalesInvoiceInventoryOwnership.VATAmount AS VATAmount,
		|	SalesInvoiceInventoryOwnership.Total AS Total,
		|	SalesInvoiceInventoryOwnership.Order AS Order,
		|	SalesInvoiceInventoryOwnership.GoodsIssue AS GoodsIssue,
		|	SalesInvoiceInventoryOwnership.SalesRep AS SalesRep,
		|	SalesInvoiceInventoryOwnership.Specification AS Specification,
		|	SalesInvoiceInventoryOwnership.InventoryGLAccount AS InventoryGLAccount,
		|	SalesInvoiceInventoryOwnership.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
		|	SalesInvoiceInventoryOwnership.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
		|	SalesInvoiceInventoryOwnership.VATOutputGLAccount AS VATOutputGLAccount,
		|	SalesInvoiceInventoryOwnership.RevenueGLAccount AS RevenueGLAccount,
		|	SalesInvoiceInventoryOwnership.COGSGLAccount AS COGSGLAccount,
		|	SalesInvoiceInventoryOwnership.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	SalesInvoiceInventoryOwnership.BundleProduct AS BundleProduct,
		|	SalesInvoiceInventoryOwnership.BundleCharacteristic AS BundleCharacteristic,
		|	SalesInvoiceInventoryOwnership.CostShare AS CostShare,
		|	SalesInvoiceInventoryOwnership.Taxable AS Taxable,
		|	SalesInvoiceInventoryOwnership.SalesTaxAmount AS SalesTaxAmount,
		|	SalesInvoiceInventoryOwnership.DeliveryStartDate AS DeliveryStartDate,
		|	SalesInvoiceInventoryOwnership.DeliveryEndDate AS DeliveryEndDate,
		|	SalesInvoiceInventoryOwnership.Ownership AS Ownership,
		|	SalesInvoiceInventoryOwnership.SerialNumber AS SerialNumber,
		|	SalesInvoiceInventoryOwnership.DropShipping AS DropShipping
		|FROM
		|	Document.SalesInvoice.InventoryOwnership AS SalesInvoiceInventoryOwnership
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SalesInvoiceInventoryOwnership.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON SalesInvoiceInventoryOwnership.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON SalesInvoiceInventoryOwnership.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 41 Then
		
		Text = "SELECT DISTINCT
		|	SalesSlipInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.SalesSlip.Inventory AS SalesSlipInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SalesSlipInventory.RevenueGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN SalesSlipInventory.RevenueGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> SalesSlipInventory.RevenueItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesSlipInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN SalesSlipInventory.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	SalesSlipInventory.LineNumber AS LineNumber,
		|	SalesSlipInventory.Products AS Products,
		|	SalesSlipInventory.Characteristic AS Characteristic,
		|	SalesSlipInventory.Batch AS Batch,
		|	SalesSlipInventory.Quantity AS Quantity,
		|	SalesSlipInventory.MeasurementUnit AS MeasurementUnit,
		|	SalesSlipInventory.Price AS Price,
		|	SalesSlipInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	SalesSlipInventory.Amount AS Amount,
		|	SalesSlipInventory.VATRate AS VATRate,
		|	SalesSlipInventory.VATAmount AS VATAmount,
		|	SalesSlipInventory.Total AS Total,
		|	SalesSlipInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|	SalesSlipInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
		|	SalesSlipInventory.ConnectionKey AS ConnectionKey,
		|	SalesSlipInventory.SerialNumbers AS SerialNumbers,
		|	SalesSlipInventory.RevenueGLAccount AS RevenueGLAccount,
		|	SalesSlipInventory.VATOutputGLAccount AS VATOutputGLAccount,
		|	SalesSlipInventory.BundleProduct AS BundleProduct,
		|	SalesSlipInventory.BundleCharacteristic AS BundleCharacteristic,
		|	SalesSlipInventory.CostShare AS CostShare
		|FROM
		|	Document.SalesSlip.Inventory AS SalesSlipInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SalesSlipInventory.RevenueGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON SalesSlipInventory.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 42 Then
		
		Text = "SELECT DISTINCT
		|	SalesSlipInventoryOwnership.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.SalesSlip.InventoryOwnership AS SalesSlipInventoryOwnership
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SalesSlipInventoryOwnership.RevenueGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN SalesSlipInventoryOwnership.RevenueGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> SalesSlipInventoryOwnership.RevenueItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesSlipInventoryOwnership.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""InventoryOwnership"" AS TabularSection,
		|	CASE
		|		WHEN SalesSlipInventoryOwnership.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	SalesSlipInventoryOwnership.LineNumber AS LineNumber,
		|	SalesSlipInventoryOwnership.Products AS Products,
		|	SalesSlipInventoryOwnership.Characteristic AS Characteristic,
		|	SalesSlipInventoryOwnership.Batch AS Batch,
		|	SalesSlipInventoryOwnership.Quantity AS Quantity,
		|	SalesSlipInventoryOwnership.MeasurementUnit AS MeasurementUnit,
		|	SalesSlipInventoryOwnership.Price AS Price,
		|	SalesSlipInventoryOwnership.Amount AS Amount,
		|	SalesSlipInventoryOwnership.VATRate AS VATRate,
		|	SalesSlipInventoryOwnership.VATAmount AS VATAmount,
		|	SalesSlipInventoryOwnership.Total AS Total,
		|	SalesSlipInventoryOwnership.RevenueGLAccount AS RevenueGLAccount,
		|	SalesSlipInventoryOwnership.VATOutputGLAccount AS VATOutputGLAccount,
		|	SalesSlipInventoryOwnership.BundleProduct AS BundleProduct,
		|	SalesSlipInventoryOwnership.BundleCharacteristic AS BundleCharacteristic,
		|	SalesSlipInventoryOwnership.CostShare AS CostShare,
		|	SalesSlipInventoryOwnership.Ownership AS Ownership,
		|	SalesSlipInventoryOwnership.SerialNumber AS SerialNumber
		|FROM
		|	Document.SalesSlip.InventoryOwnership AS SalesSlipInventoryOwnership
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SalesSlipInventoryOwnership.RevenueGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON SalesSlipInventoryOwnership.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 43 Then
		
		Text = "SELECT DISTINCT
		|	ShiftClosureInventory.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.ShiftClosure.Inventory AS ShiftClosureInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ShiftClosureInventory.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON ShiftClosureInventory.COGSGLAccount = TT_MappingCOGS.GLAccount
		|WHERE
		|	(CASE
		|				WHEN ShiftClosureInventory.RevenueGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> ShiftClosureInventory.RevenueItem
		|			OR CASE
		|				WHEN ShiftClosureInventory.COGSGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> ShiftClosureInventory.COGSItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ShiftClosureInventory.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Inventory"" AS TabularSection,
		|	CASE
		|		WHEN ShiftClosureInventory.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	CASE
		|		WHEN ShiftClosureInventory.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS COGSItem,
		|	ShiftClosureInventory.LineNumber AS LineNumber,
		|	ShiftClosureInventory.Products AS Products,
		|	ShiftClosureInventory.Characteristic AS Characteristic,
		|	ShiftClosureInventory.Batch AS Batch,
		|	ShiftClosureInventory.Quantity AS Quantity,
		|	ShiftClosureInventory.MeasurementUnit AS MeasurementUnit,
		|	ShiftClosureInventory.Price AS Price,
		|	ShiftClosureInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	ShiftClosureInventory.Amount AS Amount,
		|	ShiftClosureInventory.VATRate AS VATRate,
		|	ShiftClosureInventory.VATAmount AS VATAmount,
		|	ShiftClosureInventory.Performer AS Performer,
		|	ShiftClosureInventory.Responsible AS Responsible,
		|	ShiftClosureInventory.Total AS Total,
		|	ShiftClosureInventory.DiscountCard AS DiscountCard,
		|	ShiftClosureInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|	ShiftClosureInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
		|	ShiftClosureInventory.SerialNumbers AS SerialNumbers,
		|	ShiftClosureInventory.ConnectionKey AS ConnectionKey,
		|	ShiftClosureInventory.ReceiptNumber AS ReceiptNumber,
		|	ShiftClosureInventory.COGSGLAccount AS COGSGLAccount,
		|	ShiftClosureInventory.InventoryGLAccount AS InventoryGLAccount,
		|	ShiftClosureInventory.RevenueGLAccount AS RevenueGLAccount,
		|	ShiftClosureInventory.VATOutputGLAccount AS VATOutputGLAccount,
		|	ShiftClosureInventory.InventoryReceivedGLAccount AS InventoryReceivedGLAccount
		|FROM
		|	Document.ShiftClosure.Inventory AS ShiftClosureInventory
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ShiftClosureInventory.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON ShiftClosureInventory.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON ShiftClosureInventory.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 44 Then
		
		Text = "SELECT DISTINCT
		|	ShiftClosureInventoryOwnership.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.ShiftClosure.InventoryOwnership AS ShiftClosureInventoryOwnership
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ShiftClosureInventoryOwnership.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON ShiftClosureInventoryOwnership.COGSGLAccount = TT_MappingCOGS.GLAccount
		|WHERE
		|	(CASE
		|				WHEN ShiftClosureInventoryOwnership.RevenueGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> ShiftClosureInventoryOwnership.RevenueItem
		|			OR CASE
		|				WHEN ShiftClosureInventoryOwnership.COGSGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> ShiftClosureInventoryOwnership.COGSItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ShiftClosureInventoryOwnership.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""InventoryOwnership"" AS TabularSection,
		|	CASE
		|		WHEN ShiftClosureInventoryOwnership.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	CASE
		|		WHEN ShiftClosureInventoryOwnership.COGSGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS COGSItem,
		|	ShiftClosureInventoryOwnership.LineNumber AS LineNumber,
		|	ShiftClosureInventoryOwnership.Products AS Products,
		|	ShiftClosureInventoryOwnership.Characteristic AS Characteristic,
		|	ShiftClosureInventoryOwnership.Batch AS Batch,
		|	ShiftClosureInventoryOwnership.Quantity AS Quantity,
		|	ShiftClosureInventoryOwnership.MeasurementUnit AS MeasurementUnit,
		|	ShiftClosureInventoryOwnership.Price AS Price,
		|	ShiftClosureInventoryOwnership.Amount AS Amount,
		|	ShiftClosureInventoryOwnership.VATRate AS VATRate,
		|	ShiftClosureInventoryOwnership.VATAmount AS VATAmount,
		|	ShiftClosureInventoryOwnership.Performer AS Performer,
		|	ShiftClosureInventoryOwnership.Responsible AS Responsible,
		|	ShiftClosureInventoryOwnership.Total AS Total,
		|	ShiftClosureInventoryOwnership.DiscountCard AS DiscountCard,
		|	ShiftClosureInventoryOwnership.ReceiptNumber AS ReceiptNumber,
		|	ShiftClosureInventoryOwnership.COGSGLAccount AS COGSGLAccount,
		|	ShiftClosureInventoryOwnership.InventoryGLAccount AS InventoryGLAccount,
		|	ShiftClosureInventoryOwnership.RevenueGLAccount AS RevenueGLAccount,
		|	ShiftClosureInventoryOwnership.VATOutputGLAccount AS VATOutputGLAccount,
		|	ShiftClosureInventoryOwnership.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	ShiftClosureInventoryOwnership.Ownership AS Ownership,
		|	ShiftClosureInventoryOwnership.SerialNumber AS SerialNumber
		|FROM
		|	Document.ShiftClosure.InventoryOwnership AS ShiftClosureInventoryOwnership
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON ShiftClosureInventoryOwnership.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON ShiftClosureInventoryOwnership.COGSGLAccount = TT_MappingCOGS.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON ShiftClosureInventoryOwnership.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	// begin Drive.FullVersion
	ElsIf QueryNumber = 45 Then
		
		Text = "SELECT DISTINCT
		|	SubcontractorInvoiceIssued.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.SubcontractorInvoiceIssued.Products AS SubcontractorInvoiceIssued
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SubcontractorInvoiceIssued.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON SubcontractorInvoiceIssued.CostOfSalesGLAccount = TT_MappingCOGS.GLAccount
		|WHERE
		|	(CASE
		|				WHEN SubcontractorInvoiceIssued.RevenueGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> SubcontractorInvoiceIssued.RevenueItem
		|			OR CASE
		|				WHEN SubcontractorInvoiceIssued.CostOfSalesGLAccount = &EmptyAccount
		|					THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|				ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|			END <> SubcontractorInvoiceIssued.CostOfSalesItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SubcontractorInvoiceIssued.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Products"" AS TabularSection,
		|	CASE
		|		WHEN SubcontractorInvoiceIssued.RevenueGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS RevenueItem,
		|	CASE
		|		WHEN SubcontractorInvoiceIssued.CostOfSalesGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingCOGS.IncomeAndExpenseItem, &Undefined)
		|	END AS CostOfSalesItem,
		|	SubcontractorInvoiceIssued.LineNumber AS LineNumber,
		|	SubcontractorInvoiceIssued.Products AS Products,
		|	SubcontractorInvoiceIssued.Characteristic AS Characteristic,
		|	SubcontractorInvoiceIssued.Quantity AS Quantity,
		|	SubcontractorInvoiceIssued.MeasurementUnit AS MeasurementUnit,
		|	SubcontractorInvoiceIssued.Specification AS Specification,
		|	SubcontractorInvoiceIssued.Price AS Price,
		|	SubcontractorInvoiceIssued.Amount AS Amount,
		|	SubcontractorInvoiceIssued.VATRate AS VATRate,
		|	SubcontractorInvoiceIssued.VATAmount AS VATAmount,
		|	SubcontractorInvoiceIssued.Total AS Total,
		|	SubcontractorInvoiceIssued.Ownership AS Ownership,
		|	SubcontractorInvoiceIssued.CostOfSalesGLAccount AS CostOfSalesGLAccount,
		|	SubcontractorInvoiceIssued.ConsumptionGLAccount AS ConsumptionGLAccount,
		|	SubcontractorInvoiceIssued.RevenueGLAccount AS RevenueGLAccount,
		|	SubcontractorInvoiceIssued.VATOutputGLAccount AS VATOutputGLAccount
		|FROM
		|	Document.SubcontractorInvoiceIssued.Products AS SubcontractorInvoiceIssued
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SubcontractorInvoiceIssued.RevenueGLAccount = TT_Mapping.GLAccount
		|		LEFT JOIN TT_Mapping AS TT_MappingCOGS
		|		ON SubcontractorInvoiceIssued.CostOfSalesGLAccount = TT_MappingCOGS.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON SubcontractorInvoiceIssued.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	// end Drive.FullVersion
	ElsIf QueryNumber = 46 Then
		
		Text = "SELECT DISTINCT
		|	SupplierInvoiceExpenses.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SupplierInvoiceExpenses.InventoryGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN SupplierInvoiceExpenses.InventoryGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> SupplierInvoiceExpenses.ExpenseItem
		|	AND NOT SupplierInvoiceExpenses.Ref.IncludeExpensesInCostPrice
		|	AND SupplierInvoiceExpenses.Ref.OperationKind <> VALUE(Enum.OperationTypesSupplierInvoice.ZeroInvoice)
		|	AND (SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
		|			OR SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
		|			OR SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SupplierInvoiceExpenses.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Expenses"" AS TabularSection,
		|	CASE
		|		WHEN SupplierInvoiceExpenses.InventoryGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	SupplierInvoiceExpenses.LineNumber AS LineNumber,
		|	SupplierInvoiceExpenses.Products AS Products,
		|	SupplierInvoiceExpenses.MeasurementUnit AS MeasurementUnit,
		|	SupplierInvoiceExpenses.Quantity AS Quantity,
		|	SupplierInvoiceExpenses.Price AS Price,
		|	SupplierInvoiceExpenses.Amount AS Amount,
		|	SupplierInvoiceExpenses.VATRate AS VATRate,
		|	SupplierInvoiceExpenses.VATAmount AS VATAmount,
		|	SupplierInvoiceExpenses.PurchaseOrder AS PurchaseOrder,
		|	SupplierInvoiceExpenses.Total AS Total,
		|	SupplierInvoiceExpenses.Order AS Order,
		|	SupplierInvoiceExpenses.StructuralUnit AS StructuralUnit,
		|	SupplierInvoiceExpenses.BusinessLine AS BusinessLine,
		|	SupplierInvoiceExpenses.Content AS Content,
		|	SupplierInvoiceExpenses.ReverseChargeVATRate AS ReverseChargeVATRate,
		|	SupplierInvoiceExpenses.ReverseChargeVATAmount AS ReverseChargeVATAmount,
		|	SupplierInvoiceExpenses.InventoryGLAccount AS InventoryGLAccount,
		|	SupplierInvoiceExpenses.VATInputGLAccount AS VATInputGLAccount,
		|	SupplierInvoiceExpenses.VATOutputGLAccount AS VATOutputGLAccount,
		|	SupplierInvoiceExpenses.CrossReference AS CrossReference,
		|	SupplierInvoiceExpenses.Project AS Project,
		|	CASE
		|		WHEN SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
		|				OR SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
		|				OR SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterExpense
		|FROM
		|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON SupplierInvoiceExpenses.InventoryGLAccount = TT_Mapping.GLAccount
		|			AND (SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
		|				OR SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
		|				OR SupplierInvoiceExpenses.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON SupplierInvoiceExpenses.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 47 Then
		
		Text = "SELECT DISTINCT
		|	TaxAccrualTaxes.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.TaxAccrual.Taxes AS TaxAccrualTaxes
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON TaxAccrualTaxes.Correspondence = TT_Mapping.GLAccount
		|WHERE
		|	TaxAccrualTaxes.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
		|	AND TaxAccrualTaxes.Correspondence.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.Revenue))
		|	AND CASE
		|			WHEN TaxAccrualTaxes.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> TaxAccrualTaxes.ExpenseItem
		|
		|UNION ALL
		|
		|SELECT
		|	TaxAccrualTaxes.Ref
		|FROM
		|	Document.TaxAccrual.Taxes AS TaxAccrualTaxes
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON TaxAccrualTaxes.Correspondence = TT_Mapping.GLAccount
		|WHERE
		|	TaxAccrualTaxes.Ref.OperationKind <> VALUE(Enum.OperationTypesTaxAccrual.Accrual)
		|	AND TaxAccrualTaxes.Correspondence.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Revenue), VALUE(Enum.GLAccountsTypes.OtherIncome))
		|	AND CASE
		|			WHEN TaxAccrualTaxes.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> TaxAccrualTaxes.IncomeItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TaxAccrualTaxes.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Taxes"" AS TabularSection,
		|	CASE
		|		WHEN TaxAccrualTaxes.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	UNDEFINED AS IncomeItem,
		|	TaxAccrualTaxes.LineNumber AS LineNumber,
		|	TaxAccrualTaxes.TaxKind AS TaxKind,
		|	TaxAccrualTaxes.Amount AS Amount,
		|	TaxAccrualTaxes.Correspondence AS Correspondence,
		|	TaxAccrualTaxes.BusinessLine AS BusinessLine,
		|	TaxAccrualTaxes.SalesOrder AS SalesOrder,
		|	TaxAccrualTaxes.Department AS Department,
		|	TaxAccrualTaxes.Project AS Project,
		|	FALSE AS RegisterIncome,
		|	CASE
		|		WHEN TaxAccrualTaxes.Correspondence.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.Revenue))
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterExpense
		|FROM
		|	Document.TaxAccrual.Taxes AS TaxAccrualTaxes
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON TaxAccrualTaxes.Correspondence = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON TaxAccrualTaxes.Ref = TT_Refs.DocumentRef
		|WHERE
		|	TaxAccrualTaxes.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
		|
		|UNION ALL
		|
		|SELECT
		|	TaxAccrualTaxes.Ref,
		|	0,
		|	""Taxes"",
		|	UNDEFINED,
		|	CASE
		|		WHEN TaxAccrualTaxes.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END,
		|	TaxAccrualTaxes.LineNumber,
		|	TaxAccrualTaxes.TaxKind,
		|	TaxAccrualTaxes.Amount,
		|	TaxAccrualTaxes.Correspondence,
		|	TaxAccrualTaxes.BusinessLine,
		|	TaxAccrualTaxes.SalesOrder,
		|	TaxAccrualTaxes.Department,
		|	TaxAccrualTaxes.Project,
		|	CASE
		|		WHEN TaxAccrualTaxes.Correspondence.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.OtherIncome), VALUE(Enum.GLAccountsTypes.Revenue))
		|			THEN TRUE
		|		ELSE FALSE
		|	END,
		|	FALSE
		|FROM
		|	Document.TaxAccrual.Taxes AS TaxAccrualTaxes
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON TaxAccrualTaxes.Correspondence = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON TaxAccrualTaxes.Ref = TT_Refs.DocumentRef
		|WHERE
		|	TaxAccrualTaxes.Ref.OperationKind <> VALUE(Enum.OperationTypesTaxAccrual.Accrual)
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 48 Then
		
		Text = "SELECT DISTINCT
		|	TransferAndPromotionEarningsDeductions.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.TransferAndPromotion.EarningsDeductions AS TransferAndPromotionEarningsDeductions
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON TransferAndPromotionEarningsDeductions.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	TransferAndPromotionEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
		|	AND CASE
		|			WHEN TransferAndPromotionEarningsDeductions.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> TransferAndPromotionEarningsDeductions.ExpenseItem
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	TransferAndPromotionEarningsDeductions.Ref AS DocumentRef
		|FROM
		|	Document.TransferAndPromotion.EarningsDeductions AS TransferAndPromotionEarningsDeductions
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON TransferAndPromotionEarningsDeductions.GLExpenseAccount = TT_Mapping.GLAccount
		|WHERE
		|	TransferAndPromotionEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
		|	AND CASE
		|			WHEN TransferAndPromotionEarningsDeductions.GLExpenseAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> TransferAndPromotionEarningsDeductions.IncomeItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TransferAndPromotionEarningsDeductions.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""EarningsDeductions"" AS TabularSection,
		|	CASE
		|		WHEN TransferAndPromotionEarningsDeductions.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN TransferAndPromotionEarningsDeductions.GLExpenseAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_MappingIncome.IncomeAndExpenseItem, &Undefined)
		|	END AS IncomeItem,
		|	TransferAndPromotionEarningsDeductions.LineNumber AS LineNumber,
		|	TransferAndPromotionEarningsDeductions.EarningAndDeductionType AS EarningAndDeductionType,
		|	TransferAndPromotionEarningsDeductions.Amount AS Amount,
		|	TransferAndPromotionEarningsDeductions.Currency AS Currency,
		|	TransferAndPromotionEarningsDeductions.GLExpenseAccount AS GLExpenseAccount,
		|	TransferAndPromotionEarningsDeductions.Actuality AS Actuality,
		|	TransferAndPromotionEarningsDeductions.ConnectionKey AS ConnectionKey
		|FROM
		|	Document.TransferAndPromotion.EarningsDeductions AS TransferAndPromotionEarningsDeductions
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON TransferAndPromotionEarningsDeductions.GLExpenseAccount = TT_Mapping.GLAccount
		|			AND TransferAndPromotionEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
		|		LEFT JOIN TT_Mapping AS TT_MappingIncome
		|		ON TransferAndPromotionEarningsDeductions.GLExpenseAccount = TT_MappingIncome.GLAccount
		|			AND TransferAndPromotionEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON TransferAndPromotionEarningsDeductions.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 49 Then
		
		Text = "SELECT DISTINCT
		|	WorkOrderMaterials.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.WorkOrder.Materials AS WorkOrderMaterials
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON WorkOrderMaterials.ConsumptionGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN WorkOrderMaterials.ConsumptionGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> WorkOrderMaterials.ExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrderMaterials.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Materials"" AS TabularSection,
		|	CASE
		|		WHEN WorkOrderMaterials.ConsumptionGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	WorkOrderMaterials.LineNumber AS LineNumber,
		|	WorkOrderMaterials.ConnectionKey AS ConnectionKey,
		|	WorkOrderMaterials.Products AS Products,
		|	WorkOrderMaterials.Characteristic AS Characteristic,
		|	WorkOrderMaterials.Batch AS Batch,
		|	WorkOrderMaterials.Quantity AS Quantity,
		|	WorkOrderMaterials.Reserve AS Reserve,
		|	WorkOrderMaterials.ReserveShipment AS ReserveShipment,
		|	WorkOrderMaterials.MeasurementUnit AS MeasurementUnit,
		|	WorkOrderMaterials.StorageBin AS StorageBin,
		|	WorkOrderMaterials.SerialNumbers AS SerialNumbers,
		|	WorkOrderMaterials.ConnectionKeySerialNumbers AS ConnectionKeySerialNumbers,
		|	WorkOrderMaterials.FromBOM AS FromBOM,
		|	WorkOrderMaterials.InventoryGLAccount AS InventoryGLAccount,
		|	WorkOrderMaterials.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
		|	WorkOrderMaterials.ConsumptionGLAccount AS ConsumptionGLAccount,
		|	WorkOrderMaterials.Ownership AS Ownership,
		|	WorkOrderMaterials.Project AS Project,
		|	WorkOrderMaterials.RegisterExpense AS RegisterExpense
		|FROM
		|	Document.WorkOrder.Materials AS WorkOrderMaterials
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON WorkOrderMaterials.ConsumptionGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON WorkOrderMaterials.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 50 Then
		
		Text = "SELECT DISTINCT
		|	ArApAdjustmentsDebitor.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.ArApAdjustments.Debitor AS ArApAdjustmentsDebitor
		|		INNER JOIN Document.ArApAdjustments AS ArApAdjustments
		|		ON ArApAdjustmentsDebitor.Ref = ArApAdjustments.Ref
		|			AND (ArApAdjustments.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment))
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (ArApAdjustments.Correspondence = TT_Mapping.GLAccount)
		|WHERE
		|	(CASE
		|				WHEN ArApAdjustments.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|						OR ArApAdjustments.Correspondence = &EmptyAccount
		|					THEN &Undefined
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> ArApAdjustmentsDebitor.ExpenseItem
		|			OR CASE
		|				WHEN ArApAdjustments.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|						AND ArApAdjustments.Correspondence <> &EmptyAccount
		|					THEN ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|				ELSE &Undefined
		|			END <> ArApAdjustmentsDebitor.IncomeItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ArApAdjustmentsDebitor.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Debitor"" AS TabularSection,
		|	CASE
		|		WHEN ArApAdjustments.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|				OR ArApAdjustments.Correspondence = &EmptyAccount
		|			THEN &Undefined
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN ArApAdjustments.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|				AND ArApAdjustments.Correspondence <> &EmptyAccount
		|			THEN ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		ELSE &Undefined
		|	END AS IncomeItem,
		|	ArApAdjustmentsDebitor.LineNumber AS LineNumber,
		|	ArApAdjustmentsDebitor.Contract AS Contract,
		|	ArApAdjustmentsDebitor.Document AS Document,
		|	ArApAdjustmentsDebitor.Order AS Order,
		|	ArApAdjustmentsDebitor.Multiplicity AS Multiplicity,
		|	ArApAdjustmentsDebitor.ExchangeRate AS ExchangeRate,
		|	ArApAdjustmentsDebitor.AdvanceFlag AS AdvanceFlag,
		|	ArApAdjustmentsDebitor.SettlementsAmount AS SettlementsAmount,
		|	ArApAdjustmentsDebitor.AccountingAmount AS AccountingAmount,
		|	ArApAdjustmentsDebitor.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
		|	ArApAdjustmentsDebitor.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
		|	ArApAdjustmentsDebitor.Project AS Project
		|FROM
		|	Document.ArApAdjustments.Debitor AS ArApAdjustmentsDebitor
		|		INNER JOIN Document.ArApAdjustments AS ArApAdjustments
		|		ON ArApAdjustmentsDebitor.Ref = ArApAdjustments.Ref
		|			AND (ArApAdjustments.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment))
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (ArApAdjustments.Correspondence = TT_Mapping.GLAccount)
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON ArApAdjustmentsDebitor.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 51 Then
		
		Text = "SELECT DISTINCT
		|	ArApAdjustmentsCreditor.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.ArApAdjustments.Creditor AS ArApAdjustmentsCreditor
		|		INNER JOIN Document.ArApAdjustments AS ArApAdjustments
		|		ON ArApAdjustmentsCreditor.Ref = ArApAdjustments.Ref
		|			AND (ArApAdjustments.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment))
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (ArApAdjustments.Correspondence = TT_Mapping.GLAccount)
		|WHERE
		|	(CASE
		|				WHEN ArApAdjustments.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|						OR ArApAdjustments.Correspondence = &EmptyAccount
		|					THEN &Undefined
		|				ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|			END <> ArApAdjustmentsCreditor.ExpenseItem
		|			OR CASE
		|				WHEN ArApAdjustments.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|						AND ArApAdjustments.Correspondence <> &EmptyAccount
		|					THEN ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|				ELSE &Undefined
		|			END <> ArApAdjustmentsCreditor.IncomeItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ArApAdjustmentsCreditor.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""Creditor"" AS TabularSection,
		|	CASE
		|		WHEN ArApAdjustments.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|				OR ArApAdjustments.Correspondence = &EmptyAccount
		|			THEN &Undefined
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN ArApAdjustments.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
		|				AND ArApAdjustments.Correspondence <> &EmptyAccount
		|			THEN ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		ELSE &Undefined
		|	END AS IncomeItem,
		|	ArApAdjustmentsCreditor.LineNumber AS LineNumber,
		|	ArApAdjustmentsCreditor.Contract AS Contract,
		|	ArApAdjustmentsCreditor.Document AS Document,
		|	ArApAdjustmentsCreditor.Order AS Order,
		|	ArApAdjustmentsCreditor.Multiplicity AS Multiplicity,
		|	ArApAdjustmentsCreditor.ExchangeRate AS ExchangeRate,
		|	ArApAdjustmentsCreditor.AdvanceFlag AS AdvanceFlag,
		|	ArApAdjustmentsCreditor.SettlementsAmount AS SettlementsAmount,
		|	ArApAdjustmentsCreditor.AccountingAmount AS AccountingAmount,
		|	ArApAdjustmentsCreditor.AccountsPayableGLAccount AS AccountsPayableGLAccount,
		|	ArApAdjustmentsCreditor.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
		|	ArApAdjustmentsCreditor.Project AS Project
		|FROM
		|	Document.ArApAdjustments.Creditor AS ArApAdjustmentsCreditor
		|		INNER JOIN Document.ArApAdjustments AS ArApAdjustments
		|		ON ArApAdjustmentsCreditor.Ref = ArApAdjustments.Ref
		|			AND (ArApAdjustments.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment))
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (ArApAdjustments.Correspondence = TT_Mapping.GLAccount)
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON ArApAdjustmentsCreditor.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
		
	ElsIf QueryNumber = 52 Then
		
		Text = "SELECT DISTINCT
		|	FixedAssetSaleFixedAssets.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.FixedAssetSale.FixedAssets AS FixedAssetSaleFixedAssets
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (&GLAccountCostOfSales = TT_Mapping.GLAccount)
		|		LEFT JOIN TT_Mapping AS TT_MappingIncome
		|		ON (&GLAccountRevenueFromSales = TT_MappingIncome.GLAccount)
		|WHERE
		|	(ISNULL(TT_MappingIncome.IncomeAndExpenseItem, &Undefined) <> FixedAssetSaleFixedAssets.IncomeItem
		|			OR ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined) <> FixedAssetSaleFixedAssets.ExpenseItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FixedAssetSaleFixedAssets.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""FixedAssets"" AS TabularSection,
		|	ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined) AS ExpenseItem,
		|	ISNULL(TT_MappingIncome.IncomeAndExpenseItem, &Undefined) AS IncomeItem,
		|	FixedAssetSaleFixedAssets.LineNumber AS LineNumber,
		|	FixedAssetSaleFixedAssets.FixedAsset AS FixedAsset,
		|	FixedAssetSaleFixedAssets.Cost AS Cost,
		|	FixedAssetSaleFixedAssets.DepreciatedCost AS DepreciatedCost,
		|	FixedAssetSaleFixedAssets.Depreciation AS Depreciation,
		|	FixedAssetSaleFixedAssets.MonthlyDepreciation AS MonthlyDepreciation,
		|	FixedAssetSaleFixedAssets.Amount AS Amount,
		|	FixedAssetSaleFixedAssets.VATRate AS VATRate,
		|	FixedAssetSaleFixedAssets.VATAmount AS VATAmount,
		|	FixedAssetSaleFixedAssets.Total AS Total,
		|	FixedAssetSaleFixedAssets.Project AS Project
		|FROM
		|	Document.FixedAssetSale.FixedAssets AS FixedAssetSaleFixedAssets
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (&GLAccountCostOfSales = TT_Mapping.GLAccount)
		|		LEFT JOIN TT_Mapping AS TT_MappingIncome
		|		ON (&GLAccountRevenueFromSales = TT_MappingIncome.GLAccount)
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON FixedAssetSaleFixedAssets.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 53 Then
		
		Text = "SELECT
		|	FixedAssetWriteOff.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN FixedAssetWriteOff.Correspondence = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem,
		|	CASE
		|		WHEN FixedAssetWriteOff.Correspondence.TypeOfAccount IN (&TypeOfAccounts)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS RegisterExpense
		|FROM
		|	Document.FixedAssetWriteOff AS FixedAssetWriteOff
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (FixedAssetWriteOff.Correspondence = TT_Mapping.GLAccount)
		|WHERE
		|	CASE
		|			WHEN FixedAssetWriteOff.Correspondence = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> FixedAssetWriteOff.ExpenseItem
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 54 Then
		
		Text = "SELECT
		|	OnlineReceipt.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN &FeeExpensesGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem
		|FROM
		|	Document.OnlineReceipt AS OnlineReceipt
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (&FeeExpensesGLAccount = TT_Mapping.GLAccount)
		|WHERE
		|	CASE
		|			WHEN &FeeExpensesGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> OnlineReceipt.ExpenseItem
		|	AND NOT OnlineReceipt.POSTerminal.WithholdFeeOnPayout
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 55 Then
		
		Text = "SELECT
		|	OnlinePayment.Ref AS DocumentRef,
		|	1 AS Mark,
		|	CASE
		|		WHEN &FeeExpensesGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS ExpenseItem
		|FROM
		|	Document.OnlinePayment AS OnlinePayment
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON (&FeeExpensesGLAccount = TT_Mapping.GLAccount)
		|WHERE
		|	CASE
		|			WHEN &FeeExpensesGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> OnlinePayment.ExpenseItem
		|	AND NOT OnlinePayment.POSTerminal.WithholdFeeOnPayout
		|TOTALS
		|	MAX(Mark)
		|BY
		|	DocumentRef";
		
	ElsIf QueryNumber = 56 Then
		
		Text = "SELECT DISTINCT
		|	CashReceiptPaymentDetails.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.CashReceipt.PaymentDetails AS CashReceiptPaymentDetails
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CashReceiptPaymentDetails.DiscountAllowedGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN CashReceiptPaymentDetails.DiscountAllowedGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> CashReceiptPaymentDetails.DiscountAllowedExpenseItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CashReceiptPaymentDetails.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""PaymentDetails"" AS TabularSection,
		|	CASE
		|		WHEN CashReceiptPaymentDetails.DiscountAllowedGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS DiscountAllowedExpenseItem,
		|	CashReceiptPaymentDetails.LineNumber AS LineNumber,
		|	CashReceiptPaymentDetails.Contract AS Contract,
		|	CashReceiptPaymentDetails.AdvanceFlag AS AdvanceFlag,
		|	CashReceiptPaymentDetails.Document AS Document,
		|	CashReceiptPaymentDetails.SettlementsAmount AS SettlementsAmount,
		|	CashReceiptPaymentDetails.ExchangeRate AS ExchangeRate,
		|	CashReceiptPaymentDetails.Multiplicity AS Multiplicity,
		|	CashReceiptPaymentDetails.PaymentAmount AS PaymentAmount,
		|	CashReceiptPaymentDetails.VATRate AS VATRate,
		|	CashReceiptPaymentDetails.VATAmount AS VATAmount,
		|	CashReceiptPaymentDetails.Order AS Order,
		|	CashReceiptPaymentDetails.PlanningDocument AS PlanningDocument,
		|	CashReceiptPaymentDetails.TypeOfAmount AS TypeOfAmount,
		|	CashReceiptPaymentDetails.EPDAmount AS EPDAmount,
		|	CashReceiptPaymentDetails.SettlementsEPDAmount AS SettlementsEPDAmount,
		|	CashReceiptPaymentDetails.ExistsEPD AS ExistsEPD,
		|	CashReceiptPaymentDetails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
		|	CashReceiptPaymentDetails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
		|	CashReceiptPaymentDetails.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
		|	CashReceiptPaymentDetails.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
		|	CashReceiptPaymentDetails.DiscountAllowedGLAccount AS DiscountAllowedGLAccount,
		|	CashReceiptPaymentDetails.Item AS Item,
		|	CashReceiptPaymentDetails.ThirdPartyPayerGLAccount AS ThirdPartyPayerGLAccount,
		|	CashReceiptPaymentDetails.ThirdPartyCustomer AS ThirdPartyCustomer,
		|	CashReceiptPaymentDetails.ThirdPartyCustomerContract AS ThirdPartyCustomerContract,
		|	CashReceiptPaymentDetails.Project AS Project,
		|	CashReceiptPaymentDetails.VATOutputGLAccount AS VATOutputGLAccount
		|FROM
		|	Document.CashReceipt.PaymentDetails AS CashReceiptPaymentDetails
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CashReceiptPaymentDetails.DiscountAllowedGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON CashReceiptPaymentDetails.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	ElsIf QueryNumber = 57 Then
		
		Text = "SELECT DISTINCT
		|	CashVoucherPaymentDetails.Ref AS DocumentRef
		|INTO TT_Refs
		|FROM
		|	Document.CashVoucher.PaymentDetails AS CashVoucherPaymentDetails
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CashVoucherPaymentDetails.DiscountReceivedGLAccount = TT_Mapping.GLAccount
		|WHERE
		|	CASE
		|			WHEN CashVoucherPaymentDetails.DiscountReceivedGLAccount = &EmptyAccount
		|				THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|			ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|		END <> CashVoucherPaymentDetails.DiscountReceivedIncomeItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CashVoucherPaymentDetails.Ref AS DocumentRef,
		|	0 AS Mark,
		|	""PaymentDetails"" AS TabularSection,
		|	CASE
		|		WHEN CashVoucherPaymentDetails.DiscountReceivedGLAccount = &EmptyAccount
		|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
		|		ELSE ISNULL(TT_Mapping.IncomeAndExpenseItem, &Undefined)
		|	END AS DiscountReceivedIncomeItem,
		|	CashVoucherPaymentDetails.LineNumber AS LineNumber,
		|	CashVoucherPaymentDetails.Contract AS Contract,
		|	CashVoucherPaymentDetails.AdvanceFlag AS AdvanceFlag,
		|	CashVoucherPaymentDetails.Document AS Document,
		|	CashVoucherPaymentDetails.SettlementsAmount AS SettlementsAmount,
		|	CashVoucherPaymentDetails.ExchangeRate AS ExchangeRate,
		|	CashVoucherPaymentDetails.Multiplicity AS Multiplicity,
		|	CashVoucherPaymentDetails.PaymentAmount AS PaymentAmount,
		|	CashVoucherPaymentDetails.VATRate AS VATRate,
		|	CashVoucherPaymentDetails.VATAmount AS VATAmount,
		|	CashVoucherPaymentDetails.Order AS Order,
		|	CashVoucherPaymentDetails.PlanningDocument AS PlanningDocument,
		|	CashVoucherPaymentDetails.TypeOfAmount AS TypeOfAmount,
		|	CashVoucherPaymentDetails.EPDAmount AS EPDAmount,
		|	CashVoucherPaymentDetails.SettlementsEPDAmount AS SettlementsEPDAmount,
		|	CashVoucherPaymentDetails.ExistsEPD AS ExistsEPD,
		|	CashVoucherPaymentDetails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
		|	CashVoucherPaymentDetails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
		|	CashVoucherPaymentDetails.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
		|	CashVoucherPaymentDetails.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
		|	CashVoucherPaymentDetails.DiscountReceivedGLAccount AS DiscountReceivedGLAccount,
		|	CashVoucherPaymentDetails.VATInputGLAccount AS VATInputGLAccount,
		|	CashVoucherPaymentDetails.Item AS Item,
		|	CashVoucherPaymentDetails.Project AS Project
		|FROM
		|	Document.CashVoucher.PaymentDetails AS CashVoucherPaymentDetails
		|		LEFT JOIN TT_Mapping AS TT_Mapping
		|		ON CashVoucherPaymentDetails.DiscountReceivedGLAccount = TT_Mapping.GLAccount
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON CashVoucherPaymentDetails.Ref = TT_Refs.DocumentRef
		|
		|ORDER BY
		|	LineNumber
		|TOTALS
		|	MAX(Mark),
		|	MAX(TabularSection)
		|BY
		|	DocumentRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_Refs";
		
	EndIf;
	
	Return Text;
	
EndFunction

Function GetQueryTextForInventoryRegisters()
	
	Return
	"SELECT DISTINCT
	|	Inventory.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		INNER JOIN AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		ON Inventory.Recorder = IncomeAndExpenses.Recorder
	|WHERE
	|	(Inventory.Recorder REFS Document.AccountSalesFromConsignee
	|			OR Inventory.Recorder REFS Document.CreditNote
	|			OR Inventory.Recorder REFS Document.InventoryTransfer
	|			OR Inventory.Recorder REFS Document.SalesInvoice
	|			OR Inventory.Recorder REFS Document.ShiftClosure
	// begin Drive.FullVersion
	|			OR Inventory.Recorder REFS Document.SubcontractorInvoiceIssued
	// end Drive.FullVersion
	|			OR Inventory.Recorder REFS Document.WorkOrder)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	InventoryCostLayer.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|		INNER JOIN AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		ON InventoryCostLayer.Recorder = IncomeAndExpenses.Recorder
	|WHERE
	|	(InventoryCostLayer.Recorder REFS Document.InventoryTransfer
	|			OR InventoryCostLayer.Recorder REFS Document.InventoryWriteOff
	|			OR InventoryCostLayer.Recorder REFS Document.SalesInvoice
	|			OR InventoryCostLayer.Recorder REFS Document.ShiftClosure
	|			OR InventoryCostLayer.Recorder REFS Document.WorkOrder)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	LandedCosts.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|		INNER JOIN AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		ON LandedCosts.Recorder = IncomeAndExpenses.Recorder
	|WHERE
	|	(LandedCosts.Recorder REFS Document.InventoryTransfer
	|			OR LandedCosts.Recorder REFS Document.InventoryWriteOff
	|			OR LandedCosts.Recorder REFS Document.SalesInvoice
	|			OR LandedCosts.Recorder REFS Document.ShiftClosure
	|			OR LandedCosts.Recorder REFS Document.WorkOrder)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Inventory.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		LEFT JOIN TT_Mapping AS TT_Mapping1
	|		ON Inventory.GLAccount = TT_Mapping1.GLAccount
	|		LEFT JOIN TT_Mapping AS TT_Mapping2
	|		ON Inventory.CorrGLAccount = TT_Mapping2.GLAccount
	|WHERE
	|	(Inventory.Recorder REFS Document.GoodsReceipt
	|			OR Inventory.Recorder REFS Document.GoodsIssue)
	|	AND (NOT TT_Mapping1.GLAccount IS NULL
	|			OR NOT TT_Mapping2.GLAccount IS NULL)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	InventoryCostLayer.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|		LEFT JOIN TT_Mapping AS TT_Mapping1
	|		ON InventoryCostLayer.GLAccount = TT_Mapping1.GLAccount
	|		LEFT JOIN TT_Mapping AS TT_Mapping2
	|		ON InventoryCostLayer.CorrGLAccount = TT_Mapping2.GLAccount
	|WHERE
	|	(InventoryCostLayer.Recorder REFS Document.GoodsReceipt
	|			OR InventoryCostLayer.Recorder REFS Document.GoodsIssue)
	|	AND (NOT TT_Mapping1.GLAccount IS NULL
	|			OR NOT TT_Mapping2.GLAccount IS NULL)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	LandedCosts.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|		LEFT JOIN TT_Mapping AS TT_Mapping1
	|		ON LandedCosts.GLAccount = TT_Mapping1.GLAccount
	|		LEFT JOIN TT_Mapping AS TT_Mapping2
	|		ON LandedCosts.CorrGLAccount = TT_Mapping2.GLAccount
	|WHERE
	|	(LandedCosts.Recorder REFS Document.GoodsReceipt
	|			OR LandedCosts.Recorder REFS Document.GoodsIssue)
	|	AND (NOT TT_Mapping1.GLAccount IS NULL
	|			OR NOT TT_Mapping2.GLAccount IS NULL)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Inventory.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		LEFT JOIN TT_Mapping AS TT_Mapping1
	|		ON Inventory.GLAccount = TT_Mapping1.GLAccount
	|		LEFT JOIN TT_Mapping AS TT_Mapping2
	|		ON Inventory.CorrGLAccount = TT_Mapping2.GLAccount
	|WHERE
	|	(Inventory.Recorder REFS Document.InventoryWriteOff
	// begin Drive.FullVersion
	|			OR Inventory.Recorder REFS Document.ManufacturingOperation
	// end Drive.FullVersion
	|			OR Inventory.Recorder REFS Document.MonthEndClosing
	|			OR Inventory.Recorder REFS Document.SupplierInvoice)
	|	AND (NOT TT_Mapping1.GLAccount IS NULL
	|			OR NOT TT_Mapping2.GLAccount IS NULL)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	InventoryCostLayer.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|		LEFT JOIN TT_Mapping AS TT_Mapping1
	|		ON InventoryCostLayer.GLAccount = TT_Mapping1.GLAccount
	|		LEFT JOIN TT_Mapping AS TT_Mapping2
	|		ON InventoryCostLayer.CorrGLAccount = TT_Mapping2.GLAccount
	|WHERE
	|	(InventoryCostLayer.Recorder REFS Document.InventoryWriteOff
	// begin Drive.FullVersion
	|			OR InventoryCostLayer.Recorder REFS Document.ManufacturingOperation
	// end Drive.FullVersion
	|			OR InventoryCostLayer.Recorder REFS Document.SupplierInvoice)
	|	AND (NOT TT_Mapping1.GLAccount IS NULL
	|			OR NOT TT_Mapping2.GLAccount IS NULL)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	LandedCosts.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|		LEFT JOIN TT_Mapping AS TT_Mapping1
	|		ON LandedCosts.GLAccount = TT_Mapping1.GLAccount
	|		LEFT JOIN TT_Mapping AS TT_Mapping2
	|		ON LandedCosts.CorrGLAccount = TT_Mapping2.GLAccount
	|WHERE
	|	(LandedCosts.Recorder REFS Document.InventoryWriteOff
	// begin Drive.FullVersion
	|			OR LandedCosts.Recorder REFS Document.ManufacturingOperation
	// end Drive.FullVersion
	|			OR LandedCosts.Recorder REFS Document.MonthEndClosing)
	|	AND (NOT TT_Mapping1.GLAccount IS NULL
	|			OR NOT TT_Mapping2.GLAccount IS NULL)";
	
EndFunction

Function GetQueryTextForProfitEstimation()
	
	Return
	"SELECT DISTINCT
	|	SalesOrderEstimate.Ref AS Ref
	|FROM
	|	Document.SalesOrder.Estimate AS SalesOrderEstimate
	|		INNER JOIN TT_Mapping AS TT_Mapping
	|		ON SalesOrderEstimate.Products = TT_Mapping.GLAccount";
	
EndFunction

Function GetOtherDefaultItemTable()
	
	ItemTable = New ValueTable;
	ItemTable.Columns.Add("GLAccount", New TypeDescription("ChartOfAccountsRef.PrimaryChartOfAccounts"));
	ItemTable.Columns.Add("DefaultIncomeAndExpenseItem", New TypeDescription("CatalogRef.DefaultIncomeAndExpenseItems"));
	
	MainLineGLA = Common.ObjectAttributesValues(Catalogs.LinesOfBusiness.MainLine, "GLAccountRevenueFromSales,GLAccountCostOfSales");
	If ValueIsFilled(MainLineGLA.GLAccountRevenueFromSales) Then
		NewRow = ItemTable.Add();
		NewRow.GLAccount = MainLineGLA.GLAccountRevenueFromSales;
		NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.Revenue;
	EndIf;
	If ValueIsFilled(MainLineGLA.GLAccountCostOfSales) Then
		NewRow = ItemTable.Add();
		NewRow.GLAccount = MainLineGLA.GLAccountCostOfSales;
		NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.COGS;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	|	ProductGLAccounts.PurchaseReturn AS PurchaseReturn,
	|	CASE
	|		WHEN ProductGLAccounts.Company = VALUE(Catalog.Companies.EmptyRef)
	|			THEN 1000
	|		ELSE 0
	|	END + CASE
	|		WHEN ProductGLAccounts.ProductCategory = VALUE(Catalog.ProductsCategories.EmptyRef)
	|			THEN 100
	|		ELSE 0
	|	END + CASE
	|		WHEN ProductGLAccounts.Product = VALUE(Catalog.Products.EmptyRef)
	|			THEN 10
	|		ELSE 0
	|	END + CASE
	|		WHEN ProductGLAccounts.StructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef)
	|			THEN 1
	|		ELSE 0
	|	END AS Order
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|
	|ORDER BY
	|	Order DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	ProductGLAccounts.SalesReturn AS SalesReturn,
	|	CASE
	|		WHEN ProductGLAccounts.Company = VALUE(Catalog.Companies.EmptyRef)
	|			THEN 1000
	|		ELSE 0
	|	END + CASE
	|		WHEN ProductGLAccounts.ProductCategory = VALUE(Catalog.ProductsCategories.EmptyRef)
	|			THEN 100
	|		ELSE 0
	|	END + CASE
	|		WHEN ProductGLAccounts.Product = VALUE(Catalog.Products.EmptyRef)
	|			THEN 10
	|		ELSE 0
	|	END + CASE
	|		WHEN ProductGLAccounts.StructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef)
	|			THEN 1
	|		ELSE 0
	|	END AS Order
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|
	|ORDER BY
	|	Order DESC";
	
	QueryResult = Query.ExecuteBatch();
	
	PurchaseReturnSelection = QueryResult[0].Select();
	If PurchaseReturnSelection.Next() Then
		NewRow = ItemTable.Add();
		NewRow.GLAccount = PurchaseReturnSelection.PurchaseReturn;
		NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.PurchaseReturn;
	EndIf;
	
	SalesReturnSelection = QueryResult[1].Select();
	If SalesReturnSelection.Next() Then
		NewRow = ItemTable.Add();
		NewRow.GLAccount = SalesReturnSelection.SalesReturn;
		NewRow.DefaultIncomeAndExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.SalesReturn;
	EndIf;
	
	Return ItemTable;
	
EndFunction

#EndRegion

#EndIf