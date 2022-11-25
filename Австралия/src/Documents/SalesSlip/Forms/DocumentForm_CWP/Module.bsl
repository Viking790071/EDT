#Region Variables

&AtClient
Var Displays;

#EndRegion

#Region CommonProceduresAndFunctions

// Procedure initializes new receipt parameters.
//
&AtServer
Procedure InitializeNewReceipt()
	
	Try
		UnlockDataForEdit(Object.Ref, UUID);
	Except
		//
	EndTry;
	
	NewReceipt = Documents.SalesSlip.CreateDocument();
	
	FillPropertyValues(NewReceipt, Object,, "Inventory, PaymentWithPaymentCards, DiscountsMarkups, Number");
	
	ValueToFormData(NewReceipt, Object);
	
	Object.DocumentAmount = 0;
	
	Object.DiscountMarkupKind = Undefined;
	Object.DiscountCard = Undefined;
	Object.DiscountPercentByDiscountCard = 0;
	Object.DiscountsAreCalculated = False;
	DiscountAmount = 0;
	
	Object.CashReceived = 0;
	ReceivedPaymentCards = 0;
	
	AmountReceiptWithoutDiscounts = 0;
	AmountShortChange = 0;
	
	Object.Inventory.Clear();
	Object.PaymentWithPaymentCards.Clear();
	Object.DiscountsMarkups.Clear();
	
	Object.SalesSlipNumber = "";
	Object.Archival = False;
	Object.Status = Enums.SalesSlipStatus.ReceiptIsNotIssued;
	
	InstalledGrayColor = True;
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
	
EndProcedure

// Fills amount discounts at client.
//
&AtClient
Procedure FillAmountsDiscounts()
	
	For Each CurRow In Object.Inventory Do
		AmountWithoutDiscount = CurRow.Price * CurRow.Quantity;
		TotalDiscount = AmountWithoutDiscount - CurRow.Amount;
		ManualDiscountAmountMarkups = ?((TotalDiscount - CurRow.AutomaticDiscountAmount) > 0, TotalDiscount - CurRow.AutomaticDiscountAmount, 0);
		
		CurRow.DiscountAmount = TotalDiscount;
		CurRow.AmountDiscountsMarkups = ManualDiscountAmountMarkups;
	EndDo;
	
EndProcedure

// Procedure recalculates the document on client.
//
&AtClient
Procedure RecalculateDocumentAtClient()
	
	Object.DocumentAmount = Object.Inventory.Total("Total");
	
	Paid = Object.CashReceived + Object.PaymentWithPaymentCards.Total("Amount");
	AmountShortChange = ?(Paid = 0, 0, Paid - Object.DocumentAmount);
	
	DiscountAmount = Object.Inventory.Total("DiscountAmount");
	AmountReceiptWithoutDiscounts = Object.DocumentAmount + DiscountAmount;
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount") + Object.Inventory.Total("DiscountAmount");
	
	DisplayInformationOnCustomerDisplay();
	
EndProcedure

// The procedure fills out a list of payment card kinds.
//
&AtServer
Procedure GetChoiceListOfPaymentCardKinds()
	
	ArrayTypesOfPaymentCards = Catalogs.POSTerminals.PaymentCardKinds(Object.POSTerminal);
	
	Items.PaymentByChargeCardTypeCards.ChoiceList.LoadValues(ArrayTypesOfPaymentCards);
	
EndProcedure

// Gets references to external equipment.
//
&AtServer
Procedure GetRefsToEquipment()

	FiscalRegister = ?(
		UsePeripherals // Check for the included FO "Use Peripherals"
	  AND ValueIsFilled(Object.CashCR)
	  AND ValueIsFilled(Object.CashCR.Peripherals),
	  Object.CashCR.Peripherals.Ref,
	  Catalogs.Peripherals.EmptyRef()
	);

	POSTerminal = ?(
		UsePeripherals
	  AND ValueIsFilled(Object.POSTerminal)
	  AND ValueIsFilled(Object.POSTerminal.Peripherals)
	  AND Not Object.POSTerminal.UseWithoutEquipmentConnection,
	  Object.POSTerminal.Peripherals,
	  Catalogs.Peripherals.EmptyRef()
	);

EndProcedure

// Procedure fills the VAT rate in the tabular section according to company's taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(
				Object.AmountIncludesVAT,
				TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
				TabularSectionRow.Amount * VATRate / 100
			);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, 
		"MeasurementUnit, VATRate, Description, DescriptionFull, SKU");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	
	StructureData.Insert(
		"Content",
		DriveServer.GetProductsPresentationForPrinting(
			?(ValueIsFilled(ProductsAttributes.DescriptionFull),
			ProductsAttributes.DescriptionFull, ProductsAttributes.Description),
			StructureData.Characteristic, ProductsAttributes.SKU));
	
	If StructureData.Property("VATTaxation") 
		And Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products) And ValueIsFilled(ProductsAttributes.VATRate) Then
		StructureData.Insert("VATRate", ProductsAttributes.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind") 
		And ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert(
			"DiscountMarkupPercent", Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		And ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData, True);
	// End Bundles
	
	Return StructureData;
	
EndFunction

// Procedure fills data when Products change.
//
&AtClient
Procedure ProductsOnChange(TabularSectionRow)
	
	StructureData = New Structure();
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard",  Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	AddIncomeAndExpenseItemsToStructure(ThisObject, "Inventory", StructureData, TabularSectionRow);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData, TabularSectionRow);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	TabularSectionRow.Quantity = 1;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("PriceKind") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData, True);
	// End Bundles
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

// VAT amount is calculated in the row of a tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.Amount
	  - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
	  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure

// Procedure calculates the amount in the row of a tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, SetDescription = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	AmountBeforeCalculation = TabularSectionRow.Amount;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
		    AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	TabularSectionRow.DiscountAmount = AmountBeforeCalculation - TabularSectionRow.Amount;
	TabularSectionRow.AmountDiscountsMarkups = TabularSectionRow.DiscountAmount;
	
	// AutomaticDiscounts.
	RecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	
	// If picture was changed that focus goes from TS and procedure RecalculateDocumentAtClient() is not called.
	If RecalculationIsRequired Then
		RecalculateDocumentAtClient();
		DocumentConvertedAtClient = True;
	Else
		DocumentConvertedAtClient = False;
	EndIf;
	// End AutomaticDiscounts

	// CWP
	If SetDescription Then
		SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	EndIf;
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

// Procedure calculates discount % in tabular section string.
//
&AtClient
Procedure CalculateDiscountPercent(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// AutomaticDiscounts.
	RecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateDiscountPercent");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	
	// If picture was changed that focus goes from TS and procedure RecalculateDocumentAtClient() is not called.
	If RecalculationIsRequired Then
		RecalculateDocumentAtClient();
		DocumentConvertedAtClient = True;
	Else
		DocumentConvertedAtClient = False;
	EndIf;
	// End AutomaticDiscounts
	
	If TabularSectionRow.Quantity * TabularSectionRow.Price < TabularSectionRow.DiscountAmount Then
		TabularSectionRow.AmountDiscountsMarkups = ?((TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.AutomaticDiscountAmount) < 0, 
			0, 
			TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.AutomaticDiscountAmount);
	EndIf;
	
	TabularSectionRow.DiscountAmount = TabularSectionRow.AmountDiscountsMarkups;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	If TabularSectionRow.Price <> 0
	   AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.DiscountMarkupPercent = (1 - TabularSectionRow.Amount / (TabularSectionRow.Price * TabularSectionRow.Quantity)) * 100;
	Else
		TabularSectionRow.DiscountMarkupPercent = 0;
	EndIf;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	
EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		NewRow.DiscountAmount = (NewRow.Quantity * NewRow.Price) - NewRow.Amount;
		NewRow.AmountDiscountsMarkups = NewRow.DiscountAmount;
		NewRow.ProductsCharacteristicAndBatch = TrimAll(NewRow.Products.Description)+?(NewRow.Characteristic.IsEmpty(), "", ". "+NewRow.Characteristic)+?(NewRow.Batch.IsEmpty(), "", ". "+NewRow.Batch);
		If NewRow.DiscountAmount <> 0 Then
			DiscountPercent = Format(NewRow.DiscountAmount * 100 / (NewRow.Quantity * NewRow.Price), "NFD=2");
			DiscountText = ?(NewRow.DiscountAmount > 0, " - "+NewRow.DiscountAmount, " + "+(-NewRow.DiscountAmount))+" "+Object.DocumentCurrency
						  +" ("+?(NewRow.DiscountAmount > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
		Else
			DiscountText = "";
		EndIf;
		NewRow.DataOnRow = ""+NewRow.Price+" "+Object.DocumentCurrency+" X "+NewRow.Quantity+" "+NewRow.MeasurementUnit+DiscountText+" = "+NewRow.Amount+" "+Object.DocumentCurrency;
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
		// Bundles
		If ImportRow.IsBundle Then
			
			StructureData = New Structure();
			
			StructureData.Insert("TabName", "Inventory");
			StructureData.Insert("Object", Object);
			StructureData.Insert("Company", Object.Company);
			StructureData.Insert("Products", NewRow.Products);
			StructureData.Insert("Characteristic", NewRow.Characteristic);
			StructureData.Insert("VATTaxation", Object.VATTaxation);
			StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
			
			If ValueIsFilled(Object.PriceKind) Then
				StructureData.Insert("ProcessingDate", Object.Date);
				StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
				StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
				StructureData.Insert("PriceKind", Object.PriceKind);
				StructureData.Insert("Factor", 1);
				StructureData.Insert("Content", "");
				StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
			EndIf;
			
			// DiscountCards
			StructureData.Insert("DiscountCard", Object.DiscountCard);
			StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
			// End DiscountCards
			
			AddIncomeAndExpenseItemsToStructure(ThisObject, "Inventory", StructureData, NewRow);
			
			If UseDefaultTypeOfAccounting Then
				AddGLAccountsToStructure(ThisObject, "Inventory", StructureData, NewRow);
			EndIf;
			
			StructureData = GetDataProductsOnChange(StructureData);
			
			ReplaceInventoryLineWithBundleData(ThisObject, NewRow, StructureData);
			
		EndIf;
		// End Bundles
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

	ShowHideDealAtServer(False, True);
	
EndProcedure

// Procedure runs recalculation in the document tabular section after making changes in the "Prices and currency" form.
// The columns are recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False)
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",		  Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",	  Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	  Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	ParametersStructure.Insert("Company",			  ParentCompany);
	ParametersStructure.Insert("DocumentDate",		  Object.Date);
	ParametersStructure.Insert("RefillPrices",	  False);
	ParametersStructure.Insert("RecalculatePrices",		  RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",  False);
	ParametersStructure.Insert("DocumentCurrencyEnabled", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	ParametersStructure.Insert("DiscountKind", Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	// 3. Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	If TypeOf(ClosingResult) = Type("Structure")
	   AND ClosingResult.WereMadeChanges Then
	   
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", ClosingResult.DocumentCurrency);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.SettlementsCurrencyBeforeChange);
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		// do not verify counterparty in receipts, so. All sales are anonymised.
		Object.DiscountCard = ClosingResult.DiscountCard;
		Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		// End DiscountCards
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices And ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory");
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			FillAmountsDiscounts();
		EndIf;
		
		// DiscountCards
		If ClosingResult.RefillDiscounts AND Not ClosingResult.RefillPrices Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
		// End DiscountCards
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Update document footer
	RecalculateDocumentAtClient();
	
	// Update labels for all strings TS Inventory.
	FillInDetailsForTSInventoryAtClient();
	
EndProcedure

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.ForeignExchangeAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = TrimAll(String(LabelStructure.DocumentCurrency));
		EndIf;
	EndIf;
	
	// Price type.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.PriceKind)));  
	EndIf;
	
	// Discount type and percent.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.DiscountKind)));  
	EndIf;
																			
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, 
		String(LabelStructure.DiscountPercentByDiscountCard) + "% "
		+ NStr("en = 'by card'; ru = 'по карте';pl = 'kartą';es_ES = 'con tarjeta';es_CO = 'con tarjeta';tr = 'kart ile';it = 'con carta';de = 'per Karte'"));  
	EndIf;	
	
	// VAT taxation.
	If ValueIsFilled(LabelStructure.VATTaxation) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.VATTaxation)));  
	EndIf;
	
	// Flag showing that amount includes VAT.
	If IsBlankString(LabelText) Then
		If LabelStructure.AmountIncludesVAT Then	
			LabelText = NStr("en = 'Amount includes VAT'; ru = 'Сумма включает НДС';pl = 'Kwota zawiera VAT';es_ES = 'Importe incluye el IVA';es_CO = 'Importe incluye el IVA';tr = 'Tutara KDV dahil';it = 'Importo IVA inclusa';de = 'Der Betrag beinhaltet die USt.'");
		Else
			LabelText = NStr("en = 'Amount excludes VAT'; ru = 'Сумма без НДС';pl = 'Wartość netto';es_ES = 'Cantidad excluye el IVA';es_CO = 'Cantidad excluye el IVA';tr = 'KDV hariç tutar';it = 'Importo IVA esclusa';de = 'Betrag abzgl. USt.'");
		EndIf;
	EndIf;
	
	Return LabelText;
	
EndFunction

// Procedure forms form heading.
//
&AtServer
Procedure GenerateTitle(StructureStateCashCRSession)
	
	If StructureStateCashCRSession.SessionIsOpen Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1, Session #%2 %3'; ru = '%1, Смена №%2 %3';pl = '%1, Sesja #%2 %3';es_ES = '%1, Sesión #%2 %3';es_CO = '%1, Sesión #%2 %3';tr = '%1, Oturum #%2 %3';it = '%1, Sessione #%2 %3';de = '%1, Sitzung Nr %2 %3'"),
			TrimAll(StructureStateCashCRSession.StructuralUnit),
			TrimAll(StructureStateCashCRSession.CashCRSessionNumber),
			Format(StructureStateCashCRSession.StatusModificationDate, "DLF=D"));
	Else
		MessageText = "%1";
		If ValueIsFilled(StructureStateCashCRSession.StructuralUnit) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, TrimAll(StructureStateCashCRSession.StructuralUnit));
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, TrimAll(CashCR.StructuralUnit));
		EndIf;
	EndIf;
	
	Title = MessageText;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	UseGoodsReturnFromCustomer = AccountingPolicy.UseGoodsReturnFromCustomer;
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("RevenueGLAccount",	TabRow.RevenueGLAccount);
	StructureData.Insert("VATOutputGLAccount",	TabRow.VATOutputGLAccount);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddIncomeAndExpenseItemsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("RevenueItem",	TabRow.RevenueGLAccount);
	StructureData.Insert("TabName",		TabName);
	
EndProcedure

#Region Bundles

&AtClient
Procedure InventoryBeforeDeleteRowEnd(Result, BundleData) Export
	
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	BundleRows = Object.Inventory.FindRows(BundleData);
	If BundleRows.Count() = 0 Then
		Return;
	EndIf;
	
	BundleRow = BundleRows[0];
	
	If Result = DialogReturnCode.No Then
		
		EditBundlesComponents(BundleRow);
		
	ElsIf Result = DialogReturnCode.Yes Then
		
		BundlesClient.DeleteBundleRows(BundleRow.BundleProduct,
			BundleRow.BundleCharacteristic,
			Object.Inventory,
			Object.AddedBundles);
			
		Modified = True;
		RecalculateDocumentAtClient();
		SetBundlePictureVisible();
		
	ElsIf Result = "DeleteOne" Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("BundleProduct",			BundleRow.BundleProduct);
		FilterStructure.Insert("BundleCharacteristic",	BundleRow.BundleCharacteristic);
		AddedRows = Object.AddedBundles.FindRows(FilterStructure);
		BundleRows = Object.Inventory.FindRows(FilterStructure);
		
		If AddedRows.Count() = 0 Or AddedRows[0].Quantity <= 1 Then
			
			For Each Row In BundleRows Do
				Object.Inventory.Delete(Row);
			EndDo;
			
			For Each Row In AddedRows Do
				Object.AddedBundles.Delete(Row);
			EndDo;
			
			Return;
			
		EndIf;
		
		OldCount = AddedRows[0].Quantity;
		AddedRows[0].Quantity = OldCount - 1;
		BundlesClientServer.DeleteBundleComponent(BundleRow.BundleProduct,
			BundleRow.BundleCharacteristic,
			Object.Inventory,
			OldCount);
			
		BundleRows = Object.Inventory.FindRows(FilterStructure);
		For Each Row In BundleRows Do
			CalculateAmountInTabularSectionLine(Row);
		EndDo;
		
		Modified = True;
		RecalculateDocumentAtClient();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BundlesOnCreateAtServer()
	
	UseBundles = GetFunctionalOption("UseProductBundles");
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshBundlePictures(Inventory)
	
	For Each InventoryLine In Inventory Do
		InventoryLine.BundlePicture = ValueIsFilled(InventoryLine.BundleProduct);
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ReplaceInventoryLineWithBundleData(Form, BundleLine, StructureData)
	
	Items = Form.Items;
	Object = Form.Object;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, BundleLine, , Form.UseSerialNumbersBalance);
	BundlesClientServer.ReplaceInventoryLineWithBundleData(Object, "Inventory", BundleLine, StructureData);
	
	// Refresh RowFiler
	If Items.Inventory.RowFilter <> Undefined And Items.Inventory.RowFilter.Count() > 0 Then
		OldRowFilter = Items.Inventory.RowFilter;
		Items.Inventory.RowFilter = New FixedStructure(New Structure);
		Items.Inventory.RowFilter = OldRowFilter;
	EndIf;
	
	Items.InventoryBundlePicture.Visible = True;
	
EndProcedure

&AtServerNoContext
Procedure RefreshBundleAttributes(Inventory)
	
	If Not GetFunctionalOption("UseProductBundles") Then
		Return;
	EndIf;
	
	ProductsArray = New Array;
	For Each InventoryLine In Inventory Do
		
		If ValueIsFilled(InventoryLine.Products) And Not ValueIsFilled(InventoryLine.BundleProduct) Then
			ProductsArray.Add(InventoryLine.Products);
		EndIf;
		
	EndDo;
	
	If ProductsArray.Count() > 0 Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Products.Ref AS Ref
		|FROM
		|	Catalog.Products AS Products
		|WHERE
		|	Products.Ref IN(&ProductsArray)
		|	AND Products.IsBundle";
		
		Query.SetParameter("ProductsArray", ProductsArray);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		ProductsMap = New Map;
		
		While SelectionDetailRecords.Next() Do
			ProductsMap.Insert(SelectionDetailRecords.Ref, True);
		EndDo;
		
		For Each InventoryLine In Inventory Do
			
			If Not ValueIsFilled(InventoryLine.Products) Or ValueIsFilled(InventoryLine.BundleProduct) Then
				InventoryLine.IsBundle = False;
			Else
				InventoryLine.IsBundle = ProductsMap.Get(InventoryLine.Products);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshBundleComponents(BundleProduct, BundleCharacteristic, Quantity, BundleComponents)
	
	FillingParameters = New Structure;
	FillingParameters.Insert("Object", Object);
	FillingParameters.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	BundlesServer.RefreshBundleComponentsInTable(BundleProduct, BundleCharacteristic, Quantity, BundleComponents, FillingParameters);
	Modified = True;
	
	// AutomaticDiscounts
	ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure ActionsAfterDeleteBundleLine()
	
	RecalculateDocumentAtClient();
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow")
	
EndProcedure

&AtClient
Procedure EditBundlesComponents(InventoryLine)
	
	OpeningStructure = New Structure;
	OpeningStructure.Insert("BundleProduct", InventoryLine.BundleProduct);
	OpeningStructure.Insert("BundleCharacteristic", InventoryLine.BundleCharacteristic);
	
	AddedRows = Object.AddedBundles.FindRows(OpeningStructure);
	BundleRows = Object.Inventory.FindRows(OpeningStructure);
	
	If AddedRows.Count() = 0 Then
		OpeningStructure.Insert("Quantity", 1);
	Else
		OpeningStructure.Insert("Quantity", AddedRows[0].Quantity);
	EndIf;
	
	OpeningStructure.Insert("BundlesComponents", New Array);
	
	For Each Row In BundleRows Do
		RowStructure = New Structure("Products, Characteristic, Quantity, CostShare, MeasurementUnit, IsActive");
		FillPropertyValues(RowStructure, Row);
		RowStructure.IsActive = (Row = InventoryLine);
		OpeningStructure.BundlesComponents.Add(RowStructure);
	EndDo;
	
	OpenForm("InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle",
		OpeningStructure,
		ThisObject,
		, , , ,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Procedure SetBundlePictureVisible()
	
	BundlePictureVisible = False;
	
	For Each Row In Object.Inventory Do
		
		If Row.BundlePicture Then
			BundlePictureVisible = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Items.InventoryBundlePicture.Visible <> BundlePictureVisible Then
		Items.InventoryBundlePicture.Visible = BundlePictureVisible;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBundleConditionalAppearance()
	
	If UseBundles Then
		
		NewConditionalAppearance = ConditionalAppearance.Items.Add();
		WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
			"Object.Inventory.BundleProduct",
			Catalogs.Products.EmptyRef(),
			DataCompositionComparisonType.NotEqual);
			
		WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryProducts, InventoryCharacteristic, InventoryContent, InventoryQuantity, InventoryMeasurementUnit");
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.UnavailableTabularSectionTextColor);
				
	EndIf;
	
EndProcedure

&AtServer
Function BundleCharacteristics(Product, Text)
	
	ParametersStructure = New Structure;
	
	If IsBlankString(Text) Then
		ParametersStructure.Insert("SearchString", Undefined);
	Else
		ParametersStructure.Insert("SearchString", Text);
	EndIf;
	
	ParametersStructure.Insert("Filter", New Structure);
	ParametersStructure.Filter.Insert("Owner", Product);
	
	Return Catalogs.ProductsCharacteristics.GetChoiceData(ParametersStructure);
	
EndFunction

#EndRegion

&AtServer
Procedure SetConditionalAppearance()
	
	ColorRed			= WebColors.Red;
	FontShiftClosure	= StyleFonts.FontDialogAndMenu;
	
	// ProductReturn
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Type");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Type("DocumentRef.ProductReturn");
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRed);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ReceiptNumber");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Amount");
	FieldAppearance.Use = True;
	
	//ShiftClosure
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Type");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Type("DocumentRef.ShiftClosure");
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", FontShiftClosure);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ReceiptNumber");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Amount");
	FieldAppearance.Use = True;
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Type");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Type("DocumentRef.ShiftClosure");
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'Shift is closed'; ru = 'Смена закрыта';pl = 'Zmiana zamknięta';es_ES = 'Turno está cerrado';es_CO = 'Turno está cerrado';tr = 'Vardiya kapandı';it = 'Il turno è chiuso';de = 'Die Schicht ist abgeschlossen'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ReceiptNumber");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion

#Region UseCommonProceduresAndFunctionsCashCRSession

// Receipt print procedure on fiscal register.
//
&AtClient
Procedure IssueReceipt(GenerateSalesReceipt = False, GenerateSimplifiedTaxInvoice = False,
						GenerateWarrantyCardPerSerialNumber = False, GenerateWarrantyCardConsolidated = False)
	
	ErrorDescription = "";
	
	If Object.SalesSlipNumber <> 0
	AND Not CashCRUseWithoutEquipmentConnection Then
		
		MessageText = NStr("en = 'Receipt has already been issued on the fiscal data recorder.'; ru = 'Чек уже пробит на фискальном регистраторе!';pl = 'Paragon został już wydrukowany przez rejestrator fiskalny.';es_ES = 'Recibo ya se ha emitido en el registro de datos fiscales.';es_CO = 'Recibo ya se ha emitido en el registro de datos fiscales.';tr = 'Fiş zaten mali veri kayıt cihazında yayınlanmıştır.';it = 'La ricevuta è già stato emessa nel registratore fiscale.';de = 'Der Beleg wurde bereits an den Steuer Datenschreiber ausgegeben.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If UsePeripherals // Check for the included FO "Use Peripherals"
		AND Not CashCRUseWithoutEquipmentConnection Then 
			
			If EquipmentManagerClient.RefreshClientWorkplace() Then // Check on the certainty of Peripheral workplace
				
				DeviceIdentifier = ?(
					ValueIsFilled(FiscalRegister),
					FiscalRegister,
					Undefined
				);
				
				If DeviceIdentifier <> Undefined Then
					
					// Connect FR
					Result = EquipmentManagerClient.ConnectEquipmentByID(
						UUID,
						DeviceIdentifier,
						ErrorDescription
					);
						
					If Result Then
						
						// Prepare data
						InputParameters  = New Array;
						Output_Parameters = Undefined;
						
						SectionNumber = 1;
						
						// Preparation of the product table
						ProductsTable = New Array();
						
						For Each TSRow In Object.Inventory Do
							
							VATRate = DriveReUse.GetVATRateValue(TSRow.VATRate);
							
							ProductsTableRow = New ValueList();
							ProductsTableRow.Add(String(TSRow.Products));
																				  //  1 - Description
							ProductsTableRow.Add("");                    //  2 - Barcode
							ProductsTableRow.Add("");                    //  3 - SKU
							ProductsTableRow.Add(SectionNumber);           //  4 - Department number
							ProductsTableRow.Add(TSRow.Price);         //  5 - Price for position without discount
							ProductsTableRow.Add(TSRow.Quantity);   //  6 - Count
							ProductsTableRow.Add("");                    //  7 - Discount description
							ProductsTableRow.Add(0);                     //  8 - Discount amount
							ProductsTableRow.Add(0);                     //  9 - Discount percentage
							ProductsTableRow.Add(TSRow.Amount);        // 10 - Position amount with discount
							ProductsTableRow.Add(0);                     // 11 - Tax number (1)
							ProductsTableRow.Add(TSRow.VATAmount);     // 12 - Tax amount (1)
							ProductsTableRow.Add(VATRate);             // 13 - Tax percent (1)
							ProductsTableRow.Add(0);                     // 14 - Tax number (2)
							ProductsTableRow.Add(0);                     // 15 - Tax amount (2)
							ProductsTableRow.Add(0);                     // 16 - Tax percent (2)
							ProductsTableRow.Add("");                    // 17 - Section name of commodity string formatting
							
							ProductsTable.Add(ProductsTableRow);
							
						EndDo;
						
						// Preparation of the payment table
						PaymentsTable = New Array();
						
						// Cash
						PaymentRow = New ValueList();
						PaymentRow.Add(0);
						PaymentRow.Add(Object.CashReceived);
						PaymentRow.Add("Payment by cash");
						PaymentRow.Add("");
						PaymentsTable.Add(PaymentRow);
						
						// Noncash
						PaymentRow = New ValueList();
						PaymentRow.Add(1);
						PaymentRow.Add(Object.PaymentWithPaymentCards.Total("Amount"));
						PaymentRow.Add("Group Cashless payment");
						PaymentRow.Add("");
						PaymentsTable.Add(PaymentRow);
						
						// Preparation of the common parameters table
						CommonParameters = New Array();
						CommonParameters.Add(0);                      //  1 - Receipt type
						CommonParameters.Add(True);                 //  2 - Fiscal receipt sign
						CommonParameters.Add(Undefined);           //  3 - Print on lining document
						CommonParameters.Add(Object.DocumentAmount);  //  4 - the receipt amount without discounts
						CommonParameters.Add(Object.DocumentAmount);  //  5 - the receipt amount after applying all discounts
						CommonParameters.Add("");                     //  6 - Discount card number
						CommonParameters.Add("");                     //  7 - Header text
						CommonParameters.Add("");                     //  8 - Footer text
						CommonParameters.Add(0);                      //  9 - Session number (for receipt copy)
						CommonParameters.Add(0);                      // 10 - Receipt number (for receipt copy)
						CommonParameters.Add(0);                      // 11 - Document No (for receipt copy)
						CommonParameters.Add(0);                      // 12 - Document date (for receipt copy)
						CommonParameters.Add("");                     // 13 - Cashier name (for receipt copy)
						CommonParameters.Add("");                     // 14 - Cashier password
						CommonParameters.Add(0);                      // 15 - Template number
						CommonParameters.Add("");                     // 16 - Section name header format
						CommonParameters.Add("");                     // 17 - Section name cellar format
						
						InputParameters.Add(ProductsTable);
						InputParameters.Add(PaymentsTable);
						InputParameters.Add(CommonParameters);
						
						// Print receipt.
						Result = EquipmentManagerClient.RunCommand(
							DeviceIdentifier,
							"PrintReceipt",
							InputParameters,
							Output_Parameters
						);
						
						If Result Then
							
							// Set the received value of receipt number to document attribute.
							Object.SalesSlipNumber = Output_Parameters[1];
							Object.Status = PredefinedValue("Enum.SalesSlipStatus.Issued");
							Object.Date = CommonClient.SessionDate();
							
							If Not ValueIsFilled(Object.SalesSlipNumber) Then
								Object.SalesSlipNumber = 1;
							EndIf;
							
							Modified = True;
							
							Try
								PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
								ShowHideDealAtServer();
							Except
							
								FillInDetailsForTSInventoryAtClient();
								ShowMessageBox(Undefined, NStr("en = 'Failed to post document.'; ru = 'Не удалось провести документ.';pl = 'Zatwierdzenie dokumentu nie powiodło się.';es_ES = 'Fallado a enviar el documento.';es_CO = 'Fallado a enviar el documento.';tr = 'Belge kaydedilemedi.';it = 'Non riuscito a pubblicare il documento.';de = 'Fehler beim Buchen des Dokuments'")); // Asynchronous method.
								Return;
							EndTry;
							
							GeneratePrintForms(
								GenerateSalesReceipt,
								GenerateSimplifiedTaxInvoice,
								GenerateWarrantyCardPerSerialNumber,
								GenerateWarrantyCardConsolidated);
							
							InitializeNewReceipt();
							DisplayInformationOnCustomerDisplay();
							
						Else
							
							MessageText = NStr("en = 'When printing a receipt, an error occurred.
							                   |Receipt is not printed on the fiscal register.
							                   |Additional description: %1.'; 
							                   |ru = 'При печати чека произошла ошибка.
							                   |Чек не напечатан на фискальном регистраторе.
							                   |Дополнительное описание: %1.';
							                   |pl = 'Podczas drukowania paragonu wystąpił błąd.
							                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
							                   |Dodatkowy opis: %1.';
							                   |es_ES = 'Imprimiendo un recibo, ha ocurrido un error.
							                   |Recibo no se ha imprimido en el registro fiscal.
							                   |Descripción adicional: %1.';
							                   |es_CO = 'Imprimiendo un recibo, ha ocurrido un error.
							                   |Recibo no se ha imprimido en el registro fiscal.
							                   |Descripción adicional: %1.';
							                   |tr = 'Fiş yazdırılırken hata oluştu.
							                   |Fiş mali kayıtta yazdırılamadı.
							                   |Ek açıklama: %1.';
							                   |it = 'Si è verificato un errore durante la stampa di una ricevuta.
							                   |La ricevuta non è stampata sul registratore fiscale.
							                   |Descrizione aggiuntiva: %1.';
							                   |de = 'Beim Drucken eines Belegs ist ein Fehler aufgetreten.
							                   |Der Beleg wird nicht im Fiskalspeicher gedruckt.
							                   |Zusätzliche Beschreibung: %1.'");
							MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,Output_Parameters[1]);
							CommonClientServer.MessageToUser(MessageText);
							
						EndIf;
						
						// Disconnect FR
						EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
						
					Else
						
						MessageText = NStr("en = 'An error occurred when connecting the device.
						                   |Receipt is not printed on the fiscal register.
						                   |Additional description: %1.'; 
						                   |ru = 'При подключении устройства произошла ошибка.
						                   |Чек не напечатан на фискальном регистраторе.
						                   |Дополнительное описание: %1.';
						                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
						                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
						                   |Dodatkowy opis: %1.';
						                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
						                   |Recibo no se ha imprimido en el registro fiscal.
						                   |Descripción adicional: %1.';
						                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
						                   |Recibo no se ha imprimido en el registro fiscal.
						                   |Descripción adicional: %1.';
						                   |tr = 'Cihaz bağlanırken hata oluştu.
						                   |Fiş mali kayıtta yazdırılamadı.
						                   |Ek açıklama: %1.';
						                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
						                   |La ricevuta non è stampata nel registratore fiscale.
						                   |Descrizione aggiuntiva: %1.';
						                   |de = 'Beim Anschließen des Geräts ist ein Fehler aufgetreten.
						                   |Der Beleg wird nicht auf den Fiskalspeicher gedruckt.
						                   |Zusätzliche Beschreibung: %1.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
						CommonClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en = 'Fiscal data recorder is not selected'; ru = 'Не выбран фискальный регистратор';pl = 'Nie wybrano rejestratora danych fiskalnych';es_ES = 'Registrador de datos fiscales no se ha seleccionado';es_CO = 'Registrador de datos fiscales no se ha seleccionado';tr = 'Mali veri kaydedici seçilmedi.';it = 'Non è stata selezionata la registrazione fiscale';de = 'Fiskal-Datenschreiber ist nicht ausgewählt'");
					CommonClientServer.MessageToUser(MessageText);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		Else
			
			// External equipment is not used
			Object.Status = PredefinedValue("Enum.SalesSlipStatus.Issued");
			Object.Date = CommonClient.SessionDate();
			
			If Not ValueIsFilled(Object.SalesSlipNumber) Then
				Object.SalesSlipNumber = 1;
			EndIf;
			
			Modified = True;
			
			Try
				PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
				ShowHideDealAtServer();
			Except
				FillInDetailsForTSInventoryAtClient();
				ShowMessageBox(Undefined,NStr("en = 'Failed to post document.'; ru = 'Не удалось провести документ.';pl = 'Zatwierdzenie dokumentu nie powiodło się.';es_ES = 'Fallado a enviar el documento.';es_CO = 'Fallado a enviar el documento.';tr = 'Belge kaydedilemedi.';it = 'Non riuscito a pubblicare il documento.';de = 'Fehler beim Buchen des Dokuments'")); // Asynchronous method.
				Return;
			EndTry;
			
			GeneratePrintForms(
				GenerateSalesReceipt, 
				GenerateSimplifiedTaxInvoice,
				GenerateWarrantyCardPerSerialNumber,
				GenerateWarrantyCardConsolidated);
			
			InitializeNewReceipt();
			DisplayInformationOnCustomerDisplay();
			
		EndIf;
		
	Else
		
		FillInDetailsForTSInventoryAtClient();
		If ShowMessageBox Then
			ShowMessageBox(Undefined,NStr("en = 'Failed to post document'; ru = 'Не удалось выполнить проведение документа';pl = 'Księgowanie dokumentu nie powiodło się';es_ES = 'Fallado a enviar el documento';es_CO = 'Fallado a enviar el documento';tr = 'Belge kaydedilemedi';it = 'Impossibile pubblicare il documento';de = 'Fehler beim Buchen des Dokuments'"));
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePrintForms(GenerateSalesReceipt, GenerateSimplifiedTaxInvoice,
	GenerateWarrantyCardPerSerialNumber = False, GenerateWarrantyCardConsolidated = False)
	
	If  Not Object.Ref.IsEmpty() Then
		
		If GenerateSalesReceipt Then
			
			OpenParameters = New Structure("PrintManagerName, TemplatesNames, CommandParameter, PrintParameters");
			OpenParameters.PrintManagerName = "Document.SalesSlip";
			OpenParameters.TemplatesNames   = "SalesReceipt";
			SalesSlipsArray = New Array;
			SalesSlipsArray.Add(Object.Ref);
			OpenParameters.CommandParameter	 = SalesSlipsArray;
			
			PrintParameters = New Structure("FormTitle, ID, AdditionalParameters");
			PrintParameters.FormTitle = NStr("en = 'Receipt'; ru = 'Чек';pl = 'Paragon';es_ES = 'Recibo';es_CO = 'Recibo';tr = 'Makbuz';it = 'Ricevuto';de = 'Erhalt'");
			PrintParameters.ID = "SalesReceipt";
            PrintParameters.AdditionalParameters = New Structure("Result");
			OpenParameters.PrintParameters = PrintParameters;
			
			If Not PrintManagementClientDrive.DisplayPrintOption(SalesSlipsArray, OpenParameters, FormOwner, UniqueKey, OpenParameters.PrintParameters) Then
				OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
            EndIf;    
		EndIf;
		
		If GenerateSimplifiedTaxInvoice Then
			
			OpenParameters = New Structure("PrintManagerName, TemplatesNames, CommandParameter, PrintParameters");
			OpenParameters.PrintManagerName = "Document.SalesSlip";
			OpenParameters.TemplatesNames	= "SimplifiedTaxInvoice";
			SalesSlipsArray = New Array;
			SalesSlipsArray.Add(Object.Ref);
			OpenParameters.CommandParameter	= SalesSlipsArray;
			
			PrintParameters = New Structure("FormTitle, ID, AdditionalParameters");
			PrintParameters.FormTitle = NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura fiscal';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'");
			PrintParameters.ID = "SimplifiedTaxInvoice";
			OpenParameters.PrintParameters = PrintParameters;
			
            OpenParameters.PrintParameters	= New Structure("AdditionalParameters");
            OpenParameters.PrintParameters.AdditionalParameters = New Structure("Result");
            
            OpenParameters.PrintParameters.AdditionalParameters.Insert("Result", Undefined);
            OpenParameters.PrintParameters.Insert("ID", OpenParameters.TemplatesNames);
            OpenParameters.PrintParameters.Insert("PrintObjects", SalesSlipsArray);
            
            If Not PrintManagementClientDrive.DisplayPrintOption(SalesSlipsArray, OpenParameters, FormOwner, UniqueKey, OpenParameters.PrintParameters) Then
			    OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
            EndIf;    
			
		EndIf;
		
		If GenerateWarrantyCardPerSerialNumber Then
			
			OpenParameters = New Structure("PrintManagerName, TemplatesNames, CommandParameter, PrintParameters");
			OpenParameters.PrintManagerName = "Document.SalesSlip";
			OpenParameters.TemplatesNames	= "WarrantyCardPerSerialNumber";
			SalesSlipsArray = New Array;
			SalesSlipsArray.Add(Object.Ref);
			OpenParameters.CommandParameter	= SalesSlipsArray;
			
			PrintParameters = New Structure("FormTitle, ID, AdditionalParameters");
			PrintParameters.FormTitle = NStr("en = 'Warranty card'; ru = 'Гарантийный талон';pl = 'Karta gwarancyjna';es_ES = 'Tarjeta de garantía';es_CO = 'Tarjeta de garantía';tr = 'Garanti belgesi';it = 'Certificato di garanzia';de = 'Garantiekarte'");
			PrintParameters.ID = "WarrantyCardPerSerialNumber";
            PrintParameters.AdditionalParameters = New Structure("Result");
			OpenParameters.PrintParameters = PrintParameters;
			
			If Not PrintManagementClientDrive.DisplayPrintOption(SalesSlipsArray, OpenParameters, FormOwner, UniqueKey, OpenParameters.PrintParameters) Then
				OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
            EndIf;    
			
		EndIf;
		
		If GenerateWarrantyCardConsolidated Then
			
			OpenParameters = New Structure("PrintManagerName, TemplatesNames, CommandParameter, PrintParameters");
			OpenParameters.PrintManagerName = "Document.SalesSlip";
			OpenParameters.TemplatesNames	= "WarrantyCardConsolidated";
			SalesSlipsArray = New Array;
			SalesSlipsArray.Add(Object.Ref);
			OpenParameters.CommandParameter	= SalesSlipsArray;
			
			PrintParameters = New Structure("FormTitle, ID, AdditionalParameters");
			PrintParameters.FormTitle = NStr("en = 'Warranty card'; ru = 'Гарантийный талон';pl = 'Karta gwarancyjna';es_ES = 'Tarjeta de garantía';es_CO = 'Tarjeta de garantía';tr = 'Garanti belgesi';it = 'Certificato di garanzia';de = 'Garantiekarte'");
			PrintParameters.ID = "WarrantyCardConsolidated";
            PrintParameters.AdditionalParameters = New Structure("Result");
			OpenParameters.PrintParameters = PrintParameters;
						
			If Not PrintManagementClientDrive.DisplayPrintOption(SalesSlipsArray, OpenParameters, FormOwner, UniqueKey, OpenParameters.PrintParameters) Then
				OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
            EndIf;    
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Function gets cash session state on server.
//
&AtServerNoContext
Function GetCashCRSessionStateAtServer(CashCR)
	
	Return Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
EndFunction

// Procedure - event handler "OpenCashCRSession".
//
&AtClient
Procedure CashCRSessionOpen()
	
	Result = False;
	ClearMessages();
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					
					InputParameters  = Undefined;
					Output_Parameters = Undefined;
					
					// Open session on fiscal register
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"OpenDay",
						InputParameters, 
						Output_Parameters
					);
					
				EndIf;
				
				If Result OR UseWithoutEquipmentConnection Then
					
					Result = CashCRSessionOpenAtServer(CashCR, ErrorDescription);
					
					If Not Result Then
						
						MessageText = NStr("en = 'An error occurred when opening the session.
						                   |Session is not opened.
						                   |Additional description: %1.'; 
						                   |ru = 'При открытии смены произошла ошибка.
						                   |Смена не открыта.
						                   |Дополнительное описание: %1.';
						                   |pl = 'W czasie otwierania sesji wystąpił błąd.
						                   |Sesja nie została otwarta.
						                   |Dodatkowy opis: %1.';
						                   |es_ES = 'Ha ocurrido un error al abrir la sesión.
						                   |Sesión no está abierta.
						                   |Descripción adicional: %1.';
						                   |es_CO = 'Ha ocurrido un error al abrir la sesión.
						                   |Sesión no está abierta.
						                   |Descripción adicional: %1.';
						                   |tr = 'Oturum açıldığında bir hata oluştu. 
						                   |Oturum açılmadı. 
						                   |Ek açıklama: %1';
						                   |it = 'Si è verificato un errore all''apertura della sessione.
						                   |La sessione non è stata aperta.
						                   |Descrizione aggiuntiva: %1.';
						                   |de = 'Beim Öffnen der Sitzung ist ein Fehler aufgetreten.
						                   |Sitzung wird nicht geöffnet.
						                   |Zusätzliche Beschreibung: %1.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
						?(UseWithoutEquipmentConnection, ErrorDescription, Output_Parameters[1]));
						CommonClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en = 'An error occurred when opening the session.
					                   |Session is not opened.
					                   |Additional description: %1.'; 
					                   |ru = 'При открытии смены произошла ошибка.
					                   |Смена не открыта.
					                   |Дополнительное описание: %1.';
					                   |pl = 'W czasie otwierania sesji wystąpił błąd.
					                   |Sesja nie została otwarta.
					                   |Dodatkowy opis: %1.';
					                   |es_ES = 'Ha ocurrido un error al abrir la sesión.
					                   |Sesión no está abierta.
					                   |Descripción adicional: %1.';
					                   |es_CO = 'Ha ocurrido un error al abrir la sesión.
					                   |Sesión no está abierta.
					                   |Descripción adicional: %1.';
					                   |tr = 'Oturum açıldığında bir hata oluştu. 
					                   |Oturum açılmadı. 
					                   |Ek açıklama: %1';
					                   |it = 'Si è verificato un errore all''apertura della sessione.
					                   |La sessione non è stata aperta.
					                   |Descrizione aggiuntiva: %1.';
					                   |de = 'Beim Öffnen der Sitzung ist ein Fehler aufgetreten.
					                   |Sitzung wird nicht geöffnet.
					                   |Zusätzliche Beschreibung: %1.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
					CommonClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Session is not opened on the fiscal register.
				                   |Additional description: %1.'; 
				                   |ru = 'При подключении устройства произошла ошибка.
				                   |Смена не открыта на фискальном регистраторе.
				                   |Дополнительное описание: %1.';
				                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
				                   |Sesja nie jest otwarta w rejestrze podatkowym.
				                   |Dodatkowy opis: %1.';
				                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Sesión no está abierta en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Sesión no está abierta en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |tr = 'Cihaz bağlanırken hata oluştu.
				                   |Mali kayıtta oturum açılamadı.
				                   |Ek açıklama: %1.';
				                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
				                   |La sessione non viene aperta sul registro fiscale.
				                   |Descrizione aggiuntiva: %1.';
				                   |de = 'Beim Anschließen des Geräts ist ein Fehler aufgetreten.
				                   |Die Sitzung wird im Fiskalspeicher nicht geöffnet.
				                   |Zusätzliche Beschreibung: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'"
		);
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

// Function opens the cash session on server.
//
&AtServer
Function CashCRSessionOpenAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.ShiftClosure.CashCRSessionOpen(CashCR, ErrorDescription);
	
EndFunction

// Function verifies the existence of issued receipts during the session.
//
&AtServer
Function IssuedReceiptsExist(CashCR)
	
	StructureStateCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
	If StructureStateCashCRSession.CashCRSessionStatus <> Enums.ShiftClosureStatus.IsOpen Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesSlipInventory.Ref AS CountRecipies
	|FROM
	|	(SELECT
	|		SalesSlipInventory.Ref AS Ref
	|	FROM
	|		Document.SalesSlip.Inventory AS SalesSlipInventory
	|	WHERE
	|		SalesSlipInventory.Ref.CashCRSession = &CashCRSession
	|		AND SalesSlipInventory.Ref.Posted
	|		AND SalesSlipInventory.Ref.SalesSlipNumber > 0
	|		AND (NOT SalesSlipInventory.Ref.Archival)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SalesSlipInventory.Ref
	|	FROM
	|		Document.ProductReturn.Inventory AS SalesSlipInventory
	|	WHERE
	|		SalesSlipInventory.Ref.CashCRSession = &CashCRSession
	|		AND SalesSlipInventory.Ref.Posted
	|		AND SalesSlipInventory.Ref.SalesSlipNumber > 0
	|		AND (NOT SalesSlipInventory.Ref.Archival)) AS SalesSlipInventory";
	
	Query.SetParameter("CashCRSession", StructureStateCashCRSession.CashCRSession);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Procedure closes the cash session on server.
//
&AtServer
Function CloseCashCRSessionAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.ShiftClosure.CloseCashCRSessionExecuteArchiving(CashCR, ErrorDescription);
	
EndFunction

// Procedure - command handler "FundsIntroduction".
//
&AtClient
Procedure CashDeposition(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		InAmount = 0;
		
		WindowTitle = NStr("en = 'Deposit amount'; ru = 'Сумма внесения';pl = 'Wartość depozytu';es_ES = 'Importe del depósito';es_CO = 'Importe del depósito';tr = 'Depozito tutarı';it = 'Importo deposito';de = 'Einzahlungsbetrag'") + ", " + "%Currency%";
		WindowTitle = StrReplace(
			WindowTitle,
			"%Currency%",
			StructureStateCashCRSession.DocumentCurrencyPresentation
		);
		
		ShowInputNumber(New NotifyDescription("FundsIntroductionEnd", ThisObject, New Structure("InAmount", InAmount)), InAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'"
		);
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsIntroduction" after introduction amount enter.
//
&AtClient
Procedure FundsIntroductionEnd(Result1, AdditionalParameters) Export
	
	InAmount = ?(Result1 = Undefined, AdditionalParameters.InAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, InAmount);
		Else
			NotifyDescription = New NotifyDescription("FundsIntroductionFiscalRegisterConnectionsEnd", ThisObject, InAmount);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
				NStr("en = 'Select a fiscal data recorder'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator fiskalny';es_ES = 'Seleccionar un registrador de datos fiscales';es_CO = 'Seleccionar un registrador de datos fiscales';tr = 'Mali veri kaydediciyi seçin';it = 'Selezionare un registratore fiscale';de = 'Wählen Sie einen Steuer Datenschreiber'"),
				NStr("en = 'Fiscal data recorder is not connected.'; ru = 'Фискальный регистратор не подключен.';pl = 'Rejestrator fiskalny nie jest podłączony.';es_ES = 'Registrador de datos fiscales no está conectado.';es_CO = 'Registrador de datos fiscales no está conectado.';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore dati fiscale non è connesso.';de = 'Der Steuerdatenschreiber ist nicht angeschlossen.'"));
		EndIf;
		
	EndIf;

EndProcedure

// Procedure prints receipt on FR (Encash command).
//
&AtClient
Procedure FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	InAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Connect FR
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			// Prepare data
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			
			InputParameters.Add(1);
			InputParameters.Add(InAmount);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
			DeviceIdentifier,
			"Encash",
			InputParameters,
			Output_Parameters
			);
			
			If Not Result Then
				
				MessageText = NStr("en = 'When printing a receipt, an error occurred.
				                   |Receipt is not printed on the fiscal register.
				                   |Additional description: %1.'; 
				                   |ru = 'При печати чека произошла ошибка.
				                   |Чек не напечатан на фискальном регистраторе.
				                   |Дополнительное описание: %1.';
				                   |pl = 'Podczas drukowania paragonu wystąpił błąd.
				                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
				                   |Dodatkowy opis: %1.';
				                   |es_ES = 'Imprimiendo un recibo, ha ocurrido un error.
				                   |Recibo no se ha imprimido en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |es_CO = 'Imprimiendo un recibo, ha ocurrido un error.
				                   |Recibo no se ha imprimido en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |tr = 'Fiş yazdırılırken hata oluştu.
				                   |Fiş mali kayıtta yazdırılamadı.
				                   |Ek açıklama: %1.';
				                   |it = 'Si è verificato un errore durante la stampa di una ricevuta.
				                   |La ricevuta non è stampata sul registratore fiscale.
				                   |Descrizione aggiuntiva: %1.';
				                   |de = 'Beim Drucken eines Belegs ist ein Fehler aufgetreten.
				                   |Der Beleg wird nicht auf den Fiskalspeicher gedruckt.
				                   |Zusätzliche Beschreibung: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Output_Parameters[1]);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
			// Disconnect FR
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en = 'An error occurred when connecting the device.
			                   |Receipt is not printed on the fiscal register.
			                   |Additional description: %1.'; 
			                   |ru = 'При подключении устройства произошла ошибка.
			                   |Чек не напечатан на фискальном регистраторе.
			                   |Дополнительное описание: %1.';
			                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
			                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
			                   |Dodatkowy opis: %1.';
			                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
			                   |Recibo no se ha imprimido en el registro fiscal.
			                   |Descripción adicional: %1.';
			                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
			                   |Recibo no se ha imprimido en el registro fiscal.
			                   |Descripción adicional: %1.';
			                   |tr = 'Cihaz bağlanırken hata oluştu.
			                   |Fiş mali kayıtta yazdırılamadı.
			                   |Ek açıklama: %1.';
			                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
			                   |La ricevuta non è stampata nel registratore fiscale.
			                   |Descrizione aggiuntiva: %1.';
			                   |de = 'Beim Anschließen des Geräts ist ein Fehler aufgetreten.
			                   |Der Beleg wird nicht auf den Fiskalspeicher gedruckt.
			                   |Zusätzliche Beschreibung: %1.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsWithdrawal".
//
&AtClient
Procedure Withdrawal(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		WithdrawnAmount = 0;
		
		WindowTitle = NStr("en = 'Withdrawal amount'; ru = 'Сумма снятия';pl = 'Kwota wypłaty';es_ES = 'Importe del retiro';es_CO = 'Importe del retiro';tr = 'Para çekme tutarı';it = 'Importo prelievo';de = 'Abhebungsbetrag'") + ", " + "%Currency%";
		WindowTitle = StrReplace(
			WindowTitle,
			"%Currency%",
			StructureStateCashCRSession.DocumentCurrencyPresentation
		);
		
		ShowInputNumber(New NotifyDescription("CashWithdrawalEnd", ThisObject, New Structure("WithdrawnAmount", WithdrawnAmount)), WithdrawnAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsWithdrawal" after enter dredging amount.
//
&AtClient
Procedure CashWithdrawalEnd(Result1, AdditionalParameters) Export
	
	WithdrawnAmount = ?(Result1 = Undefined, AdditionalParameters.WithdrawnAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		ErrorDescription = "";
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, WithdrawnAmount);
		Else
			NotifyDescription = New NotifyDescription("CashWithdrawalFiscalRegisterConnectionsEnd", ThisObject, WithdrawnAmount);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
				NStr("en = 'Select a fiscal data recorder'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator fiskalny';es_ES = 'Seleccionar un registrador de datos fiscales';es_CO = 'Seleccionar un registrador de datos fiscales';tr = 'Mali veri kaydediciyi seçin';it = 'Selezionare un registratore fiscale';de = 'Wählen Sie einen Steuer Datenschreiber'"),
				NStr("en = 'Fiscal data recorder is not connected.'; ru = 'Фискальный регистратор не подключен.';pl = 'Rejestrator fiskalny nie jest podłączony.';es_ES = 'Registrador de datos fiscales no está conectado.';es_CO = 'Registrador de datos fiscales no está conectado.';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore dati fiscale non è connesso.';de = 'Der Steuerdatenschreiber ist nicht angeschlossen.'"));
		EndIf;
	
	EndIf;

EndProcedure

// Procedure prints receipt on FR (Encash command).
//
&AtClient
Procedure CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	WithdrawnAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
			
			// Connect FR
			Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
			);
			
			If Result Then
				
				// Prepare data
				InputParameters  = New Array();
				Output_Parameters = Undefined;
				
				InputParameters.Add(0);
				InputParameters.Add(WithdrawnAmount);
				
				// Print receipt.
				Result = EquipmentManagerClient.RunCommand(
					DeviceIdentifier,
					"Encash",
					InputParameters,
					Output_Parameters
				);
				
				If Not Result Then
					
					MessageText = NStr("en = 'When printing a receipt, an error occurred.
					                   |Receipt is not printed on the fiscal register.
					                   |Additional description: %1.'; 
					                   |ru = 'При печати чека произошла ошибка.
					                   |Чек не напечатан на фискальном регистраторе.
					                   |Дополнительное описание: %1.';
					                   |pl = 'Podczas drukowania paragonu wystąpił błąd.
					                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
					                   |Dodatkowy opis: %1.';
					                   |es_ES = 'Imprimiendo un recibo, ha ocurrido un error.
					                   |Recibo no se ha imprimido en el registro fiscal.
					                   |Descripción adicional: %1.';
					                   |es_CO = 'Imprimiendo un recibo, ha ocurrido un error.
					                   |Recibo no se ha imprimido en el registro fiscal.
					                   |Descripción adicional: %1.';
					                   |tr = 'Fiş yazdırılırken hata oluştu.
					                   |Fiş mali kayıtta yazdırılamadı.
					                   |Ek açıklama: %1.';
					                   |it = 'Si è verificato un errore durante la stampa di una ricevuta.
					                   |La ricevuta non è stampata sul registratore fiscale.
					                   |Descrizione aggiuntiva: %1.';
					                   |de = 'Beim Drucken eines Belegs ist ein Fehler aufgetreten.
					                   |Der Beleg wird nicht Fiskalspeicher gedruckt.
					                   |Zusätzliche Beschreibung: %1.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Output_Parameters[1]);
					CommonClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				// Disconnect FR
				EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Receipt is not printed on the fiscal register.
				                   |Additional description: %1.'; 
				                   |ru = 'При подключении устройства произошла ошибка.
				                   |Чек не напечатан на фискальном регистраторе.
				                   |Дополнительное описание: %1.';
				                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
				                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
				                   |Dodatkowy opis: %1.';
				                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Recibo no se ha imprimido en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Recibo no se ha imprimido en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |tr = 'Cihaz bağlanırken hata oluştu.
				                   |Fiş mali kayıtta yazdırılamadı.
				                   |Ek açıklama: %1.';
				                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
				                   |La ricevuta non è stampata nel registratore fiscale.
				                   |Descrizione aggiuntiva: %1.';
				                   |de = 'Beim Anschließen des Geräts ist ein Fehler aufgetreten.
				                   |Der Beleg wird nicht auf den  Fiskalspeicher gedruckt.
				                   |Zusätzliche Beschreibung: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
	
EndProcedure

// Procedure is called when pressing the PrintReceipt command panel button.
//
&AtClient
Procedure IssueReceiptExecute(Command, GenerateSalesReceipt = False, GenerateSimplifiedTaxInvoice = False,
	GenerateWarrantyCardPerSerialNumber = False, GenerateWarrantyCardConsolidated = False)
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	If Not StructureStateCashCRSession.SessionIsOpen Then
		CashCRSessionOpen();
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	EndIf;
	
	If ValueIsFilled(StructureStateCashCRSession.CashCRSessionStatus) Then
		FillPropertyValues(Object, StructureStateCashCRSession,, "Responsible, Department");
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
	EndIf;
	
	Cancel = False;
	
	ClearMessages();
	
	If Object.DeletionMark Then
		
		ErrorText = NStr("en = 'The document is marked for deletion'; ru = 'Документ помечен на удаление';pl = 'Dokument jest wybrany do usunięcia';es_ES = 'El documento está marcado para borrar';es_CO = 'El documento está marcado para borrar';tr = 'Belge silinmek üzere işaretlendi';it = 'Il documento è contrassegnato per l''eliminazione';de = 'Das Dokument ist zum Löschen markiert'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	If Object.DocumentAmount > Object.CashReceived + Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en = 'The payment amount is less than the receipt amount'; ru = 'Сумма оплаты меньше суммы чека';pl = 'Kwota opłaty jest niższa niż suma paragonu';es_ES = 'El importe de pago es menor al importe de recibo';es_CO = 'El importe de pago es menor al importe de recibo';tr = 'Ödeme tutarı, giriş tutarından daha küçüktür';it = 'L''importo di pagamento è inferiore all''importo della ricevuta';de = 'Der Zahlungsbetrag ist kleiner als der Belegbetrag'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	If Object.DocumentAmount < Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en = 'The amount of payment by payment cards exceeds the total of a receipt'; ru = 'Сумма оплаты платежными картами превышает сумму чека';pl = 'Kwota opłaty kartą przekracza łączną sumę paragonu';es_ES = 'El importe del pago con tarjetas de pago excede el total de un recibo';es_CO = 'El importe del pago con tarjetas de pago excede el total de un recibo';tr = 'Ödeme kartıyla ödeme tutarı, fiş toplamını aşıyor';it = 'L''importo del pagamento con carta è superiore al totale della ricevuta.';de = 'Der Betrag der Zahlung mit Zahlungskarten übersteigt den Gesamtbetrag einer Quittung'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	Object.Date = CommonClient.SessionDate();
	
	If Not Cancel AND CheckFilling() Then
		
		IssueReceipt(
			GenerateSalesReceipt,
			GenerateSimplifiedTaxInvoice,
			GenerateWarrantyCardPerSerialNumber,
			GenerateWarrantyCardConsolidated);
			
		Notify("RefreshSalesSlipDocumentsListForm");
		
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
		GenerateTitle(StructureStateCashCRSession);
		
	EndIf;
	
EndProcedure

// Procedure X report printing.
//
&AtClient
Procedure ReportPrintingWithoutBlankingExecuteEnd(DeviceIdentifier, AdditionalParameters) Export

	ErrorDescription = "";

	If DeviceIdentifier <> Undefined Then
		Result = EquipmentManagerClient.ConnectEquipmentByID(UUID,
		                                                                              DeviceIdentifier, ErrorDescription);

		If Result Then
			InputParameters  = Undefined;
			Output_Parameters = Undefined;

			Result = EquipmentManagerClient.RunCommand(DeviceIdentifier,
			                                                        "PrintXReport",
			                                                        InputParameters,
			                                                        Output_Parameters);

			If Not Result Then
				MessageText = NStr("en = 'An error occurred while getting the report from fiscal register.
				                   |%1.
				                   |Report on fiscal register is not formed.'; 
				                   |ru = 'При снятии отчета на фискальном регистраторе произошла ошибка.
				                   |%1.
				                   |Отчет на фискальном регистраторе не сформирован.';
				                   |pl = 'Wystąpił błąd podczas pobierania sprawozdania z rejestru fiskalnego.
				                   |%1.
				                   |Sprawozdanie nie zostało utworzone na rejestratorze fiskalnym.';
				                   |es_ES = 'Ha ocurrido un error obteniendo el informe del registro fiscal.
				                   |%1.
				                   |Informe del registro fiscal no se ha formado.';
				                   |es_CO = 'Ha ocurrido un error obteniendo el informe del registro fiscal.
				                   |%1.
				                   |Informe del registro fiscal no se ha formado.';
				                   |tr = 'Rapor mali kaydediciden alınırken bir hata oluştu. 
				                   | %1. 
				                   |Mali kaydedicide rapor oluşturulmadı.';
				                   |it = 'Si è verificato un errore durante il recupero del report dal registratore fiscale.
				                   |%1
				                   |Il report sul registratore fiscale non è stato creato.';
				                   |de = 'Beim Abrufen des Berichts aus dem Fiskalspeicher ist ein Fehler aufgetreten.
				                   |%1.
				                   |Ein Bericht über den Fiskalspeicher wird nicht gebildet.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Output_Parameters[1]);
				CommonClientServer.MessageToUser(MessageText);
			EndIf;

			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
		Else
			MessageText = NStr("en = 'An error occurred when connecting the device.'; ru = 'При подключении устройства произошла ошибка.';pl = 'Przy podłączeniu urządzenia wystąpił błąd.';es_ES = 'Ha ocurrido un error al conectar el dispositivo.';es_CO = 'Ha ocurrido un error al conectar el dispositivo.';tr = 'Cihaz bağlanırken hata oluştu.';it = 'Si è verificato un errore durante il collegamento del dispositivo.';de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.'") + Chars.LF + ErrorDescription;
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler "PrintReportWithoutClearing".
//
&AtClient
Procedure ReportPrintingWithoutBlankingExecute()
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		// Device connection
		NotifyDescription = New NotifyDescription("ReportPrintingWithoutBlankingExecuteEnd", ThisObject);
		MessageText = "";
		EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
			NStr("en = 'Select a fiscal data recorder'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator danych fiskalnych';es_ES = 'Seleccionar un registrador de datos fiscales';es_CO = 'Seleccionar un registrador de datos fiscales';tr = 'Mali veri kaydediciyi seçin';it = 'Selezionare un registratore fiscale';de = 'Wählen Sie einen Fiskaldatenschreiber'"), 
			NStr("en = 'Fiscal data recorder is not connected'; ru = 'Фискальный регистратор не подключен';pl = 'Rejestrator fiskalny nie jest podłączony';es_ES = 'Registrador de datos fiscales no está conectado';es_CO = 'Registrador de datos fiscales no está conectado';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore fiscale non è collegato';de = 'Der Steuerdatenschreiber ist nicht angeschlossen'"));
			
		If Not IsBlankString(MessageText) Then
			MessageText = NStr("en = 'Print X report'; ru = 'Печать X-отчета';pl = 'Drukuj RK bez zamknięcia zmiany';es_ES = 'Imprimir el informe X';es_CO = 'Imprimir el informe X';tr = 'X raporunu yazdır';it = 'Stampare X report';de = 'X-Bericht drucken'") + MessageText;
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
			
	Else
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");

		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Procedure - command handler "CloseCashCRSession".
//
&AtClient
Procedure CloseCashCRSession(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	Result = False;
	
	If Not IssuedReceiptsExist(CashCR) Then
		
		ErrorDescription = "";
		
		DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
		
		If ValueIsFilled(ErrorDescription) Then
			MessageText = NStr("en = 'Session is closed on the fiscal register, but errors occurred when generating the retail sales report.
			                   |Additional description: %1.'; 
			                   |ru = 'Смена закрыта на фискальном регистраторе, но при формировании отчета о розничных продажах возникли ошибки.
			                   |Дополнительное описание: %1.';
			                   |pl = 'Sesja została zamknięta w rejestratorze fiskalnym, ale podczas tworzenia raportu o sprzedaży detalicznej wystąpiły błędy.
			                   |Dodatkowy opis: %1.';
			                   |es_ES = 'Sesión está cerrada en el registro fiscal pero han ocurrido errores al generar el informe de ventas al por menor.
			                   |Descripción adicional: %1.';
			                   |es_CO = 'Sesión está cerrada en el registro fiscal pero han ocurrido errores al generar el informe de ventas al por menor.
			                   |Descripción adicional: %1.';
			                   |tr = 'Mali kayıtta oturum kapatıldı fakat perakende satış raporu oluşturulurken hatalar oluştu.
			                   |Ek açıklama: %1.';
			                   |it = 'La sessione è chiusa sul registratore fiscale, ma errori si sono registrati durante la generazione del report di vendita.
			                   |Descrizione aggiuntiva: %1.';
			                   |de = 'Die Sitzung ist im Fiskalspeicher geschlossen, aber beim Generieren des Einzelhandelsumsatzsberichts sind Fehler aufgetreten.
			                   |Zusätzliche Beschreibung: %1.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
		// Show all resulting documents to user.
		For Each Document In DocumentArray Do
			
			OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", Document));
			
		EndDo;
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
	
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					InputParameters  = Undefined;
					Output_Parameters = Undefined;
					
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"PrintZReport",
						InputParameters,
						Output_Parameters
					);
				EndIf;
				
				If Not Result AND Not UseWithoutEquipmentConnection Then
					
					MessageText = NStr("en = 'Error occurred when closing the session on the fiscal register.
					                   |""%1.""
					                   |Report on fiscal register is not formed.'; 
					                   |ru = 'При закрытии смены на фискальном регистраторе произошла ошибка.
					                   |""%1.""
					                   |Отчет на фискальном регистраторе не сформирован.';
					                   |pl = 'Wystąpił błąd podczas zamykania sesji w rejestratorze fiskalnym.
					                   |""%1.""
					                   |Raport na rejestratorze fiskalnym nie był utworzony.';
					                   |es_ES = 'Error ocurrido al cerrar la sesión en el registro fiscal.
					                   |""%1.""
					                   |Informe del registro fiscal no se ha formado.';
					                   |es_CO = 'Error ocurrido al cerrar la sesión en el registro fiscal.
					                   |""%1.""
					                   |Informe del registro fiscal no se ha formado.';
					                   |tr = 'Mali kayıtta oturum kapatılırken hata oluştu.
					                   |""%1""
					                   |Mali kayıt raporu oluşturulamadı.';
					                   |it = 'Si è verificato un errore durante la chiusura della sessione sul registratore fiscale.
					                   |""%1.""
					                   |Il report sul registratore fiscale non è stato creato.';
					                   |de = 'Beim Schließen der Sitzung im Fiskalspeicher ist ein Fehler aufgetreten.
					                   |""%1.""
					                   |Bericht über den Fiskalspeicher wird nicht gebildet.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Output_Parameters[1]);
					CommonClientServer.MessageToUser(MessageText);
					
				Else
					
					DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
					
					If ValueIsFilled(ErrorDescription)
					   AND UseWithoutEquipmentConnection Then
						
						CommonClientServer.MessageToUser(ErrorDescription);
						
					ElsIf ValueIsFilled(ErrorDescription)
						 AND Not UseWithoutEquipmentConnection Then
						
						MessageText = NStr("en = 'Session is closed on the fiscal register, but errors occurred when generating the retail sales report.
						                   |Additional description: %1.'; 
						                   |ru = 'Смена закрыта на фискальном регистраторе, но при формировании отчета о розничных продажах возникли ошибки.
						                   |Дополнительное описание: %1.';
						                   |pl = 'Sesja została zamknięta w rejestratorze fiskalnym, ale podczas tworzenia raportu o sprzedaży detalicznej wystąpiły błędy.
						                   |Dodatkowy opis: %1.';
						                   |es_ES = 'Sesión está cerrada en el registro fiscal pero han ocurrido errores al generar el informe de ventas al por menor.
						                   |Descripción adicional: %1.';
						                   |es_CO = 'Sesión está cerrada en el registro fiscal pero han ocurrido errores al generar el informe de ventas al por menor.
						                   |Descripción adicional: %1.';
						                   |tr = 'Mali kayıtta oturum kapatıldı fakat perakende satış raporu oluşturulurken hatalar oluştu.
						                   |Ek açıklama: %1.';
						                   |it = 'La sessione è chiusa sul registratore fiscale, ma errori si sono registrati durante la generazione del report di vendita.
						                   |Descrizione aggiuntiva: %1.';
						                   |de = 'Die Sitzung ist im Fiskalspeicher geschlossen, aber beim Generieren des Einzelhandelsumsatzsberichts sind Fehler aufgetreten.
						                   |Zusätzliche Beschreibung: %1.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
						CommonClientServer.MessageToUser(MessageText);
						
					EndIf;
					
					// Show all resulting documents to user.
					For Each Document In DocumentArray Do
						
						OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", Document));
						
					EndDo;
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Report is not printed and session is not closed on the fiscal register.
				                   |Additional description: %1.'; 
				                   |ru = 'При подключении устройства произошла ошибка.
				                   |Отчет не напечатан и смена не закрыта на фискальном регистраторе.
				                   |Дополнительное описание: %1.';
				                   |pl = 'Podczas podłączenia urządzenia wystąpił błąd.
				                   |Raport nie został wydrukowany i rejestrator fiskalny nie zamknął sesji.
				                   |Dodatkowy opis: %1.';
				                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Informe no se ha imprimido y la sesión no está cerrada en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Informe no se ha imprimido y la sesión no está cerrada en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |tr = 'Cihaz bağlanırken hata oluştu.
				                   |Rapor yazdırılamadı ve mali kayıtta oturum kapatılamadı.
				                   |Ek açıklama: %1.';
				                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
				                   |Il report non viene stampato e la sessione non è chiusa sul registratore fiscale.
				                   |Descrizione aggiuntiva: %1.';
				                   |de = 'Beim Anschließen des Geräts ist ein Fehler aufgetreten.
				                   |Der Bericht wird nicht gedruckt und die Sitzung wird im Fiskalspeicher nicht geschlossen.
				                   |Zusätzliche Beschreibung: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'"
		);
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	InitializeNewReceipt();
	
	Items.List.Refresh();
	
	Notify("RefreshFormsAfterZReportIsDone");
	
EndProcedure

&AtServerNoContext
Function GetLatestClosedCashCRSession()

	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED TOP 1
		|	ShiftClosure.Ref
		|FROM
		|	Document.ShiftClosure AS ShiftClosure
		|WHERE
		|	ShiftClosure.Posted
		|	AND ShiftClosure.CashCRSessionStatus <> &CashCRSessionStatus
		|
		|ORDER BY
		|	ShiftClosure.PointInTime DESC";
	
	Query.SetParameter("CashCRSessionStatus", Enums.ShiftClosureStatus.IsOpen);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		Return Documents.ShiftClosure.EmptyRef();
	EndIf;
	
EndFunction

&AtServer
Function EnterParametersForCancellingSalesSlip()
	
	// Preparation of the common parameters table
	ReceiptType = 0; //?(TypeOf(SalesSlip) = Type("DocumentRef.ProductReturn."), 1, 0);
	CommonParameters = New Array();
	CommonParameters.Add(ReceiptType);                //  1 - Receipt type
	CommonParameters.Add(True);                 //  2 - Fiscal receipt sign
	
	Return CommonParameters;
	
EndFunction

// Receipt cancellation procedure on fiscal register.
//
&AtClient
Function CancelSalesSlip(CashCR)
	
	ReceiptIsCanceled = False;
	
	ErrorDescription = "";
	
	CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
	DeviceIdentifierFR              = CashRegistersSettings.DeviceIdentifier;
	
	UseCashRegisterWithoutPeripheral = CashRegistersSettings.UseWithoutEquipmentConnection;
	
	If Not UsePeripherals 
		OR UseCashRegisterWithoutPeripheral Then
		ReceiptIsCanceled = True;
		Return ReceiptIsCanceled;
	EndIf;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
	
		
		If DeviceIdentifierFR <> Undefined Then
			
			// Connect FR
			Result = EquipmentManagerClient.ConnectEquipmentByID(ThisObject,
			                                                                              DeviceIdentifierFR,
			                                                                              ErrorDescription);
			
			If Result Then   
				
				// Prepare data
				InputParameters  = EnterParametersForCancellingSalesSlip();
				Output_Parameters = Undefined;
				
				Result = EquipmentManagerClient.RunCommand(
					DeviceIdentifierFR,
					"OpenCheck",
					InputParameters,
					Output_Parameters);
					
				If Result Then
					SessionNumberCR = Output_Parameters[0];
					SalesSlipNumber  = Output_Parameters[1]; 
					Output_Parameters = Undefined;
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifierFR,
						"CancelCheck",
						InputParameters,
						Output_Parameters);
				EndIf;
				
				If Result Then
					ReceiptIsCanceled = True;
				Else
					MessageText = NStr("en = 'When cancellation receipt there was error.
					                   |Receipt is not cancelled on fiscal register.
					                   |Additional description: %1.'; 
					                   |ru = 'При аннулировании чека произошла ошибка.
					                   |Чек не аннулирован на фискальном регистраторе.
					                   |Дополнительное описание: %1.';
					                   |pl = 'Podczas anulowania paragonu wystąpił błąd.
					                   |Rejestrator fiskalny nie anulował paragonu.
					                   |Dodatkowy opis: %1.';
					                   |es_ES = 'Cancelando el recibo, se ha producido un error.
					                   |Recibo no se ha cancelado en el registro fiscal.
					                   |Descripción adicional:%1.';
					                   |es_CO = 'Cancelando el recibo, se ha producido un error.
					                   |Recibo no se ha cancelado en el registro fiscal.
					                   |Descripción adicional:%1.';
					                   |tr = 'Fiş iptalinde hata oluştu.
					                   |Fiş, mali kayıtta iptal edilemedi.
					                   |Ek açıklama: %1.';
					                   |it = 'Durante la cancellazione della ricevuta c''è stato un errore.
					                   |La ricevuta non è stata annullata nel registratore fiscale.
					                   |Descrizione aggiuntiva: %1.';
					                   |de = 'Beim stornieren des Belegs war ein Fehler aufgetreten.
					                   |Der Beleg wird im Fiskalspeicher nicht storniert.
					                   |Zusätzliche Beschreibung: %1.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Output_Parameters[1]);
					CommonClientServer.MessageToUser(MessageText);
				EndIf;
				
				// Disconnect FR
				EquipmentManagerClient.DisableEquipmentById(ThisObject, DeviceIdentifierFR);
				
			Else
				MessageText = NStr("en = 'An error occurred when connecting the device. Receipt is not cancelled on fiscal register.
				                   |Additional description: %1.'; 
				                   |ru = 'При подключении устройства произошла ошибка. Чек не аннулирован на фискальном регистраторе.
				                   |Дополнительное описание: %1.';
				                   |pl = 'Podczas podłączenia urządzenia wystąpił błąd. Rejestrator fiskalny nie anulował paragonu.
				                   |Dodatkowy opis: %1.';
				                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo. Recibo no se ha cancelado en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo. Recibo no se ha cancelado en el registro fiscal.
				                   |Descripción adicional: %1.';
				                   |tr = 'Cihaz bağlanırken hata oluştu. Fiş mali kayıtta iptal edilemedi.
				                   |Ek açıklama: %1.';
				                   |it = 'Si è verificato un errore durante il collegamento del dispositivo. La ricevuta non è stata annullata nel registratore fiscale.
				                   |Descrizione aggiuntiva: %1.';
				                   |de = 'Beim Anschließen des Geräts ist ein Fehler aufgetreten. Der Beleg wird im Fiskalspeicher nicht storniert.
				                   |Zusätzliche Beschreibung: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
			
		Else
			MessageText = NStr("en = 'Fiscal data recorder is not selected.'; ru = 'Не выбран фискальный регистратор.';pl = 'Nie wybrano rejestratora danych fiskalnych.';es_ES = 'Registrador de datos fiscales no se ha seleccionado.';es_CO = 'Registrador de datos fiscales no se ha seleccionado.';tr = 'Mali veri kaydedici seçilmedi.';it = 'Il registratore fiscale non è selezionato.';de = 'Fiskal-Datenschreiber ist nicht ausgewählt.'");
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	Else
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ReceiptIsCanceled;
	
EndFunction

// Procedure - command handler ReceiptCancellation form.
//
&AtClient
Procedure ReceiptCancellation(Command)
	
	NotifyDescription = New NotifyDescription("ReceiptCancellationEnd", ThisObject);
	ShowQueryBox(NotifyDescription,
	NStr("en = 'Do you want to cancel the last receipt?'; ru = 'Отменить последнее поступление?';pl = 'Czy chcesz anulować ostatnie potwierdzenie?';es_ES = '¿Quiere cancelar el último recibo?';es_CO = '¿Quiere cancelar el último recibo?';tr = 'Son fişi iptal etmek istiyor musunuz?';it = 'Volete annullare l''ultima ricevuta?';de = 'Möchten Sie die letzte Quittung stornieren?'"),
	QuestionDialogMode.YesNo,, DialogReturnCode.No);
	
EndProcedure

// Procedure - command handler ReceiptCancellation form. It is called after cancellation confirmation in issue window.
//
&AtClient
Procedure ReceiptCancellationEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		CancelSalesSlip(CashCR);
	EndIf;

EndProcedure

// Procedure - command handler PrintCopyOnFiscalRegister form.
//
&AtClient
Procedure PrintCopyOnFiscalRegistrar(Command)
	
	If Not UsePeripherals Then
		
		MessageText = NStr("en = 'Cannot print the sales slip. Peripherals are not used.'; ru = 'Не удалось напечатать кассовый чек. Подключаемое оборудование не используется.';pl = 'Nie można wydrukować pokwitowania sprzedaży. Urządzenie peryferyjne nie jest włączone.';es_ES = 'No se puede imprimir el comprobante de ventas. Periféricos no están utilizados.';es_CO = 'No se puede imprimir el comprobante de ventas. Periféricos no están utilizados.';tr = 'Satış fişi yazdırılamıyor. Çevre birimleri kullanılmıyor.';it = 'Non è possibile stampare la ricevuta. Le periferiche non vengono utilizzate.';de = 'Der Kassenbon kann nicht gedruckt werden. Peripheriegeräte werden nicht verwendet.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device selection FR
		NotifyDescription = New NotifyDescription("PrintCopyOnFiscalRegistrarEnd", ThisObject);
		MessageText = "";
		EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
			NStr("en = 'Select a fiscal data recorder'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator danych fiskalnych';es_ES = 'Seleccionar un registrador de datos fiscales';es_CO = 'Seleccionar un registrador de datos fiscales';tr = 'Mali veri kaydediciyi seçin';it = 'Selezionare un registratore fiscale';de = 'Wählen Sie einen Fiskaldatenschreiber'"),
			NStr("en = 'Fiscal data recorder is not connected'; ru = 'Фискальный регистратор не подключен';pl = 'Rejestrator fiskalny nie jest podłączony';es_ES = 'Registrador de datos fiscales no está conectado';es_CO = 'Registrador de datos fiscales no está conectado';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore fiscale non è collegato';de = 'Der Steuerdatenschreiber ist nicht angeschlossen'"));
		If Not IsBlankString(MessageText) Then
			MessageText = NStr("en = 'Print the last sales slip'; ru = 'Напечатать последний кассовый чек';pl = 'Druk ostatniego potwierdzenia sprzedaży';es_ES = 'Imprimir el último recibo de compra';es_CO = 'Imprimir el último recibo de compra';tr = 'En son satış fişini yazdır';it = 'Stampa l''ultimo scontrino';de = 'Den letzten Kassenzettel ausdrucken'") + MessageText;
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	Else
		MessageText = NStr("en = 'Fiscal data recorder is not connected'; ru = 'Фискальный регистратор не подключен';pl = 'Rejestrator fiskalny nie jest podłączony';es_ES = 'Registrador de datos fiscales no está conectado';es_CO = 'Registrador de datos fiscales no está conectado';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore fiscale non è collegato';de = 'Der Steuerdatenschreiber ist nicht angeschlossen'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Procedure - command handler PrintCopyOnFiscalRegister form. Performs receipt printing on FR.
//
&AtClient
Procedure PrintCopyOnFiscalRegistrarEnd(DeviceIdentifierFR, Parameters) Export
	
	If DeviceIdentifierFR <> Undefined Then 
		
		ErrorDescription  = "";
		// FR device connection
		ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
			DeviceIdentifierFR,
			ErrorDescription);
			
		If ResultFR Then
			If Not IsBlankString(glPeripherals.LastSlipReceipt) Then
				InputParameters = New Array();
				InputParameters.Add(glPeripherals.LastSlipReceipt);
				Output_Parameters = Undefined;
				
				ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
					"PrintText",
					InputParameters,
				    Output_Parameters);
					
				If Not ResultFR Then
					MessageText = NStr(
						"en = 'An error occurred when printing a sales slip: ""%1.""'; ru = 'При печати кассового чека возникла ошибка: ""%1.""';pl = 'Wystąpił błąd podczas drukowania paragonu kasowego: ""%1.""';es_ES = 'Ha ocurrido un error al imprimir el comprobante de ventas: ""%1.""';es_CO = 'Ha ocurrido un error al imprimir el comprobante de ventas: ""%1.""';tr = 'Satış fişi yazdırılırken hata oluştu: ""%1""';it = 'Si è verificato un errore durante la stampa di uno scontrino di vendita: ""%1.""';de = 'Beim Drucken eines Kassenzettels ist ein Fehler aufgetreten: ""%1.""'"); 
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Output_Parameters[1]);
					CommonClientServer.MessageToUser(MessageText);
				EndIf;
			EndIf;
			
			// FR device disconnect
			EquipmentManagerClient.DisableEquipmentById(UUID,
			                                                                 DeviceIdentifierFR);
		Else
			MessageText = NStr("en = 'The fiscal printer connection error:
                                |""%1"".
                                |The Sales slip has not been printed.'; 
                                |ru = 'Ошибка подключения фискального принтера:
                                |""%1"".
                                |Кассовый чек не распечатан.';
                                |pl = 'Błąd podłączenia drukarki fiskalnej:
                                |""%1"".
                                |Paragon kasowy nie został wydrukowany.';
                                |es_ES = 'Error de conexión de la impresora fiscal:
                                |""%1"".
                                |No se ha imprimido el recibo de venta.';
                                |es_CO = 'Error de conexión de la impresora fiscal:
                                |""%1"".
                                |No se ha imprimido el recibo de venta.';
                                |tr = 'Mali yazıcı bağlantı hatası.
                                |""%1"".
                                |Satış fişi yazdırılamadı.';
                                |it = 'Errore di connessione della stampante fiscale:
                                |""%1"".
                                |Lo Scontrino di vendita non è stato stampato.';
                                |de = 'Der Verbindungsfehler des Steuerdruckers:
                                |""%1"".
                                |Der Kassenbeleg ist nicht ausgedruckt.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure sets mode Only view.
//
&AtServer
Procedure SetModeReadOnly()
	
	ReadOnly = True; // Receipt is issued. Change information is forbidden.
	
	Items.AcceptPayment.Enabled					= False;
	Items.PricesAndCurrency.Enabled				= False;
	Items.InventoryWeight.Enabled				= False;
	Items.InventorySelect.Enabled				= False;
	Items.InventoryImportDataFromDCT.Enabled	= False;
	
EndProcedure

// Procedure sets the receipt print availability.
//
&AtServer
Procedure SetEnabledOfReceiptPrinting()
	
	If Object.Status = Enums.SalesSlipStatus.ProductReserved
	 OR Object.CashCR.UseWithoutEquipmentConnection
	 OR ControlAtWarehouseDisabled Then
		Items.AcceptPayment.Enabled = True;
	Else
		Items.AcceptPayment.Enabled = True; // False;
	EndIf;
	
EndProcedure

// Procedure sets button headings and key combinations for form commands.
//
&AtServer
Procedure ConfigureButtonsAndMenuCommands()
	
	If Not ValueIsFilled(CWPSetting) Then
		// We issue message in procedure "FillFastGoods()".
		Return;
	EndIf;
	
	DontShowOnOpenCashdeskChoiceForm = CWPSetting.DontShowOnOpenCashdeskChoiceForm;
	
	For Each CurrentSettingCommandButtons In CWPSetting.LowerBarButtons Do
		Try
			
			If CurrentSettingCommandButtons.ButtonName = "ProductsSearchValue" Then
				If ValueIsFilled(CurrentSettingCommandButtons.Key) Then
					Items.ProductsSearchValue.Shortcut	= New Shortcut(Key[CurrentSettingCommandButtons.Key], CurrentSettingCommandButtons.Alt,
						CurrentSettingCommandButtons.Ctrl, CurrentSettingCommandButtons.Shift);
					Items.ProductsSearchValue.InputHint	= StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Enter name, code or SKU %1'; ru = 'Введите имя, код или артикул %1';pl = 'Wprowadź nazwę, kod lub kod artykułu %1';es_ES = 'Introducir el nombre, el código o el SKU %1';es_CO = 'Introducir el nombre, el código o el SKU %1';tr = 'İsim, kod veya SKU girin %1';it = 'Inserire nome, codice o SKU %1';de = 'Name, Code oder SKU eingeben %1'"),
						ShortcutPresentation(Items.ProductsSearchValue.Shortcut, False));
				Else
					Items.ProductsSearchValue.Shortcut	= New Shortcut(Key.None);
					Items.ProductsSearchValue.InputHint	= 
						NStr("en = 'Enter name, code or SKU'; ru = 'Введите имя, код или артикул';pl = 'Wprowadź nazwę, kod lub kod artykułu';es_ES = 'Introducir el nombre, el código o el SKU';es_CO = 'Introducir el nombre, el código o el SKU';tr = 'İsim, kod veya SKU girin';it = 'Inserire nome, codice o SKU';de = 'Name, Code oder SKU eingeben'");
				EndIf;
			Else
				CurrentButton	= Items[CurrentSettingCommandButtons.ButtonName];
				CurrentCommand	= Commands[CurrentSettingCommandButtons.CommandName];
				
				If ValueIsFilled(CurrentSettingCommandButtons.ButtonName) Then
					
					CurrentButton.Title = CurrentSettingCommandButtons.ButtonTitle;
					
					If CurrentSettingCommandButtons.ButtonName = "ShowJournal" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(0).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					ElsIf CurrentSettingCommandButtons.ButtonName = "ShowQuickSales" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(1).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					ElsIf CurrentSettingCommandButtons.ButtonName = "ShowMyPettyCash" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(2).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					EndIf;
					
				EndIf;
				
				If ValueIsFilled(CurrentSettingCommandButtons.Key) Then
					CurrentCommand.Shortcut = New Shortcut(Key[CurrentSettingCommandButtons.Key], CurrentSettingCommandButtons.Alt,
						CurrentSettingCommandButtons.Ctrl, CurrentSettingCommandButtons.Shift);
				Else
					CurrentCommand.Shortcut = New Shortcut(Key.None);
				EndIf;
			EndIf;
			
		Except
			CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error is occurred when button and menu command setting. %1.'; ru = 'Произошла ошибка при настройке кнопок и команд меню. %1.';pl = 'Podczas konfiguracji przycisków i poleceń wystąpił błąd. %1.';es_ES = 'Ha ocurrido un error configurando el comando de botones y del menú. %1.';es_CO = 'Ha ocurrido un error configurando el comando de botones y del menú. %1.';tr = 'Tuş ve menü komut ayarı yapıldığında hata oluştu.%1';it = 'Si è registrato un errore durante l''impostazione del pulsante e del menu di comando. %1';de = 'Bei der Einstellung der Tasten- und Menübefehle ist ein Fehler aufgetreten. %1.'"),
				ErrorDescription()));
		EndTry;
	EndDo;
	
EndProcedure

// Procedure - event handler Click item GroupbyExpandSalesSidePanel form.
//
&AtClient
Procedure GroupbyExpandSalesSidePanelClick(Item)
	
	GroupbyExpandSideSalePanelClickAtServer();
	
EndProcedure

// Procedure - event handler Click item GroupbyExpandSalesSidePanel on server.
//
&AtServer
Procedure GroupbyExpandSideSalePanelClickAtServer()
	
	If Items.ExpandGroupbySalesSidePanel.Title = ">>" Then
		Items.SidePanelSales.Visible = False;
		Items.ExpandGroupbySalesSidePanel.Title = "<<";
		Items.ExpandGroupbySalesSidePanel.Picture = PictureLib.CWP_ExpandAdditionalPanel;
	Else
		Items.SidePanelSales.Visible = True;
		Items.ExpandGroupbySalesSidePanel.Title = ">>";
		Items.ExpandGroupbySalesSidePanel.Picture = PictureLib.CWP_MinimizeAdditionalPanel;
	EndIf;
	
EndProcedure

// Procedure - event handler Click item GroupbySidePanelRefunds form.
//
&AtClient
Procedure GroupbySidePanelRefundsClick(Item)
	
	GroupbySidePanelRefundsClickAtServer();
	
EndProcedure

// Procedure - event handler Click item GroupbySidePanelRefunds on server.
//
&AtServer
Procedure GroupbySidePanelRefundsClickAtServer()
	
	If Items.GroupbySidePanelRefunds.Title = ">>" Then
		Items.SidePanelRefunds.Visible = False;
		Items.GroupbySidePanelRefunds.Title = "<<";
		Items.GroupbySidePanelRefunds.Picture = PictureLib.CWP_ExpandAdditionalPanel;
	Else
		Items.SidePanelRefunds.Visible = True;
		Items.GroupbySidePanelRefunds.Title = ">>";
		Items.GroupbySidePanelRefunds.Picture = PictureLib.CWP_MinimizeAdditionalPanel;
	EndIf;
	
EndProcedure

// Procedure changes page visible on which DEAL displays.
//
&AtServer
Procedure ShowHideDealAtServer(Show = True, Check = False)
	
	If Not Check OR Not Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow Then
		ChangeRow = "Deal: "+Change+" "+Object.DocumentCurrency;
		
		If Show Then
			Items.PagesDataOnRowAndChange.CurrentPage = Items.PageChange;
		Else
			Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure changes page visible on which DEAL displays.
//
&AtClient
Procedure ShowHideDealAtClient()
	
	If Not Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow Then
		ShowHideDealAtServer(False);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresFormEventsHandlers

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	// CWP
	CashCR = Parameters.CashCR;
	If Not ValueIsFilled(CashCR) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cash register is not determined for the user.'; ru = 'Для пользователя не определена Касса ККМ!';pl = 'Dla użytkownika nie określono kasy fiskalnej.';es_ES = 'Caja registradora no está determinada para el usuario.';es_CO = 'Caja registradora no está determinada para el usuario.';tr = 'Kullanıcı için yazar kasa belirlenmemiştir.';it = 'Il registratore di cassa non è definito per l''utente.';de = 'Die Kasse wird für den Benutzer nicht ermittelt.'");
		Message.Message();
		Cancel = True;
		Return;
	EndIf;
	
	User = Users.CurrentUser();
	
	PreviousCashCR = CashCR;
	CashCRUseWithoutEquipmentConnection = CashCR.UseWithoutEquipmentConnection;
	
	Object.POSTerminal = Parameters.POSTerminal;
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	FillPropertyValues(Object, StructureStateCashCRSession);
	BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
	BalanceInCashierRow = ""+BalanceInCashier;
	
	Object.CashCR = CashCR;
	Object.StructuralUnit = CashCR.StructuralUnit;
	Object.PriceKind = CashCR.StructuralUnit.RetailPriceKind;
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = CashCR.CashCurrency;
	EndIf;
	Object.Company = Object.CashCR.Owner;
	Object.Department = Object.CashCR.Department;
	Object.Responsible = DriveReUse.GetValueByDefaultUser(User, "MainResponsible");
	// End CWP
	
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, "CompanyVATNumber", False);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If Not ValueIsFilled(Object.Ref) Then
		GetChoiceListOfPaymentCardKinds();
	EndIf;
	
	UsePeripherals = DriveReUse.UsePeripherals();
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	
	ControlAtWarehouseDisabled = Not Constants.CheckStockBalanceOnPosting.Get()
						   OR Not Constants.CheckStockBalanceWhenIssuingSalesSlips.Get();
	
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	ExchangeRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
		
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, DriveServer.GetPresentationCurrency(Object.Company), Object.Company);
	RateNationalCurrency = StructureByCurrency.Rate;
	RepetitionNationalCurrency = StructureByCurrency.Repetition;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
	EndIf;
	
	SetAccountingPolicyValues();

	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetEnabledOfReceiptPrinting();
	
	Items.InventoryAmountDiscountsMarkups.Visible = Constants.UseManualDiscounts.Get();
	
	If Object.Status = Enums.SalesSlipStatus.Issued
	AND Not CashCRUseWithoutEquipmentConnection Then
		SetModeReadOnly();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  	= Not AllowedEditDocumentPrices;
	Items.InventoryAmountDiscountsMarkups.ReadOnly 	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	// Bundles
	BundlesOnCreateAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		RefreshBundlePictures(Object.Inventory);
		RefreshBundleAttributes(Object.Inventory);
		
	EndIf;
	
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// CWP
	SessionIsOpen = Enums.ShiftClosureStatus.IsOpen;
	
	List.Parameters.SetParameterValue("CashCR", CashCR);
	List.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	List.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	List.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	List.Parameters.SetParameterValue("FilterByChange", False);
	List.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	SalesSlipList.Parameters.SetParameterValue("CashCR", CashCR);
	SalesSlipList.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	SalesSlipList.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	SalesSlipList.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	SalesSlipList.Parameters.SetParameterValue("FilterByChange", False);
	SalesSlipList.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	SalesSlipListForReturn.Parameters.SetParameterValue("CashCR", CashCR);
	SalesSlipListForReturn.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	SalesSlipListForReturn.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	SalesSlipListForReturn.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	SalesSlipListForReturn.Parameters.SetParameterValue("FilterByChange", False);
	SalesSlipListForReturn.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	GenerateTitle(StructureStateCashCRSession);
	
	// Fast goods and settings buttons and menu commands.
	FillFastGoods(True);
	ConfigureButtonsAndMenuCommands();
	
	ImportantButtonsColor = StyleColors.UnavailableTabularSectionTextColor;
	UnavailableButtonColor = StyleColors.UnavailableButton;
	
	// Period kinds.
	ForCurrentShift = Enums.CWPPeriodTypes.ForCurrentShift;
	ForUserDefinedPeriod = Enums.CWPPeriodTypes.ForUserDefinedPeriod;
	ForYesterday = Enums.CWPPeriodTypes.ForYesterday;
	ForEntirePeriod = Enums.CWPPeriodTypes.ForEntirePeriod;
	ForPreviousShift = Enums.CWPPeriodTypes.ForPreviousShift;
	
	FillPeriodKindLists();
	
	SetPeriodAtServer(ForCurrentShift, "SalesSlipList");
	SetPeriodAtServer(ForCurrentShift, "SalesSlipListForReturn");
	SetPeriodAtServer(ForCurrentShift, "List");
	
	SwitchJournalQuickProducts = 1;
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession);
	
	ProductsTypeInventory = Enums.ProductsTypes.InventoryItem;
	ProductsTypeService = Enums.ProductsTypes.Service;
	// End CWP
	
	SetConditionalAppearance();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	GetChoiceListOfPaymentCardKinds();
	
EndProcedure

// Procedure - OnOpen form event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarcodeScanner,CustomerDisplay");
	// End Peripherals
	
	FillAmountsDiscounts();
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer form.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		If ValueIsFilled(Object.Ref) Then
			UsePostingMode = PostingModeUse.Regular;
		EndIf;
	EndIf;
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("ShowMessages", False);
	WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)
	
	// AutomaticDiscounts Display the message about discount calculation when user clicks the "Post and close" button or
	// closes the form by the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("en = 'Update:'; ru = 'Изменение:';pl = 'Zaktualizuj:';es_ES = 'Actualizar:';es_CO = 'Actualizar:';tr = 'Güncelle:';it = 'Aggiornamento:';de = 'Aktualisieren:'"), 
		GetURL(Object.Ref), 
		String(Object.Ref) + NStr("en = '. The automatic discounts are calculated.'; ru = '. Автоматические скидки рассчитаны.';pl = '. Obliczono rabaty automatyczne.';es_ES = '. Los descuentos automáticos se han calculado.';es_CO = '. Los descuentos automáticos se han calculado.';tr = '. Otomatik indirimler hesaplandı.';it = '. Sconti automatici sono stati applicati.';de = '. Die automatischen Rabatte werden berechnet.'"), 
		PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	If NOT Exit Then
		CashierWorkplaceServerCall.UpdateCashierWorkplaceSettings(CWPSetting, DontShowOnOpenCashdeskChoiceForm);
	EndIf;
	// CWP
		
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

// Procedure - event handler BeforeWrite form.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text = NStr("en = 'The automatic discounts are applied.'; ru = 'Рассчитаны автоматические скидки (наценки)!';pl = 'Stosowane są rabaty automatyczne.';es_ES = 'Los descuentos automáticos se han aplicado.';es_CO = 'Los descuentos automáticos se han aplicado.';tr = 'Otomatik indirimler uygulandı.';it = '. Sconti automatici sono stati applicati.';de = 'Die automatischen Rabatte werden angewendet.'");
			Message.DataKey = Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// AutomaticDiscounts
	If DiscountsCalculatedBeforeWrite Then
		RecalculateDocumentAtClient();
	EndIf;
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	// End Bundles
	
EndProcedure

// Procedure - event handler AfterWriteAtServer form.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
	// Bundles
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
		AND IsInputAvailable() AND Not DiscountCardRead Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
			
		EndIf;
	EndIf;
	// End Peripherals
	
	// DiscountCards
	If DiscountCardRead Then
		DiscountCardRead = False;
	EndIf;
	// End DiscountCards
	
	If EventName = "RefreshSalesSlipDocumentsListForm" Then
		
		For Each CurRow In Object.Inventory Do
			
			CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
			
		EndDo;
		
	EndIf;
	
	If EventName = "RefreshSalesSlipDocumentsListForm" Then
		Items.List.Refresh();
		
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
	EndIf;
	
	If EventName = "ProductsIsAddedFromCWP" AND ValueIsFilled(Parameter) Then
		CurrentData = Items.Inventory.CurrentData;
		If CurrentData <> Undefined Then
			If Not ValueIsFilled(CurrentData.Products) Then
				CurrentData.Products = Parameter;
				ProductsOnChange(CurrentData);
				RecalculateDocumentAtClient();
			EndIf;
		EndIf;
	EndIf;
	
	If EventName = "CWPSettingChanged" Then
		If CWPSetting = Parameter Then
			FillFastGoods();
			ConfigureButtonsAndMenuCommands();
		EndIf;
	EndIf;
	
	If EventName = "CWP_Write_CreditNote" Then
		Items.CreateCreditNote.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		Items.CreateCPVBasedOnReceipt.TextColor = New Color;
		CreditNote = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		TitlePresentation = NStr("en = 'Credit note'; ru = 'Кредитовое авизо';pl = 'Nota kredytowa';es_ES = 'Nota de crédito';es_CO = 'Nota de haber';tr = 'Alacak dekontu';it = 'Nota di credito';de = 'Gutschrift'");
		Items.DecorationCreditNote.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 #%2 dated %3'; ru = '%1 №%2 от %3';pl = '%1 #%2 z dn. %3';es_ES = '%1 #%2 fechado %3';es_CO = '%1 #%2 fechado %3';tr = '%1 sayılı %2 tarihli %3';it = '%1 #%2 con data %3';de = '%1 Nr %2 datiert %3'"),
			TitlePresentation,
			DocumentNumber,
			Format(Parameter.Date, "DLF=D"));
		Items.DecorationCreditNote.Visible = True;
		AttachIdleHandler("SalesSlipListOnActivateRowIdleProcessing", 0.3, True);
	ElsIf EventName = "CWP_Record_CPV" Then
		Items.CreateCPVBasedOnReceipt.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		Items.CreateGoodsReceipt.TextColor = New Color;
		CPV = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		Items.DecorationCPV.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cash voucher #%1 dated %2.'; ru = 'РКО №%1 от %2 г.';pl = 'Dowód kasowy KW nr %1 z dn. %2.';es_ES = 'Vale de efectivo #%1 fechado %2.';es_CO = 'Vale de efectivo #%1 fechado %2.';tr = '%1 numaralı, %2 tarihli kasa fişi.';it = 'Uscita di cassa #%1 con data %2.';de = 'Kassenbeleg Nr. %1 vom %2.'"),
			TrimAll(DocumentNumber),
			Format(Parameter.Date, "DLF=D"));
		Items.DecorationCPV.Visible = True;
	ElsIf EventName = "CWP_Write_GoodsReceipt" Then
		Items.CreateGoodsReceipt.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		GoodsReceipt = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		TitlePresentation = NStr("en = 'Goods receipt'; ru = 'Поступление товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Recibo de mercancías';es_CO = 'Recibo de mercancías';tr = 'Ambar girişi';it = 'Ricezione merce';de = 'Wareneingang'");
		Items.DecorationGoodsReceipt.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 #%2 dated %3'; ru = '%1 №%2 от %3';pl = '%1 #%2 z dn. %3';es_ES = '%1 #%2 fechado %3';es_CO = '%1 #%2 fechado %3';tr = '%1 sayılı %2 tarihli %3';it = '%1 #%2 con data %3';de = '%1 Nr %2 datiert %3'"),
			TitlePresentation,
			DocumentNumber,
			Format(Parameter.Date, "DLF=D"));
		Items.DecorationGoodsReceipt.Visible = True;
		AttachIdleHandler("SalesSlipListOnActivateRowIdleProcessing", 0.3, True);
		
	ElsIf EventName = "CWP_Write_ProductReturn" Then
		SalesSlipForReturn = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		Items.DecorationSalesSlipForReturn.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Return slip #%1 dated %2.'; ru = 'Чек возврата №%1 от %2 г.';pl = 'Zwrot #%1 z dn. %2.';es_ES = 'Comprobante de la devolución #%1 fechado %2.';es_CO = 'Comprobante de la devolución #%1 fechado %2.';tr = '%1 tarihli # %2 sayılı iade fişi.';it = 'Scontrino di restituzione #%1 datato %2.';de = 'Rückschein Nr %1 datiert %2.'"),
			DocumentNumber,
			Format(Parameter.Date, "DLF=D"));
		Items.CreateSalesSlipForReturn.TextColor = UnavailableButtonColor;
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf;
	EndIf;
	
	If EventName = "RefreshFormsAfterZReportIsDone" Then
		UpdateLabelVisibleTimedOutOver24Hours();
	EndIf;
	
	// Bundles
	If BundlesClient.ProcessNotifications(ThisObject, EventName, Source) Then
		RefreshBundleComponents(Parameter.BundleProduct, Parameter.BundleCharacteristic, Parameter.Quantity, Parameter.BundleComponents);
		ActionsAfterDeleteBundleLine();
	EndIf;
	// End Bundles
	
EndProcedure

&AtServer
Procedure UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession = Undefined)

	Date = CurrentSessionDate();
	
	If StructureStateCashCRSession = Undefined Then
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	EndIf;
	
	SetLabelVisible = False;
	If StructureStateCashCRSession.SessionIsOpen Then
		MessageText = NStr("en = 'Register shift is opened'; ru = 'Кассовая смена открыта';pl = 'Zmiana kasowa otwarta';es_ES = 'Turno del registro está abierto';es_CO = 'Turno del registro está abierto';tr = 'Kasa vardiyası açıldı';it = 'Il turno di cassa è aperto.';de = 'Kassenschicht ist geöffnet'");
		If Not Documents.ShiftClosure.SessionIsOpen(Object.CashCRSession, Date, MessageText) Then
			If Find(MessageText, "24") > 0 Then
				Items.LabelSinceChangeOpeningMore24Hours.Title = MessageText;
				SetLabelVisible = True;
			EndIf;
		EndIf;
	EndIf;
	Items.LabelSinceChangeOpeningMore24Hours.Visible = SetLabelVisible;

EndProcedure

// Procedure - event handler BeforeImportDataFromSettingsAtServer.
//
&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	ListForSaving = Settings.Get("ListForSettingSaving");
	If TypeOf(ListForSaving) = Type("ValueList") Then
		// Period recovery.
		PeriodKind = ListForSaving.Get(0).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(1).Value;
			EndDate = ListForSaving.Get(2).Value;
			If PeriodKind <> CatalogPeriodKindTransfer OR Items.List.Period.StartDate <> StartDate OR Items.List.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "List", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> CatalogPeriodKindTransfer Then
			SetPeriodAtServer(PeriodKind, "List");
		EndIf;
		
		PeriodKind = ListForSaving.Get(3).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(4).Value;
			EndDate = ListForSaving.Get(5).Value;
			If PeriodKind <> SalesSlipPeriodTransferKind OR Items.SalesSlipList.Period.StartDate <> StartDate OR Items.SalesSlipList.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "SalesSlipList", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> SalesSlipPeriodTransferKind Then
			SetPeriodAtServer(PeriodKind, "SalesSlipList");
		EndIf;
		
		PeriodKind = ListForSaving.Get(6).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(7).Value;
			EndDate = ListForSaving.Get(8).Value;
			If PeriodKind <> SalesSlipPeriodKindForReturnTransfer OR Items.SalesSlipListForReturn.Period.StartDate <> StartDate OR Items.SalesSlipListForReturn.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "SalesSlipListForReturn", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> SalesSlipPeriodKindForReturnTransfer Then
			SetPeriodAtServer(PeriodKind, "SalesSlipListForReturn");
		EndIf;
		
		// Recovery current page.
		CurrentPageName = ListForSaving.Get(9).Value;
		If ValueIsFilled(CurrentPageName) Then
			Items.GroupSalesAndReturn.CurrentPage = Items[CurrentPageName];
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnSaveDataInSettingsAtServer.
//
&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	ListForSettingSaving = New ValueList;
	// Period settings. Items 0 - 8.
	ListForSettingSaving.Add(CatalogPeriodKindTransfer);
	ListForSettingSaving.Add(Items.List.Period.StartDate);
	ListForSettingSaving.Add(Items.List.Period.EndDate);
	ListForSettingSaving.Add(SalesSlipPeriodTransferKind);
	ListForSettingSaving.Add(Items.SalesSlipList.Period.StartDate);
	ListForSettingSaving.Add(Items.SalesSlipList.Period.EndDate);
	ListForSettingSaving.Add(SalesSlipPeriodKindForReturnTransfer);
	ListForSettingSaving.Add(Items.SalesSlipListForReturn.Period.StartDate);
	ListForSettingSaving.Add(Items.SalesSlipListForReturn.Period.EndDate);
	// Current page. Item 9.
	ListForSettingSaving.Add(Items.GroupSalesAndReturn.CurrentPage.Name);
	
	Settings.Insert("ListForSettingSaving", ListForSettingSaving);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Select(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'sales slip'; ru = 'кассовый чек';pl = 'Paragon kasowy';es_ES = 'factura de compra';es_CO = 'factura de compra';tr = 'satış fişi';it = 'corrispettivo';de = 'verkaufsbeleg'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True, True);
	SelectionParameters.Insert("Company", ParentCompany);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

// Procedure - command handler ShowLog form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowJournal(Command)
	
	SwitchJournalQuickProducts = 1;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler ShowQuickSales form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowQuickSales(Command)
	
	SwitchJournalQuickProducts = 2;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler ShowMyCash form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowMyCashRegister(Command)
	
	SwitchJournalQuickProducts = 3;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler FastGoodsSetting form
//
&AtClient
Procedure QuickProductsSettings(Command)
	
	If ValueIsFilled(CWPSetting) Then
		ParametersStructure = New Structure("Key", CWPSetting);
		OpenForm("Catalog.CashierWorkplaceSettings.ObjectForm", ParametersStructure, ThisObject);
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'CWP setting is not selected.'; ru = 'Не выбраны настройки рабочего места кассира.';pl = 'Ustawienie CWP nie jest wybrane.';es_ES = 'Configuración de CWP no seleccionada.';es_CO = 'Configuración de CWP no seleccionada.';tr = 'CWP ayarı seçilmedi.';it = 'Impostazione Registratore Fiscale non selezionata.';de = 'Die CWP-Einstellung ist nicht ausgewählt.'");
		Message.Message();
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateCreditNote(Command)
	
	If ReceiptIsNotShown Then
		OpenForm("Document.CreditNote.ObjectForm", New Structure("CWP, OperationKindReturn", True, True), ThisObject, UUID);
	Else
		CurrentData = Items.SalesSlipList.CurrentData;
		If CurrentData <> Undefined Then
			OpenForm("Document.CreditNote.ObjectForm", New Structure("Basis, CWP", CurrentData.Ref, True), ThisObject, UUID);
		Else
			MessageText = NStr("en = 'Sales slip is not selected'; ru = 'Не выбран кассовый чек';pl = 'Paragon kasowy sprzedaży nie został wybrany';es_ES = 'Comprobante de ventas no seleccionado';es_CO = 'Comprobante de ventas no seleccionado';tr = 'Satış fişi seçilmedi';it = 'Lo scontrino di vendita non è selezionato';de = 'Kassenbon nicht ausgewählt'");
			CommonClientServer.MessageToUser(MessageText,, "SalesSlipList");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateGoodsReceipt(Command)
	
	If ReceiptIsNotShown Then
		OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("CWP, OperationKindReturn", True, True), ThisObject, UUID);
	Else
		If ValueIsFilled(CreditNote) Then
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis, CWP", CreditNote, True), ThisObject, UUID);
		Else
			MessageText = NStr("en = 'Credit note is not created'; ru = 'Не создан документ ""Кредитовое авизо""';pl = 'Nota kredytowa nie została utworzona';es_ES = 'Nota de crédito no creada';es_CO = 'Nota de crédito no creada';tr = 'Alacak dekontu oluşturulmadı';it = 'La nota di credito non è stata creata';de = 'Gutschrift wird nicht erstellt'");
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler CreateSalesSlipForReturn form
//
&AtClient
Procedure CreateSalesSlipForReturn(Command)
	
	If Not SalesSlipForReturn.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Return slip is already created.'; ru = 'Чек возврата уже создан.';pl = 'Formularz zwrotu jest już utworzony.';es_ES = 'Comprobante de la devolución ya se ha creado.';es_CO = 'Comprobante de la devolución ya se ha creado.';tr = 'İade fişi zaten oluşturuldu.';it = 'Lo scontrino di restituzione è già stato creato.';de = 'Rückschein ist bereits erstellt.'");
		Message.Field = "Items.CreateSalesSlipForReturn";
		Message.SetData(ThisObject);
		Message.Message();
	Else
		CurrentData = Items.SalesSlipList.CurrentData;
		If CurrentData <> Undefined Then
			OpenForm("Document.ProductReturn.ObjectForm", New Structure("Basis", CurrentData.Ref), ThisObject);
		Else
			Message = New UserMessage;
			Message.Text = NStr("en = 'Sales slip is not selected.'; ru = 'Не выбран кассовый чек.';pl = 'Paragon kasowy sprzedaży nie został wybrany.';es_ES = 'Comprobante de ventas no se ha seleccionado.';es_CO = 'Comprobante de ventas no se ha seleccionado.';tr = 'Satış fişi seçilmedi.';it = 'Lo scontrino di vendita non è selezionato.';de = 'Kassenbon ist nicht ausgewählt.'");
			Message.Field = "SalesSlipList";
			Message.Message();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler CreateCPVBasedOnCreditNote form
//
&AtClient
Procedure CreateCPVBasedOnReceipt(Command)
	
	If CreditNote.IsEmpty() Then
		MessageText = NStr("en = 'First of all it is necessary to create the credit note.'; ru = 'Сначала необходимо создать кредитовое авизо';pl = 'Przede wszystkim, konieczne jest utworzenie noty kredytowej.';es_ES = 'Primero de todo es necesario crear la nota de crédito.';es_CO = 'Primero de todo es necesario crear la nota de crédito.';tr = 'İlk önce alacak dekontu oluşturulmalıdır.';it = 'Prima di tutto è necessario creare la nota di credito.';de = 'Zunächst einmal ist es notwendig, die Gutschrift zu erstellen.'");
		CommonClientServer.MessageToUser(MessageText,, "CreateDebitInvoiceForReturn");
	Else
		CurrentData = Items.SalesSlipList.CurrentData;
		If CurrentData <> Undefined OR ReceiptIsNotShown Then
			OpenForm("Document.CashVoucher.ObjectForm", New Structure("Basis, CWP", CreditNote, True), ThisObject, UUID);
		Else
			MessageText = NStr("en = 'Sales slip is not selected'; ru = 'Не выбран кассовый чек';pl = 'Paragon kasowy sprzedaży nie został wybrany';es_ES = 'Comprobante de ventas no seleccionado';es_CO = 'Comprobante de ventas no seleccionado';tr = 'Satış fişi seçilmedi';it = 'Lo scontrino di vendita non è selezionato';de = 'Kassenbon nicht ausgewählt'");
			CommonClientServer.MessageToUser(MessageText,, "SalesSlipList");
		EndIf;
	EndIf;

EndProcedure

// Procedure - command handler AcceptPayment form.
//
&AtClient
Procedure Pay(Command)
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	If Not StructureStateCashCRSession.SessionIsOpen Then
		CashCRSessionOpen();
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		
		Object.CashCRSession = StructureStateCashCRSession.CashCRSession;
	EndIf;
	
	If ValueIsFilled(StructureStateCashCRSession.CashCRSessionStatus) Then
		FillPropertyValues(Object, StructureStateCashCRSession,, "Responsible, Department");
	EndIf;
	
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() > 0 AND Not Object.DiscountsAreCalculated Then
			CalculateDiscountsMarkups(Commands.CalculateDiscountsMarkups);
		EndIf;
	EndIf;
	
	If Object.Inventory.Count() = 0 Or Object.Inventory.Total("Amount") = 0 Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Amount payable = 0'; ru = 'Остаток задолженности = 0';pl = 'Kwota do zapłaty = 0';es_ES = 'Importe a pagar = 0';es_CO = 'Importe a pagar = 0';tr = 'Ödenecek tutar = 0';it = 'Importo dovuto = 0';de = 'Fälliger Betrag = 0'"),,
			"Object.DocumentAmount");
		Return;
	EndIf;
	
	If Not ControlAtWarehouseDisabled Then
		If Not ReserveAtServer() Then
			Return;
		Else
			FillInDetailsForTSInventoryAtClient();
		EndIf;
		Notify("RefreshSalesSlipDocumentsListForm");
	EndIf;
	
	// We will check that there were not goods with the zero price!
	ContinuePaymentReception = True;
	For Each CurrentRow In Object.Inventory Do
		If CurrentRow.Price = 0 Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'The string is missing price.'; ru = 'В строке отсутствует цена.';pl = 'W ciągu brakuje ceny.';es_ES = 'En la línea está faltando el precio.';es_CO = 'En la línea está faltando el precio.';tr = 'Satırda fiyat eksik.';it = 'Nella stringa manca il prezzo.';de = 'Der Zeichenfolge fehlt der Preis.'");
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].Price";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
		If CurrentRow.Quantity = 0 Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'In string is missing quantity.'; ru = 'В строке отсутствует количество.';pl = 'W ciągu brakuje ilośi.';es_ES = 'En la línea está faltando la cantidad.';es_CO = 'En la línea está faltando la cantidad.';tr = 'Satırda miktar eksik.';it = 'Nella stringa manca la quantità.';de = 'In der Zeichenfolge fehlt die Menge.'");
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].Quantity";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
		If CurrentRow.Products.IsEmpty() Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'The string is missing product.'; ru = 'В строке отсутствует номенклатура.';pl = 'W ciągu brakuje produktu.';es_ES = 'En la línea está faltando el producto.';es_CO = 'En la línea está faltando el producto.';tr = 'Satırda ürün eksik.';it = 'Nella stringa manca l''articolo.';de = 'Der Zeichenfolge fehlt das Produkt.'");
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].Products";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
	EndDo;
	
	If Not ContinuePaymentReception Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("PayEnd", ThisForm);
	
	ParametersStructure = New Structure("Object, PaymentWithPaymentCards, DocumentAmount, DocumentCurrency, CardKinds, CashCR, UsePeripherals, POSTerminal, FormID", 
		Object,
		Object.PaymentWithPaymentCards,
		Object.DocumentAmount,
		Object.DocumentCurrency,
		Items.PaymentByChargeCardTypeCards.ChoiceList,
		CashCR,
		UsePeripherals,
		Object.POSTerminal,
		UUID);
		
		
	OpenForm("Document.SalesSlip.Form.PaymentForm", ParametersStructure,,,,,Notification);
	
EndProcedure

// Procedure updates the form main attribute data after closing payment form.
//
&AtServer
Procedure UpdateDocumentAtServer(ObjectParameter)
	
	ValueToFormData(FormDataToValue(ObjectParameter, Type("DocumentObject.SalesSlip")), Object);
	
	If Not Object.Ref.IsEmpty() Then
		Try
			LockDataForEdit(Object.Ref, , UUID);
		Except
			//
		EndTry;
	EndIf;
	
	For Each CurrentRow In Object.Inventory Do
		SetDescriptionForTSRowsInventoryAtServer(CurrentRow);
	EndDo;
	
EndProcedure

// Procedure - command handler AcceptPayment. It is called after closing payment form.
//
&AtClient
Procedure PayEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		// Payments were made by plastic cards or cancel payments by plastic cards and in this case the document was written or posted.
		UpdateDocumentAtServer(Result.Object);
		
		If Result.Button = "IssueReceipt" Then
		
			Object.CashReceived = Result.Cash;
			
			Change = Format(Result.Deal, "NFD=2");
			
			RecalculateDocumentAtClient();
			
			GenerateSalesReceipt = Result.GenerateSalesReceipt;
			GenerateSimplifiedTaxInvoice = Result.GenerateSimplifiedTaxInvoice;
			GenerateWarrantyCardPerSerialNumber = Result.GenerateWarrantyCardPerSerialNumber;
			GenerateWarrantyCardConsolidated = Result.GenerateWarrantyCardConsolidated;
			
			IssueReceiptExecute(
				Commands.IssueReceipt,
				GenerateSalesReceipt,
				GenerateSimplifiedTaxInvoice,
				GenerateWarrantyCardPerSerialNumber,
				GenerateWarrantyCardConsolidated);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler PrintSalesReceipt form
//
&AtClient
Procedure PrintSalesReceipt(Command)
	
	ReceiptsCRArray = New Array;
	SalesSlipArrayForReturn = New Array;
	ThereAreRetailSaleReports = False;
	
	For Each ListRow In Items.List.SelectedRows Do
		If ListRow <> Undefined Then
			If TypeOf(ListRow) = Type("DocumentRef.SalesSlip") Then
				ReceiptsCRArray.Add(ListRow);
			ElsIf TypeOf(ListRow) = Type("DocumentRef.ProductReturn") Then
				SalesSlipArrayForReturn.Add(ListRow);
			Else
				ThereAreRetailSaleReports = True;
			EndIf;
		EndIf;
	EndDo;
	
	If ThereAreRetailSaleReports Then
		CommonClientServer.MessageToUser(
			NStr("en = 'For retail sale reports sales slip is not formed.'; ru = 'Кассовый чек не формируется для отчета о розничных продажах.';pl = 'W przypadku raportów sprzedaży detalicznej paragon kasowy nie jest tworzony.';es_ES = 'Para los informes de ventas al por menor, el comprobante de ventas no se ha formado.';es_CO = 'Para los informes de ventas al por menor, el comprobante de ventas no se ha formado.';tr = 'Perakende satış raporları için satış fişi oluşturulmamıştır.';it = 'Per il report della vendita al dettaglio lo scontrino di vendita non è stato creato.';de = 'Für Einzelhandelsberichte wird kein Verkaufsbeleg gebildet.'"),,
			"List");
	EndIf;
	
	If ReceiptsCRArray.Count() > 0 Then
		
		OpenParameters = New Structure("PrintManagerName,TemplatesNames,CommandParameter,PrintParameters");
		OpenParameters.PrintManagerName	= "Document.SalesSlip";
		OpenParameters.TemplatesNames	= "SalesReceipt";
		OpenParameters.CommandParameter	= ReceiptsCRArray;
		OpenParameters.PrintParameters	= Undefined;
		
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
		
	EndIf;
	
	If SalesSlipArrayForReturn.Count() > 0 Then
		
		OpenParameters = New Structure("PrintManagerName,TemplatesNames,CommandParameter,PrintParameters");
		OpenParameters.PrintManagerName	= "Document.ProductReturn";
		OpenParameters.TemplatesNames	= "SalesReceipt";
		OpenParameters.CommandParameter	= SalesSlipArrayForReturn;
		OpenParameters.PrintParameters	= Undefined;
		
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintSimplifiedTaxInvoice(Command)
	
	SalesSlipsArray = New Array;

	For Each ListRow In Items.List.SelectedRows Do
		
		If ListRow <> Undefined Then
			
			If TypeOf(ListRow) = Type("DocumentRef.SalesSlip") Then
				
				SalesSlipsArray.Add(ListRow);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If SalesSlipsArray.Count() Then
		
		OpenParameters = New Structure("PrintManagerName, TemplatesNames, CommandParameter, PrintParameters");
		OpenParameters.PrintManagerName	 = "Document.SalesSlip";
		OpenParameters.TemplatesNames	 = "SimplifiedTaxInvoice";
		OpenParameters.CommandParameter	 = SalesSlipsArray;
		OpenParameters.PrintParameters	 = Undefined;
		
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
		
	Else
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Select sales slips you want to issue tax invoice against and try again.'; ru = 'Выберите кассовые чеки, по которым нужно сформировать налоговый инвойс, и попробуйте снова.';pl = 'Wybierz paragon kasowy, na który chcesz wystawić fakturę VAT, i spróbuj ponownie.';es_ES = 'Seleccionar los comprobantes de ventas que usted quiere para emitir una factura de impuestos en contra, e intentar de nuevo.';es_CO = 'Seleccionar los comprobantes de ventas que usted quiere para emitir una factura fiscal en contra, e intentar de nuevo.';tr = 'Vergi faturasını karşı vermek istediğiniz satış fişleri seçin ve tekrar deneyin.';it = 'Selezionare i corrispettivi per i quali volete emettere fattura fiscale e provate nuovamente.';de = 'Wählen Sie Kassenbelege aus, gegen die Sie eine Steuerrechnung ausstellen möchten, und versuchen Sie es erneut.'"),, "List");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintSimplifiedTaxInvoiceForAnArchivedSalesSlip(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Date", CommonClient.SessionDate());
	ParametersStructure.Insert("Company", Object.Company);
	ParametersStructure.Insert("CashCR", CashCR);
	
	OpenForm("DataProcessor.PrintSimplifiedTaxInvoice.Form", ParametersStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure PrintWarrantyCardPerSerialNumbers(Command)
	PrintWarrantyCard(False);
EndProcedure

&AtClient
Procedure PrintWarrantyCardConsolidated(Command)
	PrintWarrantyCard(True);
EndProcedure

&AtClient
Procedure PrintWarrantyCard(Consolidated)
	
	ReceiptsCRArray = New Array;	
	For Each ListRow In Items.List.SelectedRows Do
		If ListRow <> Undefined Then
			If TypeOf(ListRow) = Type("DocumentRef.SalesSlip") Then
				ReceiptsCRArray.Add(ListRow);
			EndIf;
		EndIf;
	EndDo;
	
	If ReceiptsCRArray.Count() > 0 Then
		
		OpenParameters = New Structure("PrintManagerName,TemplatesNames,CommandParameter,PrintParameters");
		OpenParameters.PrintManagerName	= "Document.SalesSlip";
		OpenParameters.TemplatesNames	= ?(Consolidated, "WarrantyCardConsolidated", "WarrantyCardPerSerialNumber");
		OpenParameters.CommandParameter	= ReceiptsCRArray;
		OpenParameters.PrintParameters	= Undefined;
		
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
		
	Else
		
		CommonClientServer.MessageToUser(
			NStr("en = 'There are no selected sales slips.'; ru = 'Выбранные кассовые чеки отсутствуют.';pl = 'Brak wybranych paragonów kasowych';es_ES = 'No hay recibos de compra seleccionados.';es_CO = 'No hay recibos de compra seleccionados.';tr = 'Seçili satış fişi yok.';it = 'Non ci sono corrispettivi selezionati.';de = 'Es gibt keine ausgewählten Verkaufsbelege.'"),,
			"List");
		
	EndIf;
	
EndProcedure

// Procedure - command handler SubordinateDocumentStructure form
//
&AtClient
Procedure SubordinateDocumentStructure(Command)
	
	CurrentDocument = Items.SalesSlipList.CurrentRow;
	
	If CurrentDocument <> Undefined Then
		OpenForm("CommonForm.SubordinateDocumentStructureTabularRepresentation",New Structure("DocumentRef", CurrentDocument),
					ThisObject,
					CurrentDocument.UUID(),
					Undefined
					);
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'Select a document.'; ru = 'Выберите документ.';pl = 'Wybór dokumentu.';es_ES = 'Seleccionar un documento.';es_CO = 'Seleccionar un documento.';tr = 'Belgeyi seçin.';it = 'Selezionare un documento.';de = 'Wählen Sie ein Dokument aus.'");
		Message.Field = "SalesSlipList";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler Reserve on server.
&AtServer
Function ReserveAtServer(CancelReservation = False)
	
	ReturnValue = False;
	If CancelReservation Then
		CurrentDocument = Items.List.CurrentRow;
		If ValueIsFilled(CurrentDocument) AND TypeOf(CurrentDocument) = Type("DocumentRef.SalesSlip") Then
			DocObject = CurrentDocument.GetObject();
			
			OldStatus = DocObject.Status;
			
			DocObject.Status = Undefined;
			WriteMode = DocumentWriteMode.UndoPosting;
			
			Try
				DocObject.Write(WriteMode);
				If Not DocObject.Posted Then
					ReturnValue = True;
					// If we post object with which work in form you need to update the form object.
					// This situation arises in the following case. 
					// Balance control is set.
					// 1. Click the "Accept payment" button. Document will be written so. Reservation will the executed.
					// 2. IN the payment form click the "Cancel" button.
					// 3. Select current document in list and select "More..."-"Remove reserve".
					// 4. Click the "Accept payment" button.
					If DocObject.Ref = Object.Ref Then
						ValueToFormData(DocObject, Object);
					EndIf;
				EndIf;
			Except
				Message = New UserMessage;
				Message.Text = ErrorDescription();
				Message.Field = "List";
				Message.Message();
			EndTry;
		Else
			Message = New UserMessage;
			Message.Text = NStr("en = 'Sales slip is not selected.'; ru = 'Не выбран кассовый чек.';pl = 'Paragon kasowy sprzedaży nie został wybrany.';es_ES = 'Comprobante de ventas no se ha seleccionado.';es_CO = 'Comprobante de ventas no se ha seleccionado.';tr = 'Satış fişi seçilmedi.';it = 'Lo scontrino di vendita non è selezionato.';de = 'Kassenbon ist nicht ausgewählt.'");
			Message.Field = "List";
			Message.Message();
		EndIf;
	Else
		OldStatus = Object.Status;
		
		Object.Status = Enums.SalesSlipStatus.ProductReserved;
		WriteMode = DocumentWriteMode.Posting;
		
		Try
			If Not Write(New Structure("WriteMode", WriteMode)) Then
				Object.Status = OldStatus;
			Else
				ReturnValue = True;
			EndIf;
		Except
			Object.Status = OldStatus;
		EndTry;
		
		SetEnabledOfReceiptPrinting();
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Procedure - command handler RemoveReservation.
//
&AtClient
Procedure RemoveReservation(Command)
	
	ReserveAtServer(True);
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
			RecalculateDocumentAtClient();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			TabularSectionName = "Inventory";
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			Filter.Insert("IsBundle", False);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
					Object.SerialNumbers,
					RowToDelete,
					,
					UseSerialNumbersBalance);
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
			RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
			For Each RowToRecalculate In RowsToRecalculate Do
				CalculateAmountInTabularSectionLine(RowToRecalculate);
			EndDo;
			
			RecalculateDocumentAtClient();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange input field ProductsSearchValue.
//
&AtClient
Procedure ProductsSearchValueOnChange(Item)
	
	If ValueIsFilled(ProductsSearchValue) Then
		
		NewRow = Object.Inventory.Add();
		NewRow.Products = ProductsSearchValue;
		
		ProductsSearchValue = Undefined;
		Modified = True;
		
		ProductsOnChange(NewRow);
		
		RecalculateDocumentAtClient();
		
		CurrentItem = Items.ProductsSearchValue;
		Items.Inventory.CurrentRow = NewRow.GetID();
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange item ReceiptIsNotShown form.
//
&AtClient
Procedure ReceiptInNotShowedOnChange(Item)
	
	ReceiptIsNotShownOnChangeAtServer();
	
	If Not ReceiptIsNotShown Then
		AttachIdleHandler("SalesSlipListOnActivateRowIdleProcessing", 0.2, True);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange item ReceiptIsNotShown on server.
//
&AtServer
Procedure ReceiptIsNotShownOnChangeAtServer()
	
	If ReceiptIsNotShown Then
		CreditNote = "";
		CPV = "";
		
		Items.DecorationTitleReceiptsCR.Title = NStr("en = 'Create a credit note and a cash voucher'; ru = 'Создать кредитовое авизо и кассовый чек';pl = 'Utwórz notę kredytową i dowód kasowy KW';es_ES = 'Crear una nota de crédito y un vale de efectivo';es_CO = 'Crear una nota de crédito y un vale de efectivo';tr = 'Alacak dekontu ve kasa fişi oluştur';it = 'Creare una nota di credito e una uscita di cassa';de = 'Erstellen Sie eine Gutschrift und einen Kassenbeleg'");
		Items.DecorationCreditNote.Title = "";
		Items.DecorationCPV.Title = "";
		Items.DecorationGoodsReceipt.Title = "";
		
		Items.DecorationSalesSlipForReturn.Visible = False;
		Items.DecorationCreditNote.Visible = True;
		Items.DecorationCPV.Visible = True;
		Items.DecorationGoodsReceipt.Visible = True;
		
		Items.CreateSalesSlipForReturn.Visible = False;
		Items.CreateCreditNote.Visible = True;
		Items.CreateCPVBasedOnReceipt.Visible = True;
		If UseGoodsReturnFromCustomer Then
			Items.CreateGoodsReceipt.Visible = True;
		EndIf;
		
		Items.CreateCreditNote.TextColor = New Color;
		Items.CreateCPVBasedOnReceipt.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		Items.CreateGoodsReceipt.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		
		Items.PagesSalesSlipList_and_SalesSlipContent_and_PageWithLabel.CurrentPage = Items.PageWithEmptyLabel;
	Else
		Items.DecorationTitleReceiptsCR.Title = NStr("en = 'Select a reason for refund.'; ru = 'Выберите причину возмещения.';pl = 'Wybierz przyczynę zwrotu kosztów.';es_ES = 'Seleccionar un motivo para devolver.';es_CO = 'Seleccionar un motivo para devolver.';tr = 'İade nedenini seçin.';it = 'Selezionare un motivo per la restituzione.';de = 'Wählen Sie einen Grund für die Rückerstattung.'");
		
		Items.CreateSalesSlipForReturn.Visible = True;
		Items.CreateCreditNote.Visible = False;
		Items.CreateCPVBasedOnReceipt.Visible = False;
		If UseGoodsReturnFromCustomer Then
			Items.CreateGoodsReceipt.Visible = False;
		EndIf;
		
		Items.PagesSalesSlipList_and_SalesSlipContent_and_PageWithLabel.CurrentPage = Items.PageSalesSlipList_and_SalesSlipContent;
	EndIf;
	
EndProcedure

// Function gets Associated documents of a certain kind, places them
// in a temporary storage and returns address
//
&AtServer
Function PlaceRelatedDocumentsInStorage(SalesSlip, Kind)
	
	// Fill references on documents.
	Query = New Query;
	
	If Kind = "CreditNote" Then
		Query.Text = 
			"SELECT ALLOWED
			|	CreditNote.Ref AS RelatedDocument
			|FROM
			|	Document.CreditNote AS CreditNote
			|WHERE
			|	CreditNote.Posted
			|	AND CreditNote.BasisDocument = &SalesSlip";
	ElsIf Kind = "CashVoucher" Then
		Query.Text = 
			"SELECT ALLOWED
			|	CreditNote.Ref AS Ref,
			|	CreditNote.Number AS Number,
			|	CreditNote.Date AS Date
			|INTO CreditNote
			|FROM
			|	Document.CreditNote AS CreditNote
			|WHERE
			|	CreditNote.Posted
			|	AND CreditNote.BasisDocument = &SalesSlip
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	CashVoucher.Ref AS RelatedDocument
			|FROM
			|	Document.CashVoucher AS CashVoucher
			|		INNER JOIN CreditNote AS CreditNote
			|		ON CashVoucher.BasisDocument = CreditNote.Ref
			|WHERE
			|	CashVoucher.Posted";
	ElsIf Kind = "ProductReturn" Then
		Query.Text = 
			"SELECT ALLOWED
			|	ProductReturn.Ref AS RelatedDocument
			|FROM
			|	Document.ProductReturn AS ProductReturn
			|WHERE
			|	ProductReturn.Posted
			|	AND ProductReturn.SalesSlip = &SalesSlip";
	ElsIf Kind = "GoodsReceipt" Then
		Query.Text = 
			"SELECT ALLOWED
			|	GoodsReceiptProducts.Ref AS RelatedDocument
			|FROM
			|	Document.GoodsReceipt.Products AS GoodsReceiptProducts
			|WHERE
			|	GoodsReceiptProducts.Ref.Posted
			|	AND GoodsReceiptProducts.SalesDocument = &SalesSlip";
		
	EndIf;
	
	Query.SetParameter("SalesSlip", SalesSlip);
	Result = Query.Execute();
	
	Return PutToTempStorage(Result.Unload(), UUID);
	
EndFunction

// Procedure - event handler Click item DecorationCreditNote form.
//
&AtClient
Procedure DecorationCreditNoteClick(Item)
	
	If ReceiptIsNotShown Then
		If Not CreditNote.IsEmpty() Then
			OpenForm("Document.CreditNote.ObjectForm", New Structure("Key", CreditNote));
		EndIf;
	Else
		CurSalesSlip = Items.SalesSlipList.CurrentRow;
		If CurSalesSlip = Undefined Then
			Return;
		EndIf;
		
		Modified = True;
		AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurSalesSlip, "CreditNote");
		FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
		OpenForm("Document.SalesSlip.Form.LinkedDocuments", FormParameters
			,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

// Procedure - event handler Click item DecorationCPV form.
//
&AtClient
Procedure DecorationCPVClick(Item)
	
	If ReceiptIsNotShown Then
		If Not CPV.IsEmpty() Then
			OpenForm("Document.CashVoucher.ObjectForm", New Structure("Key", CPV));
		EndIf;
	Else
		CurSalesSlip = Items.SalesSlipList.CurrentRow;
		If CurSalesSlip = Undefined Then
			Return;
		EndIf;
		
		Modified = True;
		AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurSalesSlip, "CashVoucher");
		FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
		OpenForm("Document.SalesSlip.Form.LinkedDocuments", FormParameters
			,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

// Procedure - event handler Click item DecorationGoodsReceipt form.
//
&AtClient
Procedure DecorationGoodsReceiptClick(Item)
	
	If ReceiptIsNotShown Then
		If Not CreditNote.IsEmpty() Then
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Key", GoodsReceipt));
		EndIf;
	Else
		CurSalesSlip = Items.SalesSlipList.CurrentRow;
		If CurSalesSlip = Undefined Then
			Return;
		EndIf;
		
		Modified = True;
		AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurSalesSlip, "GoodsReceipt");
		FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
		OpenForm("Document.SalesSlip.Form.LinkedDocuments", FormParameters
			,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

// Procedure - event handler Click item DecorationSalesSlipForReturn form.
//
&AtClient
Procedure CRDecorationForReturnReceiptClick(Item)
		
	CurSalesSlip = Items.SalesSlipList.CurrentRow;
	If CurSalesSlip = Undefined Then
		Return;
	EndIf;
	
	Modified = True;
	AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurSalesSlip, "ProductReturn");
	FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
	OpenForm("Document.SalesSlip.Form.LinkedDocuments", FormParameters
		,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - event handler OnChange item SwitchLogFastGoods form.
//
&AtClient
Procedure SwitchJournalQuickProductsOnChange(Item)
	
	If SwitchJournalQuickProducts = 1 Then // Journal
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.Journal;
	ElsIf SwitchJournalQuickProducts = 2 Then // Quick sale
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.QuickSale;
	Else // Main attributes
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.MainAttributes;
	EndIf;
	
EndProcedure

// Procedure - event handler OnCurrentPageChange item GroupSalesAndReturn form.
//
&AtClient
Procedure GroupSalesAndReturnOnCurrentPageChange(Item, CurrentPage)
	
	SavedInSettingsDataModified = True;
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersHeaderAttributes

// Procedure - event handler OnChange field POSTerminal form.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	POSTerminalOnChangeAtServer();
	
EndProcedure

// Procedure - event handler OnChange field POSTerminal on server.
//
&AtServer
Procedure POSTerminalOnChangeAtServer()
	
	GetRefsToEquipment();
	GetChoiceListOfPaymentCardKinds();
	
EndProcedure

// Procedure - event handler OnChange field CashCR.
//
&AtClient
Procedure CashCROnChange(Item)
	
	If CashCR.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Cash register cannot be empty.'; ru = 'ККМ не может быть пустой.';pl = 'Kasa fiskalna nie może być pusta.';es_ES = 'Caja registrador no puede estar vacía.';es_CO = 'Caja registrador no puede estar vacía.';tr = 'Yazar kasa boş olamaz.';it = 'Il registratore di cassa non può essere vuoto.';de = 'Die Kasse darf nicht leer sein.'");
		Message.Field = "CashCR";
		Message.Message();
		
		CashCR = PreviousCashCR;
		Return;
	EndIf;
	
	If CashCR = PreviousCashCR Then
		Return;
	EndIf;
	
	PreviousCashCR = CashCR;
	Object.CashCR = CashCR;
	
	CashParameters = New Structure("CashCurrency");
	CashCROnChangeAtServer(CashParameters);
	
	If Object.Inventory.Count() > 0 Then
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", CashParameters.CashCurrency);
		DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory");
		
		FillVATRateByVATTaxation();
		DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		
		FillAmountsDiscounts();
		
		RecalculateDocumentAtClient();
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - event handler OnChange field CashRegister on server.
//
&AtServer
Procedure CashCROnChangeAtServer(CashParameters)
	
	CashParameters.Insert("CashCurrency", PreviousCashCR.CashCurrency);
	
	CashCRUseWithoutEquipmentConnection = CashCR.UseWithoutEquipmentConnection;
	
	Object.POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(Object.CashCR);
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	FillPropertyValues(Object, StructureStateCashCRSession);
	
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
	UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession);
	
	BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
	BalanceInCashierRow = ""+BalanceInCashier;
	
	Object.CashCR = CashCR;
	Object.StructuralUnit = CashCR.StructuralUnit;
	Object.PriceKind = CashCR.StructuralUnit.RetailPriceKind;
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = CashCR.CashCurrency;
	EndIf;
	Object.Company = Object.CashCR.Owner;
	Object.Department = Object.CashCR.Department;
	Object.Responsible = DriveReUse.GetValueByDefaultUser(User, "MainResponsible");
	
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, "CompanyVATNumber", False);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	Object.IncludeVATInPrice = True;
	
	If Not ValueIsFilled(Object.Ref) Then
		GetChoiceListOfPaymentCardKinds();
	EndIf;
	
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	ExchangeRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate
	);
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition
	);
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, DriveServer.GetPresentationCurrency(Object.Company), Object.Company);
	RateNationalCurrency = StructureByCurrency.Rate;
	RepetitionNationalCurrency = StructureByCurrency.Repetition;
	
	FillVATRateByCompanyVATTaxation();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetEnabledOfReceiptPrinting();
	
	If Object.Status = Enums.SalesSlipStatus.Issued
	AND Not CashCRUseWithoutEquipmentConnection Then
		SetModeReadOnly();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  	= Not AllowedEditDocumentPrices;
	Items.InventoryAmountDiscountsMarkups.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	List.Parameters.SetParameterValue("CashCR", CashCR);
	List.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	List.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	List.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	List.Parameters.SetParameterValue("FilterByChange", False);
	List.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	SalesSlipList.Parameters.SetParameterValue("CashCR", CashCR);
	SalesSlipList.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	SalesSlipList.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	SalesSlipList.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	SalesSlipList.Parameters.SetParameterValue("FilterByChange", False);
	SalesSlipList.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	SalesSlipListForReturn.Parameters.SetParameterValue("CashCR", CashCR);
	SalesSlipListForReturn.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	SalesSlipListForReturn.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	SalesSlipListForReturn.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	SalesSlipListForReturn.Parameters.SetParameterValue("FilterByChange", False);
	SalesSlipListForReturn.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	GenerateTitle(StructureStateCashCRSession);
	
	SetPeriodAtServer(SalesSlipPeriodTransferKind, "SalesSlipList", 
							  New StandardPeriod(Items.SalesSlipList.Period.StartDate, Items.SalesSlipList.Period.EndDate));
	SetPeriodAtServer(SalesSlipPeriodKindForReturnTransfer, "SalesSlipListForReturn", 
							  New StandardPeriod(Items.SalesSlipListForReturn.Period.StartDate, Items.SalesSlipListForReturn.Period.EndDate));
	SetPeriodAtServer(CatalogPeriodKindTransfer, "List", 
							  New StandardPeriod(Items.List.Period.StartDate, Items.List.Period.EndDate));
	
	// Recalculation TS Inventory
	ResetFlagDiscountsAreCalculatedServer("ChangeCashRegister");
	
EndProcedure

// Procedure - event handler OnChange field Company.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - event handler OnChange checkbox DoNotShowAtOpenCashChoiceForm.
//
&AtClient
Procedure DoNotShowOnOpenCashierChoiceFormOnChange(Item)
	
	// CWP
	CashierWorkplaceServerCall.UpdateCashierWorkplaceSettings(CWPSetting, DontShowOnOpenCashdeskChoiceForm);
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersTablePartAttributes

// Procedure - event handler OnChange column Products TS Inventory.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("RevenueItem", Undefined);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("Content", "");
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	AddIncomeAndExpenseItemsToStructure(ThisObject, "Inventory", StructureData);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	// Bundles
	If StructureData.IsBundle And Not StructureData.UseCharacteristics Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateDocumentAtClient();
		
	Else
	// End Bundles

		FillPropertyValues(TabularSectionRow, StructureData); 
		TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
		TabularSectionRow.Quantity = 1;
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
		TabularSectionRow.VATRate = StructureData.VATRate;
		
		
		CalculateAmountInTabularSectionLine();
		
		// Serial numbers
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
	
	EndIf;
	
EndProcedure

// Procedure - event handler OnStartEdit of the Inventory form tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	
EndProcedure

// Procedure - event handler OnEditEnd of the Inventory list row.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculateDocumentAtClient();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", 				Object.Company);
	StructureData.Insert("Products",				TabularSectionRow.Products);
	StructureData.Insert("Characteristic",			TabularSectionRow.Characteristic);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 	Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", 			Object.PriceKind);
		StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	AddIncomeAndExpenseItemsToStructure(ThisObject, "Inventory", StructureData);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	// Bundles
	If StructureData.IsBundle Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateDocumentAtClient();
	Else
	// End Bundles

		TabularSectionRow.Price = StructureData.Price;
		
		CalculateAmountInTabularSectionLine();
		
		TabularSectionRow.ProductsCharacteristicAndBatch = TrimAll(""+TabularSectionRow.Products)+?(TabularSectionRow.Characteristic.IsEmpty(), "", ". "+TabularSectionRow.Characteristic)+
			?(TabularSectionRow.Batch.IsEmpty(), "", ". "+TabularSectionRow.Batch);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	// Bundles
	CurrentRow = Items.Inventory.CurrentData;
	
	If CurrentRow.IsBundle Then
		
		StandardProcessing = False;
		
		OpeningStructure = New Structure;
		OpeningStructure.Insert("BundleProduct",	CurrentRow.Products);
		OpeningStructure.Insert("ChoiceMode",		True);
		OpeningStructure.Insert("CloseOnChoice",	True);
		
		OpenForm("InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle",
			OpeningStructure,
			Item,
			, , , ,
			FormWindowOpeningMode.LockOwnerWindow);
		
	// End Bundles
	
	ElsIf DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, True);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixFormWithAvailableQuantity",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange column TS Batch Inventory.
//
&AtClient
Procedure DocumentSalesSlipInventoryBatchOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TabularSectionRow <> Undefined Then
		TabularSectionRow.ProductsCharacteristicAndBatch = "" + TabularSectionRow.Products + ?(TabularSectionRow.Characteristic.IsEmpty(), "", ". "+TabularSectionRow.Characteristic)+
			?(TabularSectionRow.Batch.IsEmpty(), "", ". "+TabularSectionRow.Batch);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine(, False);
	
EndProcedure

// Procedure - event handler OnChange input field MeasurementUnit.
//
&AtClient
Procedure InventoryMeasurementUnitOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Price entered field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange input field AmountDiscountsMarkups.
//
&AtClient
Procedure InventoryAmountDiscountsMarkupsOnChange(Item)
	
	CalculateDiscountPercent();
	
EndProcedure

// Procedure - event handler OnChange of the Amount entered field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	TabularSectionRow.DiscountAmount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.Amount;
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
		
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);	
	
EndProcedure

&AtClient
Procedure InventoryOnChange(Item)
	
	ShowHideDealAtClient();
	
EndProcedure

&AtClient
Procedure InventoryBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	// Bundles
	If Clone Then
		
		If ValueIsFilled(Item.CurrentData.BundleProduct) Then
			Cancel = True;
		EndIf;
		
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Bundles
	If Items.Inventory.SelectedRows.Count() = Object.Inventory.Count() Then
		
		Object.AddedBundles.Clear();
		SetBundlePictureVisible();
		
	Else
		
		BundleData = New Structure("BundleProduct, BundleCharacteristic");
		
		For Each SelectedRow In Items.Inventory.SelectedRows Do
			
			SelectedRowData = Items.Inventory.RowData(SelectedRow);
			
			If BundleData.BundleProduct = Undefined Then
				
				BundleData.BundleProduct = SelectedRowData.BundleProduct;
				BundleData.BundleCharacteristic = SelectedRowData.BundleCharacteristic;
				
			ElsIf BundleData.BundleProduct <> SelectedRowData.BundleProduct
				Or BundleData.BundleCharacteristic <> SelectedRowData.BundleCharacteristic Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'Action is unavailable for bundles.'; ru = 'Это действие недоступно для наборов.';pl = 'Działanie nie jest dostępne dla zestawów.';es_ES = 'La acción no está disponible para los paquetes.';es_CO = 'La acción no está disponible para los paquetes.';tr = 'Bu işlem setler için kullanılamaz.';it = 'Azione non disponibile per kit di prodotti.';de = 'Für Bündel ist die Aktion nicht verfügbar.'"),,
					"Object.Inventory",,
					Cancel);
				Break;
				
			EndIf;
			
		EndDo;
		
		If Not Cancel And ValueIsFilled(BundleData.BundleProduct) Then
			
			Cancel = True;
			AddedBundles = Object.AddedBundles.FindRows(BundleData);
			Notification = New NotifyDescription("InventoryBeforeDeleteRowEnd", ThisObject, BundleData);
			ButtonsList = New ValueList;
			
			If AddedBundles.Count() > 0 And AddedBundles[0].Quantity > 1 Then
				
				QuestionText = BundlesClient.QuestionTextSeveralBundles();
				ButtonsList.Add(DialogReturnCode.Yes,	BundlesClient.AnswerDeleteAllBundles());
				ButtonsList.Add("DeleteOne",			BundlesClient.AnswerReduceQuantity());
				
			Else
				
				QuestionText = BundlesClient.QuestionTextOneBundle();
				ButtonsList.Add(DialogReturnCode.Yes,	BundlesClient.AswerDeleteAllComponents());
				
			EndIf;
			
			ButtonsList.Add(DialogReturnCode.No, BundlesClient.AswerChangeComponents());
			ButtonsList.Add(DialogReturnCode.Cancel);
			
			ShowQueryBox(Notification, QuestionText, ButtonsList, 0, DialogReturnCode.Yes);
			
		EndIf;
		
	EndIf;
	// End Bundles
	
	If Not Cancel Then
		CurrentData = Items.Inventory.CurrentData;
		// Serial numbers
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
			Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersDynamicLists

// Procedure - event handler OnActivateRow item SalesSlipList.
//
&AtClient
Procedure SalesSlipListOnRowRevitalization(Item)
	
	// Make a bit more period better, else user will not be able to enter a number in the search field.
	AttachIdleHandler("SalesSlipListOnActivateRowIdleProcessing", 0.3, True);
	
EndProcedure

// Procedure updates the information on the content, hyperlinks and sets cellar buttons on a Return bookmark.
//
&AtClient
Procedure SalesSlipListOnActivateRowIdleProcessing()
	
	CurSalesSlip = Items.SalesSlipList.CurrentRow;
	If CurSalesSlip <> Undefined Then
		FillReceiptAndRefContentOnDocumentsAtServer(CurSalesSlip);
	Else
		ReceiptContent = "";
	EndIf;
	
	DetachIdleHandler("SalesSlipListOnActivateRowIdleProcessing");
	
EndProcedure

// Procedure fills information about current receipt CR TS content in the SalesSlipList item.
//
&AtServer
Procedure FillReceiptAndRefContentOnDocumentsAtServer(SalesSlip)
	
	// Fill receipt content.
	ThisIsFirstString = True;
	For Each CurRow In SalesSlip.Inventory Do
		If ThisIsFirstString Then
			ThisIsFirstString = False;
			ReceiptContent = ""+CurRow.Products+". "+Chars.LF+Chars.Tab+GetDescriptionForTSStringInventoryAtServer(CurRow);
		Else
			ReceiptContent = ReceiptContent+Chars.LF+CurRow.Products+". "+Chars.LF+Chars.Tab+GetDescriptionForTSStringInventoryAtServer(CurRow);
		EndIf;
	EndDo;
	
	// Fill references on documents.
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	CreditNote.Ref AS Ref,
		|	CreditNote.Number AS Number,
		|	CreditNote.Date AS Date
		|INTO CreditNote
		|FROM
		|	Document.CreditNote AS CreditNote
		|WHERE
		|	CreditNote.Posted
		|	AND CreditNote.BasisDocument = &SalesSlip
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CreditNote.Ref AS Ref,
		|	CreditNote.Number AS Number,
		|	CreditNote.Date AS Date
		|FROM
		|	CreditNote AS CreditNote
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	CashVoucher.Ref AS Ref,
		|	CashVoucher.Date AS Date,
		|	CashVoucher.Number AS Number
		|FROM
		|	Document.CashVoucher AS CashVoucher
		|		INNER JOIN CreditNote AS CreditNote
		|		ON CashVoucher.BasisDocument = CreditNote.Ref
		|WHERE
		|	CashVoucher.Posted
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	GoodsReceiptProducts.Ref AS Ref,
		|	GoodsReceipt.Date AS Date,
		|	GoodsReceipt.Number AS Number
		|FROM
		|	CreditNote AS CreditNote_
		|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
		|		ON CreditNote_.Ref = GoodsReceiptProducts.CreditNote
		|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
		|		ON GoodsReceipt.Ref = GoodsReceiptProducts.Ref
		|WHERE
		|	GoodsReceipt.Posted
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ProductReturn.Ref AS Ref,
		|	ProductReturn.Number AS Number,
		|	ProductReturn.Date AS Date
		|FROM
		|	Document.ProductReturn AS ProductReturn
		|WHERE
		|	ProductReturn.Posted
		|	AND ProductReturn.SalesSlip = &SalesSlip";
	
	Query.SetParameter("SalesSlip", SalesSlip);
	
	MResults = Query.ExecuteBatch();
	
	// Define button and hyperlink visible.
	If SalesSlip.CashCRSession.CashCRSessionStatus = Enums.ShiftClosureStatus.IsOpen Then
		// Receipt CR on return.
		Selection = MResults[4].Select();
		If Selection.Next() Then
			SalesSlipForReturn = Selection.Ref;
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationSalesSlipForReturn.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Return slip #%1 dated %2.'; ru = 'Чек во возврату №%1 от %2 г.';pl = 'Zwrot #%1 z dn. %2.';es_ES = 'Comprobante de la devolución #%1 fechado %2.';es_CO = 'Comprobante de la devolución #%1 fechado %2.';tr = '%1 tarihli # %2 sayılı iade fişi.';it = 'Scontrino di restituzione #%1 datato %2.';de = 'Rückschein Nr %1 datiert %2.'"), 
				DocumentNumber,  
				Format(Selection.Date, "DLF=D"));
			Items.CreateSalesSlipForReturn.TextColor = UnavailableButtonColor;
		Else
			SalesSlipForReturn = Documents.ProductReturn.EmptyRef();
			Items.DecorationSalesSlipForReturn.Title = "";
			Items.CreateSalesSlipForReturn.TextColor = New Color;
		EndIf;
		
		While Selection.Next() Do
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationSalesSlipForReturn.Title = Items.DecorationSalesSlipForReturn.Title + " " + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '#%1 dated %2.'; ru = '№ %1 от %2.';pl = 'nr #%1 z dn. %2.';es_ES = '#%1 fechado %2.';es_CO = '#%1 fechado %2.';tr = '%2 tarihli # %1.';it = '#%1 con data %2.';de = 'Nr %1 datiert %2.'"),
				DocumentNumber,
				Format(Selection.Date, "DLF=D"));
		EndDo;
		
		Items.CreateSalesSlipForReturn.Visible = True;
		Items.CreateCreditNote.Visible = False;
		Items.CreateCPVBasedOnReceipt.Visible = False;
		If UseGoodsReturnFromCustomer Then
			Items.CreateGoodsReceipt.Visible = False;
		EndIf;
		
		Items.DecorationSalesSlipForReturn.Visible = True;
		Items.DecorationCreditNote.Visible = False;
		Items.DecorationCPV.Visible = False;
		Items.DecorationGoodsReceipt.Visible = False;
		
		Items.DecorationTitleReceiptsCR.Title = NStr("en = 'Choose a reason for the return'; ru = 'Выберите причину возврата';pl = 'Wybierz przyczynę zwrotu';es_ES = 'Elegir una causa para la devolución';es_CO = 'Elegir una causa para la devolución';tr = 'İade nedenini seçin';it = 'Scegli un motivo per la restituzione';de = 'Wählen Sie einen Grund für die Rückgabe'");
	Else
		
		Selection = MResults[4].Select();
		If Selection.Next() Then // Receipt CR on return.
			SalesSlipForReturn = Selection.Ref;
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationSalesSlipForReturn.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Return slip #%1 dated %2.'; ru = 'Чек во возврату №%1 от %2 г.';pl = 'Zwrot #%1 z dn. %2.';es_ES = 'Comprobante de la devolución #%1 fechado %2.';es_CO = 'Comprobante de la devolución #%1 fechado %2.';tr = '%1 tarihli # %2 sayılı iade fişi.';it = 'Scontrino di restituzione #%1 datato %2.';de = 'Rückschein Nr %1 datiert %2.'"),
			    DocumentNumber,
				Format(Selection.Date, "DLF=D"));
			
			While Selection.Next() Do
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationSalesSlipForReturn.Title = Items.DecorationSalesSlipForReturn.Title + "; "
					+ StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '#%1 dated %2.'; ru = '№ %1 от %2.';pl = 'nr #%1 z dn. %2.';es_ES = '#%1 fechado %2.';es_CO = '#%1 fechado %2.';tr = '%2 tarihli # %1.';it = '#%1 con data %2.';de = 'Nr %1 datiert %2.'"),
						DocumentNumber,
						Format(Selection.Date, "DLF=D"));
			EndDo;
			
			Items.CreateSalesSlipForReturn.TextColor = UnavailableButtonColor;
			Items.CreateSalesSlipForReturn.Visible = True;
			Items.CreateCreditNote.Visible = False;
			Items.CreateCPVBasedOnReceipt.Visible = False;
			If UseGoodsReturnFromCustomer Then
				Items.CreateGoodsReceipt.Visible = False;
			EndIf;
			
			Items.DecorationSalesSlipForReturn.Visible = True;
			Items.DecorationCreditNote.Visible = False;
			Items.DecorationCPV.Visible = False;
			Items.DecorationGoodsReceipt.Visible = False;
		Else
			// Receipt CR on return.
			SalesSlipForReturn = Documents.ProductReturn.EmptyRef();
			Items.DecorationSalesSlipForReturn.Title = "";
			
			// Credit note.
			Selection = MResults[1].Select();
			If Selection.Next() Then
				CreditNote = Selection.Ref;
				
				Items.CreateCreditNote.TextColor = UnavailableButtonColor;
				Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
				Items.CreateGoodsReceipt.TextColor = UnavailableButtonColor;
				
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				TitlePresentation = NStr("en = 'Credit note'; ru = 'Кредитовое авизо';pl = 'Nota kredytowa';es_ES = 'Nota de crédito';es_CO = 'Nota de haber';tr = 'Alacak dekontu';it = 'Nota di credito';de = 'Gutschrift'");
				Items.DecorationCreditNote.Title = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 #%2 dated %3'; ru = '%1 №%2 от %3';pl = '%1 #%2 z dn. %3';es_ES = '%1 #%2 fechado %3';es_CO = '%1 #%2 fechado %3';tr = '%1 sayılı %2 tarihli %3';it = '%1 #%2 con data %3';de = '%1 Nr %2 datiert %3'"),
					TitlePresentation,
					DocumentNumber,
					Format(Selection.Date, "DLF=D"));
				While Selection.Next() Do
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationCreditNote.Title = Items.DecorationCreditNote.Title + "; "
					+ StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '#%1 dated %2'; ru = '№%1 от %2';pl = '#%1 z dn. %2';es_ES = '#%1 fechado %2';es_CO = '#%1 fechado %2';tr = 'no %1 tarih %2';it = '#%1 con data %2';de = 'Nr %1 datiert %2'"),
						DocumentNumber,
						Format(Selection.Date, "DLF=D"));
				EndDo;
			Else
				CreditNote = Documents.CreditNote.EmptyRef();
				
				Items.CreateCreditNote.TextColor = New Color;
				Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
				Items.CreateGoodsReceipt.TextColor = UnavailableButtonColor;
				
				Items.DecorationCreditNote.Title = "";
			EndIf;
			
			// CPV.
			Selection = MResults[2].Select();
			If Selection.Next() Then
				CPV = Selection.Ref;
				
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationCPV.Title = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cash voucher #%1 dated %2.'; ru = 'РКО №%1 от %2 г.';pl = 'Dowód kasowy KW nr %1 z dn. %2.';es_ES = 'Vale de efectivo #%1 fechado %2.';es_CO = 'Vale de efectivo #%1 fechado %2.';tr = '%1 numaralı, %2 tarihli kasa fişi.';it = 'Uscita di cassa #%1 con data %2.';de = 'Kassenbeleg Nr. %1 vom %2.'"),
					DocumentNumber,
					Format(Selection.Date, "DLF=D"));
				Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
				
				While Selection.Next() Do
					DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
					Items.DecorationCPV.Title = Items.DecorationCPV.Title + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '; #%1 dated %2.'; ru = '; №%1 от %2.';pl = '; #%1 z dn. %2.';es_ES = '; #%1 fechado %2.';es_CO = '; #%1 fechado %2.';tr = '; #%1 sayılı %2 tarihli.';it = '; #%1 con data %2.';de = '; Nr %1 datiert %2.'"),
						DocumentNumber,
						Format(Selection.Date, "DLF=D"));
				EndDo;
			Else
				Items.DecorationCPV.Title = "";
				If Not CreditNote.IsEmpty() Then
					Items.CreateCPVBasedOnReceipt.TextColor = New Color;
				Else
					Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
					Items.CreateGoodsReceipt.TextColor = New Color;
				EndIf;
			EndIf;
			
			// Goods receipt.
			Selection = MResults[3].Select();
			If Selection.Next() Then
				GoodsReceipt = Selection.Ref;
				
				Items.CreateCreditNote.TextColor = UnavailableButtonColor;
				Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
				Items.CreateGoodsReceipt.TextColor = UnavailableButtonColor;
				
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				TitlePresentation = NStr("en = 'Goods return'; ru = 'Возврат товара';pl = 'Zwrot towarów';es_ES = 'Devolución de productos';es_CO = 'Devolución de productos';tr = 'Mal iadesi';it = 'Restituzione merci';de = 'Warenrücksendung'");
				Items.DecorationGoodsReceipt.Title = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 #%2 dated %3'; ru = '%1 №%2 от %3';pl = '%1 #%2 z dn. %3';es_ES = '%1 #%2 fechado %3';es_CO = '%1 #%2 fechado %3';tr = '%1 sayılı %2 tarihli %3';it = '%1 #%2 con data %3';de = '%1 Nr %2 datiert %3'"),
					TitlePresentation,
					DocumentNumber,
					Format(Selection.Date, "DLF=D"));
				While Selection.Next() Do
					DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
					Items.DecorationGoodsReceipt.Title = Items.DecorationGoodsReceipt.Title + "; "
						+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '#%1 dated %2'; ru = '№%1 от %2';pl = '#%1 z dn. %2';es_ES = '#%1 fechado %2';es_CO = '#%1 fechado %2';tr = 'no %1 tarih %2';it = '#%1 con data %2';de = 'Nr %1 datiert %2'"),
																					DocumentNumber,
																					Format(Selection.Date, "DLF=D"));
				EndDo;
			Else
				GoodsReceipt = Documents.GoodsReceipt.EmptyRef();
				
				If Not CPV.IsEmpty() Then
					Items.CreateGoodsReceipt.TextColor = New Color;
				Else
					Items.CreateGoodsReceipt.TextColor = UnavailableButtonColor;
				EndIf;
				
				Items.DecorationGoodsReceipt.Title = "";
			EndIf;
			
			Items.CreateSalesSlipForReturn.Visible = False;
			Items.CreateCreditNote.Visible = True;
			Items.CreateCPVBasedOnReceipt.Visible = True;
			If UseGoodsReturnFromCustomer Then
				Items.CreateGoodsReceipt.Visible = True;
			EndIf;
		
		Items.DecorationSalesSlipForReturn.Visible = False;
			Items.DecorationCreditNote.Visible = True;
			Items.DecorationCPV.Visible = True;
			Items.DecorationGoodsReceipt.Visible = True;
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler ValueSelection item List.
//
&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.SalesSlip.ObjectForm", New Structure("Key", CurrentData.Ref));
		ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.ProductReturn.ObjectForm", New Structure("Key", CurrentData.Ref));
		ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", CurrentData.Ref));
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region CommandFormPanelsActionProcedures

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line for which the weight should be received.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, dla którego trzeba uzyskać wagę.';es_ES = 'Seleccionar una línea para la cual el peso tienen que recibirse.';es_CO = 'Seleccionar una línea para la cual el peso tienen que recibirse.';tr = 'Ağırlığın alınması gereken bir satır seçin.';it = 'Selezionare una linea dove il peso deve essere ricevuto';de = 'Wählen Sie eine Zeile, für die das Gewicht empfangen werden soll.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

// Procedure - command handler GetWeight form. It is executed after obtaining weight from electronic scales.
//
&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en = 'Electronic scales returned zero weight.'; ru = 'Электронные весы вернули нулевой вес.';pl = 'Waga elektroniczna zwróciła zerową wagę.';es_ES = 'Escalas electrónicas han devuelto el peso cero.';es_CO = 'Escalas electrónicas han devuelto el peso cero.';tr = 'Elektronik tartı sıfır ağırlık gösteriyor.';it = 'Le bilance elettroniche hanno dato peso pari a zero.';de = 'Die elektronische Waagen gaben Nullgewicht zurück.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler Click item PricesAndCurrency form.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	
EndProcedure

// Procedure - command handler IncreaseQuantity form.
//
&AtClient
Procedure GroupQuantity(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Quantity = CurrentData.Quantity + 1;
		CalculateAmountInTabularSectionLine();
		RecalculateDocumentAtClient();
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'String is not selected.'; ru = 'Не выбрана строка.';pl = 'Ciąg nie został wybrany.';es_ES = 'Línea no se ha seleccionado.';es_CO = 'Línea no se ha seleccionado.';tr = 'Satır seçilmedi.';it = 'La stringa non è selezionata.';de = 'Zeichenfolge ist nicht ausgewählt.'");
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ReduceQuantity form.
//
&AtClient
Procedure ReduceQuantity(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Quantity = CurrentData.Quantity - 1;
		CalculateAmountInTabularSectionLine();
		RecalculateDocumentAtClient();
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'String is not selected.'; ru = 'Не выбрана строка.';pl = 'Ciąg nie został wybrany.';es_ES = 'Línea no se ha seleccionado.';es_CO = 'Línea no se ha seleccionado.';tr = 'Satır seçilmedi.';it = 'La stringa non è selezionata.';de = 'Zeichenfolge ist nicht ausgewählt.'");
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ChangeQuantityByCalculator form.
//
&AtClient
Procedure ChangeQuantityUsingCalculator(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		Notification = New NotifyDescription("ChangeQuantityUsingCalculatorEnd", ThisForm);
		
		ParametersStructure = New Structure("Quantity, ProductsCharacteristicAndBatch, Price, Amount, DiscountMarkupPercent, AutomaticDiscountPercent", 
			CurrentData.Quantity, 
			CurrentData.ProductsCharacteristicAndBatch,
			CurrentData.Price,
			CurrentData.Amount,
			CurrentData.DiscountMarkupPercent,
			CurrentData.AutomaticDiscountsPercent);
			
		OpenForm("Document.SalesSlip.Form.FormEnterQuantity", ParametersStructure,,,,,Notification);
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'String is not selected.'; ru = 'Не выбрана строка.';pl = 'Ciąg nie został wybrany.';es_ES = 'Línea no se ha seleccionado.';es_CO = 'Línea no se ha seleccionado.';tr = 'Satır seçilmedi.';it = 'La stringa non è selezionata.';de = 'Zeichenfolge ist nicht ausgewählt.'");
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ChangeQuantityByCalculatorEnd after closing quantity change form.
//
&AtClient
Procedure ChangeQuantityUsingCalculatorEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		CurrentData = Items.Inventory.CurrentData;
		If CurrentData <> Undefined Then
			CurrentData.Quantity = Result.Quantity;
			CalculateAmountInTabularSectionLine();
			RecalculateDocumentAtClient();
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler ClearTSInventory form.
//
&AtClient
Procedure ClearTSInventory(Command)
	
	If Object.Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ClearTSInventoryEnd", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Clear the table?'; ru = 'Очистить таблицу?';pl = 'Wyczyść stół?';es_ES = '¿Vaciar la tabla?';es_CO = '¿Vaciar la tabla?';tr = 'Tabloyu temizle?';it = 'Cancellare la tabella?';de = 'Tabelle reinigen?'"), QuestionDialogMode.YesNo,,DialogReturnCode.Yes);
	
EndProcedure

// Procedure - command handler ClearTSInventoryEnd after confirmation delete all strings TS inventory in issue form.
//
&AtClient
Procedure ClearTSInventoryEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		Object.Inventory.Clear();
	EndIf;

EndProcedure

// Procedure - command handler OpenProductsCard form.
//
&AtClient
Procedure OpenProductsCard(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		MTypeRestriction = New Array;
		MTypeRestriction.Add(ProductsTypeInventory);
		MTypeRestriction.Add(ProductsTypeService);
		
		AdditParameters = New Structure("TypeRestriction", MTypeRestriction);
		FillingValues = New Structure("ProductsType", MTypeRestriction);
		
		NewPositionProductsParameters = New Structure("Key, AdditionalParameters, FillingValues", CurrentData.Products, AdditParameters, FillingValues);
		OpenForm("Catalog.Products.ObjectForm", NewPositionProductsParameters, ThisObject);
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'String is not selected.'; ru = 'Не выбрана строка.';pl = 'Ciąg nie został wybrany.';es_ES = 'Línea no se ha seleccionado.';es_CO = 'Línea no se ha seleccionado.';tr = 'Satır seçilmedi.';it = 'La stringa non è selezionata.';de = 'Zeichenfolge ist nicht ausgewählt.'");
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ListCreateSalesSlipForReturn form.
//
&AtClient
Procedure ListCreateSalesSlipForReturn(Command)
	
	MessageText = "";
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.ProductReturn.ObjectForm", New Structure("Basis", CurrentData.Ref));
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Return slip is not allowed to enter based on a ddocument of the %1 type.'; ru = 'Нельзя ввести чек возврата на основании документа типа %1.';pl = 'Zwrot nie może być wprowadzony na podstawie dokumentu tego %1 typu.';es_ES = 'Comprobante de devolución no está permitido para introducción basándose en un documento del %1 tipo.';es_CO = 'Comprobante de devolución no está permitido para introducción basándose en un documento del %1 tipo.';tr = '%1 tür belgeye dayanarak iade fişi girilemez.';it = 'Lo scontrino di restituzione non è permesso in base ad un documento del tipo %1.';de = 'Der Rückschein darf nicht aufgrund eines Dokuments des %1 Typs eingegeben werden.'"),
				TypeOf(CurrentData.Ref));
		EndIf;
	Else
		MessageText = NStr("en = 'Return slip is not selected.'; ru = 'Не выбран чек возврата.';pl = 'Potwierdzenie zwrotu nie zostało wybrane.';es_ES = 'Comprobante de devolución no está seleccionado.';es_CO = 'Comprobante de devolución no está seleccionado.';tr = 'İade fişi seçilmedi.';it = 'Lo scontrino di restituzione non è selezionato.';de = 'Rückschein ist nicht ausgewählt.'");
	EndIf;
	
	If MessageText <> "" Then
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler CreateCreditNoteListForReturn form.
//
&AtClient
Procedure CreateCreditNoteListForReturn(Command)
	
	MessageText = "";
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.CreditNote.ObjectForm", New Structure("Basis, CWP", CurrentData.Ref, True), ThisObject, UUID);
		Else
			MessageText = NStr("en = 'Cannot create receipt CR for return based on the document type:'; ru = 'Невозможно создать чек ККМ а возврат на основании документа:';pl = 'Nie można utworzyć paragonu Kt potwierdzenia odbioru dla zwrotu na podstawie typu dokumentu:';es_ES = 'No se puede crear un ticket CR para retorno a base del documento de tipo:';es_CO = 'No se puede crear un ticket CR para retorno a base del documento de tipo:';tr = 'Belge türüne göre iade için fiş CR oluşturulamıyor:';it = 'Non è possibile creare ricevuta Registratore di Cassa per la restituzione sulla base del tipo di documento:';de = 'Es ist nicht möglich, den Kassenbeleg für die Rückgabe basierend auf der Dokumentart zu erstellen:'") + " " + TypeOf(CurrentData.Ref) + ".";
		EndIf;
	Else
		MessageText = NStr("en = 'Receipt CR is not selected.'; ru = 'Чек ККМ не выбран.';pl = 'Paragon Kt odbioru nie jest zaznaczony.';es_ES = 'Ticket CR no seleccionado.';es_CO = 'Ticket CR no seleccionado.';tr = 'Makbuz CR seçili değil.';it = 'La ricevuta del registratore di cassa non è selezionata.';de = 'Kassenbeleg ist nicht ausgewählt.'");
	EndIf;
	
	If MessageText <> "" Then
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
	EndIf;
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

// Procedure calculates discounts by document.
//
&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                	True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",		False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If the discounts are changed, the function returns True.
//
&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                	False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",     False);
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	DiscountsChanged = False;
	
	LineCount = AppliedDiscounts.TableDiscountsMarkups.Count();
	If LineCount <> Object.DiscountsMarkups.Count() Then
		DiscountsChanged = True;
	Else
		
		If Object.Inventory.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
			DiscountsChanged = True;
		EndIf;
		
		If Not DiscountsChanged Then
			For LineNumber = 1 To LineCount Do
				If    Object.DiscountsMarkups[LineNumber-1].Amount <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].Amount
					OR Object.DiscountsMarkups[LineNumber-1].ConnectionKey <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].ConnectionKey
					OR Object.DiscountsMarkups[LineNumber-1].DiscountMarkup <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].DiscountMarkup Then
					DiscountsChanged = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	If DiscountsChanged Then
		AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	EndIf;
	
	Return DiscountsChanged;
	
EndFunction

// Procedure calculates discounts by document.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "Inventory");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.UseManualDiscounts.Get();
	For Each CurrentRow In Object.Inventory Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
		
		SetDescriptionForTSRowsInventoryAtServer(CurrentRow);
	EndDo;
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure OpenInformationAboutDiscountsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	ParameterStructure.Insert("OnlyMessagesAfterRegistration",   False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	If Not Object.DiscountsAreCalculated Then
		QuestionText = NStr("en = 'The discounts are not applied. Do you want to apply them?'; ru = 'Скидки (наценки) не рассчитаны, рассчитать?';pl = 'Zniżki nie są stosowane. Czy chcesz je zastosować?';es_ES = 'Los descuentos no se han aplicado. ¿Quiere aplicarlos?';es_CO = 'Los descuentos no se han aplicado. ¿Quiere aplicarlos?';tr = 'İndirimler uygulanmadı. Uygulamak istiyor musunuz?';it = 'Gli sconti non sono applicati. Volete applicarli?';de = 'Die Rabatte werden nicht angewendet. Möchten Sie sie anwenden?'");
		
		AdditionalParameters = New Structure; 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	EndIf;
	
EndProcedure

// End modeless window opening "ShowDoQueryBox()". Procedure opens a common form for information analysis about
// discounts by current row.
//
&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row after calculation of automatic discounts (if it was necessary).
//
&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Procedure - event handler Selection of the Inventory tabular section.
//
&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	// Bundles
	InventoryLine = Object.Inventory.FindByID(SelectedRow);
	If Not ReadOnly And ValueIsFilled(InventoryLine.BundleProduct)
		And (Item.CurrentItem = Items.InventoryProducts
			Or Item.CurrentItem = Items.InventoryCharacteristic
			Or Item.CurrentItem = Items.InventoryQuantity
			Or Item.CurrentItem = Items.InventoryMeasurementUnit
			Or Item.CurrentItem = Items.InventoryBundlePicture) Then
			
		StandardProcessing = False;
		EditBundlesComponents(InventoryLine);
		
	// End Bundles
	
	ElsIf (Item.CurrentItem = Items.InventoryAutomaticDiscountPercent OR Item.CurrentItem = Items.InventoryAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient();
		
	EndIf;
	
EndProcedure

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure calls the report form "Used discounts" for current document in the "List" item.
//
&AtClient
Procedure AppliedDiscounts(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		MessageText = NStr("en = 'Document is not selected.
		                   |Go to ""Applied discounts"" is possible only after the selection in list.'; 
		                   |ru = 'Документ не выбран.
		                   |Переход в ""Примененные скидки"" возможен только после выбора из списка.';
		                   |pl = 'Dokument nie jest zaznaczony.
		                   |Przejść do ""Zastosowane rabaty"" jest możliwy tylko po wybraniu z listy.';
		                   |es_ES = 'Documento no se ha seleccionado.
		                   |Ir a ""Descuentos aplicados"" es posible solo después la selección en la lista.';
		                   |es_CO = 'Documento no se ha seleccionado.
		                   |Ir a ""Descuentos aplicados"" es posible solo después la selección en la lista.';
		                   |tr = 'Belge seçilmedi. 
		                   |""Uygulanan indirimler"" ''e geçiş, ancak listedeki seçimden sonra mümkündür.';
		                   |it = 'Il documento non è selezionato.
		                   |Andare a ""Sconti applicati"" è possibile solo dopo la selezione nell''elenco.';
		                   |de = 'Dokument ist nicht ausgewählt.
		                   |Gehe zu ""Ermäßigte Rabatte"" ist nur nach Auswahl in der Liste möglich.'");
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
		Return;
	ElsIf TypeOf(CurrentData.Ref) <> Type("DocumentRef.ShiftClosure") Then
		FormParameters = New Structure("DocumentRef", CurrentData.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	Else
		MessageText = NStr("en = 'Select sales slip or return slip.'; ru = 'Выберите кассовый чек или документ возврата.';pl = 'Wybierz paragon kasowy sprzedaży lub dowód zwrotu.';es_ES = 'Seleccionar un comprobante de ventas o un comprobante de revolución.';es_CO = 'Seleccionar un comprobante de ventas o un comprobante de revolución.';tr = 'Satış fişini veya iade fişini seçin.';it = 'Selezionare uno scontrino di vendita o uno scontrino di restituzione.';de = 'Wählen Sie Kaufbeleg oder Rückschein.'");
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCard(Command)
	
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", , ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

// Final part of procedure - of the form command handler ReadDiscountCard.
// Is called after read form closing of discount card.
//
&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

// Procedure - selection handler of discount card, beginning.
//
&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	ShowUserNotification(
		NStr("en = 'Discount card read'; ru = 'Считана дисконтная карта';pl = 'Karta rabatowa sczytana';es_ES = 'Tarjeta de descuento leída';es_CO = 'Tarjeta de descuento leída';tr = 'İndirim kartı okutulur';it = 'Letta carta sconto';de = 'Rabattkarte gelesen'"),
		GetURL(DiscountCard),
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Discount card %1 is read'; ru = 'Считана дисконтная карта %1';pl = 'Karta rabatowa %1 została sczytana';es_ES = 'Tarjeta de descuento %1 se ha leído';es_CO = 'Tarjeta de descuento %1 se ha leído';tr = 'İndirim kartı %1 okundu';it = 'Letta Carta sconti %1';de = 'Rabattkarte %1 wird gelesen'"), DiscountCard),
		PictureLib.Information32);
	
	DiscountCardIsSelectedAdditionally(DiscountCard);
		
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en = 'Refill discounts in all lines?'; ru = 'Перезаполнить скидки во всех строках?';pl = 'Wypełnić ponownie rabaty we wszystkich wierszach?';es_ES = '¿Volver a rellenar los descuentos en todas las líneas?';es_CO = '¿Volver a rellenar los descuentos en todas las líneas?';tr = 'Tüm satırlarda indirim yapmak ister misiniz?';it = 'Ricalcolare gli sconti in tutte le linee?';de = 'Rabatte in allen Linien auffüllen?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Discount = DriveServer.GetDiscountPercentByDiscountMarkupKind(Object.DiscountMarkupKind) + Object.DiscountPercentByDiscountCard;
	
		For Each TabularSectionRow In Object.Inventory Do
			
			TabularSectionRow.DiscountMarkupPercent = Discount;
			
			CalculateAmountInTabularSectionLine(TabularSectionRow);
			        
		EndDo;
	EndIf;
	
	RecalculateDocumentAtClient();
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");

EndProcedure

#EndRegion

#Region Peripherals

// Procedure displays information output on the customer display.
//
// Parameters:
//  No.
//
&AtClient
Procedure DisplayInformationOnCustomerDisplay()

	If Displays = Undefined Then
		Displays = EquipmentManagerClientReUse.GetEquipmentList("CustomerDisplay", , EquipmentManagerServerCall.GetClientWorkplace());
	EndIf;
	
	display = Undefined;
	DPText = ?(
		Items.Inventory.CurrentData = Undefined,
		"",
		TrimAll(Items.Inventory.CurrentData.Products)
	  + Chars.LF
	  + NStr("en = 'Total'; ru = 'Итого';pl = 'Razem';es_ES = 'Total';es_CO = 'Total';tr = 'Toplam';it = 'Totale';de = 'Gesamt'") + ": "
	  + Format(Object.DocumentAmount, "NFD=2; NGS=' '; NZ=0")
	);
	
	For Each display In Displays Do
		
		// Data preparation
		InputParameters  = New Array();
		Output_Parameters = Undefined;
		
		InputParameters.Add(DPText);
		InputParameters.Add(0);
		
		Result = EquipmentManagerClient.RunCommand(
			display.Ref,
			"DisplayText",
			InputParameters,
				Output_Parameters
		);
		
		If Not Result Then
			MessageText = NStr("en = 'When using customer display error occurred.
			                   |Additional description:
			                   |%AdditionalDetails%'; 
			                   |ru = 'При использовании дисплея покупателя произошла ошибка.
			                   |Дополнительное описание:
			                   |%AdditionalDetails%';
			                   |pl = 'Podczas korzystania z ekranu nabywcy wystąpił błąd.
			                   |Dodatkowy opis:
			                   | %AdditionalDetails%';
			                   |es_ES = 'Utilizando el error de visualización del cliente, ha ocurrido un error. 
			                   |Descripción adicional: 
			                   |%AdditionalDetails%';
			                   |es_CO = 'Utilizando el error de visualización del cliente, ha ocurrido un error. 
			                   |Descripción adicional: 
			                   |%AdditionalDetails%';
			                   |tr = 'Müşteri ekranı kullanılırken hata oluştu. 
			                   | Ek açıklama: 
			                   | %AdditionalDetails%';
			                   |it = 'Durante l''uso si è registrata la visualizzazione di un errore cliente.
			                   |Descrizione aggiuntiva:
			                   |%AdditionalDetails%';
			                   |de = 'Bei der Verwendung der Kundendisplays ist ein Fehler aufgetreten.
			                   |Zusätzliche Beschreibung:
			                   |%AdditionalDetails%'");
			MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			And BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
				StructureProductsData.Insert("Content", "");
				StructureProductsData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			// DiscountCards
			StructureProductsData.Insert("DiscountPercentByDiscountCard", StructureData.DiscountPercentByDiscountCard);
			StructureProductsData.Insert("DiscountCard", StructureData.DiscountCard);
			// End DiscountCards
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(
				StructureProductsData, StructureData.Object, "SalesSlip");
				
			If StructureData.UseDefaultTypeOfAccounting Then 
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "SalesSlip");
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("Object", Object);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	// DiscountCards
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	// End DiscountCards
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			FilterParameters = New Structure;
			FilterParameters.Insert("Products",			BarcodeData.Products);
			FilterParameters.Insert("Characteristic",	BarcodeData.Characteristic);
			FilterParameters.Insert("MeasurementUnit",	BarcodeData.MeasurementUnit);
			FilterParameters.Insert("Batch",			BarcodeData.Batch);
			// Bundles
			FilterParameters.Insert("BundleProduct",	PredefinedValue("Catalog.Products.EmptyRef"));
			// End Bundles
			TSRowsArray = Object.Inventory.FindRows(FilterParameters);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				// Bundles
				If BarcodeData.StructureProductsData.IsBundle Then
					ReplaceInventoryLineWithBundleData(ThisObject, NewRow, BarcodeData.StructureProductsData);
				Else
				// End Bundles
					CalculateAmountInTabularSectionLine(NewRow);
					Items.Inventory.CurrentRow = NewRow.GetID();
				EndIf;
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
			
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
	RecalculateDocumentAtClient();
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// Procedure - tabular section command bar command handler.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	
	NotifyDescription = New NotifyDescription("SearchByBarcodeEnd", ThisObject);
	ShowInputValue(NotifyDescription, CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined AND AdditionalParameters = Undefined Then
		Return;
	EndIf;
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;
	
EndProcedure

#EndRegion

#Region SettingDynamicListPeriods

// Procedure fills selection lists in items which manage the period in document lists.
//
&AtServer
Procedure FillPeriodKindLists()
	
	Items.MagazinePeriodKind.ChoiceList.Clear();
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForCurrentShift);
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForPreviousShift);
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForUserDefinedPeriod);
	
	Items.SalesSlipPeriodKind.ChoiceList.Clear();
	Items.SalesSlipPeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForCurrentShift);
	Items.SalesSlipPeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForPreviousShift);
	Items.SalesSlipPeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForUserDefinedPeriod);
	
	Items.SalesSlipPeriodKindForReturn.ChoiceList.Clear();
	Items.SalesSlipPeriodKindForReturn.ChoiceList.Add(Enums.CWPPeriodTypes.ForCurrentShift);
	Items.SalesSlipPeriodKindForReturn.ChoiceList.Add(Enums.CWPPeriodTypes.ForPreviousShift);
	Items.SalesSlipPeriodKindForReturn.ChoiceList.Add(Enums.CWPPeriodTypes.ForUserDefinedPeriod);
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item LogPeriodKind form.
//
&AtClient
Procedure JournalPeriodKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "List");
	StandardProcessing = False;
	Items.MagazinePeriodKind.UpdateEditText();
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item SalesSlipPeriodKind form.
//
&AtClient
Procedure SalesSlipPeriodKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "SalesSlipList");
	StandardProcessing = False;
	Items.SalesSlipPeriodKind.UpdateEditText();
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item SalesSlipPeriodKindForReturn form.
//
&AtClient
Procedure SalesSlipPeriodKindForReturnChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "SalesSlipListForReturn");
	StandardProcessing = False;
	Items.SalesSlipPeriodKindForReturn.UpdateEditText();
	
EndProcedure

// Procedure sets dynamic list period.
//
&AtClient
Procedure SetPeriodAtClient(PeriodKindCWP, ListName, ParameterStandardPeriod = Undefined)
	
	If PeriodKindCWP = ThisObject.ForUserDefinedPeriod Then
		
		If ListName = "List" Then
			CatalogPeriodKindTransfer = PeriodKindCWP;
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturnTransfer = PeriodKindCWP;
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodTransferKind = PeriodKindCWP;
		EndIf;
		
		NotifyDescription = New NotifyDescription("SetEndOfPeriod", ThisObject, New Structure("ListName", ListName));
		Dialog = New StandardPeriodEditDialog();
		Dialog.Period = ThisObject.Items[ListName].Period;
		Dialog.Show(NotifyDescription);
		
	Else
		
		SetPeriodAtServer(PeriodKindCWP, ListName, ParameterStandardPeriod);
		
	EndIf;
	
EndProcedure

// Procedure sets dynamic list period (if it is required period interactive selection).
//
&AtClient
Procedure SetEndOfPeriod(Result, Parameters) Export
	
	SetEndOfPeriodAtServer(Result, Parameters);
	
EndProcedure

// Procedure sets dynamic list period on server (if it is required period interactive selection).
//
&AtServer
Procedure SetEndOfPeriodAtServer(Result, Parameters)
	
	If Result <> Undefined Then
		
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("Status", SessionIsOpen);
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("FilterByChange", False);
		
		Items[Parameters.ListName].Period.Variant = Result.Variant;
		Items[Parameters.ListName].Period.StartDate = Result.StartDate;
		Items[Parameters.ListName].Period.EndDate = Result.EndDate;
		Items[Parameters.ListName].Refresh();
		
		If Parameters.ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = GetPeriodPresentation(Result, " - ");
		ElsIf Parameters.ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = GetPeriodPresentation(Result, " - ");
		ElsIf Parameters.ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = GetPeriodPresentation(Result, " - ");
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure sets dynamic list period on server.
//
&AtServer
Procedure SetPeriodAtServer(PeriodKindCWP, ListName, ParameterStandardPeriod = Undefined)
	
	If ListName = "List" Then
		CatalogPeriodKindTransfer = PeriodKindCWP;
	ElsIf ListName = "SalesSlipListForReturn" Then
		SalesSlipPeriodKindForReturnTransfer = PeriodKindCWP;
	ElsIf ListName = "SalesSlipList" Then
		SalesSlipPeriodTransferKind = PeriodKindCWP;
	EndIf;
	
	If PeriodKindCWP = ForCurrentShift Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", True);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = String(ForCurrentShift);
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = String(ForCurrentShift);
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = String(ForCurrentShift);
		EndIf;
		
	ElsIf PeriodKindCWP = ForPreviousShift Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", True);
		ThisObject[ListName].Parameters.SetParameterValue("CashCRSession", GetLatestClosedCashCRSession());
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = String(ForPreviousShift);
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = String(ForPreviousShift);
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = String(ForPreviousShift);
		EndIf;
		
	ElsIf PeriodKindCWP = ForYesterday Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Refresh();
		Items[ListName].Period.StartDate = BegOfDay(BegOfDay(CurrentSessionDate())-1);
		Items[ListName].Period.EndDate = BegOfDay(CurrentSessionDate())-1;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = String(ForYesterday);
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = String(ForYesterday);
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = String(ForYesterday);
		EndIf;
		
	ElsIf PeriodKindCWP = ForUserDefinedPeriod Then
		
		Items[ListName].Period.StartDate = ParameterStandardPeriod.StartDate;
		Items[ListName].Period.EndDate = ParameterStandardPeriod.EndDate;
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = GetPeriodPresentation(Items.List.Period, " - ");
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = GetPeriodPresentation(Items.SalesSlipListForReturn.Period, " - ");
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = GetPeriodPresentation(Items.SalesSlipList.Period, " - ");
		EndIf;
		
	ElsIf PeriodKindCWP = ForEntirePeriod Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = String(ForEntirePeriod);
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = String(ForEntirePeriod);
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = String(ForEntirePeriod);
		EndIf;
		
	EndIf;
	
EndProcedure

// Function returns the standard period presentation.
//
&AtClientAtServerNoContext
Function GetPeriodPresentation(StandardPeriod, Delimiter)
	
	StartDate = StandardPeriod.StartDate;
	EndDate = StandardPeriod.EndDate;
	If Not ValueIsFilled(StartDate) AND Not ValueIsFilled(EndDate) Then
		Return String(PredefinedValue("Enum.CWPPeriodTypes.ForEntirePeriod"));
	ElsIf Year(StartDate) = Year(EndDate) AND Month(StartDate) = Month(EndDate) Then
		Return Format(StartDate, "DF=dd")+Delimiter+Format(EndDate, "DLF=D");
	ElsIf Year(StartDate) = Year(EndDate) Then
		Return Format(StartDate, "DF=dd.MM")+Delimiter+Format(EndDate, "DLF=D");
	Else
		Return Format(StartDate, "DLF=D")+Delimiter+Format(EndDate, "DLF=D");
	EndIf;
	
EndFunction

#EndRegion

#Region QuickSale

// Procedure creates buttons on fast goods panel.
//
&AtServer
Procedure FillFastGoods(OnOpen = False)

	ColumnQuantity = 3;
	
	Workplace = EquipmentManagerServerCall.GetClientWorkplace();
	
	If Not ValueIsFilled(Workplace) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Failed to identify workplace to work with peripherals.'; ru = 'Не обнаружено рабочее место для работы с внешним оборудованием';pl = 'Nie udało się zidentyfikować miejsca pracy do pracy z urządzeniami peryferyjnymi.';es_ES = 'Se ha fallado identificar el lugar de trabajo para trabajar con periféricos.';es_CO = 'Se ha fallado identificar el lugar de trabajo para trabajar con periféricos.';tr = 'Çevre birimleriyle çalışmak için çalışma alanı tanımlanamadı.';it = 'Non riuscito ad identificare un posto di lavoro che lavora con le periferiche.';de = 'Der Arbeitsplatz konnte nicht identifiziert werden, um mit Peripheriegeräten zu arbeiten.'");
		Message.Message();
		Return;
	EndIf;
	
	CWPSetting = CashierWorkplaceServerCall.GetCWPSetup(Workplace);
	If Not ValueIsFilled(CWPSetting) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Failed to receive the CWP settings for current workplace.'; ru = 'Не удалось получить настройки РМК для текущего рабочего места';pl = 'Nie można odebrać ustawień MPK dla bieżącego miejsca pracy.';es_ES = 'Se ha fallado recibir los ajustes CWP para el lugar de trabajo actual.';es_CO = 'Se ha fallado recibir los ajustes CWP para el lugar de trabajo actual.';tr = 'Mevcut çalışma alanı için kasiyer çalışma alanı ayarları alınamadı.';it = 'Non riuscito a ricevere le impostazione della cassa  per il posto di lavoro corrente.';de = 'Die CWP-Einstellungen für den aktuellen Arbeitsplatz konnten nicht empfangen werden.'");
		Message.Message();
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	QuickSale.Products AS Products,
		|	QuickSale.Characteristic AS Characteristic,
		|	QuickSale.Ctrl,
		|	QuickSale.Shift,
		|	QuickSale.Alt,
		|	QuickSale.Shortcut,
		|	QuickSale.Key,
		|	QuickSale.Title,
		|	QuickSale.Products.UseCharacteristics AS CharacteristicsAreUsed,
		|	QuickSale.Products.Description AS Description,
		|	QuickSale.Characteristic.Description,
		|	CASE
		|		WHEN QuickSale.SortingField = """"
		|			THEN QuickSale.Products.Description
		|		ELSE QuickSale.SortingField
		|	END AS SortingField
		|FROM
		|	Catalog.CashierWorkplaceSettings.QuickSale AS QuickSale
		|WHERE
		|	QuickSale.Ref = &CWPSetting
		|	AND Not QuickSale.Disabled
		|
		|ORDER BY
		|	SortingField,
		|	Products,
		|	Characteristic
		|AUTOORDER";
	
	Query.SetParameter("CWPSetting", CWPSetting);
	
	MResults = Query.ExecuteBatch();
	
	ResultTable = MResults[0].Unload();
	
	// Delete commands.
	If Not OnOpen Then
		DeletedCommandArray = New Array;
		For Each Command In Commands Do
			If (Find(Command.Name, "QuickProduct_") > 0) 
				OR (Find(Command.Name, "FastGoodsGroup_") > 0) 
				Then
				DeletedCommandArray.Add(Command);
			EndIf;
		EndDo;
		For Each Command In DeletedCommandArray Do
			Commands.Delete(Command);
		EndDo;
		// Delete items.
		DeletedItemsArray = New Array;
		For Each Item In Items Do
			If (Find(Item.Name, "QuickProduct_") > 0) 
				OR (Find(Item.Name, "GroupPaymentByCard_") > 0) 
				OR (Find(Item.Name, "FastGoodsGroup_")) Then
				DeletedItemsArray.Add(Item);
			EndIf;
		EndDo;
		For Each Item In DeletedItemsArray Do
			Try
				Items.Delete(Item);
			Except EndTry;
		EndDo;
		
		QuickSale.Clear();
	EndIf;
	
	CurAcc = 1;
	For Each QuickProduct In ResultTable Do
		If Not ValueIsFilled(QuickProduct.Products) Then
			Continue;
		EndIf;
		
		NewRow = QuickSale.Add();
		FillPropertyValues(NewRow, QuickProduct);
		
		ButtonName = "QuickProduct_" + QuickSale.IndexOf(NewRow);
			
		NewCommand = Commands.Add(ButtonName);
		NewCommand.Action = "FastGoodsIsSelected";
		If ValueIsFilled(QuickProduct.Title) Then
			NewCommand.Title = QuickProduct.Title;
		Else
			NewCommand.Title = String(QuickProduct.Description)+?(ValueIsFilled(QuickProduct.CharacteristicDescription), ". "+TrimAll(QuickProduct.CharacteristicDescription), "");
		EndIf;
		NewCommand.Representation               = ButtonRepresentation.Text;
		NewCommand.ModifiesStoredData = True;
		If ValueIsFilled(QuickProduct.Key) Then
			NewCommand.Shortcut           = New Shortcut(Key[QuickProduct.Key], QuickProduct.Alt, QuickProduct.Ctrl, QuickProduct.Shift);
		EndIf;
		
		If CurAcc = 1 OR (CurAcc-1) % ColumnQuantity = 0 Then
			NewFolder = Items.Add("GroupPaymentByCard_"+CurAcc, Type("FormGroup"), Items.ButtonsGroupFastProducts);
			NewFolder.Type = FormGroupType.UsualGroup;
			NewFolder.ShowTitle = False;
			NewFolder.Group = ChildFormItemsGroup.Horizontal;
		EndIf;

		NewButton = Items.Add(ButtonName, Type("FormButton"), NewFolder);
		NewButton.OnlyInAllActions = False;
		NewButton.Visible = True;
		NewButton.CommandName = NewCommand.Name;
		If ValueIsFilled(QuickProduct.Title) Then
			NewButton.Title = TrimAll(QuickProduct.Title);
		Else
			NewButton.Title = TrimAll(QuickProduct.Description)+?(ValueIsFilled(QuickProduct.CharacteristicDescription), ". "+TrimAll(QuickProduct.CharacteristicDescription), "");
		EndIf;
		CombinationPresentation = ShortcutPresentation(NewCommand.Shortcut);
		If ValueIsFilled(CombinationPresentation) Then
			NewButton.Title = Left(TrimAll(NewButton.Title), 20) + " " + CombinationPresentation;
		EndIf;
		
		NewButton.Width = 0;
		NewButton.AutoMaxWidth = True;
		NewButton.Height = 3;
		NewButton.TitleHeight = 3;
		NewButton.Shortcut = NewCommand.Shortcut;
		
		NewRow.CommandName = ButtonName;
		
		CurAcc = CurAcc + 1;
	EndDo;
	
	If CurAcc > ColumnQuantity Then
		While (CurAcc-1) % ColumnQuantity <> 0 Do
			NewDecoration = Items.Add("LabelDecoration_"+CurAcc, Type("FormDecoration"), NewFolder);
			NewDecoration.Type = FormDecorationType.Label;
			NewDecoration.Title = "";
			NewDecoration.Width = 7;
			NewDecoration.Height = 3;
			
			CurAcc = CurAcc + 1;
		EndDo;
	EndIf;
	
	// Fast goods setting button.
	CurAcc = CurAcc + 1;
	
	NewFolder = Items.Add("GroupPaymentByCard_"+CurAcc, Type("FormGroup"), Items.ButtonsGroupFastProducts);
	NewFolder.Type = FormGroupType.UsualGroup;
	NewFolder.ShowTitle = False;
	NewFolder.Group = ChildFormItemsGroup.Horizontal;
	
	NewButton = Items.Add("QuickProductsSettings", Type("FormButton"), NewFolder);
	NewButton.Representation = ButtonRepresentation.Picture;
	NewButton.OnlyInAllActions = False;
	NewButton.Visible = True;
	NewButton.CommandName = "QuickProductsSettings";
	NewButton.Title = "Settings";
	NewButton.Width = 3;
	NewButton.Height = 1;
	NewButton.Shortcut = New Shortcut(Key.S, True, False, False);
	
EndProcedure

// Procedure - handler fast goods button click.
&AtClient
Procedure FastGoodsIsSelected(Command)
	
	FoundStrings = QuickSale.FindRows(New Structure("CommandName", ""+Command.Name));
	If FoundStrings.Count() > 0 Then
		
		FilterStructure = New Structure("Products, Characteristic", FoundStrings[0].Products, FoundStrings[0].Characteristic);
		InventoryFoundStrings = Object.Inventory.FindRows(FilterStructure);
		
		If InventoryFoundStrings.Count() = 0 Then
			NewRow = Object.Inventory.Add();
			NewRow.Products = FoundStrings[0].Products;
			NewRow.Characteristic = FoundStrings[0].Characteristic;
			
			DocumentConvertedAtClient = False;
			ProductsOnChange(NewRow);
		Else
			InventoryFoundStrings[0].Quantity = InventoryFoundStrings[0].Quantity + 1;
			
			DocumentConvertedAtClient = False;
			CalculateAmountInTabularSectionLine(InventoryFoundStrings[0]);
			
			NewRow = InventoryFoundStrings[0];
		EndIf;
		
		SetDescriptionForStringTSInventoryAtClient(NewRow);
		
		Items.Inventory.Refresh();
		Items.List.CurrentRow = NewRow.GetID();
		
		RecalculateDocumentAtClient();
		
		Items.Inventory.CurrentRow = NewRow.GetID();
		
		SwitchJournalQuickProducts = 2;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region KeyboardShortcuts

// The function returns
// the parameters key presentation:
// ValueKey						- Key
//
// Returned
// value String - Key presentation
//
&AtServer
Function KeyPresentation(ValueKey) Export
	
	If String(Key._1) = String(ValueKey) Then
		Return "1";
	ElsIf String(Key._2) = String(ValueKey) Then
		Return "2";
	ElsIf String(Key._3) = String(ValueKey) Then
		Return "3";
	ElsIf String(Key._4) = String(ValueKey) Then
		Return "4";
	ElsIf String(Key._5) = String(ValueKey) Then
		Return "5";
	ElsIf String(Key._6) = String(ValueKey) Then
		Return "6";
	ElsIf String(Key._7) = String(ValueKey) Then
		Return "7";
	ElsIf String(Key._8) = String(ValueKey) Then
		Return "8";
	ElsIf String(Key._9) = String(ValueKey) Then
		Return "9";
	ElsIf String(Key.Num0) = String(ValueKey) Then
		Return "Num 0";
	ElsIf String(Key.Num1) = String(ValueKey) Then
		Return "Num 1";
	ElsIf String(Key.Num2) = String(ValueKey) Then
		Return "Num 2";
	ElsIf String(Key.Num3) = String(ValueKey) Then
		Return "Num 3";
	ElsIf String(Key.Num4) = String(ValueKey) Then
		Return "Num 4";
	ElsIf String(Key.Num5) = String(ValueKey) Then
		Return "Num 5";
	ElsIf String(Key.Num6) = String(ValueKey) Then
		Return "Num 6";
	ElsIf String(Key.Num7) = String(ValueKey) Then
		Return "Num 7";
	ElsIf String(Key.Num8) = String(ValueKey) Then
		Return "Num 8";
	ElsIf String(Key.Num9) = String(ValueKey) Then
		Return "Num 9";
	ElsIf String(Key.NumAdd) = String(ValueKey) Then
		Return "Num +";
	ElsIf String(Key.NumDecimal) = String(ValueKey) Then
		Return "Num .";
	ElsIf String(Key.NumDivide) = String(ValueKey) Then
		Return "Num /";
	ElsIf String(Key.NumMultiply) = String(ValueKey) Then
		Return "Num *";
	ElsIf String(Key.NumSubtract) = String(ValueKey) Then
		Return "Num -";
	Else
		Return String(ValueKey);
	EndIf;
	
EndFunction

// The function returns
// the parameters key presentation:
// Shortcut						- Combination of keys that
// require WithoutBrackets presentation							- The flag indicating that the presentation shall be formed without brackets
//
// Returned
// value String - Key combination presentation
//
&AtServer
Function ShortcutPresentation(Shortcut, WithoutParentheses = False) Export
	
	If Shortcut.Key = Key.None Then
		Return "";
	EndIf;
	
	Description = ?(WithoutParentheses, "", "(");
	If Shortcut.Ctrl Then
		Description = Description + "Ctrl+"
	EndIf;
	If Shortcut.Alt Then
		Description = Description + "Alt+"
	EndIf;
	If Shortcut.Shift Then
		Description = Description + "Shift+"
	EndIf;
	Description = Description + KeyPresentation(Shortcut.Key) + ?(WithoutParentheses, "", ")");
	
	Return Description;
	
EndFunction

#EndRegion

#Region StringPresentationTSInventoryOnReceipt

// Function returns information about quantity and amounts in string form. Used to fill receipt content on a "Return" bookmark.
//
&AtServer
Function GetDescriptionForTSStringInventoryAtServer(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	ProductsCharacteristicAndBatch = TrimAll(String.Products.Description)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	Return ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
EndFunction

// Function fills the DataByString and ProductsCharacteristicAndBatch attributes string TS Inventory.
//
&AtClient
Function SetDescriptionForStringTSInventoryAtClient(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	String.ProductsCharacteristicAndBatch = TrimAll(""+String.Products)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	String.DataOnRow = ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
	ShowHideDealAtClient();
	
EndFunction

// Function fills the DataByString and ProductsCharacteristicAndBatch attributes string TS Inventory.
//
&AtServer
Function SetDescriptionForTSRowsInventoryAtServer(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	String.ProductsCharacteristicAndBatch = TrimAll(""+String.Products)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	String.DataOnRow = ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
EndFunction

// Function fills the DataByString and ProductsCharacteristicAndBatch attributes for all strings TS Inventory.
//
&AtClient
Procedure FillInDetailsForTSInventoryAtClient()
	
	For Each CurrentRow In Object.Inventory Do
		SetDescriptionForStringTSInventoryAtClient(CurrentRow);
	EndDo;
	
EndProcedure

#EndRegion

#Region WorkWithSerialNumbers

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier);
	
EndFunction

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtClient
Procedure OpenSerialNumbersSelection()
	
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtClient
Procedure InventoryCharacteristicAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	
	// Bundles
	CurrentRow = Items.Inventory.CurrentData;
	
	If CurrentRow.IsBundle Then
		
		StandardProcessing = False;
		ChoiceData = BundleCharacteristics(CurrentRow.Products, Text);
		
	EndIf;
	// End Bundles

EndProcedure

#EndRegion
