#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Public

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
	WarehouseData.Insert("TrackingArea", "InventoryIncrease");
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

Function BankAccountUseOverdraft(BankAccount, DocDate) Export
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED DISTINCT
	|	BankAccounts.UseOverdraft AS UseOverdraft,
	|	ISNULL(OverdraftLimitsSliceLast.Limit, 0) AS Limit
	|FROM
	|	Catalog.BankAccounts AS BankAccounts
	|		LEFT JOIN InformationRegister.OverdraftLimits.SliceLast(
	|				,
	|				BankAccount = &BankAccount
	|					AND &DocDate >= StartDate
	|					AND (&DocDate <= EndDate
	|						OR EndDate = DATETIME(1, 1, 1))) AS OverdraftLimitsSliceLast
	|		ON (OverdraftLimitsSliceLast.BankAccount = BankAccounts.Ref)
	|WHERE
	|	BankAccounts.Ref = &BankAccount";
	
	Query.SetParameter("BankAccount", BankAccount);
	Query.SetParameter("DocDate", DocDate);
	
	Result = New Structure("UseOverdraft,Limit", False, 0);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

// Generating procedure for the table of invoices for payment.
//
// Parameters:
// DocumentRefOpeningBalanceEntry - DocumentRef.OpeningBalanceEntry - Current document
// StructureAdditionalProperties - Structure - Additional properties of the document
//
Procedure InitializeInvoicesAndOrdersPaymentDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	AccountsReceivable.Ref.Date AS Period,
	|	&Company AS Company,
	|	AccountsReceivable.SalesOrder AS Quote,
	|	AccountsReceivable.AmountCur AS AdvanceAmount
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Ref = &Ref
	|	AND AccountsReceivable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND AccountsReceivable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayable.Ref.Date,
	|	&Company,
	|	AccountsPayable.PurchaseOrder,
	|	AccountsPayable.AmountCur
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Ref = &Ref
	|	AND AccountsPayable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND AccountsPayable.PurchaseOrder <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|	AND AccountsPayable.PurchaseOrder <> UNDEFINED
	|	AND AccountsPayable.AdvanceFlag";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccountingJournalEntries.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	AccountingJournalEntries.Amount AS Amount,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN AccountingJournalEntries.Account
	|		ELSE &OBEAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN CASE
	|					WHEN AccountingJournalEntries.Account.Currency
	|						THEN AccountingJournalEntries.Currency
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN CASE
	|					WHEN AccountingJournalEntries.Account.Currency
	|						THEN AccountingJournalEntries.AmountCur
	|					ELSE 0
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN &OBEAccount
	|		ELSE AccountingJournalEntries.Account
	|	END AS AccountCr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN UNDEFINED
	|		ELSE CASE
	|				WHEN AccountingJournalEntries.Account.Currency
	|					THEN AccountingJournalEntries.Currency
	|				ELSE UNDEFINED
	|			END
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN 0
	|		ELSE CASE
	|				WHEN AccountingJournalEntries.Account.Currency
	|					THEN AccountingJournalEntries.AmountCur
	|				ELSE 0
	|			END
	|	END AS AmountCurCr,
	|	&Content AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.OpeningBalanceEntry.OtherSections AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.Amount,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord");
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("OBEAccount",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",			DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",		StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Content",		NStr("en = 'Opening balance entry'; ru = 'Ввод начальных остатков';pl = 'Wprowadzenie salda początkowego';es_ES = 'Entrada de saldo de apertura';es_CO = 'Entrada de saldo de apertura';tr = 'Açılış bakiyesi girişi';it = 'Inserimento saldo iniziale';de = 'Anfangssaldo-Buchung'", MainLanguageCode));
	
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAdvanceHolders(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AdvanceHolders.Ref AS Ref,
	|	AdvanceHolders.Ref.Date AS Period,
	|	CASE
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AdvanceHolders.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	AdvanceHolders.Employee AS Employee,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN AdvanceHolders.Employee.OverrunGLAccount
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN AdvanceHolders.Employee.AdvanceHoldersGLAccount
	|	END AS GLAccount,
	|	AdvanceHolders.Currency AS Currency,
	|	AdvanceHolders.Document AS Document,
	|	CASE
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN VALUE(AccountingRecordType.Credit)
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN VALUE(AccountingRecordType.Debit)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN &DebtRepaymentToAdvanceHolder
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN &AdvanceHolderDebtEmergence
	|	END AS ContentOfAccountingRecord,
	|	SUM(AdvanceHolders.AmountCur) AS AmountCur,
	|	SUM(AdvanceHolders.Amount) AS Amount
	|FROM
	|	Document.OpeningBalanceEntry.AdvanceHolders AS AdvanceHolders
	|WHERE
	|	AdvanceHolders.Ref = &Ref
	|
	|GROUP BY
	|	AdvanceHolders.Ref,
	|	AdvanceHolders.Employee,
	|	AdvanceHolders.Currency,
	|	AdvanceHolders.Document,
	|	AdvanceHolders.Overrun,
	|	AdvanceHolders.Ref.Date,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN AdvanceHolders.Employee.OverrunGLAccount
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN AdvanceHolders.Employee.AdvanceHoldersGLAccount
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Employee.AdvanceHoldersGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN DocumentTable.Employee.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN DocumentTable.Employee.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&AdvanceHolderDebtEmergence AS Content
	|FROM
	|	Document.OpeningBalanceEntry.AdvanceHolders AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Overrun = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Employee.OverrunGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN DocumentTable.Employee.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN DocumentTable.Employee.OverrunGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	&DebtRepaymentToAdvanceHolder
	|FROM
	|	Document.OpeningBalanceEntry.AdvanceHolders AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Overrun = TRUE
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("OBEAccount",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",							DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AdvanceHolderDebtEmergence",	NStr("en = 'The amount due from the advance holder'; ru = 'Сумма к оплате от подотчетного лица';pl = 'Kwota należna od zaliczkobiorcy';es_ES = 'El importe adeudado por el titular del anticipo';es_CO = 'El importe adeudado por el titular del anticipo';tr = 'Avans sahibinden gelecek tutar';it = 'Importo dovuto dalla persona che ha anticipato';de = 'Der fällige Betrag von der abrechnungspflichtigen Person'", MainLanguageCode));
	Query.SetParameter("DebtRepaymentToAdvanceHolder",	NStr("en = 'The amount due from the advance holder'; ru = 'Сумма к оплате от подотчетного лица';pl = 'Kwota należna od zaliczkobiorcy';es_ES = 'El importe adeudado por el titular del anticipo';es_CO = 'El importe adeudado por el titular del anticipo';tr = 'Avans sahibinden gelecek tutar';it = 'Importo dovuto dalla persona che ha anticipato';de = 'Der fällige Betrag von der abrechnungspflichtigen Person'", MainLanguageCode));
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAdvanceHolders", ResultsArray[0].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataPayroll(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	Payroll.Ref AS Ref,
	|	Payroll.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	MIN(Payroll.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Payroll.StructuralUnit AS StructuralUnit,
	|	Payroll.Employee AS Employee,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Payroll.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	Payroll.Currency AS Currency,
	|	BEGINOFPERIOD(Payroll.RegistrationPeriod, MONTH) AS RegistrationPeriod,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&OccurrenceOfObligationsToStaff AS ContentOfAccountingRecord,
	|	SUM(Payroll.AmountCur) AS AmountCur,
	|	SUM(Payroll.Amount) AS Amount
	|FROM
	|	Document.OpeningBalanceEntry.Payroll AS Payroll
	|WHERE
	|	Payroll.Ref = &Ref
	|
	|GROUP BY
	|	Payroll.Ref,
	|	Payroll.Employee,
	|	Payroll.StructuralUnit,
	|	Payroll.Currency,
	|	Payroll.RegistrationPeriod,
	|	Payroll.Ref.Date,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Payroll.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	&OBEAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN DocumentTable.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN DocumentTable.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&OccurrenceOfObligationsToStaff AS Content
	|FROM
	|	Document.OpeningBalanceEntry.Payroll AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;

	Query.SetParameter("OBEAccount",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",								DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",							StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",				StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("OccurrenceOfObligationsToStaff",	NStr("en = 'Incurrence of liabilities to personnel'; ru = 'Возникновение обязательств перед персоналом';pl = 'Powstanie zobowiązań wobec pracownika';es_ES = 'Nacimiento de obligaciones a los empleados';es_CO = 'Nacimiento de obligaciones a los empleados';tr = 'Personele karşı yükümlülüklerin oluşması';it = 'Nascita di passività per il personale';de = 'Entstehen von Verbindlichkeiten gegenüber Mitarbeitern'", MainLanguageCode));
	Query.SetParameter("UseDefaultTypeOfAccounting",			UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll", ResultsArray[0].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataTaxesSettlements(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	OpeningBalanceEntry.Date AS Period,
	|	CASE
	|		WHEN SUM(TabTaxesSettlements.Amount) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	MIN(TabTaxesSettlements.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TabTaxesSettlements.TaxKind AS TaxKind,
	|	OpeningBalanceEntry.CompanyVATNumber AS CompanyVATNumber,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TabTaxesSettlements.TaxKind.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&TaxAccrual AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN SUM(TabTaxesSettlements.Amount) > 0
	|			THEN SUM(TabTaxesSettlements.Amount)
	|		ELSE -SUM(TabTaxesSettlements.Amount)
	|	END AS Amount
	|FROM
	|	Document.OpeningBalanceEntry.TaxesSettlements AS TabTaxesSettlements
	|		INNER JOIN Document.OpeningBalanceEntry AS OpeningBalanceEntry
	|		ON TabTaxesSettlements.Ref = OpeningBalanceEntry.Ref
	|			AND (TabTaxesSettlements.Ref = &Ref)
	|WHERE
	|	TabTaxesSettlements.Ref = &Ref
	|
	|GROUP BY
	|	TabTaxesSettlements.Ref,
	|	TabTaxesSettlements.TaxKind,
	|	OpeningBalanceEntry.CompanyVATNumber,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TabTaxesSettlements.TaxKind.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	OpeningBalanceEntry.Date
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
		|	CASE
	|		WHEN DocumentTable.Amount > 0
	|			THEN DocumentTable.Amount
	|		ELSE -DocumentTable.Amount
	|	END AS Amount,
	|	CASE
	|		WHEN DocumentTable.Amount > 0
	|			THEN &OBEAccount
	|		ELSE CASE
	|				WHEN &UseDefaultTypeOfAccounting
	|					THEN DocumentTable.TaxKind.GLAccount
	|				ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			END
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.Amount > 0
	|			THEN CASE
	|					WHEN &UseDefaultTypeOfAccounting
	|						THEN DocumentTable.TaxKind.GLAccount
	|					ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|				END
	|		ELSE &OBEAccount
	|	END AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&TaxAccrual AS Content
	|FROM
	|	Document.OpeningBalanceEntry.TaxesSettlements AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;

	Query.SetParameter("OBEAccount",				Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",						DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("TaxAccrual",				NStr("en = 'The tax payable opening balance'; ru = 'Начальный остаток налога к оплате';pl = 'Saldo początkowe VAT należnego';es_ES = 'El saldo inicial del impuesto a pagar';es_CO = 'El saldo inicial del impuesto a pagar';tr = 'Ödenecek vergi açılış bakiyesi';it = 'Imposta dovuta sul saldo iniziale';de = 'Der Anfangssaldo von zahlbarer Steuer'", MainLanguageCode));
	Query.SetParameter("UseDefaultTypeOfAccounting",	UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", ResultsArray[0].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountsReceivable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccountsReceivable.Ref.Date AS Period,
	|	CASE
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AccountsReceivable.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	AccountsReceivable.Counterparty AS Counterparty,
	|	AccountsReceivable.Contract AS Contract,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByOrders
	|				AND AccountsReceivable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND AccountsReceivable.SalesOrder <> VALUE(Document.WOrkOrder.EmptyRef)
	|			THEN AccountsReceivable.SalesOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	AccountsReceivable.Document AS Document,
	|	AccountsReceivable.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN NOT AccountsReceivable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Debt)
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN NOT AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Debit)
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Credit)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN NOT AccountsReceivable.AdvanceFlag
	|			THEN &AppearenceOfCustomerLiability
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN &CustomerObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN NOT AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.AccountsReceivableGLAccount
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.AdvancesReceivedGLAccount
	|	END AS GLAccount,
	|	SUM(AccountsReceivable.AmountCur) AS AmountCur,
	|	SUM(AccountsReceivable.Amount) AS Amount,
	|	SUM(AccountsReceivable.AmountCur) AS AmountForPaymentCur,
	|	SUM(AccountsReceivable.Amount) AS AmountForPayment
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Ref = &Ref
	|
	|GROUP BY
	|	AccountsReceivable.Counterparty,
	|	AccountsReceivable.Contract,
	|	AccountsReceivable.AdvanceFlag,
	|	AccountsReceivable.SalesOrder,
	|	AccountsReceivable.Document,
	|	AccountsReceivable.Ref,
	|	AccountsReceivable.Ref.Date,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN NOT AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.AccountsReceivableGLAccount
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.AdvancesReceivedGLAccount
	|	END,
	|	AccountsReceivable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByOrders
	|				AND AccountsReceivable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND AccountsReceivable.SalesOrder <> VALUE(Document.WOrkOrder.EmptyRef)
	|			THEN AccountsReceivable.SalesOrder
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AccountsReceivableGLAccount
	|		ELSE UNDEFINED
	|	END AS AccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN DocumentTable.AccountsReceivableGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CAST(&AppearenceOfCustomerLiability AS STRING(100)) AS Content
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN DocumentTable.AdvancesReceivedGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CAST(&CustomerObligationsRepayment AS STRING(100))
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;

	Query.SetParameter("OBEAccount",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",							DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AppearenceOfCustomerLiability",	NStr("en = 'The accounts receivable opening balance'; ru = 'Начальный остаток дебиторской задолженности';pl = 'Saldo początkowe należności';es_ES = 'El saldo inicial de las cuentas por cobrar';es_CO = 'El saldo inicial de las cuentas por cobrar';tr = 'Alacak hesapları açılış bakiyesi';it = 'Crediti contabili del saldo iniziale';de = 'Der Anfangssaldo von Offenen Posten Debitoren'", MainLanguageCode));
	Query.SetParameter("CustomerObligationsRepayment",	NStr("en = 'Enter advance balance from customers'; ru = 'Ввод остатков авансов от покупателей';pl = 'Wprowadzenie sald należności, zaliczki od nabywców';es_ES = 'Introducir el saldo de anticipos de los clientes';es_CO = 'Introducir el saldo de anticipos de los clientes';tr = 'Müşterilerin kalan avanslarını girin';it = 'Inserimento del saldo degli anticipi da parte dei clienti';de = 'Voraussaldo von Kunden eingeben'", MainLanguageCode));
	Query.SetParameter("UseDefaultTypeOfAccounting",		UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[0].Unload());
	
	If UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountsPayable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccountsPayable.Ref.Date AS Period,
	|	CASE
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AccountsPayable.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	AccountsPayable.Counterparty AS Counterparty,
	|	AccountsPayable.Contract AS Contract,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByOrders
	|				AND AccountsPayable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND AccountsPayable.PurchaseOrder <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN AccountsPayable.PurchaseOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	AccountsPayable.Document AS Document,
	|	AccountsPayable.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Debt)
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Credit)
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Debit)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN &AppearenceOfLiabilityToVendor
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN &VendorObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.AccountsPayableGLAccount
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.AdvancesPaidGLAccount
	|	END AS GLAccount,
	|	SUM(AccountsPayable.AmountCur) AS AmountCur,
	|	SUM(AccountsPayable.Amount) AS Amount,
	|	SUM(AccountsPayable.Amount) AS AmountForPayment,
	|	SUM(AccountsPayable.AmountCur) AS AmountForPaymentCur
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Ref = &Ref
	|
	|GROUP BY
	|	AccountsPayable.Counterparty,
	|	AccountsPayable.Contract,
	|	AccountsPayable.AdvanceFlag,
	|	AccountsPayable.PurchaseOrder,
	|	AccountsPayable.Document,
	|	AccountsPayable.Ref,
	|	AccountsPayable.Ref.Date,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.AccountsPayableGLAccount
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.AdvancesPaidGLAccount
	|	END,
	|	AccountsPayable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByOrders
	|				AND AccountsPayable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND AccountsPayable.PurchaseOrder <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN AccountsPayable.PurchaseOrder
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	&OBEAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN DocumentTable.AccountsPayableGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)) AS Content
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND NOT DocumentTable.AdvanceFlag
	|	AND &UseDefaultTypeOfAccounting
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN DocumentTable.AdvancesPaidGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN DocumentTable.AdvancesPaidGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	CAST(&VendorObligationsRepayment AS STRING(100))
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|	AND &UseDefaultTypeOfAccounting
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("OBEAccount"						, Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref"							, DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company"						, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"			, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AppearenceOfLiabilityToVendor"	, NStr("en = 'The accounts payable opening balance'; ru = 'Начальный остаток кредиторской задолженности';pl = 'Saldo początkowe zobowiązań';es_ES = 'El saldo inicial de las cuentas por pagar';es_CO = 'El saldo inicial de las cuentas por pagar';tr = 'Borç hesapları açılış bakiyesi';it = 'Debiti contabili del saldo iniziale';de = 'Der Anfangssaldo von Offenen Posten Kreditoren'", MainLanguageCode));
	Query.SetParameter("VendorObligationsRepayment"		, NStr("en = 'The balance of advances paid to suppliers'; ru = 'Остаток авансов, выплаченных поставщикам';pl = 'Saldo zaliczek wypłaconych dostawcom';es_ES = 'El saldo de los anticipos pagados a los proveedores';es_CO = 'El saldo de los anticipos pagados a los proveedores';tr = 'Tedarikçilere ödenen avansların bakiyesi';it = 'Saldo degli anticipi versati ai fornitori';de = 'Der Saldo der Vorauszahlungen geleistet an Lieferanten'", MainLanguageCode));
	Query.SetParameter("UseDefaultTypeOfAccounting"		, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[0].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		
		If StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Count() > 0 Then
			Selection = ResultsArray[1].Select();
			While Selection.Next() Do
				NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(NewRow, Selection);
			EndDo;
		Else
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
		EndIf;
		
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataUnallocatedExpenses(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Document,
	|	DocumentTable.Document.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	LineNumber");
 
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesCashMethod(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS BusinessLine,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	DocumentTable.LineNumber");
 
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesRetained(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	VALUE(Catalog.LinesOfBusiness.MainLine) AS BusinessLine,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Document,
	|	VALUE(Catalog.LinesOfBusiness.MainLine),
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	LineNumber");

	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DocumentDataInitializationCashAssets(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	CashAssets.Ref.Date AS Period,
	|	MIN(CashAssets.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN VALUETYPE(CashAssets.BankAccountPettyCash) = TYPE(Catalog.CashAccounts)
	|			THEN VALUE(Catalog.PaymentMethods.Cash)
	|		ELSE VALUE(Catalog.PaymentMethods.Electronic)
	|	END AS PaymentMethod,
	|	CashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	CashAssets.CashCurrency AS Currency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CashAssets.BankAccountPettyCash.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	&ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	VALUE(Catalog.CashFlowItems.OpeningBalanceEntry) AS Item,
	|	SUM(CashAssets.AmountCur) AS AmountCur,
	|	SUM(CashAssets.Amount) AS Amount,
	|	CASE
	|		WHEN VALUETYPE(CashAssets.BankAccountPettyCash) = TYPE(Catalog.CashAccounts)
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END AS CashAssetType
	|FROM
	|	Document.OpeningBalanceEntry.CashAssets AS CashAssets
	|WHERE
	|	CashAssets.Ref = &Ref
	|
	|GROUP BY
	|	CashAssets.Ref,
	|	CashAssets.CashCurrency,
	|	CASE
	|		WHEN VALUETYPE(CashAssets.BankAccountPettyCash) = TYPE(Catalog.CashAccounts)
	|			THEN VALUE(Catalog.PaymentMethods.Cash)
	|		ELSE VALUE(Catalog.PaymentMethods.Electronic)
	|	END,
	|	CashAssets.BankAccountPettyCash,
	|	CashAssets.Ref.Date,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CashAssets.BankAccountPettyCash.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.BankAccountPettyCash.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN UNDEFINED
	|		WHEN DocumentTable.BankAccountPettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN 0
	|		WHEN DocumentTable.BankAccountPettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&ContentOfAccountingRecord AS Content
	|FROM
	|	Document.OpeningBalanceEntry.CashAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("OBEAccount"					, Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref"						, DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company"					, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"		, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ContentOfAccountingRecord"	, NStr("en = 'Enter cash balance'; ru = 'Ввод остатков денежных средств';pl = 'Wprowadzenie salda gotówkowego';es_ES = 'Introducir el saldo de efectivo';es_CO = 'Introducir el saldo de efectivo';tr = 'Nakit bakiyesini girin';it = 'Inserimento del saldo in contanti';de = 'Kassenbestand eingeben'", MainLanguageCode));
	Query.SetParameter("UseDefaultTypeOfAccounting"	, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[0].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeInventoryDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency
	|INTO Header
	|FROM
	|	Document.OpeningBalanceEntry AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OpeningBalanceEntryInventory.Order AS Order,
	|	OpeningBalanceEntryInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OpeningBalanceEntryInventory.Period AS Period,
	|	OpeningBalanceEntryInventory.Company AS Company,
	|	OpeningBalanceEntryInventory.PresentationCurrency AS PresentationCurrency,
	|	OpeningBalanceEntryInventory.StructuralUnit AS StructuralUnit,
	|	OpeningBalanceEntryInventory.GLAccount AS GLAccount,
	|	OpeningBalanceEntryInventory.Products AS Products,
	|	OpeningBalanceEntryInventory.Characteristic AS Characteristic,
	|	OpeningBalanceEntryInventory.Batch AS Batch,
	|	OpeningBalanceEntryInventory.SalesOrder AS SalesOrder,
	|	OpeningBalanceEntryInventory.Quantity AS Quantity,
	|	OpeningBalanceEntryInventory.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	OpeningBalanceEntryInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord,
	|	OpeningBalanceEntryInventory.Ownership AS Ownership,
	|	OpeningBalanceEntryInventory.InventoryAccountType AS InventoryAccountType,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	OpeningBalanceEntryInventory.CorrInventoryAccountType AS CorrInventoryAccountType
	|FROM
	|	(SELECT
	|		0 AS Order,
	|		OpeningBalanceEntryInventory.LineNumber AS LineNumber,
	|		OpeningBalanceEntryInventory.Ref.Date AS Period,
	|		&Company AS Company,
	|		&PresentationCurrency AS PresentationCurrency,
	|		OpeningBalanceEntryInventory.StructuralUnit AS StructuralUnit,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN OpeningBalanceEntryInventory.InventoryGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS GLAccount,
	|		OpeningBalanceEntryInventory.Products AS Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN OpeningBalanceEntryInventory.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		CASE
	|			WHEN &UseBatches
	|					AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|						OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|				THEN OpeningBalanceEntryInventory.Batch
	|			ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|		END AS Batch,
	|		CASE
	|			WHEN OpeningBalanceEntryInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|					OR OpeningBalanceEntryInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|				THEN UNDEFINED
	|			ELSE OpeningBalanceEntryInventory.SalesOrder
	|		END AS SalesOrder,
	|		CASE
	|			WHEN VALUETYPE(OpeningBalanceEntryInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN OpeningBalanceEntryInventory.Quantity
	|			ELSE OpeningBalanceEntryInventory.Quantity * OpeningBalanceEntryInventory.MeasurementUnit.Factor
	|		END AS Quantity,
	|		OpeningBalanceEntryInventory.Amount AS Amount,
	|		VALUE(AccountingRecordType.Debit) AS RecordKindAccountingJournalEntries,
	|		&InventoryIncrease AS ContentOfAccountingRecord,
	|		OpeningBalanceEntryInventory.Ownership AS Ownership,
	|		CASE
	|			WHEN OpeningBalanceEntryInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|				THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|			WHEN OpeningBalanceEntryInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|				THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|			WHEN OpeningBalanceEntryInventory.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
	|				THEN VALUE(Enum.InventoryAccountTypes.WorkInProgress)
	|			ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|		END AS InventoryAccountType,
	|		VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType
	|	FROM
	|		Document.OpeningBalanceEntry.Inventory AS OpeningBalanceEntryInventory
	|			INNER JOIN Catalog.Products AS CatalogProducts
	|			ON OpeningBalanceEntryInventory.Products = CatalogProducts.Ref
	|			LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|			ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|				AND (CatalogProducts.UseBatches)
	|			LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|			ON OpeningBalanceEntryInventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|				AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|			LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|			ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|	WHERE
	|		OpeningBalanceEntryInventory.Ref = &Ref
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		1,
	|		EnteringOpeningBalancesDirectCost.LineNumber,
	|		EnteringOpeningBalancesDirectCost.Ref.Date,
	|		&Company,
	|		&PresentationCurrency,
	|		EnteringOpeningBalancesDirectCost.StructuralUnit,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN EnteringOpeningBalancesDirectCost.GLExpenseAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END,
	|		VALUE(Catalog.Products.EmptyRef),
	|		VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|		VALUE(Catalog.ProductsBatches.EmptyRef),
	|		EnteringOpeningBalancesDirectCost.SalesOrder,
	|		0,
	|		EnteringOpeningBalancesDirectCost.Amount,
	|		VALUE(AccountingRecordType.Debit),
	|		&ExpediturePosting,
	|		&OwnInventory,
	|		VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|		VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType
	|	FROM
	|		Document.OpeningBalanceEntry.DirectCost AS EnteringOpeningBalancesDirectCost
	|	WHERE
	|		EnteringOpeningBalancesDirectCost.Ref = &Ref) AS OpeningBalanceEntryInventory
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.CorrInventoryAccountType
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	0 AS Order,
	|	OpeningBalanceEntryInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OpeningBalanceEntryInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	OpeningBalanceEntryInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN OpeningBalanceEntryInventory.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	OpeningBalanceEntryInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OpeningBalanceEntryInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN OpeningBalanceEntryInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(OpeningBalanceEntryInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OpeningBalanceEntryInventory.Quantity
	|		ELSE OpeningBalanceEntryInventory.Quantity * OpeningBalanceEntryInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	OpeningBalanceEntryInventory.Ownership AS Ownership
	|FROM
	|	Document.OpeningBalanceEntry.Inventory AS OpeningBalanceEntryInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON OpeningBalanceEntryInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON OpeningBalanceEntryInventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	OpeningBalanceEntryInventory.Ref = &Ref
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&InventoryIncrease AS Content
	|FROM
	|	Document.OpeningBalanceEntry.Inventory AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	UNDEFINED,
	|	0,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	&ExpediturePosting
	|FROM
	|	Document.OpeningBalanceEntry.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	0 AS Order,
	|	MIN(Inventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Header.Date AS Period,
	|	Header.Company AS Company,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.Products AS Products,
	|	CASE
	|		WHEN Inventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Inventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Inventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Inventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	Inventory.Document AS CostLayer,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN Inventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Inventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	SUM(CASE
	|			WHEN VALUETYPE(Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN Inventory.Quantity
	|			ELSE Inventory.Quantity * Inventory.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	TRUE AS SourceRecord,
	|	Inventory.Ownership AS Ownership,
	|	CASE
	|		WHEN Inventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		WHEN Inventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		WHEN Inventory.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
	|			THEN VALUE(Enum.InventoryAccountTypes.WorkInProgress)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.OpeningBalanceEntry.Inventory AS Inventory
	|		ON (Inventory.Ref = Header.Ref)
	|		INNER JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON (Inventory.StructuralUnit = BusinessUnits.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (Inventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (Inventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	&UseFIFO
	|
	|GROUP BY
	|	Header.Date,
	|	Header.Company,
	|	Header.PresentationCurrency,
	|	Inventory.StructuralUnit,
	|	Inventory.Products,
	|	CASE
	|		WHEN Inventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Inventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Inventory.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Inventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	Inventory.Document,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN Inventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Inventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	Inventory.Ownership,
	|	CASE
	|		WHEN Inventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		WHEN Inventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		WHEN Inventory.InventoryGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
	|			THEN VALUE(Enum.InventoryAccountTypes.WorkInProgress)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	TableInventory.Ref.Date AS EventDate,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	1 AS Quantity,
	|	TableInventory.Ownership AS Ownership
	|FROM
	|	Document.OpeningBalanceEntry.Inventory AS TableInventory
	|		INNER JOIN Document.OpeningBalanceEntry.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TableInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TableInventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	TableInventory.Ref = &Ref
	|	AND TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Header.Date AS Period,
	|	Header.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(TableInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN TableInventory.Quantity
	|		ELSE TableInventory.Quantity * TableInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(TableInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN TableInventory.Reserve
	|		ELSE TableInventory.Reserve * TableInventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount
	|INTO InventoryReserved
	|FROM
	|	Document.OpeningBalanceEntry.Inventory AS TableInventory
	|		INNER JOIN Header AS Header
	|		ON TableInventory.Ref = Header.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TableInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TableInventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|	AND TableInventory.SalesOrder <> UNDEFINED
	|	AND TableInventory.Reserve > 0
	|	AND TableInventory.Quantity > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryReserved.LineNumber AS LineNumber,
	|	InventoryReserved.RecordType AS RecordType,
	|	InventoryReserved.Period AS Period,
	|	InventoryReserved.Company AS Company,
	|	InventoryReserved.StructuralUnit AS StructuralUnit,
	|	InventoryReserved.Products AS Products,
	|	InventoryReserved.Characteristic AS Characteristic,
	|	InventoryReserved.Batch AS Batch,
	|	InventoryReserved.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN InventoryReserved.Reserve > InventoryReserved.Quantity
	|			THEN InventoryReserved.Quantity
	|		ELSE InventoryReserved.Reserve
	|	END AS Quantity,
	|	InventoryReserved.GLAccount AS GLAccount
	|FROM
	|	InventoryReserved AS InventoryReserved");
	
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("OBEAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseReservation", Constants.UseInventoryReservation.Get());
	Query.SetParameter("InventoryIncrease", NStr("en = 'Inventory receipt'; ru = 'Прием запасов';pl = 'Przyjęcie zapasów';es_ES = 'Recibo del inventario';es_CO = 'Recibo del inventario';tr = 'Stok fişi';it = 'Ricevimento di scorte';de = 'Bestandszugang'", MainLanguageCode));
	Query.SetParameter("ExpediturePosting", NStr("en = 'Costs capitalization'; ru = 'Оприходование затрат';pl = 'Księgowanie kosztów';es_ES = 'Capitalización de costes';es_CO = 'Capitalización de costes';tr = 'Maliyet sermayelendirmesi';it = 'Capitalizzazione dei costi';de = 'Kosten-Kapitalisierung'", MainLanguageCode));
	Query.SetParameter("InventoryReception", NStr("en = 'Inventory receipt'; ru = 'Прием запасов';pl = 'Przyjęcie zapasów';es_ES = 'Recibo del inventario';es_CO = 'Recibo del inventario';tr = 'Stok fişi';it = 'Ricevimento di scorte';de = 'Bestandszugang'", MainLanguageCode));
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", ResultsArray[4].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[3].Unload());
	EndIf;
	
	// Serial numbers
	QueryResult = ResultsArray[5].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", ResultsArray[7].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationFixedAssetsDataInitialization(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties)

	Query = New Query(
	"SELECT
	|	DocumentTable.Ref.Date AS Date,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.FixedAsset.DepreciationMethod AS DepreciationMethod,
	|	DocumentTable.FixedAsset.InitialCost AS OriginalCost,
	|	DocumentTable.FixedAssetCurrentCondition AS FixedAssetCurrentCondition,
	|	DocumentTable.CurrentOutputQuantity AS CurrentOutputQuantity,
	|	DocumentTable.CurrentDepreciationAccrued AS CurrentDepreciationAccrued,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	TRUE AS EnterIntoService,
	|	DocumentTable.AccrueDepreciation AS AccrueDepreciation,
	|	CASE
	|		WHEN DocumentTable.CurrentDepreciationAccrued <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccrueDepreciationInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	DocumentTable.DepreciationChargeItem AS ExpenseItem,
	|	DocumentTable.RegisterDepreciationCharge AS RegisterExpense,
	|	DocumentTable.BusinessLine AS BusinessLine
	|INTO TemporaryTableFixedAssets
	|FROM
	|	Document.OpeningBalanceEntry.FixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	DocumentTable.FixedAssetCurrentCondition AS State,
	|	DocumentTable.AccrueDepreciation AS AccrueDepreciation,
	|	DocumentTable.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.OriginalCost AS CostForDepreciationCalculation,
	|	DocumentTable.AccrueDepreciationInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	CASE
	|		WHEN DocumentTable.RegisterExpense
	|			THEN DocumentTable.ExpenseItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS ExpenseItem,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.OriginalCost AS Cost,
	|	0 AS Depreciation,
	|	&FixedAssetAcceptanceForAccounting AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.OriginalCost > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	VALUE(AccumulationRecordType.Receipt),
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.FixedAsset,
	|	0,
	|	DocumentTable.CurrentDepreciationAccrued,
	|	&AccrueDepreciation
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.CurrentDepreciationAccrued > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.CurrentOutputQuantity AS Quantity
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.DepreciationMethod = VALUE(Enum.FixedAssetDepreciationMethods.ProportionallyToProductsVolume)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.OriginalCost AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.FixedAsset.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&FixedAssetAcceptanceForAccounting AS Content
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.OriginalCost > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.CurrentDepreciationAccrued,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.FixedAsset.DepreciationAccount,
	|	UNDEFINED,
	|	0,
	|	&AccrueDepreciation
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.CurrentDepreciationAccrued > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("OBEAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("FixedAssetAcceptanceForAccounting", NStr("en = 'Enter opening balance of capital assets'; ru = 'Ввод начальных остатков по внеоборотным активам';pl = 'Wprowadzenie sald środków trwałych';es_ES = 'Introducir el saldo de apertura de los activos del capital';es_CO = 'Introducir el saldo de apertura de los activos del capital';tr = 'Sabit aktiflerin açılış bakiyesini gir';it = 'Inserimento del saldo di apertura dello stato patrimoniale';de = 'Anfangssaldo des Kapitalvermögens eingeben'", MainLanguageCode));
	Query.SetParameter("AccrueDepreciation", NStr("en = 'Enter opening balance for depreciation'; ru = 'Ввод начальных остатков по амортизации';pl = 'Wprowadzenie sald amortyzacji';es_ES = 'Introducir el saldo de apertura para una depreciación';es_CO = 'Introducir el saldo de apertura para una depreciación';tr = 'Amortisman açılış bakiyesini gir';it = 'Inserimento del saldo di apertura per l''ammortamento';de = 'Anfangssaldo für Abschreibungen eingeben'", MainLanguageCode));
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetStatus", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetParameters", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetUsage", ResultsArray[4].Unload());
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[5].Unload());
	EndIf;

EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export
	
	AccountingSection = Common.ObjectAttributeValue(DocumentRefOpeningBalanceEntry, "AccountingSection");
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	If AccountingSection = Enums.OpeningBalanceAccountingSections.FixedAssets Then
	
		DataInitializationFixedAssetsDataInitialization(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.Inventory Then
	
		InitializeInventoryDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.CashAssets Then
	
		DocumentDataInitializationCashAssets(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.AccountsReceivablePayable Then
	
		InitializeDocumentDataAccountsReceivable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeDocumentDataAccountsPayable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeDocumentDataUnallocatedExpenses(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeDocumentDataIncomeAndExpensesCashMethod(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeDocumentDataIncomeAndExpensesRetained(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeInvoicesAndOrdersPaymentDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		
	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.Taxes Then
	
		InitializeDocumentDataTaxesSettlements(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.Payroll Then
	
		InitializeDocumentDataPayroll(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.AdvanceHolders Then
		
		InitializeDocumentDataAdvanceHolders(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.Other
		And StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
	
		GenerateTableAccountingJournalEntries(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Control

// Control of the accounting section CashAssets.
//
Procedure RunControlCashAssets(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsCashAssetsChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange Then
		
		Query = New Query;
		Query.Text = AccumulationRegisters.CashAssets.BalancesControlQueryText();
		
		AccumulationRegisters.CashAssets.GenerateTableCashAssetsBalances(StructureTemporaryTables, AdditionalProperties);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Date", AdditionalProperties.ForPosting.Date);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on cash.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AccountsReceivable.
//
Procedure RunControlCustomerAccounts(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsAccountsReceivableChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsAccountsReceivableChange.Company AS Company,
		|						RegisterRecordsAccountsReceivableChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
		|						RegisterRecordsAccountsReceivableChange.Contract AS Contract,
		|						RegisterRecordsAccountsReceivableChange.Document AS Document,
		|						RegisterRecordsAccountsReceivableChange.Order AS Order,
		|						RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange)) AS AccountsReceivableBalances
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
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on accounts receivable.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AccountsPayable.
//
Procedure RunControlAccountsPayable(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "TransferAccountsPayableChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
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
		
		ResultsArray = Query.Execute();
		
		// Negative balance on accounts payable.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AdvanceHolders.
//
Procedure RunControlAdvanceHolders(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsAdvanceHoldersChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange Then
		
		Query = New Query(
		"SELECT
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
		|				(Company, PresentationCurrency, Employee, Currency, Document) In
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
		|	(VALUETYPE(AdvanceHoldersBalances.Document) = Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) > 0
		|			OR VALUETYPE(AdvanceHoldersBalances.Document) <> Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on advance holder payments.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section Inventory.
//
Procedure RunControlInventory(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;

	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
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
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty() Then
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrorsAsList(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
		// Negative balance of inventory and cost accounting.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrorsAsList(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
		// Negative balance of products in reserve.
		ElsIf Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
		Else
			// Negative balance of inventory with reserves.
			DriveServer.CheckAvailableStockBalance(DocumentObjectOpeningBalanceEntry, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;

EndProcedure

// Control of the accounting section FixedAssets.
//
Procedure RunControlFixedAssets(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;

	// If temporary tables
	// "RegisterRecordsFixedAssetsChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsFixedAssetsChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsFixedAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.FixedAsset) AS FixedAssetPresentation,
		|	ISNULL(FixedAssetsBalance.CostBalance, 0) AS CostBalance,
		|	ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS DepreciationBalance,
		|	RegisterRecordsFixedAssetsChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsFixedAssetsChange.CostChanging AS CostChanging,
		|	RegisterRecordsFixedAssetsChange.CostChanging + ISNULL(FixedAssetsBalance.CostBalance, 0) AS DepreciatedCost,
		|	RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite AS DepreciationBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationOnWrite AS DepreciationOnWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate AS DepreciationUpdate,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate + ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS AccuredDepreciation
		|FROM
		|	RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange
		|		LEFT JOIN AccumulationRegister.FixedAssets.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, FixedAsset) In
		|					(SELECT
		|						RegisterRecordsFixedAssetsChange.Company AS Company,
		|						RegisterRecordsFixedAssetsChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset
		|					FROM
		|						RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange)) AS FixedAssetsBalance
		|		ON (RegisterRecordsFixedAssetsChange.Company = RegisterRecordsFixedAssetsChange.Company)
		|			AND (RegisterRecordsFixedAssetsChange.PresentationCurrency = RegisterRecordsFixedAssetsChange.PresentationCurrency)
		|			AND (RegisterRecordsFixedAssetsChange.FixedAsset = RegisterRecordsFixedAssetsChange.FixedAsset)
		|WHERE
		|	(ISNULL(FixedAssetsBalance.CostBalance, 0) < 0
		|			OR ISNULL(FixedAssetsBalance.DepreciationBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		QueryResult = Query.Execute();
		
		// Negative balance of property depriciation.
		If Not QueryResult.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = QueryResult.Select();
			DriveServer.ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	AccountingSection = Common.ObjectAttributeValue(DocumentRefOpeningBalanceEntry, "AccountingSection");
	
	If Not DriveServer.RunBalanceControl() Then
		If AccountingSection = Enums.OpeningBalanceAccountingSections.CashAssets Then
			AccumulationRegisters.CashAssets.IndependentCashAssetsRunControl(
				DocumentRefOpeningBalanceEntry,
				AdditionalProperties,
				Cancel,
				PostingDelete);
		EndIf;
		
		Return;
	EndIf;

	If AccountingSection = Enums.OpeningBalanceAccountingSections.FixedAssets Then

		RunControlFixedAssets(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.Inventory Then

		RunControlInventory(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.CashAssets Then

		RunControlCashAssets(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.AccountsReceivablePayable Then

		RunControlCustomerAccounts(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);
		RunControlAccountsPayable(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	ElsIf AccountingSection = Enums.OpeningBalanceAccountingSections.AdvanceHolders Then
		
		RunControlAdvanceHolders(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	EndIf;

EndProcedure

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("ProductGLAccounts") Then
		
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		
	ElsIf StructureData.Property("CounterpartyGLAccounts") Then
		
		If StructureData.TabName = "AccountsReceivable" Then
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
			GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
		ElsIf StructureData.TabName = "AccountsPayable" Then
			GLAccountsForFilling.Insert("AccountsPayableGLAccount", StructureData.AccountsPayableGLAccount);
			GLAccountsForFilling.Insert("AdvancesPaidGLAccount", StructureData.AdvancesPaidGLAccount);
		EndIf;

	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "FixedAssets" Then
		IncomeAndExpenseStructure.Insert("DepreciationChargeItem", StructureData.DepreciationChargeItem);
		IncomeAndExpenseStructure.Insert("RegisterDepreciationCharge", StructureData.RegisterDepreciationCharge);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "FixedAssets" Then
		Result.Insert("GLExpenseAccount", "DepreciationChargeItem");
	EndIf;
	
	Return Result
	
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