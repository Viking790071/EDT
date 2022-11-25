
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	If Object.OrderState = CompletedStatus Then
		Items.FormPost.Enabled			= False;
		Items.FormPostAndClose.Enabled	= False;
		Items.FormWrite.Enabled			= False;
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
	
	If Object.Ref.IsEmpty() And ValueIsFilled(Parameters.Basis) Then
		
		If TypeOf(Parameters.Basis) = Type("DocumentRef.WorkOrder") Then
			
			AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(
				CurrentSessionDate(),
				Common.ObjectAttributeValue(Parameters.Basis, "Company"));
			
			If AccountingPolicy.PostExpensesByWorkOrder Then
				
				MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Inventory consumed in %1 will charge to expenses automatically on work order completion'; ru = 'ТМЦ, потребленные в %1, будут автоматически отнесены на расходы после выполнения заказа-наряда';pl = 'Zapasy zużyte w %1 zostaną naliczone do rozchodów automatycznie po zakończeniu zlecenia pracy';es_ES = 'El inventario consumido %1se cargará a los gastos automáticamente al finalizar la orden de trabajo';es_CO = 'El inventario consumido %1se cargará a los gastos automáticamente al finalizar la orden de trabajo';tr = '%1 için kullanılan envanter, iş emri tamamlandığında masraflara otomatik yansıyacak';it = 'Le scorte consumate in %1 saranno addebitate automaticamente alle spese al completamento della commessa';de = 'Bestand verbraucht in %1 wird nach der Erfüllung des Arbeitsauftrags zu den Ausgaben automatisch zugeordnet'"),
					Parameters.Basis);
					
				CommonClientServer.MessageToUser(
					MessageToUserText,
					,
					,
					,
					Cancel);
					
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
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
	
	If Not ValueIsFilled(Object.ShipmentDate) Then
		Object.ShipmentDate = DocumentDate;
	EndIf;
	
	Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
	Object.ShipmentDatePosition = Enums.AttributeStationing.InHeader;

	If Not ValueIsFilled(Object.ShipmentDate) Then
		Object.ShipmentDate = DocumentDate;
	EndIf;
	
	InProcessStatus = Constants.TransferOrdersInProgressStatus.Get();
	CompletedStatus = Constants.StateCompletedTransferOrders.Get();
	
	If GetFunctionalOption("UseTransferOrderStatuses") Then
		
		Items.Status.Visible = False;
		
	Else
		
		Items.OrderState.Visible = False;
		
		StatusesStructure = Documents.TransferOrder.GetTransferOrderStringStatuses();
		
		For Each Item In StatusesStructure Do
			Items.Status.ChoiceList.Add(Item.Key, Item.Value);
		EndDo;
		
		ResetStatus();
		
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail;
	IsRetailEarningAccounting = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
		Or Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
		
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	SetVisibleAndEnabled();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.InventoryTransfer.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	// End Peripherals
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	Items.InventoryDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
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
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	FormManagement();
	
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

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("SalesOrderPositionInTransferOrder", 	Object.SalesOrderPosition);
	ParametersStructure.Insert("WereMadeChanges", 							False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInTransferOrder;
		SetVisibleAndEnabled();
		
		Modified = True;
		
	EndIf;

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
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
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Source", Object.StructuralUnit);
	
	StructureData = GetDataStructuralUnitOnChange(StructureData);
	
	If Not ValueIsFilled(Object.StructuralUnitPayee) Then
		Object.StructuralUnitPayee = StructureData.StructuralUnitPayee;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the StructuralUnitRecipient input field.
//
&AtClient
Procedure StructuralUnitPayeeOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Recipient", Object.StructuralUnitPayee);
	
	StructureData = GetDataStructuralUnitPayeeOnChange(StructureData);
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Object.StructuralUnit = StructureData.StructuralUnit;
	EndIf;

EndProcedure

&AtClient
Procedure StructuralUnitChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If SelectedValue = Object.StructuralUnitPayee Then
		
		MessageString = Nstr("en = 'The source warehouse and the destination warehouse should be different. Please, select another one.'; ru = 'Склады выдачи и получения должны различаться. Выберите другой склад.';pl = 'Źródłowy magazyn i magazyn przeznaczenia powinni różnić się. Proszę wybrać inny magazyn.';es_ES = 'El almacén de origen y el almacén de destino deben ser diferentes. Por favor, seleccione otro.';es_CO = 'El almacén de origen y el almacén de destino deben ser diferentes. Por favor, seleccione otro.';tr = 'Kaynak depo ve varış deposu farklı olmalıdır. Lütfen başka bir tane seçin.';it = 'Il magazzino di fonte e quello di destinazione dovrebbero essere diversi. Si prega di selezionarne un altro.';de = 'Das Quell- und das Ziellager sollten unterschiedlich sein. Bitte wählen Sie ein anderes aus.'");
		CommonClientServer.MessageToUser(MessageString);
		StandardProcessing = False;
		Object.StructuralUnit = Undefined;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StructuralUnitPayeeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If SelectedValue = Object.StructuralUnit Then
		
		MessageString = Nstr("en = 'The source warehouse and the destination warehouse should be different. Please, select another one.'; ru = 'Склады выдачи и получения должны различаться. Выберите другой склад.';pl = 'Źródłowy magazyn i magazyn przeznaczenia powinni różnić się. Proszę wybrać inny magazyn.';es_ES = 'El almacén de origen y el almacén de destino deben ser diferentes. Por favor, seleccione otro.';es_CO = 'El almacén de origen y el almacén de destino deben ser diferentes. Por favor, seleccione otro.';tr = 'Kaynak depo ve varış deposu farklı olmalıdır. Lütfen başka bir tane seçin.';it = 'Il magazzino di fonte e quello di destinazione dovrebbero essere diversi. Si prega di selezionarne un altro.';de = 'Das Quell- und das Ziellager sollten unterschiedlich sein. Bitte wählen Sie ein anderes aus.'");
		CommonClientServer.MessageToUser(MessageString);
		StandardProcessing = False;
		Object.StructuralUnitPayee = Undefined;

	EndIf;
	
EndProcedure

&AtClient
Procedure ShipmentDateStartChoice(Item, ChoiceData, StandardProcessing)
	ShipmentDate = Object.ShipmentDate;
EndProcedure


// Procedure - Opening event handler of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - Opening event handler of the StructuralUnitRecipient input field.
//
&AtClient
Procedure StructuralUnitPayeeOpening(Item, StandardProcessing)
	
	If Items.StructuralUnitPayee.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnitPayee) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
		
EndProcedure

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
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure OrderStateStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceData = GetTransferOrderStates();
	
EndProcedure

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"TransferOrder.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	
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

#EndRegion

#Region FormTableItemsEventHandlersInventory
 

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
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
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If Not NewRow Or Copy Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		StatusIsComplete = (Object.OrderState = CompletedStatus);
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory", , StatusIsComplete);
	EndIf;
	
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
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// FillInByBalance command event handler procedure
//
&AtClient
Procedure FillByBalanceAtWarehouse(Command)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		QuestionText = NStr("en = 'The products on the Inventory tab will be replaced with the products from the available stock. The base document will be cleared.
			|Do you want to continue?'; 
			|ru = 'Номенклатура на вкладке ""ТМЦ"" будут заменены номенклатурой из свободных остатков товара. Документ-основание будет очищен.
			|Продолжить?';
			|pl = 'Produkty na karcie Zapasy zostaną zastąpione produktami z dostępnych zapasów. Dokument źródłowy zostanie wyczyszczony.
			|Czy chcesz kontynuować?';
			|es_ES = 'Los productos de la pestaña Inventario serán reemplazados por los productos del stock disponible. Se borrará el documento base.
			|¿Quiere continuar?';
			|es_CO = 'Los productos de la pestaña Inventario serán reemplazados por los productos del stock disponible. Se borrará el documento base.
			|¿Quiere continuar?';
			|tr = 'Stok sekmesindeki ürünler mevcut stoktan ürünlerle değiştirilecek. Temel belge silinecek.
			|Devam etmek istiyor musunuz?';
			|it = 'Gli articoli nella scheda Inventario sarannosostiuiti con gli articoli dalle scorte disponibili. Il documento base sarà cancellato.
			| Continuare?';
			|de = 'Die Produkte auf der Registerkarte „Bestand“ werden durch die Produkte aus dem verfügbaren Bestand ersetzt. Das Basisdokument wird gelöscht.
			|Möchten Sie fortsetzen?'");
		ShowQueryBox(New NotifyDescription("FillByBalanceOnWarehouseEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillByBalanceOnWarehouseEndFragment();
EndProcedure

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Text = NStr("en = 'The ""Inventory"" section is not filled in.'; ru = 'Табличная часть ""Запасы"" не заполнена.';pl = 'Nie wypełniono sekcji ""Zapasy"".';es_ES = 'La sección ""Inventario"" no está rellenada.';es_CO = 'La sección ""Inventario"" no está rellenada.';tr = '""Stok"" bölümü doldurulmadı.';it = 'La sezione ""Scorte"" non è compilata.';de = 'Der Abschnitt ""Bestand"" ist nicht ausgefüllt.'");
		CommonClientServer.MessageToUser(Text);
		Return;
	EndIf;
	
	FillColumnReserveByReservesAtServer();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Text = NStr("en = 'The ""Inventory"" section is not filled in.'; ru = 'Табличная часть ""Запасы"" не заполнена.';pl = 'Nie wypełniono sekcji ""Zapasy"".';es_ES = 'La sección ""Inventario"" no está rellenada.';es_CO = 'La sección ""Inventario"" no está rellenada.';tr = '""Stok"" bölümü doldurulmadı.';it = 'La sezione ""Scorte"" non è compilata.';de = 'Der Abschnitt ""Bestand"" ist nicht ausgefüllt.'");
		CommonClientServer.MessageToUser(Text);
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the transfer order?'; ru = 'Заказ на перемещение будет полностью перезаполнен по ""Основанию"". Продолжить?';pl = 'Czy chcesz ponownie wypełnić zamówienie przeniesienia?';es_ES = '¿Quiere volver a rellenar la orden de transferencia?';es_CO = '¿Quiere volver a rellenar la orden de transferencia?';tr = 'Transfer emrini yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare l''ordine di trasferimento?';de = 'Möchten Sie den Transportauftrag auffüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.BasisDocument);
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

EndProcedure

// End Peripherals


// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'transfer order'; ru = 'заказ на перемещение';pl = 'zamówienie przeniesienia';es_ES = 'orden de transferencia';es_CO = 'orden de transferencia';tr = 'transfer emri';it = 'ordine trasferimento';de = 'Transportauftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
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

&AtClient
Procedure InventoryCopyRows(Command)
	CopyRowsTabularPart("Inventory"); 
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	PasteRowsTabularPart("Inventory"); 
EndProcedure

#EndRegion

#Region Private

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
Procedure Attachable_FillBatchesByFEFO_QuantityOnChange(TableName, RowData) Export
	
	RowData.Reserve = 0;
	
EndProcedure

&AtClient
Function Attachable_FillByFEFOData(TableName, ShowMessages) Export
	
	Return FillByFEFOData(ShowMessages);
	
EndFunction

&AtServer
Function FillByFEFOData(ShowMessages)
	
	Params = New Structure;
	Params.Insert("CurrentRow", Object.Inventory.FindByID(Items.Inventory.CurrentRow));
	Params.Insert("StructuralUnit", Object.StructuralUnit);
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	If Object.OperationKind = Enums.OperationTypesTransferOrder.Transfer Then
		Params.Insert("OwnershipType", Undefined);
	Else
		Params.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	EndIf;
	If Object.SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		Params.Insert("SalesOrder", Object.SalesOrder);
	Else
		Params.Insert("SalesOrder", "SalesOrder");
	EndIf;
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 			TabName);
	StructureData.Insert("Object",				Form.Object);
	StructureData.Insert("Batch",				TabRow.Batch);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
		
		StructureData.Insert("InventoryGLAccount",		TabRow.InventoryGLAccount);
		StructureData.Insert("InventoryReceivedGLAccount",	TabRow.InventoryReceivedGLAccount);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
	
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

// Procedure sets availability of the form items.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	FunctionalOptionOrderTransferInHeader = (Object.SalesOrderPosition = Enums.AttributeStationing.InHeader);
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
	NewArray.Add(Enums.BusinessUnitsTypes.Retail);
	NewArray.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
	If Constants.UseProductionSubsystem.Get() Then
		NewArray.Add(Enums.BusinessUnitsTypes.Department);
	EndIf;
	ArrayWarehouseSubdepartmentRetail = New FixedArray(NewArray);
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Department);
	ArrayUnit = New FixedArray(NewArray);
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
	ArrayWarehouse = New FixedArray(NewArray);
	
	If Object.OperationKind = Enums.OperationTypesTransferOrder.Transfer Then
		
		Items.InventoryBusinessLine.Visible = False;
		Items.SalesOrder.Visible = False;
		Items.Inventory.ChildItems.InventorySalesOrder.Visible = False;
		Items.InventoryPick.Visible = True;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouseSubdepartmentRetail);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouseSubdepartmentRetail);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
		EndIf;
		
		Items.StructuralUnit.Visible = True;
		Items.StructuralUnitPayee.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesTransferOrder.WriteOffToExpenses Then
		
		Items.InventoryBusinessLine.Visible = GetLinesOfBusinessVisible(Object.OperationKind);
		Items.SalesOrder.Visible = FunctionalOptionOrderTransferInHeader;
		Items.Inventory.ChildItems.InventorySalesOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		Items.Inventory.ChildItems.InventoryReserve.Visible = True;
		Items.InventoryChangeReserve.Visible = True;
		Items.InventoryPick.Visible = True;
		ReservationUsed = True;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnit.Visible = False;
			
		Else	
			
			Items.StructuralUnit.Visible = True;
			
		EndIf;
		
		If Not Constants.UseSeveralDepartments.Get() Then
			
			Items.StructuralUnitPayee.Visible = False;
			
		Else
			
			Items.StructuralUnitPayee.Visible = True;
			
		EndIf;
		
	Else
		
		Items.StructuralUnit.Visible = True;
		Items.StructuralUnitPayee.Visible = True;
		
	EndIf;
	
	Items.InventoryBusinessLine.Visible = GetLinesOfBusinessVisible(Object.OperationKind);
	

EndProcedure

&AtServer
// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.UseProductionSubsystem.Get() Then
		
		// Setting the method of Business unit selection depending on FO.
		If Not Constants.UseSeveralDepartments.Get()
			AND Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnit.ListChoiceMode = True;
			Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			
			Items.StructuralUnitPayee.ListChoiceMode = True;
			Items.StructuralUnitPayee.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			Items.StructuralUnitPayee.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			
		EndIf;
		
	EndIf;
	
	If Constants.UseProductionSubsystem.Get()
		OR Constants.UseSeveralWarehouses.Get() Then
		
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesTransferOrder.Transfer);
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		
		Object.OperationKind = Enums.OperationTypesTransferOrder.WriteOffToExpenses;
		
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesTransferOrder.WriteOffToExpenses);
	
EndProcedure

&AtServer
Procedure ResetStatus()
	
	If Not GetFunctionalOption("UseTransferOrderStatuses") Then
		
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
Procedure FormManagement()
	
	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	If GetAccessRightForDocumentPosting() Then
		Items.FormPost.Enabled			= Not (StatusIsComplete And Not Modified);
		Items.FormPostAndClose.Enabled	= Not (StatusIsComplete And Not Modified);
	EndIf;
	
	Items.FormWrite.Enabled				= Not (StatusIsComplete And Not Modified);
	Items.FormCreateBasedOn.Enabled		= Not StatusIsComplete;
	Items.InventoryCommandBar.Enabled	= Not StatusIsComplete;
	Items.FillByBasis.Enabled			= Not StatusIsComplete;
	Items.StructuralUnit.ReadOnly		= StatusIsComplete;
	Items.StructuralUnitPayee.ReadOnly	= StatusIsComplete;
	Items.GroupBasisDocument.ReadOnly	= StatusIsComplete;
	Items.SalesOrder.ReadOnly			= StatusIsComplete;
	Items.RightColumn.ReadOnly			= StatusIsComplete;
	Items.GroupPages.ReadOnly			= StatusIsComplete;
	
EndProcedure

&AtServerNoContext
Function GetAccessRightForDocumentPosting()
	
	Return AccessRight("Posting", Metadata.Documents.TransferOrder);
	
EndFunction

&AtServerNoContext
Function GetTransferOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TransferOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.TransferOrderStatuses AS TransferOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON TransferOrderStatuses.OrderStatus = OrderStatuses.Ref
	|
	|ORDER BY
	|	OrderStatuses.Order";
	
	Selection = Query.Execute().Select();
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Status);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

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

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	Modified = True;
	
EndProcedure

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	ProductStructure = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, BusinessLine"); 
	StructureData.Insert("BusinessLine", ProductStructure.BusinessLine);
	StructureData.Insert("MeasurementUnit", ProductStructure.MeasurementUnit);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Shows the flag showing the activity direction visible.
//
&AtServerNoContext
Function GetLinesOfBusinessVisible(OperationKind)
	
	Return OperationKind = PredefinedValue("Enum.OperationTypesTransferOrder.WriteOffToExpenses")
					   AND Constants.UseSeveralLinesOfBusiness.Get() = True;
	
EndFunction

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitOnChange(StructureData)
	
	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail;
	IsRetailEarningAccounting = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
						  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	
	If StructureData.OperationKind = Enums.OperationTypesTransferOrder.Transfer Then
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.TransferRecipient);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", StructureData.Source.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting);
		
		FunctionalOptionOrderTransferInHeader = Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		 OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
			
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesTransferOrder.WriteOffToExpenses Then	
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.WriteOffToExpensesRecipient);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Receives the data set from server for the StructuralUnitReceiverOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitPayeeOnChange(StructureData)

	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail;
	IsRetailEarningAccounting = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
						  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	
	If StructureData.OperationKind = Enums.OperationTypesTransferOrder.Transfer Then
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.TransferSource);
				
		FunctionalOptionOrderTransferInHeader = Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 	 OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
			
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
			
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesTransferOrder.WriteOffToExpenses Then	
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.WriteOffToExpensesSource);
		
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	Return StructureData;
	
EndFunction

// The procedure of processing the document operation kind change.
//
&AtServer
Procedure ProcessOperationKindChange()
	
	If ValueIsFilled(Object.OperationKind)
		AND Not Object.OperationKind = Enums.OperationTypesTransferOrder.Transfer Then
		
		User = Users.CurrentUser();
		
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
		MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
		
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
		MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		
		If Object.OperationKind = Enums.OperationTypesTransferOrder.WriteOffToExpenses Then
			
			If Not Constants.UseSeveralWarehouses.Get() Then
				
				Object.StructuralUnit = MainWarehouse;
				
			EndIf;
			
			If Not Constants.UseSeveralDepartments.Get() Then
				
				Object.StructuralUnitPayee = MainDepartment;
				
			EndIf;
			
			If (Common.ObjectAttributeValue(Object.StructuralUnit, "StructuralUnitType")
					<> Enums.BusinessUnitsTypes.Warehouse) Then
				Object.StructuralUnit = Catalogs.BusinessUnits.EmptyRef();
			EndIf;
			
			If (Common.ObjectAttributeValue(Object.StructuralUnitPayee, "StructuralUnitType")
					<> Enums.BusinessUnitsTypes.Department) Then
				Object.StructuralUnitPayee = Catalogs.BusinessUnits.EmptyRef();
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	SetVisibleAndEnabled();
	
EndProcedure

#Region Peripherals

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
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "InventoryTransfer");
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
	StructureData.Insert("Object", Object);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			
			StructureRows = New Structure;
			StructureRows.Insert("Products", BarcodeData.Products);
			StructureRows.Insert("Characteristic", BarcodeData.Characteristic);
			StructureRows.Insert("Batch", BarcodeData.Batch);
			StructureRows.Insert("MeasurementUnit", BarcodeData.MeasurementUnit);
			
			TSRowsArray = Object.Inventory.FindRows(StructureRows);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			
			Modified = True;
			
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
		
		MessageString = StringFunctionsClientServer.SubstituteParametersToString("en = 'Barcode data is not found: %1; quantity: %2'; ru = 'Данные по штрихкоду не найдены: %1; количество: %2';pl = 'Nie znaleziono danych kodu kreskowego: %1; ilość: %2';es_ES = 'Datos del código de barras no encontrados: %1; cantidad: %2';es_CO = 'Datos del código de barras no encontrados: %1; cantidad: %2';tr = 'Barkod verisi bulunamadı: %1; miktar: %2';it = 'Dati del codice a barre non trovati: %1; quantità: %2';de = 'Barcode-Daten wurden nicht gefunden: %1; Menge: %2'", CurUndefinedBarcode.Barcode, CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

#EndRegion

// The procedure fills in column Reserve by reserves for the order.
//
&AtServer
Procedure FillInventoryByWarehouseBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillInventoryByInventoryBalances();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
EndProcedure

// The procedure fills in column Reserve by reserves for the order.
//
&AtServer
Procedure FillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
EndProcedure

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

#Region WorkWithSelection

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	If UseDefaultTypeOfAccounting Then
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
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
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
Procedure FillByBalanceOnWarehouseEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillByBalanceOnWarehouseEndFragment();

EndProcedure

&AtClient
Procedure FillByBalanceOnWarehouseEndFragment()
    
    FillInventoryByWarehouseBalancesAtServer();

EndProcedure

#EndRegion


#Region CopyPasteRows

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName],Items[TabularPartName].CurrentData) Then
		
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
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtServer
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructureData = New Structure;
		StructureData.Insert("Products", Row.Products);
		StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		
		AddTabRowDataToStructure(ThisObject, TabularPartName, StructureData, Row);
		StructureData = GetDataProductsOnChange(StructureData); 
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructureData.MeasurementUnit;
		EndIf;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion