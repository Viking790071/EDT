#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function DocumentVATRate(DocumentRef) Export
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "PaymentDetails");
	
	Return DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
EndFunction

#EndRegion

#Region TableGeneration
// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssets(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",					DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashExpense",			NStr("en = 'Bank payment'; ru = 'Списание со счета';pl = 'Płatność bankowa';es_ES = 'Pago bancario';es_CO = 'Pago bancario';tr = 'Banka ödemesi';it = 'Bonifico bancario';de = 'Überweisung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&CashExpense AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic) AS PaymentMethod,
	|	VALUE(Enum.CashAssetTypes.Noncash) AS CashAssetType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.BankAccount AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.Rate * DocumentTable.Multiplicity / (DocumentTable.ExchangeRate * AccountingExchangeRates.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.ExchangeRate * AccountingExchangeRates.Repetition / (AccountingExchangeRates.Rate * DocumentTable.Multiplicity)
	|				END AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.DocumentAmount) AS AmountCur,
	|	-SUM(CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition / (AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				END AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(DocumentTable.DocumentAmount) AS AmountCurForBalance,
	|	DocumentTable.BankAccount.GLAccount AS GLAccount
	|INTO TemporaryTableCashAssets
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfPettyCashe
	|		ON DocumentTable.CashCurrency = ExchangeRateOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToAdvanceHolder)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Other)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Taxes))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Item,
	|	DocumentTable.BankAccount,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.BankAccount.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	&CashExpense,
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic),
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	TemporaryTablePaymentDetails.HeaderItem,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	-SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.OtherSettlements)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.HeaderItem,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	MAX(PayrollPayment.LineNumber),
	|	&CashExpense,
	|	VALUE(AccumulationRecordType.Expense),
	|	PayrollPayment.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic),
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	PayrollPayment.Ref.Item,
	|	PayrollPayment.Ref.BankAccount,
	|	PayrollPayment.Ref.CashCurrency,
	|	SUM(CAST(PayrollSheetEmployees.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition / (AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				END AS NUMBER(15, 2))),
	|	MIN(PayrollPayment.Ref.DocumentAmount),
	|	-SUM(CAST(PayrollSheetEmployees.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition / (AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				END AS NUMBER(15, 2))),
	|	-MIN(PayrollPayment.Ref.DocumentAmount),
	|	PayrollPayment.Ref.BankAccount.GLAccount
	|FROM
	|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
	|		INNER JOIN Document.PaymentExpense.PayrollPayment AS PayrollPayment
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfPettyCashe
	|			ON PayrollPayment.Ref.CashCurrency = ExchangeRateOfPettyCashe.Currency
	|		ON PayrollSheetEmployees.Ref = PayrollPayment.Statement
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRates
	|		ON (TRUE)
	|WHERE
	|	PayrollPayment.Ref = &Ref
	|	AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|
	|GROUP BY
	|	PayrollPayment.Ref.Date,
	|	PayrollPayment.Ref.Item,
	|	PayrollPayment.Ref.BankAccount,
	|	PayrollPayment.Ref.CashCurrency,
	|	PayrollPayment.Ref.BankAccount.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	TableBankCharges.PostingContent,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableBankCharges.Period,
	|	TableBankCharges.Company,
	|	TableBankCharges.PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic),
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	TableBankCharges.Item,
	|	TableBankCharges.BankAccount,
	|	TableBankCharges.Currency,
	|	SUM(TableBankCharges.Amount),
	|	SUM(TableBankCharges.AmountCur),
	|	SUM(TableBankCharges.Amount),
	|	SUM(TableBankCharges.AmountCur),
	|	TableBankCharges.GLAccount
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|WHERE
	|	(TableBankCharges.Amount <> 0
	|			OR TableBankCharges.AmountCur <> 0)
	|
	|GROUP BY
	|	TableBankCharges.PostingContent,
	|	TableBankCharges.Company,
	|	TableBankCharges.PresentationCurrency,
	|	TableBankCharges.Period,
	|	TableBankCharges.Item,
	|	TableBankCharges.BankAccount,
	|	TableBankCharges.GLAccount,
	|	TableBankCharges.Currency
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	PaymentMethod,
	|	BankAccountPettyCash,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text = 
	"SELECT
	|	TemporaryTableCashAssets.Company AS Company,
	|	TemporaryTableCashAssets.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableCashAssets.PaymentMethod AS PaymentMethod,
	|	TemporaryTableCashAssets.CashAssetType AS CashAssetType,
	|	TemporaryTableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	TemporaryTableCashAssets.Currency AS Currency
	|FROM
	|	TemporaryTableCashAssets AS TemporaryTableCashAssets";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashAssets");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesCashAssets(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableBankReconciliation(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseBankReconciliation") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankReconciliation", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref",					DocumentRefPaymentExpense);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Period,
	|	&Ref AS Transaction,
	|	DocumentTable.BankAccount AS BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Payment) AS TransactionType,
	|	-DocumentTable.DocumentAmount AS Amount
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToAdvanceHolder)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Other)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.OtherSettlements)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Taxes))
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.Date,
	|	&Ref,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Payment),
	|	-SUM(TemporaryTablePaymentDetails.PaymentAmount)
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.BankAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	SalaryPayment.Date,
	|	&Ref,
	|	SalaryPayment.BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Payment),
	|	-SalaryPayment.DocumentAmount
	|FROM
	|	Document.PaymentExpense AS SalaryPayment
	|WHERE
	|	SalaryPayment.Ref = &Ref
	|	AND SalaryPayment.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableBankCharges.Period,
	|	&Ref,
	|	TableBankCharges.BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Fee),
	|	-SUM(TableBankCharges.AmountCur)
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|WHERE
	|	TableBankCharges.AmountCur <> 0
	|
	|GROUP BY
	|	TableBankCharges.Period,
	|	TableBankCharges.BankAccount";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankReconciliation", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateAdvanceHoldersTable(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AdvanceHolderDebtEmergence",	NStr("en = 'Payment to advance holder'; ru = 'Выдача денег подотчетнику';pl = 'Płatność dla zaliczkobiorcy';es_ES = 'Pago al titular de anticipo';es_CO = 'Pago al titular de anticipo';tr = 'Avans sahibine ödeme';it = 'Pagamento alla persona che ha anticipato';de = 'Zahlung an die abrechnungspflichtige Person'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&AdvanceHolderDebtEmergence AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.BankAccount AS BankAccount,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END AS Document,
	|	DocumentTable.AdvanceHolder AS Employee,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(CAST(DocumentTable.DocumentAmount *CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.Rate * SettlementsExchangeRate.Repetition / (SettlementsExchangeRate.Rate * AccountingExchangeRates.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN SettlementsExchangeRate.Rate * AccountingExchangeRates.Repetition / (AccountingExchangeRates.Rate * SettlementsExchangeRate.Repetition)
	|				END AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.DocumentAmount) AS AmountCur,
	|	SUM(CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.Rate * SettlementsExchangeRate.Repetition / (SettlementsExchangeRate.Rate * AccountingExchangeRates.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN SettlementsExchangeRate.Rate * AccountingExchangeRates.Repetition / (AccountingExchangeRates.Rate * SettlementsExchangeRate.Repetition)
	|				END AS NUMBER(15, 2))) AS AmountForBalance,
	|	SUM(DocumentTable.DocumentAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN DocumentTable.AdvanceHoldersReceivableGLAccount
	|		ELSE DocumentTable.AdvanceHoldersPayableGLAccount
	|	END AS GLAccount
	|INTO TemporaryTableAdvanceHolders
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency AND Company = &Company) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementsExchangeRate
	|		ON DocumentTable.CashCurrency = SettlementsExchangeRate.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToAdvanceHolder)
	|
	|GROUP BY
	|	DocumentTable.BankAccount,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.Date,
	|	DocumentTable.CashCurrency,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN DocumentTable.AdvanceHoldersReceivableGLAccount
	|		ELSE DocumentTable.AdvanceHoldersPayableGLAccount
	|	END
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Employee,
	|	Currency,
	|	Document,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock of controlled balances of payments to accountable persons.
	Query.Text = 
	"SELECT
	|	TemporaryTableAdvanceHolders.Company AS Company,
	|	TemporaryTableAdvanceHolders.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAdvanceHolders.Employee AS Employee,
	|	TemporaryTableAdvanceHolders.Currency AS Currency,
	|	TemporaryTableAdvanceHolders.Document AS Document
	|FROM
	|	TemporaryTableAdvanceHolders AS TemporaryTableAdvanceHolders";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AdvanceHolders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAdvanceHolders(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAdvanceHolders", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AppearenceOfVendorAdvance", NStr("en = 'Advance payment to supplier'; ru = 'Аванс поставщику';pl = 'Zaliczka dla dostawcy';es_ES = 'Pago del anticipo al proveedor';es_CO = 'Pago anticipado al proveedor';tr = 'Tedarikçiye avans ödeme';it = 'Pagamento anticipato al fornitore';de = 'Vorauszahlung an den Lieferanten'", MainLanguageCode));
	Query.SetParameter("VendorObligationsRepayment", NStr("en = 'Payment to supplier'; ru = 'Погашение обязательств поставщика';pl = 'Płatność dla dostawcy';es_ES = 'Pago al proveedor';es_CO = 'Pago al proveedor';tr = 'Tedarikçiye ödeme';it = 'Pagamento al fornitore';de = 'Zahlung an den Lieferanten'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount", NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	FALSE AS IsEPD,
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &Ref
	|		ELSE TemporaryTablePaymentDetails.Document
	|	END AS Document,
	|	&Company AS Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.BankAccount AS BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.VendorAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfVendorAdvance
	|		ELSE &VendorObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForPayment,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &Ref
	|		ELSE TemporaryTablePaymentDetails.Document
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.VendorAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountVendorSettlements
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfVendorAdvance
	|		ELSE &VendorObligationsRepayment
	|	END,
	|	TemporaryTablePaymentDetails.PresentationCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	TemporaryTablePaymentDetails.Date,
	|	-SUM(TemporaryTablePaymentDetails.EPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	&EarlyPaymentDiscount,
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount)
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TemporaryTablePaymentDetails.Document = SupplierInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.PresentationCurrency
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
	|	TemporaryTableAccountsPayable AS TemporaryTableAccountsPayable";
	
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
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled balances of accounts receivable.
	Query.Text =
	"SELECT DISTINCT
	|	TemporaryTablePaymentDetails.Company AS Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePaymentDetails.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CustomerAdvanceRepayment", NStr("en = 'Refund to customer'; ru = 'Возврат покупателю';pl = 'Zwrot dla nabywcy';es_ES = 'Devolución al cliente';es_CO = 'Devolución al cliente';tr = 'Müşteriye para iadesi';it = 'Rimborsato al cliente';de = 'Rückerstattung an den Kunden'", MainLanguageCode));
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en = 'Payment to customer'; ru = 'Возникновение обязательств покупателя';pl = 'Płatność do klienta';es_ES = 'Pago al cliente';es_CO = 'Pago al cliente';tr = 'Müşteriye ödeme';it = 'Pagamento al cliente';de = 'Zahlung an den Kunden'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT DISTINCT
	|	TemporaryTablePaymentDetails.Company AS Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePaymentDetails.SettlementsType AS SettlementsType
	|INTO TemporaryTableAccountsReceivableAdvances
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|	AND TemporaryTablePaymentDetails.AdvanceFlag
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableBalances.Company AS Company,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.Contract AS Contract,
	|	TableBalances.Document AS Document,
	|	TableBalances.Order AS Order,
	|	TableBalances.SettlementsType AS SettlementsType,
	|	SUM(TableBalances.AmountBalance) AS AmountBalance,
	|	SUM(TableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableAdvancesBalances
	|FROM
	|	(SELECT
	|		TableBalances.Company AS Company,
	|		TableBalances.PresentationCurrency AS PresentationCurrency,
	|		TableBalances.Counterparty AS Counterparty,
	|		TableBalances.Contract AS Contract,
	|		TableBalances.Document AS Document,
	|		TableBalances.Order AS Order,
	|		TableBalances.SettlementsType AS SettlementsType,
	|		TableBalances.AmountBalance AS AmountBalance,
	|		TableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				&PointInTime,
	|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) IN
	|					(SELECT
	|						TemporaryTableAccountsReceivableAdvances.Company,
	|						TemporaryTableAccountsReceivableAdvances.PresentationCurrency,
	|						TemporaryTableAccountsReceivableAdvances.Counterparty,
	|						TemporaryTableAccountsReceivableAdvances.Contract,
	|						TemporaryTableAccountsReceivableAdvances.Document,
	|						TemporaryTableAccountsReceivableAdvances.Order,
	|						TemporaryTableAccountsReceivableAdvances.SettlementsType
	|					FROM
	|						TemporaryTableAccountsReceivableAdvances)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.PresentationCurrency,
	|		DocumentRegisterRecords.Counterparty,
	|		DocumentRegisterRecords.Contract,
	|		DocumentRegisterRecords.Document,
	|		DocumentRegisterRecords.Order,
	|		DocumentRegisterRecords.SettlementsType,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecords.Amount
	|			ELSE DocumentRegisterRecords.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecords.AmountCur
	|			ELSE DocumentRegisterRecords.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref) AS TableBalances
	|
	|GROUP BY
	|	TableBalances.Document,
	|	TableBalances.SettlementsType,
	|	TableBalances.Company,
	|	TableBalances.Order,
	|	TableBalances.Counterparty,
	|	TableBalances.Contract,
	|	TableBalances.PresentationCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	&Company AS Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTablePaymentDetails.BankAccount AS BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePaymentDetails.SettlementsType AS SettlementsType,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	TemporaryTablePaymentDetails.PaymentAmount AS PaymentAmount,
	|	CASE
	|		WHEN ISNULL(AdvancesBalances.AmountCurBalance, 0) = 0
	|			THEN TemporaryTablePaymentDetails.AccountingAmount
	|		ELSE TemporaryTablePaymentDetails.SettlementsAmount * AdvancesBalances.AmountBalance / AdvancesBalances.AmountCurBalance
	|	END AS Amount,
	|	TemporaryTablePaymentDetails.SettlementsAmount AS AmountCur,
	|	CASE
	|		WHEN ISNULL(AdvancesBalances.AmountCurBalance, 0) = 0
	|			THEN TemporaryTablePaymentDetails.AccountingAmount
	|		ELSE TemporaryTablePaymentDetails.SettlementsAmount * AdvancesBalances.AmountBalance / AdvancesBalances.AmountCurBalance
	|	END AS AmountForBalance,
	|	TemporaryTablePaymentDetails.SettlementsAmount AS AmountCurForBalance,
	|	CASE
	|		WHEN ISNULL(AdvancesBalances.AmountCurBalance, 0) = 0
	|			THEN TemporaryTablePaymentDetails.AccountingAmount
	|		ELSE TemporaryTablePaymentDetails.SettlementsAmount * AdvancesBalances.AmountBalance / AdvancesBalances.AmountCurBalance
	|	END AS AmountForPayment,
	|	TemporaryTablePaymentDetails.SettlementsAmount AS AmountForPaymentCur,
	|	TemporaryTablePaymentDetails.CustomerAdvancesGLAccount AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	&CustomerAdvanceRepayment AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		LEFT JOIN TemporaryTableAccountsReceivableAdvancesBalances AS AdvancesBalances
	|		ON TemporaryTablePaymentDetails.Company = AdvancesBalances.Company
	|			AND TemporaryTablePaymentDetails.PresentationCurrency = AdvancesBalances.PresentationCurrency
	|			AND TemporaryTablePaymentDetails.Counterparty = AdvancesBalances.Counterparty
	|			AND TemporaryTablePaymentDetails.Contract = AdvancesBalances.Contract
	|			AND TemporaryTablePaymentDetails.Document = AdvancesBalances.Document
	|			AND (CASE
	|				WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|						AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|						AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|					THEN TemporaryTablePaymentDetails.Order
	|				ELSE UNDEFINED
	|			END = AdvancesBalances.Order)
	|			AND TemporaryTablePaymentDetails.SettlementsType = AdvancesBalances.SettlementsType
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|	AND TemporaryTablePaymentDetails.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.SettlementsType,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.PaymentAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	&AppearenceOfCustomerLiability
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
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
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePayroll(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 								DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", 						New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", 					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", 							StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("RepaymentLiabilitiesToEmployees", 	NStr("en = 'Payroll payment'; ru = 'Погашение обязательств перед персоналом';pl = 'Płatności z tytułu płac';es_ES = 'Pago de nómina';es_CO = 'Pago de nómina';tr = 'Bordro ödemesi';it = 'Pagamento busta paga';de = 'Zahlung der Gehaltsabrechnung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", 				NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",				StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	PayrollSheet.Ref
	|FROM
	|	Document.PayrollSheet AS PayrollSheet
	|WHERE
	|	PayrollSheet.Ref In
	|			(SELECT
	|				PayrollPayment.Statement
	|			FROM
	|				Document.PaymentExpense.PayrollPayment AS PayrollPayment
	|			WHERE
	|				PayrollPayment.Ref = &Ref)";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("Document.PayrollSheet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	MAX(PayrollPayment.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PayrollPayment.Ref.Date AS Date,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	PayrollSheetEmployees.Ref.StructuralUnit AS StructuralUnit,
	|	PayrollSheetEmployees.Employee AS Employee,
	|	PayrollSheetEmployees.Ref.DocumentCurrency AS Currency,
	|	PayrollSheetEmployees.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	SUM(CAST(PayrollSheetEmployees.SettlementsAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition / (AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition)
	|			END AS NUMBER(15, 2))) AS Amount,
	|	SUM(PayrollSheetEmployees.PaymentAmount) AS AmountCur,
	|	-SUM(CAST(PayrollSheetEmployees.SettlementsAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRates.Repetition / (AccountingExchangeRates.Rate * ExchangeRateOfPettyCashe.Repetition)
	|			END AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(PayrollSheetEmployees.PaymentAmount) AS AmountCurForBalance,
	|	PayrollSheetEmployees.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	&RepaymentLiabilitiesToEmployees AS ContentOfAccountingRecord,
	|	PayrollPayment.Ref.BankAccount AS BankAccount
	|INTO TemporaryTablePayroll
	|FROM
	|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
	|		INNER JOIN Document.PaymentExpense.PayrollPayment AS PayrollPayment
	|		ON PayrollSheetEmployees.Ref = PayrollPayment.Statement
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfPettyCashe
	|		ON PayrollSheetEmployees.Ref.SettlementsCurrency = ExchangeRateOfPettyCashe.Currency
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRates
	|		ON (TRUE)
	|WHERE
	|	PayrollPayment.Ref = &Ref
	|	AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|
	|GROUP BY
	|	PayrollPayment.Ref.Date,
	|	PayrollSheetEmployees.Ref.StructuralUnit,
	|	PayrollSheetEmployees.Employee,
	|	PayrollSheetEmployees.Ref.DocumentCurrency,
	|	PayrollSheetEmployees.Ref.RegistrationPeriod,
	|	PayrollSheetEmployees.Employee.SettlementsHumanResourcesGLAccount,
	|	PayrollPayment.Ref.BankAccount
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	Employee,
	|	Currency,
	|	RegistrationPeriod,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of payroll payable.
	Query.Text =
	"SELECT
	|	TemporaryTablePayroll.Company AS Company,
	|	TemporaryTablePayroll.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePayroll.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePayroll.Employee AS Employee,
	|	TemporaryTablePayroll.Currency AS Currency,
	|	TemporaryTablePayroll.RegistrationPeriod AS RegistrationPeriod
	|FROM
	|	TemporaryTablePayroll AS TemporaryTablePayroll";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Payroll");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesPayroll(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefPaymentExpense);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("CostsReflection",				NStr("en = 'Record expenses'; ru = 'Отражение расходов';pl = 'Rejestr rozchodów';es_ES = 'Registrar los gastos';es_CO = 'Registrar los gastos';tr = 'Masrafların yansıtılması';it = 'Registrazione spese';de = 'Angezeigte Ausgaben'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			THEN DocumentTable.Department
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|				AND NOT DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				AND NOT DocumentTable.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN DocumentTable.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			THEN DocumentTable.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END AS BusinessLine,
	|	DocumentTable.ExpenseItem AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	&CostsReflection AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	CAST(DocumentTable.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN AccountingExchangeRateSliceLast.Rate * DocumentTable.Multiplicity / (DocumentTable.ExchangeRate * AccountingExchangeRateSliceLast.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentTable.ExchangeRate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * DocumentTable.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.RegisterExpense
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Other)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty))
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
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
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
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
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
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
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
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
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
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
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
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
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
	|	TemporaryTableExchangeDifferencesPayroll AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	1,
	|	TableBankCharges.Period,
	|	TableBankCharges.Company,
	|	TableBankCharges.PresentationCurrency,
	|	TableBankCharges.FeeDepartment,
	|	TableBankCharges.FeeOrder,
	|	TableBankCharges.FeeBusinessLine,
	|	TableBankCharges.BankFeeExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableBankCharges.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	TableBankCharges.PostingContent,
	|	0,
	|	TableBankCharges.Amount,
	|	FALSE
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|WHERE
	|	TableBankCharges.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN 0
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	FALSE
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN 0
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesLoanSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	SupplierInvoice.Department,
	|	CASE
	|		WHEN DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.Order
	|	END,
	|	UNDEFINED,
	|	DocumentTable.DiscountReceivedIncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.DiscountReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	&EarlyPaymentDiscount,
	|	SUM(CASE
	|			WHEN SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN DocumentTable.AccountingEPDAmountExclVAT
	|			ELSE DocumentTable.AccountingEPDAmount
	|		END),
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON DocumentTable.Document = SupplierInvoice.Ref
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|	AND DocumentTable.EPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	SupplierInvoice.Department,
	|	DocumentTable.Order,
	|	DocumentTable.DiscountReceivedIncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.DiscountReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefPaymentExpense);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Content",						NStr("en = 'Expenses incurred'; ru = 'Списание денежных средств на произвольный счет';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("TaxPay",						NStr("en = 'Tax payment'; ru = 'Оплата налога';pl = 'Zapłata podatku';es_ES = 'Pago de impuestos';es_CO = 'Pago de impuestos';tr = 'Vergi ödemesi';it = 'Pagamento tassa';de = 'Steuerzahlung'", MainLanguageCode));
	Query.SetParameter("ContentVAT",					NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ContentVATOnAdvance",			NStr("en = 'VAT on advance'; ru = 'НДС с авансов';pl = 'VAT z zaliczek';es_ES = 'IVA del anticipo';es_CO = 'IVA del anticipo';tr = 'Avans KDV''si';it = 'IVA sull''anticipo';de = 'USt. auf Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("VATAdvancesToSuppliers",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.Correspondence AS AccountDr,
	|	DocumentTable.BankAccount.GLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.DocumentAmount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.DocumentAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.AccountingAmount AS Amount,
	|	CAST(&Content AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementsExchangeRate
	|		ON DocumentTable.CashCurrency = SettlementsExchangeRate.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Other)
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.TaxKind.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.TaxKind.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.TaxKind.GLAccount.Currency
	|			THEN DocumentTable.DocumentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.DocumentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount AS Amount,
	|	CAST(&TaxPay AS STRING(100)),
	|	FALSE
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementsExchangeRate
	|		ON DocumentTable.CashCurrency = SettlementsExchangeRate.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Taxes)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAdvanceHolders AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
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
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAccountsReceivable AS DocumentTable
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
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAccountsPayable AS DocumentTable
	|WHERE
	|	NOT DocumentTable.isEPD
	|
	|UNION ALL
	|
	|SELECT
	|	8,
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
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
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
	|	9,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTablePayroll AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	11,
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
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeDifferencesPayroll AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	12,
	|	1,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLExpenseAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLExpenseAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLExpenseAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.PostingContent,
	|	FALSE
	|FROM
	|	TemporaryTableBankCharges AS DocumentTable
	|WHERE
	|	(DocumentTable.Amount <> 0
	|			OR DocumentTable.AmountCur <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	13,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	14,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.PostingContent,
	|	FALSE
	|FROM
	|	TemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	15,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.BankAccount.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.PostingContent,
	|	FALSE
	|FROM
	|	TemporaryTableLoanSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	16,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesLoanSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	19,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATInput,
	|	&VATAdvancesToSuppliers,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATOnAdvance,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|	AND &PostAdvancePaymentsBySourceDocuments
	|	AND DocumentTable.AdvanceFlag
	|	AND DocumentTable.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	20,
	|	1,
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.DiscountReceivedGLAccount,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DiscountReceivedGLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|				THEN CASE
	|						WHEN SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.SettlementsEPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.DiscountReceivedGLAccount.Currency
	|				THEN CASE
	|						WHEN SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.EPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.EPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT
	|			ELSE TemporaryTablePaymentDetails.AccountingEPDAmount
	|		END),
	|	&EarlyPaymentDiscount,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TemporaryTablePaymentDetails.Document = SupplierInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.DiscountReceivedGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DiscountReceivedGLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	21,
	|	1,
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.VATInputGLAccount,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	UNDEFINED,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|				THEN TemporaryTablePaymentDetails.SettlementsEPDAmount - TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|			ELSE 0
	|		END),
	|	0,
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount - TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT),
	|	&ContentVAT,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TemporaryTablePaymentDetails.Document = SupplierInvoice.Ref
	|			AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.VATInputGLAccount
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 									DocumentRefPaymentExpense);
	Query.SetParameter("Company", 								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", 							New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("PresentationCurrency",					StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",					StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
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
	|	0,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountExpense > 0
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	CASE
	|		WHEN DocumentTable.BusinessLine <> VALUE(Catalog.LinesOfBusiness.EmptyRef)
	|			THEN DocumentTable.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END,
	|	DocumentTable.Item,
	|	0,
	|	CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRateSliceLast.Rate * SettlementsExchangeRate.Repetition / (SettlementsExchangeRate.Rate * AccountingExchangeRateSliceLast.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN SettlementsExchangeRate.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * SettlementsExchangeRate.Repetition)
	|				END AS NUMBER(15, 2))
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementsExchangeRate
	|		ON DocumentTable.CashCurrency = SettlementsExchangeRate.Currency
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Taxes)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty))
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
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
	|	-Table.AmountIncome,
	|	0
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountIncome > 0
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.FeeBusinessLine,
	|	Table.Item,
	|	0,
	|	Table.Amount
	|FROM
	|	TemporaryTableBankCharges AS Table
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND Table.Amount <> 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	&Ref AS Document,
	|	DocumentTable.Item AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	&Ref,
	|	DocumentTable.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Item";
	
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
	|					AND PresentationCurrency = &PresentationCurrency
	|					AND Document In
	|						(SELECT
	|							DocumentTable.Document
	|						FROM
	|							TemporaryTablePaymentDetails AS DocumentTable
	|						WHERE
	|							(DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|								OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)))) AS IncomeAndExpensesRetainedBalances
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
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|	AND Not DocumentTable.AdvanceFlag
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
	|	Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|INTO TemporaryTableTableDeferredIncomeAndExpenditure
	|FROM
	|	&Table AS Table
	|WHERE
	|	(Table.AmountIncome > 0
	|			OR Table.AmountExpense > 0)";
	
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
	|	-Table.AmountIncome AS AmountIncome,
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
Procedure GenerateTableTaxesSettlements(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefPaymentExpense);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DocumentCurrency",		DocumentRefPaymentExpense.CashCurrency);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("TaxPay",				NStr("en = 'Tax payment'; ru = 'Оплата налога';pl = 'Zapłata podatku';es_ES = 'Pago de impuestos';es_CO = 'Pago de impuestos';tr = 'Vergi ödemesi';it = 'Pagamento tassa';de = 'Steuerzahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO ExchangeRate
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &DocumentCurrency) AND Company = &Company) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.TaxKind AS TaxKind,
	|	CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingCurrencyRate.ExchangeRate * DocumentTable.Multiplicity / (DocumentTable.ExchangeRate * AccountingCurrencyRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.ExchangeRate * AccountingCurrencyRate.Multiplicity / (AccountingCurrencyRate.ExchangeRate * DocumentTable.Multiplicity)
	|				END AS NUMBER(15, 2)) AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.TaxKind.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	&TaxPay AS ContentOfAccountingRecord
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN ExchangeRate AS DocumentCurrencyRate
	|		ON DocumentTable.CashCurrency = DocumentCurrencyRate.Currency
	|		LEFT JOIN ExchangeRate AS AccountingCurrencyRate
	|		ON (AccountingCurrencyRate.Currency = &PresentationCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Taxes)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UsePaymentCalendar", Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Item AS Item,
	|	VALUE(Catalog.PaymentMethods.Electronic) AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	DocumentTable.BankAccount AS BankAccountPettyCash,
	|	ISNULL(DocumentTable.SettlementsCurrency, DocumentTable.CashCurrency) AS Currency,
	|	DocumentTable.QuoteToPaymentCalendar AS Quote,
	|	CASE
	|		WHEN DocumentTable.SettlementsCurrency IS NULL
	|			THEN SUM(-DocumentTable.PaymentAmount)
	|		ELSE SUM(-DocumentTable.SettlementsAmount)
	|	END AS PaymentAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.OperationKind <> VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|
	|GROUP BY
	|	DocumentTable.Item,
	|	DocumentTable.Date,
	|	DocumentTable.BankAccount,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.QuoteToPaymentCalendar
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MAX(DocumentTable.LineNumber),
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Ref.Item,
	|	VALUE(Catalog.PaymentMethods.Electronic),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.Ref.BankAccount,
	|	DocumentTable.Ref.CashCurrency,
	|	DocumentTable.PlanningDocument,
	|	SUM(-DocumentTable.PaymentAmount)
	|FROM
	|	Document.PaymentExpense.PayrollPayment AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.PlanningDocument,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Item,
	|	DocumentTable.Ref.BankAccount,
	|	DocumentTable.Ref.CashCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Item,
	|	VALUE(Catalog.PaymentMethods.Electronic),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.BankAccount,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	-DocumentTable.DocumentAmount
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN (SELECT
	|			COUNT(ISNULL(TemporaryTablePaymentDetails.LineNumber, 0)) AS Quantity
	|		FROM
	|			TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails) AS NestedSelect
	|		ON (TRUE)
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|	AND NestedSelect.Quantity = 0
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefPaymentExpense);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Order AS Quote,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|			THEN -1
	|		ELSE 1
	|	END AS PaymentAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.DoOperationsByOrders
	|	AND (VALUETYPE(DocumentTable.Order) = TYPE(Document.SalesOrder)
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			OR VALUETYPE(DocumentTable.Order) = TYPE(Document.PurchaseOrder)
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			OR VALUETYPE(DocumentTable.Order) = TYPE(Document.SubcontractorOrderIssued)
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef))
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.OperationKind
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	If NOT StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		OR StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments
		OR DocumentRefPaymentExpense.OperationKind <> Enums.OperationTypesPaymentExpense.Vendor Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Payment.Period AS Period,
	|	Payment.Company AS Company,
	|	Payment.CompanyVATNumber AS CompanyVATNumber,
	|	Payment.PresentationCurrency AS PresentationCurrency,
	|	Payment.Supplier AS Supplier,
	|	Payment.ShipmentDocument AS ShipmentDocument,
	|	Payment.VATRate AS VATRate,
	|	Payment.VATInputGLAccount AS GLAccount,
	|	Payment.AmountExcludesVAT AS AmountExcludesVAT,
	|	Payment.VATAmount AS VATAmount
	|FROM
	|	VAT AS Payment";
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableVATInput(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		AND DocumentRefPaymentExpense.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		
		PostAdvancePayments = StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments;
		
		Query = New Query;
		Query.SetParameter("PostAdvancePayments", PostAdvancePayments);
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	Payment.Period AS Period,
		|	Payment.Company AS Company,
		|	Payment.CompanyVATNumber AS CompanyVATNumber,
		|	Payment.PresentationCurrency AS PresentationCurrency,
		|	Payment.Supplier AS Supplier,
		|	Payment.ShipmentDocument AS ShipmentDocument,
		|	Payment.VATRate AS VATRate,
		|	Payment.VATInputGLAccount AS GLAccount,
		|	VALUE(Enum.VATOperationTypes.AdvancePayment) AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	Payment.AmountExcludesVAT AS AmountExcludesVAT,
		|	Payment.VATAmount AS VATAmount
		|FROM
		|	VAT AS Payment
		|WHERE
		|	&PostAdvancePayments
		|
		|UNION ALL
		|
		|SELECT
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.CompanyVATNumber,
		|	Payment.PresentationCurrency,
		|	Payment.Counterparty,
		|	SupplierInvoice.Ref,
		|	Payment.VATRate,
		|	Payment.VATInputGLAccount AS GLAccount,
		|	VALUE(Enum.VATOperationTypes.DiscountReceived),
		|	VALUE(Enum.ProductsTypes.EmptyRef),
		|	-SUM(Payment.AccountingEPDAmountExclVAT),
		|	-SUM(Payment.AccountingEPDAmount - Payment.AccountingEPDAmountExclVAT)
		|FROM
		|	TemporaryTablePaymentDetails AS Payment
		|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
		|		ON Payment.Document = SupplierInvoice.Ref
		|			AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
		|		LEFT JOIN Catalog.VATRates AS VATRates
		|		ON (VATRates.Ref = Payment.VATRate)
		|WHERE
		|	NOT Payment.VATRate.NotTaxable
		|	AND NOT Payment.AdvanceFlag
		|	AND Payment.AccountingEPDAmount > 0
		|
		|GROUP BY
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.CompanyVATNumber,
		|	Payment.PresentationCurrency,
		|	Payment.Counterparty,
		|	SupplierInvoice.Ref,
		|	Payment.VATInputGLAccount,
		|	Payment.VATRate";
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		
	EndIf;
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT Then
		DocumentAttributes = Common.ObjectAttributesValues(DocumentRefPaymentExpense, "OperationKind, Date");
		If DocumentAttributes.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
			
			PostAdvancePayments = StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments;
			
			Query = New Query;
			Query.SetParameter("PostAdvancePayments", PostAdvancePayments);
			Query.SetParameter("VATOutput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
			Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
			Query.Text =
			"SELECT
			|	Payment.Date AS Period,
			|	Payment.Company AS Company,
			|	Payment.CompanyVATNumber AS CompanyVATNumber,
			|	Payment.PresentationCurrency AS PresentationCurrency,
			|	Payment.Counterparty AS Customer,
			|	Payment.Ref AS ShipmentDocument,
			|	Payment.VATRate AS VATRate,
			|	&VATOutput AS GLAccount,
			|	VALUE(Enum.VATOperationTypes.AdvancePayment) AS OperationType,
			|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
			|	-SUM(Payment.AmountExcludesVAT) AS AmountExcludesVAT,
			|	-SUM(Payment.VATAmount) AS VATAmount
			|FROM
			|	TemporaryTablePaymentDetails AS Payment
			|WHERE
			|	NOT Payment.VATRate.NotTaxable
			|	AND Payment.AdvanceFlag
			|	AND Payment.VATAmount > 0
			|	AND &PostAdvancePayments
			|
			|GROUP BY
			|	Payment.Date,
			|	Payment.Company,
			|	Payment.CompanyVATNumber,
			|	Payment.Counterparty,
			|	Payment.Ref,
			|	Payment.VATRate,
			|	Payment.PresentationCurrency";
			
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
			
		EndIf;
	EndIf;
	
	If Not StructureAdditionalProperties.TableForRegisterRecords.Property("TableVATOutput") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
	EndIf;
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPaymentExpense, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 					DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("PresentationCurrency", 	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency", 			DocumentRefPaymentExpense.CashCurrency);
	Query.SetParameter("LoanContractCurrency", 	DocumentRefPaymentExpense.LoanContract.SettlementsCurrency);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("VATInput",				Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("CreditPrincipalDebtPayment",	NStr("en = 'Loan principal payment'; ru = 'Оплата основного долга по кредиту';pl = 'Opłata kwoty głównej';es_ES = 'Pago principal del préstamo';es_CO = 'Pago principal del préstamo';tr = 'Borç anapara ödeme';it = 'Pagamento debito principale';de = 'Darlehensrückzahlung'",
														MainLanguageCode));
	Query.SetParameter("CreditInterestPayment",			NStr("en = 'Loan interest payment'; ru = 'Оплата процентов по кредиту';pl = 'Opłata odsetek od pożyczki';es_ES = 'Pago del interés del préstamo';es_CO = 'Pago del interés del préstamo';tr = 'Borç faiz ödemesi';it = 'Pagamento degli interessi del prestito';de = 'Darlehenszinszahlung'",
														MainLanguageCode));
	Query.SetParameter("CreditCommissionPayment",		NStr("en = 'Loan Commission payment'; ru = 'Оплата комиссии по кредиту';pl = 'Opłata prowizji od pożyczki';es_ES = 'Pago de la comisión del préstamo';es_CO = 'Pago de la comisión del préstamo';tr = 'Borç komisyon ödemesi';it = 'Pagamento della commisione del prestito';de = 'Zahlung der Darlehensprovision'",
														MainLanguageCode));
	Query.Text =
	"SELECT
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO TemporaryTableExchangeRateSliceLatest
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&PointInTime,
	|			Currency IN (&PresentationCurrency, &CashCurrency, &LoanContractCurrency)
	|				AND Company = &Company) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	PaymentExpense.Ref AS Ref,
	|	PaymentExpense.OperationKind AS OperationKind,
	|	&Company AS Company,
	|	PaymentExpense.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentExpense.Item AS Item,
	|	PaymentExpense.CashCurrency AS CashCurrency,
	|	PaymentExpense.DocumentAmount AS AmountCur,
	|	PaymentExpense.TaxKind AS TaxKind,
	|	PaymentExpense.Department AS Department,
	|	PaymentExpense.BusinessLine AS BusinessLine,
	|	PaymentExpense.Order AS Order,
	|	PaymentExpense.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PaymentExpense.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS Correspondence,
	|	PaymentExpense.AdvanceHolder AS AdvanceHolder,
	|	PaymentExpense.LoanContract AS LoanContract,
	|	PaymentExpense.Document AS Document,
	|	PaymentExpense.BasisDocument AS BasisDocument,
	|	PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.OtherSettlements) AS AccountingOtherSettlements,
	|	PaymentExpense.BankAccount AS BankAccount,
	|	PaymentExpense.Counterparty AS Counterparty,
	|	PaymentExpense.CounterpartyAccount AS CounterpartyAccount,
	|	CASE
	|		WHEN PaymentExpense.Paid
	|				AND PaymentExpense.PaymentDate <> DATETIME(1, 1, 1)
	|				AND PaymentExpense.PaymentDate <> BEGINOFPERIOD(PaymentExpense.Date, DAY)
	|			THEN PaymentExpense.PaymentDate
	|		ELSE PaymentExpense.Date
	|	END AS Date,
	|	PaymentExpense.DocumentAmount AS DocumentAmount,
	|	PaymentExpense.VATTaxation AS VATTaxation
	|INTO DocumentsTable
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentsTable.Ref AS Ref,
	|	DocumentsTable.OperationKind AS OperationKind,
	|	&Company AS Company,
	|	DocumentsTable.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentsTable.Item AS Item,
	|	DocumentsTable.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN BankAccounts.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BankAccountPettyCashGLAccount,
	|	DocumentsTable.TaxKind AS TaxKind,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TaxTypes.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS TaxKindGLAccount,
	|	DocumentsTable.Department AS Department,
	|	DocumentsTable.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN LinesOfBusiness.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BusinessLineGLAccountCostOfSales,
	|	DocumentsTable.Order AS Order,
	|	DocumentsTable.Correspondence AS Correspondence,
	|	PrimaryChartOfAccounts.TypeOfAccount AS CorrespondenceTypeOfAccount,
	|	DocumentsTable.AdvanceHolder AS AdvanceHolder,
	|	Employees.SettlementsHumanResourcesGLAccount AS AdvanceHolderSettlementsHumanResourcesGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Employees.AdvanceHoldersGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvanceHolderAdvanceHoldersGLAccount,
	|	DocumentsTable.LoanContract AS LoanContract,
	|	DocumentsTable.Document AS Document,
	|	DocumentsTable.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN DocumentsTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.OtherSettlements)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccountingOtherSettlements,
	|	DocumentsTable.BankAccount AS BankAccount,
	|	DocumentsTable.Counterparty AS Counterparty,
	|	DocumentsTable.CounterpartyAccount AS CounterpartyAccount,
	|	CAST(DocumentsTable.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN ExchangeRateSliceLatest.ExchangeRate * ExchangeRateCashAccounts.Multiplicity / (ExchangeRateCashAccounts.ExchangeRate * ExchangeRateSliceLatest.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateCashAccounts.ExchangeRate * ExchangeRateSliceLatest.Multiplicity / (ExchangeRateSliceLatest.ExchangeRate * ExchangeRateCashAccounts.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount
	|INTO TemporaryTableHeader
	|FROM
	|	DocumentsTable AS DocumentsTable
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateSliceLatest
	|		ON (ExchangeRateSliceLatest.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateCashAccounts
	|		ON (ExchangeRateCashAccounts.Currency = &CashCurrency)
	|		LEFT JOIN Catalog.LinesOfBusiness AS LinesOfBusiness
	|		ON DocumentsTable.BusinessLine = LinesOfBusiness.Ref
	|		LEFT JOIN Catalog.Employees AS Employees
	|		ON DocumentsTable.AdvanceHolder = Employees.Ref
	|		LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|		ON DocumentsTable.BankAccount = BankAccounts.Ref
	|		LEFT JOIN Catalog.TaxTypes AS TaxTypes
	|		ON DocumentsTable.TaxKind = TaxTypes.Ref
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON DocumentsTable.Correspondence = PrimaryChartOfAccounts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentHeader.OperationKind AS OperationKind,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	Counterparties.DoOperationsByContracts AS DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentTable.Item AS Item,
	|	DocumentHeader.Item AS HeaderItem,
	|	DocumentHeader.ExpenseItem AS ExpenseItem,
	|	DocumentTable.DiscountReceivedIncomeItem AS DiscountReceivedIncomeItem,
	|	DocumentHeader.Correspondence AS Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|				AND DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Ref AS Ref,
	|	DocumentHeader.Date AS Date,
	|	SUM(CAST(DocumentTable.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.ExchangeRate * DocumentTable.PaymentMultiplier / (DocumentTable.PaymentExchangeRate * AccountingExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.PaymentExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * DocumentTable.PaymentMultiplier)
	|			END AS NUMBER(15, 2))) AS AccountingAmount,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	SUM(CAST(DocumentTable.EPDAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			END AS NUMBER(15, 2))) AS AccountingEPDAmount,
	|	SUM(DocumentTable.SettlementsEPDAmount) AS SettlementsEPDAmount,
	|	SUM(DocumentTable.EPDAmount) AS EPDAmount,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.ExpenditureRequest)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.ExpenditureRequest.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashTransferPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashTransferPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN DocumentTable.Order.SetPaymentTerms
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS QuoteToPaymentCalendar,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.BankAccount.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BankAccountCashGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CustomerAdvancesGLAccount,
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
	|			THEN DocumentTable.DiscountReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS DiscountReceivedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	DocumentHeader.LoanContract AS LoanContract,
	|	DocumentHeader.CounterpartyAccount AS CounterpartyAccount,
	|	DocumentTable.TypeOfAmount AS TypeOfAmount,
	|	DocumentHeader.AdvanceHolder AS Employee,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentHeader.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentHeader.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentHeader.LoanContract.CommissionGLAccount
	|	END AS GLAccountByTypeOfAmount,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN &CreditPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &CreditInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &CreditCommissionPayment
	|	END AS ContentByTypeOfAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CAST(DocumentTable.VATAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			END AS NUMBER(15, 2))) AS VATAmount,
	|	SUM(CAST(DocumentTable.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			END AS NUMBER(15, 2))) - SUM(CAST(DocumentTable.VATAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountingExchangeRates.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			END AS NUMBER(15, 2))) AS AmountExcludesVAT,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation
	|INTO TemporaryTablePaymentDetailsPre
	|FROM
	|	DocumentsTable AS DocumentHeader
	|		LEFT JOIN Document.PaymentExpense.PaymentDetails AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|		ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
	|
	|GROUP BY
	|	DocumentHeader.CashCurrency,
	|	DocumentTable.Document,
	|	DocumentHeader.OperationKind,
	|	DocumentHeader.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentHeader.BankAccount,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|				AND DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentHeader.ExpenseItem,
	|	DocumentTable.DiscountReceivedIncomeItem,
	|	DocumentHeader.Correspondence,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.ExpenditureRequest)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.ExpenditureRequest.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashTransferPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashTransferPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN DocumentTable.Order.SetPaymentTerms
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.BankAccount.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
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
	|	Counterparties.DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders,
	|	DocumentHeader.LoanContract,
	|	DocumentHeader.CounterpartyAccount,
	|	DocumentTable.TypeOfAmount,
	|	DocumentHeader.AdvanceHolder,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentHeader.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentHeader.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentHeader.LoanContract.CommissionGLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN &CreditPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &CreditInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &CreditCommissionPayment
	|	END,
	|	DocumentTable.VATRate,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Date,
	|	DocumentHeader.VATTaxation,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.DiscountReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.Item,
	|	DocumentHeader.Item,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTable.LineNumber AS LineNumber,
	|	TemporaryTable.CashCurrency AS CashCurrency,
	|	TemporaryTable.Document AS Document,
	|	TemporaryTable.OperationKind AS OperationKind,
	|	TemporaryTable.Counterparty AS Counterparty,
	|	TemporaryTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	TemporaryTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	TemporaryTable.Contract AS Contract,
	|	TemporaryTable.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTable.BankAccount AS BankAccount,
	|	TemporaryTable.Item AS Item,
	|	TemporaryTable.ExpenseItem AS ExpenseItem,
	|	TemporaryTable.DiscountReceivedIncomeItem AS DiscountReceivedIncomeItem,
	|	TemporaryTable.Correspondence AS Correspondence,
	|	TemporaryTable.Order AS Order,
	|	TemporaryTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN TemporaryTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTable.Ref AS Ref,
	|	TemporaryTable.Date AS Date,
	|	TemporaryTable.AccountingAmount AS AccountingAmount,
	|	TemporaryTable.SettlementsAmount AS SettlementsAmount,
	|	TemporaryTable.PaymentAmount AS PaymentAmount,
	|	TemporaryTable.AccountingEPDAmount AS AccountingEPDAmount,
	|	TemporaryTable.SettlementsEPDAmount AS SettlementsEPDAmount,
	|	TemporaryTable.EPDAmount AS EPDAmount,
	|	CAST(TemporaryTable.AccountingEPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS AccountingEPDAmountExclVAT,
	|	CAST(TemporaryTable.SettlementsEPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS SettlementsEPDAmountExclVAT,
	|	CAST(TemporaryTable.EPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS EPDAmountExclVAT,
	|	TemporaryTable.QuoteToPaymentCalendar AS QuoteToPaymentCalendar,
	|	TemporaryTable.BankAccountCashGLAccount AS BankAccountCashGLAccount,
	|	TemporaryTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	TemporaryTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	TemporaryTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	TemporaryTable.DiscountReceivedGLAccount AS DiscountReceivedGLAccount,
	|	TemporaryTable.VATInputGLAccount AS VATInputGLAccount,
	|	TemporaryTable.LoanContract AS LoanContract,
	|	TemporaryTable.CounterpartyAccount AS CounterpartyAccount,
	|	TemporaryTable.TypeOfAmount AS TypeOfAmount,
	|	TemporaryTable.Employee AS Employee,
	|	TemporaryTable.GLAccountByTypeOfAmount AS GLAccountByTypeOfAmount,
	|	TemporaryTable.ContentByTypeOfAmount AS ContentByTypeOfAmount,
	|	TemporaryTable.VATRate AS VATRate,
	|	TemporaryTable.VATAmount AS VATAmount,
	|	TemporaryTable.AmountExcludesVAT AS AmountExcludesVAT,
	|	TemporaryTable.Company AS Company,
	|	TemporaryTable.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTable.VATTaxation AS VATTaxation,
	|	TemporaryTable.HeaderItem AS HeaderItem
	|INTO TemporaryTablePaymentDetails
	|FROM
	|	TemporaryTablePaymentDetailsPre AS TemporaryTable
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON TemporaryTable.VATRate = VATRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Payment.Date AS Period,
	|	Payment.Company AS Company,
	|	Payment.CompanyVATNumber AS CompanyVATNumber,
	|	Payment.PresentationCurrency AS PresentationCurrency,
	|	Payment.Counterparty AS Supplier,
	|	Payment.Ref AS ShipmentDocument,
	|	Payment.VATRate AS VATRate,
	|	SUM(Payment.AmountExcludesVAT) AS AmountExcludesVAT,
	|	SUM(Payment.VATAmount) AS VATAmount,
	|	&VATInput AS VATInputGLAccount
	|INTO VAT
	|FROM
	|	TemporaryTablePaymentDetails AS Payment
	|WHERE
	|	NOT Payment.VATRate.NotTaxable
	|	AND Payment.AdvanceFlag
	|	AND Payment.VATAmount > 0
	|
	|GROUP BY
	|	Payment.Date,
	|	Payment.Company,
	|	Payment.CompanyVATNumber,
	|	Payment.PresentationCurrency,
	|	Payment.Counterparty,
	|	Payment.Ref,
	|	Payment.VATRate";
	
	Query.Execute();
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefPaymentExpense, StructureAdditionalProperties);
	
	// Register record table creation by account sections.
	// Bank charges
	GenerateTableBankCharges(DocumentRefPaymentExpense, StructureAdditionalProperties);
	// End Bank charges
	GenerateTableCashAssets(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableBankReconciliation(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateAdvanceHoldersTable(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableMiscellaneousPayable(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableLoanSettlements(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTablePayroll(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableTaxesSettlements(DocumentRefPaymentExpense, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.AccountingModuleSettings
		= Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefPaymentExpense, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableUnallocatedExpenses(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableVATIncurred(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRefPaymentExpense, StructureAdditionalProperties);
	GenerateTableVATOutput(DocumentRefPaymentExpense, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefPaymentExpense, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.AccountingModuleSettings
		= Enums.AccountingModuleSettingsTypes.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefPaymentExpense, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefPaymentExpense, StructureAdditionalProperties);
		
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefPaymentExpense, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPaymentExpense, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		AccumulationRegisters.CashAssets.IndependentCashAssetsRunControl(
			DocumentRefPaymentExpense,
			AdditionalProperties,
			Cancel,
			PostingDelete);
			
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
		Or StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange
		Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
		Or StructureTemporaryTables.RegisterRecordsVATIncurredChange
		Or StructureTemporaryTables.RegisterRecordsBankReconciliationChange 
		Or StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		Query = New Query;
		Query.Text = AccumulationRegisters.CashAssets.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + "
		|SELECT
		|	RegisterRecordsAdvanceHoldersChange.LineNumber AS LineNumber,
		|	RegisterRecordsAdvanceHoldersChange.Company AS CompanyPresentation,
		|	RegisterRecordsAdvanceHoldersChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsAdvanceHoldersChange.Employee AS EmployeePresentation,
		|	RegisterRecordsAdvanceHoldersChange.Currency AS CurrencyPresentation,
		|	RegisterRecordsAdvanceHoldersChange.Document AS DocumentPresentation,
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
		|		LEFT JOIN AccumulationRegister.AdvanceHolders.Balance(&ControlTime, ) AS AdvanceHoldersBalances
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
		|	RegisterRecordsSuppliersSettlementsChange.Company AS CompanyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract AS ContractPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Document AS DocumentPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Order AS OrderPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS CalculationsTypesPresentation,
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
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(&ControlTime, ) AS AccountsPayableBalances
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
		|	LineNumber";
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.BankReconciliation.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.AccountsReceivable.AdvanceBalancesControlQueryText();
		
		AccumulationRegisters.CashAssets.GenerateTableCashAssetsBalances(StructureTemporaryTables, AdditionalProperties);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Date", Common.ObjectAttributeValue(DocumentRefPaymentExpense,"PaymentDate"));
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[4].IsEmpty()
			Or Not ResultsArray[5].IsEmpty()
			Or Not ResultsArray[6].IsEmpty() Then
			DocumentObjectPaymentExpense = DocumentRefPaymentExpense.GetObject()
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToBankReconciliationRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in advance on accounts receivable.
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingReturnAdvanceToAccountsRegisterErrors(DocumentObjectPaymentExpense, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Header" Then
		
		IncomeAndExpenseStructure.Insert("BankFeeExpenseItem", StructureData.BankFeeExpenseItem);
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
		
	ElsIf StructureData.TabName = "PaymentDetails"
		And StructureData.ExistsEPD Then
		IncomeAndExpenseStructure.Insert("DiscountReceivedIncomeItem", StructureData.DiscountReceivedIncomeItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	
	If StructureData.TabName = "Header" 
		And StructureData.ObjectParameters.OperationKind = Enums.OperationTypesPaymentExpense.Other Then
		Result.Insert("Correspondence", "ExpenseItem");
	ElsIf StructureData.TabName = "PaymentDetails" Then
		Result.Insert("DiscountReceivedGLAccount", "DiscountReceivedIncomeItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.TabName = "PaymentDetails" Then
		
		If ObjectParameters.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
			GLAccountsForFilling.Insert("AccountsPayableGLAccount", StructureData.AccountsPayableGLAccount);
			GLAccountsForFilling.Insert("AdvancesPaidGLAccount", StructureData.AdvancesPaidGLAccount);
			
			If StructureData.Property("ExistsEPD")
				And StructureData.ExistsEPD <> Undefined
				And StructureData.ExistsEPD Then
				
				GLAccountsForFilling.Insert("DiscountReceivedGLAccount", StructureData.DiscountReceivedGLAccount);
				
				If StructureData.EPDAmount > 0
					And StructureData.Property("Document")
					And ValueIsFilled(StructureData.Document)
					And TypeOf(StructureData.Document) = Type("DocumentRef.SupplierInvoice") Then
					
					ProvideEPD = Common.ObjectAttributeValue(StructureData.Document, "ProvideEPD");
					If ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment Then
						GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
					EndIf;
				EndIf;
				
			EndIf;
			
		ElsIf ObjectParameters.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
			GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
			
		EndIf;
		
	ElsIf ObjectParameters.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
		
		GLAccountsForFilling.Insert("AccountsPayableGLAccount", ObjectParameters.Correspondence);
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region OtherSettlements

Procedure GenerateTableMiscellaneousPayable(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Miscellaneous payables'; ru = 'Оплата прочим контрагентам';pl = 'Różne zobowiązania';es_ES = 'Cuentas a pagar varias';es_CO = 'Cuentas a pagar varias';tr = 'Çeşitli borçlar';it = 'Debiti vari';de = 'Andere Verbindlichkeiten'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Comment",						NStr("en = 'Payment to other accounts'; ru = 'Увеличение долга контрагента';pl = 'Płatność na inne konta';es_ES = 'Pago a otras cuentas';es_CO = 'Pago a otras cuentas';tr = 'Diğer hesaplara ödeme';it = 'Pagamento ad altri conti';de = 'Zahlung an andere Konten'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Ref",							DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.Document = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TemporaryTablePaymentDetails.Document = VALUE(Document.PurchaseOrder.EmptyRef)
	|				OR TemporaryTablePaymentDetails.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE TemporaryTablePaymentDetails.Document
	|	END AS Document,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTableHeader.CashCurrency AS CashCurrency,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	&AccountingForOtherOperations AS PostingContent,
	|	&Comment AS Comment,
	|	TemporaryTableHeader.Correspondence AS GLAccount,
	|	TemporaryTableHeader.BankAccount AS BankAccount,
	|	TemporaryTablePaymentDetails.Date AS Period
	|INTO TemporaryTableOtherSettlements
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN TemporaryTableHeader AS TemporaryTableHeader
	|		ON (TemporaryTableHeader.AccountingOtherSettlements)
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.OtherSettlements)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTableHeader.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.Document = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TemporaryTablePaymentDetails.Document = VALUE(Document.PurchaseOrder.EmptyRef)
	|				OR TemporaryTablePaymentDetails.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE TemporaryTablePaymentDetails.Document
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	TemporaryTableHeader.Correspondence,
	|	TemporaryTableHeader.BankAccount,
	|	TemporaryTablePaymentDetails.Date";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableOtherSettlements.Company AS Company,
	|	TemporaryTableOtherSettlements.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableOtherSettlements.Counterparty AS Counterparty,
	|	TemporaryTableOtherSettlements.Contract AS Contract
	|FROM
	|	TemporaryTableOtherSettlements AS TemporaryTableOtherSettlements";
	
	QueryResult = Query.Execute();
	
	DataLock 			= New DataLock;
	LockItem 			= DataLock.Add("AccumulationRegister.MiscellaneousPayable");
	LockItem.Mode 		= DataLockMode.Exclusive;
	LockItem.DataSource	= QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	DataLock.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountingForOtherOperations(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableMiscellaneousPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableLoanSettlements(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", 						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("Ref",							DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'"));	
	Query.SetParameter("CashCurrency",					DocumentRefPaymentExpense.CashCurrency);
	Query.SetParameter("ExchangeRateMethod",            StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	If DocumentRefPaymentExpense.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
		Query.SetParameter("SettlementsOnLoans",			NStr("en = 'Loan to employee'; ru = 'Выдача займа сотруднику';pl = 'Pożyczka dla pracownika';es_ES = 'Préstamo al empleado';es_CO = 'Préstamo al empleado';tr = 'Çalışana kredi';it = 'Prestito al dipendente';de = 'Darlehen an Mitarbeiter'"));
	ElsIf DocumentRefPaymentExpense.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty Then
		Query.SetParameter("SettlementsOnLoans",			NStr("en = 'Loan to counterparty'; ru = 'Выдача займа контрагенту';pl = 'Pożyczka dla kontrahenta';es_ES = 'Préstamo a la contrapartida';es_CO = 'Préstamo a la contrapartida';tr = 'Cari hesaba kredi';it = 'Prestito alla controparte';de = 'Darlehen an Geschäftspartner'"));
	Else
		Query.SetParameter("SettlementsOnLoans",			"");
	EndIf;
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	CASE
	|		WHEN PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
	|			THEN VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|		WHEN PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty)
	|			THEN VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|	END AS LoanKind,
	|	PaymentExpense.Date AS Date,
	|	PaymentExpense.Date AS Period,
	|	&SettlementsOnLoans AS PostingContent,
	|	CASE
	|		WHEN PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
	|			THEN PaymentExpense.AdvanceHolder
	|		WHEN PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty)
	|			THEN PaymentExpense.Counterparty
	|	END AS Counterparty,
	|	PaymentExpense.DocumentAmount AS PaymentAmount,
	|	CAST(PaymentExpense.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtCur,
	|	CAST(PaymentExpense.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebt,
	|	CAST(PaymentExpense.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtCurForBalance,
	|	CAST(PaymentExpense.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtForBalance,
	|	0 AS InterestCur,
	|	0 AS Interest,
	|	0 AS InterestCurForBalance,
	|	0 AS InterestForBalance,
	|	0 AS CommissionCur,
	|	0 AS Commission,
	|	0 AS CommissionCurForBalance,
	|	0 AS CommissionForBalance,
	|	CAST(PaymentExpense.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(PaymentExpense.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	PaymentExpense.LoanContract AS LoanContract,
	|	PaymentExpense.LoanContract.SettlementsCurrency AS Currency,
	|	PaymentExpense.CashCurrency AS CashCurrency,
	|	PaymentExpense.LoanContract.GLAccount AS GLAccount,
	|	FALSE AS DeductedFromSalary,
	|	PaymentExpense.BankAccount AS BankAccount
	|INTO TemporaryTableLoanSettlements
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfAccount
	|		ON (ExchangeRateOfAccount.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|		ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfContract
	|		ON (ExchangeRateOfContract.Currency = PaymentExpense.LoanContract.SettlementsCurrency)
	|WHERE
	|	(PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
	|			OR PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty))
	|	AND PaymentExpense.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END,
	|	DocumentTable.Date,
	|	DocumentTable.Date,
	|	DocumentTable.ContentByTypeOfAmount,
	|	DocumentTable.Counterparty,
	|	DocumentTable.PaymentAmount,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.SettlementsAmount,
	|	DocumentTable.AccountingAmount,
	|	DocumentTable.LoanContract,
	|	DocumentTable.LoanContract.SettlementsCurrency,
	|	DocumentTable.CashCurrency,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.LoanContract.CommissionGLAccount
	|		ELSE 0
	|	END,
	|	FALSE,
	|	DocumentTable.BankAccount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements)";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableLoanSettlements.Company AS Company,
	|	TemporaryTableLoanSettlements.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableLoanSettlements.Counterparty AS Counterparty,
	|	TemporaryTableLoanSettlements.LoanContract AS LoanContract
	|FROM
	|	TemporaryTableLoanSettlements AS TemporaryTableLoanSettlements";
	
	QueryResult = Query.Execute();
	
	Block					= New DataLock;
	BlockItem				= Block.Add("AccumulationRegister.LoanSettlements");
	BlockItem.Mode			= DataLockMode.Exclusive;
	BlockItem.DataSource	= QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		BlockItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesLoanSettlements(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", ResultsArray[QueryNumber].Unload());
	
EndProcedure

#EndRegion

#Region BankCharges

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBankCharges(DocumentRefPaymentExpense, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",					DocumentRefPaymentExpense);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency",			DocumentRefPaymentExpense.CashCurrency);
	Query.SetParameter("BankCharge",			NStr("en = 'Bank fee'; ru = 'Банковская комиссия';pl = 'Prowizja bankowa';es_ES = 'Comisión del banco';es_CO = 'Comisión del banco';tr = 'Banka masrafı';it = 'Commissioni bancarie';de = 'Bankgebühr'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashCurrency AS Currency,
	|	DocumentTable.BankCharge AS BankCharge,
	|	DocumentTable.BankChargeItem AS Item,
	|	DocumentTable.BankFeeExpenseItem AS BankFeeExpenseItem,
	|	DocumentTable.FeeBusinessLine AS FeeBusinessLine,
	|	DocumentTable.FeeDepartment AS FeeDepartment,
	|	CASE
	|		WHEN DocumentTable.FeeOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.FeeOrder
	|	END AS FeeOrder,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.BankCharge.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.BankCharge.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	&BankCharge AS PostingContent,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase)
	|			THEN DocumentTable.BankChargeAmount
	|		ELSE CAST(DocumentTable.BankChargeAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN DocumentTable.BankChargeExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * DocumentTable.BankChargeMultiplier)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (DocumentTable.BankChargeExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * DocumentTable.BankChargeMultiplier))
	|				END AS NUMBER(15, 2))
	|	END AS Amount,
	|	DocumentTable.BankChargeAmount AS AmountCur
	|INTO TemporaryTableBankCharges
	|FROM
	|	Document.PaymentExpense AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRateSliceLast
	|		ON (AccountingExchangeRateSliceLast.Currency = &PresentationCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	Query.Execute();

	Query.Text = 
	"SELECT
	|	TemporaryTableBankCharges.Period,
	|	TemporaryTableBankCharges.Company,
	|	TemporaryTableBankCharges.BankAccount,
	|	TemporaryTableBankCharges.Currency,
	|	TemporaryTableBankCharges.BankCharge,
	|	TemporaryTableBankCharges.Item,
	|	TemporaryTableBankCharges.PostingContent,
	|	TemporaryTableBankCharges.Amount,
	|	TemporaryTableBankCharges.AmountCur
	|FROM
	|	TemporaryTableBankCharges AS TemporaryTableBankCharges
	|WHERE
	|	(TemporaryTableBankCharges.Amount <> 0
	|			OR TemporaryTableBankCharges.AmountCur <> 0)";
	
	QueryResult	= Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankCharges", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillPaymentDetailsInfobaseUpdate() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PaymentExpense.Ref AS Ref,
	|	PaymentExpense.CashCurrency AS BankAccountCashCurrency,
	|	PaymentExpense.Company.PresentationCurrency AS CompanyPresentationCurrency,
	|	PaymentExpense.Company.ExchangeRateMethod AS CompanyExchangeRateMethod,
	|	PaymentExpense.Counterparty.SettlementsCurrency AS CounterpartySettlementsCurrency
	|FROM
	|	Document.PaymentExpense AS PaymentExpense";
	
	QuerySelection = Query.Execute().Select();
	
	While QuerySelection.Next() Do
		
		Try
			
			DocumentObject = QuerySelection.Ref.GetObject();
			If DocumentObject = Undefined Then
				Continue;
			EndIf;
			
			PresentationCurrency = QuerySelection.CompanyPresentationCurrency;
			CurrencyRate = CurrencyRateOperations.GetCurrencyRate(DocumentObject.Date,
				QuerySelection.BankAccountCashCurrency,
				DocumentObject.Company);
				
			ExchangeRate = ?(CurrencyRate.Rate = 0, 1, CurrencyRate.Rate);
			Multiplier = ?(CurrencyRate.Repetition = 0, 1, CurrencyRate.Repetition);
			
			If Not ValueIsFilled(DocumentObject.BankChargeExchangeRate) Then
				DocumentObject.BankChargeExchangeRate = ExchangeRate;
			EndIf;
			
			If Not ValueIsFilled(DocumentObject.BankChargeMultiplier) Then
				DocumentObject.BankChargeMultiplier = Multiplier;
			EndIf;
			
			If Not ValueIsFilled(DocumentObject.ExchangeRate)
				Or DocumentObject.ExchangeRate = 1 Then
				DocumentObject.ExchangeRate = ExchangeRate;
			EndIf;
			
			If Not ValueIsFilled(DocumentObject.Multiplicity)
				Or DocumentObject.Multiplicity = 1 Then
				DocumentObject.Multiplicity = Multiplier;
			EndIf;
			
			If Not ValueIsFilled(DocumentObject.AccountingAmount) Then
				
				DocumentObject.AccountingAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					DocumentObject.DocumentAmount,
					QuerySelection.CompanyExchangeRateMethod,
					DocumentObject.ExchangeRate,
					1,
					DocumentObject.Multiplicity,
					1);
					
			EndIf;
			
			For Each PaymentDetailsRow In DocumentObject.PaymentDetails Do
				
				If ValueIsFilled(PaymentDetailsRow.Contract) Then
					SettlementsCurrency = Common.ObjectAttributeValue(PaymentDetailsRow.Contract, "SettlementsCurrency");
				Else
					SettlementsCurrency = QuerySelection.CounterpartySettlementsCurrency;
				EndIf;
				
				If Not ValueIsFilled(PaymentDetailsRow.SettlementsCurrency) Then
					PaymentDetailsRow.SettlementsCurrency = SettlementsCurrency;
				EndIf;
				
				If PaymentDetailsRow.SettlementsCurrency = DocumentObject.CashCurrency Then
					
					If ValueIsFilled(PaymentDetailsRow.ExchangeRate) Then
						PaymentDetailsRow.PaymentExchangeRate = PaymentDetailsRow.ExchangeRate;
					Else
						PaymentDetailsRow.PaymentExchangeRate = ExchangeRate;
					EndIf;
					
					If ValueIsFilled(PaymentDetailsRow.Multiplicity) Then
						PaymentDetailsRow.PaymentMultiplier = PaymentDetailsRow.Multiplicity;
					Else
						PaymentDetailsRow.PaymentMultiplier = Multiplier;
					EndIf;
					
				ElsIf DocumentObject.CashCurrency = PresentationCurrency Then
					
					PaymentDetailsRow.PaymentExchangeRate = 1;
					PaymentDetailsRow.PaymentMultiplier = 1;
					
				Else
					
					If Not ValueIsFilled(PaymentDetailsRow.PaymentExchangeRate) Then
						PaymentDetailsRow.PaymentExchangeRate = ExchangeRate;
					EndIf;
					
					If Not ValueIsFilled(PaymentDetailsRow.PaymentMultiplier) Then
						PaymentDetailsRow.PaymentMultiplier = Multiplier;
					EndIf;
					
				EndIf;
				
			EndDo;
			
			InfobaseUpdate.WriteObject(DocumentObject);
		
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles:%2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles:%2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				DocumentObject.Ref,
				DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocumentObject.Metadata(),
				DocumentObject.Ref,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure SetFeeBusinessLine() Export 
	
	DefaultBusinessLine = Catalogs.LinesOfBusiness.Other;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PaymentExpense.Ref AS Ref
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.FeeBusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef)";
	
	QuerySelection = Query.Execute().Select();
	
	While QuerySelection.Next() Do
		
		Try
			
			DocumentObject = QuerySelection.Ref.GetObject();
			If DocumentObject = Undefined Then
				Continue;
			EndIf;
			
			DocumentObject.FeeBusinessLine = DefaultBusinessLine;
			
			InfobaseUpdate.WriteObject(DocumentObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				DocumentObject.Ref,
				DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocumentObject.Metadata(),
				DocumentObject.Ref,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillInEmployeeGLAccounts() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PaymentExpense.Ref AS Ref
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToAdvanceHolder)
	|	AND (PaymentExpense.AdvanceHoldersReceivableGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			OR PaymentExpense.AdvanceHoldersPayableGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		DocObject.FillInEmployeeGLAccounts();
		
		BeginTransaction();
		
		Try
			
			InfobaseUpdate.WriteObject(DocObject);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot write document ""%1"". Details: %2'; ru = 'Не удается записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'No se ha podido guardar el documento ""%1"". Detalles: %2';es_CO = 'No se ha podido guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.PaymentExpense,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
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