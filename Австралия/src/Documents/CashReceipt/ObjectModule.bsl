#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure is filling the payment details.
//
Procedure FillPaymentDetails(Val VATAmountLeftToDistribute = 0) Export
	
	IsOrderSet = False;
	
	DoOperationsByOrders = Common.ObjectAttributeValue(Counterparty, "DoOperationsByOrders");
	
	If DoOperationsByOrders AND ValueIsFilled(BasisDocument) Then
		If TypeOf(BasisDocument) = Type("DocumentRef.SalesOrder")
			OR TypeOf(BasisDocument) = Type("DocumentRef.WorkOrder") Then
			IsOrderSet = True;
		EndIf;
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	
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
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsReceivableTable
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&PeriodEndOfDay,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsReceivable.Company,
	|	DocumentAccountsReceivable.Counterparty,
	|	DocumentAccountsReceivable.Contract,
	|	DocumentAccountsReceivable.Document,
	|	DocumentAccountsReceivable.Order,
	|	DocumentAccountsReceivable.SettlementsType,
	|	CASE
	|		WHEN DocumentAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsReceivable.AmountCur
	|		ELSE DocumentAccountsReceivable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentAccountsReceivable
	|WHERE
	|	DocumentAccountsReceivable.Recorder = &Ref
	|	AND DocumentAccountsReceivable.Period <= &Period
	|	AND DocumentAccountsReceivable.Company = &Company
	|	AND DocumentAccountsReceivable.Counterparty = &Counterparty
	|	AND DocumentAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableTable.Counterparty AS Counterparty,
	|	AccountsReceivableTable.Contract AS Contract,
	|	AccountsReceivableTable.Document AS Document,
	|	AccountsReceivableTable.Order AS Order,
	|	SUM(AccountsReceivableTable.AmountCurBalance) AS AmountCurBalance
	|INTO AccountsReceivableGrouped
	|FROM
	|	AccountsReceivableTable AS AccountsReceivableTable
	|WHERE
	|	AccountsReceivableTable.AmountCurBalance > 0
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
	|	AccountsReceivableGrouped.Counterparty AS Counterparty,
	|	AccountsReceivableGrouped.Contract AS Contract,
	|	AccountsReceivableGrouped.Document AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsReceivableGrouped.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	AccountsReceivableGrouped.AmountCurBalance AS AmountCurBalance,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.CashFlowItem AS Item
	|INTO AccountsReceivableContract
	|FROM
	|	AccountsReceivableGrouped AS AccountsReceivableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableGrouped.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Document.SalesInvoice AS SalesInvoice
	|		ON AccountsReceivableGrouped.Document = SalesInvoice.Ref
	|WHERE
	|	(NOT &IsOrderSet
	|			OR AccountsReceivableGrouped.Order = &Order)
	|	AND NOT ISNULL(SalesInvoice.ThirdPartyPayment, FALSE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountsReceivableContract.Document AS Document
	|INTO DocumentTable
	|FROM
	|	AccountsReceivableContract AS AccountsReceivableContract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
	|	SalesInvoiceEarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
	|	SalesInvoiceEarlyPaymentDiscounts.Ref AS SalesInvoice
	|INTO EarlePaymentDiscounts
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON SalesInvoiceEarlyPaymentDiscounts.Ref = DocumentTable.Document
	|WHERE
	|	ENDOFPERIOD(SalesInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(EarlePaymentDiscounts.DueDate) AS DueDate,
	|	EarlePaymentDiscounts.SalesInvoice AS SalesInvoice
	|INTO EarlyPaymentMinDueDate
	|FROM
	|	EarlePaymentDiscounts AS EarlePaymentDiscounts
	|
	|GROUP BY
	|	EarlePaymentDiscounts.SalesInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS ExistsEPD,
	|	EarlePaymentDiscounts.DiscountAmount AS DiscountAmount,
	|	EarlePaymentDiscounts.SalesInvoice AS SalesInvoice
	|INTO EarlyPaymentMaxDiscountAmount
	|FROM
	|	EarlePaymentDiscounts AS EarlePaymentDiscounts
	|		INNER JOIN EarlyPaymentMinDueDate AS EarlyPaymentMinDueDate
	|		ON EarlePaymentDiscounts.SalesInvoice = EarlyPaymentMinDueDate.SalesInvoice
	|			AND EarlePaymentDiscounts.DueDate = EarlyPaymentMinDueDate.DueDate
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
	|	AccountsReceivableContract.Contract AS Contract,
	|	AccountsReceivableContract.Item AS Item,
	|	AccountsReceivableContract.Document AS Document,
	|	ISNULL(EntriesRecorderPeriod.Period, DATETIME(1, 1, 1)) AS DocumentDate,
	|	AccountsReceivableContract.Order AS Order,
	|	ExchangeRateOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRateOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRate.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRate.Multiplicity AS Multiplicity,
	|	AccountsReceivableContract.AmountCurBalance AS AmountCur,
	|	CAST(AccountsReceivableContract.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCurDocument,
	|	ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) AS DiscountAmountCur,
	|	CAST(ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity))
	|		END AS NUMBER(15, 2)) AS DiscountAmountCurDocument,
	|	ISNULL(EarlyPaymentMaxDiscountAmount.ExistsEPD, FALSE) AS ExistsEPD
	|INTO AccountsReceivableWithDiscount
	|FROM
	|	AccountsReceivableContract AS AccountsReceivableContract
	|		LEFT JOIN ExchangeRateOnPeriod AS ExchangeRateOfDocument
	|		ON (ExchangeRateOfDocument.Currency = &Currency)
	|		LEFT JOIN ExchangeRateOnPeriod AS SettlementsExchangeRate
	|		ON AccountsReceivableContract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|		LEFT JOIN EarlyPaymentMaxDiscountAmount AS EarlyPaymentMaxDiscountAmount
	|		ON AccountsReceivableContract.Document = EarlyPaymentMaxDiscountAmount.SalesInvoice
	|		LEFT JOIN EntriesRecorderPeriod AS EntriesRecorderPeriod
	|		ON AccountsReceivableContract.Document = EntriesRecorderPeriod.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableWithDiscount.Contract AS Contract,
	|	AccountsReceivableWithDiscount.Item AS Item,
	|	AccountsReceivableWithDiscount.Document AS Document,
	|	AccountsReceivableWithDiscount.DocumentDate AS DocumentDate,
	|	AccountsReceivableWithDiscount.Order AS Order,
	|	AccountsReceivableWithDiscount.CashAssetsRate AS CashAssetsRate,
	|	AccountsReceivableWithDiscount.CashMultiplicity AS CashMultiplicity,
	|	AccountsReceivableWithDiscount.ExchangeRate AS ExchangeRate,
	|	AccountsReceivableWithDiscount.Multiplicity AS Multiplicity,
	|	AccountsReceivableWithDiscount.AmountCur AS AmountCur,
	|	AccountsReceivableWithDiscount.AmountCurDocument AS AmountCurDocument,
	|	AccountsReceivableWithDiscount.DiscountAmountCur AS DiscountAmountCur,
	|	AccountsReceivableWithDiscount.DiscountAmountCurDocument AS DiscountAmountCurDocument,
	|	AccountsReceivableWithDiscount.ExistsEPD AS ExistsEPD
	|FROM
	|	AccountsReceivableWithDiscount AS AccountsReceivableWithDiscount
	|
	|ORDER BY
	|	DocumentDate
	|TOTALS
	|	SUM(AmountCurDocument),
	|	MAX(DiscountAmountCur),
	|	MAX(DiscountAmountCurDocument)
	|BY
	|	Document";
	
	Query.SetParameter("Company"              , ParentCompany);
	Query.SetParameter("ExchangeRateMethod"   , DriveServer.GetExchangeMethod(ParentCompany));
	Query.SetParameter("Counterparty"         , Counterparty);
	Query.SetParameter("Period"               , ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("PeriodEndOfDay"       , EndOfDay(?(ValueIsFilled(Date), Date, CurrentSessionDate())));
	Query.SetParameter("Currency"             , CashCurrency);
	Query.SetParameter("Ref"                  , Ref);
	Query.SetParameter("IsOrderSet"           , IsOrderSet);
	Query.SetParameter("Order"                , BasisDocument);
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Ref, OperationKind);
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		Company,
		ContractTypesList);
	
	StructureContractCurrencyRateByDefault = CurrencyRateOperations.GetCurrencyRate(Date, ContractByDefault.SettlementsCurrency, Company);
	
	PaymentDetails.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	ByGroupsSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountAllowed");
	IsFromCustomer = OperationKind = Enums.OperationTypesCashReceipt.FromCustomer;
	
	While ByGroupsSelection.Next() AND AmountLeftToDistribute > 0 Do
		
		If ByGroupsSelection.AmountCurDocument - ByGroupsSelection.DiscountAmountCurDocument <= AmountLeftToDistribute Then
			EPD				= ByGroupsSelection.DiscountAmountCurDocument;
			SettlementEPD	= ByGroupsSelection.DiscountAmountCur;
		Else
			EPD				= 0;
			SettlementEPD	= 0;
		EndIf;
		
		SelectionOfQueryResult = ByGroupsSelection.Select();
		
		While SelectionOfQueryResult.Next() AND AmountLeftToDistribute > 0 Do
			
			NewRow = PaymentDetails.Add();
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurDocument >= EPD Then
				
				AmountCurDocument	= SelectionOfQueryResult.AmountCurDocument - EPD;
				AmountCur			= SelectionOfQueryResult.AmountCur - SettlementEPD;
				EPDAmountDocument	= EPD;
				EPDAmount			= SettlementEPD;
				EPD					= 0;
				SettlementEPD		= 0;
			Else
				
				AmountCurDocument	= 0;
				AmountCur			= 0;
				EPDAmountDocument	= SelectionOfQueryResult.AmountCurDocument;
				EPDAmount			= SelectionOfQueryResult.AmountCur;
				EPD					= EPD - SelectionOfQueryResult.AmountCurDocument;
				SettlementEPD		= SettlementEPD - SelectionOfQueryResult.AmountCur;
				
			EndIf;
			
			If AmountCurDocument <= AmountLeftToDistribute Then
				
				NewRow.SettlementsAmount	= AmountCur;
				NewRow.PaymentAmount		= AmountCurDocument;
				NewRow.EPDAmount			= EPDAmountDocument;
				NewRow.SettlementsEPDAmount	= EPDAmount;
				
				VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
				
				NewRow.VATRate = VATRateData.VATRate;
				
				VATAmount					= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100);
				NewRow.VATAmount			= VATAmount;
				
				AmountLeftToDistribute		= AmountLeftToDistribute - AmountCurDocument;
				VATAmountLeftToDistribute	= VATAmountLeftToDistribute - NewRow.VATAmount;
				
			Else
				
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					ExchangeRateMethod,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity);
				
				NewRow.PaymentAmount		= AmountLeftToDistribute;
				NewRow.EPDAmount			= 0;
				NewRow.SettlementsEPDAmount	= 0;
				
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
			
			If IsFromCustomer Then
				NewRow.DiscountAllowedExpenseItem = DefaultExpenseItem;
			EndIf;
			
		EndDo;
	EndDo;
	
	If AmountLeftToDistribute > 0 Then
		
		NewRow = PaymentDetails.Add();
		
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
			
		NewRow.AdvanceFlag			= True;
		NewRow.Order				= ?(IsOrderSet, BasisDocument, Undefined);
		NewRow.PaymentAmount		= AmountLeftToDistribute;
		NewRow.EPDAmount			= 0;
		NewRow.SettlementsEPDAmount	= 0;
		
		VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
		
		NewRow.VATRate = VATRateData.VATRate;
		
		VATAmount					= ?(
			VATAmountLeftToDistribute > 0, 
			VATAmountLeftToDistribute,
			NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100));
					
		NewRow.VATAmount			= VATAmount;
		NewRow.Item					= Common.ObjectAttributeValue(NewRow.Contract, "CashFlowItem");
		
		If IsFromCustomer Then
			NewRow.DiscountAllowedExpenseItem = DefaultExpenseItem;
		EndIf;
		
	EndIf;
	
	If PaymentDetails.Count() = 0 Then
		NewRow = PaymentDetails.Add();
		NewRow.Contract			= ContractByDefault;
		NewRow.Item				= Common.ObjectAttributeValue(NewRow.Contract, "CashFlowItem");
		NewRow.PaymentAmount	= DocumentAmount;
		
		If IsFromCustomer Then
			NewRow.DiscountAllowedExpenseItem = DefaultExpenseItem;
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
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.AmountBalance AS Amount,
	|	AccountsPayableBalances.AmountCurBalance AS AmountCur
	|INTO AccountsPayableTable
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			&PeriodEndOfDay,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsPayable.Counterparty,
	|	DocumentAccountsPayable.Contract,
	|	DocumentAccountsPayable.Document,
	|	DocumentAccountsPayable.Order,
	|	CASE
	|		WHEN DocumentAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsPayable.Amount
	|		ELSE DocumentAccountsPayable.Amount
	|	END,
	|	CASE
	|		WHEN DocumentAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsPayable.AmountCur
	|		ELSE DocumentAccountsPayable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsPayable AS DocumentAccountsPayable
	|WHERE
	|	DocumentAccountsPayable.Recorder = &Ref
	|	AND DocumentAccountsPayable.Company = &Company
	|	AND DocumentAccountsPayable.Counterparty = &Counterparty
	|	AND DocumentAccountsPayable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableTable.Counterparty AS Counterparty,
	|	AccountsPayableTable.Contract AS Contract,
	|	AccountsPayableTable.Document AS Document,
	|	AccountsPayableTable.Order AS Order,
	|	-SUM(AccountsPayableTable.Amount) AS Amount,
	|	-SUM(AccountsPayableTable.AmountCur) AS AmountCur
	|INTO AccountsPayableGrouped
	|FROM
	|	AccountsPayableTable AS AccountsPayableTable
	|WHERE
	|	AccountsPayableTable.AmountCur < 0
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
	|	AccountsPayableGrouped.Contract AS Contract,
	|	CounterpartyContracts.CashFlowItem AS Item,
	|	TRUE AS AdvanceFlag,
	|	AccountsPayableGrouped.Document AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsPayableGrouped.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	AccountsPayableGrouped.AmountCur AS SettlementsAmount,
	|	CASE
	|		WHEN &PresentationCurrency = &Currency
	|			THEN AccountsPayableGrouped.Amount
	|		WHEN CounterpartyContracts.SettlementsCurrency = &Currency
	|			THEN AccountsPayableGrouped.AmountCur
	|		ELSE AccountsPayableGrouped.AmountCur * CASE
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
	|						THEN AccountsPayableGrouped.Amount / AccountsPayableGrouped.AmountCur * CashCurrencyRates.ExchangeRate / CashCurrencyRates.Multiplicity * SettlementsRates.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN AccountsPayableGrouped.AmountCur / AccountsPayableGrouped.Amount * CashCurrencyRates.ExchangeRate / CashCurrencyRates.Multiplicity * SettlementsRates.Multiplicity
	|				END
	|		ELSE SettlementsRates.ExchangeRate
	|	END AS ExchangeRate,
	|	SettlementsRates.Multiplicity AS Multiplicity
	|FROM
	|	AccountsPayableGrouped AS AccountsPayableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsPayableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsPayableGrouped.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN ExchangeRatesOnPeriod AS SettlementsRates
	|		ON (CounterpartyContracts.SettlementsCurrency = SettlementsRates.Currency)
	|		LEFT JOIN ExchangeRatesOnPeriod AS CashCurrencyRates
	|		ON (CashCurrencyRates.Currency = &Currency)";
	
	Query.SetParameter("Company",               ParentCompany);
	Query.SetParameter("PresentationCurrency",  DriveServer.GetPresentationCurrency(ParentCompany));
	Query.SetParameter("ExchangeRateMethod"  ,  DriveServer.GetExchangeMethod(ParentCompany));	
	Query.SetParameter("Counterparty",          Counterparty);
	Query.SetParameter("Period",                Date);
	Query.SetParameter("PeriodEndOfDay",        EndOfDay(Date));
	Query.SetParameter("Ref",                   Ref);
	Query.SetParameter("Currency",              CashCurrency);
	
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

Procedure FillThirdPartyPaymentDetails() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	
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
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsReceivableTable
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&PeriodEndOfDay,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsReceivable.Company,
	|	DocumentAccountsReceivable.Counterparty,
	|	DocumentAccountsReceivable.Contract,
	|	DocumentAccountsReceivable.Document,
	|	DocumentAccountsReceivable.Order,
	|	DocumentAccountsReceivable.SettlementsType,
	|	CASE
	|		WHEN DocumentAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsReceivable.AmountCur
	|		ELSE DocumentAccountsReceivable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentAccountsReceivable
	|WHERE
	|	DocumentAccountsReceivable.Recorder = &Ref
	|	AND DocumentAccountsReceivable.Period <= &Period
	|	AND DocumentAccountsReceivable.Company = &Company
	|	AND DocumentAccountsReceivable.Counterparty = &Counterparty
	|	AND DocumentAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ThirdPartyPaymentsBalances.Company AS Company,
	|	ThirdPartyPaymentsBalances.Counterparty AS Counterparty,
	|	ThirdPartyPaymentsBalances.Contract AS Contract,
	|	ThirdPartyPaymentsBalances.Document AS Document,
	|	ThirdPartyPaymentsBalances.Payer AS Payer,
	|	ThirdPartyPaymentsBalances.PayerContract AS PayerContract,
	|	ThirdPartyPaymentsBalances.AmountBalance AS AmountBalance
	|INTO ThirdPartyPaymentsTable
	|FROM
	|	AccumulationRegister.ThirdPartyPayments.Balance(
	|			,
	|			Company = &Company
	|				AND Payer = &Counterparty) AS ThirdPartyPaymentsBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentThirdPartyPayments.Company,
	|	DocumentThirdPartyPayments.Counterparty,
	|	DocumentThirdPartyPayments.Contract,
	|	DocumentThirdPartyPayments.Document,
	|	DocumentThirdPartyPayments.Payer,
	|	DocumentThirdPartyPayments.PayerContract,
	|	CASE
	|		WHEN DocumentThirdPartyPayments.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentThirdPartyPayments.Amount
	|		ELSE DocumentThirdPartyPayments.Amount
	|	END
	|FROM
	|	AccumulationRegister.ThirdPartyPayments AS DocumentThirdPartyPayments
	|WHERE
	|	DocumentThirdPartyPayments.Recorder = &Ref
	|	AND DocumentThirdPartyPayments.Period <= &Period
	|	AND DocumentThirdPartyPayments.Company = &Company
	|	AND DocumentThirdPartyPayments.Payer = &Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableTable.Counterparty AS Counterparty,
	|	AccountsReceivableTable.Contract AS Contract,
	|	AccountsReceivableTable.Document AS Document,
	|	AccountsReceivableTable.Order AS Order,
	|	SUM(AccountsReceivableTable.AmountCurBalance) AS AmountCurBalance
	|INTO AccountsReceivableGrouped
	|FROM
	|	AccountsReceivableTable AS AccountsReceivableTable
	|WHERE
	|	AccountsReceivableTable.AmountCurBalance > 0
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
	|	ThirdPartyPaymentsTable.Counterparty AS Counterparty,
	|	ThirdPartyPaymentsTable.Contract AS Contract,
	|	ThirdPartyPaymentsTable.Document AS Document,
	|	ThirdPartyPaymentsTable.Payer AS Payer,
	|	ThirdPartyPaymentsTable.PayerContract AS PayerContract
	|INTO ThirdPartyPaymentsGrouped
	|FROM
	|	ThirdPartyPaymentsTable AS ThirdPartyPaymentsTable
	|WHERE
	|	ThirdPartyPaymentsTable.AmountBalance > 0
	|
	|GROUP BY
	|	ThirdPartyPaymentsTable.Counterparty,
	|	ThirdPartyPaymentsTable.Contract,
	|	ThirdPartyPaymentsTable.Document,
	|	ThirdPartyPaymentsTable.Payer,
	|	ThirdPartyPaymentsTable.PayerContract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableGrouped.Counterparty AS Counterparty,
	|	AccountsReceivableGrouped.Contract AS Contract,
	|	AccountsReceivableGrouped.Document AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsReceivableGrouped.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	AccountsReceivableGrouped.AmountCurBalance AS AmountCurBalance,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.CashFlowItem AS Item,
	|	ThirdPartyPaymentsGrouped.Counterparty AS ThirdPartyCustomer,
	|	ThirdPartyPaymentsGrouped.Contract AS ThirdPartyCustomerContract
	|INTO AccountsReceivableContract
	|FROM
	|	AccountsReceivableGrouped AS AccountsReceivableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableGrouped.Contract = CounterpartyContracts.Ref
	|		INNER JOIN ThirdPartyPaymentsGrouped AS ThirdPartyPaymentsGrouped
	|		ON AccountsReceivableGrouped.Document = ThirdPartyPaymentsGrouped.Document
	|			AND AccountsReceivableGrouped.Counterparty = ThirdPartyPaymentsGrouped.Payer
	|			AND AccountsReceivableGrouped.Contract = ThirdPartyPaymentsGrouped.PayerContract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableContract.Contract AS Contract,
	|	AccountsReceivableContract.Item AS Item,
	|	AccountsReceivableContract.Document AS Document,
	|	AccountsReceivableContract.Order AS Order,
	|	ExchangeRateOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRateOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRate.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRate.Multiplicity AS Multiplicity,
	|	AccountsReceivableContract.AmountCurBalance AS AmountCur,
	|	CAST(AccountsReceivableContract.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS AmountCurDocument,
	|	AccountsReceivableContract.ThirdPartyCustomer AS ThirdPartyCustomer,
	|	AccountsReceivableContract.ThirdPartyCustomerContract AS ThirdPartyCustomerContract
	|FROM
	|	AccountsReceivableContract AS AccountsReceivableContract
	|		LEFT JOIN ExchangeRateOnPeriod AS ExchangeRateOfDocument
	|		ON (ExchangeRateOfDocument.Currency = &Currency)
	|		LEFT JOIN ExchangeRateOnPeriod AS SettlementsExchangeRate
	|		ON AccountsReceivableContract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|
	|ORDER BY
	|	Document";
	
	Query.SetParameter("Company",				ParentCompany);
	Query.SetParameter("Counterparty",			Counterparty);
	Query.SetParameter("Period",				Date);
	Query.SetParameter("PeriodEndOfDay",		EndOfDay(Date));
	Query.SetParameter("Currency",				CashCurrency);
	Query.SetParameter("Ref",					Ref);
	Query.SetParameter("ExchangeRateMethod",	ExchangeRateMethod);
	
	PaymentDetails.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() AND AmountLeftToDistribute > 0 Do
		
		NewRow = PaymentDetails.Add();
		
		FillPropertyValues(NewRow, Selection);
		
		AmountCurDocument = Selection.AmountCurDocument;
		AmountCur = Selection.AmountCur;
		
		If AmountCurDocument <= AmountLeftToDistribute Then
			
			NewRow.SettlementsAmount	= AmountCur;
			NewRow.PaymentAmount		= AmountCurDocument;
			VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
			NewRow.VATRate = VATRateData.VATRate;
			NewRow.VATAmount			= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100);
			AmountLeftToDistribute		= AmountLeftToDistribute - AmountCurDocument;
			
		Else
			
			NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRateMethod,
				Selection.CashAssetsRate,
				Selection.ExchangeRate,
				Selection.CashMultiplicity,
				Selection.Multiplicity);
			
			NewRow.PaymentAmount		= AmountLeftToDistribute;
			VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
			NewRow.VATRate = VATRateData.VATRate;
			NewRow.VATAmount			= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100);
			AmountLeftToDistribute		= 0;
			
		EndIf;
		
	EndDo;
	
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
		
	EndIf;
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashInflowForecast(BasisDocument, Amount = Undefined)
	
	Query = New Query;
	Query.SetParameter("Ref",	BasisDocument);
	Query.SetParameter("Date",	?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(Ref.Company));
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT ALLOWED
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	DocumentTable.PettyCash AS PettyCash,
		|	DocumentTable.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(SettlementsExchangeRate.Rate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRate.Repetition, 1) AS Multiplicity,
		|	CAST(&Amount * CASE
		|			WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRate.Rate <> 0
		|					AND ExchangeRateOfDocument.Repetition <> 0
		|				THEN CASE
		|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|							THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1))
		|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|							THEN 1 / (ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1)))
		|					END
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.CashInflowForecast AS DocumentTable
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
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	DocumentTable.PettyCash AS PettyCash,
		|	DocumentTable.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.DocumentAmount AS DocumentAmount,
		|	DocumentTable.DocumentAmount AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(SettlementsExchangeRate.Rate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRate.Repetition, 1) AS Multiplicity,
		|	CAST(DocumentTable.DocumentAmount * CASE
		|			WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRate.Rate <> 0
		|					AND ExchangeRateOfDocument.Repetition <> 0
		|				THEN CASE
		|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|							THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1))
		|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|							THEN 1 / (ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (ISNULL(SettlementsExchangeRate.Rate, 1) * ISNULL(ExchangeRateOfDocument.Repetition, 1)))
		|					END
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.DocumentAmount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.CashInflowForecast AS DocumentTable
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
		
		VATTaxation = DriveServer.VATTaxation(Company, Date);
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.AdvanceFlag = True;
		NewRow.PlanningDocument = BasisDocument;
		
		If ValueIsFilled(BasisDocument.BasisDocument)
		   AND TypeOf(BasisDocument.BasisDocument) = Type("DocumentRef.SalesOrder")
		   AND Counterparty.DoOperationsByOrders Then
			
			NewRow.Order = BasisDocument.BasisDocument;
			
		EndIf;
		
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
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	// Fill document header data.
	Query.Text = 
	"SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashReceipt.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.SubjectToVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.PettyCashPayee AS PettyCash,
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
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByQuote(FillingData, LineNumber = Undefined, Amount = Undefined)
	
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
	|	Document.Quote AS DocumentHeader
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
	|		LEFT JOIN Document.Quote.PaymentCalendar AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|			AND (DocumentTable.LineNumber = &LineNumber)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
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
	|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
	|	VALUE(Document.Quote.EmptyRef) AS Quote,
	|	DocumentTable.VATRate AS VATRate,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Rate / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Rate / (CashAccountRates.Rate * SettlementsRates.Repetition))
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
	|		LEFT JOIN Document.Quote.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	CashAccounts.PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
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
Procedure FillBySalesOrder(FillingData, LineNumber = Undefined, Amount = Undefined)
	
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
	|	ISNULL(AccountingPolicySliceLast.RegisteredForSalesTax, FALSE) AS RegisteredForSalesTax
	|INTO AccountingPolicy
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON SalesOrder.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	SalesOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.VATAmount AS VATAmount
	|INTO TaxTotalsNotGrouped
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN AccountingPolicy AS AccountingPolicy
	|		ON (FALSE IN
	|				(SELECT
	|					AccountingPolicy.RegisteredForSalesTax AS RegisteredForSalesTax
	|				FROM
	|					AccountingPolicy AS AccountingPolicy))
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrderSalesTax.Ref,
	|	SalesOrderSalesTax.Amount
	|FROM
	|	Document.SalesOrder.SalesTax AS SalesOrderSalesTax
	|		INNER JOIN AccountingPolicy AS AccountingPolicy
	|		ON (TRUE IN
	|				(SELECT
	|					AccountingPolicy.RegisteredForSalesTax AS RegisteredForSalesTax
	|				FROM
	|					AccountingPolicy AS AccountingPolicy))
	|WHERE
	|	SalesOrderSalesTax.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TaxTotalsNotGrouped.Ref AS Ref,
	|	SUM(TaxTotalsNotGrouped.VATAmount) AS VATAmount
	|INTO TaxTotals
	|FROM
	|	TaxTotalsNotGrouped AS TaxTotalsNotGrouped
	|
	|GROUP BY
	|	TaxTotalsNotGrouped.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
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
	|	ISNULL(TaxTotals.VATAmount, 0) AS DocumentVATAmount
	|INTO DocumentHeader
	|FROM
	|	Document.SalesOrder AS DocumentHeader
	|		LEFT JOIN TaxTotals AS TaxTotals
	|		ON DocumentHeader.Ref = TaxTotals.Ref
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
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
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
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	UNDEFINED AS Document,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS DocumentAmount,
	|	MAX(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentHeader.DocumentVATAmount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentHeader.DocumentVATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS DocumentVATAmount
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
	|		LEFT JOIN Document.SalesOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	CashAccounts.PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Contract,
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
		
		FillPaymentDetails(Selection.DocumentVATAmount);
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByWorkOrder(FillingData, LineNumber = Undefined, Amount = Undefined)
	
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
	|	ISNULL(AccountingPolicySliceLast.RegisteredForSalesTax, FALSE) AS RegisteredForSalesTax
	|INTO AccountingPolicy
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON SalesOrder.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	SalesOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.VATAmount AS VATAmount
	|INTO TaxTotalsNotGrouped
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN AccountingPolicy AS AccountingPolicy
	|		ON (FALSE IN
	|				(SELECT
	|					AccountingPolicy.RegisteredForSalesTax AS RegisteredForSalesTax
	|				FROM
	|					AccountingPolicy AS AccountingPolicy))
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrderSalesTax.Ref,
	|	SalesOrderSalesTax.Amount
	|FROM
	|	Document.SalesOrder.SalesTax AS SalesOrderSalesTax
	|		INNER JOIN AccountingPolicy AS AccountingPolicy
	|		ON (TRUE IN
	|				(SELECT
	|					AccountingPolicy.RegisteredForSalesTax AS RegisteredForSalesTax
	|				FROM
	|					AccountingPolicy AS AccountingPolicy))
	|WHERE
	|	SalesOrderSalesTax.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TaxTotalsNotGrouped.Ref AS Ref,
	|	SUM(TaxTotalsNotGrouped.VATAmount) AS VATAmount
	|INTO TaxTotals
	|FROM
	|	TaxTotalsNotGrouped AS TaxTotalsNotGrouped
	|
	|GROUP BY
	|	TaxTotalsNotGrouped.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
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
	|	ISNULL(TaxTotals.VATAmount, 0) AS DocumentVATAmount,
	|	DocumentHeader.OrderState AS OrderState
	|INTO DocumentHeader
	|FROM
	|	Document.WorkOrder AS DocumentHeader
	|		LEFT JOIN TaxTotals AS TaxTotals
	|		ON DocumentHeader.Ref = TaxTotals.Ref
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
	|		LEFT JOIN Document.WorkOrder.PaymentCalendar AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|			AND (DocumentTable.LineNumber = &LineNumber)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderInventory.Total AS Total,
	|	WorkOrderInventory.SalesTaxAmount AS SalesTaxAmount,
	|	WorkOrderInventory.Ref AS Ref
	|INTO DocumentTable
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		INNER JOIN DocumentHeader AS DocumentHeader
	|		ON WorkOrderInventory.Ref = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	WorkOrderWorks.Total,
	|	WorkOrderWorks.SalesTaxAmount,
	|	WorkOrderWorks.Ref
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|		INNER JOIN DocumentHeader AS DocumentHeader
	|		ON WorkOrderWorks.Ref = DocumentHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
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
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN CashAccounts.Currency IS NULL
	|			THEN DocumentRates.Repetition
	|		ELSE CashAccountRates.Repetition
	|	END AS Multiplicity,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	UNDEFINED AS Document,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS DocumentAmount,
	|	MAX(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * DocumentHeader.DocumentVATAmount * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL(Coeffs.Coeff * DocumentHeader.DocumentVATAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition))
	|					END, 0)
	|		END) AS DocumentVATAmount
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
	|		LEFT JOIN DocumentTable AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Counterparty,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Contract,
	|	CashAccounts.PettyCash,
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
		
		FillPaymentDetails(Selection.DocumentVATAmount);
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//
Procedure FillBySalesOrderDependOnBalanceForPayment(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod"   , DriveServer.GetExchangeMethod(FillingData.Company));	
	
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
	|	Document.SalesOrder AS DocumentHeader
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
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
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
	|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
	|	VALUE(Document.Quote.EmptyRef) AS Quote,
	|	DocumentTable.VATRate AS VATRate,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL(Coeffs.Coeff * (DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
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
	|		LEFT JOIN Document.SalesOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentTable.VATRate,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	CashAccounts.PettyCash,
	|	DocumentHeader.Contract,
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
Procedure FillBySalesInvoice(FillingData)
	
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
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.ThirdPartyPayment AS ThirdPartyPayment,
	|	DocumentHeader.Payer AS Payer,
	|	DocumentHeader.PayerContract AS PayerContract,
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
	|	END AS AdvancesReceivedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.ThirdPartyPayerGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ThirdPartyPayerGLAccount
	|INTO DocumentHeader
	|FROM
	|	Document.SalesInvoice AS DocumentHeader
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
	|		WHEN DocumentHeader.ThirdPartyPayment
	|			THEN VALUE(Enum.OperationTypesCashReceipt.PaymentFromThirdParties)
	|		ELSE VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	END AS OperationKind,
	|	CASE
	|		WHEN DocumentHeader.ThirdPartyPayment
	|			THEN Contracts.CashFlowItem
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|	END AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	CashAccounts.PettyCash AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	CASE
	|		WHEN DocumentHeader.ThirdPartyPayment
	|			THEN DocumentHeader.Payer
	|		ELSE DocumentHeader.Counterparty
	|	END AS Counterparty,
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
	|	CASE
	|		WHEN NOT DocumentHeader.ThirdPartyPayment
	|				AND Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN DocumentHeader.ThirdPartyPayment
	|			THEN DocumentHeader.PayerContract
	|		ELSE DocumentHeader.Contract
	|	END AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
	|	SUM(ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) * DocumentHeader.ExchangeRate * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN CashAccounts.Currency IS NULL
	|				THEN ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition))
	|						END, 0)
	|			ELSE ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) * CASE
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
	|		END) AS VATAmount,
	|	DocumentHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
	|	DocumentHeader.ThirdPartyPayerGLAccount AS ThirdPartyPayerGLAccount,
	|	CASE
	|		WHEN DocumentHeader.ThirdPartyPayment
	|			THEN DocumentHeader.Counterparty
	|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
	|	END AS ThirdPartyCustomer,
	|	CASE
	|		WHEN DocumentHeader.ThirdPartyPayment
	|			THEN DocumentHeader.Contract
	|		ELSE VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	END AS ThirdPartyCustomerContract
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
	|		LEFT JOIN Document.SalesInvoice.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Ref,
	|	DocumentHeader.Counterparty,
	|	CashAccounts.PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	Counterparties.DoOperationsByOrders,
	|	DocumentTable.Order,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	DocumentHeader.AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount,
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
	|	DocumentHeader.ThirdPartyPayerGLAccount,
	|	DocumentHeader.Payer,
	|	DocumentHeader.PayerContract,
	|	DocumentHeader.ThirdPartyPayment,
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
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssetSale(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(Ref.Company));	
	
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
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO DocumentHeader
	|FROM
	|	Document.FixedAssetSale AS DocumentHeader
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
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
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
	|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
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
	|		LEFT JOIN Document.FixedAssetSale.FixedAssets AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.Counterparty,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Contract,
	|	CashAccounts.PettyCash,
	|	DocumentHeader.Ref,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
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
Procedure FillByShiftClosure(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.CashCR AS CashCR,
	|	DocumentHeader.Item AS Item,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	DocumentHeader.Ref AS Ref
	|INTO TT_DocumentHeader
	|FROM
	|	Document.ShiftClosure AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	CashAccounts.Ref AS PettyCash
	|INTO TT_PettyCash
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Catalog.CashAccounts AS CashAccounts
	|		ON TT_DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|WHERE
	|	NOT CashAccounts.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesCashReceipt.RetailIncome) AS OperationKind,
	|	SUM(ISNULL(DocumentTable.Total, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.VATAmount, 0)) AS VATAmount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.CashCR AS CashCR,
	|	DocumentHeader.Item AS Item,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.Ref AS BasisDocument,
	|	TT_PettyCash.PettyCash AS PettyCash
	|FROM
	|	TT_DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.ShiftClosure.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref,
	|	TT_PettyCash AS TT_PettyCash
	|
	|GROUP BY
	|	DocumentTable.VATRate,
	|	DocumentHeader.Ref,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.CashCR,
	|	DocumentHeader.Item,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.DocumentCurrency,
	|	TT_PettyCash.PettyCash";
	
	QueryResult = Query.Execute();
	
	AmountLeftToDistribute = FillingData.PaymentWithPaymentCards.Total("Amount");
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PaymentDetails.Clear();
		
		If Selection.PaymentAmount - AmountLeftToDistribute > 0 Then
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.PaymentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
			DocumentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
			AmountLeftToDistribute = 0;
		Else
			AmountLeftToDistribute = AmountLeftToDistribute - Selection.PaymentAmount;
		EndIf;
		
		While Selection.Next() Do
			If Selection.PaymentAmount - AmountLeftToDistribute > 0 Then
				NewRow = PaymentDetails.Add();
				FillPropertyValues(NewRow, Selection);
				NewRow.PaymentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
				DocumentAmount = DocumentAmount + Selection.PaymentAmount - AmountLeftToDistribute;
				AmountLeftToDistribute = 0;
			Else
				AmountLeftToDistribute = AmountLeftToDistribute - Selection.PaymentAmount;
			EndIf;
		EndDo;
		
		If PaymentDetails.Count() = 0 Then
			PaymentDetails.Add();
		EndIf;
		
	EndIf;
	
EndProcedure

// begin Drive.FullVersion
Procedure FillBySubcontractorInvoiceIssued(FillingData)
	
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
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.SetPaymentTerms
	|		AND DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Cash) AS PaymentTermsAreSetInCash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.Order AS Order,
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
	|	Document.SubcontractorInvoiceIssued AS DocumentHeader
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
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
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
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
	|	SUM(ISNULL(DocumentTable.Total * DocumentHeader.ExchangeRate * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
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
	|		END) AS VATAmount,
	|	DocumentHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
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
	|		LEFT JOIN Document.SubcontractorInvoiceIssued.Products AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.Ref,
	|	DocumentHeader.Counterparty,
	|	CashAccounts.PettyCash,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	Counterparties.DoOperationsByOrders,
	|	DocumentHeader.Order,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	DocumentHeader.AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount,
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
// end Drive.FullVersion 

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByDocumentSalesOrder(BasisDocument)
	
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
	|	Document.SalesOrder AS DocumentHeader
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
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
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
	|					THEN (DocumentTable.Total + DocumentTable.SalesTaxAmount) * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN (DocumentTable.Total + DocumentTable.SalesTaxAmount) / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)), 0)
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
	|		LEFT JOIN Document.SalesOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Contract,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	CashAccounts.PettyCash,
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
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByDocumentWorkOrder(BasisDocument)
	
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
	|	DocumentHeader.OrderState AS OrderState
	|INTO DocumentHeader
	|FROM
	|	Document.WorkOrder AS DocumentHeader
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
	|	WorkOrderInventory.Total AS Total,
	|	WorkOrderInventory.SalesTaxAmount AS SalesTaxAmount,
	|	WorkOrderInventory.VATRate AS VATRate,
	|	WorkOrderInventory.VATAmount AS VATAmount,
	|	WorkOrderInventory.Ref AS Ref
	|INTO DocumentTable
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		INNER JOIN DocumentHeader AS DocumentHeader
	|		ON WorkOrderInventory.Ref = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	WorkOrderWorks.Total,
	|	WorkOrderWorks.SalesTaxAmount,
	|	WorkOrderWorks.VATRate,
	|	WorkOrderWorks.VATAmount,
	|	WorkOrderWorks.Ref
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|		INNER JOIN DocumentHeader AS DocumentHeader
	|		ON WorkOrderWorks.Ref = DocumentHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
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
	|					THEN (DocumentTable.Total + DocumentTable.SalesTaxAmount) * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN (DocumentTable.Total + DocumentTable.SalesTaxAmount) / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|			END, 0)) AS SettlementsAmount,
	|	SettlementsRates.Rate AS ExchangeRate,
	|	SettlementsRates.Repetition AS Multiplicity,
	|	SUM(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition), 0)
	|						ELSE ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) * DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition), 0)
	|					END
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN CASE
	|						WHEN CashAccounts.Currency IS NULL
	|							THEN ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * DocumentRates.Repetition / (DocumentRates.Rate * SettlementsRates.Repetition)), 0)
	|						ELSE ISNULL((DocumentTable.Total + DocumentTable.SalesTaxAmount) / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity) * SettlementsRates.Rate * CashAccountRates.Repetition / (CashAccountRates.Rate * SettlementsRates.Repetition)), 0)
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
	|		LEFT JOIN DocumentTable AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	ISNULL(CashAccounts.Currency, DocumentHeader.CashCurrency),
	|	CashAccounts.PettyCash,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.Contract,
	|	Counterparties.DoOperationsByOrders,
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
	
	If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer AND PaymentDetails.Count() > 0 Then
		
		DocumentArray			= PaymentDetails.UnloadColumn("Document");
		CheckDate				= ?(ValueIsFilled(Date), Date, CurrentSessionDate());
		DocumentArrayWithEPD	= Documents.SalesInvoice.GetSalesInvoiceArrayWithEPD(DocumentArray, CheckDate);
		
		For Each TabularSectionRow In PaymentDetails Do
			
			If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SalesInvoice") Then
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

#EndRegion

#Region EventHandlers

// Procedure - handler of the OnCopy event.
//
Procedure OnCopy(CopiedObject)
	
	SalesSlipNumber = "";
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		If OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
			
			BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			
		EndIf;
		
	EndIf;
	
	For Each TSRow In PaymentDetails Do
		If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
		
		// Miscellaneous payable
		If (OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements)
			AND TSRow.VATRate.IsEmpty() Then
			TSRow.VATRate	= Catalogs.VATRates.Exempt;
			TSRow.VATAmount	= 0;
		EndIf;
		// End miscellaneous payable
	EndDo;
	
	If (OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		Or OperationKind = Enums.OperationTypesCashReceipt.FromVendor)
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

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.Quote") Then
		FillByQuote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashInflowForecast") Then
		FillByCashInflowForecast(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ShiftClosure") Then
		FillByShiftClosure(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.FixedAssetSale") Then
		FillByFixedAssetSale(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillByDocumentSalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.WorkOrder") Then
		FillByDocumentWorkOrder(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.LoanContract") Then
		FillByLoanContract(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Basis") Then
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis)= Type("DocumentRef.SalesOrder") Then
			FillBySalesOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.Quote") Then
			FillByQuote(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.SalesOrder") Then
			FillBySalesOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.WorkOrder") Then
			FillByWorkOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashInflowForecast") Then
			FillByCashInflowForecast(FillingData.Document, FillingData.Amount);
		EndIf;
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Document") Then
		If TypeOf(FillingData.Document) = Type("DocumentRef.Quote") Then
			FillByQuote(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.SalesOrder") Then
			FillBySalesOrder(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.WorkOrder") Then
			FillByWorkOrder(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashInflowForecast") Then
			FillByCashInflowForecast(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashTransferPlan") Then
			FillByCashTransferPlan(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document)= Type("DocumentRef.LoanInterestCommissionAccruals") Then
			FillByAccrualsForLoans(FillingData);
		EndIf;
	// begin Drive.FullVersion
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorInvoiceIssued") Then
		FillBySubcontractorInvoiceIssued(FillingData);
	// end Drive.FullVersion 
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	If Not ValueIsFilled(AcceptedFrom)
	      AND ValueIsFilled(Counterparty)
	      AND (OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
	     OR OperationKind = Enums.OperationTypesCashReceipt.FromVendor) Then
			
			AcceptedFrom = ?(Counterparty.DescriptionFull = "", Counterparty.Description, Counterparty.DescriptionFull);
			
		EndIf;
		
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountAllowed");
	If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
		For Each Row In PaymentDetails Do
			Row.DiscountAllowedExpenseItem = DefaultExpenseItem;
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
	If OperationKind = Enums.OperationTypesCashReceipt.FromVendor
		Or OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		Or OperationKind = Enums.OperationTypesCashReceipt.PaymentFromThirdParties Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Item");
		
		If OperationKind = Enums.OperationTypesCashReceipt.FromVendor
			Or OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		EndIf;
		
		For Each RowPaymentDetails In PaymentDetails Do
			
			If Not ValueIsFilled(RowPaymentDetails.Document) Then
				
				MessageText = "";
				
				If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer And Not RowPaymentDetails.AdvanceFlag Then
					MessageText = ?(PaymentDetails.Count() = 1,
						NStr("en = 'Please specify the shipment document or select the ""Advance payment"" check box.'; ru = 'Укажите документ отгрузки или признак аванса платежа.';pl = 'Określ dokument wysyłki lub zaznacz pole wyboru ""Płatność zaliczkowa"".';es_ES = 'Por favor, especifique el documento de envío o seleccione la casilla de verificación ""Pago anticipado"".';es_CO = 'Por favor, especifique el documento de envío o seleccione la casilla de verificación ""Pago anticipado"".';tr = 'Lütfen, sevkiyat belgesi belirtin veya ""Avans ödeme"" onay kutusunu seçin.';it = 'Si prega di specificare il documento di spedizione o selezionare la casella di controllo ""Pagamento anticipato"".';de = 'Bitte geben Sie den Lieferbeleg an oder aktivieren Sie das Kontrollkästchen ""Vorauszahlung"".'"),
						NStr("en = 'Please specify the shipment document or select the ""Advance payment"" check box in line #%1 of the payment details.'; ru = 'Укажите документ отгрузки или признак оплаты в строке %1 списка ""Расшифровка платежа"".';pl = 'Określ dokument wysyłki lub zaznacz pole wyboru ""Płatność zaliczkowa"" w wierszu nr %1 szczegółów płatności.';es_ES = 'Por favor, especifique el documento de envío o seleccione la casilla de verificación ""Pago anticipado"" en la línea #%1 de los detalles de pago.';es_CO = 'Por favor, especifique el documento de envío o seleccione la casilla de verificación ""Pago anticipado"" en la línea #%1 de los detalles de pago.';tr = 'Lütfen sevkiyat belgesini belirtin ya da ödeme ayrıntılarının #%1 satırındaki ""Avans ödeme"" onay kutusunu seçin.';it = 'Si prega di specificare il documento di spedizione o selezionare la casella di controllo ""Pagamento Anticipato"" nella linea #%1 dei dettagli di pagamento.';de = 'Bitte geben Sie den Lieferbeleg an oder aktivieren Sie das Kontrollkästchen ""Vorauszahlung"" in Zeile Nr %1 der Zahlungsdaten.'"));
				ElsIf OperationKind = Enums.OperationTypesCashReceipt.PaymentFromThirdParties Then
					MessageText = ?(PaymentDetails.Count() = 1,
						NStr("en = 'Document is required.'; ru = 'Укажите документ.';pl = 'Wymagany jest dokument.';es_ES = 'Se requiere el documento.';es_CO = 'Se requiere el documento.';tr = 'Belge gerekli.';it = 'È richiesto il documento.';de = 'Dokument ist erforderlich.'"),
						NStr("en = 'Document is required in line #%1.'; ru = 'В строке №%1 требуется указать документ.';pl = 'Dokument jest wymagany w wierszu nr %1.';es_ES = 'Se requiere el documento en la línea #%1.';es_CO = 'Se requiere el documento en la línea #%1.';tr = '%1 nolu satırda belge gerekli.';it = 'È richiesto il documento nella riga #%1.';de = 'Dokument ist in der Zeile Nr. %1 erforderlich.'"));
				ElsIf OperationKind = Enums.OperationTypesCashReceipt.FromVendor Then
					MessageText = ?(PaymentDetails.Count() = 1,
						NStr("en = 'Please specify a billing document.'; ru = 'Укажите документ расчетов.';pl = 'Określ dokument rozliczeniowy.';es_ES = 'Por favor, especifique un documento de facturación.';es_CO = 'Por favor, especifique un documento de facturación.';tr = 'Lütfen, fatura belgesi belirtin.';it = 'Indicare un documento di fatturazione.';de = 'Bitte geben Sie einen Abrechnungsbeleg an.'"),
						NStr("en = 'Please specify a billing documen in line #%1 of the payment details.'; ru = 'Укажите документ расчетов в строке №%1 списка ""Расшифровка платежа"".';pl = 'Określ dokument rozliczeniowy w wierszu #%1 szczegółów płatności.';es_ES = 'Por favor, especifique un documento de facturación en la línea #%1 de los detalles de pago.';es_CO = 'Por favor, especifique un documento de facturación en la línea #%1 de los detalles de pago.';tr = 'Lütfen, ödeme ayrıntılarının %1 nolu satırında faturalama belgesi belirtin.';it = 'Indicare un documento di fatturazione nella riga #%1 dei dettagli di pagamento.';de = 'Bitte geben Sie in der Zeile Nr %1 der Zahlungsdetails einen Abrechnungsbeleg an.'"));
				EndIf;
				
				If ValueIsFilled(MessageText) Then
					
					If PaymentDetails.Count() > 1 Then
						MessageText = StrTemplate(MessageText, String(RowPaymentDetails.LineNumber));
					EndIf;
				
					DriveServer.ShowMessageAboutError(ThisObject,
						MessageText,
						"PaymentDetails",
						RowPaymentDetails.LineNumber,
						"Document",
						Cancel);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
			And RowPaymentDetails.ExistsEPD
			And Not ValueIsFilled(RowPaymentDetails.DiscountAllowedExpenseItem) Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'On the Payment allocation tab, in line #%1, an expense item is required.'; ru = 'Во вкладке ""Расшифровка платежа"" в строке %1 требуется указать статью расходов.';pl = 'Na karcie Alokacja płatności, w wierszu nr %1, pozycja rozchodów jest wymagana.';es_ES = 'En la pestaña Asignación del pago, en la línea #%1, se requiere un artículo de gasto.';es_CO = 'En la pestaña Asignación del pago, en la línea #%1, se requiere un artículo de gasto.';tr = 'Ödeme tahsisi sekmesinin %1 nolu satırında gider kalemi gerekli.';it = 'Nella scheda Dettagli del pagamento, nella riga #%1, è richiesta una voce di uscita.';de = 'Eine Position von Ausgaben ist in der Zeile Nr. %1 auf der Registerkarte Zahlungszuordnung erforderlich.'"),
				String(RowPaymentDetails.LineNumber));
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				,
				Cancel);
			
		EndIf;
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The document amount (%1 %3) is not equal to the sum of payment amounts in the payment details (%2 %3).'; ru = 'Сумма документа (%1 %3) не соответствует сумме разнесенных платежей в табличной части (%2 %3).';pl = 'Kwota dokumentu (%1 %3) różni się od sumy kwot płatności w szczegółach płatności (%2 %3).';es_ES = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';es_CO = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';tr = 'Belge tutarı (%1 %3) ödeme ayrıntılarındaki (%2 %3) ödeme tutarı toplamında eşit değildir.';it = 'L''importo del documento (%1 %3) non corrisponde alla somma degli importi di pagamento nei dettagli di pagamento (%2 %3).';de = 'Der Belegbetrag (%1 %3) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%2 %3).'"),
							TrimAll(DocumentAmount),
							TrimAll(PaymentAmount),
							TrimAll(CashCurrency));
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
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
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
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.RetailIncome Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The document amount (%1 %3) is not equal to the sum of payment amounts in the payment details (%2 %3).'; ru = 'Сумма документа (%1 %3) не соответствует сумме разнесенных платежей в табличной части (%2 %3).';pl = 'Kwota dokumentu (%1 %3) różni się od sumy kwot płatności w szczegółach płatności (%2 %3).';es_ES = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';es_CO = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';tr = 'Belge tutarı (%1 %3) ödeme ayrıntılarındaki (%2 %3) ödeme tutarı toplamında eşit değildir.';it = 'L''importo del documento (%1 %3) non corrisponde alla somma degli importi di pagamento nei dettagli di pagamento (%2 %3).';de = 'Der Belegbetrag (%1 %3) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%2 %3).'"),
							TrimAll(DocumentAmount),
							TrimAll(PaymentAmount),
							TrimAll(CashCurrency));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel);
		EndIf;
		
		If ValueIsFilled(CashCR) Then
			
			If ValueIsFilled(PettyCash) And ValueIsFilled(CashCurrency) Then
				
				CashCRCurrency = Common.ObjectAttributeValue(CashCR, "CashCurrency");
				
				If CashCRCurrency <> CashCurrency Then
					
					MessageText = NStr("en = 'Currency mismatch. The cash register and the cash account should have the same currency.'; ru = 'Валюты  не совпадают. Кассовый аппарат и кассовый счет должны иметь одинаковую валюту.';pl = 'Niedopasowanie waluty. Kasa fiskalna i rachunek gotówkowy powinny mieć tę samą walutę.';es_ES = 'Desfase de divisas. La caja registradora y la cuenta de caja deben tener la misma divisa.';es_CO = 'Desfase de divisas. La caja registradora y la cuenta de caja deben tener la misma divisa.';tr = 'Para birimi uyuşmazlığı. Yazar kasa ile kasa hesabı aynı para birimine sahip olmalıdır.';it = 'Discrepanza di valuta. Il registratore di cassa ed il conto di cassa devono avere la stessa valuta.';de = 'Währungsungleichgewicht. Die Kasse und das Liquiditätskonto sollten die gleiche Währung haben.'");
					DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "PettyCash", Cancel);
					
				EndIf;
				
			EndIf;
			
			If ValueIsFilled(BasisDocument) And TypeOf(BasisDocument) = Type("DocumentRef.ShiftClosure") Then
				
				ShiftClosureCashCR = Common.ObjectAttributeValue(BasisDocument, "CashCR");
				
				If ShiftClosureCashCR <> CashCR Then
					
					MessageText = NStr("en = 'Cash registers mismatch. The selected cash register should be the same as in the shift closure.'; ru = 'Ошибка выбора кассового аппарата. Кассовый аппарат должен совпадать с выбранным в закрытии смены.';pl = 'Niezgodność kas fiskalnych. Wybrana kasa fiskalna powinna być taka sama, jak w przypadku zamknięcia zmiany.';es_ES = 'Desfase de divisas. La caja registradora seleccionada debe ser la misma como en el cierre de turno.';es_CO = 'Desfase de divisas. La caja registradora seleccionada debe ser la misma como en el cierre de turno.';tr = 'Yazar kasa uyumsuzluğu. Seçilen yazar kasa, vardiya kapanışı ile aynı olmalıdır.';it = 'Discrepanza di registratore di cassa. Il registratore di cassa selezionato dovrebbe essere lo stessso del turno di chiusura.';de = 'Kassen haben ein Ungleichgewicht. Die ausgewählte Kasse sollte mit dem Schichtende übereinstimmen.'");
					DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "CashCR", Cancel);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The document amount (%1 %3) is not equal to the sum of payment amounts in the payment details (%2 %3).'; ru = 'Сумма документа (%1 %3) не соответствует сумме разнесенных платежей в табличной части (%2 %3).';pl = 'Kwota dokumentu (%1 %3) różni się od sumy kwot płatności w szczegółach płatności (%2 %3).';es_ES = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';es_CO = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';tr = 'Belge tutarı (%1 %3) ödeme ayrıntılarındaki (%2 %3) ödeme tutarı toplamında eşit değildir.';it = 'L''importo del documento (%1 %3) non corrisponde alla somma degli importi di pagamento nei dettagli di pagamento (%2 %3).';de = 'Der Belegbetrag (%1 %3) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%2 %3).'"),
							TrimAll(DocumentAmount),
							TrimAll(PaymentAmount),
							TrimAll(CashCurrency));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.Other Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		
		If Not RegisterIncome Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
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
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.CurrencyPurchase Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		
		If Not RegisterIncome Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
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
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
	// Miscellaneous payable
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The document amount (%1 %3) is not equal to the sum of payment amounts in the payment details (%2 %3).'; ru = 'Сумма документа (%1 %3) не соответствует сумме разнесенных платежей в табличной части (%2 %3).';pl = 'Kwota dokumentu (%1 %3) różni się od sumy kwot płatności w szczegółach płatności (%2 %3).';es_ES = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';es_CO = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';tr = 'Belge tutarı (%1 %3) ödeme ayrıntılarındaki (%2 %3) ödeme tutarı toplamında eşit değildir.';it = 'L''importo del documento (%1 %3) non corrisponde alla somma degli importi di pagamento nei dettagli di pagamento (%2 %3).';de = 'Der Belegbetrag (%1 %3) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%2 %3).'"),
							TrimAll(DocumentAmount),
							TrimAll(PaymentAmount),
							TrimAll(CashCurrency));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel);
		EndIf;
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
		If AdvanceHolder.IsEmpty() Then
			MessageText = NStr("en = 'The ""Employee"" field is required'; ru = 'Поле ""Сотрудник"" не заполнено';pl = 'Należy wypełnić pole ""Pracownik""';es_ES = 'El campo ""Empleado"" se requiere';es_CO = 'El campo ""Empleado"" se requiere';tr = '""Çalışan"" alanı gerekli';it = 'Il campo ""Dipendente"" non è compilato';de = 'Das Feld ""Mitarbeiter"" ist erforderlich'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"AdvanceHolder",
				Cancel);
		EndIf;
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The document amount (%1 %3) is not equal to the sum of payment amounts in the payment details (%2 %3).'; ru = 'Сумма документа (%1 %3) не соответствует сумме разнесенных платежей в табличной части (%2 %3).';pl = 'Kwota dokumentu (%1 %3) różni się od sumy kwot płatności w szczegółach płatności (%2 %3).';es_ES = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';es_CO = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';tr = 'Belge tutarı (%1 %3) ödeme ayrıntılarındaki (%2 %3) ödeme tutarı toplamında eşit değildir.';it = 'L''importo del documento (%1 %3) non corrisponde alla somma degli importi di pagamento nei dettagli di pagamento (%2 %3).';de = 'Der Belegbetrag (%1 %3) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%2 %3).'"),
							TrimAll(DocumentAmount),
							TrimAll(PaymentAmount),
							TrimAll(CashCurrency));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByCounterparty Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder"); 
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
		If Counterparty.IsEmpty() Then
			MessageText = NStr("en = 'The ""Borrower"" field is required'; ru = 'Поле ""Заемщик"" не заполнено';pl = 'Pole ""Pożyczkobiorca"" jest wymagane';es_ES = 'El campo ""Prestatario"" se requiere';es_CO = 'El campo ""Prestatario"" se requiere';tr = '""Borçlanan"" alanı gerekli';it = 'È richiesto il campo ""Mutuatario""';de = 'Das Feld ""Darlehensnehmer"" ist erforderlich'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"Counterparty",
				Cancel);
		EndIf;
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The document amount (%1 %3) is not equal to the sum of payment amounts in the payment details (%2 %3).'; ru = 'Сумма документа (%1 %3) не соответствует сумме разнесенных платежей в табличной части (%2 %3).';pl = 'Kwota dokumentu (%1 %3) różni się od sumy kwot płatności w szczegółach płatności (%2 %3).';es_ES = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';es_CO = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';tr = 'Belge tutarı (%1 %3) ödeme ayrıntılarındaki (%2 %3) ödeme tutarı toplamında eşit değildir.';it = 'L''importo del documento (%1 %3) non corrisponde alla somma degli importi di pagamento nei dettagli di pagamento (%2 %3).';de = 'Der Belegbetrag (%1 %3) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%2 %3).'"),
							TrimAll(DocumentAmount),
							TrimAll(PaymentAmount),
							TrimAll(CashCurrency));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Item");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ThirdPartyCustomerContract");
		
	// End Miscellaneous payable	
	EndIf;

	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	If ValueIsFilled(LoanContract) Then
		Documents.LoanContract.CheckOnPosted(LoanContract, Cancel);	
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
	Documents.CashReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Miscellaneous payable
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
	// End Miscellaneous payable
	DriveServer.ReflectThirdPartyPayments(AdditionalProperties, RegisterRecords, Cancel);
	
	//VAT
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.CashReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.CashReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

#Region OtherSettlements

Procedure FillByLoanContract(DocRefLoanContract, Amount = Undefined) Export
	
	VerifiedAttributesValues = New Structure("Posted", Common.ObjectAttributeValue(DocRefLoanContract, "Posted"));
	Documents.LoanContract.CheckEnterBasedOnLoanContract(VerifiedAttributesValues);
	
	Query = New Query;
	Query.SetParameter("Ref",	DocRefLoanContract);
	Query.SetParameter("Date",	?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	If Amount <> Undefined Then
		
		Query.Text =
		"SELECT ALLOWED
		|	REFPRESENTATION(&Ref) AS Basis,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
		|			THEN VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty)
		|		ELSE VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
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
		|	ISNULL(SettlementsExchangeRate.Rate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRate.Repetition, 1) AS Multiplicity,
		|	CAST(&Amount AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN DocumentTable.PrincipalItem
		|	END AS Item,
		|	DocumentTable.PettyCash AS PettyCash
		|FROM
		|	Document.LoanContract AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsExchangeRate
		|		ON DocumentTable.SettlementsCurrency = SettlementsExchangeRate.Currency
		|			AND DocumentTable.Company = SettlementsExchangeRate.Company
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
		|			THEN VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
		|			THEN VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByCounterparty)
		|		ELSE VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
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
		|	ISNULL(SettlementsExchangeRate.Rate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRate.Repetition, 1) AS Multiplicity,
		|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN DocumentTable.PrincipalItem
		|	END AS Item,
		|	DocumentTable.PettyCash AS PettyCash
		|FROM
		|	Document.LoanContract AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsExchangeRate
		|		ON DocumentTable.SettlementsCurrency = SettlementsExchangeRate.Currency
		|			AND DocumentTable.Company = SettlementsExchangeRate.Company
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
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
		
		If DocRefLoanContract.LoanKind = Enums.LoanContractTypes.Borrowed Then
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
		Else
			DocumentAmount = 0;
		EndIf;
		
		If Not ValueIsFilled(PettyCash) Then
			PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Company);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillByAccrualsForLoans(FillingData) Export
	
	Query = New Query;
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		Query.SetParameter("Ref",					FillingData.Document);
		Query.SetParameter("Borrower",				FillingData.Borrower);
		Query.SetParameter("Counterparty",			FillingData.Lender);
		Query.SetParameter("LoanContract",	FillingData.LoanContract);
		Query.SetParameter("SettlementsCurrency",	FillingData.SettlementsCurrency);
		
	ElsIf FillingData.Accruals.Count() > 0 Then
		
		Query.SetParameter("Ref",					FillingData);
		Query.SetParameter("Borrower",				FillingData.Accruals[0].Borrower);
		Query.SetParameter("Counterparty",			FillingData.Accruals[0].Lender);
		Query.SetParameter("LoanContract",			FillingData.Accruals[0].LoanContract);
		Query.SetParameter("SettlementsCurrency",	FillingData.Accruals[0].SettlementsCurrency);
		
	Else
		Return;
	EndIf;
	
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query.Text =
	"SELECT ALLOWED
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Ref.Company AS Company,
	|	DocumentTable.SettlementsCurrency AS CashCurrency,
	|	DocumentTable.Borrower AS AdvanceHolder,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.AmountType AS TypeOfAmount,
	|	DocumentTable.Total AS PaymentAmount,
	|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
	|	ISNULL(SettlementsExchangeRate.Rate, 1) AS ExchangeRate,
	|	ISNULL(SettlementsExchangeRate.Repetition, 1) AS Multiplicity,
	|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsExchangeRate
	|		ON DocumentTable.SettlementsCurrency = SettlementsExchangeRate.Currency
	|			AND DocumentTable.Ref.Company = SettlementsExchangeRate.Company
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON DocumentTable.Ref.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.LoanContract = &LoanContract
	|	AND DocumentTable.SettlementsCurrency = &SettlementsCurrency
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

#EndIf
