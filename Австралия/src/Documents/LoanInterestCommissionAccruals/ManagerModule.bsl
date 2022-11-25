#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Public

// Initializes value tables containing data of the document tabular sections.
// Saves value tables to properties of the "AdditionalProperties" structure.
//
Procedure InitializeDocumentData(DocumentRefAccrualsForLoans, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccrualsForLoansAccruals.Ref AS Ref,
	|	AccrualsForLoansAccruals.LineNumber AS LineNumber,
	|	AccrualsForLoansAccruals.AmountType AS AmountType,
	|	AccrualsForLoansAccruals.Date AS Date,
	|	AccrualsForLoansAccruals.Borrower AS Borrower,
	|	AccrualsForLoansAccruals.Lender AS Lender,
	|	AccrualsForLoansAccruals.LoanContract AS LoanContract,
	|	AccrualsForLoansAccruals.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentLoanContract.InterestIncomeItem AS IncomeItem,
	|	DocumentLoanContract.InterestExpenseItem AS ExpenseItem,
	|	DocumentLoanContract.CommissionExpenseItem AS CommissionExpenseItem,
	|	DocumentLoanContract.CommissionIncomeItem AS CommissionIncomeItem,
	|	DocumentLoanContract.InterestIncomeItem.IncomeAndExpenseType AS IncomeItemType,
	|	DocumentLoanContract.InterestExpenseItem.IncomeAndExpenseType AS ExpenseItemType,
	|	AccrualsForLoansAccruals.Total AS AmountCur,
	|	CAST(AccrualsForLoansAccruals.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN AccountingExchangeRate.Repetition * SettlementExchangeRate.Rate / (AccountingExchangeRate.Rate * SettlementExchangeRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (AccountingExchangeRate.Repetition * SettlementExchangeRate.Rate / (AccountingExchangeRate.Rate * SettlementExchangeRate.Repetition))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentLoanInterestCommissionAccruals.OperationType = &AccrualsForLoans
	|			THEN CASE
	|					WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|						THEN DocumentLoanContract.CostAccount
	|					ELSE DocumentLoanContract.CostAccountCommission
	|				END
	|		ELSE CASE
	|				WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|					THEN DocumentLoanContract.InterestGLAccount
	|				ELSE DocumentLoanContract.CommissionGLAccount
	|			END
	|	END AS CostAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AccrualsForLoansAccruals.LoanContract.CostAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountOfIncomeAndExpenses,
	|	AccrualsForLoansAccruals.StructuralUnit AS StructuralUnit,
	|	AccrualsForLoansAccruals.Order AS SalesOrder,
	|	AccrualsForLoansAccruals.BusinessArea AS BusinessArea,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentLoanInterestCommissionAccruals.OperationType = &AccrualsForLoans
	|			THEN CASE
	|					WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|						THEN DocumentLoanContract.InterestGLAccount
	|					ELSE DocumentLoanContract.CommissionGLAccount
	|				END
	|		ELSE CASE
	|				WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|					THEN DocumentLoanContract.CostAccount
	|				ELSE DocumentLoanContract.CostAccountCommission
	|			END
	|	END AS Correspondence,
	|	DocumentLoanInterestCommissionAccruals.Date AS Period,
	|	DocumentLoanInterestCommissionAccruals.OperationType AS OperationType
	|INTO Accruals
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS AccrualsForLoansAccruals
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementExchangeRate
	|		ON AccrualsForLoansAccruals.SettlementsCurrency = SettlementExchangeRate.Currency
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (AccountingExchangeRate.Currency = &PresentationCurrency)
	|		LEFT JOIN Document.LoanInterestCommissionAccruals AS DocumentLoanInterestCommissionAccruals
	|		ON AccrualsForLoansAccruals.Ref = DocumentLoanInterestCommissionAccruals.Ref
	|		LEFT JOIN Document.LoanContract AS DocumentLoanContract
	|		ON AccrualsForLoansAccruals.LoanContract = DocumentLoanContract.Ref
	|WHERE
	|	AccrualsForLoansAccruals.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Accruals.LineNumber AS LineNumber,
	|	Accruals.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Accruals.BusinessArea AS BusinessLine,
	|	Accruals.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN Accruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN Accruals.ExpenseItem
	|		ELSE Accruals.CommissionExpenseItem
	|	END AS IncomeAndExpenseItem,
	|	Accruals.CostAccount AS GLAccount,
	|	CASE
	|		WHEN Accruals.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE Accruals.SalesOrder
	|	END AS SalesOrder,
	|	0 AS AmountIncome,
	|	Accruals.Amount AS AmountExpense,
	|	&OtherIncomeAndExpensePostingContent AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	Accruals AS Accruals
	|WHERE
	|	Accruals.OperationType = &AccrualsForLoans
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Accruals.LineNumber AS LineNumber,
	|	Accruals.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Accruals.BusinessArea AS BusinessLine,
	|	Accruals.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN Accruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN Accruals.IncomeItem
	|		ELSE Accruals.CommissionIncomeItem
	|	END AS IncomeAndExpenseItem,
	|	Accruals.Correspondence AS GLAccount,
	|	CASE
	|		WHEN Accruals.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE Accruals.SalesOrder
	|	END AS SalesOrder,
	|	Accruals.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	Accruals.Amount AS Amount,
	|	&OtherIncomeAndExpensePostingContent AS ContentOfAccountingRecord
	|FROM
	|	Accruals AS Accruals
	|WHERE
	|	Accruals.OperationType <> &AccrualsForLoans
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Accruals.LineNumber AS LineNumber,
	|	Accruals.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Accruals.CostAccount AS AccountDr,
	|	CASE
	|		WHEN Accruals.CostAccount.Currency
	|			THEN Accruals.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN Accruals.CostAccount.Currency
	|			THEN Accruals.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	Accruals.Correspondence AS AccountCr,
	|	CASE
	|		WHEN Accruals.Correspondence.Currency
	|			THEN Accruals.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN Accruals.Correspondence.Currency
	|			THEN Accruals.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	Accruals.Amount AS Amount,
	|	&OtherIncomeAndExpensePostingContent AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Accruals AS Accruals
	|WHERE
	|	Accruals.OperationType = &AccrualsForLoans
	|
	|UNION ALL
	|
	|SELECT
	|	Accruals.LineNumber,
	|	Accruals.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	Accruals.CostAccount,
	|	CASE
	|		WHEN Accruals.CostAccount.Currency
	|			THEN Accruals.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN Accruals.CostAccount.Currency
	|			THEN Accruals.AmountCur
	|		ELSE 0
	|	END,
	|	Accruals.Correspondence,
	|	CASE
	|		WHEN Accruals.Correspondence.Currency
	|			THEN Accruals.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN Accruals.Correspondence.Currency
	|			THEN Accruals.AmountCur
	|		ELSE 0
	|	END,
	|	Accruals.Amount,
	|	&OtherIncomeAndExpensePostingContent,
	|	FALSE
	|FROM
	|	Accruals AS Accruals
	|WHERE
	|	Accruals.OperationType <> &AccrualsForLoans
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	&PresentationCurrency,
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
	|	AND OfflineRecords.OfflineRecord");
	
	Query.SetParameter("Ref",							DocumentRefAccrualsForLoans);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("AccrualsForLoans",				Enums.LoanAccrualTypes.AccrualsForLoansBorrowed);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",	GetFunctionalOption("UseDefaultTypeOfAccounting"));
	Query.SetParameter("CounterpartyLoanAgreement",		Enums.LoanContractTypes.CounterpartyLoanAgreement);
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("OtherIncomeAndExpensePostingContent", NStr("en = 'Loans'; ru = 'Расчеты по кредитам и займам';pl = 'Rozliczenia z tytułu kredytów i pożyczek';es_ES = 'Préstamos';es_CO = 'Préstamos';tr = 'Krediler';it = 'Prestiti';de = 'Darlehen'", MainLanguageCode));
	
	ResultArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultArray[1].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultArray[2].Unload());
	Else
		
		Selection = ResultArray[2].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefAccrualsForLoans, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefAccrualsForLoans, StructureAdditionalProperties);
	
	// LoanSettlements
	GenerateTableLoanSettlements(DocumentRefAccrualsForLoans, StructureAdditionalProperties);
	
	// Accounting
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultArray[3].Unload());
	ElsIf StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefAccrualsForLoans, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefAccrualsForLoans, StructureAdditionalProperties);
		
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefAccrualsForLoans, StructureAdditionalProperties);
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	Return IncomeAndExpenseStructure;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion


#Region LibrariesHandlers

#Region PrintInterface

// Fills the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see field content in the PrintManagement.CreatePrintCommandCollection function.
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

#EndRegion

#Region Private

#Region TableGeneration

// Generates the value table containing data to post for the register.
// Saves value tables to properties of the "AdditionalProperties" structure.
//
Procedure GenerateTableLoanSettlements(DocumentRefAccrualsForLoans, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CreditInterestAccrued",		NStr("en = '(Received) loan interest is accrued'; ru = 'Начислены проценты по кредиту (полученному)';pl = '(Otrzymane) odsetki od pożyczki są naliczone';es_ES = '(Recibido) interés del préstamo está acumulado';es_CO = '(Recibido) interés del préstamo está acumulado';tr = '(Alınan) kredi faizi tahakkuk ettirildi';it = 'L''interesse per il prestito (ricevuto) è maturato';de = '(Erhaltene) Darlehenszinsen sind aufgelaufen'", MainLanguageCode));
	Query.SetParameter("CreditCommissionAccrued",	NStr("en = '(Received) loan commission is accrued'; ru = 'Начислена комиссия по кредиту (полученному)';pl = '(Otrzymana) prowizja od pożyczki naliczona';es_ES = '(Recibido) comisión del préstamo está acumulada';es_CO = '(Recibido) comisión del préstamo está acumulada';tr = '(Alınan) kredi komisyonu tahakkuk ettirildi';it = 'La commissione per il prestito (ricevuto) è maturata';de = '(Empfangene) Darlehensprovision ist aufgelaufen'", MainLanguageCode));
	Query.SetParameter("LoanInterestAccrued",		NStr("en = '(Issued) loan interest is accrued'; ru = 'Начислены проценты по займу (выданному)';pl = '(Wydane) odsetki od pożyczki są naliczone';es_ES = '(Emitido) interés del préstamo está acumulado';es_CO = '(Emitido) interés del préstamo está acumulado';tr = '(Verilen) kredi faizi tahakkuk ettirildi';it = 'L''interesse per il prestito (emesso) è maturato';de = '(Ausgegebene) Darlehenszinsen sind aufgelaufen'", MainLanguageCode));
	Query.SetParameter("LoanCommissionAccrued",		NStr("en = '(Issued) loan commission is accrued'; ru = 'Начислена комиссия по займу (выданному)';pl = '(Wydana) prowizja od pożyczki naliczona';es_ES = '(Emitido) comisión del préstamo está acumulada';es_CO = '(Emitido) comisión del préstamo está acumulada';tr = '(Verilen) kredi komisyonu tahakkuk ettirildi';it = 'La commissione per il prestito (emesso) è maturata';de = '(Ausgegebene) Darlehensprovision ist aufgelaufen'", MainLanguageCode));
	Query.SetParameter("Ref",						DocumentRefAccrualsForLoans);
	Query.SetParameter("PointInTime",				New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));	
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",    	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|			THEN AccrualsForLoansAccruals.Lender
	|		ELSE AccrualsForLoansAccruals.Borrower
	|	END AS Counterparty,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END AS LoanKind,
	|	AccrualsForLoansAccruals.LoanContract AS LoanContract,
	|	AccrualsForLoansAccruals.Date AS Period,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN AccrualsForLoansAccruals.Total
	|		ELSE 0
	|	END AS InterestCur,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN AccrualsForLoansAccruals.Total
	|		ELSE 0
	|	END AS CommissionCur,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN CAST(AccrualsForLoansAccruals.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN AccountingExchangeRate.Repetition * SettlementExchangeRate.Rate / (AccountingExchangeRate.Rate * SettlementExchangeRate.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (AccountingExchangeRate.Repetition * SettlementExchangeRate.Rate / (AccountingExchangeRate.Rate * SettlementExchangeRate.Repetition))
	|					END AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS Interest,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN CAST(AccrualsForLoansAccruals.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN AccountingExchangeRate.Repetition * SettlementExchangeRate.Rate / (AccountingExchangeRate.Rate * SettlementExchangeRate.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (AccountingExchangeRate.Repetition * SettlementExchangeRate.Rate / (AccountingExchangeRate.Rate * SettlementExchangeRate.Repetition))
	|					END AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS Commission,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|			THEN CASE
	|					WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|						THEN &CreditCommissionAccrued
	|					ELSE &CreditInterestAccrued
	|				END
	|		ELSE CASE
	|				WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|					THEN &LoanCommissionAccrued
	|				ELSE &LoanInterestAccrued
	|			END
	|	END AS PostingContent,
	|	AccrualsForLoansAccruals.StructuralUnit AS StructuralUnit
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS AccrualsForLoansAccruals
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS SettlementExchangeRate
	|		ON AccrualsForLoansAccruals.SettlementsCurrency = SettlementExchangeRate.Currency
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|WHERE
	|	AccrualsForLoansAccruals.Ref = &Ref";
	
	RequestResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", RequestResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRefAccrualsForLoans, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#Region InfobaseUpdate

Procedure UpdateDocumentTabSectionAnalytics() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	LoanInterestCommissionAccruals.Ref AS Ref,
	|	LoanInterestCommissionAccruals.LoanContract AS LoanContract,
	|	CASE
	|		WHEN DocumentLoanContract.InterestExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentLoanContract.BusinessArea
	|	END AS BusinessArea,
	|	CASE
	|		WHEN DocumentLoanContract.InterestExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE DocumentLoanContract.StructuralUnit
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentLoanContract.InterestExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE DocumentLoanContract.Order
	|	END AS Order
	|INTO LoanInterestCommissionAccruals
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS LoanInterestCommissionAccruals
	|		INNER JOIN Document.LoanInterestCommissionAccruals AS LoanInterestCommission
	|		ON LoanInterestCommissionAccruals.Ref = LoanInterestCommission.Ref
	|		INNER JOIN Document.LoanContract AS DocumentLoanContract
	|		ON LoanInterestCommissionAccruals.LoanContract = DocumentLoanContract.Ref
	|WHERE
	|	LoanInterestCommission.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|	AND LoanInterestCommissionAccruals.BusinessArea = VALUE(Catalog.LinesOfBusiness.EmptyRef)
	|	AND LoanInterestCommissionAccruals.Order = VALUE(Document.SalesOrder.EmptyRef)
	|	AND LoanInterestCommissionAccruals.StructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	LoanInterestCommissionAccruals.Ref,
	|	LoanInterestCommissionAccruals.LoanContract,
	|	CASE
	|		WHEN DocumentLoanContract.InterestIncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentLoanContract.BusinessArea
	|	END,
	|	CASE
	|		WHEN DocumentLoanContract.InterestIncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE DocumentLoanContract.StructuralUnit
	|	END,
	|	CASE
	|		WHEN DocumentLoanContract.InterestIncomeItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE DocumentLoanContract.Order
	|	END
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS LoanInterestCommissionAccruals
	|		INNER JOIN Document.LoanInterestCommissionAccruals AS LoanInterestCommission
	|		ON LoanInterestCommissionAccruals.Ref = LoanInterestCommission.Ref
	|		INNER JOIN Document.LoanContract AS DocumentLoanContract
	|		ON LoanInterestCommissionAccruals.LoanContract = DocumentLoanContract.Ref
	|WHERE
	|	LoanInterestCommission.OperationType <> VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|	AND LoanInterestCommissionAccruals.BusinessArea = VALUE(Catalog.LinesOfBusiness.EmptyRef)
	|	AND LoanInterestCommissionAccruals.Order = VALUE(Document.SalesOrder.EmptyRef)
	|	AND LoanInterestCommissionAccruals.StructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanInterestCommissionAccruals.Ref AS Ref,
	|	LoanInterestCommissionAccruals.LoanContract AS LoanContract,
	|	LoanInterestCommissionAccruals.BusinessArea AS BusinessArea,
	|	LoanInterestCommissionAccruals.Order AS Order,
	|	LoanInterestCommissionAccruals.StructuralUnit AS StructuralUnit
	|INTO LoanTable
	|FROM
	|	LoanInterestCommissionAccruals AS LoanInterestCommissionAccruals
	|WHERE
	|	(LoanInterestCommissionAccruals.BusinessArea <> VALUE(Catalog.LinesOfBusiness.EmptyRef)
	|			OR LoanInterestCommissionAccruals.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|			OR LoanInterestCommissionAccruals.Order <> VALUE(Document.SalesOrder.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanTable.LoanContract AS LoanContract,
	|	LoanTable.BusinessArea AS BusinessArea,
	|	LoanTable.Order AS Order,
	|	LoanTable.StructuralUnit AS StructuralUnit
	|FROM
	|	LoanTable AS LoanTable
	|
	|GROUP BY
	|	LoanTable.LoanContract,
	|	LoanTable.Order,
	|	LoanTable.StructuralUnit,
	|	LoanTable.BusinessArea
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	LoanTable.Ref AS Ref
	|FROM
	|	LoanTable AS LoanTable";
	
	QueryResult = Query.ExecuteBatch();
	
	LoanContractTable =  QueryResult[2].Unload();
	
	Selection = QueryResult[3].Select();
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		Accruals = DocObject.Accruals.Unload();
		
		For Each Accrual In Accruals Do
			
			If ValueIsFilled(Accrual.BusinessArea)
				Or ValueIsFilled(Accrual.Order)
				Or ValueIsFilled(Accrual.StructuralUnit) Then
				Continue;
			EndIf;
			
			LoanContractRow = LoanContractTable.Find(Accrual.LoanContract, "LoanContract");
			If LoanContractRow = Undefined Then
				Continue;
			EndIf;
			
			If ValueIsFilled(LoanContractRow.BusinessArea) Then
				Accrual.BusinessArea = LoanContractRow.BusinessArea;
			EndIf;
			
			If ValueIsFilled(LoanContractRow.Order) Then
				Accrual.Order = LoanContractRow.Order;
			EndIf;
			
			If ValueIsFilled(LoanContractRow.StructuralUnit) Then
				Accrual.StructuralUnit = LoanContractRow.StructuralUnit;
			EndIf;
			
		EndDo;
		
		DocObject.Accruals.Load(Accruals);
		
		Try
			
			InfobaseUpdate.WriteObject(DocObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot write document ""%1"". Details: %2'; ru = 'Не удается записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'No se ha podido guardar el documento ""%1"". Detalles: %2';es_CO = 'No se ha podido guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar%2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
