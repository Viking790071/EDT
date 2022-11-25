#Region Variables

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtServer
Procedure GetFormValuesOfParameters()
	
	If Parameters.Property("PriceKind") Then
		PriceKind = Parameters.PriceKind;
		PriceKindOnOpen = Parameters.PriceKind;
		PriceKindIsAttribute = True;
	Else
		Items.PriceKind.Visible = False;
		PriceKindIsAttribute = False;
		Items.DiscountKind.Visible = False;
		DiscountKindIsAttribute = False;
	EndIf;
	
	If Parameters.Property("Company") Then
		DocDate = Undefined;
		Parameters.Property("DocumentDate", DocDate);
		Company = Parameters.Company;
		
		WorkWithForm.SetChoiceParametersByCompany(Company, ThisForm, "PriceKind");
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		Company = DriveReUse.GetUserDefaultCompany();
	EndIf;
	
	If ValueIsFilled(Company) Then
		CompanyAttributes = Common.ObjectAttributesValues(Company, "ExchangeRateMethod,PresentationCurrency");
		ExchangeRateMethod = CompanyAttributes.ExchangeRateMethod;
		PresentationCurrency = CompanyAttributes.PresentationCurrency;
	EndIf;
	
	If Parameters.Property("DocumentCurrencyEnabled") Then
		Items.Currency.ReadOnly = NOT Parameters.DocumentCurrencyEnabled;
		Items.RecalculatePrices.Visible = Parameters.DocumentCurrencyEnabled;
	EndIf;
	
	UseCounterpartiesPricesTracking = GetFunctionalOption("UseCounterpartiesPricesTracking");
	If Parameters.Property("SupplierPriceTypes") And UseCounterpartiesPricesTracking Then
		
		SupplierPriceTypes = Parameters.SupplierPriceTypes;
		PriceKindCounterpartyOnOpen = Parameters.SupplierPriceTypes;
		Counterparty = Parameters.Counterparty;
		PriceKindCounterpartyIsAttribute = True;
		
		ValueArray = New Array;
		ValueArray.Add(Counterparty);
		ValueArray = New FixedArray(ValueArray);
		NewParameter = New ChoiceParameter("Filter.Owner", ValueArray);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.SupplierPriceTypes.ChoiceParameters = NewParameters;
		
	Else
		
		Items.SupplierPriceTypes.Visible = False;
		PriceKindCounterpartyIsAttribute = False;
		Items.SupplierDiscountKind.Visible = False;
		SupplierDiscountKindIsAttribute = False;
		
	EndIf;
	
	If Parameters.Property("RegisterVendorPrices") And UseCounterpartiesPricesTracking Then
		RegisterVendorPrices = Parameters.RegisterVendorPrices;
		RegisterVendorPricesOnOpen = Parameters.RegisterVendorPrices;
		RegisterVendorPricesIsAttribute = True;
	Else
		Items.RegisterVendorPrices.Visible = False;
		RegisterVendorPricesIsAttribute = False;
	EndIf;
	
	If Parameters.Property("RefillPrices") Then
		RefillPrices = Parameters.RefillPrices;
	EndIf;
	
	If Not (PriceKindIsAttribute OR PriceKindCounterpartyIsAttribute) Then
		Items.RefillPrices.Visible = False;
	EndIf; 
	
	If Parameters.Property("DiscountKind") Then
		DiscountKind = Parameters.DiscountKind;
		DiscountKindOnOpen = Parameters.DiscountKind;
		DiscountKindIsAttribute = True;
	Else
		Items.DiscountKind.Visible = False;
		DiscountKindIsAttribute = False;
	EndIf;
	
	If Parameters.Property("SupplierDiscountKind") Then
		SupplierDiscountKind = Parameters.SupplierDiscountKind;
		SupplierDiscountKindOnOpen = Parameters.SupplierDiscountKind;
		Items.SupplierDiscountKind.Visible = True;
		SupplierDiscountKindIsAttribute = True;
	Else
		Items.SupplierDiscountKind.Visible = False;
		SupplierDiscountKindIsAttribute = False;
	EndIf;
	
	If Parameters.Property("DiscountCard") Then
		DiscountCard = Parameters.DiscountCard;
		DiscountCardOnOpen = Parameters.DiscountCard;
		DiscountCardHasAttribute = True;
		If Parameters.Property("Counterparty") Then
			Counterparty = Parameters.Counterparty;
		EndIf;
		Items.DiscountCard.Visible = True;
		DiscountCardHasAttribute = True;
	Else
		Items.DiscountCard.Visible = False;
		DiscountCardHasAttribute = False;
	EndIf;
	
	If Parameters.Property("DocumentCurrency") Then
		
		DocumentCurrency = Parameters.DocumentCurrency;
		DocumentCurrencyOnOpen = Parameters.DocumentCurrency;
		DocumentCurrencyIsAttribute = True;
		
		If Parameters.Property("ExchangeRate") And Parameters.Property("Multiplicity") Then
			
			ExchangeRate = Parameters.ExchangeRate;
			Multiplicity = Parameters.Multiplicity;
			ExchangeRateAndMultiplicityAreAttributes = True;
			
			If DocumentCurrency = PresentationCurrency Then
				Items.ExchangeRate.ReadOnly = True;
				Items.Multiplicity.ReadOnly = True;
			EndIf;
			
		Else
			Items.ExchangeRate.Visible = False;
			Items.Multiplicity.Visible = False;
			ExchangeRateAndMultiplicityAreAttributes = False;
		EndIf;
		
		ExchangeRateOnOpen = ExchangeRate;
		MultiplicityOnOpen = Multiplicity;
		
	Else
		Items.DocumentCurrency.Visible = False;
		Items.ExchangeRate.Visible = False;
		Items.Multiplicity.Visible = False;
		Items.RecalculatePrices.Visible = False;
		DocumentCurrencyIsAttribute = False;
		ExchangeRateAndMultiplicityAreAttributes = False;
	EndIf;
	
	If Parameters.Property("VATTaxation") Then
		
		VATTaxation				= Parameters.VATTaxation;
		VATTaxationOnOpen		= Parameters.VATTaxation;
		VATTaxationIsAttribute	= True;
		
		ReverseChargeNotApplicable = Parameters.Property("ReverseChargeNotApplicable") And Parameters.ReverseChargeNotApplicable;
		
		ReverseChargeVATIsCalculated = Parameters.Property("ReverseChargeVATIsCalculated") And Parameters.ReverseChargeVATIsCalculated;
		
		AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocDate, Company);
		
		Items.VATTaxation.ListChoiceMode = True;
		VATTaxationChoiceList = Items.VATTaxation.ChoiceList;
		VATTaxationChoiceList.Clear();
		
		For Each VATTaxationType In Enums.VATTaxationTypes Do
			If WorkWithVAT.VATTaxationTypeIsValid(VATTaxationType, AccountingPolicy.RegisteredForVAT, ReverseChargeNotApplicable) Then
				VATTaxationChoiceList.Add(VATTaxationType);
			EndIf;
		EndDo;
		
		If Parameters.Property("VATTaxationReadOnly") Then
			Items.VATTaxation.ReadOnly = True;
		EndIf;
		
	Else
		
		Items.VATTaxation.Visible	= False;
		VATTaxationIsAttribute		= False;
		
	EndIf;
	
	If Parameters.Property("SalesTaxRate") Then
		
		SalesTaxRate = Parameters.SalesTaxRate;
		SalesTaxRateOnOpen = Parameters.SalesTaxRate;
		SalesTaxRateIsAttribute = True;
		
	Else
		
		Items.SalesTaxRate.Visible = False;
		SalesTaxRateIsAttribute = False;
		
	EndIf;
	
	If Parameters.Property("SalesTaxPercentage") Then
		
		SalesTaxPercentageOnOpen = Parameters.SalesTaxPercentage;
		SalesTaxPercentage = Parameters.SalesTaxPercentage;
		SalesTaxPercentageIsAttribute = True;
		
	Else
		
		SalesTaxPercentageIsAttribute = False;
		SetVisibleSalesTaxPercentage();
		
	EndIf;
	
	If Parameters.Property("AmountIncludesVAT") Then
		AmountIncludesVAT = Parameters.AmountIncludesVAT;
		AmountIncludesVATOnOpen = Parameters.AmountIncludesVAT;
		AmountIncludesVATIsAttribute = True;
	Else
		AmountIncludesVATIsAttribute = False;
	EndIf;
	
	If Parameters.Property("AutomaticVATCalculation")
		And Parameters.Property("PerInvoiceVATRoundingRule")
		And Parameters.PerInvoiceVATRoundingRule Then
		AutomaticVATCalculation = Parameters.AutomaticVATCalculation;
		AutomaticVATCalculationOnOpen = Parameters.AutomaticVATCalculation;
		AutomaticVATCalculationIsAttribute = True;
		
	Else
		AutomaticVATCalculationIsAttribute = False;
	EndIf;
	
	If Parameters.Property("IncludeVATInPrice") Then
		IncludeVATInPrice = Parameters.IncludeVATInPrice;
		IncludeVATInPriceOnOpen = Parameters.IncludeVATInPrice;
		IncludeVATInPriceIsAttribute = True;
	Else
		IncludeVATInPriceIsAttribute = False;
	EndIf;
	
	VATInclusionAttributesVisibility();
	
	If Parameters.Property("Contract") Then
		
		If ValueIsFilled(Parameters.Contract) Then
			SettlementsCurrency = Common.ObjectAttributeValue(Parameters.Contract, "SettlementsCurrency");
		EndIf;
		SettlementsRate = Parameters.ContractCurrencyExchangeRate;
		SettlementsMultiplicity = Parameters.ContractCurrencyMultiplicity;
		
		SettlementsCurrencyRateOnOpen = SettlementsRate;
		SettlementsMultiplicityOnOpen = SettlementsMultiplicity;
		
		ContractIsAttribute = True;
		
		If SettlementsCurrency = PresentationCurrency Then
			Items.SettlementsRate.ReadOnly = True;
			Items.SettlementsMultiplicity.ReadOnly = True;
		EndIf;
		
	Else
		
		Items.SettlementsCurrency.Visible = False;
		Items.SettlementsRate.Visible = False;
		Items.SettlementsMultiplicity.Visible = False;
		
		ContractIsAttribute = False;
		
	EndIf;
	
	RecalculatePrices = Parameters.RecalculatePrices;
	
	If Parameters.Property("OperationKind")
		And (Parameters.OperationKind = Enums.OperationTypesSupplierInvoice.ZeroInvoice
		Or Parameters.OperationKind = Enums.OperationTypesSalesInvoice.ZeroInvoice) Then
		
		RefillPrices = False;
		Items.RefillPrices.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the exchange rates table
//
Procedure FillExchangeRateTable()
	
	Query = New Query;
	Query.SetParameter("DocumentDate", Parameters.DocumentDate);
	Query.SetParameter("Company", Company);
	Query.Text = 
	"SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, Company = &Company) AS ExchangeRateSliceLast";
	
	QueryResultTable = Query.Execute().Unload();
	ExchangeRates.Load(QueryResultTable);
	
EndProcedure

&AtClient
// Procedure checks the correctness of the form attributes filling.
//
Procedure CheckFillOfFormAttributes(Cancel, OnlyPriceKindIsNotFilled = False)
    	
	// Attributes filling check.
	
	// DiscountCards
	OnlyPriceKindIsNotFilled = True;
	// End DiscountCards
	
	// Kind of counterparty prices.
	If (RefillPrices OR RegisterVendorPrices) AND PriceKindCounterpartyIsAttribute Then
		If Not ValueIsFilled(SupplierPriceTypes) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Select the supplier price type to renew the purchase prices.'; ru = 'Чтобы обновить цены закупки, обновите тип цен поставщика.';pl = 'Wybierz rodzaj ceny dostawcy, aby odnowić ceny zakupu.';es_ES = 'Seleccionar el tipo de precio del proveedor para renovar los precios de compra.';es_CO = 'Seleccionar el tipo de precio del proveedor para renovar los precios de compra.';tr = 'Satın alma fiyatlarını yenilemek için tedarikçi fiyat türünü seçin.';it = 'Selezionare il tipo prezzo fornitore per aggiornare il prezzo di acquisto.';de = 'Wählen Sie den Preistyp des Lieferanten, um die Einkaufspreise zu erneuern.'"),,
				"SupplierPriceTypes",,
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
    	EndIf;
	EndIf;
	
	// Document currency.
	If DocumentCurrencyIsAttribute Then
		If Not ValueIsFilled(DocumentCurrency) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Select the transaction currency.'; ru = 'Выберите валюту операции';pl = 'Wybierz walutę transakcji.';es_ES = 'Seleccionar la moneda de transacción.';es_CO = 'Seleccionar la moneda de transacción.';tr = 'İşlem para birimini seçin.';it = 'Selezionare la valuta di transazione.';de = 'Wählen Sie die Transaktionswährung aus.'"),,
				"DocumentCurrency",,
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
		EndIf;
		
		If ExchangeRateAndMultiplicityAreAttributes Then
			If Not ValueIsFilled(ExchangeRate) Then
				CommonClientServer.MessageToUser(
					NStr("en = 'Exchange rate is required.'; ru = 'Укажите курс валюты.';pl = 'Wymagany jest kurs waluty.';es_ES = 'Se requiere un tipo de cambio.';es_CO = 'Se requiere un tipo de cambio.';tr = 'Döviz kuru gerekli.';it = 'Tasso di cambio richiesto.';de = 'Wechselkurs ist erforderlich.'"),,
					"ExchangeRate",, 
					Cancel);
					
				OnlyPriceKindIsNotFilled = False; // DiscountCards
			EndIf;
			If Not ValueIsFilled(Multiplicity) Then
				CommonClientServer.MessageToUser(
					NStr("en = 'Multiplier is required.'; ru = 'Укажите кратность.';pl = 'Wymagany jest mnożnik.';es_ES = 'Se requiere un multiplicador.';es_CO = 'Se requiere un multiplicador.';tr = 'Çarpan gerekli.';it = 'Moltiplicatore richiesto';de = 'Multiplikator ist erforderlich.'"),,
					"Multiplicity",,
					Cancel);
					
				OnlyPriceKindIsNotFilled = False; // DiscountCards
			EndIf;
		EndIf;
		
	EndIf;
	
	// VAT taxation.
	If VATTaxationIsAttribute Then
		If Not ValueIsFilled(VATTaxation) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Select a tax category.'; ru = 'Укажите вид налогообложения.';pl = 'Wybierz rodzaj opodatkowania VAT.';es_ES = 'Seleccionar la categoría fiscal.';es_CO = 'Seleccionar la categoría fiscal.';tr = 'Vergi kategorisi seçin.';it = 'Selezionare un categoria di imposta.';de = 'Wählen Sie eine Steuerkategorie aus.'"),,
				"VATTaxation",, 
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
   		EndIf;
	EndIf;
	
	// Calculations.
	If ContractIsAttribute Then
		If Not ValueIsFilled(SettlementsRate) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Exchange rate is required.'; ru = 'Укажите курс валюты.';pl = 'Wymagany jest kurs waluty.';es_ES = 'Se requiere un tipo de cambio.';es_CO = 'Se requiere un tipo de cambio.';tr = 'Döviz kuru gerekli.';it = 'Tasso di cambio richiesto.';de = 'Wechselkurs ist erforderlich.'"),,
				"SettlementsRate",, 
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
		EndIf;
		
		If Not ValueIsFilled(SettlementsMultiplicity) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Multiplier is required.'; ru = 'Укажите кратность.';pl = 'Wymagany jest mnożnik.';es_ES = 'Se requiere un multiplicador.';es_CO = 'Se requiere un multiplicador.';tr = 'Çarpan gerekli.';it = 'Moltiplicatore richiesto';de = 'Multiplikator ist erforderlich.'"),,
				"SettlementsMultiplicity",,
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
		EndIf;
	EndIf;
	
	// Prices kind.
	If RefillPrices AND PriceKindIsAttribute Then
		If Not ValueIsFilled(PriceKind) Then
			
			If DiscountKind.IsEmpty() AND Not DiscountCard.IsEmpty() AND OnlyPriceKindIsNotFilled Then // DiscountCards
				// You can recalculate the discounts on the discount card in the document.
			Else
				CommonClientServer.MessageToUser(
					NStr("en = 'Select a price type.'; ru = 'Укажите тип цен.';pl = 'Określ rodzaj ceny.';es_ES = 'Seleccionar un tipo de precio.';es_CO = 'Seleccionar un tipo de precio.';tr = 'Fiyat türü seçin.';it = 'Specificare un tipo di prezzo.';de = 'Wählen Sie einen Preistyp aus.'"),,
					"PriceKind");
					
				OnlyPriceKindIsNotFilled = False;
			EndIf;
			
			Cancel = True;
    	EndIf;
	EndIf;
	
	// Sales tax.
	If SalesTaxRateIsAttribute Then
		If Not ValueIsFilled(SalesTaxRate) Then
			
			CommonClientServer.MessageToUser(
				NStr("en = 'Select a sales tax rate.'; ru = 'Выберите ставку налога с продаж.';pl = 'Wybierz stawkę podatku od sprzedaży.';es_ES = 'Seleccione una tasa de impuesto sobre ventas.';es_CO = 'Seleccione una tasa de impuesto sobre ventas.';tr = 'Satış vergisi oranı seçin.';it = 'Selezionare una aliquota fiscale di vendita.';de = 'Umsatzsteuersatz auswählen.'"),
				,
				"SalesTaxRate",
				,
				Cancel);
			
			OnlyPriceKindIsNotFilled = False; // DiscountCards
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks if the form was modified.
//
Procedure CheckIfFormWasModified()

	WereMadeChanges = False;
	
	ChangesPriceKind				= ?(PriceKindIsAttribute, PriceKindOnOpen <> PriceKind, False);
	ChangesSupplierPriceTypes		= ?(PriceKindCounterpartyIsAttribute, PriceKindCounterpartyOnOpen <> SupplierPriceTypes, False);
	ChangesToRegisterVendorPrices	= ?(RegisterVendorPricesIsAttribute, RegisterVendorPricesOnOpen <> RegisterVendorPrices, False);
	ChangesDiscountKind				= ?(DiscountKindIsAttribute, DiscountKindOnOpen <> DiscountKind, False);
	ChangesSupplierDiscountKind		= ?(SupplierDiscountKindIsAttribute, SupplierDiscountKindOnOpen <> SupplierDiscountKind, False);
	ChangesDocumentCurrency			= ?(DocumentCurrencyIsAttribute, DocumentCurrencyOnOpen <> DocumentCurrency, False);
	ChangesExchangeRate				= ?(DocumentCurrencyIsAttribute And ExchangeRateAndMultiplicityAreAttributes,
											ExchangeRateOnOpen <> ExchangeRate, False);
	ChangesMultiplicity				= ?(DocumentCurrencyIsAttribute And ExchangeRateAndMultiplicityAreAttributes,
											MultiplicityOnOpen <> Multiplicity, False);
	ChangesVATTaxation				= ?(VATTaxationIsAttribute, VATTaxationOnOpen <> VATTaxation, False);
	ChangesAmountIncludesVAT 		= ?(AmountIncludesVATIsAttribute, AmountIncludesVATOnOpen <> AmountIncludesVAT, False);
	ChangesAutomaticVATCalculation	= ?(AutomaticVATCalculationIsAttribute, AutomaticVATCalculationOnOpen <> AutomaticVATCalculation, False);
	ChangesIncludeVATInPrice		= ?(IncludeVATInPriceIsAttribute, IncludeVATInPriceOnOpen <> IncludeVATInPrice, False);
	ChangesSettlementsRate			= ?(ContractIsAttribute, SettlementsCurrencyRateOnOpen <> SettlementsRate, False);
	ChangesSettlementsRates			= ?(ContractIsAttribute, SettlementsMultiplicityOnOpen <> SettlementsMultiplicity, False);
	ChangesDiscountCard				= ?(DiscountCardHasAttribute, DiscountCardOnOpen <> DiscountCard, False);
	ChangesSalesTaxRate				= ?(SalesTaxRateIsAttribute, SalesTaxRateOnOpen <> SalesTaxRate, False);
	ChangesSalesTaxPercentage		= ?(SalesTaxPercentageIsAttribute, SalesTaxPercentageOnOpen <> SalesTaxPercentage, False);
	
	If RefillPrices
		Or RecalculatePrices
		Or ChangesDocumentCurrency
		Or ChangesExchangeRate
		Or ChangesMultiplicity
		Or ChangesVATTaxation
		Or ChangesAmountIncludesVAT
		Or ChangesAutomaticVATCalculation
		Or ChangesIncludeVATInPrice
		Or ChangesSettlementsRate
		Or ChangesSettlementsRates
		Or ChangesPriceKind
		Or ChangesSupplierPriceTypes
		Or ChangesToRegisterVendorPrices
		Or ChangesDiscountCard
		Or ChangesDiscountKind 
		Or ChangesSupplierDiscountKind
		Or ChangesSalesTaxRate
		Or ChangesSalesTaxPercentage Then
		
		WereMadeChanges = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure VATInclusionAttributesVisibility()
	
	TaxationVisibilityComponent = VATTaxationIsAttribute And VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
	
	Items.AmountIncludesVAT.Visible = AmountIncludesVATIsAttribute And TaxationVisibilityComponent;
	Items.IncludeVATInPrice.Visible = IncludeVATInPriceIsAttribute And TaxationVisibilityComponent;
	
	Items.AutomaticVATCalculation.Visible = AutomaticVATCalculationIsAttribute And VATTaxationIsAttribute
		And (VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
			Or VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT And ReverseChargeVATIsCalculated);
	
EndProcedure

&AtServerNoContext
Function GetAmountIncludesVAT(PriceKind)
	Return Common.ObjectAttributeValue(PriceKind, "PriceIncludesVAT");
EndFunction

&AtServerNoContext
Function GetSalesTaxPercentage(SalesTaxRate)
	
	Return Common.ObjectAttributeValue(SalesTaxRate, "Rate");
	
EndFunction

#Region DiscountCards

// Function returns the discount card holder.
//
&AtServerNoContext
Function GetCardHolder(DiscountCard)

	Return DiscountCard.CardOwner;

EndFunction

#EndRegion

&AtServer
Procedure SetVisibleSalesTaxPercentage()
	
	If SalesTaxRateIsAttribute And SalesTaxPercentageIsAttribute Then
		Items.SalesTaxPercentage.Visible = True;
		Combined = ?(ValueIsFilled(SalesTaxRate), Common.ObjectAttributeValue(SalesTaxRate, "Combined"), False);
		Items.SalesTaxPercentage.Enabled = Not Combined;
	Else
		Items.SalesTaxPercentage.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInCurrencyRateChoiceList(CurRateItemName, Currency)
	
	FillParameters = New Structure;
	FillParameters.Insert("Currency", 				Currency);
	FillParameters.Insert("PresentationCurrency", 	PresentationCurrency);
	FillParameters.Insert("DocumentDate", 			DocumentDate);
	FillParameters.Insert("Company", 				Company);
	
	DriveClientServer.FillInCurrencyRateChoiceList(ThisForm, CurRateItemName, FillParameters);
	
EndProcedure

&AtClient
Procedure SetRateAndMultiplicity(SetSettlements = True)
	
	If DocumentCurrency = SettlementsCurrency Then
		
		If SetSettlements Then
			SettlementsRate = ExchangeRate;
			SettlementsMultiplicity = Multiplicity;
		Else
			ExchangeRate = SettlementsRate;
			Multiplicity = SettlementsMultiplicity;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetFormValuesOfParameters();
	FillExchangeRateTable();
	
	Parameters.Property("WarningText", WarningText);
	If IsBlankString(WarningText) Then
		
		CommonClientServer.SetFormItemProperty(Items, "WarningGroup", "Visible", False);
		
	EndIf;
	Items.Warning.Title = WarningText;
	
	// DiscountCards
	Parameters.Property("DocumentDate", DocumentDate);
	ConfigureLabelOnDiscountCard();
	
	SetVisibleSalesTaxPercentage();
	
	FillInCurrencyRateChoiceList("SettlementsRate", SettlementsCurrency);
	FillInCurrencyRateChoiceList("ExchangeRate", DocumentCurrency);
	
EndProcedure

#EndRegion

#Region ActionsOfTheFormCommandPanels

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure CommandOK(Command)
	
	Cancel = False;
	OnlyPriceKindIsNotFilledAndCardIsFilled = False; // DiscountCards
	
	CheckFillOfFormAttributes(Cancel, OnlyPriceKindIsNotFilledAndCardIsFilled);
	CheckIfFormWasModified();
	
	If Not Cancel OR OnlyPriceKindIsNotFilledAndCardIsFilled Then
		
		StructureOfFormAttributes = New Structure;
		
		StructureOfFormAttributes.Insert("WereMadeChanges", 		WereMadeChanges);
		
		StructureOfFormAttributes.Insert("PriceKind", 				PriceKind);
		StructureOfFormAttributes.Insert("SupplierPriceTypes", 		SupplierPriceTypes);
		StructureOfFormAttributes.Insert("RegisterVendorPrices", 	RegisterVendorPrices);
		StructureOfFormAttributes.Insert("DiscountKind",  			DiscountKind);
		StructureOfFormAttributes.Insert("SupplierDiscountKind",	SupplierDiscountKind);
		
		StructureOfFormAttributes.Insert("DocumentCurrency", 		DocumentCurrency);
		StructureOfFormAttributes.Insert("ExchangeRate", 			ExchangeRate);
		StructureOfFormAttributes.Insert("Multiplicity", 			Multiplicity);
		
		StructureOfFormAttributes.Insert("VATTaxation",				VATTaxation);
		StructureOfFormAttributes.Insert("AmountIncludesVAT", 		AmountIncludesVAT);
		StructureOfFormAttributes.Insert("AutomaticVATCalculation",	AutomaticVATCalculation);
		StructureOfFormAttributes.Insert("IncludeVATInPrice", 		IncludeVATInPrice);
		
		StructureOfFormAttributes.Insert("SettlementsCurrency", 	SettlementsCurrency);
		StructureOfFormAttributes.Insert("SettlementsRate", 		SettlementsRate);
		StructureOfFormAttributes.Insert("SettlementsMultiplicity",	SettlementsMultiplicity);
		
		StructureOfFormAttributes.Insert("PrevCurrencyOfDocument", 	DocumentCurrencyOnOpen);
		StructureOfFormAttributes.Insert("PrevVATTaxation", 		VATTaxationOnOpen);
		StructureOfFormAttributes.Insert("PrevAmountIncludesVAT", 	AmountIncludesVATOnOpen);
		
		StructureOfFormAttributes.Insert("RefillPrices", 			RefillPrices AND Not Cancel);
		StructureOfFormAttributes.Insert("RecalculatePrices", 		RecalculatePrices);
		
		StructureOfFormAttributes.Insert("RefillDiscounts",					RefillPrices AND OnlyPriceKindIsNotFilledAndCardIsFilled);
		StructureOfFormAttributes.Insert("DiscountCard",  					DiscountCard);
		StructureOfFormAttributes.Insert("DiscountPercentByDiscountCard",	DiscountPercentByDiscountCard);
		StructureOfFormAttributes.Insert("Counterparty",					GetCardHolder(DiscountCard));
		
		StructureOfFormAttributes.Insert("SalesTaxRate",			SalesTaxRate);
		StructureOfFormAttributes.Insert("SalesTaxPercentage",		SalesTaxPercentage);
		StructureOfFormAttributes.Insert("PrevSalesTaxRate",		SalesTaxRateOnOpen);
		StructureOfFormAttributes.Insert("PrevSalesTaxPercentage",	SalesTaxPercentageOnOpen);
		
		Close(StructureOfFormAttributes);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange of the PriceKind input field.
//
Procedure PriceKindOnChange(Item)
	
	If ValueIsFilled(PriceKind) Then
                        
        If PriceKindOnOpen <> PriceKind Then
			
			RefillPrices = True;

		EndIf;
		
		AmountIncludesVAT = GetAmountIncludesVAT(PriceKind);
        
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler of the StartChoice item of the SupplierPriceTypes form.
//
Procedure SupplierPriceTypesStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyDescription = New NotifyDescription("SupplierPriceTypesSelectionFormEnd", ThisObject); 
	OpenForm(
		"Catalog.SupplierPriceTypes.ChoiceForm", 
		New Structure("Counterparty", Counterparty), 
		SupplierPriceTypes, 
		UUID, ,	,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure is called after selection of price types from the form catalog selection SupplierPriceTypes.
//
&AtClient
Procedure SupplierPriceTypesSelectionFormEnd(ClosingResult, AdditionalParameters) Export

	If ValueIsFilled(ClosingResult) Then 
		SupplierPriceTypes = ClosingResult;
		
		If PriceKindCounterpartyOnOpen <> SupplierPriceTypes Then
			
			RefillPrices = True;

		EndIf;
		
		AmountIncludesVAT = GetAmountIncludesVAT(SupplierPriceTypes);
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierDiscountKindOnChange(Item)
	
	If SupplierDiscountKindOnOpen <> SupplierDiscountKind Then
		RefillPrices = True;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the DiscountKind input field.
//
Procedure DiscountKindOnChange(Item)
	
	If DiscountKindOnOpen <> DiscountKind Then
		RefillPrices = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure CurrencyOnChange(Item)
	
	If ValueIsFilled(DocumentCurrency) Then
		
		ArrayExchangeRateMultiplicity = ExchangeRates.FindRows(New Structure("Currency", DocumentCurrency));
		
		If ArrayExchangeRateMultiplicity.Count() Then
			ExchangeRate = ArrayExchangeRateMultiplicity[0].ExchangeRate;
			Multiplicity = ArrayExchangeRateMultiplicity[0].Multiplicity;
		Else
			ExchangeRate = 0;
			Multiplicity = 0;
		EndIf;
		
		SetRateAndMultiplicity();
		
		FillInCurrencyRateChoiceList("ExchangeRate", DocumentCurrency);
		
		If DocumentCurrencyOnOpen <> DocumentCurrency Then
			RecalculatePrices = True;
		EndIf;
		
		If DocumentCurrency = PresentationCurrency Then
			Items.ExchangeRate.ReadOnly = True;
			Items.Multiplicity.ReadOnly = True;
		Else
			Items.ExchangeRate.ReadOnly = False;
			Items.Multiplicity.ReadOnly = False;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeRateOnChange(Item)
	SetRateAndMultiplicity();
EndProcedure

&AtClient
Procedure MultiplicityOnChange(Item)
	SetRateAndMultiplicity();
EndProcedure

&AtClient
Procedure SettlementsRateOnChange(Item)
	SetRateAndMultiplicity(False);
EndProcedure

&AtClient
Procedure SettlementsMultiplicityOnChange(Item)
	SetRateAndMultiplicity(False);
EndProcedure

&AtClient
// Procedure - event handler OnChange of the RefillPrices input field.
//
Procedure RefillPricesOnChange(Item)
	
	If PriceKindIsAttribute Then
		
		If RefillPrices Then
			If DiscountKind.IsEmpty() AND Not DiscountCard.IsEmpty() Then // DiscountCards
				Items.PriceKind.AutoMarkIncomplete = False;
			Else
				Items.PriceKind.AutoMarkIncomplete = True;
			EndIf;
		Else	
			Items.PriceKind.AutoMarkIncomplete = False;
			ClearMarkIncomplete();
		EndIf;		
	
	ElsIf PriceKindCounterpartyIsAttribute Then
		
		If RefillPrices OR RegisterVendorPrices Then
			Items.SupplierPriceTypes.AutoMarkIncomplete = True;
		Else	
			Items.SupplierPriceTypes.AutoMarkIncomplete = False;
			ClearMarkIncomplete();
		EndIf;		
	
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the RegisterVendorPrices input field.
//
Procedure RegisterVendorPricesOnChange(Item)
	
	If RegisterVendorPrices OR RefillPrices Then
		Items.SupplierPriceTypes.AutoMarkIncomplete = True;
	Else	
		Items.SupplierPriceTypes.AutoMarkIncomplete = False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
Procedure VATTaxationOnChange(Item)
	VATInclusionAttributesVisibility();
EndProcedure

&AtClient
Procedure SalesTaxRateOnChange(Item)
	
	SalesTaxPercentage = GetSalesTaxPercentage(SalesTaxRate);
	
	SetVisibleSalesTaxPercentage();
	
EndProcedure

#Region DiscountCards

// Procedure - event handler of the StartChoice item of the DiscountCard form.
//
&AtClient
Procedure DiscountCardStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyDescription = New NotifyDescription("OpenDiscountCardSelectionFormEnd", ThisObject); //, New Structure("Filter", FilterStructure));
	OpenForm("Catalog.DiscountCards.ChoiceForm", New Structure("Counterparty", Counterparty), DiscountCard, UUID, , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure is called after selection of the discount card from the form catalog selection DiscountCards.
//
&AtClient
Procedure OpenDiscountCardSelectionFormEnd(ClosingResult, AdditionalParameters) Export

	If ValueIsFilled(ClosingResult) Then 
		DiscountCard = ClosingResult;
	
		If DiscountCardOnOpen <> DiscountCard Then
			
			RefillPrices = True;
			
		EndIf;
	EndIf;

	// The % of the progressive discount could have been changed, so refresh the label, even if the discount card is not changed.
	ConfigureLabelOnDiscountCard();
	
EndProcedure

// Procedure - event handler of the OnChange item of the DiscountCard form.
//
&AtClient
Procedure DiscountCardOnChange(Item)
	
	If DiscountCardOnOpen <> DiscountCard Then
		
		RefillPrices = True;
		
	EndIf;
	
	// The % of the progressive discount could have been changed, so refresh the label, even if the discount card is not changed.
	ConfigureLabelOnDiscountCard();
	
	RefillPricesOnChange(Items.RefillPrices);
	
EndProcedure

// Procedure fills the discount card tooltip with the information about the discount on the discount card.
//
&AtServer
Procedure ConfigureLabelOnDiscountCard()
	
	If Not DiscountCard.IsEmpty() Then
		If Not Counterparty.IsEmpty() AND DiscountCard.Owner.ThisIsMembershipCard AND DiscountCard.CardOwner <> Counterparty Then
			
			DiscountCard = Catalogs.DiscountCards.EmptyRef();
			
			Message = New UserMessage;
			Message.Text = "Discount card owner does not match with a counterparty in the document.";
			Message.Field = "DiscountCard";
			Message.Message();
			
		EndIf;
	EndIf;
	
	If DiscountCard.IsEmpty() Then
		DiscountPercentByDiscountCard = 0;
		Items.DiscountCard.ToolTip = "";
	Else
		DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(DocumentDate, DiscountCard);
		Items.DiscountCard.ToolTip = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Discount by the card is %1%'; ru = 'Скидка по карте составляет %1%';pl = 'Rabat przy użyciu karty wynosi %1%';es_ES = 'Descuento por la tarjeta es %1%';es_CO = 'Descuento por la tarjeta es %1%';tr = 'Kart indirimi %%1';it = 'Sconto dalla scheda è %1%';de = 'Rabatt von der Karte ist %1%'"), DiscountPercentByDiscountCard);
		
	EndIf;
	
EndProcedure

#EndRegion

&AtClient
Procedure SelectExchangeRateDateEnd(Result, ChoiceContext) Export
	
	If Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	ThisObject[ChoiceContext.AttributeName] = Result;
	SetRateAndMultiplicity(ChoiceContext.SetSettlements);
	
EndProcedure

&AtClient
Procedure ExchangeRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	CommonChoiceProcessing(SelectedValue, "ExchangeRate", DocumentCurrency, StandardProcessing, True);
	
EndProcedure

&AtClient
Procedure SettlementsRateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	CommonChoiceProcessing(SelectedValue, "SettlementsRate", SettlementsCurrency, StandardProcessing, False);
	
EndProcedure

&AtClient
Procedure CommonChoiceProcessing(SelectedValue, AttributeName, Currency, StandardProcessing, SetSettlements)
	
	StandardProcessing = False;
	
	ChoiceContext = New Structure;
	ChoiceContext.Insert("AttributeName", AttributeName);
	ChoiceContext.Insert("SetSettlements", SetSettlements);
	
	NotifyDescription = New NotifyDescription("SelectExchangeRateDateEnd", ThisForm, ChoiceContext);
	
	If SelectedValue = 0 Then
		
		ExchangeRateFormParameters = DriveClient.GetSelectExchangeRateDateParameters();
		ExchangeRateFormParameters.Company 					= Company;
		ExchangeRateFormParameters.Currency 				= Currency;
		ExchangeRateFormParameters.ExchangeRateMethod 		= ExchangeRateMethod;
		ExchangeRateFormParameters.PresentationCurrency 	= PresentationCurrency;
		ExchangeRateFormParameters.RateDate 				= DocumentDate;
		
		DriveClient.OpenSelectExchangeRateDateForm(ExchangeRateFormParameters, ThisForm, NotifyDescription);
		
	Else
		
		ExecuteNotifyProcessing(NotifyDescription, SelectedValue);
		
	EndIf;
	
EndProcedure

#EndRegion
