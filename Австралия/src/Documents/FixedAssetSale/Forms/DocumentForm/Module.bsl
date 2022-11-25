#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtClient
// The procedure handles the change of the Price kind and Settlement currency document attributes
//
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	ContractData = DocumentParameters.ContractData;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate      = ?(ContractData.SettlementsCurrencyRateRepetition.Rate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		
	EndIf;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, False, WarningText);
		
	EndIf;
	
EndProcedure

// Function places the list of advances into temporary storage and returns the address
//
&AtServer
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|SettlementsAmount,
			|AmountDocCur,
			|ExchangeRate,
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction

// Function gets the list of advances from the temporary storage
//
&AtServer
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure

&AtClient
// Recalculates the exchange rate and exchange rate multiplier of
// the payment currency when the document date is changed.
//
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurrencyRateRepetition = StructureData.CurrencyRateRepetition;
	SettlementsCurrencyRateRepetition = StructureData.SettlementsCurrencyRateRepetition;
	
	NewExchangeRate	= ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
	NewRatio		= ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
	
	NewContractCurrencyExchangeRate = ?(SettlementsCurrencyRateRepetition.Rate = 0,
		1,
		SettlementsCurrencyRateRepetition.Rate);
	
	NewContractCurrencyRatio = ?(SettlementsCurrencyRateRepetition.Repetition = 0,
		1,
		SettlementsCurrencyRateRepetition.Repetition);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio
		OR Object.ContractCurrencyExchangeRate <> NewContractCurrencyExchangeRate
		OR Object.ContractCurrencyMultiplicity <> NewContractCurrencyRatio Then
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate", NewExchangeRate);
		QuestionParameters.Insert("NewRatio", NewRatio);
		QuestionParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		QuestionParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd", 
			ThisObject,
			QuestionParameters);
		
		QuestionText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
	EndIf;
	
EndProcedure

// Performs the actions after a response to the question about recalculation of the exchange rate and exchange rate multiplier of the payment currency.
//
&AtClient
Procedure QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
		For Each TabularSectionRow In Object.Prepayment Do
			
			TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				ExchangeRateMethod,
				Object.ContractCurrencyExchangeRate,
				Object.ExchangeRate,
				Object.ContractCurrencyMultiplicity,
				Object.Multiplicity);
			
		EndDo;
		
		// Generate price and currency label.
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RefillPrices = False, RecalculatePrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure();
	
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
	ParametersStructure.Insert("VATTaxationReadOnly",			True);
	ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
	ParametersStructure.Insert("Company",						Company);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("WarningText",					WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable",	True);
	ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
	
	// Open form "Prices and Currency".
	// Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	StructurePricesAndCurrency = ClosingResult;
	
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", StructurePricesAndCurrency.DocumentCurrency);
		DocCurRecalcStructure.Insert("Rate", StructurePricesAndCurrency.ExchangeRate);
		DocCurRecalcStructure.Insert("Repetition", StructurePricesAndCurrency.Multiplicity);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrency);
		DocCurRecalcStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		DocCurRecalcStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.DocumentCurrency = StructurePricesAndCurrency.DocumentCurrency;
		Object.ExchangeRate = StructurePricesAndCurrency.ExchangeRate;
		Object.Multiplicity = StructurePricesAndCurrency.Multiplicity;
		Object.ContractCurrencyExchangeRate = StructurePricesAndCurrency.SettlementsRate;
		Object.ContractCurrencyMultiplicity = StructurePricesAndCurrency.SettlementsMultiplicity;
		Object.VATTaxation = StructurePricesAndCurrency.VATTaxation;
		Object.AmountIncludesVAT = StructurePricesAndCurrency.AmountIncludesVAT;
		Object.IncludeVATInPrice = StructurePricesAndCurrency.IncludeVATInPrice;
		Object.AutomaticVATCalculation = StructurePricesAndCurrency.AutomaticVATCalculation;
		
		// Recalculate prices by currency.
		If StructurePricesAndCurrency.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "FixedAssets");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "FixedAssets");
		EndIf;
		
		For Each TabularSectionRow In Object.Prepayment Do
			
			TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				ExchangeRateMethod,
				Object.ContractCurrencyExchangeRate,
				Object.ExchangeRate,
				Object.ContractCurrencyMultiplicity,
				Object.Multiplicity);
			
		EndDo;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	OpenPricesAndCurrencyFormEndAtServer();
	
EndProcedure

&AtServer
Procedure OpenPricesAndCurrencyFormEndAtServer()
	
	SetPrepaymentColumnsProperties();
	
EndProcedure

&AtServer
Procedure SetPrepaymentColumnsProperties()
	
	Items.PrepaymentSettlementsAmount.Title =
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Clearing amount (%1)'; ru = 'Сумма зачета (%1)';pl = 'Kwota rozliczenia (%1)';es_ES = 'Importe de liquidaciones (%1)';es_CO = 'Importe de liquidaciones (%1)';tr = 'Mahsup edilen tutar (%1)';it = 'Importo di compensazione (%1)';de = 'Ausgleichsbetrag (%1)'"),
			SettlementsCurrency);
	
	If Object.DocumentCurrency = SettlementsCurrency Then
		Items.PrepaymentAmountDocCur.Visible = False;
	Else
		Items.PrepaymentAmountDocCur.Visible = True;
		Items.PrepaymentAmountDocCur.Title =
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Cantidad (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
				Object.DocumentCurrency);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange(Object.DocumentCurrency, SettlementsCurrency);
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency();
	
	DocumentDate = Object.Date;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DocumentCurrency, SettlementsCurrency)
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, DocumentCurrency, Object.Company);
	
	ProcessingCompanyVATNumbers();
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	If DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

// Receives the data set from the server for the CompanyOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(Object.Company));
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillFixedAssets", False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	FillVATRateByVATTaxation();
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillFixedAssets", False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	StructureData = New Structure();
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
		
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, ContractByDefault.SettlementsCurrency, Company)
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), ContractByDefault.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataContractOnChange(Date, DocumentCurrency, Contract, Company)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillFixedAssets", False);
		
		FillAddedColumns(ParametersStructure);
	
	EndIf;
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company)
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction

&AtServer
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData)
																	
	If Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;												
	
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FillFixedAssets", True);
	ParametersStructure.Insert("GetGLAccounts", False);
	
	If UseDefaultTypeOfAccounting Then
		ParametersStructure.Insert("FillHeader", True);
	EndIf;
	
	FillAddedColumns(ParametersStructure);
				
	Return StructureData;
	
EndFunction

&AtServer
// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
Procedure FillVATRateByCompanyVATTaxation()
	
	// to be removed
	Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
	Return;
	
	If WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, True)
		And Object.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT Then
		Return;
	EndIf;
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.FixedAssetsVatRate.Visible = True;
		Items.FixedAssetsAmountVAT.Visible = True;
		Items.FixedAssetsTotal.Visible = True;
		Items.VATAmount.Visible = True;
		
		For Each TabularSectionRow In Object.FixedAssets Do
			
			TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
						
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.FixedAssetsVatRate.Visible = False;
		Items.FixedAssetsAmountVAT.Visible = False;
		Items.FixedAssetsTotal.Visible = False;
		Items.VATAmount.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
		    DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		For Each TabularSectionRow In Object.FixedAssets Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	If Object.AmountIncludesVAT Then
		TabularSectionRow.VATAmount = TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100);
	Else
		TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
	EndIf;
	
EndProcedure

// Calculates the assets depreciation.
//
&AtServerNoContext
Procedure CalculateDepreciation(AddressFixedAssetsInStorage, Date, Company)
	
	TableFixedAssets = GetFromTempStorage(AddressFixedAssetsInStorage);
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.SetParameter("Period",		   Date);
	Query.SetParameter("Company",   Company);
	Query.SetParameter("BegOfYear",	   BegOfYear(Date));
	Query.SetParameter("BeginOfPeriod", BegOfMonth(Date));
	Query.SetParameter("EndOfPeriod",  EndOfMonth(Date));
	Query.SetParameter("FixedAssetsList", TableFixedAssets.UnloadColumn("FixedAsset"));
	Query.SetParameter("TableFixedAssets", TableFixedAssets);
	
	Query.Text =
	"SELECT ALLOWED
	|	ListOfAmortizableFA.FixedAsset AS FixedAsset,
	|	PRESENTATION(ListOfAmortizableFA.FixedAsset) AS FixedAssetPresentation,
	|	ListOfAmortizableFA.FixedAsset.Code AS Code,
	|	ListOfAmortizableFA.BeginAccrueDepriciation AS BeginAccrueDepriciation,
	|	ListOfAmortizableFA.EndAccrueDepriciation AS EndAccrueDepriciation,
	|	ListOfAmortizableFA.EndAccrueDepreciationInCurrentMonth AS EndAccrueDepreciationInCurrentMonth,
	|	ISNULL(FACost.DepreciationClosingBalance, 0) AS DepreciationClosingBalance,
	|	ISNULL(FACost.DepreciationTurnover, 0) AS DepreciationTurnover,
	|	ISNULL(FACost.CostClosingBalance, 0) AS BalanceCost,
	|	ISNULL(FACost.CostOpeningBalance, 0) AS CostOpeningBalance,
	|	ISNULL(DepreciationBalancesAndTurnovers.CostOpeningBalance, 0) - ISNULL(DepreciationBalancesAndTurnovers.DepreciationOpeningBalance, 0) AS CostAtBegOfYear,
	|	ISNULL(ListOfAmortizableFA.FixedAsset.DepreciationMethod, 0) AS DepreciationMethod,
	|	ISNULL(ListOfAmortizableFA.FixedAsset.InitialCost, 0) AS OriginalCost,
	|	ISNULL(DepreciationParametersSliceLast.ApplyInCurrentMonth, 0) AS ApplyInCurrentMonth,
	|	DepreciationParametersSliceLast.Period AS Period,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.UsagePeriodForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.UsagePeriodForDepreciationCalculation, 0)
	|	END AS UsagePeriodForDepreciationCalculation,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.CostForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.CostForDepreciationCalculation, 0)
	|	END AS CostForDepreciationCalculation,
	|	ISNULL(DepreciationSignChange.UpdateAmortAccrued, FALSE) AS UpdateAmortAccrued,
	|	ISNULL(DepreciationSignChange.AccrueInCurMonth, FALSE) AS AccrueInCurMonth,
	|	ISNULL(FixedAssetOutputTurnovers.QuantityTurnover, 0) AS OutputVolume,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.AmountOfProductsServicesForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.AmountOfProductsServicesForDepreciationCalculation, 0)
	|	END AS AmountOfProductsServicesForDepreciationCalculation
	|INTO TemporaryTableForDepreciationCalculation
	|FROM
	|	(SELECT
	|		SliceFirst.AccrueDepreciation AS BeginAccrueDepriciation,
	|		SliceLast.AccrueDepreciation AS EndAccrueDepriciation,
	|		SliceLast.AccrueDepreciationInCurrentMonth AS EndAccrueDepreciationInCurrentMonth,
	|		SliceLast.FixedAsset AS FixedAsset
	|	FROM
	|		(SELECT
	|			FixedAssetStateSliceFirst.FixedAsset AS FixedAsset,
	|			FixedAssetStateSliceFirst.AccrueDepreciation AS AccrueDepreciation,
	|			FixedAssetStateSliceFirst.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
	|			FixedAssetStateSliceFirst.Period AS Period
	|		FROM
	|			InformationRegister.FixedAssetStatus.SliceLast(
	|					&BeginOfPeriod,
	|					Company = &Company
	|						AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceFirst) AS SliceFirst
	|			Full JOIN (SELECT
	|				FixedAssetStateSliceLast.FixedAsset AS FixedAsset,
	|				FixedAssetStateSliceLast.AccrueDepreciation AS AccrueDepreciation,
	|				FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
	|				FixedAssetStateSliceLast.Period AS Period
	|			FROM
	|				InformationRegister.FixedAssetStatus.SliceLast(
	|						&EndOfPeriod,
	|						Company = &Company
	|							AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceLast) AS SliceLast
	|			ON SliceFirst.FixedAsset = SliceLast.FixedAsset) AS ListOfAmortizableFA
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(
	|				&BegOfYear,
	|				,
	|				,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationBalancesAndTurnovers
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationBalancesAndTurnovers.FixedAsset
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(
	|				&BeginOfPeriod,
	|				&EndOfPeriod,
	|				,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS FACost
	|		ON ListOfAmortizableFA.FixedAsset = FACost.FixedAsset
	|		LEFT JOIN InformationRegister.FixedAssetParameters.SliceLast(
	|				&EndOfPeriod,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationParametersSliceLast
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationParametersSliceLast.FixedAsset
	|		LEFT JOIN InformationRegister.FixedAssetParameters.SliceLast(
	|				&BeginOfPeriod,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationParametersSliceLastBegOfMonth
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationParametersSliceLastBegOfMonth.FixedAsset
	|		LEFT JOIN (SELECT
	|			COUNT(DISTINCT TRUE) AS UpdateAmortAccrued,
	|			FixedAssetState.FixedAsset AS FixedAsset,
	|			FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth AS AccrueInCurMonth
	|		FROM
	|			InformationRegister.FixedAssetStatus AS FixedAssetState
	|				INNER JOIN InformationRegister.FixedAssetStatus.SliceLast(
	|						&EndOfPeriod,
	|						Company = &Company
	|							AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceLast
	|				ON FixedAssetState.FixedAsset = FixedAssetStateSliceLast.FixedAsset
	|		WHERE
	|			FixedAssetState.Period between &BeginOfPeriod AND &EndOfPeriod
	|			AND FixedAssetState.Company = &Company
	|			AND FixedAssetState.FixedAsset IN(&FixedAssetsList)
	|		
	|		GROUP BY
	|			FixedAssetState.FixedAsset,
	|			FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth) AS DepreciationSignChange
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationSignChange.FixedAsset
	|		LEFT JOIN AccumulationRegister.FixedAssetUsage.Turnovers(
	|				&BeginOfPeriod,
	|				&EndOfPeriod,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetOutputTurnovers
	|		ON ListOfAmortizableFA.FixedAsset = FixedAssetOutputTurnovers.FixedAsset
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&Period AS Period,
	|	Table.FixedAsset AS FixedAsset,
	|	Table.FixedAssetPresentation AS FixedAssetPresentation,
	|	Table.Code AS Code,
	|	Table.DepreciationClosingBalance AS DepreciationClosingBalance,
	|	Table.BalanceCost AS BalanceCost,
	|	0 AS Cost,
	|	CASE
	|		WHEN CASE
	|				WHEN Table.DepreciationAmount < Table.TotalLeftToWriteOff
	|					THEN Table.DepreciationAmount
	|				ELSE Table.TotalLeftToWriteOff
	|			END > 0
	|			THEN CASE
	|					WHEN Table.DepreciationAmount < Table.TotalLeftToWriteOff
	|						THEN Table.DepreciationAmount
	|					ELSE Table.TotalLeftToWriteOff
	|				END
	|		ELSE 0
	|	END AS Depreciation
	|INTO TableDepreciationCalculation
	|FROM
	|	(SELECT
	|		CASE
	|			WHEN Table.DepreciationMethod = VALUE(Enum.FixedAssetDepreciationMethods.Linear)
	|				THEN Table.CostForDepreciationCalculation / CASE
	|						WHEN Table.UsagePeriodForDepreciationCalculation = 0
	|							THEN 1
	|						ELSE Table.UsagePeriodForDepreciationCalculation
	|					END
	|			WHEN Table.DepreciationMethod = VALUE(Enum.FixedAssetDepreciationMethods.ProportionallyToProductsVolume)
	|				THEN Table.CostForDepreciationCalculation * Table.OutputVolume / CASE
	|						WHEN Table.AmountOfProductsServicesForDepreciationCalculation = 0
	|							THEN 1
	|						ELSE Table.AmountOfProductsServicesForDepreciationCalculation
	|					END
	|			ELSE 0
	|		END AS DepreciationAmount,
	|		Table.FixedAsset AS FixedAsset,
	|		Table.FixedAssetPresentation AS FixedAssetPresentation,
	|		Table.Code AS Code,
	|		Table.DepreciationClosingBalance AS DepreciationClosingBalance,
	|		Table.BalanceCost AS BalanceCost,
	|		Table.BalanceCost - Table.DepreciationClosingBalance AS TotalLeftToWriteOff
	|	FROM
	|		TemporaryTableForDepreciationCalculation AS Table) AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableForDepreciationCalculation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableFixedAssets.LineNumber AS LineNumber,
	|	TableFixedAssets.FixedAsset AS FixedAsset,
	|	TableFixedAssets.Amount AS Amount,
	|	TableFixedAssets.VATRate AS VATRate,
	|	TableFixedAssets.VATAmount AS VATAmount,
	|	TableFixedAssets.Total AS Total,
	|	TableFixedAssets.ExpenseItem AS ExpenseItem,
	|	TableFixedAssets.IncomeItem AS IncomeItem
	|INTO TableFixedAssets
	|FROM
	|	&TableFixedAssets AS TableFixedAssets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableFixedAssets.LineNumber AS LineNumber,
	|	TableFixedAssets.FixedAsset AS FixedAsset,
	|	TableFixedAssets.Amount AS Amount,
	|	TableFixedAssets.VATRate AS VATRate,
	|	TableFixedAssets.VATAmount AS VATAmount,
	|	TableFixedAssets.Total AS Total,
	|	TableFixedAssets.ExpenseItem AS ExpenseItem,
	|	TableFixedAssets.IncomeItem AS IncomeItem,
	|	TableDepreciationCalculation.BalanceCost AS Cost,
	|	TableDepreciationCalculation.Depreciation AS MonthlyDepreciation,
	|	TableDepreciationCalculation.DepreciationClosingBalance AS Depreciation,
	|	TableDepreciationCalculation.BalanceCost - TableDepreciationCalculation.DepreciationClosingBalance AS DepreciatedCost
	|FROM
	|	TableFixedAssets AS TableFixedAssets
	|		LEFT JOIN TableDepreciationCalculation AS TableDepreciationCalculation
	|		ON TableFixedAssets.FixedAsset = TableDepreciationCalculation.FixedAsset
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableFixedAssets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableDepreciationCalculation";
	
	QueryResult = Query.ExecuteBatch();
	
	DepreciationTable = QueryResult[4].Unload();
	
	PutToTempStorage(DepreciationTable, AddressFixedAssetsInStorage);
	
EndProcedure

// The function puts the FixedAssets tabular section
// to the temporary storage and returns an address
//
&AtServer
Function PlaceFixedAssetsToStorage()
	
	Return PutToTempStorage(
		Object.FixedAssets.Unload(,
			"LineNumber,
			|FixedAsset,
			|Amount,
			|VATRate,
			|VATAmount,
			|Total,
			|ExpenseItem,
			|IncomeItem"
		),
		UUID
	);
	
EndFunction

// The function receives the FixedAssets tabular section from the temporary storage.
//
&AtServer
Procedure GetFixedAssetsFromStorage(AddressFixedAssetsInStorage)
	
	TableFixedAssets = GetFromTempStorage(AddressFixedAssetsInStorage);
	Object.FixedAssets.Clear();
	For Each RowFixedAssets In TableFixedAssets Do
		String = Object.FixedAssets.Add();
		FillPropertyValues(String, RowFixedAssets);
	EndDo;
	
	FillVATRateByVATTaxation();
		
EndProcedure

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		DocumentParameters = New Structure;
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract, Object.Company);
			
		Else
			
			DocumentParameters.Insert("CounterpartyBeforeChange", ContractData.CounterpartyBeforeChange);
			
		EndIf;
		
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
			AND ValueIsFilled(SettlementsCurrency)
			AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.FixedAssets.Count() > 0;
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
		
		If Object.Prepayment.Count() > 0 Then
			
			QuestionText = NStr("en = 'Prepayment setoff will be cleared, continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Zaliczenie przedpłaty będzie anulowane, kontynuować?';es_ES = 'Compensación del prepago se liquidará, ¿continuar?';es_CO = 'Compensación del prepago se liquidará, ¿continuar?';tr = 'Ön ödeme mahsuplaştırılması silinecek, devam mı?';it = 'Pagamento anticipato compensazione verrà cancellata, continuare?';de = 'Anzahlungsverrechnung wird gelöscht, fortsetzen?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
			
		EndIf;
		
		SetPrepaymentColumnsProperties();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	PerInvoiceVATRoundingRule	= AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForVAT			= AccountingPolicy.RegisteredForVAT;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting
		And ParametersStructure.FillHeader Then
			
		Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
		GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
		StructureArray.Add(Header);
			
	EndIf;
	
	If ParametersStructure.FillFixedAssets Then
		
		FixedAssets = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "FixedAssets", Object);
		GLAccountsInDocuments.CompleteStructureData(FixedAssets, ObjectParameters, "FixedAssets");
		
		StructureArray.Add(FixedAssets);
		
	EndIf;

	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting
		And ParametersStructure.FillHeader Then
		GLAccounts = Header.GLAccounts;
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateLabelPricesAndCurrency()
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
Procedure SetFixedAssetsCalculatedEnabled()
	
	Items.FixedAssetsCalculated.Enabled = Not Object.Posted;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	Company = DriveServer.GetCompany(Object.Company);
	
	StructureByCurrencyDocument = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency = StructureByCurrency.Rate;
	RepetitionNationalCurrency = StructureByCurrency.Repetition;
	DocumentSubtotal = Object.FixedAssets.Total("Total") - Object.FixedAssets.Total("VATAmount");
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherExpenses");
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherIncome");
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	SetAccountingPolicyValues();
	
	SetPrepaymentColumnsProperties();
	
	// to be removed on VAT review, also check document module Filling()
	// also check FillVATRateByCompanyVATTaxation() in this module
	// also to be deleted the VATTaxationReadOnly parameter in this module and in the PricesAndCurrency form
	Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis) 
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	EndIf;
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		Items.FixedAssetsVatRate.Visible = True;
		Items.FixedAssetsAmountVAT.Visible = True;
		Items.FixedAssetsTotal.Visible = True;
		Items.VATAmount.Visible = True;
	Else
		Items.FixedAssetsVatRate.Visible = False;
		Items.FixedAssetsAmountVAT.Visible = False;
		Items.FixedAssetsTotal.Visible = False;
		Items.VATAmount.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	// to be removed on VAT review, also check document module Filling()
	// also to be deleted the VATTaxationReadOnly parameter in this module and in the PricesAndCurrency form
	Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency", SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate", Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency", RateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting", ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation", Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ProcessingCompanyVATNumbers();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FillFixedAssets", True);
	ParametersStructure.Insert("GetGLAccounts", False);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	If UseDefaultTypeOfAccounting Then
		ParametersStructure.Insert("FillHeader", True);
	EndIf;
	
	FillAddedColumns(ParametersStructure);
	
	Items.GLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	// Setting contract visible.
	SetContractVisible();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FillFixedAssets", True);
	ParametersStructure.Insert("GetGLAccounts", False);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	If UseDefaultTypeOfAccounting Then
		ParametersStructure.Insert("FillHeader", True);
	EndIf;
	
	FillAddedColumns(ParametersStructure);
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
// Procedure - event handler OnOpen.
//
Procedure OnOpen(Cancel)
	
	SetFixedAssetsCalculatedEnabled();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	SetFixedAssetsCalculatedEnabled();
	
	Notify("FixedAssetsStatesUpdate");
	Notify("NotificationAboutChangingDebt");
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FillFixedAssets", True);
	ParametersStructure.Insert("GetGLAccounts", False);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	If UseDefaultTypeOfAccounting Then
		ParametersStructure.Insert("FillHeader", True);
	EndIf;
	
	FillAddedColumns(ParametersStructure);
		
EndProcedure

// Procedure - event handler of the form BeforeWrite
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	UpdateSubordinatedInvoice = Modified;
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer form.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting
	   AND DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes
	   AND CurrentObject.Prepayment.Count() = 0 Then
		FillPrepayment(CurrentObject);
	EndIf;
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("TabularSectionName", "FixedAssets");
	WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

// Procedure fills advances.
//
&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter)
		   AND Object.Counterparty = Parameter Then
		   
			ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		   
			SetContractVisible();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler ChoiceProcessing.
//
&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
Procedure PricesAndCurrencyClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
EndProcedure

// Procedure - Execute event handler of the PrepaymentOffset command
//
&AtClient
Procedure PrepaymentSetoffExecute(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a counterparty.'; ru = 'Выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please select a contract.'; ru = 'Выберите договор.';pl = 'Wybierz umowę.';es_ES = 'Por favor, especifique un contrato.';es_CO = 'Por favor, especifique un contrato.';tr = 'Lütfen, sözleşme seçin.';it = 'Si prega di selezionare un contratto.';de = 'Bitte wählen Sie einen Vertrag aus.'"));
		Return;
	EndIf;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressPrepaymentInStorage"		, AddressPrepaymentInStorage);
	SelectionParameters.Insert("Pick" 							, True);
	SelectionParameters.Insert("IsOrder"						, False);
	SelectionParameters.Insert("OrderInHeader"					, False);
	SelectionParameters.Insert("Company"						, Company);
	SelectionParameters.Insert("Date"							, Object.Date);
	SelectionParameters.Insert("Ref"							, Object.Ref);
	SelectionParameters.Insert("Counterparty"					, Object.Counterparty);
	SelectionParameters.Insert("Contract"						, Object.Contract);
	SelectionParameters.Insert("ContractCurrencyExchangeRate"	, Object.ContractCurrencyExchangeRate);
	SelectionParameters.Insert("ContractCurrencyMultiplicity"	, Object.ContractCurrencyMultiplicity);
	SelectionParameters.Insert("ExchangeRate"					, Object.ExchangeRate);
	SelectionParameters.Insert("Multiplicity"					, Object.Multiplicity);
	SelectionParameters.Insert("DocumentCurrency"				, Object.DocumentCurrency);
	SelectionParameters.Insert("DocumentAmount"					, Object.FixedAssets.Total("Total"));
	
	ReturnCode = Undefined;
	
	NotifyDescription = New NotifyDescription("ExecuteEndSetoffPrepayment",
		ThisObject,
		New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage));
	
	OpenForm("CommonForm.SelectAdvancesReceivedFromTheCustomer", SelectionParameters,,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure ExecuteEndSetoffPrepayment(Result, AdditionalParameters) Export
    
    AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
    
    
    ReturnCode = Result;
    
    If ReturnCode = DialogReturnCode.OK Then
        GetPrepaymentFromStorage(AddressPrepaymentInStorage);
    EndIf;

EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	Company = StructureData.Company;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	GenerateLabelPricesAndCurrency();
	
	ProcessingCompanyVATNumbers(False);
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
		
		FillVATRateByCompanyVATTaxation();
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		
		StructureData.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		
		ProcessContractChange(StructureData);
		GenerateLabelPricesAndCurrency();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
EndProcedure

// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "");
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#Region FormItemEventHandlersFormTableFixedAssets

// Procedure - OnChange event handler of
// edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsOnChange(Item)
	
	DocumentSubtotal = Object.FixedAssets.Total("Total") - Object.FixedAssets.Total("VATAmount");
	
EndProcedure

// Procedure - OnChange event handler of
// the FixedAssets edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.ExpenseItem = DefaultExpenseItem;
	TabularSectionRow.IncomeItem = DefaultIncomeItem;
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
		
	StructureData = GetDataProductsOnChange(StructureData);
		
	TabularSectionRow.VATRate = StructureData.VATRate;
			
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - OnChange event handler of
// the Cost edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsCostOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.DepreciatedCost = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	
EndProcedure

// Procedure - OnChange event handler of
// the Depreciation edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsDepreciationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.Depreciation = ?(
		TabularSectionRow.Depreciation > TabularSectionRow.Cost,
		TabularSectionRow.Cost,
		TabularSectionRow.Depreciation
	);
	TabularSectionRow.DepreciatedCost = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	DepreciationInCurrentMonthMax = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	TabularSectionRow.MonthlyDepreciation = ?(
		TabularSectionRow.MonthlyDepreciation > DepreciationInCurrentMonthMax,
		DepreciationInCurrentMonthMax,
		TabularSectionRow.MonthlyDepreciation
	);
	
EndProcedure

// Procedure - OnChange event handler of
// the ResidualCost edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsDepreciatedCostOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.DepreciatedCost = ?(
		TabularSectionRow.DepreciatedCost > TabularSectionRow.Cost,
		TabularSectionRow.Cost,
		TabularSectionRow.DepreciatedCost
	);
	TabularSectionRow.Depreciation = TabularSectionRow.Cost - TabularSectionRow.DepreciatedCost;
	DepreciationInCurrentMonthMax = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	TabularSectionRow.MonthlyDepreciation = ?(
		TabularSectionRow.MonthlyDepreciation > DepreciationInCurrentMonthMax,
		DepreciationInCurrentMonthMax,
		TabularSectionRow.MonthlyDepreciation
	);
	
EndProcedure

// Procedure - OnChange event handler of
// the DepreciationForMonth edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsDepreciationForMonthOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	DepreciationInCurrentMonthMax = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	TabularSectionRow.MonthlyDepreciation = ?(
		TabularSectionRow.MonthlyDepreciation > DepreciationInCurrentMonthMax,
		DepreciationInCurrentMonthMax,
		TabularSectionRow.MonthlyDepreciation
	);
	
EndProcedure

// Procedure - OnChange event handler of
// the VATRate edit box of the FixedAssets tabular section. Calculates VAT amount.
//
&AtClient
Procedure FixedAssetsVATRateOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - OnChange event handler of
// the VATAmount edit box of the FixedAssets tabular section. Calculates VAT amount.
//
&AtClient
Procedure FixedAssetsVATAmountOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - OnChange event handler of
// the Amount edit box of the FixedAssets tabular section. Calculates VAT amount.
//
&AtClient
Procedure FixedAssetsAmountOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
Procedure FixedAssetsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "FixedAssets", StandardProcessing);
	
EndProcedure

&AtClient
Procedure FixedAssetsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "FixedAssetsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "FixedAssets");
	EndIf;
	
EndProcedure

&AtClient
Procedure FixedAssetsOnActivateCell(Item)
	
	CurrentData = Items.FixedAssets.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.FixedAssets.CurrentItem;
		If TableCurrentColumn.Name = "FixedAssetsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.FixedAssets.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "FixedAssets");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FixedAssetsOnStartEdit(Item, NewRow, Clone)
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure FixedAssetsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

#EndRegion

// Procedure - the Calculate command action handler.
//
&AtClient
Procedure Calculate(Command)
	
	If Object.Posted Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("CalculateEnd", ThisObject);
	
	If Object.FixedAssets.Count() > 0 Then
		ShowQueryBox(NotifyDescription,
			NStr("en = 'Entered data will be recalculated. Continue?'; ru = 'Введенные данные будут пересчитаны! Продолжить?';pl = 'Wprowadzone dane zostaną przeliczone. Kontynuować?';es_ES = 'Datos introducidos se recalcularán. ¿Continuar?';es_CO = 'Datos introducidos se recalcularán. ¿Continuar?';tr = 'Girilen veriler yeniden hesaplanacaktır. Devam et?';it = 'I dati inseriti verranno ricalcolati. Proseguire?';de = 'Die eingegebenen Daten werden neu berechnet. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	AddressFixedAssetsInStorage = PlaceFixedAssetsToStorage();
	CalculateDepreciation(AddressFixedAssetsInStorage, Object.Date, Company);
	GetFixedAssetsFromStorage(AddressFixedAssetsInStorage);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FillFixedAssets", True);
	ParametersStructure.Insert("GetGLAccounts", False);
	
	If UseDefaultTypeOfAccounting Then
		ParametersStructure.Insert("FillHeader", True);
	EndIf;
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

#Region FormTableItemsEventHandlersPrepayment

&AtClient
Procedure PrepaymentSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	CalculatePrepaymentPaymentAmount(TabularSectionRow);
	
	TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		Object.ContractCurrencyExchangeRate,
		Object.ExchangeRate,
		Object.ContractCurrencyMultiplicity,
		Object.Multiplicity);
	
EndProcedure

&AtClient
Procedure PrepaymentRateOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
EndProcedure

&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor") Then
		If TabularSectionRow.PaymentAmount <> 0 Then
			TabularSectionRow.ExchangeRate = TabularSectionRow.SettlementsAmount
				* TabularSectionRow.Multiplicity
				/ TabularSectionRow.PaymentAmount;
		EndIf;
	Else
		If TabularSectionRow.SettlementsAmount <> 0 Then
			TabularSectionRow.ExchangeRate = TabularSectionRow.PaymentAmount
				/ TabularSectionRow.SettlementsAmount
				* TabularSectionRow.Multiplicity;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure PrepaymentDocumentOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		
		ParametersStructure = GetAdvanceExchangeRateParameters(TabularSectionRow.Document);
		
		TabularSectionRow.ExchangeRate = GetCalculatedAdvanceExchangeRate(ParametersStructure);
		
		CalculatePrepaymentPaymentAmount(TabularSectionRow);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

// Performs the actions after a response to the question about prepayment clearing.
//
&AtClient
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		ProcessPricesKindAndSettlementsCurrencyChange(AdditionalParameters);
		
	Else
		
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		
		If AdditionalParameters.Property("CounterpartyBeforeChange") Then
			
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region Private

&AtClient
Procedure CalculatePrepaymentPaymentAmount(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Prepayment.CurrentData;
	EndIf;
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		1,
		TabularSectionRow.Multiplicity,
		1);
	
EndProcedure

&AtClient
Function GetAdvanceExchangeRateParameters(DocumentParam)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Ref", Object.Ref);
	ParametersStructure.Insert("Company", Company);
	ParametersStructure.Insert("Counterparty", Object.Counterparty);
	ParametersStructure.Insert("Contract", Object.Contract);
	ParametersStructure.Insert("Document", DocumentParam);
	ParametersStructure.Insert("Order", Undefined);
	ParametersStructure.Insert("Period", EndOfDay(Object.Date) + 1);
	
	Return ParametersStructure;
	
EndFunction

&AtServerNoContext
Function GetCalculatedAdvanceExchangeRate(ParametersStructure)
	
	Return DriveServer.GetCalculatedAdvanceReceivedExchangeRate(ParametersStructure);
	
EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion
