
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CalculateItemsAtServer();
	
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisObject);
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisObject);
	DriveServer.OverrideStandartGenerateJobCommand(ThisObject);
	
	WeightUOM = Constants.WeightUOM.Get();
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ProcessingCompanyVATNumbers();
	
	SetAvailableItems();
	SetConditionalAppearance();
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarcodeScanner");
	// End Peripherals
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	CalculateQtyOfAddressesAndWeightOfContainer();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

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
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID Then
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	CompanyOnChangeAtServer();
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion 

#Region FormTableItemsEventHandlersSalesOrders

&AtClient
Procedure SalesOrdersOnChange(Item)
	UpdateAvailableItemsAtServer();
EndProcedure

&AtClient
Procedure SalesOrdersSaleOrderStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	AvailableSalesOrdersArray = GetAvaibleSalesOrders();
	
	OpenForm = OpenForm("Document.SalesOrder.ChoiceForm",, Item);
	FilterItems = OpenForm.List.Filter.Items;
	FilterItems.Clear();
	
	NewFilter = FilterItems.Add(Type("DataCompositionFilterItem"));
	NewFilter.Use            = True;
	NewFilter.LeftValue      = New DataCompositionField("Ref");
	NewFilter.ComparisonType = DataCompositionComparisonType.InList;
	NewFilter.RightValue     = AvailableSalesOrdersArray;
	
	OpenForm.Open();
	
EndProcedure

&AtClient
Procedure SalesOrdersSaleOrderChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	CurrentData = Items.SalesOrders.CurrentData;
	CurrentData.SalesOrder = SelectedValue;
	UpdateAvailableItemsAtServer();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersExistingPackages

&AtClient
Procedure ExistingPackagesOnActivateRow(Item)
	
	CurrentData = Items.ExistingPackages.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentExistingPackageLine = CurrentData.KeyExistingPackages;
		
	SetFilterByPackageContents();
EndProcedure

&AtClient
Procedure ExistingPackagesContainerTypeOnChange(Item)
	ExistingPackagesContainerTypeOnChangeAtServer();
EndProcedure

&AtClient
Procedure ExistingPackagesBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.ExistingPackages.CurrentData;
	FindedRows = Object.Inventory.FindRows(New Structure("ExistingPackageLine", CurrentData.KeyExistingPackages));
	
	If FindedRows.Count() > 0 Then
		Cancel = True;
		NotifyDescription = New NotifyDescription("EndDeleteConainer", ThisObject,CurrentData.KeyExistingPackages);
		ShowQueryBox(NotifyDescription, NStr("en = 'This container is not empty. Continue?'; ru = 'Этот контейнер не пустой. Продолжить?';pl = 'To opakowanie nie jest puste. Kontynuować?';es_ES = 'Este contenedor no está vacío. ¿Continuar?';es_CO = 'Este contenedor no está vacío. ¿Continuar?';tr = 'Bu konteynır boş değil. Devam et?';it = 'Il contenitore non è vuoto. Continuare?';de = 'Dieser Container ist nicht leer. Fortsetzen?'"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExistingPackagesOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		Item.CurrentData.KeyExistingPackages = New UUID();
		Item.CurrentData.Weight = Item.CurrentData.WeightOfContainer;
		CurrentExistingPackageLine = Item.CurrentData.KeyExistingPackages;
		
		ExistingPackagesOnActivateRow(Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExistingPackagesDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	If Row = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(DragParameters.Value) = Type("Structure") Then
		
		DoType = "";
		If DragParameters.Value.Property("Type",DoType) Then
			
			StandardProcessing = False;
			
			ProductArray = DragParameters.Value.Value;
			CurrentData = Object.ExistingPackages.FindByID(Row);
			
			If DoType = "AvailableItem" Then 
				
				If AskForQuantity Then
					
					OpenParameters = New Structure;
					OpenParameters.Insert("ArrayAvailableItems",ProductArray);
					OpenParameters.Insert("KeyExistingPackages",CurrentData.KeyExistingPackages);
					OpenParameters.Insert("ItemTable",TableAvailableItem);
					
					Res = New NotifyDescription("AfterValueInput", ThisObject, OpenParameters);
					Quantity = 0;
					ShowInputValue(Res, Quantity, NStr("en = 'Please enter a quantity'; ru = 'Введите количество';pl = 'Proszę wprowadzić ilość';es_ES = 'Por favor, introduzca una cantidad';es_CO = 'Por favor, introduzca una cantidad';tr = 'Lütfen, miktar girin';it = 'Per piacere inserisci una quantità';de = 'Bitte geben Sie eine Menge ein'"));
					
				Else
					AddProductIntoContainerInArray(ProductArray, CurrentData.KeyExistingPackages, TableAvailableItem);
					CalculateItemsAtServer();
				EndIf;

			ElsIf DoType = "MoveItems" Then
				
				AddProductIntoContainerInArray(ProductArray, CurrentData.KeyExistingPackages, Object.Inventory);
				QtyOfArray = ProductArray.Count();
				Counter = 0;
				
				While Counter <= QtyOfArray -1 Do
					DataRow = Object.Inventory.FindByID(ProductArray[Counter]);
					Object.Inventory.Delete(DataRow);
					QtyOfArray = QtyOfArray - 1;
				EndDo;	
				
				CalculateItemsAtServer();

			EndIf;
			
		EndIf;
		
		Modified = True;
		UpdateWeightOfPackages();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExistingPackagesDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAvailableItem

&AtClient
Procedure TableAvailableItemDragStart(Item, DragParameters, Perform)
	
	ValueStructure = New Structure("Type,Value","AvailableItem",Item.SelectedRows);
	DragParameters.Value = ValueStructure;
EndProcedure

&AtClient
Procedure TableAvailableItemDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure TableAvailableItemDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	If TypeOf(DragParameters.Value) = Type("Structure") Then
		
		DoType = "";
		If DragParameters.Value.Property("Type", DoType) Then
			
			StandardProcessing = False;
			ProductArray = DragParameters.Value.Value;
			
			If DoType = "MoveItems" Then
				
				QtyOfArray = ProductArray.Count();
				Counter = 0;
				
				While Counter <= QtyOfArray -1 Do
					DataRow = Object.Inventory.FindByID(ProductArray[Counter]);
					Object.Inventory.Delete(DataRow);
					QtyOfArray = QtyOfArray - 1;
				EndDo;	
				
				CalculateItemsAtServer();

			EndIf;
		EndIf;
		
		Modified = True;
		UpdateWeightOfPackages();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TableAvailableItemQuantityOnChange(Item)
	
	CurrentData = Items.TableAvailableItem.CurrentData;
	
	If CurrentData = Undefined  Then
		Return;
	EndIf;
	
	CalculateRowWeight(CurrentData.GetId(), False);
	
EndProcedure

&AtClient
Procedure TableAvailableItemMeasurementUnitOnChange(Item)
	
	CurrentData = Items.TableAvailableItem.CurrentData;
	
	If CurrentData = Undefined  Then
		Return;
	EndIf;
	
	CalculateRowWeight(CurrentData.GetId(), False);
	
EndProcedure

&AtClient
Procedure FilterBySalesOrdersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	Items.FilterBySalesOrders.ChoiceList.Clear();
	
	For Each Row In Object.SalesOrders Do
		Items.FilterBySalesOrders.ChoiceList.Add(Row.SalesOrder);
	EndDo;
	
EndProcedure

&AtClient
Procedure FilterBySalesOrdersOnChange(Item)
	
	If Not ValueIsFilled(FilterBySalesOrders) Then
		Items.TableAvailableItem.RowFilter = Undefined;
	Else
		Items.TableAvailableItem.RowFilter = New FixedStructure("SalesOrder", FilterBySalesOrders);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPackageContents

&AtClient
Procedure PackageContentsQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData = Undefined  Then
		Return;
	EndIf;
	
	PackageContentsQuantityOnChangeAtServer(CurrentData.GetId());
	
EndProcedure

&AtServer
Procedure PackageContentsQuantityOnChangeAtServer(CurrentItem)
	
	CalculateItemsAtServer();
	CalculateRowWeight(CurrentItem);
	
EndProcedure

&AtClient
Procedure PackageContentsAfterDeleteRow(Item)
	UpdateWeightOfPackages();
	CalculateItemsAtServer();
EndProcedure

&AtClient
Procedure PackageContentsDragStart(Item, DragParameters, Perform)
	ValueStructure = New Structure("Type,Value","MoveItems",Item.SelectedRows);
	DragParameters.Value = ValueStructure;
EndProcedure

&AtClient
Procedure PackageContentsOnStartEdit(Item, NewRow, Clone)
	If NewRow And Not Clone Then 
		Item.CurrentData.ExistingPackageLine = CurrentExistingPackageLine;	
	EndIf;
EndProcedure

&AtClient
Procedure PackageContentsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	ExistingPackageRow = Items.ExistingPackages.CurrentData;
	If ExistingPackageRow = Undefined Then
		Return;		
	EndIf;
	
	If TypeOf(DragParameters.Value) = Type("Structure") Then
		
		DoType = "";
		If DragParameters.Value.Property("Type", DoType) Then
			
			StandardProcessing = False;
			
			ProductArray = DragParameters.Value.Value;
			
			If DoType = "AvailableItem" Then 
				
				If AskForQuantity Then
					
					OpenParameters = New Structure;
					OpenParameters.Insert("ArrayAvailableItems", ProductArray);
					OpenParameters.Insert("KeyExistingPackages", ExistingPackageRow.KeyExistingPackages);
					OpenParameters.Insert("ItemTable", TableAvailableItem);
					
					Res = New NotifyDescription("AfterValueInput", ThisObject, OpenParameters);
					Quantity = 0;
					ShowInputValue(Res, Quantity, NStr("en = 'Please enter a quantity'; ru = 'Введите количество';pl = 'Proszę wprowadzić ilość';es_ES = 'Por favor, introduzca una cantidad';es_CO = 'Por favor, introduzca una cantidad';tr = 'Lütfen, miktar girin';it = 'Per piacere inserisci una quantità';de = 'Bitte geben Sie eine Menge ein'"));
					
				Else
					AddProductIntoContainerInArray(ProductArray, ExistingPackageRow.KeyExistingPackages, TableAvailableItem);
					CalculateItemsAtServer();
				EndIf;

			ElsIf DoType = "MoveItems" Then
				
				AddProductIntoContainerInArray(ProductArray, ExistingPackageRow.KeyExistingPackages, Object.Inventory);
				QtyOfArray = ProductArray.Count();
				Counter = 0;
				
				While Counter <= QtyOfArray -1 Do
					DataRow = Object.Inventory.FindByID(ProductArray[Counter]);
					Object.Inventory.Delete(DataRow);
					QtyOfArray = QtyOfArray - 1;
				EndDo;	
				
				CalculateItemsAtServer();

			EndIf;
			
		EndIf;
		
		Modified = True;
		UpdateWeightOfPackages();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PackageContentsDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure PackageContentsSerialNumberStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenSerialNumbersSelection();
EndProcedure

&AtClient
Procedure PackageContentsWeightOnChange(Item)
	UpdateWeightOfPackages();
EndProcedure

&AtClient
Procedure PackageContentsProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Quantity = 1;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("ID", TabularSectionRow.GetID());
	
	StructureData = GetDataProductsOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData); 
	UpdateWeightOfPackages();
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryMeasurementUnitOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData = Undefined  Then
		Return;
	EndIf;
	
	PackageContentsQuantityOnChangeAtServer(CurrentData.GetId());
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddProductToSelectedPackage(Command)
	
	CurrentContainer = Items.ExistingPackages.CurrentData;
	
	If CurrentContainer = Undefined Then 
		CommonClientServer.MessageToUser(NStr("en = 'Choose container'; ru = 'Выберите контейнер';pl = 'Wybierz opakowanie';es_ES = 'Seleccione el contenedor';es_CO = 'Seleccione el contenedor';tr = 'Konteynır seçin';it = 'Scegli contenitore';de = 'Container auswählen'"));
		Return;
	EndIf;
	
	ArrayAvailableItems = Items.TableAvailableItem.SelectedRows;
	
	If AskForQuantity Then
		
		OpenParameters = New Structure;
		OpenParameters.Insert("ArrayAvailableItems",ArrayAvailableItems);
		OpenParameters.Insert("KeyExistingPackages",CurrentContainer.KeyExistingPackages);
		OpenParameters.Insert("ItemTable",TableAvailableItem);
		
		Res = New NotifyDescription("AfterValueInput", ThisObject, OpenParameters);
		Quantity = 0;
		ShowInputValue(Res, Quantity, NStr("en = 'Please enter a quantity'; ru = 'Введите количество';pl = 'Proszę wprowadzić ilość';es_ES = 'Por favor, introduzca una cantidad';es_CO = 'Por favor, introduzca una cantidad';tr = 'Lütfen, miktar girin';it = 'Per piacere inserisci una quantità';de = 'Bitte geben Sie eine Menge ein'"));
		
	Else
		AddProductIntoContainerInArray(ArrayAvailableItems, CurrentContainer.KeyExistingPackages, TableAvailableItem);
		UpdateWeightOfPackages();
		CalculateItemsAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure AddAllProductsToSelectedPackage(Command)
	
	CurrentContainer = Items.ExistingPackages.CurrentData;
	
	If CurrentContainer = Undefined Then 
		CommonClientServer.MessageToUser(NStr("en = 'Choose container'; ru = 'Выберите контейнер';pl = 'Wybierz opakowanie';es_ES = 'Seleccione el contenedor';es_CO = 'Seleccione el contenedor';tr = 'Konteynır seçin';it = 'Scegli contenitore';de = 'Container auswählen'"));
		Return;
	EndIf;
	
	For Each Row In TableAvailableItem Do
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, Row);
		NewRow.ExistingPackageLine = CurrentContainer.KeyExistingPackages;
	EndDo;
	
	UpdateAvailableItemsAtServer();
	UpdateWeightOfPackages();
	
EndProcedure

&AtClient
Procedure ChangePackage(Command)
	
	ValueList = New ValueList;
	
	For Each Row In Object.ExistingPackages Do
		ValueList.Add(Row, "ID " + Row.InternalID);
	EndDo;
	
	Res = New NotifyDescription("DoAfterShowChooseItem", ThisObject);
	ValueList.ShowChooseItem(Res, NStr("en = 'Select container'; ru = 'Выберите контейнер';pl = 'Wybierz opakowanie';es_ES = 'Seleccione el contenedor';es_CO = 'Seleccione el contenedor';tr = 'Konteynır seçin';it = 'Seleziona contenitore';de = 'Container wählen'"));
	
EndProcedure

&AtClient
Procedure DoAfterShowChooseItem(ItemSelection, ListOfParameters) Export
	
	If ItemSelection = Undefined Then
        Return;
    Else
		
		SelectedValue = ItemSelection.Value;
		ProductArray = Items.Inventory.SelectedRows;
		AddProductIntoContainerInArray(ProductArray, SelectedValue.KeyExistingPackages, Object.Inventory);
		QtyOfArray = ProductArray.Count();
		Counter = 0;
		
		While Counter <= QtyOfArray - 1 Do
			
			DataRow = Object.Inventory.FindByID(ProductArray[Counter]);
			Object.Inventory.Delete(DataRow);
			QtyOfArray = QtyOfArray - 1;
			
		EndDo;
		
	EndIf;
	
	Modified = True;
	CalculateItemsAtServer();
	UpdateWeightOfPackages();
	
EndProcedure

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

&AtClient
Procedure Attachable_GenerateSalesInvoice(Command)
	
	If Modified Or Not ValueIsFilled(Object.Ref) Then
		
		QueryText = NStr("en = 'The Packing slip will be automatically saved. Then the selected document will be generated. Continue?'; ru = 'Упаковочный лист будет автоматически сохранен, затем будет сформирован выбранный документ. Продолжить?';pl = 'List przewozowy zostanie automatycznie zapisany. Zatem wybrany dokument zostanie wygenerowany. Kontynuować?';es_ES = 'El Albarán de entrega se guardará automáticamente. A continuación, se generará el documento seleccionado. ¿Continuar?';es_CO = 'El Albarán de entrega se guardará automáticamente. A continuación, se generará el documento seleccionado. ¿Continuar?';tr = 'Sevk irsaliyesi otomatik olarak saklanacak. Ardından, seçilen belge oluşturulacak. Devam edilsin mi?';it = 'La Packing list sarà salvata automaticamente. Poi, il documento selezionato sarà generato. Continuare?';de = 'Der Packzettel wird automatisch gespeichert. Dann das ausgewählte Dokument wird generiert. Fortsetzen?'");
		
		ShowQueryBox(New NotifyDescription("GenerateSalesInvoiceEnd", ThisObject), QueryText, QuestionDialogMode.OKCancel);
		
		Return;
		
	EndIf;
	
	CreateSalesInvoicesClient();

EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)

	If Modified Or Not ValueIsFilled(Object.Ref) Then
		
		QueryText = NStr("en = 'The Packing slip will be automatically saved. Then the selected document will be generated. Continue?'; ru = 'Упаковочный лист будет автоматически сохранен, затем будет сформирован выбранный документ. Продолжить?';pl = 'List przewozowy zostanie automatycznie zapisany. Zatem wybrany dokument zostanie wygenerowany. Kontynuować?';es_ES = 'El Albarán de entrega se guardará automáticamente. A continuación, se generará el documento seleccionado. ¿Continuar?';es_CO = 'El Albarán de entrega se guardará automáticamente. A continuación, se generará el documento seleccionado. ¿Continuar?';tr = 'Sevk irsaliyesi otomatik olarak saklanacak. Ardından, seçilen belge oluşturulacak. Devam edilsin mi?';it = 'La Packing list sarà salvata automaticamente. Poi, il documento selezionato sarà generato. Continuare?';de = 'Der Packzettel wird automatisch gespeichert. Dann das ausgewählte Dokument wird generiert. Fortsetzen?'");
		
		ShowQueryBox(New NotifyDescription("GenerateGoodsIssueEnd", ThisObject), QueryText, QuestionDialogMode.OKCancel);
		
		Return;
		
	EndIf;
	
	CreateGoodsIssueClient();

EndProcedure

&AtClient
Procedure Attachable_GenerateJob(Command)

	If Modified Or Not ValueIsFilled(Object.Ref) Then
		
		QueryText = NStr("en = 'The Packing slip will be automatically saved. Then the selected document will be generated. Continue?'; ru = 'Упаковочный лист будет автоматически сохранен, затем будет сформирован выбранный документ. Продолжить?';pl = 'List przewozowy zostanie automatycznie zapisany. Zatem wybrany dokument zostanie wygenerowany. Kontynuować?';es_ES = 'El Albarán de entrega se guardará automáticamente. A continuación, se generará el documento seleccionado. ¿Continuar?';es_CO = 'El Albarán de entrega se guardará automáticamente. A continuación, se generará el documento seleccionado. ¿Continuar?';tr = 'Sevk irsaliyesi otomatik olarak saklanacak. Ardından, seçilen belge oluşturulacak. Devam edilsin mi?';it = 'La Packing list sarà salvata automaticamente. Poi, il documento selezionato sarà generato. Continuare?';de = 'Der Packzettel wird automatisch gespeichert. Dann das ausgewählte Dokument wird generiert. Fortsetzen?'");
		
		ShowQueryBox(New NotifyDescription("GenerateJobEnd", ThisObject), QueryText, QuestionDialogMode.OKCancel);
		
		Return;
		
	EndIf;
	
	CreateJobClient();

EndProcedure
// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	AdditionalParameters = New Structure("CurBarcode", CurBarcode);
	ShowInputValue(New NotifyDescription(
		"SearchByBarcodeEnd", ThisObject, AdditionalParameters), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;
	
EndProcedure

// Procedure processes the received barcodes.
//
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
		
		MessageString = NStr("en = 'Barcode is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono kodów kreskowych: %1%; ilość: %2%';es_ES = 'Código de barras no encontrado: %1%; cantidad: %2%';es_CO = 'Código de barras no encontrado: %1%; cantidad: %2%';tr = 'Barkod bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità:%2%';de = 'Barcode wird nicht gefunden: %1%; Menge: %2%'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			MessageString, CurUndefinedBarcode.Barcode, CurUndefinedBarcode.Quantity); 
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	CurrentDataExistingPackages = Items.ExistingPackages.CurrentData;
	
	If CurrentDataExistingPackages = Undefined Then
		Return UnknownBarcodes;
	EndIf;
		
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
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			FilterStructure = New Structure;
			FilterStructure.Insert("Products",				BarcodeData.Products);
			FilterStructure.Insert("Characteristic",		BarcodeData.Characteristic);
			FilterStructure.Insert("Batch",					BarcodeData.Batch);
			FilterStructure.Insert("MeasurementUnit",		BarcodeData.MeasurementUnit);
			FilterStructure.Insert("ExistingPackageLine",	CurrentDataExistingPackages.KeyExistingPackages);
			
			TSRowsArray = Object.Inventory.FindRows(FilterStructure);
			If TSRowsArray.Count() = 0 Then
				
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.ExistingPackageLine = CurrentDataExistingPackages.KeyExistingPackages;
				CalculateRowWeight(NewRow.GetID());
			Else
				
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateRowWeight(FoundString.GetID());
			EndIf;
			
			Modified = True;
		EndIf;
	EndDo;
	
	
	Return UnknownBarcodes;
	
EndFunction

&AtServerNoContext
Procedure GetDataByBarcodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CalculateItemsAtServer()
	CalculateQtyOfAddressesAndWeightOfContainer();
	UpdateAvailableItemsAtServer();
EndFunction

&AtServer
Function GetDataProductsOnChange(StructureData)
	
	MeasurementUnit = Common.ObjectAttributeValue(StructureData.Products, "MeasurementUnit");
	StructureData.Insert("MeasurementUnit", MeasurementUnit);
	CalculateRowWeight(StructureData.ID);
	Return StructureData;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	NewConditionalAppearance.Appearance.SetParameterValue("BackColor", WebColors.LightCoral);
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Greater;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("Object.ExistingPackages.QtyOfAddresses");
	Filter.RightValue = 1;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("ExistingPackages");
	
EndProcedure

&AtServer
Procedure SetAvailableItems()
	CurrentUser = UsersClientServer.CurrentUser();
	
	AskForQuantity = DriveReUse.GetValueByDefaultUser(CurrentUser, "AskForQuantity",False);
	
	If AskForQuantity Then 
		Items.TableAvailableItem.SelectionMode = TableSelectionMode.SingleRow;
		Items.Inventory.SelectionMode    = TableSelectionMode.SingleRow;;
	EndIf;
	
	If ValueIsFilled(WeightUOM) Then
		TitleText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Weight (%1)'; ru = 'Вес (%1)';pl = 'Waga (%1)';es_ES = 'Peso (%1)';es_CO = 'Peso (%1)';tr = 'Ağırlık (%1)';it = 'Peso (%1)';de = 'Gewicht (%1)'"), WeightUOM);  
		Items.ExistingPackagesWeight.Title = TitleText;
		Items.InventoryWeight.Title = TitleText;
		Items.TableAvailableItemWeight.Title = TitleText;
	EndIf;
		
EndProcedure

&AtServer
Procedure UpdateAvailableItemsAtServer()
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesOrder.Ref AS Ref
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&SalesOrdersRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SUM(SalesOrderInventory.Quantity) AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND ISNULL(UOM.Weight, 0) <> 0
	|			THEN UOM.Weight
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOM)
	|			THEN ProductsCatalog.Weight * UOM.Factor
	|		ELSE ISNULL(ProductsCatalog.Weight, 0)
	|	END AS Weight
	|INTO TT_SalesOrdersInventory
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|			LEFT JOIN Catalog.Products AS ProductsCatalog
	|			ON SalesOrderInventory.Products = ProductsCatalog.Ref
	|			LEFT JOIN Catalog.UOM AS UOM
	|			ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|		ON TT_SalesOrders.Ref = SalesOrderInventory.Ref
	|			AND (SalesOrderInventory.ProductsTypeInventory)
	|
	|GROUP BY
	|	SalesOrderInventory.Ref,
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.Batch,
	|	SalesOrderInventory.MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND ISNULL(UOM.Weight, 0) <> 0
	|			THEN UOM.Weight
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOM)
	|			THEN ProductsCatalog.Weight * UOM.Factor
	|		ELSE ISNULL(ProductsCatalog.Weight, 0)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PackedOrdersTurnovers.Products AS Products,
	|	PackedOrdersTurnovers.Characteristic AS Characteristic,
	|	PackedOrdersTurnovers.Batch AS Batch,
	|	PackedOrdersTurnovers.SalesOrder AS SalesOrder,
	|	PackedOrdersTurnovers.MeasurementUnit AS MeasurementUnit,
	|	SUM(PackedOrdersTurnovers.QuantityTurnover) AS QuantityTurnover
	|INTO TT_AccumPackedOrders
	|FROM
	|	AccumulationRegister.PackedOrders.Turnovers(, , Auto, ) AS PackedOrdersTurnovers
	|WHERE
	|	PackedOrdersTurnovers.Recorder <> &Recorder
	|
	|GROUP BY
	|	PackedOrdersTurnovers.Characteristic,
	|	PackedOrdersTurnovers.SalesOrder,
	|	PackedOrdersTurnovers.Products,
	|	PackedOrdersTurnovers.Batch,
	|	PackedOrdersTurnovers.MeasurementUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfDocument.Products AS Products,
	|	TableOfDocument.Characteristic AS Characteristic,
	|	TableOfDocument.Batch AS Batch,
	|	TableOfDocument.SalesOrder AS SalesOrder,
	|	TableOfDocument.Quantity AS Quantity,
	|	TableOfDocument.MeasurementUnit AS MeasurementUnit
	|INTO TT_TableOfDocument
	|FROM
	|	&TableOfDocument AS TableOfDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableOfDocument.Products AS Products,
	|	TT_TableOfDocument.Characteristic AS Characteristic,
	|	TT_TableOfDocument.Batch AS Batch,
	|	TT_TableOfDocument.SalesOrder AS SalesOrder,
	|	SUM(TT_TableOfDocument.Quantity) AS Quantity,
	|	TT_TableOfDocument.MeasurementUnit AS MeasurementUnit
	|INTO TT_TOfDoc
	|FROM
	|	TT_TableOfDocument AS TT_TableOfDocument
	|
	|GROUP BY
	|	TT_TableOfDocument.Products,
	|	TT_TableOfDocument.Batch,
	|	TT_TableOfDocument.SalesOrder,
	|	TT_TableOfDocument.Characteristic,
	|	TT_TableOfDocument.MeasurementUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrdersInventory.Ref AS SalesOrder,
	|	TT_SalesOrdersInventory.Products AS Products,
	|	TT_SalesOrdersInventory.Characteristic AS Characteristic,
	|	TT_SalesOrdersInventory.Batch AS Batch,
	|	TT_SalesOrdersInventory.MeasurementUnit AS MeasurementUnit,
	|	TT_SalesOrdersInventory.Quantity - ISNULL(TT_AccumPackedOrders.QuantityTurnover, 0) - ISNULL(TT_TOfDoc.Quantity, 0) AS Quantity,
	|	TT_SalesOrdersInventory.Weight * (TT_SalesOrdersInventory.Quantity - ISNULL(TT_AccumPackedOrders.QuantityTurnover, 0) - ISNULL(TT_TOfDoc.Quantity, 0)) AS Weight
	|INTO Result
	|FROM
	|	TT_SalesOrdersInventory AS TT_SalesOrdersInventory
	|		LEFT JOIN TT_AccumPackedOrders AS TT_AccumPackedOrders
	|		ON TT_SalesOrdersInventory.Products = TT_AccumPackedOrders.Products
	|			AND TT_SalesOrdersInventory.Characteristic = TT_AccumPackedOrders.Characteristic
	|			AND TT_SalesOrdersInventory.Batch = TT_AccumPackedOrders.Batch
	|			AND TT_SalesOrdersInventory.Ref = TT_AccumPackedOrders.SalesOrder
	|			AND TT_SalesOrdersInventory.MeasurementUnit = TT_AccumPackedOrders.MeasurementUnit
	|		LEFT JOIN TT_TOfDoc AS TT_TOfDoc
	|		ON TT_SalesOrdersInventory.Ref = TT_TOfDoc.SalesOrder
	|			AND TT_SalesOrdersInventory.Products = TT_TOfDoc.Products
	|			AND TT_SalesOrdersInventory.Characteristic = TT_TOfDoc.Characteristic
	|			AND TT_SalesOrdersInventory.Batch = TT_TOfDoc.Batch
	|			AND TT_SalesOrdersInventory.MeasurementUnit = TT_TOfDoc.MeasurementUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Result.SalesOrder AS SalesOrder,
	|	Result.Products AS Products,
	|	Result.Characteristic AS Characteristic,
	|	Result.Batch AS Batch,
	|	Result.MeasurementUnit AS MeasurementUnit,
	|	Result.Quantity AS Quantity,
	|	Result.Weight AS Weight
	|FROM
	|	Result AS Result
	|WHERE
	|	Result.Quantity > 0";
	Query.SetParameter("SalesOrdersRef", Object.SalesOrders.Unload().UnloadColumn("SalesOrder"));
	Query.SetParameter("Recorder", Object.Ref);
	Query.SetParameter("TableOfDocument", Object.Inventory.Unload());
	
	TableAvailealeItems = Query.Execute().Unload();
	
	TableAvailableItem.Load(TableAvailealeItems);
	
EndProcedure

&AtClient
Procedure AfterValueInput(Result, AdditionalParameters) Export
	
	If Not ValueIsFilled(Result) Then 
		Return;
	EndIf;
	
	AddProductIntoContainerInArray(
		AdditionalParameters.ArrayAvailableItems,
		AdditionalParameters.KeyExistingPackages,
		AdditionalParameters.ItemTable, Result);
	UpdateWeightOfPackages();
	CalculateItemsAtServer();

EndProcedure

&AtClient
Procedure AddProductIntoContainerInArray(ArrayAvailableItems, KeyExistingPackages, DataTable, Quantity = 0)
	
	If ArrayAvailableItems.Count() = 0 Then 
		CommonClientServer.MessageToUser(NStr("en = 'Choose product'; ru = 'Выберите номенклатуру';pl = 'Wybierz produkt';es_ES = 'Seleccione el producto';es_CO = 'Seleccione el producto';tr = 'Ürün seçin';it = 'Selezionare articolo';de = 'Produkt auswählen'"));
		Return;
	EndIf;
	
	For Each Row In ArrayAvailableItems Do
		
		NewRow = Object.Inventory.Add();
		DataRow = DataTable.FindByID(Row);
		FillPropertyValues(NewRow, DataRow);
		
		If Quantity <> 0 Then
			NewRow.Quantity = Quantity;
			CalculateRowWeight(NewRow.GetID());
		EndIf;
		
		NewRow.ExistingPackageLine = KeyExistingPackages;
		
	EndDo;

EndProcedure

&AtServer
Procedure CalculateQtyOfAddressesAndWeightOfContainer()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PackingSlipPackageContents.SalesOrder AS SalesOrder,
	|	PackingSlipPackageContents.ExistingPackageLine AS ExistingPackageLine
	|INTO TT_CalcAdress
	|FROM
	|	&Inventory AS PackingSlipPackageContents
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT TT_CalcAdress.SalesOrder.ShippingAddress) AS QtyOfAddresses,
	|	TT_CalcAdress.ExistingPackageLine AS ExistingPackageLine
	|FROM
	|	TT_CalcAdress AS TT_CalcAdress
	|
	|GROUP BY
	|	TT_CalcAdress.ExistingPackageLine";
	
	Query.SetParameter("Inventory",Object.Inventory.Unload());
	TV = Query.Execute().Unload();
	
	For Each Row In Object.ExistingPackages Do
		FoundRow = TV.Find(Row.KeyExistingPackages,"ExistingPackageLine");
		If FoundRow <> Undefined Then
			Row.QtyOfAddresses = FoundRow.QtyOfAddresses;
		EndIf;
		
		Row.WeightOfContainer = Common.ObjectAttributeValue(Row.ContainerType, "Weight");	
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ExistingPackagesContainerTypeOnChangeAtServer()
	
	CurrentRow = Items.ExistingPackages.CurrentRow;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Object.ExistingPackages.FindByID(CurrentRow);
	WeightOfContainer = Common.ObjectAttributeValue(CurrentData.ContainerType, "Weight");
	CurrentData.Weight = WeightOfContainer;
	CurrentData.WeightOfContainer = WeightOfContainer;
	
EndProcedure

&AtClient
Procedure SetFilterByPackageContents()
	CurrentData = Items.ExistingPackages.CurrentData;
	
	If CurrentData <> Undefined Then
		Items.Inventory.RowFilter = New FixedStructure("ExistingPackageLine", CurrentData.KeyExistingPackages);
	Else 
		Items.Inventory.RowFilter = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure EndDeleteConainer(Result, Parameters) Export
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;

	FindedRows = Object.Inventory.FindRows(New Structure("ExistingPackageLine", Parameters));

	For Each Row In FindedRows Do
		Object.Inventory.Delete(Row);
	EndDo;
	
	FindedRows = Object.ExistingPackages.FindRows(New Structure("KeyExistingPackages", Parameters));

	For Each Row In FindedRows Do
		Object.ExistingPackages.Delete(Row);
	EndDo;
	
	UpdateAvailableItemsAtServer();
	
EndProcedure

&AtServer
Procedure CalculateRowWeight(CurrentItem, IsInventory = True)
	
	If IsInventory Then
		Row = Object.Inventory.FindByID(CurrentItem);
	Else
		Row = TableAvailableItem.FindByID(CurrentItem);
	EndIf;
	
	Weight = 0;
	
	If TypeOf(Row.MeasurementUnit) = Type("CatalogRef.UOM")
		And ValueIsFilled(Row.MeasurementUnit.Weight) Then
		Weight = Common.ObjectAttributeValue(Row.MeasurementUnit, "Weight");
	ElsIf TypeOf(Row.MeasurementUnit) = Type("CatalogRef.UOM") Then
		Factor = Common.ObjectAttributeValue(Row.MeasurementUnit, "Factor");
		Weight = Common.ObjectAttributeValue(Row.Products, "Weight") * Factor;
	Else
		Weight = Common.ObjectAttributeValue(Row.Products, "Weight");
	EndIf;
	
	Row.Weight = Weight * Row.Quantity;
	
EndProcedure

&AtServer
Function GetAvaibleSalesOrders()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesOrder.Ref AS Ref
	|INTO TT_AvaibleOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|		INNER JOIN Catalog.SalesOrderStatuses AS SalesOrderStatuses
	|		ON SalesOrder.OrderState = SalesOrderStatuses.Ref
	|WHERE
	|	SalesOrder.Posted
	|	AND SalesOrderStatuses.OrderStatus <> VALUE(Enum.OrderStatuses.Completed)
	|	AND SalesOrder.StructuralUnitReserve = &Warehouse
	|	AND SalesOrder.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(SalesOrderInventory.Quantity) AS Quantity
	|INTO TT_AvaibleOrdersInventory
	|FROM
	|	TT_AvaibleOrders AS TT_AvaibleOrders
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON TT_AvaibleOrders.Ref = SalesOrderInventory.Ref
	|
	|GROUP BY
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.Batch,
	|	SalesOrderInventory.Ref,
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.MeasurementUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_AvaibleOrdersInventory.Ref AS Ref
	|FROM
	|	TT_AvaibleOrdersInventory AS TT_AvaibleOrdersInventory
	|		LEFT JOIN AccumulationRegister.PackedOrders.Turnovers(
	|				,
	|				,
	|				,
	|				SalesOrder IN
	|					(SELECT
	|						TT_AvaibleOrders.Ref AS Ref
	|					FROM
	|						TT_AvaibleOrders AS TT_AvaibleOrders)) AS PackedOrdersTurnovers
	|		ON TT_AvaibleOrdersInventory.Products = PackedOrdersTurnovers.Products
	|			AND TT_AvaibleOrdersInventory.Characteristic = PackedOrdersTurnovers.Characteristic
	|			AND TT_AvaibleOrdersInventory.Batch = PackedOrdersTurnovers.Batch
	|			AND TT_AvaibleOrdersInventory.MeasurementUnit = PackedOrdersTurnovers.MeasurementUnit
	|			AND TT_AvaibleOrdersInventory.Ref = PackedOrdersTurnovers.SalesOrder
	|WHERE
	|	TT_AvaibleOrdersInventory.Quantity - ISNULL(PackedOrdersTurnovers.QuantityTurnover, 0) > 0";
	
	Query.SetParameter("Company",	Object.Company);
	Query.SetParameter("Warehouse",	Object.StructuralUnit);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	FilterStrucure = New Structure;
	AvailableSalesOrders = New Array;	
	
	While Selection.Next() Do
		FilterStrucure.Insert("SalesOrder", Selection.Ref);
		If Object.SalesOrders.FindRows(FilterStrucure).Count() = 0 Then
			AvailableSalesOrders.Add(Selection.Ref);
		EndIf;
	EndDo;
	
	Return AvailableSalesOrders;
	
EndFunction

&AtClient
Procedure UpdateWeightOfPackages()

	For Each ExistingPackageRow In Object.ExistingPackages Do
		
		WeightOfItems = 0;
		FilterStructure = New Structure("ExistingPackageLine", ExistingPackageRow.KeyExistingPackages);
		ArrayOfRows = Object.Inventory.FindRows(FilterStructure);
		
		For Each Row In ArrayOfRows Do
			WeightOfItems = WeightOfItems + Row.Weight;
		EndDo;
		
		ExistingPackageRow.Weight = ExistingPackageRow.WeightOfContainer + WeightOfItems;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure GenerateGoodsIssueEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);

	Write(WriteParameters);
	 
	CreateGoodsIssueClient();
	
EndProcedure

&AtClient
Procedure CreateGoodsIssueClient()
	
	OrdersArray = New Array;
	
	For Each RowOrder In Object.SalesOrders Do
		If  OrdersArray.Find(RowOrder.SalesOrder) <> Undefined Then
			Continue;
		EndIf;
		
		OrdersArray.Add(RowOrder.SalesOrder);
	EndDo;
	
	AddEmptyShippingAddress = GetAddEmptyShippingAddress();
	
	BasisStructure = New Structure();
	BasisStructure.Insert("PackingSlip", Object.Ref);
	
	If OrdersArray.Count() = 1 Then
		
		BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
		OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
		
	Else
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Company", Object.Company);
		AdditionalParameters.Insert("AddEmptyShippingAddress", AddEmptyShippingAddress);

		DataStructure = DriveServer.CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(OrdersArray, AdditionalParameters);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge üst bilgilerinde farklı %1 değerlerine sahip. Bunları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			BasisStructure.Insert("OrdersGroups", DataStructure.OrdersGroups);
			ShowQueryBox(
				New NotifyDescription("CreateGoodsIssue",
					ThisObject,
					BasisStructure),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateGoodsIssue(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("PackingSlip", Object.Ref);
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

&AtClient
Procedure CreateSalesInvoicesClient()

	OrdersArray = New Array;
	
	For Each RowOrder In Object.SalesOrders Do
		If  OrdersArray.Find(RowOrder.SalesOrder) <> Undefined Then
			Continue;
		EndIf;
		
		OrdersArray.Add(RowOrder.SalesOrder);
	EndDo;
	
	AddEmptyShippingAddress = GetAddEmptyShippingAddress();
	
	BasisStructure = New Structure();
	BasisStructure.Insert("PackingSlip", Object.Ref);
	
	If OrdersArray.Count() = 1 Then
		
		BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
		OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
		
	Else
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Company", Object.Company);
		AdditionalParameters.Insert("AddEmptyShippingAddress", AddEmptyShippingAddress);
		
		BasisStructure = New Structure();
		BasisStructure.Insert("PackingSlip", Object.Ref);
		
		DataStructure = DriveServer.CheckOrdersKeyAttributes(OrdersArray, AdditionalParameters);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge üst bilgilerinde farklı %1 değerlerine sahip. Bunları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			BasisStructure.Insert("OrdersGroups", DataStructure.OrdersGroups);
			ShowQueryBox(
				New NotifyDescription("CreateSalesInvoices", 
					ThisObject,
					BasisStructure),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure GenerateSalesInvoiceEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);

	Write(WriteParameters);
	 
	CreateSalesInvoicesClient();
		
EndProcedure

&AtClient
Procedure CreateSalesInvoices(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("PackingSlip", Object.Ref);
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

&AtClient
Procedure CreateJobClient()

	OpenForm("BusinessProcess.Job.ObjectForm", New Structure("Basis", Object.Ref));
			
EndProcedure

&AtClient
Procedure GenerateJobEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);

	Write(WriteParameters);
	 
	CreateJobClient();
		
EndProcedure

&AtClient
Function GetAddEmptyShippingAddress()

	AddEmptyShippingAddress	= False;
	
	For Each Row In Object.Inventory Do
		If Row.SalesOrder = PredefinedValue("Document.SalesOrder.EmptyRef") Then
			AddEmptyShippingAddress	= True;
			Break;
		EndIf;
	EndDo;
	
	Return AddEmptyShippingAddress; 

EndFunction

&AtServer
Procedure CompanyOnChangeAtServer()
	ProcessingCompanyVATNumbers(False);
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure DateOnChangeAtServer()
	ProcessingCompanyVATNumbers();
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

#Region SerialNumbers

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

#EndRegion

#EndRegion
