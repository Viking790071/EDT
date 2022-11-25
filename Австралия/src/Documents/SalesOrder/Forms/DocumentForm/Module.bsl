
#Region Variables

&AtClient
Var ThisIsNewRow;

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		If Object.Ref.IsEmpty() Then
			Cancel = True;
		EndIf;
		Return;
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	If Not ValueIsFilled(Object.ShipmentDate) Then
		Object.ShipmentDate = DocumentDate;
	EndIf;
	
	ThisObject.InventoryReservation	= GetFunctionalOption("UseInventoryReservation");
	ThisObject.ForeignExchangeAccounting	= GetFunctionalOption("ForeignExchangeAccounting");
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	ThisObject.Counterparty	= Object.Counterparty;
	ThisObject.Contract		= Object.Contract;
	ShipmentDate = Object.ShipmentDate;
	If ValueIsFilled(ThisObject.Contract) Then
		ThisObject.SettlementsCurrency = Common.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	
	ThisObject.FunctionalCurrency			= DriveReUse.GetFunctionalCurrency();
	StructureByCurrency						= CurrencyRateOperations.GetCurrencyRate(Object.Date, ThisObject.FunctionalCurrency, Object.Company);
	ThisObject.NationalCurrencyExchangeRate	= StructureByCurrency.Rate;
	ThisObject.NationalCurrencyMultiplicity	= StructureByCurrency.Repetition;
	TabularSectionName = "Inventory";
	
	SetAccountingPolicyValues();
	
	ReadCounterpartyAttributes(ThisObject.CounterpartyAttributes, Object.Counterparty);
	
	TollProcessing					= GetFunctionalOption("UseSubcontractingManufacturing");
	Items.OperationKind.ReadOnly	= Not TollProcessing;
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesSalesOrder.OrderForSale);
	
	If TollProcessing Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesSalesOrder.OrderForProcessing);
	EndIf;

	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation(True);
		FillSalesTaxRate(True);
		
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		And ValueIsFilled(Parameters.CopyingValue)
		And Object.SetPaymentTerms Then
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar, , Parameters.CopyingValue);
		
	EndIf;
	
	SetVisibleTaxAttributes();
	
	Items.StructuralUnitReserve.Visible	= ThisObject.InventoryReservation;
	
	If Items.OperationKind.ChoiceList.Count() = 1 Then
		Items.OperationKind.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	// If the document is opened from pick, fill the tabular section products
	If Parameters.FillingValues.Property("InventoryAddressInStorage") 
		AND ValueIsFilled(Parameters.FillingValues.InventoryAddressInStorage) Then
		
		GetInventoryFromStorage(Parameters.FillingValues.InventoryAddressInStorage, 
			Parameters.FillingValues.TabularSectionName,
			Parameters.FillingValues.AreCharacteristics,
			Parameters.FillingValues.AreBatches);
		
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly				= Not AllowedEditDocumentPrices;
	
	// Status.
	
	InProcessStatus = DriveReUse.GetStatusInProcessOfSalesOrders();
	CompletedStatus = DriveReUse.GetStatusCompletedSalesOrders();
	
	If GetFunctionalOption("UseSalesOrderStatuses") Then
		
		Items.GroupStatuses.Visible = False;
		
	Else
		
		Items.StateGroup.Visible = False;
		
		StatusesStructure = Documents.SalesOrder.GetSalesOrderStringStatuses();
		
		For Each Item In StatusesStructure Do
			Items.Status.ChoiceList.Add(Item.Key, Item.Value);
		EndDo;
		
		ResetStatus();
		
	EndIf;
	
	Items.LastEvent.Visible = GetFunctionalOption("UseDocumentEvent");
	
	// Bundles
	BundlesOnCreateAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Parameters.FillingValues.Property("Inventory") Then
			
			For Each RowData In Parameters.FillingValues.Inventory Do
				
				FilterStructure = New Structure;
				FilterStructure.Insert("Products", RowData.Products);
				If RowData.Property("Characteristic") And ValueIsFilled(RowData.Characteristic) Then
					FilterStructure.Insert("Characteristic", RowData.Characteristic);
				EndIf;
				Rows = Object.Inventory.FindRows(FilterStructure);
				
				For Each BundleRow In Rows Do
					
					StructureData = New Structure();
					StructureData.Insert("Company",			Object.Company);
					StructureData.Insert("Products",		BundleRow.Products);
					StructureData.Insert("Characteristic",	BundleRow.Characteristic);
					StructureData.Insert("VATTaxation",		Object.VATTaxation);
					StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
					
					If ValueIsFilled(Object.PriceKind) Then
						StructureData.Insert("ProcessingDate",		Object.Date);
						StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
						StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
						StructureData.Insert("PriceKind",			Object.PriceKind);
						StructureData.Insert("Factor",				1);
						StructureData.Insert("DiscountMarkupKind",	Object.DiscountMarkupKind);
					EndIf;
					
					// DiscountCards
					StructureData.Insert("DiscountCard", Object.DiscountCard);
					StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
					// End DiscountCards
					
					AddTabRowDataToStructure(ThisObject, "Inventory", StructureData, BundleRow);
					
					StructureData = GetDataProductsOnChange(StructureData);
					
					If StructureData.IsBundle And Not StructureData.UseCharacteristics Then
						ReplaceInventoryLineWithBundleData(ThisObject, BundleRow, StructureData);
					Else
						FillPropertyValues(BundleRow, StructureData);
					EndIf;
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
		RefreshBundlePictures(Object.Inventory);
		RefreshBundleAttributes(Object.Inventory);
		
	EndIf;
	
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
	ProcessingCompanyVATNumbers();
	
	//Conditional appearance
	SetConditionalAppearance();
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters);
	// End StandardSubsystems.Interactions
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.SalesOrder.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	ReadAdditionalInformationPanelData();
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If UsersClientServer.IsExternalUserSession() Then
		PrintManagementClientDrive.GeneratePrintFormForExternalUsers(Object.Ref,
			"Document.SalesOrder",
			"OrderConfirmation",
			NStr("en = 'Order confirmation'; ru = 'Заказ покупателя';pl = 'Potwierdzenie zamówienia';es_ES = 'Confirmación de pedido';es_CO = 'Confirmación de pedido';tr = 'Sipariş onayı';it = 'Conferma ordine';de = 'Auftragsbestätigung'"),
			FormOwner,
			UniqueKey);
		Cancel = True;
		Return;
	EndIf;
	
	FormManagement();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	SetVisibleEnablePaymentTermItems();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
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
	
	If EventName = "Write_Counterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(ThisObject.CounterpartyAttributes, Parameter);
		FormManagement();
		
	EndIf;
	
	// Bundles
	If BundlesClient.ProcessNotifications(ThisObject, EventName, Source) Then
		RefreshBundleComponents(Parameter.BundleProduct, Parameter.BundleCharacteristic, Parameter.Quantity, Parameter.BundleComponents);
		ActionsAfterDeleteBundleLine();
	EndIf;
	// End Bundles
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			RecalculateSalesTax();
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
			
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

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		If DriveReUse.CounterpartyContractsControlNeeded() And CounterpartyAttributes.DoOperationsByContracts Then
			
			CheckContractToDocumentConditionAccordance(
				MessageText, 
				CurrentObject.Contract, 
				CurrentObject.Ref, 
				CurrentObject.Company, 
				CurrentObject.Counterparty, 
				CurrentObject.OperationKind, 
				Cancel);
			
		EndIf;
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the sales order.'; ru = 'Невозможно провести заказ покупателя.';pl = 'Nie można zatwierdzić zamówienia sprzedaży.';es_ES = 'No se puede enviar el orden de venta.';es_CO = 'No se puede enviar el orden de venta.';tr = 'Satış siparişi kaydedilemiyor.';it = 'Impossibile pubblicare l''ordine cliente.';de = 'Der Kundenauftrag kann nicht gebucht werden.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
	EndIf;
	
	SalesTaxServer.CalculateInventorySalesTaxAmount(CurrentObject.Inventory, CurrentObject.SalesTax.Total("Amount"));
	
	AmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject);
	If AmountsHaveChanged Then
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(CurrentObject);
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReadAdditionalInformationPanelData();
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
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

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.Interactions
	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "SalesOrder");
	// End StandardSubsystems.Interactions
	
	Notify("Write_SalesOrder", Object.Ref);
	If Object.Posted
		And ValueIsFilled(Object.BasisDocument)
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.Quote") Then
		NotifyParameter = New Structure;
		NotifyParameter.Insert("Quotation", Object.BasisDocument);
		NotifyParameter.Insert("Status", PredefinedValue("Catalog.QuotationStatuses.Converted"));
		Notify("Write_Quotation", NotifyParameter, ThisObject);
	EndIf;
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	// End Bundles
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormItemEventHandlersHeader

&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "StatusInProcess" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "StatusCompleted" Then
		Object.OrderState = CompletedStatus;
	ElsIf Status = "StatusCanceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	FormManagement();
	
EndProcedure

&AtClient
Procedure OrderStateOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then 
		Object.Closed = False;
	EndIf;
	FormManagement();
	
EndProcedure

&AtClient
Procedure OrderStateStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ChoiceData = GetSalesOrderStates();
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	// Company change event processor.
	Object.Number = "";
	StructureData = GetDataCompanyOnChange();
	ParentCompany = StructureData.Company;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	// Petty cash by default
	If StructureData.Property("PettyCash") Then
		Object.PettyCash = StructureData.PettyCash;
	EndIf;
	// End Petty cash by default
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ProcessContractChange();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
	
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure StructuralUnitReserveOnChange(Item)
	StructuralUnitReserveOnChangeAtServer();
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	ProcessContractChange();
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If TypeOfOperationsBeforeChange <> Object.OperationKind Then
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForSale") Then
			Items.ReadDiscountCard.Visible = True;
		Else
			If Not Object.DiscountCard.IsEmpty() Then
				
				Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
				Object.DiscountPercentByDiscountCard = 0;
				
				GenerateLabelPricesAndCurrency(ThisObject);
				
			EndIf;
			Items.ReadDiscountCard.Visible = False;
			Object.SetPaymentTerms = False;
			Object.PaymentCalendar.Clear();
		EndIf;
	EndIf;
	
	FormManagement();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		Object.DeliveryOption = CounterpartyAttributes.DefaultDeliveryOption;
		Object.SalesRep = CounterpartyAttributes.SalesRep;
		
		ContractData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = ContractData.Contract;
		
		ProcessContractChange(ContractData);
		
		If Not ValueIsFilled(Object.ShippingAddress) Then
			
			DeliveryData = GetDeliveryData(Object.Counterparty);
			
			If DeliveryData.ShippingAddress = Undefined Then
				CommonClientServer.MessageToUser(NStr("en = 'Delivery address is required'; ru = 'Укажите адрес доставки';pl = 'Wymagany jest adres dostawy';es_ES = 'Se requiere la dirección de entrega';es_CO = 'Se requiere la dirección de entrega';tr = 'Teslimat adresi gerekli';it = 'È richiesto l''indirizzo di consegna';de = 'Adresse ist ein Pflichtfeld'"));
			Else
				Object.ShippingAddress = DeliveryData.ShippingAddress;
			EndIf;
			
		EndIf;
		
		ProcessShippingAddressChange();
		GenerateLabelPricesAndCurrency(ThisObject);
		FormManagement();
		SetVisibleEnablePaymentTermItems();
		
		Object.Project = PredefinedValue("Catalog.Projects.EmptyRef");
		FillProjectChoiceParameters();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	ClearEstimate();
	
	ReadAdditionalInformationPanelData();
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetContractChoiceFormParameters(
		Object.Ref,
		Object.Company,
		Object.Counterparty,
		Object.Contract,
		CounterpartyAttributes.DoOperationsByContracts,
		Object.OperationKind);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
EndProcedure

&AtClient
Procedure BankAccountOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
EndProcedure

&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	PaymentCalendarCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar Then
		If PaymentCalendarCount > 1 Then
			ClearMessages();
			TextMessage = NStr("en = 'You can''t change the mode of payment terms because there is more than one payment date'; ru = 'Вы не можете переключить режим отображения платежного календаря, т.к. указано более одной даты оплаты.';pl = 'Nie możesz zmienić trybu warunków płatności, ponieważ istnieje kilka dat płatności';es_ES = 'Usted no puede cambiar el modo de los términos de pago porque hay más de una fecha de pago';es_CO = 'Usted no puede cambiar el modo de los términos de pago porque hay más de una fecha de pago';tr = 'Birden fazla ödeme tarihi olduğundan, ödeme şartlarının modu değiştirilemez';it = 'Non è possibile modificare i termini di pagamento, perché c''è più di una data di pagamento';de = 'Sie können den Modus der Zahlungsbedingungen nicht ändern, da es mehr als einen Zahlungsdatum gibt.'");
			CommonClientServer.MessageToUser(TextMessage);
			
			SwitchTypeListOfPaymentCalendar = 1;
		ElsIf PaymentCalendarCount = 0 Then
			NewLine = Object.PaymentCalendar.Add();
		EndIf;
	EndIf;
		
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
EndProcedure

&AtClient
Procedure SetPaymentTermsOnChange(Item)
	
	If Object.SetPaymentTerms Then
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar, True);
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'; ru = 'Условия оплаты будут очищены. Продолжить?';pl = 'Warunki płatności zostaną wyczyszczone. Czy chcesz kontynuować?';es_ES = 'Los términos de pagos se eliminarán. ¿Quiere continuar?';es_CO = 'Los términos de pagos se eliminarán. ¿Quiere continuar?';tr = 'Ödeme şartları silinecek. Devam etmek istiyor musunuz?';it = 'I termini di pagamento saranno cancellati. Continuare?';de = 'Die Zahlungsbedingungen werden gelöscht. Möchten Sie fortfahren?'");
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShipmentDateOnChange(Item)
	
	If ShipmentDate <> Object.ShipmentDate Then
		DatesChangeProcessing();
	EndIf;
	
EndProcedure

&AtClient
Procedure DeliveryOptionOnChange(Item)
	FormManagement();
EndProcedure

&AtClient
Procedure ShippingAddressOnChange(Item)
	ProcessShippingAddressChange();
EndProcedure

&AtClient
Procedure DebtBalanceURLProcessing(Item, FormattedStingHyperlink, StandartProcessing)
	
	StandartProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "BalanceContext");
	FormParameters.Insert("Filter", New Structure("Period, Counterparty", New StandardPeriod, Object.Counterparty));
	FormParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.StatementOfAccount.Form", FormParameters, ThisObject, UUID);
	
EndProcedure

&AtClient
Procedure SalesAmountURLProcessing(Item, FormattedStingHyperlink, StandartProcessing)
	
	StandartProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "SalesDynamicsByCustomers");
	FormParameters.Insert("Filter", New Structure("Period, Counterparty", New StandardPeriod, Object.Counterparty));
	FormParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.NetSales.Form", FormParameters, ThisObject, UUID);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

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
		
	EndIf;
	// End Bundles
	
	If Item.CurrentItem = Items.InventoryAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient();
		
	ElsIf Field.Name = "InventoryGLAccounts" Then
		
		StandardProcessing = False;
		IsReadOnly = ReadOnly Or (Object.OrderState = CompletedStatus);
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory", , IsReadOnly);
		
	EndIf;
	
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
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Copy AND 
		(Item.CurrentData.AutomaticDiscountsPercent <> 0 Or Item.CurrentData.AutomaticDiscountAmount <> 0) Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
		ClearEstimate();
	ElsIf UseAutomaticDiscounts AND NewRow AND Copy Then
		// Automatic discounts have become irrelevant.
		ClearCheckboxDiscountsAreCalculatedClient("OnStartEdit");
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
	ThisIsNewRow = False;

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

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearEstimate();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("StructuralUnit", Object.StructuralUnitReserve);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("Taxable", TabularSectionRow.Taxable);
	StructureData.Insert("Batch", TabularSectionRow.Batch);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("DropShipping", False);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
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
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	// Bundles
	If StructureData.IsBundle And Not StructureData.UseCharacteristics Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateSubtotal();
		
	Else
	// End Bundles
		
		FillPropertyValues(TabularSectionRow, StructureData); 
		TabularSectionRow.Quantity				= 1;
		TabularSectionRow.Content				= "";
		TabularSectionRow.ProductsTypeInventory	= StructureData.IsInventoryItem;
		
		CalculateAmountInTabularSectionLine();
		
		ClearEstimate();
		
	// Bundles
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
Procedure InventoryProductsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.Parent.CurrentData;
	
	ParametersFormProducts = New Structure;
	
	If ValueIsFilled(Object.StructuralUnitReserve) Then
		ParametersFormProducts.Insert("FilterWarehouse", Object.StructuralUnitReserve);
	EndIf;
	
	If ValueIsFilled(Object.Company) Then
		ParametersFormProducts.Insert("FilterBalancesCompany", Object.Company);
	EndIf; 
	
	ChoiceHandler = New NotifyDescription("InventoryProductsStartChoiceEnd", 
		ThisObject, 
		New Structure("CurrentData, Item", CurrentData, Item));
	
	OpenForm("Catalog.Products.ChoiceForm", 
		ParametersFormProducts,
		ThisObject,
		, , , 
		ChoiceHandler, 
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure InventoryProductsStartChoiceEnd(ResultValue, AdditionalParameters) Export
	
	If ResultValue = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters.CurrentData.Products = ResultValue;
	
	InventoryProductsOnChange(AdditionalParameters.Item);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", 				Object.Company);
	StructureData.Insert("Products", 	TabularSectionRow.Products);
	StructureData.Insert("Characteristic",			TabularSectionRow.Characteristic);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(Object.PriceKind) Then
	
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("DocumentCurrency", 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);	
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price", 				TabularSectionRow.Price);	
		StructureData.Insert("PriceKind",			Object.PriceKind);
		StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	// Bundles
	If StructureData.IsBundle Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateSubtotal();
	Else
	// End Bundles
		
		TabularSectionRow.Price			= StructureData.Price;
		TabularSectionRow.Content		= "";
		If StructureData.Property("Specification") Then
			TabularSectionRow.Specification = StructureData.Specification;
		EndIf;
		
		CalculateAmountInTabularSectionLine();
		
		ClearEstimate();
	 	
	// Bundles
	EndIf;
	// End Bundles
	
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
		SelectionMarker		= "Inventory";
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

&AtClient
Procedure InventoryBatchOnChange(Item)
	
	ClearEstimate();

EndProcedure

&AtClient
Procedure InventorySpecificationOnChange(Item)
	
	ClearEstimate();

EndProcedure

&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Inventory.CurrentData;
		ContentPattern = DriveServer.GetContentText(TabularSectionRow.Products, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	InventoryQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure InventoryMeasurementUnitOnChange(Item)
	
	ClearEstimate();

EndProcedure

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
	
	TabularSectionRow.MeasurementUnit = ValueSelected;
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

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
		
	// VAT amount.
	CalculateVATAmount(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryTaxableOnChange(Item)
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryShipmentDateOnChange(Item)
	DatesChangeProcessing();
EndProcedure

&AtClient
Procedure InventoryDropShippingOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.DropShipping Then
		TabularSectionRow.Reserve = 0;
	EndIf; 
	
EndProcedure

#EndRegion

#Region TabularSectionCommandpanelsActions

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.ConsumerMaterials.Count() <> 0 Then
		
		Response = Undefined;

		NotifyDescription = New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject);
		ShowQueryBox(NotifyDescription,
						NStr("en = 'Tabular section ""Third party components"" will be filled in again. Do you want to continue?'; ru = 'Табличная часть ""Компоненты сторонних организаций"" будет перезаполнена. Продолжить?';pl = 'Sekcja tabelaryczna ""Komponenty strony trzeciej"" zostanie wypełniony ponownie. Czy chcesz kontynuować?';es_ES = 'La sección tabular ""Componentes de terceros"" se rellenará de nuevo. ¿Quieres continuar?';es_CO = 'La sección tabular ""Componentes de terceros"" se rellenará de nuevo. ¿Quieres continuar?';tr = '""Üçüncü taraf malzemeleri"" tablo bölümü tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'La sezione tabellare ""Componenti di terze parti"" saranno ricompilati. Continuare?';de = 'Der tabellarische Abschnitt ""Materialbestand von Dritten"" wird erneut ausgefüllt. Möchten Sie fortsetzen?'"), 
						QuestionDialogMode.YesNo, 0);
        Return;
		
	EndIf;
	
	CommandToFillBySpecificationFragment();
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationEnd(Result, AdditionalParameters) Export
    
    If Result = DialogReturnCode.No Then
        Return;
    EndIf;

	CommandToFillBySpecificationFragment();

EndProcedure

&AtClient
Procedure CommandToFillBySpecificationFragment()
    
    FillByBillsOfMaterialsAtServer();

EndProcedure

#EndRegion

#Region FormItemEventHandlersFormConsumerMaterials

&AtClient
Procedure ConsumerMaterialsProductsOnChange(Item)
	
	TabularSectionRow = Items.ConsumerMaterials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", ParentCompany);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);

	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormPaymentCalendar

&AtClient
Procedure PaymentCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	TotalAmount = Object.Inventory.Total("Amount") + Object.SalesTax.Total("Amount");
	TotalVATAmount = Object.Inventory.Total("VATAmount");
	
	If TotalAmount = 0 Then
		CurrentRow.PaymentPercentage = 0;
		CurrentRow.PaymentVATAmount = 0;
	Else
		CurrentRow.PaymentPercentage = Round(CurrentRow.PaymentAmount / TotalAmount * 100, 2, 1);
		CurrentRow.PaymentVATAmount = Round(TotalVATAmount * CurrentRow.PaymentAmount / TotalAmount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount = Round((Object.Inventory.Total("Amount") + Object.SalesTax.Total("Amount")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	TotalInventoryAmountOfVAT = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > TotalInventoryAmountOfVAT Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - TotalInventoryAmountOfVAT);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Clone)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If NewRow Then
		CurrentRow.PaymentBaselineDate = PredefinedValue("Enum.BaselineDateForPayment.PostingDate");
	EndIf;
	
	If CurrentRow.PaymentPercentage = 0 Then
		
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Object.Inventory.Total("Amount") + Object.SalesTax.Total("Amount") - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Inventory.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillRefreshEstimate(Item)
	
	SaveAndOpenEstimate();
	
EndProcedure

&AtClient
Procedure OpenEstimate(Item)
	
	SaveAndOpenEstimate();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormSalesTax

&AtClient
Procedure SalesTaxSalesTaxRateOnChange(Item)
	
	SalesTaxTabularRow = Items.SalesTax.CurrentData;
	
	If SalesTaxTabularRow <> Undefined And ValueIsFilled(SalesTaxTabularRow.SalesTaxRate) Then
		
		SalesTaxTabularRow.SalesTaxPercentage = GetSalesTaxPercentage(SalesTaxTabularRow.SalesTaxRate);
		
		CalculateSalesTaxAmount(SalesTaxTabularRow);
		
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SalesTaxSalesTaxPercentageOnChange(Item)
	
	SalesTaxTabularRow = Items.SalesTax.CurrentData;
	
	If SalesTaxTabularRow <> Undefined And ValueIsFilled(SalesTaxTabularRow.SalesTaxRate) Then
		
		CalculateSalesTaxAmount(SalesTaxTabularRow);
		
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SalesTaxAfterDeleteRow(Item)
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure SalesTaxAmountOnChange(Item)
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

#EndRegion

#Region FormCommandEvents

&AtClient
Procedure CloseOrder(Command)
	
	If Modified Or Not Object.Posted Then
		ShowQueryBox(New NotifyDescription("CloseOrderEnd", ThisObject),
			NStr("en = 'Cannot complete the order. The changes are not saved.
				|Click OK to save the changes.'; 
				|ru = 'Не удалось завершить заказ. Изменения не сохранены.
				|Нажмите ОК, чтобы сохранить изменения.';
				|pl = 'Nie można zakończyć zlecenia. Zmiany nie są zapisane.
				|Kliknij OK aby zapisać zmiany.';
				|es_ES = 'Ha ocurrido un error al finalizar el pedido. Los cambios no se han guardado.
				|Haga clic en OK para guardar los cambios.';
				|es_CO = 'Ha ocurrido un error al finalizar el pedido. Los cambios no se han guardado.
				|Haga clic en OK para guardar los cambios.';
				|tr = 'Sipariş tamamlanamıyor. Değişiklikler kaydedilmedi.
				|Değişiklikleri kaydetmek için Tamam''a tıklayın.';
				|it = 'Impossibile completare l''ordine. Le modifiche non sono salvate. 
				|Cliccare su OK per salvare le modifiche.';
				|de = 'Der Auftrag kann nicht abgeschlossen werden. Die Änderungen sind nicht gespeichert.
				|Um die Änderungen zu speichern, klicken Sie auf OK.'"), QuestionDialogMode.OKCancel);
		Return;
	EndIf;
		
	CloseOrderFragment();
	FormManagement();
	
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
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

// Gets the weight for tabular section row.
//
&AtClient
Procedure GetWeightForTabularSectionRow(TabularSectionRow)
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line to get the weight for.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, aby uzyskać wagę.';es_ES = 'Seleccionar una línea para obtener el peso para.';es_CO = 'Seleccionar una línea para obtener el peso para.';tr = 'Ağırlığı alınacak bir satır seçin.';it = 'Selezionare una linea per ottenere il peso.';de = 'Wählen Sie eine Linie aus, für die das Gewicht ermittelt werden soll.'"));
		
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
			MessageText = NStr("en = 'The electronic scale returned zero weight.'; ru = 'Электронные весы вернули нулевой вес.';pl = 'Waga elektroniczna zwróciła wagę zerową.';es_ES = 'Las escalas electrónicas han devuelto el peso cero.';es_CO = 'Las escalas electrónicas han devuelto el peso cero.';tr = 'Elektronik tartı sıfır ağırlık gösteriyor.';it = 'La bilancia elettronica ha dato peso pari a zero.';de = 'Die elektronische Waage gab Nullgewicht zurück.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine(TabularSectionRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	GetWeightForTabularSectionRow(TabularSectionRow);
	
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

&AtClient
Procedure EditInList(Command)
	
	If Items.EditInList.Check AND Object.PaymentCalendar.Count() > 1 Then
		
		NotifyDescription = New NotifyDescription("SetOptionEditInListCompleted", ThisObject);
		
		ShowQueryBox(
			NotifyDescription,
			NStr("en = 'All lines except the first one will be deleted. Do you want to continue?'; ru = 'Все строки кроме первой будут удалены. Продолжить?';pl = 'Wszystkie wiersze, oprócz pierwszego, zostaną usunięte. Czy chcesz kontynuować?';es_ES = 'Todas las líneas a excepción de la primera se borrarán. ¿Quiere continuar?';es_CO = 'Todas las líneas a excepción de la primera se borrarán. ¿Quiere continuar?';tr = 'İlki haricinde tüm satırlar silinecek. Devam etmek istiyor musunuz?';it = 'Tutte le linee tranne la prima verranno eliminate. Volete continuare?';de = 'Alle Zeilen außer der ersten werden gelöscht. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.YesNo
		);
		Return;
	EndIf;
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	FormManagement();
	
EndProcedure

&AtClient
Procedure DocumentSetup(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ShipmentDatePositionInSalesOrder", Object.ShipmentDatePosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingCompleted", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingCompleted(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.ShipmentDatePosition = StructureDocumentSetting.ShipmentDatePositionInSalesOrder;
		
		BeforeShipmentDateVisible = Items.ShipmentDate.Visible;
		
		FormManagement();
		
		If BeforeShipmentDateVisible = False // It was in TS.
			AND Items.ShipmentDate.Visible = True Then // It is in the header.
			
			DatesChangeProcessing();
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'There are no products to reserve.'; ru = 'Табличная часть ""Товары"" не заполнена!';pl = 'Brak produktów do rezerwy.';es_ES = 'No hay productos para reservar.';es_CO = 'No hay productos para reservar.';tr = 'Rezerve edilecek ürün yok.';it = 'Non ci sono articoli da riservare.';de = 'Es gibt keine Produkte zu reservieren.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByBalancesAtServer();
	
	// Bundles
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
EndProcedure

&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'There is nothing to clear.'; ru = 'Невозможно заполнить колонку ""Резерв"", потому что табличная часть ""Запасы и услуги"" не заполнена!';pl = 'Nie ma nic do wyczyszczenia.';es_ES = 'No hay nada para liquidar.';es_CO = 'No hay nada para liquidar.';tr = 'Temizlenecek bir şey yok.';it = 'Non c''è nulla da cancellare.';de = 'Es gibt nichts zu löschen.'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		
		If TabularSectionRow.ProductsTypeInventory Then
			TabularSectionRow.Reserve = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'The sales order will be repopulated from the base document. Continue?'; ru = 'Заказ покупателя будет повторно заполнен из документа-основания. Продолжить?';pl = 'Zamówienie sprzedaży zostanie ponownie wypełnione z dokumentu źródłowego. Kontynuować?';es_ES = 'El pedido de cliente se rellenará desde el documento base. ¿Continuar?';es_CO = 'El pedido de cliente se rellenará desde el documento base. ¿Continuar?';tr = 'Satış siparişi temel belgeden yeniden doldurulacak. Devam edilsin mi?';it = 'L''ordine cliente sarà ripopolato dal documento di base. Continuare?';de = 'Der Kundenauftrag wird aus dem Basisdokument neu automatisch aufgefüllt. Fortfahren?'"),
		QuestionDialogMode.YesNo,);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
		SetVisibleEnablePaymentTermItems();
	EndIf;

EndProcedure

&AtClient
Procedure UpdateCounterpartySegments(Command)

	ClearMessages();
	ExecutionResult = GenerateCounterpartySegmentsAtServer();
	If Not ExecutionResult.Status = "Completed" Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure FillSalesTax(Command)
	
	RecalculateSalesTax();
	
EndProcedure

&AtClient
Procedure SplitLine(Command)
	
	ItemForm  = Items.Inventory;
	TableDocument = Object.Inventory;
	
	AdditionalParameters = New Structure;
	
	DriveClient.SplitLineOfTable(
		TableDocument,
		ItemForm,
		New NotifyDescription("SplitLineEnd", ThisObject, AdditionalParameters));
		
EndProcedure

&AtClient
Procedure SplitLineEnd(NewLine, AdditionalParameters) Export
	
	If NewLine <> Undefined Then
		
		CalculateAmountInTabularSectionLine("Inventory", NewLine);
		InventoryQuantityOnChangeAtClient();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
	
	//InventoryAmount
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.DiscountMarkupPercent");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 100;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("MarkIncomplete", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryAmount");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Blank field formatting'; ru = 'Формат незаполненного поля';pl = 'Formatowanie pola puste';es_ES = 'Formateo del campo en blanco';es_CO = 'Formateo del campo en blanco';tr = 'Boş alan biçimlendirme';it = 'Formattazione del campo vuoto';de = 'Leere Feldformatierung'");
	
	//InventoryAmount
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.TotalDiscountAmountIsMoreThanAmount");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("MarkIncomplete", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryAmount");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Blank field formatting'; ru = 'Формат незаполненного поля';pl = 'Formatowanie pola puste';es_ES = 'Formateo del campo en blanco';es_CO = 'Formateo del campo en blanco';tr = 'Boş alan biçimlendirme';it = 'Formattazione del campo vuoto';de = 'Leere Feldformatierung'");
	
	//InventoryReserve
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.ProductsTypeInventory");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<For products>'; ru = '<Для номенклатуры>';pl = '<Dla produktów>';es_ES = '<Para los productos>';es_CO = '<Para los productos>';tr = '<Ürünler için>';it = '<Per articoli>';de = '<Für Produkte>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryReserve");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Availability of the Reserve column'; ru = 'Доступность колонки Резерв';pl = 'Dostępność kolumny Rezerwy';es_ES = 'Disponibilidad de la columna de Reserva';es_CO = 'Disponibilidad de la columna de Reserva';tr = 'Rezerv sütununun kullanılabilirliği';it = 'Disponibilità della colonna Riserva';de = 'Verfügbarkeit der Reservespalte'");
	
	//PerformersKTU
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Performers.EarningAndDeductionType");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Catalogs.EarningAndDeductionTypes.PieceRatePayFixedAmount;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<not considered>'; ru = '<не учитывается>';pl = '<nie uwzględniono>';es_ES = '<no se considera>';es_CO = '<no se considera>';tr = '<değerlendirilmedi>';it = '<non considerato>';de = '<nicht berücksichtigt>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	ItemAppearance.Appearance.SetParameterValue("Enabled", True);
	ItemAppearance.Appearance.SetParameterValue("Visible", True);
	ItemAppearance.Appearance.SetParameterValue("ReadOnly", True);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("PerformersKTU");
	FieldAppearance.Use = True;
	
	// Drop shipping
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.ProductsTypeInventory");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryDropShipping");
	FieldAppearance.Use = True;
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.DropShipping");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryReserve");
	FieldAppearance.Use = True;
	
EndProcedure

&AtClient
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	ContractData = DocumentParameters.ContractData;
	QueryPriceKind = DocumentParameters.QueryPriceKind;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	DiscountKindChanged = DocumentParameters.DiscountKindChanged;
	If DocumentParameters.Property("ClearDiscountCard") Then
		ClearDiscountCard = DocumentParameters.ClearDiscountCard;
	Else
		ClearDiscountCard = False;
	EndIf;
	RecalculationRequiredInventory	= DocumentParameters.RecalculationRequiredInventory;
	RecalculationRequiredWork		= DocumentParameters.RecalculationRequiredWork;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate	= ?(ContractData.SettlementsCurrencyRateRepetition.Rate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity	= ?(ContractData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		
	EndIf;
	
	If PriceKindChanged Then
		
		Object.PriceKind = ContractData.PriceKind;
		
	EndIf; 
	
	If DiscountKindChanged Then
		
		Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
		
	EndIf;
	
	If ClearDiscountCard Then
		
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;
		
	EndIf;
	
	If Object.DocumentCurrency <> ContractData.SettlementsCurrency Then
		
		Object.BankAccount = Undefined;
		
	EndIf;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If PriceKindChanged OR DiscountKindChanged Then
			
			WarningText = MessagesToUserClientServer.GetPriceTypeOnChangeWarningText();
			
		EndIf;
		
		WarningText = WarningText
			+ ?(IsBlankString(WarningText), "", Chars.LF + Chars.LF)
			+ MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, (PriceKindChanged Or DiscountKindChanged), WarningText);
		
	ElsIf QueryPriceKind Then
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
		If (RecalculationRequiredInventory AND Object.Inventory.Count() > 0)
			OR (RecalculationRequiredWork AND Object.Works.Count() > 0) Then
			
			QuestionText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. Recalculate the document according to the contract?'; ru = 'Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! Пересчитать документ в соответствии с договором?';pl = 'Cena i rabaty w umowie z kontrahentem różnią się od cen i rabatów w dokumencie! Przeliczyć dokument zgodnie z umową?';es_ES = 'El precio y descuento en el contrato con la contraparte es diferente del precio y descuento en el documento. ¿Recalcular el documento según el contrato?';es_CO = 'El precio y descuento en el contrato con la contraparte es diferente del precio y descuento en el documento. ¿Recalcular el documento según el contrato?';tr = 'Cari hesap ile yapılan sözleşmede yer alan fiyat ve indirim koşulları, belgedeki fiyat ve indirimden farklılık gösterir. Belge sözleşmeye göre yeniden hesaplansın mı?';it = 'Il prezzo e lo sconto nel contratto con la controparte differiscono dal prezzo e lo sconto nel documento. Ricalcolare il documento in base al contratto?';de = 'Preis und Rabatt im Vertrag mit dem Geschäftspartner unterscheiden sich von Preis und Rabatt im Beleg. Das Dokument gemäß dem Vertrag neu berechnen?'");
			
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);
	RecalculateSubtotal();
	
	// DiscountCards
	// IN this procedure call not modal window of question is occurred.
	RecalculateDiscountPercentAtDocumentDateChange();
	// End DiscountCards
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
	ClearEstimate();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange()
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If Object.DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	SetAccountingPolicyValues();
	
	DatesChangeProcessing();
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	FillSalesTaxRate();
	SetVisibleTaxAttributes();
	SetAutomaticVATCalculation();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataCompanyOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	FillSalesTaxRate();
	SetVisibleTaxAttributes();
	SetAutomaticVATCalculation();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined)
	
	If StructureData.Property("Characteristic")
		And ValueIsFilled(StructureData.Characteristic)
		And Common.ObjectAttributeValue(StructureData.Characteristic, "Owner") <> StructureData.Products Then
		
		StructureData.Characteristic = Catalogs.ProductsCharacteristics.EmptyRef();
		
	EndIf;
	
	If StructureData.Property("Batch")
		And ValueIsFilled(StructureData.Batch)
		And Common.ObjectAttributeValue(StructureData.Batch, "Owner") <> StructureData.Products Then
		
		StructureData.Batch = Catalogs.ProductsBatches.EmptyRef();
		
	EndIf;
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products,
		"MeasurementUnit, ProductsType, VATRate, ReplenishmentMethod, Description");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	StructureData.Insert("IsService", ProductsAttributes.ProductsType = PredefinedValue("Enum.ProductsTypes.Service"));
	StructureData.Insert("IsInventoryItem", ProductsAttributes.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	
	If StructureData.Property("TimeNorm") Then		
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products) And ValueIsFilled(ProductsAttributes.VATRate) Then
		StructureData.Insert("VATRate", ProductsAttributes.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("Taxable") Then
		StructureData.Insert("Taxable", StructureData.Products.Taxable);
	EndIf;
	
	If Not ObjectDate = Undefined Then
		
		Specification = Undefined;
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
			Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		EndIf;
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
			Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work
				And Not ValueIsFilled(Specification) Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		EndIf;
		StructureData.Insert("Specification", Specification);
		
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		EndIf;
		
		If StructureData.Property("WorkKind") Then
		
			StructureData.Products = StructureData.WorkKind;
			StructureData.Characteristic = Catalogs.ProductsCharacteristics.EmptyRef();
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
		Else
		
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
		
		EndIf;
		
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
	
	If StructureData.UseDefaultTypeOfAccounting And StructureData.Property("GLAccounts") Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData, True);
	// End Bundles
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate = Undefined)
	
	If StructureData.Property("PriceKind") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier")
			OR NOT ValueIsFilled(StructureData.MeasurementUnit) Then
				StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If Not ObjectDate = Undefined Then
		
		Specification = Undefined;
		
		ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "ProductsType, ReplenishmentMethod");
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
			Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		EndIf;
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
			Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work
				And Not ValueIsFilled(Specification) Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		EndIf;
		StructureData.Insert("Specification", Specification);
		
	EndIf;
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData, True);
	// End Bundles
	
	Return StructureData;
	
EndFunction

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

&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	FillVATRateByCompanyVATTaxation(, True);
	FillSalesTaxRate();
	
	StructureData = GetDataContractOnChange(
		Date,
		DocumentCurrency,
		ContractByDefault,
		Company,
		CounterpartyAttributes.DoOperationsByContracts);
	
	StructureData.Insert("Contract", ContractByDefault);
	StructureData.Insert("CallFromProcedureAtCounterpartyChange", True);
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDeliveryData(Counterparty)
	Return ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty, False);
EndFunction

&AtServer
Function GetDeliveryAttributes(ShippingAddress)
	Return ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
EndFunction

&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract, Company, DoOperationsByContracts)
	
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
		"PriceKind",
		Contract.PriceKind
	);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	If DoOperationsByContracts And ValueIsFilled(Contract) Then
		
		StructureData.Insert("ShippingAddress", Common.ObjectAttributeValue(Contract, "ShippingAddress"));
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure StructuralUnitReserveOnChangeAtServer()
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;

EndProcedure

&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsOpening = False, IsCounterpartyOnChange = False)
	
	If Not WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, False)
		Or Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT
		Or IsCounterpartyOnChange Then
		
		TaxationBeforeChange = Object.VATTaxation;
		
		Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty,
			DriveServer.VATTaxation(Object.Company, Object.Date),
			False);
		
		If Not TaxationBeforeChange = Object.VATTaxation Or IsOpening Then
			FillVATRateByVATTaxation(IsOpening);
		EndIf;
	
	EndIf;
	
EndProcedure

&AtServer
Procedure FillVATRateByVATTaxation(IsOpening = False)
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If Not IsOpening Then
			
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
			
			For Each TabularSectionRow In Object.Works Do
				
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
			
		EndIf;
		
	Else
		
		If Not IsOpening Then
			
			If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
				DefaultVATRate = Catalogs.VATRates.Exempt;
			Else
				DefaultVATRate = Catalogs.VATRates.ZeroRate;
			EndIf;
			
			For Each TabularSectionRow In Object.Inventory Do
			
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
				
				TabularSectionRow.Total = TabularSectionRow.Amount;
				
			EndDo;
			
			For Each TabularSectionRow In Object.Works Do
			
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
				
				TabularSectionRow.Total = TabularSectionRow.Amount;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	If Object.AmountIncludesVAT Then
		TabularSectionRow.VATAmount = TabularSectionRow.Amount - TabularSectionRow.Amount / ((VATRate + 100) / 100);
	Else
		TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
	EndIf;
											
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined, RecalcSalesTax = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
		
	// Amount.
	If TabularSectionName = "Works" Then
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Multiplicity * TabularSectionRow.Factor * TabularSectionRow.Price;
	Else
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf; 
		
	// Discounts.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	If RecalcSalesTax Then
		RecalculateSalesTax();
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurrencyRateRepetition = StructureData.CurrencyRateRepetition;
	SettlementsCurrencyRateRepetition = StructureData.SettlementsCurrencyRateRepetition;
	
	NewExchangeRate = ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
	NewRatio = ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
	
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
		
		QuestionText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate", NewExchangeRate);
		AdditionalParameters.Insert("NewRatio", NewRatio);
		AdditionalParameters.Insert("NewContractCurrencyExchangeRate", NewContractCurrencyExchangeRate);
		AdditionalParameters.Insert("NewContractCurrencyRatio", NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewExchangeRateettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",						ParentCompany);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("PriceKind",						Object.PriceKind);
	ParametersStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	
	If RegisteredForVAT Then
		ParametersStructure.Insert("AutomaticVATCalculation",	Object.AutomaticVATCalculation);
		ParametersStructure.Insert("PerInvoiceVATRoundingRule",	PerInvoiceVATRoundingRule);
		ParametersStructure.Insert("VATTaxation",				Object.VATTaxation);
		ParametersStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
		ParametersStructure.Insert("IncludeVATInPrice",			Object.IncludeVATInPrice);
	EndIf;
	
	If RegisteredForSalesTax Then
		ParametersStructure.Insert("SalesTaxRate",			Object.SalesTaxRate);
		ParametersStructure.Insert("SalesTaxPercentage",	Object.SalesTaxPercentage);
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForSale") Then
		ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
		ParametersStructure.Insert("WarningText", WarningText);
	EndIf;
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd",
		ThisObject,
		AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure RefillTabularSectionPricesByPriceKind() 
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",				ParentCompany);
	DataStructure.Insert("PriceKind",			Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	
	DataStructure.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	DataStructure.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	DataStructure.Insert("DiscountMarkupPercent", 0);
	
	If WorkKindInHeader Then
		
		For Each TSRow In Object.Works Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.Products) Then
				Continue;	
			EndIf; 
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("WorkKind",			Object.WorkKind);
			TabularSectionRow.Insert("Products",		TSRow.Products);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;
	
	Else
	
		For Each TSRow In Object.Works Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.WorkKind) Then
				Continue;	
			EndIf; 
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("WorkKind",			TSRow.WorkKind);
			TabularSectionRow.Insert("Products",		TSRow.Products);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;
	
	EndIf;
		
	GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);	
	
	For Each TSRow In DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("Products", TSRow.Products);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		
		SearchResult = Object.Works.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do				
			ResultRow.Price = TSRow.Price;
			CalculateAmountInTabularSectionLine("Works", ResultRow, False);
		EndDo;
		
	EndDo;
	
	For Each TabularSectionRow In Object.Works Do
		TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
		CalculateAmountInTabularSectionLine("Works", TabularSectionRow, False);
	EndDo;
	
	RecalculateSalesTax();
	
EndProcedure

&AtServerNoContext
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection)
	
	// Discounts.
	If DataStructure.Property("DiscountMarkupKind") 
		AND ValueIsFilled(DataStructure.DiscountMarkupKind) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupKind.Percent;
		
	EndIf;	
	
	// Discount card.
	If DataStructure.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(DataStructure.DiscountPercentByDiscountCard) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent + DataStructure.DiscountPercentByDiscountCard;
		
	EndIf;
		
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
	// Work kind.
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("WorkKind", TypeDescription);
	
	// Products.
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Products", TypeDescription);
	
	// FixedValue.
	Array.Add(Type("Boolean"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("FixedCost", TypeDescription);
	
	// Variant.
	Array.Add(Type("CatalogRef.ProductsCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Characteristic", TypeDescription);
	
	// VATRates.
	Array.Add(Type("CatalogRef.VATRates"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("VATRate", TypeDescription);	
	
	For Each TSRow In DocumentTabularSection Do
		
		NewRow = ProductsTable.Add();
		NewRow.WorkKind	 	 = TSRow.WorkKind;
		NewRow.FixedCost	 = False;
		NewRow.Products	 = TSRow.Products;
		NewRow.Characteristic	 = TSRow.Characteristic;
		If TypeOf(TSRow) = Type("Structure")
		   AND TSRow.Property("VATRate") Then
			NewRow.VATRate		 = TSRow.VATRate;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ProductsTable.WorkKind,
	|	ProductsTable.FixedCost,
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.VATRate
	|INTO TemporaryProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable";
	
	Query.SetParameter("ProductsTable", ProductsTable);
	Query.Execute();
	
	// 2. We will fill prices.
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;	
	EndIf;	
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = 
	"SELECT ALLOWED
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.VATRate AS VATRate,
	|	PricesSliceLast.PriceKind.PriceCurrency AS PricesCurrency,
	|	PricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(PricesSliceLast.Price * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|		END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	TemporaryProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON (CASE
	|				WHEN ProductsTable.FixedCost
	|					THEN ProductsTable.Products = PricesSliceLast.Products
	|				ELSE ProductsTable.WorkKind = PricesSliceLast.Products
	|			END)
	|			AND (CASE
	|				WHEN ProductsTable.FixedCost
	|					THEN ProductsTable.Characteristic = PricesSliceLast.Characteristic
	|				ELSE TRUE
	|			END)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON (PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&ProcessingDate,
	|			Currency = &DocumentCurrency
	|				AND Company = &Company) AS DocumentCurrencyRate";
		
	Query.SetParameter("ProcessingDate",	DataStructure.Date);
	Query.SetParameter("PriceKind",			PriceKindParameter);
	Query.SetParameter("DocumentCurrency", 	DataStructure.DocumentCurrency);
	Query.SetParameter("Company", 			DataStructure.Company);
	Query.SetParameter("ExchangeRateMethod",DriveServer.GetExchangeMethod(DataStructure.Company));

	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		If TypeOf(TSRow) = Type("Structure")
		   AND TabularSectionRow.Property("VATRate") Then
			SearchStructure.Insert("VATRate", TabularSectionRow.VATRate);
		EndIf;
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Dynamically calculate the price
				If DynamicPriceKind Then
					
					Price = Price * (1 + Markup / 100);
					
				EndIf;
				
				If DataStructure.Property("AmountIncludesVAT") 
				   AND ((DataStructure.AmountIncludesVAT AND Not SearchResult[0].PriceIncludesVAT) 
				   OR (NOT DataStructure.AmountIncludesVAT AND SearchResult[0].PriceIncludesVAT)) Then
					Price = DriveServer.RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, TabularSectionRow.VATRate);
				EndIf;
										
				TabularSectionRow.Price = DriveClientServer.RoundPrice(Price, Enums.RoundingMethods.Round0_01);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TempTablesManager.Close()
	
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
				StructureProductsData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			
			// DiscountCards
			StructureProductsData.Insert("DiscountPercentByDiscountCard", StructureData.DiscountPercentByDiscountCard);
			StructureProductsData.Insert("DiscountCard", StructureData.DiscountCard);
			// End DiscountCards
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "SalesOrder");
			EndIf;
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData, StructureData.Date));
			
			
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
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
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
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				
				NewRow.ProductsTypeInventory = BarcodeData.StructureProductsData.IsInventoryItem;
				
				// Bundles
				If BarcodeData.StructureProductsData.IsBundle Then
					ReplaceInventoryLineWithBundleData(ThisObject, NewRow, BarcodeData.StructureProductsData);
				Else
				// End Bundles
					CalculateAmountInTabularSectionLine( , NewRow);
					Items.Inventory.CurrentRow = NewRow.GetID();
				EndIf;
			Else
				
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine( , FoundString);
				Items.Inventory.CurrentRow = FoundString.GetID();
				
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
		
		MessageString = NStr("en = 'Barcode is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Kod kreskowy nie został znaleziony: %1%; ilość: %2%';es_ES = 'Código de barras no encontrado: %1%; cantidad: %2%';es_CO = 'Código de barras no encontrado: %1%; cantidad: %2%';tr = 'Barkod bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità:%2%';de = 'Barcode wird nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure
// End Peripherals

&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, OperationKind, Cancel)
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document, OperationKind);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND GetFunctionalOption("CheckContractsOnPosting") Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetContractChoiceFormParameters(Document, Company, Counterparty, Contract, DoOperationsByContracts, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationKind);
	
EndFunction

&AtServer
Procedure ProcessOperationKindChange()
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	
	For Each StringInventory In Object.Inventory Do
		StringInventory.Reserve = 0;
	EndDo;
	
EndProcedure

&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
		
	If ContractBeforeChange <> Object.Contract Then
		
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(
				Object.Date,
				Object.DocumentCurrency,
				Object.Contract,
				Object.Company,
				CounterpartyAttributes.DoOperationsByContracts);
			
		EndIf;
		
		If ContractData.Property("ShippingAddress") And ValueIsFilled(ContractData.ShippingAddress) Then
			
			If Object.ShippingAddress <> ContractData.ShippingAddress Then
				
				Object.ShippingAddress = ContractData.ShippingAddress;
				If Not ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
					ProcessShippingAddressChange();
				EndIf;
				
			EndIf;
			
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		DiscountKindChanged = (Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind);
		If ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
			ClearDiscountCard = ValueIsFilled(Object.DiscountCard); // Attribute DiscountCard will be cleared later.
		Else
			ClearDiscountCard = False;
		EndIf;
		
		QueryPriceKind = (ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged));
		
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
			AND ValueIsFilled(SettlementsCurrency)
			AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("DiscountKindChanged", DiscountKindChanged);
		DocumentParameters.Insert("ClearDiscountCard", ClearDiscountCard);
		DocumentParameters.Insert("RecalculationRequiredInventory", Object.Inventory.Count() > 0);
		DocumentParameters.Insert("RecalculationRequiredWork", False);
		
		ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForSale") Then
			FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			SetVisibleEnablePaymentTermItems();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessShippingAddressChange()
	
	DeliveryData = GetDeliveryAttributes(Object.ShippingAddress);
	
	FillPropertyValues(Object, DeliveryData,,"SalesRep");
	If ValueIsFilled(DeliveryData.SalesRep) Then
		Object.SalesRep = DeliveryData.SalesRep;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		Modified = True;
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			
			Object.BankAccount = Undefined;
			
		EndIf;
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Not Object.Counterparty.IsEmpty() Then
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
				Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			Else // We will show the message and we will not change discount card data.
				CommonClientServer.MessageToUser(
				DiscountCardsClient.GetDiscountCardInapplicableMessage(),
				,
				"Counterparty",
				"Object");
			EndIf;
		ElsIf ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Object.Counterparty.IsEmpty() Then
			Object.Counterparty = ClosingResult.Counterparty;
			CounterpartyOnChange(Items.Counterparty); // Discount card data is cleared in this procedure.
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			
			ShowUserNotification(
				NStr("en = 'Customer is filled and discount card is read.'; ru = 'Заполнен контрагент и считана дисконтная карта.';pl = 'Klient wypełniony, karta rabatowa sczytana.';es_ES = 'Cliente se ha rellenado y la tarjeta de descuento se ha leído.';es_CO = 'Cliente se ha rellenado y la tarjeta de descuento se ha leído.';tr = 'Müşteri dolduruldu ve indirim kartı okundu.';it = 'Il Cliente è stata compilato e la carta sconto è stata letta';de = 'Die Kundendaten wurden ausgefüllt und die Rabattkarte wurde gelesen.'"),
				GetURL(Object.DiscountCard),
				StringFunctionsClientServer.SubstituteParametersToString(
				    NStr("en = 'The customer is filled and discount card %1 is read.'; ru = 'В документе заполнен контрагент и считана дисконтная карта %1.';pl = 'Klient jest wypełniony, karta rabatowa %1 sczytana.';es_ES = 'El cliente se ha rellenado y la tarjeta de descuento %1 se ha leído.';es_CO = 'El cliente se ha rellenado y la tarjeta de descuento %1 se ha leído.';tr = 'Müşteri dolduruldu ve indirim kartı %1 okundu.';it = 'Il Cliente è stata compilato e la carta sconto %1 è stata letta';de = 'Die Kundendaten wurden ausgefüllt und die Rabattkarte %1 wurde gelesen.'"),
					Object.DiscountCard),
				PictureLib.Information32);
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		EndIf;
		// End DiscountCards
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", ClosingResult.DocumentCurrency);
		DocCurRecalcStructure.Insert("Rate", ClosingResult.ExchangeRate);
		DocCurRecalcStructure.Insert("Repetition", ClosingResult.Multiplicity);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrency);
		DocCurRecalcStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		DocCurRecalcStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.ExchangeRate;
		Object.Multiplicity = ClosingResult.Multiplicity;
		Object.ContractCurrencyExchangeRate = ClosingResult.SettlementsRate;
		Object.ContractCurrencyMultiplicity = ClosingResult.SettlementsMultiplicity;
		
		// VAT
		If RegisteredForVAT Then
			
			Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
			Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
			Object.VATTaxation = ClosingResult.VATTaxation;
			Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
			
			// Recalculate the amount if VAT taxation flag is changed.
			If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
				
				FillVATRateByVATTaxation();
				
			EndIf;
			
		EndIf;
		
		// Sales tax.
		If RegisteredForSalesTax Then
			
			Object.SalesTaxRate = ClosingResult.SalesTaxRate;
			Object.SalesTaxPercentage = ClosingResult.SalesTaxPercentage;
			
			If ClosingResult.SalesTaxRate <> ClosingResult.PrevSalesTaxRate
				Or ClosingResult.SalesTaxPercentage <> ClosingResult.PrevSalesTaxPercentage Then
				
				RecalculateSalesTax();
				
			EndIf;
			
		EndIf;
		
		SetVisibleTaxAttributes();
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory", PricesPrecision);
			
		EndIf;
		
		// DiscountCards
		If ClosingResult.RefillDiscounts AND Not ClosingResult.RefillPrices Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
		// End DiscountCards
		
		// Generate price and currency label.
		GenerateLabelPricesAndCurrency(ThisObject);
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
		
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
	
	EndIf;
		
EndProcedure

&AtClient
Procedure DefineNewExchangeRateettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ContractData = AdditionalParameters.ContractData;
		
		If AdditionalParameters.RecalculationRequiredInventory Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			
		EndIf;
		
		If AdditionalParameters.RecalculationRequiredWork Then
			
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, SalesRep, DefaultDeliveryOption, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtClient
Procedure SetOptionEditInListCompleted(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	While Object.PaymentCalendar.Count() > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar.Count()-1);
	EndDo;
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	FormManagement();
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	VisibleFlags = GetFlagsForFormItemsVisible(Object.ShipmentDatePosition, Object.OperationKind, Object.DeliveryOption);
	
	ShipmentDateInHeader	= VisibleFlags.ShipmentDateInHeader;
	IsOrderForProcessing	= VisibleFlags.IsOrderForProcessing;
	OrderSaved				= Not Object.Ref.IsEmpty();
	DeliveryOptionIsFilled	= ValueIsFilled(Object.DeliveryOption);
	
	Items.ShipmentDate.Visible						= ShipmentDateInHeader;
	Items.InventoryShipmentDate.Visible				= Not ShipmentDateInHeader;
	Items.Contract.Visible							= CounterpartyAttributes.DoOperationsByContracts;
	Items.InventoryCommandsChangeReserve.Visible	= Not IsOrderForProcessing;
	Items.InventoryReserve.Visible					= Not IsOrderForProcessing;
	Items.InventoryProject.Visible					= Not IsOrderForProcessing;
	Items.PageConsumerMaterials.Visible				= IsOrderForProcessing;
	Items.InventoryBatch.Visible					= Not IsOrderForProcessing AND ThisObject.InventoryReservation;
	Items.FillRefreshEstimate.Visible				= Not Object.EstimateIsCalculated AND Not ReadOnly;
	Items.OpenEstimate.Visible						= Object.EstimateIsCalculated;
	Items.GroupPaymentCalendar.Visible				= VisibleFlags.OperationKindOrderForSale;
	Items.LogisticsCompany.Visible					= DeliveryOptionIsFilled AND VisibleFlags.DeliveryOptionLogisticsCompany;
	Items.ShippingAddress.Visible					= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.ContactPerson.Visible						= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.GoodsMarking.Visible						= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeFrom.Visible					= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeTo.Visible					= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.Incoterms.Visible							= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	
	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	If GetAccessRightForDocumentPosting() Then
		Items.FormPost.Enabled			= Not StatusIsComplete Or Not Object.Closed;
		Items.FormPostAndClose.Enabled	= Not StatusIsComplete Or Not Object.Closed;
	EndIf;
	
	Items.FormWrite.Enabled 				= Not StatusIsComplete Or Not Object.Closed;
	Items.FormCreateBasedOn.Enabled 		= Not StatusIsComplete Or Not Object.Closed;
	Items.CloseOrder.Visible				= Not Object.Closed;
	Items.CloseOrderStatus.Visible			= Not Object.Closed;
	CloseOrderEnabled 						= DriveServer.CheckCloseOrderEnabled(Object.Ref);
	Items.CloseOrder.Enabled				= CloseOrderEnabled;
	Items.CloseOrderStatus.Enabled			= CloseOrderEnabled;
	Items.InventoryCommandBar.Enabled		= Not StatusIsComplete;
	Items.FillByBasis.Enabled				= Not StatusIsComplete;
	Items.PricesAndCurrency.Enabled			= Not StatusIsComplete;
	Items.FillRefreshEstimate.Enabled		= Not StatusIsComplete;
	Items.ReadDiscountCard.Enabled			= Not StatusIsComplete;
	Items.Counterparty.ReadOnly				= StatusIsComplete;
	Items.Contract.ReadOnly					= StatusIsComplete;
	Items.BasisDocument.ReadOnly			= StatusIsComplete;
	Items.ShippingGroup.ReadOnly			= StatusIsComplete;
	Items.HeaderRight.ReadOnly				= StatusIsComplete;
	Items.Pages.ReadOnly					= StatusIsComplete;
	Items.Footer.ReadOnly					= StatusIsComplete;

	Items.OrderState.DropListButton = True;
	
	FillProjectChoiceParameters();
	
EndProcedure

&AtServerNoContext
Function GetAccessRightForDocumentPosting()
	
	Return AccessRight("Posting", Metadata.Documents.SalesOrder);
	
EndFunction

&AtServerNoContext
Function GetFlagsForFormItemsVisible(ShipmentDatePosition, OperationKind, DeliveryOption)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("ShipmentDateInHeader", (ShipmentDatePosition = Enums.AttributeStationing.InHeader));
	VisibleFlags.Insert("IsOrderForProcessing", (OperationKind = Enums.OperationTypesSalesOrder.OrderForProcessing));
	VisibleFlags.Insert("OperationKindOrderForSale", (OperationKind = Enums.OperationTypesSalesOrder.OrderForSale));
	VisibleFlags.Insert("DeliveryOptionLogisticsCompany", (DeliveryOption = Enums.DeliveryOptions.LogisticsCompany));
	VisibleFlags.Insert("DeliveryOptionSelfPickup", (DeliveryOption = Enums.DeliveryOptions.SelfPickup));
	
	Return VisibleFlags;
	
EndFunction

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForSalesTax = AccountingPolicy.RegisteredForSalesTax;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure RecalculateSubtotal()
	Totals = DriveServer.CalculateSubtotal(Object.Inventory.Unload(), Object.AmountIncludesVAT, Object.SalesTax.Unload());
	
	If Not Object.ForOpeningBalancesOnly
		Or Object.Inventory.Count() > 0 Then
		
		FillPropertyValues(ThisObject, Totals);
		FillPropertyValues(Object, Totals);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesBillsOfMaterialstack = New Array;
	Document.FillTabularSectionBySpecification(NodesBillsOfMaterialStack);
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillProjectChoiceParameters()
	
	FilterCounterparty = New Array;
	FilterCounterparty.Add(PredefinedValue("Catalog.Counterparties.EmptyRef"));
	FilterCounterparty.Add(Object.Counterparty);
	
	NewParameter = New ChoiceParameter("Filter.Counterparty", New FixedArray(FilterCounterparty));
	
	ProjectChoiceParameters = New Array;
	ProjectChoiceParameters.Add(NewParameter);
	
	Items.Project.ChoiceParameters = New FixedArray(ProjectChoiceParameters);
	
EndProcedure

&AtServer
Procedure ResetStatus()
	
	If Not GetFunctionalOption("UseSalesOrderStatuses") Then
		
		OrderStatus = Common.ObjectAttributeValue(Object.OrderState, "OrderStatus");
		
		If OrderStatus = Enums.OrderStatuses.InProcess And Not Object.Closed Then
			Status = "StatusInProcess";
		ElsIf OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "StatusCompleted";
		Else
			Status = "StatusCanceled";
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	
	Return Fields;
	
EndFunction

#Region AdditionalInformationPanel

&AtServer
Procedure ReadAdditionalInformationPanelData()
	
	AdditionalInformationPanel.ReadAdditionalInformationPanelData(ThisObject, Counterparty);
	
EndProcedure

#EndRegion

#EndRegion

#Region WorkWithPick

&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'sales order'; ru = 'заказ покупателя';pl = 'zamówienie sprzedaży';es_ES = 'orden de ventas';es_CO = 'orden de ventas';tr = 'satış siparişi';it = 'ordine cliente';de = 'Kundenauftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True, True);
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForProcessing") Then
		SelectionParameters.Insert("DiscountsMarkupsVisible", False);
	EndIf;
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

&AtClient
Procedure MaterialsPick(Command)
	
	TabularSectionName	= "ConsumerMaterials";
	SelectionMarker		= "Materials";
	DocumentPresentaion	= NStr("en = 'sales order'; ru = 'заказ покупателя';pl = 'zamówienie sprzedaży';es_ES = 'orden de ventas';es_CO = 'orden de ventas';tr = 'satış siparişi';it = 'ordine cliente';de = 'Kundenauftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, True);
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForProcessing") Then
		SelectionParameters.Insert("DiscountsMarkupsVisible", False);
	EndIf;
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

&AtClient
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogClient.AddMessageForEventLog("Error", , EventLogMonitorErrorText);
		
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	If Not (TypeOf(TableForImport) = Type("ValueTable")
		OR TypeOf(TableForImport) = Type("Array")) Then
		
		ErrorText = NStr("en = 'Data type in the temporary storage is mismatching the expected data for the document.
					|Storage address: %1. Tabular section name: %2'; 
					|ru = 'Данные во временном хранилище не совпадают с ожидаемыми данными для данного документа.
					|Адрес хранилища: %1. Табличная часть: %2';
					|pl = 'Typ danych w repozytorium tymczasowej pamięci jest niezgodny z oczekiwanymi danymi dla dokumentu.
					|Adres pamięci: %1. Nazwa sekcji tabelarycznej: %2';
					|es_ES = 'El tipo de datos en el almacenamiento temporal no coincide con los datos estimados para el documento.
					|La dirección del almacenamiento: %1. El nombre de la sección tabular: %2';
					|es_CO = 'El tipo de datos en el almacenamiento temporal no coincide con los datos estimados para el documento.
					|La dirección del almacenamiento: %1. El nombre de la sección tabular: %2';
					|tr = 'Geçici depolamadaki veri türü, doküman için beklenen verilerle uyuşmuyor.
					| Depolama adresi: %1. Tablo bölüm adı: %2';
					|it = 'Il tipo di dati nell''archivio temporaneo non corrisponde ai dati attesi per il documento.
					|Indirizzo di immagazzinamento: %1. Nome sezione tabellare: %2';
					|de = 'Der Datentyp im Zwischenspeicher stimmt nicht mit den erwarteten Daten für das Dokument überein.
					|Speicheradresse: %1. Tabellarischer Abschnittsname: %2'");

		EventLogMonitorErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
			InventoryAddressInStorage,
			TabularSectionName);
		
		Return;
		
	Else
		
		EventLogMonitorErrorText = "";
		
	EndIf;
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, "StructuralUnitReserve");
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If NewRow.Property("Total")
			AND Not ValueIsFilled(NewRow.Total) Then
			
			NewRow.Total = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
			
		EndIf;
		
		// Refilling
		If TabularSectionName = "Works" Then
			
			NewRow.ConnectionKey = DriveServer.CreateNewLinkKey(ThisForm);
			
			If ValueIsFilled(ImportRow.Products) Then
				
				NewRow.ProductsTypeService = (ImportRow.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.Service"));
				
			EndIf;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
			
			If UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
			EndIf;
			
			If ValueIsFilled(ImportRow.Products) Then
				
				NewRow.ProductsTypeInventory = (ImportRow.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
				
			EndIf;
			
			// Bundles
			If ImportRow.IsBundle Then
				
				StructureData = New Structure();
				
				StructureData.Insert("Company", 						Object.Company);
				StructureData.Insert("ProcessingDate",					Object.Date);
				StructureData.Insert("PriceKind",						Object.PriceKind);
				StructureData.Insert("DocumentCurrency",				Object.DocumentCurrency);
				StructureData.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
				StructureData.Insert("Products",						NewRow.Products);
				StructureData.Insert("Characteristic",					NewRow.Characteristic);
				StructureData.Insert("Factor",							1);
				StructureData.Insert("VATTaxation",						Object.VATTaxation);
				StructureData.Insert("DiscountMarkupKind",				Object.DiscountMarkupKind);
				StructureData.Insert("DiscountCard",					Object.DiscountCard);
				StructureData.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
				StructureData.Insert("UseDefaultTypeOfAccounting",		UseDefaultTypeOfAccounting);
				
				AddTabRowDataToStructure(ThisObject, "Inventory", StructureData, NewRow);
				StructureData = GetDataProductsOnChange(StructureData);
				
				ReplaceInventoryLineWithBundleData(ThisObject, NewRow, StructureData);
				
			EndIf;
			// End Bundles
			
		EndIf;
		
		If NewRow.Property("Specification") Then 
			
			Specification = Undefined;
			
			ProductsAttributes = Common.ObjectAttributesValues(ImportRow.Products, "ProductsType, ReplenishmentMethod");
			If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
				Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work Then
				Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(ImportRow.Products,
					Object.Date, 
					ImportRow.Characteristic,
					Enums.OperationTypesProductionOrder.Assembly);
			EndIf;
			If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
				Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work
					And Not ValueIsFilled(Specification) Then
				Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(ImportRow.Products,
					Object.Date, 
					ImportRow.Characteristic,
					Enums.OperationTypesProductionOrder.Production);
			EndIf;
			
			NewRow.Specification = Specification;
			
		EndIf;
		
	EndDo;
	
	If UseDefaultTypeOfAccounting Then
		
		Document = FormAttributeToValue("Object");
		GLAccountsInDocuments.FillGLAccountsInDocument(Document);
		ValueToFormAttribute(Document, "Object");
		
		FillAddedColumns();
		
	EndIf;

	// Bundles
	RefreshBundlePictures(Object.Inventory);
	// End Bundles
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			AreCharacteristics 			= True;
			
			AreBatches			= False;
			
			If SelectionMarker = "Inventory" Then
				
				TabularSectionName	= "Inventory";
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
				If Not IsBlankString(EventLogMonitorErrorText) Then
					WriteErrorReadingDataFromStorage();
				EndIf;
				
				RecalculateSalesTax();
				PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
				RecalculateSubtotal();
				ClearEstimate();
				
			ElsIf SelectionMarker = "Materials" Then
				
				TabularSectionName	= "ConsumerMaterials";
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
			EndIf;
			
			SelectionMarker = "";
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
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			AreCharacteristics 			= True;
			
			AreBatches			= False;
			
			If SelectionMarker = "Inventory" Then
				
				TabularSectionName	= "Inventory";
				
				// Clear inventory
				Filter = New Structure;
				Filter.Insert("Products", ClosingResult.FilterProducts);
				Filter.Insert("IsBundle", False);
				
				RowsToDelete = Object[TabularSectionName].FindRows(Filter);
				For Each RowToDelete In RowsToDelete Do
					Object[TabularSectionName].Delete(RowToDelete);
				EndDo;
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
				RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
				For Each RowToRecalculate In RowsToRecalculate Do
					CalculateAmountInTabularSectionLine(TabularSectionName, RowToRecalculate, False);
				EndDo;
				
				If Not IsBlankString(EventLogMonitorErrorText) Then
					WriteErrorReadingDataFromStorage();
				EndIf;
				
				RecalculateSalesTax();
				PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
				RecalculateSubtotal();
				ClearEstimate();
				
			EndIf;
			
			SelectionMarker = "";
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

// Procedure - selection handler of discount card, beginning.
//
&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	DiscountCardOwner = GetDiscountCardOwner(DiscountCard);
	If Object.Counterparty.IsEmpty() AND Not DiscountCardOwner.IsEmpty() Then
		Object.Counterparty = DiscountCardOwner;
		CounterpartyOnChange(Items.Counterparty);
		
		ShowUserNotification(
			NStr("en = 'Customer is filled and discount card is read'; ru = 'Заполнен контрагент и считана дисконтная карта';pl = 'Klient wypełniony, karta rabatowa sczytana';es_ES = 'Cliente se ha rellenado y la tarjeta de descuento se ha leído';es_CO = 'Cliente se ha rellenado y la tarjeta de descuento se ha leído';tr = 'Müşteri dolduruldu ve indirim kartı okundu';it = 'Il Cliente è stato compilato e la carta sconto è stata letta';de = 'Die Kundendaten wurden ausgefüllt und die Rabattkarte wurde gelesen'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The customer is filled and discount card %1 is read'; ru = 'В документе заполнен контрагент и считана дисконтная карта %1';pl = 'Klient jest wypełniony, karta rabatowa %1 sczytana.';es_ES = 'El cliente se ha rellenado y la tarjeta de descuento %1 se ha leído';es_CO = 'El cliente se ha rellenado y la tarjeta de descuento %1 se ha leído';tr = 'Müşteri dolduruldu ve %1 indirim kartı okundu';it = 'Il Cliente è stato compilato e la carta sconto %1 è stata letta';de = 'Die Kundendaten wurden ausgefüllt und die Rabattkarte %1 wurde gelesen'"), DiscountCard),
			PictureLib.Information32);
	ElsIf Object.Counterparty <> DiscountCardOwner AND Not DiscountCardOwner.IsEmpty() Then
		
		CommonClientServer.MessageToUser(
			DiscountCardsClient.GetDiscountCardInapplicableMessage(),
			,
			"Counterparty",
			"Object");
		
		Return;
	Else
		ShowUserNotification(
			NStr("en = 'Discount card is read'; ru = 'Считана дисконтная карта';pl = 'Karta rabatowa została sczytana';es_ES = 'Tarjeta de descuento se ha leído';es_CO = 'Tarjeta de descuento se ha leído';tr = 'İndirim kartı okundu';it = 'La carta sconto è stata letta';de = 'Rabattkarte wird gelesen'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Discount card %1 is read'; ru = 'Считана дисконтная карта %1';pl = 'Karta rabatowa %1 została sczytana';es_ES = 'Tarjeta de descuento %1 se ha leído';es_CO = 'Tarjeta de descuento %1 se ha leído';tr = 'İndirim kartı %1 okundu';it = 'Letta Carta sconti %1';de = 'Rabattkarte %1 wird gelesen'"), DiscountCard),
			PictureLib.Information32);
	EndIf;
	
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
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en = 'Should we recalculate discounts in all lines?'; ru = 'Перезаполнить скидки во всех строках?';pl = 'Czy powinniśmy obliczyć zniżki we wszystkich wierszach?';es_ES = '¿Hay que recalcular los descuentos en todas las líneas?';es_CO = '¿Hay que recalcular los descuentos en todas las líneas?';tr = 'Tüm satırlarda indirimler yeniden hesaplansın mı?';it = 'Dobbiamo ricalcolare gli sconti in tutte le linee?';de = 'Sollten wir Rabatte in allen Zeilen neu berechnen?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	ClearEstimate();
	
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
		
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
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
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
			
			RecalculateSalesTax();
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
		EndIf;
				
	EndIf;
	
EndProcedure

// Function returns the discount card owner.
//
&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
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
	ClearEstimate();
	
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
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
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
	
	RecalculateSubtotal();
	
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
		
		If TypeOf(ThisObject.CurrentItem) = Type("FormTable")
			And ThisObject.CurrentItem.Name = "Inventory" Then
			
			HandlerParameters = New Structure;
			HandlerParameters.Insert("Action", Action);
			HandlerParameters.Insert("SPColumn", SPColumn);
			AttachIdleHandler("HandlerResetFlagDiscountsAreCalculated", 0.1, True);
			
		Else
			
			RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
			
		EndIf;
		
	EndIf;
	
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
	
EndFunction

&AtClient
Procedure HandlerResetFlagDiscountsAreCalculated() Export 
	
	NeedRefocus = False;
	
	If TypeOf(ThisObject.CurrentItem) = Type("FormTable")
		And ThisObject.CurrentItem.Name = "Inventory"
		And TypeOf(ThisObject.CurrentItem.CurrentItem) = Type("FormField") Then
		NeedRefocus = True;
	EndIf;
	
	RecalculationIsRequired = ResetFlagDiscountsAreCalculated(HandlerParameters.Action, HandlerParameters.SPColumn);
	
	If NeedRefocus And Items.Inventory.CurrentRow <> Undefined Then
		Items.Inventory.ChangeRow();
	EndIf;
	
EndProcedure


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

#EndRegion

#Region Estimate

&AtClient
Procedure SaveAndOpenEstimate()
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operators workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	If Modified Or Object.Ref.IsEmpty() Then
		
		Notification = New NotifyDescription("SaveAndOpenEstimateCompletion", ThisObject);
		ShowQueryBox(Notification, 
			NStr("en = 'For profit estimation, the sales order will be saved. 
			|Do you want to continue?'; 
			|ru = 'Для оценки прибыли заказ покупателя будет сохранен. 
			|Продолжить?';
			|pl = 'Dla oszacowania zysku, zamówienie sprzedaży zostanie zapisane. 
			|Czy chcesz kontynuować?';
			|es_ES = 'Para estimar las ganancias, se guardará la orden de venta. 
			|¿Quiere continuar?';
			|es_CO = 'Para estimar las ganancias, se guardará la orden de venta. 
			|¿Quiere continuar?';
			|tr = 'Kar tahmini için satış siparişi kaydedilecek. 
			|Devam etmek istiyor musunuz?';
			|it = 'Per una stima dell''utile, l''ordine cliente verrà salvato. 
			|Continuare?';
			|de = 'Zur Gewinnschätzung wird der Kundenauftrag gespeichert. 
			|Möchten Sie fortsetzen?'"),
			QuestionDialogMode.OKCancel);
		Return;
		
	EndIf;
	
	ParameterStructure = New Structure;
	FillEstimateOpenParameters(ParameterStructure);
	Notification = New NotifyDescription("OnChangeEstimate", ThisObject);
	OpenForm("Document.SalesOrder.Form.EstimateForm", ParameterStructure, ThisObject, UUID,,, Notification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SaveAndOpenEstimateCompletion(Answer, AdditionalData) Export
	
	If Answer = DialogReturnCode.OK Then
		Write();
		If Object.Ref.IsEmpty() Or Modified Then
			Return; // Failed to write, the platform shows the error message.
		EndIf;
		SaveAndOpenEstimate();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeEstimate(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult = Undefined Then
		Return;
	EndIf;
	
	If Not ReadOnly AND OpeningResult.Property("DataAddress") Then
		OnChangeEstimateServer(OpeningResult.DataAddress);
		FormManagement();
	EndIf;
	
	If OpeningResult.Property("Print")
		AND OpeningResult.Print = True Then
			Command = Commands.Estimate;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearEstimate()
	
	If Not Object.EstimateIsCalculated Then
		Return;
	EndIf; 
	
	Object.EstimateIsCalculated = False;
	
	// Delete all not common estimate rows
	FilterStructure = New Structure;
	FilterStructure.Insert("Source", PredefinedValue("Enum.EstimateRowsSources.InventoryItem"));
	StringsToDelete = Object.Estimate.FindRows(FilterStructure);
	
	For Each Str In StringsToDelete Do
		Object.Estimate.Delete(Str);
	EndDo;
	
	Items.FillRefreshEstimate.Visible = Not Object.EstimateIsCalculated;
	Items.OpenEstimate.Visible = Object.EstimateIsCalculated;
	
EndProcedure

&AtServer
Function FillEstimateOpenParameters(ParameterStructure)
	
	For Each TabularSectionRow In Object.Inventory Do
		If Not ValueIsFilled(TabularSectionRow.ConnectionKey) Then
			DriveClientServer.FillConnectionKey(Object.Inventory, TabularSectionRow, "ConnectionKey");
		EndIf;
	EndDo;
	
	IsComplete = (Object.OrderState = CompletedStatus);
	
	DataStructure = New Structure;
	DataStructure.Insert("Ref",			Object.Ref);
	DataStructure.Insert("ReadOnly",	?(IsComplete, IsComplete, ReadOnly));
	
	DataOrder = New Structure;
	DataOrder.Insert("Date",	Object.Date);
	DataOrder.Insert("Number",	Object.Number);
	
	For Each Attribute In Metadata.Documents.SalesOrder.Attributes Do
		DataOrder.Insert(Attribute.Name, Object[Attribute.Name]);
	EndDo;
	
	DataStructure.Insert("DataOrder",	DataOrder);
	DataStructure.Insert("Company",		Object.Company);
	DataStructure.Insert("PriceTypes",	Object.EstimatePriceTypes.Unload().UnloadColumn("PriceKind"));
	
	InventoryTable = Object.Inventory.Unload();
	DataStructure.Insert("Inventory",	InventoryTable);
	
	EstimateTable = Object.Estimate.Unload();
	DataStructure.Insert("Estimate",	EstimateTable);
	
	ParameterStructure.Insert("DataAddress", PutToTempStorage(DataStructure, UUID));
	
EndFunction

&AtServer
Procedure OnChangeEstimateServer(SettingsAddress)
	
	If Not IsTempStorageURL(SettingsAddress) Then
		Return;
	EndIf;
	
	Modified = True;
	
	DataStructure = GetFromTempStorage(SettingsAddress);
	Object.Estimate.Load(DataStructure.Estimate);
	
	Object.Inventory.Clear();
	
	For Each EstimateRow In DataStructure.Inventory Do
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, EstimateRow);
	EndDo;
	
	Object.EstimatePriceTypes.Clear();
	
	For Each PriceKind In DataStructure.PriceTypes Do
		Object.EstimatePriceTypes.Add().PriceKind = PriceKind;
	EndDo;
	
	FillPropertyValues(Object, DataStructure, "EstimateCostPriceCalculationMethod, EstimateTemplate, EstimateComment");
	Object.EstimateIsCalculated = True;
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(False);
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"SalesOrder.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	DataLoadSettings.Insert("DatePositionInOrder",		Object.ShipmentDatePosition);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		ClearEstimate();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSources

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

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_FillBatchesByFEFO_Selected()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_Selected(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_All()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_All(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_BatchOnChange(TableName) Export
	
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_QuantityOnChange(TableName, RowData) Export
	
	InventoryQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Function Attachable_FillByFEFOData(TableName, ShowMessages) Export
	
	Return FillByFEFOData(ShowMessages);
	
EndFunction

&AtServer
Function FillByFEFOData(ShowMessages)
	
	Params = New Structure;
	Params.Insert("CurrentRow", Object.Inventory.FindByID(Items.Inventory.CurrentRow));
	Params.Insert("StructuralUnit", Object.StructuralUnitReserve);
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	Params.Insert("Cell", Object.Cell);
	Params.Insert("OwnershipType", Undefined);
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

&AtClient
Procedure InventoryQuantityOnChangeAtClient()
	
	CalculateAmountInTabularSectionLine();
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure ClearPaymentCalendarContinue(Answer, Parameters) Export
	If Answer = DialogReturnCode.Yes Then
		Object.PaymentCalendar.Clear();
		SetEnableGroupPaymentCalendarDetails();
	ElsIf Answer = DialogReturnCode.No Then
		Object.SetPaymentTerms = True;
	EndIf;
EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	SetVisibleTaxAttributes();
	
	SetSwitchTypeListOfPaymentCalendar();
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
EndProcedure

&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
EndProcedure

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentMethod()
	
	If Object.CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = True;
	ElsIf Object.CashAssetType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		Items.BankAccount.Visible = True;
		Items.PettyCash.Visible = False;
	Else
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = False;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarAsList;
	Else
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarWithoutSplitting;
	EndIf;
	
EndProcedure

&AtServer
Procedure DatesChangeProcessing()
	
	If Object.ShipmentDatePosition = Enums.AttributeStationing.InTabularSection Then
		Object.ShipmentDate = DriveServer.ColumnMin(Object.Inventory.Unload(), "ShipmentDate");
	EndIf;
	
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
	
EndProcedure

&AtServer
Procedure FillPaymentCalendar(TypeListOfPaymentCalendar, IsEnabledManually = False, CopyingValue = Undefined)
	
	If CopyingValue <> Undefined Then
		PaymentCalendarCopy = Object.PaymentCalendar.Unload();
		Object.PaymentCalendar.Clear();
	EndIf;
		
	PaymentTermsServer.FillPaymentCalendarFromContract(Object, IsEnabledManually);
	
	TypeListOfPaymentCalendar = Number(Object.PaymentCalendar.Count() > 1);
	
	If CopyingValue <> Undefined And Object.PaymentCalendar.Count() = 1
			And Object.PaymentCalendar[0].PaymentDate = Date(1,1,1) Then
		
		Object.PaymentCalendar.Clear();
		
		DiffInSeconds = (Common.ObjectAttributeValue(CopyingValue, "ShipmentDate") - ShipmentDate);
		DiffInSeconds = ?(DiffInSeconds < 0, -DiffInSeconds, DiffInSeconds);
		For Each Row In CopyingValue.PaymentCalendar Do
			NewRow = Object.PaymentCalendar.Add();
			FillPropertyValues(NewRow, Row);
			NewRow.PaymentDate = NewRow.PaymentDate + DiffInSeconds;
		EndDo;
		
	Else
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibleEnablePaymentTermItems()
	
	SetEnableGroupPaymentCalendarDetails();
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
EndProcedure
	
&AtClient
Procedure CloseOrderEnd(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);
	
	If Response = DialogReturnCode.Cancel
		Or Not Write(WriteParameters) Then
		Return;
	EndIf;
	
	CloseOrderFragment();
	FormManagement();
	
EndProcedure

&AtServer
Procedure CloseOrderFragment(Result = Undefined, AdditionalParameters = Undefined) Export
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.Ref);
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("SalesOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CheckDocumentInventoryReservation();
	OrdersClosingObject.CloseOrders();
	Read();
	
	ResetStatus();
	
EndProcedure

&AtServerNoContext
Function GetSalesOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SalesOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.SalesOrderStatuses AS SalesOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON SalesOrderStatuses.OrderStatus = OrderStatuses.Ref
	|
	|ORDER BY
	|	OrderStatuses.Order";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Status);
	EndDo;
	
	Return ChoiceData;	
	
EndFunction

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 			TabName);
	StructureData.Insert("Object",				Form.Object);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
		StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, "StructuralUnitReserve");
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
	
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateLabelPricesAndCurrency(Form)
	
	Object = Form.Object;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Form.SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		Form.ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			Form.NationalCurrencyExchangeRate);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				Form.RegisteredForVAT);
	LabelStructure.Insert("RegisteredForSalesTax",			Form.RegisteredForSalesTax);
	LabelStructure.Insert("SalesTaxRate",					Object.SalesTaxRate);
	
	Form.PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
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
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
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
			CalculateAmountInTabularSectionLine("Inventory" ,Row, False);
		EndDo;
		
		Modified = True;
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
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
	FillingParameters.Insert("FillGLAccount", True);
	FillingParameters.Insert("StructuralUnit", "StructuralUnitReserve");
	
	BundlesServer.RefreshBundleComponentsInTable(BundleProduct, BundleCharacteristic, Quantity, BundleComponents, FillingParameters);
	Modified = True;
	
	// AutomaticDiscounts
	ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure ActionsAfterDeleteBundleLine()
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
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

#Region BackgroundJobs

&AtServer
Function GenerateCounterpartySegmentsAtServer()
	
	CounterpartySegmentsJobID = Undefined;
	
	ProcedureName = "ContactsClassification.ExecuteCounterpartySegmentsGeneration";
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("en = 'Counterparty segments generation'; ru = 'Создание сегментов контрагентов';pl = 'Generacja segmentów kontrahenta';es_ES = 'Generación de segmentos de contrapartida';es_CO = 'Generación de segmentos de contrapartida';tr = 'Cari hesap segmentleri oluşturma';it = 'Generazione segmenti controparti';de = 'Generierung von Geschäftspartnersegmenten'");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(ProcedureName,, StartSettings);
	
	StorageAddress = ExecutionResult.ResultAddress;
	CounterpartySegmentsJobID = ExecutionResult.JobID;
	
	If ExecutionResult.Status = "Completed" Then
		MessageText = NStr("en = 'Counterparty segments have been updated successfully.'; ru = 'Сегменты контрагентов успешно обновлены.';pl = 'Segmenty kontrahenta zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de contrapartida.';es_CO = 'Se han actualizado con éxito los segmentos de contrapartida.';tr = 'Cari hesap segmentleri başarıyla güncellendi.';it = 'I segmenti delle controparti sono stati aggiornati con successo.';de = 'Die Geschäftspartner-Segmente wurden erfolgreich aktualisiert.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ExecutionResult;

EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(CounterpartySegmentsJobID) Then
			MessageText = NStr("en = 'Counterparty segments have been updated successfully.'; ru = 'Сегменты контрагентов успешно обновлены.';pl = 'Segmenty kontrahenta zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de contrapartida.';es_CO = 'Se han actualizado con éxito los segmentos de contrapartida.';tr = 'Cari hesap segmentleri başarıyla güncellendi.';it = 'I segmenti delle controparti sono stati aggiornati con successo.';de = 'Die Geschäftspartner-Segmente wurden erfolgreich aktualisiert.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution",
				IdleHandlerParameters.CurrentInterval,
				True);
		EndIf;
	Except
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(CounterpartySegmentsJobID)
	
	Return TimeConsumingOperations.JobCompleted(CounterpartySegmentsJobID);
	
EndFunction

#EndRegion

#Region SalesTax

&AtServer
Procedure SetVisibleTaxAttributes()
	
	IsSubjectToVAT = (Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT);
	
	Items.InventoryVATRate.Visible				= IsSubjectToVAT;
	Items.InventoryVATAmount.Visible			= IsSubjectToVAT;
	Items.InventoryAmountTotal.Visible			= IsSubjectToVAT;
	Items.PaymentVATAmount.Visible				= IsSubjectToVAT;
	Items.PaymentCalendarPayVATAmount.Visible	= IsSubjectToVAT;
	Items.DocumentTax.Visible					= IsSubjectToVAT OR RegisteredForSalesTax;
	Items.InventoryTaxable.Visible				= RegisteredForSalesTax;
	Items.InventorySalesTaxAmount.Visible		= RegisteredForSalesTax;
	Items.PageSalesTax.Visible					= RegisteredForSalesTax;
	
EndProcedure

&AtServerNoContext
Function GetSalesTaxPercentage(SalesTaxRate)
	
	Return Common.ObjectAttributeValue(SalesTaxRate, "Rate");
	
EndFunction

&AtClient
Procedure CalculateSalesTaxAmount(TableRow)
	
	AmountTaxable = GetTotalTaxable();
	
	TableRow.Amount = Round(AmountTaxable * TableRow.SalesTaxPercentage / 100, 2, RoundMode.Round15as20);
	
EndProcedure

&AtServer
Function GetTotalTaxable()
	
	InventoryTaxable = Object.Inventory.Unload(New Structure("Taxable", True));
	
	Return InventoryTaxable.Total("Total");
	
EndFunction

&AtServer
Procedure FillSalesTaxRate(IsOpening = False)
	
	SalesTaxRateBeforeChange = Object.SalesTaxRate;
	
	Object.SalesTaxRate = DriveServer.CounterpartySalesTaxRate(Object.Counterparty, RegisteredForSalesTax);
	
	If SalesTaxRateBeforeChange <> Object.SalesTaxRate OR IsOpening Then
		
		If ValueIsFilled(Object.SalesTaxRate) Then
			Object.SalesTaxPercentage = Common.ObjectAttributeValue(Object.SalesTaxRate, "Rate");
		Else
			Object.SalesTaxPercentage = 0;
		EndIf;
		
		RecalculateSalesTax();
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RecalculateSalesTax()
	
	FormObject = FormAttributeToValue("Object");
	FormObject.RecalculateSalesTax();
	ValueToFormAttribute(FormObject, "Object");
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion