#Region Variables

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

&AtClient
Var RowCopyWorks;

&AtClient
Var CopyingProductsRow;

&AtClient
Var ThisIsNewRow;

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	CounterpartyContractParameters = New Structure;
	If Not ValueIsFilled(Object.Ref)
		And ValueIsFilled(Object.Counterparty)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			ContractParametersByDefault = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
			Object.Contract = ContractParametersByDefault;
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			CounterpartyContractParameters = Common.ObjectAttributesValues(Object.Contract, "SettlementsCurrency, DiscountMarkupKind, PriceKind");
			
			Object.DocumentCurrency = CounterpartyContractParameters.SettlementsCurrency;
			
			If ValueIsFilled(Object.BasisDocument) 
				And TypeOf(Object.BasisDocument) = Type("DocumentRef.Quote") Then
				
				CurrencyBasisDocument = Common.ObjectAttributeValue(Object.BasisDocument, "DocumentCurrency");
				
				If CurrencyBasisDocument <> Object.DocumentCurrency Then
				
					Object.DocumentCurrency = CurrencyBasisDocument;
					
				EndIf;
				
			EndIf;
			
			SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, CounterpartyContractParameters.SettlementsCurrency, Object.Company);
			Object.ExchangeRate = ?(SettlementsCurrencyRateRepetition.Rate = 0, 1, SettlementsCurrencyRateRepetition.Rate);
			Object.DiscountMarkupKind = CounterpartyContractParameters.DiscountMarkupKind;
			
			If Not ValueIsFilled(Object.PriceKind) Then
				Object.PriceKind = CounterpartyContractParameters.PriceKind;
			EndIf;
			
			If Object.PaymentCalendar.Count() = 0 Then
				FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			EndIf;
		EndIf;
	Else
		CounterpartyContractParameters = Common.ObjectAttributesValues(Object.Contract, "SettlementsCurrency");
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	CounterpartyContractParameters.Property("SettlementsCurrency", SettlementsCurrency);
	FunctionalCurrency = DriveReUse.GetFunctionalCurrency();
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency = StructureByCurrency.Rate;
	RepetitionNationalCurrency = StructureByCurrency.Repetition;
	TabularSectionName = "Works";
	
	UseInventoryReservation = GetFunctionalOption("UseInventoryReservation");
	SetAccountingPolicyValues();
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	If Not ValueIsFilled(Object.Ref) Then
		
		// Start and Finish
		If Not (Parameters.FillingValues.Property("Start") OR Parameters.FillingValues.Property("Finish")) Then
			CurrentDate = CurrentSessionDate();
			Object.Start = CurrentDate;
			Object.Finish = EndOfDay(CurrentDate);
		EndIf;
		
		If Not ValueIsFilled(Parameters.CopyingValue) Then
			
			If Not ValueIsFilled(Object.BankAccount) Then
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
			EndIf;
			
			If Not ValueIsFilled(Object.PettyCash) Then
				Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Object.Worksite) Then
			
			Object.Worksite = Enums.Worksites.CompanySite;
			
		EndIf;
		
		If Object.Inventory.Count() = 0 Then
			FillInventoryFromAllBillsOfMaterialsAtServer();
		EndIf;
		
		If Object.Materials.Count() = 0 Then
			FillMaterialsByAllBillsOfMaterialsAtServer();
		EndIf;
		
	EndIf;
	
	MakeNamesOfMaterialsAndPerformers();
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation();
		FillSalesTaxRate();
		
	EndIf;
	
	SetVisibleTaxAttributes();
	
	// Generate price and currency label.
	ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(ThisObject, "MaterialsRegisterExpense");
	
	SetVisibleAndEnabledFromState();
	
	UsePayrollSubsystem = GetFunctionalOption("UsePayrollSubsystem")
		AND (AccessManagement.HasRole("AddEditPayrollSubsystem") OR AccessManagement.HasRole("FullRights"));
	
	// FO Use Payroll subsystem.
	SetVisibleByFOUseSubsystemPayroll();
	
	Items.LastEvent.Visible = GetFunctionalOption("UseDocumentEvent");
	
	ProcessingCompanyVATNumbers();
	
	// If the document is opened from pick, fill the tabular section products
	If Parameters.FillingValues.Property("InventoryAddressInStorage")
		AND ValueIsFilled(Parameters.FillingValues.InventoryAddressInStorage) Then
		
		GetInventoryFromStorage(Parameters.FillingValues.InventoryAddressInStorage,
							Parameters.FillingValues.TabularSectionName,
							Parameters.FillingValues.AreCharacteristics,
							Parameters.FillingValues.AreBatches);
		
	EndIf;
	
	// Form title setting.
	If Not ValueIsFilled(Object.Ref) Then
		AutoTitle = False;
		Title = NStr("en = 'Work order (Create)'; ru = 'Заказ-наряд (Создание)';pl = 'Zlecenie pracy (Tworzenie)';es_ES = 'Orden de trabajo (Crear)';es_CO = 'Orden de trabajo (Crear)';tr = 'İş emri (Oluştur)';it = 'Commessa (Crea)';de = 'Arbeitsauftrag (Erstellen)'");
	EndIf;
	
	// Status.
	
	InProcessStatus = DriveReUse.GetStatusInProcessOfWorkOrders();
	CompletedStatus = DriveReUse.GetStatusCompletedWorkOrders();
	
	If Not GetFunctionalOption("UseWorkOrderStatuses") Then
		
		Items.GroupState.Visible = False;
		
		Items.ValStatus.ChoiceList.Add(Documents.WorkOrder.InProcessStatus(), NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'"));
		Items.ValStatus.ChoiceList.Add(Documents.WorkOrder.CompletedStatus(), NStr("en = 'Completed'; ru = 'Завершенные';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
		Items.ValStatus.ChoiceList.Add(Documents.WorkOrder.CanceledStatus(), NStr("en = 'Canceled'; ru = 'Отменено';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Cancellati';de = 'Abgebrochen'"));
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			ValStatus = Documents.WorkOrder.InProcessStatus();
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			ValStatus = Documents.WorkOrder.CompletedStatus();
		Else
			ValStatus = Documents.WorkOrder.CanceledStatus();
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings(); 
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf;
	
	// Set filter for TableWorks by Product type.
	FilterStructure = New Structure;
	FilterStructure.Insert("ProductsTypeService", False);
	FixedFilterStructure = New FixedStructure(FilterStructure);
	Items.TableWorks.RowFilter = FixedFilterStructure;
	
	// Setting contract visible.
	SetContractVisible();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.WorksPrice.ReadOnly 					= Not AllowedEditDocumentPrices;
	Items.WorksDiscountMarkupPercent.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.WorksAmount.ReadOnly 					= Not AllowedEditDocumentPrices;
	Items.WorksAmountVAT.ReadOnly 				= Not AllowedEditDocumentPrices;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 					= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly	 			= Not AllowedEditDocumentPrices;
	
	// Bundles
	BundlesOnCreateAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		RefreshBundlePictures(Object.Inventory);
		RefreshBundleAttributes(Object.Inventory);
		
	EndIf;
	
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Materials");
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "ConsumersInventory");
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
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
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();

	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	StartDate = Object.Start;
	
	ReadAdditionalInformationPanelData();
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject, "Materials");
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	DocumentDate = CurrentObject.Date;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
	MakeNamesOfMaterialsAndPerformers();
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	SetSwitchTypeListOfPaymentCalendar();
	
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
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	SetVisibleEnablePaymentTermItems();
	
	SetVisibleAndEnabledFromState();
	SetVisibleDeliveryAttributes();
	SetSerialNumberEnable();
	FillProjectChoiceParameters();
	
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// AutomaticDiscounts
	// Display the message about discount calculation when user clicks the "Post and close" button or closes the form by
	// the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(
			NStr("en = 'Update:'; ru = 'Изменение:';pl = 'Zaktualizuj:';es_ES = 'Actualizar:';es_CO = 'Actualizar:';tr = 'Güncelle:';it = 'Aggiornamento:';de = 'Aktualisieren:'"),
			GetURL(Object.Ref),
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1. The automatic discounts are calculated.'; ru = '%1. Автоматические скидки рассчитаны.';pl = '%1. Obliczono rabaty automatyczne.';es_ES = '%1. Los descuentos automáticos se han calculado.';es_CO = '%1. Los descuentos automáticos se han calculado.';tr = '%1. Otomatik indirimler hesaplandı.';it = '%1. Sconti automatici sono stati calcolati.';de = '%1. Die automatischen Rabatte werden berechnet.'"),
				String(Object.Ref)),
			PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		
		NotifyWorkCalendar = True;
		DocumentModified = False;
		
		Notify("NotificationAboutChangingDebt");
		Notify("RefreshAccountingTransaction");
		
		// Bundles
		RefreshBundlePictures(Object.Inventory);
		// End Bundles
		
	EndIf;
	
	If Object.Posted
		And ValueIsFilled(Object.BasisDocument)
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.Quote") Then
		NotifyParameter = New Structure;
		NotifyParameter.Insert("Quotation", Object.BasisDocument);
		NotifyParameter.Insert("Status", PredefinedValue("Catalog.QuotationStatuses.Converted"));
		Notify("Write_Quotation", NotifyParameter, ThisObject);
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
			RecalculateSubtotal();
			CommonClientServer.MessageToUser(NStr("en = 'The automatic discounts are applied.'; ru = 'Рассчитаны автоматические скидки.';pl = 'Stosowane są rabaty automatyczne.';es_ES = 'Los descuentos automáticos se han aplicado.';es_CO = 'Los descuentos automáticos se han aplicado.';tr = 'Otomatik indirimler uygulandı.';it = '. Sconti automatici sono stati applicati.';de = 'Die automatischen Rabatte werden angewendet.'"));
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	If Modified Then
		
		DocumentModified = True;
		
	EndIf;
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		If DriveReUse.CounterpartyContractsControlNeeded() And CounterpartyAttributes.DoOperationsByContracts Then
			
			CheckContractToDocumentConditionAccordance(
				MessageText,
				CurrentObject.Contract,
				CurrentObject.Ref,
				CurrentObject.Company,
				CurrentObject.Counterparty,
				Cancel);
			
		EndIf;
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			MessageToUserText = ?(Cancel, NStr("en = 'Cannot post the work order.'; ru = 'Невозможно провести заказ-наряд';pl = 'Nie można zaksięgować zlecenia pracy.';es_ES = 'No se puede publicar el orden de trabajo.';es_CO = 'No se puede publicar el orden de trabajo.';tr = 'İş emri gönderilemiyor.';it = 'Non è possibile pubblicare la Commessa.';de = 'Fehler beim Buchen des Arbeitsauftrags.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				CommonClientServer.MessageToUser(MessageToUserText, ,"Contract","Object", Cancel);
				Return;
			Else
				CommonClientServer.MessageToUser(MessageToUserText);
			EndIf;
		EndIf;
		
	EndIf;
	
	CurrentObject.CalculateInventoryAndWorksSalesTaxAmount();
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("TabularSectionName", "Works");
	WorksAmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
	
	InvAmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject);
	
	If WorksAmountsHaveChanged Or InvAmountsHaveChanged Then
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(CurrentObject);
		WriteParameters.Insert("RecalculateSubtotal", True);
	EndIf;
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
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

&AtServer
// Procedure-handler of the AfterWriteOnServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
	// Form title setting.
	Title = "";
	AutoTitle = True;
	
	// Bundles
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	MakeNamesOfMaterialsAndPerformers();
	
	ReadAdditionalInformationPanelData();
	
	If WriteParameters.Property("RecalculateSubtotal") Then
		RecalculateSubtotal();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
	If Cancel Then
		Return;
	EndIf;
	
	If NotifyWorkCalendar Then
		Notify("ChangedWorkOrder", Object.Responsible);
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
		AND IsInputAvailable() AND Not DiscountCardRead Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			TableName = GetTableNameByCurrentPage();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity, TableName", Parameter[0], 1, TableName)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity, TableName", Parameter[1][1], 1, TableName)); // Get a barcode from the additional data
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
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetContractVisible();
		
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID Then
		
		If Items.Pages.CurrentPage = Items.GroupWork Then
			ChangedCount = GetSerialNumbersMaterialsFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange input field Status.
//
&AtClient
Procedure VALStatusOnChange(Item)
	
	If ValStatus = NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'") Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf ValStatus = NStr("en = 'Completed'; ru = 'Завершенные';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'") Then
		Object.OrderState = CompletedStatus;
	ElsIf ValStatus = NStr("en = 'Canceled'; ru = 'Отменено';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Cancellati';de = 'Abgebrochen'") Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	
	SetVisibleAndEnabledFromState();
	
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

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.Company;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
		
	RecalculateSubtotal();
	
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
		
		Object.SalesRep = CounterpartyAttributes.SalesRep;
		
		ContractData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = ContractData.Contract;
		
		ProcessContractChange(ContractData);
		GenerateLabelPricesAndCurrency(ThisObject);
		
		If Not ValueIsFilled(Object.Location) Then
			
			DeliveryData = GetDeliveryData(Object.Counterparty);
			
			If DeliveryData.ShippingAddress = Undefined Then
				CommonClientServer.MessageToUser(NStr("en = 'Delivery address is required'; ru = 'Укажите адрес доставки';pl = 'Wymagany jest adres dostawy';es_ES = 'Se requiere la dirección de entrega';es_CO = 'Se requiere la dirección de entrega';tr = 'Teslimat adresi gerekli';it = 'È richiesto l''indirizzo di consegna';de = 'Adresse ist ein Pflichtfeld'"));
			Else
				Object.Location = DeliveryData.ShippingAddress;
			EndIf;
			
		EndIf;
		
		ProcessShippingAddressChange();
		
		SetVisibleDeliveryAttributes();
		SetVisibleEnablePaymentTermItems();
		
		Object.Project = PredefinedValue("Catalog.Projects.EmptyRef");
		FillProjectChoiceParameters();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
	ReadAdditionalInformationPanelData();
	
EndProcedure

&AtClient
Procedure InventoryStructuralUnitOnChange(Item)
	InventoryStructuralUnitOnChangeAtServer();
EndProcedure

&AtClient
Procedure InventoryWarehouseOnChange(Item)
	InventoryWarehouseOnChangeAtServer();
EndProcedure

&AtClient
Procedure WorksiteOnChange(Item)
	SetVisibleDeliveryAttributes();
EndProcedure

&AtClient
Procedure LocationOnChange(Item)
	
	ProcessShippingAddressChange();
	
EndProcedure

// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure EquipmentOnChange(Item)
	
	SetSerialNumberEnable();
	
EndProcedure

// Procedure - event handler SelectionStart input field Contract.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormOfContractParameters(
		Object.Ref,
		Object.Company,
		Object.Counterparty,
		CounterpartyAttributes.DoOperationsByContracts,
		Object.Contract);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure SalesStructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.SalesStructuralUnit) Then
		
		If Not ValueIsFilled(Object.StructuralUnitReserve) Then
			
			StructureData = New Structure();
			StructureData.Insert("Department", Object.SalesStructuralUnit);
			
			StructureData = GetDataStructuralUnitOnChange(StructureData);
			
			Object.StructuralUnitReserve = StructureData.InventoryStructuralUnit;
			
		EndIf;
		
	Else
		
		Items.WOCellInventory.Enabled = False;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the OrderState input field.
//
&AtClient
Procedure OrderStatusOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then 
		Object.Closed = False;
	EndIf;
	
	SetVisibleAndEnabledFromState();
	
EndProcedure

&AtClient
Procedure OrderStatusStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = GetWorkOrderStates();
	
EndProcedure

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure StartOnChange(Item)
	
	If Object.Start > Object.Finish Then
		Object.Start = WhenChangingStart;
		CommonClientServer.MessageToUser(NStr("en = 'The start date is later than the end date. Please correct the dates.'; ru = 'Дата старта не может быть больше даты финиша.';pl = 'Data rozpoczęcia nie może być późniejsza niż data zakończenia. Skoryguj daty.';es_ES = 'La fecha del inicio es posterior a la fecha del fin. Por favor, corrija las fechas.';es_CO = 'La fecha del inicio es posterior a la fecha del fin. Por favor, corrija las fechas.';tr = 'Başlangıç tarihi bitiş tarihinden ileri. Lütfen, tarihleri düzeltin.';it = 'La data di inizio è successiva alla data di fine. Correggere le date.';de = 'Das Startdatum liegt nach dem Enddatum. Bitte korrigieren Sie die Daten.'"));
	Else
		WhenChangingStart = Object.Start;
	EndIf;
	
	If StartDate <> Object.Start Then
		
		DatesChangeProcessing();
		StartDate = Object.Start;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure FinishOnChange(Item)
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		CommonClientServer.MessageToUser(NStr("en = 'The end date is earlier than the start date. Please correct the dates.'; ru = 'Дата финиша не может быть меньше даты старта.';pl = 'Data zakończenia jest wcześniejsza niż data rozpoczęcia. Skoryguj daty.';es_ES = 'La fecha del fin es anterior a la fecha del inicio. Por favor, corrija las fechas.';es_CO = 'La fecha del fin es anterior a la fecha del inicio. Por favor, corrija las fechas.';tr = 'Bitiş tarihi başlangıç tarihinden önce. Lütfen, tarihleri düzeltin.';it = 'La data di fine è precedente alla data di inizio. Correggere le date.';de = 'Das Enddatum liegt vor dem Startdatum. Bitte korrigieren Sie die Daten.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field WorkKind.
//
&AtClient
Procedure WorkKindOnChange(Item)
	
	If ValueIsFilled(Object.WorkKind) Then
		
		FillWithBundledService(Object.WorkKind);
		
	EndIf;
	
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

#Region InventoryFormTableItemsEventHandlers

// Procedure - event handler OnEditEnd tabular section Products.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	ThisIsNewRow = False;
	
EndProcedure

// Procedure - event handler AfterDeleteRow tabular section Products.
//
&AtClient
Procedure InventoryAfterDeletion(Item)
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
// Procedure - event handler BeforeAddStart tabular section "Products".
//
Procedure InventoryBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		// Bundles
		If ValueIsFilled(Item.CurrentData.BundleProduct) Then
			Cancel = True;
		Else
		// End Bundles
			RecalculateSubtotal();
			CopyingProductsRow = True
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange tabular section "Products".
//
Procedure InventoryOnChange(Item)
	
	If CopyingProductsRow = Undefined OR Not CopyingProductsRow Then
		RecalculateSubtotal();
	Else
		CopyingProductsRow = False;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ProductsProductsOnChange(Item)
	
	ProcessProductsProductsChange(Items.Inventory.CurrentData);
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("Products",			TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		StructureData.Insert("VATRate",				TabularSectionRow.VATRate);
		StructureData.Insert("Price",				TabularSectionRow.Price);
		StructureData.Insert("PriceKind",			Object.PriceKind);
		StructureData.Insert("MeasurementUnit",		TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData, TabularSectionRow);
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	// Bundles
	If StructureData.IsBundle Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateSubtotal();
		
	Else
	// End Bundles
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.Content = "";
		
		CalculateAmountInTabularSectionLine("Inventory");
	
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
		
	EndIf;
	// End Bundles
	
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
Procedure ProductsQuantityOnChange(Item)
	
	ProductsQuantityOnChangeAtClient();
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure GoodsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
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
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ProductsPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure GoodsDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure ProductsAmountOnChange(Item)
	
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
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ProductsVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ProductsVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange input field Reserve.
//
&AtClient
Procedure WOProductsReserveOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
EndProcedure

#EndRegion

#Region WorksFormTableItemsEventHandlers

// Procedure - event handler OnActivateRow tabular sectionp "Works".
//
&AtClient
Procedure WorksOnActivateRow(Item)
	
	TabularSectionName = "Works";
	If Object.Materials.Count() Then
		DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	EndIf;
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
EndProcedure

// Procedure - event handler OnActivateRow tabular section "TableWorks".
//
&AtClient
Procedure TableWorkOnActivateRow(Item)
	
	TabularSectionName = "TableWorks";
	
	If Object.LaborAssignment.Count() Then
		DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "LaborAssignment");
	EndIf;
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Works.
//
&AtClient
Procedure WorksOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Works";
	If NewRow Then
		
		DriveClient.AddConnectionKeyToTabularSectionLine(ThisObject);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
		
	EndIf;
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine("Works", Item.CurrentData);
	EndIf;
	// End AutomaticDiscounts

EndProcedure

// Procedure - event handler BeforeAddStart tabular section "Works".
//
&AtClient
Procedure WorksBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		RecalculateSubtotal();
		RowCopyWorks = True;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange tabular section "Works".
//
&AtClient
Procedure WorksOnChange(Item)
	
	If RowCopyWorks = Undefined OR Not RowCopyWorks Then
		RecalculateSubtotal();
	Else
		RowCopyWorks = False;
	EndIf;
	
EndProcedure

// Procedure - event handler OnEditEnd of tabular section Works.
//
&AtClient
Procedure WorksOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
	// Set filter for TableWorks by Product type.
	FilterStructure = New Structure;
	FilterStructure.Insert("ProductsTypeService", False);
	FixedFilterStructure = New FixedStructure(FilterStructure);
	Items.TableWorks.RowFilter = FixedFilterStructure;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillConsumersInventory", False);
	ParametersStructure.Insert("FillMaterials", True);
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Procedure - event handler BeforeDelete tabular section Works.
//
&AtClient
Procedure WorksBeforeDelete(Item, Cancel)

	TabularSectionName = "Works";
	
	TabularSectionRow = Items.Works.CurrentData;
	
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "Materials");
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "LaborAssignment");
	DeleteRowsOfInventoryTabularSection(TabularSectionRow.ConnectionKey);
	
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
EndProcedure

// Procedure - event handler AfterDeleteRow tabular section Works.
//
&AtClient
Procedure WorksAfterDeleteRow(Item)
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure WorksProductsOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	TabularSectionName = "Works";
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("TimeNorm", 1);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("Taxable", TabularSectionRow.Taxable);
	
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Factor", 1);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards

	StructureData.Insert("TabName", TabularSectionName);
	StructureData.Insert("Object", Object);
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	If Not ValueIsFilled(StructureData.Specification)
		And StructureData.ShowSpecificationMessage Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot match a bill of materials to product ""%1"". You can select a bill of materials manually.'; ru = 'Не удалось сопоставить спецификацию с номенклатурой ""%1"". Вы можете выбрать спецификацию вручную.';pl = 'Nie można dopasować specyfikacji materiałowej do produktu ""%1"". Możesz wybrać specyfikację materiałową ręcznie.';es_ES = 'No puede coincidir una lista de materiales con el producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';es_CO = 'No puede coincidir una lista de materiales con el producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';tr = '''''%1'''' ürünü ile ürün reçetesi eşleşmiyor. Ürün reçetesini manuel olarak seçebilirsiniz.';it = 'Impossibile abbinare una distinta base all''articolo ""%1"". È possibile selezionare una distinta base manualmente.';de = 'Kann die Stückliste mit dem Produkt ""%1"" nicht übereinstimmen. Sie können die Stückliste manuell auswählen.'"),
			StructureData.ProductDescription);
		CommonClientServer.MessageToUser(MessageText);
			
	EndIf;
	
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.StandardHours = StructureData.TimeNorm;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Content = "";
	
	If (ValueIsFilled(Object.PriceKind) AND StructureData.Property("Price")) OR StructureData.Property("Price") Then
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	EndIf;
	
	TabularSectionRow.ProductsTypeService = StructureData.IsService;
	
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Works");
	
	RecalculateConnectedTables(True);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillConsumersInventory", False);
	ParametersStructure.Insert("FillMaterials", True);
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure WorksCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("TimeNorm", 1);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(Object.PriceKind) Then
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

	StructureData.Insert("Object", Object);
	StructureData.Insert("TabName", "Works");
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	TabularSectionRow.StandardHours = StructureData.TimeNorm;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	TabularSectionRow.Specification = StructureData.Specification;
	
	If ValueIsFilled(Object.PriceKind) OR StructureData.Property("Price") Then
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Works");
	
EndProcedure

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure VALWorksContentAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Works.CurrentData;
		ContentPattern = DriveServer.GetContentText(TabularSectionRow.Products, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field WorkKind.
//
&AtClient
Procedure WorksWorkKindOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.WorkKind) Then
		
		FillWithBundledService(TabularSectionRow.WorkKind);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure WorksQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	CalculateStandardHoursInTabularSectionLine("Works");
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
	RecalculateConnectedTables();
	
EndProcedure

&AtClient
Procedure WorksStandardHoursOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure WorksPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure WorksDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure WorksAmountOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
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
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure WorksVATRateOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure WorksAmountVATOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

#EndRegion

#Region MaterialsFormTableItemsEventHandlers

// Procedure - event handler BeforeAddStart tabular section Materials.
//
&AtClient
Procedure MaterialsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Works";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, Item.Name);
	
EndProcedure

&AtClient
Procedure MaterialsBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Materials.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbersMaterials,
		CurrentData, "ConnectionKeySerialNumbers", UseSerialNumbersBalance);
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Materials.
//
&AtClient
Procedure MaterialsOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Works";
	
	If NewRow Then
		
		If Item.RowFilter = Undefined Then
			
			DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
			
		EndIf;
		
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisObject, Item.Name);
		
	EndIf;
	
	If Item.CurrentItem.Name = "OWMaterialsSerialNumbers" Then
		OpenSelectionMaterialsSerialNumbers();
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);

EndProcedure

&AtClient
Procedure MaterialsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "MaterialsGLAccounts" Then
		
		StandardProcessing = False;
		IsReadOnly = (Object.OrderState = CompletedStatus) Or ReadOnly;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials", , IsReadOnly);
		
	ElsIf Field.Name = "MaterialsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Materials");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MaterialsOnEditEnd(Item, NewRow, CancelEdit)
	
	ThisIsNewRow = False;

EndProcedure

&AtClient
Procedure MaterialsAfterDeleteRow(Item)
	
	If Object.Materials.Count() = 0 Then
		
		Items.Materials.RowFilter = Undefined;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MaterialsOnActivateCell(Item)
	
	CurrentData = Items.Materials.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Materials.CurrentItem;
		If TableCurrentColumn.Name = "MaterialsGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Materials.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials");
		ElsIf TableCurrentColumn.Name = "MaterialsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Materials.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Materials");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure MaterialsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Materials.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials");
	
EndProcedure

&AtClient
Procedure MaterialsSerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenSelectionMaterialsSerialNumbers();
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure MaterialsProductsOnChange(Item)
	
	TabularSectionRow = Items.Materials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Warehouse", Object.InventoryWarehouse);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("IncomeAndExpenseItems",	TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	
	AddTabRowDataToStructure(ThisObject, "Materials", StructureData);
	StructureData = MaterialsGetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Reserve = 0;
	
EndProcedure

&AtClient
Procedure MaterialsBatchOnChange(Item)
	
	MaterialsBatchOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure MaterialsBatchOnChangeAtClient()
	
	TabRow = Items.Materials.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	AddTabRowDataToStructure(ThisObject, "Materials", StructureData);
	
	StructureData.Insert("Products",	TabRow.Products);
	StructureData.Insert("Batch",	TabRow.Batch);
	
	MaterialsBatchOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtServer
Procedure MaterialsBatchOnChangeAtServer(StructureData)
	
	If UseDefaultTypeOfAccounting Then
		
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, "InventoryWarehouse");
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		EndIf;
		
		StructureData.Insert("ObjectParameters", ObjectParameters);
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Reserve.
//
&AtClient
Procedure MaterialsReserveOnChange(Item)
	
	TabularSectionRow = Items.Materials.CurrentData;
	
EndProcedure

&AtClient
Procedure MaterialsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Materials", StandardProcessing);
	
EndProcedure

&AtClient
Procedure MaterialsRegisterExpenseOnChange(Item)
	
	CurrentData = Items.Materials.CurrentData;
	
	If CurrentData <> Undefined And Not CurrentData.RegisterExpense Then
		CurrentData.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillInventory", False);
		ParametersStructure.Insert("FillConsumersInventory", False);
		ParametersStructure.Insert("FillMaterials", True);
		FillAddedColumns(ParametersStructure);
	EndIf;
	
EndProcedure

#EndRegion

#Region PerformersFormTableItemsEventHandlers

// Procedure - event handler BeforeAddStart of tabular section Performers.
//
&AtClient
Procedure PerformersBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "TableWorks";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, Item.Name);
	
EndProcedure

&AtClient
Procedure LaborAssignmentAfterDeleteRow(Item)
	
	If Object.LaborAssignment.Count() = 0 Then
		
		Items.LaborAssignment.RowFilter = Undefined;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Performers.
//
&AtClient
Procedure PerformersOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "TableWorks";
	If NewRow Then
		
		If Item.RowFilter = Undefined Then
			
			DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "LaborAssignment");
			
		EndIf;
		
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisObject, Item.Name);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Employee.
//
&AtClient
Procedure PerformersEmployeeOnChange(Item)
	
	TabularSectionRow = Items.LaborAssignment.CurrentData;
	TabularSectionRow.Position = EmployeePosition(TabularSectionRow.Employee, Object.Company);
	TabularSectionRow.LPR = 1;
	TabularSectionRow.PayCode = PredefinedValue("Catalog.PayCodes.Work");

EndProcedure

#EndRegion

#Region ConsumersInventoryFormTableItemsEventHandlers

&AtClient
Procedure CustomerMaterialsOnStartEdit(Item, NewRow, Copy)
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;

EndProcedure

&AtClient
Procedure CustomerMaterialsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ConsumersInventoryGLAccounts" Then
		
		StandardProcessing = False;
		IsReadOnly = (Object.OrderState = CompletedStatus) Or ReadOnly;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "ConsumersInventory", , IsReadOnly);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CustomerMaterialsOnEditEnd(Item, NewRow, CancelEdit)
	
	ThisIsNewRow = False;

EndProcedure

&AtClient
Procedure CustomerMaterialsOnActivateCell(Item)
	
	CurrentData = Items.ConsumersInventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.ConsumersInventory.CurrentItem;
		If TableCurrentColumn.Name = "ConsumersInventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.ConsumersInventory.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "ConsumersInventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CustomerMaterialsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.ConsumersInventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "ConsumersInventory");
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure OWCustomerMaterialsProductsOnChange(Item)
	
	TabularSectionRow = Items.ConsumersInventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", ParentCompany);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "ConsumersInventory", StructureData);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	
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

#Region FormCommandsEventHandlers

#Region CommandFormPanelsActionProcedures

&AtClient
Procedure SearchByBarcode(TableName)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode, TableName", CurBarcode, TableName)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity, TableName", TrimAll(CurBarcode), 1, AdditionalParameters.TableName));
	EndIf;
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Function GetTableNameByCurrentPage()
	
	Result = "Inventory";
	Page = Items.Pages.CurrentPage.Name;
	
	If Page = "GroupWork" Then
		Result = "Materials";
	ElsIf Page = "GroupConsumerMaterials" Then
		Result = "ConsumersInventory";
	EndIf;
	
	Return Result;
	
EndFunction

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

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillBySpecification(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'Select a line containing BOM in the section above.'; ru = 'Не выбрана строка основной табличной части!';pl = 'Wybierz linię w specyfikacji materiałowej z powyższej sekcji.';es_ES = 'Seleccionar una línea que contenga BOM en la sección arriba.';es_CO = 'Seleccionar una línea que contenga BOM en la sección arriba.';tr = 'Yukarıdaki bölümde ürün reçetesi içeren bir satır seçin.';it = 'Selezionare una linea contenente una Distinta Base nella sezione precedente.';de = 'Wählen Sie im oberen Abschnitt eine Zeile mit Stückliste aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentTSLine.Specification) Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'BOM is not specified'; ru = 'Не указана спецификация';pl = 'Specyfikacja materiałowa nie została wybrana';es_ES = 'Lista de materiales no especificada';es_CO = 'Lista de materiales no especificada';tr = 'Ürün reçetesi belirtilmemiş';it = 'Distinta Base non specificata';de = 'Stückliste ist nicht angegeben'"));
		Return;
	EndIf;
	
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", CurrentTSLine.ConnectionKey));
	
	If SearchResult.Count() <> 0 Then
		
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillBySpecificationEnd", ThisObject, New Structure("SearchResult", SearchResult)),
			NStr("en = 'This will overwrite the list of inventory. Do you want to continue?'; ru = 'Табличная часть ""Материалы"" будет перезаполнена! Продолжить выполнение операции?';pl = 'Lista zapasów zostanie nadpisana. Czy chcesz kontynuować?';es_ES = 'Eso sobrescribirá la lista de inventario. ¿Quiere continuar?';es_CO = 'Eso sobrescribirá la lista de inventario. ¿Quiere continuar?';tr = 'Bu işlem malzeme listesinin üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'Questo sovrascriverà l''elenco delle scorte. Volete continuare?';de = 'Dadurch wird die Bestandsliste überschrieben. Möchten Sie fortsetzen?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillBySpecificationFragment(SearchResult);
	
EndProcedure

&AtClient
Procedure FillBySpecificationEnd(Result, AdditionalParameters) Export
	
	SearchResult = AdditionalParameters.SearchResult;
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillBySpecificationFragment(SearchResult);
	
EndProcedure

&AtClient
Procedure FillBySpecificationFragment(Val SearchResult)
	
	Var IndexOfDeletion, SearchString, FilterStr, CurrentTSLine;
	
	Modified = True;
	
	For Each SearchString In SearchResult Do
		IndexOfDeletion = Object.Materials.IndexOf(SearchString);
		Object.Materials.Delete(IndexOfDeletion);
	EndDo;
	
	CurrentTSLine = Items.Works.CurrentData;
	FillByBillsOfMaterialsAtServer(CurrentTSLine.Specification, CurrentTSLine.ConnectionKey);
	
	// For WEB version bug
	If Items.Materials.RowFilter = Undefined Then
		
		TabularSectionName = "Works";
		DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
		TabularSectionName	= "Materials";
		
	EndIf;
	
	FilterStr = New FixedStructure("ConnectionKey", Items.Materials.RowFilter["ConnectionKey"]);
	Items.Materials.RowFilter = FilterStr;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillConsumersInventory", False);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Procedure - fill button handler by all BillsOfMaterials of tabular field Works
&AtClient
Procedure FillMaterialsFromAllBillsOfMaterials(Command)
	
	If Not Object.Works.Count() > 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'Please fill the works list.'; ru = 'Заполните табличную часть ""Работы"".';pl = 'Proszę wypełnić listę prac.';es_ES = 'Por favor, rellene la lista de trabajos.';es_CO = 'Por favor, rellene la lista de trabajos.';tr = 'Lütfen iş listesini doldurun.';it = 'Per piacere compilare l''elenco dei lavori.';de = 'Bitte füllen Sie die Werksliste aus.'"),,,"Works");
		Return;
	EndIf;
	
	If Object.Materials.Count() > 0 Then
		
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("FillMaterialsFromAllBillsOfMaterialsEnd", ThisObject),
			NStr("en = 'This will overwrite the list of inventory. Do you want to continue?'; ru = 'Табличная часть ""Материалы"" будет перезаполнена! Продолжить выполнение операции?';pl = 'Lista zapasów zostanie nadpisana. Czy chcesz kontynuować?';es_ES = 'Eso sobrescribirá la lista de inventario. ¿Quiere continuar?';es_CO = 'Eso sobrescribirá la lista de inventario. ¿Quiere continuar?';tr = 'Bu işlem malzeme listesinin üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'Questo sovrascriverà l''elenco delle scorte. Volete continuare?';de = 'Dadurch wird die Bestandsliste überschrieben. Möchten Sie fortsetzen?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillMaterialsFromAllBillsOfMaterialsFragment();
	
EndProcedure

&AtClient
Procedure FillMaterialsFromAllBillsOfMaterialsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillMaterialsFromAllBillsOfMaterialsFragment();
	
EndProcedure

&AtClient
Procedure FillInventoryFromAllBillsOfMaterials(Command)
	
	If Object.Works.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'Please fill the works list.'; ru = 'Заполните табличную часть ""Работы"".';pl = 'Proszę wypełnić listę prac.';es_ES = 'Por favor, rellene la lista de trabajos.';es_CO = 'Por favor, rellene la lista de trabajos.';tr = 'Lütfen iş listesini doldurun.';it = 'Per piacere compilare l''elenco dei lavori.';de = 'Bitte füllen Sie die Werksliste aus.'"),,,"Works");
		Return;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("FillInventoryFromAllBillsOfMaterialsEnd", ThisObject),
		NStr("en = 'This will overwrite the list of inventory. Do you want to continue?'; ru = 'Для выполнения операции требуется очистить табличную часть ""Материалы""! Продолжить выполнение операции?';pl = 'Lista zapasów zostanie nadpisana. Czy chcesz kontynuować?';es_ES = 'Eso sobrescribirá la lista de inventario. ¿Quiere continuar?';es_CO = 'Eso sobrescribirá la lista de inventario. ¿Quiere continuar?';tr = 'Bu işlem malzeme listesinin üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'Questo sovrascriverà l''elenco delle scorte. Volete continuare?';de = 'Dadurch wird die Bestandsliste überschrieben. Möchten Sie fortsetzen?'"), QuestionDialogMode.YesNo, 0);
	Else
		FillInventoryFromAllBillsOfMaterialsEnd(DialogReturnCode.Yes, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInventoryFromAllBillsOfMaterialsEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillInventoryFromAllBillsOfMaterialsAtServer();
	
	For Each TabularSectionRow In Object.Inventory Do
		If ValueIsFilled(TabularSectionRow.ConnectionKeyForWorks) Then
			ProcessProductsProductsChange(TabularSectionRow);
		EndIf;
	EndDo;

EndProcedure

&AtClient
Procedure FillMaterialsFromAllBillsOfMaterialsFragment()
	
	Modified = True;
	
	Object.Materials.Clear();
	
	FillMaterialsByAllBillsOfMaterialsAtServer();
	
	// For the WEB we will repeat pick, what it is correct to display the following PM
	TabularSectionName = "Works";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "LaborAssignment");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillConsumersInventory", False);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillByTeamsForCurrentWorks(Command)
	
	TabularSectionName = "TableWorks";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, TabularSectionName);
	If Cancel Then
		Return;
	EndIf;
	
	CurrentTSLine = Items.TableWorks.CurrentData;
	If Not ValueIsFilled(CurrentTSLine.Products) Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'Work is not specified'; ru = 'Не указана работа';pl = 'Praca nie została określona';es_ES = 'Trabajo no especificado';es_CO = 'Trabajo no especificado';tr = 'İş belirtilmemiş';it = 'Lavoro non specificato';de = 'Arbeit ist nicht spezifiziert'"));
		Return;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MultiselectList", True);
	ArrayOfTeams = Undefined;

	OpenForm("Catalog.Teams.ChoiceForm", OpenParameters,,,,, New NotifyDescription("FillByTeamsForCurrentWorksChoiceTeamsEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure FillByTeamsForCurrentWorksChoiceTeamsEnd(Result, AdditionalParameters) Export
	
	ArrayOfTeams = Result;
	If ArrayOfTeams = Undefined Then
		Return;
	EndIf;
	
	SearchResult = New Array;
	If Object.LaborAssignment.Count() Then
		SearchResult = Object.LaborAssignment.FindRows(New Structure("ConnectionKey", Items.LaborAssignment.RowFilter["ConnectionKey"]));
		
		If SearchResult.Count() <> 0 Then
			Response = Undefined;
			
			ShowQueryBox(New NotifyDescription("FillByTeamsForCurrentWorksEnd", ThisObject, New Structure("ArrayOfTeams, SearchResult", ArrayOfTeams, SearchResult)), NStr("en = 'This will overwrite the list of assignees for the current work. Do you want to continue?'; ru = 'Табличная часть ""Исполнители"" для текущей работы будет перезаполнена! Продолжить выполнение операции?';pl = 'Lista wykonawców dla bieżącej pracy zostanie nadpisana. Czy chcesz kontynuować?';es_ES = 'Eso sobrescribirá la lista de beneficiarios para el trabajo actual. ¿Quiere continuar?';es_CO = 'Eso sobrescribirá la lista de beneficiarios para el trabajo actual. ¿Quiere continuar?';tr = 'Bu işlem o an ki iş için temsilciler listesinin üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'Questo sovrascriverà l''elenco degli assegnatari per i lavori in corso. Volete continuare?';de = 'Dies überschreibt die Liste der Aufgabenempfänger für die aktuelle Arbeit. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.YesNo, 0);
			Return;
		EndIf;
	EndIf;
	FillByTeamsForCurrentWorksFragment(ArrayOfTeams, SearchResult);
	
EndProcedure

&AtClient
Procedure FillByTeamsForCurrentWorksEnd(Result, AdditionalParameters) Export
	
	ArrayOfTeams = AdditionalParameters.ArrayOfTeams;
	SearchResult = AdditionalParameters.SearchResult;
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillByTeamsForCurrentWorksFragment(AdditionalParameters.ArrayOfTeams, AdditionalParameters.SearchResult);
	
EndProcedure

&AtClient
Procedure FillByTeamsForCurrentWorksFragment(Val ArrayOfTeams, Val SearchResult)
	
	Var IndexOfDeletion, PerformersConnectionKey, SearchString, FilterStr;
	
	For Each SearchString In SearchResult Do
		IndexOfDeletion = Object.LaborAssignment.IndexOf(SearchString);
		Object.LaborAssignment.Delete(IndexOfDeletion);
	EndDo;
	
	PerformersConnectionKey = Items.TableWorks.CurrentData.ConnectionKey;
	FillTabularSectionPerformersByTeamsAtServer(ArrayOfTeams, PerformersConnectionKey);
	
	FilterStr = New FixedStructure("ConnectionKey", PerformersConnectionKey);
	Items.LaborAssignment.RowFilter = FilterStr;
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillByTeamsForAllWorks(Command)
	
	TabularSectionName = "TableWorks";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, TabularSectionName);
	If Cancel Then
		Return;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MultiselectList", True);
	ArrayOfTeams = Undefined;

	OpenForm("Catalog.Teams.ChoiceForm", OpenParameters,,,,, New NotifyDescription("FillByTeamsForAllWorksChoiceTeamsEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure FillByTeamsForAllWorksChoiceTeamsEnd(Result, AdditionalParameters) Export
	
	ArrayOfTeams = Result;
	If ArrayOfTeams = Undefined Then
		Return;
	EndIf;
	
	If Object.LaborAssignment.Count() <> 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillByTeamsForAllWorksEnd", ThisObject, New Structure("ArrayOfTeams", ArrayOfTeams)),
			NStr("en = 'This will overwrite the list of assignees. Do you want to continue?'; ru = 'Табличная часть ""Исполнители"" будет перезаполнена! Продолжить выполнение операции?';pl = 'Lista wykonawców zostanie nadpisana. Czy chcesz kontynuować?';es_ES = 'Eso sobrescribirá la lista de beneficiarios. ¿Quiere continuar?';es_CO = 'Eso sobrescribirá la lista de beneficiarios. ¿Quiere continuar?';tr = 'Bu işlem temsilciler listesinin üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'Questo sovrascriverà l''elenco degli assegnatari per i lavori in corso. Volete continuare?';de = 'Dies überschreibt die Liste der Empfänger. Möchten Sie fortsetzen?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	FillByTeamsForAllWorksFragment(ArrayOfTeams);
	
EndProcedure

&AtClient
Procedure FillByTeamsForAllWorksEnd(Result, AdditionalParameters) Export
	
	ArrayOfTeams = AdditionalParameters.ArrayOfTeams;
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillByTeamsForAllWorksFragment(ArrayOfTeams);
	
EndProcedure

&AtClient
Procedure FillByTeamsForAllWorksFragment(Val ArrayOfTeams)
	
	Var FilterStr;
	
	Object.LaborAssignment.Clear();
	
	FillTabularSectionPerformersByTeamsAtServer(ArrayOfTeams);
	
	FilterStr = New FixedStructure("ConnectionKey", Items.TableWorks.CurrentData.ConnectionKey);
	Items.LaborAssignment.RowFilter = FilterStr;
	
EndProcedure

&AtClient
Procedure AllocateWorkedHours(Command)
	
	TabularSectionRow = Items.TableWorks.CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	AllocateWorkedHoursOnServer(TabularSectionRow.ConnectionKey, TabularSectionRow.StandardHours);	
	
EndProcedure

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WorkKindPositionInWorkOrder", Object.WorkKindPosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	StructureDocumentSetting = Undefined;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	// 2. Open "Setting document" form.
	StructureDocumentSetting = Result;
	
	// 3. Apply changes made in "Document setting" form.
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.WorkKindPosition		= StructureDocumentSetting.WorkKindPositionInWorkOrder;
		
		SetVisibleFromUserSettings();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	GetWeightForTabularSectionRow(TabularSectionRow);
	
EndProcedure

#Region ChangeReserveProducts

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeGoodsReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'There are no products to reserve.'; ru = 'Табличная часть ""Товары"" не заполнена!';pl = 'Brak produktów do zarezerwowania.';es_ES = 'No hay productos para reservar.';es_CO = 'No hay productos para reservar.';tr = 'Rezerve edilecek ürün yok.';it = 'Non ci sono articoli da riservare.';de = 'Es gibt keine Produkte zu reservieren.'"));
		Return;
	EndIf;
	
	WOGoodsFillColumnReserveByBalancesAtServer();
	
	// Bundles
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeProductsReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'There is nothing to clear.'; ru = 'Невозможно заполнить колонку ""Резерв"", потому что табличная часть ""Запасы и услуги"" не заполнена!';pl = 'Nie ma nic do wyczyszczenia.';es_ES = 'No hay nada para liquidar.';es_CO = 'No hay nada para liquidar.';tr = 'Temizlenecek bir şey yok.';it = 'Non c''è nulla da cancellare.';de = 'Es gibt nichts zu löschen.'"));
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		
		If TabularSectionRow.ProductsTypeInventory Then
			TabularSectionRow.Reserve = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'work order'; ru = 'заказ-наряд';pl = 'zlecenie pracy';es_ES = 'orden de trabajo';es_CO = 'orden de trabajo';tr = 'iş emri';it = 'commessa';de = 'Arbeitsauftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True, True);
	SelectionParameters.Insert("Company",			ParentCompany);
	SelectionParameters.Insert("StructuralUnit",	Object.StructuralUnitReserve);
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
Procedure WorkSelection(Command)
	
	TabularSectionName			= "Works";
	SelectionMarker				= "Works";
	PickupForMaterialsInWorks	= False;
	
	DocumentPresentaion	= NStr("en = 'work order'; ru = 'заказ-наряд';pl = 'zlecenie pracy';es_ES = 'orden de trabajo';es_CO = 'orden de trabajo';tr = 'iş emri';it = 'commessa';de = 'Arbeitsauftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, False);
	SelectionParameters.Insert("Company",			ParentCompany);
	SelectionParameters.Insert("StructuralUnit",	Object.StructuralUnitReserve);
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
	
	TabularSectionName = "ConsumersInventory";
	SelectionMarker = "ConsumersInventory";
	
	DocumentPresentaion	= NStr("en = 'work order'; ru = 'заказ-наряд';pl = 'zlecenie pracy';es_ES = 'orden de trabajo';es_CO = 'orden de trabajo';tr = 'iş emri';it = 'commessa';de = 'arbeitsauftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject,
		TabularSectionName, DocumentPresentaion, True, False, True);
	SelectionParameters.Insert("Company",			ParentCompany);
	SelectionParameters.Insert("StructuralUnit",	Object.InventoryWarehouse);
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
Procedure WOMaterialsPick(Command)
	
	TabularSectionName = "Works";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, "Materials");
	If Cancel Then
		Return;
	EndIf;
	
	TabularSectionName = "Materials";
	SelectionMarker = "Works";
	PickupForMaterialsInWorks = True;
	
	DocumentPresentaion	= "work order";
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, True);
	SelectionParameters.Insert("Company",			ParentCompany);
	SelectionParameters.Insert("StructuralUnit",	Object.InventoryWarehouse);
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
				|tr = 'Emir tamamlanamıyor. Değişiklikler kaydedilmedi.
				|Değişiklikleri kaydetmek için Tamam''a tıklayın.';
				|it = 'Impossibile completare l''ordine. Le modifiche non sono salvate. 
				|Cliccare su OK per salvare le modifiche.';
				|de = 'Der Auftrag kann nicht abgeschlossen werden. Die Änderungen sind nicht gespeichert.
				|Um die Änderungen zu speichern, klicken Sie auf OK.'"), QuestionDialogMode.OKCancel);
		Return;
	EndIf;
		
	CloseOrderFragment();
	SetVisibleAndEnabledFromState();
	
EndProcedure

// Procedure is called by clicking the PricesCurrency
// button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
		
EndProcedure

&AtClient
Procedure SearchByBarcodeInventory(Command)
	SearchByBarcode("Inventory");
EndProcedure

&AtClient
Procedure SearchByBarcodeConsumersInventory(Command)
	SearchByBarcode("ConsumersInventory");
EndProcedure

&AtClient
Procedure SearchByBarcodeMaterials(Command)
	
	TabularSectionName = "Works";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, "Materials");
	If Cancel Then
		Return;
	EndIf;
	
	SearchByBarcode("Materials");
EndProcedure

#Region ChangeReserveMaterials

&AtClient
Procedure WOChangeMaterialsReserveFillByBalancesForAllEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByBalancesForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveFillByBalancesForAllFragment()
	
	MaterialsFillColumnReserveByBalancesAtServer();
	
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	
EndProcedure

&AtClient
Procedure ChangeMaterialsReserveClearReserveForAllEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	WOChangeMaterialsReserveClearReserveForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveClearReserveForAllFragment()
	
	Var TabularSectionRow;
	
	For Each TabularSectionRow In Object.Materials Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeMaterialsReserveFillByBalances(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'There is nothing to reserve.'; ru = 'Табличная часть ""Материалы"" не заполнена!';pl = 'Nie ma nic do zarezerwowania.';es_ES = 'No hay nada para reservar.';es_CO = 'No hay nada para reservar.';tr = 'Rezerve edilecek bir şey yok.';it = 'Non c''è nulla da riservare.';de = 'Es gibt nichts zu reservieren.'"));
		Return;
	EndIf;
	
	MaterialsConnectionKey = Items.Materials.RowFilter["ConnectionKey"];
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
	If SearchResult.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'There is nothing to reserve.'; ru = 'Табличная часть ""Материалы"" не заполнена!';pl = 'Nie ma nic do zarezerwowania.';es_ES = 'No hay nada para reservar.';es_CO = 'No hay nada para reservar.';tr = 'Rezerve edilecek bir şey yok.';it = 'Non c''è nulla da riservare.';de = 'Es gibt nichts zu reservieren.'"));
		Return;
	EndIf;
	
	MaterialsFillColumnReserveByBalancesAtServer(MaterialsConnectionKey);
	
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	
EndProcedure

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeMaterialsReserveFillByBalancesForAll(Command)
	
	If Object.Materials.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'There is nothing to reserve.'; ru = 'Табличная часть ""Материалы"" не заполнена!';pl = 'Nie ma nic do zarezerwowania.';es_ES = 'No hay nada para reservar.';es_CO = 'No hay nada para reservar.';tr = 'Rezerve edilecek bir şey yok.';it = 'Non c''è nulla da riservare.';de = 'Es gibt nichts zu reservieren.'"));
		Return;
	EndIf;
	
	If Object.Works.Count() > 1 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("WOChangeMaterialsReserveFillByBalancesForAllEnd", ThisObject),
			NStr("en = 'This will overwrite the Reserve column in the list of inventory. Do you want to continue?'; ru = 'В табличной части ""Материалы"" колонка ""Резерв"" будет перезаполнена для всех работ! Продолжить выполнение операции?';pl = 'Kolumna Rezerwa listy zapasów zostanie nadpisana. Czy chcesz kontynuować?';es_ES = 'Eso sobrescribirá la columna Reserva en la lista de inventario. ¿Quiere continuar?';es_CO = 'Eso sobrescribirá la columna Reserva en la lista de inventario. ¿Quiere continuar?';tr = 'Bu işlem stok listesindeki Rezerv sütununun üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'Questo sovrascriverà la colonna della Riserva nell''elenco delle scorte. Volete continuare?';de = 'Dadurch wird die Spalte ""Reserve"" in der Bestandsliste überschrieben. Möchten Sie fortsetzen?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByBalancesForAllFragment();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeMaterialsReserveClearReserve(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'Select a line in the section above.'; ru = 'Не выбрана строка основной табличной части!';pl = 'Wybierz linię w powyższej sekcji.';es_ES = 'Seleccionar una línea en la sección arriba.';es_CO = 'Seleccionar una línea en la sección arriba.';tr = 'Yukarıdaki bölümde satır seçin.';it = 'Selezionare una linea nella sezione precedente.';de = 'Wählen Sie im obigen Abschnitt eine Zeile aus.'"));
		Return;
	EndIf;
	
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", Items.Materials.RowFilter["ConnectionKey"]));
	If SearchResult.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'There is nothing to clear.'; ru = 'Табличная часть ""Материалы"" не заполнена!';pl = 'Nie ma nic do wyczyszczenia.';es_ES = 'No hay nada para liquidar.';es_CO = 'No hay nada para liquidar.';tr = 'Temizlenecek bir şey yok.';it = 'Non c''è nulla da cancellare.';de = 'Es gibt nichts zu löschen.'"));
		Return;
	EndIf;
	
	For Each TabularSectionRow In SearchResult Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeMaterialsReserveClearReserveForAll(Command)
	
	If Object.Materials.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'There is nothing to clear.'; ru = 'Табличная часть ""Материалы"" не заполнена!';pl = 'Nie ma nic do wyczyszczenia.';es_ES = 'No hay nada para liquidar.';es_CO = 'No hay nada para liquidar.';tr = 'Temizlenecek bir şey yok.';it = 'Non c''è nulla da cancellare.';de = 'Es gibt nichts zu löschen.'"));
		Return;
	EndIf;
	
	If Object.Works.Count() > 1 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("ChangeMaterialsReserveClearReserveForAllEnd", ThisObject),
			NStr("en = 'This will overwrite the Reserve column in the list of materials. Do you want to continue?'; ru = 'В табличной части ""Материалы"" колонка ""Резерв"" будет перезаполнена для всех работ! Продолжить выполнение операции?';pl = 'Kolumna Rezerwa listy materiałów zostanie nadpisana. Czy chcesz kontynuować?';es_ES = 'Eso sobrescribirá la columna Reserva en la lista de materiales. ¿Quiere continuar?';es_CO = 'Eso sobrescribirá la columna Reserva en la lista de materiales. ¿Quiere continuar?';tr = 'Bu işlem malzeme listesindeki Rezerv sütununun üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'Questo sovrascriverà la colonna della Riserva nell''elenco dei materiali. Volete continuare?';de = 'Dies überschreibt die Spalte ""Reserve"" in der Liste der Materialien. Möchten Sie fortsetzen?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	WOChangeMaterialsReserveClearReserveForAllFragment();
	
EndProcedure

#EndRegion

#Region EventHandlersOfPaymentCalendar

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
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field SwitchTypeListOfPaymentCalendar.
//
&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	LineCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar AND LineCount > 1 Then
		Response = Undefined;
		ShowQueryBox(
			New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)),
			NStr("en = 'All lines except for the first one will be deleted. Continue?'; ru = 'Все строки кроме первой будут удалены. Продолжить?';pl = 'Wszystkie wiersze za wyjątkiem pierwszego zostaną usunięte. Kontynuować?';es_ES = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';es_CO = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';tr = 'İlki haricinde tüm satırlar silinecek. Devam edilsin mi?';it = 'Tutte le linee eccetto la prima saranno cancellate. Continuare?';de = 'Alle Zeilen bis auf die erste werden gelöscht. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentPercent input field.
//
&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentAmount = Object.Inventory.Total("Amount") + Object.Works.Total("Amount") + Object.SalesTax.Total("Amount");
	PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
	
	CurrentRow.PaymentAmount = Round(PaymentAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(PaymentVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentAmount = Object.Inventory.Total("Amount") + Object.Works.Total("Amount") + Object.SalesTax.Total("Amount");
	PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
	
	CurrentRow.PaymentPercentage = ?(PaymentAmount = 0, 0, Round(CurrentRow.PaymentAmount / PaymentAmount * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(PaymentVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
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
	
	PaymentAmount = Object.Inventory.Total("Amount") + Object.Works.Total("Amount") + Object.SalesTax.Total("Amount");
	PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = PaymentAmount - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = PaymentVATAmount - Object.PaymentCalendar.Total("PaymentVATAmount");
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

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 AND Object.Works.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

// Procedure - command handler "OpenDiscountInformation" for tabular section "Inventory".
//
&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient("Inventory")
	
EndProcedure

// Procedure - command handler "OpenDiscountInformation" for tabular section "Works".
//
&AtClient
Procedure OpenInformationAboutDiscountsWorks(Command)
	
	CurrentData = Items.Works.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient("Works");
	
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
		OpenInformationAboutDiscountsClient("Inventory");
		
	ElsIf Field.Name = "InventoryGLAccounts" Then
		
		StandardProcessing = False;
		IsReadOnly = (Object.OrderState = CompletedStatus) Or ReadOnly;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory", , IsReadOnly);
		
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
	
	// Serial numbers
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
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
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

// Procedure - event handler Table parts selection Works.
//
&AtClient
Procedure ChoiceWorks(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.WorksAutomaticDiscountPercent OR Item.CurrentItem = Items.WorksAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient("Works");
		
	EndIf;
	
EndProcedure

#EndRegion

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the work order with the base document data?'; ru = 'Заказ-наряд будет перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz uzupełnić zlecenie pracy danymi z dokumentu źródłowego?';es_ES = '¿Quiere volver a rellenar el orden de trabajo con los datos del documento base?';es_CO = '¿Quiere volver a rellenar el orden de trabajo con los datos del documento base?';tr = 'Temel belge verileriyle iş emrini yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare la commessa con i dati del documento di base?';de = 'Möchten Sie den Arbeitsauftrag mit den Basisdokumentdaten nachfüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
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

#EndRegion

#Region Private

#Region CommonProceduresAndFunctions

&AtClient
Procedure ProductsQuantityOnChangeAtClient()
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtServer
Procedure AllocateWorkedHoursOnServer(ConnectionKey, StandartHours)

	Query = New Query;
	Query.Text = 	
	"SELECT
	|	Labor.Employee AS Employee,
	|	Labor.LPR AS LPR,
	|	Labor.ConnectionKey AS ConnectionKey
	|INTO TT_Labor
	|FROM
	|	&Labor AS Labor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Labor.Employee AS Employee,
	|	TT_Labor.LPR AS LPR
	|INTO TT_LaborForWork
	|FROM
	|	TT_Labor AS TT_Labor
	|WHERE
	|	TT_Labor.ConnectionKey = &ConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_LaborForWork.LPR / NestedSelect.LPR * &StandartHours AS HoursWorked,
	|	TT_LaborForWork.Employee AS Employee
	|INTO TT_Hours
	|FROM
	|	(SELECT
	|		SUM(TT_LaborForWork.LPR) AS LPR
	|	FROM
	|		TT_LaborForWork AS TT_LaborForWork) AS NestedSelect,
	|	TT_LaborForWork AS TT_LaborForWork
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TT_Hours.HoursWorked AS HoursWorked,
	|	TT_Hours.Employee AS Employee
	|INTO TT_MostHours
	|FROM
	|	TT_Hours AS TT_Hours
	|
	|ORDER BY
	|	TT_Hours.HoursWorked DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_MostHours.Employee AS Employee,
	|	&StandartHours - NestedSelect.HoursSum AS HoursAdd
	|INTO TTHoursAdd
	|FROM
	|	(SELECT
	|		SUM(CAST(TT_Hours.HoursWorked AS NUMBER(15, 2))) AS HoursSum
	|	FROM
	|		TT_Hours AS TT_Hours) AS NestedSelect,
	|	TT_MostHours AS TT_MostHours
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee AS Employee,
	|	SUM(NestedSelect.HoursWorked) AS HoursWorked
	|FROM
	|	(SELECT
	|		TTHoursAdd.Employee AS Employee,
	|		TTHoursAdd.HoursAdd AS HoursWorked
	|	FROM
	|		TTHoursAdd AS TTHoursAdd
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TT_Hours.Employee,
	|		TT_Hours.HoursWorked
	|	FROM
	|		TT_Hours AS TT_Hours) AS NestedSelect
	|
	|GROUP BY
	|	NestedSelect.Employee";
	
	Query.SetParameter("Labor", Object.LaborAssignment.Unload());
	Query.SetParameter("ConnectionKey", ConnectionKey);
	Query.SetParameter("StandartHours", StandartHours);
	
	ResultTable = Query.Execute().Unload();
	
	FilterStr = New Structure("ConnectionKey", ConnectionKey);
	LaborRows = Object.LaborAssignment.FindRows(FilterStr);
	
	For Each Row IN LaborRows DO
		LaborLPR = ResultTable.Find(Row.Employee, "Employee");
		Row.HoursWorked = LaborLPR.HoursWorked;
	EndDo;

EndProcedure

&AtClient
Procedure ProcessProductsProductsChange(TabularSectionRow)
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("Taxable", TabularSectionRow.Taxable);
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
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData, TabularSectionRow);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	// Bundles
	If StructureData.IsBundle And Not StructureData.UseCharacteristics Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateSubtotal();
		
	Else
	// End Bundles
	
	FillPropertyValues(TabularSectionRow, StructureData);
	If TabularSectionRow.Quantity = 0 Then
		TabularSectionRow.Quantity = 1;
	EndIf;
		TabularSectionRow.Content = "";
		
		TabularSectionRow.ProductsTypeInventory = StructureData.IsInventoryItem;
		
		CalculateAmountInTabularSectionLine("Inventory", TabularSectionRow);
	
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibleDeliveryAttributes()
	
	Items.Location.Visible	= (Object.Worksite = PredefinedValue("Enum.Worksites.CustomerSite"));
	
EndProcedure

&AtServer
Function GetDeliveryAttributes(ShippingAddress)
	Return ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
EndFunction

&AtServer
Function GetDeliveryData(Counterparty)
	Return ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty, False);
EndFunction

&AtServer
Procedure RecalculateSubtotal()
	
	SubtotalsTable = Object.Inventory.Unload();
	For Each WorkLine In Object.Works Do
		NewLine = SubtotalsTable.Add();
		FillPropertyValues(NewLine, WorkLine);
	EndDo;
	
	Totals = DriveServer.CalculateSubtotal(SubtotalsTable, Object.AmountIncludesVAT, Object.SalesTax.Unload(), False);
	FillPropertyValues(ThisObject, Totals);
	FillPropertyValues(Object, Totals);
	
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
	DiscountKindChanged = DocumentParameters.DiscountKindChanged;
	If DocumentParameters.Property("ClearDiscountCard") Then
		ClearDiscountCard = True;
	Else
		ClearDiscountCard = False;
	EndIf;
	RecalculationRequiredInventory = DocumentParameters.RecalculationRequiredInventory;
	RecalculationRequiredWork = DocumentParameters.RecalculationRequiredWork;
	
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
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, (PriceKindChanged OR DiscountKindChanged), WarningText);
		
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
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
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

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers(False);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
	FillVATRateByCompanyVATTaxation();
	FillSalesTaxRate();
	SetVisibleTaxAttributes();
	SetAutomaticVATCalculation();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure InventoryStructuralUnitOnChangeAtServer()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure InventoryWarehouseOnChangeAtServer()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillConsumersInventory", False);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined)
	
	ProductsData = New Structure;
	
	ProductsData.Insert("MeasurementUnit", Catalogs.UOMClassifier.EmptyRef());
	ProductsData.Insert("ProductsType", Enums.ProductsTypes.EmptyRef());
	ProductsData.Insert("VATRate", Catalogs.VATRates.EmptyRef());
	ProductsData.Insert("Taxable", False);
	ProductsData.Insert("Description", "");
	ProductsData.Insert("ReplenishmentMethod", Enums.InventoryReplenishmentMethods.EmptyRef());
	
	If ValueIsFilled(StructureData.Products) Then
		
		ProductsData = Common.ObjectAttributesValues(StructureData.Products,
			"MeasurementUnit, ProductsType, VATRate, Taxable, Description, ReplenishmentMethod");
		
	EndIf;
	
	StructureData.Insert("MeasurementUnit", ProductsData.MeasurementUnit);
	
	StructureData.Insert("IsService", ProductsData.ProductsType = Enums.ProductsTypes.Service);
	StructureData.Insert("IsInventoryItem", ProductsData.ProductsType = Enums.ProductsTypes.InventoryItem);
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	If StructureData.Property("VATTaxation")
		And Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(ProductsData.VATRate) Then
		StructureData.Insert("VATRate", ProductsData.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("Taxable") Then
		StructureData.Insert("Taxable", ProductsData.Taxable);
	EndIf;
	
	StructureData.Insert("ShowSpecificationMessage", False);
	
	If Not ObjectDate = Undefined Then
		
		Specification = Undefined;
		
		If ProductsData.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
			Or ProductsData.ProductsType = Enums.ProductsTypes.Work Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		EndIf;
		If ProductsData.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
			Or ProductsData.ProductsType = Enums.ProductsTypes.Work
				And Not ValueIsFilled(Specification) Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		EndIf;
		StructureData.Insert("Specification", Specification);
		
		StructureData.Insert("ShowSpecificationMessage", True);
		StructureData.Insert("ProductDescription", ProductsData.Description);
		
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind")
		And ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
	
	If StructureData.Property("DiscountPercentByDiscountCard") 
		And ValueIsFilled(StructureData.DiscountCard) Then
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
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);
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

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByCompanyVATTaxation(True);
	FillSalesTaxRate();
	
	StructureData = GetDataContractOnChange(
		Date,
		DocumentCurrency,
		ContractByDefault,
		Company,
		CounterpartyAttributes.DoOperationsByContracts);
	
	StructureData.Insert("Contract", ContractByDefault);
	StructureData.Insert("CallFromProcedureAtCounterpartyChange", True);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract, Company, DoOperationsByContracts)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company));
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined));
	
	If DoOperationsByContracts And ValueIsFilled(Contract) Then
		
		StructureData.Insert("ShippingAddress", Common.ObjectAttributeValue(Contract, "ShippingAddress"));
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function MaterialsGetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	StructureData.Insert("StorageBin", DriveServer.GetStorageBin(StructureData));
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(StructureData.Object, "InventoryWarehouse");
		GLAccountsInDocuments.CompleteObjectParameters(StructureData.Object, ObjectParameters);
		
		StructureData.Insert("ObjectParameters", ObjectParameters);
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
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

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
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
		
	Else
		
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
		
		For Each TabularSectionRow In Object.Works Do
			
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// It receives data set from the server for the StructuralUnitOnChange procedure.
//
Function GetDataStructuralUnitOnChange(StructureData)
	
	If StructureData.Department.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
		OR StructureData.Department.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
	
		StructureData.Insert("InventoryStructuralUnit", StructureData.Department.TransferSource);
		StructureData.Insert("CellInventory", StructureData.Department.TransferSourceCell);

	Else
		
		StructureData.Insert("InventoryStructuralUnit", Undefined);
		StructureData.Insert("CellInventory", Undefined);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

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
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined, ColumnTS = Undefined, RecalcSalesTax = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	// Discounts.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	If RecalcSalesTax Then
		RecalculateSalesTax();
	EndIf;
	
EndProcedure

// Procedure calculates the quantity in the row of tabular section.
//
&AtClient
Procedure CalculateStandardHoursInTabularSectionLine(TabularSectionName = "Work", TabularSectionRow = Undefined, ColumnTS = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	WorkFilter = New Structure;
	WorkFilter.Insert("Products", TabularSectionRow.Products);
	WorkFilter.Insert("Characteristic", TabularSectionRow.Characteristic);
	WorkFilter.Insert("ProcessingDate", Object.Date);
	
	TabularSectionRow.StandardHours = TabularSectionRow.Quantity * DriveServer.GetWorkTimeRate(WorkFilter);
		
EndProcedure

&AtClient
Procedure RecalculateConnectedTables(Refill = False)
	
	TabularSectionName = "Works";
	
	TabularSectionRow = Items.Works.CurrentData;
	
	If Refill Then
	
		DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "Materials");
		DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "LaborAssignment");
		DeleteRowsOfInventoryTabularSection(TabularSectionRow.ConnectionKey);
		
		TabularSectionRow.Materials = "";
		TabularSectionRow.Performers = "";
		
	Else
		
		DeleteSubordinateRowsWithBOM("Materials", TabularSectionRow.ConnectionKey);
		DeleteSubordinateRowsWithBOM("Inventory", TabularSectionRow.ConnectionKey);
		
	EndIf;
	
	If ValueIsFilled(TabularSectionRow.Specification) Then
		
		FillByBillsOfMaterialsAtServer(TabularSectionRow.Specification, TabularSectionRow.ConnectionKey, TabularSectionRow.Quantity);
		FillInventoryByBillsOfMaterials(TabularSectionRow.Specification, TabularSectionRow.Quantity);
		
	EndIf;
	
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
		
		QuestionText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate", NewExchangeRate);
		AdditionalParameters.Insert("NewRatio", NewRatio);
		AdditionalParameters.Insert("NewContractCurrencyExchangeRate", NewContractCurrencyExchangeRate);
		AdditionalParameters.Insert("NewContractCurrencyRatio", NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewExchangeRatesettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
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
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("Company",						ParentCompany);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("PriceKind",						Object.PriceKind);
	ParametersStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard",					Object.DiscountCard);
	ParametersStructure.Insert("WarningText",					WarningText);
	
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
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByPriceKind() 
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",			ParentCompany);
	DataStructure.Insert("PriceKind",				Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	
	DataStructure.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	DataStructure.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	DataStructure.Insert("DiscountMarkupPercent", 0);
	
	For Each TSRow In Object.Works Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;
		EndIf;
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		TSRow.Products);
		TabularSectionRow.Insert("Characteristic",	TSRow.Characteristic);
		TabularSectionRow.Insert("Price",			0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
	
	GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
	For Each TSRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products", TSRow.Products);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		
		SearchResult = Object.Works.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			ResultRow.Price = TSRow.Price;
			CalculateAmountInTabularSectionLine("Works", ResultRow, "Price", False);
		EndDo;
		
	EndDo;
	
	For Each TabularSectionRow In Object.Works Do
		TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
		CalculateAmountInTabularSectionLine("Works", TabularSectionRow, "Price", False);
	EndDo;
	
	RecalculateSalesTax();
	
EndProcedure

&AtServerNoContext
// Filling the tabular section Work with bundled service.
// 
Function BundledServiceComposition(WorkKind)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	BundledServicesWorksAndServices.Products AS Products,
	|	BundledServicesWorksAndServices.StandardHours AS StandardHours,
	|	BundledServicesWorksAndServices.Specification AS Specification
	|FROM
	|	Catalog.BundledServices.WorksAndServices AS BundledServicesWorksAndServices
	|WHERE
	|	BundledServicesWorksAndServices.Ref = &WorkKind";
	
	Query.SetParameter("WorkKind", WorkKind);
	
	BundledServicesArray = New Array;
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		BundledServicesStructure = New Structure("Products, StandardHours, Specification");
		FillPropertyValues(BundledServicesStructure, SelectionDetailRecords);
		BundledServicesArray.Add(BundledServicesStructure);
		
	EndDo;
	
	Return BundledServicesArray;
	
EndFunction

&AtClient
// Filling the tabular section Work with bundled service.
// 
Procedure FillWithBundledService(WorkKind)
	
	ArrayToDel = New Array;
	
	For Each WorkLine In Object.Works Do
		If WorkLine.WorkKind = WorkKind Then
			ArrayToDel.Add(WorkLine);
		EndIf;
	EndDo;
	
	TabularSectionName = "Works";
	For Each DelLine In ArrayToDel Do
		
		// Clear Materials
		SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", DelLine.ConnectionKey));
		For Each SearchString In SearchResult Do
			IndexOfDeletion = Object.Materials.IndexOf(SearchString);
			Object.Materials.Delete(IndexOfDeletion);
		EndDo;
		
		// Clear LaborAssignment
		SearchResult = Object.LaborAssignment.FindRows(New Structure("ConnectionKey", DelLine.ConnectionKey));
		For Each SearchString In SearchResult Do
			IndexOfDeletion = Object.LaborAssignment.IndexOf(SearchString);
			Object.LaborAssignment.Delete(IndexOfDeletion);
		EndDo;
		
		Object.Works.Delete(DelLine);
		
		ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
		
	EndDo;
	
	WorksTable = BundledServiceComposition(WorkKind);
	
	For Each WorkLine In WorksTable Do
		
		TabularSectionRow = Object.Works.Add();
		FillPropertyValues(TabularSectionRow, WorkLine);
		TabularSectionRow.WorkKind = WorkKind;
		TabularSectionName = "Works";
		TabularSectionRow.ConnectionKey = NewConnectionKey();
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("TimeNorm", 1);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		StructureData.Insert("DiscountCard", Object.DiscountCard);
		StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
		StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		
		StructureData.Insert("Object", Object);
		StructureData.Insert("TabName", "Works");
		StructureData = GetDataProductsOnChange(StructureData, Object.Date);
		
		TabularSectionRow.Quantity = 1;
		TabularSectionRow.StandardHours = ?(TabularSectionRow.StandardHours = 0, StructureData.TimeNorm, TabularSectionRow.StandardHours);
		TabularSectionRow.VATRate = StructureData.VATRate;
		TabularSectionRow.Specification = ?(ValueIsFilled(TabularSectionRow.Specification), TabularSectionRow.Specification, StructureData.Specification);
		TabularSectionRow.Content = "";
		
		If (ValueIsFilled(Object.PriceKind) AND StructureData.Property("Price")) OR StructureData.Property("Price") Then
			TabularSectionRow.Price = StructureData.Price;
			TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
		EndIf;
		
		TabularSectionRow.ProductsTypeService = StructureData.IsService;
		
		CalculateAmountInTabularSectionLine("Works", TabularSectionRow, , False);
		
	EndDo;
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
	RecalculateSalesTax();
	
EndProcedure

&AtServer
Function NewConnectionKey()
	
	Return DriveServer.CreateNewLinkKey(ThisObject);
	
EndFunction

&AtServerNoContext
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
// AttributesStructure - Attribute structure, which necessary
// when recalculation DocumentTabularSection - FormDataStructure, it
// contains the tabular document part.
//
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
		NewRow.Products = TSRow.Products;
		NewRow.Characteristic	 = TSRow.Characteristic;
		If TypeOf(TSRow) = Type("Structure") AND TSRow.Property("VATRate") Then
			NewRow.VATRate	 = TSRow.VATRate;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
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
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition))
	|		END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	TemporaryProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON (ProductsTable.Products = PricesSliceLast.Products)
	|			AND (ProductsTable.Characteristic = PricesSliceLast.Characteristic)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON (PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS DocumentCurrencyRate";
		
	Query.SetParameter("ProcessingDate",	DataStructure.Date);
	Query.SetParameter("PriceKind",			PriceKindParameter);
	Query.SetParameter("DocumentCurrency",	DataStructure.DocumentCurrency);
	Query.SetParameter("Company", 			DataStructure.Company);
	Query.SetParameter("ExchangeRateMethod",DriveServer.GetExchangeMethod(DataStructure.Company));	
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		If TypeOf(TSRow) = Type("Structure") AND TabularSectionRow.Property("VATRate") Then
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

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrencyForForm(LabelStructure)
	
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
	
	If LabelStructure.RegisteredForVAT
		Or LabelStructure.VATTaxation <> PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
	
		// VAT taxation.
		If ValueIsFilled(LabelStructure.VATTaxation) Then
			If IsBlankString(LabelText) Then
				LabelText = LabelText + "%1";
			Else
				LabelText = LabelText + " • %1";
			EndIf;
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.VATTaxation)));
		EndIf;
		
	EndIf;
	
	If LabelStructure.RegisteredForVAT Then
		
		// Flag showing that amount includes VAT.
		If IsBlankString(LabelText) Then
			If LabelStructure.AmountIncludesVAT Then
				LabelText = NStr("en = 'VAT inclusive'; ru = 'Сумма включает НДС';pl = 'Cena brutto';es_ES = 'IVA incluido';es_CO = 'IVA incluido';tr = 'KDV dahil';it = 'IVA inclusa';de = 'Inklusive USt.'");
			Else
				LabelText = NStr("en = 'VAT exclusive'; ru = 'Сумма не включает НДС';pl = 'VAT wyłączny';es_ES = 'IVA no incluido';es_CO = 'IVA no incluido';tr = 'KDV hariç';it = 'IVA esclusa';de = 'Exklusive USt.'");
			EndIf;
		EndIf;
	
	EndIf;
	
	Return LabelText;
	
EndFunction

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
	LabelStructure.Insert("RateNationalCurrency",			Form.RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				Form.RegisteredForVAT);
	LabelStructure.Insert("RegisteredForSalesTax",			Form.RegisteredForSalesTax);
	LabelStructure.Insert("SalesTaxRate",					Object.SalesTaxRate);
	
	Form.PricesAndCurrency = GenerateLabelPricesAndCurrencyForForm(LabelStructure);
	
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
		
		If BarcodeData <> Undefined AND BarcodeData.Count() <> 0 Then
			
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
				StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
				
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
				IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(
					StructureProductsData, StructureData.Object, "WorkOrder");
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "WorkOrder");
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
		
		If BarcodeData <> Undefined AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			Filter = New Structure("Products, Characteristic, MeasurementUnit, Batch");
			FillPropertyValues(Filter, BarcodeData);
			
			If BarcodesData.TableName = "Inventory" Then
				
				// Bundles
				Filter.Insert("BundleProduct",	PredefinedValue("Catalog.Products.EmptyRef"));
				// End Bundles
				
				TSRowsArray = Object.Inventory.FindRows(Filter);
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
					
					NewRow = TSRowsArray[0];
					NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
					CalculateAmountInTabularSectionLine( , NewRow);
					Items.Inventory.CurrentRow = NewRow.GetID();
					
				EndIf;
				
			ElsIf BarcodesData.TableName = "Materials" Then
				
				If Items.Materials.RowFilter = Undefined Then
					
					TabularSectionName = "Works";
					DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
					TabularSectionName	= "Materials";
					
				EndIf;
				
				Filter.Insert("ConnectionKey", Items.Materials.RowFilter["ConnectionKey"]);
				TSRowsArray = Object.Materials.FindRows(Filter);
				If TSRowsArray.Count() = 0 Then
					
					NewRow = Object.Materials.Add();
					FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
					NewRow.Products = BarcodeData.Products;
					NewRow.Characteristic = BarcodeData.Characteristic;
					NewRow.Batch = BarcodeData.Batch;
					NewRow.Quantity = CurBarcode.Quantity;
					NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
					NewRow.ConnectionKey = Items.Materials.RowFilter["ConnectionKey"];
					Items.Materials.CurrentRow = NewRow.GetID();
					
				Else
					
					NewRow = TSRowsArray[0];
					NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
					Items.Materials.CurrentRow = NewRow.GetID();
					
				EndIf;
				
				If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
					WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object, "ConnectionKeySerialNumbers");
				EndIf;
				
			ElsIf BarcodesData.TableName = "ConsumersInventory" Then
				
				TSRowsArray = Object.ConsumersInventory.FindRows(Filter);
				If TSRowsArray.Count() = 0 Then
					
					NewRow = Object.ConsumersInventory.Add();
					FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
					NewRow.Products = BarcodeData.Products;
					NewRow.Characteristic = BarcodeData.Characteristic;
					NewRow.Batch = BarcodeData.Batch;
					NewRow.Quantity = CurBarcode.Quantity;
					NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
					
					Items.ConsumersInventory.CurrentRow = NewRow.GetID();
					
				Else
					
					NewRow = TSRowsArray[0];
					NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
					Items.ConsumersInventory.CurrentRow = NewRow.GetID();
					
				EndIf;
				
			EndIf;
				
		EndIf;
	EndDo;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillConsumersInventory", False);
	ParametersStructure.Insert("FillMaterials", True);
	FillAddedColumns(ParametersStructure);
	
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
Procedure BarcodesAreReceivedFragment(UnknownBarcodes)
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Kod kreskowy nie został znaleziony: %1%; ilość: %2%';es_ES = 'Código de barras no encontrado: %1%; cantidad: %2%';es_CO = 'Código de barras no encontrado: %1%; cantidad: %2%';tr = 'Barkod bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità:%2%';de = 'Barcode wird nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

&AtServer
// Procedure fills inventories by specification.
//
Procedure FillByBillsOfMaterialsAtServer(BySpecification, ConnectionKey, RequiredQuantity = 1, UsedMeasurementUnit = Undefined)
	
	Query = New Query(
	"SELECT
	|	MAX(BillsOfMaterialsContent.LineNumber) AS BillsOfMaterialsContentLineNumber,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	SUM(CASE
	|			WHEN BillsOfMaterialsContent.Ref.Quantity = 0
	|				THEN 0
	|			ELSE BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * &Factor * &Quantity
	|		END) AS Quantity,
	|	TRUE AS FromBOM,
	|	CASE
	|		WHEN ProductsCatalog.Warehouse = &Warehouse
	|			THEN ProductsCatalog.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS StorageBin
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON BillsOfMaterialsContent.Products = ProductsCatalog.Ref
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND BillsOfMaterialsContent.Products.ProductsType = &ProductsType
	|	AND NOT BillsOfMaterialsContent.GoodsForSale
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType,
	|	CASE
	|		WHEN ProductsCatalog.Warehouse = &Warehouse
	|			THEN ProductsCatalog.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END
	|
	|ORDER BY
	|	BillsOfMaterialsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("Warehouse", Object.InventoryWarehouse);
	Query.SetParameter("Specification", BySpecification);
	Query.SetParameter("Quantity", RequiredQuantity);
	
	If Not TypeOf(UsedMeasurementUnit) = Type("CatalogRef.UOMClassifier")
		AND UsedMeasurementUnit <> Undefined Then
		Query.SetParameter("Factor", UsedMeasurementUnit.Factor);
	Else
		Query.SetParameter("Factor", 1);
	EndIf;
	
	Query.SetParameter("ProductsType", Enums.ProductsTypes.InventoryItem);
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, "InventoryWarehouse");
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Object.Materials.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.ConnectionKey = ConnectionKey;
		
		If UseDefaultTypeOfAccounting Then
			
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, "Materials");
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
// Procedure fills inventories by specification.
//
Procedure FillInventoryByBillsOfMaterials(BySpecification, RequiredQuantity = 1)
	
	FillInventoryByBOMAtServer(BySpecification, RequiredQuantity);
	
	For Each TabularSectionRow In Object.Inventory Do
		If TabularSectionRow.ConnectionKeyForWorks = Items.Materials.RowFilter["ConnectionKey"] Then
			ProcessProductsProductsChange(TabularSectionRow);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillInventoryByBOMAtServer(BySpecification, RequiredQuantity)
	
	Query = New Query(
	"SELECT
	|	MAX(BillsOfMaterialsContent.LineNumber) AS BillsOfMaterialsContentLineNumber,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	SUM(BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * &Quantity) AS Quantity,
	|	TRUE AS FromBOM
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND BillsOfMaterialsContent.ContentRowType = &ContentRowType
	|	AND BillsOfMaterialsContent.GoodsForSale
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType
	|
	|ORDER BY
	|	BillsOfMaterialsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("Specification", BySpecification);
	Query.SetParameter("ContentRowType", Enums.BOMLineType.Material);
	Query.SetParameter("Quantity", RequiredQuantity);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.ConnectionKeyForWorks = Items.Materials.RowFilter["ConnectionKey"];
		
	EndDo;
	
EndProcedure

&AtServer
// Get materials by BillsOfMaterials
//
Procedure MoveMaterialsToTableFieldWithRecordKeys(TableOfBillsOfMaterials, UseDefaultTypeOfAccounting)
	
	Query	= New Query;
	
	Query.Text = 
	"SELECT
	|	TableOfBillsOfMaterials.Specification AS Specification,
	|	TableOfBillsOfMaterials.Quantity AS Quantity,
	|	TableOfBillsOfMaterials.CoefficientFromBaseMeasurementUnit AS CoefficientFromBaseMeasurementUnit,
	|	TableOfBillsOfMaterials.ConnectionKey AS ConnectionKey
	|INTO TmpSpecificationTab
	|FROM
	|	&TableOfBillsOfMaterials AS TableOfBillsOfMaterials
	|WHERE
	|	NOT TableOfBillsOfMaterials.ProductsTypeService
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TmpSpecificationTab.ConnectionKey AS ConnectionKey,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	BillsOfMaterialsContent.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN BillsOfMaterialsContent.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|			THEN CASE
	|					WHEN NOT BillsOfMaterialsContent.MeasurementUnit = BillsOfMaterialsContent.Products.MeasurementUnit
	|						THEN CASE
	|								WHEN BillsOfMaterialsContent.MeasurementUnit.Factor = 0
	|									THEN 1
	|								ELSE BillsOfMaterialsContent.MeasurementUnit.Factor
	|							END
	|					ELSE 1
	|				END
	|		ELSE 1
	|	END AS CoefficientFromBaseMeasurementUnit,
	|	CASE
	|		WHEN BillsOfMaterialsContent.Ref.Quantity = 0
	|			THEN 0
	|		ELSE BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * TmpSpecificationTab.Quantity * CASE
	|				WHEN ISNULL(TmpSpecificationTab.CoefficientFromBaseMeasurementUnit, 0) = 0
	|					THEN 1
	|				ELSE TmpSpecificationTab.CoefficientFromBaseMeasurementUnit
	|			END
	|	END AS Quantity,
	|	BillsOfMaterialsContent.Ref.Quantity AS ProductsQuantity,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	TRUE AS FromBOM,
	|	CASE
	|		WHEN ProductsCatalog.Warehouse = &Warehouse
	|			THEN ProductsCatalog.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS StorageBin
	|FROM
	|	TmpSpecificationTab AS TmpSpecificationTab
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|			LEFT JOIN Catalog.Products AS ProductsCatalog
	|			ON BillsOfMaterialsContent.Products = ProductsCatalog.Ref
	|		ON TmpSpecificationTab.Specification = BillsOfMaterialsContent.Ref
	|WHERE
	|	NOT BillsOfMaterialsContent.GoodsForSale
	|	AND BillsOfMaterialsContent.ContentRowType = VALUE(Enum.BOMLineType.Material)";
	
	Query.SetParameter("TableOfBillsOfMaterials", TableOfBillsOfMaterials);
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("Warehouse", Object.InventoryWarehouse);
	
	QueryResult = Query.Execute().Unload();
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, "InventoryWarehouse");
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each TableRow In QueryResult Do
		
		NewRow = Object.Materials.Add();
		FillPropertyValues(NewRow, TableRow);
		
		If UseDefaultTypeOfAccounting Then
			
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, "Materials");
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure MoveInventotyToTableFieldWithRecordKeys(TableOfBillsOfMaterials)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TableOfBillsOfMaterials.Specification AS Specification,
	|	TableOfBillsOfMaterials.Quantity AS Quantity,
	|	TableOfBillsOfMaterials.CoefficientFromBaseMeasurementUnit AS CoefficientFromBaseMeasurementUnit,
	|	TableOfBillsOfMaterials.ConnectionKey AS ConnectionKey
	|INTO TmpSpecificationTab
	|FROM
	|	&TableOfBillsOfMaterials AS TableOfBillsOfMaterials
	|WHERE
	|	NOT TableOfBillsOfMaterials.ProductsTypeService
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TmpSpecificationTab.ConnectionKey AS ConnectionKeyForWorks,
	|	BillsOfMaterialsContent.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * TmpSpecificationTab.Quantity * CASE
	|		WHEN ISNULL(TmpSpecificationTab.CoefficientFromBaseMeasurementUnit, 0) = 0
	|			THEN 1
	|		ELSE TmpSpecificationTab.CoefficientFromBaseMeasurementUnit
	|	END AS Quantity
	|FROM
	|	TmpSpecificationTab AS TmpSpecificationTab
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TmpSpecificationTab.Specification = BillsOfMaterialsContent.Ref
	|WHERE
	|	BillsOfMaterialsContent.ContentRowType = VALUE(Enum.BOMLineType.Material)
	|	AND BillsOfMaterialsContent.GoodsForSale";
	
	Query.SetParameter("TableOfBillsOfMaterials", TableOfBillsOfMaterials);
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	
	Selection = Query.Execute().Select();
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	While Selection.Next() Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		
		If UseDefaultTypeOfAccounting Then

			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, "Inventory");
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
// Calls the material fill procedure by
// all BillsOfMaterials Next minimizes the row duplicates
Procedure FillMaterialsByAllBillsOfMaterialsAtServer()
	
	Works_ValueTable = FormAttributeToValue("Object").Works.Unload();
	
	// Delete rows without BillsOfMaterials and with BillsOfMaterials without content
	Counter = (Works_ValueTable.Count() - 1);
	While Counter >= 0 Do
		If Works_ValueTable[Counter].Specification.Content.Count() = 0 Then 
			Works_ValueTable.Delete(Works_ValueTable[Counter]);
		EndIf;
		Counter = Counter - 1;
	EndDo;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	Works_ValueTable.Columns.Add("CoefficientFromBaseMeasurementUnit", New TypeDescription("Number"));
	MoveMaterialsToTableFieldWithRecordKeys(Works_ValueTable, UseDefaultTypeOfAccounting);
	
	ColumnNamesArray = New Array;
	ColumnNamesArray.Add("ConnectionKey");
	ColumnNamesArray.Add("Products");
	ColumnNamesArray.Add("Characteristic");
	ColumnNamesArray.Add("Batch");
	ColumnNamesArray.Add("MeasurementUnit");
	ColumnNamesArray.Add("StorageBin");
	ColumnNamesArray.Add("FromBOM");
	ColumnNamesArray.Add("ExpenseItem");
	ColumnNamesArray.Add("RegisterExpense");
	
	If UseDefaultTypeOfAccounting Then
		ColumnNamesArray.Add("GLAccounts");
		ColumnNamesArray.Add("InventoryGLAccount");
		ColumnNamesArray.Add("InventoryReceivedGLAccount");
		ColumnNamesArray.Add("ConsumptionGLAccount");
	EndIf;
	
	// Everything is filled now we will minimize the duplicating rows.
	MaterialsTable = Object.Materials.Unload();
	MaterialsTable.GroupBy(StrConcat(ColumnNamesArray, ","), "Quantity, Reserve");
	
	Object.Materials.Clear();
	Object.Materials.Load(MaterialsTable);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure FillInventoryFromAllBillsOfMaterialsAtServer()
	
	Modified = True;
	
	RowsToDel = New Array;
	For Each InventoryRow In Object.Inventory Do
		If ValueIsFilled(InventoryRow.ConnectionKeyForWorks) Then
			RowsToDel.Add(InventoryRow);
		EndIf;
	EndDo;
	
	For Each RowToDel In RowsToDel Do
		Object.Inventory.Delete(RowToDel);
	EndDo;
	
	Works_ValueTable = Object.Works.Unload();
	
	// Delete rows without BillsOfMaterials and with BillsOfMaterials without content
	Counter = (Works_ValueTable.Count() - 1);
	While Counter >= 0 Do
		If Works_ValueTable[Counter].Specification.Content.Count() = 0 Then 
			Works_ValueTable.Delete(Works_ValueTable[Counter]);
		EndIf;
		Counter = Counter - 1;
	EndDo;
	
	Works_ValueTable.Columns.Add("CoefficientFromBaseMeasurementUnit", New TypeDescription("Number"));
	
	MoveInventotyToTableFieldWithRecordKeys(Works_ValueTable);
	
EndProcedure
&AtServer
// Generates column content Materials and Performers in the PM Work Work order.
//
Procedure MakeNamesOfMaterialsAndPerformers()
	
	// Subordinate TP
	UseSecondaryEmployment = GetFunctionalOption("UseSecondaryEmployment");
	For Each WorkRow In Object.Works Do
	
		StringMaterials = "";
		ArrayByKeyRecords = Object.Materials.FindRows(New Structure("ConnectionKey", WorkRow.ConnectionKey));
		For Each TSRow In ArrayByKeyRecords Do
			StringMaterials = StringMaterials + ?(StringMaterials = "", "", ", ") + TSRow.Products 
								+ ?(ValueIsFilled(TSRow.Characteristic), " (" + TSRow.Characteristic + ")", "");
		EndDo;
		WorkRow.Materials = StringMaterials;
		
		TablePerformers = Object.LaborAssignment.Unload(New Structure("ConnectionKey", WorkRow.ConnectionKey), "Employee");
		Query = New Query;
		
		Query.Text = 
		"SELECT
		|	Employees.Code,
		|	Employees.Description,
		|	ChangeHistoryOfIndividualNamesSliceLast.Surname,
		|	ChangeHistoryOfIndividualNamesSliceLast.Name,
		|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic
		|FROM
		|	Catalog.Employees AS Employees
		|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&ToDate, ) AS ChangeHistoryOfIndividualNamesSliceLast
		|		ON Employees.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
		|WHERE
		|	Employees.Ref IN(&TablePerformers)";
		
		Query.SetParameter("ToDate", Object.Date);
		Query.SetParameter("TablePerformers", TablePerformers);
		
		Selection = Query.Execute().Select();
		
		StringPerformers = "";
		While Selection.Next() Do
			PresentationEmployee = DriveServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic);
			StringPerformers = StringPerformers + ?(StringPerformers = "", "", ", ")
				+ ?(ValueIsFilled(PresentationEmployee), PresentationEmployee, Selection.Description);
			If UseSecondaryEmployment Then
				StringPerformers = StringPerformers + " (" + TrimAll(Selection.Code) + ")";
			EndIf;
		EndDo;
		WorkRow.Performers = StringPerformers;
	
	EndDo;
	
EndProcedure

// Procedure fills the tabular section Performers by teams.
//
&AtServer
Procedure FillTabularSectionPerformersByTeamsAtServer(ArrayOfTeams, PerformersConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionPerformersByTeams(ArrayOfTeams, PerformersConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, Cancel)
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND GetFunctionalOption("CheckContractsOnPosting") Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, DoOperationsByContracts, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

// Performs actions when counterparty contract is changed.
//
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
			
			If Object.Location <> ContractData.ShippingAddress Then
				
				Object.Location = ContractData.ShippingAddress;
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
			AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0);
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("DiscountKindChanged", DiscountKindChanged);
		DocumentParameters.Insert("ClearDiscountCard", ClearDiscountCard);
		DocumentParameters.Insert("RecalculationRequiredInventory", Object.Inventory.Count() > 0);
		DocumentParameters.Insert("RecalculationRequiredWork", Object.Works.Count() > 0);
		
		ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessShippingAddressChange()
	
	DeliveryData = GetDeliveryAttributes(Object.Location);
	
	If ValueIsFilled(DeliveryData.SalesRep) Then
		Object.SalesRep = DeliveryData.SalesRep;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, SalesRep, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForSalesTax = AccountingPolicy.RegisteredForSalesTax;
	PostExpensesByWorkOrder = AccountingPolicy.PostExpensesByWorkOrder;
	
	Items.WorksProject.Visible				= PostExpensesByWorkOrder;
	Items.InventoryProject.Visible			= PostExpensesByWorkOrder;
	Items.LaborAssignmentProject.Visible	= PostExpensesByWorkOrder;
	Items.MaterialsProject.Visible			= PostExpensesByWorkOrder;
	Items.MaterialsSerialNumbers.Visible	= PostExpensesByWorkOrder;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure WOGoodsFillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.GoodsFillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure MaterialsFillColumnReserveByBalancesAtServer(MaterialsConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.MaterialsFillColumnReserveByBalances(MaterialsConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure DeleteRowsOfInventoryTabularSection(WorksConnectionKey)
	
	SubordinateTabularSection = Object.Inventory;
	
	SearchResult = SubordinateTabularSection.FindRows(New Structure("ConnectionKeyForWorks", WorksConnectionKey));
	For Each SearchString In SearchResult Do
		IndexOfDeletion = SubordinateTabularSection.IndexOf(SearchString);
		SubordinateTabularSection.Delete(IndexOfDeletion);
	EndDo;
	
EndProcedure

&AtClient
Procedure DeleteSubordinateRowsWithBOM(TabularSectionName, WorksConnectionKey)
	
	SubordinateTabularSection = Object[TabularSectionName];
	ConnectionKeyAttributeName = ?(TabularSectionName = "Materials", "ConnectionKey", "ConnectionKeyForWorks");
	
	ArrayToDel = New Array;
		
	For Each TabRow In SubordinateTabularSection Do
		If TabRow[ConnectionKeyAttributeName] = WorksConnectionKey
			AND TabRow.FromBOM Then
			
			ArrayToDel.Add(TabRow);
			
		EndIf;
	EndDo;
	
	For Each RowToDel In ArrayToDel Do
		SubordinateTabularSection.Delete(RowToDel);
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 			TabName);
	StructureData.Insert("Object",				Form.Object);
	StructureData.Insert("Batch",				TabRow.Batch);
	
	If StructureData.TabName = "Materials" Then
		StructureData.Insert("Ownership", TabRow.Ownership);
		StructureData.Insert("ExpenseItem", TabRow.ExpenseItem);
		StructureData.Insert("RegisterExpense", TabRow.RegisterExpense);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
		
		If StructureData.TabName = "ConsumersInventory" Then
			StructureData.Insert("InventoryReceivedGLAccount", TabRow.InventoryReceivedGLAccount);
		ElsIf StructureData.TabName = "Materials" Then
			StructureData.Insert("InventoryGLAccount", TabRow.InventoryGLAccount);
			StructureData.Insert("InventoryReceivedGLAccount", TabRow.InventoryReceivedGLAccount);
			StructureData.Insert("ConsumptionGLAccount", TabRow.ConsumptionGLAccount);
		ElsIf StructureData.TabName = "Inventory" Then
			StructureData.Insert("InventoryGLAccount", TabRow.InventoryGLAccount);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, "StructuralUnitReserve");
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
	
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		
		If ParametersStructure.FillInventory Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
			GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
			StructureArray.Add(StructureData);
			
		EndIf;
		
		If ParametersStructure.FillConsumersInventory Then 
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "ConsumersInventory");
			GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "ConsumersInventory");
			StructureArray.Add(StructureData);
			
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillMaterials Then 
		
		ObjectParameters.Insert("StructuralUnit", Object.InventoryWarehouse);
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Materials");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Materials");
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	SetVisibleTaxAttributes();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	
	FillAddedColumns(ParametersStructure);
	
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
Procedure DatesChangeProcessing()
	
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
	
EndProcedure

#EndRegion

#Region ProcedureForWorksWithPick

// Fixes error in event log
//
&AtClient
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogClient.AddMessageForEventLog("Error", , EventLogMonitorErrorText);
	
EndProcedure

// Function gets a product list from the temporary storage
//
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
	
	If TabularSectionName = "Materials" Then
		
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, "InventoryWarehouse");
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		EndIf;
		
	Else
		
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object, "StructuralUnitReserve");
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		EndIf;
		
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
		If NewRow.Property("Total")
			AND Not ValueIsFilled(NewRow.Total) Then
			
			NewRow.Total = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
			
		EndIf;
		
		// Refilling
		If TabularSectionName = "Works" Then
			
			NewRow.StandardHours = 1;
			
			NewRow.ConnectionKey = DriveServer.CreateNewLinkKey(ThisObject);
			
			If ValueIsFilled(ImportRow.Products) Then
				NewRow.ProductsTypeService = ImportRow.Products.ProductsType = Enums.ProductsTypes.Service;
			EndIf;
			
			Specification = Undefined;
			ProductsAttributes = Common.ObjectAttributesValues(NewRow.Products, "ReplenishmentMethod, ProductsType");
			If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
				Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work Then
				Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(NewRow.Products,
					Object.Date, 
					NewRow.Characteristic,
					Enums.OperationTypesProductionOrder.Assembly);
			EndIf;
			If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
				Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work
					And Not ValueIsFilled(Specification) Then
				Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(NewRow.Products,
					Object.Date, 
					NewRow.Characteristic,
					Enums.OperationTypesProductionOrder.Production);
			EndIf;
			NewRow.Specification = Specification;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			If ValueIsFilled(ImportRow.Products) Then
				NewRow.ProductsTypeInventory = ImportRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem;
			EndIf;
			
			// Bundles
			If ImportRow.IsBundle Then
				
				StructureData = New Structure;
				StructureData.Insert("Company", Object.Company);
				StructureData.Insert("Products", ImportRow.Products);
				StructureData.Insert("Characteristic", ImportRow.Characteristic);
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
				StructureData.Insert("DiscountCard", Object.DiscountCard);
				StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
				// End DiscountCards
				
				AddTabRowDataToStructure(ThisObject, "Inventory", StructureData, NewRow);
				
				StructureData = GetDataProductsOnChange(StructureData);
				
				ReplaceInventoryLineWithBundleData(ThisObject, NewRow, StructureData);
				
			EndIf;
			// End Bundles
			
		EndIf;
		
	EndDo;
	
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
			AreCharacteristics		= True;
			
			If SelectionMarker = "Works" Then
				
				If PickupForMaterialsInWorks Then
					
					TabularSectionName	= "Materials";
					AreBatches			= True;
					
					If Items[TabularSectionName].RowFilter = Undefined Then
						
						TabularSectionName = "Works";
						DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
						TabularSectionName	= "Materials";
						
					EndIf;
					
					MaterialsGetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
					
					FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
					Items[TabularSectionName].RowFilter = FilterStr;
					
				Else
					
					TabularSectionName	= "Works";
					AreBatches			= False;
					
					GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
					
					RecalculateSalesTax();
					RecalculateSubtotal();
					
					// Cash flow projection.
					PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
					
				EndIf;
				
			ElsIf SelectionMarker = "Inventory" Then
				
				TabularSectionName	= "Inventory";
				AreBatches 			= True;
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
				If Not IsBlankString(EventLogMonitorErrorText) Then
					WriteErrorReadingDataFromStorage();
				EndIf;
				
				RecalculateSalesTax();
				RecalculateSubtotal();
				
				// Cash flow projection.
				PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
				
			ElsIf SelectionMarker = "ConsumersInventory" Then
				
				TabularSectionName	= "ConsumersInventory";
				AreBatches 			= False;
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
			EndIf;
			
			Modified = True;
			
			ParametersStructure = New Structure;
			ParametersStructure.Insert("GetGLAccounts", False);
			ParametersStructure.Insert("FillInventory", False);
			ParametersStructure.Insert("FillConsumersInventory", False);
			ParametersStructure.Insert("FillMaterials", True);
			
			FillAddedColumns(ParametersStructure);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DataProcessorProcedureButtonPressPickTPMaterials

&AtServer
// Function gets a product list from the temporary storage
//
Procedure MaterialsGetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object.Materials.Add();
		FillPropertyValues(NewRow, ImportRow);
		
		StructureData = New Structure;
		StructureData.Insert("Products", NewRow.Products);
		StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		StructureData.Insert("Warehouse", Object.InventoryWarehouse);
		
		AddTabRowDataToStructure(ThisObject, "Materials", StructureData, NewRow);
		
		StructureData = MaterialsGetDataProductsOnChange(StructureData);
		FillPropertyValues(NewRow, StructureData);
		
		NewRow.ConnectionKey = Items.Materials.RowFilter["ConnectionKey"];
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure sets form item availability from order stage.
//
&AtServer
Procedure SetVisibleAndEnabledFromState()
	
	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	Items.InventoryReserve.Visible						= NOT StatusIsComplete;
	Items.InventoryChangeReserveFillByBalances.Visible	= NOT StatusIsComplete;
	Items.MaterialsReserve.Visible						= NOT StatusIsComplete;
	Items.MaterialsGroupFill.Visible					= NOT StatusIsComplete;
	Items.ExecutorsFillByTeams.Visible					= NOT StatusIsComplete;
	
	If GetAccessRightForDocumentPosting() Then
		Items.FormPost.Enabled			= (Not StatusIsComplete Or Not Object.Closed);
		Items.FormPostAndClose.Enabled	= (Not StatusIsComplete Or Not Object.Closed);
	EndIf;
	
	Items.FormWrite.Enabled							= Not StatusIsComplete Or Not Object.Closed;
	Items.FormCreateBasedOn.Enabled 				= Not StatusIsComplete Or Not Object.Closed;
	Items.CloseOrder.Visible						= Not Object.Closed;
	Items.CloseOrderStatus.Visible					= Not Object.Closed;
	CloseOrderEnabled 								= DriveServer.CheckCloseOrderEnabled(Object.Ref);
	Items.CloseOrder.Enabled						= CloseOrderEnabled;
	Items.CloseOrderStatus.Enabled					= CloseOrderEnabled;
	Items.InventoryCommandBar.Enabled				= Not StatusIsComplete;
	Items.PricesAndCurrency.Enabled					= Not StatusIsComplete;
	Items.ReadDiscountCard.Enabled					= Not StatusIsComplete;
	Items.WorksWorksSelection.Enabled				= Not StatusIsComplete;
	Items.WorksCalculateDiscountsMarkups.Enabled	= Not StatusIsComplete;
	Items.MaterialsMaterialsPickup.Enabled			= Not StatusIsComplete;
	Items.CustomerMaterialsMaterialsPickup.Enabled	= Not StatusIsComplete;
	Items.FillByBasis.Enabled						= Not StatusIsComplete;
	
	Items.Counterparty.ReadOnly				= StatusIsComplete;
	Items.Contract.ReadOnly					= StatusIsComplete;
	Items.GroupStartSummary.ReadOnly		= StatusIsComplete;
	Items.RightColumn.ReadOnly				= StatusIsComplete;
	Items.GroupTerms.ReadOnly				= StatusIsComplete;
	Items.GroupWorkDescription.ReadOnly		= StatusIsComplete;
	Items.GroupComment.ReadOnly				= StatusIsComplete;
	Items.Equipment.ReadOnly				= StatusIsComplete;
	Items.SerialNumber.ReadOnly				= StatusIsComplete;
	Items.BasisDocument.ReadOnly			= StatusIsComplete;
	
	Items.GroupWork.ReadOnly				= StatusIsComplete;
	Items.GroupInventory.ReadOnly			= StatusIsComplete;
	Items.GroupConsumerMaterials.ReadOnly	= StatusIsComplete;
	Items.GroupPerformers.ReadOnly			= StatusIsComplete;
	Items.GroupPaymentsCalendar.ReadOnly	= StatusIsComplete;
	Items.GroupAdditional.ReadOnly			= StatusIsComplete;
	
	Items.MaterialsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.ConsumersInventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
EndProcedure

&AtServerNoContext
Function GetAccessRightForDocumentPosting()
	
	Return AccessRight("Posting", Metadata.Documents.WorkOrder);
	
EndFunction

&AtServer
// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	Items.GroupPerformers.Visible = UsePayrollSubsystem;
	
EndProcedure

// Procedure sets the form item visible.
//
&AtServer
Procedure SetVisibleFromUserSettings()
	
	If Object.WorkKindPosition = Enums.AttributeStationing.InHeader Then
		Items.WorkKind.Visible = True;
		Items.WorksWorkKind.Visible = False;
		Items.TableWorksWorkKind.Visible = False;
		WorkKindInHeader = True;
	Else
		Items.WorkKind.Visible = False;
		Items.WorksWorkKind.Visible = True;
		Items.TableWorksWorkKind.Visible = True;
		WorkKindInHeader = False;
	EndIf;
	
EndProcedure

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtServer
Procedure SetSerialNumberEnable()

	Items.SerialNumber.Enabled = UseSerialNumbersBalance AND Object.Equipment.UseSerialNumbers;
	If Items.SerialNumber.Enabled Then
		Items.SerialNumber.InputHint = "";
	Else
		Items.SerialNumber.InputHint = NStr("en = '<not use>'; ru = '<Не используется>';pl = '<nie używane>';es_ES = '<no se usa>';es_CO = '<no se usa>';tr = '<kullanmayın>';it = '<non utilizzato>';de = '<nicht verwendet>'");
	EndIf;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctionsOfPaymentCalendar

&AtServerNoContext
Function EmployeePosition(Employee, Company)
	
	Position = Catalogs.Positions.EmptyRef();
	
	If ValueIsFilled(Employee) And ValueIsFilled(Company) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	EmployeesSliceLast.Position AS Position
		|FROM
		|	InformationRegister.Employees.SliceLast(
		|			,
		|			Company = &Company
		|				AND Employee = &Employee) AS EmployeesSliceLast";
		
		Query.SetParameter("Company", Company);
		Query.SetParameter("Employee", Employee);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			Position = SelectionDetailRecords.Position;
		EndIf;
		
	EndIf;
	
	Return Position;
	
EndFunction

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

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPaymentCalendarAsListAsString.CurrentPage = Items.GroupPaymentCalendarAsList;
	Else
		Items.GroupPaymentCalendarAsListAsString.CurrentPage = Items.GroupPaymentCalendarAsString;
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

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.WorksPrice);
	
	Return Fields;
	
EndFunction

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
	SetVisibleAndEnabledFromState();
	
EndProcedure

&AtServer
Procedure CloseOrderFragment(Result = Undefined, AdditionalParameters = Undefined)
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.Ref);
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("WorkOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Read();
	
EndProcedure

&AtServerNoContext
Function GetWorkOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	WorkOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON WorkOrderStatuses.OrderStatus = OrderStatuses.Ref
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

#Region SerialNumbers

&AtClient
Procedure OpenSelectionMaterialsSerialNumbers()
	
	CurrentDataIdentifier = Items.Materials.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParametersMaterials(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersMaterialsFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Materials");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbersMaterials");
	ParametersFieldNames.Insert("FieldNameConnectionKey", "ConnectionKeySerialNumbers");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParametersMaterials(RowID, PickMode = Undefined, TSName = "Materials", TSNameSerialNumbers = "SerialNumbersMaterials")
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, RowID, True,
		"Materials", "SerialNumbersMaterials", "ConnectionKeySerialNumbers");
	
EndFunction

#EndRegion

#Region AutomaticDiscounts

// Procedure calculates discounts by document.
//
&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject", True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation", False);
	
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
	ParameterStructure.Insert("ApplyToObject", False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation", False);
	
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
				If Object.DiscountsMarkups[LineNumber-1].Amount <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].Amount
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
	Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
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
	
	For Each CurrentRow In Object.Works Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure OpenInformationAboutDiscountsClient(TSName)
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject", True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation", False);
	
	ParameterStructure.Insert("OnlyMessagesAfterRegistration", False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	If Not Object.DiscountsAreCalculated Then
		QuestionText = NStr("en = 'The discounts are not applied. Do you want to apply them?'; ru = 'Скидки (наценки) не рассчитаны, рассчитать?';pl = 'Zniżki nie są stosowane. Czy chcesz je zastosować?';es_ES = 'Los descuentos no se han aplicado. ¿Quiere aplicarlos?';es_CO = 'Los descuentos no se han aplicado. ¿Quiere aplicarlos?';tr = 'İndirimler uygulanmadı. Uygulamak istiyor musunuz?';it = 'Gli sconti non sono applicati. Volete applicarli?';de = 'Die Rabatte werden nicht angewendet. Möchten Sie sie anwenden?'");
		
		AdditionalParameters = New Structure("TSName", TSName); 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, TSName);
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
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, AdditionalParameters.TSName);
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row after calculation of automatic discounts (if it was necessary).
//
&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, TSName)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items[TSName].CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0) AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
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
	If UseAutomaticDiscounts AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0) AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn, "Inventory", "Works");
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 AND Object.Works.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
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
			NStr("en = 'Customer is filled in and discount card is read'; ru = 'Заполнен контрагент и считана дисконтная карта';pl = 'Klient wypełniony, karta rabatowa sczytana';es_ES = 'Cliente se ha rellenado y la tarjeta de descuento se ha leído';es_CO = 'Cliente se ha rellenado y la tarjeta de descuento se ha leído';tr = 'Müşteri dolduruldu ve indirim kartı okundu';it = 'Il Cliente è stata compilato e la carta sconto è stata letta';de = 'Die Kundendaten wurden ausgefüllt und die Rabattkarte wurde gelesen'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The customer is filled out in the document and discount card %1 is read'; ru = 'В документе заполнен контрагент и считана дисконтная карта %1';pl = 'W dokumencie wskazano klienta, karta rabatowa %1 została sczytana';es_ES = 'El cliente se ha rellenado en el documento y la tarjeta de descuento %1 se ha leído';es_CO = 'El cliente se ha rellenado en el documento y la tarjeta de descuento %1 se ha leído';tr = 'Müşteri belgeyi ve indirim kartını doldurdu %1 okundu';it = 'Il Cliente è stato compilato nel documento e la carta sconto %1 è stata letta';de = 'Der Kunde wurde im Dokument ausgefüllt und die Rabattkarte %1 wurde gelesen'"), DiscountCard),
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
			NStr("en = 'Discount card read'; ru = 'Считана дисконтная карта';pl = 'Karta rabatowa sczytana';es_ES = 'Tarjeta de descuento leída';es_CO = 'Tarjeta de descuento leída';tr = 'İndirim kartı okutulur';it = 'Letta carta sconto';de = 'Rabattkarte gelesen'"),
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
	
	If Object.Inventory.Count() > 0 Or Object.Works.Count() > 0 Then
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
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Inventory");
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Works");
	EndIf;
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

// Function returns the discount card owner.
//
&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

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
				NStr("en = 'Change the percent of discount of the card from %1% to %2% and recalculate discounts in all rows?'; ru = 'Процент скидки карты изменится с %1% на %2% и будет перезаполнен в документе. Продолжить?';pl = 'Zmienić procent rabatu na karcie z %1% na %2% i przeliczyć ponownie rabaty we wszystkich wierszach?';es_ES = '¿Cambiar el por ciento del descuento de la tarjeta de %1= &nbsp;% a %2= &nbsp;% y recalcular los descuentos en todas las filas?';es_CO = '¿Cambiar el por ciento del descuento de la tarjeta de %1% a %2% y recalcular los descuentos en todas las filas?';tr = 'Kartın indirim yüzdesi %1%''den %2%''ye değiştirilsin ve tüm satırlarda indirimleri yeniden doldurulsun mu?';it = 'Cambiare la percentuale di sconto della carta da %1% a %2% e ricalcolare gli sconti in tutte le righe?';de = 'Den Prozentsatz des Rabatts der Karte von %1% in %2% ändern und den Rabatt in allen Zeilen neu berechnen?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		Else
			
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to change the discount percent of the card from %1% to %2%?'; ru = 'Изменить процент скидки карты с %1% на %2%?';pl = 'Czy chcesz zmienić procent rabatu karty z %1% na %2%?';es_ES = '¿Quiere cambiar el por ciento del descuento de la tarjeta de %1= &nbsp;% a %2= &nbsp;%?';es_CO = '¿Quiere cambiar el por ciento del descuento de la tarjeta de %1% a %2%?';tr = 'İndirim oranını %1%''den %2%''ye değiştirmek istiyor musunuz?';it = 'Volete cambiare la percentuale di sconto da %1% a %2%?';de = 'Möchten Sie den Rabattprozentsatz der Karte von %1% in %2% ändern?'"),
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
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Inventory");
			
			RecalculateSalesTax();
			// Cash flow projection.
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		EndIf;
				
	EndIf;
	
EndProcedure

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
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
			CalculateAmountInTabularSectionLine("ConsumersInventory", Row, , False);
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
	FillingParameters.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
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

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
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
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			And ClosingResult.RecalculatePrices Then
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Works", PricesPrecision);
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			And Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory", PricesPrecision);
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Works", PricesPrecision);
			
		EndIf;
		
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
// Procedure-handler of the response to question about the necessity to set a new currency rate
//
Procedure DefineNewExchangeRatesettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure-handler response on question about document recalculate by contract data
//
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ContractData = AdditionalParameters.ContractData;
		
		If AdditionalParameters.RecalculationRequiredInventory Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
			
		EndIf;
		
		If AdditionalParameters.RecalculationRequiredWork Then
			
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

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
	
	Items.InventoryVATRate.Visible						= IsSubjectToVAT;
	Items.InventoryVATAmount.Visible					= IsSubjectToVAT;
	Items.InventoryAmountTotal.Visible					= IsSubjectToVAT;
	Items.InventoryTaxable.Visible						= RegisteredForSalesTax;
	Items.InventorySalesTaxAmount.Visible				= RegisteredForSalesTax;
	Items.WorksVATRate.Visible							= IsSubjectToVAT;
	Items.WorksAmountVAT.Visible						= IsSubjectToVAT;
	Items.WorksTotal.Visible							= IsSubjectToVAT;
	Items.WorksTaxable.Visible							= RegisteredForSalesTax;
	Items.WorksSalesTaxAmount.Visible					= RegisteredForSalesTax;
	Items.PaymentCalendarPaymentVATAmount.Visible		= IsSubjectToVAT;
	Items.ListPaymentCalendarVATAmountPayments.Visible	= IsSubjectToVAT;
	Items.DocumentTax.Visible							= IsSubjectToVAT OR RegisteredForSalesTax;
	Items.GroupSalesTax.Visible							= RegisteredForSalesTax;
	
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
	WorksTaxable = Object.Works.Unload(New Structure("Taxable", True));
	
	Return InventoryTaxable.Total("Total") + WorksTaxable.Total("Total");
	
EndFunction

&AtServer
Procedure FillSalesTaxRate()
	
	SalesTaxRateBeforeChange = Object.SalesTaxRate;
	
	Object.SalesTaxRate = DriveServer.CounterpartySalesTaxRate(Object.Counterparty, RegisteredForSalesTax);
	
	If SalesTaxRateBeforeChange <> Object.SalesTaxRate Then
		
		If ValueIsFilled(Object.SalesTaxRate) Then
			Object.SalesTaxPercentage = Common.ObjectAttributeValue(Object.SalesTaxRate, "Rate");
		Else
			Object.SalesTaxPercentage = 0;
		EndIf;
		
		RecalculateSalesTax();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RecalculateSalesTax()
	
	FormObject = FormAttributeToValue("Object");
	FormObject.RecalculateSalesTax();
	ValueToFormAttribute(FormObject, "Object");
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillConsumersInventory", True);
	ParametersStructure.Insert("FillMaterials", True);
	FillAddedColumns(ParametersStructure);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_FillBatchesByFEFO_Selected()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", False);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_Selected(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_All()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", False);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_All(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFOMaterials_Selected()
	
	Params = New Structure;
	Params.Insert("TableName", "Materials");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", False);
	
	BatchesClient.FillBatchesByFEFO_Selected(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFOMaterials_All()
	
	Params = New Structure;
	Params.Insert("TableName", "Materials");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", False);
	
	BatchesClient.FillBatchesByFEFO_All(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_BatchOnChange(TableName) Export
	
	MaterialsBatchOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_QuantityOnChange(TableName, RowData) Export
	
	ProductsQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Function Attachable_FillByFEFOData(TableName, ShowMessages) Export
	
	If TableName = "Inventory" Then
		Return FillByFEFOData(ShowMessages);
	Else
		Return FillByFEFODataMaterials(ShowMessages);
	EndIf;
	
EndFunction

&AtServer
Function FillByFEFODataMaterials(ShowMessages)
	
	Params = New Structure;
	If Items.Materials.CurrentRow <> Undefined Then
		Params.Insert("CurrentRow", Object.Materials.FindByID(Items.Materials.CurrentRow));
	Else
		Params.Insert("CurrentRow", Undefined);
	EndIf;
	Params.Insert("StructuralUnit", Object.StructuralUnitReserve);
	Params.Insert("TableName", "Materials");
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	Params.Insert("Cell", Params.CurrentRow.StorageBin);
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

&AtServer
Function FillByFEFOData(ShowMessages)
	
	Params = New Structure;
	Params.Insert("CurrentRow", Object.Inventory.FindByID(Items.Inventory.CurrentRow));
	Params.Insert("StructuralUnit", Object.InventoryWarehouse);
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	Params.Insert("Cell", Params.CurrentRow.StorageBin);
	Params.Insert("OwnershipType", Undefined);
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtServer
Procedure ReadAdditionalInformationPanelData()
	
	AdditionalInformationPanel.ReadAdditionalInformationPanelData(ThisObject, Counterparty);
	
EndProcedure

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion