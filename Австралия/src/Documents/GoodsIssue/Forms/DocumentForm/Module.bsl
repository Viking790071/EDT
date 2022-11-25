
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
	// Bundles
	RefreshBundleAttributes(Object.Products);
	// End Bundles
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.Interactions
	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "GoodsIssue");
	// End StandardSubsystems.Interactions
	
	// begin Drive.FullVersion
	EventName = DriveServerCall.GetNotificationEventName(Object.Ref);
	If Not IsBlankString(EventName) Then
		Notify(EventName);
	EndIf;
	// end Drive.FullVersion
	
	// Bundles
	RefreshBundlePictures(Object.Products);
	// End Bundles
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		If Object.Ref.IsEmpty() Then
			Cancel = True;
		EndIf;
		Return;
	EndIf;
	
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
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.GoodsIssue.TabularSections.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	Items.ProductsImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Bundles
	BundlesOnCreateAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		RefreshBundlePictures(Object.Products);
		RefreshBundleAttributes(Object.Products);
		DocumentDate = CurrentSessionDate();
		
	EndIf;
	
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
	ProcessingCompanyVATNumbers();
	FillOperationTypeChoiceList();
	
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisForm);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();

	SetVisibleAndEnabled();
	SetFormConditionalAppearance();
	
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculationVisibility();
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	Items.ProductsDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If UsersClientServer.IsExternalUserSession() Then
		PrintManagementClientDrive.GeneratePrintFormForExternalUsers(Object.Ref,
			"Document.GoodsIssue",
			"DeliveryNote",
			NStr("en = 'Delivery note'; ru = 'Уведомление о доставке';pl = 'Wydanie zewnętrzne';es_ES = 'Nota de entrega';es_CO = 'Nota de entrega';tr = 'Sevk irsaliyesi';it = 'Documento di trasporto';de = 'Lieferschein'"),
			FormOwner,
			UniqueKey);
		Cancel = True;
		Return;
	EndIf;
	
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
	
	SetVisibleDeliveryAttributes();
	SetContractVisible();
	
	SetAppearanceForOperationType();
	
	OperationTypeBeforeChange = Object.OperationType;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals

EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Bundles
	RefreshBundlePictures(Object.Products);
	RefreshBundleAttributes(Object.Products);
	// End Bundles
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	FillAddedColumns();
	
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
			CalculateQuantityInTabularSectionLine();
		EndIf;
		
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
	
	// Bundles
	If BundlesClient.ProcessNotifications(ThisObject, EventName, Source) Then
		RefreshBundleComponents(Parameter.BundleProduct, Parameter.BundleCharacteristic, Parameter.Quantity, Parameter.BundleComponents);
	EndIf;
	// End Bundles
	
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
	ElsIf ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "CommonForm.InventoryOwnership" Then
		EditOwnershipProcessingAtClient(SelectedValue.TempStorageInventoryOwnershipAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormItemsEventHandlers

&AtClient
Procedure StructuralUnitOnChange(Item)
	StructuralUnitOnChangeAtServer();
EndProcedure

&AtClient
Procedure OperationTypeOnChange(Item)
	
	If OperationTypeBeforeChange = Object.OperationType Then
		Return;
	EndIf;
	
	If OperationTypeBeforeChange <> Object.OperationType 
		And (Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.DropShipping") 
		Or OperationTypeBeforeChange = PredefinedValue("Enum.OperationTypesGoodsIssue.DropShipping")) 
		And Object.Products.Count() > 0 Then
		
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("OperationTypeOnChangeEnd", ThisObject);
		TextQuery = NStr("en = 'After you select another operation, the Products tab will be cleared. 
						|Continue?'; 
						|ru = 'После выбора другой операции вкладка Номенклатура будет очищена. 
						|Продолжить?';
						|pl = 'Po zaznaczeniu innej operacji, karta Produkty zostanie wyczyszczona. 
						|Kontynuować?';
						|es_ES = 'Después de seleccionar otra operación, la pestaña Productos se eliminará.
						|¿Continuar?';
						|es_CO = 'Después de seleccionar otra operación, la pestaña Productos se eliminará.
						|¿Continuar?';
						|tr = 'Başka bir işlem seçtiğinizde Ürünler sekmesi temizlenir. 
						|Devam edilsin mi?';
						|it = 'Dopo aver selezionato un''altra operazione, la scheda Articoli sarà cancellata.
						|Continuare?';
						|de = 'Wenn Sie eine andere Operation auswählen, wird die Registerkarte Produkte entleert. 
						|Fortfahren?'");
		ShowQueryBox(Notification, TextQuery, Mode, 0);
		
		Return;
		
	EndIf;
	
	ProcessOperationTypeChange();
	
	ProcessContractChange();
	
	SetAppearanceForOperationType();
	ClearOwnership();
	
	SetVisibleDeliveryAttributes();
	
	OperationTypeBeforeChange = Object.OperationType;
	
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure OperationTypeOnChangeEnd(Result, ParametersStructure) Export
	
	If Result = DialogReturnCode.No Then
		
		Object.OperationType = OperationTypeBeforeChange;
		Return;
		
	EndIf;
	
	Object.Products.Clear();
	
	ProcessOperationTypeChange();
	ProcessContractChange();
	SetAppearanceForOperationType();
	ClearOwnership();
	SetVisibleDeliveryAttributes();
	
	OperationTypeBeforeChange = Object.OperationType;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
		
		Object.DeliveryOption = CounterpartyAttributes.DefaultDeliveryOption;
		Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationType);
		ProcessContractChange(True);
		
		SetVisibleDeliveryAttributes();
		SetContractVisible();
		
		If Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.ReturnToAThirdParty") Then
			SetAppearanceForOperationType();
			ClearOwnership();
		EndIf;
		
		If Not ValueIsFilled(Object.ShippingAddress) Then
			
			DeliveryData = GetDeliveryData(Object.Counterparty);
			
			If DeliveryData.ShippingAddress = Undefined Then
				CommonClientServer.MessageToUser(NStr("en = 'Delivery address is required'; ru = 'Укажите адрес доставки';pl = 'Wymagany jest adres dostawy';es_ES = 'Se requiere la dirección de entrega';es_CO = 'Se requiere la dirección de entrega';tr = 'Teslimat adresi gerekli';it = 'È richiesto l''indirizzo di consegna';de = 'Adresse ist ein Pflichtfeld'"));
			Else
				Object.ShippingAddress = DeliveryData.ShippingAddress;
			EndIf;
			
		EndIf;
		
		ProcessShippingAddressChange();
		
	Else
		
		Object.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeliveryOptionOnChange(Item)
	SetVisibleDeliveryAttributes();
EndProcedure

&AtClient
Procedure ShippingAddressOnChange(Item)
	ProcessShippingAddressChange();
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
	
	CompanyOnChangeAtServer();
	ProcessContractChange();
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
	If Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.ReturnToAThirdParty") Then
		SetAppearanceForOperationType();
		ClearOwnership();
	EndIf;
	
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
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("IncomeAndExpenseItems",	TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	
	AddTabRowDataToStructure(ThisObject, "Products", StructureData);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	// Bundles
	If StructureData.IsBundle And Not StructureData.UseCharacteristics Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		
	Else
	// End Bundles
	
		FillPropertyValues(TabularSectionRow, StructureData); 
		TabularSectionRow.MeasurementUnit	= StructureData.MeasurementUnit;
		TabularSectionRow.Quantity			= 1;
		
		// Serial numbers
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
	
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsProductsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.Parent.CurrentData;
	
	ParametersFormProducts = New Structure;
	
	If ValueIsFilled(Object.StructuralUnit) Then
		ParametersFormProducts.Insert("FilterWarehouse", Object.StructuralUnit);
	EndIf;
	
	If ValueIsFilled(Object.Company) Then
		ParametersFormProducts.Insert("FilterBalancesCompany", Object.Company);
	EndIf;
	
	ParametersFormProducts.Insert("Filter", New Structure("ProductsType",PredefinedValue("Enum.ProductsTypes.InventoryItem")));

	ChoiceHandler = New NotifyDescription("ProductsProductsStartChoiceEnd", 
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
Procedure ProductsProductsStartChoiceEnd(ResultValue, AdditionalParameters) Export
	
	If ResultValue = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters.CurrentData.Products = ResultValue;
	
	ProductsProductOnChange(AdditionalParameters.Item);
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	// Bundles
	TabularSectionRow = Items.Products.CurrentData;
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Products", StructureData);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	If StructureData.IsBundle Then
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
	EndIf;
	// End Bundles

EndProcedure

&AtClient
Procedure ProductsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	// Bundles
	CurrentRow = Items.Products.CurrentData;
	
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
		
		TabularSectionName	= "Products";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, False);
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
Procedure ProductsCharacteristicAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	
	// Bundles
	CurrentRow = Items.Products.CurrentData;
	
	If CurrentRow.IsBundle Then
		
		StandardProcessing = False;
		ChoiceData = BundleCharacteristics(CurrentRow.Products, Text);
		
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Item)
	CalculateQuantityInTabularSectionLine();
EndProcedure

&AtClient
Procedure ProductsSalesInvoiceOnChange(Item)
	
	TabRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Products", StructureData);

	ProductsSalesInvoiceOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure ProductsSerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();

EndProcedure

&AtClient
Procedure ProductsBeforeDeleteRow(Item, Cancel)
	
	// Bundles
	If Items.Products.SelectedRows.Count() = Object.Products.Count() Then
		
		Object.AddedBundles.Clear();
		SetBundlePictureVisible();
		
	Else
		
		BundleData = New Structure("BundleProduct, BundleCharacteristic");
		
		For Each SelectedRow In Items.Products.SelectedRows Do
			
			SelectedRowData = Items.Products.RowData(SelectedRow);
			
			If BundleData.BundleProduct = Undefined Then
				
				BundleData.BundleProduct = SelectedRowData.BundleProduct;
				BundleData.BundleCharacteristic = SelectedRowData.BundleCharacteristic;
				
			ElsIf BundleData.BundleProduct <> SelectedRowData.BundleProduct
				Or BundleData.BundleCharacteristic <> SelectedRowData.BundleCharacteristic Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'Action is unavailable for bundles.'; ru = 'Это действие недоступно для наборов.';pl = 'Działanie nie jest dostępne dla zestawów.';es_ES = 'La acción no está disponible para los paquetes.';es_CO = 'La acción no está disponible para los paquetes.';tr = 'Bu işlem setler için kullanılamaz.';it = 'Azione non disponibile per kit di prodotti.';de = 'Für Bündel ist die Aktion nicht verfügbar.'"),,
					"Object.Products",,
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
				
				QuestionText = NStr("en = 'This item is a component of duplicate bundles. To continue, click one of the buttons:
                                     |-""Delete all bundles"". Deletes the item by deleting all duplicate bundles.
                                     |-""Change components of the bundle"". Opens the selected bundle for changing components.'; 
                                     |ru = 'Этот товар входит в одинаковые наборы. Чтобы продолжить, нажмите одну из кнопок:
                                     |-""Удалить все наборы"". Удаляет товар вместе со всеми одинаковыми наборами.
                                     |-""Изменить компоненты набора"". Открывает выбранный набор для изменения компонентов.';
                                     |pl = 'Ten element jest komponentem duplikowanych zestawów. Aby kontynuować, kliknij jeden z przycisków:
                                     |-""Usuń wszystkie zestawy"". Element zostanie usunięty poprzez usunięcie wszystkich duplikowanych zestawów.
                                     |-""Zmień komponenty zestawu"". Otworzy się wybrany zestaw do zmiany komponentów.';
                                     |es_ES = 'Este elemento es un componente de paquetes duplicados. Para continuar, haga clic en uno de los botones:
                                     |-""Eliminar todos los paquetes"". Elimina el elemento borrando todos los paquetes duplicados.
                                     |-""Cambiar los componentes del paquete"". Abre el paquete seleccionado para modificar sus componentes.';
                                     |es_CO = 'Este elemento es un componente de paquetes duplicados. Para continuar, haga clic en uno de los botones:
                                     |-""Eliminar todos los paquetes"". Elimina el elemento borrando todos los paquetes duplicados.
                                     |-""Cambiar los componentes del paquete"". Abre el paquete seleccionado para modificar sus componentes.';
                                     |tr = 'Bu ürün tekrarlayan ürün setlerine ait bir malzemedir. Devam etmek için şunlardan birine tıklayın:
                                     |-""Tüm setleri sil"". Tüm tekrarlayan ürün setlerini silerek öğeyi siler.
                                     |-""Ürün seti malzemelerini değiştir"". Malzemelerin değiştirilmesi için, seçilen ürün setini açar.';
                                     |it = 'Questo elemento è una componente di un kit di prodotti duplicato. Per continuare, cliccare su uno dei pulsanti:
                                     |- ""Eliminare tutti i kit di prodotti"" elimina l''elemento e tutti i kit di prodotti duplicati;
                                     |- ""Modificare componenti del kit di prodotti"" apre il kit di prodotti selezionato per la modifica delle componenti.';
                                     |de = 'Dieser Artikel ist eine Komponente von duplizierten Artikelgruppen. Um fortzufahren, klicken Sie auf eine der Schaltflächen:
                                     |-""Alle Artikelgruppen löschen"". Dadurch wird der Artikel mit Löschen aller duplizierten Artikelgruppen gelöscht.
                                     |-""Komponenten der Artikelgruppe bearbeiten"". Dadurch wird die ausgewählte Artikelgruppe für Bearbeitung der Komponenten geöffnet.'");
				ButtonsList.Add(DialogReturnCode.Yes,	NStr("en = 'Delete all bundles'; ru = 'Удалить все наборы';pl = 'Usuń wszystkie zestawy';es_ES = 'Eliminar todos los paquetes';es_CO = 'Eliminar todos los paquetes';tr = 'Tüm setleri sil';it = 'Elimina tutti i kit di prodotti';de = 'Alle Bündel löschen'"));
				
				If UseSerialNumbersBalance <> True Then
					ButtonsList.Add("DeleteOne",			NStr("en = 'Delete bundle'; ru = 'Удалить набор';pl = 'Usuń zestaw';es_ES = 'Eliminar el paquete';es_CO = 'Eliminar el paquete';tr = 'Ürün setini sil';it = 'Eliminare kit di prodotti';de = 'Artikelgruppe löschen'"));
				EndIf;
				
			Else
				
				QuestionText = NStr("en = 'This item belongs to a bundle. 
					|To remove all components of this bundle, select ""Delete entire bundle"".
					|To change the quantity or remove bundled items, select ""Change quantity of components"".'; 
					|ru = 'Этот товар входит в набор. 
					|Чтобы удалить все компоненты набора, выберите ""Удалить весь набор"".
					|Чтобы изменить количество или удалить компоненты набора, выберите ""Изменить количество компонентов"".';
					|pl = 'Ten element należy do zestawu. 
					|Aby usunąć wszystkie komponenty tego zestawu, zaznacz ""Usuń cały zestaw"".
					|Aby zmienić ilość lub usunąć elementy zestawu, zaznacz ""Zmień ilość komponentów"".';
					|es_ES = 'Este elemento pertenece a un paquete. 
					|Para eliminar todos los componentes de este paquete, seleccione ""Eliminar todo el paquete"". 
					|Para cambiar la cantidad o eliminar los elementos del paquete, seleccione ""Cambiar la cantidad de componentes"".';
					|es_CO = 'Este elemento pertenece a un paquete. 
					|Para eliminar todos los componentes de este paquete, seleccione ""Eliminar todo el paquete"". 
					|Para cambiar la cantidad o eliminar los elementos del paquete, seleccione ""Cambiar la cantidad de componentes"".';
					|tr = 'Bu öğe bir ürün setine ait. 
					|Bu ürün setinin tüm malzemelerini çıkarmak için ""Tüm ürün setini sil""i seçin.
					|Miktarı değiştirmek veya set ürünlerini çıkarmak için ""Malzemelerin miktarını değiştir""i seçin.';
					|it = 'Questo elemento appartiene a un kit di prodotti.
					|Per rimuovere tutte le componenti di questo kit, selezionate ""Eliminare intero kit di prodotti"".
					|Per modificare la quantità o rimuovere gli elementi nel kit di prodotti, selezionare ""Eliminare quantità di componenti"".';
					|de = 'Dieser Artikel gehört zu einer Artikelgruppe. 
					|Um alle Komponente zu löschen, wählen Sie ""Die ganze Artikelgruppe löschen"" aus.
					|Um die Menge zu ändern oder Artikel aus der Artikelgruppe zu löschen, wählen Sie ""Menge der Komponenten bearbeiten"" aus.'");
				ButtonsList.Add(DialogReturnCode.Yes,	NStr("en = 'Delete entire bundle'; ru = 'Удалить весь набор';pl = 'Usuń cały zestaw';es_ES = 'Eliminar todo el paquete';es_CO = 'Eliminar todo el paquete';tr = 'Tüm ürün setini sil';it = 'Eliminare intero kit di prodotti';de = 'Die ganze Artikelgruppe löschen'"));
				
			EndIf;
			
			ButtonsList.Add(DialogReturnCode.No, NStr("en = 'Change quantity of components'; ru = 'Изменить количество компонентов';pl = 'Zmień ilość komponentów';es_ES = 'Cambiar la cantidad de componentes';es_CO = 'Cambiar la cantidad de componentes';tr = 'Malzemelerin miktarını değiştir';it = 'Eliminare quantità di componenti';de = 'Menge der Komponenten bearbeiten'"));
			ButtonsList.Add(DialogReturnCode.Cancel);
			
			ShowQueryBox(Notification, QuestionText, ButtonsList, 0, DialogReturnCode.Yes);
			
		EndIf;
		
	EndIf;
	// End Bundles
	
	If Not Cancel Then
		// Serial numbers
		CurrentData = Items.Products.CurrentData;
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;	
	
	If Item.CurrentItem.Name = "ProductsSerialNumbers" Then
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
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Products");
	ElsIf Field.Name = "ProductsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Products");
	EndIf;
	
	// Bundles
	InventoryLine = Object.Products.FindByID(SelectedRow);
	If Not ReadOnly And ValueIsFilled(InventoryLine.BundleProduct)
		And (Item.CurrentItem = Items.ProductsProducts
			Or Item.CurrentItem = Items.ProductsCharacteristic
			Or Item.CurrentItem = Items.ProductsQuantity
			Or Item.CurrentItem = Items.ProductsMeasurementUnit
			Or Item.CurrentItem = Items.ProductsBundlePicture) Then
			
		StandardProcessing = False;
		EditBundlesComponents(InventoryLine);
		
	EndIf;
	// End Bundles
	
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
Procedure ProductsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	// Bundles
	If Clone Then
		
		If ValueIsFilled(Item.CurrentData.BundleProduct) Then
			Cancel = True;
		EndIf;
		
	EndIf;
	// End Bundles
	
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

#Region FormCommandsEventHandlers

&AtClient
Procedure FillFromOrder(Command)
	
	If ValueIsFilled(Object.Order) Then
		ShowQueryBox(New NotifyDescription("FillByOrderEnd", ThisObject),
			NStr("en = 'The document will be fully filled out according to the ""Order."" Continue?'; ru = 'Документ будет полностью перезаполнен по ""Заказу""! Продолжить выполнение операции?';pl = 'Dokument zostanie wypełniony w całości zgodnie z ""Zamówieniem"". Dalej?';es_ES = 'El documento se rellenará completamente según el ""Orden"". ¿Continuar?';es_CO = 'El documento se rellenará completamente según el ""Orden"". ¿Continuar?';tr = 'Belge ""Sipariş""e göre tamamen doldurulacak. Devam edilsin mi?';it = 'Il documento sarà interamente compilato secondo l''""Ordine"". Continuare?';de = 'Das Dokument wird entsprechend der ""Bestellung"" vollständig ausgefüllt. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		MessagesToUserClient.ShowMessageSelectOrder();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByOrderEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Object.Products.Clear();
		FillByDocument(Object.Order);
		SetContractVisible();
	EndIf;
	
EndProcedure

&AtClient
Procedure Settings(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PurchaseOrderPositionInReceiptDocuments", Object.PurchaseOrderPosition);
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

&AtClient
Procedure EditOwnership(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TempStorageAddress", PutEditOwnershipDataToTempStorage());
	
	OpenForm("CommonForm.InventoryOwnership", FormParameters, ThisObject);
	
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
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(StructureProductsData, StructureData.Object, "GoodsIssue", "Products");
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "GoodsIssue", "Products");
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
			// Bundles
			Filter.Insert("BundleProduct",	PredefinedValue("Catalog.Products.EmptyRef"));
			// End Bundles
			TSRowsArray = Object.Products.FindRows(Filter);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Products.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				// Bundles
				If BarcodeData.StructureProductsData.IsBundle Then
					ReplaceInventoryLineWithBundleData(ThisObject, NewRow, BarcodeData.StructureProductsData);
				Else
				// End Bundles
					Items.Products.CurrentRow = NewRow.GetID();
				EndIf;
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
		|Order");
	FillPropertyValues(SelectionParameters, Object);
	
	SelectionParameters.Insert("TempStorageInventoryAddress", PutProductsToTempStorage());
	SelectionParameters.Insert("ShowGoodsIssue", False);
	
	// Bundles
	SelectionParameters.Insert("ShowBundles", True);
	// End Bundles
	
	OpenForm("CommonForm.SelectionFromOrders", SelectionParameters, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function PutProductsToTempStorage()
	
	ProductsTable = Object.Products.Unload();
	
	ProductsTable.Columns.Add("Reserve", New TypeDescription("Number"));
	ProductsTable.Columns.Add("Content", New TypeDescription("String"));
	ProductsTable.Columns.Add("GoodsIssue", New TypeDescription("DocumentRef.GoodsIssue"));
	
	If ValueIsFilled(Object.Order) Then
		For Each ProductRow In ProductsTable Do
			
			If Not ValueIsFilled(ProductRow.Order) Then
				ProductRow.Order = Object.Order;
			EndIf;
			
			ProductRow.Content = String(ProductRow.Products);
			
		EndDo;
	EndIf;
	
	Return PutToTempStorage(ProductsTable);
	
EndFunction

&AtServer
Procedure OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress)
	
	TablesStructure = GetFromTempStorage(TempStorageInventoryAddress);
	
	InventorySearchStructure = New Structure("Products, Characteristic, BundleProduct, BundleCharacteristic, Batch, Order, SalesInvoice");
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each InventoryRow In TablesStructure.Inventory Do
		
		FillPropertyValues(InventorySearchStructure, InventoryRow);
		
		If InventorySearchStructure.SalesInvoice = Undefined Then
			InventorySearchStructure.SalesInvoice = Documents.SalesInvoice.EmptyRef();
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
	
	// Bundles
	If TablesStructure.AddedBundles.Count() Then
		For Each AddedBundle In TablesStructure.AddedBundles Do
			NewRow = Object.AddedBundles.Add();
			FillPropertyValues(NewRow, AddedBundle);
		EndDo;
		
		RefreshBundlePictures(Object.Products);
		RefreshBundleAttributes(Object.Products);
		SetBundlePictureVisible();
	EndIf;
	// End Bundles
	
	OrdersTable = Object.Products.Unload( , "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	
	If OrdersTable.Count() > 1 Then
		Object.Order = Undefined;
		Object.Contract = Undefined;
		Object.SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	ElsIf OrdersTable.Count() = 1 Then
		Object.Order = OrdersTable[0].Order;
		Object.Contract = OrdersTable[0].Contract;
		Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	
	SetVisibleFromUserSettings();
	
EndProcedure

&AtClient
Procedure SelectProducts(Command)
	
	TabularSectionName	= "Products";
	DocumentPresentaion	= NStr("en = 'goods issue'; ru = 'отпуск товаров';pl = 'wydanie zewnętrzne';es_ES = 'salida de mercancías';es_CO = 'salida de productos';tr = 'ambar çıkışı';it = 'spedizione merce/ddt';de = 'Warenausgang'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True, True);
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
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Products", True, True);
			
			Object.StructuralUnit 	= ClosingResult.StockWarehouse;
			Object.Cell 			= ClosingResult.StockCell;
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
		FillPropertyValues(StructureData, NewRow);
		
		StructureData.Insert("IncomeAndExpenseItems",	NewRow.IncomeAndExpenseItems);
		StructureData.Insert("IncomeAndExpenseItemsFilled", NewRow.IncomeAndExpenseItemsFilled);
		AddTabRowDataToStructure(ThisObject, "Products", StructureData, NewRow);
		
		IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
		
		If StructureData.UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillProductGLAccounts(StructureData);
		EndIf;
		
		FillPropertyValues(NewRow, StructureData);
		
		// Bundles
		If ImportRow.IsBundle Then
			
			StructureData.Insert("Company", Object.Company);
			
			AddTabRowDataToStructure(ThisObject, "Products", StructureData, NewRow);
			StructureData = GetDataProductsOnChange(StructureData);
			
			ReplaceInventoryLineWithBundleData(ThisObject, NewRow, StructureData);
			
		EndIf;
		// End Bundles
		
	EndDo;
	
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
			Filter.Insert("IsBundle", False);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, RowToDelete,, UseSerialNumbersBalance);
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
			RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
			For Each RowToRecalculate In RowsToRecalculate Do
				CalculateQuantityInTabularSectionLine(RowToRecalculate);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region DataImportFromExternalSources

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"GoodsIssue.Products");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import products from file'; ru = 'Загрузка запасов из файла';pl = 'Importuj produkty z pliku';es_ES = 'Importar los productos del archivo';es_CO = 'Importar los productos del archivo';tr = 'Ürünleri dosyadan içe aktar';it = 'Importazione articoli da file';de = 'Produkte aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
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
Procedure Attachable_FillBatchesByFEFO_Selected()
	
	Params = New Structure;
	Params.Insert("TableName", "Products");
	Params.Insert("BatchOnChangeHandler", False);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_Selected(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_All()
	
	Params = New Structure;
	Params.Insert("TableName", "Products");
	Params.Insert("BatchOnChangeHandler", False);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_All(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_QuantityOnChange(TableName, RowData) Export
	
	CalculateQuantityInTabularSectionLine(RowData);
	
EndProcedure

&AtClient
Function Attachable_FillByFEFOData(TableName, ShowMessages) Export
	
	Return FillByFEFOData(ShowMessages);
	
EndFunction

&AtServer
Function FillByFEFOData(ShowMessages)
	
	Params = New Structure;
	Params.Insert("CurrentRow", Object.Products.FindByID(Items.Products.CurrentRow));
	Params.Insert("StructuralUnit", Object.StructuralUnit);
	Params.Insert("TableName", "Products");
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	Params.Insert("Cell", Object.Cell);
	If Object.SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		Params.Insert("SalesOrder", Object.Order);
	Else
		Params.Insert("SalesOrder", Params.CurrentRow.Order);
	EndIf;
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

&AtClient
Procedure ClearOwnership()
	
	For Each ProductsRow In Object.Products Do
		ProductsRow.Ownership = "";
	EndDo;
	
EndProcedure

&AtServer
Procedure EditOwnershipProcessingAtServer(TempStorageAddress)
	
	OwnershipTable = GetFromTempStorage(TempStorageAddress);
	
	Object.ProductsOwnership.Load(OwnershipTable);
	
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
Procedure Attachable_GenerateSalesInvoice(Command)
	
	Array = New Array;
	Array.Add(Object.Ref);
	
	DriveClient.SalesInvoiceGenerationBasedOnGoodsIssue(Array);
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationType);
	
	FillAddedColumns(True);
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	SetAutomaticVATCalculationVisibility();
	
	ProcessingCompanyVATNumbers(False);
	
	InformationRegisters.AccountingSourceDocuments.CheckNotifyTypesOfAccountingProblems(
		Object.Ref,
		Object.Company,
		DocumentDate);

EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure DateOnChangeAtServer()
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers();
	
	SetAutomaticVATCalculation();
	SetAutomaticVATCalculationVisibility();
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	PerInvoiceVATRoundingRule	= AccountingPolicy.PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculationVisibility()
	
	Items.AutomaticVATCalculation.Visible = (
		Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
		And Items.ProductsVATRate.Visible)
		
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	FillAddedColumns(True);
	SetVisibleAndEnabled();
	
EndProcedure

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
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
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData, StructureData.UseDefaultTypeOfAccounting);
	// End Bundles
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Products.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Procedure SetVisibleFromUserSettings()
	
	IsPurchaseReturn	= (Object.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn);
	IsDropShipping		= (Object.OperationType = Enums.OperationTypesGoodsIssue.DropShipping);
	
	Items.FormSettings.Visible = (Object.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer
		Or IsPurchaseReturn Or IsDropShipping);

	If (Object.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer 
			Or IsDropShipping)
			And Object.SalesOrderPosition = Enums.AttributeStationing.InHeader
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn 
			And Object.PurchaseOrderPosition = Enums.AttributeStationing.InHeader
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.TransferToAThirdParty 
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor 
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer Then
		VisibleValue = True;
	Else
		VisibleValue = False;
	EndIf;
	
	Items.Order.Enabled = VisibleValue;
	Items.Contract.Enabled = VisibleValue;

	If VisibleValue Then
		Items.Order.InputHint = "";
		Items.Contract.InputHint = "";
	Else 
		Items.Order.InputHint = NStr("en = '<Multiple orders mode>'; ru = '<Режим нескольких заказов>';pl = '<Tryb wielu zamówień>';es_ES = '<Modo de órdenes múltiples>';es_CO = '<Modo de órdenes múltiples>';tr = '<Birden fazla emir modu>';it = '<Modalità ordini multipli>';de = '<Mehrfach-Bestellungen Modus>'");
		Items.Contract.InputHint = NStr("en = '<Multiple orders mode>'; ru = '<Режим нескольких заказов>';pl = '<Tryb wielu zamówień>';es_ES = '<Modo de órdenes múltiples>';es_CO = '<Modo de órdenes múltiples>';tr = '<Birden fazla emir modu>';it = '<Modalità ordini multipli>';de = '<Mehrfach-Bestellungen Modus>'");
	EndIf;
	
	Items.ProductsOrder.Visible = Not VisibleValue;
	Items.ProductsContract.Visible = Not VisibleValue;
	Items.FillFromOrder.Visible = VisibleValue
		And (Object.OperationType <> Enums.OperationTypesGoodsIssue.PurchaseReturn);
	Items.ProductsProject.Visible = IsPurchaseReturn
		Or ?(Object.SalesOrderPosition = Enums.AttributeStationing.InHeader, ValueIsFilled(Object.Order), True);
	Items.ProductsSelectOrderedProducts.Visible = (Object.OperationType <> Enums.OperationTypesGoodsIssue.PurchaseReturn);
	
EndProcedure

&AtClient
Procedure SettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInShipmentDocuments;
		Object.PurchaseOrderPosition = StructureDocumentSetting.PurchaseOrderPositionInReceiptDocuments;
		If (Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.SaleToCustomer")
			Or Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.DropShipping"))
			And Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader")
			Or Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.PurchaseReturn")
			And Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			
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
		
		SetVisibleFromUserSettings();
		
		Modified = True;
		
	EndIf;
	
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

&AtClient
Procedure CalculateQuantityInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Products.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = ?(TabularSectionRow.InitialQuantity = 0, 0, TabularSectionRow.InitialAmount / TabularSectionRow.InitialQuantity * TabularSectionRow.Quantity);
	DriveClient.CalculateVATAmount(TabularSectionRow, Object.AmountIncludesVAT);
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow, "SerialNumbers");
	EndIf;

EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	If NOT ValueIsFilled(Object.Order) Then
		Return;
	EndIf;
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns();
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	SetVisibleFromUserSettings();
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure SetVisibleDeliveryAttributes()
	
	IsDropShipping = (Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.DropShipping"));
	
	Items.DeliveryOption.Visible = Not IsDropShipping;
	Items.TrackingNumber.Visible = IsDropShipping;
	
	VisibleFlags			= GetFlagsForFormItemsVisible(Object.DeliveryOption);
	DeliveryOptionIsFilled	= ValueIsFilled(Object.DeliveryOption);

	Items.LogisticsCompany.Visible	= DeliveryOptionIsFilled AND VisibleFlags.DeliveryOptionLogisticsCompany;
	Items.ShippingAddress.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.ContactPerson.Visible		= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.GoodsMarking.Visible		= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeFrom.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeTo.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.Incoterms.Visible			= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	
EndProcedure

&AtClient
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtServerNoContext
Function GetContractShippingAddress(Contract)
	
	Return Common.ObjectAttributeValue(Contract, "ShippingAddress");
	
EndFunction

&AtServerNoContext
Function GetFlagsForFormItemsVisible(DeliveryOption)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("DeliveryOptionLogisticsCompany", (DeliveryOption = Enums.DeliveryOptions.LogisticsCompany));
	VisibleFlags.Insert("DeliveryOptionSelfPickup", (DeliveryOption = Enums.DeliveryOptions.SelfPickup));
	
	Return VisibleFlags;
	
EndFunction

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DefaultDeliveryOption, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtClient
Procedure ProcessContractChange(CallFromCounterpartyOnChange = False)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If CounterpartyAttributes.DoOperationsByContracts And ValueIsFilled(Object.Contract) Then
			
			ShippingAddress = GetContractShippingAddress(Object.Contract);
			
			If ValueIsFilled(ShippingAddress) And ShippingAddress <> Object.ShippingAddress Then
				
				Object.ShippingAddress = ShippingAddress;
				If Not CallFromCounterpartyOnChange Then
					ProcessShippingAddressChange();
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessShippingAddressChange()
	
	DeliveryData = GetDeliveryAttributes(Object.ShippingAddress);
	
	FillPropertyValues(Object, DeliveryData);
	
EndProcedure

&AtServer
Function GetDeliveryData(Counterparty)
	Return ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty, False);
EndFunction

&AtServer
Function GetDeliveryAttributes(ShippingAddress)
	Return ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
EndFunction

&AtServer
Procedure ProcessOperationTypeChange()
	
	CheckBasisAvailability();
	
	If Not GetFunctionalOption("CanReceiveSubcontractingServices")
		And Object.OperationType = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
		
		MessageText = NStr("en = 'The functional option ""Use subcontractor order issued"" should be on for this operation type'; ru = 'Функциональная опция ""Использовать выданные заказы на переработку"" должна быть включена для данного типа операции';pl = 'Funkcjonalna opcja ""Używaj wydanego zamówienia wykonawcy"" musi być włączona dla tego typu operacji';es_ES = 'La opción funcional "" Utilizar la orden emitida del subcontratista"" debe estar activada para este tipo de operación';es_CO = 'La opción funcional "" Utilizar la orden emitida del subcontratista"" debe estar activada para este tipo de operación';tr = 'Bu işlem türü için ""Çıkarılan alt yüklenici siparişini kullan"" işlevinin açık olması gerekir';it = 'L''opzione funzionale ""Utilizzare ordine subfornitura emesso"" dovrebbe essere attiva per questo tipo di operazione';de = 'Die funktionale Option ""Ausgestellte Subunternehmerauftrag verwenden"" sollte für diesen Operationstyp aktiviert sein'");
		CommonClientServer.MessageToUser(MessageText, , "OperationKind");
		
	// begin Drive.FullVersion
	ElsIf Not GetFunctionalOption("CanProvideSubcontractingServices")
		And (Object.OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer) Then 
		
		MessageText = NStr("en = 'The functional option ""Use subcontractor order received"" should be on for this operation type'; ru = 'Функциональная опция ""Использовать полученные заказы на переработку"" должна быть включена для данного типа операции';pl = 'Funkcjonalna opcja ""Używaj otrzymanego zamówienia podwykonawcy"" musi być włączona dla tego typu operacji';es_ES = 'La opción funcional ""Utilizar la orden recibida del subcontratista"" debe estar activada para este tipo de operación';es_CO = 'La opción funcional ""Utilizar la orden recibida del subcontratista"" debe estar activada para este tipo de operación';tr = 'Bu işlem türü için ""Alınan alt yüklenici siparişini kullan"" işlevinin açık olması gerekir';it = 'L''opzione funzionale ""Utilizzare ordine di subfornitura ricevuto"" dovrebbe essere attiva per questo tipo di operazione';de = 'Die funktionale Option ""Subunternehmerauftrag erhalten verwenden"" sollte für diesen Operationstyp aktiviert sein'");
		CommonClientServer.MessageToUser(MessageText, , "OperationKind");
		
	// end Drive.FullVersion
	EndIf;
	
	SetDeliveryOptionAccordanceToOperationType();
	FillAddedColumns(True);
	
	SetVisibleAndEnabled();
	ProcessingCompanyVATNumbers();
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationType);
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabled()
	
	IsSaleToCustomer = (Object.OperationType = Enums.OperationTypesGoodsIssue.SaleToCustomer);
	IsPurchaseReturn = (Object.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn);
	IsIntraTransfer = (Object.OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer);
	IsTransferToSubcontractor = (Object.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractor);
	IsReturnToAThirdParty = (Object.OperationType = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty);
	IsTransferToAThirdParty = (Object.OperationType = Enums.OperationTypesGoodsIssue.TransferToAThirdParty);
	IsSubcontracting = (Object.OperationType = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer
		Or Object.OperationType = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer);
	IsDropShipping = (Object.OperationType = Enums.OperationTypesGoodsIssue.DropShipping);
	
	Items.GroupOrder.Visible	= 
		IsSaleToCustomer Or IsPurchaseReturn Or IsTransferToSubcontractor Or IsTransferToAThirdParty Or IsSubcontracting 
		Or IsDropShipping;
	Items.ProductsOrder.Visible	= IsSaleToCustomer Or IsPurchaseReturn Or IsTransferToSubcontractor Or IsDropShipping;
	Items.BasisDocument.Visible				= Not IsTransferToSubcontractor;
	
	Items.ProductsSalesInvoice.Visible		= IsSaleToCustomer Or IsPurchaseReturn Or IsDropShipping;
	Items.ProductsSupplierInvoice.Visible			= IsPurchaseReturn;
	Items.ProductsDebitNote.Visible					= IsPurchaseReturn;
	Items.ProductsInitialQuantity.Visible			= IsPurchaseReturn;
	Items.ProductsInitialAmount.Visible				= IsPurchaseReturn;
	Items.ProductsPrice.Visible						= IsPurchaseReturn;
	Items.ProductsAmount.Visible					= IsPurchaseReturn;
	Items.ProductsVATRate.Visible					= IsPurchaseReturn;
	Items.ProductsVATAmount.Visible					= IsPurchaseReturn;
	Items.ProductsProject.Visible					= IsPurchaseReturn
		Or ?(Object.SalesOrderPosition = Enums.AttributeStationing.InHeader, ValueIsFilled(Object.Order), True);
	Items.ProductsContract.Visible					= Not IsIntraTransfer;
	Items.StructuralUnit.Visible					= Not (IsIntraTransfer Or IsDropShipping);
	
	Items.GroupCounterpartyOrderInfo.Visible	= Not IsIntraTransfer;
	Items.GroupIntraCommunityTransfer.Visible	= IsIntraTransfer;
	
	Items.AllowExpiredBatches.Visible = IsSaleToCustomer And DriveAccessManagementReUse.ExpiredBatchesInSalesDocumentsIsAllowed();
	
	If IsPurchaseReturn Then
		Items.ProductsQuantity.Title = NStr("en = 'Return quantity'; ru = 'Возвращаемое количество';pl = 'Zwracana ilość';es_ES = 'Cantidad para la devolución';es_CO = 'Cantidad para la devolución';tr = 'İade miktarı';it = 'Quantità restituita';de = 'Retouren- Menge'");
	Else
		Items.ProductsQuantity.Title = NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'");
	EndIf;
	
	Items.Order.ChoiceParameters = New FixedArray(New Array);
	
	If IsSaleToCustomer Or IsDropShipping Then
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.SalesOrder");
		Items.ProductsOrder.TypeRestriction = New TypeDescription("DocumentRef.SalesOrder");
	ElsIf IsTransferToSubcontractor Then
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.SubcontractorOrderIssued");
		Items.ProductsOrder.TypeRestriction = New TypeDescription("DocumentRef.SubcontractorOrderIssued");
	ElsIf IsSubcontracting Then
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.SubcontractorOrderReceived");
		Items.ProductsOrder.TypeRestriction = New TypeDescription("DocumentRef.SubcontractorOrderReceived");
	Else
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.PurchaseOrder");
		Items.ProductsOrder.TypeRestriction = New TypeDescription("DocumentRef.PurchaseOrder");
		
		ParamentersArray = New Array;
		If IsPurchaseReturn Then
			NewParameter = New ChoiceParameter("Filter.OperationKind", Enums.OperationTypesPurchaseOrder.OrderForPurchase);
		Else
			NewParameter = New ChoiceParameter("Filter.OperationKind", Enums.OperationTypesPurchaseOrder.OrderForProcessing);
		Endif;
		ParamentersArray.Add(NewParameter);
		
		Items.Order.ChoiceParameters = New FixedArray(ParamentersArray);
	EndIf;
	
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	If Not ValueIsFilled(Object.StructuralUnit)
		Or (IsIntraTransfer 
			Or IsDropShipping)
		Or StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items.Cell.Visible = False;
	Else
		Items.Cell.Visible = True;
	EndIf;
	
	Items.ProductsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	Items.ProductsIncomeAndExpenseItems.Visible = IsSaleToCustomer Or IsPurchaseReturn Or IsDropShipping;
	
	SetVisibleFromUserSettings();
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Products");
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "Products");
	
EndProcedure

&AtClient
Procedure SetAppearanceForOperationType()
	
	Items.InventoryEditOwnership.Visible	= False;
	
	If Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.SaleToCustomer")
		Or Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.DropShipping") Then
		
		Items.ProductsOwnership.Visible			= False;
		Items.InventoryEditOwnership.Visible	= True;
		
	ElsIf Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.TransferToAThirdParty")
		Or Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.PurchaseReturn") Then
		
		NewArray = New Array();
		
		EnumOwnInventory	= PredefinedValue("Enum.InventoryOwnershipTypes.OwnInventory");
		NewChoiceParameter	= New ChoiceParameter("Filter.OwnershipType", EnumOwnInventory);
		NewArray.Add(NewChoiceParameter);
		
		Items.ProductsOwnership.Visible				= True;
		Items.ProductsOwnership.ChoiceParameters	= New FixedArray(NewArray);
		
	ElsIf Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.ReturnToAThirdParty") Then
		
		NewArray = New Array();
		
		EnumCounterpartysInventory	= PredefinedValue("Enum.InventoryOwnershipTypes.CounterpartysInventory");
		NewChoiceParameter			= New ChoiceParameter("Filter.OwnershipType", EnumCounterpartysInventory);
		NewArray.Add(NewChoiceParameter);
		
		NewChoiceParameter			= New ChoiceParameter("Filter.Counterparty", Object.Counterparty);
		NewArray.Add(NewChoiceParameter);
		
		NewChoiceParameter			= New ChoiceParameter("Filter.Contract", Object.Contract);
		NewArray.Add(NewChoiceParameter);
		
		Items.ProductsOwnership.Visible				= True;
		Items.ProductsOwnership.ChoiceParameters	= New FixedArray(NewArray);
		
	ElsIf Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer")
		Or Object.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.TransferToSubcontractingCustomer") Then 
		
		NewArray = New Array();
		
		EnumCounterpartysInventory	= PredefinedValue("Enum.InventoryOwnershipTypes.CustomerProvidedInventory");
		NewChoiceParameter			= New ChoiceParameter("Filter.OwnershipType", EnumCounterpartysInventory);
		NewArray.Add(NewChoiceParameter);
		
		NewChoiceParameter			= New ChoiceParameter("Filter.Counterparty", Object.Counterparty);
		NewArray.Add(NewChoiceParameter);
		
		NewChoiceParameter			= New ChoiceParameter("Filter.Contract", Object.Contract);
		NewArray.Add(NewChoiceParameter);
		
		Items.ProductsOwnership.Visible				= True;
		Items.ProductsOwnership.ChoiceParameters	= New FixedArray(NewArray);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationType)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationType);
	
EndFunction

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 			TabName);
	StructureData.Insert("Object",				Form.Object);
	StructureData.Insert("Products",			TabRow.Products);
	StructureData.Insert("Characteristic",		TabRow.Characteristic);
	StructureData.Insert("SalesInvoice",		TabRow.SalesInvoice);
	
	If TabName = "Products" Then 
		StructureData.Insert("RevenueItem", TabRow.RevenueItem);
		StructureData.Insert("COGSItem", TabRow.COGSItem);
		StructureData.Insert("PurchaseReturnItem", TabRow.PurchaseReturnItem);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",							TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",					TabRow.GLAccountsFilled);
		
		StructureData.Insert("InventoryGLAccount",					TabRow.InventoryGLAccount);
		StructureData.Insert("RevenueGLAccount", 					TabRow.RevenueGLAccount);
		StructureData.Insert("COGSGLAccount", 						TabRow.COGSGLAccount);
		StructureData.Insert("UnearnedRevenueGLAccount",			TabRow.UnearnedRevenueGLAccount);
		StructureData.Insert("InventoryReceivedGLAccount",			TabRow.InventoryReceivedGLAccount);
		StructureData.Insert("InventoryTransferredGLAccount",		TabRow.InventoryTransferredGLAccount);
		StructureData.Insert("GoodsShippedNotInvoicedGLAccount",	TabRow.GoodsShippedNotInvoicedGLAccount);
		StructureData.Insert("GoodsInTransitGLAccount",				TabRow.GoodsInTransitGLAccount);
		StructureData.Insert("PurchaseReturnGLAccount",				TabRow.PurchaseReturnGLAccount);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureArray = New Array;
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Products");
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Products");
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

&AtServer
Procedure ProductsSalesInvoiceOnChangeAtServer(StructureData)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsAmountOnChange(Item)
	DriveClient.CalculateVATAmount(Items.Products.CurrentData, Object.AmountIncludesVAT);
EndProcedure

&AtServer
Procedure CheckBasisAvailability()

	If Object.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn Then
		
		ShowWarning = False; 
		If Object.Products.Count() = 0 Then
			ShowWarning = True;
		Else
			For Each Row In Object.Products Do
				If Row.VATRate = Catalogs.VATRates.EmptyRef() Then
					ShowWarning = True;
				EndIf;
			EndDo;
		EndIf;
		
		If ShowWarning Then
			CommonClientServer.MessageToUser(NStr("en = 'To fill-in ""Goods issue"" with Purchase return operation, please go to the Supplier invoices list, select one or several invoices, and press Generate button.'; ru = 'Для заполнения поля ""Отпуск товаров"" с помощью операции возврата покупки, перейдите в список инвойсов поставщика, выберите один или несколько инвойсов и нажмите кнопку ""Создать"".';pl = 'Aby wypełnić ""Wydanie zewnętrzne"" danymi operacji Zwrotu zakupu, proszę przejść do listy Faktur zakupu wybierz jedną lub więcej faktur, i kliknij przycisk Wygeneruj.';es_ES = 'Para rellenar el campo ""Salida de mercancías"" con la operación de devolución de compras, vaya a la lista de facturas de proveedor, seleccione una o varias facturas y pulse el botón Generar.';es_CO = 'Para rellenar el campo "" Expedición de productos "" con la operación de devolución de compras, vaya a la lista de facturas de proveedores, seleccione una o varias facturas y pulse el botón Generar.';tr = 'Satın alma iade işlemiyle ""Ambar çıkışını"" doldurmak için, lütfen Satın alma faturaları listesine gidin, bir veya birkaç fatura seçin ve Oluştur butonuna basın.';it = 'Per compilare ""Spedizione merce"" con l''operazione di restituzione acquisto, si prega di andare nell''elenco Fatture Fornitore, selezionare una o più fatture e premete il pulsante Generare.';de = 'Um den ""Warenausgang"" mit der Operation Einkaufsretoure auszufüllen, gehen Sie bitte in die Liste der Lieferantenrechnungen, wählen Sie eine oder mehrere Rechnungen aus und drücken Sie die Schaltfläche Generieren.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	
	If Object.OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer Then
		Items.CompanyVATNumber.Visible = False;
		WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.OriginVATNumber, FillOnlyEmpty);
	Else
		WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);
	EndIf;	
		
EndProcedure

&AtServer
Procedure FillOperationTypeChoiceList()
	
	ChoiceList = Items.OperationType.ChoiceList;
	
	ChoiceList.Clear();
	
	ChoiceList.Add(Enums.OperationTypesGoodsIssue.SaleToCustomer);
	ChoiceList.Add(Enums.OperationTypesGoodsIssue.TransferToAThirdParty);
	ChoiceList.Add(Enums.OperationTypesGoodsIssue.ReturnToAThirdParty);
	ChoiceList.Add(Enums.OperationTypesGoodsIssue.PurchaseReturn);
	
	If GetFunctionalOption("IntraCommunityTransfers") Then
		ChoiceList.Add(Enums.OperationTypesGoodsIssue.IntraCommunityTransfer);
	EndIf;
	
	If GetFunctionalOption("CanReceiveSubcontractingServices") Then
		ChoiceList.Add(Enums.OperationTypesGoodsIssue.TransferToSubcontractor);
	EndIf;
	
	If GetFunctionalOption("UseDropShipping") Then
		ChoiceList.Add(Enums.OperationTypesGoodsIssue.DropShipping);
	EndIf;
	
	// begin Drive.FullVersion
	If GetFunctionalOption("CanProvideSubcontractingServices") Then
		ChoiceList.Add(Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer);
		ChoiceList.Add(Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer);
	EndIf;
	// end Drive.FullVersion
	
EndProcedure

#Region Bundles

&AtClient
Procedure InventoryBeforeDeleteRowEnd(Result, BundleData) Export
	
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	BundleRows = Object.Products.FindRows(BundleData);
	If BundleRows.Count() = 0 Then
		Return;
	EndIf;
	
	BundleRow = BundleRows[0];
	
	If Result = DialogReturnCode.No Then
		
		EditBundlesComponents(BundleRow);
		
	ElsIf Result = DialogReturnCode.Yes Then
		
		BundlesClient.DeleteBundleRows(BundleRow.BundleProduct,
			BundleRow.BundleCharacteristic,
			Object.Products,
			Object.AddedBundles);
			
		Modified = True;
		SetBundlePictureVisible();
		
	ElsIf Result = "DeleteOne" Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("BundleProduct",			BundleRow.BundleProduct);
		FilterStructure.Insert("BundleCharacteristic",	BundleRow.BundleCharacteristic);
		AddedRows = Object.AddedBundles.FindRows(FilterStructure);
		BundleRows = Object.Products.FindRows(FilterStructure);
		
		If AddedRows.Count() = 0 Or AddedRows[0].Quantity <= 1 Then
			
			For Each Row In BundleRows Do
				Object.Products.Delete(Row);
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
			Object.Products,
			OldCount);
			
		Modified = True;
		
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
	BundlesClientServer.ReplaceInventoryLineWithBundleData(Object, "Products", BundleLine, StructureData);
	
	// Refresh RowFiler
	If Items.Products.RowFilter <> Undefined And Items.Products.RowFilter.Count() > 0 Then
		OldRowFilter = Items.Products.RowFilter;
		Items.Products.RowFilter = New FixedStructure(New Structure);
		Items.Products.RowFilter = OldRowFilter;
	EndIf;
	
	Items.ProductsBundlePicture.Visible = True;
	
EndProcedure

&AtServerNoContext
Procedure RefreshBundleAttributes(Products)
	
	If Not GetFunctionalOption("UseProductBundles") Then
		Return;
	EndIf;
	
	ProductsArray = New Array;
	For Each InventoryLine In Products Do
		
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
		
		For Each InventoryLine In Products Do
			
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
	FillingParameters.Insert("TableName", "Products");
	FillingParameters.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);

	BundlesServer.RefreshBundleComponentsInTable(BundleProduct, BundleCharacteristic, Quantity, BundleComponents, FillingParameters);
	Modified = True;
	
EndProcedure

&AtClient
Procedure EditBundlesComponents(InventoryLine)
	
	OpeningStructure = New Structure;
	OpeningStructure.Insert("BundleProduct", InventoryLine.BundleProduct);
	OpeningStructure.Insert("BundleCharacteristic", InventoryLine.BundleCharacteristic);
	
	AddedRows = Object.AddedBundles.FindRows(OpeningStructure);
	BundleRows = Object.Products.FindRows(OpeningStructure);
	
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
	
	For Each Row In Object.Products Do
		
		If Row.BundlePicture Then
			BundlePictureVisible = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Items.ProductsBundlePicture.Visible <> BundlePictureVisible Then
		Items.ProductsBundlePicture.Visible = BundlePictureVisible;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBundleConditionalAppearance()
	
	If UseBundles Then
		
		NewConditionalAppearance = ConditionalAppearance.Items.Add();
		WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
			"Object.Products.BundleProduct",
			Catalogs.Products.EmptyRef(),
			DataCompositionComparisonType.NotEqual);
			
		WorkWithForm.AddAppearanceField(NewConditionalAppearance, "ProductsProducts, ProductsCharacteristic, ProductsContent, ProductsQuantity, ProductsMeasurementUnit");
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

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.ProductsPrice);
	
	Return Fields;
	
EndFunction

#EndRegion

&AtServer
Procedure SetDeliveryOptionAccordanceToOperationType()
	
	If Object.OperationType = Enums.OperationTypesGoodsIssue.DropShipping Then
	
		Object.DeliveryOption	= Enums.DeliveryOptions.EmptyRef();
	
	EndIf;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion