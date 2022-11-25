
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "CommonForm.InventoryOwnership" Then
		EditOwnershipProcessingAtClient(SelectedValue.TempStorageInventoryOwnershipAddress);
	EndIf;
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetAccountingPolicyValues();
	
	If ValueIsFilled(Object.SalesSlipNumber)
	AND Not CashCRUseWithoutEquipmentConnection Then
		SetModeReadOnly();
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		GetChoiceListOfPaymentCardKinds();
	EndIf;
	
	UsePeripherals = DriveReUse.UsePeripherals();
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.DocumentTax.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.DocumentTax.Visible = False;
	EndIf;
	
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
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();
	
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	ProcessingCompanyVATNumbers();
	
	ETUseWithoutEquipmentConnection = Object.POSTerminal.UseWithoutEquipmentConnection;
	Items.PaymentWithPaymentCardsCancelPayment.Visible = Not ETUseWithoutEquipmentConnection;
	
	Items.InventoryDiscountAmount.Visible = Constants.UseManualDiscounts.Get();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly 	= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountAmount.ReadOnly 			= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
EndProcedure

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	For Each CurRow In Object.Inventory Do
		CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
	EndDo;
	
EndProcedure

// Procedure - OnReadAtServer event handler of the form.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	FillAddedColumns();
	
	GetChoiceListOfPaymentCardKinds();
	Items.IssueReceipt.Enabled = Not Object.DeletionMark;
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)

	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals

	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification("Update:", 
										GetURL(Object.Ref), 
										String(Object.Ref)+NStr("en = '. The automatic discounts are applied.'; ru = '. Автоматические скидки (наценки) рассчитаны!';pl = '. Stosowane są rabaty automatyczne.';es_ES = '. Descuentos automáticos se han aplicado.';es_CO = '. Descuentos automáticos se han aplicado.';tr = '. Otomatik indirimler uygulandı.';it = '. Sconti automatici sono stati applicati.';de = '. Die automatischen Rabatte werden angewendet.'"), 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts

EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "RefreshSalesSlipDocumentsListForm" Then
		For Each CurRow In Object.Inventory Do
			CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
		EndDo;
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
	
EndProcedure

// BeforeRecord event handler procedure.
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
	
	Notify("RefreshSalesSlipDocumentsListForm");
	Notify("RefreshAccountingTransaction");
	
	// CWP
	If TypeOf(FormOwner) = Type("ClientApplicationForm")
		AND Find(FormOwner.FormName, "DocumentForm_CWP") > 0 
		Then
		Notify("CWP_Write_ProductReturn", New Structure("Ref, Number, Date", Object.Ref, Object.Number, Object.Date));
	EndIf;
	// End CWP
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EditOwnership(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TempStorageAddress", PutEditOwnershipDataToTempStorage());
	
	OpenForm("CommonForm.InventoryOwnership", FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	FillAddedColumns(True);
		
	FillVATRateByCompanyVATTaxation();
	
	ProcessingCompanyVATNumbers(False);
	
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	FillAddedColumns(True);
	FillVATRateByCompanyVATTaxation();
	
EndProcedure

// Procedure recalculates the document on client.
//
&AtClient
Procedure RecalculateDocumentAtClient()
	
	Object.DocumentAmount = Object.Inventory.Total("Total");
	Object.DocumentTax = Object.Inventory.Total("VATAmount");
	Object.DocumentSubtotal = Object.DocumentAmount - Object.DocumentTax;
	
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
		ValueIsFilled(Object.CashCR) AND ValueIsFilled(Object.CashCR.Peripherals),
		Object.CashCR.Peripherals.Ref,
		Catalogs.Peripherals.EmptyRef()
	);
	
	POSTerminal = ?(
		ValueIsFilled(Object.POSTerminal) AND ValueIsFilled(Object.POSTerminal.Peripherals),
		Object.POSTerminal.Peripherals,
		Catalogs.Peripherals.EmptyRef()
	);
	
	Items.PaymentWithPaymentCardsCancelPayment.Enabled = ValueIsFilled(POSTerminal);
	
EndProcedure

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	If WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, False)
		And Object.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT Then
		Return;
	EndIf;
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.DocumentTax.Visible = True;
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.DocumentTax.Visible = False;
		
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
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, 
		"MeasurementUnit, VATRate, Description, DescriptionFull, SKU");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
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
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", 
			Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
	
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;

	Return StructureData;
	
EndFunction

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
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
	DocumentDate = Object.Date;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Procedure DateOnChangeAtServer()
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	
EndProcedure

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

// VAT amount is calculated in the row of tabular section.
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

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
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
	
	// AutomaticDiscounts.
	RecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	
	// If picture was changed that focus goes from TS and procedure RecalculateDocumentAtClient() is not called.
	If RecalculationIsRequired Then
		RecalculateDocumentAtClient();
	EndIf;
	// End AutomaticDiscounts
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
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
	
	If TabularSectionRow.Quantity * TabularSectionRow.Price < TabularSectionRow.DiscountAmount Then
		TabularSectionRow.DiscountAmount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	If TabularSectionRow.Price <> 0
	   AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.DiscountMarkupPercent = (1 - TabularSectionRow.Amount / (TabularSectionRow.Price * TabularSectionRow.Quantity)) * 100;
	Else
		TabularSectionRow.DiscountMarkupPercent = 0;
	EndIf;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets mode Only view.
//
&AtServer
Procedure SetModeReadOnly()
	
	ReadOnly = True; // Receipt is issued. Change information is forbidden.
	Items.IssueReceipt.Enabled = False;
	Items.PaymentWithPaymentCardsCancelPayment.Enabled = False;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Receipt print procedure on fiscal register.
//
&AtClient
Procedure IssueReceipt()
	
	ErrorDescription = "";
	
	If Object.SalesSlipNumber <> 0
	AND Not CashCRUseWithoutEquipmentConnection Then
		
		MessageText = NStr("en = 'Receipt has already been issued on the fiscal data recorder.'; ru = 'Чек уже пробит на фискальном регистраторе!';pl = 'Paragon został już wydrukowany przez rejestrator fiskalny.';es_ES = 'Recibo ya se ha emitido en el registro de datos fiscales.';es_CO = 'Recibo ya se ha emitido en el registro de datos fiscales.';tr = 'Fiş zaten mali veri kayıt cihazında yayınlanmıştır.';it = 'La ricevuta è già stato emessa nel registratore fiscale.';de = 'Der Beleg wurde bereits an den Steuer Datenschreiber ausgegeben.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	ShowMessageBox = False;
	If Object.PaymentWithPaymentCards.Count() = 0 OR DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		DeviceIdentifierET = Undefined;
		DeviceIdentifierFR = Undefined;
		ResultFR               = True;
		ResultET               = True;
		
		If UsePeripherals Then
			
			If EquipmentManagerClient.RefreshClientWorkplace() Then
				
				// Device selection FR
				DeviceIdentifierFR = ?(
					ValueIsFilled(FiscalRegister),
					FiscalRegister,
					Undefined
				);
				
				If DeviceIdentifierFR <> Undefined OR CashCRUseWithoutEquipmentConnection Then
					
					If Not CashCRUseWithoutEquipmentConnection Then
						
						// FR device connection
						ResultFR = EquipmentManagerClient.ConnectEquipmentByID(
							UUID,
							DeviceIdentifierFR,
							ErrorDescription
						);
						
					EndIf;
					
					If ResultFR OR CashCRUseWithoutEquipmentConnection Then
						
						// It is required to check and cancel noncash payments in advance
						If ValueIsFilled(POSTerminal)
						   AND Object.PaymentWithPaymentCards.Count() > 0
						   AND Not ETUseWithoutEquipmentConnection Then
							
							// Device selection ET
							DeviceIdentifierET = ?(
								ValueIsFilled(POSTerminal),
								POSTerminal,
								Undefined
							);
							
							If DeviceIdentifierET <> Undefined Then
								
								// ET device connection
								ResultET = EquipmentManagerClient.ConnectEquipmentByID(
									UUID,
									DeviceIdentifierET,
									ErrorDescription
								);
								
								If ResultET Then
									
									For Each OperationPayment In Object.PaymentWithPaymentCards Do
										
										If OperationPayment.PaymentCanceled Then
											Continue;
										EndIf;
										
										AmountOfOperations       = OperationPayment.Amount;
										CardNumber          = OperationPayment.ChargeCardNo;
										OperationRefNumber = OperationPayment.RefNo;
										ETReceiptNo         = OperationPayment.ETReceiptNo;
										SlipCheckString      = "";
										
										InputParameters  = New Array();
										Output_Parameters = Undefined;
										
										InputParameters.Add(AmountOfOperations);
										InputParameters.Add(OperationRefNumber);
										InputParameters.Add(ETReceiptNo);
										
										// Executing the operation on POS terminal
										ResultET = EquipmentManagerClient.RunCommand(
											DeviceIdentifierET,
											"AuthorizeVoid",
											InputParameters,
											Output_Parameters
										);
										
										If Not ResultET Then
											
											MessageText = NStr("en = 'When operation execution there
											                   |was error: ""%ErrorDescription%"".
											                   |Cancellation by card has not been performed.'; 
											                   |ru = 'При выполнении операции возникла ошибка:
											                   |""%ErrorDescription%"".
											                   |Отмена по карте не была произведена.';
											                   |pl = 'W trakcie realizacji operacji wystąpił
											                   |błąd: ""%ErrorDescription%"".
											                   |Anulowanie z karty nie zostało wykonane.';
											                   |es_ES = 'Ejecutando la operación,
											                   |se ha producido el error: ""%ErrorDescription%"".
											                   |Cancelación con tarjeta no se ha realizado.';
											                   |es_CO = 'Ejecutando la operación,
											                   |se ha producido el error: ""%ErrorDescription%"".
											                   |Cancelación con tarjeta no se ha realizado.';
											                   |tr = 'İşlem esnasında bir 
											                   |hata oluştu: ""%ErrorDescription%"". 
											                   |Kartla iptal işlemi yapılmadı.';
											                   |it = 'Durante l''esecuzione dell''operazione
											                   |si è registrato un errore: ""%ErrorDescription%"".
											                   |La cancellazione con carta non è stata eseguita.';
											                   |de = 'Bei der Ausführung der Operation gab es
											                   |einen Fehler: ""%ErrorDescription%"".
											                   |Die Stornierung durch die Karte wurde nicht durchgeführt.'");
											MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
											CommonClientServer.MessageToUser(MessageText);
											
										Else
											
											If Not IsBlankString(Output_Parameters[0][1]) Then
												
												glPeripherals.Insert("LastSlipReceipt", Output_Parameters[0][1]);
												
											EndIf;
											
											CardNumber          = "";
											OperationRefNumber = "";
											ETReceiptNo         = "";
											SlipCheckString      = Output_Parameters[0][1];
											
											If Not IsBlankString(SlipCheckString) Then
												
												InputParameters  = New Array();
												InputParameters.Add(SlipCheckString);
												Output_Parameters = Undefined;
												
												ResultFR = EquipmentManagerClient.RunCommand(
													DeviceIdentifierFR,
													"PrintText",
													InputParameters,
													Output_Parameters
												);
												
											EndIf;
											
										EndIf;
										
										If ResultET AND Not ResultFR Then
											
											ErrorDescriptionFR = Output_Parameters[1];
											
											MessageText = NStr("en = 'When printing slip receipt
											                   |there was error: ""%ErrorDescription%"".
											                   |Operation by card has been cancelled.'; 
											                   |ru = 'При печати слип-чека
											                   |возникла ошибка: ""%ErrorDescription%"".
											                   |Операция по карте была отменена.';
											                   |pl = 'W trakcie drukowania paragonu wystąpił
											                   |błąd: ""%ErrorDescription%"".
											                   |Operacja z kartą została anulowana.';
											                   |es_ES = 'Imprimiendo el recibo del comprobante
											                   |, se ha producido el error: ""%ErrorDescription%"".
											                   |Operación con tarjeta se ha cancelado.';
											                   |es_CO = 'Imprimiendo el recibo del comprobante
											                   |, se ha producido el error: ""%ErrorDescription%"".
											                   |Operación con tarjeta se ha cancelado.';
											                   |tr = 'Fiş yazdırılırken
											                   |hata oluştu: ""%ErrorDescription%"".
											                   |Kartla işlem iptal edildi.';
											                   |it = 'Durante la stampa dello scontrino
											                   |c''è stato un errore: ""%ErrorDescription%"".
											                   |L''operazione con la carta è stata cancellata.';
											                   |de = 'Beim Drucken des Belegs
											                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
											                   |Die Bedienung per Karte wurde abgebrochen.'");
											MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescriptionFR);
											CommonClientServer.MessageToUser(MessageText);
											
										ElsIf ResultET Then
											
											OperationPayment.PaymentCanceled = True;
											
										EndIf;
										
									EndDo;
									
									// ET device disconnect
									EquipmentManagerClient.DisableEquipmentById(
										UUID,
										DeviceIdentifierET
									);
									
								Else
									
									MessageText = NStr("en = 'When POS terminal connection there
									                   |was error: ""%ErrorDescription%"".
									                   |Operation by card has not been performed.'; 
									                   |ru = 'При подключении эквайрингового
									                   |терминала произошла ошибка: ""%ErrorDescription%"".
									                   |Операция по карте не была выполнена.';
									                   |pl = 'W trakcie połączenia terminala POS wystąpił
									                   |błąd: ""%ErrorDescription%"".
									                   |Operacja z kartą nie została wykonana.';
									                   |es_ES = 'Conectando el terminal TPV, se ha
									                   |producido el error: ""%ErrorDescription%"".
									                   |Operación con tarjeta no se ha realizado.';
									                   |es_CO = 'Conectando el terminal TPV, se ha
									                   |producido el error: ""%ErrorDescription%"".
									                   |Operación con tarjeta no se ha realizado.';
									                   |tr = 'POS terminali bağlantısında hata oluştu:
									                   |""%ErrorDescription%"".
									                   |Kartla işlem yapılamadı.';
									                   |it = 'Alla connessione del terminale POS,
									                   |si è verificato un errore: ""%ErrorDescription%"".
									                   |L''operazione  con carta non è stata eseguita.';
									                   |de = 'Beim Anschluss des POS-Terminals
									                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
									                   |Die Operation mit der Karte wurde nicht ausgeführt.'");
									MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescription);
									CommonClientServer.MessageToUser(MessageText);
									
								EndIf;
								
							EndIf;
							
						EndIf;
						
						// Write the document for data loss prevention
						PostingResult = True;
						If Object.PaymentWithPaymentCards.Count() <> 0 Then
							
							PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
							
						EndIf;
						
						If (ResultET OR ETUseWithoutEquipmentConnection) AND PostingResult Then
							
							If Not CashCRUseWithoutEquipmentConnection Then
								
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
									ProductsTableRow.Add(TSRow.Quantity);   //  6 - Quantity
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
								PaymentRow.Add(Object.DocumentAmount - Object.PaymentWithPaymentCards.Total("Amount"));
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
								CommonParameters.Add(1);                      //  1 - Receipt type
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
									DeviceIdentifierFR,
									"PrintReceipt",
									InputParameters,
									Output_Parameters
								);
								
							EndIf;
							
							If CashCRUseWithoutEquipmentConnection OR Result Then
								
								// Set the received value of receipt number to document attribute.
								If Not CashCRUseWithoutEquipmentConnection Then
									Object.SalesSlipNumber = Output_Parameters[1];
								EndIf;
								
								Object.Date = CommonClient.SessionDate();
								If Not ValueIsFilled(Object.SalesSlipNumber) Then
									Object.SalesSlipNumber = 1;
								EndIf;
								
								Modified = True;
								
								PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
								If PostingResult = True
								AND Not CashCRUseWithoutEquipmentConnection Then
									SetModeReadOnly();
								EndIf;
								
							Else
								
								MessageText = NStr("en = 'When printing a receipt, an error occurred.
								                   |Receipt is not printed on the fiscal register.
								                   |Additional
								                   |description: %AdditionalDetails%'; 
								                   |ru = 'При печати чека произошла ошибка.
								                   |Чек не напечатан на фискальном регистраторе.
								                   |Дополнительное
								                   |описание: %AdditionalDetails%';
								                   |pl = 'Podczas drukowania paragonu wystąpił błąd.
								                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
								                   |Dodatkowy
								                   |opis: %AdditionalDetails%';
								                   |es_ES = 'Imprimiendo un recibo, ha ocurrido un error.
								                   |Recibo no se ha imprimido en el registro fiscal.
								                   |Descripción
								                   |adicional: %AdditionalDetails%';
								                   |es_CO = 'Imprimiendo un recibo, ha ocurrido un error.
								                   |Recibo no se ha imprimido en el registro fiscal.
								                   |Descripción
								                   |adicional: %AdditionalDetails%';
								                   |tr = 'Fiş basılırken bir hata oluştu. 
								                   |Fiş mali kaydedicide yazdırılamıyor. 
								                   |Ek 
								                   |açıklama: %AdditionalDetails%';
								                   |it = 'Si è verificato un errore durante la stampa di una ricevuta.
								                   |La ricevuta non è stampata sul registratore fiscale.
								                   |Descrizione
								                   |aggiuntiva: %AdditionalDetails%';
								                   |de = 'Beim Drucken eines Belegs ist ein Fehler aufgetreten.
								                   |Der Beleg wird nicht auf das Fiskalspeicher gedruckt.
								                   |Zusätzliche Beschreibung:
								                   |%AdditionalDetails%'"
								);
								
								MessageText = StrReplace(
									MessageText,
									"%AdditionalDetails%",
									Output_Parameters[1]
								);
								
								CommonClientServer.MessageToUser(MessageText);
								
							EndIf;
							
						EndIf;
						
						If Not CashCRUseWithoutEquipmentConnection Then
							
							// Disconnect FR
							EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifierFR);
							
						EndIf;
						
					Else
						
						MessageText = NStr("en = 'The fiscal printer connection error:
                                            |""%ErrorDescription%"".
                                            |The operation by card has not been performed.'; 
                                            |ru = 'Ошибка подключения фискального принтера:
                                            |""%ErrorDescription%"".
                                            |Операция по карте не может быть выполнена.';
                                            |pl = 'Błąd podłączenia drukarki fiskalnej:
                                            |""%ErrorDescription%"".
                                            |Operacja kartą nie została wykonana.';
                                            |es_ES = 'Error de conexión de la impresora fiscal:
                                            |""%ErrorDescription%"".
                                            |La operación con tarjeta no se ha realizado.';
                                            |es_CO = 'Error de conexión de la impresora fiscal:
                                            |""%ErrorDescription%"".
                                            |La operación con tarjeta no se ha realizado.';
                                            |tr = 'Mali yazıcı bağlantı hatası:
                                            |""%ErrorDescription%"".
                                            |Kartla işlem gerçekleştirilmedi.';
                                            |it = 'Errore di connessione della stampante fiscale:
                                            |%ErrorDescription%.
                                            |L''operazione da scheda non è stata eseguita.';
                                            |de = 'Der Verbindungsfehler des Steuerdruckers:
                                            |""%ErrorDescription%"".
                                            |Die Operation nach der Karte ist nicht ausgeführt.'");
						MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
						CommonClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		Else
			
			// External equipment is not used
			Object.Date = CommonClient.SessionDate();
			If Not ValueIsFilled(Object.SalesSlipNumber) Then
				Object.SalesSlipNumber = 1;
			EndIf;
			
			Modified = True;
			
			PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
			If PostingResult = True
			AND Not CashCRUseWithoutEquipmentConnection Then
				SetModeReadOnly();
			EndIf;
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'; ru = 'Не удалось выполнить проведение документа';pl = 'Księgowanie dokumentu nie powiodło się';es_ES = 'Fallado a enviar el documento';es_CO = 'Fallado a enviar el documento';tr = 'Belge kaydedilemedi';it = 'Impossibile pubblicare il documento';de = 'Fehler beim Buchen des Dokuments'"));
	EndIf;
	
	Notify("RefreshFormListDocumentsReceiptsCRReturn");
	
EndProcedure

// Procedure is called when pressing the PrintReceipt command panel button.
//
&AtClient
Procedure IssueReceiptExecute()
	
	Cancel = False;
	
	ClearMessages();
	
	If Object.DeletionMark Then
		
		ErrorText = NStr("en = 'The document is marked for deletion'; ru = 'Документ помечен на удаление';pl = 'Dokument jest wybrany do usunięcia';es_ES = 'El documento está marcado para borrar';es_CO = 'El documento está marcado para borrar';tr = 'Belge silinmek üzere işaretlendi';it = 'Il documento è contrassegnato per l''eliminazione';de = 'Das Dokument ist zum Löschen markiert'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	Object.Date = CommonClient.SessionDate();
	
	If Not Cancel AND CheckFilling() Then
		
		IssueReceipt();
		
	EndIf;
	
EndProcedure

// The procedure is called when clicking CancelPayment on the command panel.
//
&AtClient
Procedure CancelPayment(Command)
	
	DeviceIdentifierET = Undefined;
	DeviceIdentifierFR = Undefined;
	ErrorDescription            = "";
	
	// Check selected string in payment table by payment cards
	CurrentData = Items.PaymentWithPaymentCards.CurrentData;
	If CurrentData = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'Select the line of canceled payment by card.'; ru = 'Выберите строку отменяемой оплаты картой.';pl = 'Wybierz wiersz anlowanej opłaty kartą.';es_ES = 'Seleccionar la línea del pago cancelado con tarjeta.';es_CO = 'Seleccionar la línea del pago cancelado con tarjeta.';tr = 'Kartla iptal edilen ödemenin satırını seçin.';it = 'Selezionare la linea del pagamento con carta annullato.';de = 'Wählen Sie die Zeile der stornierten Zahlung per Karte.'"));
		Return;
	EndIf;
	
	If CurrentData.PaymentCanceled Then
		CommonClientServer.MessageToUser(NStr("en = 'This payment has already been canceled.'; ru = 'Данная оплата уже отменена.';pl = 'Opłata została już anulowana.';es_ES = 'Este pago ya se ha cancelado.';es_CO = 'Este pago ya se ha cancelado.';tr = 'Bu ödeme zaten iptal edildi.';it = 'Questo pagamento è già stato annullato.';de = 'Diese Zahlung wurde bereits storniert.'"));
		Return;
	EndIf;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		AmountOfOperations       = CurrentData.Amount;
		CardNumber          = CurrentData.ChargeCardNo;
		OperationRefNumber = CurrentData.RefNo;
		ETReceiptNo         = CurrentData.ETReceiptNo;
		SlipCheckString      = "";
		
		// Device selection ET
		DeviceIdentifierET = ?(
			ValueIsFilled(POSTerminal),
			POSTerminal,
			Undefined
		);
		
		If DeviceIdentifierET <> Undefined Then
			
			// Device selection FR
			DeviceIdentifierFR = ?(
				ValueIsFilled(FiscalRegister),
				FiscalRegister,
				Undefined
			);
			
			If DeviceIdentifierFR <> Undefined OR CashCRUseWithoutEquipmentConnection Then
				
				// ET device connection
				ResultET = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifierET,
					ErrorDescription
				);
				
				If ResultET Then
					
					// FR device connection
					ResultFR = EquipmentManagerClient.ConnectEquipmentByID(
						UUID,
						DeviceIdentifierFR,
						ErrorDescription
					);
					
					If ResultFR OR CashCRUseWithoutEquipmentConnection Then
						
						InputParameters  = New Array();
						Output_Parameters = Undefined;
						
						InputParameters.Add(AmountOfOperations);
						InputParameters.Add(OperationRefNumber);
						InputParameters.Add(ETReceiptNo);
						
						// Executing the operation on POS terminal
						ResultET = EquipmentManagerClient.RunCommand(
							DeviceIdentifierET,
							"AuthorizeVoid",
							InputParameters,
							Output_Parameters
						);
						
						If ResultET Then
							
							CardNumber          = "";
							OperationRefNumber = "";
							ETReceiptNo         = "";
							SlipCheckString      = Output_Parameters[0][1];
							
							If Not IsBlankString(SlipCheckString) Then
								glPeripherals.Insert("LastSlipReceipt", SlipCheckString);
							EndIf;
							
							If Not IsBlankString(SlipCheckString) AND Not CashCRUseWithoutEquipmentConnection Then
								
								InputParameters = New Array();
								InputParameters.Add(SlipCheckString);
								Output_Parameters = Undefined;
								
								ResultFR = EquipmentManagerClient.RunCommand(
									DeviceIdentifierFR,
									"PrintText",
									InputParameters,
									Output_Parameters
								);
							EndIf;
							
						Else
							
							MessageText = NStr("en = 'When operation execution there
							                   |was error: ""%ErrorDescription%"".
							                   |Cancellation by card has not been performed.'; 
							                   |ru = 'При выполнении операции возникла ошибка:
							                   |""%ErrorDescription%"".
							                   |Отмена по карте не была произведена.';
							                   |pl = 'W trakcie realizacji operacji wystąpił
							                   |błąd: ""%ErrorDescription%"".
							                   |Anulowanie z karty nie zostało wykonane.';
							                   |es_ES = 'Ejecutando la operación,
							                   |se ha producido el error: ""%ErrorDescription%"".
							                   |Cancelación con tarjeta no se ha realizado.';
							                   |es_CO = 'Ejecutando la operación,
							                   |se ha producido el error: ""%ErrorDescription%"".
							                   |Cancelación con tarjeta no se ha realizado.';
							                   |tr = 'İşlem esnasında bir 
							                   |hata oluştu: ""%ErrorDescription%"". 
							                   |Kartla iptal işlemi yapılmadı.';
							                   |it = 'Durante l''esecuzione dell''operazione
							                   |si è registrato un errore: ""%ErrorDescription%"".
							                   |La cancellazione con carta non è stata eseguita.';
							                   |de = 'Bei der Ausführung der Operation gab es
							                   |einen Fehler: ""%ErrorDescription%"".
							                   |Die Stornierung durch die Karte wurde nicht durchgeführt.'");
							
							MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
							
							CommonClientServer.MessageToUser(MessageText);
							
						EndIf;
						
						If ResultET AND (NOT ResultFR AND Not CashCRUseWithoutEquipmentConnection) Then
							
							ErrorDescriptionFR = Output_Parameters[1];
							
							MessageText = NStr("en = 'When printing slip receipt
							                   |there was error: ""%ErrorDescription%"".
							                   |Operation by card has been cancelled.'; 
							                   |ru = 'При печати слип-чека
							                   |возникла ошибка: ""%ErrorDescription%"".
							                   |Операция по карте была отменена.';
							                   |pl = 'W trakcie drukowania paragonu wystąpił
							                   |błąd: ""%ErrorDescription%"".
							                   |Operacja z kartą została anulowana.';
							                   |es_ES = 'Imprimiendo el recibo del comprobante
							                   |, se ha producido el error: ""%ErrorDescription%"".
							                   |Operación con tarjeta se ha cancelado.';
							                   |es_CO = 'Imprimiendo el recibo del comprobante
							                   |, se ha producido el error: ""%ErrorDescription%"".
							                   |Operación con tarjeta se ha cancelado.';
							                   |tr = 'Fiş yazdırılırken
							                   |hata oluştu: ""%ErrorDescription%"".
							                   |Kartla işlem iptal edildi.';
							                   |it = 'Durante la stampa dello scontrino
							                   |c''è stato un errore: ""%ErrorDescription%"".
							                   |L''operazione con la carta è stata cancellata.';
							                   |de = 'Beim Drucken des Belegs
							                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
							                   |Die Bedienung per Karte wurde abgebrochen.'");
							
							MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescriptionFR);
							
							CommonClientServer.MessageToUser(MessageText);
							
						ElsIf ResultET Then
							
							CurrentData.PaymentCanceled = True;
							
						EndIf;
						
						// FR device disconnect
						EquipmentManagerClient.DisableEquipmentById(
							UUID,
							DeviceIdentifierFR
						);
						// ET device disconnect
						EquipmentManagerClient.DisableEquipmentById(
							UUID,
							DeviceIdentifierET
						);
						
					Else
						
						MessageText = NStr("en = 'The fiscal printer connection error:
                                            |""%ErrorDescription%"".
                                            |The operation by card has not been performed.'; 
                                            |ru = 'Ошибка подключения фискального принтера:
                                            |""%ErrorDescription%"".
                                            |Операция по карте не может быть выполнена.';
                                            |pl = 'Błąd podłączenia drukarki fiskalnej:
                                            |""%ErrorDescription%"".
                                            |Operacja kartą nie została wykonana.';
                                            |es_ES = 'Error de conexión de la impresora fiscal:
                                            |""%ErrorDescription%"".
                                            |La operación con tarjeta no se ha realizado.';
                                            |es_CO = 'Error de conexión de la impresora fiscal:
                                            |""%ErrorDescription%"".
                                            |La operación con tarjeta no se ha realizado.';
                                            |tr = 'Mali yazıcı bağlantı hatası:
                                            |""%ErrorDescription%"".
                                            |Kartla işlem gerçekleştirilmedi.';
                                            |it = 'Errore di connessione della stampante fiscale:
                                            |%ErrorDescription%.
                                            |L''operazione da scheda non è stata eseguita.';
                                            |de = 'Der Verbindungsfehler des Steuerdruckers:
                                            |""%ErrorDescription%"".
                                            |Die Operation nach der Karte ist nicht ausgeführt.'");
						MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
						CommonClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en = 'When POS terminal connection there
					                   |was error: ""%ErrorDescription%"".
					                   |Operation by card has not been performed.'; 
					                   |ru = 'При подключении эквайрингового
					                   |терминала произошла ошибка: ""%ErrorDescription%"".
					                   |Операция по карте не была выполнена.';
					                   |pl = 'W trakcie połączenia terminala POS wystąpił
					                   |błąd: ""%ErrorDescription%"".
					                   |Operacja z kartą nie została wykonana.';
					                   |es_ES = 'Conectando el terminal TPV, se ha
					                   |producido el error: ""%ErrorDescription%"".
					                   |Operación con tarjeta no se ha realizado.';
					                   |es_CO = 'Conectando el terminal TPV, se ha
					                   |producido el error: ""%ErrorDescription%"".
					                   |Operación con tarjeta no se ha realizado.';
					                   |tr = 'POS terminali bağlantısında hata oluştu:
					                   |""%ErrorDescription%"".
					                   |Kartla işlem yapılamadı.';
					                   |it = 'Alla connessione del terminale POS,
					                   |si è verificato un errore: ""%ErrorDescription%"".
					                   |L''operazione  con carta non è stata eseguita.';
					                   |de = 'Beim Anschluss des POS-Terminals
					                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
					                   |Die Operation mit der Karte wurde nicht ausgeführt.'");
					MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescription);
					CommonClientServer.MessageToUser(MessageText);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange field CashRegister on server.
//
&AtServer
Procedure CashCROnChangeAtServer()
	
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionAttributesToDate(Object.CashCR, ?(ValueIsFilled(Object.Ref), Object.Date, CurrentSessionDate()));
	
	If ValueIsFilled(StatusCashCRSession.CashCRSessionStatus) Then
		
		FillPropertyValues(Object, StatusCashCRSession);
		
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	Object.POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(Object.CashCR);
	
	GetRefsToEquipment();
	
	Object.Department = Object.CashCR.Department;
	
	If Not ValueIsFilled(Object.Department) Then
		
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
		MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		Object.Department = MainDepartment;
		
	EndIf;
	
	FillVATRateByCompanyVATTaxation();
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	Items.InventoryPrice.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	Items.InventoryAmount.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	
EndProcedure

// Procedure - event handler OnChange field CashCR.
//
&AtClient
Procedure CashCROnChange(Item)
	
	CashCROnChangeAtServer();
	DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler OnChange field POSTerminal on server.
//
&AtServer
Procedure POSTerminalOnChangeAtServer()
	
	GetRefsToEquipment();
	GetChoiceListOfPaymentCardKinds();
	ETUseWithoutEquipmentConnection = Object.POSTerminal.UseWithoutEquipmentConnection;
	Items.PaymentWithPaymentCardsCancelPayment.Visible = Not ETUseWithoutEquipmentConnection;
	
EndProcedure

// Procedure - OnChange event handler of the POSTerminal field.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	POSTerminalOnChangeAtServer();
	
EndProcedure

// Procedure - event handler OnChange of the Date input field.
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

// Procedure - event handler OnChange field Company.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	CompanyOnChangeAtServer();
	
EndProcedure

// Procedure - OnChange event handler of the StructuralUnit field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	StructuralUnitOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#Region EventHandlersOfTheInventoryTabularSectionAttributes

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("Object", Object);
	StructureData.Insert("RevenueItem", Undefined);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("IncomeAndExpenseItems",	TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("DocumentCurrency",  Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	
	CalculateAmountInTabularSectionLine();
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, ,UseSerialNumbersBalance);
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Company", 				Object.Company);
	StructureData.Insert("Products",	 TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 	Object.Date);
		StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	
	CalculateAmountInTabularSectionLine();
	
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
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
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

// Procedure - OnChange event handler of the DiscountAmount input field.
//
&AtClient
Procedure InventoryOfDiscountAmountIfYouChange(Item)
	
	CalculateDiscountPercent();
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
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
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", ThisObject.CurrentItem.CurrentItem.Name);
		
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
Procedure InventoryIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Inventory", StandardProcessing);
	
EndProcedure

&AtClient
// Procedure - event handler OnEditEnd of the Inventory list row.
//
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

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
		ElsIf TableCurrentColumn.Name = "InventoryIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

#EndRegion

#Region EventHandlersOfThePaymentCardsTSAttributes

// Procedure - OnEditEnd event handler of the PaymentWithPaymentCards list string.
//
&AtClient
Procedure PaymentWithPaymentCardsOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
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

#Region AutomaticDiscounts

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

&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	
	RecalculateDocumentAtClient();
	
EndProcedure

&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
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

&AtServer
Procedure CalculateDiscountsMarkupsByBaseDocumentServer()

	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	ReceiptsCRArray = New Array;
	ReceiptsCRArray.Add(Object.SalesSlip);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	DiscountsMarkups.Ref AS Order,
	|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	DiscountsMarkups.Amount AS AutomaticDiscountAmount,
	|	CASE
	|		WHEN SalesSlipInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsTypeInventory,
	|	CASE
	|		WHEN VALUETYPE(SalesSlipInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesSlipInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	SalesSlipInventory.Products,
	|	SalesSlipInventory.Characteristic,
	|	SalesSlipInventory.MeasurementUnit,
	|	SalesSlipInventory.Quantity
	|FROM
	|	Document.SalesSlip.DiscountsMarkups AS DiscountsMarkups
	|		INNER JOIN Document.SalesSlip.Inventory AS SalesSlipInventory
	|		ON DiscountsMarkups.Ref = SalesSlipInventory.Ref
	|			AND DiscountsMarkups.ConnectionKey = SalesSlipInventory.ConnectionKey
	|WHERE
	|	DiscountsMarkups.Ref IN(&ReceiptsCRArray)";
	
	Query.SetParameter("ReceiptsCRArray", ReceiptsCRArray);
	
	ResultsArray = Query.ExecuteBatch();
	
	OrderDiscountsMarkups = ResultsArray[0].Unload();
	
	Object.DiscountsMarkups.Clear();
	For Each CurrentDocumentRow In Object.Inventory Do
		CurrentDocumentRow.AutomaticDiscountsPercent = 0;
		CurrentDocumentRow.AutomaticDiscountAmount = 0;
	EndDo;
	
	DiscountsMarkupsCalculationResult = Object.DiscountsMarkups.Unload();
	
	For Each CurrentOrderRow In OrderDiscountsMarkups Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", CurrentOrderRow.Products);
		StructureForSearch.Insert("Characteristic", CurrentOrderRow.Characteristic);
		
		DocumentRowsArray = Object.Inventory.FindRows(StructureForSearch);
		If DocumentRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		QuantityInOrder = CurrentOrderRow.Quantity * CurrentOrderRow.Factor;
		Distributed = 0;
		For Each CurrentDocumentRow In DocumentRowsArray Do
			QuantityToWriteOff = CurrentDocumentRow.Quantity * 
									?(TypeOf(CurrentDocumentRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), 1, CurrentDocumentRow.MeasurementUnit.Factor);
			
			RecalculateAmounts = QuantityInOrder <> QuantityToWriteOff;
			DiscountRecalculationCoefficient = ?(RecalculateAmounts, QuantityToWriteOff / QuantityInOrder, 1);
			If DiscountRecalculationCoefficient <> 1 Then
				CurrentAutomaticDiscountAmount = ROUND(CurrentOrderRow.AutomaticDiscountAmount * DiscountRecalculationCoefficient,2);
			Else
				CurrentAutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount;
			EndIf;
			
			DiscountString = DiscountsMarkupsCalculationResult.Add();
			FillPropertyValues(DiscountString, CurrentOrderRow);
			DiscountString.Amount = CurrentAutomaticDiscountAmount;
			DiscountString.ConnectionKey = CurrentDocumentRow.ConnectionKey;
			
			CurrentOrderRow.AutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount - CurrentAutomaticDiscountAmount;
			QuantityInOrder = QuantityInOrder - QuantityToWriteOff;
			If QuantityInOrder <=0 Or CurrentOrderRow.AutomaticDiscountAmount <=0 Then
				Break;
			EndIf;
		EndDo;
		
	EndDo;
	
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsCalculationResult);
	
EndProcedure

// Procedure - "CalculateDiscountsMarkups" command handler.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	CalculateDiscountsMarkupsByBaseDocumentServer();
	ParameterStructure.Insert("ApplyToObject", True);
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
	EndDo;
	
EndProcedure

&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
EndProcedure

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

&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.InventoryAutomaticDiscountPercent OR Item.CurrentItem = Items.InventoryAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient();
	ElsIf Field.Name = "InventoryGLAccounts" Then
		
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory", , ReadOnly);
		StandardProcessing = False;
		
	ElsIf Field.Name = "InventoryIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

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

&AtClient
Procedure AppliedDiscounts(Command)
	
	If Object.Ref.IsEmpty() Then
		QuestionText = "Data is still not recorded.
		|Transfer to ""Applied discounts"" is possible only after data is written.
		|Data will be written.";
		NotifyDescription = New NotifyDescription("AppliedDiscountsCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel);
	Else
		FormParameters = New Structure("DocumentRef", Object.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure AppliedDiscountsCompletion(Result, Parameters) Export
	
	If Result <> DialogReturnCode.OK Then
		Return;
	EndIf;

	If Write() Then
		FormParameters = New Structure("DocumentRef", Object.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject);
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

&AtServer
Procedure EditOwnershipProcessingAtServer(TempStorageAddress)
	
	OwnershipTable = GetFromTempStorage(TempStorageAddress);
	
	Object.InventoryOwnership.Load(OwnershipTable);
	
EndProcedure

&AtClient
Procedure EditOwnershipProcessingAtClient(TempStorageAddress)
	
	EditOwnershipProcessingAtServer(TempStorageAddress);
	
EndProcedure

&AtServer
Function PutEditOwnershipDataToTempStorage()
	
	DocObject = FormAttributeToValue("Object");
	DataForOwnershipForm = InventoryOwnershipServer.GetDataForInventoryOwnershipForm(DocObject);
	TempStorageAddress = PutToTempStorage(DataForOwnershipForm, UUID);
	Return TempStorageAddress;
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 			TabName);
	StructureData.Insert("Object",				Form.Object);
	
	If TabName = "Inventory" Then
		StructureData.Insert("RevenueItem", TabRow.RevenueItem);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
		StructureData.Insert("RevenueGLAccount",	TabRow.RevenueGLAccount);
		StructureData.Insert("VATOutputGLAccount",	TabRow.VATOutputGLAccount);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Inventory");
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Inventory");
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);

EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	
	Return Fields;
	
EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion