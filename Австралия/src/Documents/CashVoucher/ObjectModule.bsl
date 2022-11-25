#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillInEmployeeGLAccounts(ByEmployee = True, ByDefault = True) Export
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	If ByEmployee And ValueIsFilled(AdvanceHolder) Then
		EmployeeAttributes = Common.ObjectAttributesValues(AdvanceHolder, "AdvanceHoldersGLAccount, OverrunGLAccount");
		AdvanceHoldersReceivableGLAccount = EmployeeAttributes.AdvanceHoldersGLAccount;
		AdvanceHoldersPayableGLAccount = EmployeeAttributes.OverrunGLAccount;
	EndIf;
	
	If ByDefault Then
		
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
	|	AccountsPayableBalances.PresentationCurrency AS PresentationCurrency,
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
	|				AND PresentationCurrency = &PresentationCurrency
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsPayable.Company,
	|	DocumentAccountsPayable.PresentationCurrency,
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
	|	AND DocumentAccountsPayable.Period <= &Period
	|	AND DocumentAccountsPayable.Company = &Company
	|	AND DocumentAccountsPayable.Counterparty = &Counterparty
	|	AND DocumentAccountsPayable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|	AND DocumentAccountsPayable.PresentationCurrency = &PresentationCurrency
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
	|	AccountsPayableTable.Document AS Document
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
	|	ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.Period AS Period
	|INTO EntriesRecorderPeriod
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON AccountingJournalEntries.Recorder = DocumentTable.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableContract.Contract AS Contract,
	|	AccountsPayableContract.Item AS Item,
	|	AccountsPayableContract.Document AS Document,
	|	ISNULL(EntriesRecorderPeriod.Period, DATETIME(1, 1, 1)) AS DocumentDate,
	|	AccountsPayableContract.Order AS Order,
	|	ExchangeRateOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRateOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRate.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRate.Multiplicity AS Multiplicity,
	|	AccountsPayableContract.AmountCurBalance AS AmountCurBalance,
	|	CAST(AccountsPayableContract.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCurDocument,
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
	|		LEFT JOIN EntriesRecorderPeriod AS EntriesRecorderPeriod
	|		ON AccountsPayableContract.Document = EntriesRecorderPeriod.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableWithDiscount.Contract AS Contract,
	|	AccountsPayableWithDiscount.Item AS Item,
	|	AccountsPayableWithDiscount.Document AS Document,
	|	AccountsPayableWithDiscount.DocumentDate AS DocumentDate,
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
	|	AccountsPayableWithDiscount.DocumentDate,
	|	AccountsPayableWithDiscount.ExistsEPD,
	|	AccountsPayableWithDiscount.Order
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("PresentationCurrency", DriveServer.GetPresentationCurrency(ParentCompany));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(ParentCompany));	
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Date);
	Query.SetParameter("PeriodEndOfDay", EndOfDay(Date));
	Query.SetParameter("Currency", CashCurrency);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("IsOrderSet", IsOrderSet);
	Query.SetParameter("Order", BasisDocument);
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Ref, OperationKind);
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		Company,
		ContractTypesList);
	
	StructureContractCurrencyRateByDefault = CurrencyRateOperations.GetCurrencyRate(Date, ContractByDefault.SettlementsCurrency, Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountReceived");
	IsVendor = OperationKind = Enums.OperationTypesCashVoucher.Vendor;
	
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
				
				VATAmount					= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100);
				NewRow.VATAmount			= VATAmount;
				
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurDocument;
				VATAmountLeftToDistribute	= VATAmountLeftToDistribute - VATAmount;
				
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
			NewRow.ExchangeRate = ?(
				StructureContractCurrencyRateByDefault.Rate = 0,
				1,
				StructureContractCurrencyRateByDefault.Rate);
				
			NewRow.Multiplicity = ?(
				StructureContractCurrencyRateByDefault.Repetition = 0,
				1,
				StructureContractCurrencyRateByDefault.Repetition);
				
			NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRateMethod,
				ExchangeRateCurrenciesDC,
				NewRow.ExchangeRate,
				CurrencyUnitConversionFactor,
				NewRow.Multiplicity);
				
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
	|SELECT
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
	|		ELSE AccountsReceivableGrouped.AmountCur * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN SettlementsRates.ExchangeRate * CashCurrencyRates.Multiplicity / CashCurrencyRates.ExchangeRate / SettlementsRates.Multiplicity
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (SettlementsRates.ExchangeRate * CashCurrencyRates.Multiplicity / CashCurrencyRates.ExchangeRate / SettlementsRates.Multiplicity)
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
	
	Query.SetParameter("Company"             , ParentCompany);
	Query.SetParameter("PresentationCurrency", DriveServer.GetPresentationCurrency(ParentCompany));
	Query.SetParameter("ExchangeRateMethod"  , DriveServer.GetExchangeMethod(ParentCompany));
	Query.SetParameter("Counterparty"        , Counterparty);
	Query.SetParameter("Period"              , Date);
	Query.SetParameter("PeriodEndOfDay"      , EndOfDay(Date));
	Query.SetParameter("Ref"                 , Ref);
	Query.SetParameter("Currency"            , CashCurrency);
	
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
		
		DocumentAmount = PaymentDetails.Total("PaymentAmount");
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByExpenditureRequest(BasisDocument, Amount = Undefined)
	
	StructureBasisDoc = Common.ObjectAttributesValues(
		BasisDocument,
		"PaymentConfirmationStatus, CashAssetType, CashFlowItem");
		
	If StructureBasisDoc.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'Please select an approved Payment request.'; ru = 'Выберите утвержденную заявку на расходование средств.';pl = 'Wybierz zatwierdzone wezwanie do zapłaty.';es_ES = 'Por favor, seleccione una solicitud de Pago aprobado.';es_CO = 'Por favor, seleccione una solicitud de Pago aprobado.';tr = 'Lütfen, onaylanmış bir Ödeme talebi seçin.';it = 'Si prega di selezionare una Richiesta di pagamento approvata.';de = 'Bitte wählen Sie eine genehmigte Zahlungsaufforderung aus.'");
	EndIf;
	If StructureBasisDoc.CashAssetType = Enums.CashAssetTypes.Noncash Then
		Raise NStr("en = 'Please select an Payment request with a cash or undefined payment method.'; ru = 'Выберите заявку на расходование средств посредством денежных средств или с неопределенным способом оплаты.';pl = 'Wybierz wezwanie do zapłaty za pomocą gotówki lub niezdefiniowanej metody płatności.';es_ES = 'Por favor, seleccione una solicitud de Pago en efectivo o un método de pago no definido.';es_CO = 'Por favor, seleccione una solicitud de Pago en efectivo o un método de pago no definido.';tr = 'Lütfen, nakit veya tanımsız ödeme yöntemli bir Ödeme talebi seçin.';it = 'Si prega di selezionare una Richiesta di pagamento con metodo di pagamento in contanti o non definito.';de = 'Bitte wählen Sie eine Zahlungsaufforderung mit einer Barzahlung oder einer nicht definierten Zahlungsmethode aus.'");
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
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashVoucher.Salary) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.BasisDocument AS Statement,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.CashFlowItem AS Item,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.DocumentAmount AS DocumentAmount,
		|	DocumentHeader.DocumentAmount AS PaymentAmount
		|FROM
		|	Document.ExpenditureRequest AS DocumentHeader
		|WHERE
		|	DocumentHeader.Ref = &Ref";
	
	ElsIf Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT ALLOWED
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.BasisDocument AS RequestBasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	DocumentTable.PettyCash AS PettyCash,
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
		|	CAST(&Amount * CASE
		|			WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRate.Rate <> 0
		|					AND ExchangeRateOfDocument.Repetition <> 0
		|				THEN ExchangeRateOfDocument.Rate * CASE
		|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|							THEN SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1))
		|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|							THEN 1 / (SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1)))
		|					END
		|			ELSE 1
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
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT ALLOWED
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.BasisDocument AS RequestBasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	DocumentTable.PettyCash AS PettyCash,
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
		|	CAST(DocumentTable.DocumentAmount * CASE
		|			WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRate.Rate <> 0
		|					AND ExchangeRateOfDocument.Repetition <> 0
		|				THEN ExchangeRateOfDocument.Rate * CASE
		|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|							THEN SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1))
		|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|							THEN 1 / (SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1)))
		|					END
		|			ELSE 1
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
	
	DocumentDate          = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	Company               = Common.ObjectAttributeValue(BasisDocument, "Company");
	PresentationCurrency  = DriveServer.GetPresentationCurrency(Company);
	
	Query = New Query;
	Query.SetParameter("Ref"                 , BasisDocument);
	Query.SetParameter("Company"             , Company);
	Query.SetParameter("DocumentDate"        , DocumentDate);
	Query.SetParameter("PresentationCurrency", PresentationCurrency);
	Query.SetParameter("Company"             , Company);
	Query.SetParameter("ExchangeRateMethod"  , DriveServer.GetExchangeMethod(Company));
	
	Query.Text =
	"SELECT ALLOWED
	|	AccountingPolicySliceLast.Company AS Company,
	|	AccountingPolicySliceLast.DefaultVATRate AS DefaultVATRate,
	|	AccountingPolicySliceLast.RegisteredForVAT AS RegisteredForVAT
	|INTO TemporaryAccountingPolicy
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&DocumentDate, Company = &Company) AS AccountingPolicySliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO TemporaryExchangeRate
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
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
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RMARequest.Ref AS RMARequest,
	|	CASE
	|		WHEN SalesInvoiceInventory.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(SalesInvoiceInventory.Total / SalesInvoiceInventory.Quantity * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|		END, 0) AS NUMBER(15, 2))
	|	END AS SettlementsAmount,
	|	CASE
	|		WHEN SalesInvoiceInventory.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(SalesInvoiceInventory.Total / SalesInvoiceInventory.Quantity * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsRates.ExchangeRate * DocumentRates.Multiplicity / (DocumentRates.ExchangeRate * SettlementsRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsRates.ExchangeRate * DocumentRates.Multiplicity / (DocumentRates.ExchangeRate * SettlementsRates.Multiplicity))
	|		END, 0) AS NUMBER(15, 2))
	|	END AS PaymentAmount,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	RMARequest.UseSerialNumbers AS UseSerialNumbers,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	DocumentHeader.Order AS Order,
	|	CashAccounts.PettyCash AS PettyCash,
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
	|		LEFT JOIN CashAccounts AS CashAccounts
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
	|		ELSE CAST(ISNULL(SalesSlipInventory.Total / SalesSlipInventory.Quantity * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|		END, 0) AS NUMBER(15, 2))
	|	END,
	|	CASE
	|		WHEN SalesSlipInventory.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(SalesSlipInventory.Total / SalesSlipInventory.Quantity * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsRates.ExchangeRate * DocumentRates.Multiplicity / (DocumentRates.ExchangeRate * SettlementsRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsRates.ExchangeRate * DocumentRates.Multiplicity / (DocumentRates.ExchangeRate * SettlementsRates.Multiplicity))
	|		END, 0) AS NUMBER(15, 2))
	|	END,
	|	SalesSlipInventory.ConnectionKey,
	|	RMARequest.UseSerialNumbers,
	|	SalesSlipInventory.VATRate,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentHeader.Order,
	|	CashAccounts.PettyCash,
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
	|		LEFT JOIN CashAccounts AS CashAccounts
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
	|	InventoryAmountTable.PettyCash AS PettyCash,
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
	|	InventorySettlementAmounts.PettyCash AS PettyCash,
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
Procedure FillByCashTransferPlan(BasisDocument, Amount = Undefined)
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'Please select an approved cash transfer plan.'; ru = 'Нельзя ввести перемещение денег на основании неутвержденного планового документа.';pl = 'Wybierz zatwierdzony plan przelewów gotówkowych.';es_ES = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';es_CO = 'Por favor, seleccione un plan de traslado de efectivo aprobado.';tr = 'Lütfen onaylı nakit transfer planını seçin.';it = 'Si prega di selezionare un piano di trasferimento contanti approvato.';de = 'Bitte wählen Sie einen genehmigten Überweisungsplan aus.'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);

	// Fill document header data.
	Query.Text =
	"SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.SubjectToVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
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

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySupplierInvoice(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(BasisDocument.Company));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoice.ExchangeRate AS ExchangeRate,
	|	SupplierInvoice.Multiplicity AS Multiplicity,
	|	SupplierInvoice.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SupplierInvoice.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SupplierInvoice.SetPaymentTerms
	|		AND SupplierInvoice.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.PettyCash AS PettyCash,
	|	SupplierInvoice.VATTaxation AS VATTaxation,
	|	SupplierInvoice.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoice.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoice.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesPaidGLAccount
	|INTO SupplierInvoice
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		SupplierInvoice AS SupplierInvoice
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON SupplierInvoice.PettyCash = CashAccounts.Ref
	|				AND (SupplierInvoice.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		SupplierInvoice AS SupplierInvoice
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON SupplierInvoice.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON SupplierInvoice.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		SupplierInvoice AS SupplierInvoice
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON SupplierInvoice.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoice.VATTaxation AS VATTaxation,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	SupplierInvoice.Contract AS Contract,
	|	CashAccounts.PettyCash AS PettyCash,
	|	ISNULL(CashAccounts.Currency, SupplierInvoice.DocumentCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	ISNULL(SupplierInvoiceInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity))
	|		END, 0) AS SettlementsAmount,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN ISNULL(SupplierInvoiceInventory.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		ELSE ISNULL(SupplierInvoiceInventory.Total * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|				END, 0)
	|	END AS PaymentAmount,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN ISNULL(SupplierInvoiceInventory.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		ELSE ISNULL(SupplierInvoiceInventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|				END, 0)
	|	END AS VATAmount,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Order = UNDEFINED
	|				OR VALUETYPE(SupplierInvoiceInventory.Order) = TYPE(Document.SalesOrder)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE SupplierInvoiceInventory.Order
	|	END AS PurchaseOrder,
	|	CASE
	|		WHEN VALUETYPE(SupplierInvoice.BasisDocument) = TYPE(Document.SalesInvoice)
	|				AND SupplierInvoice.BasisDocument <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN SupplierInvoice.BasisDocument
	|		ELSE &Ref
	|	END AS Document,
	|	SupplierInvoice.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	SupplierInvoice.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|INTO Table
	|FROM
	|	SupplierInvoice AS SupplierInvoice
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON SupplierInvoice.Ref = SupplierInvoiceInventory.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON SupplierInvoice.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND SupplierInvoice.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON SupplierInvoice.DocumentCurrency = DocumentRates.Currency
	|			AND SupplierInvoice.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND SupplierInvoice.Company = SettlementsRates.Company
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoice.Company,
	|	SupplierInvoice.CompanyVATNumber,
	|	SupplierInvoice.VATTaxation,
	|	SupplierInvoice.Counterparty,
	|	SupplierInvoice.Contract,
	|	CashAccounts.PettyCash,
	|	ISNULL(CashAccounts.Currency, SupplierInvoice.DocumentCurrency),
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	ISNULL(SupplierInvoiceExpenses.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity))
	|		END, 0),
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN ISNULL(SupplierInvoiceExpenses.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		ELSE ISNULL(SupplierInvoiceExpenses.Total * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|				END, 0)
	|	END,
	|	SupplierInvoiceExpenses.VATRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN ISNULL(SupplierInvoiceExpenses.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		ELSE ISNULL(SupplierInvoiceExpenses.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|				END, 0)
	|	END,
	|	SupplierInvoiceExpenses.PurchaseOrder,
	|	CASE
	|		WHEN VALUETYPE(SupplierInvoice.BasisDocument) = TYPE(Document.SalesInvoice)
	|				AND SupplierInvoice.BasisDocument <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN SupplierInvoice.BasisDocument
	|		ELSE &Ref
	|	END,
	|	SupplierInvoice.AccountsPayableGLAccount,
	|	SupplierInvoice.AdvancesPaidGLAccount
	|FROM
	|	SupplierInvoice AS SupplierInvoice
	|		INNER JOIN Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
	|		ON SupplierInvoice.Ref = SupplierInvoiceExpenses.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON SupplierInvoice.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND SupplierInvoice.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON SupplierInvoice.DocumentCurrency = DocumentRates.Currency
	|			AND SupplierInvoice.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND SupplierInvoice.Company = SettlementsRates.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	Table.Document AS Document,
	|	Table.Company AS Company,
	|	Table.CompanyVATNumber AS CompanyVATNumber,
	|	Table.VATTaxation AS VATTaxation,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	Table.Counterparty AS Counterparty,
	|	Table.CashCurrency AS CashCurrency,
	|	Table.Contract AS Contract,
	|	Table.PettyCash AS PettyCash,
	|	FALSE AS AdvanceFlag,
	|	Table.VATRate AS VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN Table.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	&Ref AS BasisDocument,
	|	Table.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	Table.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
	|	MAX(Table.CC_ExchangeRate) AS CC_ExchangeRate,
	|	MAX(Table.CC_Multiplicity) AS CC_Multiplicity,
	|	MAX(Table.ExchangeRate) AS ExchangeRate,
	|	MAX(Table.Multiplicity) AS Multiplicity,
	|	SUM(Table.PaymentAmount) AS PaymentAmount,
	|	SUM(Table.VATAmount) AS VATAmount,
	|	SUM(Table.SettlementsAmount) AS SettlementsAmount
	|FROM
	|	Table AS Table
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Table.Counterparty = Counterparties.Ref
	|
	|GROUP BY
	|	Table.Company,
	|	Table.CompanyVATNumber,
	|	Table.VATTaxation,
	|	Table.Counterparty,
	|	Table.CashCurrency,
	|	Table.Contract,
	|	Table.PettyCash,
	|	Table.VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN Table.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	Table.Document,
	|	Table.AccountsPayableGLAccount,
	|	Table.AdvancesPaidGLAccount";
	
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
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesCashVoucher.ToCustomer) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	CashAccounts.PettyCash AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	DocumentHeader.Ref AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	SUM(ISNULL(DocumentTable.Total * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(DocumentTable.Total * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(DocumentTable.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(DocumentTable.VATAmount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(DocumentTable.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
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
	|	DocumentHeader.Ref,
	|	DocumentHeader.BasisDocument,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	CashAccounts.PettyCash,
	|	DocumentHeader.Counterparty,
	|	CashAccounts.Currency,
	|	DocumentHeader.CashCurrency,
	|	DocumentHeader.Contract,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Ref";
	
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
//  FillingData - Structure - Data on filling the document.
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
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.PurchaseOrder AS PurchaseOrder,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	DocumentHeader.PettyCash AS PettyCash,
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
	|	Document.AdditionalExpenses AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.PettyCash = CashAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	&Ref AS Document,
	|	CashAccounts.PettyCash AS PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.DocumentCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(ISNULL(DocumentTable.Total * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(DocumentTable.Total * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(DocumentTable.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(DocumentTable.VATAmount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(DocumentTable.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	DocumentHeader.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.AdditionalExpenses.Expenses AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.DocumentCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	CashAccounts.PettyCash,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	CashAccounts.Currency,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	DocumentHeader.AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.DocumentCurrency)";
	
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
//  FillingData - Structure - Data on filling the document.
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
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	DocumentHeader.PettyCash AS PettyCash,
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
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.PettyCash = CashAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationTypesCashVoucher.ToCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	CashAccounts.PettyCash AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.DocumentCurrency) AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	&Ref AS Document,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.AmountIncludesVAT
	|						THEN DocumentTable.BrokerageAmount * CASE
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|									THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|									THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|							END
	|					ELSE (DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount) * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|						END
	|				END AS NUMBER(15, 2)), 0)) AS SettlementsAmount,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.AmountIncludesVAT
	|						THEN DocumentTable.BrokerageAmount
	|					ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|				END * CASE
	|					WHEN CashAccounts.Currency IS NULL
	|						THEN CASE
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|									THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|									THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|							END
	|					ELSE CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|						END
	|				END AS NUMBER(15, 2)), 0)) AS PaymentAmount,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN CashAccounts.Currency IS NULL
	|						THEN DocumentTable.BrokerageVATAmount * CASE
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|									THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|									THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|							END
	|					ELSE DocumentTable.BrokerageVATAmount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|						END
	|				END AS NUMBER(15, 2)), 0)) AS VATAmount,
	|	DocumentHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.AccountSalesFromConsignee.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.DocumentCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	CashAccounts.PettyCash,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	CashAccounts.Currency,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	DocumentHeader.AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.DocumentCurrency)";
	
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
//  FillingData - Structure - Data on filling the document.
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
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.KeepBackCommissionFee AS KeepBackCommissionFee,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	DocumentHeader.PettyCash AS PettyCash,
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
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.PettyCash = CashAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	CashAccounts.PettyCash AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.DocumentCurrency) AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	&Ref AS Document,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.AmountIncludesVAT
	|						THEN CASE
	|								WHEN DocumentHeader.KeepBackCommissionFee
	|									THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|								ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|							END
	|					ELSE CASE
	|							WHEN DocumentHeader.KeepBackCommissionFee
	|								THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|							ELSE DocumentTable.AmountReceipt
	|						END
	|				END * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END AS NUMBER(15, 2)), 0)) AS SettlementsAmount,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.AmountIncludesVAT
	|						THEN CASE
	|								WHEN DocumentHeader.KeepBackCommissionFee
	|									THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|								ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|							END
	|					ELSE CASE
	|							WHEN DocumentHeader.KeepBackCommissionFee
	|								THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|							ELSE DocumentTable.AmountReceipt
	|						END
	|				END * CASE
	|					WHEN CashAccounts.Currency IS NULL
	|						THEN CASE
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|									THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|									THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|							END
	|					ELSE CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|						END
	|				END AS NUMBER(15, 2)), 0)) AS PaymentAmount,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.KeepBackCommissionFee
	|						THEN DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageVATAmount
	|					ELSE DocumentTable.ReceiptVATAmount
	|				END * CASE
	|					WHEN CashAccounts.Currency IS NULL
	|						THEN CASE
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|									THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|									THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|							END
	|					ELSE CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|						END
	|				END AS NUMBER(15, 2)), 0)) AS VATAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	DocumentHeader.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.AccountSalesToConsignor.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.DocumentCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	CashAccounts.PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.DocumentCurrency),
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Contract,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.VATRate,
	|	DocumentHeader.AccountsPayableGLAccount,
	|	DocumentHeader.AdvancesPaidGLAccount,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySupplierQuote(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
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
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(Query.Parameters.Ref.Company));	
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
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
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.PettyCash = CashAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
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
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	UNDEFINED AS Document,
	|	VALUE(Document.SupplierQuote.EmptyRef) AS Quote,
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
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	MIN(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(CAST(Coeffs.Amount * CASE
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|									THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|									THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|							END AS NUMBER(15, 2)), 0)
	|			ELSE ISNULL(CAST(Coeffs.Amount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|						END AS NUMBER(15, 2)), 0)
	|		END) AS AmountNeeded
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.SupplierQuote.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Coeffs AS Coeffs
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentTable.VATRate,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Contract,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
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
	
	Query = New Query();
	
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
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(Query.Parameters.Ref.Company));	
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order
	|INTO DocumentHeader
	|FROM
	|	Document.PurchaseOrder AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.PettyCash = CashAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
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
	|		LEFT JOIN Document.SalesOrder.PaymentCalendar AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|			AND (DocumentTable.LineNumber = &LineNumber)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	CashAccounts.PettyCash AS PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS DocumentAmount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Coeffs AS Coeffs
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Contract,
	|	CashAccounts.PettyCash,
	|	DocumentHeader.VATTaxation,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Counterparty,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		FillPropertyValues(ThisObject, Selection);
		ExchangeRate = Selection.CC_ExchangeRate;
		Multiplicity = Selection.CC_Multiplicity;
		
		FillPaymentDetails();
		
	Endif;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//
Procedure FillByPurchaseOrderDependOnBalanceForPayment(FillingData)
	
	Query = New Query();
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentSessionDate());
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(FillingData.Company));	
	
	Query.Text =
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
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
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.PettyCash = CashAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS SettlementsAmount,
	|	(InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity))
	|			END / DocumentHeader.DocumentAmount AS Coeff
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
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Date AS Date,
	|	&Ref AS BasisDocument,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN &Ref
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	CashAccounts.PettyCash AS PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
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
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS PaymentAmount,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentTable.VATAmount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentTable.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS VATAmount,
	|	MIN(Coeffs.SettlementsAmount) AS SettlementsAmountNeeded
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Coeffs AS Coeffs
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
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
	|	DocumentHeader.Counterparty,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN &Ref
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentHeader.VATTaxation,
	|	DocumentTable.VATRate,
	|	CashAccounts.PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Contract,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition";
	
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
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Company AS Company,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	VALUE(Enum.OperationTypesCashVoucher.Salary) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	&Ref AS Statement,
	|	CashAccounts.PettyCash AS PettyCash,
	|	REFPRESENTATION(DocumentHeader.Ref) AS Basis,
	|	DocumentHeader.DocumentAmount AS DocumentAmount,
	|	DocumentHeader.DocumentAmount AS PaymentAmount,
	|	DocumentHeader.CashCurrency AS CashCurrency
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN CashAccounts AS CashAccounts
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
// BasisDocument - DocumentRef.CashInflowForecast - Scheduled payment 
// FillingData   - Structure - Data on filling the document.
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
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON DocumentHeader.Company = Companies.Ref
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.Taxes) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	DocumentHeader.Company AS Company,
	|	CashAccounts.PettyCash AS PettyCash,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	VALUE(Catalog.VATRates.Exempt) AS VATRate,
	|	DocumentRates.Rate AS ExchangeRate,
	|	DocumentRates.Repetition AS Multiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount,
	|	DocumentTableTaxes.TaxKind AS TaxKind,
	|	DocumentTableTaxes.BusinessLine AS BusinessLine
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN CashAccounts AS CashAccounts
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
	
	If OperationKind = Enums.OperationTypesCashVoucher.Vendor AND PaymentDetails.Count() > 0 Then
		
		DocumentArray			= PaymentDetails.UnloadColumn("Document");
		CheckDate				= ?(ValueIsFilled(Date), Date, CurrentSessionDate());
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
	
	If OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
		
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
		|	AND DocumentAccountsPayable.Period <= &Period
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
		|SELECT
		|	SupplierInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
		|	SupplierInvoiceEarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
		|	SupplierInvoiceEarlyPaymentDiscounts.Ref AS SupplierInvoice
		|INTO EarlyPaymentDiscounts
		|FROM
		|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
		|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
		|		ON SupplierInvoiceEarlyPaymentDiscounts.Ref = SupplierInvoiceTable.Document
		|WHERE
		|	ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
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
		Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(ParentCompany));
		Query.SetParameter("Counterparty", Counterparty);
		Query.SetParameter("Period", Date);
		Query.SetParameter("Currency", CashCurrency);
		Query.SetParameter("Ref", Ref);
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
	
	Query = New Query();
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
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	CashAccounts.PettyCash AS PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
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
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL(DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)), 0)
	|					END
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL(DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL(DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)), 0)
	|					END
	|		END) AS VATAmount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	Contracts.CashFlowItem AS Item
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SubcontractorOrderIssued.Products AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Contract,
	|	CashAccounts.PettyCash,
	|	DocumentHeader.VATTaxation,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Counterparty,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	Contracts.CashFlowItem";
	
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
	|	SubcontractorInvoiceReceived.Ref AS Ref,
	|	SubcontractorInvoiceReceived.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorInvoiceReceived.ExchangeRate AS ExchangeRate,
	|	SubcontractorInvoiceReceived.Multiplicity AS Multiplicity,
	|	SubcontractorInvoiceReceived.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SubcontractorInvoiceReceived.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SubcontractorInvoiceReceived.SetPaymentTerms
	|		AND SubcontractorInvoiceReceived.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	SubcontractorInvoiceReceived.Company AS Company,
	|	SubcontractorInvoiceReceived.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoiceReceived.Counterparty AS Counterparty,
	|	SubcontractorInvoiceReceived.Contract AS Contract,
	|	SubcontractorInvoiceReceived.PettyCash AS PettyCash,
	|	SubcontractorInvoiceReceived.VATTaxation AS VATTaxation,
	|	SubcontractorInvoiceReceived.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceReceived.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceReceived.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesPaidGLAccount
	|INTO SubcontractorInvoiceReceived
	|FROM
	|	Document.SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|WHERE
	|	SubcontractorInvoiceReceived.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON SubcontractorInvoiceReceived.PettyCash = CashAccounts.Ref
	|				AND (SubcontractorInvoiceReceived.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON SubcontractorInvoiceReceived.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON SubcontractorInvoiceReceived.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON SubcontractorInvoiceReceived.DocumentCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SubcontractorInvoiceReceived.Company AS Company,
	|	SubcontractorInvoiceReceived.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoiceReceived.VATTaxation AS VATTaxation,
	|	SubcontractorInvoiceReceived.Counterparty AS Counterparty,
	|	SubcontractorInvoiceReceived.Contract AS Contract,
	|	CashAccounts.PettyCash AS PettyCash,
	|	ISNULL(CashAccounts.Currency, SubcontractorInvoiceReceived.DocumentCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS CC_Multiplicity,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	ISNULL(SubcontractorInvoiceReceivedProducts.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity))
	|		END, 0) AS SettlementsAmount,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN ISNULL(SubcontractorInvoiceReceivedProducts.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		ELSE ISNULL(SubcontractorInvoiceReceivedProducts.Total * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|				END, 0)
	|	END AS PaymentAmount,
	|	SubcontractorInvoiceReceivedProducts.VATRate AS VATRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN ISNULL(SubcontractorInvoiceReceivedProducts.VATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		ELSE ISNULL(SubcontractorInvoiceReceivedProducts.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (SubcontractorInvoiceReceived.ExchangeRate * SubcontractorInvoiceReceived.ContractCurrencyMultiplicity / (SubcontractorInvoiceReceived.ContractCurrencyExchangeRate * SubcontractorInvoiceReceived.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|				END, 0)
	|	END AS VATAmount,
	|	CASE
	|		WHEN SubcontractorInvoiceReceived.BasisDocument = VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE SubcontractorInvoiceReceived.BasisDocument
	|	END AS Order,
	|	&Ref AS Document,
	|	SubcontractorInvoiceReceived.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	SubcontractorInvoiceReceived.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|INTO SubcontractorInvoiceReceivedTable
	|FROM
	|	SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|		INNER JOIN Document.SubcontractorInvoiceReceived.Products AS SubcontractorInvoiceReceivedProducts
	|		ON SubcontractorInvoiceReceived.Ref = SubcontractorInvoiceReceivedProducts.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON SubcontractorInvoiceReceived.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND SubcontractorInvoiceReceived.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON SubcontractorInvoiceReceived.DocumentCurrency = DocumentRates.Currency
	|			AND SubcontractorInvoiceReceived.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND SubcontractorInvoiceReceived.Company = SettlementsRates.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	SubcontractorInvoiceReceivedTable.Document AS Document,
	|	SubcontractorInvoiceReceivedTable.Company AS Company,
	|	SubcontractorInvoiceReceivedTable.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoiceReceivedTable.VATTaxation AS VATTaxation,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	SubcontractorInvoiceReceivedTable.Counterparty AS Counterparty,
	|	SubcontractorInvoiceReceivedTable.CashCurrency AS CashCurrency,
	|	SubcontractorInvoiceReceivedTable.Contract AS Contract,
	|	SubcontractorInvoiceReceivedTable.PettyCash AS PettyCash,
	|	FALSE AS AdvanceFlag,
	|	SubcontractorInvoiceReceivedTable.VATRate AS VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN SubcontractorInvoiceReceivedTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	&Ref AS BasisDocument,
	|	SubcontractorInvoiceReceivedTable.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	SubcontractorInvoiceReceivedTable.AdvancesPaidGLAccount AS AdvancesPaidGLAccount,
	|	MAX(SubcontractorInvoiceReceivedTable.CC_ExchangeRate) AS CC_ExchangeRate,
	|	MAX(SubcontractorInvoiceReceivedTable.CC_Multiplicity) AS CC_Multiplicity,
	|	MAX(SubcontractorInvoiceReceivedTable.ExchangeRate) AS ExchangeRate,
	|	MAX(SubcontractorInvoiceReceivedTable.Multiplicity) AS Multiplicity,
	|	SUM(SubcontractorInvoiceReceivedTable.PaymentAmount) AS PaymentAmount,
	|	SUM(SubcontractorInvoiceReceivedTable.VATAmount) AS VATAmount,
	|	SUM(SubcontractorInvoiceReceivedTable.SettlementsAmount) AS SettlementsAmount
	|FROM
	|	SubcontractorInvoiceReceivedTable AS SubcontractorInvoiceReceivedTable
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SubcontractorInvoiceReceivedTable.Counterparty = Counterparties.Ref
	|
	|GROUP BY
	|	SubcontractorInvoiceReceivedTable.Company,
	|	SubcontractorInvoiceReceivedTable.CompanyVATNumber,
	|	SubcontractorInvoiceReceivedTable.VATTaxation,
	|	SubcontractorInvoiceReceivedTable.Counterparty,
	|	SubcontractorInvoiceReceivedTable.CashCurrency,
	|	SubcontractorInvoiceReceivedTable.Contract,
	|	SubcontractorInvoiceReceivedTable.PettyCash,
	|	SubcontractorInvoiceReceivedTable.VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN SubcontractorInvoiceReceivedTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	SubcontractorInvoiceReceivedTable.Document,
	|	SubcontractorInvoiceReceivedTable.AccountsPayableGLAccount,
	|	SubcontractorInvoiceReceivedTable.AdvancesPaidGLAccount";
	
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
	
	Query = New Query();
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
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order
	|INTO DocumentHeader
	|FROM
	|	Document.PurchaseOrder AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	CashAccounts.PettyCash AS PettyCash,
	|	CashAccounts.Currency AS Currency
	|INTO CashAccounts
	|FROM
	|	(SELECT
	|		CashAccounts.Ref AS PettyCash,
	|		CashAccounts.CurrencyByDefault AS Currency,
	|		1 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.PettyCash = CashAccounts.Ref
	|				AND (DocumentHeader.PaymentTermsAreSetInCash)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		2
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.Companies AS Companies
	|			ON DocumentHeader.Company = Companies.Ref
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (Companies.PettyCashByDefault = CashAccounts.Ref)
	|				AND (NOT CashAccounts.DeletionMark)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CashAccounts.Ref,
	|		CashAccounts.CurrencyByDefault,
	|		3
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.CashAccounts AS CashAccounts
	|			ON DocumentHeader.CashCurrency = CashAccounts.CurrencyByDefault
	|				AND (NOT CashAccounts.DeletionMark)) AS CashAccounts
	|
	|ORDER BY
	|	CashAccounts.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	CashAccounts.PettyCash AS PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency) AS CashCurrency,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END AS CC_ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
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
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL(DocumentTable.Total / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)), 0)
	|					END
	|		END) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL(DocumentTable.VATAmount * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL(DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL(DocumentTable.VATAmount / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)), 0)
	|					END
	|		END) AS VATAmount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	Contracts.CashFlowItem AS Item
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN CashAccounts AS CashAccounts
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS CashAccountRates
	|		ON (CashAccounts.Currency = CashAccountRates.Currency)
	|			AND DocumentHeader.Company = CashAccountRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS DocumentRates
	|		ON DocumentHeader.CashCurrency = DocumentRates.Currency
	|			AND DocumentHeader.Company = DocumentRates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Contract,
	|	CashAccounts.PettyCash,
	|	DocumentHeader.VATTaxation,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Counterparty,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Rate
	|		ELSE CashAccountRates.Rate
	|	END,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END,
	|	SettlementsRates.Rate,
	|	SettlementsRates.Repetition,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	Contracts.CashFlowItem";
	
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

#EndRegion

#Region EventHandlers

// Procedure - handler of the OnCopy event.
//
Procedure OnCopy(CopiedObject)
	
	SalesSlipNumber = "";
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.ExpenditureRequest") Then
		FillByExpenditureRequest(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		FillBySupplierInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CreditNote") Then
		FillByCreditNote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AdditionalExpenses") Then
		FillByAdditionalExpenses(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AccountSalesFromConsignee") Then
		FillByAccountSalesFromConsignee(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AccountSalesToConsignor") Then
		FillByAccountSalesToConsignor(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByDocumentPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.SupplierQuote") Then
		FillBySupplierQuote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PayrollSheet") Then
		FillByPayrollSheet(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.TaxAccrual") Then
		FillByTaxAccrual(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.LoanContract") Then
		FillByLoanContract(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.RMARequest") Then
		FillByRMARequest(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorOrderIssued") Then
		FillBySubcontractorOrderIssued(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorInvoiceReceived") Then
		FillBySubcontractorInvoiceReceived(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Basis") Then
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis)= Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.SupplierQuote") Then
			FillBySupplierQuote(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.ExpenditureRequest") Then
			FillByExpenditureRequest(FillingData.Document, FillingData.Amount);
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
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	FillInEmployeeGLAccounts(False);
	
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountReceived");
	If OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		For Each Row In PaymentDetails Do
			Row.DiscountReceivedIncomeItem = DefaultIncomeItem;
		EndDo;
	EndIf;
	
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
	If OperationKind = Enums.OperationTypesCashVoucher.Vendor
		Or OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Item");
				
		For Each RowPaymentDetails In PaymentDetails Do
			If Not ValueIsFilled(RowPaymentDetails.Document)
				And (OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
					Or (OperationKind = Enums.OperationTypesCashVoucher.Vendor
						And Not RowPaymentDetails.AdvanceFlag)) Then
				
				If PaymentDetails.Count() = 1 Then
					If OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
						MessageText = NStr("en = 'Specify a shipment document or an advance payment.'; ru = 'Укажите документ отгрузки или признак аванса платежа.';pl = 'Określ dokument wysyłki lub płatność zaliczkową.';es_ES = 'Especificar un documentos de envío o un pago anticipado.';es_CO = 'Especificar un documentos de envío o un pago anticipado.';tr = 'Sevkiyat belgesi veya avans ödeme belirtin.';it = 'Specificare un documento di spedizione o un pagamento di anticipo.';de = 'Geben Sie einen Lieferbeleg oder eine Vorauszahlung an.'");
					Else
						MessageText = NStr("en = 'Specify a billing document.'; ru = 'Укажите документ расчетов';pl = 'Określ dokument rozliczeniowy.';es_ES = 'Especificar el documento de presupuesto.';es_CO = 'Especificar el documento de presupuesto.';tr = 'Fatura belgesi belirtin.';it = 'Specificare un documento di fatturazione.';de = 'Geben Sie einen Abrechnungsbeleg an.'");
					EndIf;
				Else
					If OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
						MessageText = NStr("en = 'Specify a shipment document or payment flag in line #%LineNumber% of the payment details.'; ru = 'Укажите документ отгрузки или признак оплаты в строке %LineNumber% списка ""Расшифровка платежа"".';pl = 'Określ dokument wysyłki lub zaznacz płatność w wierszu nr %LineNumber% szczegółów płatności.';es_ES = 'Especificar un documento de envío o la casilla de pago en la línea #%LineNumber% de los detalles de pago.';es_CO = 'Especificar un documento de envío o la casilla de pago en la línea #%LineNumber% de los detalles de pago.';tr = 'Ödeme ayrıntılarının no %LineNumber% satırında bir sevkiyat belgesi ya da ödeme bayrağı belirtin.';it = 'Specificare un documento di spedizione o il contrassegno di pagamento nella linea #%LineNumber% dell''elenco ""Dettagli di pagamento"".';de = 'Geben Sie in der Zeile Nr %LineNumber% der Zahlungsdetails einen Lieferbeleg oder ein Zahlungskennzeichen an.'");
					Else
						MessageText = NStr("en = 'Specify a billing document in line #%LineNumber% of the payment details.'; ru = 'Укажите документ расчетов в строке №%LineNumber% списка ""Расшифровка платежа"".';pl = 'Określ dokument rozliczeniowy w wierszu nr %LineNumber% szczegółów płatności.';es_ES = 'Especificar el documento de facturación en la línea #%LineNumber% de los detalles de pago.';es_CO = 'Especificar el documento de facturación en la línea #%LineNumber% de los detalles de pago.';tr = 'Ödeme ayrıntılarının #%LineNumber% satırındaki faturalama belgesini belirleyin.';it = 'Specificare un documento di fatturazione nella linea #%LineNumber% dei dettagli di pagamento.';de = 'Geben Sie in der Zeile Nr %LineNumber% der Zahlungsdetails eine Abrechnungsbeleg an.'");
					EndIf;
					MessageText = StrReplace(MessageText, "%LineNumber%", String(RowPaymentDetails.LineNumber));
				EndIf;
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"PaymentDetails",
					RowPaymentDetails.LineNumber,
					"Document",
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
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'; ru = 'Сумма документа: %DocumentAmount %CashCurrency%, не соответствует сумме разнесенных платежей в табличной части: %PaymentAmount% %CashCurrency%!';pl = 'Kwota dokumentu (%DocumentAmount %CashCurrency%) różni się od sumy płatności w szczegółach płatności (%PaymentAmount% %CashCurrency%).';es_ES = 'El importe del documento (%DocumentAmount %CashCurrency%) no es igual a la suma de los importes de pagos en los detalles de pago (%PaymentAmount% %CashCurrency%).';es_CO = 'El importe del documento (%DocumentAmount %CashCurrency%) no es igual a la suma de los importes de pagos en los detalles de pago (%PaymentAmount% %CashCurrency%).';tr = 'Belge tutarı (%DocumentAmount %CashCurrency%) ödeme ayrıntılarında (%PaymentAmount% %CashCurrency%) ödeme tutarlarının toplamına eşit değildir.';it = 'L''importo del documento (%DocumentAmount %CashCurrency%) non è pari alla somma degli importi del pagamento nei dettagli di pagamento (%PaymentAmount% %CashCurrency%).';de = 'Der Belegbetrag (%DocumentAmount %CashCurrency%) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%PaymentAmount% %CashCurrency%).'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", TrimAll(String(CashCurrency)));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel);
			
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.ToAdvanceHolder Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.Salary Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		PaymentAmount = PayrollPayment.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'Amount (%1) must match the total amount of Payslips (%2). Edit either of the amounts. To edit a Payslip amount, open the Payslip and edit its details.'; ru = 'Сумма (%1) должна соответствовать общей сумме расчетных листков (%2). Отредактируйте любую из сумм. Чтобы изменить сумму расчетного листка, откройте его и отредактируйте сведения.';pl = 'Wartość (%1) powinna odpowiadać łącznej wartości pasków wynagrodzenia (%2). Edytuj jedną z wartości. Do edycji wartości pasku wynagrodzenia, otwórz Pasek wynagrodzenia i edytuj szczegóły.';es_ES = 'El importe (%1) debe coincidir con la cantidad total de nóminas (%2). Edite cualquiera de las cantidades. Para editar el monto de un recibo de pago, abra el recibo de pago y edite sus detalles.';es_CO = 'La cantidad (%1) debe coincidir con la cantidad total de nóminas (%2). Edite cualquiera de las cantidades. Para editar el monto de un recibo de pago, abra el recibo de pago y edite sus detalles.';tr = 'Tutar (%1), Maaş bordrolarının toplam tutarına (%2) eşit olmalıdır. Maaş bordrosu tutarını düzenlemek için Maaş bordrosunu açıp bilgilerini düzenleyin.';it = 'L''importo (%1) deve corrispondere all''importo totale delle Buste Paga (%2). Non modificare gli importi. Per modificare l''importo di una Busta Paga, aprire la Busta Paga e modificare i suoi dettagli.';de = 'Der Betrag (%1) muss mit dem Gesamtbetrag von Lohnzetteln (%2) übereinstimmen. Bearbeiten Sie einen des Betrags. Um einen Betrag aus Lohnzettel zu bearbeiten, öffnen Sie den Lohnzettel und bearbeiten dessen Details.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, DocumentAmount, PaymentAmount);
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "DocumentAmount", Cancel);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.SalaryForEmployee Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.Other Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		
		If ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		EndIf;
		
		If Not RegisterExpense Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.TransferToCashCR Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	// Other settlement
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToCounterparty Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'; ru = 'Сумма документа: %DocumentAmount %CashCurrency%, не соответствует сумме разнесенных платежей в табличной части: %PaymentAmount% %CashCurrency%!';pl = 'Kwota dokumentu (%DocumentAmount %CashCurrency%) różni się od sumy płatności w szczegółach płatności (%PaymentAmount% %CashCurrency%).';es_ES = 'El importe del documento (%DocumentAmount %CashCurrency%) no es igual a la suma de los importes de pagos en los detalles de pago (%PaymentAmount% %CashCurrency%).';es_CO = 'El importe del documento (%DocumentAmount %CashCurrency%) no es igual a la suma de los importes de pagos en los detalles de pago (%PaymentAmount% %CashCurrency%).';tr = 'Belge tutarı (%DocumentAmount %CashCurrency%) ödeme ayrıntılarında (%PaymentAmount% %CashCurrency%) ödeme tutarlarının toplamına eşit değildir.';it = 'L''importo del documento (%DocumentAmount %CashCurrency%) non è pari alla somma degli importi del pagamento nei dettagli di pagamento (%PaymentAmount% %CashCurrency%).';de = 'Der Belegbetrag (%DocumentAmount %CashCurrency%) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%PaymentAmount% %CashCurrency%).'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", String(CashCurrency));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel);
			
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		
		If ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'; ru = 'Сумма документа: %DocumentAmount %CashCurrency%, не соответствует сумме разнесенных платежей в табличной части: %PaymentAmount% %CashCurrency%!';pl = 'Kwota dokumentu (%DocumentAmount %CashCurrency%) różni się od sumy płatności w szczegółach płatności (%PaymentAmount% %CashCurrency%).';es_ES = 'El importe del documento (%DocumentAmount %CashCurrency%) no es igual a la suma de los importes de pagos en los detalles de pago (%PaymentAmount% %CashCurrency%).';es_CO = 'El importe del documento (%DocumentAmount %CashCurrency%) no es igual a la suma de los importes de pagos en los detalles de pago (%PaymentAmount% %CashCurrency%).';tr = 'Belge tutarı (%DocumentAmount %CashCurrency%) ödeme ayrıntılarında (%PaymentAmount% %CashCurrency%) ödeme tutarlarının toplamına eşit değildir.';it = 'L''importo del documento (%DocumentAmount %CashCurrency%) non è pari alla somma degli importi del pagamento nei dettagli di pagamento (%PaymentAmount% %CashCurrency%).';de = 'Der Belegbetrag (%DocumentAmount %CashCurrency%) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%PaymentAmount% %CashCurrency%).'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", String(CashCurrency));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel);
			
		EndIf;
		
	// End Other settlement
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
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
		
		If (OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements)
			OR OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements
			AND TSRow.VATRate.IsEmpty() Then
			TSRow.VATRate	= Catalogs.VATRates.Exempt;
			TSRow.VATAmount	= 0;
		EndIf;
	EndDo;
	
	If (OperationKind = Enums.OperationTypesCashVoucher.Vendor
		Or OperationKind = Enums.OperationTypesCashVoucher.ToCustomer)
		And PaymentDetails.Count() > 0 Then
		Item = PaymentDetails[0].Item;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
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
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization.
	Documents.CashVoucher.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	//VAT
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.CashVoucher.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties to undo the posting of a document.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
		
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.CashVoucher.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	If Not Cancel Then
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

#Region OtherSettlements

Procedure FillByLoanContract(DocRefLoanContract) Export
	      
	Query = New Query;
	Query.SetParameter("Ref",			DocRefLoanContract);
	Query.SetParameter("Date",			?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("LoanKind",		Enums.LoanContractTypes.EmployeeLoanAgreement);
	
	Query.Text =
	"SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	CASE
	|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN VALUE(Enum.OperationTypesCashVoucher.IssueLoanToCounterparty)
	|		ELSE VALUE(Enum.OperationTypesCashVoucher.IssueLoanToEmployee)
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
	|	DocumentTable.PettyCash AS PettyCash
	|FROM
	|	Document.LoanContract AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS ExchangeRate
	|		ON DocumentTable.SettlementsCurrency = ExchangeRate.Currency
	|			AND DocumentTable.Company = ExchangeRate.Company
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	DocumentTable.Ref = &Ref";
		
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
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
	
	If Not ValueIsFilled(PettyCash) Then
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
	|	VALUE(Enum.OperationTypesCashVoucher.LoanSettlements) AS OperationKind,
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
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
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
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
