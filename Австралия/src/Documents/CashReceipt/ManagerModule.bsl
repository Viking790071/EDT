#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCashReceipt, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency",					DocumentRefCashReceipt.CashCurrency);
	Query.SetParameter("LoanContractCurrency",			DocumentRefCashReceipt.LoanContract.SettlementsCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);

	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("LoanPrincipalDebtPayment",	NStr("en = 'Loan principal debt payment'; ru = 'Оплата основного долга по займу';pl = 'Opłata kwoty głównej pożyczki';es_ES = 'Pago de la deuda principal del préstamo';es_CO = 'Pago de la deuda principal del préstamo';tr = 'Borç anapara borç ödeme';it = 'Pagamento debito principale';de = 'Zahlung der Darlehenshauptschuld'",
													MainLanguageCode));
	Query.SetParameter("LoanInterestPayment",		NStr("en = 'Loan interest payment'; ru = 'Оплата процентов по займу';pl = 'Opłata odsetek od pożyczki';es_ES = 'Pago del interés del préstamo';es_CO = 'Pago del interés del préstamo';tr = 'Borç faiz ödemesi';it = 'Pagamento degli interessi del prestito';de = 'Darlehenszinszahlung'",
													MainLanguageCode));
	Query.SetParameter("LoanCommissionPayment",		NStr("en = 'Loan Commission payment'; ru = 'Оплата комиссии по кредиту';pl = 'Opłata prowizji od pożyczki';es_ES = 'Pago de la comisión del préstamo';es_CO = 'Pago de la comisión del préstamo';tr = 'Borç komisyon ödemesi';it = 'Pagamento della commisione del prestito';de = 'Zahlung der Darlehensprovision'",
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
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE CAST(DocumentTable.DocumentAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|				END AS NUMBER(15, 2))
	|	END AS Amount,
	|	DocumentTable.DocumentAmount AS AmountCur,
	|	DocumentTable.RegisterIncome AS RegisterIncome,
	|	DocumentTable.IncomeItem AS IncomeItem,
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
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(BusinessUnits.GLAccountInRetail, VALUE(Catalog.BusinessUnits.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(BusinessUnits.MarkupGLAccount, VALUE(Catalog.BusinessUnits.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS StructuralUnitGLAccountMarkup,
	|	DocumentTable.Department AS Department,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(LinesOfBusiness.GLAccountRevenueFromSales, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BusinessLineGLAccountOfRevenueFromSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ISNULL(LinesOfBusiness.GLAccountCostOfSales, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS BusinessLineGLAccountOfSalesCost,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS Correspondence,
	|	ISNULL(IncomeAndExpenseItems.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS IncomeAndExpenseType,
	|	DocumentTable.AdvanceHolder AS AdvanceHolder,
	|	ISNULL(Employees.AdvanceHoldersGLAccount, VALUE(Catalog.Employees.EmptyRef)) AS AdvanceHolderAdvanceHoldersGLAccount,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.Ref AS Ref
	|INTO TemporaryTableHeader
	|FROM
	|	Document.CashReceipt AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRateSliceLast
	|		ON (AccountingExchangeRateSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|		ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
	|		LEFT JOIN Catalog.CashAccounts AS CashAccounts
	|		ON DocumentTable.PettyCash = CashAccounts.Ref
	|		LEFT JOIN Catalog.CashRegisters AS CashRegisters
	|		ON DocumentTable.CashCR = CashRegisters.Ref
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON DocumentTable.StructuralUnit = BusinessUnits.Ref
	|		LEFT JOIN Catalog.LinesOfBusiness AS LinesOfBusiness
	|		ON DocumentTable.BusinessLine = LinesOfBusiness.Ref
	|		LEFT JOIN Catalog.Employees AS Employees
	|		ON DocumentTable.AdvanceHolder = Employees.Ref
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON DocumentTable.IncomeItem = IncomeAndExpenseItems.Ref
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
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.ThirdPartyPayerGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ThirdPartyPayerGLAccount,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.ThirdPartyCustomer AS ThirdPartyCustomer,
	|	DocumentTable.ThirdPartyCustomerContract AS ThirdPartyCustomerContract,
	|	DocumentTable.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableHeader.PettyCash AS PettyCash,
	|	TemporaryTableHeader.PettyCashGLAccount AS BankAccountCashGLAccount,
	|	CASE
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN LoanContractDoc.PrincipalItem
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN LoanContractDoc.InterestItem
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN LoanContractDoc.CommissionItem
	|		ELSE DocumentTable.Item
	|	END AS Item,
	|	TemporaryTableHeader.Correspondence AS Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN (DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef))
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|			THEN UNDEFINED
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
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
	|	TemporaryTableHeader.LoanContract AS LoanContract,
	|	DocumentTable.TypeOfAmount AS TypeOfAmount,
	|	TemporaryTableHeader.AdvanceHolder AS Employee,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN LoanContractDoc.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN LoanContractDoc.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN LoanContractDoc.CommissionGLAccount
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
	|	SUM(CAST(DocumentTable.VATAmount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.Multiplicity * ExchangeRateOfPettyCashe.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.Multiplicity * ExchangeRateOfPettyCashe.Multiplicity))
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
	|	TemporaryTableHeader.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.DiscountAllowedExpenseItem AS DiscountAllowedExpenseItem
	|INTO TemporaryTablePaymentDetailsPre
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON TemporaryTableHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Document.LoanContract AS LoanContractDoc
	|		ON TemporaryTableHeader.LoanContract = LoanContractDoc.Ref
	|		INNER JOIN Document.CashReceipt.PaymentDetails AS DocumentTable
	|			LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRate
	|			ON (AccountingExchangeRate.Currency = &PresentationCurrency)
	|			LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|			ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
	|			LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|			ON DocumentTable.Contract = CounterpartyContracts.Ref
	|		ON TemporaryTableHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Contract,
	|	DocumentTable.ThirdPartyCustomer,
	|	DocumentTable.ThirdPartyCustomerContract,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract.SettlementsCurrency,
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
	|	Counterparties.DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders,
	|	TemporaryTableHeader.PettyCash,
	|	TemporaryTableHeader.PettyCashGLAccount,
	|	TemporaryTableHeader.Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN (DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef))
	|				AND TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|			THEN UNDEFINED
	|		WHEN TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
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
	|			THEN LoanContractDoc.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN LoanContractDoc.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN LoanContractDoc.CommissionGLAccount
	|	END,
	|	TemporaryTableHeader.Company,
	|	TemporaryTableHeader.CompanyVATNumber,
	|	TemporaryTableHeader.PresentationCurrency,
	|	CASE
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN LoanContractDoc.PrincipalItem
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN LoanContractDoc.InterestItem
	|		WHEN (TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|				OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty))
	|				AND DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN LoanContractDoc.CommissionItem
	|		ELSE DocumentTable.Item
	|	END,
	|	DocumentTable.DiscountAllowedExpenseItem
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
	|	TemporaryTable.BankAccountCashGLAccount AS BankAccountCashGLAccount,
	|	TemporaryTable.Item AS Item,
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
	|	TemporaryTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	TemporaryTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	TemporaryTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	TemporaryTable.DiscountAllowedGLAccount AS DiscountAllowedGLAccount,
	|	TemporaryTable.VATOutputGLAccount AS VATOutputGLAccount,
	|	TemporaryTable.ThirdPartyPayerGLAccount AS ThirdPartyPayerGLAccount,
	|	TemporaryTable.ThirdPartyCustomer AS ThirdPartyCustomer,
	|	TemporaryTable.ThirdPartyCustomerContract AS ThirdPartyCustomerContract,
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
	|	TemporaryTable.DiscountAllowedExpenseItem AS DiscountAllowedExpenseItem
	|INTO TemporaryTablePaymentDetails
	|FROM
	|	TemporaryTablePaymentDetailsPre AS TemporaryTable
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON TemporaryTable.VATRate = VATRates.Ref";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTableCashAssets(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateAdvanceHoldersTable(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableThirdPartyPayments(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefCashReceipt, StructureAdditionalProperties);
	// Miscellaneous payable
	GenerateTableMiscellaneousPayable(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableLoanSettlements(DocumentRefCashReceipt, StructureAdditionalProperties);
	// End Miscellaneous payable
	GenerateTablePOSSummary(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefCashReceipt, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefCashReceipt, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefCashReceipt, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableVATOutput(DocumentRefCashReceipt, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefCashReceipt, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefCashReceipt, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefCashReceipt, StructureAdditionalProperties);
		
	EndIf;
		
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCashReceipt, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
	 Or StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange
	 Or StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
	 Or StructureTemporaryTables.RegisterRecordsPOSSummaryChange
	 Or StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange
	 Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPOSSummaryChange.LineNumber AS LineNumber,
		|	RegisterRecordsPOSSummaryChange.Company AS CompanyPresentation,
		|	RegisterRecordsPOSSummaryChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsPOSSummaryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsPOSSummaryChange.StructuralUnit.RetailPriceKind.PriceCurrency AS CurrencyPresentation,
		|	ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsPOSSummaryChange.SumCurChange + ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsPOSSummaryChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsPOSSummaryChange.AmountChange AS AmountChange,
		|	RegisterRecordsPOSSummaryChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsPOSSummaryChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsPOSSummaryChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsPOSSummaryChange.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsPOSSummaryChange AS RegisterRecordsPOSSummaryChange
		|		LEFT JOIN AccumulationRegister.POSSummary.Balance(&ControlTime, ) AS POSSummaryBalances
		|		ON RegisterRecordsPOSSummaryChange.Company = POSSummaryBalances.Company
		|			AND RegisterRecordsPOSSummaryChange.PresentationCurrency = POSSummaryBalances.PresentationCurrency
		|			AND RegisterRecordsPOSSummaryChange.StructuralUnit = POSSummaryBalances.StructuralUnit
		|WHERE
		|	ISNULL(POSSummaryBalances.AmountCurBalance, 0) < 0
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
		Query.Text = Query.Text + AccumulationRegisters.AccountsPayable.AdvanceBalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[4].IsEmpty()
			Or Not ResultsArray[5].IsEmpty() Then
			DocumentObjectCashReceipt = DocumentRefCashReceipt.GetObject()
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in cash CR.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in advance on accounts payable.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingReturnAdvanceToAccountsRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
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
Procedure GenerateTableCashAssets(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",						DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",				New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",				StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",      StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashFundsReceipt",			NStr("en = 'Cash received'; ru = 'Приходный кассовый ордер';pl = 'Otrzymano gotówkę';es_ES = 'Efectivo recibido';es_CO = 'Efectivo recibido';tr = 'Alınan nakit';it = 'Cassa ricevuta.';de = 'Barmittel erhalten'", MainLanguageCode));
	Query.SetParameter("RevenueInRetailReceipt",	NStr("en = 'Cash withdrawal from cash register'; ru = 'Выемка из кассы';pl = 'Wypłata gotówki z kasy fiskalnej';es_ES = 'Retiro de efectivo de la caja registradora';es_CO = 'Retiro de efectivo de la caja registradora';tr = 'Yazar kasadan çekilen nakit';it = 'Prelievo di cassa dal registratore di cassa';de = 'Barauszahlung aus der Kasse'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",		StructureAdditionalProperties.ForPosting.ExchangeRateMethod);

	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
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
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.PettyCashGLAccount AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|				OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|			THEN &RevenueInRetailReceipt
	|		ELSE &CashFundsReceipt
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromAdvanceHolder)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Item,
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|				OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|			THEN &RevenueInRetailReceipt
	|		ELSE &CashFundsReceipt
	|	END,
	|	DocumentTable.PresentationCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
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
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount,
	|	&CashFundsReceipt
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.PaymentFromThirdParties))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	PaymentMethod,
	|	CashAssetType,
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
	|	TemporaryTableCashAssets";
	
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
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|	&CashExpense AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
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
	Query.SetParameter("Ref",					DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CashExpense",			NStr("en = 'Cash withdrawal fron cash register'; ru = 'Списание со счета из кассы ККМ';pl = 'Wypłata gotówki z kasy fiskalnej';es_ES = 'Retiro de efectivo de la caja registradora';es_CO = 'Retiro de efectivo de la caja registradora';tr = 'Yazar kasadan çekilen nakit';it = 'Prelievo di cassa dal registratore di cassa';de = 'Barauszahlung aus der Kasse'", MainLanguageCode));
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
Procedure GenerateAdvanceHoldersTable(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("RepaymentOfAdvanceHolderDebt",	NStr("en = 'Refund from advance holder'; ru = 'Погашение долга подотчетника';pl = 'Zwrot od zaliczkobiórcy';es_ES = 'Devolución del titular de anticipo';es_CO = 'Devolución del titular de anticipo';tr = 'Avans sahibinden iade';it = 'Rimborsato dalla persona che ha anticipato';de = 'Rückerstattung von der abrechnungspflichtigen Person'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.AdvanceHolder AS Employee,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.AdvanceHolderAdvanceHoldersGLAccount AS GLAccount,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord
	|INTO TemporaryTableAdvanceHolders
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromAdvanceHolder)
	|
	|GROUP BY
	|	DocumentTable.PettyCash,
	|	DocumentTable.Document,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.AdvanceHolderAdvanceHoldersGLAccount
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
Procedure GenerateTableCustomerAccounts(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("AppearenceOfCustomerAdvance",	NStr("en = 'Advance payment from customer'; ru = 'Аванс покупателя';pl = 'Zaliczka od nabywcy';es_ES = 'Pago anticipado del cliente';es_CO = 'Pago anticipado del cliente';tr = 'Müşteriden alınan avans ödeme';it = 'Pagamento anticipato da parte del cliente';de = 'Vorauszahlung vom Kunden'", MainLanguageCode));
	Query.SetParameter("CustomerObligationsRepayment",	NStr("en = 'Payment from customer'; ru = 'Оплата от покупателя';pl = 'Płatność od nabywcy';es_ES = 'Pago del cliente';es_CO = 'Pago del cliente';tr = 'Müşteriden ödeme';it = 'Pagamento dal cliente';de = 'Zahlung vom Kunden'", MainLanguageCode));
	Query.SetParameter("ThirdPartyPayment",				NStr("en = 'Payment from third-party'; ru = 'Сторонний платеж';pl = 'Płatność od strony trzeciej';es_ES = 'Pago de terceros';es_CO = 'Pago de terceros';tr = 'Üçüncü taraftan ödeme';it = 'Pagamento da terze parti';de = 'Zahlung von Dritten'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
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
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.PettyCash AS PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
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
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountForPaymentCur,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
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
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	FALSE,
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	UNDEFINED,
	|	TemporaryTablePaymentDetails.Date,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount),
	|	TemporaryTablePaymentDetails.ThirdPartyPayerGLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	&ThirdPartyPayment
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.PaymentFromThirdParties)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.ThirdPartyPayerGLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency
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
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
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
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	&EarlyPaymentDiscount
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
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
	|	TemporaryTableAccountsReceivable";
	
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
Procedure GenerateTableThirdPartyPayments(DocumentRefCashReceipt, StructureAdditionalProperties)
	
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.PaymentFromThirdParties)
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
Procedure GenerateTableAccountsPayable(DocumentRefCashReceipt, StructureAdditionalProperties)
	
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
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)";
	
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

	Query.SetParameter("Ref"							, DocumentRefCashReceipt);
	Query.SetParameter("PointInTime"					, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod"					, StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company"						, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"			, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("VendorAdvanceRepayment"			, NStr("en = 'Advance payment refund from supplier'; ru = 'Возврат аванса от поставщика';pl = 'Zwrot zaliczki od dostawcy';es_ES = 'Devolución del pago adelantado del proveedor';es_CO = 'Devolución del pago anticipado del proveedor';tr = 'Tedarikçiden avans ödeme iadesi';it = 'Il rimborso del pagamento anticipato dal fornitore';de = 'Vorauszahlung Erstattung von Lieferanten'", MainLanguageCode));
	Query.SetParameter("AppearenceOfLiabilityToVendor"	, NStr("en = 'Payment from supplier'; ru = 'Возникновение обязательств перед поставщиком';pl = 'Płatność od dostawcy';es_ES = 'Pago del proveedor';es_CO = 'Pago del proveedor';tr = 'Tedarikçiden ödeme';it = 'Pagamento dal fornitore';de = 'Zahlung vom Lieferanten'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference"				, NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod"				, StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting"		, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
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
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
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
	|	TemporaryTablePaymentDetails.VendorAdvancesGLAccount AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	&VendorAdvanceRepayment AS ContentOfAccountingRecord
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
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
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	TemporaryTablePaymentDetails.PaymentAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.AccountingAmount,
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	&AppearenceOfLiabilityToVendor
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
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
Procedure GenerateTableIncomeAndExpenses(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref"						, DocumentRefCashReceipt);
	Query.SetParameter("Company"					, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"		, StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	Query.SetParameter("PointInTime"				, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeReflection"			, NStr("en = 'Other income'; ru = 'Оприходование денежных средств с произвольного счета';pl = 'Inne przychody';es_ES = 'Otros ingresos';es_CO = 'Otros ingresos';tr = 'Diğer gelir';it = 'Altre entrate';de = 'Sonstige Einnahmen'", MainLanguageCode));
	Query.SetParameter("CostsReflection"			, NStr("en = 'Expenses incurred'; ru = 'Отражение расходов';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference"			, NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount"		, NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem"				, Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem"				, Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("CostOfSales"				, Catalogs.DefaultIncomeAndExpenseItems.GetItem("CostOfSales"));
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("UseDefaultTypeOfAccounting"	, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	Query.SetParameter("Revenue"					, Catalogs.DefaultIncomeAndExpenseItems.GetItem("Revenue"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	DocumentTable.IncomeItem AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.RegisterIncome
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Department,
	|	UNDEFINED,
	|	DocumentTable.BusinessLine,
	|	&Revenue,
	|	DocumentTable.BusinessLineGLAccountOfRevenueFromSales,
	|	&IncomeReflection,
	|	DocumentTable.Amount,
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
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
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
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
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
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
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.Department,
	|	UNDEFINED,
	|	DocumentTable.BusinessLine,
	|	&CostOfSales,
	|	DocumentTable.BusinessLineGLAccountOfSalesCost,
	|	&CostsReflection,
	|	0,
	|	DocumentTable.Cost,
	|	FALSE
	|FROM
	|	TemporaryTableCost AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	10,
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
	|	11,
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
	|	12,
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
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
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
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Content",						NStr("en = 'Other income'; ru = 'Оприходование денежных средств с произвольного счета';pl = 'Inne przychody';es_ES = 'Otros ingresos';es_CO = 'Otros ingresos';tr = 'Diğer gelir';it = 'Altre entrate';de = 'Sonstige Einnahmen'", MainLanguageCode));
	Query.SetParameter("ContentCurrencyPurchase",		NStr("en = 'Foreign currency purchase'; ru = 'Покупка валюты';pl = 'Zakup waluty obcej';es_ES = 'Compra de la moneda extranjera';es_CO = 'Compra de la moneda extranjera';tr = 'Döviz satın alımı';it = 'Acquisto di valuta estera';de = 'Devisenkauf'", MainLanguageCode));
	Query.SetParameter("ContentRetailIncome",			NStr("en = 'Cash withdrawal from cash register'; ru = 'Выемка из кассы';pl = 'Wypłata gotówki z kasy fiskalnej';es_ES = 'Retiro de efectivo de la caja registradora';es_CO = 'Retiro de efectivo de la caja registradora';tr = 'Yazar kasadan çekilen nakit';it = 'Prelievo di cassa dal registratore di cassa';de = 'Barauszahlung aus der Kasse'", MainLanguageCode));
	Query.SetParameter("ContentCost",					NStr("en = 'Cost of goods sold'; ru = 'Себестоимость';pl = 'Koszt własny towarów sprzedanych';es_ES = 'Coste de mercancías vendidas';es_CO = 'Coste de mercancías vendidas';tr = 'Satılan malların maliyeti';it = 'Costo dei beni venduti';de = 'Wareneinsatz'", MainLanguageCode));
	Query.SetParameter("ContentMarkup",					NStr("en = 'Retail markup'; ru = 'Наценка';pl = 'Marża detaliczna';es_ES = 'Marca de la venta al por menor';es_CO = 'Marca de la venta al por menor';tr = 'Perakende kâr marjı';it = 'Margine di vendita al dettaglio';de = 'Einzelhandels-Aufschlag'", MainLanguageCode));
	Query.SetParameter("ContentVAT",					NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ContentVATOnAdvance",			NStr("en = 'VAT charged on advance payment'; ru = 'НДС с авансов';pl = 'VAT zaliczka z góry';es_ES = 'El IVA cobrado del pago anticipado';es_CO = 'El IVA cobrado del pago anticipado';tr = 'Avans ödemenin KDV''si';it = 'IVA addebitata sul pagamento anticipato';de = 'USt. berechnet auf Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("VATAdvancesFromCustomers",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesFromCustomers"));
	Query.SetParameter("VATOutput",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Query.SetParameter("RegisteredForVAT",				StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.PettyCashGLAccount AS AccountDr,
	|	DocumentTable.Correspondence AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
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
	|			WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase)
	|				THEN &ContentCurrencyPurchase
	|			ELSE &Content
	|		END AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCashGLAccount,
	|	DocumentTable.CashCRGLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&ContentRetailIncome AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCashGLAccount,
	|	DocumentTable.BusinessLineGLAccountOfRevenueFromSales,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessLineGLAccountOfRevenueFromSales.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessLineGLAccountOfRevenueFromSales.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&ContentRetailIncome AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	13,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN DocumentTable.BusinessLineGLAccountOfSalesCost.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessLineGLAccountOfSalesCost.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	DocumentTable.Cost,
	|	CAST(&ContentCost AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableCost AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	14,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	-(DocumentTable.Amount - TableCost.Cost),
	|	CAST(&ContentMarkup AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|		LEFT JOIN TemporaryTableCost AS TableCost
	|		ON DocumentTable.Company = TableCost.Company
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	15,
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
	|	16,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	17,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	18,
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
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
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
	|	21,
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
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	TemporaryTablePaymentDetails.VATOutputGLAccount,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 									DocumentRefCashReceipt);
	Query.SetParameter("Company", 								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", 							New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("PresentationCurrency", 					StructureAdditionalProperties.ForPosting.PresentationCurrency);
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
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
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase))
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
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
	|	Table.AmountExpense > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 									DocumentRefCashReceipt);
	Query.SetParameter("Company", 								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 					StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	&Ref AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.AccountingAmount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	&Ref,
	|	DocumentTable.Item,
	|	0,
	|	-DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", 									DocumentRefCashReceipt);
	Query.SetParameter("Company", 								StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 					StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", 								StructureAdditionalProperties.ForPosting.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Document,
	|	DocumentTable.Item";
	
	QueryResult = Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.IncomeAndExpensesRetained");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", 				"Company");
	LockItem.UseFromDataSource("PresentationCurrency", 	"PresentationCurrency");
	LockItem.UseFromDataSource("Document", 				"Document");
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
	|					AND Document In
	|						(SELECT
	|							DocumentTable.Document
	|						FROM
	|							TemporaryTablePaymentDetails AS DocumentTable
	|						WHERE
	|							(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|								OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)))) AS IncomeAndExpensesRetainedBalances
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
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
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
	|	- Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UsePaymentCalendar", Constants.UsePaymentCalendar.Get());
	
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
	|	PaymentCalendar.BankAccountPettyCash,
	|	PaymentCalendar.PaymentConfirmationStatus,
	|	PaymentCalendar.Quote,
	|	SalesInvoiceTable.Document,
	|	SalesInvoiceTable.Period,
	|	PaymentCalendar.PresentationCurrency
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
	|	VALUE(Catalog.PaymentMethods.Cash) AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	DocumentTable.PettyCash AS BankAccountPettyCash,
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
	|	DocumentTable.PettyCash,
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
	|	VALUE(Catalog.PaymentMethods.Cash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	DocumentTable.DocumentAmount,
	|	0
	|FROM
	|	Document.CashReceipt AS DocumentTable
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
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
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
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor))
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePOSSummary(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",					DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("RetailIncome",			NStr("en = 'Revenue'; ru = 'Отражение доходов';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("Cost",					NStr("en = 'Cost of goods sold'; ru = 'Себестоимость';pl = 'Koszt własny towarów sprzedanych';es_ES = 'Coste de mercancías vendidas';es_CO = 'Coste de mercancías vendidas';tr = 'Satılan malların maliyeti';it = 'Costo dei beni venduti';de = 'Wareneinsatz'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",    StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Date,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Department AS Department,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.BusinessLineGLAccountOfSalesCost AS BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS GLAccount,
	|	0 AS Cost,
	|	&RetailIncome AS ContentOfAccountingRecord
	|INTO TemporaryTablePOSSummary
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Department,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.StructuralUnitGLAccountInRetail
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Department AS Department,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.BusinessLineGLAccountOfSalesCost AS BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN POSSummaryBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|			THEN POSSummaryBalances.CostBalance
	|		WHEN POSSummaryBalances.AmountCurBalance <> 0
	|			THEN CAST(POSSummaryBalances.CostBalance * DocumentTable.AmountCur / POSSummaryBalances.AmountCurBalance AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS Cost
	|INTO TemporaryTableCost
	|FROM
	|	TemporaryTablePOSSummary AS DocumentTable
	|		LEFT JOIN (SELECT
	|			POSSummaryBalances.Company AS Company,
	|			POSSummaryBalances.PresentationCurrency AS PresentationCurrency,
	|			POSSummaryBalances.StructuralUnit AS StructuralUnit,
	|			POSSummaryBalances.Currency AS Currency,
	|			SUM(POSSummaryBalances.AmountBalance) AS AmountBalance,
	|			SUM(POSSummaryBalances.AmountCurBalance) AS AmountCurBalance,
	|			SUM(POSSummaryBalances.CostBalance) AS CostBalance
	|		FROM
	|			(SELECT
	|				POSSummaryBalances.Company AS Company,
	|				POSSummaryBalances.PresentationCurrency AS PresentationCurrency,
	|				POSSummaryBalances.StructuralUnit AS StructuralUnit,
	|				POSSummaryBalances.Currency AS Currency,
	|				ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
	|				ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS AmountCurBalance,
	|				ISNULL(POSSummaryBalances.CostBalance, 0) AS CostBalance
	|			FROM
	|				AccumulationRegister.POSSummary.Balance(
	|						&PointInTime,
	|						(Company, PresentationCurrency, StructuralUnit, Currency) IN
	|							(SELECT DISTINCT
	|								TemporaryTablePOSSummary.Company,
	|								TemporaryTablePOSSummary.PresentationCurrency,
	|								TemporaryTablePOSSummary.StructuralUnit,
	|								TemporaryTablePOSSummary.Currency
	|							FROM
	|								TemporaryTablePOSSummary)) AS POSSummaryBalances
	|			
	|			UNION ALL
	|			
	|			SELECT
	|				DocumentRegisterRecordsPOSSummary.Company,
	|				DocumentRegisterRecordsPOSSummary.PresentationCurrency,
	|				DocumentRegisterRecordsPOSSummary.StructuralUnit,
	|				DocumentRegisterRecordsPOSSummary.Currency,
	|				CASE
	|					WHEN DocumentRegisterRecordsPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsPOSSummary.Amount, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsPOSSummary.Amount, 0)
	|				END,
	|				CASE
	|					WHEN DocumentRegisterRecordsPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsPOSSummary.AmountCur, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsPOSSummary.AmountCur, 0)
	|				END,
	|				CASE
	|					WHEN DocumentRegisterRecordsPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsPOSSummary.Cost, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsPOSSummary.Cost, 0)
	|				END
	|			FROM
	|				AccumulationRegister.POSSummary AS DocumentRegisterRecordsPOSSummary
	|			WHERE
	|				DocumentRegisterRecordsPOSSummary.Recorder = &Ref
	|				AND DocumentRegisterRecordsPOSSummary.Period <= &ControlPeriod) AS POSSummaryBalances
	|		
	|		GROUP BY
	|			POSSummaryBalances.Company,
	|			POSSummaryBalances.PresentationCurrency,
	|			POSSummaryBalances.StructuralUnit,
	|			POSSummaryBalances.Currency) AS POSSummaryBalances
	|		ON DocumentTable.Company = POSSummaryBalances.Company
	|			AND DocumentTable.PresentationCurrency = POSSummaryBalances.PresentationCurrency
	|			AND DocumentTable.StructuralUnit = POSSummaryBalances.StructuralUnit
	|			AND DocumentTable.Currency = POSSummaryBalances.Currency
	|WHERE
	|	(CASE
	|				WHEN POSSummaryBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|					THEN POSSummaryBalances.CostBalance
	|				WHEN POSSummaryBalances.AmountCurBalance <> 0
	|					THEN CAST(POSSummaryBalances.CostBalance * DocumentTable.AmountCur / POSSummaryBalances.AmountCurBalance AS NUMBER(15, 2))
	|				ELSE 0
	|			END > 0.005
	|			OR CASE
	|				WHEN POSSummaryBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|					THEN POSSummaryBalances.CostBalance
	|				WHEN POSSummaryBalances.AmountCurBalance <> 0
	|					THEN CAST(POSSummaryBalances.CostBalance * DocumentTable.AmountCur / POSSummaryBalances.AmountCurBalance AS NUMBER(15, 2))
	|				ELSE 0
	|			END < -0.005)";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTablePOSSummary.Company AS Company,
	|	TemporaryTablePOSSummary.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePOSSummary.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePOSSummary.Currency AS Currency
	|FROM
	|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.POSSummary");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	POSSummaryBalances.Company AS Company,
	|	POSSummaryBalances.PresentationCurrency AS PresentationCurrency,
	|	POSSummaryBalances.StructuralUnit AS StructuralUnit,
	|	POSSummaryBalances.GLAccount AS GLAccount,
	|	POSSummaryBalances.Currency AS Currency,
	|	SUM(POSSummaryBalances.AmountBalance) AS AmountBalance,
	|	SUM(POSSummaryBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableBalancesAfterPosting
	|FROM
	|	(SELECT
	|		TemporaryTable.Company AS Company,
	|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
	|		TemporaryTable.StructuralUnit AS StructuralUnit,
	|		TemporaryTable.Currency AS Currency,
	|		TemporaryTable.GLAccount AS GLAccount,
	|		TemporaryTable.AmountForBalance AS AmountBalance,
	|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
	|	FROM
	|		TemporaryTablePOSSummary AS TemporaryTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableBalances.Company,
	|		TableBalances.PresentationCurrency,
	|		TableBalances.StructuralUnit,
	|		TableBalances.Currency,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN TableBalances.StructuralUnit.GLAccountInRetail
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END,
	|		ISNULL(TableBalances.AmountBalance, 0),
	|		ISNULL(TableBalances.AmountCurBalance, 0)
	|	FROM
	|		AccumulationRegister.POSSummary.Balance(
	|				&PointInTime,
	|				(Company, PresentationCurrency, StructuralUnit, Currency) IN
	|					(SELECT DISTINCT
	|						TemporaryTablePOSSummary.Company,
	|						TemporaryTablePOSSummary.PresentationCurrency,
	|						TemporaryTablePOSSummary.StructuralUnit,
	|						TemporaryTablePOSSummary.Currency
	|					FROM
	|						TemporaryTablePOSSummary)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.PresentationCurrency,
	|		DocumentRegisterRecords.StructuralUnit,
	|		DocumentRegisterRecords.Currency,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN DocumentRegisterRecords.StructuralUnit.GLAccountInRetail
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END,
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
	|		AccumulationRegister.POSSummary AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref
	|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS POSSummaryBalances
	|
	|GROUP BY
	|	POSSummaryBalances.Company,
	|	POSSummaryBalances.PresentationCurrency,
	|	POSSummaryBalances.StructuralUnit,
	|	POSSummaryBalances.Currency,
	|	POSSummaryBalances.GLAccount
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	1 AS LineNumber,
	|	&ControlPeriod AS Date,
	|	TablePOSSummary.Company AS Company,
	|	TablePOSSummary.PresentationCurrency AS PresentationCurrency,
	|	TablePOSSummary.StructuralUnit AS StructuralUnit,
	|	ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition))
	|	END - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
	|	TablePOSSummary.Currency AS Currency,
	|	TablePOSSummary.GLAccount AS GLAccount
	|INTO TemporaryTableCurrencyExchangeRateDifferencesPOSSummary
	|FROM
	|	TemporaryTablePOSSummary AS TablePOSSummary
	|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
	|		ON TablePOSSummary.Company = TableBalances.Company
	|			AND TablePOSSummary.StructuralUnit = TableBalances.StructuralUnit
	|			AND TablePOSSummary.Currency = TableBalances.Currency
	|			AND TablePOSSummary.GLAccount = TableBalances.GLAccount
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingExchangeRateSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|						(SELECT DISTINCT
	|							TemporaryTablePOSSummary.Currency
	|						FROM
	|							TemporaryTablePOSSummary)
	|					AND Company = &Company) AS CurrencyExchangeRateCashSliceLast
	|		ON TablePOSSummary.Currency = CurrencyExchangeRateCashSliceLast.Currency
	|WHERE
	|	(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition))
	|	END - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
	|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition))
	|	END - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur,
	|	0 AS Cost,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	UNDEFINED AS SalesDocument,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTablePOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.Currency,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	0,
	|	0,
	|	&ExchangeDifference,
	|	UNDEFINED,
	|	FALSE
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.Currency,
	|	0,
	|	0,
	|	DocumentTable.Cost,
	|	&Cost,
	|	&Ref,
	|	FALSE
	|FROM
	|	TemporaryTableCost AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableBalancesAfterPosting";
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePOSSummary", ResultsArray[2].Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		AND DocumentRefCashReceipt.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
		
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
		|	Payment.PresentationCurrency,
		|	Payment.Counterparty,
		|	Payment.Ref,
		|	Payment.VATRate
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
		|	Payment.PresentationCurrency,
		|	Payment.Counterparty,
		|	SalesInvoice.Ref,
		|	Payment.VATRate,
		|	Payment.VATOutputGLAccount";
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		
	EndIf;
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Header" Then
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
			And StructureData.ObjectParameters.OperationKind = Enums.OperationTypesCashReceipt.Other Then
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
	
	If ObjectParameters.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
		GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
		GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
		
		If StructureData.Property("ExistsEPD")
			And StructureData.ExistsEPD <> Undefined
			And StructureData.ExistsEPD Then
			
			GLAccountsForFilling.Insert("DiscountAllowedGLAccount", StructureData.DiscountAllowedGLAccount);
			
		EndIf;
		
		If StructureData.EPDAmount > 0
			And StructureData.Property("Document")
			And ValueIsFilled(StructureData.Document)
			And TypeOf(StructureData.Document) = Type("DocumentRef.SalesInvoice") Then
			
			ProvideEPD = Common.ObjectAttributeValue(StructureData.Document, "ProvideEPD");
			If ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment Then
				GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
			EndIf;
			
		EndIf;
		
	ElsIf ObjectParameters.OperationKind = Enums.OperationTypesCashReceipt.FromVendor Then
		GLAccountsForFilling.Insert("AccountsPayableGLAccount", StructureData.AccountsPayableGLAccount);
		GLAccountsForFilling.Insert("AdvancesPaidGLAccount", StructureData.AdvancesPaidGLAccount);
	ElsIf ObjectParameters.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements Then
		GLAccountsForFilling.Insert("AccountsReceivableGLAccount", ObjectParameters.Correspondence);
	ElsIf ObjectParameters.OperationKind = Enums.OperationTypesCashReceipt.PaymentFromThirdParties Then
		GLAccountsForFilling.Insert("ThirdPartyPayerGLAccount", StructureData.ThirdPartyPayerGLAccount);
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, PrintParams = Undefined)
	
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_CashReceipt";
	
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
		|	CashReceipt.Ref AS Ref,
		|	CashReceipt.Number AS DocumentNumber,
		|	CashReceipt.Date AS DocumentDate,
		|	CashReceipt.Company AS Company,
		|	CashReceipt.Company.LegalEntityIndividual AS LegalEntityIndividual,
		|	CashReceipt.Company.Prefix AS Prefix,
		|	CashReceipt.Company.DescriptionFull AS CompanyPresentation,
		|	CashReceipt.CashCurrency AS CashCurrency,
		|	PRESENTATION(CashReceipt.CashCurrency) AS CurrencyPresentation,
		|	CashReceipt.AcceptedFrom AS AcceptedFrom,
		|	CashReceipt.Basis AS Basis,
		|	CashReceipt.DocumentAmount AS DocumentAmount,
		|	CASE
		|		WHEN CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
		|				OR CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
		|				OR CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
		|			THEN CashReceipt.Counterparty.DescriptionFull
		|		WHEN CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromAdvanceHolder)
		|			THEN CashReceipt.AdvanceHolder.Description
		|		ELSE CashReceipt.AcceptedFrom
		|	END AS Payer
		|FROM
		|	Document.CashReceipt AS CashReceipt
		|WHERE
		|	CashReceipt.Ref = &CurrentDocument";
		
		// MultilingualSupport
		
		If PrintParams = Undefined Then
			LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
		Else
			LanguageCode = PrintParams.LanguageCode;
		EndIf;
		
		SessionParameters.LanguageCodeForOutput = LanguageCode;
		DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
		
		// End MultilingualSupport
		
		Header = Query.Execute().Select();
		Header.Next();
		
		SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_CashReceipt_CashReceiptVoucher";
		Template = PrintManagement.PrintFormTemplate("Document.CashReceipt.PF_MXL_CashReceiptVoucher", LanguageCode);
		
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
		
		TemplateArea = Template.GetArea("HeaderRecipient");
		
		TemplateArea.Parameters.Fill(Header);
		
		RecipientPresentation	= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		TemplateArea.Parameters.RecipientPresentation	= RecipientPresentation;
		TemplateArea.Parameters.RecipientAddress		= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
		TemplateArea.Parameters.RecipientPhoneFax		= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "PhoneNumbers,Fax");
		TemplateArea.Parameters.RecipientEmail			= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "Email");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("HeaderPayer");
		
		TemplateArea.Parameters.Payer	= TrimAll(Header.Payer);
		If ValueIsFilled(Header.AcceptedFrom)
			AND TrimAll(Header.AcceptedFrom) <> TrimAll(Header.Payer) Then
		
			TemplateArea.Parameters.AcceptedFrom	= TrimAll(Header.AcceptedFrom);
		
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
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
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
	
	Var Errors;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "CashReceiptVoucher") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CashReceiptVoucher", 
		    NStr("en = 'Cash receipt'; ru = 'Приходный кассовый ордер';pl = 'KP - Dowód wpłaty';es_ES = 'Recibo de efectivo';es_CO = 'Recibo de efectivo';tr = 'Nakit tahsilat';it = 'Entrata di cassa';de = 'Zahlungseingang'"), PrintForm(ObjectsArray, PrintObjects, PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "AdvancePaymentInvoice") Then
		
		CashReceiptArray	= New Array;
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
						NStr("en = 'Generate an ""Advance payment invoice"" based on the %1 before printing.'; ru = 'Создать инвойс на аванс на основании %1 перед печатью.';pl = 'Wygeneruj ""Fakturę zaliczkową"" na podstawie %1 przed wydrukiem.';es_ES = 'Generar un ""Informe de pago anticipado"" basado en el %1 antes de imprimir.';es_CO = 'Generar un ""Informe de pago anticipado"" basado en el %1 antes de imprimir.';tr = 'Yazdırmadan önce %1 temel alan bir ""Ön ödeme faturası"" oluşturun.';it = 'Generare una ""Fattura di pagamento di anticipo"" basata su %1 prima della stampa.';de = 'Eine ""Vorauszahlungsrechnung"" auf Basis des %1 vor dem Druck generieren.'"),
						PrintObject);
					
					CommonClientServer.AddUserError(Errors,, MessageText, Undefined);
					
					Continue;
					
				EndIf;
				
			Else
				
				CashReceiptArray.Add(PrintObject);
				
			EndIf;
			
		EndDo;
		
		If CashReceiptArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
				CashReceiptArray,
				PrintObjects, 
				"AdvancePaymentInvoice", , PrintParameters.Result);
			
		EndIf;
		
		If TaxInvoiceArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
				TaxInvoiceArray,
				PrintObjects, 
				"AdvancePaymentInvoice",
				SpreadsheetDocument, PrintParameters.Result);
			
		EndIf;
		
		If CashReceiptArray.Count() > 0 Or TaxInvoiceArray.Count() > 0 Then
			
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
	PrintCommand.ID							= "CashReceiptVoucher";
	PrintCommand.Presentation				= NStr("en = 'Cash receipt'; ru = 'Приходный кассовый ордер';pl = 'KP - Dowód wpłaty';es_ES = 'Recibo de efectivo';es_CO = 'Recibo de efectivo';tr = 'Nakit tahsilat';it = 'Entrata di cassa';de = 'Zahlungseingang'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "AdvancePaymentInvoice";
	PrintCommand.Presentation				= NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago anticipado';es_CO = 'Factura del pago anticipado';tr = 'Avans ödeme faturası';it = 'Fattura pagamento di anticipo';de = 'Vorauszahlung Zahlung Rechnung'");
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

#Region OtherSettlements

Procedure GenerateTableMiscellaneousPayable(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Miscellaneous receivables'; ru = 'Поступление от прочих контрагентов';pl = 'Różne należności';es_ES = 'Cuentas a cobrar varias';es_CO = 'Cuentas a cobrar varias';tr = 'Çeşitli alacaklar';it = 'Crediti vari';de = 'Übrige Forderungen'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Comment",						NStr("en = 'Payment from other accounts'; ru = 'Уменьшение долга контрагента';pl = 'Płatność z innych kont';es_ES = 'Pago de otras cuentas';es_CO = 'Pago de otras cuentas';tr = 'Diğer hesaplardan ödeme';it = 'Pagamento ad altri conti';de = 'Zahlung von anderen Konten'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
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
	|	TemporaryTableHeader.PettyCash AS PettyCash,
	|	TemporaryTablePaymentDetails.Date AS Period
	|INTO TemporaryTableOtherSettlements
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN TemporaryTableHeader AS TemporaryTableHeader
	|		ON (TRUE)
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
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

Procedure GenerateTableLoanSettlements(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("LoanSettlements",				NStr("en = 'Credit payment receipt'; ru = 'Поступление по кредиту';pl = 'Wpływ płatności z racji kredytu';es_ES = 'Recibo del pago de crédito';es_CO = 'Recibo del pago de crédito';tr = 'Kredi ödeme tutarı';it = 'Ricevimento di pagamento di credito';de = 'Kredit-Zahlungsbeleg'"));
	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'"));	
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency",					DocumentRefCashReceipt.CashCurrency);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.LoanContractTypes.Borrowed) AS LoanKind,
	|	CashReceipt.Date AS Date,
	|	CashReceipt.Date AS Period,
	|	&LoanSettlements AS PostingContent,
	|	CashReceipt.Counterparty AS Counterparty,
	|	CashReceipt.DocumentAmount AS PaymentAmount,
	|	CAST(CashReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtCur,
	|	CAST(CashReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebt,
	|	CAST(CashReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS PrincipalDebtCurForBalance,
	|	CAST(CashReceipt.DocumentAmount * CASE
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
	|	CAST(CashReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfContract.Multiplicity / (ExchangeRateOfContract.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CashReceipt.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRateOfPettyCashe.ExchangeRate * ExchangeRateOfAccount.Multiplicity / (ExchangeRateOfAccount.ExchangeRate * ExchangeRateOfPettyCashe.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CashReceipt.LoanContract AS LoanContract,
	|	CashReceipt.LoanContract.SettlementsCurrency AS Currency,
	|	CashReceipt.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CashReceipt.LoanContract.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CashReceipt.PettyCash AS PettyCash,
	|	FALSE AS DeductedFromSalary
	|INTO TemporaryTableLoanSettlements
	|FROM
	|	Document.CashReceipt AS CashReceipt
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfAccount
	|		ON (ExchangeRateOfAccount.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfPettyCashe
	|		ON (ExchangeRateOfPettyCashe.Currency = &CashCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ExchangeRateOfContract
	|		ON (ExchangeRateOfContract.Currency = CashReceipt.LoanContract.SettlementsCurrency)
	|WHERE
	|	CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
	|	AND CashReceipt.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense),
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty)
	|			THEN VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END,
	|	DocumentTable.Date,
	|	DocumentTable.Date,
	|	DocumentTable.ContentByTypeOfAmount,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty)
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
	|	DocumentTable.GLAccountByTypeOfAmount,
	|	DocumentTable.PettyCash,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty))";
	
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
	
	Locker = New DataLock;
	LockerItem = Locker.Add("AccumulationRegister.LoanSettlements");
	LockerItem.Mode = DataLockMode.Exclusive;
	LockerItem.DataSource = QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockerItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	Locker.Lock();
	
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

#EndIf
