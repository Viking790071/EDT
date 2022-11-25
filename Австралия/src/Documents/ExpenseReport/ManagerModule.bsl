#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefExpenseReport, StructureAdditionalProperties) Export
	
	Query = New Query();
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	DocumentAttributes = Common.ObjectAttributesValues(DocumentRefExpenseReport, "DocumentCurrency, VATTaxation");
	StructureAdditionalProperties.Insert("DocumentAttributes", DocumentAttributes);
	
	Query.SetParameter("Ref",									DocumentRefExpenseReport);
	Query.SetParameter("PointInTime",							New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",					StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",							StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryIncrease",						NStr("en = 'Inventory purchase'; ru = 'Прием запасов';pl = 'Zakup magazynu';es_ES = 'Compra del inventario';es_CO = 'Compra del inventario';tr = 'Stok satın alımı';it = 'Acquisto di scorte';de = 'Bestandseinkauf'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",							NStr("en = 'Expenses incurred'; ru = 'Отражение затрат';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("RepaymentOfAdvanceHolderDebt",			NStr("en = 'Refund from advance holder'; ru = 'Погашение долга подотчетника';pl = 'Zwrot od zaliczkobiórcy';es_ES = 'Devolución del titular de anticipo';es_CO = 'Devolución del titular de anticipo';tr = 'Avans sahibinden iade';it = 'Rimborsato dalla persona che ha anticipato';de = 'Rückerstattung von der abrechnungspflichtigen Person'", MainLanguageCode));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod",	StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("PresentationCurrency",					StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DocumentCurrency",						DocumentAttributes.DocumentCurrency);
	Query.SetParameter("ExchangeRateMethod",					StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("OwnInventory",							Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting",			StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Document.Item AS Item
	|FROM
	|	Document.ExpenseReport.AdvancesPaid AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND &IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		Item = QueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	Query.SetParameter("Item", Item);
	
	Query.Text =
	"SELECT
	|	ExpenseReport.Ref AS Ref,
	|	ExpenseReport.Date AS Date,
	|	ExpenseReport.Employee AS Employee,
	|	ExpenseReport.DocumentCurrency AS DocumentCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ExpenseReport.AdvanceHoldersReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvanceHoldersReceivableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ExpenseReport.AdvanceHoldersPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvanceHoldersPayableGLAccount,
	|	ExpenseReport.IncludeVATInPrice AS IncludeVATInPrice,
	|	ExpenseReport.CompanyVATNumber AS CompanyVATNumber
	|INTO ExpenseReportHeader
	|FROM
	|	Document.ExpenseReport AS ExpenseReport
	|WHERE
	|	ExpenseReport.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.Rate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Repetition AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&PointInTime,
	|			Currency IN (&PresentationCurrency, &DocumentCurrency)
	|				AND Company = &Company) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	ExpenseReportHeader.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	Counterparties.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Contract AS Contract,
	|	CounterpartyContracts.SettlementsCurrency AS Currency,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Document AS Document,
	|	ExpenseReportHeader.Employee AS Employee,
	|	ExpenseReportHeader.DocumentCurrency AS DocumentCurrency,
	|	ExpenseReportHeader.AdvanceHoldersPayableGLAccount AS OverrunGLAccount,
	|	ExpenseReportHeader.AdvanceHoldersReceivableGLAccount AS AdvanceHoldersGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VendorAdvancesGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN DocumentTable.AdvancesPaidGLAccount
	|					ELSE DocumentTable.AccountsPayableGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	DocumentTable.Order AS Order,
	|	CASE
	|		WHEN ISNULL(PurchaseOrder.SetPaymentTerms, FALSE)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS QuoteToPaymentCalendar,
	|	CASE
	|		WHEN DocumentTable.Item = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Item
	|	END AS Item,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	SUM(CAST(DocumentTable.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|			END AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount
	|INTO TemporaryTablePayments
	|FROM
	|	ExpenseReportHeader AS ExpenseReportHeader
	|		INNER JOIN Document.ExpenseReport.Payments AS DocumentTable
	|		ON ExpenseReportHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON (DocumentTable.Counterparty = Counterparties.Ref)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (DocumentTable.Contract = CounterpartyContracts.Ref)
	|		LEFT JOIN Document.PurchaseOrder AS PurchaseOrder
	|		ON (DocumentTable.Order = PurchaseOrder.Ref)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	CounterpartyContracts.SettlementsCurrency,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Document,
	|	DocumentTable.Order,
	|	DocumentTable.Item,
	|	ExpenseReportHeader.Date,
	|	CASE
	|		WHEN ISNULL(PurchaseOrder.SetPaymentTerms, FALSE)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	ExpenseReportHeader.AdvanceHoldersPayableGLAccount,
	|	ExpenseReportHeader.AdvanceHoldersReceivableGLAccount,
	|	ExpenseReportHeader.Employee,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN DocumentTable.AdvancesPaidGLAccount
	|					ELSE DocumentTable.AccountsPayableGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	ExpenseReportHeader.DocumentCurrency,
	|	Counterparties.DoOperationsByOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReportInventory.LineNumber AS LineNumber,
	|	ExpenseReportInventory.Period AS Period,
	|	ExpenseReportInventory.Company AS Company,
	|	ExpenseReportInventory.CompanyVATNumber AS CompanyVATNumber,
	|	ExpenseReportInventory.PresentationCurrency AS PresentationCurrency,
	|	ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|	ExpenseReportInventory.Cell AS Cell,
	|	ExpenseReportInventory.GLAccount AS GLAccount,
	|	ExpenseReportInventory.InventoryAccountType AS InventoryAccountType,
	|	ExpenseReportInventory.VATInputGLAccount AS VATInputGLAccount,
	|	ExpenseReportInventory.Products AS Products,
	|	ExpenseReportInventory.BusinessLine AS BusinessLine,
	|	ExpenseReportInventory.Employee AS Employee,
	|	ExpenseReportInventory.Currency AS Currency,
	|	ExpenseReportInventory.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	ExpenseReportInventory.OverrunGLAccount AS OverrunGLAccount,
	|	ExpenseReportInventory.Characteristic AS Characteristic,
	|	ExpenseReportInventory.Batch AS Batch,
	|	ExpenseReportInventory.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	ExpenseReportInventory.SalesOrder AS SalesOrder,
	|	ExpenseReportInventory.DeductibleTax AS DeductibleTax,
	|	ExpenseReportInventory.Supplier AS Supplier,
	|	ExpenseReportInventory.Quantity AS Quantity,
	|	ExpenseReportInventory.Amount AS Amount,
	|	ExpenseReportInventory.AmountCur AS AmountCur,
	|	ExpenseReportInventory.VATAmount AS VATAmount,
	|	ExpenseReportInventory.VATRate AS VATRate,
	|	ExpenseReportInventory.VATAmountCur AS VATAmountCur,
	|	&Item AS Item,
	|	&Ref AS Document
	|INTO TemporaryTableInventory
	|FROM
	|	(SELECT
	|		ExpenseReportInventory.LineNumber AS LineNumber,
	|		ExpenseReportHeader.Date AS Period,
	|		&Company AS Company,
	|		&PresentationCurrency AS PresentationCurrency,
	|		ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|		ExpenseReportInventory.Cell AS Cell,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN ExpenseReportInventory.InventoryGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS GLAccount,
	|		VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN ExpenseReportInventory.VATInputGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS VATInputGLAccount,
	|		CatalogProducts.BusinessLine AS BusinessLine,
	|		ExpenseReportInventory.Products AS Products,
	|		ExpenseReportHeader.Employee AS Employee,
	|		ExpenseReportInventory.VATRate AS VATRate,
	|		ExpenseReportInventory.DeductibleTax AS DeductibleTax,
	|		ExpenseReportInventory.Supplier AS Supplier,
	|		ExpenseReportHeader.DocumentCurrency AS Currency,
	|		ExpenseReportHeader.AdvanceHoldersPayableGLAccount AS OverrunGLAccount,
	|		ExpenseReportHeader.AdvanceHoldersReceivableGLAccount AS AdvanceHoldersGLAccount,
	|		UNDEFINED AS SalesOrder,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN ExpenseReportInventory.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		CASE
	|			WHEN &UseBatches
	|					AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|						OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|				THEN ExpenseReportInventory.Batch
	|			ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|		END AS Batch,
	|		ExpenseReportInventory.Ownership AS Ownership,
	|		ExpenseReportInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|		CASE
	|			WHEN ExpenseReportHeader.IncludeVATInPrice
	|					OR NOT ExpenseReportInventory.DeductibleTax
	|				THEN 0
	|			ELSE ExpenseReportInventory.VATAmount
	|		END AS VATAmountCur,
	|		CASE
	|			WHEN ExpenseReportHeader.IncludeVATInPrice
	|					OR NOT ExpenseReportInventory.DeductibleTax
	|				THEN 0
	|			ELSE ExpenseReportInventory.VATAmountPresentationCur
	|		END AS VATAmount,
	|		ExpenseReportInventory.Total AS AmountCur,
	|		ExpenseReportInventory.TotalPresentationCur AS Amount,
	|		&InventoryIncrease AS ContentOfAccountingRecord,
	|		ExpenseReportHeader.CompanyVATNumber AS CompanyVATNumber
	|	FROM
	|		ExpenseReportHeader AS ExpenseReportHeader
	|			INNER JOIN Document.ExpenseReport.Inventory AS ExpenseReportInventory
	|			ON ExpenseReportHeader.Ref = ExpenseReportInventory.Ref
	|			LEFT JOIN Catalog.UOM AS CatalogUOM
	|			ON (CatalogUOM.Ref = ExpenseReportInventory.MeasurementUnit)
	|			LEFT JOIN Catalog.Products AS CatalogProducts
	|			ON (CatalogProducts.Ref = ExpenseReportInventory.Products)
	|			LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|			ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|				AND (CatalogProducts.UseBatches)
	|			LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|			ON (ExpenseReportInventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|				AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|			LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|			ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)) AS ExpenseReportInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReportExpenses.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ExpenseReportExpenses.Period AS Period,
	|	ExpenseReportExpenses.Company AS Company,
	|	ExpenseReportExpenses.CompanyVATNumber AS CompanyVATNumber,
	|	ExpenseReportExpenses.PresentationCurrency AS PresentationCurrency,
	|	ExpenseReportExpenses.StructuralUnit AS StructuralUnit,
	|	ExpenseReportExpenses.RegisterExpense AS RegisterExpense,
	|	ExpenseReportExpenses.ExpenseItem AS ExpenseItem,
	|	ExpenseReportExpenses.GLAccount AS GLAccount,
	|	ExpenseReportExpenses.InventoryAccountType AS InventoryAccountType,
	|	ExpenseReportExpenses.VATInputGLAccount AS VATInputGLAccount,
	|	ExpenseReportExpenses.Products AS Products,
	|	&OwnInventory AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	ExpenseReportExpenses.Employee AS Employee,
	|	ExpenseReportExpenses.Currency AS Currency,
	|	ExpenseReportExpenses.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	ExpenseReportExpenses.OverrunGLAccount AS OverrunGLAccount,
	|	ExpenseReportExpenses.Characteristic AS Characteristic,
	|	ExpenseReportExpenses.Batch AS Batch,
	|	ExpenseReportExpenses.Quantity AS Quantity,
	|	ExpenseReportExpenses.SalesOrder AS SalesOrder,
	|	ExpenseReportExpenses.Amount AS Amount,
	|	ExpenseReportExpenses.AmountCur AS AmountCur,
	|	ExpenseReportExpenses.VATRate AS VATRate,
	|	ExpenseReportExpenses.DeductibleTax AS DeductibleTax,
	|	ExpenseReportExpenses.Supplier AS Supplier,
	|	ExpenseReportExpenses.VATAmount AS VATAmount,
	|	ExpenseReportExpenses.VATAmountCur AS VATAmountCur,
	|	ExpenseReportExpenses.ExpenseItemType AS ExpenseItemType,
	|	ExpenseReportExpenses.BusinessLine AS BusinessLine,
	|	&Item AS Item,
	|	TRUE AS FixedCost,
	|	&Ref AS Document
	|INTO TemporaryTableExpenses
	|FROM
	|	(SELECT
	|		ExpenseReportExpenses.LineNumber AS LineNumber,
	|		ExpenseReportHeader.Date AS Period,
	|		&Company AS Company,
	|		&PresentationCurrency AS PresentationCurrency,
	|		ExpenseReportExpenses.StructuralUnit AS StructuralUnit,
	|		ExpenseReportExpenses.RegisterExpense AS RegisterExpense,
	|		ExpenseReportExpenses.ExpenseItem AS ExpenseItem,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN ExpenseReportExpenses.InventoryGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS GLAccount,
	|		CASE
	|			WHEN ExpenseReportExpenses.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|				THEN VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|			ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|		END AS InventoryAccountType,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN ExpenseReportExpenses.VATInputGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS VATInputGLAccount,
	|		ExpenseReportExpenses.BusinessLine AS BusinessLine,
	|		ExpenseReportExpenses.Products AS Products,
	|		ExpenseReportExpenses.VATRate AS VATRate,
	|		ExpenseReportExpenses.DeductibleTax AS DeductibleTax,
	|		ExpenseReportExpenses.Supplier AS Supplier,
	|		ExpenseReportHeader.Employee AS Employee,
	|		ExpenseReportHeader.DocumentCurrency AS Currency,
	|		ExpenseReportHeader.AdvanceHoldersReceivableGLAccount AS AdvanceHoldersGLAccount,
	|		ExpenseReportHeader.AdvanceHoldersPayableGLAccount AS OverrunGLAccount,
	|		VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|		VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|		ExpenseReportExpenses.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|		ExpenseReportExpenses.SalesOrder AS SalesOrder,
	|		CASE
	|			WHEN ExpenseReportHeader.IncludeVATInPrice
	|					OR NOT ExpenseReportExpenses.DeductibleTax
	|				THEN 0
	|			ELSE ExpenseReportExpenses.VATAmount
	|		END AS VATAmountCur,
	|		CASE
	|			WHEN ExpenseReportHeader.IncludeVATInPrice
	|					OR NOT ExpenseReportExpenses.DeductibleTax
	|				THEN 0
	|			ELSE ExpenseReportExpenses.VATAmountPresentationCur
	|		END AS VATAmount,
	|		ExpenseReportExpenses.Total AS AmountCur,
	|		ExpenseReportExpenses.TotalPresentationCur AS Amount,
	|		IncomeAndExpenseItems.IncomeAndExpenseType AS ExpenseItemType,
	|		ExpenseReportHeader.CompanyVATNumber AS CompanyVATNumber
	|	FROM
	|		ExpenseReportHeader AS ExpenseReportHeader
	|			INNER JOIN Document.ExpenseReport.Expenses AS ExpenseReportExpenses
	|			ON ExpenseReportHeader.Ref = ExpenseReportExpenses.Ref
	|			LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|			ON (ExpenseReportExpenses.ExpenseItem = IncomeAndExpenseItems.Ref)
	|			LEFT JOIN Catalog.UOM AS CatalogUOM
	|			ON (ExpenseReportExpenses.MeasurementUnit = CatalogUOM.Ref)) AS ExpenseReportExpenses
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	ExpenseReportHeader.Date AS Period,
	|	ExpenseReportHeader.Employee AS Employee,
	|	ExpenseReportHeader.AdvanceHoldersReceivableGLAccount AS GLAccount,
	|	ExpenseReportHeader.AdvanceHoldersPayableGLAccount AS AdvanceHoldersPayableGLAccount,
	|	ExpenseReportHeader.DocumentCurrency AS Currency,
	|	DocumentTable.Document AS Document,
	|	SUM(CAST(DocumentTable.Amount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|			END AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.Amount) AS AmountCur,
	|	-SUM(CAST(DocumentTable.Amount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|			END AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(DocumentTable.Amount) AS AmountCurForBalance
	|INTO TemporaryTableAdvancesPaid
	|FROM
	|	ExpenseReportHeader AS ExpenseReportHeader
	|		INNER JOIN Document.ExpenseReport.AdvancesPaid AS DocumentTable
	|		ON ExpenseReportHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	ExpenseReportHeader.Date,
	|	ExpenseReportHeader.Employee,
	|	ExpenseReportHeader.AdvanceHoldersReceivableGLAccount,
	|	ExpenseReportHeader.AdvanceHoldersPayableGLAccount,
	|	ExpenseReportHeader.DocumentCurrency
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Employee,
	|	Currency,
	|	Document,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTables.LineNumber) AS LineNumber,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTables.Period AS Period,
	|	DocumentTables.Employee AS Employee,
	|	DocumentTables.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|	DocumentTables.OverrunGLAccount AS GLAccount,
	|	DocumentTables.Currency AS Currency,
	|	&Ref AS Document,
	|	SUM(DocumentTables.Amount) AS Amount,
	|	SUM(DocumentTables.AmountCur) AS AmountCur
	|INTO TemporaryTableCostsAccountablePerson
	|FROM
	|	(SELECT
	|		MAX(DocumentTable.LineNumber) AS LineNumber,
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Employee AS Employee,
	|		DocumentTable.AdvanceHoldersGLAccount AS AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount AS OverrunGLAccount,
	|		DocumentTable.Currency AS Currency,
	|		SUM(DocumentTable.Amount) AS Amount,
	|		SUM(DocumentTable.AmountCur) AS AmountCur
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		MAX(DocumentTable.LineNumber),
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency,
	|		SUM(DocumentTable.Amount),
	|		SUM(DocumentTable.AmountCur)
	|	FROM
	|		TemporaryTableExpenses AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.Currency
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		MAX(DocumentTable.LineNumber),
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.DocumentCurrency,
	|		SUM(DocumentTable.Amount),
	|		SUM(DocumentTable.PaymentAmount)
	|	FROM
	|		TemporaryTablePayments AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Employee,
	|		DocumentTable.AdvanceHoldersGLAccount,
	|		DocumentTable.OverrunGLAccount,
	|		DocumentTable.DocumentCurrency) AS DocumentTables
	|
	|GROUP BY
	|	DocumentTables.Period,
	|	DocumentTables.Employee,
	|	DocumentTables.AdvanceHoldersGLAccount,
	|	DocumentTables.OverrunGLAccount,
	|	DocumentTables.Currency";
	
	Query.ExecuteBatch();
	
	GenerateTableInventory(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateAdvanceHoldersTable(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTablePurchases(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableInventoryCostLayer(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableVATIncurred(DocumentRefExpenseReport, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRefExpenseReport, StructureAdditionalProperties);
	
	GenerateTableAccountingEntriesData(DocumentRefExpenseReport, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefExpenseReport, StructureAdditionalProperties);

	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefExpenseReport, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefExpenseReport, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefExpenseReport, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefExpenseReport, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefExpenseReport, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.	
	If StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange
		Or StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Ownership) AS OwnershipPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership, Cell) IN
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.Products AS Products,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Ownership = InventoryInWarehousesOfBalance.Ownership
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.InventoryAccountType) AS InventoryAccountTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Ownership) AS OwnershipPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryChange.CostObject AS CostObject
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.PresentationCurrency = InventoryBalances.PresentationCurrency
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.InventoryAccountType = InventoryBalances.InventoryAccountType
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.Ownership = InventoryBalances.Ownership
		|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAdvanceHoldersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Employee) AS EmployeePresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Currency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Document) AS DocumentPresentation,
		|	ISNULL(AdvanceHoldersBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAdvanceHoldersChange.SumCurChange + ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) AS AccountablePersonBalance,
		|	RegisterRecordsAdvanceHoldersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAdvanceHoldersChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAdvanceHoldersChange.AmountChange AS AmountChange,
		|	RegisterRecordsAdvanceHoldersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAdvanceHoldersChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAdvanceHoldersChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsAdvanceHoldersChange AS RegisterRecordsAdvanceHoldersChange
		|		LEFT JOIN AccumulationRegister.AdvanceHolders.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Employee, Currency, Document) IN
		|					(SELECT
		|						RegisterRecordsAdvanceHoldersChange.Company AS Company,
		|						RegisterRecordsAdvanceHoldersChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsAdvanceHoldersChange.Employee AS Employee,
		|						RegisterRecordsAdvanceHoldersChange.Currency AS Currency,
		|						RegisterRecordsAdvanceHoldersChange.Document AS Document
		|					FROM
		|						RegisterRecordsAdvanceHoldersChange AS RegisterRecordsAdvanceHoldersChange)) AS AdvanceHoldersBalances
		|		ON RegisterRecordsAdvanceHoldersChange.Company = AdvanceHoldersBalances.Company
		|			AND RegisterRecordsAdvanceHoldersChange.PresentationCurrency = AdvanceHoldersBalances.PresentationCurrency
		|			AND RegisterRecordsAdvanceHoldersChange.Employee = AdvanceHoldersBalances.Employee
		|			AND RegisterRecordsAdvanceHoldersChange.Currency = AdvanceHoldersBalances.Currency
		|			AND RegisterRecordsAdvanceHoldersChange.Document = AdvanceHoldersBalances.Document
		|WHERE
		|	(VALUETYPE(AdvanceHoldersBalances.Document) = TYPE(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) > 0
		|			OR VALUETYPE(AdvanceHoldersBalances.Document) <> TYPE(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	TRUE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) IN
		|					(SELECT
		|						RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|						RegisterRecordsSuppliersSettlementsChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|						RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|						RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|						RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|						RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange)) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.PresentationCurrency = AccountsPayableBalances.PresentationCurrency
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty() Then
			DocumentObjectExpenseReport = DocumentRefExpenseReport.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		// Negative balance of inventory and cost accounting.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectExpenseReport, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("InventoryIncrease",	NStr("en = 'Inventory purchase'; ru = 'Прием запасов';pl = 'Zakup magazynu';es_ES = 'Compra del inventario';es_CO = 'Compra del inventario';tr = 'Stok satın alımı';it = 'Acquisto di scorte';de = 'Bestandseinkauf'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",		NStr("en = 'Expenses incurred'; ru = 'Прочих затраты (расходы)';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.InventoryAccountType AS InventoryAccountType,
	|	DocumentTable.Products AS Products,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.Batch AS Batch,
	|	DocumentTable.Ownership AS Ownership,
	|	DocumentTable.CostObject AS CostObject,
	|	DocumentTable.SalesOrder AS SalesOrder,
	|	DocumentTable.Quantity AS Quantity,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS Amount,
	|	TRUE AS FixedCost,
	|	&InventoryIncrease AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.GLAccount,
	|	DocumentTable.InventoryAccountType,
	|	VALUE(Catalog.Products.EmptyRef),
	|	DocumentTable.Characteristic,
	|	DocumentTable.Batch,
	|	DocumentTable.Ownership,
	|	DocumentTable.CostObject,
	|	CASE
	|		WHEN DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END,
	|	0,
	|	DocumentTable.Amount - DocumentTable.VATAmount,
	|	TRUE,
	|	&OtherExpenses
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	ResultTable = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	
	Query.Text =
	"SELECT
	|	ExpenseReportInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ExpenseReportInventory.Period AS Period,
	|	ExpenseReportInventory.Company AS Company,
	|	ExpenseReportInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ExpenseReportInventory.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	ExpenseReportInventory.Products AS Products,
	|	ExpenseReportInventory.Characteristic AS Characteristic,
	|	ExpenseReportInventory.Batch AS Batch,
	|	ExpenseReportInventory.Ownership AS Ownership,
	|	ExpenseReportInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS ExpenseReportInventory
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInventoryCostLayer(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	MIN(Inventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	CASE
	|		WHEN Inventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Inventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Inventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	Inventory.Characteristic AS Characteristic,
	|	&Ref AS CostLayer,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount - Inventory.VATAmount) AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	TemporaryTableInventory AS Inventory
	|WHERE
	|	&UseFIFO
	|
	|GROUP BY
	|	Inventory.Period,
	|	Inventory.Company,
	|	Inventory.PresentationCurrency,
	|	Inventory.Products,
	|	CASE
	|		WHEN Inventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Inventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Inventory.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.InventoryAccountType
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateAdvanceHoldersTable(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	CalculateCurrencyDifference = DriveServer.GetNeedToCalculateExchangeDifferences(Query.TempTablesManager,
		"TemporaryTableCostsAccountablePerson");
	PointInTime = StructureAdditionalProperties.ForPosting.PointInTime;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("PointInTime", New Boundary(PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);	
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DocumentCurrency", StructureAdditionalProperties.DocumentAttributes.DocumentCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("CalculateCurrencyDifference", CalculateCurrencyDifference);
	
	// Setting the exclusive lock of controlled balances of payments to accountable persons.
	Query.Text = 
	"SELECT
	|	TemporaryTableAdvancesPaid.Company AS Company,
	|	TemporaryTableAdvancesPaid.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAdvancesPaid.Employee AS Employee,
	|	TemporaryTableAdvancesPaid.Currency AS Currency,
	|	TemporaryTableAdvancesPaid.Document AS Document
	|FROM
	|	TemporaryTableAdvancesPaid AS TemporaryTableAdvancesPaid";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AdvanceHolders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	AccountsBalances.Company AS Company,
	|	AccountsBalances.PresentationCurrency AS PresentationCurrency,
	|	AccountsBalances.Employee AS Employee,
	|	AccountsBalances.Currency AS Currency,
	|	AccountsBalances.Document AS Document,
	|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableBalancesAfterPosting
	|FROM
	|	(SELECT
	|		TemporaryTable.Company AS Company,
	|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
	|		TemporaryTable.Employee AS Employee,
	|		TemporaryTable.Currency AS Currency,
	|		TemporaryTable.Document AS Document,
	|		TemporaryTable.AmountForBalance AS AmountBalance,
	|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
	|	FROM
	|		TemporaryTableAdvancesPaid AS TemporaryTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableBalances.Company,
	|		TableBalances.PresentationCurrency,
	|		TableBalances.Employee,
	|		TableBalances.Currency,
	|		TableBalances.Document,
	|		ISNULL(TableBalances.AmountBalance, 0),
	|		ISNULL(TableBalances.AmountCurBalance, 0)
	|	FROM
	|		AccumulationRegister.AdvanceHolders.Balance(
	|				&PointInTime,
	|				(Company, PresentationCurrency, Employee, Currency, Document) IN
	|					(SELECT DISTINCT
	|						TemporaryTableAdvancesPaid.Company,
	|						TemporaryTableAdvancesPaid.PresentationCurrency,
	|						TemporaryTableAdvancesPaid.Employee,
	|						TemporaryTableAdvancesPaid.Currency,
	|						TemporaryTableAdvancesPaid.Document
	|					FROM
	|						TemporaryTableAdvancesPaid)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.PresentationCurrency,
	|		DocumentRegisterRecords.Employee,
	|		DocumentRegisterRecords.Currency,
	|		DocumentRegisterRecords.Document,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AdvanceHolders AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref
	|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
	|
	|GROUP BY
	|	AccountsBalances.Company,
	|	AccountsBalances.PresentationCurrency,
	|	AccountsBalances.Employee,
	|	AccountsBalances.Currency,
	|	AccountsBalances.Document
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Employee,
	|	Currency,
	|	Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	1 AS LineNumber,
	|	&ControlPeriod AS Date,
	|	TableAccounts.Company AS Company,
	|	TableAccounts.PresentationCurrency AS PresentationCurrency,
	|	TableAccounts.Employee AS Employee,
	|	TableAccounts.Currency AS Currency,
	|	TableAccounts.Document AS Document,
	|	ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|	END - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
	|	TableAccounts.GLAccount AS GLAccount,
	|	TRUE AS AccountsReceivable
	|INTO TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder
	|FROM
	|	TemporaryTableAdvancesPaid AS TableAccounts
	|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
	|		ON TableAccounts.Company = TableBalances.Company
	|			AND TableAccounts.PresentationCurrency = TableBalances.PresentationCurrency
	|			AND TableAccounts.Employee = TableBalances.Employee
	|			AND TableAccounts.Currency = TableBalances.Currency
	|			AND TableAccounts.Document = TableBalances.Document
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|WHERE
	|	&CalculateCurrencyDifference
	|	AND (ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|			END - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
	|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|			END - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	2,
	|	TableAccounts.Period,
	|	TableAccounts.Company,
	|	TableAccounts.PresentationCurrency,
	|	TableAccounts.Employee,
	|	TableAccounts.Currency,
	|	TableAccounts.Document,
	|	ISNULL(TableAccounts.AmountCur, 0) * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|	END - ISNULL(TableAccounts.Amount, 0),
	|	TableAccounts.GLAccount,
	|	FALSE
	|FROM
	|	TemporaryTableCostsAccountablePerson AS TableAccounts
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|WHERE
	|	&CalculateCurrencyDifference
	|	AND (ISNULL(TableAccounts.AmountCur, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|			END - ISNULL(TableAccounts.Amount, 0) >= 0.005
	|			OR ISNULL(TableAccounts.AmountCur, 0) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|			END - ISNULL(TableAccounts.Amount, 0) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Employee AS Employee,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur
	|FROM
	|	TemporaryTableAdvancesPaid AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.AdvanceHoldersPayableGLAccount,
	|	&Ref,
	|	DocumentTable.Employee,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Currency,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur)
	|FROM
	|	TemporaryTableAdvancesPaid AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.LineNumber,
	|	DocumentTable.AdvanceHoldersPayableGLAccount,
	|	DocumentTable.Employee,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Currency,
	|	DocumentTable.ContentOfAccountingRecord
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Document,
	|	DocumentTable.Employee,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Currency,
	|	DocumentTable.Amount,
	|	DocumentTable.AmountCur
	|FROM
	|	TemporaryTableCostsAccountablePerson AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Document,
	|	DocumentTable.Employee,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Currency,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	0
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|WHERE
	|	DocumentTable.AccountsReceivable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Document,
	|	DocumentTable.Employee,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Currency,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	0
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|WHERE
	|	NOT DocumentTable.AccountsReceivable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	ResultTable = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAdvanceHolders", ResultTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",				DocumentRefExpenseReport);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("VendorObligationsRepayment"	,	NStr("en = 'Payment to supplier'; ru = 'Погашение обязательств поставщика';pl = 'Płatność dla dostawcy';es_ES = 'Pago al proveedor';es_CO = 'Pago al proveedor';tr = 'Tedarikçiye ödeme';it = 'Pagamento al fornitore';de = 'Zahlung an den Lieferanten'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",		StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	TemporaryTablePayments.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePayments.AdvanceFlag
	|			THEN &Ref
	|		ELSE TemporaryTablePayments.Document
	|	END AS Document,
	|	&VendorObligationsRepayment AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN TemporaryTablePayments.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTablePayments.GLAccount AS GLAccount,
	|	TemporaryTablePayments.Currency AS Currency,
	|	TemporaryTablePayments.Counterparty AS Counterparty,
	|	TemporaryTablePayments.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByOrders
	|				AND TemporaryTablePayments.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TemporaryTablePayments.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePayments.Period AS Date,
	|	SUM(TemporaryTablePayments.Amount) AS Amount,
	|	SUM(TemporaryTablePayments.SettlementsAmount) AS AmountCur,
	|	-SUM(TemporaryTablePayments.Amount) AS AmountForBalance,
	|	-SUM(TemporaryTablePayments.SettlementsAmount) AS AmountCurForBalance,
	|	SUM(TemporaryTablePayments.Amount) AS AmountForPayment,
	|	SUM(TemporaryTablePayments.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePayments AS TemporaryTablePayments
	|
	|GROUP BY
	|	TemporaryTablePayments.LineNumber,
	|	TemporaryTablePayments.GLAccount,
	|	TemporaryTablePayments.Currency,
	|	TemporaryTablePayments.Counterparty,
	|	TemporaryTablePayments.Contract,
	|	TemporaryTablePayments.Period,
	|	CASE
	|		WHEN TemporaryTablePayments.AdvanceFlag
	|			THEN &Ref
	|		ELSE TemporaryTablePayments.Document
	|	END,
	|	CASE
	|		WHEN TemporaryTablePayments.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePayments.DoOperationsByOrders
	|				AND TemporaryTablePayments.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TemporaryTablePayments.Order
	|		ELSE UNDEFINED
	|	END
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();

	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.PresentationCurrency AS PresentationCurrency,	
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	ResultTable = ResultsArray[QueryNumber].Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefExpenseReport);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",					NStr("en = 'Expenses incurred'; ru = 'Отражение расходов';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",				Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences > 0
	|				OR NOT DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences < 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences > 0
	|				OR NOT DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences < 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivable
	|			THEN CASE
	|					WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|						THEN DocumentTable.AmountOfExchangeDifferences
	|					ELSE 0
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|					THEN -DocumentTable.AmountOfExchangeDifferences
	|				ELSE 0
	|			END
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivable
	|			THEN CASE
	|					WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|						THEN 0
	|					ELSE -DocumentTable.AmountOfExchangeDifferences
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|					THEN 0
	|				ELSE DocumentTable.AmountOfExchangeDifferences
	|			END
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentTable.BusinessLine
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|				OR DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.GLAccount,
	|	&OtherExpenses,
	|	0,
	|	DocumentTable.Amount - DocumentTable.VATAmount,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.RegisterExpense
	|	AND (DocumentTable.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		OR DocumentTable.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXExpenseItem
	|		ELSE &FXIncomeItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Order,
	|	DocumentTable.LineNumber";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.Item,
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountExpense > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	&Ref AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefExpenseReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Item,
	|	DocumentTable.PresentationCurrency";
	
	QueryResult = Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.IncomeAndExpensesRetained");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", "Company");
	LockItem.UseFromDataSource("PresentationCurrency", "PresentationCurrency");	
	LockItem.UseFromDataSource("Document", "Document");
	Block.Lock();
	
	TableAmountForWriteOff = QueryResult.Unload();
	
	// Generating the table with remaining balance.
	Query.Text =
	"SELECT
	|	&Period AS Period,
	|	IncomeAndExpensesRetainedBalances.Company AS Company,
	|	IncomeAndExpensesRetainedBalances.PresentationCurrency AS PresentationCurrency,
	|	IncomeAndExpensesRetainedBalances.Document AS Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine AS BusinessLine,
	|	VALUE(Catalog.CashFlowItems.EmptyRef) AS Item,
	|	0 AS AmountIncome,
	|	0 AS AmountExpense,
	|	-SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountExpenseBalance) AS AmountExpenseBalance
	|FROM
	|	(SELECT
	|		IncomeAndExpensesRetainedBalances.Company AS Company,
	|		IncomeAndExpensesRetainedBalances.PresentationCurrency AS PresentationCurrency,
	|		IncomeAndExpensesRetainedBalances.Document AS Document,
	|		IncomeAndExpensesRetainedBalances.BusinessLine AS BusinessLine,
	|		IncomeAndExpensesRetainedBalances.AmountIncomeBalance AS AmountIncomeBalance,
	|		IncomeAndExpensesRetainedBalances.AmountExpenseBalance AS AmountExpenseBalance
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained.Balance(
	|				,
	|				Company = &Company
	|					AND Document IN
	|						(SELECT
	|							DocumentTable.Document
	|						FROM
	|							TemporaryTablePayments AS DocumentTable)) AS IncomeAndExpensesRetainedBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Company,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.PresentationCurrency,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Document,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.BusinessLine,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|		END
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained AS DocumentRegisterRecordsOfIncomeAndExpensesPending
	|	WHERE
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Recorder = &Ref) AS IncomeAndExpensesRetainedBalances
	|
	|GROUP BY
	|	IncomeAndExpensesRetainedBalances.Company,
	|	IncomeAndExpensesRetainedBalances.PresentationCurrency,
	|	IncomeAndExpensesRetainedBalances.Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine
	|
	|ORDER BY
	|	Document";
	
	TableSumBalance = Query.Execute().Unload();

	TableSumBalance.Indexes.Add("Document");
	
	// Calculation of the write-off amounts.
	For Each StringSumToBeWrittenOff In TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances In RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountExpenseBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountRowBalances.AmountExpenseBalance;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountExpenseBalance;
			ElsIf AmountRowBalances.AmountExpenseBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountToBeWrittenOff;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Item";
	
	TableAmountForWriteOff = Query.Execute().Unload();
	
	For Each StringSumToBeWrittenOff In TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances In RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountIncomeBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountRowBalances.AmountIncomeBalance;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountIncomeBalance;
			ElsIf AmountRowBalances.AmountIncomeBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountToBeWrittenOff;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating a temporary table with amounts,
	// items and directions of activities. Required to generate movements of income
	// and expenses by cash method.
	Query.Text =
	"SELECT
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Document AS Document,
	|	Table.Item AS Item,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|INTO TemporaryTableTableDeferredIncomeAndExpenditure
	|FROM
	|	&Table AS Table
	|WHERE
	|	Table.AmountExpense > 0";
	
	Query.SetParameter("Table", TableSumBalance);
	
	Query.Execute();
	
	// Generating the table for recording in the register.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,	
	|	Table.Document AS Document,
	|	Table.Item AS Item,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchases(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	TablePurchases.Currency AS Currency,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	TablePurchases.Ownership AS Ownership,
	|	UNDEFINED AS PurchaseOrder,
	|	TablePurchases.Document AS Document,
	|	TablePurchases.VATRate AS VATRate,
	|	SUM(TablePurchases.Quantity) AS Quantity,
	|	SUM(TablePurchases.VATAmount) AS VATAmount,
	|	SUM(TablePurchases.Amount - TablePurchases.VATAmount) AS Amount,
	|	SUM(TablePurchases.VATAmountCur) AS VATAmountCur,
	|	SUM(TablePurchases.AmountCur - TablePurchases.VATAmountCur) AS AmountCur
	|FROM
	|	TemporaryTableInventory AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	TablePurchases.Currency,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Ownership,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	VALUE(Catalog.Counterparties.EmptyRef),
	|	TablePurchases.Currency,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Ownership,
	|	UNDEFINED,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate,
	|	SUM(TablePurchases.Quantity),
	|	SUM(TablePurchases.VATAmount),
	|	SUM(TablePurchases.Amount - TablePurchases.VATAmount),
	|	SUM(TablePurchases.VATAmountCur),
	|	SUM(TablePurchases.AmountCur - TablePurchases.VATAmountCur)
	|FROM
	|	TemporaryTableExpenses AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	TablePurchases.Currency,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Ownership,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("InventoryIncrease",				NStr("en = 'Inventory purchase'; ru = 'Прием запасов';pl = 'Zakup magazynu';es_ES = 'Compra del inventario';es_CO = 'Compra del inventario';tr = 'Stok satın alımı';it = 'Acquisto di scorte';de = 'Bestandseinkauf'", MainLanguageCode));
	Query.SetParameter("VendorsPayment",				NStr("en = 'Payment to supplier'; ru = 'Оплата поставщику';pl = 'Płatność dla dostawcy';es_ES = 'Pago al proveedor';es_CO = 'Pago al proveedor';tr = 'Tedarikçiye ödeme';it = 'Pagamento al fornitore';de = 'Zahlung an den Lieferanten'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",					NStr("en = 'Expenses incurred'; ru = 'Прочих затраты (расходы)';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("PreVATInventory",				NStr("en = 'VAT input on goods purchased'; ru = 'Входящий НДС по закупленным товарам';pl = 'VAT na zakupiony towar';es_ES = 'Entrada del IVA de las mercancías compradas';es_CO = 'Entrada del IVA de las mercancías compradas';tr = 'Satın alınan mallarda KDV girişi';it = 'IVA inserita sulla merce acquistata';de = 'USt.-Eingabe auf eingekaufte Waren'", MainLanguageCode));
	Query.SetParameter("PreVATExpenses",				NStr("en = 'VAT input on expenses incurred'; ru = 'Входящий НДС по предъявленным расходам';pl = 'VAT od poniesionych rozchodów';es_ES = 'Entrada del IVA de los gastos incurridos';es_CO = 'Entrada del IVA de los gastos incurridos';tr = 'Yapılan giderlere ilişkin KDV girişi';it = 'IVA inserita sulle spese sostenute';de = 'USt.-Eingabe auf angefallene Ausgaben'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",							DocumentRefExpenseReport);
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.GLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur - DocumentTable.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.OverrunGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.OverrunGLAccount.Currency
	|			THEN DocumentTable.AmountCur - DocumentTable.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS Amount,
	|	CAST(&OtherExpenses AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur - DocumentTable.VATAmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.OverrunGLAccount,
	|	CASE
	|		WHEN DocumentTable.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.OverrunGLAccount.Currency
	|			THEN DocumentTable.AmountCur - DocumentTable.VATAmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount - DocumentTable.VATAmount,
	|	CAST(&InventoryIncrease AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AdvanceHoldersGLAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&VendorsPayment AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TableAdvancesPaid.LineNumber,
	|	TableAdvancesPaid.Period,
	|	TableAdvancesPaid.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAdvancesPaid.AdvanceHoldersPayableGLAccount,
	|	CASE
	|		WHEN TableAdvancesPaid.AdvanceHoldersPayableGLAccount.Currency
	|			THEN TableAdvancesPaid.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAdvancesPaid.AdvanceHoldersPayableGLAccount.Currency
	|			THEN TableAdvancesPaid.AmountCur
	|		ELSE 0
	|	END,
	|	TableAdvancesPaid.GLAccount,
	|	CASE
	|		WHEN TableAdvancesPaid.GLAccount.Currency
	|			THEN TableAdvancesPaid.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAdvancesPaid.GLAccount.Currency
	|			THEN TableAdvancesPaid.AmountCur
	|		ELSE 0
	|	END,
	|	TableAdvancesPaid.Amount,
	|	TableAdvancesPaid.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAdvancesPaid AS TableAdvancesPaid
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences > 0
	|				OR NOT DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences < 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN (DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences > 0
	|				OR NOT DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences < 0)
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences > 0
	|				OR NOT DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences < 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN (DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences < 0
	|				OR NOT DocumentTable.AccountsReceivable
	|					AND DocumentTable.AmountOfExchangeDifferences > 0)
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	MIN(DocumentTable.LineNumber),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.OverrunGLAccount,
	|	CASE
	|		WHEN DocumentTable.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN DocumentTable.OverrunGLAccount.Currency
	|				THEN DocumentTable.VATAmountCur
	|			ELSE 0
	|		END),
	|	SUM(DocumentTable.VATAmount),
	|	CAST(&PreVATInventory AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.DeductibleTax
	|	AND DocumentTable.VATAmount > 0
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.VATInputGLAccount,
	|	DocumentTable.Company,
	|	DocumentTable.OverrunGLAccount,
	|	DocumentTable.Period
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	MIN(DocumentTable.LineNumber),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.OverrunGLAccount,
	|	CASE
	|		WHEN DocumentTable.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN DocumentTable.OverrunGLAccount.Currency
	|				THEN DocumentTable.VATAmountCur
	|			ELSE 0
	|		END),
	|	SUM(DocumentTable.VATAmount),
	|	CAST(&PreVATExpenses AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.DeductibleTax
	|	AND DocumentTable.VATAmount > 0
	|
	|GROUP BY
	|	DocumentTable.Company,
	|	DocumentTable.Period,
	|	DocumentTable.VATInputGLAccount,
	|	DocumentTable.OverrunGLAccount,
	|	CASE
	|		WHEN DocumentTable.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	&Company AS Company,
	|	DocumentTable.Order AS Quote,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	(VALUETYPE(DocumentTable.Order) = TYPE(Document.SalesOrder)
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			OR VALUETYPE(DocumentTable.Order) = TYPE(Document.PurchaseOrder)
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Order
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",              StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UsePaymentCalendar",   Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	VALUE(Catalog.PaymentMethods.Cash) AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	UNDEFINED AS BankAccountPettyCash,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.QuoteToPaymentCalendar AS Quote,
	|	SUM(-DocumentTable.SettlementsAmount) AS PaymentAmount
	|FROM
	|	TemporaryTablePayments AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Currency,
	|	DocumentTable.QuoteToPaymentCalendar
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		And StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
		And Not StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	TemporaryTableRows.ShipmentDocument AS ShipmentDocument,
		|	TemporaryTableRows.VATRate AS VATRate,
		|	TemporaryTableRows.GLAccount AS GLAccount,
		|	TemporaryTableRows.Period AS Period,
		|	TemporaryTableRows.Company AS Company,
		|	TemporaryTableRows.CompanyVATNumber AS CompanyVATNumber,
		|	TemporaryTableRows.PresentationCurrency AS PresentationCurrency,
		|	TemporaryTableRows.Supplier AS Supplier,
		|	SUM(TemporaryTableRows.VATAmount) AS VATAmount,
		|	SUM(TemporaryTableRows.AmountExcludesVAT) AS AmountExcludesVAT
		|FROM
		|	(SELECT
		|		TemporaryTableInventory.Document AS ShipmentDocument,
		|		TemporaryTableInventory.VATRate AS VATRate,
		|		TemporaryTableInventory.VATInputGLAccount AS GLAccount,
		|		TemporaryTableInventory.Period AS Period,
		|		TemporaryTableInventory.Company AS Company,
		|		TemporaryTableInventory.CompanyVATNumber AS CompanyVATNumber,
		|		TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTableInventory.Supplier AS Supplier,
		|		TemporaryTableInventory.VATAmount AS VATAmount,
		|		TemporaryTableInventory.Amount - TemporaryTableInventory.VATAmount AS AmountExcludesVAT
		|	FROM
		|		TemporaryTableInventory AS TemporaryTableInventory
		|	WHERE
		|		TemporaryTableInventory.DeductibleTax
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TemporaryTableExpenses.Document,
		|		TemporaryTableExpenses.VATRate,
		|		TemporaryTableExpenses.VATInputGLAccount,
		|		TemporaryTableExpenses.Period,
		|		TemporaryTableExpenses.Company,
		|		TemporaryTableExpenses.CompanyVATNumber,
		|		TemporaryTableExpenses.PresentationCurrency,
		|		TemporaryTableExpenses.Supplier,
		|		TemporaryTableExpenses.VATAmount,
		|		TemporaryTableExpenses.Amount - TemporaryTableExpenses.VATAmount
		|	FROM
		|		TemporaryTableExpenses AS TemporaryTableExpenses
		|	WHERE
		|		TemporaryTableExpenses.DeductibleTax) AS TemporaryTableRows
		|
		|GROUP BY
		|	TemporaryTableRows.Period,
		|	TemporaryTableRows.VATRate,
		|	TemporaryTableRows.GLAccount,
		|	TemporaryTableRows.PresentationCurrency,
		|	TemporaryTableRows.Supplier,
		|	TemporaryTableRows.ShipmentDocument,
		|	TemporaryTableRows.CompanyVATNumber,
		|	TemporaryTableRows.Company";
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", Query.Execute().Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", New ValueTable);
		Return;
	EndIf;

EndProcedure

Procedure GenerateTableVATInput(DocumentRefExpenseReport, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		And StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
		And StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	VALUE(Enum.VATOperationTypes.Purchases) AS OperationType,
		|	TemporaryTableRows.ShipmentDocument AS ShipmentDocument,
		|	TemporaryTableRows.VATRate AS VATRate,
		|	TemporaryTableRows.GLAccount AS GLAccount,
		|	TemporaryTableRows.Period AS Period,
		|	TemporaryTableRows.Company AS Company,
		|	TemporaryTableRows.CompanyVATNumber AS CompanyVATNumber,
		|	TemporaryTableRows.PresentationCurrency AS PresentationCurrency,
		|	TemporaryTableRows.Supplier AS Supplier,
		|	TemporaryTableRows.ProductsType AS ProductsType,
		|	SUM(TemporaryTableRows.VATAmount) AS VATAmount,
		|	SUM(TemporaryTableRows.AmountExcludesVAT) AS AmountExcludesVAT
		|FROM
		|	(SELECT
		|		TemporaryTableInventory.Document AS ShipmentDocument,
		|		TemporaryTableInventory.VATRate AS VATRate,
		|		TemporaryTableInventory.VATInputGLAccount AS GLAccount,
		|		TemporaryTableInventory.Period AS Period,
		|		TemporaryTableInventory.Company AS Company,
		|		TemporaryTableInventory.CompanyVATNumber AS CompanyVATNumber,
		|		TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTableInventory.Supplier AS Supplier,
		|		CatalogProducts.ProductsType AS ProductsType,
		|		TemporaryTableInventory.VATAmount AS VATAmount,
		|		TemporaryTableInventory.Amount - TemporaryTableInventory.VATAmount AS AmountExcludesVAT
		|	FROM
		|		TemporaryTableInventory AS TemporaryTableInventory
		|			INNER JOIN Catalog.Products AS CatalogProducts
		|			ON TemporaryTableInventory.Products = CatalogProducts.Ref
		|	WHERE
		|		TemporaryTableInventory.DeductibleTax
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TemporaryTableExpenses.Document,
		|		TemporaryTableExpenses.VATRate,
		|		TemporaryTableExpenses.VATInputGLAccount,
		|		TemporaryTableExpenses.Period,
		|		TemporaryTableExpenses.Company,
		|		TemporaryTableExpenses.CompanyVATNumber,
		|		TemporaryTableExpenses.PresentationCurrency,
		|		TemporaryTableExpenses.Supplier,
		|		CatalogProducts.ProductsType,
		|		TemporaryTableExpenses.VATAmount,
		|		TemporaryTableExpenses.Amount - TemporaryTableExpenses.VATAmount
		|	FROM
		|		TemporaryTableExpenses AS TemporaryTableExpenses
		|			INNER JOIN Catalog.Products AS CatalogProducts
		|			ON TemporaryTableExpenses.Products = CatalogProducts.Ref
		|	WHERE
		|		TemporaryTableExpenses.DeductibleTax) AS TemporaryTableRows
		|
		|GROUP BY
		|	TemporaryTableRows.Period,
		|	TemporaryTableRows.VATRate,
		|	TemporaryTableRows.GLAccount,
		|	TemporaryTableRows.PresentationCurrency,
		|	TemporaryTableRows.Supplier,
		|	TemporaryTableRows.ShipmentDocument,
		|	TemporaryTableRows.CompanyVATNumber,
		|	TemporaryTableRows.Company,
		|	TemporaryTableRows.ProductsType";
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
	EndIf;
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("CounterpartyGLAccounts") Then
		
		GLAccountsForFilling.Insert("AccountsPayableGLAccount", StructureData.AccountsPayableGLAccount);
		GLAccountsForFilling.Insert("AdvancesPaidGLAccount", StructureData.AdvancesPaidGLAccount);
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Expenses" Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
		IncomeAndExpenseStructure.Insert("RegisterExpense", StructureData.RegisterExpense);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Expenses" Then
		Result.Insert("InventoryGLAccount", "ExpenseItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", "StructuralUnit");
	WarehouseData.Insert("TrackingArea", "Inbound_FromSupplier");
	
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

Function DocumentVATRate(DocumentRef) Export
	
	VATRateInv = DriveServer.DocumentVATRate(DocumentRef);
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Expenses");
	VATRateExp = DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
	If ValueIsFilled(VATRateInv) And ValueIsFilled(VATRateExp) Then
		
		If VATRateInv = VATRateExp Then
			Return VATRateInv;
		Else
			Return Catalogs.VATRates.EmptyRef();
		EndIf;
		
	ElsIf ValueIsFilled(VATRateInv) Then
		
		Return VATRateInv;
		
	Else
		
		Return VATRateExp;
		
	EndIf;
	
EndFunction

#Region LibrariesHandlers

#Region PrintInterface

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export

	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"GoodsReceivedNote",
			NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'"),
			DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote", PrintParameters.Result));
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ExpenseClaim") Then
		
		SpreadsheetDocument = DataProcessors.PrintExpenseClaim.PrintForm(ObjectsArray,
			PrintObjects,
			"ExpenseClaim",
			PrintParameters.Result);
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
			"ExpenseClaim",
			NStr("en = 'Expense claim'; ru = 'Авансовый отчет';pl = 'Raport rozchodów';es_ES = 'Reclamación de gastos';es_CO = 'Reclamación de gastos';tr = 'Masraf raporu';it = 'Richiesta di spese';de = 'Kostenabrechnung'"),
			SpreadsheetDocument);
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export

	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ExpenseClaim";
	PrintCommand.Presentation				= NStr("en = 'Expense claim'; ru = 'Авансовый отчет';pl = 'Raport rozchodów';es_ES = 'Reclamación de gastos';es_CO = 'Reclamación de gastos';tr = 'Masraf raporu';it = 'Richiesta di spese';de = 'Kostenabrechnung'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region AccountingTemplates

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	Return AccountingFields;
	
EndFunction

#EndRegion

#EndIf