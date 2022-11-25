#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SalesSlipInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SalesSlipInventory.Date AS Period,
	|	SalesSlipInventory.Company AS Company,
	|	SalesSlipInventory.Products AS Products,
	|	SalesSlipInventory.Characteristic AS Characteristic,
	|	SalesSlipInventory.Batch AS Batch,
	|	SalesSlipInventory.Ownership AS Ownership,
	|	SalesSlipInventory.StructuralUnit AS StructuralUnit,
	|	SUM(SalesSlipInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventoryOwnership AS SalesSlipInventory
	|WHERE
	|	SalesSlipInventory.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (&CheckIssued
	|			OR &ProductReserved)
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	SalesSlipInventory.LineNumber,
	|	SalesSlipInventory.Date,
	|	SalesSlipInventory.Company,
	|	SalesSlipInventory.Products,
	|	SalesSlipInventory.Characteristic,
	|	SalesSlipInventory.Batch,
	|	SalesSlipInventory.Ownership,
	|	SalesSlipInventory.StructuralUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefSalesSlip);
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("ProductReserved", StructureAdditionalProperties.ForPosting.ProductReserved);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentData.Date AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentData.Company AS Company,
	|	DocumentData.PresentationCurrency AS PresentationCurrency,
	|	DocumentData.CashCR AS CashCR,
	|	DocumentData.CashCRGLAccount AS GLAccount,
	|	DocumentData.DocumentCurrency AS Currency,
	|	SUM(DocumentData.Amount) AS Amount,
	|	SUM(DocumentData.AmountCur) AS AmountCur,
	|	SUM(DocumentData.Amount) AS AmountForBalance,
	|	SUM(DocumentData.AmountCur) AS AmountCurForBalance,
	|	CAST(&CashFundsReceipt AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableInventoryOwnership AS DocumentData
	|WHERE
	|	&CheckIssued
	|	AND Not &Archival
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.PresentationCurrency,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentData.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentData.Company,
	|	DocumentData.PresentationCurrency,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency,
	|	SUM(DocumentData.Amount),
	|	SUM(DocumentData.AmountCur),
	|	-SUM(DocumentData.Amount),
	|	-SUM(DocumentData.AmountCur),
	|	CAST(&PaymentWithPaymentCards AS String(100))
	|FROM
	|	TemporaryTablePaymentCards AS DocumentData
	|WHERE
	|	&CheckIssued
	|	AND Not &Archival
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.PresentationCurrency,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	CashCR,
	|	Currency,
	|	GLAccount";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefSalesSlip);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	Query.SetParameter("CashFundsReceipt", NStr("en = 'Cash receipt to cash register'; ru = 'Поступление денежных средств в кассу ККМ';pl = 'Przychód środków pieniężnych do kasy fiskalnej';es_ES = 'Recibo de efectivo en la caja registradora';es_CO = 'Recibo de efectivo en la caja registradora';tr = 'Nakit tahsilat fişinin yazar kasaya girmesi';it = 'Entrata di cassa nel registratore di cassa';de = 'Zahlungseingang an die Kasse'", MainLanguageCode));
	Query.SetParameter("PaymentWithPaymentCards", NStr("en = 'Payment with payment cards'; ru = 'Оплата платежными картами';pl = 'Płatność kartami płatniczymi';es_ES = 'Pago con tarjetas de pago';es_CO = 'Pago con tarjetas de pago';tr = 'Ödeme kartıyla yapılan ödemeler';it = 'Pagamento con carte di pagamento';de = 'Zahlung mit Zahlungskarten'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssetsInRetailCashes.Company AS Company,
	|	TemporaryTableCashAssetsInRetailCashes.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableCashAssetsInRetailCashes.CashCR AS CashCR
	|FROM
	|	TemporaryTableCashAssetsInRetailCashes";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashInCashRegisters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesCashInCashRegisters(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashInCashRegisters", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Date AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.RevenueItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales AS GLAccount,
	|	CAST(&IncomeReflection AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventoryOwnership AS TableIncomeAndExpenses
	|WHERE
	|	NOT TableIncomeAndExpenses.ProductsOnCommission
	|	AND &CheckIssued
	|	AND NOT &Archival
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.RevenueItem,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("FXIncomeItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Record income'; ru = 'Отражение доходов';pl = 'Rejestr przychodów';es_ES = 'Registrar los ingresos';es_CO = 'Registrar los ingresos';tr = 'Gelirlerin kaydı';it = 'Registrazione fatturato';de = 'Gebuchte Einnahme'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("CheckIssued",									StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival",										StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	TableSales.DocumentCurrency AS Currency,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.Ownership AS Ownership,
	|	TableSales.SalesOrder AS SalesOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.Department AS Department,
	|	TableSales.Responsible AS Responsible,
	|	TableSales.BundleProduct AS BundleProduct,
	|	TableSales.BundleCharacteristic AS BundleCharacteristic,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.VATAmount) AS VATAmount,
	|	SUM(TableSales.Amount - TableSales.VATAmount) AS Amount,
	|	SUM(TableSales.VATAmountCur) AS VATAmountCur,
	|	SUM(TableSales.AmountCur - TableSales.VATAmountCur) AS AmountCur,
	|	0 AS Cost
	|FROM
	|	TemporaryTableInventoryOwnership AS TableSales
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.DocumentCurrency,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.Ownership,
	|	TableSales.SalesOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.BundleProduct,
	|	TableSales.BundleCharacteristic,
	|	TableSales.Responsible";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableAccountingJournalEntries.LineNumber AS LineNumber,
	|	TableAccountingJournalEntries.Date AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.CashCRGLAccount AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN &AccountsPayable
	|		ELSE TableAccountingJournalEntries.GLAccountRevenueFromSales
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventoryOwnership AS TableAccountingJournalEntries
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.POSTerminalGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.POSTerminalGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.POSTerminalGLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.CashCRGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.Amount,
	|	&ReflectionOfPaymentByCards,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentCards AS TableAccountingJournalEntries
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences < 0
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS TableAccountingJournalEntries
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.CashCRGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATAmount,
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventoryOwnership AS TableAccountingJournalEntries
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("AccountsPayable",								Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'; ru = 'Выручка от продажи';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("ReflectionOfPaymentByCards",					NStr("en = 'Payment with payment cards'; ru = 'Оплата платежными картами';pl = 'Płatność kartami płatniczymi';es_ES = 'Pago con tarjetas de pago';es_CO = 'Pago con tarjetas de pago';tr = 'Ödeme kartıyla yapılan ödemeler';it = 'Pagamento con carte di pagamento';de = 'Zahlung mit Zahlungskarten'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",							StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("CheckIssued",									StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival",										StructureAdditionalProperties.ForPosting.Archival);
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("VAT",											NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));

	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do  
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefSalesSlip, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
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
	|	SalesSlipInventory.LineNumber AS LineNumber,
	|	SalesSlipInventory.Ref AS Document,
	|	SalesSlipInventory.Ref.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SalesSlipInventory.Ref.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS Cell,
	|	SalesSlipInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesSlipInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|				OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN SalesSlipInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SalesSlipInventory.ConnectionKey AS ConnectionKey
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SalesSlip.Inventory AS SalesSlipInventory
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON SalesSlipInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON SalesSlipInventory.Ref.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	SalesSlipInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesSlipInventory.LineNumber AS LineNumber,
	|	SalesSlipInventory.Ref AS Document,
	|	DocSalesSlip.Date AS Date,
	|	UNDEFINED AS SalesOrder,
	|	DocSalesSlip.CashCR AS CashCR,
	|	DocSalesSlip.Responsible AS Responsible,
	|	CashRegisters.Owner AS CashCROwner,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(CashRegisters.GLAccount, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CashCRGLAccount,
	|	DocSalesSlip.DocumentCurrency AS DocumentCurrency,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocSalesSlip.StructuralUnit AS StructuralUnit,
	|	DocSalesSlip.Department AS Department,
	|	SalesSlipInventory.Products.BusinessLine AS BusinessLine,
	|	SalesSlipInventory.Products.ProductsType AS ProductsType,
	|	SalesSlipInventory.RevenueItem AS RevenueItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesSlipInventory.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountRevenueFromSales,
	|	UNDEFINED AS Cell,
	|	CASE
	|		WHEN CatInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	SalesSlipInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesSlipInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SalesSlipInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SalesSlipInventory.Ownership AS Ownership,
	|	SalesSlipInventory.SerialNumber AS SerialNumber,
	|	SalesSlipInventory.Quantity AS Quantity,
	|	SalesSlipInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN DocSalesSlip.IncludeVATInPrice
	|				THEN 0
	|			ELSE SalesSlipInventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(SalesSlipInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(SalesSlipInventory.VATAmount AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(SalesSlipInventory.Total AS NUMBER(15, 2)) AS AmountCur,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesSlipInventory.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	SalesSlipInventory.BundleProduct AS BundleProduct,
	|	SalesSlipInventory.BundleCharacteristic AS BundleCharacteristic
	|INTO TemporaryTableInventoryOwnership
	|FROM
	|	Document.SalesSlip.InventoryOwnership AS SalesSlipInventory
	|		INNER JOIN Document.SalesSlip AS DocSalesSlip
	|		ON SalesSlipInventory.Ref = DocSalesSlip.Ref
	|		LEFT JOIN Catalog.CashRegisters AS CashRegisters
	|		ON DocSalesSlip.CashCR = CashRegisters.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|		LEFT JOIN Catalog.InventoryOwnership AS CatInventoryOwnership
	|		ON SalesSlipInventory.Ownership = CatInventoryOwnership.Ref
	|WHERE
	|	SalesSlipInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TabularSection.LineNumber AS LineNumber,
	|	DocSalesSlip.Date AS Date,
	|	&Ref AS Document,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocSalesSlip.CashCR AS CashCR,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(CashRegisters.GLAccount, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CashCRGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(POSTerminals.GLAccount, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS POSTerminalGLAccount,
	|	DocSalesSlip.DocumentCurrency AS DocumentCurrency,
	|	CAST(TabularSection.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	TabularSection.Amount AS AmountCur
	|INTO TemporaryTablePaymentCards
	|FROM
	|	Document.SalesSlip.PaymentWithPaymentCards AS TabularSection
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|		INNER JOIN Document.SalesSlip AS DocSalesSlip
	|		ON TabularSection.Ref = DocSalesSlip.Ref
	|		LEFT JOIN Catalog.CashRegisters AS CashRegisters
	|		ON DocSalesSlip.CashCR = CashRegisters.Ref
	|		LEFT JOIN Catalog.POSTerminals AS POSTerminals
	|		ON DocSalesSlip.POSTerminal = POSTerminals.Ref
	|WHERE
	|	TabularSection.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesSlipDiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	SalesSlipDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	CAST(SalesSlipDiscountsMarkups.Amount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	SalesSlipDiscountsMarkups.Ref.Date AS Period,
	|	SalesSlipDiscountsMarkups.Ref.StructuralUnit AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.SalesSlip.DiscountsMarkups AS SalesSlipDiscountsMarkups
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &DocumentCurrency)
	|WHERE
	|	SalesSlipDiscountsMarkups.Ref = &Ref
	|	AND SalesSlipDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.SalesSlip.SerialNumbers AS SalesInvoiceSerialNumbers
	|WHERE
	|	SalesInvoiceSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref", DocumentRefSalesSlip);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DocumentCurrency", Common.ObjectAttributeValue(DocumentRefSalesSlip, "DocumentCurrency"));
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefSalesSlip, StructureAdditionalProperties);
	
	GenerateTableInventoryInWarehouses(DocumentRefSalesSlip, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefSalesSlip, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefSalesSlip, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefSalesSlip, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefSalesSlip, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefSalesSlip, StructureAdditionalProperties);
	EndIf;
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefSalesSlip, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesSlip, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefSalesSlip, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefSalesSlip, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefSalesSlip, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefSalesSlip, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefSalesSlip, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl()
	 OR Not Constants.CheckStockBalanceWhenIssuingSalesSlips.Get()
	    OR DocumentRefSalesSlip.Archival Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", control goods implementation.
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange
		OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
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
		|	RegisterRecordsCashInCashRegistersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.CashCR) AS CashCRDescription,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.CashCR.CashCurrency) AS CurrencyPresentation,
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsCashInCashRegistersChange.SumCurChange + ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS BalanceCashAssets,
		|	RegisterRecordsCashInCashRegistersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountChange AS AmountChange,
		|	RegisterRecordsCashInCashRegistersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsCashInCashRegistersChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsCashInCashRegistersChange AS RegisterRecordsCashInCashRegistersChange
		|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, CashCR) IN
		|					(SELECT
		|						RegisterRecordsCashInCashRegistersChange.Company AS Company,
		|						RegisterRecordsCashInCashRegistersChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsCashInCashRegistersChange.CashCR AS CashAssetType
		|					FROM
		|						RegisterRecordsCashInCashRegistersChange AS RegisterRecordsCashInCashRegistersChange)) AS CashAssetsInRetailCashesBalances
		|		ON RegisterRecordsCashInCashRegistersChange.Company = CashAssetsInRetailCashesBalances.Company
		|			AND RegisterRecordsCashInCashRegistersChange.PresentationCurrency = CashAssetsInRetailCashesBalances.PresentationCurrency
		|			AND RegisterRecordsCashInCashRegistersChange.CashCR = CashAssetsInRetailCashesBalances.CashCR
		|WHERE
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Ownership AS OwnershipPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.Ownership = SerialNumbersBalance.Ownership
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
		 OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectSalesSlip = DocumentRefSalesSlip.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSalesSlip, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in cash CR.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocumentObjectSalesSlip, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectSalesSlip, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

// Generates values table creating data for posting by the SalesWithCardBasedDiscounts register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	If DocumentRefSalesSlip.DiscountCard.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesWithCardBasedDiscounts", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	TableSales.Document.DiscountCard AS DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner AS CardOwner,
	|	SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableInventoryOwnership AS TableSales
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.PresentationCurrency,
	|	TableSales.Document.DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesWithCardBasedDiscounts", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region Internal

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	If DocumentRefSalesSlip.DiscountsMarkups.Count() = 0 OR Not GetFunctionalOption("UseAutomaticDiscounts") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableAutoDiscountsMarkups.Period,
	|	TemporaryTableAutoDiscountsMarkups.DiscountMarkup AS AutomaticDiscount,
	|	TemporaryTableAutoDiscountsMarkups.Amount AS DiscountAmount,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Document AS DocumentDiscounts,
	|	TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventory.StructuralUnit AS RecipientDiscounts
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TemporaryTableInventory.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure

#EndRegion

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure("RevenueItem", StructureData.RevenueItem);
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Inventory" Then
		Result.Insert("RevenueGLAccount", "RevenueItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
	GLAccountsForFilling.Insert("RevenueGLAccount", StructureData.RevenueGLAccount);
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	AmountFields = New Array;
	AmountFields.Add("Amount");
	AmountFields.Add("VATAmount");
	AmountFields.Add("Total");
	Parameters.Insert("AmountFields", AmountFields);
	
	HeaderFields = New Structure;
	HeaderFields.Insert("Company", "Company");
	HeaderFields.Insert("StructuralUnit", "StructuralUnit");
	HeaderFields.Insert("Cell", Catalogs.Cells.EmptyRef());
	Parameters.Insert("HeaderFields", HeaderFields);
	
	// for consistency check between Inventory and Inventory ownership fields
	NotUsedFields = New Array;
	NotUsedFields.Add("DiscountMarkupPercent");
	NotUsedFields.Add("AutomaticDiscountsPercent");
	NotUsedFields.Add("AutomaticDiscountAmount");
	NotUsedFields.Add("ConnectionKey");
	NotUsedFields.Add("SerialNumbers");
	Parameters.Insert("NotUsedFields", NotUsedFields);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
	WarehouseData.Insert("TrackingArea", "Outbound_SalesToCustomer");
	
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region PrintInterface

// Function generates tabular document of petty cash book cover.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	Spreadsheet = New SpreadsheetDocument;
	Spreadsheet.PrintParametersName = "PRINT_PARAMETERS_Check_SaleInvoice";
	
	FirstDocument = True;
	
	For Each SalesSlip In ObjectsArray Do
		
		If Not FirstDocument Then
			Spreadsheet.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = Spreadsheet.TableHeight + 1;
		
		Query = New Query;
		Query.SetParameter("CurrentDocument", SalesSlip.Ref);
		
		Query.Text =
		"SELECT ALLOWED
		|	DocReceipt.Number AS Number,
		|	DocReceipt.Date AS Date,
		|	DocReceipt.CashCR AS CashCR,
		|	DocReceipt.DocumentCurrency AS Currency,
		|	DocReceipt.CashCR.Presentation AS Customer,
		|	DocReceipt.Company AS Company,
		|	DocReceipt.Company.Prefix AS Prefix,
		|	DocReceipt.Company.Presentation AS Vendor,
		|	DocReceipt.DocumentAmount AS DocumentAmount,
		|	DocReceipt.AmountIncludesVAT AS AmountIncludesVAT,
		|	DocReceipt.Responsible.Ind AS Responsible,
		|	DocReceipt.Inventory.(
		|		LineNumber AS LineNumber,
		|		Products AS Products,
		|		Products.Presentation AS InventoryItem,
		|		Products.DescriptionFull AS InventoryFullDescr,
		|		Products.Code AS Code,
		|		Products.SKU AS SKU,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Price AS Price,
		|		Amount AS Amount,
		|		VATAmount AS VATAmount,
		|		Total AS Total,
		|		ConnectionKey,
		|		DiscountMarkupPercent,
		|		CASE
		|			WHEN DocReceipt.Inventory.DiscountMarkupPercent <> 0
		|					OR DocReceipt.Inventory.AutomaticDiscountAmount <> 0
		|				THEN 1
		|			ELSE 0
		|		END AS IsDiscount,
		|		AutomaticDiscountAmount
		|	),
		|	DocReceipt.SerialNumbers.(
		|		SerialNumber,
		|		ConnectionKey
		|	)
		|FROM
		|	Document.SalesSlip AS DocReceipt
		|WHERE
		|	DocReceipt.Ref = &CurrentDocument";
		
		// MultilingualSupport
		If PrintParams = Undefined Then
			LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
		Else
			LanguageCode = PrintParams.LanguageCode;
		EndIf;
		
		If LanguageCode <> CurrentLanguage().LanguageCode Then 
			SessionParameters.LanguageCodeForOutput = LanguageCode;
		EndIf;
		
		DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
		// End MultilingualSupport
		
		Header = Query.Execute().Select();
		Header.Next();
		
		Template = PrintManagement.PrintFormTemplate("Document.SalesSlip.PF_MXL_SalesReceipt", LanguageCode);
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company,
			Header.Date,
			,
			,
			,
			LanguageCode);
		
		If Header.Date < Date('20110101') Then
			DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;
		
		// Output invoice header.
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "Sales receipt No "
									+ DocumentNumber
									+ " from "
									+ Format(Header.Date, "DLF=DD");
		
		Spreadsheet.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		VendorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.VendorPresentation = VendorPresentation;
		TemplateArea.Parameters.Vendor = Header.Company;
		Spreadsheet.Put(TemplateArea);
		
		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
		
		NumberArea = Template.GetArea("TableHeader|LineNumber");
		DataArea = Template.GetArea("TableHeader|Data");
		DiscountsArea = Template.GetArea("TableHeader|Discount");
		AmountArea  = Template.GetArea("TableHeader|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		Spreadsheet.Join(DataArea);
		If AreDiscounts Then
			Spreadsheet.Join(DiscountsArea);
		EndIf;
		Spreadsheet.Join(AmountArea);
		
		AreaColumnInventory = Template.Area("InventoryItem");
		
		If Not AreDiscounts Then
			AreaColumnInventory.ColumnWidth =
				AreaColumnInventory.ColumnWidth
			  + Template.Area("AmountWithoutDiscount").ColumnWidth
			  + Template.Area("DiscountAmount").ColumnWidth;
		EndIf;
		
		NumberArea = Template.GetArea("String|LineNumber");
		DataArea = Template.GetArea("String|Data");
		DiscountsArea = Template.GetArea("String|Discount");
		AmountArea  = Template.GetArea("String|Amount");
		
		Amount			= 0;
		VATAmount		= 0;
		Total			= 0;
		TotalDiscounts		= 0;
		TotalWithoutDiscounts	= 0;
		
		LinesSelectionInventory = Header.Inventory.Select();
		LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		While LinesSelectionInventory.Next() Do
			
			If Not ValueIsFilled(LinesSelectionInventory.Products) Then
				CommonClientServer.MessageToUser(
					NStr("en = 'Products value is not filled in in one of the rows - String during printing is skipped.'; ru = 'В одной из строк не заполнено значение номенклатуры - строка при печати пропущена.';pl = 'W jednym z wierszy nie wypełniono wartości pozycji – podczas drukowania wiersz będzie pominięty.';es_ES = 'Valor de productos no está rellenado en una de las filas - Línea durante la impresión se ha saltado.';es_CO = 'Valor de productos no está rellenado en una de las filas - Línea durante la impresión se ha saltado.';tr = 'Ürünler değeri satırlardan birinde doldurulmadı - Yazdırma sırasında dize atlandı.';it = 'In una delle righe manca il valore dell''articolo - la linea è stata saltata durante la stampa.';de = 'Der Produktwert wird in einer der Zeilen nicht ausgefüllt - Zeichenkette während des Druckens wird übersprungen.'",
						LanguageCode));
				Continue;
			EndIf;
			
			NumberArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Put(NumberArea);
			
			DataArea.Parameters.Fill(LinesSelectionInventory);
			StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
			DataArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
				LinesSelectionInventory.InventoryItem, LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
			DataArea.Parameters.Price = Format(LinesSelectionInventory.Price,
				"NFD= " + PricePrecision);
			
			Spreadsheet.Join(DataArea);
			
			Discount = 0;
			
			If AreDiscounts Then
				If LinesSelectionInventory.DiscountMarkupPercent = 100 Then
					Discount = LinesSelectionInventory.Price * LinesSelectionInventory.Quantity;
					DiscountsArea.Parameters.Discount = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = Discount;
				ElsIf LinesSelectionInventory.DiscountMarkupPercent = 0 AND LinesSelectionInventory.AutomaticDiscountAmount = 0 Then
					DiscountsArea.Parameters.Discount = 0;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount;
				Else
					Discount = LinesSelectionInventory.Quantity * LinesSelectionInventory.Price - LinesSelectionInventory.Amount; // AutomaticDiscounts
					DiscountsArea.Parameters.Discount = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount + Discount;
				EndIf;
				Spreadsheet.Join(DiscountsArea);
			EndIf;
			
			AmountArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Join(AmountArea);
			
			Amount			= Amount			+ LinesSelectionInventory.Amount;
			VATAmount		= VATAmount		+ LinesSelectionInventory.VATAmount;
			Total			= Total			+ LinesSelectionInventory.Total;
			TotalDiscounts		= TotalDiscounts	+ Discount;
			TotalWithoutDiscounts	= Amount			+ TotalDiscounts;
			
		EndDo;
		
		// Output Total.
		FillStructureSection = New Structure;
		FillStructureSection.Insert("TitleVAT", ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:"));
		
		NumberArea = Template.GetArea("Total|LineNumber");
		DataArea = Template.GetArea("Total|Data");
		DiscountsArea = Template.GetArea("Total|Discount");
		AmountArea  = Template.GetArea("Total|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		DataArea.Parameters.Fill(FillStructureSection);
		Spreadsheet.Join(DataArea);
		
		If AreDiscounts Then
			
			FillStructureSection.Insert("TotalDiscounts", TotalDiscounts);
			FillStructureSection.Insert("TotalWithoutDiscounts", TotalWithoutDiscounts);
			
			DiscountsArea.Parameters.Fill(FillStructureSection);
			Spreadsheet.Join(DiscountsArea);
			
		EndIf;
		
		FillStructureSection.Insert("Amount", Amount);
		FillStructureSection.Insert("VATAmount", VATAmount);
		FillStructureSection.Insert("Total", Total);
		
		AmountArea.Parameters.Fill(FillStructureSection);
		Spreadsheet.Join(AmountArea);
		
		// Output amount in writing.
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = "Total titles "
										+ String(LinesSelectionInventory.Count())
										+ ", in the amount of "
										+ DriveServer.AmountsFormat(AmountToBeWrittenInWords, Header.Currency);
		
		TemplateArea.Parameters.AmountInWords = CurrencyRateOperations.GenerateAmountInWords(AmountToBeWrittenInWords, Header.Currency);
		
		Spreadsheet.Put(TemplateArea);
		
		// Output signatures.
		TemplateArea = Template.GetArea("Signatures");
		
		If ValueIsFilled(Header.Responsible) Then
			
			ResponsibleData = DriveServer.IndData(
				DriveServer.GetCompany(Header.Company),
				Header.Responsible, 
				Header.Date);
			
			TemplateArea.Parameters.ResponsiblePosition		= ResponsibleData.Position;
			TemplateArea.Parameters.ResponsibleDetails	= ResponsibleData.Presentation;
			
		EndIf;
		
		TemplateArea.Parameters.Fill(Header);
		Spreadsheet.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(Spreadsheet, FirstLineNumber, PrintObjects, SalesSlip);
		
	EndDo;
	
	Spreadsheet.FitToPage = True;
	
	Return Spreadsheet;
	
EndFunction

// Document printing procedure.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
       
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "SalesReceipt") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"SalesReceipt",
			NStr("en = 'Sales receipt'; ru = 'Поступление от продаж';pl = 'Potwierdzenie sprzedaży';es_ES = 'Recibo de ventas';es_CO = 'Recibo de ventas';tr = 'Satış makbuzu';it = 'Ricevuta di vendita';de = 'Verkaufsbon'"),
			PrintForm(ObjectsArray, PrintObjects, "Sales receipt", PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "SimplifiedTaxInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection, 
            "SimplifiedTaxInvoice", 
            NStr("en = 'Simplified tax invoice'; ru = 'Упрощенный налоговый инвойс';pl = 'Uproszczona faktura VAT';es_ES = 'Factura de impuestos simplificada';es_CO = 'Factura fiscal simplificada';tr = 'Sadeleştirilmiş vergi faturası';it = 'Fattura fiscale semplificata';de = 'Vereinfachte Steuerrechnung'"), 
            DataProcessors.PrintSimplifiedTaxInvoice.PrintForm(ObjectsArray, PrintObjects, "SimplifiedTaxInvoice", PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WarrantyCardPerSerialNumber") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WarrantyCardPerSerialNumber",
			NStr("en = 'Warranty card (per serial number)'; ru = 'Гарантийный талон (по серийным номерам)';pl = 'Karta gwarancyjna (dla numeru seryjnego)';es_ES = 'Tarjeta de garantía (por número de serie)';es_CO = 'Tarjeta de garantía (por número de serie)';tr = 'Garanti belgesi (seri numarasına göre)';it = 'Certificato di garanzia (per numero di serie)';de = 'Garantiekarte (nach Seriennummer)'"),
			WorkWithProductsServer.PrintWarrantyCard(ObjectsArray, PrintObjects, "PerSerialNumber", PrintParameters.Result));
															
	EndIf;	
															
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WarrantyCardConsolidated") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WarrantyCardConsolidated",
			NStr("en = 'Warranty card (consolidated)'; ru = 'Гарантийный талон (общий)';pl = 'Karta gwarancyjna (skonsolidowana)';es_ES = 'Tarjeta de garantía (consolidada)';es_CO = 'Tarjeta de garantía (consolidada)';tr = 'Garanti kartı (konsolide)';it = 'Certificato di garanzia (consolidato)';de = 'Garantiekarte (konsolidiert)'"),
			WorkWithProductsServer.PrintWarrantyCard(ObjectsArray, PrintObjects, "Consolidated", PrintParameters.Result));
															
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "SalesReceipt";
	PrintCommand.Presentation = NStr("en = 'Receipt'; ru = 'Получение';pl = 'Paragon';es_ES = 'Recibo';es_CO = 'Recibo';tr = 'Gelir';it = 'Entrata';de = 'Erhalt'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentForm_CWP";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "SimplifiedTaxInvoice";
	PrintCommand.Presentation = NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura fiscal';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentForm_CWP";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.FunctionalOptions = "UseVAT";
	PrintCommand.Order = 2;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID	= "WarrantyCardPerSerialNumber";
	PrintCommand.Presentation = NStr("en = 'Warranty card (per serial number)'; ru = 'Гарантийный талон (по серийным номерам)';pl = 'Karta gwarancyjna (dla numeru seryjnego)';es_ES = 'Tarjeta de garantía (por número de serie)';es_CO = 'Tarjeta de garantía (por número de serie)';tr = 'Garanti belgesi (seri numarasına göre)';it = 'Certificato di garanzia (per numero di serie)';de = 'Garantiekarte (nach Seriennummer)'");
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentForm_CWP";
	PrintCommand.Order = 3;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID	= "WarrantyCardConsolidated";
	PrintCommand.Presentation = NStr("en = 'Warranty card (consolidated)'; ru = 'Гарантийный талон (общий)';pl = 'Karta gwarancyjna (skonsolidowana)';es_ES = 'Tarjeta de garantía (consolidada)';es_CO = 'Tarjeta de garantía (consolidada)';tr = 'Garanti kartı (konsolide)';it = 'Certificato di garanzia (consolidato)';de = 'Garantiekarte (konsolidiert)'");
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentForm_CWP";
	PrintCommand.Order = 4;
	
EndProcedure

#EndRegion

#Region WorkWithSerialNumbers

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		
		Query.Text =
		"SELECT
		|	TableSerialNumbers.Date AS Period,
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
		|	TableSerialNumbers.Date AS EventDate,
		|	TableSerialNumbers.SerialNumber AS SerialNumber,
		|	TableSerialNumbers.Company AS Company,
		|	TableSerialNumbers.Products AS Products,
		|	TableSerialNumbers.Characteristic AS Characteristic,
		|	TableSerialNumbers.Batch AS Batch,
		|	TableSerialNumbers.Ownership AS Ownership,
		|	TableSerialNumbers.StructuralUnit AS StructuralUnit,
		|	TableSerialNumbers.Cell AS Cell,
		|	1 AS Quantity
		|FROM
		|	TemporaryTableInventoryOwnership AS TableSerialNumbers
		|WHERE
		|	NOT TableSerialNumbers.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)
		|	AND (&CheckIssued)
		|	AND (NOT &Archival)";
		
	Else
		
		Query.Text =
		"SELECT
		|	TemporaryTableInventory.Date AS Period,
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	TemporaryTableInventory.Date AS EventDate,
		|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
		|	SerialNumbers.SerialNumber AS SerialNumber,
		|	TemporaryTableInventory.Company AS Company,
		|	TemporaryTableInventory.Products AS Products,
		|	TemporaryTableInventory.Characteristic AS Characteristic,
		|	TemporaryTableInventory.Batch AS Batch,
		|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
		|	TemporaryTableInventory.Cell AS Cell,
		|	1 AS Quantity
		|FROM
		|	TemporaryTableInventory AS TemporaryTableInventory
		|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
		|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
		|			AND (&CheckIssued)
		|			AND (NOT &Archival)";
		
	EndIf;
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf; 
	
EndProcedure

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