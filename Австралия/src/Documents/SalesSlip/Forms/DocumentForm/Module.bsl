
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
	Items.Reserve.Visible = Not ControlAtWarehouseDisabled;
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
	ShiftClosureIsOpen = (Common.ObjectAttributeValue(Object.CashCRSession, "CashCRSessionStatus")
							= PredefinedValue("Enum.ShiftClosureStatus.IsOpen"));
	
	If AccessRight("InteractiveInsert", Metadata.Documents.ProductReturn) Then
		Items.FormDocumentProductReturnCreateBasedOn.Visible = ShiftClosureIsOpen;
	EndIf;
	If AccessRight("InteractiveInsert", Metadata.Documents.CreditNote) Then
		Items.FormDocumentCreditNoteCreateBasedOn.Visible = Not ShiftClosureIsOpen;
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
	
	If Not ValueIsFilled(Object.Ref)
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
	
	SetAccountingPolicyValues();
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ProcessingCompanyVATNumbers();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();
	
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetEnabledOfReceiptPrinting();
	Items.PaymentWithPaymentCards.Enabled = ValueIsFilled(Object.POSTerminal);
	
	If Object.Status = Enums.SalesSlipStatus.Issued Then
		SetModeReadOnly();
	EndIf;
	
	SetPaymentEnabled();
	
	Items.InventoryAmountDiscountsMarkups.Visible = Constants.UseManualDiscounts.Get();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  = Not AllowedEditDocumentPrices;
	Items.InventoryAmountDiscountsMarkups.ReadOnly 	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	
	Items.DocumentAmount.ToolTip = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Receipt amount (%1)'; ru = 'Сумма приход (%1)';pl = 'Otrzymana kwota (%1)';es_ES = 'Importe del recibo (%1)';es_CO = 'Importe del recibo (%1)';tr = 'Giriş tutarı (%1)';it = 'Importo ricevuta (%1)';de = 'Belegbetrag (%1)'"),
		Object.DocumentCurrency);
		
	Items.CashReceived.ToolTip = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Received in cash (%1)'; ru = 'Получено наличными (%1)';pl = 'Otrzymano gotówką (%1)';es_ES = 'Recibido en efectivo (%1)';es_CO = 'Recibido en efectivo (%1)';tr = 'Nakit olarak alındı (%1)';it = 'Ricevuto in contanti (%1)';de = 'In bar erhalten (%1)'"),
		Object.DocumentCurrency);
		
	Items.PaymentWithPaymentCardsTotalAmount.ToolTip = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'By payment cards (%1)'; ru = 'Платежными картами (%1)';pl = 'Kartami płatniczymi (%1)';es_ES = 'Con tarjetas de pago (%1)';es_CO = 'Con tarjetas de pago (%1)';tr = 'Ödeme kartları ile (%1)';it = 'Tramite carta di pagamento (%1)';de = 'Durch Zahlungskarten (%1)'"),
		Object.DocumentCurrency);
		
	Items.PaymentWithPaymentCardsTotalAmount.ToolTip = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Change (%1)'; ru = 'Изменение (%1)';pl = 'Rozmienianie pieniędzy (%1)';es_ES = 'Cambio (%1)';es_CO = 'Cambio (%1)';tr = 'Değiştir (%1)';it = 'Resto (%1)';de = 'Änderung (%1)'"),
		Object.DocumentCurrency);
	
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
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	FillAddedColumns();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	GetChoiceListOfPaymentCardKinds();
	
	Items.IssueReceipt.Enabled = Not Object.DeletionMark;
	
EndProcedure

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarcodeScanner,CustomerDisplay");
	// End Peripherals
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
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
	
	WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject);
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)
	
	// AutomaticDiscounts
	// Display the message about discount calculation when user clicks the "Post and close" button or closes the form by
	// the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("en = 'Update:'; ru = 'Изменение:';pl = 'Zaktualizuj:';es_ES = 'Actualizar:';es_CO = 'Actualizar:';tr = 'Güncelle:';it = 'Aggiornamento:';de = 'Aktualisieren:'"), 
										GetURL(Object.Ref), 
										String(Object.Ref) + NStr("en = '. The automatic discounts are calculated.'; ru = '. Автоматические скидки рассчитаны.';pl = '. Obliczono rabaty automatyczne.';es_ES = '. Los descuentos automáticos se han calculado.';es_CO = '. Los descuentos automáticos se han calculado.';tr = '. Otomatik indirimler hesaplandı.';it = '. Sconti automatici sono stati applicati.';de = '. Die automatischen Rabatte werden berechnet.'"), 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals

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
	
	// AutomaticDiscounts
	If DiscountsCalculatedBeforeWrite Then
		RecalculateDocumentAtClient();
	EndIf;
	// End AutomaticDiscounts
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	// End Bundles
	
	Notify("RefreshSalesSlipDocumentsListForm");
	Notify("RefreshAccountingTransaction");
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
		And IsInputAvailable() And Not DiscountCardRead Then
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
	
	// Bundles
	If BundlesClient.ProcessNotifications(ThisObject, EventName, Source) Then
		RefreshBundleComponents(Parameter.BundleProduct, Parameter.BundleCharacteristic, Parameter.Quantity, Parameter.BundleComponents);
		ActionsAfterDeleteBundleLine();
	EndIf;
	// End Bundles
	
	If EventName = "RefreshSalesSlipDocumentsListForm" Then
		
		For Each CurRow In Object.Inventory Do
			
			CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
			
		EndDo;
		
	ElsIf EventName = "SerialNumbersSelection"
		And ValueIsFilled(Parameter) 
		// Form owner checkup
		And Source <> New UUID("00000000-0000-0000-0000-000000000000")
		And Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf; 
		
	EndIf;
	
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
	
	AmountShortChange = Object.PaymentWithPaymentCards.Total("Amount")
			   + Object.CashReceived
			   - Object.DocumentAmount;
	
	DocumentDiscount = Object.Inventory.Total("DiscountAmount");
	AmountTotal = Object.Inventory.Total("Total");
	VATAmountTotal = Object.Inventory.Total("VATAmount");
	
	Object.DocumentAmount = AmountTotal;		
	Object.DocumentTax = VATAmountTotal;
	Object.DocumentSubtotal = AmountTotal - VATAmountTotal + DocumentDiscount;
	
	GenerateToolTipsToAttributes();
	
	DisplayInformationOnCustomerDisplay();
	
EndProcedure

// Procedure recalculates the document on client.
//
&AtClient
Procedure GenerateToolTipsToAttributes()
	
	TitleAmountCheque = NStr("en = 'Receipt amount ('; ru = 'Сумма чека (';pl = 'Wartość paragonu (';es_ES = 'Importe del recibo (';es_CO = 'Importe del recibo (';tr = 'Giriş tutarı (';it = 'Importo ricevuta (';de = 'Belegbetrag ('") + "%Currency%" + ")";
	TitleAmountCheque = StrReplace(TitleAmountCheque, "%Currency%", Object.DocumentCurrency);
	Items.DocumentAmount.ToolTip = TitleAmountCheque;
	
	TitleReceivedCash = NStr("en = 'Received in cash ('; ru = 'Получено наличными (';pl = 'Otrzymano gotówką (';es_ES = 'Recibido en efectivo (';es_CO = 'Recibido en efectivo (';tr = 'Nakit olarak alındı (';it = 'Ricevuto in contanti (';de = 'In bar erhalten ('") + "%Currency%" + ")";
	TitleReceivedCash = StrReplace(TitleReceivedCash, "%Currency%", Object.DocumentCurrency);
	Items.CashReceived.ToolTip = TitleReceivedCash;
	
	TitlePaymentWithPaymentCards = NStr("en = 'By payment cards ('; ru = 'Платежными картами (';pl = 'Płatność kartą (';es_ES = 'Con tarjetas de pago (';es_CO = 'Con tarjetas de pago (';tr = 'Ödeme kartları ile (';it = 'Con carte di pagamento (';de = 'Durch Zahlungskarten ('") + "%Currency%" + ")";
	TitlePaymentWithPaymentCards = StrReplace(TitlePaymentWithPaymentCards, "%Currency%", Object.DocumentCurrency);
	Items.PaymentWithPaymentCardsTotalAmount.ToolTip = TitlePaymentWithPaymentCards;
	
	TitleAmountPutting = NStr("en = 'Change ('; ru = 'Сдача (';pl = 'Reszta (';es_ES = 'Cambio (';es_CO = 'Cambio (';tr = 'Para üstü (';it = 'Resto (';de = 'Wechselgeld ('") + "%Currency%" + ")";
	TitleAmountPutting = StrReplace(TitleAmountPutting, "%Currency%", Object.DocumentCurrency);
	Items.AmountShortChange.ToolTip = TitleAmountPutting;
	
EndProcedure

&AtClient
Procedure CheckPaymentAmounts(Cancel)
	
	If Object.DocumentAmount > Object.CashReceived + Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en = 'The payment amount is less than the receipt amount'; ru = 'Сумма оплаты меньше суммы чека';pl = 'Kwota opłaty jest niższa niż suma paragonu';es_ES = 'El importe de pago es menor al importe de recibo';es_CO = 'El importe de pago es menor al importe de recibo';tr = 'Ödeme tutarı, giriş tutarından daha küçüktür';it = 'L''importo di pagamento è inferiore all''importo della ricevuta';de = 'Der Zahlungsbetrag ist kleiner als der Belegbetrag'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	If Object.DocumentAmount < Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en = 'The amount of payment by payment cards exceeds the total of a receipt'; ru = 'Сумма оплаты платежными картами превышает сумму чека';pl = 'Kwota opłaty kartą przekracza łączną sumę paragonu';es_ES = 'El importe del pago con tarjetas de pago excede el total de un recibo';es_CO = 'El importe del pago con tarjetas de pago excede el total de un recibo';tr = 'Ödeme kartıyla ödeme tutarı, fiş toplamını aşıyor';it = 'L''importo del pagamento con carta è superiore al totale della ricevuta.';de = 'Der Betrag der Zahlung mit Zahlungskarten übersteigt den Gesamtbetrag einer Quittung '");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

// Peripherals
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
			
			StructureProductsData = CreateGeneralAttributeValuesStructure(StructureData, "Inventory", BarcodeData);
			
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
			
			If CurBarcode.Property("SerialNumber") AND ValueIsFilled(CurBarcode.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, CurBarcode.SerialNumber, Object);
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

// End Peripherals

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

	Items.GroupOfAutomatedPaymentCards.Visible = ValueIsFilled(POSTerminal);
	Items.GroupManualPaymentCards.Visible = Not ValueIsFilled(POSTerminal);
	
	// Context menu
	Items.ContextMenuGroupOfAutomatedPaymentCards.Visible = ValueIsFilled(POSTerminal);
	Items.ContextMenuGroupManualPaymentCards.Visible = Not ValueIsFilled(POSTerminal);
	
	Items.PaymentWithPaymentCards.ReadOnly = ValueIsFilled(POSTerminal);
	
EndProcedure

// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
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
			StructureData.Characteristic, ProductsAttributes.SKU)
	);
	
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
		StructureData.Insert(
			"DiscountMarkupPercent", Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData, True);
	// End Bundles
	
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

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// DiscountCards
	// IN this procedure call not modal window of question is occurred.
	RecalculateDiscountPercentAtDocumentDateChange();
	// End DiscountCards
	
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
	TabularSectionRow.AmountDiscountsMarkups = TabularSectionRow.DiscountAmount;
	
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

// Procedure calculates discount % in tabular section string.
//
&AtClient
Procedure CalculateDiscountMarkupPercent(TabularSectionRow = Undefined)
	
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
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
		// Bundles
		If ImportRow.IsBundle Then
			
			StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", NewRow);
			
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
			
			AddTabRowDataToStructure(ThisObject, "Inventory", StructureData, NewRow);
			StructureData = GetDataProductsOnChange(StructureData);
			
			ReplaceInventoryLineWithBundleData(ThisObject, NewRow, StructureData);
			
		EndIf;
		// End Bundles
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False)
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
	ParametersStructure.Insert("Company",						ParentCompany);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					False);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("DocumentCurrencyEnabled",		False);
	ParametersStructure.Insert("PriceKind",						Object.PriceKind);
	ParametersStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard",					Object.DiscountCard);
	ParametersStructure.Insert("ReverseChargeNotApplicable",	True);
	ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
	
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
		Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices And ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
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
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory", PricesPrecision);
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
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Update document footer
	RecalculateDocumentAtClient();
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	ProcessingCompanyVATNumbers(False);
	
	FillAddedColumns(True);
	
	FillVATRateByCompanyVATTaxation();
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	FillAddedColumns(True);
	FillVATRateByCompanyVATTaxation();
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("Object", Form.Object);
	
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
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
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
	
	BundlesServer.RefreshBundleComponentsInTable(BundleProduct, BundleCharacteristic,Quantity, BundleComponents, FillingParameters);
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

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets mode Only view.
//
&AtServer
Procedure SetModeReadOnly()
	
	ReadOnly = True; // Receipt is issued. Change information is forbidden.
	
	If CashCRUseWithoutEquipmentConnection Then
		Items.IssueReceipt.Title = NStr("en = 'Cancel issuing'; ru = 'Отменить пробитие';pl = 'Anuluj wybicie';es_ES = 'Cancelar la emisión';es_CO = 'Cancelar la emisión';tr = 'Düzenlemeyi iptal et';it = 'Annullare l''invio';de = 'Ausgabe abbrechen'");
		Items.IssueReceipt.Enabled = True;
	Else
		Items.IssueReceipt.Enabled = False;
	EndIf;
	
	Items.PricesAndCurrency.Enabled = False;
	Items.InventoryWeight.Enabled = False;
	Items.InventoryPick.Enabled = False;
	Items.PaymentWithPaymentCardsAddPaymentByCard.Enabled = False;
	Items.PaymentWithPaymentCardsDeletePaymentByCard.Enabled = False;
	Items.InventoryImportDataFromDCT.Enabled = False;
	// DiscountCards
	Items.ReadDiscountCard.Enabled = False;
	// AutomaticDiscounts
	Items.InventoryCalculateDiscountsMarkups.Enabled = False;
	
EndProcedure

// The procedure cancels the View only mode.
//
&AtClient
Procedure CancelModeViewOnly()
	
	Items.IssueReceipt.Title = NStr("en = 'Issue cash receipt'; ru = 'Пробить чек';pl = 'Wybij paragon';es_ES = 'Emitir el recibo de efectivo';es_CO = 'Emitir el recibo de efectivo';tr = 'Nakit tahsilat fişini düzenle';it = 'Emettere entrata di cassa';de = 'Kassenbon ausstellen'");
	ReadOnly = False;
	Items.PricesAndCurrency.Enabled = True;
	Items.InventoryWeight.Enabled = True;
	Items.InventoryPick.Enabled = True;
	Items.PaymentWithPaymentCardsAddPaymentByCard.Enabled = True;
	Items.PaymentWithPaymentCardsDeletePaymentByCard.Enabled = True;
	Items.InventoryImportDataFromDCT.Enabled = True;
	// DiscountCards
	Items.ReadDiscountCard.Enabled = True;
	// AutomaticDiscounts
	Items.InventoryCalculateDiscountsMarkups.Enabled = True;
	
EndProcedure

// Procedure sets the payment availability.
//
&AtServer
Procedure SetPaymentEnabled()
	
	If Object.CashAssetType = Enums.CashAssetTypes.Cash Then
	
		Items.PaymentWithPaymentCards.Enabled = False;
		Items.PagePaymentWithPaymentCards.Visible = False;
		Items.CashReceived.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
		Items.CalculateAmountOfCashVoucher.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
	
	ElsIf Not ValueIsFilled(Object.CashAssetType) Then // Mixed
	
		Items.PaymentWithPaymentCards.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
		Items.PagePaymentWithPaymentCards.Visible = True;
		Items.CashReceived.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
		Items.CalculateAmountOfCashVoucher.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
	
	Else // By payment cards
		
		Items.PaymentWithPaymentCards.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
		Items.PagePaymentWithPaymentCards.Visible = True;
		Items.CashReceived.Enabled = False;
		Items.CalculateAmountOfCashVoucher.Enabled = False;
	
	EndIf;
	
EndProcedure

// Procedure sets the receipt print availability.
//
&AtServer
Procedure SetEnabledOfReceiptPrinting()
	
	If Object.Status = Enums.SalesSlipStatus.ProductReserved
	 OR Object.CashCR.UseWithoutEquipmentConnection
	 OR ControlAtWarehouseDisabled Then
		Items.IssueReceipt.Enabled = True;
	Else
		Items.IssueReceipt.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure displays information output on the customer display.
//
// Parameters:
//  No.
//
&AtClient
Procedure DisplayInformationOnCustomerDisplay()

	Displays = EquipmentManagerClientReUse.GetEquipmentList("CustomerDisplay", , EquipmentManagerServerCall.GetClientWorkplace());
	display = Undefined;
	DPText = ?(
		Items.Inventory.CurrentData = Undefined,
		"",
		TrimAll(Items.Inventory.CurrentData.Products)
	  + Chars.LF
	  + StringFunctionsClientServer.SubstituteParametersToString(
	  		NStr("en = 'Total: %1'; ru = 'Итого: %1';pl = 'Łącznie: %1';es_ES = 'Total: %1';es_CO = 'Total: %1';tr = 'Toplam: %1';it = 'Totale: %1';de = 'Insgesamt: %1'"),
	  		Format(Object.DocumentAmount, "NFD=2; NGS=' '; NZ=0"))
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
			                   |Additional
			                   |description: %AdditionalDetails%'; 
			                   |ru = 'При использовании дисплея покупателя произошла ошибка.
			                   |Дополнительное
			                   |описание: %AdditionalDetails%';
			                   |pl = 'Podczas korzystania z ekranu klienta wystąpił błąd.
			                   |Dodatkowy
			                   |opis: %AdditionalDetails%';
			                   |es_ES = 'Utilizando el error de visualización del cliente, ha ocurrido un error.
			                   |Descripción
			                   |adicional: %AdditionalDetails%';
			                   |es_CO = 'Utilizando el error de visualización del cliente, ha ocurrido un error.
			                   |Descripción
			                   |adicional: %AdditionalDetails%';
			                   |tr = 'Müşteri görüntüleme hatası oluştu. 
			                   |Ek
			                   | açıklama:%AdditionalDetails%';
			                   |it = 'Si è registrato un errore durante l''uso della visualizzazione cliente.
			                   |Descrizione
			                   |aggiuntiva: %AdditionalDetails%';
			                   |de = 'Bei der Verwendung des Kundendisplays ist ein Fehler aufgetreten.
			                   |Zusätzliche
			                   |Beschreibung: %AdditionalDetails%'");
			MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndDo;
	
EndProcedure

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
    EndIf;

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

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// The procedure of cancelling receipt issuing if equipment is not connected.
//
&AtClient
Procedure CancelBreakoutCheque()
	
	PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.UndoPosting));
	If PostingResult = True Then
		CancelModeViewOnly();
	EndIf;
	
EndProcedure

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
	If (ControlAtWarehouseDisabled OR DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox)) Then
		
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
							
							PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
							
							If PostingResult = True Then
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
							                   |tr = 'Fiş yazdırılırken hata oluştu.
							                   |Fiş mali kayıtta yazdırılamadı.
							                   |Ek
							                   |açıklama: %AdditionalDetails%';
							                   |it = 'Si è verificato un errore durante la stampa di una ricevuta.
							                   |La ricevuta non è stampata sul registratore fiscale.
							                   |Descrizione
							                   |aggiuntiva: %AdditionalDetails%';
							                   |de = 'Beim Drucken eines Belegs ist ein Fehler aufgetreten.
							                   |Der Beleg wird nicht auf dem Fiskalspeicher gedruckt.
							                   |Zusätzliche
							                   |Beschreibung: %AdditionalDetails%'");
							MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
							CommonClientServer.MessageToUser(MessageText);
							
						EndIf;
						
						// Disconnect FR
						EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
						
					Else
						
						MessageText = NStr("en = 'An error occurred when connecting the device.
						                   |Receipt is not printed on the fiscal register.
						                   |Additional
						                   |description: %AdditionalDetails%'; 
						                   |ru = 'При подключении устройства произошла ошибка.
						                   |Чек не напечатан на фискальном регистраторе.
						                   |Дополнительное
						                   |описание: %AdditionalDetails%';
						                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
						                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
						                   |Dodatkowy
						                   |opis: %AdditionalDetails%';
						                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
						                   |Recibo no se ha imprimido en el registro fiscal.
						                   |Descripción
						                   |adicional: %AdditionalDetails%';
						                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
						                   |Recibo no se ha imprimido en el registro fiscal.
						                   |Descripción
						                   |adicional: %AdditionalDetails%';
						                   |tr = 'Cihaz bağlanırken hata oluştu.
						                   |Fiş mali kayıtta yazdırılamadı.
						                   |Ek
						                   |açıklama: %AdditionalDetails%';
						                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
						                   |LA ricevuta non è stampata nel registratore fiscale.
						                   |Descrizione
						                   |Aggiuntiva: %AdditionalDetails%';
						                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
						                   |Der Beleg wird nicht auf den Fiskalspeicher gedruckt.
						                   |Zusätzliche
						                   |Beschreibung: %AdditionalDetails%'");
						MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
						CommonClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en = 'Fiscal data recorder is not selected'; ru = 'Не выбран фискальный регистратор';pl = 'Nie wybrano rejestratora danych fiskalnych';es_ES = 'Registrador de datos fiscales no se ha seleccionado';es_CO = 'Registrador de datos fiscales no se ha seleccionado';tr = 'Mali veri kaydedici seçilmedi.';it = 'Il registratore fiscale non è selezionato.';de = 'Fiskal-Datenschreiber ist nicht ausgewählt'");
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
			
			PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
			
			If PostingResult = True Then
				SetModeReadOnly();
			EndIf;
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'; ru = 'Не удалось выполнить проведение документа';pl = 'Księgowanie dokumentu nie powiodło się';es_ES = 'Fallado a enviar el documento';es_CO = 'Fallado a enviar el documento';tr = 'Belge kaydedilemedi';it = 'Impossibile pubblicare il documento';de = 'Fehler beim Buchen des Dokuments'"));
	EndIf;
	
EndProcedure

// Procedure is called when pressing the PrintReceipt command panel button.
//
&AtClient
Procedure IssueReceiptExecute(Command)
	
	Cancel = False;
	
	ClearMessages();
	
	If Object.DeletionMark Then
		
		ErrorText = NStr("en = 'The document is marked for deletion'; ru = 'Документ помечен на удаление';pl = 'Dokument jest wybrany do usunięcia';es_ES = 'El documento está marcado para borrar';es_CO = 'El documento está marcado para borrar';tr = 'Belge silinmek üzere işaretlendi';it = 'Il documento è contrassegnato per l''eliminazione';de = 'Das Dokument ist zum Löschen markiert'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	CheckPaymentAmounts(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If ReadOnly Then
		CancelBreakoutCheque();
		SetPaymentEnabled();
	ElsIf CheckFilling() Then
		Object.Date = CommonClient.SessionDate();
		IssueReceipt();
	EndIf;
	
EndProcedure

// Procedure - AddPaymentByCard command handler.
//
&AtClient
Procedure AddPaymentByCard(Command)
	
	DeviceIdentifierET = Undefined;
	DeviceIdentifierFR = Undefined;
	ErrorDescription            = "";
	
	AmountOfOperations       = 0;
	CardNumber          = "";
	OperationRefNumber = "";
	ETReceiptNo         = "";
	SlipCheckString      = "";
	CardKind            = "";
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If UsePeripherals Then // Check on the included FO "Use ExternalEquipment"
			
			If EquipmentManagerClient.RefreshClientWorkplace()Then // Checks if the operator's workplace is specified
				
				// Device selection ET
				DeviceIdentifierET = ?(ValueIsFilled(POSTerminal),
											  POSTerminal,
											  Undefined);
				
				If DeviceIdentifierET <> Undefined Then
					
					// Device selection FR
					DeviceIdentifierFR = ?(ValueIsFilled(FiscalRegister),
												  FiscalRegister,
												  Undefined);
					
					If DeviceIdentifierFR <> Undefined
					 OR CashCRUseWithoutEquipmentConnection Then
						
						// ET device connection
						ResultET = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																										DeviceIdentifierET,
																										ErrorDescription);
						
						If ResultET Then
							
							// FR device connection
							ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																											DeviceIdentifierFR,
																											ErrorDescription);
							
							If ResultFR OR CashCRUseWithoutEquipmentConnection Then
								
								// we will authorize operation previously
								FormParameters = New Structure();
								FormParameters.Insert("Amount", Object.DocumentAmount - Object.CashReceived - Object.PaymentWithPaymentCards.Total("Amount"));
								FormParameters.Insert("LimitAmount", Object.DocumentAmount - Object.PaymentWithPaymentCards.Total("Amount"));
								FormParameters.Insert("ListOfCardTypes", New ValueList());
								IndexOf = 0;
								For Each CardKind In Items.PaymentByChargeCardTypeCards.ChoiceList Do
									FormParameters.ListOfCardTypes.Add(IndexOf, CardKind.Value);
									IndexOf = IndexOf + 1;
								EndDo;
								
								Result = Undefined;

								
								OpenForm("Catalog.Peripherals.Form.POSTerminalAuthorizationForm", FormParameters,,,,, New NotifyDescription("AddPaymentByCardEnd", ThisObject, New Structure("FRDeviceIdentifier, ETDeviceIdentifier, CardNumber", DeviceIdentifierFR, DeviceIdentifierET, CardNumber)));
							Else
								MessageText = NStr("en = 'An error occurred while connecting
								                   |the fiscal register: ""%ErrorDescription%"".
								                   |Operation by card has not been performed.'; 
								                   |ru = 'При подключении фискального регистратора произошла ошибка:
								                   |""%ErrorDescription%"".
								                   |Операция по карте не была выполнена.';
								                   |pl = 'W czasie połączenia
								                   |rejestratora fiskalnego wystąpił błąd:""%ErrorDescription%"".
								                   | Operacja z kartą nie została wykonana.';
								                   |es_ES = 'Ha ocurrido un error al conectar
								                   |el registro fiscal: ""%ErrorDescription%"".
								                   |Operación con tarjeta no se ha realizado.';
								                   |es_CO = 'Ha ocurrido un error al conectar
								                   |el registro fiscal: ""%ErrorDescription%"".
								                   |Operación con tarjeta no se ha realizado.';
								                   |tr = 'Mali kayıt cihazı bağlanırken
								                   |hata oluştu: ""%ErrorDescription%"".
								                   |Kartla işlem yapılamadı.';
								                   |it = 'Un errore si è registrato durante la connessione
								                   |del registratore fiscale: ""%ErrorDescription%"".
								                   |L''operazione con la carta non è stata eseguita.';
								                   |de = 'Beim Verbinden
								                   |des Fiskalspeichers ist ein Fehler aufgetreten: ""%ErrorDescription%"".
								                   |Die Operation per Karte wurde nicht ausgeführt.'");
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
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
							CommonClientServer.MessageToUser(MessageText);
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		Else
			
			// External equipment is not used
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'; ru = 'Не удалось выполнить проведение документа';pl = 'Księgowanie dokumentu nie powiodło się';es_ES = 'Fallado a enviar el documento';es_CO = 'Fallado a enviar el documento';tr = 'Belge kaydedilemedi';it = 'Impossibile pubblicare il documento';de = 'Fehler beim Buchen des Dokuments'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure AddPaymentByCardEnd(Result1, AdditionalParameters) Export
    
    DeviceIdentifierFR = AdditionalParameters.DeviceIdentifierFR;
    DeviceIdentifierET = AdditionalParameters.DeviceIdentifierET;
    CardNumber = AdditionalParameters.CardNumber;
    
    
    // we will authorize operation previously
    Result = Result1;
    
    If TypeOf(Result) = Type("Structure") Then
        
        InputParameters  = New Array();
        Output_Parameters = Undefined;
        
        InputParameters.Add(Result.Amount);
        InputParameters.Add(Result.CardNumber);
        
        AmountOfOperations       = Result.Amount;
        CardNumber          = Result.CardNumber;
        OperationRefNumber = Result.RefNo;
        ETReceiptNo         = Result.ReceiptNumber;
        CardKind      = Items.PaymentByChargeCardTypeCards.ChoiceList[Result.CardType].Value;
        
        // Executing the operation on POS terminal
        ResultET = EquipmentManagerClient.RunCommand(DeviceIdentifierET,
        "AuthorizeSales",
        InputParameters,
        Output_Parameters);
        
        If ResultET Then
            
            CardNumber          = ?(NOT IsBlankString(CardNumber)
            AND IsBlankString(StrReplace(TrimAll(Output_Parameters[0]), "*", "")),
            CardNumber, Output_Parameters[0]);
            OperationRefNumber = Output_Parameters[1];
            ETReceiptNo         = Output_Parameters[2];
            SlipCheckString      = Output_Parameters[3][1];
            
            If Not IsBlankString(SlipCheckString) Then
                glPeripherals.Insert("LastSlipReceipt", SlipCheckString);
            EndIf;
            
            If Not IsBlankString(SlipCheckString) AND Not CashCRUseWithoutEquipmentConnection Then
                InputParameters  = New Array();
                InputParameters.Add(SlipCheckString);
                Output_Parameters = Undefined;
                
                ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
                "PrintText",
                InputParameters,
                Output_Parameters);
			Else
				ResultFR = True;
            EndIf;
            
        Else
            
            MessageText = NStr("en = 'When operation execution there
                               |was error: ""%ErrorDescription%"".
                               |Payment by card has not been performed.'; 
                               |ru = 'При выполнении операции возникла ошибка:
                               |""%ErrorDescription%"".
                               |Отмена по карте не была произведена';
                               |pl = 'W czasie realizacji operacji wystąpił
                               |błąd: ""%ErrorDescription%"".
                               |Opłata kartą nie została wykonana.';
                               |es_ES = 'Ejecutando la operación, se ha
                               |producido el error: ""%ErrorDescription%"".
                               |Pago con tarjeta no se ha realizado.';
                               |es_CO = 'Ejecutando la operación, se ha
                               |producido el error: ""%ErrorDescription%"".
                               |Pago con tarjeta no se ha realizado.';
                               |tr = 'İşlem esnasında bir 
                               |hata oluştu: ""%ErrorDescription%"". 
                               |Kartla iptal işlemi yapılmadı.';
                               |it = 'Durante l''esecuzione dell''operazione
                               |si è registrato un errore: ""%ErrorDescription%"".
                               |Il pagamento con carta non è stato eseguito.';
                               |de = 'Bei der Ausführung der Operation
                               |ist ein Fehler aufgetreten: ""%ErrorDescription%"".
                               |Die Zahlung per Karte wurde nicht ausgeführt.'"
            );
            MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
            CommonClientServer.MessageToUser(MessageText);
            
        EndIf;
        
        If ResultET AND (NOT ResultFR AND Not CashCRUseWithoutEquipmentConnection) Then
            
            ErrorDescriptionFR = Output_Parameters[1];
            
            InputParameters  = New Array();
            Output_Parameters = Undefined;
            
            InputParameters.Add(AmountOfOperations);
            InputParameters.Add(OperationRefNumber);
            InputParameters.Add(ETReceiptNo);
            
            // Executing the operation on POS terminal
            EquipmentManagerClient.RunCommand(DeviceIdentifierET,
            "EmergencyVoid",
            InputParameters,
            Output_Parameters);
            
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
                               |Die Bedienung per Karte wurde abgebrochen.'"
            );
            MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescriptionFR);
            CommonClientServer.MessageToUser(MessageText);
            
        ElsIf ResultET Then
            
            // Save the data of payment by card to the table
            PaymentRowByCard = Object.PaymentWithPaymentCards.Add();
            
            PaymentRowByCard.ChargeCardKind   = CardKind;
            PaymentRowByCard.ChargeCardNo = CardNumber; // ItIsPossible record empty Numbers maps or Numbers type "****************"
            PaymentRowByCard.Amount               = AmountOfOperations;
            PaymentRowByCard.RefNo      = OperationRefNumber;
            PaymentRowByCard.ETReceiptNo         = ETReceiptNo;
            
            RecalculateDocumentAtClient();
            
            Write(); // It is required to write document to prevent information loss.
            
        EndIf;
    EndIf;
    
    // FR device disconnect
    EquipmentManagerClient.DisableEquipmentById(UUID,
    DeviceIdentifierFR);
    // ET device disconnect
    EquipmentManagerClient.DisableEquipmentById(UUID,
    DeviceIdentifierET);

EndProcedure

// Procedure - DeletePaymentByCard command handler.
//
&AtClient
Procedure DeletePaymentByCard(Command)
	
	DeviceIdentifierET = Undefined;
	DeviceIdentifierFR = Undefined;
	ErrorDescription            = "";
	
	// Check selected string in payment table by payment cards
	CurrentData = Items.PaymentWithPaymentCards.CurrentData;
	If CurrentData = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'Select a row of deleted payment by card'; ru = 'Выберите строку удаляемой оплаты картой.';pl = 'Wybierz wiersz usuwanej płatności kartą';es_ES = 'Seleccionar una fila de los pagos borrados con tarjeta';es_CO = 'Seleccionar una fila de los pagos borrados con tarjeta';tr = 'Kartla silinen ödemelerin bir satırını seçin';it = 'Selezionare una riga di pagamento cancellato con carta';de = 'Wählen Sie eine Zeile mit gelöschter Zahlung per Karte aus'"));
		Return;
	EndIf;
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If UsePeripherals Then // Check on the included FO "Use ExternalEquipment"
			If EquipmentManagerClient.RefreshClientWorkplace()Then // Checks if the operator's workplace is specified
				AmountOfOperations       = CurrentData.Amount;
				CardNumber          = CurrentData.ChargeCardNo;
				OperationRefNumber = CurrentData.RefNo;
				ETReceiptNo         = CurrentData.ETReceiptNo;
				SlipCheckString      = "";
				
				// Device selection ET
				DeviceIdentifierET = ?(ValueIsFilled(POSTerminal),
											  POSTerminal,
											  Undefined);
				
				If DeviceIdentifierET <> Undefined Then
					// Device selection FR
					DeviceIdentifierFR = ?(ValueIsFilled(FiscalRegister),
												  FiscalRegister,
												  Undefined);
					
					If DeviceIdentifierFR <> Undefined OR CashCRUseWithoutEquipmentConnection Then
						// ET device connection
						ResultET = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																										DeviceIdentifierET,
																										ErrorDescription);
						
						If ResultET Then
							// FR device connection
							ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																											DeviceIdentifierFR,
																											ErrorDescription);
							
							If ResultFR OR CashCRUseWithoutEquipmentConnection Then
								
								InputParameters  = New Array();
								Output_Parameters = Undefined;
								
								InputParameters.Add(AmountOfOperations);
								InputParameters.Add(OperationRefNumber);
								InputParameters.Add(ETReceiptNo);
								
								// Executing the operation on POS terminal
								ResultET = EquipmentManagerClient.RunCommand(DeviceIdentifierET,
																						  "AuthorizeVoid",
																						  InputParameters,
																						  Output_Parameters);
								
								If ResultET Then
									
									CardNumber          = "";
									OperationRefNumber = "";
									ETReceiptNo         = "";
									SlipCheckString      = Output_Parameters[0][1];
									
									If Not IsBlankString(SlipCheckString) Then
										glPeripherals.Insert("LastSlipReceipt", SlipCheckString);
									EndIf;
									
									If Not IsBlankString(SlipCheckString) AND Not CashCRUseWithoutEquipmentConnection Then
										InputParameters  = New Array();
										InputParameters.Add(SlipCheckString);
										Output_Parameters = Undefined;
										
										ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
																								  "PrintText",
																								  InputParameters,
																								  Output_Parameters);
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
									
									Object.PaymentWithPaymentCards.Delete(CurrentData);
									
									RecalculateDocumentAtClient();
									
									Write();
									
								EndIf;
								
								// FR device disconnect
								EquipmentManagerClient.DisableEquipmentById(UUID,
																								 DeviceIdentifierFR);
								// ET device disconnect
								EquipmentManagerClient.DisableEquipmentById(UUID,
																								 DeviceIdentifierET);
							Else
								MessageText = NStr("en = 'An error occurred while connecting
								                   |the fiscal register: ""%ErrorDescription%"".
								                   |Operation by card has not been performed.'; 
								                   |ru = 'При подключении фискального регистратора произошла ошибка:
								                   |""%ErrorDescription%"".
								                   |Операция по карте не была выполнена.';
								                   |pl = 'W czasie połączenia
								                   |rejestratora fiskalnego wystąpił błąd:""%ErrorDescription%"".
								                   | Operacja z kartą nie została wykonana.';
								                   |es_ES = 'Ha ocurrido un error al conectar
								                   |el registro fiscal: ""%ErrorDescription%"".
								                   |Operación con tarjeta no se ha realizado.';
								                   |es_CO = 'Ha ocurrido un error al conectar
								                   |el registro fiscal: ""%ErrorDescription%"".
								                   |Operación con tarjeta no se ha realizado.';
								                   |tr = 'Mali kayıt cihazı bağlanırken
								                   |hata oluştu: ""%ErrorDescription%"".
								                   |Kartla işlem yapılamadı.';
								                   |it = 'Un errore si è registrato durante la connessione
								                   |del registratore fiscale: ""%ErrorDescription%"".
								                   |L''operazione con la carta non è stata eseguita.';
								                   |de = 'Beim Verbinden
								                   |des Fiskalspeichers ist ein Fehler aufgetreten: ""%ErrorDescription%"".
								                   |Die Operation per Karte wurde nicht ausgeführt.'");
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
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
							CommonClientServer.MessageToUser(MessageText);
						EndIf;
					EndIf;
				EndIf;
			Else
				MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
				
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'; ru = 'Не удалось выполнить проведение документа';pl = 'Księgowanie dokumentu nie powiodło się';es_ES = 'Fallado a enviar el documento';es_CO = 'Fallado a enviar el documento';tr = 'Belge kaydedilemedi';it = 'Impossibile pubblicare il documento';de = 'Fehler beim Buchen des Dokuments'"));
	EndIf;
	
EndProcedure

// Procedure - PrintLastSlipCheck command handler.
//
&AtClient
Procedure PrintLastSlipReceipt(Command)
	
	If UsePeripherals Then // Check on the included FO "Use ExternalEquipment"
		If EquipmentManagerClient.RefreshClientWorkplace()Then // Checks if the operator's workplace is specified
			DeviceIdentifierFR = Undefined;
			ErrorDescription            = "";
			
			SlipCheckString = "";
			If Not glPeripherals.Property("LastSlipReceipt", SlipCheckString)
			 Or TypeOf(SlipCheckString) <> Type("String")
			 Or IsBlankString(SlipCheckString) Then
				CommonClientServer.MessageToUser(NStr("en = 'Slip check is absent.
				                                         |Acquiring operation may not have been executed for this session.'; 
				                                         |ru = 'Слип-чек отсутствует.
				                                         |Возможно для данного сеанса еще не выполнялась эквайринговая операция.';
				                                         |pl = 'Brak paragonu.
				                                         |Być może w danej sesji nie przeprowadzono jeszcze operacji bezgotówkowych.';
				                                         |es_ES = 'Revisión de comprobante está faltando.
				                                         |Puede ser que la operación de adquisición no se haya ejecutado para esta sesión.';
				                                         |es_CO = 'Revisión de comprobante está faltando.
				                                         |Puede ser que la operación de adquisición no se haya ejecutado para esta sesión.';
				                                         |tr = 'Kayma kontrolü mevcut değil. 
				                                         |Bu oturum için satın alma işlemi yürütülememiş olabilir.';
				                                         |it = 'Controllo scontrino è assente.
				                                         |L''operazione di acquisizione potrebbe non essere stata eseguita per questa sessione.';
				                                         |de = 'Belegprüfung fehlt.
				                                         |Die angeforderte Operation wurde für diese Sitzung möglicherweise nicht ausgeführt.'"));
				Return;
			EndIf;
			
			// Device selection FR
			DeviceIdentifierFR = ?(ValueIsFilled(FiscalRegister),
										  FiscalRegister,
										  Undefined);
			
			If DeviceIdentifierFR <> Undefined Then
				// FR device connection
				ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																								DeviceIdentifierFR,
																								ErrorDescription);
				
				If ResultFR Then
					
					InputParameters  = New Array();
					InputParameters.Add(SlipCheckString);
					Output_Parameters = Undefined;
					
					ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
																			  "PrintText",
																			  InputParameters,
																			  Output_Parameters);
					If Not ResultFR Then
						MessageText = NStr("en = 'When printing slip receipt
						                   |there was error: ""%ErrorDescription%"".'; 
						                   |ru = 'При печати слип-чека
						                   |возникла ошибка: ""%ErrorDescription%"".';
						                   |pl = 'W czasie drukowania paragonu
						                   |wystąpił błąd: ""%ErrorDescription%"".';
						                   |es_ES = 'Imprimiendo el recibo del comprobante
						                   |, se ha producido el error: ""%ErrorDescription%"".';
						                   |es_CO = 'Imprimiendo el recibo del comprobante
						                   |, se ha producido el error: ""%ErrorDescription%"".';
						                   |tr = 'Fiş makbuzu yazdırırken 
						                   |hata oluştu: ""%ErrorDescription%"".';
						                   |it = 'Durante la stampa dello scontrino
						                   |c''è stato un errore: ""%ErrorDescription%"".';
						                   |de = 'Beim Drucken des Belegs
						                   |ist ein Fehler aufgetreten: ""%ErrorDescription%"".'");
						MessageText = StrReplace(MessageText,
													 "%ErrorDescription%",
													 Output_Parameters[1]);
						CommonClientServer.MessageToUser(MessageText);
					EndIf;
					
					// FR device disconnect
					EquipmentManagerClient.DisableEquipmentById(UUID,
																					 DeviceIdentifierFR);
				Else
					MessageText = NStr("en = 'An error occurred while connecting the fiscal register: ""%ErrorDescription%"".'; ru = 'При подключении фискального регистратора произошла ошибка: ""%ErrorDescription%"".';pl = 'Podczas połączenia rejestratora fiskalnego wystąpił błąd: ""%ErrorDescription%"".';es_ES = 'Ha ocurrido un error al conectar el registro fiscal: ""%ErrorDescription%"".';es_CO = 'Ha ocurrido un error al conectar el registro fiscal: ""%ErrorDescription%"".';tr = 'Mali kayıt bağlanırken hata oluştu: ""%ErrorDescription%"".';it = 'Si è verificato un errore durante la connessione del registratore fiscale: %ErrorDescription%.';de = 'Beim Verbinden des Fiskalregisters ist ein Fehler aufgetreten: ""%ErrorDescription%"".'");
					MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
					CommonClientServer.MessageToUser(MessageText);
				EndIf;
			EndIf;
		Else
			MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
			
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler Reserve on server.
&AtServer
Procedure ReserveAtServer(CancelReservation = False)
	
	OldStatus = Object.Status;
	
	If CancelReservation Then
		Object.Status = Undefined;
		WriteMode = DocumentWriteMode.UndoPosting;
	Else
		Object.Status = Enums.SalesSlipStatus.ProductReserved;
		WriteMode= DocumentWriteMode.Posting;
	EndIf;
	
	Try
		If Not Write(New Structure("WriteMode", WriteMode)) Then
			Object.Status = OldStatus;
		EndIf;
	Except
		Object.Status = OldStatus;
	EndTry;
	
	SetEnabledOfReceiptPrinting();
	SetPaymentEnabled();
	
EndProcedure

// Procedure - The Reserve command handler.
//
&AtClient
Procedure Reserve(Command)
	
	ReserveAtServer();
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
EndProcedure

// Procedure - command handler RemoveReservation.
//
&AtClient
Procedure RemoveReservation(Command)
	
	ReserveAtServer(True);
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
EndProcedure

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
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

// Procedure calculates the amount of payment in cash.
//
&AtClient
Procedure CalculateAmountOfCashVoucher(Command)
	
	PaymentTotalPaymentCards = Object.PaymentWithPaymentCards.Total("Amount");
	Object.CashReceived = Object.DocumentAmount
							 - ?(PaymentTotalPaymentCards > Object.DocumentAmount, 0, PaymentTotalPaymentCards);
	
	RecalculateDocumentAtClient();
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
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
			
			Modified = True;
			
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

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange field CashRegister on server.
//
&AtServer
Procedure CashCROnChangeAtServer()
	
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionAttributesToDate(Object.CashCR, ?(ValueIsFilled(Object.Ref), Object.Date, CurrentSessionDate()));
	
	If ValueIsFilled(StatusCashCRSession.CashCRSessionStatus) Then
		FillPropertyValues(Object, StatusCashCRSession);
	EndIf;
	
	Items.Reserve.Visible = Not ControlAtWarehouseDisabled;
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
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
	Items.InventoryVATAmount.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	
EndProcedure

// Procedure - event handler OnChange field CashCR.
//
&AtClient
Procedure CashCROnChange(Item)
	
	CashCROnChangeAtServer();
	DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
	RecalculateDocumentAtClient();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentInCashAmount field.
//
&AtClient
Procedure CashReceivedOnChange(Item)
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler OnChange field POSTerminal on server.
//
&AtServer
Procedure POSTerminalOnChangeAtServer()
	
	GetRefsToEquipment();
	GetChoiceListOfPaymentCardKinds();
	SetPaymentEnabled();
	
EndProcedure

// Procedure - OnChange event handler of the POSTerminal field.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	POSTerminalOnChangeAtServer();
	
EndProcedure

// Procedure - OnChange event handler of the PettyCashShift field.
//
&AtServer
Procedure CashCRSessionOnChangeAtServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ShiftClosure.CashCR AS CashCR
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	ShiftClosure.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.CashCRSession);
	
	Result = Query.Execute();
	Selection = Result.Select();
	Selection.Next();
	
	Object.CashCR = Selection.CashCR;
	
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(Object.CashCR);
	FillPropertyValues(Object, StatusCashCRSession);
	
	Items.Reserve.Visible = Not ControlAtWarehouseDisabled;
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
EndProcedure

// Procedure - OnChange event handler of the PettyCashShift field.
//
&AtClient
Procedure CashCRSessionOnChange(Item)
	
	CashCRSessionOnChangeAtServer();
	DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - OnChange event handler of the PaymentForm field on server.
//
&AtServer
Function PaymentFormOnChangeAtServer(ErrorDescription = "")
	
	If Object.CashAssetType = Enums.CashAssetTypes.Cash Then
		
		If Object.PaymentWithPaymentCards.Count() > 0 Then
			
			Object.PaymentMethod = Catalogs.PaymentMethods.Undefined;
			Object.CashAssetType = Enums.CashAssetTypes.EmptyRef();
			
			ErrorDescription = NStr("en = 'Paid with payment cards. Cannot set the ""In cash"" payment method'; ru = 'Проведена оплата платежными картами! Установить форму оплаты ""Наличными"" невозможно';pl = 'Opłacono kartąi. Nie można wybrać sposobu płatności ""gotówka""';es_ES = 'Pagado con tarjetas de pago. No se puede establecer el método de pago ""En efectivo""';es_CO = 'Pagado con tarjetas de pago. No se puede establecer el método de pago ""En efectivo""';tr = 'Ödeme kartları ile ödendi. ""Nakit para"" ödeme yöntemi ayarlanamaz';it = 'Pagamento con carte di pagamento! È impossibile impostare una forma di pagamento ""Contanti""';de = 'Bezahlt mit Zahlungskarten. Die Zahlungsmethode ""in bar"" kann nicht festgelegt werden'");
			Return False;
			
		EndIf;
		
	ElsIf Not ValueIsFilled(Object.CashAssetType) Then // Mixed
		
	Else // By payment cards
		
		Object.CashReceived = 0;
		
	EndIf;
	
	SetPaymentEnabled();
	
	Return True;
	
EndFunction

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	ErrorDescription = "";
	If Not PaymentFormOnChangeAtServer(ErrorDescription) Then
		ShowMessageBox(Undefined, ErrorDescription);
	EndIf;
EndProcedure

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

// Procedure - event handler OnChange field Company.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	CompanyOnChangeAtServer();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
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
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", TabularSectionRow);
	
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
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
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
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
			Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
		
	EndIf;
	
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
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 	Object.Date);
		StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
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

// Procedure - event handler OnChange input field AmountDiscountsMarkups.
//
&AtClient
Procedure InventoryAmountDiscountsMarkupsOnChange(Item)
	
	CalculateDiscountMarkupPercent();
	
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

// Procedure - event handler OnEditEnd of the Inventory list row.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	ThisIsNewRow = False;
	
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
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenSerialNumbersSelection();
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
		// Serial numbers
		CurrentData = Items.Inventory.CurrentData;
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
			Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

#EndRegion

// Procedure - OnEditEnd event handler of the PaymentWithPaymentCards list string.
//
&AtClient
Procedure PaymentWithPaymentCardsOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

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

#Region DiscountCards

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", , ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

// Final part of procedure - of command handler ReadDiscountCard forms.
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
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
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

// Function returns True if the discount card, which is passed as the parameter, is fixed.
//
&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountTypeForDiscountCards.FixedDiscount;
	
EndFunction

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChange()
	
	If Object.DiscountCard.IsEmpty() OR ThisDiscountCardWithFixedDiscount(Object.DiscountCard) Then
		Return;
	EndIf;
	
	PreDiscountPercentByDiscountCard = Object.DiscountPercentByDiscountCard;
	NewDiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	If PreDiscountPercentByDiscountCard <> NewDiscountPercentByDiscountCard Then
		
		If Object.Inventory.Count() > 0 Then
			
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to change the discount rate from %1% to %2% and apply to the document?'; ru = 'Процент скидки карты изменится с %1% на %2% и будет перезаполнен в документе. Продолжить?';pl = 'Zmienić stawkę rabatową z %1% na %2% i zastosować w dokumencie?';es_ES = '¿Quiere cambiar el tipo de descuento de %1% a %2% y aplicar en el documento?';es_CO = '¿Quiere cambiar el tipo de descuento de %1% a %2% y aplicar en el documento?';tr = 'İndirim oranını %1%''den %2%''ye değiştirmek ve dokümana uygulamak ister misiniz?';it = 'Volete cambiare la percentuale di sconto da %1% a %2% ed applicarla al documento?';de = 'Möchten Sie den Diskontsatz von %1% in %2% ändern und auf das Dokument anwenden?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);			
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		Else
			
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to change the discount rate from %1% to %2%?'; ru = 'Изменить процент скидки карты с %1% на %2%?';pl = 'Zmienić stawkę rabatu z %1% na %2%?';es_ES = '¿Quiere cambiar el tipo de descuento de %1% a %2%?';es_CO = '¿Quiere cambiar el tipo de descuento de %1% a %2%?';tr = 'İndirim oranını %1%''den %2%''ye değiştirmek ister misiniz?';it = 'Volete cambiare la percentuale di sconto da %1% a %2%?';de = 'Möchten Sie den Diskontsatz von %1% in %2% ändern?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);			
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		EndIf;
		
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
		
	EndIf;
	
EndProcedure

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
		LabelStructure.Insert("ExchangeRate",					ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
				
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

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If discounts changed the function returns the value True.
//
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
	EndDo;
	
EndProcedure

// Procedure - command handler "OpenInformationAboutDiscounts".
//
&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
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

// End modeless window opening "ShowQuestion()". Procedure opens a common form for information analysis about discounts
// by current row.
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

// Procedure - event handler Table parts selection Inventory.
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
		
	ElsIf Field.Name = "InventoryGLAccounts" Then
		
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory", , ReadOnly);
		
	ElsIf Field.Name = "InventoryIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Inventory forms.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
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
Procedure InventoryBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	// Bundles
	If Clone Then
		
		If ValueIsFilled(Item.CurrentData.BundleProduct) Then
			Cancel = True;
		EndIf;
		
	EndIf;
	// End Bundles
	
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

// Procedure - AppliedDiscounts event handler of the form.
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

// End the AppliedDiscounts procedure. Called after closing the answer form.
//
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

// Procedure - event handler AfterWriteAtServer form.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
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

#EndRegion

#EndRegion

#Region Private

&AtClientAtServerNoContext
Function CreateGeneralAttributeValuesStructure(Form, TabName, TabRow)
	
	Object = Form.Object;
	
	StructureData = New Structure("
	|TabName,
	|Object,
	|Company,
	|Products,
	|Characteristic,
	|VATTaxation,
	|UseDefaultTypeOfAccounting,
	|IncomeAndExpenseItems,
	|IncomeAndExpenseItemsFilled,
	|RevenueItem");
	
	FillPropertyValues(StructureData, Form);
	FillPropertyValues(StructureData, Object);
	FillPropertyValues(StructureData, TabRow);
	
	StructureData.Insert("TabName", TabName);
	
	Return StructureData;
	
EndFunction

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