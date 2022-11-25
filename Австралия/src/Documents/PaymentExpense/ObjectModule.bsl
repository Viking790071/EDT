#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillInEmployeeGLAccounts(IsEmployee = True, IsDefault = True) Export
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	If IsEmployee And ValueIsFilled(AdvanceHolder) Then
		EmployeeAttributes = Common.ObjectAttributesValues(AdvanceHolder, "AdvanceHoldersGLAccount, OverrunGLAccount");
		AdvanceHoldersReceivableGLAccount = EmployeeAttributes.AdvanceHoldersGLAccount;
		AdvanceHoldersPayableGLAccount = EmployeeAttributes.OverrunGLAccount;
	EndIf;
	
	If IsDefault Then
		
		If Not ValueIsFilled(AdvanceHoldersReceivableGLAccount) Then
			AdvanceHoldersReceivableGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
		EndIf;
		
		If Not ValueIsFilled(AdvanceHoldersPayableGLAccount) Then
			AdvanceHoldersPayableGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure is filling the payment details.
//
Procedure FillPaymentDetails(Val VATAmountLeftToDistribute = 0) Export
	
	IsOrderSet = False;
	
	If ValueIsFilled(Counterparty) Then
		DoOperationsByOrders = Common.ObjectAttributeValue(Counterparty, "DoOperationsByOrders");
		
		If DoOperationsByOrders AND ValueIsFilled(BasisDocument) Then
			If TypeOf(BasisDocument) = Type("DocumentRef.PurchaseOrder")
				Or TypeOf(BasisDocument) = Type("DocumentRef.SubcontractorOrderIssued") Then
				IsOrderSet = True;
			EndIf;
		EndIf;
	EndIf;

	ParentCompany = DriveServer.GetCompany(Company);
	
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	ElsIf VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, CashCurrency, Company);
	
	ExchangeRateCurrenciesDC = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	CurrencyUnitConversionFactor = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO ExchangeRateOnPeriod
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsPayableTable
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			&PeriodEndOfDay,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsPayable.Company,
	|	DocumentAccountsPayable.Counterparty,
	|	DocumentAccountsPayable.Contract,
	|	DocumentAccountsPayable.Document,
	|	DocumentAccountsPayable.Order,
	|	DocumentAccountsPayable.SettlementsType,
	|	CASE
	|		WHEN DocumentAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsPayable.AmountCur
	|		ELSE DocumentAccountsPayable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsPayable AS DocumentAccountsPayable
	|WHERE
	|	DocumentAccountsPayable.Recorder = &Ref
	|	AND DocumentAccountsPayable.Period <= &PaymentDate
	|	AND DocumentAccountsPayable.Company = &Company
	|	AND DocumentAccountsPayable.Counterparty = &Counterparty
	|	AND DocumentAccountsPayable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableTable.Counterparty AS Counterparty,
	|	AccountsPayableTable.Contract AS Contract,
	|	AccountsPayableTable.Document AS Document,
	|	AccountsPayableTable.Order AS Order,
	|	SUM(AccountsPayableTable.AmountCurBalance) AS AmountCurBalance
	|INTO AccountsPayableGrouped
	|FROM
	|	AccountsPayableTable AS AccountsPayableTable
	|WHERE
	|	AccountsPayableTable.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsPayableTable.Counterparty,
	|	AccountsPayableTable.Contract,
	|	AccountsPayableTable.Document,
	|	AccountsPayableTable.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableGrouped.Counterparty AS Counterparty,
	|	AccountsPayableGrouped.Contract AS Contract,
	|	AccountsPayableGrouped.Document AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsPayableGrouped.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	AccountsPayableGrouped.AmountCurBalance AS AmountCurBalance,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.CashFlowItem AS Item
	|INTO AccountsPayableContract
	|FROM
	|	AccountsPayableGrouped AS AccountsPayableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsPayableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsPayableGrouped.Contract = CounterpartyContracts.Ref
	|WHERE
	|	(NOT &IsOrderSet
	|			OR AccountsPayableGrouped.Order = &Order)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountsPayableTable.Document AS Document,
	|	AccountsPayableTable.Document.Date AS DocumentDate
	|INTO DocumentTable
	|FROM
	|	AccountsPayableTable AS AccountsPayableTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TRUE AS ExistsEPD,
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref AS SupplierInvoice
	|INTO EarlyPaymentDiscounts
	|FROM
	|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON SupplierInvoiceEarlyPaymentDiscounts.Ref = DocumentTable.Document
	|WHERE
	|	ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &PaymentDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	DocumentTable.Document AS Document,
	|	ISNULL(PaymentExpense.PaymentDate, DocumentTable.DocumentDate) AS PaymentDate
	|INTO PaymentDates
	|FROM
	|	DocumentTable AS DocumentTable
	|		LEFT JOIN Document.PaymentExpense AS PaymentExpense
	|		ON DocumentTable.Document = PaymentExpense.Ref
	|			AND (PaymentExpense.Paid)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableContract.Contract AS Contract,
	|	AccountsPayableContract.Item AS Item,
	|	AccountsPayableContract.Document AS Document,
	|	ISNULL(PaymentDates.PaymentDate, DATETIME(1, 1, 1)) AS PaymentDate,
	|	AccountsPayableContract.Order AS Order,
	|	ExchangeRateOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRateOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRate.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRate.Multiplicity AS Multiplicity,
	|	AccountsPayableContract.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN CAST(AccountsPayableContract.AmountCurBalance * SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity) AS NUMBER(15, 2))
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CAST(AccountsPayableContract.AmountCurBalance / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)) AS NUMBER(15, 2))
	|	END AS AmountCurDocument,
	|	ISNULL(EarlyPaymentDiscounts.ExistsEPD, FALSE) AS ExistsEPD
	|INTO AccountsPayableWithDiscount
	|FROM
	|	AccountsPayableContract AS AccountsPayableContract
	|		LEFT JOIN ExchangeRateOnPeriod AS ExchangeRateOfDocument
	|		ON (ExchangeRateOfDocument.Currency = &Currency)
	|		LEFT JOIN ExchangeRateOnPeriod AS SettlementsExchangeRate
	|		ON AccountsPayableContract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|		LEFT JOIN EarlyPaymentDiscounts AS EarlyPaymentDiscounts
	|		ON AccountsPayableContract.Document = EarlyPaymentDiscounts.SupplierInvoice
	|		LEFT JOIN PaymentDates AS PaymentDates
	|		ON AccountsPayableContract.Document = PaymentDates.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableWithDiscount.Contract AS Contract,
	|	AccountsPayableWithDiscount.Item AS Item,
	|	AccountsPayableWithDiscount.Document AS Document,
	|	AccountsPayableWithDiscount.PaymentDate AS PaymentDate,
	|	AccountsPayableWithDiscount.Order AS Order,
	|	MAX(AccountsPayableWithDiscount.CashAssetsRate) AS CashAssetsRate,
	|	MAX(AccountsPayableWithDiscount.CashMultiplicity) AS CashMultiplicity,
	|	MAX(AccountsPayableWithDiscount.ExchangeRate) AS ExchangeRate,
	|	MAX(AccountsPayableWithDiscount.Multiplicity) AS Multiplicity,
	|	SUM(AccountsPayableWithDiscount.AmountCurBalance) AS AmountCurBalance,
	|	SUM(AccountsPayableWithDiscount.AmountCurDocument) AS AmountCurDocument,
	|	AccountsPayableWithDiscount.ExistsEPD AS ExistsEPD
	|FROM
	|	AccountsPayableWithDiscount AS AccountsPayableWithDiscount
	|
	|GROUP BY
	|	AccountsPayableWithDiscount.Contract,
	|	AccountsPayableWithDiscount.Item,
	|	AccountsPayableWithDiscount.Document,
	|	AccountsPayableWithDiscount.PaymentDate,
	|	AccountsPayableWithDiscount.ExistsEPD,
	|	AccountsPayableWithDiscount.Order
	|
	|ORDER BY
	|	PaymentDate";
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Date);
	Query.SetParameter("PeriodEndOfDay", EndOfDay(Date));
	Query.SetParameter("PaymentDate", ?(ValueIsFilled(PaymentDate), PaymentDate, Date));
	Query.SetParameter("Currency", CashCurrency);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("IsOrderSet", IsOrderSet);
	Query.SetParameter("Order", BasisDocument);
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(ParentCompany));
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Ref, OperationKind);
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		Company,
		ContractTypesList);
	
	StructureContractCurrencyRateByDefault = CurrencyRateOperations.GetCurrencyRate(Date, ContractByDefault.SettlementsCurrency, Company);
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountReceived");
	IsVendor = OperationKind = Enums.OperationTypesPaymentExpense.Vendor;
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	PaymentDetails.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = PaymentDetails.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurDocument < AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				NewRow.PaymentAmount = SelectionOfQueryResult.AmountCurDocument;
				
				VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
				
				NewRow.VATRate = VATRateData.VATRate;
				
				VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100);
				NewRow.VATAmount = VATAmount;
				
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurDocument;
				VATAmountLeftToDistribute = VATAmountLeftToDistribute - VATAmount;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					ExchangeRateMethod,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity);
					
				NewRow.PaymentAmount = AmountLeftToDistribute;
				
				VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
				
				NewRow.VATRate = VATRateData.VATRate;
				
				VATAmount					= ?(
					VATAmountLeftToDistribute > 0, 
					VATAmountLeftToDistribute,
					NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100));
					
				NewRow.VATAmount			= VATAmount;
					
				AmountLeftToDistribute		= 0;
				VATAmountLeftToDistribute	= 0;
				
			EndIf;
			
		Else
			
			NewRow.Contract = ContractByDefault;
			
			NewRow.AdvanceFlag = True;
			NewRow.Order = ?(IsOrderSet, BasisDocument, Undefined);
			NewRow.PaymentAmount = AmountLeftToDistribute;
			
			VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
			
			NewRow.VATRate = VATRateData.VATRate;
			
			VATAmount					= ?(
			VATAmountLeftToDistribute > 0, 
			VATAmountLeftToDistribute,
			NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100));
			
			NewRow.VATAmount			= VATAmount;
			
			AmountLeftToDistribute		= 0;
			VATAmountLeftToDistribute	= 0;
			
			NewRow.Item = Common.ObjectAttributeValue(NewRow.Contract, "CashFlowItem");
			
		EndIf;
		
		If IsVendor Then
			NewRow.DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndIf;
		
	EndDo;
	
	If PaymentDetails.Count() = 0 Then
		NewRow = PaymentDetails.Add();
		NewRow.Contract			= ContractByDefault;
		NewRow.Item				= Common.ObjectAttributeValue(NewRow.Contract, "CashFlowItem");
		NewRow.PaymentAmount	= DocumentAmount;
		
		If IsVendor Then
			NewRow.DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndIf;
	EndIf;
	
	FillCurrenciesRatesInPaymentDetails();
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure

Procedure FillAdvancesPaymentDetails() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	ElsIf VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.Rate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Repetition AS Multiplicity
	|INTO ExchangeRatesOnPeriod
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.AmountBalance AS Amount,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCur
	|INTO AccountsReceivableTable
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&PeriodEndOfDay,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsReceivable.Counterparty,
	|	DocumentAccountsReceivable.Contract,
	|	DocumentAccountsReceivable.Document,
	|	DocumentAccountsReceivable.Order,
	|	CASE
	|		WHEN DocumentAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsReceivable.Amount
	|		ELSE DocumentAccountsReceivable.Amount
	|	END,
	|	CASE
	|		WHEN DocumentAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsReceivable.AmountCur
	|		ELSE DocumentAccountsReceivable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentAccountsReceivable
	|WHERE
	|	DocumentAccountsReceivable.Recorder = &Ref
	|	AND DocumentAccountsReceivable.Company = &Company
	|	AND DocumentAccountsReceivable.Counterparty = &Counterparty
	|	AND DocumentAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableTable.Counterparty AS Counterparty,
	|	AccountsReceivableTable.Contract AS Contract,
	|	AccountsReceivableTable.Document AS Document,
	|	AccountsReceivableTable.Order AS Order,
	|	-SUM(AccountsReceivableTable.Amount) AS Amount,
	|	-SUM(AccountsReceivableTable.AmountCur) AS AmountCur
	|INTO AccountsReceivableGrouped
	|FROM
	|	AccountsReceivableTable AS AccountsReceivableTable
	|WHERE
	|	AccountsReceivableTable.AmountCur < 0
	|
	|GROUP BY
	|	AccountsReceivableTable.Counterparty,
	|	AccountsReceivableTable.Contract,
	|	AccountsReceivableTable.Document,
	|	AccountsReceivableTable.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableGrouped.Contract AS Contract,
	|	CounterpartyContracts.CashFlowItem AS Item,
	|	TRUE AS AdvanceFlag,
	|	AccountsReceivableGrouped.Document AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsReceivableGrouped.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	AccountsReceivableGrouped.AmountCur AS SettlementsAmount,
	|	CASE
	|		WHEN &PresentationCurrency = &Currency
	|			THEN AccountsReceivableGrouped.Amount
	|		WHEN CounterpartyContracts.SettlementsCurrency = &Currency
	|			THEN AccountsReceivableGrouped.AmountCur
	|		ELSE CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN AccountsReceivableGrouped.AmountCur * SettlementsRates.ExchangeRate * CashCurrencyRates.Multiplicity / CashCurrencyRates.ExchangeRate / SettlementsRates.Multiplicity
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountsReceivableGrouped.AmountCur / (SettlementsRates.ExchangeRate * CashCurrencyRates.Multiplicity / CashCurrencyRates.ExchangeRate / SettlementsRates.Multiplicity)
	|			END
	|	END AS PaymentAmount,
	|	CASE
	|		WHEN &PresentationCurrency = &Currency
	|			THEN CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN AccountsReceivableGrouped.Amount / AccountsReceivableGrouped.AmountCur * CashCurrencyRates.ExchangeRate / CashCurrencyRates.Multiplicity * SettlementsRates.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN AccountsReceivableGrouped.AmountCur / AccountsReceivableGrouped.Amount * CashCurrencyRates.ExchangeRate / CashCurrencyRates.Multiplicity * SettlementsRates.Multiplicity
	|				END
	|		ELSE SettlementsRates.ExchangeRate
	|	END AS ExchangeRate,
	|	SettlementsRates.Multiplicity AS Multiplicity
	|FROM
	|	AccountsReceivableGrouped AS AccountsReceivableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableGrouped.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN ExchangeRatesOnPeriod AS SettlementsRates
	|		ON (CounterpartyContracts.SettlementsCurrency = SettlementsRates.Currency)
	|		LEFT JOIN ExchangeRatesOnPeriod AS CashCurrencyRates
	|		ON (CashCurrencyRates.Currency = &Currency)";
	
	Query.SetParameter("Company"               , ParentCompany);
	Query.SetParameter("PresentationCurrency"  , DriveServer.GetPresentationCurrency(ParentCompany));
	Query.SetParameter("Counterparty"          , Counterparty);
	Query.SetParameter("Period"                , Date);
	Query.SetParameter("PeriodEndOfDay"        , EndOfDay(Date));
	Query.SetParameter("Ref"                   , Ref);
	Query.SetParameter("Currency"              , CashCurrency);
	Query.SetParameter("ExchangeRateMethod"    , DriveServer.GetExchangeMethod(ParentCompany));
	
	PaymentDetails.Load(Query.Execute().Unload());
	
	If PaymentDetails.Count() = 0 Then
		
		ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Ref, OperationKind);
		ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
			Counterparty,
			Company,
			ContractTypesList);
		
		NewRow = PaymentDetails.Add();
		NewRow.Contract			= ContractByDefault;
		NewRow.Item				= Common.ObjectAttributeValue(NewRow.Contract, "CashFlowItem");
		NewRow.PaymentAmount	= DocumentAmount;
		
	Else
		
		For Each NewRow In PaymentDetails Do
			VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
			NewRow.VATRate = VATRateData.VATRate;
			NewRow.VATAmount			= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100);
		EndDo;
		
	EndIf;
	
	FillCurrenciesRatesInPaymentDetails();
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByExpenditureRequest(BasisDocument, Amount = Undefined)
	
	StructureBasisDoc = Common.ObjectAttributesValues(
		BasisDocument,
		"PaymentConfirmationStatus, CashAssetType, CashFlowItem");
	
	If StructureBasisDoc.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'Please select an approved Payment request.'; ru = 'Выберите утвержденную заявку на расходование средств.';pl = 'Wybierz zatwierdzone wezwanie do zapłaty.';es_ES = 'Por favor, seleccione una solicitud de Pago aprobado.';es_CO = 'Por favor, seleccione una solicitud de Pago aprobado.';tr = 'Lütfen, onaylanmış bir Ödeme talebi seçin.';it = 'Si prega di selezionare una Richiesta di pagamento approvata.';de = 'Bitte wählen Sie eine genehmigte Zahlungsaufforderung aus.'");
	EndIf;
	If StructureBasisDoc.CashAssetType = Enums.CashAssetTypes.Cash Then
		Raise NStr("en = 'Please select an Payment request with a bank or undefined payment method.'; ru = 'Выберите заявку на расходование средств посредством банковского перевода или с неопределенным способом оплаты.';pl = 'Wybierz wezwanie do zapłaty za pomocą bankowej lub niezdefiniowanej metody płatności.';es_ES = 'Por favor, seleccione una solicitud de Pago con un banco, o el método de pago no definido.';es_CO = 'Por favor, seleccione una solicitud de Pago con un banco, o el método de pago no definido.';tr = 'Lütfen, banka veya tanımsız ödeme yöntemli bir Ödeme talebi seçin.';it = 'Si prega di selezionare una Richiesta di pagamento con metodo di pagamento bancario o non definito.';de = 'Bitte wählen Sie eine Zahlungsaufforderung mit einer Bankzahlung oder einer nicht definierten Zahlungsmethode aus.'");
	EndIf;
	
	IsPayroll = False;
	
	If StructureBasisDoc.CashFlowItem = Catalogs.CashFlowItems.Payroll Then
		IsPayroll = True;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref",	BasisDocument);
	Query.SetParameter("Date",	?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	If Not IsPayroll Then
		Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	EndIf;
	
	If IsPayroll Then
	
		Query.Text =
		"SELECT ALLOWED
		|	VALUE(Enum.OperationTypesPaymentExpense.Salary) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.BasisDocument AS Statement,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.CashFlowItem AS Item,
		|	CASE
		|		WHEN DocumentHeader.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentHeader.BankAccount
		|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
		|			THEN DocumentHeader.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
		|	END AS BankAccount,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.DocumentAmount AS DocumentAmount,
		|	DocumentHeader.DocumentAmount AS PaymentAmount
		|FROM
		|	Document.ExpenditureRequest AS DocumentHeader
		|		LEFT JOIN (SELECT TOP 1
		|			BankAccounts.Ref AS BankAccount,
		|			BankAccounts.Owner AS Owner,
		|			BankAccounts.CashCurrency AS CashCurrency
		|		FROM
		|			Document.ExpenditureRequest AS DocumentHeader
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentHeader.Company = BankAccounts.Owner
		|					AND DocumentHeader.DocumentCurrency = BankAccounts.CashCurrency
		|		WHERE
		|			DocumentHeader.Ref = &Ref
		|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
		|		ON DocumentHeader.DocumentCurrency = NestedSelect.CashCurrency
		|			AND DocumentHeader.Company = NestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref";
	
	ElsIf Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT ALLOWED
		|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.BasisDocument AS RequestBasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	CASE
		|		WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentTable.BankAccount
		|		WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|			THEN DocumentTable.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
		|	END AS BankAccount,
		|	DocumentTable.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(ExchangeRateOfDocument.Rate, 1) AS CC_ExchangeRate,
		|	ISNULL(ExchangeRateOfDocument.Repetition, 1) AS CC_Multiplicity,
		|	ISNULL(SettlementsExchangeRate.Rate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRate.Repetition, 1) AS Multiplicity,
		|	CAST(CASE
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|				THEN &Amount * CASE
		|						WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|								AND SettlementsExchangeRate.Rate <> 0
		|								AND ExchangeRateOfDocument.Repetition <> 0
		|							THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1))
		|						ELSE 1
		|					END
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|				THEN &Amount / CASE
		|						WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|								AND SettlementsExchangeRate.Rate <> 0
		|								AND ExchangeRateOfDocument.Repetition <> 0
		|							THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1))
		|						ELSE 1
		|					END
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.ExpenditureRequest AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsExchangeRate
		|		ON DocumentTable.Contract.SettlementsCurrency = SettlementsExchangeRate.Currency
		|			AND DocumentTable.Company = SettlementsExchangeRate.Company
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS ExchangeRateOfDocument
		|		ON DocumentTable.DocumentCurrency = ExchangeRateOfDocument.Currency
		|			AND DocumentTable.Company = ExchangeRateOfDocument.Company
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN (SELECT TOP 1
		|			BankAccounts.Ref AS BankAccount,
		|			BankAccounts.Owner AS Owner,
		|			BankAccounts.CashCurrency AS CashCurrency
		|		FROM
		|			Document.ExpenditureRequest AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|		WHERE
		|			DocumentTable.Ref = &Ref
		|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
		|		ON DocumentTable.DocumentCurrency = NestedSelect.CashCurrency
		|			AND DocumentTable.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT ALLOWED
		|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.BasisDocument AS RequestBasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	CASE
		|		WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentTable.BankAccount
		|		WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|			THEN DocumentTable.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
		|	END AS BankAccount,
		|	DocumentTable.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.DocumentAmount AS DocumentAmount,
		|	DocumentTable.DocumentAmount AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(ExchangeRateOfDocument.Rate, 1) AS CC_ExchangeRate,
		|	ISNULL(ExchangeRateOfDocument.Repetition, 1) AS CC_Multiplicity,
		|	ISNULL(SettlementsExchangeRate.Rate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRate.Repetition, 1) AS Multiplicity,
		|	CAST(CASE
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|				THEN DocumentTable.DocumentAmount * CASE
		|						WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|								AND SettlementsExchangeRate.Rate <> 0
		|								AND ExchangeRateOfDocument.Repetition <> 0
		|							THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1))
		|						ELSE 1
		|					END
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|				THEN DocumentTable.DocumentAmount / CASE
		|						WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|								AND SettlementsExchangeRate.Rate <> 0
		|								AND ExchangeRateOfDocument.Repetition <> 0
		|							THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1))
		|						ELSE 1
		|					END
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.DocumentAmount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.ExpenditureRequest AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsExchangeRate
		|		ON DocumentTable.Contract.SettlementsCurrency = SettlementsExchangeRate.Currency
		|			AND DocumentTable.Company = SettlementsExchangeRate.Company
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS ExchangeRateOfDocument
		|		ON DocumentTable.DocumentCurrency = ExchangeRateOfDocument.Currency
		|			AND DocumentTable.Company = ExchangeRateOfDocument.Company
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN (SELECT TOP 1
		|			BankAccounts.Ref AS BankAccount,
		|			BankAccounts.Owner AS Owner,
		|			BankAccounts.CashCurrency AS CashCurrency
		|		FROM
		|			Document.ExpenditureRequest AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|		WHERE
		|			DocumentTable.Ref = &Ref
		|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
		|		ON DocumentTable.DocumentCurrency = NestedSelect.CashCurrency
		|			AND DocumentTable.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	EndIf;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		If IsPayroll Then
			
			PayrollPayment.Clear();
			NewRow = PayrollPayment.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.PlanningDocument = BasisDocument;
			
			PaymentDetails.Clear();
			NewRow = PaymentDetails.Add();
			NewRow.PaymentAmount = Selection.PaymentAmount;
			
		Else 
				
			ExchangeRate = Selection.CC_ExchangeRate;
			Multiplicity = Selection.CC_Multiplicity;
			
			VATTaxation = DriveServer.VATTaxation(Company, Date);
			If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
				GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, BasisDocument);
			EndIf;
			
			PaymentDetails.Clear();
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.AdvanceFlag = True;
			NewRow.PlanningDocument = BasisDocument;
			
			If ValueIsFilled(BasisDocument.BasisDocument)
				AND TypeOf(BasisDocument.BasisDocument) = Type("DocumentRef.PurchaseOrder")
				AND Counterparty.DoOperationsByOrders Then
				
				NewRow.Order = BasisDocument.BasisDocument;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//
Procedure FillByRMARequest(BasisDocument)
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	PresentationCurrency = DriveServer.GetPresentationCurrency(BasisDocument.Company);
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("DocumentDate", DocumentDate);
	Query.SetParameter("Company", BasisDocument.Company);
	Query.SetParameter("PresentationCurrency", PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	
	Query.Text =
	"SELECT ALLOWED
	|	AccountingPolicySliceLast.Company AS Company,
	|	AccountingPolicySliceLast.DefaultVATRate AS DefaultVATRate,
	|	AccountingPolicySliceLast.RegisteredForVAT AS RegisteredForVAT
	|INTO TemporaryAccountingPolicy
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&DocumentDate, ) AS AccountingPolicySliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO TemporaryExchangeRate
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, Company = &Company) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RMARequest.Company AS Company,
	|	RMARequest.Counterparty AS Counterparty,
	|	RMARequest.Contract AS Contract,
	|	RMARequest.Invoice AS Invoice,
	|	RMARequest.Ref AS Ref,
	|	RMARequest.Equipment AS Equipment,
	|	RMARequest.Characteristic AS Characteristic,
	|	RMARequest.SerialNumber AS SerialNumber
	|INTO RMARequestTable
	|FROM
	|	Document.RMARequest AS RMARequest
	|WHERE
	|	RMARequest.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RMARequestTable.Company AS Company,
	|	RMARequestTable.Counterparty AS Counterparty,
	|	RMARequestTable.Contract AS Contract,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, &PresentationCurrency) AS SettlementsCurrency,
	|	RMARequestTable.Invoice AS Invoice,
	|	RMARequestTable.Ref AS Ref,
	|	RMARequestTable.Equipment AS Equipment,
	|	RMARequestTable.Characteristic AS Characteristic,
	|	RMARequestTable.SerialNumber AS SerialNumber,
	|	ISNULL(Products.UseSerialNumbers, FALSE) AS UseSerialNumbers
	|INTO RMARequest
	|FROM
	|	RMARequestTable AS RMARequestTable
	|		LEFT JOIN Catalog.Products AS Products
	|		ON RMARequestTable.Equipment = Products.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON RMARequestTable.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RMARequest.SettlementsCurrency AS SettlementsCurrency,
	|	ISNULL(Counterparties.DoOperationsByOrders, FALSE) AS DoOperationsByOrders,
	|	RMARequest.Company AS Company,
	|	RMARequest.Counterparty AS Counterparty,
	|	RMARequest.Contract AS Contract,
	|	RMARequest.Invoice AS Invoice,
	|	RMARequest.Ref AS Ref,
	|	ISNULL(TemporaryAccountingPolicy.RegisteredForVAT, FALSE) AS RegisteredForVAT,
	|	ISNULL(TemporaryAccountingPolicy.DefaultVATRate, VALUE(Catalog.VATRates.EmptyRef)) AS DefaultVATRate
	|INTO RMARequestWithCurrency
	|FROM
	|	RMARequest AS RMARequest
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON RMARequest.Counterparty = Counterparties.Ref
	|		LEFT JOIN TemporaryAccountingPolicy AS TemporaryAccountingPolicy
	|		ON RMARequest.Company = TemporaryAccountingPolicy.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceSerialNumbers.SerialNumber AS SerialNumber
	|INTO InvoiceSerialNumbers
	|FROM
	|	Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|		INNER JOIN RMARequest AS RMARequest
	|		ON SalesInvoiceSerialNumbers.Ref = RMARequest.Invoice
	|
	|UNION ALL
	|
	|SELECT
	|	SalesSlipSerialNumbers.ConnectionKey,
	|	SalesSlipSerialNumbers.SerialNumber
	|FROM
	|	Document.SalesSlip.SerialNumbers AS SalesSlipSerialNumbers
	|		INNER JOIN RMARequest AS RMARequest
	|		ON SalesSlipSerialNumbers.Ref = RMARequest.Invoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	InvoiceSerialNumbers.ConnectionKey AS ConnectionKey
	|INTO ConnectionKeyTable
	|FROM
	|	InvoiceSerialNumbers AS InvoiceSerialNumbers
	|		INNER JOIN RMARequest AS RMARequest
	|		ON InvoiceSerialNumbers.SerialNumber = RMARequest.SerialNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(*) AS Qty
	|INTO SerialNumbersQty
	|FROM
	|	InvoiceSerialNumbers AS InvoiceSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	CASE
	|		WHEN SalesInvoice.Order REFS Document.SalesOrder
	|			THEN SalesInvoice.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	SalesInvoice.ExchangeRate AS ExchangeRate,
	|	SalesInvoice.Multiplicity AS Multiplicity,
	|	SalesInvoice.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SalesInvoice.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO DocumentHeader
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		INNER JOIN RMARequest AS RMARequest
	|		ON SalesInvoice.Ref = RMARequest.Invoice
	|
	|UNION ALL
	|
	|SELECT
	|	SalesSlip.Ref,
	|	SalesSlip.Company,
	|	SalesSlip.DocumentCurrency,
	|	UNDEFINED,
	|	1,
	|	1,
	|	1,
	|	1
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|		INNER JOIN RMARequest AS RMARequest
	|		ON SalesSlip.Ref = RMARequest.Invoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.DocumentCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.DocumentCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RMARequest.Ref AS RMARequest,
	|	CASE
	|		WHEN SalesInvoiceInventory.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(SalesInvoiceInventory.Total / SalesInvoiceInventory.Quantity * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity)
	|					END, 0) AS NUMBER(15, 2))
	|	END AS SettlementsAmount,
	|	CASE
	|		WHEN SalesInvoiceInventory.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SalesInvoiceInventory.Total / SalesInvoiceInventory.Quantity * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.ExchangeRate * DocumentRates.Multiplicity / (DocumentRates.ExchangeRate * SettlementsRates.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN SalesInvoiceInventory.Total / SalesInvoiceInventory.Quantity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.ExchangeRate * DocumentRates.Multiplicity / (DocumentRates.ExchangeRate * SettlementsRates.Multiplicity))
	|					END, 0) AS NUMBER(15, 2))
	|	END AS PaymentAmount,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	RMARequest.UseSerialNumbers AS UseSerialNumbers,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	DocumentHeader.Order AS Order,
	|	BankAccounts.BankAccount AS BankAccount,
	|	DocumentRates.ExchangeRate AS CC_ExchangeRate,
	|	DocumentRates.Multiplicity AS CC_Multiplicity,
	|	SettlementsRates.ExchangeRate AS ExchangeRate,
	|	SettlementsRates.Multiplicity AS Multiplicity
	|INTO InventoryAmountTable
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN RMARequest AS RMARequest
	|		ON SalesInvoiceInventory.Ref = RMARequest.Invoice
	|			AND SalesInvoiceInventory.Products = RMARequest.Equipment
	|			AND SalesInvoiceInventory.Characteristic = RMARequest.Characteristic
	|		INNER JOIN DocumentHeader AS DocumentHeader
	|		ON SalesInvoiceInventory.Ref = DocumentHeader.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN TemporaryExchangeRate AS DocumentRates
	|		ON (DocumentHeader.DocumentCurrency = DocumentRates.Currency)
	|		LEFT JOIN TemporaryExchangeRate AS SettlementsRates
	|		ON (RMARequest.SettlementsCurrency = SettlementsRates.Currency)
	|
	|UNION ALL
	|
	|SELECT
	|	RMARequest.Ref,
	|	CASE
	|		WHEN SalesSlipInventory.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SalesSlipInventory.Total / SalesSlipInventory.Quantity * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN SalesSlipInventory.Total / SalesSlipInventory.Quantity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|					END, 0) AS NUMBER(15, 2))
	|	END,
	|	CASE
	|		WHEN SalesSlipInventory.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SalesSlipInventory.Total / SalesSlipInventory.Quantity * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.ExchangeRate * DocumentRates.Multiplicity / (DocumentRates.ExchangeRate * SettlementsRates.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN SalesSlipInventory.Total / SalesSlipInventory.Quantity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.ExchangeRate * DocumentRates.Multiplicity / (DocumentRates.ExchangeRate * SettlementsRates.Multiplicity))
	|					END, 0) AS NUMBER(15, 2))
	|	END,
	|	SalesSlipInventory.ConnectionKey,
	|	RMARequest.UseSerialNumbers,
	|	SalesSlipInventory.VATRate,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentHeader.Order,
	|	BankAccounts.BankAccount,
	|	DocumentRates.ExchangeRate,
	|	DocumentRates.Multiplicity,
	|	SettlementsRates.ExchangeRate,
	|	SettlementsRates.Multiplicity
	|FROM
	|	Document.SalesSlip.Inventory AS SalesSlipInventory
	|		INNER JOIN RMARequest AS RMARequest
	|		ON SalesSlipInventory.Ref = RMARequest.Invoice
	|			AND SalesSlipInventory.Products = RMARequest.Equipment
	|			AND SalesSlipInventory.Characteristic = RMARequest.Characteristic
	|		INNER JOIN DocumentHeader AS DocumentHeader
	|		ON SalesSlipInventory.Ref = DocumentHeader.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN TemporaryExchangeRate AS DocumentRates
	|		ON (DocumentHeader.DocumentCurrency = DocumentRates.Currency)
	|		LEFT JOIN TemporaryExchangeRate AS SettlementsRates
	|		ON (RMARequest.SettlementsCurrency = SettlementsRates.Currency)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryAmountTable.RMARequest AS RMARequest,
	|	InventoryAmountTable.SettlementsAmount AS SettlementsAmount,
	|	InventoryAmountTable.PaymentAmount AS PaymentAmount,
	|	InventoryAmountTable.VATRate AS VATRate,
	|	InventoryAmountTable.Order AS Order,
	|	InventoryAmountTable.DocumentCurrency AS DocumentCurrency,
	|	InventoryAmountTable.BankAccount AS BankAccount,
	|	InventoryAmountTable.CC_ExchangeRate AS CC_ExchangeRate,
	|	InventoryAmountTable.CC_Multiplicity AS CC_Multiplicity,
	|	InventoryAmountTable.ExchangeRate AS ExchangeRate,
	|	InventoryAmountTable.Multiplicity AS Multiplicity
	|INTO InventorySettlementAmounts
	|FROM
	|	InventoryAmountTable AS InventoryAmountTable
	|		LEFT JOIN ConnectionKeyTable AS ConnectionKeyTable
	|		ON InventoryAmountTable.ConnectionKey = ConnectionKeyTable.ConnectionKey,
	|	SerialNumbersQty AS SerialNumbersQty
	|WHERE
	|	(NOT InventoryAmountTable.UseSerialNumbers
	|			OR SerialNumbersQty.Qty = 0
	|			OR NOT ConnectionKeyTable.ConnectionKey IS NULL)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RMARequestWithCurrency.SettlementsCurrency AS SettlementsCurrency,
	|	RMARequestWithCurrency.Company AS Company,
	|	RMARequestWithCurrency.Counterparty AS Counterparty,
	|	RMARequestWithCurrency.Contract AS Contract,
	|	RMARequestWithCurrency.Ref AS BasisDocument,
	|	RMARequestWithCurrency.Invoice AS Document,
	|	CASE
	|		WHEN RMARequestWithCurrency.DoOperationsByOrders
	|			THEN ISNULL(InventorySettlementAmounts.Order, UNDEFINED)
	|		ELSE UNDEFINED
	|	END AS Order,
	|	VALUE(Enum.OperationTypesCashVoucher.ToCustomer) AS OperationKind,
	|	CASE
	|		WHEN RMARequestWithCurrency.RegisteredForVAT
	|			THEN VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|		ELSE VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	END AS VATTaxation,
	|	CASE
	|		WHEN NOT RMARequestWithCurrency.RegisteredForVAT
	|			THEN VALUE(Catalog.VATRates.Exempt)
	|		WHEN ISNULL(InventorySettlementAmounts.VATRate, VALUE(Catalog.VATRates.EmptyRef)) <> VALUE(Catalog.VATRates.EmptyRef)
	|			THEN InventorySettlementAmounts.VATRate
	|		WHEN RMARequestWithCurrency.DefaultVATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN VALUE(Catalog.VATRates.Exempt)
	|		ELSE RMARequestWithCurrency.DefaultVATRate
	|	END AS VATRate,
	|	InventorySettlementAmounts.BankAccount AS BankAccount,
	|	InventorySettlementAmounts.DocumentCurrency AS CashCurrency,
	|	ISNULL(InventorySettlementAmounts.CC_ExchangeRate, 1) AS CC_ExchangeRate,
	|	ISNULL(InventorySettlementAmounts.CC_Multiplicity, 1) AS CC_Multiplicity,
	|	ISNULL(InventorySettlementAmounts.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(InventorySettlementAmounts.Multiplicity, 1) AS Multiplicity,
	|	ISNULL(InventorySettlementAmounts.PaymentAmount, 0) AS PaymentAmount,
	|	ISNULL(InventorySettlementAmounts.SettlementsAmount, 0) AS SettlementsAmount
	|FROM
	|	RMARequestWithCurrency AS RMARequestWithCurrency
	|		LEFT JOIN InventorySettlementAmounts AS InventorySettlementAmounts
	|		ON RMARequestWithCurrency.Ref = InventorySettlementAmounts.RMARequest";
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		Rate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((Rate + 100) / 100);
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//
Procedure FillByCreditNote(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.BasisDocument AS BasisDocument
	|INTO DocumentHeader
	|FROM
	|	Document.CreditNote AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesPaymentExpense.ToCustomer) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	BankAccounts.BankAccount AS BankAccount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	DocumentHeader.Ref AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.CreditNote.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Ref,
	|	DocumentHeader.VATTaxation,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Contract,
	|	DocumentHeader.BasisDocument,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashTransferPlan(BasisDocument, Amount = Undefined)
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'Please select an approved cash transfer plan.'; ru = 'Нельзя ввести перемещение денег на основании неутвержденного планового документа.';pl = 'Wybierz zatwierdzony plan przelewów gotówkowych.';es_ES = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';es_CO = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';tr = 'Lütfen onaylı nakit transfer planını seçin.';it = 'Si prega di selezionare un piano di trasferimento contanti approvato.';de = 'Bitte wählen Sie einen genehmigten Überweisungsplan aus.'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);

	// Fill document header data.
	Query.Text =
	"SELECT ALLOWED
	|	VALUE(Enum.OperationTypesPaymentExpense.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.SubjectToVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.BankAccount.CashCurrency AS CashCurrency,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.DocumentAmount AS PaymentAmount
	|FROM
	|	Document.CashTransferPlan AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		VATTaxation = DriveServer.VATTaxation(Company, Date);
		If Amount <> Undefined Then
			DocumentAmount = Amount;
		EndIf;
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.PlanningDocument = BasisDocument;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.CashInflowForecast - Scheduled
// payment FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseInvoice(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesPaidGLAccount,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency
	|INTO DocumentHeader
	|FROM
	|	Document.SupplierInvoice AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.Total AS Total,
	|	DocumentTable.VATRate AS VATRate,
	|	DocumentTable.VATAmount AS VATAmount
	|INTO DocumentTable
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SupplierInvoice.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentHeader.Ref,
	|	DocumentTable.PurchaseOrder,
	|	DocumentTable.Total,
	|	DocumentTable.VATRate,
	|	DocumentTable.VATAmount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SupplierInvoice.Expenses AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	BankAccounts.BankAccount AS BankAccount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	DocumentHeader.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
	|	DocumentHeader.DocumentCurrency AS SettlementsCurrency
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN DocumentTable AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Contract,
	|	DocumentHeader.Ref,
	|	DocumentTable.VATRate,
	|	DocumentHeader.AdvancesPaidGLAccount,
	|	DocumentHeader.AccountsPayableGLAccount,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	DocumentHeader.DocumentCurrency";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByAdditionalExpenses(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesPaidGLAccount,
	|	DocumentHeader.PurchaseOrder AS PurchaseOrder
	|INTO DocumentHeader
	|FROM
	|	Document.AdditionalExpenses AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	BankAccounts.BankAccount AS BankAccount,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	DocumentHeader.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|INTO PaymentDetails
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.AdditionalExpenses.Expenses AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.Ref,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Contract,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentHeader.Counterparty,
	|	DocumentTable.VATRate,
	|	DocumentHeader.AdvancesPaidGLAccount,
	|	DocumentHeader.AccountsPayableGLAccount,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor),
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	DocumentHeader.Ref,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentHeader.Contract,
	|	FALSE,
	|	&Ref,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN AdditionalExpensesCustomsDeclaration.Amount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AdditionalExpensesCustomsDeclaration.Amount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)),
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN AdditionalExpensesCustomsDeclaration.Amount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN AdditionalExpensesCustomsDeclaration.Amount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN AdditionalExpensesCustomsDeclaration.Amount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN AdditionalExpensesCustomsDeclaration.Amount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END),
	|	VALUE(Catalog.VATRates.Exempt),
	|	0,
	|	DocumentHeader.AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.AdditionalExpenses.CustomsDeclaration AS AdditionalExpensesCustomsDeclaration
	|		ON DocumentHeader.Ref = AdditionalExpensesCustomsDeclaration.Ref
	|			AND (AdditionalExpensesCustomsDeclaration.IncludeToCurrentInvoice)
	|
	|GROUP BY
	|	DocumentHeader.Ref,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Contract,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.AdvancesPaidGLAccount,
	|	DocumentHeader.AccountsPayableGLAccount,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentDetails.OperationKind AS OperationKind,
	|	PaymentDetails.Item AS Item,
	|	PaymentDetails.BasisDocument AS BasisDocument,
	|	PaymentDetails.Company AS Company,
	|	PaymentDetails.CompanyVATNumber AS CompanyVATNumber,
	|	PaymentDetails.VATTaxation AS VATTaxation,
	|	PRESENTATION(PaymentDetails.Counterparty) AS AcceptedFrom,
	|	PaymentDetails.BankAccount AS BankAccount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	PaymentDetails.Counterparty AS Counterparty,
	|	PaymentDetails.CashCurrency AS CashCurrency,
	|	PaymentDetails.CC_ExchangeRate AS CC_ExchangeRate,
	|	PaymentDetails.CC_Multiplicity AS CC_Multiplicity,
	|	PaymentDetails.Order AS Order,
	|	PaymentDetails.Contract AS Contract,
	|	PaymentDetails.AdvanceFlag AS AdvanceFlag,
	|	PaymentDetails.Document AS Document,
	|	SUM(PaymentDetails.SettlementsAmount) AS SettlementsAmount,
	|	PaymentDetails.ExchangeRate AS ExchangeRate,
	|	PaymentDetails.Multiplicity AS Multiplicity,
	|	SUM(PaymentDetails.PaymentAmount) AS PaymentAmount,
	|	MAX(PaymentDetails.VATRate) AS VATRate,
	|	SUM(PaymentDetails.VATAmount) AS VATAmount,
	|	PaymentDetails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	PaymentDetails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|FROM
	|	PaymentDetails AS PaymentDetails
	|
	|GROUP BY
	|	PaymentDetails.CompanyVATNumber,
	|	PaymentDetails.CashCurrency,
	|	PaymentDetails.Order,
	|	PaymentDetails.BankAccount,
	|	PaymentDetails.Counterparty,
	|	PaymentDetails.AdvanceFlag,
	|	PaymentDetails.AccountsPayableGLAccount,
	|	PaymentDetails.OperationKind,
	|	PaymentDetails.BasisDocument,
	|	PaymentDetails.Contract,
	|	PaymentDetails.Item,
	|	PaymentDetails.Document,
	|	PaymentDetails.Company,
	|	PaymentDetails.VATTaxation,
	|	PaymentDetails.AdvancesPaidGLAccount,
	|	PaymentDetails.CC_ExchangeRate,
	|	PaymentDetails.CC_Multiplicity,
	|	PaymentDetails.ExchangeRate,
	|	PaymentDetails.Multiplicity";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByAccountSalesFromConsignee(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsReceivableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesReceivedGLAccount
	|INTO DocumentHeader
	|FROM
	|	Document.AccountSalesFromConsignee AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesPaymentExpense.ToCustomer) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	BankAccounts.BankAccount AS BankAccount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CASE
	|							WHEN DocumentHeader.AmountIncludesVAT
	|								THEN DocumentTable.BrokerageAmount
	|							ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|						END * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN CASE
	|							WHEN DocumentHeader.AmountIncludesVAT
	|								THEN DocumentTable.BrokerageAmount
	|							ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|						END / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN CASE
	|										WHEN DocumentHeader.AmountIncludesVAT
	|											THEN DocumentTable.BrokerageAmount
	|										ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|									END * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN CASE
	|										WHEN DocumentHeader.AmountIncludesVAT
	|											THEN DocumentTable.BrokerageAmount
	|										ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|									END / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN CASE
	|									WHEN DocumentHeader.AmountIncludesVAT
	|										THEN DocumentTable.BrokerageAmount
	|									ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|								END * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN CASE
	|									WHEN DocumentHeader.AmountIncludesVAT
	|										THEN DocumentTable.BrokerageAmount
	|									ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|								END / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.BrokerageVATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.BrokerageVATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.BrokerageVATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.BrokerageVATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	DocumentHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.AccountSalesFromConsignee.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentTable.VATRate,
	|	DocumentHeader.AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Ref,
	|	BankAccounts.BankAccount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Contract,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByAccountSalesToConsignor(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesPaidGLAccount
	|INTO DocumentHeader
	|FROM
	|	Document.AccountSalesToConsignor AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	BankAccounts.BankAccount AS BankAccount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN DocumentHeader.AmountIncludesVAT
	|					THEN CASE
	|							WHEN DocumentHeader.KeepBackCommissionFee
	|								THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|							ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|						END
	|				ELSE CASE
	|						WHEN DocumentHeader.KeepBackCommissionFee
	|							THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|						ELSE DocumentTable.AmountReceipt
	|					END
	|			END * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity)
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN DocumentHeader.AmountIncludesVAT
	|								THEN CASE
	|										WHEN DocumentHeader.KeepBackCommissionFee
	|											THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|										ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|									END
	|							ELSE CASE
	|									WHEN DocumentHeader.KeepBackCommissionFee
	|										THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|									ELSE DocumentTable.AmountReceipt
	|								END
	|						END * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN DocumentHeader.AmountIncludesVAT
	|							THEN CASE
	|									WHEN DocumentHeader.KeepBackCommissionFee
	|										THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|									ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|								END
	|						ELSE CASE
	|								WHEN DocumentHeader.KeepBackCommissionFee
	|									THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|								ELSE DocumentTable.AmountReceipt
	|							END
	|					END * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN DocumentHeader.KeepBackCommissionFee
	|								THEN DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageVATAmount
	|							ELSE DocumentTable.ReceiptVATAmount
	|						END * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN DocumentHeader.KeepBackCommissionFee
	|							THEN DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageVATAmount
	|						ELSE DocumentTable.ReceiptVATAmount
	|					END * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	DocumentHeader.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.AccountSalesToConsignor.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Ref,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Contract,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentTable.VATRate,
	|	DocumentHeader.AdvancesPaidGLAccount,
	|	DocumentHeader.AccountsPayableGLAccount,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillByCustomsDeclaration(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.DutyAmount + DocumentHeader.OtherDutyAmount + DocumentHeader.ExciseAmount + DocumentHeader.VATAmount AS Total,
	|	DocumentHeader.VATAmount AS VATAmount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount
	|INTO DocumentHeader
	|FROM
	|	Document.CustomsDeclaration AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	BankAccounts.BankAccount AS BankAccount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	DocumentHeader.Ref AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentHeader.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentHeader.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentHeader.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	VALUE(Catalog.VATRates.Exempt) AS VATRate,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentHeader.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentHeader.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	DocumentHeader.AccountsPayableGLAccount AS AccountsPayableGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Ref,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Contract,
	|	DocumentHeader.BasisDocument,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	DocumentHeader.Ref,
	|	DocumentHeader.AccountsPayableGLAccount";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySupplierQuote(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query;
	
	If LineNumber = Undefined Then
		Query.SetParameter("Ref", FillingData);
	Else
		Query.SetParameter("Ref", FillingData.Basis)
	EndIf;
	If Amount = Undefined Then
		Query.SetParameter("Amount", 0);
		Query.SetParameter("AmountIsSet", False);
	Else
		Query.SetParameter("Amount", Amount);
		Query.SetParameter("AmountIsSet", True);
	EndIf;
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("LineNumber", LineNumber);
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(FillingData.Company));
	
	Query.Text = 
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount
	|INTO DocumentHeader
	|FROM
	|	Document.SupplierQuote AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN &AmountIsSet
	|			THEN &Amount / DocumentHeader.DocumentAmount
	|		WHEN &LineNumber <> UNDEFINED
	|			THEN ISNULL((DocumentTable.PaymentAmount + CASE
	|						WHEN DocumentHeader.AmountIncludesVAT
	|							THEN 0
	|						ELSE DocumentTable.PaymentVATAmount
	|					END) / DocumentHeader.DocumentAmount, 0)
	|		ELSE 1
	|	END AS Coeff,
	|	CASE
	|		WHEN &AmountIsSet
	|			THEN &Amount
	|		WHEN &LineNumber <> UNDEFINED
	|			THEN ISNULL(DocumentTable.PaymentAmount + CASE
	|						WHEN DocumentHeader.AmountIncludesVAT
	|							THEN 0
	|						ELSE DocumentTable.PaymentVATAmount
	|					END, 0)
	|		ELSE DocumentHeader.DocumentAmount
	|	END AS Amount
	|INTO Coeffs
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.SupplierQuote.PaymentCalendar AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|			AND (DocumentTable.LineNumber = &LineNumber)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	BankAccounts.BankAccount AS BankAccount,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	UNDEFINED AS Document,
	|	DocumentTable.VATRate AS VATRate,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.VATAmount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	MIN(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CAST(Coeffs.Amount * CASE
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|									THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|									THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|							END AS NUMBER(15, 2)), 0)
	|			ELSE ISNULL(CAST(Coeffs.Amount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|						END AS NUMBER(15, 2)), 0)
	|		END) AS AmountNeeded
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN Coeffs AS Coeffs
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.SupplierQuote.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Contract,
	|	DocumentHeader.VATTaxation,
	|	DocumentTable.VATRate,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition";
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	FirstRow = True;
	AmountNeeded = 0;
	
	While Selection.Next() Do
		
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If FirstRow Then
			FillPropertyValues(ThisObject, Selection);
			ExchangeRate = Selection.CC_ExchangeRate;
			Multiplicity = Selection.CC_Multiplicity;
			AmountNeeded = Selection.AmountNeeded;
			MaxAmount = NewRow.PaymentAmount;
			MaxAmountRow = NewRow;
			FirstRow = False;
		EndIf;
		
		If NewRow.PaymentAmount > MaxAmount Then
			MaxAmount = NewRow.PaymentAmount;
			MaxAmountRow = NewRow;
		EndIf;
		
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	If DocumentAmount <> AmountNeeded And Not FirstRow Then
		CorrectSettlementsAmount = (MaxAmountRow.PaymentAmount = MaxAmountRow.SettlementsAmount);
		MaxAmountRow.PaymentAmount = MaxAmountRow.PaymentAmount + AmountNeeded - DocumentAmount;
		DocumentAmount = AmountNeeded;
		If CorrectSettlementsAmount Then
			MaxAmountRow.SettlementsAmount = MaxAmountRow.PaymentAmount;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseOrder(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query;
	
	If LineNumber = Undefined Then
		Documents.PurchaseOrder.CheckMustBeApproved(FillingData);
		Query.SetParameter("Ref", FillingData);
	Else
		Documents.PurchaseOrder.CheckMustBeApproved(FillingData.Basis);
		Query.SetParameter("Ref", FillingData.Basis)
	EndIf;
	
	If Amount = Undefined Then
		Query.SetParameter("Amount", 0);
		Query.SetParameter("AmountIsSet", False);
	Else
		Query.SetParameter("Amount", Amount);
		Query.SetParameter("AmountIsSet", True);
	EndIf;
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("LineNumber", LineNumber);
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(FillingData.Company));
	
	Query.Text = 
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount
	|INTO DocumentHeader
	|FROM
	|	Document.PurchaseOrder AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN &AmountIsSet
	|			THEN &Amount / DocumentHeader.DocumentAmount
	|		WHEN &LineNumber <> UNDEFINED
	|			THEN ISNULL((DocumentTable.PaymentAmount + CASE
	|						WHEN DocumentHeader.AmountIncludesVAT
	|							THEN 0
	|						ELSE DocumentTable.PaymentVATAmount
	|					END) / DocumentHeader.DocumentAmount, 0)
	|		ELSE 1
	|	END AS Coeff,
	|	CASE
	|		WHEN &AmountIsSet
	|			THEN &Amount
	|		WHEN &LineNumber <> UNDEFINED
	|			THEN ISNULL(DocumentTable.PaymentAmount + CASE
	|						WHEN DocumentHeader.AmountIncludesVAT
	|							THEN 0
	|						ELSE DocumentTable.PaymentVATAmount
	|					END, 0)
	|		ELSE DocumentHeader.DocumentAmount
	|	END AS Amount
	|INTO Coeffs
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.PurchaseOrder.PaymentCalendar AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|			AND (DocumentTable.LineNumber = &LineNumber)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	BankAccounts.BankAccount AS BankAccount,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	UNDEFINED AS Document,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS DocumentAmount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN Coeffs AS Coeffs
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Contract,
	|	BankAccounts.BankAccount,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		FillPaymentDetails();
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//
Procedure FillByPurchaseOrderDependOnBalanceForPayment(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(FillingData.Company));
	
	Query.Text = 
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount
	|INTO DocumentHeader
	|FROM
	|	Document.PurchaseOrder AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS SettlementsAmount,
	|	(InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity))
	|						END / DocumentHeader.DocumentAmount AS Coeff
	|INTO Coeffs
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN AccumulationRegister.InvoicesAndOrdersPayment.Turnovers AS InvoicesAndOrdersPaymentTurnovers
	|		ON DocumentHeader.Ref = InvoicesAndOrdersPaymentTurnovers.Quote
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	BankAccounts.BankAccount AS BankAccount,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	UNDEFINED AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN &Ref
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.VATRate AS VATRate,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.VATAmount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	Coeffs.SettlementsAmount AS SettlementsAmountNeeded
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN Coeffs AS Coeffs
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	BankAccounts.BankAccount,
	|	DocumentHeader.VATTaxation,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Contract,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN &Ref
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.VATRate,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	Coeffs.SettlementsAmount";
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	FirstRow = True;
	SettlementsAmountNeeded = 0;
	
	While Selection.Next() Do
		
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If FirstRow Then
			FillPropertyValues(ThisObject, Selection);
			ExchangeRate = Selection.CC_ExchangeRate;
			Multiplicity = Selection.CC_Multiplicity;
			SettlementsAmountNeeded = Selection.SettlementsAmountNeeded;
			MaxAmount = NewRow.SettlementsAmount;
			MaxAmountRow = NewRow;
			FirstRow = False;
		EndIf;
		
		If NewRow.PaymentAmount > MaxAmount Then
			MaxAmount = NewRow.PaymentAmount;
			MaxAmountRow = NewRow;
		EndIf;
		
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	TotalSettlementsAmount = PaymentDetails.Total("SettlementsAmount");
	If TotalSettlementsAmount <> SettlementsAmountNeeded And Not FirstRow Then
		CorrectPaymentAmount = (MaxAmountRow.PaymentAmount = MaxAmountRow.SettlementsAmount);
		MaxAmountRow.SettlementsAmount = MaxAmountRow.SettlementsAmount + SettlementsAmountNeeded - TotalSettlementsAmount;
		If CorrectPaymentAmount Then
			MaxAmountRow.PaymentAmount = MaxAmountRow.SettlementsAmount;
		EndIf;
	EndIf;
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPayrollSheet(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.DocumentAmount AS DocumentAmount
	|INTO DocumentHeader
	|FROM
	|	Document.PayrollSheet AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Company AS Company,
	|	VALUE(Enum.OperationTypesPaymentExpense.Salary) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	&Ref AS Statement,
	|	BankAccounts.BankAccount AS BankAccount,
	|	REFPRESENTATION(DocumentHeader.Ref) AS Basis,
	|	DocumentHeader.DocumentAmount AS DocumentAmount,
	|	DocumentHeader.DocumentAmount AS PaymentAmount,
	|	DocumentHeader.CashCurrency AS CashCurrency
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PayrollPayment.Clear();
		NewRow = PayrollPayment.Add();
		FillPropertyValues(NewRow, Selection);
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis of tax Earning.
//
// Parameters:
// BasisDocument - DocumentRef.CashInflowForecast - Scheduled
// payment FillingData - Structure - Data on filling the document.
//	
Procedure FillByTaxAccrual(BasisDocument)
	
	If BasisDocument.OperationKind <> Enums.OperationTypesTaxAccrual.Accrual Then
		Raise NStr("en = 'Please select a tax accrual with ""Accrual"" operation.'; ru = 'Выберите начисление налогов с операцией ""Начисление"".';pl = 'Wybierz naliczenie podatku za pomocą operacji ""Naliczanie"".';es_ES = 'Por favor, seleccione una acumulación de impuestos con la operación ""Acumulación"".';es_CO = 'Por favor, seleccione una acumulación de impuestos con la operación ""Acumulación"".';tr = 'Lütfen ""Tahakkuk"" işlemi ile bir vergi tahakkuku seçin.';it = 'Si prega di selezionare un accantonamento fiscale con Operazione ""Accantonamento"".';de = 'Bitte wählen Sie eine Steuerrückstellung mit der Operation ""Rückstellung"".'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref",	BasisDocument);
	Query.SetParameter("Date",	?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	Companies.PresentationCurrency AS CashCurrency,
	|	DocumentHeader.DocumentAmount AS DocumentAmount
	|INTO DocumentHeader
	|FROM
	|	Document.TaxAccrual AS DocumentHeader
	|		INNER JOIN Catalog.Companies AS Companies
	|		ON DocumentHeader.Company = Companies.Ref
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesPaymentExpense.Taxes) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	DocumentHeader.Company AS Company,
	|	BankAccounts.BankAccount AS BankAccount,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	VALUE(Catalog.VATRates.Exempt) AS VATRate,
	|	DocumentRates.Rate AS ExchangeRate,
	|	DocumentRates.Repetition AS Multiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount,
	|	DocumentTableTaxes.TaxKind AS TaxKind,
	|	DocumentTableTaxes.BusinessLine AS BusinessLine
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN (SELECT TOP 1
	|			DocumentTable.Ref AS Ref,
	|			DocumentTable.TaxKind AS TaxKind,
	|			DocumentTable.BusinessLine AS BusinessLine
	|		FROM
	|			Document.TaxAccrual.Taxes AS DocumentTable
	|		WHERE
	|			DocumentTable.Ref = &Ref) AS DocumentTableTaxes
	|		ON DocumentHeader.Ref = DocumentTableTaxes.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company";

	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		VATTaxation = DriveServer.VATTaxation(Company, Date);
		PaymentDetails.Clear();
		
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation(TabularSectionRow)
	
	If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
		TabularSectionRow.VATRate = Catalogs.VATRates.Exempt;
		TabularSectionRow.VATAmount = 0;
	ElsIf VATTaxation = Enums.VATTaxationTypes.ForExport Then	
		TabularSectionRow.VATRate = Catalogs.VATRates.ZeroRate;
		TabularSectionRow.VATAmount = 0;
	EndIf;
	
EndProcedure

// Defines field ExistsEPD in PaymentDetails tabular section
//
Procedure DefinePaymentDetailsExistsEPD() Export
	
	If OperationKind = Enums.OperationTypesPaymentExpense.Vendor AND PaymentDetails.Count() > 0 Then
		
		DocumentArray			= PaymentDetails.UnloadColumn("Document");
		CheckDate				= ?(ValueIsFilled(PaymentDate), PaymentDate, Date);
		CheckDate				= ?(ValueIsFilled(CheckDate), CheckDate, CurrentSessionDate());
		DocumentArrayWithEPD	= Documents.SupplierInvoice.GetSupplierInvoiceArrayWithEPD(DocumentArray, CheckDate);
		
		For Each TabularSectionRow In PaymentDetails Do
			
			If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SupplierInvoice") Then
				If DocumentArrayWithEPD.Find(TabularSectionRow.Document) = Undefined Then
					TabularSectionRow.ExistsEPD = False;
				Else
					TabularSectionRow.ExistsEPD = True;
				EndIf;
			Else
				TabularSectionRow.ExistsEPD = False;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Calculates Early payment discount.
//
Procedure CalculateEPD() Export
	
	If OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		
		DocumentTable = PaymentDetails.Unload(New Structure("ExistsEPD", True), "Document");
		
		ParentCompany = DriveServer.GetCompany(Company);
		
		If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
		ElsIf VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		Query = New Query;
		Query.Text =
		"SELECT DISTINCT
		|	DocumentTable.Document AS Document
		|INTO SupplierInvoiceTable
		|FROM
		|	&DocumentTable AS DocumentTable
		|WHERE
		|	DocumentTable.Document REFS Document.SupplierInvoice
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ExchangeRateSliceLast.Currency AS Currency,
		|	ExchangeRateSliceLast.Rate AS ExchangeRate,
		|	ExchangeRateSliceLast.Repetition AS Multiplicity
		|INTO ExchangeRateOnPeriod
		|FROM
		|	InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS ExchangeRateSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	AccountsPayableBalances.Company AS Company,
		|	AccountsPayableBalances.Counterparty AS Counterparty,
		|	AccountsPayableBalances.Contract AS Contract,
		|	AccountsPayableBalances.Document AS Document,
		|	AccountsPayableBalances.SettlementsType AS SettlementsType,
		|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
		|INTO AccountsPayableTable
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			,
		|			Company = &Company
		|				AND Counterparty = &Counterparty
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				AND Document IN
		|					(SELECT
		|						SupplierInvoiceTable.Document
		|					FROM
		|						SupplierInvoiceTable)) AS AccountsPayableBalances
		|
		|UNION ALL
		|
		|SELECT
		|	DocumentAccountsPayable.Company,
		|	DocumentAccountsPayable.Counterparty,
		|	DocumentAccountsPayable.Contract,
		|	DocumentAccountsPayable.Document,
		|	DocumentAccountsPayable.SettlementsType,
		|	CASE
		|		WHEN DocumentAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN -DocumentAccountsPayable.AmountCur
		|		ELSE DocumentAccountsPayable.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.AccountsPayable AS DocumentAccountsPayable
		|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
		|		ON DocumentAccountsPayable.Document = SupplierInvoiceTable.Document
		|WHERE
		|	DocumentAccountsPayable.Recorder = &Ref
		|	AND DocumentAccountsPayable.Period <= &PaymentDate
		|	AND DocumentAccountsPayable.Company = &Company
		|	AND DocumentAccountsPayable.Counterparty = &Counterparty
		|	AND DocumentAccountsPayable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountsPayableTable.Contract AS Contract,
		|	AccountsPayableTable.Document AS Document,
		|	SUM(AccountsPayableTable.AmountCurBalance) AS AmountCurBalance
		|INTO AccountsPayableGrouped
		|FROM
		|	AccountsPayableTable AS AccountsPayableTable
		|WHERE
		|	AccountsPayableTable.AmountCurBalance > 0
		|
		|GROUP BY
		|	AccountsPayableTable.Contract,
		|	AccountsPayableTable.Document
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	AccountsPayableGrouped.Contract AS Contract,
		|	AccountsPayableGrouped.Document AS Document,
		|	AccountsPayableGrouped.AmountCurBalance AS AmountCurBalance,
		|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
		|INTO AccountsPayableContract
		|FROM
		|	AccountsPayableGrouped AS AccountsPayableGrouped
		|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON AccountsPayableGrouped.Contract = CounterpartyContracts.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SupplierInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
		|	SupplierInvoiceEarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
		|	SupplierInvoiceEarlyPaymentDiscounts.Ref AS SupplierInvoice
		|INTO EarlyPaymentDiscounts
		|FROM
		|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
		|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
		|		ON SupplierInvoiceEarlyPaymentDiscounts.Ref = SupplierInvoiceTable.Document
		|WHERE
		|	ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &PaymentDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(EarlyPaymentDiscounts.DueDate) AS DueDate,
		|	EarlyPaymentDiscounts.SupplierInvoice AS SupplierInvoice
		|INTO EarlyPaymentMinDueDate
		|FROM
		|	EarlyPaymentDiscounts AS EarlyPaymentDiscounts
		|
		|GROUP BY
		|	EarlyPaymentDiscounts.SupplierInvoice
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	EarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
		|	EarlyPaymentDiscounts.SupplierInvoice AS SupplierInvoice
		|INTO EarlyPaymentMaxDiscountAmount
		|FROM
		|	EarlyPaymentDiscounts AS EarlyPaymentDiscounts
		|		INNER JOIN EarlyPaymentMinDueDate AS EarlyPaymentMinDueDate
		|		ON EarlyPaymentDiscounts.SupplierInvoice = EarlyPaymentMinDueDate.SupplierInvoice
		|			AND EarlyPaymentDiscounts.DueDate = EarlyPaymentMinDueDate.DueDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountsPayableContract.Contract AS Contract,
		|	AccountsPayableContract.Document AS Document,
		|	ExchangeRateOfDocument.ExchangeRate AS CashAssetsRate,
		|	ExchangeRateOfDocument.Multiplicity AS CashMultiplicity,
		|	SettlementsExchangeRate.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRate.Multiplicity AS Multiplicity,
		|	AccountsPayableContract.AmountCurBalance AS AmountCur,
		|	CAST(AccountsPayableContract.AmountCurBalance * CASE
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|				THEN SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|				THEN 1 / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity))
		|		END AS NUMBER(15, 2)) AS AmountCurDocument,
		|	ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) AS SettlementsEPDAmount,
		|	CAST(ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) * CASE
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|				THEN SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|				THEN 1 / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity))
		|		END AS NUMBER(15, 2)) AS EPDAmount
		|FROM
		|	AccountsPayableContract AS AccountsPayableContract
		|		LEFT JOIN ExchangeRateOnPeriod AS ExchangeRateOfDocument
		|		ON (ExchangeRateOfDocument.Currency = &Currency)
		|		LEFT JOIN ExchangeRateOnPeriod AS SettlementsExchangeRate
		|		ON AccountsPayableContract.SettlementsCurrency = SettlementsExchangeRate.Currency
		|		LEFT JOIN EarlyPaymentMaxDiscountAmount AS EarlyPaymentMaxDiscountAmount
		|		ON AccountsPayableContract.Document = EarlyPaymentMaxDiscountAmount.SupplierInvoice";
		
		Query.SetParameter("Company", ParentCompany);
		Query.SetParameter("Counterparty", Counterparty);
		Query.SetParameter("Period", Date);
		Query.SetParameter("PaymentDate", ?(ValueIsFilled(PaymentDate), PaymentDate, Date));
		Query.SetParameter("Currency", CashCurrency);
		Query.SetParameter("Ref", Ref);
		Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(ParentCompany));
		Query.SetParameter("DocumentTable", DocumentTable);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			FilterParameters = New Structure("Contract,Document,ExistsEPD", Selection.Contract, Selection.Document, True);
			
			PaymentRows			= PaymentDetails.FindRows(FilterParameters);
			PaymentTable		= PaymentDetails.Unload(FilterParameters);
			PaymentAmountTotal	= PaymentTable.Total("PaymentAmount") + PaymentTable.Total("EPDAmount");
			
			EPDAmount				= Selection.EPDAmount;
			SettlementsEPDAmount	= Selection.SettlementsEPDAmount;
			
			If PaymentAmountTotal >= Selection.AmountCurDocument Then
				ValidForEPD = True;
			Else
				ValidForEPD = False;
			EndIf;
				
			For each Row In PaymentRows Do
				
				Row.PaymentAmount			= Row.PaymentAmount + Row.EPDAmount;
				Row.SettlementsAmount		= Row.SettlementsAmount + Row.SettlementsEPDAmount;
				Row.EPDAmount				= 0;
				Row.SettlementsEPDAmount	= 0;
				
				If ValidForEPD Then
					
					If Row.PaymentAmount > EPDAmount Then
						
						Row.EPDAmount				= EPDAmount;
						Row.SettlementsEPDAmount	= SettlementsEPDAmount;
						Row.PaymentAmount			= Row.PaymentAmount - Row.EPDAmount;
						Row.SettlementsAmount		= Row.SettlementsAmount - Row.SettlementsEPDAmount;
						
						EPDAmount				= 0;
						SettlementsEPDAmount	= 0;
						
					Else
						
						Row.EPDAmount				= Row.PaymentAmount;
						Row.SettlementsEPDAmount	= Row.SettlementsAmount;
						Row.PaymentAmount			= 0;
						Row.SettlementsAmount		= 0;
						
						EPDAmount				= EPDAmount - Row.EPDAmount;
						SettlementsEPDAmount	= SettlementsEPDAmount - Row.SettlementsEPDAmount;
						
					EndIf;
					
				EndIf;
				
				VATRate = ?(ValueIsFilled(Row.VATRate), Row.VATRate, DefaultVATRate);
				
				Row.VATRate		= VATRate;
				Row.VATAmount	= Row.PaymentAmount - (Row.PaymentAmount) / ((VATRate.Rate + 100) / 100);
				
			EndDo;
			
		EndDo;
		
		PaymentRowsWithoutEPD = PaymentDetails.FindRows(New Structure("ExistsEPD", False));
		For each Row In PaymentRowsWithoutEPD Do
			
			If Row.EPDAmount > 0 Then
				
				Row.PaymentAmount			= Row.PaymentAmount + Row.EPDAmount;
				Row.SettlementsAmount		= Row.SettlementsAmount + Row.SettlementsEPDAmount;
				Row.EPDAmount				= 0;
				Row.SettlementsEPDAmount	= 0;
				
				VATRate = ?(ValueIsFilled(Row.VATRate), Row.VATRate, DefaultVATRate);
				
				Row.VATRate		= VATRate;
				Row.VATAmount	= Row.PaymentAmount - (Row.PaymentAmount) / ((VATRate.Rate + 100) / 100);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - DocumentRef.SubcontractorOrderIssued - Basis document.
//
Procedure FillBySubcontractorOrderIssued(FillingData)
	
	Query = New Query;
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(FillingData.Company));
	
	Query.Text = 
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount
	|INTO DocumentHeader
	|FROM
	|	Document.SubcontractorOrderIssued AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	BankAccounts.BankAccount AS BankAccount,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	UNDEFINED AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CASE
	|						WHEN BankAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN BankAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL(DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)), 0)
	|					END
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CASE
	|						WHEN BankAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL(DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN BankAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL(DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)), 0)
	|					END
	|		END) AS VATAmount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.SubcontractorOrderIssued.Products AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Contract,
	|	BankAccounts.BankAccount,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END";
	
	QueryResult = Query.Execute();	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - DocumentRef.SubcontractorInvoiceReceived - Basis document.
//
Procedure FillBySubcontractorInvoiceReceived(FillingData)
	
	Query = New Query;
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(FillingData.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.BasisDocument AS BasisDocument,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesPaidGLAccount
	|INTO DocumentHeader
	|FROM
	|	Document.SubcontractorInvoiceReceived AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	BankAccounts.BankAccount AS BankAccount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|				AND DocumentHeader.BasisDocument <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN DocumentHeader.BasisDocument
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN BankAccounts.Currency IS NULL
	|				THEN ISNULL(CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	DocumentHeader.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SubcontractorInvoiceReceived.Products AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|				AND DocumentHeader.BasisDocument <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN DocumentHeader.BasisDocument
	|		ELSE UNDEFINED
	|	END,
	|	BankAccounts.BankAccount,
	|	DocumentHeader.Contract,
	|	DocumentHeader.Ref,
	|	DocumentTable.VATRate,
	|	DocumentHeader.AdvancesPaidGLAccount,
	|	DocumentHeader.AccountsPayableGLAccount,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByDocumentPurchaseOrder(BasisDocument)
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	
	Query.Text = 
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash) AS PaymentTermsAreSetInNoncash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount
	|INTO DocumentHeader
	|FROM
	|	Document.PurchaseOrder AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	BankAccounts.BankAccount AS BankAccount,
	|	BankAccounts.Currency AS Currency
	|INTO BankAccounts
	|FROM
	|	(SELECT
	|		BankAccounts.Ref AS BankAccount,
	|		BankAccounts.CashCurrency AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.BankAccount = BankAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInNoncash)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND (Companies.BankAccountByDefault = BankAccounts.Ref)
	|				AND (NOT BankAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccounts.Ref,
	|		BankAccounts.CashCurrency,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON DocumentHeader.CashCurrency = BankAccounts.CashCurrency
	|				AND DocumentHeader.Company = BankAccounts.Owner
	|				AND (NOT BankAccounts.DeletionMark)) AS BankAccounts
	|
	|ORDER BY
	|	BankAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesPaymentExpense.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	BankAccounts.BankAccount AS BankAccount,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	UNDEFINED AS Document,
	|	SUM(ISNULL(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CASE
	|						WHEN BankAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN BankAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL(DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)), 0)
	|					END
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CASE
	|						WHEN BankAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL(DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN BankAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL(DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * BankAccountRates.Repetition / (BankAccountRates.Rate * SettlementsRates.Repetition)), 0)
	|					END
	|		END) AS VATAmount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN BankAccounts AS BankAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS BankAccountRates
	|		ON (BankAccounts.Currency = BankAccountRates.Currency)
	|			AND DocumentHeader.Company = BankAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	ISNULL(BankAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Contract,
	|	BankAccounts.BankAccount,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE BankAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN BankAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE BankAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
	EndIf;
	
EndProcedure

#Region BankCharges

Procedure BringDataToConsistentState()
	
	If Not UseBankCharges Then
	
		BankCharge			= Catalogs.BankCharges.EmptyRef();
		BankChargeItem		= Catalogs.CashFlowItems.EmptyRef();
		BankChargeAmount	= 0;
	
	EndIf;
	
EndProcedure

#EndRegion

#Region OtherSettlements

Procedure FillByLoanContract(DocRefLoanContract, Amount = Undefined) Export
	      
	Query = New Query;
	
	Query.SetParameter("Ref",			DocRefLoanContract);
	Query.SetParameter("Date",			?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("LoanKind",		Enums.LoanContractTypes.EmployeeLoanAgreement);
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT ALLOWED
		|	REFPRESENTATION(&Ref) AS Basis,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements)
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
		|			THEN VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty)
		|		ELSE VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
		|	END AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.SettlementsCurrency AS CashCurrency,
		|	DocumentTable.Employee AS AdvanceHolder,
		|	DocumentTable.Counterparty AS Counterparty,
		|	&Ref AS LoanContract,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(ExchangeRate.Rate, 1) AS ExchangeRate,
		|	ISNULL(ExchangeRate.Repetition, 1) AS Multiplicity,
		|	CAST(&Amount AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
		|			THEN DocumentTable.PrincipalItem
		|	END AS Item
		|FROM
		|	Document.LoanContract AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS ExchangeRate
		|		ON DocumentTable.SettlementsCurrency = ExchangeRate.Currency
		|			AND DocumentTable.Company = ExchangeRate.Company
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Ref.Company = AccountingPolicySliceLast.Company
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT ALLOWED
		|	REFPRESENTATION(&Ref) AS Basis,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements)
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
		|			THEN VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToCounterparty)
		|		ELSE VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
		|	END AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.SettlementsCurrency AS CashCurrency,
		|	DocumentTable.Employee AS AdvanceHolder,
		|	DocumentTable.Counterparty AS Counterparty,
		|	&Ref AS LoanContract,
		|	DocumentTable.Total AS DocumentAmount,
		|	DocumentTable.Total AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(ExchangeRate.Rate, 1) AS ExchangeRate,
		|	ISNULL(ExchangeRate.Repetition, 1) AS Multiplicity,
		|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
		|			THEN DocumentTable.PrincipalItem
		|	END AS Item,
		|	DocumentTable.BankAccount AS BankAccount
		|FROM
		|	Document.LoanContract AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS ExchangeRate
		|		ON DocumentTable.SettlementsCurrency = ExchangeRate.Currency
		|			AND DocumentTable.Company = ExchangeRate.Company
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Ref.Company = AccountingPolicySliceLast.Company
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	EndIf;
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
	
		PaymentDetails.Clear();
		If DocRefLoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement
			OR DocRefLoanContract.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement Then
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
		Else
			DocumentAmount = 0;
		EndIf;
		
		PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Company);
		
	EndIf;
	
EndProcedure

Procedure FillByAccrualsForLoans(FillingData) Export
	
	Query = New Query;
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		Query.SetParameter("Ref",					FillingData.Document);
		Query.SetParameter("Borrower",				FillingData.Borrower);
		Query.SetParameter("Counterparty",			FillingData.Lender);
		Query.SetParameter("LoanContract",			FillingData.LoanContract);
		Query.SetParameter("Currency",				FillingData.SettlementsCurrency);
		
	ElsIf FillingData.Accruals.Count() > 0 Then
		
		Query.SetParameter("Ref",					FillingData);
		Query.SetParameter("Borrower",				FillingData.Accruals[0].Borrower);
		Query.SetParameter("Counterparty",			FillingData.Accruals[0].Lender);
		Query.SetParameter("LoanContract",			FillingData.Accruals[0].LoanContract);
		Query.SetParameter("Currency",				FillingData.Accruals[0].SettlementsCurrency);
		
	Else
		Return;
	EndIf;
	
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query.Text =
	"SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesPaymentExpense.LoanSettlements) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Ref.Company AS Company,
	|	DocumentTable.SettlementsCurrency AS CashCurrency,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.AmountType AS TypeOfAmount,
	|	DocumentTable.Total AS PaymentAmount,
	|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
	|	ISNULL(ExchangeRate.Rate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRate.Repetition, 1) AS Multiplicity,
	|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
	|	DocumentTable.LoanContract.Counterparty AS Counterparty
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS ExchangeRate
	|		ON DocumentTable.SettlementsCurrency = ExchangeRate.Currency
	|			AND DocumentTable.Ref.Company = ExchangeRate.Company
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON DocumentTable.Ref.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.LoanContract = &LoanContract
	|	AND DocumentTable.SettlementsCurrency = &Currency
	|	AND DocumentTable.Lender = &Counterparty
	|	AND DocumentTable.Borrower = &Borrower
	|
	|ORDER BY
	|	DocumentTable.LineNumber";
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		
		PaymentDetails.Clear();
		
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
		
		PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Company);
		DocumentAmount = PaymentDetails.Total("PaymentAmount");
		
	EndIf;
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.ExpenditureRequest") Then
		FillByExpenditureRequest(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then	
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		FillByPurchaseInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AdditionalExpenses") Then
		FillByAdditionalExpenses(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AccountSalesFromConsignee") Then
		FillByAccountSalesFromConsignee(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AccountSalesToConsignor") Then
		FillByAccountSalesToConsignor(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PayrollSheet") Then
		FillByPayrollSheet(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByDocumentPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.SupplierQuote") Then
		FillBySupplierQuote(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.TaxAccrual") Then
		FillByTaxAccrual(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.LoanContract") Then
		FillByLoanContract(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.RMARequest") Then
		FillByRMARequest(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CreditNote") Then
		FillByCreditNote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorOrderIssued") Then
		FillBySubcontractorOrderIssued(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorInvoiceReceived") Then
		FillBySubcontractorInvoiceReceived(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomsDeclaration") Then
		FillByCustomsDeclaration(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("Basis") Then
			
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis)= Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.SupplierQuote") Then
			FillBySupplierQuote(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrder(FillingData, FillingData.LineNumber);
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("Document") Then
		
		If TypeOf(FillingData.Document) = Type("DocumentRef.SupplierQuote") Then
			FillBySupplierQuote(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrder(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.ExpenditureRequest") Then
			FillByExpenditureRequest(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashTransferPlan") Then
			FillByCashTransferPlan(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document)= Type("DocumentRef.LoanInterestCommissionAccruals") Then
			FillByAccrualsForLoans(FillingData);
		EndIf;
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	
	FillInEmployeeGLAccounts(False);
	
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountReceived");
	If OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		For Each Row In PaymentDetails Do
			Row.DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndDo;
	EndIf;
	
	FillCurrenciesRatesInPaymentDetails();
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	// Deletion of verifiable attributes from the structure depending
	// on the operation type.
	If OperationKind = Enums.OperationTypesPaymentExpense.Vendor
		Or OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
	
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		
		For Each RowPaymentDetails In PaymentDetails Do
			
			If Not ValueIsFilled(RowPaymentDetails.Document)
				And (OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
				Or (OperationKind = Enums.OperationTypesPaymentExpense.Vendor
				And Not RowPaymentDetails.AdvanceFlag)) Then
				
				If PaymentDetails.Count() = 1 Then
					
					If OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
						MessageText = NStr("en = 'Specify the shipment document or set the advance payment flag.'; ru = 'Укажите документ отгрузки или признак ""Авансовый платеж"".';pl = 'Określ dokument wysyłki lub ustaw flagę zaliczki.';es_ES = 'Especificar el documento de envío o establecer ca casilla de pago anticipado.';es_CO = 'Especificar el documento de envío o establecer ca casilla de pago anticipado.';tr = 'Gönderi belgesini belirleyin veya avans ödeme bayrağını ayarlayın.';it = 'Specificare il documento di spedizione o impostare il contrassegno di pagamento anticipato.';de = 'Geben Sie den Lieferbeleg an oder setzen Sie das Kennzeichen Vorauszahlung.'");
					Else
						MessageText = NStr("en = 'Specify a billing document.'; ru = 'Укажите документ расчетов';pl = 'Określ dokument rozliczeniowy.';es_ES = 'Especificar el documento de presupuesto.';es_CO = 'Especificar el documento de presupuesto.';tr = 'Fatura belgesi belirtin.';it = 'Specificare un documento di fatturazione.';de = 'Geben Sie einen Abrechnungsbeleg an.'");
					EndIf;
					
				Else
					
					If OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
						MessageText = NStr("en = 'Specify a shipment document or set advance payment flag in line #%1 of the payment allocation.'; ru = 'Укажите документ отгрузки или признак аванса в строке %1 списка ""Расшифровка платежа"".';pl = 'Określ dokument wysyłki lub zaznacz zaliczkę w wierszu nr %1 Alokacji płatności.';es_ES = 'Especificar un documento de envío o establecer una casilla de pago anticipado en la línea #%1 de la asignación de pago.';es_CO = 'Especificar un documento de envío o establecer una casilla de pago anticipado en la línea #%1 de la asignación de pago.';tr = 'Sevkiyat belgesi belirtin veya ödeme tahsisinin #%1 satırına avans ödeme işareti koyun.';it = 'Specificare un documento di spedizione o impostare il contrassegno di pagamento anticipato nella riga #%1 dell''assegnazione di pagamento.';de = 'Geben Sie einen Lieferbeleg an oder setzen Sie das Kennzeichen Vorauszahlung in der Zeile Nr %1 der Zahlungszuordnung.'");
					Else
						MessageText = NStr("en = 'Specify a billing document in line #%1 of the payment details.'; ru = 'Укажите документ расчетов в строке %1 списка ""Расшифровка платежа"".';pl = 'Określ dokument rozliczeniowy w wierszu nr %1 szczegółów płatności.';es_ES = 'Especificar el documento de facturación en la línea #%1 de los detalles de pago.';es_CO = 'Especificar el documento de facturación en la línea #%1 de los detalles de pago.';tr = 'Ödeme ayrıntılarının #%1 satırındaki faturalama belgesini belirleyin.';it = 'Specificare un documento di fatturazione nella linea #%1 dei dettagli di pagamento.';de = 'Geben Sie in der Zeile Nr %1 der Zahlungsdetails eine Abrechnungsbeleg an.'");
					EndIf;
					MessageText = StrTemplate(MessageText, String(RowPaymentDetails.LineNumber));
					
				EndIf;
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"PaymentDetails",
					RowPaymentDetails.LineNumber,
					"Document",
					Cancel
				);
			EndIf;
			
			If Not ValueIsFilled(RowPaymentDetails.Contract) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""Contract"" is required on line #%1 of the payment allocation.'; ru = 'В строке №%1 списка ""Расшифровка платежа"" необходимо указать ""Договор"".';pl = '""Kontrakt"" jest wymagany w wierszu nr %1 Alokacji płatności.';es_ES = 'El ""Contrato"" se requiere en la línea #%1 de la asignación de pago.';es_CO = 'El ""Contrato"" se requiere en la línea #%1 de la asignación de pago.';tr = 'Ödeme tahsisinin #%1 satırında ""Sözleşme"" zorunludur.';it = 'È richiesto il ""Contratto"" nella riga #%1 dell''assegnazione di pagamento.';de = 'Der ""Vertrag"" ist in der Zeile Nr.%1 der Zahlungszuordnung nötig.'"),
					String(RowPaymentDetails.LineNumber));
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"PaymentDetails",
					RowPaymentDetails.LineNumber,
					"Contract",
					Cancel);
				
			EndIf;
			
			If Not ValueIsFilled(RowPaymentDetails.SettlementsAmount) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""Contract amount"" is required on line #%1 of the payment allocation.'; ru = 'В строке №%1 списка ""Расшифровка платежа"" необходимо указать ""Сумма по договору"".';pl = '""Wartość kontraktu"" jest wymagana w wierszu nr %1 Alokacji płatności.';es_ES = 'El ""Importe del contrato"" se requiere en la línea # %1de la asignación de pago.';es_CO = 'El ""Importe del contrato"" se requiere en la línea # %1de la asignación de pago.';tr = 'Ödeme tahsisinin #%1 satırında ""Sözleşme tutarı"" zorunludur.';it = 'È richiesto ""Importo contratto"" nella riga #%1 dell''assegnazione di pagamento.';de = 'Der ""Vertragsbetrag"" ist in der Zeile Nr. %1 der Zahlungszuordnung nötig.'"),
					String(RowPaymentDetails.LineNumber));
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"PaymentDetails",
					RowPaymentDetails.LineNumber,
					"SettlementsAmount",
					Cancel);
				
			EndIf;
			
			If Not ValueIsFilled(RowPaymentDetails.PaymentAmount) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""Payment amount"" is required on line #%1 of the payment allocation.'; ru = 'В строке №%1 списка ""Расшифровка платежа"" необходимо указать ""Сумма платежа"".';pl = '""Kwota płatności"" jest wymagana w wierszu nr %1 Alokacji płatności.';es_ES = 'El ""Importe del pago"" se requiere en la línea #%1 de la asignación de pago.';es_CO = 'El ""Importe del pago"" se requiere en la línea #%1 de la asignación de pago.';tr = 'Ödeme tahsisinin #%1 satırında ""Ödeme Tutarı"" zorunludur.';it = 'È richiesto ""Importo del pagamento"" nella riga #%1 dell''assegnazione di pagamento.';de = 'Der ""Zahlungsbetrag"" ist in der Zeile Nr.%1 der Zahlungsverteilung nötig.'"),
					String(RowPaymentDetails.LineNumber));
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"PaymentDetails",
					RowPaymentDetails.LineNumber,
					"PaymentAmount",
					Cancel);
				
			EndIf;
				
			If Not ValueIsFilled(RowPaymentDetails.VATRate) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""VAT %"" is required on line #%1 of the payment allocation.'; ru = 'В строке №%1 списка ""Расшифровка платежа"" необходимо указать ""НДС %"".';pl = '""VAT %"" jest wymagany w wierszu nr %1 Alokacji płatności.';es_ES = 'El ""% de IVA"" se requiere en la línea #%1 de la asignación de pago.';es_CO = 'El ""% de IVA"" se requiere en la línea #%1 de la asignación de pago.';tr = 'Ödeme tahsisinin #%1 satırında ""%KDV"" zorunludur.';it = 'È richiesto ""% IVA"" nella riga #%1 dell''assegnazione di pagamento.';de = 'Der ""USt. %"" ist in der Zeile Nr.%1 der Zahlungszuordnung nötig.'"),
					String(RowPaymentDetails.LineNumber));
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"PaymentDetails",
					RowPaymentDetails.LineNumber,
					"VATRate",
					Cancel);
				
			EndIf;
			
			If Not ValueIsFilled(RowPaymentDetails.Item) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""Cash flow item"" is required on line #%1 of the payment allocation.'; ru = 'В строке №%1 списка ""Расшифровка платежа"" необходимо указать ""Статья ДДС"".';pl = '""Pozycja przepływów pieniężnych"" jest wymagana w wierszu nr %1 Alokacji płatności.';es_ES = 'El ""Elemento del flujo de caja"" se requiere en la línea #%1 de la asignación del pago.';es_CO = 'El ""Flujo de caja"" se requiere en la línea #%1 de la asignación de pago.';tr = 'Ödeme tahsisinin #%1 satırında ""Nakit Akışı Öğesi"" zorunludur.';it = 'È richiesto ""Voce del flusso di cassa"" nella riga #%1 dell''assegnazione di pagamento.';de = 'Die ""Cashflow-Posten"" ist in der Zeile Nr.%1 der Zahlungszuordnung nötig.'"),
					String(RowPaymentDetails.LineNumber));
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"PaymentDetails",
					RowPaymentDetails.LineNumber,
					"Item",
					Cancel);
				
			EndIf;

			If OperationKind = Enums.OperationTypesPaymentExpense.Vendor
				And RowPaymentDetails.ExistsEPD
				And Not ValueIsFilled(RowPaymentDetails.DiscountReceivedIncomeItem) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""Income item"" is required on line %1 of the ""Payment allocation"" list.'; ru = 'В строке %1 списка ""Расшифровка платежа"" необходимо указать ""Cтатью доходов"".';pl = 'Wymagana jest ""Pozycja dochodów"" w wierszu %1 listy ""Alokacja płatności"".';es_ES = 'El ""Artículo de ingresos"" se requiere en la línea %1 de la lista ""Asignación del pago"".';es_CO = 'El ""Artículo de ingresos"" se requiere en la línea %1 de la lista ""Asignación del pago"".';tr = '""Ödeme tahsisi"" listesinin %1 satırında ""Gelir kalemi"" gerekli.';it = 'La ""Voce di entrata"" è richiesta nella riga %1 dell''elenco ""Dettagli del pagamento"".';de = 'Die ""Position von Einnahme"" ist in der Zeile Nr.%1 der Liste ""Zahlungszuordnung"" erforderlich.'"),
					String(RowPaymentDetails.LineNumber));
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					,
					,
					,
					Cancel);
				
			EndIf;
			
		EndDo;
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		CheckPayments(PaymentAmount, DocumentAmount, CashCurrency, Cancel);
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.ToAdvanceHolder Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentMultiplier");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.DiscountReceivedIncomeItem");
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.Salary Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentMultiplier");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.DiscountReceivedIncomeItem");
		
		PaymentAmount = PayrollPayment.Total("PaymentAmount");
		CheckPayments(PaymentAmount, DocumentAmount, CashCurrency, Cancel);
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.Other Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		
		If ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentMultiplier");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.DiscountReceivedIncomeItem");
		
		If Not RegisterExpense Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.DiscountReceivedIncomeItem");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = StrTemplate(NStr("en = 'The document amount (%1 %2) is not equal to the sum of payments in the details section: (%3 %4).'; ru = 'Сумма документа: %1 %2, не соответствует сумме разнесенных платежей в табличной части: %3 %4!';pl = 'Kwota dokumentu (%1 %2) różni się od sumy płatności w sekcji szczegółów: (%3 %4).';es_ES = 'El importe del documento (%1 %2) no es igual a la suma de pagos en la sección de detalles: (%3 %4).';es_CO = 'El importe del documento (%1 %2) no es igual a la suma de pagos en la sección de detalles: (%3 %4).';tr = 'Belge tutarı (%1 %2) ayrıntılar bölümündeki ödeme toplamına eşit değildir: (%3 %4)';it = 'L''importo del documento (%1 %2) non è uguale alla somma dei pagamenti nei dettagli: (%3 %4%)!';de = 'Der Belegbetrag (%1 %2) entspricht nicht der Summe der Zahlungen im Detailbereich: (%3 %4).'"), 
									String(DocumentAmount), 
									String(CashCurrency), 
									String(PaymentAmount), 
									String(CashCurrency));
									
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentMultiplier");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.DiscountReceivedIncomeItem");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		If AdvanceHolder.IsEmpty() Then
			MessageText = NStr("en = 'The ""Advance holder"" field is required'; ru = 'Поле ""Сотрудник"" не заполнено';pl = 'Pole ""Zaliczkobiorca"" jest wymagane';es_ES = 'Se requiere el campo ""Titular de anticipo""';es_CO = 'Se requiere el campo ""Titular de anticipo""';tr = '""Avans sahibi"" alanı zorunludur';it = 'Il campo ""Persona che ha anticipato"" è richiesto';de = 'Das Feld ""Abrechnungspflichtige Person"" ist erforderlich.'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"AdvanceHolder",
				Cancel
			);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentMultiplier");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.DiscountReceivedIncomeItem");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		If Counterparty.IsEmpty() Then
			MessageText = NStr("en = 'The ""Counterparty"" field is required'; ru = 'Поле ""Контрагент"" не заполнено';pl = 'Pole ""Kontrahent"" jest wymagane';es_ES = 'El campo ""Contrapartida"" se requiere';es_CO = 'El campo ""Contrapartida"" se requiere';tr = '""Cari hesap"" alanı zorunludur';it = 'È richiesto il campo ""Controparte""';de = 'Das Feld ""Geschäftspartner"" ist erforderlich'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"Counterparty",
				Cancel
			);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentMultiplier");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.DiscountReceivedIncomeItem");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = StrTemplate(NStr("en = 'The document amount (%1 %2) is not equal to the sum of payments in the details section: (%3 %4).'; ru = 'Сумма документа: %1 %2, не соответствует сумме разнесенных платежей в табличной части: %3 %4!';pl = 'Kwota dokumentu (%1 %2) różni się od sumy płatności w sekcji szczegółów: (%3 %4).';es_ES = 'El importe del documento (%1 %2) no es igual a la suma de pagos en la sección de detalles: (%3 %4).';es_CO = 'El importe del documento (%1 %2) no es igual a la suma de pagos en la sección de detalles: (%3 %4).';tr = 'Belge tutarı (%1 %2) ayrıntılar bölümündeki ödeme toplamına eşit değildir: (%3 %4)';it = 'L''importo del documento (%1 %2) non è uguale alla somma dei pagamenti nei dettagli: (%3 %4%)!';de = 'Der Belegbetrag (%1 %2) entspricht nicht der Summe der Zahlungen im Detailbereich: (%3 %4).'"), 
									String(DocumentAmount), 
									String(CashCurrency), 
									String(PaymentAmount), 
									String(CashCurrency));
									
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
	
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.PaymentMultiplier");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.DiscountReceivedIncomeItem");
		
	EndIf;
	
	// Bank charges
	If Not UseBankCharges Then
	
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankCharge");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankChargeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankChargeAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankFeeExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankChargeExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankChargeMultiplier");
	
	EndIf;
	// End Bank charges
	
	If Not Paid Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDate");
		
		If GetFunctionalOption("UseBankReconciliation") And Not IsNew()
			And AccumulationRegisters.BankReconciliation.TransactionCleared(Ref, BankAccount) Then
			
			MessageText = NStr("en = 'The transaction is marked as Cleared in a Bank reconciliation,
							|the Paid option should be enabled.'; 
							|ru = 'Во взаиморасчетах с банком операция отмечена как выполненная,
							|следует включить опцию Оплачено.';
							|pl = 'Transakcja jest zaznaczona jako rozliczona w Uzgodnieniu bankowym,
							|Opcja Opłacono powinno być włączone.';
							|es_ES = 'La transacción está marcada como Liquidada en una conciliación bancaria, 
							|la opción Pagar debe estar habilitada.';
							|es_CO = 'La transacción está marcada como Liquidada en una conciliación bancaria, 
							|la opción Pagar debe estar habilitada.';
							|tr = 'İşlem, Banka mutabakatında Tahsil edildi olarak işaretlendi, 
							|Ödendi seçeneğinin etkinleştirilmesi gerekiyor.';
							|it = 'La transazione è contrassegnata come compensata nelle riconciliazioni bancarie,
							|l''opzione Pagata dovrebbe essere abilitata.';
							|de = 'Die Transaktion wird in einer Bankabstimmung als Ausgeglichen markiert,
							|die Option Bezahlt sollte aktiviert sein.'");
			CommonClientServer.MessageToUser(MessageText, ThisObject, "Paid", , Cancel);
			
		EndIf;
		
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Paid = False;
	ExportDate = Undefined;
	PaymentDate = Undefined;
	
	ExternalDocumentNumber = "";
	ExternalDocumentDate = "";
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	If IsNew() And DriveReUse.GetValueOfSetting("MarkBankPaymentsAsPaid") Then
		Paid = True;
		PaymentDate = Date;
	EndIf;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get()
		And ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
		
		BusinessLine = Catalogs.LinesOfBusiness.MainLine;
		
	EndIf;
	
	For Each TSRow In PaymentDetails Do
		If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
		
		If (OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements)
			AND TSRow.VATRate.IsEmpty() Then
			TSRow.VATRate	= Catalogs.VATRates.Exempt;
			TSRow.VATAmount	= 0;
		EndIf;
	EndDo;
	
	If (OperationKind = Enums.OperationTypesPaymentExpense.Vendor
			Or OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer)
		And PaymentDetails.Count() > 0 Then
		Item = PaymentDetails[0].Item;
	EndIf;
	
	// Bank charges
	BringDataToConsistentState();
	// End Bank charges
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.PaymentExpense.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBankReconciliation(AdditionalProperties, RegisterRecords, Cancel);
	
	If Paid Then
		// Registering in accounting sections
		DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	
		// Accounting
		DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);

		// Bank charges
		DriveServer.ReflectBankCharges(AdditionalProperties, RegisterRecords, Cancel);
		// End Bank charges
		DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
		
		//VAT
		DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Paid Then
		RunControlAdvanceBalances(AdditionalProperties, Cancel);
	EndIf;
	
	If Not Cancel Then
		
		If Paid Then
			WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
		EndIf;
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
	// Control of negative balance on cash receipt
	Documents.PaymentExpense.RunControl(Ref, AdditionalProperties, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
	// Control of negative balance on cash receipt
	Documents.PaymentExpense.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	If Not Cancel Then
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckPayments(PaymentAmount, DocumentAmount, CashCurrency, Cancel)
	
	If PaymentAmount <> DocumentAmount Then
		
		StringOfCashCurrency = TrimAll(String(CashCurrency));
		
		MessageText = StrTemplate(NStr("en = 'The document amount (%1 %2) is not equal to the sum of payments in the details section: (%3 %4).'; ru = 'Сумма документа: %1 %2, не соответствует сумме разнесенных платежей в табличной части: %3 %4!';pl = 'Kwota dokumentu (%1 %2) różni się od sumy płatności w sekcji szczegółów: (%3 %4).';es_ES = 'El importe del documento (%1 %2) no es igual a la suma de pagos en la sección de detalles: (%3 %4).';es_CO = 'El importe del documento (%1 %2) no es igual a la suma de pagos en la sección de detalles: (%3 %4).';tr = 'Belge tutarı (%1 %2) ayrıntılar bölümündeki ödeme toplamına eşit değildir: (%3 %4)';it = 'L''importo del documento (%1 %2) non è uguale alla somma dei pagamenti nei dettagli: (%3 %4%)!';de = 'Der Belegbetrag (%1 %2) entspricht nicht der Summe der Zahlungen im Detailbereich: (%3 %4).'"), 
			String(DocumentAmount),
			StringOfCashCurrency,
			String(PaymentAmount),
			StringOfCashCurrency);
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"DocumentAmount",
			Cancel);
	EndIf;
		
EndProcedure

Procedure FillCurrenciesRatesInPaymentDetails()
	
	DriveServer.FillCurrenciesRatesInPaymentDetails(ThisObject);
	
EndProcedure

Procedure RunControlAdvanceBalances(AdditionalProperties, Cancel)
	
	If Not Constants.CheckStockBalanceOnPosting.Get() 
		Or Not AdditionalProperties.Property("Modified") 
		Or Not AdditionalProperties.Modified Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentExpense.Counterparty AS Counterparty,
	|	TS_PaymentDetails.Contract AS Contract,
	|	CounterpartyContracts.SettlementsCurrency AS Currency,
	|	TS_PaymentDetails.Document AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|				AND PaymentExpense.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND PaymentExpense.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN PaymentExpense.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	SUM(TS_PaymentDetails.SettlementsAmount) AS SumCurOnWrite,
	|	MAX(TS_PaymentDetails.LineNumber) AS LineNumber
	|INTO DocumentTable
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|		INNER JOIN Document.PaymentExpense.PaymentDetails AS TS_PaymentDetails
	|		ON PaymentExpense.Ref = TS_PaymentDetails.Ref
	|			AND (TS_PaymentDetails.AdvanceFlag)
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON PaymentExpense.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TS_PaymentDetails.Contract = CounterpartyContracts.Ref
	|WHERE
	|	PaymentExpense.Ref = &Ref
	|
	|GROUP BY
	|	PaymentExpense.Counterparty,
	|	TS_PaymentDetails.Contract,
	|	TS_PaymentDetails.Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|				AND PaymentExpense.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND PaymentExpense.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN PaymentExpense.Order
	|		ELSE UNDEFINED
	|	END,
	|	CounterpartyContracts.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.PresentationCurrency AS PresentationCurrencyPresentation,
	|	DocumentTable.Counterparty AS CounterpartyPresentation,
	|	DocumentTable.Contract AS ContractPresentation,
	|	DocumentTable.Currency AS CurrencyPresentation,
	|	DocumentTable.Document AS DocumentPresentation,
	|	DocumentTable.Order AS OrderPresentation,
	|	DocumentTable.SettlementsType AS CalculationsTypesPresentation,
	|	DocumentTable.SumCurOnWrite AS SumCurOnWrite,
	|	-ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
	|	DocumentTable.LineNumber AS LineNumber
	|FROM
	|	DocumentTable AS DocumentTable
	|		INNER JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
	|		ON DocumentTable.Company = AccountsReceivableBalances.Company
	|			AND DocumentTable.PresentationCurrency = AccountsReceivableBalances.PresentationCurrency
	|			AND DocumentTable.Counterparty = AccountsReceivableBalances.Counterparty
	|			AND DocumentTable.Contract = AccountsReceivableBalances.Contract
	|			AND DocumentTable.Document = AccountsReceivableBalances.Document
	|			AND DocumentTable.Order = AccountsReceivableBalances.Order
	|			AND DocumentTable.SettlementsType = AccountsReceivableBalances.SettlementsType
	|			AND (DocumentTable.SumCurOnWrite + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", AdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("Ref", Ref);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		QueryResultSelection = Result.Select();
		DriveServer.ShowMessageAboutPostingReturnAdvanceToAccountsRegisterErrors(Ref, QueryResultSelection, Cancel);
	EndIf;

EndProcedure

#EndRegion

#EndIf
