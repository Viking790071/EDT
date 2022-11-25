#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCashVoucher, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency",					DocumentRefCashVoucher.CashCurrency);
	Query.SetParameter("LoanContractCurrency",			DocumentRefCashVoucher.LoanContract.SettlementsCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("VATInput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));

	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("CreditPrincipalDebtPayment",	NStr("en = 'Loan principal repayment'; ru = 'Оплата основного долга по кредиту';pl = 'Spłata kwoty głównej pożyczki';es_ES = 'Reembolso del capital del préstamo';es_CO = 'Pago principal del préstamo';tr = 'Borç anapara geri ödemesi';it = 'Pagamento debito principale';de = 'Darlehensrückzahlung'",
														MainLanguageCode));
	Query.SetParameter("CreditInterestPayment",			NStr("en = 'Loan interest repayment'; ru = 'Оплата процентов по кредиту';pl = 'Spłata odsetek kredytowych';es_ES = 'Reembolso del interés del préstamo';es_CO = 'Pago del interés del préstamo';tr = 'Borç faiz ödemesi';it = 'Pagamento degli interessi del prestito';de = 'Rückzahlung der Darlehenszinsen'",
														MainLanguageCode));
	Query.SetParameter("CreditCommissionPayment",		NStr("en = 'Loan Commission repayment'; ru = 'Оплата комиссии по кредиту';pl = 'Opłata prowizji od pożyczki';es_ES = 'Reembolso de la comisión del préstamo';es_CO = 'Pago de la comisión del préstamo';tr = 'Borç komisyon ödemesi';it = 'Pagamento della commisione del prestito';de = 'Rückzahlung der Darlehensprovision'",
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
	|	DocumentTable.OperationKind AS OperationKind,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	DocumentTable.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.CashCR AS CashCR,
	|	DocumentTable.CashCurrency AS CashCurrency,
	|	CAST(DocumentTable.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	DocumentTable.DocumentAmount AS AmountCur,
	|	DocumentTable.RegisterExpense AS RegisterExpense,
	|	DocumentTable.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(CashAccounts.GLAccount, VALUE(Catalog.CashAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS PettyCashGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(CashRegisters.GLAccount, VALUE(Catalog.CashAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CashCRGLAccount,
	|	DocumentTable.TaxKind AS TaxKind,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(TaxTypes.GLAccount, VALUE(Catalog.TaxTypes.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS TaxKindGLAccount,
	|	DocumentTable.Department AS Department,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(LinesOfBusiness.GLAccountCostOfSales, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.Order AS Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS Correspondence,
	|	ISNULL(IncomeAndExpenseItems.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS IncomeAndExpenseType,
	|	DocumentTable.AdvanceHolder AS AdvanceHolder,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(Employees.SettlementsHumanResourcesGLAccount, VALUE(Catalog.Employees.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvanceHolderPersonnelGLAccount,
	|	DocumentTable.RegistrationPeriod AS RegistrationPeriod,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(Employees.AdvanceHoldersGLAccount, VALUE(Catalog.Employees.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvanceHolderAdvanceHoldersGLAccount,
	|	DocumentTable.AdvanceHoldersReceivableGLAccount AS AdvanceHoldersReceivableGLAccount,
	|	DocumentTable.AdvanceHoldersPayableGLAccount AS AdvanceHoldersPayableGLAccount,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccountingOtherSettlements,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.Ref AS Ref
	|INTO TemporaryTableHeader
	|FROM
	|	Document.CashVoucher AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRateSliceLast
	|		ON (AccountingExchangeRateSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|		ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
	|		LEFT JOIN Catalog.LinesOfBusiness AS LinesOfBusiness
	|		ON DocumentTable.BusinessLine = LinesOfBusiness.Ref
	|		LEFT JOIN Catalog.Employees AS Employees
	|		ON DocumentTable.AdvanceHolder = Employees.Ref
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON DocumentTable.ExpenseItem = IncomeAndExpenseItems.Ref
	|		LEFT JOIN Catalog.CashAccounts AS CashAccounts
	|		ON DocumentTable.PettyCash = CashAccounts.Ref
	|		LEFT JOIN Catalog.CashRegisters AS CashRegisters
	|		ON DocumentTable.CashCR = CashRegisters.Ref
	|		LEFT JOIN Catalog.TaxTypes AS TaxTypes
	|		ON DocumentTable.TaxKind = TaxTypes.Ref
	|WHERE
	|	DocumentTable.Ref = &Ref
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
	|	DocumentTable.Contract AS Contract,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableHeader.PettyCash AS PettyCash,
	|	TemporaryTableHeader.Correspondence AS Correspondence,
	|	CASE
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN LoanContractDoc.PrincipalItem
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN LoanContractDoc.InterestItem
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN LoanContractDoc.CommissionItem
	|		ELSE DocumentTable.Item
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|				AND DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Ref AS Ref,
	|	TemporaryTableHeader.Date AS Date,
	|	SUM(CAST(DocumentTable.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|			END AS NUMBER(15, 2))) AS AccountingAmount,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	SUM(CAST(DocumentTable.EPDAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
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
	|	TemporaryTableHeader.PettyCashGLAccount AS BankAccountCashGLAccount,
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
	|			THEN &CreditPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &CreditInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &CreditCommissionPayment
	|	END AS ContentByTypeOfAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CAST(DocumentTable.VATAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|			END AS NUMBER(15, 2))) AS VATAmount,
	|	SUM(CAST(DocumentTable.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|			END AS NUMBER(15, 2))) - SUM(CAST(DocumentTable.VATAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|			END AS NUMBER(15, 2))) AS AmountExcludesVAT,
	|	TemporaryTableHeader.Company AS Company,
	|	TemporaryTableHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.DiscountReceivedIncomeItem AS DiscountReceivedIncomeItem
	|INTO TemporaryTablePaymentDetailsPre
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.CashVoucher.PaymentDetails AS DocumentTable
	|			LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRate
	|			ON (AccountingExchangeRate.Currency = &PresentationCurrency)
	|			LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|			ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
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
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Order,
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
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN &CreditPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &CreditInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &CreditCommissionPayment
	|	END,
	|	DocumentTable.Ref,
	|	DocumentTable.VATRate,
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
	|			THEN DocumentTable.DiscountReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	TemporaryTableHeader.CashCurrency,
	|	TemporaryTableHeader.OperationKind,
	|	TemporaryTableHeader.Counterparty,
	|	Counterparties.DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders,
	|	CounterpartyContracts.SettlementsCurrency,
	|	TemporaryTableHeader.PettyCash,
	|	TemporaryTableHeader.Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|				AND DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	TemporaryTableHeader.Date,
	|	TemporaryTableHeader.PettyCashGLAccount,
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
	|	CASE
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN LoanContractDoc.PrincipalItem
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN LoanContractDoc.InterestItem
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN LoanContractDoc.CommissionItem
	|		ELSE DocumentTable.Item
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	DocumentTable.DiscountReceivedIncomeItem
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
	|	TemporaryTable.PettyCash AS PettyCash,
	|	TemporaryTable.Correspondence AS Correspondence,
	|	TemporaryTable.Item AS Item,
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
	|	TemporaryTable.TypeOfAmount AS TypeOfAmount,
	|	TemporaryTable.Employee AS Employee,
	|	TemporaryTable.GLAccountByTypeOfAmount AS GLAccountByTypeOfAmount,
	|	TemporaryTable.ContentByTypeOfAmount AS ContentByTypeOfAmount,
	|	TemporaryTable.VATRate AS VATRate,
	|	TemporaryTable.VATAmount AS VATAmount,
	|	TemporaryTable.AmountExcludesVAT AS AmountExcludesVAT,
	|	TemporaryTable.Company AS Company,
	|	TemporaryTable.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTable.DiscountReceivedIncomeItem AS DiscountReceivedIncomeItem
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
	|	&VATInput AS VATInputGLAccount,
	|	SUM(Payment.AmountExcludesVAT) AS AmountExcludesVAT,
	|	SUM(Payment.VATAmount) AS VATAmount
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
	
	// Register record table creation by account sections.
	GenerateTableCashAssets(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateAdvanceHoldersTable(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTablePayroll(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableMiscellaneousPayable(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableLoanSettlements(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableTaxesSettlements(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableVATIncurred(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRefCashVoucher, StructureAdditionalProperties);
	
	GenerateTableAccountingEntriesData(DocumentRefCashVoucher, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefCashVoucher, StructureAdditionalProperties);

	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefCashVoucher, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefCashVoucher, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefCashVoucher, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefCashVoucher, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCashVoucher, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
		Or StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange
		Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
		Or StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange
		Or StructureTemporaryTables.RegisterRecordsVATIncurredChange
		Or StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCashAssetsChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashAssetsChange.Company AS CompanyPresentation,
		|	RegisterRecordsCashAssetsChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountCashPresentation,
		|	RegisterRecordsCashAssetsChange.Currency AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.PaymentMethod) AS PaymentMethodRepresentation,
		|	RegisterRecordsCashAssetsChange.PaymentMethod AS PaymentMethod,
		|	ISNULL(CashAssetsBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsCashAssetsChange.SumCurChange + ISNULL(CashAssetsBalances.AmountCurBalance, 0) AS BalanceCashAssets,
		|	RegisterRecordsCashAssetsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashAssetsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsCashAssetsChange.AmountChange AS AmountChange,
		|	RegisterRecordsCashAssetsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsCashAssetsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsCashAssetsChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange
		|		LEFT JOIN AccumulationRegister.CashAssets.Balance(&ControlTime, ) AS CashAssetsBalances
		|		ON RegisterRecordsCashAssetsChange.Company = CashAssetsBalances.Company
		|			AND RegisterRecordsCashAssetsChange.PresentationCurrency = CashAssetsBalances.PresentationCurrency
		|			AND RegisterRecordsCashAssetsChange.PaymentMethod = CashAssetsBalances.PaymentMethod
		|			AND RegisterRecordsCashAssetsChange.BankAccountPettyCash = CashAssetsBalances.BankAccountPettyCash
		|			AND RegisterRecordsCashAssetsChange.Currency = CashAssetsBalances.Currency
		|WHERE
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsCashInCashRegistersChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashInCashRegistersChange.Company AS CompanyPresentation,
		|	RegisterRecordsCashInCashRegistersChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsCashInCashRegistersChange.CashCR AS CashCRDescription,
		|	RegisterRecordsCashInCashRegistersChange.CashCR.CashCurrency AS CurrencyPresentation,
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
		|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(&ControlTime, ) AS CashAssetsInRetailCashesBalances
		|		ON RegisterRecordsCashInCashRegistersChange.Company = CashAssetsInRetailCashesBalances.Company
		|			AND RegisterRecordsCashInCashRegistersChange.PresentationCurrency = CashAssetsInRetailCashesBalances.PresentationCurrency
		|			AND RegisterRecordsCashInCashRegistersChange.CashCR = CashAssetsInRetailCashesBalances.CashCR
		|WHERE
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.AccountsReceivable.AdvanceBalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[5].IsEmpty()
			Or Not ResultsArray[6].IsEmpty() Then
			DocumentObjectCashVoucher = DocumentRefCashVoucher.GetObject()
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in cash CR.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in advance on accounts receivable.
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingReturnAdvanceToAccountsRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
	EndIf;
	
EndProcedure

Function DocumentVATRate(DocumentRef) Export
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "PaymentDetails");
	
	Return DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
EndFunction

#EndRegion

#Region Private

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssets(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",					DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashExpense",			NStr("en = 'Cash payment'; ru = 'Форма оплаты: наличными';pl = 'Płatność gotówkowa';es_ES = 'Pago en efectivo';es_CO = 'Pago en efectivo';tr = 'Nakit ödeme';it = 'Pagamento in contanti';de = 'Barzahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&CashExpense AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PaymentMethods.Cash) AS PaymentMethod,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.PettyCash AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.PettyCashGLAccount AS GLAccount
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToAdvanceHolder)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToCounterparty)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.TransferToCashCR)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Taxes)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Item,
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.PettyCashGLAccount,
	|	DocumentTable.PresentationCurrency
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
	|	VALUE(Catalog.PaymentMethods.Cash),
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	-SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
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
	|	VALUE(Catalog.PaymentMethods.Cash),
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	PayrollPayment.Ref.Item,
	|	PayrollPayment.Ref.PettyCash,
	|	PayrollPayment.Ref.CashCurrency,
	|	SUM(CAST(PayrollSheetEmployees.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition))
	|			END AS NUMBER(15, 2))),
	|	MIN(PayrollPayment.Ref.DocumentAmount),
	|	-SUM(CAST(PayrollSheetEmployees.PaymentAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition))
	|			END AS NUMBER(15, 2))),
	|	-MIN(PayrollPayment.Ref.DocumentAmount),
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollPayment.Ref.PettyCash.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|FROM
	|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
	|		INNER JOIN Document.CashVoucher.PayrollPayment AS PayrollPayment
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfPettyCashe
	|			ON PayrollPayment.Ref.CashCurrency = ExchangeRateOfPettyCashe.Currency
	|		ON PayrollSheetEmployees.Ref = PayrollPayment.Statement
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|WHERE
	|	PayrollPayment.Ref = &Ref
	|	AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|
	|GROUP BY
	|	PayrollPayment.Ref.Date,
	|	PayrollPayment.Ref.Item,
	|	PayrollPayment.Ref.PettyCash,
	|	PayrollPayment.Ref.CashCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollPayment.Ref.PettyCash.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.CashCR AS CashCR,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.CashCRGLAccount AS GLAccount,
	|	&CashFundsReceipt AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.TransferToCashCR)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.CashCR,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.CashCRGLAccount
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	CashCR,
	|	Currency,
	|	GLAccount";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref",					DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CashFundsReceipt",		NStr("en = 'Cash transfer to cash register'; ru = 'Перемещение денежных средств в кассу ККМ';pl = 'Przeniesienie gotówki do kasy fiskalnej';es_ES = 'Transferencia de efectivo a la caja registradora';es_CO = 'Transferencia de efectivo a la caja registradora';tr = 'Yazar kasaya nakit transferi';it = 'Trasferimento di denaro nel registratore di cassa';de = 'Überweisung an die Kasse'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("ExchangeRateMethod", 	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
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
Procedure GenerateAdvanceHoldersTable(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AdvanceHolderDebtEmergence",	NStr("en = 'Payment to advance holder'; ru = 'Выдача денег подотчетнику';pl = 'Płatność dla zaliczkobiorcy';es_ES = 'Pago al titular de anticipo';es_CO = 'Pago al titular de anticipo';tr = 'Avans sahibine ödeme';it = 'Pagamento alla persona che ha anticipato';de = 'Zahlung an die abrechnungspflichtige Person'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&AdvanceHolderDebtEmergence AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.PettyCash AS PettyCash,
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
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN DocumentTable.AdvanceHoldersReceivableGLAccount
	|		ELSE DocumentTable.AdvanceHoldersPayableGLAccount
	|	END AS GLAccount
	|INTO TemporaryTableAdvanceHolders
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToAdvanceHolder)
	|
	|GROUP BY
	|	DocumentTable.PettyCash,
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
Procedure GenerateTableAccountsPayable(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",				DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AppearenceOfVendorAdvance",		NStr("en = 'Advance payment to supplier'; ru = 'Аванс поставщику';pl = 'Zaliczka dla dostawcy';es_ES = 'Pago del anticipo al proveedor';es_CO = 'Pago anticipado al proveedor';tr = 'Tedarikçiye avans ödeme';it = 'Pagamento anticipato al fornitore';de = 'Vorauszahlung an den Lieferanten'", MainLanguageCode));
	Query.SetParameter("VendorObligationsRepayment",	NStr("en = 'Payment to supplier'; ru = 'Погашение обязательств поставщика';pl = 'Płatność dla dostawcy';es_ES = 'Pago al proveedor';es_CO = 'Pago al proveedor';tr = 'Tedarikçiye ödeme';it = 'Pagamento al fornitore';de = 'Zahlung an den Lieferanten'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",		NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod", 		StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", 	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
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
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.PettyCash AS PettyCash,
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
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
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.PettyCash,
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Document,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements
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
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefCashVoucher, StructureAdditionalProperties)
	
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)";
	
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
	
	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("CustomerAdvanceRepayment",		NStr("en = 'Refund to customer'; ru = 'Возврат покупателю';pl = 'Zwrot dla nabywcy';es_ES = 'Devolución al cliente';es_CO = 'Devolución al cliente';tr = 'Müşteriye para iadesi';it = 'Rimborsato al cliente';de = 'Rückerstattung an den Kunden'", MainLanguageCode));
	Query.SetParameter("AppearenceOfCustomerLiability",	NStr("en = 'Payment to customer'; ru = 'Возникновение обязательств покупателя';pl = 'Płatność do klienta';es_ES = 'Pago al cliente';es_CO = 'Pago al cliente';tr = 'Müşteriye ödeme';it = 'Pagamento al cliente';de = 'Zahlung an den Kunden'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
	|	TableBalances.PresentationCurrency,
	|	TableBalances.Order,
	|	TableBalances.Counterparty,
	|	TableBalances.Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTablePaymentDetails.PettyCash AS PettyCash,
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|	AND TemporaryTablePaymentDetails.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.PettyCash,
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
Procedure GenerateTablePayroll(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",				DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("RepaymentLiabilitiesToEmployees",	NStr("en = 'Payroll payment'; ru = 'Погашение обязательств перед персоналом';pl = 'Płatności z tytułu płac';es_ES = 'Pago de nómina';es_CO = 'Pago de nómina';tr = 'Bordro ödemesi';it = 'Pagamento busta paga';de = 'Zahlung der Gehaltsabrechnung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",		StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
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
	|				Document.CashVoucher.PayrollPayment AS PayrollPayment
	|			WHERE
	|				PayrollPayment.Ref = &Ref
	|				AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary))";
	
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
	|	PayrollSheetEmployees.Ref.SettlementsCurrency AS Currency,
	|	PayrollSheetEmployees.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	SUM(CAST(PayrollSheetEmployees.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition))
	|		END AS NUMBER(15, 2))) AS Amount,
	|	SUM(PayrollSheetEmployees.SettlementsAmount) AS AmountCur,
	|	-SUM(CAST(PayrollSheetEmployees.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.Rate * AccountingExchangeRate.Repetition / (AccountingExchangeRate.Rate * ExchangeRateOfPettyCashe.Repetition))
	|		END AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(PayrollSheetEmployees.SettlementsAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollSheetEmployees.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	&RepaymentLiabilitiesToEmployees AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollPayment.Ref.PettyCash.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS PettyCashGLAccount
	|INTO TemporaryTablePayroll
	|FROM
	|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
	|		INNER JOIN Document.CashVoucher.PayrollPayment AS PayrollPayment
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS ExchangeRateOfPettyCashe
	|			ON PayrollPayment.Ref.CashCurrency = ExchangeRateOfPettyCashe.Currency
	|		ON PayrollSheetEmployees.Ref = PayrollPayment.Statement
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRate
	|		ON (TRUE)
	|WHERE
	|	PayrollPayment.Ref = &Ref
	|	AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|
	|GROUP BY
	|	PayrollPayment.Ref.Date,
	|	PayrollSheetEmployees.Ref.StructuralUnit,
	|	PayrollSheetEmployees.Employee,
	|	PayrollSheetEmployees.Ref.SettlementsCurrency,
	|	PayrollSheetEmployees.Ref.RegistrationPeriod,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollSheetEmployees.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	PayrollPayment.Ref.PettyCash,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PayrollPayment.Ref.PettyCash.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Department,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.RegistrationPeriod,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	DocumentTable.AdvanceHolderPersonnelGLAccount,
	|	&RepaymentLiabilitiesToEmployees,
	|	DocumentTable.PettyCashGLAccount
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Department,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.RegistrationPeriod,
	|	DocumentTable.AdvanceHolderPersonnelGLAccount,
	|	DocumentTable.PettyCashGLAccount
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
	
	// Setting the exclusive lock for the controlled balances of salary payable.
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
Procedure GenerateTableIncomeAndExpenses(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("CostsReflection",				NStr("en = 'Expenses incurred'; ru = 'Отражение расходов';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	2 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN DocumentTable.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			THEN DocumentTable.Department
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN DocumentTable.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			THEN DocumentTable.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END AS BusinessLine,
	|	DocumentTable.ExpenseItem AS IncomeAndExpenseItem,
	|	DocumentTable.Correspondence AS GLAccount,
	|	&CostsReflection AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.RegisterExpense
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Other)
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
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
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
	|	DocumentTable.DiscountReceivedGLAccount,
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
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	DocumentTable.DiscountReceivedGLAccount
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Content",						NStr("en = 'Expenses incurred'; ru = 'Списание денежных средств на произвольный счет';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("ContentTransferToCashCR",		NStr("en = 'Cash transfer to cash register'; ru = 'Перемещение денежных средств в кассу ККМ';pl = 'Przeniesienie gotówki do kasy fiskalnej';es_ES = 'Transferencia de efectivo a la caja registradora';es_CO = 'Transferencia de efectivo a la caja registradora';tr = 'Yazar kasaya nakit transferi';it = 'Trasferimento di denaro nel registratore di cassa';de = 'Überweisung an die Kasse'", MainLanguageCode));
	Query.SetParameter("TaxPay",						NStr("en = 'Tax payment'; ru = 'Оплата налога';pl = 'Zapłata podatku';es_ES = 'Pago de impuestos';es_CO = 'Pago de impuestos';tr = 'Vergi ödemesi';it = 'Pagamento delle tasse';de = 'Steuerzahlung'", MainLanguageCode));
	Query.SetParameter("ContentVAT",					NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ContentVATOnAdvance",			NStr("en = 'VAT charged on advance payment'; ru = 'НДС с авансов';pl = 'VAT zaliczka z góry';es_ES = 'El IVA cobrado del pago anticipado';es_CO = 'El IVA cobrado del pago anticipado';tr = 'Avans ödemenin KDV''si';it = 'IVA addebitata sul pagamento anticipato';de = 'USt. berechnet auf Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("VATAdvancesToSuppliers",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("RegisteredForVAT",				StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.Correspondence AS AccountDr,
	|	DocumentTable.PettyCashGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CAST(&Content AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Other)
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CashCRGLAccount,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&ContentTransferToCashCR AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.TransferToCashCR)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.TaxKindGLAccount,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.TaxKind.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.TaxKind.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&TaxPay AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Taxes)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	5,
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
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	7,
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
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	9,
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
	|	10,
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
	|	11,
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
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	12,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
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
	|	13,
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
	|	14,
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
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	16,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.VATInputGLAccount,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToCounterparty)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Taxes))
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
	|	Table.AmountIncome > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Order,
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
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
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|	AND NOT DocumentTable.AdvanceFlag
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
	|							TemporaryTablePaymentDetails AS DocumentTable
	|						WHERE
	|							(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|								OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)))) AS IncomeAndExpensesRetainedBalances
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
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
Procedure GenerateTableTaxesSettlements(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",			DocumentRefCashVoucher);
	Query.SetParameter("Company",		StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime",	New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("TaxPay",		NStr("en = 'Tax payment'; ru = 'Оплата налога';pl = 'Zapłata podatku';es_ES = 'Pago de impuestos';es_CO = 'Pago de impuestos';tr = 'Vergi ödemesi';it = 'Pagamento tassa';de = 'Steuerzahlung'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.TaxKind AS TaxKind,
	|	DocumentTable.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentTable.Amount AS Amount,
	|	&TaxPay AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Taxes)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("UsePaymentCalendar", Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Item AS Item,
	|	VALUE(Catalog.PaymentMethods.Cash) AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	DocumentTable.PettyCash AS BankAccountPettyCash,
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
	|	AND DocumentTable.OperationKind <> VALUE(Enum.OperationTypesCashVoucher.Salary)
	|
	|GROUP BY
	|	DocumentTable.Item,
	|	DocumentTable.Date,
	|	DocumentTable.PettyCash,
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
	|	VALUE(Catalog.PaymentMethods.Cash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.Ref.PettyCash,
	|	DocumentTable.Ref.CashCurrency,
	|	DocumentTable.PlanningDocument,
	|	SUM(-DocumentTable.PaymentAmount)
	|FROM
	|	Document.CashVoucher.PayrollPayment AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.PlanningDocument,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Item,
	|	DocumentTable.Ref.PettyCash,
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
	|	VALUE(Catalog.PaymentMethods.Cash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	-DocumentTable.DocumentAmount
	|FROM
	|	Document.CashVoucher AS DocumentTable
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
	|	Order,
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefCashVoucher, StructureAdditionalProperties)
	
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
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer))
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

Procedure GenerateTableVATInput(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		AND DocumentRefCashVoucher.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
		
		PostAdvancePayments = StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments;
		
		Query = New Query;
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
		|	NULL,
		|	Payment.Counterparty,
		|	SupplierInvoice.Ref,
		|	Payment.VATRate,
		|	Payment.VATInputGLAccount,
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
		|	Payment.Counterparty,
		|	SupplierInvoice.Ref,
		|	Payment.VATRate,
		|	Payment.VATInputGLAccount,
		|	Payment.GLAccountVendorSettlements";
		
		Query.SetParameter("PostAdvancePayments", PostAdvancePayments);
		Query.SetParameter("VATAdvancesToSuppliers", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
		
	Else
	
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
	
	EndIf;
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	If NOT StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments
		Or DocumentRefCashVoucher.OperationKind <> Enums.OperationTypesCashVoucher.Vendor Then
		
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

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Header" Then
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
			And StructureData.ObjectParameters.OperationKind = Enums.OperationTypesCashVoucher.Other Then
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
	
		If ObjectParameters.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
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
		
		ElsIf ObjectParameters.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
			GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
			GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
		EndIf;

		
	ElsIf ObjectParameters.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
		GLAccountsForFilling.Insert("AccountsPayableGLAccount", ObjectParameters.Correspondence);
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, PrintParams = Undefined)
	
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_CashVoucher";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
	
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		Query.Text = 
		"SELECT ALLOWED
		|	CashVoucher.Number AS DocumentNumber,
		|	CashVoucher.Date AS DocumentDate,
		|	CashVoucher.Company AS Company,
		|	CashVoucher.Company.LegalEntityIndividual AS LegalEntityIndividual,
		|	CashVoucher.Company.Prefix AS Prefix,
		|	CashVoucher.Company.DescriptionFull AS CompanyPresentation,
		|	CashVoucher.Issue AS Issue,
		|	CashVoucher.Basis AS Basis,
		|	CashVoucher.DocumentAmount AS DocumentAmount,
		|	CashVoucher.ByDocument AS DocumentAttributesWhichIdentifiesPerson,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN CashVoucher.PettyCash.GLAccount.Code
		|		ELSE """"
		|	END AS CreditSubAccount,
		|	CashVoucher.CashCurrency AS CashCurrency,
		|	CASE
		|		WHEN CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
		|				OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
		|				OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
		|			THEN CashVoucher.Counterparty.DescriptionFull
		|		WHEN CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToAdvanceHolder)
		|				OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee)
		|			THEN CashVoucher.AdvanceHolder.Description
		|		ELSE CashVoucher.Issue
		|	END AS Recipient
		|FROM
		|	Document.CashVoucher AS CashVoucher
		|WHERE
		|	CashVoucher.Ref = &CurrentDocument";
		
		// MultilingualSupport
		
		If PrintParams = Undefined Then
			LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
		Else
			LanguageCode = PrintParams.LanguageCode;
		EndIf;
		
		SessionParameters.LanguageCodeForOutput = LanguageCode;
		DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
		
		// End MultilingualSupport
		
		Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
		
		Header = Query.Execute().Select();
		Header.Next();
		
		SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_CashVoucher_CashExpenseVoucher";
		Template = PrintManagement.PrintFormTemplate("Document.CashVoucher.PF_MXL_CashExpenseVoucher", LanguageCode);
		
		If Template.Areas.Find("TitleWithLogo") <> Undefined
			AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
			
			If ValueIsFilled(Header.Company.LogoFile) Then
				
				TemplateArea = Template.GetArea("TitleWithLogo");
				TemplateArea.Parameters.Fill(Header);
				
				PictureData = AttachedFiles.GetBinaryFileData(Header.Company.LogoFile);
				If ValueIsFilled(PictureData) Then
					
					TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
					
				EndIf;
				
			Else // If images are not selected, print regular header
				
				TemplateArea = Template.GetArea("TitleWithoutLogo");
				TemplateArea.Parameters.Fill(Header);
				
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		Else
			
			MessageText = NStr("en = 'Maybe, custom template is being used. Default procedures of account printing may work incorrectly.'; ru = 'Возможно, используется пользовательский макет. Штатный механизм печати счетов может работать некорректно.';pl = 'Możliwe wykorzystanie niestandardowego szablonu. Domyślne procedury drukowania konta mogą działać niepoprawnie.';es_ES = 'Puede ser que el modelo personalizado se esté utilizando. Procedimientos por defecto de la impresión de cuentas pueden trabajar de forma incorrecta.';es_CO = 'Puede ser que el modelo personalizado se esté utilizando. Procedimientos por defecto de la impresión de cuentas pueden trabajar de forma incorrecta.';tr = 'Özel şablon kullanılıyor olabilir. Hesap yazdırmanın varsayılan prosedürleri yanlış çalışabilir.';it = 'Probabilmente sono utilizzati layout personalizzati. Procedure personalizzate di stampa conti potrebbero lavorare non correttamente.';de = 'Möglicherweise wird eine benutzerdefinierte Vorlage verwendet. Die Standardverfahren für den Kontodruck können falsch funktionieren.'");
			CommonClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		EndIf;
		
		InfoAboutCompany	= DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		
		TemplateArea = Template.GetArea("HeaderPayer");
		
		TemplateArea.Parameters.Fill(Header);
		
		PayerPresentation	= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		TemplateArea.Parameters.PayerPresentation	= PayerPresentation;
		TemplateArea.Parameters.PayerAddress		= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
		TemplateArea.Parameters.PayerPhoneFax		= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "PhoneNumbers,Fax");
		TemplateArea.Parameters.PayerEmail			= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "Email");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("HeaderRecipient");
		
		TemplateArea.Parameters.Recipient	= TrimAll(Header.Recipient);
		If ValueIsFilled(Header.Issue)
			AND TrimAll(Header.Issue) <> TrimAll(Header.Recipient) Then
		
			TemplateArea.Parameters.Issue	= TrimAll(Header.Issue);
		
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("PaymentBasis");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("TotalAmount");
		TemplateArea.Parameters.Total	= Format(Header.DocumentAmount,"NFD=2") + " " + Header.CashCurrency;
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Footer");
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "CashExpenseVoucher") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"CashExpenseVoucher",
			NStr("en = 'Cash voucher'; ru = 'Расходный кассовый ордер';pl = 'Dowód kasowy KW';es_ES = 'Vale de efectivo';es_CO = 'Vale de efectivo';tr = 'Kasa fişi';it = 'Uscita di cassa';de = 'Kassenbeleg'"),
			PrintForm(ObjectsArray, PrintObjects, PrintParameters.Result));
		
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
	PrintCommand.ID							= "CashExpenseVoucher";
	PrintCommand.Presentation				= NStr("en = 'Cash voucher'; ru = 'Расходный кассовый ордер';pl = 'Dowód kasowy KW';es_ES = 'Bono de pago en efectivo';es_CO = 'Vale de efectivo';tr = 'Kasa fişi';it = 'Uscita di cassa';de = 'Kassenbeleg'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
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

Procedure GenerateTableMiscellaneousPayable(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Miscellaneous payables'; ru = 'Оплата прочим контрагентам';pl = 'Różne zobowiązania';es_ES = 'Cuentas a pagar varias';es_CO = 'Cuentas a pagar varias';tr = 'Çeşitli borçlar';it = 'Debiti vari';de = 'Andere Verbindlichkeiten'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Comment",						NStr("en = 'Payment to other accounts'; ru = 'Увеличение долга контрагента';pl = 'Płatność na inne konta';es_ES = 'Pago a otras cuentas';es_CO = 'Pago a otras cuentas';tr = 'Diğer hesaplara ödeme';it = 'Pagamento ad altri conti';de = 'Zahlung an andere Konten'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Ref",							DocumentRefCashVoucher);
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
	|	TemporaryTableHeader.PettyCash AS PettyCash,
	|	TemporaryTablePaymentDetails.Date AS Period
	|INTO TemporaryTableOtherSettlements
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN TemporaryTableHeader AS TemporaryTableHeader
	|		ON (TemporaryTableHeader.AccountingOtherSettlements)
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
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
	|	TemporaryTableHeader.PettyCash,
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

Procedure GenerateTableLoanSettlements(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", 					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("Ref",						DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",				New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",				StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'"));
	Query.SetParameter("CashCurrency",				DocumentRefCashVoucher.CashCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	If DocumentRefCashVoucher.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee Then
		Query.SetParameter("SettlementsOnLoans",			NStr("en = 'Loan issue to employee'; ru = 'Выдача займа сотруднику';pl = 'Udzielenie pożyczki pracownikowi';es_ES = 'Emisión del préstamo al empleado';es_CO = 'Emisión del préstamo al empleado';tr = 'Çalışana kredi düzenle';it = 'Prestito erogato al dipendente';de = 'Darlehensausgabe an Mitarbeiter'"));
	Else
		Query.SetParameter("SettlementsOnLoans",			NStr("en = 'Loan to counterparty'; ru = 'Выдача займа контрагенту';pl = 'Pożyczka dla kontrahenta';es_ES = 'Préstamo a la contrapartida';es_CO = 'Préstamo a la contrapartida';tr = 'Cari hesaba kredi';it = 'Prestito alla controparte';de = 'Darlehen an Geschäftspartner'"));
	EndIf;
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	CASE
	|		WHEN CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		WHEN CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToCounterparty)
	|			THEN VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END AS LoanKind,
	|	CashVoucher.Date AS Date,
	|	CashVoucher.Date AS Period,
	|	&SettlementsOnLoans AS PostingContent,
	|	CashVoucher.AdvanceHolder AS Counterparty,
	|	CashVoucher.DocumentAmount AS PaymentAmount,
	|	CAST(CashVoucher.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtCur,
	|	CAST(CashVoucher.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebt,
	|	CAST(CashVoucher.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtCurForBalance,
	|	CAST(CashVoucher.DocumentAmount * CASE
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
	|	CAST(CashVoucher.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CashVoucher.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CashVoucher.LoanContract AS LoanContract,
	|	CashVoucher.LoanContract.SettlementsCurrency AS Currency,
	|	CashVoucher.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CashVoucher.LoanContract.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CashVoucher.PettyCash AS PettyCash,
	|	FALSE AS DeductedFromSalary
	|INTO TemporaryTableLoanSettlements
	|FROM
	|	Document.CashVoucher AS CashVoucher
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfAccount
	|		ON (ExchangeRateOfAccount.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|		ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfContract
	|		ON (ExchangeRateOfContract.Currency = CashVoucher.LoanContract.SettlementsCurrency)
	|WHERE
	|	(CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToEmployee)
	|			OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToCounterparty))
	|	AND CashVoucher.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
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
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.LoanContract.CommissionGLAccount
	|		ELSE 0
	|	END,
	|	DocumentTable.PettyCash,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)";
	
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
	
	DataLock			= New DataLock;
	LockItem			= DataLock.Add("AccumulationRegister.LoanSettlements");
	LockItem.Mode		= DataLockMode.Exclusive;
	LockItem.DataSource	= QueryResult;
	
	For Each Column In QueryResult.Columns Do
		LockItem.UseFromDataSource(Column.Name, Column.Name);
	EndDo;
	
	DataLock.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesLoanSettlements(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", ResultsArray[QueryNumber].Unload());
	
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

#EndRegion

#Region InfobaseUpdate

Procedure FillInEmployeeGLAccounts() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CashVoucher.Ref AS Ref
	|FROM
	|	Document.CashVoucher AS CashVoucher
	|WHERE
	|	CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToAdvanceHolder)
	|	AND (CashVoucher.AdvanceHoldersReceivableGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			OR CashVoucher.AdvanceHoldersPayableGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))";
	
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
				NStr("en = 'Cannot write document ""%1"". Details: %2'; ru = 'Не удается записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'No se ha podido guardar el documento ""%11"". Detalles: %2';es_CO = 'No se ha podido guardar el documento ""%11"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.CashVoucher,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf