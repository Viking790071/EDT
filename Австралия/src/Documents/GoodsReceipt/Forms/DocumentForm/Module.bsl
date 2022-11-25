
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	Company						= Object.Company;
	Counterparty				= Object.Counterparty;
	Contract					= Object.Contract;
	Order						= Object.Order;
	If ValueIsFilled(Object.Contract) Then
		SettlementsCurrency			= Common.ObjectAttributeValue(Object.Contract, "SettlementsCurrency");
	EndIf;
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency		= StructureByCurrency.Rate;
	RepetitionNationalCurrency	= StructureByCurrency.Repetition;
	
	SetAccountingPolicyValues();
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation();
		
	EndIf;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	OperationType = Object.OperationType;
	PurchaseFromSupplierOperation = (Object.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier);
	SalesReturnOperation = (Object.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn);
	IsDropShippingOperation = (Object.OperationType = Enums.OperationTypesGoodsReceipt.DropShipping);
	
	ForeignExchangeAccounting	= Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
	LabelStructure.Insert("SupplierDiscountKind",		Object.DiscountType);
	LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",			RegisteredForVAT);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ProcessingCompanyVATNumbers();
	FillOperationTypeChoiceList();
	
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.GoodsReceipt.TabularSections.Products, DataLoadSettings, ThisObject);
	
	// Cross-references visible.
	UseCrossReferences = Constants.UseProductCrossReferences.Get();
	
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
	Items.ProductsImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals

	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	DriveServer.OverrideStandartGenerateSupplierInvoiceCommand(ThisObject);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();
	
	SetVisibleAndEnabled();
	SetFormConditionalAppearance();
	SetOwnershipChoiceParameters();
	
	Items.ProductsDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	RecalculateSubtotal();
	
EndProcedure

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
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("TabularSectionName", "Products");
	WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
			RecalculateSubtotal();
		EndIf;
		
	ElsIf EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		SetContractVisible();
		
	EndIf;
	
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
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.SelectionFromOrders" Then
		OrderedProductsSelectionProcessingAtServer(SelectedValue.TempStorageInventoryAddress);
		RecalculateSubtotal();
	ElsIf ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "CommonForm.InventoryReservation" Then
		EditReservationProcessingAtClient(SelectedValue.TempStorageInventoryReservationAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormItemsHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	CompanyBeforeChange = Company;
	Company = Object.Company;
	
	If CompanyBeforeChange <> Company Then
		
		Object.Number = "";
		
		// Prices precision begin
		PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
		// Prices precision end
		
		CompanyDataOnChange();
		
		Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationType);
		
		If ContinentalMethod 
			And (PurchaseFromSupplierOperation Or SalesReturnOperation Or IsDropShippingOperation) Then
			
			ProcessContractChange();
			
			GenerateLabelPricesAndCurrency();
			
		EndIf;
		
	Else
		
		Object.Contract = Contract;
		Object.Order = Order;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		If Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty") 
			Or Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer") Then
			ClearOwnership();
		EndIf;
		
		Object.Contract = StructureData.Contract;
		
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		If ContinentalMethod 
			And (PurchaseFromSupplierOperation Or SalesReturnOperation Or IsDropShippingOperation) Then
			ProcessContractChangeFragment(ContractBeforeChange, StructureData);
		EndIf;
		
	Else
		
		Object.Contract = Contract;
		Object.Order = Order;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	If ContinentalMethod 
		And (PurchaseFromSupplierOperation Or SalesReturnOperation Or IsDropShippingOperation) Then
		ProcessContractChange();
	EndIf;
	
	If Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty") 
		Or Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer") Then
		
		SetOwnershipChoiceParameters();
		ClearOwnership();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref, Object.Company, Object.Counterparty, Object.Contract, CounterpartyAttributes.DoOperationsByContracts, Object.OperationType);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure OperationTypeOnChange(Item)
	
	OperationTypeBeforeChange = OperationType;
	OperationType = Object.OperationType;
	OperationTypePurchaseFromSupplier	= PredefinedValue("Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier");
	OperationTypeDropShipping			= PredefinedValue("Enum.OperationTypesGoodsReceipt.DropShipping");
	OperationTypeIntraTransfer			= PredefinedValue("Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer");
	
	// Check ProductsSupplierInvoice is filled
	If Not (Object.OperationType = OperationTypePurchaseFromSupplier 
		Or Object.OperationType = OperationTypeDropShipping) Then
	
		For Each LineProducts In Object.Products Do
			
			If ValueIsFilled(LineProducts.SupplierInvoice) Then
				
				MessageText = NStr("en = 'Cannot set this operation.
					|This Goods receipt is related to Supplier invoices. Remove them from the Products tab and try again.'; 
					|ru = 'Не удается установить эту операцию.
					|Поступление товаров связано с счетами поставщикам. Удалите их во вкладке ""Номенклатура"" и повторите попытку.';
					|pl = 'Nie można ustawić tej operacji.
					|To przyjęcie towarów jest powiązane z Fakturami zakupu. Usuń je z karty Produkty i spróbuj ponownie.';
					|es_ES = 'No se puede establecer esta operación.
					|Este recibo de Mercancías está relacionado con las facturas de Proveedor. Elimínelas de la pestaña Productos e inténtelo de nuevo.';
					|es_CO = 'No se puede establecer esta operación.
					|Este recibo de Mercancías está relacionado con las facturas de los Proveedores. Elimínelas de la pestaña Productos e inténtelo de nuevo.';
					|tr = 'İşlem yapılamıyor. 
					|Bu Ambar girişi, Satın alma faturalarıyla ilişkili. Bunları Ürünler sekmesinden kaldırıp tekrar deneyin.';
					|it = 'Impossibile impostare questa operazione. 
					|Questa Ricezione merce è correlata alle fatture Fornitori. Rimuoverle dalla scheda Articoli e riprovare.';
					|de = 'Kann diese Operation nicht festlegen.
					|Diese Warenquittung bezieht sich auf Lieferantenrechnungen. Entfernen Sie sie aus dem Produkt-Tab und versuchen Sie es erneut.'");
				CommonClientServer.MessageToUser(MessageText, Object.Ref, "OperationType");
				
				Object.OperationType = OperationTypePurchaseFromSupplier;
				
				Return;
				
			EndIf;
			
		EndDo; 
	
	EndIf;
	
	If OperationTypeBeforeChange <> OperationType Then
		
		If OperationType = OperationTypeIntraTransfer And Object.Products.Count() > 0 Then
			ShowQueryBox(
				New NotifyDescription("ConfirmProductsClearing", ThisObject, OperationTypeBeforeChange),
				MessagesToUserClientServer.TabularSectionWillBeCleared(NStr("en = 'Products'; ru = 'Номенклатура';pl = 'Produkty';es_ES = 'Productos';es_CO = 'Productos';tr = 'Ürünler';it = 'Articoli';de = 'Produkte'")),
				QuestionDialogMode.YesNo,
				,
				DialogReturnCode.No);
			Return;
		EndIf;
		
		ProcessOperationTypeChange(OperationTypeBeforeChange, OperationType);
		
		If ContinentalMethod 
			And (PurchaseFromSupplierOperation Or SalesReturnOperation Or IsDropShippingOperation) Then
			ProcessContractChange();
		EndIf;
		
	Else
		Object.Order = Order;
	EndIf;
	
EndProcedure

&AtClient
Procedure ConfirmProductsClearing(Response, OperationTypeBeforeChange) Export 
	
	If Response = DialogReturnCode.Yes Then
		
		Object.Products.Clear();
		
		ProcessOperationTypeChange(OperationTypeBeforeChange, OperationType);
		
	Else
		
		Object.OperationType = OperationTypeBeforeChange;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	StructuralUnitOnChangeAtServer();
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region TableEventHandlers

&AtClient
Procedure ProductsProductOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Date",	Object.Date);
	StructureData.Insert("Company",	Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("DiscountType",	Object.DiscountType);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("IncomeAndExpenseItems",	TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	
	AddTabDataToStructure(ThisObject, "Products", StructureData);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit	= StructureData.MeasurementUnit;
	If TabularSectionRow.Quantity = 0 Then
		TabularSectionRow.Quantity		= 1;
	EndIf;
	TabularSectionRow.VATRate			= StructureData.VATRate;
	
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company",	Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabDataToStructure(ThisObject, "Products", StructureData);
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Products.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Products";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
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
Procedure ProductsCrossReferenceOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Date",		Object.Date);
	StructureData.Insert("Company",		Object.Company);
	StructureData.Insert("Counterparty",Object.Counterparty);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabDataToStructure(ThisObject, "Products", StructureData);
	StructureData = GetDataCrossReferenceOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit	= StructureData.MeasurementUnit;
	If TabularSectionRow.Quantity = 0 Then
		TabularSectionRow.Quantity		= 1;
	EndIf;
	TabularSectionRow.VATRate			= StructureData.VATRate;
	
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Item)
	CalculateAmountInTabularSectionLine();
EndProcedure

&AtClient
Procedure ProductsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Products.CurrentData;
	
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
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure ProductsSerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();

EndProcedure

&AtClient
Procedure ProductsPriceOnChange(Item)
	CalculateAmountInTabularSectionLine();
EndProcedure

&AtClient
Procedure ProductsDiscountPercentOnChange(Item)
	CalculateAmountInTabularSectionLine();
EndProcedure

&AtClient
Procedure ProductsDiscountAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	DriveClient.CalculateVATAmount(TabularSectionRow, Object.AmountIncludesVAT);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);

EndProcedure

&AtClient
Procedure ProductsAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	If TabularSectionRow.DiscountPercent = 100 Then
		TabularSectionRow.DiscountAmount = TabularSectionRow.Amount;
	Else
		TabularSectionRow.DiscountAmount = (TabularSectionRow.Amount / (100 - TabularSectionRow.DiscountPercent))
											* TabularSectionRow.DiscountPercent;
	EndIf;
	
	AmountWithoutDiscount = TabularSectionRow.Amount + TabularSectionRow.DiscountAmount;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = AmountWithoutDiscount / TabularSectionRow.Quantity;
	EndIf;
	
	DriveClient.CalculateVATAmount(TabularSectionRow, Object.AmountIncludesVAT);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
Procedure ProductsVATRateOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	DriveClient.CalculateVATAmount(TabularSectionRow, Object.AmountIncludesVAT);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
Procedure ProductsVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
Procedure ProductsSupplierInvoiceOnChange(Item)
	
	TabRow = Items.Products.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabDataToStructure(ThisObject, "Products", StructureData);

	ProductsSupplierInvoiceOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtClient
Procedure ProductsOnChange(Item)
	RecalculateSubtotal();
EndProcedure

&AtClient
Procedure ProductsBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Products.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);

EndProcedure

&AtClient
Procedure ProductsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);

EndProcedure

&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ProductsGLAccounts" Then
		StandardProcessing = False;
		IsIntraTransfer = (Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer"));
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Products", , IsIntraTransfer);
	ElsIf Field.Name = "ProductsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Products");
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsOnActivateCell(Item)
	
	CurrentData = Items.Products.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Products.CurrentItem;
		If TableCurrentColumn.Name = "ProductsGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Products.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Products");
		ElsIf TableCurrentColumn.Name = "ProductsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Products.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Products");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure ProductsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Products.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Products");
	
EndProcedure

&AtClient
Procedure ProductsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Products", StandardProcessing);
	
EndProcedure

#EndRegion

#Region CommandHandlenrs

&AtClient
Procedure FillFromOrder(Command)
	
	If Not ValueIsFilled(Object.Order) Then
		MessagesToUserClient.ShowMessageSelectOrder();
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByOrderEnd", ThisObject),
		NStr("en = 'The document will be fully filled out according to the ""Order."" Continue?'; ru = 'Документ будет полностью перезаполнен по ""Заказу""! Продолжить выполнение операции?';pl = 'Dokument zostanie wypełniony w całości zgodnie z ""Zamówieniem"". Dalej?';es_ES = 'El documento se rellenará completamente según el ""Orden"". ¿Continuar?';es_CO = 'El documento se rellenará completamente según el ""Orden"". ¿Continuar?';tr = 'Belge ""Sipariş""e göre tamamen doldurulacak. Devam edilsin mi?';it = 'Il documento sarà interamente compilato secondo l''""Ordine"". Continuare?';de = 'Das Dokument wird entsprechend der ""Bestellung"" vollständig ausgefüllt. Fortsetzen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByOrderEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument(Object.Order);
	EndIf;

EndProcedure

&AtClient
Procedure Settings(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PurchaseOrderPositionInReceiptDocuments", Object.OrderPosition);
	ParametersStructure.Insert("SalesOrderPositionInShipmentDocuments", Object.SalesOrderPosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	InvCount = Object.Products.Count();
	If InvCount > 1 Then
		
		CurrOrder = Object.Products[0].Order;
		MultipleOrders = False;
		
		For Index = 1 To InvCount - 1 Do
			
			If CurrOrder <> Object.Products[Index].Order Then
				MultipleOrders = True;
				Break;
			EndIf;
			
			CurrOrder = Object.Products[Index].Order;
			
		EndDo;
		
		If MultipleOrders Then
			ParametersStructure.Insert("ReadOnly", True);
		EndIf;
		
	EndIf;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("SettingEnd", ThisObject));
	
EndProcedure

// Peripherals

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
			StructureProductsData.Insert("Date", StructureData.Date);
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("DiscountType", StructureData.DiscountType);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(
				StructureProductsData, StructureData.Object, "GoodsReceipt", "Products");
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(
					StructureProductsData, StructureData.Object, "GoodsReceipt", "Products");
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
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("Object", Object);
	StructureData.Insert("DiscountType", Object.DiscountType);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		If BarcodeData <> Undefined
			AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			
			Filter = New Structure();
			Filter.Insert("Products", BarcodeData.Products);
			Filter.Insert("Characteristic", BarcodeData.Characteristic);
			Filter.Insert("Batch", BarcodeData.Batch);
			Filter.Insert("MeasurementUnit", BarcodeData.MeasurementUnit);
				
			TSRowsArray = Object.Products.FindRows(Filter);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Products.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.DiscountPercent = BarcodeData.StructureProductsData.DiscountPercent;
				Items.Products.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				Items.Products.CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
			
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;
	
EndFunction

&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm("InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification);
		
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
	
	TemplateMessage = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			TemplateMessage,
			CurUndefinedBarcode.Barcode,
			CurUndefinedBarcode.Quantity);
		
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

&AtClient
Procedure EditReservation(Command)
	
	If Modified And Object.Posted Then
		
		Cancel = False;
		CheckReservedProductsChangeClient(Cancel);
		
		If Not Cancel Then
			OpenInventoryReservation();
		EndIf;
		Return;
		
	ElsIf (Modified Or Not Object.Posted) Then 
		
		MessagesToUserClient.ShowMessageCannotOpenInventoryReservationWindow();
		Return;
		
	EndIf;

	OpenInventoryReservation();
	
EndProcedure

&AtClient
Procedure OpenInventoryReservation()
	
	FormParameters = New Structure;
	FormParameters.Insert("TempStorageAddress", PutEditReservationDataToTempStorage());
	FormParameters.Insert("AdjustedReserved", Object.AdjustedReserved);
	FormParameters.Insert("UseAdjustedReserve", ChangeAdjustedReserved() And Object.AdjustedReserved);
	
	OpenForm("CommonForm.InventoryReservation", FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region WorkWithSelect

&AtClient
Procedure SelectOrderedProducts(Command)

	Try
		LockFormDataForEdit();
		Modified = True;
	Except
		ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	SelectionParameters = New Structure(
		"Ref,
		|Company,
		|StructuralUnit,
		|Counterparty,
		|Contract,
		|Order,
		|OperationType");
	FillPropertyValues(SelectionParameters, Object);
	
	SelectionParameters.Insert("TempStorageInventoryAddress", PutProductsToTempStorage());
	SelectionParameters.Insert("ShowGoodsIssue", False);
	SelectionParameters.Insert("ShowPurchaseOrders", True);
	SelectionParameters.Insert("ContinentalMethod", ContinentalMethod);
	
	OpenForm("CommonForm.SelectionFromOrders", SelectionParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function PutProductsToTempStorage()
	
	ProductsTable = Object.Products.Unload();
	
	ProductsTable.Columns.Add("Reserve", New TypeDescription("Number"));
	ProductsTable.Columns.Add("Content", New TypeDescription("String"));
	ProductsTable.Columns.Add("GoodsIssue", New TypeDescription("DocumentRef.GoodsIssue"));
	ProductsTable.Columns.Add("SalesInvoice", New TypeDescription("DocumentRef.SalesInvoice"));
	
	If ValueIsFilled(Object.Order) Then
		For Each ProductRow In ProductsTable Do
			
			If Not ValueIsFilled(ProductRow.Order) Then
				ProductRow.Order = Object.Order;
			EndIf;
			ProductRow.SalesInvoice = ProductRow.SupplierInvoice;			
			ProductRow.Content = String(ProductRow.Products);
			
		EndDo;
	EndIf;
	
	Return PutToTempStorage(ProductsTable);
	
EndFunction

&AtServer
Procedure OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress)
	
	TablesStructure = GetFromTempStorage(TempStorageInventoryAddress);
	
	InventorySearchStructure = New Structure("Products, Characteristic, Batch, Order, SupplierInvoice");
	
	TablesStructure.Inventory.Columns.SalesInvoice.Name = "SupplierInvoice";
	EmptySI = Documents.SupplierInvoice.EmptyRef();
	EmptyPO = Documents.PurchaseOrder.EmptyRef();
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each InventoryRow In TablesStructure.Inventory Do
		
		FillPropertyValues(InventorySearchStructure, InventoryRow);
		
		If InventorySearchStructure.SupplierInvoice = Undefined Then
			InventorySearchStructure.SupplierInvoice = EmptySI;
		EndIf;
		If InventorySearchStructure.Order = Undefined Then
			InventorySearchStructure.Order = EmptyPO;
		EndIf;
		
		TS_InventoryRows = Object.Products.FindRows(InventorySearchStructure);
		For Each TS_InventoryRow In TS_InventoryRows Do
			Object.Products.Delete(TS_InventoryRow);
		EndDo;
			
		TS_InventoryRow = Object.Products.Add();
		FillPropertyValues(TS_InventoryRow, InventoryRow);
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, TS_InventoryRow, "Products");
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, TS_InventoryRow, "Products");
		EndIf;
		
	EndDo;
	
	OrdersTable = Object.Products.Unload( , "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	
	If OrdersTable.Count() > 1 Then
		Object.Order = Undefined;
		Object.Contract = Undefined;
		Object.OrderPosition = Enums.AttributeStationing.InTabularSection;
	ElsIf OrdersTable.Count() = 1 Then
		Object.Order = OrdersTable[0].Order;
		Object.Contract = OrdersTable[0].Contract;
		Object.OrderPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	
	SetVisibleFromUserSettings();
	SetContractVisible();
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region DataImportFromExternalSources

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"GoodsReceipt.Products");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import products from file'; ru = 'Загрузка запасов из файла';pl = 'Importuj produkty z pliku';es_ES = 'Importar los productos del archivo';es_CO = 'Importar los productos del archivo';tr = 'Ürünleri dosyadan içe aktar';it = 'Importazione articoli da file';de = 'Produkte aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		RecalculateSubtotal();
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

#EndRegion

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

#Region CopyPasteRows

&AtClient
Procedure CopyRows(Command)
	CopyRowsTabularPart("Products");
EndProcedure

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName], Items[TabularPartName].CurrentData) Then
		CountOfCopied = 0;
		CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied);
		TabularPartCopyClient.NotifyUserCopyRows(CountOfCopied);
	EndIf;
	
EndProcedure

&AtServer 
Procedure CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied)
	
	TabularPartCopyServer.Copy(Object[TabularPartName], Items[TabularPartName].SelectedRows, CountOfCopied);
	
EndProcedure

&AtClient
Procedure PasteRows(Command)
	
	PasteRowsTabularPart("Products");
	
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	ProcessPastedRows(TabularPartName, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtClient 
Procedure ProcessPastedRows(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For Iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - Iterator];
		CalculateAmountInTabularSectionLine(Row);
		
	EndDo; 
	
EndProcedure

&AtServer 
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For Iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - Iterator];
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Date", Object.Date);
		StructureData.Insert("Products", Row.Products);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		
		AddTabDataToStructure(ThisObject, TabularPartName, StructureData, Row);
		
		StructureData = GetDataProductsOnChange(StructureData);
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructureData.MeasurementUnit;
		EndIf;
		
		Row.VATRate = StructureData.VATRate;
		
	EndDo;
	
EndProcedure

#EndRegion

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

#Region Private

&AtClient
Procedure GenerateLabelPricesAndCurrency()
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
	LabelStructure.Insert("SupplierDiscountKind",		Object.DiscountType);
	LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",			RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
Procedure Attachable_GenerateSupplierInvoice(Command)
	
	Array = New Array;
	Array.Add(Object.Ref);
	
	IsDropShipping = False;
	
	If Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.DropShipping") Then
		IsDropShipping = True;
	EndIf;
	
	DriveClient.SupplierInvoiceGenerationBasedOnGoodsReceipt(Array, IsDropShipping);
	
EndProcedure

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureData);
	
	AttributeArray = New Array;
	AttributeArray.Add("MeasurementUnit");
	AttributeArray.Add("VATRate");
	AttributeArray.Add("BusinessLine");
	
	If StructureData.UseDefaultTypeOfAccounting Then
		AttributeArray.Add("ExpensesGLAccount.TypeOfAccount");
	EndIf;
	
	ProductData = Common.ObjectAttributesValues(StructureData.Products, StrConcat(AttributeArray, ","));
	
	StructureData.Insert("MeasurementUnit", ProductData.MeasurementUnit);
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(StructureData.Date, StructureData.Company);
	
	If ValueIsFilled(ProductData.VATRate) Then
		ProductVATRate = ProductData.VATRate;
	Else
		ProductVATRate = AccountingPolicy.DefaultVATRate;
	EndIf;
	
	If Not AccountingPolicy.RegisteredForVAT Then
		StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
	Elsif Not StructureData.Property("VATTaxation")
			Or StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		StructureData.Insert("VATRate", ProductVATRate);
	ElsIf StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
	Else
		StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
	EndIf;
	
	If StructureData.Property("DiscountType") Then
		StructureData.Insert("DiscountPercent", Common.ObjectAttributeValue(StructureData.DiscountType, "Percent"));
	Else
		StructureData.Insert("DiscountPercent", 0);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureData);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCrossReferenceOnChange(StructureData)
	
	CrossReferenceData = Common.ObjectAttributesValues(StructureData.CrossReference, "Products, Characteristic");
	FillPropertyValues(StructureData, CrossReferenceData);
	
	If CrossReferenceData.Products = Undefined Then
		StructureData.Insert("Products", Catalogs.Products.EmptyRef());
	Else
		StructureData.Insert("Products", CrossReferenceData.Products);
	EndIf;
	
	AttributeArray = New Array;
	AttributeArray.Add("MeasurementUnit");
	AttributeArray.Add("VATRate");
	AttributeArray.Add("BusinessLine");
	
	If StructureData.UseDefaultTypeOfAccounting Then
		AttributeArray.Add("ExpensesGLAccount.TypeOfAccount");
	EndIf;
	
	ProductData = Common.ObjectAttributesValues(StructureData.Products, StrConcat(AttributeArray, ","));
	
	StructureData.Insert("MeasurementUnit", ProductData.MeasurementUnit);
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(StructureData.Date, StructureData.Company);
	
	If ValueIsFilled(ProductData.VATRate) Then
		ProductVATRate = ProductData.VATRate;
	Else
		ProductVATRate = AccountingPolicy.DefaultVATRate;
	EndIf;
	
	If Not AccountingPolicy.RegisteredForVAT Then
		StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
	Elsif Not StructureData.Property("VATTaxation")
			Or StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		StructureData.Insert("VATRate", ProductVATRate);
	ElsIf StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
	Else
		StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
	EndIf;
	
	If StructureData.Property("DiscountType") Then
		StructureData.Insert("DiscountPercent", Common.ObjectAttributeValue(StructureData.DiscountType, "Percent"));
	Else
		StructureData.Insert("DiscountPercent", 0);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationType)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationType);
	
EndFunction

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Products.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Procedure SetVisibleFromUserSettings()
	
	Items.FormSettings.Visible = PurchaseFromSupplierOperation And Not ContinentalMethod
		Or SalesReturnOperation
		Or IsDropShippingOperation;

	If Object.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier 
		And Object.OrderPosition = Enums.AttributeStationing.InHeader
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn 
		And Object.SalesOrderPosition = Enums.AttributeStationing.InHeader
		Or ContinentalMethod
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty 
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer 
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.DropShipping
		// begin Drive.FullVersion
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor 
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer 
		// end Drive.FullVersion
		Then
		VisibleValue = True;
	Else
		VisibleValue = False;
	EndIf;
	
	Items.Order.Enabled = VisibleValue;
	
	Items.Contract.Enabled = Not (Object.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn
		And Object.SalesOrderPosition = Enums.AttributeStationing.InTabularSection);
	
	If VisibleValue Then
		Items.Order.InputHint = "";
		Items.Contract.InputHint = "";
	Else 
		Items.Order.InputHint = NStr("en = '<Multiple orders mode>'; ru = '<Режим нескольких заказов>';pl = '<Tryb wielu zamówień>';es_ES = '<Modo de órdenes múltiples>';es_CO = '<Modo de órdenes múltiples>';tr = '<Birden fazla emir modu>';it = '<Modalità ordini multipli>';de = '<Mehrfach-Bestellungen Modus>'");
		Items.Contract.InputHint = NStr("en = '<Multiple orders mode>'; ru = '<Режим нескольких заказов>';pl = '<Tryb wielu zamówień>';es_ES = '<Modo de órdenes múltiples>';es_CO = '<Modo de órdenes múltiples>';tr = '<Birden fazla emir modu>';it = '<Modalità ordini multipli>';de = '<Mehrfach-Bestellungen Modus>'");
	EndIf;
	
	Items.ProductsOrder.Visible = Not VisibleValue;
	Items.FillFromOrder.Visible = VisibleValue;
	
EndProcedure

&AtClient
Procedure SettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.OrderPosition = StructureDocumentSetting.PurchaseOrderPositionInReceiptDocuments;
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInShipmentDocuments;
		
		If OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier")
			And Object.OrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") 
			Or OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.SalesReturn")
			And Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			
			If Object.Products.Count() Then
				Object.Order = Object.Products[0].Order;
				Object.Contract = Object.Products[0].Contract;
			EndIf;
			
		Else
			
			If ValueIsFilled(Object.Order) Then
				For Each InventoryRow In Object.Products Do
					If Not ValueIsFilled(InventoryRow.Order) Then
						InventoryRow.Order = Object.Order;
					EndIf;
				EndDo;
				
				Object.Order = Undefined;
			EndIf;
			
			If ValueIsFilled(Object.Contract) Then
				For Each InventoryRow In Object.Products Do
					If Not ValueIsFilled(InventoryRow.Contract) Then
						InventoryRow.Contract = Object.Contract;
					EndIf;
				EndDo;
				
				Object.Contract = Undefined;
			EndIf;
			
		EndIf;
		
		SetVisibleAndEnabled();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	FillAddedColumns(True);
	SetVisibleAndEnabled();
	
EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	AdditionalParameters = New Structure("NameTSInventory", "Products");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, AdditionalParameters);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False, "Products");
EndFunction

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns();
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetVisibleAndEnabled();
	
	RecalculateSubtotalServer();
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure ProcessOperationTypeChange(OperationTypeBeforeChange, OperationType)
	
	OperationReceiptFromAThirdParty = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty;
	// begin Drive.FullVersion
	ReceiptFromSubcontractingCustomer = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer;
	// end Drive.FullVersion 
	
	If Not GetFunctionalOption("CanReceiveSubcontractingServices")
		And (Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor) Then
		
		MessageText = NStr("en = 'The functional option ""Use subcontractor order issued"" should be on for this operation type'; ru = 'Функциональная опция ""Использовать выданные заказы на переработку"" должна быть включена для данного типа операции';pl = 'Opcja funkcjonalna ""Używaj wydanego zamówienia wykonawcy"" powinna być włączona dla tego typu operacji';es_ES = 'La opción funcional "" Utilizar la orden emitida del subcontratista"" debe estar activada para este tipo de operación';es_CO = 'La opción funcional "" Utilizar la orden emitida del subcontratista"" debe estar activada para este tipo de operación';tr = 'Bu işlem türü için ""Çıkarılan alt yüklenici siparişini kullan"" işlevinin açık olması gerekir';it = 'L''opzione funzionale ""Utilizzare ordine subfornitura emesso"" dovrebbe essere attiva per questo tipo di operazione';de = 'Die funktionale Option ""Ausgestellte Subunternehmerauftrag verwenden"" sollte für diesen Operationstyp aktiviert sein'");
		CommonClientServer.MessageToUser(MessageText, , "OperationKind");
		
	// begin Drive.FullVersion
	ElsIf Not GetFunctionalOption("CanProvideSubcontractingServices") 
		And Object.OperationType = ReceiptFromSubcontractingCustomer Then
		
		MessageText = NStr("en = 'The functional option ""Use subcontractor order received"" should be on for this operation type'; ru = 'Функциональная опция ""Использовать полученные заказы на переработку"" должна быть включена для данного типа операции';pl = 'Opcja funkcjonalna ""Używaj otrzymanego zamówienia podwykonawcy"" powinna być włączona dla tego typu operacji';es_ES = 'La opción funcional ""Utilizar la orden recibida del subcontratista"" debe estar activada para este tipo de operación';es_CO = 'La opción funcional ""Utilizar la orden recibida del subcontratista"" debe estar activada para este tipo de operación';tr = 'Bu işlem türü için ""Alınan alt yüklenici siparişini kullan"" işlevinin açık olması gerekir';it = 'L''opzione funzionale ""Utilizzare ordine di subfornitura ricevuto"" dovrebbe essere attiva per questo tipo di operazione';de = 'Die funktionale Option ""Subunternehmerauftrag erhalten verwenden"" sollte für diesen Operationstyp aktiviert sein'");
		CommonClientServer.MessageToUser(MessageText, , "OperationKind");
	// end Drive.FullVersion 
			
	EndIf;
	
	If OperationTypeBeforeChange = OperationReceiptFromAThirdParty
		Or OperationType = OperationReceiptFromAThirdParty 
		// begin Drive.FullVersion
		Or OperationTypeBeforeChange = ReceiptFromSubcontractingCustomer
		Or OperationType = ReceiptFromSubcontractingCustomer
		// end Drive.FullVersion 
		Then
		
		Object.Order = Undefined;
		
		For Each ProductsRow In Object.Products Do
			ProductsRow.Ownership = "";
		EndDo;
		
	EndIf;
	
	PurchaseFromSupplierOperation = (Object.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier);
	SalesReturnOperation = (Object.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn);
	IsDropShippingOperation = (Object.OperationType = Enums.OperationTypesGoodsReceipt.DropShipping);
	
	CheckTransactionsMethodologyAttributes();
	
	FillAddedColumns(True);
	
	SetVisibleAndEnabled();
	ProcessingCompanyVATNumbers();
	SetOwnershipChoiceParameters();
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationType);
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabled()
	
	IsIntraTransfer = (Object.OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer);
	IsReturnFromAThirdParty = (Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty);
	IsReceiptFromAThirdParty = (Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty);
	IsPurchaseFromSupplier = (Object.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier);
	IsReceiptFromSubcontractor = (Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor);
	IsReturnFromSubcontractor = (Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor);
	IsReceiptFromSubcontractingCustomer = False;
	IsDropShipping = (Object.OperationType = Enums.OperationTypesGoodsReceipt.DropShipping);
	// begin Drive.FullVersion
	IsReceiptFromSubcontractingCustomer = 
		(Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer);
	// end Drive.FullVersion 
	
	Items.GroupOrder.Visible = Not (IsIntraTransfer Or IsReturnFromAThirdParty);
	Items.ProductsOrder.Visible = Not (IsIntraTransfer Or IsReturnFromAThirdParty Or IsReceiptFromAThirdParty);
	
	Items.ProductsSalesInvoice.Visible		= SalesReturnOperation;
	Items.ProductsCreditNote.Visible		= SalesReturnOperation;
	Items.ProductsInitialQuantity.Visible	= SalesReturnOperation;
	Items.ProductsInitialAmount.Visible		= SalesReturnOperation And ContinentalMethod;
	Items.ProductsCostOfGoodsSold.Visible	= SalesReturnOperation;
	Items.ProductsProject.Visible			= SalesReturnOperation;
	Items.ProductsSupplierInvoice.Visible	= (IsPurchaseFromSupplier Or IsReceiptFromAThirdParty Or IsReturnFromAThirdParty);
	Items.ProductsBasisDocument.Visible		= Not 
		(SalesReturnOperation Or IsReceiptFromSubcontractor Or IsReturnFromSubcontractor Or IsReceiptFromSubcontractingCustomer);
	Items.ProductsIncomeAndExpenseItems.Visible	= SalesReturnOperation;
	
	Items.StructuralUnit.Visible				= Not (IsIntraTransfer Or IsDropShipping);
	Items.GroupCounterpartyOrderInfo.Visible	= Not IsIntraTransfer;
	Items.GroupIntraCommunityTransfer.Visible	= IsIntraTransfer;
	
	Items.ProductsProcessing.Visible = Not IsIntraTransfer;
	Items.Products.ReadOnly = IsIntraTransfer;
	
	If SalesReturnOperation Then
		Items.ProductsQuantity.Title = NStr("en = 'Return quantity'; ru = 'Возвращаемое количество';pl = 'Zwracana ilość';es_ES = 'Cantidad para la devolución';es_CO = 'Cantidad para la devolución';tr = 'İade miktarı';it = 'Quantità restituita';de = 'Retouren- Menge'");
	Else
		Items.ProductsQuantity.Title = NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'");
	EndIf;
	
	If IsPurchaseFromSupplier 
		Or IsDropShipping Then
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.PurchaseOrder");
		Items.ProductsOrder.TypeRestriction = New TypeDescription("DocumentRef.PurchaseOrder");
		// Operation type of order
		ArrayOperationTypesPO = New Array();
		If IsDropShipping Then
			ArrayOperationTypesPO.Add(PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForDropShipping"));
			
		Else 
			ArrayOperationTypesPO.Add(PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForProcessing"));
			ArrayOperationTypesPO.Add(PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForPurchase"));
		EndIf;
		FixedArrayParameters			= DriveClientServer.GetFixedArrayChoiceParameters(ArrayOperationTypesPO, "Filter.OperationKind");
		Items.Order.ChoiceParameters			= FixedArrayParameters;
		Items.ProductsOrder.ChoiceParameters	= FixedArrayParameters;
	ElsIf IsReceiptFromSubcontractor Or IsReturnFromSubcontractor Then
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.SubcontractorOrderIssued");
		Items.ProductsOrder.TypeRestriction = New TypeDescription("DocumentRef.SubcontractorOrderIssued");
	// begin Drive.FullVersion
	ElsIf IsReceiptFromSubcontractingCustomer Then
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.SubcontractorOrderReceived");
		Items.ProductsOrder.TypeRestriction = New TypeDescription("DocumentRef.SubcontractorOrderReceived");
	// end Drive.FullVersion
	Else
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.SalesOrder");
		Items.ProductsOrder.TypeRestriction = New TypeDescription("DocumentRef.SalesOrder");
	EndIf;
	
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	If Not ValueIsFilled(Object.StructuralUnit)
		Or IsIntraTransfer 
		Or IsDropShipping
		Or StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items.Cell.Visible = False;
	Else
		Items.Cell.Visible = True;
	EndIf;
	
	AmountsVisible = ContinentalMethod And (PurchaseFromSupplierOperation Or SalesReturnOperation Or IsDropShippingOperation);
	
	Items.ProductsPrice.Visible = AmountsVisible;
	Items.ProductsAmount.Visible = AmountsVisible;
	Items.ProductsGroupDiscounts.Visible = AmountsVisible;
	Items.PricesAndCurrency.Visible = AmountsVisible;
	Items.Totals.Visible = AmountsVisible;
	
	Items.ProductsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	SetContractVisible();
	SetVATTaxationDependantItemsVisibility();
	
	SetVisibleFromUserSettings();
	
EndProcedure

&AtServer
Procedure SetOwnershipChoiceParameters()
	
	OwnershipChoiceParameters = New Array;
	If Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
		
		NewChoiceParameter = New ChoiceParameter("Filter.OwnershipType", Enums.InventoryOwnershipTypes.CounterpartysInventory);
		OwnershipChoiceParameters.Add(NewChoiceParameter);
		
		NewChoiceParameter = New ChoiceParameter("Filter.Counterparty", Object.Counterparty);
		OwnershipChoiceParameters.Add(NewChoiceParameter);
		
		NewChoiceParameter = New ChoiceParameter("Filter.Contract", Object.Contract);
		OwnershipChoiceParameters.Add(NewChoiceParameter);
	// begin Drive.FullVersion
	ElsIf Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer Then
		
		NewChoiceParameter = New ChoiceParameter("Filter.OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		OwnershipChoiceParameters.Add(NewChoiceParameter);
		
		NewChoiceParameter = New ChoiceParameter("Filter.Counterparty", Object.Counterparty);
		OwnershipChoiceParameters.Add(NewChoiceParameter);
		
		NewChoiceParameter = New ChoiceParameter("Filter.Contract", Object.Contract);
		OwnershipChoiceParameters.Add(NewChoiceParameter);
	// end Drive.FullVersion 
	Else
		
		NewChoiceParameter = New ChoiceParameter("Filter.OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		OwnershipChoiceParameters.Add(NewChoiceParameter);
		
	EndIf;
	
	Items.ProductsOwnership.ChoiceParameters = New FixedArray(OwnershipChoiceParameters);
	
EndProcedure

&AtClient
Procedure ClearOwnership()
	
	For Each ProductsRow In Object.Products Do
		ProductsRow.Ownership = "";
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddTabDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 							TabName);
	StructureData.Insert("Object",								Form.Object);
	StructureData.Insert("Products",							TabRow.Products);
	StructureData.Insert("Characteristic",						TabRow.Characteristic);
	StructureData.Insert("CrossReference",						TabRow.CrossReference);
	StructureData.Insert("SupplierInvoice",						TabRow.SupplierInvoice);
	StructureData.Insert("SalesReturnItem",						TabRow.SalesReturnItem);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",							TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",					TabRow.GLAccountsFilled);
		
		StructureData.Insert("InventoryGLAccount",					TabRow.InventoryGLAccount);
		StructureData.Insert("InventoryTransferredGLAccount",		TabRow.InventoryTransferredGLAccount);
		StructureData.Insert("InventoryReceivedGLAccount",			TabRow.InventoryReceivedGLAccount);
		StructureData.Insert("GoodsReceivedNotInvoicedGLAccount",	TabRow.GoodsReceivedNotInvoicedGLAccount);
		StructureData.Insert("GoodsInvoicedNotDeliveredGLAccount",	TabRow.GoodsInvoicedNotDeliveredGLAccount);
		StructureData.Insert("GoodsInTransitGLAccount",				TabRow.GoodsInTransitGLAccount);
		StructureData.Insert("COGSGLAccount",						TabRow.COGSGLAccount);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureArray = New Array();
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Products");
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Products");
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

&AtServer
Procedure ProductsSupplierInvoiceOnChangeAtServer(StructureData)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	ContinentalMethod = AccountingPolicy.ContinentalMethod;
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
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
	ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",						Company);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("WarningText",					WarningText);
	ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
	ParametersStructure.Insert("SupplierDiscountKind",			Object.DiscountType);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd",
		ThisObject,
		AttributesBeforeChange);
		
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") And ClosingResult.WereMadeChanges Then
		
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
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
		Object.DiscountType = ClosingResult.SupplierDiscountKind;
		
		// Recalculate by discounts.
		If ClosingResult.RefillPrices Then
			DiscountPercent = GetDiscountPercent(Object.DiscountType);
			For Each TabularSectionRow In Object.Products Do
				TabularSectionRow.DiscountPercent = DiscountPercent;
				CalculateAmountInTabularSectionLine(TabularSectionRow);
			EndDo;
		EndIf;
		
		// Recalculate prices by currency.
		If ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Products", PricesPrecision);
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Products", PricesPrecision);
		EndIf;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	RecalculateSubtotal();
	
	ProcessChangesOnButtonPricesAndCurrenciesEndAtServer();
	
EndProcedure

&AtServerNoContext
Function GetDiscountPercent(DiscountType)
	Return Common.ObjectAttributeValue(DiscountType, "Percent");
EndFunction

&AtServer
Procedure ProcessChangesOnButtonPricesAndCurrenciesEndAtServer()
	
	FillAddedColumns(True);
	
EndProcedure

&AtServer
Procedure FillVATRateByVATTaxation()
	
	SetVATTaxationDependantItemsVisibility();
	
	DefaultVATRate = Undefined;
	DefaultVATRateIsRead = False;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		For Each TabularSectionRow In Object.Products Do
			
			ProductVATRate = Common.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
			
			If ValueIsFilled(ProductVATRate) Then
				TabularSectionRow.VATRate = ProductVATRate;
			Else
				If Not DefaultVATRateIsRead Then
					DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
					DefaultVATRateIsRead = True;
				EndIf;
				TabularSectionRow.VATRate = DefaultVATRate;
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			If Object.AmountIncludesVAT Then
				TabularSectionRow.VATAmount = TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100);
				TabularSectionRow.Total = TabularSectionRow.Amount;
			Else
				TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
				TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;
			EndIf;
			
		EndDo;
		
	Else
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			VATRateByTaxation = Catalogs.VATRates.Exempt;
		Else
			VATRateByTaxation = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		For Each TabularSectionRow In Object.Products Do
		
			TabularSectionRow.VATRate = VATRateByTaxation;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
	RecalculateSubtotalServer();
	
EndProcedure

&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsCounterpartyOnChange = False)
	
	If Not WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, False)
		Or Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT 
		Or Object.VATTaxation = Enums.VATTaxationTypes.EmptyRef()
		Or IsCounterpartyOnChange Then
		
		TaxationBeforeChange = Object.VATTaxation;
		
		Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty,
			DriveServer.VATTaxation(Object.Company, Object.Date),
			False);
		
		If Not TaxationBeforeChange = Object.VATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVATTaxationDependantItemsVisibility()
	
	IsSubjectToVATTaxation = (Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT);
	
	Items.ProductsVATRate.Visible = ContinentalMethod And IsSubjectToVATTaxation;
	Items.ProductsVATAmount.Visible = ContinentalMethod And IsSubjectToVATTaxation;
	Items.ProductsTotal.Visible = ContinentalMethod And IsSubjectToVATTaxation;
	Items.DocumentTax.Visible = ContinentalMethod And IsSubjectToVATTaxation;
	
EndProcedure

&AtClient
Procedure RecalculateSubtotal()
	
	Totals = CalculateSubtotal(Object.Products, Object.AmountIncludesVAT);
	FillPropertyValues(ThisObject, Totals);
	
EndProcedure

&AtServer
Procedure RecalculateSubtotalServer()
	
	Totals = DriveServer.CalculateSubtotalPurchases(Object.Products.Unload(), Object.AmountIncludesVAT);
	FillPropertyValues(ThisObject, Totals);
	
EndProcedure

&AtServerNoContext
Function CalculateSubtotal(Val TabularSection, AmountIncludesVAT)
	
	Return DriveServer.CalculateSubtotalPurchases(TabularSection.Unload(), AmountIncludesVAT);
	
EndFunction

&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationType);
	
	FillVATRateByCompanyVATTaxation(True);
	
	If Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty 
		Or Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer Then
		SetOwnershipChoiceParameters();
	EndIf;
	
	StructureData = GetDataContractOnChange(Date, ContractByDefault, Company);
	
	SetContractVisible();
	
	If UseCrossReferences Then
		FillCrossReference(True);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure SetContractVisible()
	
	If ValueIsFilled(Object.Counterparty) Then
		ShowContracts = CounterpartyAttributes.DoOperationsByContracts;
	Else
		ShowContracts = False;
	EndIf;
	
	Items.Contract.Visible = (ShowContracts Or Object.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn)
		And Object.OrderPosition = Enums.AttributeStationing.InHeader;
	Items.ProductsContract.Visible = ShowContracts And Object.OrderPosition = Enums.AttributeStationing.InTabularSection;
	
EndProcedure

&AtServer
Procedure FillCrossReference(IsCounterpartyChanged)
	
	For Each LineInventory In Object.Products Do
		
		If ValueIsFilled(LineInventory.CrossReference) 
			And Not IsCounterpartyChanged Then
			
			Return;
			
		EndIf;
		
		StructureInventory = New Structure("Counterparty, Products, Characteristic",
			Counterparty,
			LineInventory.Products,
			LineInventory.Characteristic);
		
		Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureInventory);
		
		LineInventory.CrossReference = StructureInventory.CrossReference;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	// ProductsPrice, ProductsAmount, ProductsVATRate, ProductsVATAmount, ProductsTotal
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Products.SupplierInvoice",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "ProductsPrice, ProductsDiscountPercent, ProductsDiscountAmount, ProductsAmount, ProductsVATRate, ProductsVATAmount, ProductsTotal");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Products");
	
EndProcedure

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Or Not ValueIsFilled(Object.DocumentCurrency) Then
		ProcessContractChangeFragment(ContractBeforeChange);
	Else
		Object.Order = Order;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeFragment(ContractBeforeChange, StructureData = Undefined)
	
	If StructureData = Undefined Then
		StructureData = GetDataContractOnChange(Object.Date, Object.Contract, Object.Company);
	EndIf;
	
	SettlementsCurrency = StructureData.SettlementsCurrency;
	DiscountType = StructureData.DiscountType;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate = ?(StructureData.SettlementsCurrencyRateRepetition.Rate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
	EndIf;
	
	CurrencyChanged = (ValueIsFilled(SettlementsCurrency) And Object.DocumentCurrency <> StructureData.SettlementsCurrency);
	DiscountTypeChanged = (ValueIsFilled(DiscountType) And Object.DiscountType <> StructureData.DiscountType);
	
	OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
		And (CurrencyChanged Or DiscountTypeChanged)
		And Object.Products.Count();
	
	Order = Object.Order;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	If ValueIsFilled(DiscountType) Then
		Object.DiscountType = DiscountType;
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If DiscountTypeChanged Then
			WarningText = NStr("en = 'The counterparty''s discount type differ from discounts in the document. Check the discounts in the document.'; ru = 'Тип скидки контрагента отличается от скидок в документе. Проверьте скидки в документе.';pl = 'Typ rabatu kontrahenta różni się od rabatów w dokumencie. Sprawdź rabaty w dokumencie.';es_ES = 'El tipo de descuento de la contraparte difiere de los descuentos en el documento. Compruebe los descuentos en el documento.';es_CO = 'El tipo de descuento de la contraparte difiere de los descuentos en el documento. Compruebe los descuentos en el documento.';tr = 'Cari hesabın indirim türü belgedeki indirimlerden farklı. Belgedeki indirimleri kontrol edin.';it = 'Il tipo di sconto della controparte differisce dagli sconti nel documento. Verificare gli sconti nel documento.';de = 'Der Rabatttyp unterscheidet sich von Rabatten im Dokument. Überprüfen Sie die Rabatte im Dokument.'");
		EndIf;
		
		If CurrencyChanged Then
			WarningText = WarningText
			+ ?(IsBlankString(WarningText), "", Chars.LF + Chars.LF)
			+ MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		EndIf;
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, DiscountTypeChanged, WarningText);
		
	Else
		
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtServerNoContext
Function GetDataContractOnChange(Date, Contract, Company)
	
	StructureData = New Structure;
	
	StructureData.Insert("Contract", Contract);
	StructureData.Insert("SettlementsCurrency", Common.ObjectAttributeValue(Contract, "SettlementsCurrency"));
	StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateOperations.GetCurrencyRate(Date, StructureData.SettlementsCurrency, Company));
	StructureData.Insert("DiscountType", Common.ObjectAttributeValue(Contract, "DiscountMarkupKind"));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, DoOperationsByContracts, OperationType)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document, OperationType);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	If ContinentalMethod And (PurchaseFromSupplierOperation Or SalesReturnOperation Or IsDropShippingOperation) Then
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;
		
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange()
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	
	StructureData = New Structure("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If Object.DocumentCurrency <> SettlementsCurrency Then
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company);
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
	Else
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
	EndIf;
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers();
	FillVATRateByCompanyVATTaxation();
	
	SetVisibleAndEnabled();
	SetAutomaticVATCalculation();
	
	CheckTransactionsMethodologyAttributes();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure CompanyDataOnChange()
	
	SetAccountingPolicyValues();
	SetVisibleAndEnabled();
	SetAutomaticVATCalculation();
	
	FillVATRateByCompanyVATTaxation();
	
	CheckTransactionsMethodologyAttributes();
	
	FillAddedColumns(True);
	
	ProcessingCompanyVATNumbers(False);
	
	InformationRegisters.AccountingSourceDocuments.CheckNotifyTypesOfAccountingProblems(
		Object.Ref,
		Object.Company,
		DocumentDate);

EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Products.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	TabularSectionRow.DiscountAmount = TabularSectionRow.DiscountPercent * TabularSectionRow.Amount / 100;
	TabularSectionRow.Amount = TabularSectionRow.Amount - TabularSectionRow.DiscountAmount;
	
	DriveClient.CalculateVATAmount(TabularSectionRow, Object.AmountIncludesVAT);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	If Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.SalesReturn") Then
		TabularSectionRow.CostOfGoodsSold = DriveClient.GetCostAmount(TabularSectionRow.SalesDocument, TabularSectionRow);
	EndIf;
	
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow, "SerialNumbers");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
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
Procedure CheckTransactionsMethodologyAttributes()
	
	If PurchaseFromSupplierOperation 
		Or SalesReturnOperation 
		Or IsDropShippingOperation Then
		FillVATRateByCompanyVATTaxation();
	Else
		ClearContinentalStockTransactionsMethodologyAttributes();
	EndIf;
	
	SetVATTaxationDependantItemsVisibility();
	
EndProcedure

&AtServer
Procedure ClearContinentalStockTransactionsMethodologyAttributes()
	
	For Each ProdRow In Object.Products Do
		
		ProdRow.Price = 0;
		ProdRow.Amount = 0;
		ProdRow.VATAmount = 0;
		ProdRow.Total = 0;
		
		ProdRow.VATRate = Undefined;
		
	EndDo;
	
	Object.DocumentCurrency = Undefined;
	Object.ExchangeRate = 1;
	Object.Multiplicity = 1;
	Object.ContractCurrencyExchangeRate = 1;
	Object.ContractCurrencyMultiplicity = 1;
	Object.DocumentAmount = 0;
	
	Object.VATTaxation = Undefined;
	Object.AmountIncludesVAT = False;
	Object.IncludeVATInPrice = False;
	
	SetVATTaxationDependantItemsVisibility();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.Posted And Not WriteParameters.WriteMode = DocumentWriteMode.UndoPosting Then
			
		If CheckReservedProductsChange() And Object.AdjustedReserved Then
			
			ShowQueryBoxCheckReservedProductsChange();
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	// CWP
	If TypeOf(FormOwner) = Type("ClientApplicationForm")
		AND Find(FormOwner.FormName, "DocumentForm_CWP") > 0 Then
		Notify("CWP_Write_GoodsReceipt", New Structure("Ref, Number, Date", Object.Ref, Object.Number, Object.Date));
	EndIf;
	// End CWP
	
	// begin Drive.FullVersion
	EventName = DriveServerCall.GetNotificationEventName(Object.Ref);
	If Not IsBlankString(EventName) Then
		Notify(EventName);
	EndIf;
	// end Drive.FullVersion
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			TabularSectionName	= "Products";
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, RowToDelete,, UseSerialNumbersBalance);
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
			RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
			For Each RowToRecalculate In RowsToRecalculate Do
				CalculateAmountInTabularSectionLine(RowToRecalculate);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
	EndIf;
	
	StructureData.Insert("Products", TableForImport.UnloadColumn("Products"));
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		AddTabDataToStructure(ThisObject, "Products", StructureData, NewRow);
		
		IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillProductGLAccounts(StructureData);
		EndIf;
		
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	
	If Object.OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer Then
		Items.CompanyVATNumber.Visible = False;
		WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.DestinationVATNumber, FillOnlyEmpty);
	Else
		WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);
	EndIf;
		
EndProcedure

&AtServer
Procedure FillOperationTypeChoiceList()
	
	ChoiceList = Items.OperationType.ChoiceList;
	
	ChoiceList.Clear();
	
	ChoiceList.Add(Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier);
	ChoiceList.Add(Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty);
	ChoiceList.Add(Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty);
	ChoiceList.Add(Enums.OperationTypesGoodsReceipt.SalesReturn);
	
	If GetFunctionalOption("IntraCommunityTransfers") Then
		ChoiceList.Add(Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer);
	EndIf;
	
	If GetFunctionalOption("CanReceiveSubcontractingServices") Then
		ChoiceList.Add(Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor);
		ChoiceList.Add(Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor);
	EndIf;
	
	If GetFunctionalOption("UseDropShipping") Then
		ChoiceList.Add(Enums.OperationTypesGoodsReceipt.DropShipping);
	EndIf;
	
	// begin Drive.FullVersion
	If GetFunctionalOption("CanProvideSubcontractingServices") Then
		ChoiceList.Add(Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer);
	EndIf;
	// end Drive.FullVersion 
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtClient
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
		Or Object.Multiplicity <> NewRatio
		Or Object.ContractCurrencyExchangeRate <> NewContractCurrencyExchangeRate
		Or Object.ContractCurrencyMultiplicity <> NewContractCurrencyRatio Then
		
		QuestionText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",					NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",							NewRatio);
		AdditionalParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		AdditionalParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("RecalculateExchangeRatesEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateExchangeRatesEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
	EndIf;
	
EndProcedure

#Region Reservation

&AtServer
Function PutEditReservationDataToTempStorage()

	DocObject = FormAttributeToValue("Object");
	DataForOwnershipForm = InventoryReservationServer.GetDataFormInventoryReservationForm(DocObject);
	TempStorageAddress = PutToTempStorage(DataForOwnershipForm, UUID);
	
	Return TempStorageAddress;

EndFunction

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.ProductsPrice);
	
	Return Fields;
	
EndFunction

&AtServer
Procedure EditReservationProcessingAtServer(TempStorageAddress)
	
	StructureData = GetFromTempStorage(TempStorageAddress);
	
	Object.AdjustedReserved = StructureData.AdjustedReserved;
	
	If StructureData.AdjustedReserved Then
		Object.Reservation.Load(StructureData.ReservationTable);
	EndIf;
	
	ThisObject.Modified = True;
	
EndProcedure

&AtClient
Procedure EditReservationProcessingAtClient(TempStorageAddress)
	
	EditReservationProcessingAtServer(TempStorageAddress);
	
EndProcedure

&AtClient
Procedure CheckReservedProductsChangeClient(Cancel)

	If Object.Posted Then
			
		If CheckReservedProductsChange() Then
			
			If Object.AdjustedReserved Then
				ShowQueryBoxCheckReservedProductsChange(True);
			Else
				MessagesToUserClient.ShowMessageCannotOpenInventoryReservationWindow();
			EndIf;
			
			Cancel = True;
			Return;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure ShowQueryBoxCheckReservedProductsChange(NeedOpenForm = False)
	
	MessageString = MessagesToUserClient.MessageCleaningWarningInventoryReservation(Object.Ref);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("NeedOpenForm", NeedOpenForm);

	ShowQueryBox(New NotifyDescription("CheckReservedProductsChangeEnd", ThisObject, ParametersStructure),
	MessageString, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure CheckReservedProductsChangeEnd(QuestionResult, AdditionalParameters) Export 
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		Object.AdjustedReserved = False;
		Object.Reservation.Clear();
		
		Try
			Write(WriteParameters);
			
			If AdditionalParameters.Property("NeedOpenForm") And AdditionalParameters.NeedOpenForm Then
				OpenInventoryReservation();
			EndIf;
		Except
			ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		EndTry;
		
		Return;
	EndIf;

EndProcedure

&AtServer
Function CheckReservedProductsChange()
	
	If Object.Reservation.Count()> 0 Then
		
		DocumentObject = FormAttributeToValue("Object");
		
		ParametersData = New Structure;
		ParametersData.Insert("Ref", Object.Ref);
		ParametersData.Insert("TableName", "Products");
		ParametersData.Insert("ProductsChanges", DocumentObject.Products.Unload());
		ParametersData.Insert("UseOrder", True);
		
		Return InventoryReservationServer.CheckReservedProductsChange(ParametersData);
		
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Function ChangeAdjustedReserved()

	Return Object.AdjustedReserved = Common.ObjectAttributeValue(Object.Ref, "AdjustedReserved");

EndFunction

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion