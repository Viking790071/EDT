
#Region Variables

&AtClient
Var ThisIsNewRow;

&AtClient
Var LineCopyInventory;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
EndProcedure

// Procedure - OnCreateAtServer event handler.
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
	
	If Not ValueIsFilled(Object.Ref)
		And ValueIsFilled(Object.Counterparty)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			
			ContractAttributesStructure = Common.ObjectAttributesValues(Object.Contract,
				"SettlementsCurrency,SupplierPriceTypes, DiscountMarkupKind");
			
			If Not ValueIsFilled(Object.DocumentCurrency) Then
				
				Object.DocumentCurrency = ContractAttributesStructure.SettlementsCurrency;
				
				CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
				
				Object.ExchangeRate = ?(CurrencyRateRepetition.ExchangeRate = 0, 1, CurrencyRateRepetition.ExchangeRate);
				Object.Multiplicity = ?(CurrencyRateRepetition.Multiplicity = 0, 1, CurrencyRateRepetition.Multiplicity);
				
			EndIf;
			
			If Not ValueIsFilled(Object.SupplierPriceTypes) Then
				Object.SupplierPriceTypes = ContractAttributesStructure.SupplierPriceTypes;
			EndIf;
			
			If Not ValueIsFilled(Object.DiscountType) Then
				Object.DiscountType = ContractAttributesStructure.DiscountMarkupKind;
			EndIf;
			
			If Object.PaymentCalendar.Count() = 0 Then
				FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	If Not ValueIsFilled(Object.ReceiptDate) Then
		Object.ReceiptDate = DocumentDate;
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	ReceiptDate = Object.ReceiptDate;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency = StructureByCurrency.Rate;
	RepetitionNationalCurrency = StructureByCurrency.Repetition;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	SetAccountingPolicyValues();
	
	InProcessStatus = Constants.PurchaseOrdersInProgressStatus.Get();
	CompletedStatus = Constants.PurchaseOrdersCompletionStatus.Get();
	
	If GetFunctionalOption("UsePurchaseOrderStatuses") Then
		
		Items.Status.Visible = False;
		
	Else
		
		Items.OrderState.Visible = False;
		
		StatusesStructure = Documents.PurchaseOrder.GetPurchaseOrderStringStatuses();
		
		For Each Item In StatusesStructure Do
			Items.Status.ChoiceList.Add(Item.Key, Item.Value);
		EndDo;
		
		ResetStatus();
		
	EndIf;
	
	Items.OperationKind.Visible = GetVisibleOperationKind();
	SetCustomerCounterparty();
	
	UsePurchaseOrderApproval = Constants.UsePurchaseOrderApproval.Get();
	GetApprovalConditions();
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.CopyingValue)
		And Not ValueIsFilled(Object.BankAccount)
		And Not ValueIsFilled(Object.PettyCash) Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	CASE
		|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
		|			THEN Companies.BankAccountByDefault
		|		ELSE UNDEFINED
		|	END AS BankAccount
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Company");
		Query.SetParameter("Company", Object.Company);
		Query.SetParameter("CashCurrency", Object.DocumentCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			Object.BankAccount = Selection.BankAccount;
		EndIf;
		Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
		
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
		Items.DocumentTax.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
		Items.DocumentTax.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("SupplierDiscountKind",			Object.DiscountType);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("SupplierPriceTypes",				Object.SupplierPriceTypes);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ProcessingCompanyVATNumbers();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
		
	SetVisibleAndEnabled();
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings(); 
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	// If the document is opened from pick, fill the tabular section products
	If Parameters.FillingValues.Property("InventoryAddressInStorage") 
		And ValueIsFilled(Parameters.FillingValues.InventoryAddressInStorage) Then
		
		FillingValues = Parameters.FillingValues;
		
		GetInventoryFromStorage(FillingValues.InventoryAddressInStorage, 
							FillingValues.TabularSectionName,
							FillingValues.AreCharacteristics,
							FillingValues.AreBatches);
		
	EndIf;
	
	// Setting contract visible.
	SetContractVisible();
		
	// Cross-references visible.
	UseCrossReferences = Constants.UseProductCrossReferences.Get();
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.PurchaseOrder.TabularSections.Inventory, DataLoadSettings, ThisObject);
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
		
	SetTypeSalesOrder();
		
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	SetSwitchTypeListOfPaymentCalendar();
	
	If GetFunctionalOption("UsePurchaseOrderApproval") Then
		ApprovalStatus = Object.ApprovalStatus;
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If NeedToApprovePurchaseOrder() Then
		
		If Modified
			Or (Object.Posted And WriteParameters.WriteMode = DocumentWriteMode.UndoPosting)
			Or (Not Object.Posted And WriteParameters.WriteMode = DocumentWriteMode.Posting) Then
			
			DocumentModified = True;
		EndIf;
		
		If DocumentModified
			And Not Object.OrderState = CompletedStatus
			And Not UserWarned
			And (ApprovalStatus = PredefinedValue("Enum.ApprovalStatuses.Approved")
				Or ApprovalStatus = PredefinedValue("Enum.ApprovalStatuses.Rejected")) Then
			
			Text = NStr("en = 'The approval status will be reset. Do you want to continue?'; ru = 'Состояние утверждения будет очищено. Продолжить?';pl = 'Status zatwierdzenia zostanie zresetowany. Czy chcesz kontynuować?';es_ES = 'El estado de aprobación será restablecido. Quiere continuar?';es_CO = 'El estado de aprobación será restablecido. Quiere continuar?';tr = 'Onay durumu sıfırlanacak. Devam etmek istiyor musunuz?';it = 'Lo stato di approvazione verrà ripristinato. Continuare?';de = 'Der Genehmigungsstatus wird zurückgesetzt. Möchten Sie fortsetzen?'");
			Notification = New NotifyDescription("ResetApprovalStatusEnd", ThisObject, WriteParameters);
			ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
			
			Cancel = True;
			UserWarned = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(
			MessageText, 
			Object.Contract,
			Object.Ref,
			Object.Company,
			Object.Counterparty,
			Object.OperationKind,
			Cancel,
			CounterpartyAttributes.DoOperationsByContracts);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Document is not posted.'; ru = 'Документ не проведен.';pl = 'Dokument niezaksięgowany.';es_ES = 'El documento no se ha publicado.';es_CO = 'El documento no se ha publicado.';tr = 'Belge kaydedilmedi.';it = 'Il documento non è pubblicato.';de = 'Dokument ist nicht gebucht.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
			EndIf;
			Message.Message();
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	If Modified
		Or (CurrentObject.Posted And WriteParameters.WriteMode = DocumentWriteMode.UndoPosting)
		Or (Not CurrentObject.Posted And WriteParameters.WriteMode = DocumentWriteMode.Posting) Then
		
		DocumentModified = True;
	EndIf;
	
EndProcedure

// Procedure - event handler OnOpen.
//
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
	
	FormManagement();
	SetVisibleEnablePaymentTermItems();
	
	RecalculateSubtotal();
	
	OperationKindBeforeChange = Object.OperationKind;
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
	If NotifyWorkCalendar Then
		Notify("ChangedOrderVendor", Object.Responsible);
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
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
	
	If EventName = "AfterRecordingOfCounterparty"
		And ValueIsFilled(Parameter)
		And Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetContractVisible();
		
	EndIf;
	
	If EventName = "Write_PurchaseApproval"
		And UsePurchaseOrderApproval Then 
		Read();
		FormManagement();
	EndIf;
	
EndProcedure

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
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

#Region FormHeaderItemsEventHandlers

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

// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ProcessContractChange();
	
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	If OperationKindBeforeChange = Object.OperationKind Then
		Return;
	EndIf;
	
	If OperationKindBeforeChange <> Object.OperationKind 
		And (Object.Inventory.Count() > 0 Or Object.Materials.Count() > 0)Then
		
		StringOperationKind = "";
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForDropShipping") Then
			StringOperationKind = NStr("en = 'Drop shipping'; ru = 'Дропшиппинг';pl = 'Dropshipping';es_ES = 'Envío directo';es_CO = 'Envío directo';tr = 'Stoksuz satış';it = 'Dropshipping';de = 'Streckengeschäft'");
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForProcessing") Then
			StringOperationKind = NStr("en = 'Subcontracting'; ru = 'Переработка';pl = 'Podwykonawstwo';es_ES = 'Subcontratación';es_CO = 'Subcontratación';tr = 'Taşeronluk';it = 'Subfornitura';de = 'Subunternehmerbestellung'");
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForPurchase") Then
			StringOperationKind = NStr("en = 'Purchase order'; ru = 'Заказ поставщику';pl = 'Zamówienie zakupu';es_ES = 'Orden de compra';es_CO = 'Orden de compra';tr = 'Satın alma siparişi';it = 'Ordine di acquisto';de = 'Bestellung an Lieferanten'");
		EndIf;
		
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("OperationKindOnChangeEnd", ThisObject);
		If StringOperationKind = "" Then
			TextQuery = NStr("en = 'After you clear the operation, all Purchase order tabs will be cleared. 
							|Continue? '; 
							|ru = 'После удаления операции все вкладки заказа поставщику будут очищены. 
							|Продолжить? ';
							|pl = 'Po odznaczeniu operacji, wszystkie karty Zamówienie zakupu zostaną wyczyszczone. 
							|Kontynuować? ';
							|es_ES = 'Después de eliminar la operación, todas las pestañas Orden de compra serán eliminadas. 
							|¿Continuar?  ';
							|es_CO = 'Después de eliminar la operación, todas las pestañas Orden de compra serán eliminadas. 
							|¿Continuar?  ';
							|tr = 'İşlemi sildiğinizde tüm Satın alma siparişi sekmeleri temizlenecek. 
							|Devam edilsin mi?';
							|it = 'Dopo aver cancellato l''operazione, tutte le schede Ordine di acquisto saranno cancellate. 
							|Continuare? ';
							|de = 'Nachdem Sie die Operation löschen, werden die Registerkarten Bestellung an Lieferanten entleert. 
							|Fortfahren? '");
		ElsIf OperationKindBeforeChange = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForProcessing") Then
			TextQuery = NStr("en = 'After you change the operation to %1, all Purchase order tabs will be cleared. 
							|Continue?'; 
							|ru = 'После изменения операции на %1 все вкладки заказа поставщику будут очищены. 
							|Продолжить?';
							|pl = 'Po zmianie operacji na %1, wszystkie karty Zamówienie zakupu zostaną wyczyszczone. 
							|Kontynuować?';
							|es_ES = 'Después de cambiar la operación a %1, todas las pestañas Orden de compra se eliminarán.
							|¿Continuar?';
							|es_CO = 'Después de cambiar la operación a %1, todas las pestañas Orden de compra se eliminarán.
							|¿Continuar?';
							|tr = 'İşlemi %1 olarak değiştirdiğinizde tüm Satın alma siparişi sekmeleri temizlenecek. 
							|Devam edilsin mi?';
							|it = 'Dopo aver modificato l''operazione in %1, tutte le schede Ordine di acquisto saranno cancellate. 
							|Continuare?';
							|de = 'Nachdem Sie die Operation auf %1 ändern, werden die Registerkarten Bestellung an Lieferanten entleert. 
							|Fortfahren?'");
			TextQuery = StringFunctionsClientServer.SubstituteParametersToString(TextQuery, StringOperationKind);
		Else
			TextQuery = NStr("en = 'After you change the operation to %1, the Products tab will be cleared. 
							|Continue?'; 
							|ru = 'После изменения операции на %1 вкладка Номенклатура будет очищена. 
							|Продолжить?';
							|pl = 'Po zmianie operacji na %1, karta Produkty zostanie wyczyszczona. 
							|Kontynuować?';
							|es_ES = 'Después de cambiar la operación a %1, la pestaña de Productos se eliminará. 
							|¿Continuar?';
							|es_CO = 'Después de cambiar la operación a %1, la pestaña de Productos se eliminará. 
							|¿Continuar?';
							|tr = 'İşlemi %1 olarak değiştirdiğinizde Ürünler sekmesi temizlenecek. 
							|Devam edilsin mi?';
							|it = 'Dopo aver modificato l''operazione in %1, la scheda Articoli sarà cancellata. 
							|Continuare?';
							|de = 'Nachdem Sie die Operation auf %1 ändern, werden die Registerkarten Bestellung an Lieferanten entleert. 
							|Fortfahren?'");
			TextQuery = StringFunctionsClientServer.SubstituteParametersToString(TextQuery, StringOperationKind);
		EndIf;
		ShowQueryBox(Notification, TextQuery, Mode, 0);
		
		Return;
		
	Else 
		
		ProcessOperationKindChange();
		ProcessContractChange();
		OperationKindBeforeChange = Object.OperationKind;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationKindOnChangeEnd(Result, ParametersStructure) Export
	
	If Result = DialogReturnCode.No Then
		
		Object.OperationKind = OperationKindBeforeChange;
		Return;
		
	EndIf;
	
	Object.Inventory.Clear();
	ProcessOperationKindChange();
	ProcessContractChange();
	OperationKindBeforeChange = Object.OperationKind;
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		StructureData.Insert("CounterpartyChanged", True);
		ProcessContractChange(StructureData);
		
		GenerateLabelPricesAndCurrency();
		SetVisibleEnablePaymentTermItems();
		
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
Procedure StructuralUnitReserveOnChange(Item)
	StructuralUnitReserveAtServer();
EndProcedure

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormOfContractParameters(
		Object.Ref,
		Object.Company,
		Object.Counterparty,
		Object.Contract,
		Object.OperationKind,
		CounterpartyAttributes.DoOperationsByContracts);
		
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the OrderState input field.
//
&AtClient
Procedure OrderStateOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then 
		Object.Closed = False;
	EndIf;
		
	If Not TrimAll(Status) = "Open" Then
		Items.SetPaymentTerms.Enabled = True;
	EndIf;
	
	ChangeApprovalStatus();
	SetVisibleAndEnabled();
	FormManagement();
	
EndProcedure
	
&AtClient
Procedure OrderStateStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ChoiceData = GetPurchaseOrderStates();
EndProcedure

&AtClient
Procedure ReceiptDateOnChange(Item)
	
	If ReceiptDate <> Object.ReceiptDate Then
		DatesChangeProcessing();
	EndIf;

EndProcedure

&AtClient
Procedure ApprovalStatusClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not Object.Ref.IsEmpty()
		And Not Modified Then
		
		FormParameters = GetFormParameters(Object.Ref);
		OpenForm(FormParameters.FormName, FormParameters.Parameters);
		
	Else
		
		Notification = New NotifyDescription(
			"BeforeOpeningBusinessProcess", ThisObject);
			
		QueryText = NStr(
			"en = 'To switch to another page you must save your work.
			|Click OK to save and continue, 
			|or click Cancel to return.'; 
			|ru = 'Для перехода на другую страницу необходимо сохранить результаты работы.
			|Нажмите OK, чтобы сохранить данные и продолжить, 
			|или Отмена для возврата.';
			|pl = 'Aby przejść do innej strony, musisz zapisać swoją pracę.
			|Kliknij na OK, aby zapisać i kontynuować, lub kliknij Anuluj,
			|aby wrócić.';
			|es_ES = 'Para pasar a la creación del contacto usted debe guardar su trabajo.
			|Pulse OK para guardar y continuar
			|o pulse Cancelar para volver.';
			|es_CO = 'Para pasar a la creación del contacto usted debe guardar su trabajo.
			|Pulse OK para guardar y continuar
			|o pulse Cancelar para volver.';
			|tr = 'Başka bir sayfaya geçmek için çalışmanızı kaydetmeniz gerekir.
			|Kaydedip devam etmek için Tamam''a, 
			|geri dönmek için İptal''e tıklayın.';
			|it = 'Per passare ad un''altra pagina dovete salvare il vostro lavoro.
			|Premere OK per salvare e continuare,
			|o premere Annulla per ritornare.';
			|de = 'Um zu einer anderen Seite zu wechseln, müssen Sie Ihre Arbeit speichern.
			|Klicken Sie auf OK, um zu speichern und fortzufahren,
			|oder klicken Sie auf Abbrechen, um zurückzukehren.'");
		
		ShowQueryBox(Notification, QueryText, QuestionDialogMode.OKCancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	SetTypeSalesOrder();
	
EndProcedure

#Region Delivery

&AtClient
Procedure ShippingAddressOnChange(Item)
	ProcessShippingAddressChange();
EndProcedure

#EndRegion

#EndRegion

#Region InventoryFormTableItemsEventHandlers

// Procedure - OnEditEnd event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	If LineCopyInventory = Undefined Or Not LineCopyInventory Then
		RecalculateSubtotal();
	Else
		LineCopyInventory = False;
	EndIf;
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - AfterDeletion event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("DiscountType", Object.DiscountType);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Counterparty", 	Object.Counterparty);
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("Products", 		TabularSectionRow.Products);
	StructureData.Insert("Characteristic", 	TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", 			Object.Date);
		StructureData.Insert("DocumentCurrency", 		Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 		Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 				TabularSectionRow.VATRate);
		StructureData.Insert("Price", 					TabularSectionRow.Price);
		
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
		
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	StructureData.Property("CrossReference", TabularSectionRow.CrossReference);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	
	TabularSectionRow.Specification = StructureData.Specification;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
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

// Procedure - event handler OnChange of the CrossReference input field.
//
&AtClient
Procedure InventoryCrossReferenceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("CrossReference", TabularSectionRow.CrossReference);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	StructureData = GetDataCrossReferenceOnChange(StructureData, Object.Date);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler AutoPick of the Content input field.
//
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

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		Or TabularSectionRow.Price = 0 Then
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
	
	If CurrentFactor = 0 And Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 And Factor = 1 Then
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
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryDiscountPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryDiscountAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.DiscountPercent = 100 Then
		TabularSectionRow.DiscountAmount = TabularSectionRow.Amount;
	Else
		TabularSectionRow.DiscountAmount = (TabularSectionRow.Amount / (100 - TabularSectionRow.DiscountPercent))
											* TabularSectionRow.DiscountPercent;
	EndIf;
	
	AmountWithoutDiscount = TabularSectionRow.Amount + TabularSectionRow.DiscountAmount;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = AmountWithoutDiscount / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
	ChangeApprovalStatus();
	FormManagement();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryIncreaseDateOnChange(Item)
	DatesChangeProcessing();
EndProcedure

#EndRegion

#Region MaterialsFormTableItemsEventHandlers

&AtClient
Procedure MaterialsOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Or Clone Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;

EndProcedure

&AtClient
Procedure MaterialsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "MaterialsGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials", , ReadOnly);
	EndIf;
	
EndProcedure

&AtClient
Procedure MaterialsOnActivateCell(Item)
	
	CurrentData = Items.Materials.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Materials.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure MaterialsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure MaterialsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Materials.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials");
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure MaterialsProductsOnChange(Item)
	
	TabularSectionRow = Items.Materials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Materials", StructureData);
	StructureData = GetDataProductsOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	
EndProcedure

&AtClient
Procedure MaterialsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Materials.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Materials";
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

#EndRegion

#Region PaymentCalendarFormTableItemsEventHandlers

// Procedure - event handler OnChange of the ReflectInPaymentCalendar input field.
//
&AtClient
Procedure SetPaymentTermsOnChange(Item)
	
	If Object.SetPaymentTerms Then
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar, True);
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'; ru = 'Условия оплаты будут очищены. Продолжить?';pl = 'Warunki płatności zostaną wyczyszczone. Czy chcesz kontynuować?';es_ES = 'Los términos de pagos se eliminarán. ¿Quiere continuar?';es_CO = 'Los términos de pagos se eliminarán. ¿Quiere continuar?';tr = 'Ödeme şartları silinecek. Devam etmek istiyor musunuz?';it = 'I termini di pagamento saranno cancellati. Continuare?';de = 'Die Zahlungsbedingungen werden gelöscht. Möchten Sie fortfahren?'");
		ShowQueryBox(Notify, QueryText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field SwitchTypeListOfPaymentCalendar.
//
&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	LineCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar And LineCount > 1 Then
		Response = Undefined;
		ShowQueryBox(
			New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)),
			NStr("en = 'All lines except for the first one will be deleted. Continue?'; ru = 'Все строки кроме первой будут удалены. Продолжить?';pl = 'Wszystkie wiersze za wyjątkiem pierwszego zostaną usunięte. Kontynuować?';es_ES = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';es_CO = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';tr = 'İlki haricinde tüm satırlar silinecek. Devam edilsin mi?';it = 'Tutte le linee eccetto la prima saranno cancellate. Continuare?';de = 'Alle Zeilen bis auf die erste werden gelöscht. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	SetVisiblePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentPercent input field.
//
&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount = Round(Object.Inventory.Total("Amount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("Amount");
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("VATAmount");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
EndProcedure

// Procedure - OnStartEdit event handler of the .PaymentCalendar list
//
&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If NewRow Then
		CurrentRow.PaymentBaselineDate = PredefinedValue("Enum.BaselineDateForPayment.PostingDate");
	EndIf;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Object.Inventory.Total("Amount") - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Inventory.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;
	
EndProcedure

// Procedure - BeforeDeletion event handler of the PaymentCalendar tabular section.
//
&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
EndProcedure

// Procedure - click handler on the FillByBasis button.
//
&AtClient
Procedure FillByRFQ(Command)
	
	If Not ValueIsFilled(Object.RFQResponse) Then
		MessagesToUserClient.ShowMessageSelectRFQResponse();
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(
		New NotifyDescription("FillByRFQEnd", ThisObject),
		NStr("en = 'The document will be completely refilled on the ""RFQ response."" Continue?'; ru = 'Документ будет полностью перезаполнен по ""Ответ на запрос коммерческого предложения""! Продолжить выполнение операции?';pl = 'Cały dokument zostanie wypełniony ponownie zgodnie z ""Odpowiedź na zapytanie ofertowe"". Kontynuować?';es_ES = 'El documento se volverá a rellenar completamente en la ""Respuesta de la solicitud de presupuesto"". ¿Continuar?';es_CO = 'El documento se volverá a rellenar completamente en la ""Respuesta de la solicitud de presupuesto"". ¿Continuar?';tr = 'Belge, ""Satın alma talebi"" üzerine tamamen doldurulacaktır. Devam et?';it = 'Il documento sarà completamente ricompilato su ""Offerta fornitore"". Continuare?';de = 'Das Dokument wird in der ""Antwort auf die Angebotsanfrage"" vollständig aufgefüllt. Fortsetzen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByRFQEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		FillByDocument(Object.RFQResponse);
		
		SetVisibleEnablePaymentTermItems();
		GenerateLabelPricesAndCurrency();
		
	EndIf;

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
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
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
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
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
		And Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ReceiptDatePositionInPurchaseOrder", 	Object.ReceiptDatePosition);
	ParametersStructure.Insert("SalesOrderPositionInShipmentDocuments", Object.SalesOrderPosition);
	ParametersStructure.Insert("RenameSalesOrderPositionInShipmentDocuments", NStr("en = 'Reserve for position in Purchase order'; ru = 'Положение строки ""Резерв для"" в заказе поставщику';pl = 'Pozycja rezerwa dla w Zamówieniu zakupu';es_ES = 'Reserva de posición en el pedido de compra';es_CO = 'Reserva de posición en el pedido de compra';tr = 'Satın alma siparişinde ""Rezerve et"" pozisyonu';it = 'Riserva per posizione nell''Ordine di acquisto';de = 'Reserve für Position in Bestellung an Lieferanten'"));
	ParametersStructure.Insert("WereMadeChanges", 						False);
	
	StructureDocumentSetting = Undefined;

	TableObject = Object.Inventory;
	InvCount = TableObject.Count();
	If InvCount > 1 Then
		
		CurrOrder = TableObject[0].SalesOrder;
		MultipleOrders = False;
		
		For Index = 1 To InvCount - 1 Do
			
			If CurrOrder <> TableObject[Index].SalesOrder Then
				MultipleOrders = True;
				Break;
			EndIf;
			
			CurrOrder = TableObject[Index].SalesOrder;
			
		EndDo;
		
		If MultipleOrders Then
			ParametersStructure.Insert("ReadOnly", True);
		EndIf;
		
	EndIf;

	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	// 2. Open the form "Prices and Currency".
	StructureDocumentSetting = Result;
	
	// 3. Apply changes made in "Document setting" form.
	If TypeOf(StructureDocumentSetting) = Type("Structure") And StructureDocumentSetting.WereMadeChanges Then
		
		Object.ReceiptDatePosition = StructureDocumentSetting.ReceiptDatePositionInPurchaseOrder;
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInShipmentDocuments;
		
		If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			
			If Object.Inventory.Count() Then
				Object.SalesOrder = Object.Inventory[0].SalesOrder;
			EndIf;
			
		Else
			
			If ValueIsFilled(Object.SalesOrder) Then
				For Each InventoryRow In Object.Inventory Do
					If Not ValueIsFilled(InventoryRow.SalesOrder) Then
						InventoryRow.SalesOrder = Object.SalesOrder;
					EndIf;
				EndDo;
				
				Object.SalesOrder = Undefined;
			EndIf;
			
		EndIf;

		PrevReceiptDateVisible = Items.ReceiptDate.Visible;
		
		SetVisibleFromUserSettings();
				
		If PrevReceiptDateVisible = False // It was in TS.
			And Items.ReceiptDate.Visible = True Then // It is in the header.
			
			DatesChangeProcessing();
		EndIf;
		
		Modified = True;
		
	EndIf;

EndProcedure

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeReserveFillByBalances(Command)
	
	If Object.Materials.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Tabular section ""Materials"" is not filled in.'; ru = 'Табличная часть ""Материалы"" не заполнена!';pl = 'Nie wypełniono sekcji tabelarycznej ""Materiały"".';es_ES = 'Sección tabular ""Materiales"" no está rellenada.';es_CO = 'Sección tabular ""Materiales"" no está rellenada.';tr = '""Malzemeler"" tablo bölümü doldurulmadı.';it = 'La sezione tabellare ""Materiali"" non è  compilata!';de = 'Tabellenabschnitt ""Materialien"" ist nicht ausgefüllt.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByBalancesAtServer();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Materials.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Tabular section ""Materials"" is not filled in.'; ru = 'Табличная часть ""Материалы"" не заполнена!';pl = 'Nie wypełniono sekcji tabelarycznej ""Materiały"".';es_ES = 'Sección tabular ""Materiales"" no está rellenada.';es_CO = 'Sección tabular ""Materiales"" no está rellenada.';tr = '""Malzemeler"" tablo bölümü doldurulmadı.';it = 'La sezione tabellare ""Materiali"" non è  compilata!';de = 'Tabellenabschnitt ""Materialien"" ist nicht ausgefüllt.'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Materials Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

// Procedure - event handler OnChange input field Status.
//
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
	
	ChangeApprovalStatus();
	FormManagement();
	
EndProcedure

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

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the purchase order?'; ru = 'Перезаполнить заказ поставщику?';pl = 'Czy chcesz ponownie wypełnić zamówienie zakupu?';es_ES = '¿Quiere volver a rellenar el pedido de compra?';es_CO = '¿Quiere volver a rellenar el pedido de compra?';tr = 'Satın alma siparişini yeniden doldurmak istiyor musunuz?';it = 'Ricompilare l''ordine di acquisto?';de = 'Möchten Sie die Bestellung an Lieferanten neu auffüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByOrder(Command)
	
	If ValueIsFilled(Object.SalesOrder) Then
		
		Response = Undefined;
		
		If TypeOf(Object.SalesOrder) = Type("DocumentRef.SalesOrder") Then
			Message = NStr("en = 'The document will be repopulated from the selected Sales order. Do you want to continue?'; ru = 'Документ будет перезаполнен из выбранного заказа покупателя. Продолжить?';pl = 'Dokument zostanie ponownie wypełniony z wybranego Zamówienia sprzedaży. Czy chcesz kontynuować?';es_ES = 'El documento se volverá a rellenar de la orden de ventas seleccionada. ¿Quiere continuar?';es_CO = 'El documento se volverá a rellenar de la orden de ventas seleccionada. ¿Quiere continuar?';tr = 'Belge, seçilen Satış siparişinden yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'Il documento sarà ripopolato dall''Ordine cliente selezionato. Continuare?';de = 'Das Dokument wird aus dem ausgewählten Kundenauftrag neu aufgefüllt. Weiter?'");
		ElsIf TypeOf(Object.SalesOrder) = Type("DocumentRef.WorkOrder") Then
			Message = NStr("en = 'The document will be repopulated from the selected Work order. Do you want to continue?'; ru = 'Документ будет перезаполнен из выбранного заказа-наряда. Продолжить?';pl = 'Dokument zostanie ponownie wypełniony z wybranego Zlecenia pracy. Czy chcesz kontynuować?';es_ES = 'El documento se volverá a rellenar de la orden de trabajo seleccionada. ¿Quiere continuar?';es_CO = 'El documento se volverá a rellenar de la orden de trabajo seleccionada. ¿Quiere continuar?';tr = 'Belge, seçilen İş emrinden tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'Il documento sarà ripopolato a partire dalla commessa selezionata. Continuare?';de = 'Das Dokument wird aus dem ausgewählten Arbeitsauftrag neu aufgefüllt. Weiter?'");
		EndIf;
		
		ShowQueryBox(New NotifyDescription("FillByOrderEnd", ThisObject), Message, QuestionDialogMode.YesNo, 0);
	Else
		MessagesToUserClient.ShowMessageSelectOrder();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByOrderEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Object.Inventory.Clear();
		FillByDocument(Object.SalesOrder);
		SetVisibleAndEnabled();
	EndIf;
	
EndProcedure

#Region TabularSectionCommandpanelsActions

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Materials.Count() <> 0 Then
		
		Response = Undefined;

		NotifyDescription = New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject);
		ShowQueryBox(NotifyDescription,
						NStr("en = 'Tabular section ""Own materials"" will be filled in again. Do you want to continue?'; ru = 'Табличная часть ""Материалы в переработку"" будет перезаполнена. Продолжить?';pl = 'Sekcja tabelaryczna ""Materiały do przetwarzania"" zostanie wypełniona ponownie. Czy chcesz kontynuować?';es_ES = 'La parte tabular ""Materias primas suministradas"" será rellenada de nuevo. ¿Quiere continuar?';es_CO = 'La parte tabular ""Materias primas suministradas"" será rellenada de nuevo. ¿Quiere continuar?';tr = '""Tedarik edilen hammaddeler"" tablo bölümü tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'La sezione tabellare ""Propri materiali"" sarà ricompilata. Continuare?';de = 'Der tabellarische Abschnitt ""Eigene Rohmaterialien"" wird erneut ausgefüllt. Möchten Sie fortsetzen?'"), 
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

#EndRegion

#Region Private

#Region GeneralPurposeProceduresAndFunctions

&AtServer
Procedure ResetStatus()
	
	If Not GetFunctionalOption("UsePurchaseOrderStatuses") Then
		
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
Procedure GenerateLabelPricesAndCurrency()
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("SupplierDiscountKind",			Object.DiscountType);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("SupplierPriceTypes",				Object.SupplierPriceTypes);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
// The procedure handles the change of the Price type and Settlement currency document attributes
//
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	ContractData = DocumentParameters.ContractData;
	QueryPriceKind = DocumentParameters.QueryPriceKind;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	RecalculationRequired = DocumentParameters.RecalculationRequired;
	ModifiedDiscountType = DocumentParameters.ModifiedDiscountType;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
		
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate = ?(ContractData.SettlementsCurrencyRateRepetition.Rate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
	EndIf;
	
	If PriceKindChanged Then
		
		Object.SupplierPriceTypes	= ContractData.SupplierPriceTypes;
		
	EndIf;
	
	If ModifiedDiscountType Then
		
		Object.DiscountType = ContractData.DiscountType;
		
	EndIf;
	
	If Object.DocumentCurrency <> ContractData.SettlementsCurrency Then
		
		Object.BankAccount = Undefined;
		
	EndIf;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If PriceKindChanged Or ModifiedDiscountType Then
			
			WarningText = MessagesToUserClientServer.GetPriceTypeOnChangeWarningText();
			
		EndIf;
		
		WarningText = WarningText
				+ ?(IsBlankString(WarningText), "", Chars.LF + Chars.LF)
				+ MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, PriceKindChanged, WarningText);
		
	ElsIf QueryPriceKind Then
		
		GenerateLabelPricesAndCurrency();
		
		If RecalculationRequired Then
			
			QuestionText = MessagesToUserClientServer.GetDiscountOnChangeText();
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	DocumentDate = Object.Date;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange()
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	ProcessingCompanyVATNumbers();
	FillVATRateByCompanyVATTaxation();
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If Object.DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	DatesChangeProcessing();
	
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	StructureData.Insert("BankAccount", Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Company.BankAccountByDefault.CashCurrency);
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
		
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined)
	
	Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureData);
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products,
		"MeasurementUnit, VATRate, ReplenishmentMethod");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	
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
	
	If Not ObjectDate = Undefined Then
		Specification = Undefined;
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		ElsIf ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		EndIf;
		StructureData.Insert("Specification", Specification);
		
	EndIf;
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting And StructureData.Property("GLAccounts") Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	If StructureData.Property("DiscountType") Then
		StructureData.Insert("DiscountPercent", Common.ObjectAttributeValue(StructureData.DiscountType, "Percent"));
	Else
		StructureData.Insert("DiscountPercent", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate = Undefined)
	
	Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureData);
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;		
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;	
	
	If Not ObjectDate = Undefined Then
		Specification = Undefined;
		ProductsReplenishmentMethod = Common.ObjectAttributeValue(StructureData.Products, "ReplenishmentMethod");
		If ProductsReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		ElsIf ProductsReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		EndIf;
		StructureData.Insert("Specification", Specification);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataCrossReferenceOnChange(StructureData, ObjectDate)
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.CrossReference, 
		"Products, Characteristic, Products.MeasurementUnit, Products.VATRate, Products.ReplenishmentMethod"); 
	
	StructureData.Insert("Products", ProductsAttributes.Products);
	StructureData.Insert("Characteristic", ProductsAttributes.Characteristic);
	StructureData.Insert("MeasurementUnit", ProductsAttributes.ProductsMeasurementUnit);
	
	If StructureData.Property("VATTaxation") 
		And Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products) And ValueIsFilled(ProductsAttributes.ProductsVATRate) Then
		StructureData.Insert("VATRate", ProductsAttributes.ProductsVATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If Not ObjectDate = Undefined Then
		Specification = Undefined;
		If ProductsAttributes.ProductsReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		ElsIf ProductsAttributes.ProductsReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		EndIf;
		StructureData.Insert("Specification", Specification);
	EndIf;
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.Property("DiscountType") Then
		StructureData.Insert("DiscountPercent", Common.ObjectAttributeValue(StructureData.DiscountType, "Percent"));
	Else
		StructureData.Insert("DiscountPercent", 0);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting And StructureData.Property("GLAccounts") Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
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

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	FillVATRateByCompanyVATTaxation(True);
	SetContractVisible();
	
	If UseCrossReferences Then
		FillCrossReference(True);
	EndIf;
	
	GetApprovalConditions();
	
	Return DriveServer.GetDataCounterpartyOnChange(Object.Ref, Date, Counterparty, Company);
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract, Company)
	
	Return DriveServer.GetDataContractOnChange(Date, DocumentCurrency, Contract, Company);
	
EndFunction

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsCounterpartyOnChange = False)
	
	If Not WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, False)
		Or Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT
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

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
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
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
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

&AtServer
Procedure StructuralUnitReserveAtServer()
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;

EndProcedure

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
	TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
	TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	TabularSectionRow.DiscountAmount = TabularSectionRow.DiscountPercent * TabularSectionRow.Amount / 100;
	TabularSectionRow.Amount = TabularSectionRow.Amount - TabularSectionRow.DiscountAmount;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	ChangeApprovalStatus();
	FormManagement();
	
EndProcedure

// Procedure recalculates subtotal
//
&AtClient
Procedure RecalculateSubtotal()
	
	Totals = CalculateSubtotal(Object.Inventory, Object.AmountIncludesVAT);
	FillPropertyValues(ThisObject, Totals);
	
EndProcedure

&AtServerNoContext
Function CalculateSubtotal(Val TabularSection, AmountIncludesVAT)
	
	Return DriveServer.CalculateSubtotalPurchases(TabularSection.Unload(), AmountIncludesVAT);
	
EndFunction

// Recalculates the exchange rate and exchange rate multiplier of
// the payment currency when the document date is changed.
//
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
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate", NewExchangeRate);
		QuestionParameters.Insert("NewRatio", NewRatio);
		QuestionParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		QuestionParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd",
			ThisObject, 
			QuestionParameters);
		
		MessageText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorFragment()
	
	GenerateLabelPricesAndCurrency();
	
EndProcedure

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
		
	// 1. Form parameter structure to fill the "Prices and Currency" form.
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
	ParametersStructure.Insert("Company",						ParentCompany);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
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

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
		Items.DocumentTax.Visible = True;

	Else	
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
		Items.DocumentTax.Visible = False;
	EndIf;
	
	SetContractVisible();
	
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
			StructureProductsData.Insert("Counterparty", StructureData.Counterparty);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			StructureProductsData.Insert("DiscountType", StructureData.DiscountType);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			If ValueIsFilled(StructureData.SupplierPriceTypes) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsData.Insert("SupplierPriceTypes", StructureData.SupplierPriceTypes);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					And TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit = BarcodeData.Products.MeasurementUnit;
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
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("DiscountType", Object.DiscountType);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewRow.DiscountPercent = BarcodeData.StructureProductsData.DiscountPercent;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
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
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification
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
	
EndProcedure

// End Peripherals

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
EndProcedure

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, OperationKind, Cancel, IsOperationsByContracts)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		Or Not IsOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document, OperationKind);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		And Constants.CheckContractsOnPosting.Get() Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract, OperationKind, IsOperationsByContracts)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", IsOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationKind);
	
EndFunction

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
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Materials");
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Materials");
	
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

// Performs actions when the operation kind changes.
//
&AtServer
Procedure ProcessOperationKindChange()
	
	SetVisibleAndEnabled();
	Object.Materials.Clear();
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	
EndProcedure

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract, Object.Company);
			
		EndIf;
		
		PriceKindChanged = Object.SupplierPriceTypes <> ContractData.SupplierPriceTypes
			Or ContractData.Property("CounterpartyChanged");
		ModifiedDiscountType = (Object.DiscountType <> ContractData.DiscountType);
		QueryPriceKind = ValueIsFilled(Object.Contract) And (PriceKindChanged Or ModifiedDiscountType);
		
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
			And ValueIsFilled(SettlementsCurrency)
			And Object.DocumentCurrency <> ContractData.SettlementsCurrency
			And Object.Inventory.Count() > 0;
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("ModifiedDiscountType", ModifiedDiscountType);
		DocumentParameters.Insert("RecalculationRequired", Object.Inventory.Count() > 0);
		
		ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
		GetApprovalConditions();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesBillsOfMaterialstack = New Array;
	Document.FillTabularSectionBySpecification(NodesBillsOfMaterialStack);
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessChangesOnButtonPricesAndCurrenciesAtServer(ClosingResult)
	
	// Recalculate the amount if VAT taxation flag is changed.
	If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
	GetApprovalConditions();
	
EndProcedure

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName 	= "Inventory";
	DocumentPresentaion	= NStr("en = 'purchase order'; ru = 'заказ поставщику';pl = 'zamówienie zakupu';es_ES = 'orden de compra';es_CO = 'orden de compra';tr = 'satın alma siparişi';it = 'ordine di acquisto';de = 'bestellung an lieferanten'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject,
		TabularSectionName, DocumentPresentaion, True, False, True);
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("Counterparty", Counterparty);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnitReserve);
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

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure MaterialsPick(Command)
	
	TabularSectionName 	= "Materials";
	DocumentPresentaion	= NStr("en = 'purchase order'; ru = 'заказ поставщику';pl = 'zamówienie zakupu';es_ES = 'orden de compra';es_CO = 'orden de compra';tr = 'satın alma siparişi';it = 'ordine di acquisto';de = 'bestellung an lieferanten'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, True);
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnitReserve);
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
		If TabularSectionName = "Inventory" Then
			NewRow.DiscountPercent = Common.ObjectAttributeValue(Object.DiscountType, "Percent");
			
			// Fill supplier price
			If NewRow.Price = 0 And ValueIsFilled(Object.SupplierPriceTypes) Then
				StructureData = New Structure;
				StructureData.Insert("Company", 			Object.Company);
				StructureData.Insert("Counterparty", 		Object.Counterparty);
				StructureData.Insert("Products", 			NewRow.Products);
				StructureData.Insert("Characteristic",		NewRow.Characteristic);
				StructureData.Insert("ProcessingDate",		Object.Date);
				StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
				StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
				StructureData.Insert("VATRate",				NewRow.VATRate);
				StructureData.Insert("Price",				NewRow.Price);
				StructureData.Insert("SupplierPriceTypes",	Object.SupplierPriceTypes);
				StructureData.Insert("MeasurementUnit",		NewRow.MeasurementUnit);
				StructureData = GetDataCharacteristicOnChange(StructureData);
				StructureData.Property("CrossReference",	NewRow.CrossReference);
				
				NewRow.Price = StructureData.Price;
				NewRow.Content = "";
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				NewRow.DiscountAmount = NewRow.DiscountPercent * NewRow.Amount / 100;
				NewRow.Amount = NewRow.Amount - NewRow.DiscountAmount;
				VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
				NewRow.VATAmount = ?(Object.AmountIncludesVAT, 
				NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
				NewRow.Amount * VATRate / 100);
				NewRow.Total = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
			EndIf;
		
		EndIf;
		
		If TabularSectionName = "Materials" Then
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
			
			If UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			CurrentPagesInventory	= (Items.Pages.CurrentPage = Items.GroupInventory);
			TabularSectionName		= ?(CurrentPagesInventory, "Inventory", "Materials");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
			If CurrentPagesInventory Then
				
				// Cash flow projection.
				PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
				RecalculateSubtotal();
				
			EndIf;
			
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
			CurrentPagesInventory		= (Items.Pages.CurrentPage = Items.GroupInventory);
			TabularSectionName			= ?(CurrentPagesInventory, "Inventory", "Materials");
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
			If CurrentPagesInventory Then
				
				// Payment calendar.
				PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
				RecalculateSubtotal();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	IsDropShipping = False;
	
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;

	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForPurchase")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForDropShipping") Then
		Items.GroupMaterials.Visible = False;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForProcessing") Then
		Items.GroupMaterials.Visible = True;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForDropShipping") Then
		IsDropShipping = True;
	EndIf;
	
	// Products.
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForPurchase") 
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForDropShipping") Then
		NewArray = New Array();
		NewArray.Add(Enums.ProductsTypes.InventoryItem);
		NewArray.Add(Enums.ProductsTypes.Service);
		ArrayInventoryAndExpenses = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayInventoryAndExpenses);
		NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryAndExpenses);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		// Bundles
		NewParameter = New ChoiceParameter("Filter.IsBundle", False);
		NewArray.Add(NewParameter);
		// End Bundles
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryProducts.ChoiceParameters = NewParameters;
		
		Items.GroupInventory.Title = NStr("en = 'Products'; ru = 'Номенклатура';pl = 'Produkty';es_ES = 'Productos';es_CO = 'Productos';tr = 'Ürünler';it = 'Articoli';de = 'Produkte'");
		
	Else
		NewParameter = New ChoiceParameter("Filter.ProductsType", Enums.ProductsTypes.InventoryItem);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		// Bundles
		NewParameter = New ChoiceParameter("Filter.IsBundle", False);
		NewArray.Add(NewParameter);
		// End Bundles
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryProducts.ChoiceParameters = NewParameters;
		
		Items.GroupInventory.Title = NStr("en = 'Goods'; ru = 'Товары';pl = 'Towary';es_ES = 'Mercancías';es_CO = 'Mercancías';tr = 'Mallar';it = 'Merci';de = 'Waren'");
		
		For Each StringInventory In Object.Inventory Do
			If StringInventory.Products.ProductsType = Enums.ProductsTypes.Service Then
				StringInventory.Products = Undefined;
			EndIf;
		EndDo;
		
	EndIf;
	
	Items.MaterialsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	Items.Warehouse.Visible		= Not IsDropShipping;
	Items.GroupDelivery.Visible	= IsDropShipping;
	
	Items.InventorySpecification.Visible = (Object.OperationKind <> Enums.OperationTypesPurchaseOrder.OrderForPurchase);
	Items.FormDocumentSetting.Visible = GetFunctionalOption("UseInventoryReservation");

EndProcedure

// Procedure sets the form item visible.
//
&AtServer
Procedure SetVisibleFromUserSettings()
	
	VisibleValue = (Object.SalesOrderPosition = Enums.AttributeStationing.InHeader);
	
	Items.SalesOrder.Enabled = VisibleValue;
	Items.FillBySalesOrder.Visible = VisibleValue;
	
	Items.InventorySalesOrder.Visible = Not VisibleValue;
	Items.GroupBasisDocument.ReadOnly = Not VisibleValue;

	If VisibleValue Then
		Items.SalesOrder.InputHint = "";
	Else 
		Items.SalesOrder.InputHint = NStr("en = '<Multiple orders mode>'; ru = '<Режим нескольких заказов>';pl = '<Tryb wielu zamówień>';es_ES = '<Modo de órdenes múltiples>';es_CO = '<Modo de órdenes múltiples>';tr = '<Birden fazla sipariş modu>';it = '<Modalità ordini multipli>';de = '<Modus Mehrfache Bestellungen>'");
	EndIf;
	
	If Object.ReceiptDatePosition = Enums.AttributeStationing.InHeader Then
		Items.ReceiptDate.Visible = True;
		Items.InventoryIncreaseDate.Visible = False;
	Else
		Items.ReceiptDate.Visible = False;
		Items.InventoryIncreaseDate.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Function GetVisibleOperationKind()
	
	Result = False;
	
	If GetFunctionalOption("TransferRawMaterialsForProcessing")
		And Constants.UseSubcontractorManufacturers.Get() Then
		Result = True;
	ElsIf GetFunctionalOption("UseDropShipping") Then
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

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
	ClosingStructure.Insert("PurchaseOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Read();
	
	ResetStatus();
	
EndProcedure

&AtClient
Procedure FormManagement()

	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	If GetAccessRightForDocumentPosting() Then
		Items.FormPost.Enabled			= (Not StatusIsComplete Or Not Object.Closed);
		Items.FormPostAndClose.Enabled	= (Not StatusIsComplete Or Not Object.Closed);
	EndIf;
	
	Items.FormWrite.Enabled 				= Not StatusIsComplete Or Not Object.Closed;
	Items.FormCreateBasedOn.Enabled 		= Not StatusIsComplete Or Not Object.Closed;
	Items.CloseOrder.Visible				= Not Object.Closed;
	Items.CloseOrder.Enabled				= DriveServer.CheckCloseOrderEnabled(Object.Ref);
	Items.InventoryCommandBar.Enabled		= Not StatusIsComplete;
	Items.FillByRFQ.Enabled					= Not StatusIsComplete;
	Items.PricesAndCurrency.Enabled			= Not StatusIsComplete;
	Items.Counterparty.ReadOnly				= StatusIsComplete;
	Items.Contract.ReadOnly					= StatusIsComplete;
	Items.ReceiptDate.ReadOnly				= StatusIsComplete;
	Items.GroupBasis.ReadOnly				= StatusIsComplete;
	Items.GroupRFQ.ReadOnly					= StatusIsComplete;
	Items.RightColumn.ReadOnly				= StatusIsComplete;
	Items.Pages.ReadOnly					= StatusIsComplete;
	Items.Footer.ReadOnly					= StatusIsComplete;
	
	NeedToApprovePurchaseOrder = NeedToApprovePurchaseOrder();
	
	Items.ApprovalStatus.Visible = NeedToApprovePurchaseOrder And Not Object.ApprovalStatus.IsEmpty();
	Items.Approver.Visible = NeedToApprovePurchaseOrder;
	Items.ApprovalDate.Visible = NeedToApprovePurchaseOrder;
	
	Items.ApprovalDate.ReadOnly = (Object.ApprovalStatus = PredefinedValue("Enum.ApprovalStatuses.Approved"));
	
EndProcedure

&AtServerNoContext
Function GetAccessRightForDocumentPosting()
	
	Return AccessRight("Posting", Metadata.Documents.PurchaseOrder);
	
EndFunction

&AtServerNoContext
Function GetPurchaseOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PurchaseOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.PurchaseOrderStatuses AS PurchaseOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON PurchaseOrderStatuses.OrderStatus = OrderStatuses.Ref
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

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServerNoContext
Function GetBusinessProcesses(Ref)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PurchaseApproval.Ref AS Ref,
	|	PurchaseApproval.Completed AS Completed
	|FROM
	|	BusinessProcess.PurchaseApproval AS PurchaseApproval
	|WHERE
	|	PurchaseApproval.Subject = &Ref";
	
	Query.SetParameter("Ref", Ref);
	Return Query.Execute().Unload();
	
EndFunction

&AtServerNoContext
Procedure CompleteBusinessProcesses(Ref)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	PurchaseApproval.Ref AS Ref
	|FROM
	|	BusinessProcess.PurchaseApproval AS PurchaseApproval
	|WHERE
	|	PurchaseApproval.Subject = &Ref
	|	AND NOT PurchaseApproval.Completed";
	
	Query.SetParameter("Ref", Ref);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		BusinessProcessObject = Selection.Ref.GetObject();
		BusinessProcessObject.Completed = True;
		BusinessProcessObject.Write();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeOpeningBusinessProcess(Result, Parameters) Export
	
	If Result = DialogReturnCode.OK Then
		Write();
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessShippingAddressChange()
	
	DeliveryData = GetDeliveryAttributes(Object.ShippingAddress);
	
	FillPropertyValues(Object, DeliveryData);
	
EndProcedure

&AtServerNoContext
Function GetDeliveryAttributes(ShippingAddress)
	Return ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
EndFunction

&AtServer
Procedure SetCustomerCounterparty()
	
	If ValueIsFilled(Object.ContactPerson) Then
		
		CustomerCounterparty = Common.ObjectAttributeValue(Object.ContactPerson, "Owner");
		
	ElsIf ValueIsFilled(Object.ShippingAddress) Then
		
		CustomerCounterparty = Common.ObjectAttributeValue(Object.ShippingAddress, "Owner");
		
	ElsIf Object.Inventory.Count() > 0
		And ValueIsFilled(Object.Inventory[0].SalesOrder)
		And (TypeOf(Object.Inventory[0].SalesOrder) = Type("DocumentRef.SalesOrder")
			Or TypeOf(Object.Inventory[0].SalesOrder) = Type("DocumentRef.WorkOrder")) Then
		
		CustomerCounterparty = Common.ObjectAttributeValue(Object.Inventory[0].SalesOrder, "Counterparty");
		
	EndIf;
	
	ChoiceParameterLinks = New Array;
	ChoiceParameterLinks.Add(New ChoiceParameterLink("Filter.Owner", "CustomerCounterparty"));
	Items.ShippingAddress.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinks);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"PurchaseOrder.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		
		// Cash flow projection.
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSource

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
// End StandardSubsystems.AttachableCommand

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

#Region GeneralPurposeProceduresAndFunctionsOfPaymentCalendar

&AtServer
Procedure FillPaymentCalendar(TypeListOfPaymentCalendar, IsEnabledManually = False)
	
	PaymentTermsServer.FillPaymentCalendarFromContract(Object, IsEnabledManually);
	
	TypeListOfPaymentCalendar = Number(Object.PaymentCalendar.Count() > 1);
	Modified = True;
	
EndProcedure

&AtClient
Procedure SetVisibleEnablePaymentTermItems()
	
	SetEnableGroupPaymentCalendarDetails();
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
EndProcedure

&AtServer
Procedure DatesChangeProcessing()
	
	If Object.ReceiptDatePosition = Enums.AttributeStationing.InTabularSection Then
		Object.ReceiptDate = DriveServer.ColumnMin(Object.Inventory.Unload(), "ReceiptDate");
	EndIf;
	
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
	
EndProcedure

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
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
Procedure ClearPaymentCalendarContinue(Answer, Parameters) Export
	If Answer = DialogReturnCode.Yes Then
		Object.PaymentCalendar.Clear();
		SetEnableGroupPaymentCalendarDetails();
	ElsIf Answer = DialogReturnCode.No Then
		Object.SetPaymentTerms = True;
	EndIf;
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
	
	LineCount = AdditionalParameters.LineCount;
	
	If Result = DialogReturnCode.No Then
		SwitchTypeListOfPaymentCalendar = 1;
		Return;
	EndIf;
	
	While LineCount > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar[LineCount - 1]);
		LineCount = LineCount - 1;
	EndDo;
	Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	
	SetVisiblePaymentCalendar();

EndProcedure

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTypeSalesOrder()

	If TypeOf(Object.BasisDocument) = Type("DocumentRef.SalesOrder") Then
		NewType = New TypeDescription("DocumentRef.SalesOrder");
	ElsIf TypeOf(Object.BasisDocument) = Type("DocumentRef.WorkOrder") Then
		NewType = New TypeDescription("DocumentRef.WorkOrder");
	Else
		TypesArray = New Array;
		TypesArray.Add(TypeOf("DocumentRef.SalesOrder"));
		TypesArray.Add(TypeOf("DocumentRef.WorkOrder"));
		
		NewType = New TypeDescription(TypesArray);
	EndIf;
	
	Items.SalesOrder.TypeRestriction = NewType;
	Items.InventorySalesOrder.TypeRestriction = NewType;

EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	
	Return Fields;
	
EndFunction

#EndRegion

#Region InteractiveActionResultHandlers

// Procedure-handler of the result of opening the "Prices and currencies" form
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	// Refill the tabular section "Inventory" if changes were made to the form "Prices and Currency".
	If TypeOf(ClosingResult) = Type("Structure") And ClosingResult.WereMadeChanges Then
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		
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
		Object.SupplierPriceTypes = ClosingResult.SupplierPriceTypes;
		Object.DiscountType = ClosingResult.SupplierDiscountKind;
		Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			And ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
		EndIf;
		
		ProcessChangesOnButtonPricesAndCurrenciesAtServer(ClosingResult);

		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			And Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory", PricesPrecision);
		EndIf;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
EndProcedure

&AtClient
// Procedure-handler response on question about document recalculate by contract data
//
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		If AdditionalParameters.RecalculationRequired Then
			
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory", True);
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region TooltipEventsHandlers

// Procedure sets the contract visible in dependence on established parameter to counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtServer
Procedure FillCrossReference(IsCounterpartyChanged)
	
	For Each LineInventory In Object.Inventory Do
		
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

&AtClient
Procedure InventoryBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Clone Then
		TotalTotal = Object.Inventory.Total("Total") + Item.CurrentData.Total;
		TotalVATAmount = Object.Inventory.Total("VATAmount") + Item.CurrentData.VATAmount;
		DiscountTotal = Object.Inventory.Total("DiscountAmount");
		Object.DocumentTax = TotalVATAmount;
		Object.DocumentSubtotal = TotalTotal - TotalVATAmount + DiscountTotal;
		LineCopyInventory = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region PurchaseOrderApproval

&AtClient
Procedure ChangeApprovalStatus()
	
	If ReadOnly Or Not UsePurchaseOrderApproval Then
		Return;
	EndIf;
	
	If Not NeedToApprovePurchaseOrder() Then
		
		Object.ApprovalStatus = PredefinedValue("Enum.ApprovalStatuses.EmptyRef");
		Return;
		
	EndIf;
	
	If (Object.OrderState <> PredefinedValue("Catalog.PurchaseOrderStatuses.Open")
		And Not ValueIsFilled(Object.ApprovalStatus)) Then
		
		Object.ApprovalStatus = PredefinedValue("Enum.ApprovalStatuses.ReadyForApproval");
		
	ElsIf Object.OrderState = PredefinedValue("Catalog.PurchaseOrderStatuses.Open") Then
		
		Object.ApprovalStatus = PredefinedValue("Enum.ApprovalStatuses.EmptyRef");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GetApprovalConditions()
	
	PurchaseOrdersApprovalType = Constants.PurchaseOrdersApprovalType.Get();
	
	If PurchaseOrdersApprovalType = Enums.PurchaseOrdersApprovalTypes.ApproveAll Then
		
		ApprovePurchaseOrders = True;
		LimitInSettlementsCurrency = 0;
		
	ElsIf PurchaseOrdersApprovalType = Enums.PurchaseOrdersApprovalTypes.ApproveGreaterAmount Then
		
		ApprovePurchaseOrders = True;
		LimitInSettlementsCurrency = Constants.LimitWithoutPurchaseOrderApproval.Get();
		
	Else
		
		ApprovalAttributes = Common.ObjectAttributesValues(Object.Contract, "ApprovePurchaseOrders, LimitWithoutApproval");
		ApprovePurchaseOrders = ApprovalAttributes.ApprovePurchaseOrders;
		
		If Not ApprovePurchaseOrders Then
			Return;
		EndIf;
		
		LimitInSettlementsCurrency = ApprovalAttributes.LimitWithoutApproval;
		
	EndIf;
	
	If Object.DocumentCurrency <> SettlementsCurrency
		And LimitInSettlementsCurrency <> 0 Then
		
		DocumentCurrencyStructure = New Structure;
		DocumentCurrencyStructure.Insert("Currency", Object.DocumentCurrency);
		DocumentCurrencyStructure.Insert("Rate", Object.ExchangeRate);
		DocumentCurrencyStructure.Insert("Repetition", Object.Multiplicity);
		
		LimitWithoutApproval = CurrenciesExchangeRatesClientServer.ConvertAtRate(
			LimitInSettlementsCurrency,
			Common.ObjectAttributeValue(Object.Company, "ExchangeRateMethod"),
			CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company),
			DocumentCurrencyStructure);
		
	Else
		LimitWithoutApproval = LimitInSettlementsCurrency;
	EndIf;
	
EndProcedure

&AtClient
Function NeedToApprovePurchaseOrder()
	
	If ApprovePurchaseOrders Then
		Return Object.Inventory.Total("Total") > LimitWithoutApproval;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClient
Procedure ResetApprovalStatusEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		CompleteBusinessProcesses(Object.Ref);
		
		Object.ApprovalStatus = PredefinedValue("Enum.ApprovalStatuses.ReadyForApproval");
		UserWarned = True;
		Write(AdditionalParameters);
	EndIf;
	
EndProcedure

&AtServer
Function GetFormParameters(Ref)
	
	FormParameters = New Structure;
	
	ResultTable = GetBusinessProcesses(Object.Ref);
	If ResultTable.Count() = 0 Then
		
		FormParameters.Insert("FormName", "BusinessProcess.PurchaseApproval.ObjectForm");
		FormParameters.Insert("Parameters", New Structure("Basis", Ref));
		
	ElsIf ResultTable.Count() = 1
		And Not (Object.ApprovalStatus = Enums.ApprovalStatuses.ReadyForApproval
		And ResultTable[0].Completed) Then
		
		FormParameters.Insert("FormName", "BusinessProcess.PurchaseApproval.ObjectForm");
		FormParameters.Insert("Parameters", New Structure("Key", ResultTable[0].Ref));
	Else
		
		FilterStructure = New Structure("Subject", Ref); 
		FormParameters.Insert("FormName", "BusinessProcess.PurchaseApproval.ListForm");
		FormParameters.Insert("Parameters", New Structure("Filter", FilterStructure));
		
	EndIf;
	
	Return FormParameters;
	
EndFunction

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion