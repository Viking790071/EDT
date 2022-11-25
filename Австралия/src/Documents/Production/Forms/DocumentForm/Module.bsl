
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure fills in Inventory by specification.
//
&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionBySpecification();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	False);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	False);
		FillAddedColumns(ParametersStructure);
		
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	False);
		ParametersStructure.Insert("FillDisposals",	True);
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

// Procedure fills in Inventory by specification.
//
&AtServer
Procedure FillByProductsBySpecificationAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillByProductsWithBOM();
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

// Gets data set from server.
//
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
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined, OperationKind = Undefined)
	
	StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, Description");
	
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
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate, OperationKind)
	
	StructureData.Insert("ShowSpecificationMessage", False);
	
	If Not ObjectDate = Undefined Then
		
		StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "Description");
		
		Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			ObjectDate, 
			StructureData.Characteristic,
			OperationKind);
		
		StructureData.Insert("Specification", Specification);
		StructureData.Insert("ShowSpecificationMessage", True);
		StructureData.Insert("ProductDescription", StuctureProduct.Description);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
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
	
	If StructureData.Department.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
		OR StructureData.Department.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		
		StructureData.Insert("ProductsStructuralUnit", StructureData.Department.TransferRecipient);
		StructureData.Insert("ProductsCell", StructureData.Department.TransferRecipientCell);
		
	Else
		
		StructureData.Insert("ProductsStructuralUnit", Undefined);
		StructureData.Insert("ProductsCell", Undefined);
		
	EndIf;
	
	If StructureData.Department.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
		OR StructureData.Department.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		
		StructureData.Insert("InventoryStructuralUnit", StructureData.Department.TransferSource);
		StructureData.Insert("CellInventory", StructureData.Department.TransferSourceCell);
		
	Else
		
		StructureData.Insert("InventoryStructuralUnit", Undefined);
		StructureData.Insert("CellInventory", Undefined);
		
	EndIf;
	
	StructureData.Insert("DisposalsStructuralUnit", StructureData.Department.RecipientOfWastes);
	StructureData.Insert("DisposalsCell", StructureData.Department.DisposalsRecipientCell);
	
	Return StructureData;
	
EndFunction

// Receives data set from the server for CellOnChange procedure.
//
&AtServerNoContext
Function GetDataCellOnChange(StructureData)
	
	If StructureData.StructuralUnit = StructureData.ProductsStructuralUnit Then
		
		If StructureData.StructuralUnit.TransferRecipient <> StructureData.ProductsStructuralUnit
			OR StructureData.StructuralUnit.TransferRecipientCell <> StructureData.ProductsCell Then
			
			StructureData.Insert("NewGoodsCell", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.InventoryStructuralUnit Then
		
		If StructureData.StructuralUnit.TransferSource <> StructureData.InventoryStructuralUnit
			OR StructureData.StructuralUnit.TransferSourceCell <> StructureData.CellInventory Then
			
			StructureData.Insert("NewCellInventory", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.DisposalsStructuralUnit Then
		
		If StructureData.StructuralUnit.RecipientOfWastes <> StructureData.DisposalsStructuralUnit
			OR StructureData.StructuralUnit.DisposalsRecipientCell <> StructureData.DisposalsCell Then
			
			StructureData.Insert("NewCellWastes", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	Return StructureData;
	
EndFunction

// Procedure calls the data processor for document filling by basis.
//
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

&AtServer
Procedure OperationKindOnChangeAtServer()
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillProducts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillDisposals",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	SetVisibleAndEnabled();
	
	If OperationKind <> Object.OperationKind Then
		
		// cleaning BOM column in Products
		For Each ProductsLine In Object.Products Do
			
			ProductsLine.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef");
			
		EndDo;
		
		OperationKind = Object.OperationKind;
		
		Object.Reservation.Clear();
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
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("Ownership", Catalogs.InventoryOwnership.EmptyRef());
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "Production", StructureData.TableName);
			EndIf;
			
			BarcodeData.Insert("StructureProductsData",
				GetDataProductsOnChange(StructureProductsData, StructureData.Object.Date, StructureData.Object.OperationKind));
			
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
	StructureData.Insert("Object", Object);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If Items.Pages.CurrentPage = Items.TSProducts Then
		TableName = "Products";
	Else
		TableName = "Inventory";
	EndIf;
	
	StructureData.Insert("TableName", TableName);
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			And BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object[TableName].FindRows(New Structure("Products, Characteristic, Batch, MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
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
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				Items[TableName].CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				Items[TableName].CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") And ValueIsFilled(BarcodeData.SerialNumber) And TableName = "Inventory" Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
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
	
EndProcedure

// End Peripherals

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		Items.InventoryCostPercentage.Visible = True;
		
		Items.GroupWarehouseProductsAssembling.Visible = False;
		Items.GroupWarehouseProductsDisassembling.Visible = True;
		
		Items.GroupWarehouseInventoryAssembling.Visible = False;
		Items.GroupWarehouseInventoryDisassembling.Visible = True;
		
		Items.FillBatchesByFEFO.Visible = False;
		Items.FillBatchesByFEFOProducts.Visible = True;
		
	Else
		
		Items.InventoryCostPercentage.Visible = False;
		
		Items.GroupWarehouseProductsAssembling.Visible = True;
		Items.GroupWarehouseProductsDisassembling.Visible = False;
		
		Items.GroupWarehouseInventoryAssembling.Visible = True;
		Items.GroupWarehouseInventoryDisassembling.Visible = False;
		
		Items.FillBatchesByFEFO.Visible = True;
		Items.FillBatchesByFEFOProducts.Visible = False;
		
	EndIf;
	
	Items.TSDisposals.Visible = Constants.UseByProductsInKitProcessing.Get();
	
	Items.ProductsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.DisposalsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	SetVisibleSalesOrder();
	
EndProcedure

&AtServer
Procedure SetVisibleSalesOrder()
	
	If ValueIsFilled(Object.ProductsStructuralUnit) Then
		StructuralUnitType = Common.ObjectAttributeValue(Object.ProductsStructuralUnit, "StructuralUnitType");
	Else
		StructuralUnitType = Undefined;
	EndIf;
	
	Items.GroupSalesOrder.Visible = (StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse);
	
EndProcedure

// Procedure sets selection mode and selection list for the form units.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetModeAndChoiceList()
	
	Items.Cell.Enabled = ValueIsFilled(Object.StructuralUnit);
	
	Items.ProductsCellAssembling.Enabled = ValueIsFilled(Object.ProductsStructuralUnit);
	Items.CellInventoryDisassembling.Enabled = ValueIsFilled(Object.ProductsStructuralUnit);
	
	Items.CellInventoryAssembling.Enabled = ValueIsFilled(Object.InventoryStructuralUnit);
	Items.ProductsCellDisassembling.Enabled = ValueIsFilled(Object.InventoryStructuralUnit);
	
	Items.DisposalsCell.Enabled = ValueIsFilled(Object.DisposalsStructuralUnit);
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
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
	
	Array = New Array();
	Array.Add(Type("DocumentRef.KitOrder"));
	NewDescription = New TypeDescription(Array);
	
	Items.BasisDocument.TypeRestriction = NewDescription;
	
EndProcedure

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'production'; ru = 'производство';pl = 'produkcja';es_ES = 'producción';es_CO = 'producción';tr = 'üretim';it = 'produzione';de = 'produktion'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
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

// Procedure - handler of the Action event of the Pick TS Products command.
//
&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName	= "Products";
	SelectionMarker		= "Products";
	DocumentPresentaion	= NStr("en = 'production'; ru = 'производство';pl = 'produkcja';es_ES = 'producción';es_CO = 'producción';tr = 'üretim';it = 'produzione';de = 'produktion'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
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

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure DisposalsPick(Command)
	
	TabularSectionName	= "Disposals";
	SelectionMarker		= "Disposals";
	DocumentPresentaion	= NStr("en = 'production'; ru = 'производство';pl = 'produkcja';es_ES = 'producción';es_CO = 'producción';tr = 'üretim';it = 'produzione';de = 'produktion'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
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
        BarcodesReceived(New Structure("Barcode, Quantity, CostPercentage", TrimAll(CurBarcode), 1, 1));
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

// Procedure of processing the results of selection closing
//
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

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[SelectionMarker].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				Object[SelectionMarker].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, SelectionMarker, True, True);
			
		EndIf;
		
	EndIf;
	
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

#EndRegion

#Region FormEventsHandlers

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
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	ElsIf ChoiceSource.FormName = "CommonForm.InventoryReservation" Then
		EditReservationProcessingAtClient(SelectedValue.TempStorageInventoryReservationAddress);
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
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	OperationKind = Object.OperationKind;
	
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
	
	SetVisibleAndEnabled();
	SetModeAndChoiceList();
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Products");
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Disposals");
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.Production.TabularSections.Products, DataLoadSettings, ThisObject);
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
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject, "Products");
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
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
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

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If ValueIsFilled(Object.BasisDocument) Then
		Notify("Record_Production", Object.Ref);
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
				Data.Add(New Structure("Barcode, Quantity, CostPercentage", Parameter[0], 1, 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity, CostPercentage", Parameter[1][1], 1, 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
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

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of clicking the FillByBasis button.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectOrder();
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the production document?'; ru = 'Документ будет полностью перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz uzupełnić dokument produkcyjny?';es_ES = '¿Quiere volver a rellenar el documento de producción?';es_CO = '¿Quiere volver a rellenar el documento de producción?';tr = 'Üretim belgesini yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare il documento di produzione?';de = 'Möchten Sie das Produktionsdokument nachfüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument();
	EndIf;
	
EndProcedure

// Procedure - handler of the  FillUsingSalesOrder click button.
//
&AtClient
Procedure FillUsingSalesOrder(Command)
	
	If Not ValueIsFilled(Object.SalesOrder) Then
		MessagesToUserClient.ShowMessageSelectOrder();
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillBySalesOrderEnd", ThisObject),
		NStr("en = 'The document will be repopulated from the selected Sales order. Do you want to continue?'; ru = 'Документ будет перезаполнен из выбранного заказа покупателя. Продолжить?';pl = 'Dokument zostanie ponownie wypełniony z wybranego Zamówienia sprzedaży. Czy chcesz kontynuować?';es_ES = 'El documento se volverá a rellenar de la orden de ventas seleccionada. ¿Quiere continuar?';es_CO = 'El documento se volverá a rellenar de la orden de ventas seleccionada. ¿Quiere continuar?';tr = 'Belge, seçilen Satış siparişinden tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'Il documento sarà ripopolato dall''Ordine cliente selezionato. Continuare?';de = 'Das Dokument wird aus dem ausgewählten Kundenauftrag neu aufgefüllt. Möchten Sie fortsetzen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillBySalesOrderEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument("SalesOrder");
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

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
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
EndProcedure

// Procedure - handler of the OnChange event of the BasisDocument input field.
//
&AtClient
Procedure BasisDocumentOnChange(Item)
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	OperationKindOnChangeAtServer();
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
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
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnit) Then
	
		StructureData = New Structure();
		StructureData.Insert("Department", Object.StructuralUnit);
		
		StructureData = GetDataStructuralUnitOnChange(StructureData);
		
		If ValueIsFilled(StructureData.ProductsStructuralUnit) Then
			
			Object.ProductsStructuralUnit = StructureData.ProductsStructuralUnit;
			Object.ProductsCell = StructureData.ProductsCell;
			
		Else
			
			Object.ProductsStructuralUnit = Object.StructuralUnit;
			Object.ProductsCell = Object.Cell;
			
		EndIf;
		
		If ValueIsFilled(StructureData.InventoryStructuralUnit) Then
			
			Object.InventoryStructuralUnit = StructureData.InventoryStructuralUnit;
			Object.CellInventory = StructureData.CellInventory;
			
		Else
			
			Object.InventoryStructuralUnit = Object.StructuralUnit;
			Object.CellInventory = Object.Cell;
			
		EndIf;
		
		If ValueIsFilled(StructureData.DisposalsStructuralUnit) Then
			
			Object.DisposalsStructuralUnit = StructureData.DisposalsStructuralUnit;
			Object.DisposalsCell = StructureData.DisposalsCell;
			
		Else
			
			Object.DisposalsStructuralUnit = Object.StructuralUnit;
			Object.DisposalsCell = Object.Cell;
			
		EndIf;
		
	EndIf;
	
	Items.Cell.Enabled = ValueIsFilled(Object.StructuralUnit);
	
	SetVisibleSalesOrder();
	
EndProcedure

// Procedure - event handler Field opening StructuralUnit.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Cell input field.
//
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

// Procedure - OnChange event handler of the ProductsStructuralUnitAssembling input field.
//
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
	
	SetVisibleSalesOrder();
	
EndProcedure

// Procedure - Open event handler of ProductsStructuralUnitAssembling field.
//
&AtClient
Procedure StructuralUnitOfProductAssemblyOpening(Item, StandardProcessing)
	
	If Items.ProductsStructuralUnitAssembling.ListChoiceMode
		AND Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the ProductsStructuralUnitDisassembling input field.
//
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

// Procedure - Open event handler of ProductsStructuralUnitDisassembling field.
//
&AtClient
Procedure ProductsStructuralUnitDisassemblingOpen(Item, StandardProcessing)
	
	If Items.ProductsStructuralUnitDisassembling.ListChoiceMode
		AND Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the InventoryStructuralUnitAssembling input field.
//
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

// Procedure - Open event handler of InventoryStructuralUnitAssembling field.
//
&AtClient
Procedure InventoryStructuralUnitInAssemblingOpen(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitAssembling.ListChoiceMode
		AND Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the InventoryStructuralUnitDisassembling input field.
//
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
	
	SetVisibleSalesOrder();
	
EndProcedure

// Procedure - Handler of event Opening InventoryStructuralUnitDisassembling field.
//
&AtClient
Procedure InventoryStructuralUnitDisassemblyOpening(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitDisassembling.ListChoiceMode
		AND Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the DisposalsStructuralUnit input field.
//
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

// Procedure - Open event handler of DisposalsStructuralUnit field.
//
&AtClient
Procedure DisposalsStructuralUnitOpening(Item, StandardProcessing)
	
	If Items.DisposalsStructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

#Region TabularSectionCommandpanelsActions

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Inventory.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject), NStr("en = 'Tabular section ""Materials"" will be filled in again. Continue?'; ru = 'Табличная часть ""Материалы"" будет перезаполнена! Продолжить?';pl = 'Sekcja tabelaryczna ""Materiały"" zostanie wypełniona ponownie. Kontynuować?';es_ES = 'Sección tabular ""Materiales"" se rellenará de nuevo. ¿Continuar?';es_CO = 'Sección tabular ""Materiales"" se rellenará de nuevo. ¿Continuar?';tr = '""Malzemeler"" tablo bölümü tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Materiali"" sarà compilata di nuovo. Continuare?';de = 'Der Tabellenabschnitt ""Materialien"" wird wieder ausgefüllt. Fortsetzen?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
		
	EndIf;
	
	CommandToFillBySpecificationFragment();
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CommandToFillBySpecificationFragment();

EndProcedure

&AtClient
Procedure CommandToFillBySpecificationFragment()
    
    FillByBillsOfMaterialsAtServer();

EndProcedure

&AtClient
Procedure FillByProductsBySpecification(Command)
	
	If Object.Disposals.Count() <> 0 Then
		
		Response = Undefined;
		
		ShowQueryBox(
			New NotifyDescription("FillByProductsBySpecificationEnd", ThisObject),
			NStr("en = 'The By-products tab will be repopulated with the data from the bill of materials.'; ru = 'Вкладка Побочная продукция будет перезаполнена данными из спецификации.';pl = 'Karta ""Produkty uboczne"" zostanie wypełniona ponownie danymi z tabeli ""Specyfikacja materiałowa"".';es_ES = 'La pestaña Trozo y deterioro será rellenada con los datos de la lista de materiales.';es_CO = 'La pestaña Trozo y deterioro será rellenada con los datos de la lista de materiales.';tr = 'Yan ürünler sekmesi, ürün reçetesi verileriyle yeniden doldurulacak.';it = 'La scheda Sottoprodotto sarà ricompilata con i dati della Distinta base.';de = 'Die Registerkarte ""Nebenprodukte"" wird mit den Daten aus der Stückliste neu aufgefüllt.'"), 
			QuestionDialogMode.YesNo,
			0);
		Return;
		
	EndIf;
	
	FillByProductsBySpecificationFragment();
	
EndProcedure

&AtClient
Procedure FillByProductsBySpecificationEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillByProductsBySpecificationFragment();
	
EndProcedure

&AtClient
Procedure FillByProductsBySpecificationFragment()
	
	FillByProductsBySpecificationAtServer();
	
EndProcedure

#EndRegion

#Region TabularSectionAttributeEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Products", StructureData);	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date, Object.OperationKind);
	
	If StructureData.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef")
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
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbersProducts, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date, Object.OperationKind);
	
	If StructureData.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef") 
		And StructureData.ShowSpecificationMessage Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot match a bill of materials with variant to product ""%1"". You can select a bill of materials manually.'; ru = 'Не удалось сопоставить спецификацию с вариантом с номенклатурой ""%1"". Вы можете выбрать спецификацию вручную.';pl = 'Nie można dopasować specyfikacji materiałowej do produktu ""%1"". Możesz wybrać specyfikację materiałową ręcznie.';es_ES = 'No puedo coincidir una lista de materiales con la variante del producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';es_CO = 'No puedo coincidir una lista de materiales con la variante del producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';tr = '''''%1'''' ürünü ile varyantlı ürün reçetesi eşleşmiyor. Ürün reçetesini manuel olarak seçebilirsiniz.';it = 'Impossibile abbinare una distinta base con variante all''articolo ""%1"". È possibile selezionare una distinta base manualmente.';de = 'Kann die Stückliste mit einer Variante mit dem Produkt ""%1"" nicht übereinstimmen. Sie können die Stückliste manuell auswählen.'"),
			StructureData.ProductDescription);
		CommonClientServer.MessageToUser(MessageText);
			
	EndIf;
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Products.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Products";
		SelectionMarker		= "Products";
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

#EndRegion

#Region TabularSectionInventoryEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
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
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	InventoryQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);

EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
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
Procedure ProductsQuantityOnChange(Item)
	
	ProductsQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure ProductsBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Products.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbersProducts, CurrentData,  ,UseSerialNumbersBalance);

EndProcedure

&AtClient
Procedure ProductsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
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
	OpenSerialNumbersSelection("Products","SerialNumbersProducts");
	
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

// Procedure - event handler OnChange of the variant input field.
//
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
		SelectionMarker		= "Inventory";
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
Procedure InventoryBatchOnChange(Item)
	
	InventoryBatchOnChangeAtClient();
	
EndProcedure

&AtServer
Procedure InventoryBatchOnChangeAtServer(StructureData)
	
	If UseDefaultTypeOfAccounting Then
		
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		
		StructureData.Insert("ObjectParameters", ObjectParameters);
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region TabularSectionDisposalsEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure DisposalsProductsOnChange(Item)
	
	TabularSectionRow = Items.Disposals.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("TabName", "Disposals");
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Disposals", StructureData);	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

&AtClient
Procedure DisposalsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Disposals.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Disposals";
		SelectionMarker		= "Disposals";
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

#Region LibrariesHandlers

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileGoods(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"Production.Products");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import goods from file'; ru = 'Загрузка товаров из файла';pl = 'Import towarów z pliku';es_ES = 'Importar mercancías del archivo';es_CO = 'Importar mercancías del archivo';tr = 'Malları dosyadan içe aktar';it = 'Importa merci da file';de = 'Importieren Sie Waren aus der Datei'"));
	
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

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

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

&AtClient
Procedure OpenSerialNumbersSelection(NameTSInventory, TSNameSerialNumbers)
	
	CurrentDataIdentifier = Items[NameTSInventory].CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier, NameTSInventory, TSNameSerialNumbers);
	// Using field InventoryStructuralUnit for SN selection
	ParametersOfSerialNumbers.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
	
EndProcedure

&AtServer
Function GetSerialNumbersInventoryFromStorage(AddressInTemporaryStorage, RowKey)
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Inventory");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbers");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);

EndFunction

&AtServer
Function GetProductsSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Products");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbersProducts");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier, TSName, TSNameSerialNumbers)
	
	If TSName = "Inventory" AND Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly") Then
		PickMode = True;
	ElsIf TSName = "Products" AND Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Disassembly") Then
		PickMode = True;
	Else
		PickMode = False;
	EndIf;
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, PickMode, TSName, TSNameSerialNumbers);
	
EndFunction

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 						TabName);
	StructureData.Insert("Object",							Form.Object);
	StructureData.Insert("Batch", 							TabRow.Batch);
	StructureData.Insert("Ownership", 						TabRow.Ownership);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",						TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",				TabRow.GLAccountsFilled);
		
		StructureData.Insert("ConsumptionGLAccount",			TabRow.ConsumptionGLAccount);
		StructureData.Insert("InventoryGLAccount",				TabRow.InventoryGLAccount);
		
		If StructureData.TabName = "Inventory" Then
			StructureData.Insert("InventoryReceivedGLAccount",	TabRow.InventoryReceivedGLAccount);
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
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Inventory");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Inventory");
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	If ParametersStructure.FillDisposals Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Disposals");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Disposals");
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

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

#Region Reservation

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

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion