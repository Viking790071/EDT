
#Region Variables

&AtClient
Var ThisIsNewRow;

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
	
	OperationKind = Object.OperationKind;
	BasisDocument = Object.BasisDocument;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	UseByProductsAccounting = True;
	
	SetVisibleAndEnabled(True);
	SetModeAndChoiceList();
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Products");
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Disposals");
	
	AllocationType = Number(Object.ManualAllocation);
	SetAllocationItemsAvailability();
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(
		Metadata.Documents.Production.TabularSections.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// Peripherals.
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList(
		"ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	AccountingPrice = InformationRegisters.AccountingPolicy.GetAccountingPolicy(
		?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()),
		Object.Company).AccountingPrice;
		
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
		
	WorkWithForm.SetReadOnlyForTableColumn(Items.WorksInProgressWorkInProgress, True);
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject, "Products");
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject);
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetWIPChoiceParameter();
	
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
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	ElsIf ChoiceSource.FormName = "CommonForm.InventoryReservation" Then
		EditReservationProcessingAtClient(SelectedValue.TempStorageInventoryReservationAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals" And IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				// Get a barcode from the basic data
				Data.Add(New Structure("Barcode, Quantity, CostPercentage", Parameter[0], 1, 1));
			Else
				// Get a barcode from the additional data
				Data.Add(New Structure("Barcode, Quantity, CostPercentage", Parameter[1][1], 1, 1));
			EndIf;
			
			BarcodesReceived(Data);
			
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "SerialNumbersSelection"
		And ValueIsFilled(Parameter) 
		// Form owner checkup
		And Source <> New UUID("00000000-0000-0000-0000-000000000000")
		And Source = UUID Then
		
		If Items.Pages.CurrentPage = Items.TSProducts Then
			GetProductsSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		Else
			GetSerialNumbersInventoryFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		EndIf;
		
	EndIf;
	
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
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
	
	EndIf;
	
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
	
	If ValueIsFilled(Object.BasisDocument) Then
		Notify("Record_Production", Object.Ref);
		Notify("NotificationSubcontractingServicesDocumentsChange");
	EndIf;
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	AccountingPrice = StructureData.AccountingPrice;
	RefillByProductsPrices();

EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	If ValueIsFilled(Object.BasisDocument) Then
		
		ProductionOrderOperationType = Object.OperationKind;
		If ValueIsFilled(Object.OperationKind) Then
			ProductionOrderOperationType = OperationTypeBasedOnProductionOrder(Object.BasisDocument);
		EndIf;
		
		If ProductionOrderOperationType <> Object.OperationKind Then
			AdditionalParameters = New Structure("ProductionOrderOperationType", ProductionOrderOperationType);
			ShowQueryBox(New NotifyDescription("OperationTypeOnChangeEnd", ThisObject, AdditionalParameters),
				NStr("en = 'The Production order process type differs from the process type of this document. Do you want to change the document process type?'; ru = 'Тип процесса заказа на производство отличается от типа процесса этого документа. Изменить тип процесса документа?';pl = 'Typ procesu Zlecenia produkcyjnego różni się od typu procesu tego dokumentu. Czy chcesz zmienić typ procesu dokumentu?';es_ES = 'El tipo de proceso de la orden de producción difiere del tipo de proceso de este documento. ¿Desea cambiar el tipo de proceso del documento?';es_CO = 'El tipo de proceso de la orden de producción difiere del tipo de proceso de este documento. ¿Desea cambiar el tipo de proceso del documento?';tr = 'Üretim emrinin süreç türü bu belgenin süreç türünden farklı. Belgenin süreç türünü değiştirmek ister misiniz?';it = 'Il tipo di processo dell''Ordine di produzione differisce dal tipo di processo di questo documento. Modificare il tipo di processo del documento?';de = 'Der Prozesstyp des Produktionsauftrags weicht von dem Prozesstyp dieses Dokuments ab. Möchten Sie den Dokumentenprozesstyp ändern?'"),
				QuestionDialogMode.YesNo);
		Else
			BasisDocument = Object.BasisDocument;
		EndIf;
		
	Else
		
		BasisDocument = Object.BasisDocument;
		
	EndIf;
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	SetWIPChoiceParameter();
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	OperationKindOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure OperationKindOnChangeAtClient()
	
	AllocationType = Number(Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.ConvertFromWIP"));
	Object.ManualAllocation = Boolean(AllocationType);
	SetAllocationItemsAvailability();
	
	OperationKindOnChangeAtServer();
	
	If OperationKind <> Object.OperationKind Then
		
		// cleaning BOM column in Products
		For Each ProductsLine In Object.Products Do
			
			ProductsLine.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef");
			
		EndDo;
		
		OperationKind = Object.OperationKind;
		
		Object.Reservation.Clear();
		
	EndIf;
	
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
Procedure StructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnit) Then
	
		StructureData = New Structure();
		StructureData.Insert("Department", Object.StructuralUnit);
		
		StructureData = GetDataStructuralUnitOnChange(StructureData);
		
		If ValueIsFilled(StructureData.ProductsStructuralUnit) Then
			
			Object.ProductsStructuralUnit = StructureData.ProductsStructuralUnit;
			Object.ProductsCell = StructureData.ProductsCell;
			
		ElsIf Not ValueIsFilled(Object.ProductsStructuralUnit) Then
			
			Object.ProductsStructuralUnit = Object.StructuralUnit;
			Object.ProductsCell = Object.Cell;
			
		EndIf;
		
		If ValueIsFilled(StructureData.InventoryStructuralUnit) Then
			
			Object.InventoryStructuralUnit = StructureData.InventoryStructuralUnit;
			Object.CellInventory = StructureData.CellInventory;
			
		ElsIf Not ValueIsFilled(Object.InventoryStructuralUnit) Then
			
			Object.InventoryStructuralUnit = Object.StructuralUnit;
			Object.CellInventory = Object.Cell;
			
		EndIf;
		
		If ValueIsFilled(StructureData.DisposalsStructuralUnit) Then
			
			Object.DisposalsStructuralUnit = StructureData.DisposalsStructuralUnit;
			Object.DisposalsCell = StructureData.DisposalsCell;
			
		ElsIf Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
			
			Object.DisposalsStructuralUnit = Object.StructuralUnit;
			Object.DisposalsCell = Object.Cell;
			
		EndIf;
		
	Else
		
		Items.Cell.Enabled = False;
		
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
Procedure CellOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("StructuralUnit", Object.StructuralUnit);
	StructureData.Insert("Cell", Object.Cell);
	StructureData.Insert("ProductsStructuralUnit", Object.ProductsStructuralUnit);
	StructureData.Insert("ProductsCell", Object.ProductsCell);
	StructureData.Insert("InventoryStructuralUnit", Object.InventoryStructuralUnit);
	StructureData.Insert("CellInventory", Object.CellInventory);
	StructureData.Insert("DisposalsStructuralUnit", Object.DisposalsStructuralUnit);
	StructureData.Insert("DisposalsCell", Object.DisposalsCell);
	
	StructureData = GetDataCellOnChange(StructureData);
	
	If StructureData.Property("NewGoodsCell") Then
		Object.ProductsCell = StructureData.NewGoodsCell;
	EndIf;
	
	If StructureData.Property("NewCellInventory") Then
		Object.CellInventory = StructureData.NewCellInventory;
	EndIf;
	
	If StructureData.Property("NewCellWastes") Then
		Object.DisposalsCell = StructureData.NewCellWastes;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsStructuralUnitAssemblingOnChange(Item)
	
	Items.ProductsCellAssembling.Enabled = ValueIsFilled(Object.ProductsStructuralUnit);
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	False);
		ParametersStructure.Insert("FillDisposals",	False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StructuralUnitOfProductAssemblyOpening(Item, StandardProcessing)
	
	If Items.ProductsStructuralUnitAssembling.ListChoiceMode
		And Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsStructuralUnitDisassemblingOnChange(Item)
	
	Items.ProductsCellDisassembling.Enabled = ValueIsFilled(Object.InventoryStructuralUnit);
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	False);
		ParametersStructure.Insert("FillDisposals",	False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsStructuralUnitDisassemblingOpen(Item, StandardProcessing)
	
	If Items.ProductsStructuralUnitDisassembling.ListChoiceMode
		And Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryStructuralUnitAssemblingOnChange(Item)
	
	Items.CellInventoryAssembling.Enabled = ValueIsFilled(Object.InventoryStructuralUnit);
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	False);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryStructuralUnitInAssemblingOpen(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitAssembling.ListChoiceMode
		And Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryStructuralUnitDisassemblyOnChange(Item)
	
	Items.CellInventoryDisassembling.Enabled = ValueIsFilled(Object.ProductsStructuralUnit);
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	False);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryStructuralUnitDisassemblyOpening(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitDisassembling.ListChoiceMode
		And Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsStructuralUnitOnChange(Item)
	
	Items.DisposalsCell.Enabled = ValueIsFilled(Object.DisposalsStructuralUnit);
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	False);
		ParametersStructure.Insert("FillInventory",	False);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;

EndProcedure

&AtClient
Procedure DisposalsStructuralUnitOpening(Item, StandardProcessing)
	
	If Items.DisposalsStructuralUnit.ListChoiceMode
		And Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AllocationTypeOnChange(Item)
	Object.ManualAllocation = Boolean(AllocationType);
	SetAllocationItemsAvailability();
EndProcedure

&AtClient
Procedure Attachable_ReadOnlyFieldStartChoice(Item, ChoiceData, StandardProcessing)
	If Not Item.TextEdit Then
		StandardProcessing = False;
	EndIf;
EndProcedure

#EndRegion

#Region ProductsFormTableItemsEventHandlers

&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Products", StructureData);
	StructureData = GetDataProductsOnChange(StructureData, Object.Date, Object.OperationKind);
	
	If Not ValueIsFilled(StructureData.Specification)
		And StructureData.ShowSpecificationMessage Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot match a bill of materials to product ""%1"". You can select a bill of materials manually.'; ru = 'Не удалось сопоставить спецификацию с номенклатурой ""%1"". Вы можете выбрать спецификацию вручную.';pl = 'Nie można dopasować specyfikacji materiałowej do produktu ""%1"". Możesz wybrać specyfikację materiałową ręcznie.';es_ES = 'No puede coincidir una lista de materiales con el producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';es_CO = 'No puede coincidir una lista de materiales con el producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';tr = '''''%1'''' ürünü ile ürün reçetesi eşleşmiyor. Ürün reçetesini manuel olarak seçebilirsiniz.';it = 'Impossibile abbinare una distinta base all''articolo ""%1"". È possibile selezionare una distinta base manualmente.';de = 'Kann die Stückliste mit dem Produkt ""%1"" nicht übereinstimmen. Sie können die Stückliste manuell auswählen.'"),
			StructureData.ProductDescription);
		CommonClientServer.MessageToUser(MessageText);
			
	EndIf;
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbersProducts, TabularSectionRow, , UseSerialNumbersBalance);
	
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
	
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Item)
	
	ProductsQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure ProductsBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Products.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbersProducts, CurrentData, ,UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure ProductsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "ProductsSerialNumbers" Then
		OpenSerialNumbersSelection("Products","SerialNumbersProducts");
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsSerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection("Products", "SerialNumbersProducts");
	
EndProcedure

&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ProductsGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Products");
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

#EndRegion

#Region InventoryFormTableItemsEventHandlers

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
	StructureData = GetDataProductsOnChange(StructureData, Object.Date, Object.OperationKind);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.CostPercentage = 1;
	
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	InventoryQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection("Inventory", "SerialNumbers");
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection("Inventory", "SerialNumbers");
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
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
Procedure InventoryBatchOnChange(Item)
	
	InventoryBatchOnChangeAtClient();
	
EndProcedure

#EndRegion

#Region DisposalsFormTableItemsEventHandlers

&AtClient
Procedure DisposalsProductsOnChange(Item)
	
	TabularSectionRow = Items.Disposals.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			AccountingPrice);
	StructureData.Insert("Products",			TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
	StructureData.Insert("Factor",				1);
	StructureData.Insert("TabName",				"Disposals");
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Disposals", StructureData);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If Not ValueIsFilled(TabularSectionRow.Price) Then
		AccountingPriceMessage();
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Disposals.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			AccountingPrice);
	StructureData.Insert("DocumentCurrency",	TabularSectionRow.DocumentCurrency);
	StructureData.Insert("Products",			TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
	StructureData.Insert("MeasurementUnit",		TabularSectionRow.MeasurementUnit);
	StructureData.Insert("TabName",				"Disposals");
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If Not ValueIsFilled(TabularSectionRow.Price) Then
		AccountingPriceMessage();
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsPriceOnChange(Item)
	TabularSectionRow = Items.Disposals.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
EndProcedure

&AtClient
Procedure DisposalsQuantityOnChange(Item)
	TabularSectionRow = Items.Disposals.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
EndProcedure

&AtClient
Procedure DisposalsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.ByProducts.CurrentData;
	
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
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	TabularSectionRow.MeasurementUnit = ValueSelected;
	
EndProcedure

&AtClient
Procedure DisposalsOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Or Clone Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "DisposalsGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Disposals");
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsOnActivateCell(Item)
	
	CurrentData = Items.Disposals.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Disposals.CurrentItem;
		If TableCurrentColumn.Name = "DisposalsGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Disposals.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Disposals");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsOnEditEnd(Item, NewRow, CancelEdit)
	
	ThisIsNewRow = False;
	
EndProcedure

&AtClient
Procedure DisposalsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Disposals.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Disposals");
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Not CheckBOMFilling() Then
		Return;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(
			New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject),
			NStr("en = 'Tabular section ""Components"" will be filled in again. Continue?'; ru = 'Табличная часть ""Сырье и материалы"" будет перезаполнена. Продолжить?';pl = 'Sekcja tabelaryczna ""Komponenty"" zostanie wypełniona ponownie. Kontynuować?';es_ES = 'La sección tabular ""Componentes"" será rellenada de nuevo. ¿Continuar?';es_CO = 'La sección tabular ""Componentes"" será rellenada de nuevo. ¿Continuar?';tr = '""Malzemeler"" tablo bölümü tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Componenti"" sarà ricompilata. Continuare?';de = 'Der tabellarische Abschnitt ""Materialbestand"" wird erneut ausgefüllt. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		CommandToFillBySpecificationFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInByProductsWithBOM(Command)
	
	If Not CheckBOMFilling() Then
		Return;
	EndIf;
	
	If Object.Disposals.Count() > 0 Then
		ShowQueryBox(
			New NotifyDescription("FillInByProductsWithBOMEnd", ThisObject),
			NStr("en = 'The data on the ""By-products"" tab will be replaced with the data from the bill of materials. Do you want to continue?'; ru = 'Данные во вкладке ""Побочная продукция"" будут заменены данными из спецификации. Продолжить?';pl = 'Dane na karcie ""Produkty uboczne"" zostaną zastąpione danymi ze specyfikacji materiałowej. Czy chcesz kontynuować?';es_ES = 'Los datos de la pestaña ""Trozo y deterioro"" se reemplazarán por los datos de la lista de materiales. ¿Quiere continuar?';es_CO = 'Los datos de la pestaña ""Trozo y deterioro"" se reemplazarán por los datos de la lista de materiales. ¿Quiere continuar?';tr = '""Yan ürünler"" sekmesindeki veriler ürün reçetesindeki verilerle değiştirilecek. Devam etmek istiyor musunuz?';it = 'I dati nella scheda ""Scarti e residui"" saranno sostituiti con i dati della distinta base. Continuare?';de = 'Die Daten auf der Registerkarte ""Nebenprodukte"" werden durch die Daten aus der ausgewählten Stückliste ersetzt. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		FillInByProductsWithBOMFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure LoadFromFileGoods(Command)
	
	NotifyDescription = New NotifyDescription(
		"ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName", "Production.Products");
	DataLoadSettings.Insert("Title", NStr("en = 'Import goods from file'; ru = 'Загрузка товаров из файла';pl = 'Import towarów z pliku';es_ES = 'Importar mercancías del archivo';es_CO = 'Importar mercancías del archivo';tr = 'Malları dosyadan içe aktar';it = 'Importa merci da file';de = 'Importieren Sie Waren aus der Datei'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(
		DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DisposalsPick(Command)
	
	TabularSectionName	= "Disposals";
	SelectionMarker		= "Disposals";
	
	DocumentPresentaion	= NStr("en = 'production'; ru = 'Производство';pl = 'produkcja';es_ES = 'producción';es_CO = 'producción';tr = 'üretim';it = 'produzione';de = 'produktion'");
	
	SelectionParameters	= DriveClient.GetSelectionParameters(
		ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
		
	SelectionParameters.Insert("Company", ParentCompany);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly") Then
		SelectionParameters.Insert("StructuralUnit", Object.ProductsStructuralUnit);
	Else
		SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
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
Procedure FillByBasis(Command)
	
	If ValueIsFilled(Object.BasisDocument) Then
		
		ProductionOrderOperationType = Object.OperationKind;
		If ValueIsFilled(Object.OperationKind) Then
			ProductionOrderOperationType = OperationTypeBasedOnProductionOrder(Object.BasisDocument);
		EndIf;
		
		If ProductionOrderOperationType = Object.OperationKind Then
			ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
				NStr("en = 'Do you want to refill the production document?'; ru = 'Документ будет полностью перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz uzupełnić dokument produkcyjny?';es_ES = '¿Quiere volver a rellenar el documento de producción?';es_CO = '¿Quiere volver a rellenar el documento de producción?';tr = 'Üretim belgesini yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare il documento di produzione?';de = 'Möchten Sie das Produktionsdokument nachfüllen?'"),
				QuestionDialogMode.YesNo);
		Else
			ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
				NStr("en = 'The Production order process type differs from the process type of this document. Do you want to change the document  process type and repopulate data from the Production order?'; ru = 'Тип процесса заказа на производство отличается от типа процесса этого документа. Изменить тип процесса документа и повторно заполнить данные на основании заказа на производство?';pl = 'Typ procesu Zlecenia produkcyjnego różni się od typu procesu dokumentu. Czy chcesz zmienić typ procesu dokumentu i ponownie wypełnić dane ze Zlecenia produkcyjnego?';es_ES = 'El tipo de proceso de la orden de producción difiere del tipo de proceso de este documento. ¿Quiere cambiar el tipo de proceso del documento y rellenar los datos de la Orden de producción?';es_CO = 'El tipo de proceso de la orden de producción difiere del tipo de proceso de este documento. ¿Quiere cambiar el tipo de proceso del documento y rellenar los datos de la Orden de producción?';tr = 'Üretim emrinin süreç türü bu belgenin süreç türünden farklı. Belgenin süreç türünü değiştirmek ve verileri Üretim emrinden yeniden doldurmak istiyor musunuz?';it = 'Il tipo di processo dell''Ordine di produzione differisce dal tipo di processo di questo documento. Modificare il tipo di processo del documento e ricompilare i dati dall''Ordine di produzione?';de = 'Der Status des Produktionsauftrags unterscheidet sich vom Status dieses Dokuments. Möchten Sie den Status des Dokuments ändern und die Daten aus dem Produktionsauftrag neu auffüllen?'"),
				QuestionDialogMode.YesNo);
		EndIf;
		
	Else
		MessagesToUserClient.ShowMessageSelectOrder();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByWIP(Command)
	
	If ValueIsFilled(Object.WorkInProgress) Then
		ShowQueryBox(New NotifyDescription("FillByWIPEnd", ThisObject),
			NStr("en = 'Do you want to refill the production document?'; ru = 'Перезаполнить документ ""Производство""?';pl = 'Czy chcesz uzupełnić dokument produkcyjny?';es_ES = '¿Quiere volver a rellenar el documento de producción?';es_CO = '¿Quiere volver a rellenar el documento de producción?';tr = 'Üretim belgesini yeniden doldurmak istiyor musunuz?';it = 'Ricompilare il Documento di Produzione?';de = 'Möchten Sie das Produktionsdokument nachfüllen?'"),
			QuestionDialogMode.YesNo);
	Else
		MessagesToUserClient.ShowMessageSelectWorkInProgress();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillUsingSalesOrder(Command)
	
	If ValueIsFilled(Object.SalesOrder) Then
		ShowQueryBox(New NotifyDescription("FillBySalesOrderEnd", ThisObject),
			NStr("en = 'The document will be repopulated from the selected Sales order. Do you want to continue?'; ru = 'Документ будет перезаполнен из выбранного заказа покупателя. Продолжить?';pl = 'Dokument zostanie ponownie wypełniony z wybranego Zamówienia sprzedaży. Czy chcesz kontynuować?';es_ES = 'El documento se volverá a rellenar de la orden de ventas seleccionada. ¿Quiere continuar?';es_CO = 'El documento se volverá a rellenar de la orden de ventas seleccionada. ¿Quiere continuar?';tr = 'Belge, seçilen Satış siparişinden tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'Il documento sarà ripopolato dall''Ordine cliente selezionato. Continuare?';de = 'Das Dokument wird aus dem ausgewählten Kundenauftrag neu aufgefüllt. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		MessagesToUserClient.ShowMessageSelectOrder();
	EndIf;
	
EndProcedure

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
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'production'; ru = 'Производство';pl = 'produkcja';es_ES = 'producción';es_CO = 'producción';tr = 'üretim';it = 'produzione';de = 'produktion'");
	
	ShowAvailable = (Object.OperationKind <> PredefinedValue("Enum.OperationTypesProduction.Disassembly"));
	
	SelectionParameters	= DriveClient.GetSelectionParameters(
		ThisObject, TabularSectionName, DocumentPresentaion, True, False, ShowAvailable);
	
	SelectionParameters.Insert("Company", ParentCompany);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly") Then
		SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	Else
		SelectionParameters.Insert("StructuralUnit", Object.StructuralUnit);
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
Procedure ProductsPick(Command)
	
	TabularSectionName	= "Products";
	SelectionMarker		= "Products";
	DocumentPresentaion	= NStr("en = 'production'; ru = 'производство';pl = 'produkcja';es_ES = 'producción';es_CO = 'producción';tr = 'üretim';it = 'produzione';de = 'produktion'");
	
	ShowAvailable = (Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Disassembly"));
	
	SelectionParameters	= DriveClient.GetSelectionParameters(
		ThisObject, TabularSectionName, DocumentPresentaion, True, False, ShowAvailable);
	
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	
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
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	NotifyDescr = New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode));
	ShowInputValue(NotifyDescr, CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure AllocateAutomatically(Command)
	
	If Object.Allocation.Count() > 0 Then
		ShowQueryBox(
			New NotifyDescription("AllocateAutomaticallyQueryBoxHandler", ThisObject),
			NStr("en = 'Tabular section ""Allocation"" will be filled in again. Continue?'; ru = 'Табличная часть ""Разнесение"" будет перезаполнена. Продолжить?';pl = 'Sekcja tabelaryczna ""Przydzielenie"" zostanie wypełniona ponownie. Kontynuować?';es_ES = 'La sección tabular ""Asignación"" será rellenada de nuevo. ¿Continuar?';es_CO = 'La sección tabular ""Asignación"" será rellenada de nuevo. ¿Continuar?';tr = '""Tahsis"" tablo bölümü yeniden doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Allocazione"" sarà ricompilata. Continuare?';de = 'Der tabellarische Abschnitt ""Zuordnung"" wird erneut ausgefüllt. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		AllocateAutomaticallyAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckAllocationCorrectness(Command)
	
	CheckAllocationCorrectnessAtServer();
	
EndProcedure

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

// Reservation

&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly")
		And Object.Inventory.Count() = 0 Then
		
		MessagesToUserClient.ShowMessageNoProductsToReserve();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Disassembly")
		And Object.Products.Count() = 0 Then
		
		MessagesToUserClient.ShowMessageNoProductsToReserve();
		
	ElsIf Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		MessageText = NStr("en = '""Consume from"" is required.'; ru = 'Требуется заполнить поле ""Списать из"".';pl = 'Wymagane jest ""Spożywaj z"".';es_ES = 'Se requiere ""Consumir de"".';es_CO = 'Se requiere ""Consumir de"".';tr = '""Tüketilecek kısım"" gerekli.';it = '""Consumare da"" è necessario.';de = '""Verbrauch von"" ist ein Pflichtfeld.'");
		CommonClientServer.MessageToUser(MessageText,,, "Object.InventoryStructuralUnit");
		
	Else
		
		FillColumnReserveByBalancesAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly") Then
		
		If Object.Inventory.Count() = 0 Then
			
			MessagesToUserClient.ShowMessageNothingToClearAtReserve();
			
		Else
			
			For Each TabularSectionRow In Object.Inventory Do
				TabularSectionRow.Reserve = 0;
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Disassembly") Then
		
		If Object.Products.Count() = 0 Then
			
			MessagesToUserClient.ShowMessageNothingToClearAtReserve();
			
		Else
			
			For Each TabularSectionRow In Object.Products Do
				TabularSectionRow.Reserve = 0;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// End Reservation

#EndRegion

#Region Private

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

&AtClient
Procedure Attachable_FillBatchesByFEFOProducts_Selected()
	
	Params = New Structure;
	Params.Insert("TableName", "Products");
	Params.Insert("BatchOnChangeHandler", False);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_Selected(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFOProducts_All()
	
	Params = New Structure;
	Params.Insert("TableName", "Products");
	Params.Insert("BatchOnChangeHandler", False);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_All(ThisObject, Params);
	
EndProcedure

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
Procedure SetWIPChoiceParameter()
	
	NewParameter = New ChoiceParameter("Filter.BasisDocument", Object.BasisDocument);
	NewArray = New Array();
	If ValueIsFilled(Object.BasisDocument) Then
		NewArray.Add(NewParameter);
	EndIf;
	
	NewParameter = New ChoiceParameter("Filter.ProductionMethod", PredefinedValue("Enum.ProductionMethods.InHouseProduction"));
	NewArray.Add(NewParameter);
	
	NewParameters = New FixedArray(NewArray);
	Items.WorkInProgress.ChoiceParameters = NewParameters;
	
EndProcedure

&AtClient
Procedure ProductsQuantityOnChangeAtClient()
	
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object,
			Items.Products.CurrentData, "SerialNumbersProducts");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChangeAtClient()
	
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, Items.Inventory.CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryBatchOnChangeAtClient()
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabRow.Products);
	StructureData.Insert("Batch", TabRow.Batch);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
	
	InventoryBatchOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_BatchOnChange(TableName) Export
	
	InventoryBatchOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_QuantityOnChange(TableName, RowData) Export
	
	If TableName = "Inventory" Then
		InventoryQuantityOnChangeAtClient();
	Else
		ProductsQuantityOnChangeAtClient();
	EndIf;
	
EndProcedure

&AtClient
Function Attachable_FillByFEFOData(TableName, ShowMessages) Export
	
	Return FillByFEFOData(TableName, ShowMessages);
	
EndFunction

&AtServer
Function FillByFEFOData(TableName, ShowMessages)
	
	Params = New Structure;
	Params.Insert("TableName", TableName);
	Params.Insert("CurrentRow", Object[TableName].FindByID(Items[TableName].CurrentRow));
	Params.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	Params.Insert("Cell", Object.CellInventory);
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

&AtServer
Procedure SetVisibleAndEnabled(OnOpen = False)
	
	IsDisassemblyOperationKind = (Object.OperationKind = Enums.OperationTypesProduction.Disassembly);
	IsAssemblyOperationKind = (Object.OperationKind = Enums.OperationTypesProduction.Assembly);
	IsConvertFromWIPOperationKind = (Object.OperationKind = Enums.OperationTypesProduction.ConvertFromWIP);
	
	Items.InventoryCostPercentage.Visible = IsDisassemblyOperationKind;
	
	Items.GroupWarehouseProductsAssembling.Visible = Not IsDisassemblyOperationKind;
	Items.GroupWarehouseProductsDisassembling.Visible = IsDisassemblyOperationKind;
	
	Items.GroupWarehouseInventoryAssembling.Visible = Not IsDisassemblyOperationKind;
	Items.GroupWarehouseInventoryDisassembling.Visible = IsDisassemblyOperationKind;
	
	Items.AllocationQuantity.Visible = Not IsDisassemblyOperationKind;
	Items.AllocationMeasurementUnit.Visible = Not IsDisassemblyOperationKind;
	Items.AllocationQuantityPerCostShare.Visible = IsDisassemblyOperationKind;
	Items.AllocationCorrMeasurementUnitPerCostShare.Visible = IsDisassemblyOperationKind;
	
	Items.FillBatchesByFEFOProducts.Visible = IsDisassemblyOperationKind;
	
	Items.FillBatchesByFEFO.Visible = IsAssemblyOperationKind;
	
	Items.TSActivities.Visible = IsConvertFromWIPOperationKind;
	Items.ActivitiesStandardWorkload.Visible = Not IsConvertFromWIPOperationKind;
	Items.ActivitiesRate.Visible = Not IsConvertFromWIPOperationKind;
	Items.ActivitiesTotal.Visible = Not IsConvertFromWIPOperationKind;
	Items.ActivitiesActualWorkload.Visible = Not IsConvertFromWIPOperationKind;
	
	Items.GroupWarehouseInventoryAssembling.Visible =
		Items.GroupWarehouseInventoryAssembling.Visible And Not IsConvertFromWIPOperationKind;
	Items.CommandFillBySpecification.Visible = Not IsConvertFromWIPOperationKind;
	Items.InventoryBatch.Visible = Not IsConvertFromWIPOperationKind;
	Items.InventorySerialNumbers.Visible = Not IsConvertFromWIPOperationKind;
	Items.InventorySpecification.Visible = Not IsConvertFromWIPOperationKind;
	
	Items.AllocationType.ReadOnly = IsConvertFromWIPOperationKind;
	Items.AllocationCorrBatch.Visible = Not IsConvertFromWIPOperationKind;
	Items.AllocationBatch.Visible = Not IsConvertFromWIPOperationKind;
	Items.AllocationGLAccount.Visible = UseDefaultTypeOfAccounting And Not IsConvertFromWIPOperationKind;
	Items.AllocationStructuralUnit.Visible = IsConvertFromWIPOperationKind;
	Items.AllocationCostObject.Visible = IsConvertFromWIPOperationKind;
	Items.AllocationConsumptionGLAccount.Visible = IsConvertFromWIPOperationKind;
	
	If GetFunctionalOption("CanProvideSubcontractingServices") Then
		SalesOrder = Common.ObjectAttributeValue(Object.BasisDocument, "SalesOrder");
		SubcontractingServices = (TypeOf(SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived"));
	Else
		SubcontractingServices = False;
	EndIf;
	
	If OnOpen Then
		UseByProductsAccountingStartingFrom = Constants.UseByProductsAccountingStartingFrom.Get();
		UseByProductsAccounting = ?(ValueIsFilled(UseByProductsAccountingStartingFrom),
			?(ValueIsFilled(Object.Date),
				UseByProductsAccountingStartingFrom <= Object.Date,
				True),
			False);
	EndIf;
	
	If UseByProductsAccounting Then
		Items.TSDisposals.Visible = IsConvertFromWIPOperationKind And Not SubcontractingServices;
		Items.AllocationByProduct.Visible = IsConvertFromWIPOperationKind And Not SubcontractingServices;
	EndIf;
	
	Items.GroupWIP.Visible = IsConvertFromWIPOperationKind;
	Items.WorkInProgress.Visible = (Object.WorksInProgress.Count() <= 1);
	Items.RelatedWorksInProgress.Visible = (Object.WorksInProgress.Count() > 1);
	
	Items.ProductsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.ActivitiesGLAccount.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.DisposalsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.AllocationCorrGLAccount.Visible = UseDefaultTypeOfAccounting;
	Items.AllocationConsumptionGLAccount.Visible = UseDefaultTypeOfAccounting;
	
	Items.OperationKind.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.ProductsStructuralUnitAssembling.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.ProductsStructuralUnitDisassembling.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.InventoryStructuralUnitAssembling.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.InventoryStructuralUnitDisassembling.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.DisposalsStructuralUnit.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.Company.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.StructuralUnit.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.Products.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.ProductsProducts.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.ProductsQuantity.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.ProductsMeasurementUnit.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.InventoryProducts.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.InventoryQuantity.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.InventoryMeasurementUnit.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.DisposalsProducts.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.DisposalsQuantity.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	Items.DisposalsMeasurementUnit.AutoMarkIncomplete = Not Object.ForOpeningBalancesOnly;
	
	CommonClientServer.SetFormItemProperty(Items, "ProductsCommandsChangeReserve", "Visible", IsDisassemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "ProductsReserve", "Visible", IsDisassemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "InventoryCommandsChangeReserve", "Visible", IsAssemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "InventoryReserve", "Visible", IsAssemblyOperationKind);
	
EndProcedure

&AtServer
Procedure SetModeAndChoiceList()
	
	Items.Cell.Enabled = ValueIsFilled(Object.StructuralUnit);
	Items.ProductsCellAssembling.Enabled = ValueIsFilled(Object.ProductsStructuralUnit);
	Items.CellInventoryDisassembling.Enabled = ValueIsFilled(Object.ProductsStructuralUnit);
	Items.CellInventoryAssembling.Enabled = ValueIsFilled(Object.InventoryStructuralUnit);
	Items.ProductsCellDisassembling.Enabled = ValueIsFilled(Object.InventoryStructuralUnit);
	Items.DisposalsCell.Enabled = ValueIsFilled(Object.DisposalsStructuralUnit);
	
	If Not Constants.UseSeveralDepartments.Get()
		And Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.ProductsStructuralUnitAssembling.ListChoiceMode = True;
		Items.ProductsStructuralUnitAssembling.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.ProductsStructuralUnitAssembling.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.ProductsStructuralUnitDisassembling.ListChoiceMode = True;
		Items.ProductsStructuralUnitDisassembling.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.ProductsStructuralUnitDisassembling.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.InventoryStructuralUnitAssembling.ListChoiceMode = True;
		Items.InventoryStructuralUnitAssembling.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.InventoryStructuralUnitAssembling.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.InventoryStructuralUnitDisassembling.ListChoiceMode = True;
		Items.InventoryStructuralUnitDisassembling.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.InventoryStructuralUnitDisassembling.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.DisposalsStructuralUnit.ListChoiceMode = True;
		Items.DisposalsStructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.DisposalsStructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

&AtServer
Procedure FillByBillsOfMaterialsAtServer(FillActivities = False)
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionBySpecification();
	If FillActivities Then
		Document.FillInActivitiesByBOM();
	EndIf;
	If AllocationType Then
		Document.FillByProductsWithBOM(Undefined);
	EndIf;
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	False);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		FillAddedColumns(ParametersStructure);
		
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	False);
		ParametersStructure.Insert("FillDisposals",	False);
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Function CheckBOMFilling()
	
	Result = True;
	
	MessageTemplate = NStr("en = 'Bill of materials is required on line %1'; ru = 'В строке %1 требуется спецификация';pl = 'Specyfikacja materiałowa jest wymagana w wierszu %1';es_ES = 'Se requiere una lista de materiales en línea%1';es_CO = 'Se requiere una lista de materiales en línea%1';tr = '%1 satırında ürün reçetesi zorunlu';it = 'La distinta base è richiesta nella riga %1';de = 'Stückliste ist in der Zeile %1erforderlich'");
	
	For Each ProductsRow In Object.Products Do
		
		If Not ValueIsFilled(ProductsRow.Specification) Then
			
			Result = False;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate, ProductsRow.LineNumber);
			
			CommonClientServer.MessageToUser(
				MessageText,
				,
				CommonClientServer.PathToTabularSection("Object.Products", ProductsRow.LineNumber, "Specification"));
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange(Object.Ref, Object.Date, Object.Company);
	AccountingPrice = StructureData.AccountingPrice;
	RefillByProductsPrices();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, Company)
	
	StructureData = New Structure();
	StructureData.Insert("AccountingPrice",
		InformationRegisters.AccountingPolicy.GetAccountingPolicy(DateNew, Company).AccountingPrice);
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetCompanyDataOnChange(Company)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	StructureData.Insert("AccountingPrice", 
		InformationRegisters.AccountingPolicy.GetAccountingPolicy(
			?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()),
			Company).AccountingPrice);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined, OperationKind = Undefined)
	
	StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, Description");
	
	StructureData.Insert("MeasurementUnit", StuctureProduct.MeasurementUnit);
	StructureData.Insert("ProductDescription", StuctureProduct.Description);
	
	StructureData.Insert("ShowSpecificationMessage", False);
	
	If Not ObjectDate = Undefined Then
		
		If StructureData.Property("Characteristic") Then
			SpecificationWithoutCharacteristic = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				OperationKind);
		Else
			SpecificationWithoutCharacteristic = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				Catalogs.ProductsCharacteristics.EmptyRef(),
				OperationKind);
		EndIf;
		
		StructureData.Insert("Specification", SpecificationWithoutCharacteristic);
		
		StructureData.Insert("ShowSpecificationMessage", True);
		StructureData.Insert("ProductDescription", StuctureProduct.Description);
		
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		StructureData.Insert("DocumentCurrency", Common.ObjectAttributeValue(StructureData.Company, "PresentationCurrency"));
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate = Undefined, OperationKind = Undefined)
	
	StructureData.Insert("Specification",
		DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic, OperationKind));
		
	StructureData.Insert("ShowSpecificationMessage", False);
	
	If Not ObjectDate = Undefined Then
		
		StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "Description");
		
		SpecificationWithCharacteristic = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			ObjectDate, 
			StructureData.Characteristic,
			OperationKind);
		StructureData.Insert("Specification", SpecificationWithCharacteristic);
		StructureData.Insert("ShowSpecificationMessage", True);
		StructureData.Insert("ProductDescription", StuctureProduct.Description);
		
	EndIf;
	
	If StructureData.Property("PriceKind")
		And StructureData.Property("MeasurementUnit")
		And StructureData.MeasurementUnit = Undefined Then
		
		StructureData.Insert("Price", 0);
		
	ElsIf StructureData.Property("PriceKind") And StructureData.Property("MeasurementUnit") Then
		
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
Function GetDataStructuralUnitOnChange(StructureData)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	DepartmentData = Common.ObjectAttributesValues(
		StructureData.Department,
		"TransferRecipient,
		|TransferRecipientCell,
		|TransferSource,
		|TransferSourceCell,
		|RecipientOfWastes,
		|DisposalsRecipientCell");
	
	StructureData.Insert("ProductsStructuralUnit", DepartmentData.TransferRecipient);
	StructureData.Insert("ProductsCell", DepartmentData.TransferRecipientCell);
	
	StructureData.Insert("InventoryStructuralUnit", DepartmentData.TransferSource);
	StructureData.Insert("CellInventory", DepartmentData.TransferSourceCell);
	
	StructureData.Insert("DisposalsStructuralUnit", DepartmentData.RecipientOfWastes);
	StructureData.Insert("DisposalsCell", DepartmentData.DisposalsRecipientCell);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCellOnChange(StructureData)
	
	StructuralUnitData = Common.ObjectAttributesValues(
		StructureData.StructuralUnit,
		"TransferRecipient,
		|TransferRecipientCell,
		|TransferSource,
		|TransferSourceCell,
		|RecipientOfWastes,
		|DisposalsRecipientCell");
	
	If StructureData.StructuralUnit = StructureData.ProductsStructuralUnit
		And (StructuralUnitData.TransferRecipient <> StructureData.ProductsStructuralUnit
			Or StructuralUnitData.TransferRecipientCell <> StructureData.ProductsCell) Then
		StructureData.Insert("NewGoodsCell", StructureData.Cell);
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.InventoryStructuralUnit
		And (StructuralUnitData.TransferSource <> StructureData.InventoryStructuralUnit
			Or StructuralUnitData.TransferSourceCell <> StructureData.CellInventory) Then
		StructureData.Insert("NewCellInventory", StructureData.Cell);
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.DisposalsStructuralUnit
		And (StructuralUnitData.RecipientOfWastes <> StructureData.DisposalsStructuralUnit
			Or StructuralUnitData.DisposalsRecipientCell <> StructureData.DisposalsCell) Then
		StructureData.Insert("NewCellWastes", StructureData.Cell);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure InventoryBatchOnChangeAtServer(StructureData)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByDocument(AttributeBasis = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Fill(Object[AttributeBasis]);
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtClient
Procedure AccountingPriceMessage()
	CommonClientServer.MessageToUser(NStr("en = 'The price is required for the by-product. Fill in the Accounting price in the Accounting policy or specify the price on the by-product card.'; ru = 'Для побочной продукции необходимо указать цену. Заполните Учетную цену в Учетной политике или укажите цену в карточке побочной продукции.';pl = 'Wymagana jest cena produktu ubocznego. Wypełnij Cenę ewidencyjną w Polityce rachunkowości lub określ cenę na karcie Produkty uboczne.';es_ES = 'Se requiere el precio del trozo y deterioro. Rellene el precio contable en la Política de contabilidad o especifique el precio en la tarjeta del trozo y deterioro.';es_CO = 'Se requiere el precio del trozo y deterioro. Rellene el precio contable en la Política de contabilidad o especifique el precio en la tarjeta del trozo y deterioro.';tr = 'Yan ürün için fiyat gerekli. Muhasebe politikasında muhasebe fiyatını doldurun veya yan ürün kartında fiyatı girin.';it = 'È richiesto il prezzo per lo scarto. Compilare il Prezzo contabile nella Politica contabile o specificare il prezzo nella scheda dello scarto.';de = 'Der Preis ist für das Nebenprodukt erforderlich. Geben Sie den Buchhaltungspreis in der Bilanzierungsrichtlinien ein oder geben Sie den Preis auf der Nebenproduktkarte an.'"));
EndProcedure

&AtServer
Procedure OperationKindOnChangeAtServer()
	
	If Not AllocationType Then
		Object.Disposals.Clear();
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument();
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationTypeOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Object.OperationKind = AdditionalParameters.ProductionOrderOperationType;
		OperationKindOnChangeAtClient();
		BasisDocument = Object.BasisDocument;
	Else
		Object.BasisDocument = BasisDocument;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByWIPEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument("WorkInProgress");
	EndIf;
	
EndProcedure

&AtClient
Procedure FillBySalesOrderEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument("SalesOrder");
	EndIf;
	
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
	Modified = True;
	
EndProcedure

&AtClient
Procedure FillInByProductsWithBOMEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillInByProductsWithBOMFragment();
	
EndProcedure

&AtClient
Procedure FillInByProductsWithBOMFragment()
	
	FillInByProductsWithBOMAtServer();
	Modified = True;
	
	HasEmptyPrice = False;
	For Each DisposalsLine In Object.Disposals Do
		If DisposalsLine.Price = 0 Then
			HasEmptyPrice = True;
			Break;
		EndIf;
	EndDo;
	
	If HasEmptyPrice Then
		AccountingPriceMessage();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInByProductsWithBOMAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillByProductsWithBOM(Undefined);
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	False);
		ParametersStructure.Insert("FillInventory",	False);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefillByProductsPrices()
	
	StructureData = New Structure();
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			AccountingPrice);
	StructureData.Insert("Products",			Undefined);
	StructureData.Insert("Characteristic",		Undefined);
	StructureData.Insert("Factor",				1);
	StructureData.Insert("DocumentCurrency",	Undefined);
	
	For Each ByProductsLine In Object.Disposals Do
		
		StructureData.DocumentCurrency 	= ByProductsLine.DocumentCurrency;
		StructureData.Products 			= ByProductsLine.Products;
		StructureData.Characteristic 	= ByProductsLine.Characteristic;
		
		ByProductsLine.Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		ByProductsLine.Amount = ByProductsLine.Price * ByProductsLine.Quantity;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity, CostPercentage", TrimAll(CurBarcode), 1, 1));
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
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") And Result.Count() > 0 Then
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
			StructureProductsData.Insert("Products",		BarcodeData.Products);
			StructureProductsData.Insert("Characteristic",	BarcodeData.Characteristic);
			StructureProductsData.Insert("Ownership",		Catalogs.InventoryOwnership.EmptyRef());
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "Production");
			EndIf;
			
			BarcodeData.Insert("StructureProductsData",
				GetDataProductsOnChange(StructureProductsData, StructureData.Object.Date, StructureData.Object.OperationKind));
			
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
	
	If Items.Pages.CurrentPage = Items.TSProducts Then
		TableName = "Products";
	Else
		TableName = "Inventory";
	EndIf;
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined And BarcodeData.Count() = 0 Then
			
			UnknownBarcodes.Add(CurBarcode);
			
		Else
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Products", BarcodeData.Products);
			SearchStructure.Insert("Characteristic", BarcodeData.Characteristic);
			SearchStructure.Insert("Batch", BarcodeData.Batch);
			SearchStructure.Insert("MeasurementUnit", BarcodeData.MeasurementUnit);
			
			TSRowsArray = Object[TableName].FindRows(SearchStructure);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object[TableName].Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				If NewRow.Property("CostPercentage") Then
					NewRow.CostPercentage = 1;
				EndIf;
				If ValueIsFilled(BarcodeData.MeasurementUnit) Then
					NewRow.MeasurementUnit = BarcodeData.MeasurementUnit;
				Else
					NewRow.MeasurementUnit = BarcodeData.StructureProductsData.MeasurementUnit;
				EndIf;
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				Items[TableName].CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				Items[TableName].CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber")
				And ValueIsFilled(BarcodeData.SerialNumber)
				And TableName = "Inventory" Then
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
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject, , , , Notification);
		
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
		
		MessageString = NStr("en = 'Barcode data is not found: %1; quantity: %2'; ru = 'Данные по штрихкоду не найдены: %1; количество: %2';pl = 'Nie znaleziono danych kodu kreskowego: %1; ilość: %2';es_ES = 'Datos del código de barras no encontrados: %1; cantidad: %2';es_CO = 'Datos del código de barras no encontrados: %1; cantidad: %2';tr = 'Barkod verisi bulunamadı: %1; miktar: %2';it = 'Il codice a barre non è stato trovato per: %1; quantità: %2';de = 'Barcode-Daten wurden nicht gefunden: %1; Menge: %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			MessageString,
			CurUndefinedBarcode.Barcode,
			CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OpenSerialNumbersSelection(NameTSInventory, TSNameSerialNumbers)
	
	CurrentDataIdentifier = Items[NameTSInventory].CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(
		CurrentDataIdentifier, NameTSInventory, TSNameSerialNumbers);
	// Using field InventoryStructuralUnit for SN selection
	ParametersOfSerialNumbers.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	ParametersOfSerialNumbers.Insert("Cell", Object.CellInventory);
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
	
EndProcedure

&AtServer
Function GetSerialNumbersInventoryFromStorage(AddressInTemporaryStorage, RowKey)
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Inventory");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbers");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(
		Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function GetProductsSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Products");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbersProducts");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(
		Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier, TSName, TSNameSerialNumbers)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly")
		And TSName = "Inventory" Then
		PickMode = True;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Disassembly")
		And TSName = "Products"  Then
		PickMode = True;
	Else
		PickMode = False;
	EndIf;
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(
		Object, ThisObject.UUID, CurrentDataIdentifier, PickMode, TSName, TSNameSerialNumbers);
	
EndFunction

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 						 TabName);
	StructureData.Insert("Object",							 Form.Object);
	StructureData.Insert("Batch", 							 TabRow.Batch);
	StructureData.Insert("Ownership", 						 TabRow.Ownership);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",						 TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",				 TabRow.GLAccountsFilled);
		
		StructureData.Insert("ConsumptionGLAccount",			 TabRow.ConsumptionGLAccount);
		StructureData.Insert("InventoryGLAccount",				 TabRow.InventoryGLAccount);
		
		If StructureData.TabName = "Inventory" Then
			StructureData.Insert("InventoryReceivedGLAccount",	 TabRow.InventoryReceivedGLAccount);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)

	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If ParametersStructure.FillProducts Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Products");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Products");
		
		StructureArray.Add(StructureData);
	
	EndIf;
	
	If ParametersStructure.FillInventory Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	If ParametersStructure.FillDisposals Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Disposals");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Disposals");
		
		StructureArray.Add(StructureData);
		
		DocumentCurrency = Common.ObjectAttributeValue(Object.Company, "PresentationCurrency");
		For Each DisposalsLine In Object.Disposals Do
			DisposalsLine.DocumentCurrency = DocumentCurrency;
		EndDo;
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
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
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, SelectionMarker, True, True);
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAllocationItemsAvailability()
	
	Items.AllocationAllocateAutomatically.Enabled = Object.ManualAllocation;
	Items.AllocationCheckAllocationCorrectness.Enabled = Object.ManualAllocation;
	
	Items.AllocationQuantity.ReadOnly = Not Object.ManualAllocation;
	Items.AllocationQuantityPerCostShare.ReadOnly = Not Object.ManualAllocation;
	
	If Object.ManualAllocation Then
		Items.AllocationQuantity.HeaderPicture = PictureLib.Change;
		Items.AllocationQuantityPerCostShare.HeaderPicture = PictureLib.Change;
		Items.AllocationStructuralUnit.HeaderPicture = PictureLib.Change;
		Items.AllocationCostObject.HeaderPicture = PictureLib.Change;
	Else
		Items.AllocationQuantity.HeaderPicture = New Picture;
		Items.AllocationQuantityPerCostShare.HeaderPicture = New Picture;
		Items.AllocationStructuralUnit.HeaderPicture = New Picture;
		Items.AllocationCostObject.HeaderPicture = New Picture;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllocateAutomaticallyQueryBoxHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	AllocateAutomaticallyAtServer();
	
EndProcedure

&AtServer
Procedure AllocateAutomaticallyAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.Allocate();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CheckAllocationCorrectnessAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.CheckAllocationCorrectness(True);
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.DisposalsPrice);
	
	Return Fields;
	
EndFunction
&AtServerNoContext
Function OperationTypeBasedOnProductionOrder(ProductionOrder)
	
	ProductionOrderOperationKind = Common.ObjectAttributeValue(ProductionOrder, "OperationKind");
	
	Result = Enums.OperationTypesProduction.Disassembly;
	
	If ProductionOrderOperationKind = Enums.OperationTypesProductionOrder.Assembly Then
		Result = Enums.OperationTypesProduction.Assembly;
	ElsIf ProductionOrderOperationKind = Enums.OperationTypesProductionOrder.Production Then
		Result = Enums.OperationTypesProduction.ConvertFromWIP;
	EndIf;
	
	Return Result;
	
EndFunction

#Region Reservation

&AtServer
Function PutEditReservationDataToTempStorage()

	DocObject = FormAttributeToValue("Object");
	DataForOwnershipForm = InventoryReservationServer.GetDataFormInventoryReservationForm(DocObject);
	TempStorageAddress = PutToTempStorage(DataForOwnershipForm, UUID);
	
	Return TempStorageAddress;

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
		
		TableName = "Products";
		
		If Object.OperationKind = Enums.OperationTypesProduction.Disassembly Then
			TableName = "Inventory";
		EndIf;
		
		DocumentObject = FormAttributeToValue("Object");
		
		ParametersData = New Structure;
		ParametersData.Insert("Ref", Object.Ref);
		ParametersData.Insert("TableName", TableName);
		ParametersData.Insert("ProductsChanges", DocumentObject[TableName].Unload());
		ParametersData.Insert("UseOrder", False);
		
		Return InventoryReservationServer.CheckReservedProductsChange(ParametersData);
		
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Function ChangeAdjustedReserved()

	Return Object.AdjustedReserved = Common.ObjectAttributeValue(Object.Ref, "AdjustedReserved");

EndFunction


// Reservation

&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

// End Reservation
#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion