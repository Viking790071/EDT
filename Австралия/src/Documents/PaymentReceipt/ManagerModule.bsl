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
Procedure GenerateTableCashAssets(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefPaymentReceipt);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashFundsReceipt",		NStr("en = 'Bank receipt'; ru = 'Поступление на счет';pl = 'Potwierdzenie zapłaty';es_ES = 'Recibo bancario';es_CO = 'Recibo bancario';tr = 'Banka tahsilatı';it = 'Ricevuta bancaria';de = 'Zahlungseingang'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&CashFundsReceipt AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic) AS PaymentMethod,
	|	VALUE(Enum.CashAssetTypes.Noncash) AS CashAssetType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.BankAccount AS BankAccountPettyCash,
	|	DocumentTable.BankAccountGLAccount AS GLAccount,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromAdvanceHolder)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Taxes)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Item,
	|	DocumentTable.BankAccount,
	|	DocumentTable.BankAccountGLAccount,
	|	DocumentTable.CashCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	&CashFundsReceipt,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic),
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount)
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PaymentFromThirdParties))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount,
	|	TemporaryTablePaymentDetails.CashCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	&CashFundsReceipt,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic),
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	TemporaryTablePaymentDetails.HeaderItem,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount)
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.OtherSettlements)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.HeaderItem,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount,
	|	TemporaryTablePaymentDetails.CashCurrency
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
	|	TableBankCharges.GLAccount,
	|	TableBankCharges.Currency,
	|	SUM(TableBankCharges.Amount),
	|	SUM(TableBankCharges.AmountCur),
	|	SUM(TableBankCharges.Amount),
	|	SUM(TableBankCharges.AmountCur)
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|WHERE
	|	(TableBankCharges.Amount <> 0
	|			OR TableBankCharges.AmountCur <> 0)
	|
	|GROUP BY
	|	TableBankCharges.PostingContent,
	|	TableBankCharges.Company,
	|	TableBankCharges.Period,
	|	TableBankCharges.Item,
	|	TableBankCharges.BankAccount,
	|	TableBankCharges.GLAccount,
	|	TableBankCharges.Currency,
	|	TableBankCharges.PresentationCurrency
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

Procedure GenerateTableBankReconciliation(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseBankReconciliation") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankReconciliation", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref",					DocumentRefPaymentReceipt);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Period,
	|	&Ref AS Transaction,
	|	DocumentTable.BankAccount AS BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Payment) AS TransactionType,
	|	SUM(DocumentTable.AmountCur) AS Amount
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromAdvanceHolder)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Taxes)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.BankAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.Date,
	|	&Ref,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Payment),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount)
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PaymentFromThirdParties))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.BankAccount
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
Procedure GenerateAdvanceHoldersTable(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefPaymentReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("RepaymentOfAdvanceHolderDebt",	NStr("en = 'Repayment of advance holder''s debt'; ru = 'Погашение долга подотчетника';pl = 'Spłata długu zaliczkobiorcy';es_ES = 'Pago de la deuda del titular de anticipo';es_CO = 'Pago de la deuda del titular de anticipo';tr = 'Bağlı kişinin borcunun geri ödemesi';it = 'Rimborso del debito della persona che ha anticipato';de = 'Rückzahlung der Schulden der abrechnungspflichtigen Person'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",		StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.AdvanceHolder AS Employee,
	|	DocumentTable.AdvanceHolderAdvanceHoldersGLAccount AS GLAccount,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance
	|INTO TemporaryTableAdvanceHolders
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromAdvanceHolder)
	|
	|GROUP BY
	|	DocumentTable.BankAccount,
	|	DocumentTable.Document,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.AdvanceHolderAdvanceHoldersGLAccount,
	|	DocumentTable.Date,
	|	DocumentTable.CashCurrency
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
	|	TemporaryTableAdvanceHolders";
	
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
Procedure GenerateTableCustomerAccounts(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",                           DocumentRefPaymentReceipt);
	Query.SetParameter("PointInTime",                   New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",                 StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",                       StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AppearenceOfCustomerAdvance",   NStr("en = 'Advance payment from customer'; ru = 'Аванс покупателя';pl = 'Zaliczka od nabywcy';es_ES = 'Pago anticipado del cliente';es_CO = 'Pago anticipado del cliente';tr = 'Müşteriden alınan avans ödeme';it = 'Pagamento anticipato da parte del cliente';de = 'Vorauszahlung vom Kunden'", MainLanguageCode));
	Query.SetParameter("CustomerObligationsRepayment",  NStr("en = 'Payment from customer'; ru = 'Оплата от покупателя';pl = 'Płatność od nabywcy';es_ES = 'Pago del cliente';es_CO = 'Pago del cliente';tr = 'Müşteriden ödeme';it = 'Pagamento dal cliente';de = 'Zahlung vom Kunden'", MainLanguageCode));
	Query.SetParameter("ThirdPartyPayment",             NStr("en = 'Payment from third-party'; ru = 'Сторонний платеж';pl = 'Płatność od strony trzeciej';es_ES = 'Pago de terceros';es_CO = 'Pago de terceros';tr = 'Üçüncü taraftan ödeme';it = 'Pagamento da terze parti';de = 'Zahlung von Dritten'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",          NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",            NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	FALSE AS IsEPD,
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &Ref
	|		ELSE TemporaryTablePaymentDetails.Document
	|	END AS Document,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.BankAccount AS BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	// begin Drive.FullVersion
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	// end Drive.FullVersion
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForPayment,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &Ref
	|		ELSE TemporaryTablePaymentDetails.Document
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	// begin Drive.FullVersion
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	// end Drive.FullVersion
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	FALSE,
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&ThirdPartyPayment,
	|	&Company AS Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.BankAccount AS BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.ThirdPartyPayerGLAccount,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	UNDEFINED,
	|	TemporaryTablePaymentDetails.Date,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount)
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PaymentFromThirdParties)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.ThirdPartyPayerGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&EarlyPaymentDiscount,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.Date,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	-SUM(TemporaryTablePaymentDetails.EPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount)
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
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
	
	// Setting the exclusive lock for the controlled balances of accounts receivable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable AS TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableThirdPartyPayments(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.Date AS Period,
	|	TemporaryTablePaymentDetails.Company AS Company,
	|	TemporaryTablePaymentDetails.ThirdPartyCustomer AS Counterparty,
	|	TemporaryTablePaymentDetails.ThirdPartyCustomerContract AS Contract,
	|	TemporaryTablePaymentDetails.Counterparty AS Payer,
	|	TemporaryTablePaymentDetails.Contract AS PayerContract,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS Amount
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PaymentFromThirdParties)
	|	AND TemporaryTablePaymentDetails.SettlementsAmount <> 0
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.ThirdPartyCustomerContract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Company,
	|	TemporaryTablePaymentDetails.ThirdPartyCustomer,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableThirdPartyPayments", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text = 
	"SELECT
	|	TemporaryTablePaymentDetails.Company AS Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	TemporaryTablePaymentDetails.Order AS Order,
	|	TemporaryTablePaymentDetails.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref"							, DocumentRefPaymentReceipt);
	Query.SetParameter("PointInTime"					, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod"					, StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company"						, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"			, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("VendorAdvanceRepayment"			, NStr("en = 'Reversal of advance payment clearing'; ru = 'Сторнирование зачета аванса поставщику';pl = 'Anulowanie rozliczenia zaliczki';es_ES = 'Inversión de la eliminación del pago adelantado';es_CO = 'Inversión de la eliminación del pago anticipado';tr = 'Avans ödeme mahsuplaştırılmasının geri dönmesi';it = 'Inversione di anticipo di pagamento, compensazione';de = 'Storno der Vorauszahlungsverrechnung'", MainLanguageCode));
	Query.SetParameter("AppearenceOfLiabilityToVendor"	, NStr("en = 'Accounts payable recognition'; ru = 'Возникновение обязательств перед поставщиком';pl = 'Zobowiązania przyjęte do ewidencji';es_ES = 'Reconocimiento de las cuentas por pagar';es_CO = 'Reconocimiento de las cuentas a pagar';tr = 'Borçlu hesapların doğrulanması';it = 'Riconoscimento di debiti';de = 'Aufnahme von Offenen Posten Kreditoren'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference"				, NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod"				, StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting"		, GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT DISTINCT
	|	TemporaryTablePaymentDetails.Company AS Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	TemporaryTablePaymentDetails.Order AS Order,
	|	TemporaryTablePaymentDetails.SettlementsType AS SettlementsType
	|INTO TemporaryTableAccountsPayableAdvances
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
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
	|INTO TemporaryTableAccountsPayableAdvancesBalances
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
	|		AccumulationRegister.AccountsPayable.Balance(
	|				&PointInTime,
	|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) IN
	|					(SELECT
	|						TemporaryTableAccountsPayableAdvances.Company,
	|						TemporaryTableAccountsPayableAdvances.PresentationCurrency,
	|						TemporaryTableAccountsPayableAdvances.Counterparty,
	|						TemporaryTableAccountsPayableAdvances.Contract,
	|						TemporaryTableAccountsPayableAdvances.Document,
	|						TemporaryTableAccountsPayableAdvances.Order,
	|						TemporaryTableAccountsPayableAdvances.SettlementsType
	|					FROM
	|						TemporaryTableAccountsPayableAdvances)) AS TableBalances
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
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecords
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
	|	&VendorAdvanceRepayment AS ContentOfAccountingRecord,
	|	TemporaryTablePaymentDetails.Company AS Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTablePaymentDetails.BankAccount AS BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.VendorAdvancesGLAccount AS GLAccount,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	TemporaryTablePaymentDetails.SettlementsType AS SettlementsType,
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
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		LEFT JOIN TemporaryTableAccountsPayableAdvancesBalances AS AdvancesBalances
	|		ON TemporaryTablePaymentDetails.Company = AdvancesBalances.Company
	|			AND TemporaryTablePaymentDetails.PresentationCurrency = AdvancesBalances.PresentationCurrency
	|			AND TemporaryTablePaymentDetails.Counterparty = AdvancesBalances.Counterparty
	|			AND TemporaryTablePaymentDetails.Contract = AdvancesBalances.Contract
	|			AND TemporaryTablePaymentDetails.Document = AdvancesBalances.Document
	|			AND TemporaryTablePaymentDetails.Order = AdvancesBalances.Order
	|			AND TemporaryTablePaymentDetails.SettlementsType = AdvancesBalances.SettlementsType
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
	|	AND TemporaryTablePaymentDetails.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&AppearenceOfLiabilityToVendor,
	|	TemporaryTablePaymentDetails.Company,
	|	TemporaryTablePaymentDetails.PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.BankAccount,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.SettlementsType,
	|	TemporaryTablePaymentDetails.PaymentAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
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
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 							DocumentRefPaymentReceipt);
	Query.SetParameter("Company", 						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime", 					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeReflection",				NStr("en = 'Record income'; ru = 'Отражение доходов';pl = 'Rejestr przychodów';es_ES = 'Registrar los ingresos';es_CO = 'Registrar los ingresos';tr = 'Gelirlerin kaydı';it = 'Registrazione fatturato';de = 'Gebuchte Einnahme'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	DocumentTable.IncomeItem AS IncomeAndExpenseItem,
	|	DocumentTable.Correspondence AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.RegisterIncome
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase))
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
	|	6,
	|	1,
	|	TableBankCharges.Period,
	|	TableBankCharges.Company,
	|	TableBankCharges.PresentationCurrency,
	|	TableBankCharges.FeeDepartment,
	|	TableBankCharges.FeeOrder,
	|	TableBankCharges.FeeBusinessLine,
	|	TableBankCharges.BankFeeExpenseItem,
	|	TableBankCharges.GLExpenseAccount,
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
	|	7,
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
	|	TemporaryTableExchangeRateDifferencesLoanSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	SalesInvoice.Department,
	|	CASE
	|		WHEN DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.Order
	|	END,
	|	UNDEFINED,
	|	DocumentTable.DiscountAllowedExpenseItem,
	|	DocumentTable.DiscountAllowedGLAccount,
	|	&EarlyPaymentDiscount,
	|	0,
	|	SUM(CASE
	|			WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN DocumentTable.AccountingEPDAmountExclVAT
	|			ELSE DocumentTable.AccountingEPDAmount
	|		END),
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON DocumentTable.Document = SalesInvoice.Ref
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|	AND DocumentTable.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	SalesInvoice.Department,
	|	DocumentTable.Order,
	|	DocumentTable.DiscountAllowedExpenseItem,
	|	DocumentTable.DiscountAllowedGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.FeeDepartment,
	|	UNDEFINED,
	|	DocumentTable.FeeBusinessLine,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.FeeExpensesGLAccount,
	|	DocumentTable.ContentPaymentProcessorFee,
	|	0,
	|	DocumentTable.FeeTotalPC,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
	|	AND DocumentTable.WithholdFeeOnPayout
	|	AND DocumentTable.FeeTotalPC <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	11,
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
	|	TemporaryTableExchangeRateDifferencesFundsTransfersBeingProcessed AS DocumentTable
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
Procedure GenerateTableAccountingJournalEntries(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefPaymentReceipt);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Content",						NStr("en = 'Other income'; ru = 'Оприходование денежных средств с произвольного счета';pl = 'Inne przychody';es_ES = 'Otros ingresos';es_CO = 'Otros ingresos';tr = 'Diğer gelir';it = 'Altre entrate';de = 'Sonstige Einnahmen'", MainLanguageCode));
	Query.SetParameter("TaxReturn",						NStr("en = 'Tax refund'; ru = 'Возврат налога';pl = 'Zwrot podatku';es_ES = 'Devolución de impuestos';es_CO = 'Devolución de impuestos';tr = 'Vergi iadesi';it = 'Rimborso fiscale';de = 'Steuererstattung'", MainLanguageCode));
	Query.SetParameter("ContentCurrencyPurchase",		NStr("en = 'Foreign exchange purchase'; ru = 'Покупка валюты';pl = 'Zakup waluty obcej';es_ES = 'Compra del cambio extranjero';es_CO = 'Compra del cambio extranjero';tr = 'Döviz satın alımı';it = 'Acquisto valuta estera';de = 'Kauf von Devisen'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ContentVATOnAdvance",			NStr("en = 'VAT on advance'; ru = 'НДС с авансов';pl = 'VAT z zaliczek';es_ES = 'IVA del anticipo';es_CO = 'IVA del anticipo';tr = 'Avans KDV''si';it = 'IVA sull''anticipo';de = 'USt. auf Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ContentVAT",					NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("ContentPayout",					NStr("en = 'Payout from payment processor'; ru = 'Выплата платежной системы';pl = 'Wypłata od systemu płatności';es_ES = 'Pago desde el procesador de pagos';es_CO = 'Pago desde el procesador de pagos';tr = 'Ödeme işlemcisinden gelen ödeme';it = 'Pagamento da elaboratore pagamenti';de = 'Auszahlung vom Zahlungsanbieter'", MainLanguageCode));
	Query.SetParameter("ContentComissionWithhold",		NStr("en = 'Commission deducted'; ru = 'Комиссия удержана';pl = 'Potrącono prowizję';es_ES = 'Comisión deducida';es_CO = 'Comisión deducida';tr = 'Komisyon düşülür';it = 'Commissione dedotta';de = 'Provisionszahlung abgezogen'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("VATAdvancesFromCustomers",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesFromCustomers"));
	Query.SetParameter("VATOutput",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Query.SetParameter("RegisteredForVAT",				StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.BankAccountGLAccount AS AccountDr,
	|	DocumentTable.Correspondence AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CAST(CASE
	|			WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase)
	|				THEN &ContentCurrencyPurchase
	|			ELSE &Content
	|		END AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankAccountGLAccount,
	|	DocumentTable.TaxKindGLAccountForReimbursement,
	|	CASE
	|		WHEN DocumentTable.BankAccountGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.TaxKindGLAccountForReimbursement.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccountGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TaxKindGLAccountForReimbursement.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&TaxReturn AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Taxes)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankAccount.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
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
	|	DocumentTable.BankAccount.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAccountsReceivable AS DocumentTable
	|WHERE
	|	NOT DocumentTable.isEPD
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
	|	DocumentTable.BankAccount.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAccountsPayable AS DocumentTable
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
	|	11,
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
	|	15,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankAccount.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
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
	|	TemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	16,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankAccount.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
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
	|	TemporaryTableLoanSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	17,
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
	|	18,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesFromCustomers,
	|	&VATOutput,
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
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|	AND &PostAdvancePaymentsBySourceDocuments
	|	AND DocumentTable.AdvanceFlag
	|	AND &RegisteredForVAT
	|	AND DocumentTable.VATAmount <> 0
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	19,
	|	1,
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TemporaryTablePaymentDetails.DiscountAllowedGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DiscountAllowedGLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.DiscountAllowedGLAccount.Currency
	|				THEN CASE
	|						WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.EPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.EPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|				THEN CASE
	|						WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.SettlementsEPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT
	|			ELSE TemporaryTablePaymentDetails.AccountingEPDAmount
	|		END),
	|	&EarlyPaymentDiscount,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.DiscountAllowedGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DiscountAllowedGLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	20,
	|	1,
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TemporaryTablePaymentDetails.VATOutputGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	UNDEFINED,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|				THEN TemporaryTablePaymentDetails.SettlementsEPDAmount - TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|			ELSE 0
	|		END),
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount - TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT),
	|	&ContentVAT,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|			AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.VATOutputGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	21,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankAccountGLAccount,
	|	DocumentTable.FundsTransfersBeingProcessedGLAccount,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FundsTransfersBeingProcessedGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BankAccount.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.FundsTransfersBeingProcessedGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&ContentPayout,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
	|
	|UNION ALL
	|
	|SELECT
	|	22,
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
	|	TemporaryTableExchangeRateDifferencesFundsTransfersBeingProcessed AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	23,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.FeeExpensesGLAccount,
	|	DocumentTable.FeeProcessorDebtGLAccount,
	|	CASE
	|		WHEN DocumentTable.FeeExpensesGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FeeProcessorDebtGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FeeExpensesGLAccount.Currency
	|			THEN DocumentTable.FeeTotal
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.FeeProcessorDebtGLAccount.Currency
	|			THEN DocumentTable.FeeTotal
	|		ELSE 0
	|	END,
	|	DocumentTable.FeeTotalPC,
	|	DocumentTable.ContentPaymentProcessorFee,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
	|	AND DocumentTable.WithholdFeeOnPayout
	|
	|UNION ALL
	|
	|SELECT
	|	24,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.FeeProcessorDebtGLAccount,
	|	DocumentTable.FundsTransfersBeingProcessedGLAccount,
	|	CASE
	|		WHEN DocumentTable.FeeProcessorDebtGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FundsTransfersBeingProcessedGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FeeProcessorDebtGLAccount.Currency
	|			THEN DocumentTable.FeeTotal
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.FundsTransfersBeingProcessedGLAccount.Currency
	|			THEN DocumentTable.FeeTotal
	|		ELSE 0
	|	END,
	|	DocumentTable.FeeTotalPC,
	|	&ContentComissionWithhold,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
	|	AND DocumentTable.WithholdFeeOnPayout
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",									DocumentRefPaymentReceipt);
	Query.SetParameter("Company",								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",					StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime",							New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.AccountingAmount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
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
	|	Table.AmountIncome,
	|	0
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountIncome > 0
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	0,
	|	-DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
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
	|	-Table.AmountExpense
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountExpense > 0
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref"                                    , DocumentRefPaymentReceipt);
	Query.SetParameter("Company"                                , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"                   , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod"  , StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
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
	|	DocumentTable.AccountingAmount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
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
	|	0,
	|	-DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref"                                    , DocumentRefPaymentReceipt);
	Query.SetParameter("Company"                                , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"                   , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod"  , StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period"                                 , StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|	AND NOT DocumentTable.AdvanceFlag
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
	LockItem.UseFromDataSource("Company" , "Company");
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
	|	SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
	|	-SUM(IncomeAndExpensesRetainedBalances.AmountExpenseBalance) AS AmountExpenseBalance
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
	|					AND Document IN
	|						(SELECT
	|							DocumentTable.Document
	|						FROM
	|							TemporaryTablePaymentDetails AS DocumentTable
	|						WHERE
	|							(DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|								OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)))) AS IncomeAndExpensesRetainedBalances
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
	|	IncomeAndExpensesRetainedBalances.Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine,
	|	IncomeAndExpensesRetainedBalances.PresentationCurrency
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
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
	|	Table.AmountIncome AS AmountIncome,
	|	-Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableTaxesSettlements(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Company"              , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency" , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime"          , New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("TaxReturn"            , NStr("en = 'Tax return'; ru = 'Возврат налога';pl = 'Zwrot podatku';es_ES = 'Devolución de impuestos';es_CO = 'Devolución de impuestos';tr = 'Vergi iadesi';it = 'Rimborso fiscale';de = 'Steuerrückerstattungen'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod"   , StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.TaxKind AS TaxKind,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentTable.DocumentAmount * DocumentTable.ExchangeRate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * DocumentTable.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN DocumentTable.DocumentAmount / (DocumentTable.ExchangeRate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * DocumentTable.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.TaxKind.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CAST(&TaxReturn AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementsExchangeRate
	|		ON DocumentTable.CashCurrency = SettlementsExchangeRate.Currency
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Taxes)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref"                    , DocumentRefPaymentReceipt);
	Query.SetParameter("Company"                , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"   , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UsePaymentCalendar"     , Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT DISTINCT
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Date AS Period
	|INTO SalesInvoiceTable
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON DocumentTable.Document = SalesInvoice.Ref
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivable.AmountCur AS AmountCur,
	|	AccountsReceivable.Document AS Document
	|INTO PaymentsAmountsDocument
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON AccountsReceivable.Document = SalesInvoiceTable.Document
	|WHERE
	|	AccountsReceivable.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND AccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|	AND AccountsReceivable.Recorder <> AccountsReceivable.Document
	|	AND AccountsReceivable.Recorder <> &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.Document
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoiceTable.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(PaymentsAmountsDocument.AmountCur) AS AmountCur,
	|	PaymentsAmountsDocument.Document AS Document
	|INTO PaymentsAmounts
	|FROM
	|	PaymentsAmountsDocument AS PaymentsAmountsDocument
	|
	|GROUP BY
	|	PaymentsAmountsDocument.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Company AS Company,
	|	PaymentCalendar.PresentationCurrency AS PresentationCurrency,
	|	PaymentCalendar.Currency AS Currency,
	|	PaymentCalendar.Item AS Item,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod,
	|	PaymentCalendar.BankAccountPettyCash AS BankAccountPettyCash,
	|	PaymentCalendar.Quote AS Quote,
	|	PaymentCalendar.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	SUM(PaymentCalendar.Amount) AS Amount,
	|	SalesInvoiceTable.Document AS Document,
	|	SalesInvoiceTable.Period AS Period
	|INTO SalesInvoicePaymentCalendar
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendar
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON PaymentCalendar.Recorder = SalesInvoiceTable.Document
	|
	|GROUP BY
	|	PaymentCalendar.PaymentMethod,
	|	PaymentCalendar.Currency,
	|	PaymentCalendar.Item,
	|	PaymentCalendar.Company,
	|	PaymentCalendar.PresentationCurrency,
	|	PaymentCalendar.BankAccountPettyCash,
	|	PaymentCalendar.PaymentConfirmationStatus,
	|	PaymentCalendar.Quote,
	|	SalesInvoiceTable.Document,
	|	SalesInvoiceTable.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoicePaymentCalendar.Company AS Company,
	|	SalesInvoicePaymentCalendar.PresentationCurrency AS PresentationCurrency,
	|	SalesInvoicePaymentCalendar.Currency AS Currency,
	|	SalesInvoicePaymentCalendar.Item AS Item,
	|	SalesInvoicePaymentCalendar.PaymentMethod AS PaymentMethod,
	|	SalesInvoicePaymentCalendar.BankAccountPettyCash AS BankAccountPettyCash,
	|	SalesInvoicePaymentCalendar.Quote AS Quote,
	|	SalesInvoicePaymentCalendar.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	ISNULL(PaymentsAmounts.AmountCur, 0) - SalesInvoicePaymentCalendar.Amount AS Amount,
	|	SalesInvoicePaymentCalendar.Document AS Document,
	|	SalesInvoicePaymentCalendar.Period AS Period
	|INTO Tabular
	|FROM
	|	SalesInvoicePaymentCalendar AS SalesInvoicePaymentCalendar
	|		LEFT JOIN PaymentsAmounts AS PaymentsAmounts
	|		ON SalesInvoicePaymentCalendar.Document = PaymentsAmounts.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
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
	|			THEN SUM(DocumentTable.PaymentAmount)
	|		ELSE SUM(DocumentTable.SettlementsAmount)
	|	END AS PaymentAmount,
	|	0 AS Amount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.BankAccount,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.QuoteToPaymentCalendar,
	|	DocumentTable.Item
	|
	|UNION ALL
	|
	|SELECT
	|	2,
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
	|	DocumentTable.DocumentAmount,
	|	0
	|FROM
	|	Document.PaymentReceipt AS DocumentTable
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
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	Tabular.Period,
	|	Tabular.Company,
	|	Tabular.PresentationCurrency,
	|	Tabular.Item,
	|	Tabular.PaymentMethod,
	|	Tabular.PaymentConfirmationStatus,
	|	Tabular.BankAccountPettyCash,
	|	Tabular.Currency,
	|	Tabular.Quote,
	|	0,
	|	Tabular.Amount
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.Amount < 0
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
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
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
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
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef))
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor))
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

Procedure GenerateTableVATOutput(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		AND DocumentRefPaymentReceipt.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
		
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
		|	SUM(Payment.AmountExcludesVAT) AS AmountExcludesVAT,
		|	SUM(Payment.VATAmount) AS VATAmount
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
		|	Payment.PresentationCurrency
		|
		|UNION ALL
		|
		|SELECT
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.CompanyVATNumber,
		|	Payment.PresentationCurrency,
		|	Payment.Counterparty,
		|	SalesInvoice.Ref,
		|	Payment.VATRate,
		|	Payment.VATOutputGLAccount,
		|	VALUE(Enum.VATOperationTypes.DiscountAllowed),
		|	VALUE(Enum.ProductsTypes.EmptyRef),
		|	-SUM(Payment.AccountingEPDAmountExclVAT),
		|	-SUM(Payment.AccountingEPDAmount - Payment.AccountingEPDAmountExclVAT)
		|FROM
		|	TemporaryTablePaymentDetails AS Payment
		|		INNER JOIN Document.SalesInvoice AS SalesInvoice
		|		ON Payment.Document = SalesInvoice.Ref
		|			AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
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
		|	Payment.Counterparty,
		|	SalesInvoice.Ref,
		|	Payment.VATRate,
		|	Payment.VATOutputGLAccount,
		|	Payment.PresentationCurrency";
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		
	EndIf;
	
EndProcedure

Procedure GenerateTableFundsTransfersBeingProcessed(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",					DocumentRef);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("FundsTransfersBeingProcessedGLAccount",
		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FundsTransfersBeingProcessed"));
	
	Query.Text =
	"SELECT
	|	PayoutDetails.LineNumber AS LineNumber,
	|	PayoutDetails.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	PayoutDetails.PresentationCurrency AS PresentationCurrency,
	|	PayoutDetails.PaymentProcessor AS PaymentProcessor,
	|	PayoutDetails.PaymentProcessorContract AS PaymentProcessorContract,
	|	PayoutDetails.POSTerminal AS POSTerminal,
	|	PayoutDetails.Currency AS Currency,
	|	PayoutDetails.Document AS Document,
	|	PayoutDetails.AmountCur AS AmountCur,
	|	PayoutDetails.Amount AS Amount,
	|	-PayoutDetails.AmountCur AS AmountCurForBalance,
	|	-PayoutDetails.Amount AS AmountForBalance,
	|	PayoutDetails.FeeAmount AS FeeAmount
	|INTO TemporaryTableFundsTransfersBeingProcessed
	|FROM
	|	TemporaryTablePayoutDetails AS PayoutDetails
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentTable.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	&Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.PaymentProcessor,
	|	DocumentTable.PaymentProcessorContract,
	|	DocumentTable.POSTerminal,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	DocumentTable.DocumentAmount,
	|	DocumentTable.Amount,
	|	-DocumentTable.DocumentAmount,
	|	-DocumentTable.Amount,
	|	0
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
	|	AND NOT DocumentTable.WithholdFeeOnPayout";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableFundsTransfersBeingProcessed.Company AS Company,
	|	TemporaryTableFundsTransfersBeingProcessed.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableFundsTransfersBeingProcessed.PaymentProcessor AS PaymentProcessor,
	|	TemporaryTableFundsTransfersBeingProcessed.PaymentProcessorContract AS PaymentProcessorContract,
	|	TemporaryTableFundsTransfersBeingProcessed.POSTerminal AS POSTerminal,
	|	TemporaryTableFundsTransfersBeingProcessed.Currency AS Currency,
	|	TemporaryTableFundsTransfersBeingProcessed.Document AS Document
	|FROM
	|	TemporaryTableFundsTransfersBeingProcessed AS TemporaryTableFundsTransfersBeingProcessed";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.FundsTransfersBeingProcessed");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesFundsTransfersBeingProcessed(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFundsTransfersBeingProcessed", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPaymentReceipt, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref"                   , DocumentRefPaymentReceipt);
	Query.SetParameter("PointInTime"           , New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company"               , StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("PresentationCurrency"  , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency"          , DocumentRefPaymentReceipt.CashCurrency);
	Query.SetParameter("LoanContractCurrency"  , DocumentRefPaymentReceipt.LoanContract.SettlementsCurrency);
	Query.SetParameter("ExchangeRateMethod"    , StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	Query.SetParameter("FundsTransfersBeingProcessedGLAccount",
		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FundsTransfersBeingProcessed"));
	Query.SetParameter("FeeExpensesGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses"));
	Query.SetParameter("FeeProcessorDebtGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable"));
	
	Query.SetParameter("FundsTransfersBeingProcessedGLAccount",
		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FundsTransfersBeingProcessed"));
	Query.SetParameter("FeeExpensesGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses"));
	Query.SetParameter("FeeProcessorDebtGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable"));
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("LoanPrincipalDebtPayment",		NStr("en = 'Loan principal debt payment'; ru = 'Оплата основного долга по займу';pl = 'Opłata głównego długu z racji pożyczki';es_ES = 'Pago de la deuda principal del préstamo';es_CO = 'Pago de la deuda principal del préstamo';tr = 'Borç anapara borç ödeme';it = 'Pagamento debito principale';de = 'Zahlung der Darlehenshauptschuld'",	MainLanguageCode));
	Query.SetParameter("LoanInterestPayment",			NStr("en = 'Loan interest payment'; ru = 'Оплата процентов по займу';pl = 'Opłata odsetek od pożyczki';es_ES = 'Pago del interés del préstamo';es_CO = 'Pago del interés del préstamo';tr = 'Borç faiz ödemesi';it = 'Pagamento degli interessi del prestito';de = 'Darlehenszinszahlung'",		MainLanguageCode));
	Query.SetParameter("LoanCommissionPayment",			NStr("en = 'Loan Commission payment'; ru = 'Оплата комиссии по кредиту';pl = 'Opłata prowizji od pożyczki';es_ES = 'Pago de la comisión del préstamo';es_CO = 'Pago de la comisión del préstamo';tr = 'Borç komisyon ödemesi';it = 'Pagamento della commisione del prestito';de = 'Zahlung der Darlehensprovision'",		MainLanguageCode));
	Query.SetParameter("ContentPaymentProcessorFee",	NStr("en = 'Payment processor fee'; ru = 'Комиссия платежной системы';pl = 'Prowizja systemu płatności';es_ES = 'Tasa del procesador de pagos';es_CO = 'Tasa del procesador de pagos';tr = 'Ödeme işlemcisi ücreti';it = 'Commissione elaboratore pagamenti';de = 'Gebühr des Zahlungsanbieters'",		MainLanguageCode));
	
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
	|	DocumentTable.OperationKind AS OperationKind,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashCurrency AS CashCurrency,
	|	DocumentTable.AccountingAmount AS AccountingAmount,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.BankFeeExpenseItem AS BankFeeExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS Correspondence,
	|	DocumentTable.RegisterIncome AS RegisterIncome,
	|	DocumentTable.IncomeItem AS IncomeItem,
	|	DocumentTable.ExpenseItem AS ExpenseItem,
	|	DocumentTable.TaxKind AS TaxKind,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.AdvanceHolder AS AdvanceHolder,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref AS Ref,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.FeeTotal AS FeeTotal,
	|	DocumentTable.POSTerminal AS POSTerminal,
	|	DocumentTable.ExchangeRate AS ExchangeRate,
	|	DocumentTable.Multiplicity AS Multiplicity
	|INTO TemporaryTableHeaderPre
	|FROM
	|	Document.PaymentReceipt AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayoutDetails.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&PresentationCurrency AS PresentationCurrency,
	|	POSTerminals.PaymentProcessor AS PaymentProcessor,
	|	POSTerminals.PaymentProcessorContract AS PaymentProcessorContract,
	|	DocumentTable.POSTerminal AS POSTerminal,
	|	DocumentTable.CashCurrency AS Currency,
	|	PayoutDetails.Document AS Document,
	|	CASE
	|		WHEN PayoutDetails.Document REFS Document.OnlinePayment
	|			THEN -PayoutDetails.RefundAmount
	|		ELSE PayoutDetails.Amount
	|	END AS AmountCur,
	|	CAST(CASE
	|			WHEN PayoutDetails.Document REFS Document.OnlinePayment
	|				THEN -PayoutDetails.RefundAmount
	|			ELSE PayoutDetails.Amount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN BankAcountExchangeRate.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CASE
	|		WHEN PayoutDetails.Document REFS Document.OnlinePayment
	|			THEN PayoutDetails.RefundFeeAmount
	|		ELSE PayoutDetails.FeeAmount
	|	END AS FeeAmount,
	|	CAST(CASE
	|			WHEN PayoutDetails.Document REFS Document.OnlinePayment
	|				THEN PayoutDetails.RefundFeeAmount
	|			ELSE PayoutDetails.FeeAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN BankAcountExchangeRate.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|		END AS NUMBER(15, 2)) AS FeeAmountPC
	|INTO TemporaryTablePayoutDetails
	|FROM
	|	TemporaryTableHeaderPre AS DocumentTable
	|		LEFT JOIN Document.PaymentReceipt.PaymentProcessorPayoutDetails AS PayoutDetails
	|		ON DocumentTable.Ref = PayoutDetails.Ref
	|		LEFT JOIN Catalog.POSTerminals AS POSTerminals
	|		ON DocumentTable.POSTerminal = POSTerminals.Ref
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRateSliceLast
	|		ON (AccountingExchangeRateSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS BankAcountExchangeRate
	|		ON (BankAcountExchangeRate.Currency = &CashCurrency)
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
	|	AND POSTerminals.WithholdFeeOnPayout
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(PayoutDetails.Amount - PayoutDetails.FeeAmountPC) AS Amount,
	|	SUM(PayoutDetails.FeeAmountPC) AS FeeAmountPC
	|INTO PayoutDetailsTotals
	|FROM
	|	TemporaryTablePayoutDetails AS PayoutDetails
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.OperationKind AS OperationKind,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	DocumentTable.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashCurrency AS CashCurrency,
	|	DocumentTable.BankFeeExpenseItem AS BankFeeExpenseItem,
	|	ISNULL(PayoutDetailsTotals.Amount, CASE
	|			WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase)
	|				THEN DocumentTable.AccountingAmount
	|			ELSE CAST(DocumentTable.DocumentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * DocumentTable.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentTable.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * DocumentTable.Multiplicity))
	|					END AS NUMBER(15, 2))
	|		END) AS Amount,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.DocumentAmount AS AmountCur,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(BankAccounts.GLAccount, VALUE(Catalog.BankAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BankAccountGLAccount,
	|	DocumentTable.Correspondence AS Correspondence,
	|	DocumentTable.RegisterIncome AS RegisterIncome,
	|	DocumentTable.IncomeItem AS IncomeItem,
	|	DocumentTable.ExpenseItem AS ExpenseItem,
	|	ISNULL(IncomeAndExpenseItems.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)) AS IncomeAndExpenseType,
	|	DocumentTable.TaxKind AS TaxKind,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(TaxTypes.GLAccountForReimbursement, VALUE(Catalog.TaxTypes.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS TaxKindGLAccountForReimbursement,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.AdvanceHolder AS AdvanceHolder,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(Employees.AdvanceHoldersGLAccount, VALUE(Catalog.Employees.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvanceHolderAdvanceHoldersGLAccount,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref AS Ref,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.Counterparty AS Counterparty,
	|	&FundsTransfersBeingProcessedGLAccount AS FundsTransfersBeingProcessedGLAccount,
	|	&FeeExpensesGLAccount AS FeeExpensesGLAccount,
	|	&FeeProcessorDebtGLAccount AS FeeProcessorDebtGLAccount,
	|	DocumentTable.FeeTotal AS FeeTotal,
	|	ISNULL(PayoutDetailsTotals.FeeAmountPC, CAST(DocumentTable.FeeTotal * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN BankAcountExchangeRate.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) AS FeeTotalPC,
	|	DocumentTable.POSTerminal AS POSTerminal,
	|	POSTerminals.WithholdFeeOnPayout AS WithholdFeeOnPayout,
	|	POSTerminals.PaymentProcessor AS PaymentProcessor,
	|	POSTerminals.PaymentProcessorContract AS PaymentProcessorContract,
	|	POSTerminals.BusinessLine AS FeeBusinessLine,
	|	POSTerminals.Department AS FeeDepartment,
	|	&ContentPaymentProcessorFee AS ContentPaymentProcessorFee,
	|	DocumentTable.AccountingAmount AS AccountingAmount,
	|	DocumentTable.ExchangeRate AS ExchangeRate,
	|	DocumentTable.Multiplicity AS Multiplicity
	|INTO TemporaryTableHeader
	|FROM
	|	TemporaryTableHeaderPre AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRateSliceLast
	|		ON (AccountingExchangeRateSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS BankAcountExchangeRate
	|		ON (BankAcountExchangeRate.Currency = &CashCurrency)
	|		LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|		ON DocumentTable.BankAccount = BankAccounts.Ref
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON DocumentTable.IncomeItem = IncomeAndExpenseItems.Ref
	|		LEFT JOIN Catalog.TaxTypes AS TaxTypes
	|		ON DocumentTable.TaxKind = TaxTypes.Ref
	|		LEFT JOIN Catalog.Employees AS Employees
	|		ON DocumentTable.AdvanceHolder = Employees.Ref
	|		LEFT JOIN Catalog.POSTerminals AS POSTerminals
	|		ON DocumentTable.POSTerminal = POSTerminals.Ref
	|		LEFT JOIN PayoutDetailsTotals AS PayoutDetailsTotals
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	TemporaryTableHeader.CashCurrency AS CashCurrency,
	|	DocumentTable.Document AS Document,
	|	TemporaryTableHeader.OperationKind AS OperationKind,
	|	TemporaryTableHeader.Counterparty AS Counterparty,
	|	Counterparties.DoOperationsByContracts AS DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders AS DoOperationsByOrders,
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
	|			THEN DocumentTable.DiscountAllowedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS DiscountAllowedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.ThirdPartyPayerGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ThirdPartyPayerGLAccount,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DiscountAllowedExpenseItem AS DiscountAllowedExpenseItem,
	|	DocumentTable.ThirdPartyCustomer AS ThirdPartyCustomer,
	|	DocumentTable.ThirdPartyCustomerContract AS ThirdPartyCustomerContract,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableHeader.BankAccount AS BankAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TemporaryTableHeader.BankAccount.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BankAccountCashGLAccount,
	|	CASE
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN LoanContractDoc.PrincipalItem
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN LoanContractDoc.InterestItem
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN LoanContractDoc.CommissionItem
	|		ELSE DocumentTable.Item
	|	END AS Item,
	|	TemporaryTableHeader.Item AS HeaderItem,
	|	TemporaryTableHeader.Correspondence AS Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN (DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef))
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
	|			THEN UNDEFINED
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	TemporaryTableHeader.Date AS Date,
	|	DocumentTable.Ref AS Ref,
	|	SUM(CASE
	|			WHEN TemporaryTableHeader.CashCurrency = &PresentationCurrency
	|				THEN DocumentTable.PaymentAmount
	|			ELSE CAST(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.PaymentAmount * DocumentTable.PaymentExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * DocumentTable.PaymentMultiplier)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.PaymentAmount / (DocumentTable.PaymentExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * DocumentTable.PaymentMultiplier))
	|					END AS NUMBER(15, 2))
	|		END) AS AccountingAmount,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.EPDAmount * DocumentTable.PaymentExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * DocumentTable.PaymentMultiplier)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.EPDAmount / (DocumentTable.PaymentExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * DocumentTable.PaymentMultiplier))
	|			END AS NUMBER(15, 2))) AS AccountingEPDAmount,
	|	SUM(DocumentTable.SettlementsEPDAmount) AS SettlementsEPDAmount,
	|	SUM(DocumentTable.EPDAmount) AS EPDAmount,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashInflowForecast)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashInflowForecast.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashTransferPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashTransferPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN DocumentTable.Order.SetPaymentTerms
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS QuoteToPaymentCalendar,
	|	TemporaryTableHeader.LoanContract AS LoanContract,
	|	DocumentTable.TypeOfAmount AS TypeOfAmount,
	|	TemporaryTableHeader.AdvanceHolder AS Employee,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN TemporaryTableHeader.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN TemporaryTableHeader.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN TemporaryTableHeader.LoanContract.CommissionGLAccount
	|	END AS GLAccountByTypeOfAmount,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN &LoanPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &LoanInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &LoanCommissionPayment
	|	END AS ContentByTypeOfAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.VATAmount * BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.VATAmount / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) AS VATAmount,
	|	SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.PaymentAmount * BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.PaymentAmount / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) - SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.VATAmount * BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.VATAmount / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) AS AmountExcludesVAT,
	|	TemporaryTableHeader.Company AS Company,
	|	TemporaryTableHeader.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTableHeader.PresentationCurrency AS PresentationCurrency
	|INTO TemporaryTablePaymentDetailsPre
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.PaymentReceipt.PaymentDetails AS DocumentTable
	|			LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRate
	|			ON (AccountingExchangeRate.Currency = &PresentationCurrency)
	|			LEFT JOIN TemporaryTableExchangeRateSliceLatest AS BankAcountExchangeRate
	|			ON (BankAcountExchangeRate.Currency = &CashCurrency)
	|			LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|			ON DocumentTable.Contract = CounterpartyContracts.Ref
	|		ON TemporaryTableHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON TemporaryTableHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Document.LoanContract AS LoanContractDoc
	|		ON TemporaryTableHeader.LoanContract = LoanContractDoc.Ref
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Contract,
	|	DocumentTable.ThirdPartyCustomer,
	|	DocumentTable.ThirdPartyCustomerContract,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref,
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
	|	DocumentTable.TypeOfAmount,
	|	DocumentTable.DiscountAllowedExpenseItem,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN &LoanPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &LoanInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &LoanCommissionPayment
	|	END,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashInflowForecast)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashInflowForecast.EmptyRef)
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
	|			THEN DocumentTable.DiscountAllowedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.ThirdPartyPayerGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	TemporaryTableHeader.CashCurrency,
	|	TemporaryTableHeader.OperationKind,
	|	TemporaryTableHeader.Counterparty,
	|	TemporaryTableHeader.BankAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TemporaryTableHeader.BankAccount.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	TemporaryTableHeader.Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN (DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef))
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
	|			THEN UNDEFINED
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	TemporaryTableHeader.Date,
	|	TemporaryTableHeader.LoanContract,
	|	TemporaryTableHeader.AdvanceHolder,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN TemporaryTableHeader.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN TemporaryTableHeader.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN TemporaryTableHeader.LoanContract.CommissionGLAccount
	|	END,
	|	TemporaryTableHeader.Company,
	|	TemporaryTableHeader.CompanyVATNumber,
	|	TemporaryTableHeader.PresentationCurrency,
	|	CounterpartyContracts.SettlementsCurrency,
	|	Counterparties.DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders,
	|	CASE
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN LoanContractDoc.PrincipalItem
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN LoanContractDoc.InterestItem
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN LoanContractDoc.CommissionItem
	|		ELSE DocumentTable.Item
	|	END,
	|	TemporaryTableHeader.Item
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTable.Company AS Company,
	|	TemporaryTable.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTable.LineNumber AS LineNumber,
	|	TemporaryTable.CashCurrency AS CashCurrency,
	|	TemporaryTable.Document AS Document,
	|	TemporaryTable.OperationKind AS OperationKind,
	|	TemporaryTable.Counterparty AS Counterparty,
	|	TemporaryTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	TemporaryTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	TemporaryTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	TemporaryTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	TemporaryTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	TemporaryTable.DiscountAllowedGLAccount AS DiscountAllowedGLAccount,
	|	TemporaryTable.VATOutputGLAccount AS VATOutputGLAccount,
	|	TemporaryTable.ThirdPartyPayerGLAccount AS ThirdPartyPayerGLAccount,
	|	TemporaryTable.Contract AS Contract,
	|	TemporaryTable.ThirdPartyCustomer AS ThirdPartyCustomer,
	|	TemporaryTable.ThirdPartyCustomerContract AS ThirdPartyCustomerContract,
	|	TemporaryTable.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTable.BankAccount AS BankAccount,
	|	TemporaryTable.BankAccountCashGLAccount AS BankAccountCashGLAccount,
	|	TemporaryTable.Item AS Item,
	|	TemporaryTable.Correspondence AS Correspondence,
	|	TemporaryTable.DiscountAllowedExpenseItem AS DiscountAllowedExpenseItem,
	|	TemporaryTable.Order AS Order,
	|	TemporaryTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN TemporaryTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTable.Date AS Date,
	|	TemporaryTable.Ref AS Ref,
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
	|	TemporaryTable.LoanContract AS LoanContract,
	|	TemporaryTable.TypeOfAmount AS TypeOfAmount,
	|	TemporaryTable.Employee AS Employee,
	|	TemporaryTable.GLAccountByTypeOfAmount AS GLAccountByTypeOfAmount,
	|	TemporaryTable.ContentByTypeOfAmount AS ContentByTypeOfAmount,
	|	TemporaryTable.VATRate AS VATRate,
	|	TemporaryTable.VATAmount AS VATAmount,
	|	TemporaryTable.AmountExcludesVAT AS AmountExcludesVAT,
	|	TemporaryTable.HeaderItem AS HeaderItem
	|INTO TemporaryTablePaymentDetails
	|FROM
	|	TemporaryTablePaymentDetailsPre AS TemporaryTable
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON TemporaryTable.VATRate = VATRates.Ref";
	
	Query.Execute();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	
	// Register record table creation by account sections.
	// Bank charges
	GenerateTableBankCharges(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	// End Bank charges
	GenerateTableCashAssets(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableFundsTransfersBeingProcessed(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableBankReconciliation(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateAdvanceHoldersTable(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableThirdPartyPayments(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableMiscellaneousPayable(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableLoanSettlements(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableTaxesSettlements(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	
	GenerateTableVATOutput(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefPaymentReceipt, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefPaymentReceipt, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefPaymentReceipt, StructureAdditionalProperties);
		
	EndIf;

EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPaymentReceipt, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange
		Or StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
		Or StructureTemporaryTables.RegisterRecordsBankReconciliationChange
		Or StructureTemporaryTables.RegisterRecordsFundsTransfersBeingProcessedChange
		Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
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
		|	(VALUETYPE(AdvanceHoldersBalances.Document) = Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) > 0
		|			OR VALUETYPE(AdvanceHoldersBalances.Document) <> Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	RegisterRecordsAccountsReceivableChange.Company AS CompanyPresentation,
		|	RegisterRecordsAccountsReceivableChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract AS ContractPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Document AS DocumentPresentation,
		|	RegisterRecordsAccountsReceivableChange.Order AS OrderPresentation,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS CalculationsTypesPresentation,
		|	TRUE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.PresentationCurrency = AccountsReceivableBalances.PresentationCurrency
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.BankReconciliation.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.FundsTransfersBeingProcessed.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.AccountsPayable.AdvanceBalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[4].IsEmpty() Then
			DocumentObjectPaymentReceipt = DocumentRefPaymentReceipt.GetObject()
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectPaymentReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectPaymentReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToBankReconciliationRegisterErrors(DocumentObjectPaymentReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on FundsTransfersBeingProcessed
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToFundsTransfersBeingProcessed(DocumentObjectPaymentReceipt,
				QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in advance on accounts payable.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingReturnAdvanceToAccountsRegisterErrors(DocumentObjectPaymentReceipt, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Header" Then
		
		IncomeAndExpenseStructure.Insert("BankFeeExpenseItem", StructureData.BankFeeExpenseItem);
		IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
		
	ElsIf StructureData.TabName = "PaymentDetails"
		And StructureData.ExistsEPD Then
		IncomeAndExpenseStructure.Insert("DiscountAllowedExpenseItem", StructureData.DiscountAllowedExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	
	If StructureData.TabName = "Header" 
		And StructureData.ObjectParameters.OperationKind = Enums.OperationTypesPaymentReceipt.Other Then
		Result.Insert("Correspondence", "IncomeItem");
	ElsIf StructureData.TabName = "PaymentDetails" Then
		Result.Insert("DiscountAllowedGLAccount", "DiscountAllowedExpenseItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.TabName = "PaymentDetails" Then
		
		If ObjectParameters.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
			GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
			
			If StructureData.Property("ExistsEPD")
				And StructureData.ExistsEPD <> Undefined
				And StructureData.ExistsEPD Then
				
				GLAccountsForFilling.Insert("DiscountAllowedGLAccount", StructureData.DiscountAllowedGLAccount);
				
				If StructureData.EPDAmount > 0
					And StructureData.Property("Document")
					And ValueIsFilled(StructureData.Document)
					And TypeOf(StructureData.Document) = Type("DocumentRef.SalesInvoice") Then
					
					ProvideEPD = Common.ObjectAttributeValue(StructureData.Document, "ProvideEPD");
					If ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment Then
						GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
					EndIf;
				EndIf;
				
			EndIf;
			
		ElsIf ObjectParameters.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
			GLAccountsForFilling.Insert("AccountsPayableGLAccount", StructureData.AccountsPayableGLAccount);
			GLAccountsForFilling.Insert("AdvancesPaidGLAccount", StructureData.AdvancesPaidGLAccount);
		ElsIf ObjectParameters.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties Then
			GLAccountsForFilling.Insert("ThirdPartyPayerGLAccount", StructureData.ThirdPartyPayerGLAccount);
		EndIf;
		
	ElsIf ObjectParameters.OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
		GLAccountsForFilling.Insert("AccountsReceivableGLAccount", ObjectParameters.Correspondence);
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	Var Errors;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "AdvancePaymentInvoice") Then
		
		BankReceiptArray	= New Array;
		TaxInvoiceArray		= New Array;
		
		For Each PrintObject In ObjectsArray Do
			
			If NOT WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(PrintObject.Date, PrintObject.Company) Then
				
				TaxInvoice = Documents.TaxInvoiceIssued.GetTaxInvoiceIssued(PrintObject);
				If ValueIsFilled(TaxInvoice) Then
					
					TaxInvoiceArray.Add(TaxInvoice);
					
				Else
					
					PrintManagement.OutputSpreadsheetDocumentToCollection(
						PrintFormsCollection,
						"AdvancePaymentInvoice",
						NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago anticipado';es_CO = 'Factura del pago anticipado';tr = 'Avans ödeme faturası';it = 'Fattura pagamento di anticipo';de = 'Vorauszahlung Zahlung Rechnung'"), 
						New SpreadsheetDocument);
						
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Generate an ""Advance payment invoice"" based on the %1 before printing.'; ru = 'Создать ""Инвойс на аванс"" на основании %1 перед печатью';pl = 'Wygeneruj ""Fakturę zaliczkową"" na podstawie %1 przed wydrukiem.';es_ES = 'Generar un ""Informe de pago anticipado"" basado en el %1 antes de imprimir.';es_CO = 'Generar un ""Informe de pago anticipado"" basado en el %1 antes de imprimir.';tr = 'Yazdırmadan önce %1 temel alan bir ""Ön ödeme faturası"" oluşturun.';it = 'Generare una ""Fattura di pagamento di anticipo"" basata su %1 prima della stampa.';de = 'Eine ""Vorauszahlungsrechnung"" auf Basis des %1 vor dem Druck generieren.'"),
						PrintObject);
					
					CommonClientServer.AddUserError(Errors,, MessageText, Undefined);
					
					Continue;
					
				EndIf;
				
			Else
				
				BankReceiptArray.Add(PrintObject);
				
			EndIf;
			
		EndDo;
		
		If BankReceiptArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
				BankReceiptArray,
				PrintObjects, 
				"AdvancePaymentInvoice",, PrintParameters.Result);
			
		EndIf;
		
		If TaxInvoiceArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
				TaxInvoiceArray,
				PrintObjects, 
				"AdvancePaymentInvoice",
				SpreadsheetDocument, PrintParameters.Result);
			
		EndIf;
		
		If BankReceiptArray.Count() > 0 OR TaxInvoiceArray.Count() > 0 Then
			
			PrintManagement.OutputSpreadsheetDocumentToCollection(
				PrintFormsCollection,
				"AdvancePaymentInvoice",
				NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago anticipado';es_CO = 'Factura del pago anticipado';tr = 'Avans ödeme faturası';it = 'Fattura pagamento di anticipo';de = 'Vorauszahlung Zahlung Rechnung'"),
				SpreadsheetDocument);
			
		EndIf;
		
	EndIf;
	
	If Errors <> Undefined Then
		CommonClientServer.ReportErrorsToUser(Errors);
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
	PrintCommand.ID							= "AdvancePaymentInvoice";
	PrintCommand.Presentation				= NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago anticipado';es_CO = 'Factura del pago anticipado';tr = 'Avans ödeme faturası';it = 'Fattura pagamento di anticipo';de = 'Vorauszahlung Zahlung Rechnung'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
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

Procedure GenerateTableMiscellaneousPayable(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company"						, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"			, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AccountingForOtherOperations"	, NStr("en = 'Miscellaneous receivables'; ru = 'Поступление от прочих контрагентов';pl = 'Różne należności';es_ES = 'Cuentas a cobrar varias';es_CO = 'Cuentas a cobrar varias';tr = 'Çeşitli alacaklar';it = 'Crediti vari';de = 'Übrige Forderungen'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Comment"						, NStr("en = 'Payment from other accounts'; ru = 'Уменьшение долга контрагента';pl = 'Płatność z innych kont';es_ES = 'Pago de otras cuentas';es_CO = 'Pago de otras cuentas';tr = 'Diğer hesaplardan ödeme';it = 'Pagamento ad altri conti';de = 'Zahlung von anderen Konten'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Ref"							, DocumentRefPaymentReceipt);
	Query.SetParameter("PointInTime"					, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod"					, StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference"			, NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("ExchangeRateMethod"				, StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting"		, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|		ON (TRUE)
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.OtherSettlements)
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

Procedure GenerateTableLoanSettlements(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company"					, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"		, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("LoanSettlements"			, NStr("en = 'Credit payment receipt'; ru = 'Поступление по кредиту';pl = 'Wpływ płatności z racji kredytu';es_ES = 'Recibo del pago de crédito';es_CO = 'Recibo del pago de crédito';tr = 'Kredi ödeme tutarı';it = 'Ricevimento di pagamento di credito';de = 'Kredit-Zahlungsbeleg'"));
	Query.SetParameter("Ref"						, DocumentRefPaymentReceipt);
	Query.SetParameter("PointInTime"				, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod"				, StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference"		, NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'"));	
	Query.SetParameter("CashCurrency"				, DocumentRefPaymentReceipt.CashCurrency);
	Query.SetParameter("ExchangeRateMethod"			, StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting"	, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	CASE
	|		WHEN PaymentReceipt.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanSettlements)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END AS LoanKind,
	|	PaymentReceipt.Date AS Date,
	|	PaymentReceipt.Date AS Period,
	|	&LoanSettlements AS PostingContent,
	|	PaymentReceipt.Counterparty AS Counterparty,
	|	PaymentReceipt.DocumentAmount AS PaymentAmount,
	|	CAST(PaymentReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtCur,
	|	CAST(PaymentReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebt,
	|	CAST(PaymentReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtCurForBalance,
	|	CAST(PaymentReceipt.DocumentAmount * CASE
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
	|	CAST(PaymentReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(PaymentReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	PaymentReceipt.LoanContract AS LoanContract,
	|	PaymentReceipt.LoanContract.SettlementsCurrency AS Currency,
	|	PaymentReceipt.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PaymentReceipt.LoanContract.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	PaymentReceipt.BankAccount AS BankAccount,
	|	FALSE AS DeductedFromSalary
	|INTO TemporaryTableLoanSettlements
	|FROM
	|	Document.PaymentReceipt AS PaymentReceipt
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfAccount
	|		ON (ExchangeRateOfAccount.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|		ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfContract
	|		ON (ExchangeRateOfContract.Currency = PaymentReceipt.LoanContract.SettlementsCurrency)
	|WHERE
	|	PaymentReceipt.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanSettlements)
	|	AND PaymentReceipt.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense),
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanSettlements)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty)
	|			THEN VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END,
	|	DocumentTable.Date,
	|	DocumentTable.Date,
	|	DocumentTable.ContentByTypeOfAmount,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty)
	|			THEN DocumentTable.Counterparty
	|		ELSE DocumentTable.Employee
	|	END,
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
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.GLAccountByTypeOfAmount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.BankAccount,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty))";
	
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
	BlockItem 				= Block.Add("AccumulationRegister.LoanSettlements");
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
Procedure GenerateTableBankCharges(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",					DocumentRefPaymentReceipt);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency",			DocumentRefPaymentReceipt.CashCurrency);
	Query.SetParameter("BankCharge",			NStr("en = 'Bank fee'; ru = 'Банковская комиссия';pl = 'Prowizja bankowa';es_ES = 'Comisión del banco';es_CO = 'Comisión del banco';tr = 'Banka masrafı';it = 'Commissioni bancarie';de = 'Bankgebühr'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
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
	|	CAST(DocumentTable.BankChargeAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentTable.BankChargeExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * DocumentTable.BankChargeMultiplier)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DocumentTable.BankChargeExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * DocumentTable.BankChargeMultiplier))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	DocumentTable.BankChargeAmount AS AmountCur
	|INTO TemporaryTableBankCharges
	|FROM
	|	Document.PaymentReceipt AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRateSliceLast
	|		ON (AccountingExchangeRateSliceLast.Currency = &PresentationCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	Query.Execute();

	Query.Text = 
	"SELECT
	|	TemporaryTableBankCharges.Period AS Period,
	|	TemporaryTableBankCharges.Company AS Company,
	|	TemporaryTableBankCharges.BankAccount AS BankAccount,
	|	TemporaryTableBankCharges.Currency AS Currency,
	|	TemporaryTableBankCharges.BankCharge AS BankCharge,
	|	TemporaryTableBankCharges.Item AS Item,
	|	TemporaryTableBankCharges.PostingContent AS PostingContent,
	|	TemporaryTableBankCharges.Amount AS Amount,
	|	TemporaryTableBankCharges.AmountCur AS AmountCur
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
	|	PaymentReceipt.Ref AS Ref,
	|	PaymentReceipt.CashCurrency AS BankAccountCashCurrency,
	|	PaymentReceipt.Company.PresentationCurrency AS CompanyPresentationCurrency,
	|	PaymentReceipt.Company.ExchangeRateMethod AS CompanyExchangeRateMethod,
	|	PaymentReceipt.Counterparty.SettlementsCurrency AS CounterpartySettlementsCurrency
	|FROM
	|	Document.PaymentReceipt AS PaymentReceipt";
	
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
				Or Not DocumentObject.OperationKind = Enums.OperationTypesPaymentReceipt.CurrencyPurchase
				Or DocumentObject.ExchangeRate = 1 Then
				DocumentObject.ExchangeRate = ExchangeRate;
			EndIf;
			
			If Not ValueIsFilled(DocumentObject.Multiplicity)
				Or Not DocumentObject.OperationKind = Enums.OperationTypesPaymentReceipt.CurrencyPurchase
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

Procedure SetFeeBusinessLine() Export 
	
	DefaultBusinessLine = Catalogs.LinesOfBusiness.Other;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PaymentReceipt.Ref AS Ref
	|FROM
	|	Document.PaymentReceipt AS PaymentReceipt
	|WHERE
	|	PaymentReceipt.FeeBusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef)";
	
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
