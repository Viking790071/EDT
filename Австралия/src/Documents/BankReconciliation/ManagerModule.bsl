#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",						DocumentRef);
	Query.SetParameter("PointInTime",				New Boundary(AdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",					AdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod",		AdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("PresentationCurrency",		AdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseDefaultTypeOfAccounting",	GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	BankReconciliation.Ref AS Ref,
	|	BankReconciliation.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	BankReconciliation.BankAccount AS BankAccount,
	|	BankReconciliation.UseServiceCharge AS UseServiceCharge,
	|	BankReconciliation.ServiceChargeType AS ServiceChargeType,
	|	BankReconciliation.ServiceChargeCashFlowItem AS ServiceChargeCashFlowItem,
	|	BankReconciliation.ExpenseItem AS ExpenseItem,
	|	BankReconciliation.IncomeItem AS IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN BankReconciliation.ServiceChargeAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ServiceChargeAccount,
	|	BankReconciliation.ServiceChargeAmount AS ServiceChargeAmount,
	|	BankReconciliation.ServiceChargeDate AS ServiceChargeDate,
	|	BankReconciliation.UseInterestEarned AS UseInterestEarned,
	|	BankReconciliation.InterestEarnedCashFlowItem AS InterestEarnedCashFlowItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN BankReconciliation.InterestEarnedAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InterestEarnedAccount,
	|	BankReconciliation.InterestEarnedAmount AS InterestEarnedAmount,
	|	BankReconciliation.InterestEarnedDate AS InterestEarnedDate
	|INTO TemporaryTableHeader
	|FROM
	|	Document.BankReconciliation AS BankReconciliation
	|WHERE
	|	BankReconciliation.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableHeader.Ref AS Ref,
	|	TemporaryTableHeader.Date AS Date,
	|	TemporaryTableHeader.BankAccount AS BankAccount,
	|	ClearedTransactions.LineNumber AS LineNumber,
	|	ClearedTransactions.Transaction AS Transaction,
	|	ClearedTransactions.TransactionType AS TransactionType,
	|	ClearedTransactions.TransactionAmount AS TransactionAmount
	|INTO TemporaryTableClearedTransactions
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.BankReconciliation.ClearedTransactions AS ClearedTransactions
	|		ON TemporaryTableHeader.Ref = ClearedTransactions.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableHeader.Ref AS Ref,
	|	TemporaryTableHeader.Date AS Date,
	|	TemporaryTableHeader.Company AS Company,
	|	TemporaryTableHeader.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableHeader.BankAccount AS BankAccount,
	|	TemporaryTableHeader.ExpenseItem AS ExpenseItem,
	|	TemporaryTableHeader.IncomeItem AS IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN BankAccounts.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GLAccountData.Currency
	|		ELSE FALSE
	|	END AS GLAccountCurrencyFlag,
	|	BankAccounts.CashCurrency AS Currency,
	|	TemporaryTableHeader.UseServiceCharge AS UseServiceCharge,
	|	TemporaryTableHeader.ServiceChargeType AS ServiceChargeType,
	|	TemporaryTableHeader.ServiceChargeCashFlowItem AS ServiceChargeCashFlowItem,
	|	TemporaryTableHeader.ServiceChargeAccount AS ServiceChargeAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ServiceChargeAccountData.Currency
	|		ELSE FALSE
	|	END AS ServiceChargeAccountCurrencyFlag,
	|	TemporaryTableHeader.ServiceChargeAmount AS ServiceChargeAmount,
	|	CAST(TemporaryTableHeader.ServiceChargeAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_Rates.Rate * PC_Rates.Repetition / (PC_Rates.Rate * DC_Rates.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_Rates.Rate * PC_Rates.Repetition / (PC_Rates.Rate * DC_Rates.Repetition))
	|		END AS NUMBER(15, 2)) AS ServiceChargeAccountingAmount,
	|	TemporaryTableHeader.ServiceChargeDate AS ServiceChargeDate,
	|	TemporaryTableHeader.UseInterestEarned AS UseInterestEarned,
	|	TemporaryTableHeader.InterestEarnedCashFlowItem AS InterestEarnedCashFlowItem,
	|	TemporaryTableHeader.InterestEarnedAccount AS InterestEarnedAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InterestEarnedAccountData.Currency
	|		ELSE FALSE
	|	END AS InterestEarnedAccountCurrencyFlag,
	|	TemporaryTableHeader.InterestEarnedAmount AS InterestEarnedAmount,
	|	CAST(TemporaryTableHeader.InterestEarnedAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_Rates.Rate * PC_Rates.Repetition / (PC_Rates.Rate * DC_Rates.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_Rates.Rate * PC_Rates.Repetition / (PC_Rates.Rate * DC_Rates.Repetition))
	|		END AS NUMBER(15, 2)) AS InterestEarnedAccountingAmount,
	|	TemporaryTableHeader.InterestEarnedDate AS InterestEarnedDate
	|INTO TemporaryTableServiceChargeAndInterestEarned
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS ServiceChargeAccountData
	|		ON TemporaryTableHeader.ServiceChargeAccount = ServiceChargeAccountData.Ref
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS InterestEarnedAccountData
	|		ON TemporaryTableHeader.InterestEarnedAccount = InterestEarnedAccountData.Ref
	|		LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|		ON TemporaryTableHeader.BankAccount = BankAccounts.Ref
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS GLAccountData
	|		ON (BankAccounts.GLAccount = GLAccountData.Ref)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS DC_Rates
	|		ON (BankAccounts.CashCurrency = DC_Rates.Currency)
	|			AND TemporaryTableHeader.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Currency = &PresentationCurrency) AS PC_Rates
	|		ON TemporaryTableHeader.Company = PC_Rates.Company";
	
	Query.ExecuteBatch();
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	AdditionalProperties.Insert("ServiceChargeText",
		NStr("en = 'Service charge'; ru = 'Комиссия';pl = 'Opłata za obsługę';es_ES = 'Gastos de servicio';es_CO = 'Gastos de servicio';tr = 'Hizmet ücreti';it = 'Commissioni servizio';de = 'Nebenkosten'",
			DefaultLanguageCode));
	AdditionalProperties.Insert("InterestEarnedText",
		NStr("en = 'Interest earned'; ru = 'Полученные проценты';pl = 'Naliczone odsetki';es_ES = 'Interés devengado';es_CO = 'Interés devengado';tr = 'Kazanılan faiz';it = 'Interesse guadagnato';de = 'Zinsertrag'",
			DefaultLanguageCode));
	AdditionalProperties.Insert("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Fremdwährungsgewinne und -verluste'",
			DefaultLanguageCode));
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRef, AdditionalProperties);
	
	GenerateTableBankReconciliation(DocumentRef, AdditionalProperties);
	GenerateTableBankCharges(DocumentRef, AdditionalProperties);
	GenerateTableCashAssets(DocumentRef, AdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRef, AdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRef, AdditionalProperties);
	
	// Accounting
	If AdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRef, AdditionalProperties);
	ElsIf AdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRef, AdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRef, AdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRef, AdditionalProperties);
	
EndProcedure

Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsBankReconciliationChange Then
		
		Query = New Query;
		
		Query.Text = AccumulationRegisters.BankReconciliation.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			DocumentObject = DocumentRef.GetObject();
			QueryResultSelection = Result.Select();
			DriveServer.ShowMessageAboutPostingToBankReconciliationRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure


#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Header" Then
		IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Header" Then
		Result.Insert("ServiceChargeAccount", "ExpenseItem");
		Result.Insert("InterestEarnedAccount", "IncomeItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	Return GLAccountsForFilling;
	
EndFunction

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

#Region LibrariesHandlers

// StandardSubsystems.ObjectsVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectsVersioning

#EndRegion

#EndRegion

#Region Private

Procedure GenerateTableBankReconciliation(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ClearedTransactions.Date AS Period,
	|	ClearedTransactions.Transaction AS Transaction,
	|	ClearedTransactions.BankAccount AS BankAccount,
	|	ClearedTransactions.TransactionType AS TransactionType,
	|	ClearedTransactions.TransactionAmount AS Amount
	|FROM
	|	TemporaryTableClearedTransactions AS ClearedTransactions
	|
	|ORDER BY
	|	ClearedTransactions.LineNumber";
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableBankReconciliation", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableBankCharges(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("PostingContent", AdditionalProperties.ServiceChargeText);
	
	Query.Text =
	"SELECT
	|	TableBankCharges.ServiceChargeDate AS Period,
	|	TableBankCharges.Company AS Company,
	|	TableBankCharges.BankAccount AS BankAccount,
	|	TableBankCharges.Currency AS Currency,
	|	TableBankCharges.ServiceChargeType AS BankCharge,
	|	TableBankCharges.ServiceChargeAmount AS AmountCur,
	|	TableBankCharges.ServiceChargeAccountingAmount AS Amount,
	|	&PostingContent AS PostingContent,
	|	TableBankCharges.ServiceChargeCashFlowItem AS Item
	|FROM
	|	TemporaryTableServiceChargeAndInterestEarned AS TableBankCharges
	|WHERE
	|	TableBankCharges.UseServiceCharge";
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableBankCharges", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableCashAssets(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref",				 DocumentRef);
	Query.SetParameter("PointInTime",		 New Boundary(AdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",		 AdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ServiceChargeText",	 AdditionalProperties.ServiceChargeText);
	Query.SetParameter("InterestEarnedText", AdditionalProperties.InterestEarnedText);
	Query.SetParameter("ExchangeDifference", AdditionalProperties.ExchangeDifference);
	Query.SetParameter("ExchangeRateMethod", AdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInterestEarned.InterestEarnedDate AS Date,
	|	TableInterestEarned.Company AS Company,
	|	TableInterestEarned.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic) AS PaymentMethod,
	|	VALUE(Enum.CashAssetTypes.Noncash) AS CashAssetType,
	|	TableInterestEarned.BankAccount AS BankAccountPettyCash,
	|	TableInterestEarned.GLAccount AS GLAccount,
	|	TableInterestEarned.Currency AS Currency,
	|	TableInterestEarned.InterestEarnedAmount AS AmountCur,
	|	TableInterestEarned.InterestEarnedAccountingAmount AS Amount,
	|	&InterestEarnedText AS ContentOfAccountingRecord,
	|	TableInterestEarned.InterestEarnedCashFlowItem AS Item
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableServiceChargeAndInterestEarned AS TableInterestEarned
	|WHERE
	|	TableInterestEarned.UseInterestEarned
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableBankCharges.ServiceChargeDate,
	|	TableBankCharges.Company,
	|	TableBankCharges.PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Electronic),
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	TableBankCharges.BankAccount,
	|	TableBankCharges.GLAccount,
	|	TableBankCharges.Currency,
	|	TableBankCharges.ServiceChargeAmount,
	|	TableBankCharges.ServiceChargeAccountingAmount,
	|	&ServiceChargeText,
	|	TableBankCharges.ServiceChargeCashFlowItem
	|FROM
	|	TemporaryTableServiceChargeAndInterestEarned AS TableBankCharges
	|WHERE
	|	TableBankCharges.UseServiceCharge";
	
	Query.Execute();
	
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
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpenses(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("ServiceChargeText",	 AdditionalProperties.ServiceChargeText);
	Query.SetParameter("InterestEarnedText", AdditionalProperties.InterestEarnedText);
	
	Query.Text =
	"SELECT
	|	TableInterestEarned.InterestEarnedDate AS Period,
	|	TableInterestEarned.Company AS Company,
	|	TableInterestEarned.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	TableInterestEarned.IncomeItem AS IncomeAndExpenseItem,
	|	TableInterestEarned.InterestEarnedAccount AS GLAccount,
	|	TableInterestEarned.InterestEarnedAccountingAmount AS AmountIncome,
	|	0 AS AmountExpense,
	|	&InterestEarnedText AS ContentOfAccountingRecord,
	|	TableInterestEarned.InterestEarnedCashFlowItem AS Item
	|FROM
	|	TemporaryTableServiceChargeAndInterestEarned AS TableInterestEarned
	|WHERE
	|	TableInterestEarned.UseInterestEarned
	|
	|UNION ALL
	|
	|SELECT
	|	TableBankCharges.ServiceChargeDate,
	|	TableBankCharges.Company,
	|	TableBankCharges.PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	TableBankCharges.ExpenseItem AS ExpenseItem,
	|	TableBankCharges.ServiceChargeAccount,
	|	0,
	|	TableBankCharges.ServiceChargeAccountingAmount,
	|	&ServiceChargeText,
	|	TableBankCharges.ServiceChargeCashFlowItem
	|FROM
	|	TemporaryTableServiceChargeAndInterestEarned AS TableBankCharges
	|WHERE
	|	TableBankCharges.UseServiceCharge";
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRef, AdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("ServiceChargeText",	 AdditionalProperties.ServiceChargeText);
	Query.SetParameter("InterestEarnedText", AdditionalProperties.InterestEarnedText);
	
	Query.Text =
	"SELECT
	|	TableInterestEarned.InterestEarnedDate AS Period,
	|	TableInterestEarned.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableInterestEarned.GLAccount AS AccountDr,
	|	TableInterestEarned.InterestEarnedAccount AS AccountCr,
	|	CASE
	|		WHEN TableInterestEarned.GLAccountCurrencyFlag
	|			THEN TableInterestEarned.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableInterestEarned.InterestEarnedAccountCurrencyFlag
	|			THEN TableInterestEarned.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableInterestEarned.GLAccountCurrencyFlag
	|			THEN TableInterestEarned.InterestEarnedAmount
	|		ELSE UNDEFINED
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableInterestEarned.InterestEarnedAccountCurrencyFlag
	|			THEN TableInterestEarned.InterestEarnedAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableInterestEarned.InterestEarnedAccountingAmount AS Amount,
	|	&InterestEarnedText AS Content
	|FROM
	|	TemporaryTableServiceChargeAndInterestEarned AS TableInterestEarned
	|WHERE
	|	TableInterestEarned.UseInterestEarned
	|
	|UNION ALL
	|
	|SELECT
	|	TableBankCharges.ServiceChargeDate,
	|	TableBankCharges.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableBankCharges.ServiceChargeAccount,
	|	TableBankCharges.GLAccount,
	|	CASE
	|		WHEN TableBankCharges.ServiceChargeAccountCurrencyFlag
	|			THEN TableBankCharges.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableBankCharges.GLAccountCurrencyFlag
	|			THEN TableBankCharges.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableBankCharges.ServiceChargeAccountCurrencyFlag
	|			THEN TableBankCharges.ServiceChargeAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN TableBankCharges.GLAccountCurrencyFlag
	|			THEN TableBankCharges.ServiceChargeAmount
	|		ELSE UNDEFINED
	|	END,
	|	TableBankCharges.ServiceChargeAccountingAmount,
	|	&ServiceChargeText
	|FROM
	|	TemporaryTableServiceChargeAndInterestEarned AS TableBankCharges
	|WHERE
	|	TableBankCharges.UseServiceCharge";
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, AdditionalProperties)

	AdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndIf