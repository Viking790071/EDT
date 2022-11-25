
#Region Variables

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

#EndRegion

#Region FormEventHandlers

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
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	OperationKind = Object.OperationKind;
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
	SetVisibleAndEnabled();
	SetModeAndChoiceList();
	SetConditionalAppearance();
	
	DocumentModified = False;
	
	InProcessStatus = Constants.KitOrdersInProgressStatus.Get();
	CompletedStatus = Constants.KitOrdersCompletionStatus.Get();
	
	If Not Constants.UseKitOrderStatuses.Get() Then
		
		Items.StateGroup.Visible = False;
		
		Items.Status.ChoiceList.Add("InProcess", NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In corso';de = 'In Bearbeitung'"));
		Items.Status.ChoiceList.Add("Completed", NStr("en = 'Completed'; ru = 'Завершен';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
		Items.Status.ChoiceList.Add("Canceled", NStr("en = 'Canceled'; ru = 'Отменен';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Annullato';de = 'Abgebrochen'"));
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess And Not Object.Closed Then
			Status = "InProcess";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "Completed";
		Else
			Status = "Canceled";
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(
		Metadata.Documents.KitOrder.TabularSections.Products,
		DataLoadSettings,
		ThisObject);
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
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList(
		"ElectronicScales",
		,
		EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	Items.ProductsDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
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
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
	FormManagement();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	DocumentModified = False;
	
EndProcedure

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
		And IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			// Get a barcode from the basic data
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1));
			Else
				// Get a barcode from the additional data
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1));
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	CurrentObject.AdditionalProperties.Insert("NeedRecalculation", NeedRecalculation)
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
	If Cancel Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
EndProcedure

&AtClient
Procedure OrderStateStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = GetKitOrderStates();
	
EndProcedure

&AtClient
Procedure OperationKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = PredefinedValue("Enum.OperationTypesKitOrder.Disassembly") Then
		
		ProductsTypeInventory = PredefinedValue("Enum.ProductsTypes.InventoryItem");
		For Each StringProducts In Object.Products Do
			
			If ValueIsFilled(StringProducts.Products)
				And StringProducts.ProductsType <> ProductsTypeInventory Then
				
				MessageText = NStr("en = 'On the Finished products tab, in line #%2, %1 is a product with the Work type or Service type. Such a product cannot be included in the Disassembly process type. To be able to continue, delete the product from the Finished products tab.'; ru = 'Во вкладке Готовая продукция в строке %2 %1 - это номенклатура с типом Работа или Услуга. Такая номенклатура не может быть включена в тип процесса Разборка. Удалите номенклатуру из вкладки Готовая продукция для продолжения.';pl = 'W karcie ""Gotowe produkty"", w wierszu nr %2, %1 jest produkt z typem ""Praca"" lub ""Usługa"". Takie produkty nie mogą wchodzić do typu procesu ""Rozebranie"". Aby móc kontynuować, usuń produkt z karty ""Gotowe produkty"".';es_ES = 'En la pestaña Productos terminados, en la línea #%2, %1 es un producto con el tipo de Trabajo o el tipo de Servicio. Dicho producto no puede ser incluido en el tipo de proceso de Desmontaje. Para poder continuar, elimine el producto de la pestaña Productos terminados.';es_CO = 'En la pestaña Productos terminados, en la línea #%2, %1 es un producto con el tipo de Trabajo o el tipo de Servicio. Dicho producto no puede ser incluido en el tipo de proceso de Desmontaje. Para poder continuar, elimine el producto de la pestaña Productos terminados.';tr = 'Nihai ürünler sekmesinin %2 numaralı satırında %1, İş ve Hizmet türünde bir üründür. Bu tür bir ürün Demontaj işlem türüne dahil edilemez. Devam edebilmek için, ürünü Nihai ürünler sekmesinden silin.';it = 'Nella scheda Articoli finiti, nella riga #%2, %1 è un articolo con tipo Lavoro o Servizio. In quanto tale, questo articolo non può essere incluso nel tipo Processo di disassemblaggio. Per continuare, eliminare l''articolo dalla scheda Articoli finiti.';de = 'Auf der Registerkarte ""Fertigprodukte"" gibt es in der Zeile Nr. %2, %1 ein Produkt mit dem Arbeits- oder Dienstleistungstyp. Dieses Produkt kann nicht in den Vorgangstyp Demontage eingeschlossen werden. Um fortfahren zu können, löschen Sie dieses Produkt aus der Registerkarte ""Fertigprodukte"".'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					String(StringProducts.Products),
					StringProducts.LineNumber);
					
				DriveClient.ShowMessageAboutError(Object, MessageText);
				StandardProcessing = False;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	SetVisibleAndEnabled();
	
	If OperationKind <> Object.OperationKind Then
		
		// cleaning BOM column in Products
		For Each ProductsLine In Object.Products Do
			
			ProductsLine.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef");
			
		EndDo;
		
		ChangeOrderTabularSection();
		
		OperationKind = Object.OperationKind;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "InProcess" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "Completed" Then
		Object.OrderState = CompletedStatus;
	ElsIf Status = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	FormManagement();
	FillNeedRecalculation();
	
EndProcedure

&AtClient
Procedure OrderStateOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then
		
		Object.Closed = False;
		
	EndIf;
	
	FillNeedRecalculation();
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure StartOnChange(Item)
	
	If Object.Start > Object.Finish Then
		If ValueIsFilled(Object.Finish) Then
			DateDiff = Object.Finish - WhenChangingStart;
			Object.Finish = Object.Finish + DateDiff;
		Else
			Object.Finish = EndOfDay(Object.Start);
		EndIf;
		WhenChangingFinish = Object.Finish;
	EndIf;
	
	WhenChangingStart = Object.Start;
	FillNeedRecalculation();
	
EndProcedure

&AtClient
Procedure FinishOnChange(Item)
	
	Object.Finish = EndOfDay(Object.Finish);
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		CommonClientServer.MessageToUser(NStr("en = 'Due date cannot be earlier than Start date.'; ru = 'Срок не может быть раньше Даты начала.';pl = 'Termin nie może być wcześniejszy niż Data początkowa.';es_ES = 'La Fecha de vencimiento no puede ser anterior a la Fecha de inicio.';es_CO = 'La Fecha de vencimiento no puede ser anterior a la Fecha de inicio.';tr = 'Bitiş tarihi, Başlangıç tarihinden önce olamaz.';it = 'La Data prevista non può essere precedente alla Data di inizio.';de = 'Der Fälligkeitstermin darf nicht vor dem Startdatum liegen.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
EndProcedure

&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		And Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StatusExtendedTooltipNavigationLinkProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("DataProcessor.AdministrationPanel.Form.PurchaseSection");
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProducts

&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date, Object.OperationKind);
	
	If Not ValueIsFilled(StructureData.Specification)
		And StructureData.ShowSpecificationMessage Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot match a bill of materials to product ""%1"". You can select a bill of materials manually.'; ru = 'Не удалось сопоставить спецификацию с номенклатурой ""%1"". Вы можете выбрать спецификацию вручную.';pl = 'Nie można dopasować specyfikacji materiałowej do produktu ""%1"". Możesz wybrać specyfikację materiałową ręcznie.';es_ES = 'No puede coincidir una lista de materiales con el producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';es_CO = 'No puede coincidir una lista de materiales con el producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';tr = '''''%1'''' ürünü ile ürün reçetesi eşleşmiyor. Ürün reçetesini manuel olarak seçebilirsiniz.';it = 'Impossibile abbinare una distinta base all''articolo ""%1"". È possibile selezionare una distinta base manualmente.';de = 'Kann die Stückliste mit dem Produkt ""%1"" nicht übereinstimmen. Sie können die Stückliste manuell auswählen.'"),
			StructureData.ProductDescription);
		CommonClientServer.MessageToUser(MessageText);
			
	EndIf;
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
	TabularSectionRow.ProductsType = StructureData.ProductsType;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date, Object.OperationKind);
	
	If Not ValueIsFilled(StructureData.Specification)
		And StructureData.ShowSpecificationMessage Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot match a bill of materials with variant to product ""%1"". You can select a bill of materials manually.'; ru = 'Не удалось сопоставить спецификацию с вариантом с номенклатурой ""%1"". Вы можете выбрать спецификацию вручную.';pl = 'Nie można dopasować specyfikacji materiałowej do produktu ""%1"". Możesz wybrać specyfikację materiałową ręcznie.';es_ES = 'No puedo coincidir una lista de materiales con la variante del producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';es_CO = 'No puedo coincidir una lista de materiales con la variante del producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';tr = '''''%1'''' ürünü ile varyantlı ürün reçetesi eşleşmiyor. Ürün reçetesini manuel olarak seçebilirsiniz.';it = 'Impossibile abbinare una distinta base con variante all''articolo ""%1"". È possibile selezionare una distinta base manualmente.';de = 'Kann die Stückliste mit einer Variante mit dem Produkt ""%1"" nicht übereinstimmen. Sie können die Stückliste manuell auswählen.'"),
			StructureData.ProductDescription);
		CommonClientServer.MessageToUser(MessageText);
			
	EndIf;
	
	TabularSectionRow.Specification = StructureData.Specification;
	
	FormManagement();
	
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
Procedure ProductsSpecificationOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure ProductsAfterDeleteRow(Item)
	
	If Object.Products.Count() = 0 Then
		Object.Inventory.Clear();
		FormManagement();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date, Object.OperationKind);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date, Object.OperationKind);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
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

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Inventory.Count() <> 0 Then
		
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject),
			NStr("en = 'The Components tab will be repopulated. Do you want to continue?'; ru = 'Вкладка Компоненты будет перезаполнена. Продолжить?';pl = 'Karta Komponenty zostanie wypełniona ponownie. Czy chcesz kontynuować?';es_ES = 'La pestaña Componentes será rellenada. ¿Quiere continuar?';es_CO = 'La pestaña Componentes será rellenada. ¿Quiere continuar?';tr = 'Malzemeler sekmesi yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'La scheda Componenti sarà ricompilata. Continuare?';de = 'Die Tabelle mit Komponenten wird neu auffüllt. Möchten Sie fortfahren?'"), 
			QuestionDialogMode.YesNo);
		
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

&AtClient
Procedure CloseOrder(Command)
	
	If Modified Or Not Object.Posted Then
		ShowQueryBox(
			New NotifyDescription("CloseOrderEnd", ThisObject),
			NStr("en = 'The Kit order is not saved yet. It will be saved and then completed.'; ru = 'Заказ на комплектацию еще не записан. Он будет записан после завершения.';pl = 'Zamówienie zestawu jeszcze nie jest zapisane. Ono zostanie zapisane a następnie zakończone.';es_ES = 'El pedido del kit todavía no se ha guardado. Será guardado y luego finalizado.';es_CO = 'El pedido del kit todavía no se ha guardado. Será guardado y luego finalizado.';tr = 'Set siparişi henüz kaydedilmedi. Kaydedilip tamamlanacak.';it = 'L''Ordine kit non è ancora stato salvato. Sarà salvato e poi completato.';de = 'Der Kit-Auftrag ist noch nicht gespeichert. Er wird gespeichert und dann abgeschlossen.'"),
			QuestionDialogMode.OKCancel);
		Return;
	EndIf;
	
	CloseOrderFragment();
	FormManagement();
	
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

&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;
	
	ShowQueryBox(
		New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to repopulate the Kit order?'; ru = 'Перезаполнить заказ на комплектацию?';pl = 'Czy chcesz ponownie wypełnić zamówienie zestawu?';es_ES = '¿Desea rellenar el pedido del kit?';es_CO = '¿Desea rellenar el pedido del kit?';tr = 'Set siparişini yeniden doldurmak istiyor musunuz?';it = 'Ricompilare l''Ordine kit?';de = 'Möchten Sie den Kit-Auftrag neu füllen?'"),
		QuestionDialogMode.YesNo,
		0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillUsingSalesOrder(Command)
	
	Response = Undefined;

	ShowQueryBox(New NotifyDescription("FillBySalesOrderEnd", ThisObject), 
		NStr("en = 'The Kit order will be repopulated with data from the selected Sales order. Do you want to continue?'; ru = 'Заказ на комплектацию будет перезаполнен данными из выбранного заказа покупателя. Продолжить?';pl = 'Zamówienie zestawu zostanie wypełnione danymi z wybranego Zamówienia sprzedaży. Czy chcesz kontynuować?';es_ES = 'El pedido del kit se volverá a rellenar con los datos de la Orden de ventas seleccionada. ¿Quiere continuar?';es_CO = 'El pedido del kit se volverá a rellenar con los datos de la Orden de ventas seleccionada. ¿Quiere continuar?';tr = 'Set siparişi, seçilen Satış siparişinin verileriyle yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'L''Ordine kit sarà ricompilato con i dati dall''Ordine cliente selezionato. Continuare?';de = 'Der Kit-Auftrag wird aus dem ausgewählten Kundenauftrag neu aufgefüllt. Möchten Sie fortfahren?'"), 
		QuestionDialogMode.YesNo,
		0);
	
EndProcedure

&AtClient
Procedure FillBySalesOrderEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument("SalesOrder");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region ServiceProceduresAndFunctions

&AtServer
Procedure CloseOrderFragment(Result = Undefined, AdditionalParameters = Undefined) Export
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.Ref);
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("KitOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Read();
	
EndProcedure

&AtClient
Procedure FormManagement()

	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	If GetAccessRightForDocumentPosting() Then
		Items.FormPost.Enabled			= (Not StatusIsComplete Or Not Object.Closed);
		Items.FormPostAndClose.Enabled	= (Not StatusIsComplete Or Not Object.Closed);
	EndIf;
	
	Items.FormWrite.Enabled 			= Not StatusIsComplete Or Not Object.Closed;
	Items.FormCreateBasedOn.Enabled 	= Not StatusIsComplete Or Not Object.Closed;
	Items.CloseOrder.Visible			= Not Object.Closed;
	Items.CloseOrderStatus.Visible		= Not Object.Closed;
	CloseOrderEnabled 					= DriveServer.CheckCloseOrderEnabled(Object.Ref);
	Items.CloseOrder.Enabled			= CloseOrderEnabled;
	Items.CloseOrderStatus.Enabled		= CloseOrderEnabled;
	Items.ProductsCommandBar.Enabled	= Not StatusIsComplete;
	Items.InventoryCommandBar.Enabled	= Not StatusIsComplete;
	Items.FillByBasis.Enabled			= Not StatusIsComplete;
	Items.FillUsingSalesOrder.Enabled	= Not StatusIsComplete;
	Items.StructuralUnit.ReadOnly		= StatusIsComplete;
	Items.StarFinishGroup.ReadOnly		= StatusIsComplete;
	Items.GroupBasisDocument.ReadOnly	= StatusIsComplete;
	Items.RightColumn.ReadOnly			= StatusIsComplete;
	Items.Pages.ReadOnly				= StatusIsComplete;
	Items.FormSettings.Enabled			= Not StatusIsComplete;
	
EndProcedure

&AtServerNoContext
Function GetAccessRightForDocumentPosting()
	
	Return AccessRight("Posting", Metadata.Documents.KitOrder);
	
EndFunction

&AtServerNoContext
Function GetKitOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	KitOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.KitOrderStatuses AS KitOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON KitOrderStatuses.OrderStatus = OrderStatuses.Ref
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
Procedure FillNeedRecalculation()

	If Object.Ref.OrderState = Catalogs.KitOrderStatuses.Open Then
		
		If Object.OrderState <> Catalogs.KitOrderStatuses.Open Then
			
			NeedRecalculation = True;
			
		EndIf;
		
	Else
		
		NeedRecalculation = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionBySpecification();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate, OperationKind)
	
	StuctureProduct = Common.ObjectAttributesValues(StructureData.Products,
		"MeasurementUnit, ProductsType, Description");
	
	StructureData.Insert("ProductsType", StuctureProduct.ProductsType);
	StructureData.Insert("MeasurementUnit", StuctureProduct.MeasurementUnit);
	StructureData.Insert("ProductDescription", StuctureProduct.Description);
	
	StructureData.Insert("ShowSpecificationMessage", False);
	
	If Not ObjectDate = Undefined Then
		
		If StructureData.Property("Characteristic") Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				OperationKind);
		Else
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				Catalogs.ProductsCharacteristics.EmptyRef(),
				OperationKind);
		EndIf;
		
		StructureData.Insert("Specification", Specification);
		
		StructureData.Insert("ShowSpecificationMessage", True);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate = Undefined, OperationKind = Undefined)
	
	StructureData.Insert("ShowSpecificationMessage", False);
	
	If Not ObjectDate = Undefined Then
		
		StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "Description");
		
		Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(
			StructureData.Products,
			ObjectDate,
			StructureData.Characteristic,
			OperationKind);
		StructureData.Insert("Specification", Specification);
		
		StructureData.Insert("ShowSpecificationMessage", True);
		StructureData.Insert("ProductDescription", StuctureProduct.Description);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure FillByDocument(Attribute = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Fill(Object[Attribute]);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabled()
	
	VisibleValue = (Object.SalesOrderPosition = Enums.AttributeStationing.InHeader);
	
	Items.GroupSalesOrder.Visible = VisibleValue;
	Items.GroupBasisDocument.Enabled = VisibleValue;
	
	UseDisassembly = Object.OperationKind = PredefinedValue("Enum.OperationTypesKitOrder.Disassembly");
	
	CommonClientServer.SetFormItemProperty(Items, "InventorySalesOrder", "Visible", Not VisibleValue And UseDisassembly);
	CommonClientServer.SetFormItemProperty(Items, "ProductsSalesOrder", "Visible", Not VisibleValue And Not UseDisassembly);
	CommonClientServer.SetFormItemProperty(Items, "ProductsSalesOrder", "TypeRestriction", New TypeDescription("DocumentRef.SalesOrder"));
	CommonClientServer.SetFormItemProperty(Items, "InventorySalesOrder", "TypeRestriction", New TypeDescription("DocumentRef.SalesOrder"));
	CommonClientServer.SetFormItemProperty(Items, "FormSettings", "Visible", GetFunctionalOption("UseInventoryReservation"));
	
	If Object.OperationKind = Enums.OperationTypesKitOrder.Disassembly Then
		
		// Product type.
		NewParameter = New ChoiceParameter("Filter.ProductsType", Enums.ProductsTypes.InventoryItem);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProducts.ChoiceParameters = NewParameters;
		
	Else
		
		// Product type.
		NewArray = New Array();
		NewArray.Add(Enums.ProductsTypes.InventoryItem);
		NewArray.Add(Enums.ProductsTypes.Work);
		NewArray.Add(Enums.ProductsTypes.Service);
		ArrayInventoryWork = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayInventoryWork);
		NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryWork);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProducts.ChoiceParameters = NewParameters;
		
	EndIf;
	
EndProcedure

// Procedure sets selection mode and selection list for the form units.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetModeAndChoiceList()
	
	If Not Constants.UseSeveralDepartments.Get()
		And Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
	
	// ProductsSpecification
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Products.ProductsType");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.ProductsTypes.Service;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<bills of materials are not used>'; ru = '<спецификации не используются>';pl = '<Specyfikacje materiałowe nie są używane>';es_ES = '<listas de materiales no se utilizan>';es_CO = '<bills of materials are not used>';tr = '<ürün reçeteleri kullanılmaz>';it = '<Distinte base non utilizzate>';de = '<Stücklisten werden nicht verwendet>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProductsSpecification");
	FieldAppearance.Use = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'kit order'; ru = 'заказ на комплектацию';pl = 'zamówienie zestawu';es_ES = 'pedido del Kit';es_CO = 'pedido del Kit';tr = 'set siparişi';it = 'ordine kit';de = 'kit-auftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False);
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnit);
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
Procedure ProductsPick(Command)
	
	TabularSectionName 	= "Products";
	DocumentPresentaion	= NStr("en = 'kit order'; ru = 'заказ на комплектацию';pl = 'zamówienie zestawu';es_ES = 'pedido del Kit';es_CO = 'pedido del Kit';tr = 'set siparişi';it = 'ordine kit';de = 'kit-auftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnit);
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

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName = "Products" Then
			
			If ValueIsFilled(ImportRow.Products) Then
				
				NewRow.ProductsType = ImportRow.Products.ProductsType;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			CurrentPagesProducts		= (Items.Pages.CurrentPage = Items.TSProducts);
			TabularSectionName			= ?(CurrentPagesProducts, "Products", "Inventory");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
			FormManagement();
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			CurrentPagesProducts		= (Items.Pages.CurrentPage = Items.TSProducts);
			TabularSectionName			= ?(CurrentPagesProducts, "Products", "Inventory");
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure
&AtClient
Procedure Settings(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("SalesOrderPositionInShipmentDocuments", Object.SalesOrderPosition);
	ParametersStructure.Insert("RenameSalesOrderPositionInShipmentDocuments", NStr("en = 'Reserve for position in Kit order'; ru = 'Положение строки ""Резерв для"" в заказе на комплектацию';pl = 'Pozycja rezerwa dla w Zamówieniu zestawu';es_ES = 'Reserva de posición en el pedido del Kit';es_CO = 'Reserva de posición en el pedido del Kit';tr = 'Set siparişinde ""Rezerve et"" pozisyonu';it = 'Riserva per posizione nell''Ordine kit';de = 'Reserve für Position in Kit-Auftrag'"));
	ParametersStructure.Insert("WereMadeChanges", False);
	
	TableName = ?(Object.OperationKind = PredefinedValue("Enum.OperationTypesKitOrder.Disassembly"),
		"Inventory", "Products");
	
	TableObject = Object[TableName];
	
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
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("SettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure SettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInShipmentDocuments;
		NameTable = ?(Object.OperationKind = PredefinedValue("Enum.OperationTypesKitOrder.Disassembly"),
			"Inventory", "Products");
		TableObject = Object[NameTable];
		
		If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			
			If TableObject.Count() Then
				Object.SalesOrder = TableObject[0].SalesOrder;
			EndIf;
			
		Else
			
			If ValueIsFilled(Object.SalesOrder) Then
				For Each InventoryRow In TableObject Do
					If Not ValueIsFilled(InventoryRow.SalesOrder) Then
						InventoryRow.SalesOrder = Object.SalesOrder;
					EndIf;
				EndDo;
				
				Object.SalesOrder = Undefined;
				Object.BasisDocument = Undefined;
			EndIf;
			
		EndIf;
		
		SetVisibleAndEnabled();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeOrderTabularSection()
	
	If Object.OperationKind = Enums.OperationTypesKitOrder.Disassembly Then
		For Each TabularSectionRow In Object.Products Do
			TabularSectionRow.SalesOrder = Undefined;
		EndDo;
	Else
		For Each TabularSectionRow In Object.Inventory Do
			TabularSectionRow.SalesOrder = Documents.SalesOrder.EmptyRef();
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileGoods(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"KitOrder.Products");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import finished products from file'; ru = 'Загрузка готовой продукции из файла';pl = 'Importuj gotowe produkty z pliku';es_ES = 'Importar los productos terminados del archivo';es_CO = 'Importar los productos terminados del archivo';tr = 'Nihai ürünleri dosyadan içe aktar';it = 'Importare articoli finiti da file';de = 'Fertigprodukte aus Datei importieren'"));
	
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

#Region Peripherals

&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserire codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;

EndProcedure

&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line for which the weight should be received.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, dla którego trzeba uzyskać wagę.';es_ES = 'Seleccionar una línea para la cual el peso tienen que recibirse.';es_CO = 'Seleccionar una línea para la cual el peso tienen que recibirse.';tr = 'Ağırlığın alınması gereken bir satır seçin.';it = 'Selezionare la riga per la quale dovrà essere ricevuto il peso.';de = 'Wählen Sie eine Zeile aus, für die das Gewicht empfangen werden soll.'"));
		
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
			MessageText = NStr("en = 'Electronic scales returned zero weight.'; ru = 'Электронные весы вернули нулевой вес.';pl = 'Waga elektroniczna zwróciła zerową wagę.';es_ES = 'Escalas electrónicas han devuelto el peso cero.';es_CO = 'Escalas electrónicas han devuelto el peso cero.';tr = 'Elektronik tartı sıfır ağırlık gösteriyor.';it = 'Le bilance elettroniche restituiscono zero peso.';de = 'Die elektronische Waagen gaben Nullgewicht zurück.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
		EndIf;
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
		And Result.Count() > 0 Then
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
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			
			BarcodeData.Insert("StructureProductsData",
				GetDataProductsOnChange(StructureProductsData, StructureData.Date, StructureData.OperationKind));
			
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
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("OperationKind", Object.OperationKind);
	GetDataByBarCodes(StructureData);
	
	If Items.Pages.CurrentPage = Items.TSProducts Then
		TableName = "Products";
	Else
		TableName = "Inventory";
	EndIf;
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			And BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object[TableName].FindRows(New Structure("Products,Characteristic,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object[TableName].Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				If NewRow.Property("ProductsType") Then
					NewRow.ProductsType = BarcodeData.StructureProductsData.ProductsType;
				EndIf;
				Items[TableName].CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				Items[TableName].CurrentRow = FoundString.GetID();
			EndIf;
			
			Modified = True;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction

&AtClient
Procedure BarcodesReceived(BarcodesData)
	
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
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Dati del codice a barre non trovati: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
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

#EndRegion
