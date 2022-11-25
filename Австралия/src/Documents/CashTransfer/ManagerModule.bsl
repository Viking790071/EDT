#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssets(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",					DocumentRef);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashTransfering",		NStr("en = 'Cash transfer'; ru = 'Перемещение денежных средств';pl = 'Przelew gotówkowy';es_ES = 'Transferencia de efectivo';es_CO = 'Transferencia de efectivo';tr = 'Nakit transferi';it = 'Trasferimento di denaro';de = 'Überweisung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	CAST(&CashTransfering AS STRING(100)) AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.PaymentMethod AS PaymentMethod,
	|	DocumentTable.CashAssetType AS CashAssetType,
	|	DocumentTable.Item AS Item,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		ELSE DocumentTable.BankAccount
	|	END AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition))
	|			END AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.DocumentAmount) AS AmountCur,
	|	-SUM(CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition))
	|			END AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(DocumentTable.DocumentAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash.GLAccount
	|		ELSE DocumentTable.BankAccount.GLAccount
	|	END AS GLAccount
	|INTO TemporaryTableCashAssets
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfPettyCashe
	|		ON DocumentTable.CashCurrency = ExchangeRateOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Item,
	|	DocumentTable.CashCurrency,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		ELSE DocumentTable.BankAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash.GLAccount
	|		ELSE DocumentTable.BankAccount.GLAccount
	|	END,
	|	DocumentTable.PaymentMethod,
	|	DocumentTable.CashAssetType
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	CAST(&CashTransfering AS STRING(100)),
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.PaymentMethodPayee,
	|	DocumentTable.CashAssetTypePayee,
	|	DocumentTable.Item,
	|	CASE
	|		WHEN DocumentTable.CashAssetTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee
	|		ELSE DocumentTable.BankAccountPayee
	|	END,
	|	DocumentTable.CashCurrency,
	|	SUM(CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition))
	|			END AS NUMBER(15, 2))),
	|	SUM(DocumentTable.DocumentAmount),
	|	SUM(CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition))
	|			END AS NUMBER(15, 2))),
	|	SUM(DocumentTable.DocumentAmount),
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee.GLAccount
	|		ELSE DocumentTable.BankAccountPayee.GLAccount
	|	END
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfPettyCashe
	|		ON DocumentTable.CashCurrency = ExchangeRateOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Item,
	|	DocumentTable.CashCurrency,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee.GLAccount
	|		ELSE DocumentTable.BankAccountPayee.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashAssetTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee
	|		ELSE DocumentTable.BankAccountPayee
	|	END,
	|	DocumentTable.PaymentMethodPayee,
	|	DocumentTable.CashAssetTypePayee
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

Procedure GenerateTableBankReconciliation(DocumentRef, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseBankReconciliation") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankReconciliation", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", DocumentRef);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTableCashAssets.Date AS Period,
	|	&Ref AS Transaction,
	|	TemporaryTableCashAssets.BankAccountPettyCash AS BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Payment) AS TransactionType,
	|	CASE
	|		WHEN TemporaryTableCashAssets.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -TemporaryTableCashAssets.AmountCur
	|		ELSE TemporaryTableCashAssets.AmountCur
	|	END AS Amount
	|FROM
	|	TemporaryTableCashAssets AS TemporaryTableCashAssets
	|WHERE
	|	TemporaryTableCashAssets.PaymentMethod = VALUE(Catalog.PaymentMethods.Electronic)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankReconciliation", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",				Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Cash flow projection table formation procedure.
//
// Parameters:
//  DocumentRef - DocumentRef.CashInflowForecast - Current document 
//  AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UsePaymentCalendar", Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.PaymentMethod AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	DocumentTable.BasisDocument AS Quote,
	|	-DocumentTable.DocumentAmount AS PaymentAmount
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Item,
	|	DocumentTable.PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	CASE
	|		WHEN DocumentTable.CashAssetTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee
	|		WHEN DocumentTable.CashAssetTypePayee = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccountPayee
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.BasisDocument,
	|	DocumentTable.DocumentAmount
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRef);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Content",						NStr("en = 'Cash transfer'; ru = 'Списание денежных средств на произвольный счет';pl = 'Przelew gotówkowy';es_ES = 'Transferencia de efectivo';es_CO = 'Transferencia de efectivo';tr = 'Nakit transferi';it = 'Trasferimento di denaro';de = 'Überweisung'", MainLanguageCode));
	Query.SetParameter("TaxPay",						NStr("en = 'Tax payment'; ru = 'Оплата налога';pl = 'Zapłata podatku';es_ES = 'Pago de impuestos';es_CO = 'Pago de impuestos';tr = 'Vergi ödemesi';it = 'Pagamento tassa';de = 'Steuerzahlung'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.CashAssetTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee.GLAccount
	|		ELSE DocumentTable.BankAccountPayee.GLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash.GLAccount
	|		ELSE DocumentTable.BankAccount.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CashAssetTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN CASE
	|					WHEN DocumentTable.PettyCashPayee.GLAccount.Currency
	|						THEN DocumentTable.CashCurrency
	|					ELSE UNDEFINED
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.BankAccountPayee.GLAccount.Currency
	|					THEN DocumentTable.CashCurrency
	|				ELSE UNDEFINED
	|			END
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN CASE
	|					WHEN DocumentTable.PettyCash.GLAccount.Currency
	|						THEN DocumentTable.CashCurrency
	|					ELSE UNDEFINED
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.BankAccount.GLAccount.Currency
	|					THEN DocumentTable.CashCurrency
	|				ELSE UNDEFINED
	|			END
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CashAssetTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN CASE
	|					WHEN DocumentTable.PettyCashPayee.GLAccount.Currency
	|						THEN DocumentTable.DocumentAmount
	|					ELSE 0
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.BankAccountPayee.GLAccount.Currency
	|					THEN DocumentTable.DocumentAmount
	|				ELSE 0
	|			END
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN CASE
	|					WHEN DocumentTable.PettyCash.GLAccount.Currency
	|						THEN DocumentTable.DocumentAmount
	|					ELSE 0
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.BankAccount.GLAccount.Currency
	|					THEN DocumentTable.DocumentAmount
	|				ELSE 0
	|			END
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.DocumentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN SettlementsExchangeRate.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * SettlementsExchangeRate.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (SettlementsExchangeRate.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * SettlementsExchangeRate.Repetition))
	|			END AS NUMBER(15, 2)) AS Amount,
	|	CAST(&Content AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementsExchangeRate
	|		ON DocumentTable.CashCurrency = SettlementsExchangeRate.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
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
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#Region Public

// Creates a document data table.
//
// Parameters:
//  DocumentRef - DocumentRef.CashInflowForecast - Current document
//  StructureAdditionalProperties - AdditionalProperties - Additional properties of the document
//	
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	GenerateTableCashAssets(DocumentRef, StructureAdditionalProperties);
	GenerateTableBankReconciliation(DocumentRef, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		AccumulationRegisters.CashAssets.IndependentCashAssetsRunControl(
			DocumentRef,
			AdditionalProperties,
			Cancel,
			PostingDelete);
			
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
		Or StructureTemporaryTables.RegisterRecordsBankReconciliationChange Then
		
		Query = New Query;
		Query.Text = AccumulationRegisters.CashAssets.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.BankReconciliation.BalancesControlQueryText();
		
		AccumulationRegisters.CashAssets.GenerateTableCashAssetsBalances(StructureTemporaryTables, AdditionalProperties);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Date", AdditionalProperties.ForPosting.Date);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty() Then
			DocumentObjectCashVoucher = DocumentRef.GetObject();
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToBankReconciliationRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

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