
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// The procedure fills in the "Inventory by standards" tabular section.
//
&AtServer
Procedure FillTabularSectionInventoryByStandards()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryFillingByStandards();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the "Inventory by balance" tabular section.
//
&AtServer
Procedure FillTabularSectionInventoryByBalance()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryFillingByBalance();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns();
	
EndProcedure

// The procedure fills in the "InventoryAllocation by standards" tabular section.
//
&AtServer
Procedure FillTabularSectionInventoryDistributionByStandards()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryDistributionByStandards();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the "InventoryAllocation by quantity" tabular section.
//
&AtServer
Procedure FillTabularSectionInventoryDistributionByCount()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryDistributionByCount();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the Costs tabular section.
//
&AtServer
Procedure FillTabularSectionCostsByBalance()
	
	Document = FormAttributeToValue("Object");
	Document.RunExpenseFillingByBalance();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the ExpensesAllocation tabular section.
//
&AtServer
Procedure FillTabularSectionCostingByCount()
	
	Document = FormAttributeToValue("Object");
	Document.RunCostingByCount();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the Production tabular section.
//
&AtServer
Procedure FillTabularSectionProductsByOutput()
	
	Document = FormAttributeToValue("Object");
	Document.RunProductsFillingByOutput();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns();
	
EndProcedure

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange(Company)
	
	FillAddedColumns(True);
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("GLAccounts",				TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",		TabRow.GLAccountsFilled);
	StructureData.Insert("ConsumptionGLAccount",	TabRow.ConsumptionGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		InventoryData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteStructureData(InventoryData, ObjectParameters);
		StructureArray.Add(InventoryData);
		
		InventoryDistributionData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "InventoryDistribution");
		GLAccountsInDocuments.CompleteStructureData(InventoryDistributionData, ObjectParameters, "InventoryDistribution");
		StructureArray.Add(InventoryDistributionData);
		
		CostAllocationData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "CostAllocation");
		GLAccountsInDocuments.CompleteStructureData(CostAllocationData, ObjectParameters, "CostAllocation");
		StructureArray.Add(CostAllocationData);
	
	EndIf;
	
	CostsData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Costs");
	GLAccountsInDocuments.CompleteCounterpartyStructureData(CostsData, ObjectParameters, "Costs");
	StructureArray.Add(CostsData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
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
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(StructureProductsData, StructureData.Object, "CostAllocation");
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "CostAllocation");
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
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
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
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName	= "Products";
	DocumentPresentaion	= NStr("en = 'cost allocation'; ru = 'Распределение затрат';pl = 'alokacja kosztów';es_ES = 'asignación de costes';es_CO = 'asignación de costes';tr = 'maliyet dağıtımı';it = 'allocazione costo';de = 'Kostenzuordnung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'cost allocation'; ru = 'Распределение затрат';pl = 'alokacja kosztów';es_ES = 'asignación de costes';es_CO = 'asignación de costes';tr = 'maliyet dağıtımı';it = 'allocazione costo';de = 'Kostenzuordnung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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
		
		If TabularSectionName = "Inventory" Then
			NewRow.ConnectionKey = DriveServer.CreateNewLinkKey(ThisForm);
		EndIf;
		
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName <> "Products" Then
			
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
			TabularSectionName 	= ?(Items.Pages.CurrentPage = Items.GroupProducts, "Products", "Inventory");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);		
			
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
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
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();
	
	Items.CostAllocationGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryDistributionGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
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
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	FillAddedColumns();
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
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

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined)
	
	StructureData.Insert("MeasurementUnit", Common.ObjectAttributeValue(StructureData.Products, "MeasurementUnit"));
	
	If Not ObjectDate = Undefined Then
		If StructureData.Property("Characteristic") Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic);
		Else
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				Catalogs.ProductsCharacteristics.EmptyRef());
		EndIf;
		StructureData.Insert("Specification", Specification);
	EndIf;
	
	If StructureData.Property("UseDefaultTypeOfAccounting") 
		And StructureData.UseDefaultTypeOfAccounting
		And StructureData.Property("GLAccounts") Then
		
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate)
	
	Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
		ObjectDate, 
		StructureData.Characteristic);
	StructureData.Insert("Specification", Specification);
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM TABULAR SECTIONS COMMAND PANELS ACTIONS

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryFillByStandards(Command)
	
	If Object.Inventory.Count() <> 0 Then

		QuestionText = NStr("en = 'The ""Inventory"" tabular section will be filled in again.'; ru = 'Табличная часть ""Запасы"" будет перезаполнена!';pl = 'Sekcja tabelaryczna ""Zapasy"" zostanie wypełniona ponownie.';es_ES = 'La sección tabular ""Inventario"" se rellenará de nuevo.';es_CO = 'La sección tabular ""Inventario"" se rellenará de nuevo.';tr = '""Stok"" tablo bölümü tekrar doldurulacak.';it = 'La sezione tabellare ""Scorte"" sarà riempita di nuovo.';de = 'Der Tabellenabschnitt ""Bestand"" wird erneut ausgefüllt.'") + Chars.LF;
		If Object.InventoryDistribution.Count() <> 0 Then
			QuestionText = QuestionText + NStr("en = 'The ""Inventory allocation"" tabular section will be cleared.'; ru = 'Табличная часть ""Распределение запасов"" будет очищена!';pl = 'Sekcja tabelaryczna ""Alokacja zapasów"" zostanie wyczyszczona.';es_ES = 'La sección tabular ""Asignación del inventario"" se eliminará.';es_CO = 'La sección tabular ""Asignación del inventario"" se eliminará.';tr = '""Stok dağıtımı"" tablo bölümü silinecek.';it = 'La sezione tabellare ""Allocazione delle scorte"" verrà cancellata.';de = 'Der Tabellenbereich ""Bestandszuordnung"" wird gelöscht.'") + Chars.LF;
		EndIf;	
		QuestionText = QuestionText + NStr("en = 'Continue?'; ru = 'Продолжить?';pl = 'Kontynuować?';es_ES = '¿Continuar?';es_CO = '¿Continuar?';tr = 'Devam et?';it = 'Continuare?';de = 'Fortsetzen?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryFillByStandardsEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryFillByStandardsFragment();
EndProcedure

&AtClient
Procedure InventoryFillByStandardsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryFillByStandardsFragment();

EndProcedure

&AtClient
Procedure InventoryFillByStandardsFragment()
    
    FillTabularSectionInventoryByStandards();

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryFillByBalances(Command)
	
	If Object.Inventory.Count() <> 0 Then

		QuestionText = NStr("en = 'The ""Inventory"" tabular section will be filled in again.'; ru = 'Табличная часть ""Запасы"" будет перезаполнена!';pl = 'Sekcja tabelaryczna ""Zapasy"" zostanie wypełniona ponownie.';es_ES = 'La sección tabular ""Inventario"" se rellenará de nuevo.';es_CO = 'La sección tabular ""Inventario"" se rellenará de nuevo.';tr = '""Stok"" tablo bölümü tekrar doldurulacak.';it = 'La sezione tabellare ""Scorte"" sarà riempita di nuovo.';de = 'Der Tabellenabschnitt ""Bestand"" wird erneut ausgefüllt.'") + Chars.LF;
		If Object.InventoryDistribution.Count() <> 0 Then
			QuestionText = QuestionText + NStr("en = 'The ""Inventory allocation"" tabular section will be cleared.'; ru = 'Табличная часть ""Распределение запасов"" будет очищена!';pl = 'Sekcja tabelaryczna ""Alokacja zapasów"" zostanie wyczyszczona.';es_ES = 'La sección tabular ""Asignación del inventario"" se eliminará.';es_CO = 'La sección tabular ""Asignación del inventario"" se eliminará.';tr = '""Stok dağıtımı"" tablo bölümü silinecek.';it = 'La sezione tabellare ""Allocazione delle scorte"" verrà cancellata.';de = 'Der Tabellenbereich ""Bestandszuordnung"" wird gelöscht.'") + Chars.LF;
		EndIf;	
		QuestionText = QuestionText + NStr("en = 'Continue?'; ru = 'Продолжить?';pl = 'Kontynuować?';es_ES = '¿Continuar?';es_CO = '¿Continuar?';tr = 'Devam et?';it = 'Continuare?';de = 'Fortsetzen?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryFillByBalancesEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryFillByBalancesFragment();
EndProcedure

&AtClient
Procedure InventoryFillByBalancesEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryFillByBalancesFragment();

EndProcedure

&AtClient
Procedure InventoryFillByBalancesFragment()
    
    FillTabularSectionInventoryByBalance();

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryDistributeByStandards(Command)
	
	If Object.InventoryDistribution.Count() <> 0 Then

		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryDistributeByStandardsEnd", ThisObject), NStr("en = 'The ""Inventory allocation"" tabular section will be filled in again. Continue?'; ru = 'Табличная часть ""Распределение запасов"" будет перезаполнена! Продолжить?';pl = 'Sekcja tabelaryczna ""Alokacja zapasów"" zostanie wypełniona ponownie. Kontynuować?';es_ES = 'La sección tabular ""Asignación del inventario"" se rellenará de nuevo. ¿Continuar?';es_CO = 'La sección tabular ""Asignación del inventario"" se rellenará de nuevo. ¿Continuar?';tr = '""Stok dağıtımı"" tablo bölümü tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Allocazione delle scorte"" sarà riempita di nuovo. Continuare?';de = 'Der Tabellenteil ""Bestandszuordnung"" wird erneut ausgefüllt. Fortsetzen?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryDistributeByStandardsFragment();
EndProcedure

&AtClient
Procedure InventoryDistributeByStandardsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryDistributeByStandardsFragment();

EndProcedure

&AtClient
Procedure InventoryDistributeByStandardsFragment()
    
    FillTabularSectionInventoryDistributionByStandards();
    
    If Object.Inventory.Count() <> 0 Then
        
        If Items.Inventory.CurrentRow = Undefined Then
            Items.Inventory.CurrentRow = 0;
        EndIf;	
        
        TabularSectionName = "Inventory";
        DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
        
    EndIf;

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryDistributeByQuantity(Command)
	
	If Object.InventoryDistribution.Count() <> 0 Then

		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryDistributeByQuantityEnd", ThisObject), NStr("en = 'The ""Inventory allocation"" tabular section will be filled in again. Continue?'; ru = 'Табличная часть ""Распределение запасов"" будет перезаполнена! Продолжить?';pl = 'Sekcja tabelaryczna ""Alokacja zapasów"" zostanie wypełniona ponownie. Kontynuować?';es_ES = 'La sección tabular ""Asignación del inventario"" se rellenará de nuevo. ¿Continuar?';es_CO = 'La sección tabular ""Asignación del inventario"" se rellenará de nuevo. ¿Continuar?';tr = '""Stok dağıtımı"" tablo bölümü tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Allocazione delle scorte"" sarà riempita di nuovo. Continuare?';de = 'Der Tabellenteil ""Bestandszuordnung"" wird erneut ausgefüllt. Fortsetzen?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryDistributeByQuantityFragment();
EndProcedure

&AtClient
Procedure InventoryDistributeByQuantityEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryDistributeByQuantityFragment();

EndProcedure

&AtClient
Procedure InventoryDistributeByQuantityFragment()
    
    FillTabularSectionInventoryDistributionByCount();
    
    If Object.Inventory.Count() <> 0 Then
        
        If Items.Inventory.CurrentRow = Undefined Then
            Items.Inventory.CurrentRow = 0;
        EndIf;
        
        TabularSectionName = "Inventory";
        DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
        
    EndIf;

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CostsFillByBalance(Command)
	
	If Object.Costs.Count() <> 0 Then

		QuestionText = NStr("en = 'The ""Expenses"" tabular section will be filled in again.'; ru = 'Табличная часть ""Затраты"" будет перезаполнена!';pl = 'Sekcja tabelaryczna ""Koszty"" zostanie wypełniona ponownie.';es_ES = 'La sección tabular ""Gastos"" se rellenará de nuevo.';es_CO = 'La sección tabular ""Gastos"" se rellenará de nuevo.';tr = '""Masraflar"" tablo bölümü tekrar doldurulacak.';it = 'La sezione tabellare ""Spese"" sarà riempita di nuovo.';de = 'Der Tabellenteil ""Ausgaben"" wird erneut ausgefüllt.'") + Chars.LF;
		QuestionText = QuestionText + NStr("en = 'The ""Expense allocation"" tabular section will be filled in again.'; ru = 'Табличная часть ""Распределение расходов"" будет очищена!';pl = 'Sekcja tabelaryczna ""Alokacja kosztów"" zostanie wyczyszczona.';es_ES = 'La sección tabular ""Asignación de gastos"" se rellenará de nuevo.';es_CO = 'La sección tabular ""Asignación de gastos"" se rellenará de nuevo.';tr = '""Gider tahsisi"" tablo bölümü tekrar doldurulacak.';it = 'La sezione tabellare ""Assegnazione delle spese"" sarà riempita di nuovo.';de = 'Der Tabellenteil ""Kostenzuordnung"" wird erneut ausgefüllt.'") + Chars.LF;
		QuestionText = QuestionText + NStr("en = 'Continue?'; ru = 'Продолжить?';pl = 'Kontynuować?';es_ES = '¿Continuar?';es_CO = '¿Continuar?';tr = 'Devam et?';it = 'Continuare?';de = 'Fortsetzen?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CostsFillByBalanceEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	CostsFillByBalanceFragment();
EndProcedure

&AtClient
Procedure CostsFillByBalanceEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CostsFillByBalanceFragment();

EndProcedure

&AtClient
Procedure CostsFillByBalanceFragment()
    
    FillTabularSectionCostsByBalance();

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CostsDistributeByQuantity(Command)
	                  
	If Object.CostAllocation.Count() <> 0 Then

		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AllocateCostsByQuantityEnd", ThisObject), NStr("en = 'The ""Expense allocation"" tabular section will be filled in again. Continue?'; ru = 'Табличная часть ""Распределение расходов"" будет перезаполнена! Продолжить?';pl = 'Sekcja tabelaryczna ""Alokacja kosztów"" zostanie wypełniona ponownie. Kontynuować?';es_ES = 'La sección tabular ""Asignación de gastos"" se rellenará de nuevo. ¿Continuar?';es_CO = 'La sección tabular ""Asignación de gastos"" se rellenará de nuevo. ¿Continuar?';tr = '""Gider tahsisi"" tablo bölümü tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Assegnazione delle spese"" sarà riempita di nuovo. Continuare?';de = 'Der Tabellenteil ""Kostenzuordnung"" wird erneut ausgefüllt. Fortsetzen?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	AllocateCostsByQuantityFragment();
EndProcedure

&AtClient
Procedure AllocateCostsByQuantityEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    AllocateCostsByQuantityFragment();

EndProcedure

&AtClient
Procedure AllocateCostsByQuantityFragment()
    
    FillTabularSectionCostingByCount();
    
    If Object.Costs.Count() <> 0 Then
        
        If Items.Costs.CurrentRow = Undefined Then
            Items.Costs.CurrentRow = 0;
        EndIf;
        
        TabularSectionName = "Costs";
        DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
        
    EndIf;

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure ProductsFillByOutput(Command)
	
	If Object.Products.Count() <> 0 Then

		Response = Undefined;

		ShowQueryBox(New NotifyDescription("ProductsFillByOutputEnd", ThisObject), NStr("en = 'The ""Products"" tabular section will be filled in again. Continue?'; ru = 'Табличная часть ""Продукция"" будет перезаполнена! Продолжить?';pl = 'Sekcja tabelaryczna ""Towary"" będzie wypełniona ponownie. Kontynuować?';es_ES = 'La sección tabular ""Productos"" se rellenará de nuevo. ¿Continuar?';es_CO = 'La sección tabular ""Productos"" se rellenará de nuevo. ¿Continuar?';tr = '""Ürünler"" tablo bölümü tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Prodotti"" sarà riempita di nuovo. Continuare?';de = 'Der Tabellenabschnitt ""Produkte"" wird erneut ausgefüllt. Fortsetzen?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	ProductsFillByOutputFragment();
EndProcedure

&AtClient
Procedure ProductsFillByOutputEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    ProductsFillByOutputFragment();

EndProcedure

&AtClient
Procedure ProductsFillByOutputFragment()
    
    FillTabularSectionProductsByOutput();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTIONS EVENT HANDLERS

// Procedure - OnActivating event handler of the Costs tabular section.
//
&AtClient
Procedure CostsOnActivateRow(Item)
	
	TabularSectionName = "Costs";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
	
EndProcedure

// Procedure - OnStartEdit event handler of the Costs tabular section.
//
&AtClient
Procedure CostsOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Costs";
	If NewRow Then

		DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
		
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);

EndProcedure

// Procedure - BeforeDeleting event handler of the Costs tabular section.
//
&AtClient
Procedure CostsBeforeDelete(Item, Cancel)

	TabularSectionName = "Costs";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "CostAllocation");

EndProcedure

// Procedure - OnStartEdit event handler of the CostAllocation tabular section.
//
&AtClient
Procedure CostingOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Costs";
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

&AtClient
Procedure CostsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "CostsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Costs");
	EndIf;
	
EndProcedure

&AtClient
Procedure CostsOnActivateCell(Item)
	
	CurrentData = Items.Costs.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Costs.CurrentItem;
		If TableCurrentColumn.Name = "CostsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Costs.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Costs");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CostsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure CostsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Costs", StandardProcessing);
	
EndProcedure

// Procedure - BeforeStartAdding event handler of the CostAllocation tabular section.
//
&AtClient
Procedure CostingBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Costs";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

&AtClient
Procedure CostingSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "CostAllocationGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "CostAllocation");
	EndIf;
	
EndProcedure

&AtClient
Procedure CostingOnActivateCell(Item)
	
	CurrentData = Items.CostAllocation.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.CostAllocation.CurrentItem;
		If TableCurrentColumn.Name = "CostAllocationGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.CostAllocation.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "CostAllocation");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CostingOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure CostingGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.CostAllocation.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "CostAllocation");
	
EndProcedure

// Procedure - OnActivating event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnActivateRow(Item)
	
	TabularSectionName = "Inventory";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
	
EndProcedure

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Inventory";
	If NewRow Then

		DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
		
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

// Procedure - handler of event BeforeDelete of tabular section Inventory.
//
&AtClient
Procedure InventoryBeforeDelete(Item, Cancel)

	TabularSectionName = "Inventory";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "InventoryDistribution");

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

// Procedure - OnStartEdit event handler of the InventoryAllocation tabular section.
//
&AtClient
Procedure InventoryDistributionOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Inventory";
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

// Procedure - BeforeStartEditing event handler of the InventoryAllocation tabular section.
//
&AtClient
Procedure InventoryDistributionBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Inventory";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

&AtClient
Procedure InventoryDistributionSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryDistributionGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "InventoryDistribution");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryDistributionOnActivateCell(Item)
	
	CurrentData = Items.InventoryDistribution.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.InventoryDistribution.CurrentItem;
		If TableCurrentColumn.Name = "InventoryDistributionGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.InventoryDistribution.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "InventoryDistribution");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryDistributionOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryDistributionGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.InventoryDistribution.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "InventoryDistribution");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE PRODUCTS TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;

EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF INVENTORY ALLOCATION TS ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryDistributionProductsOnChange(Item)
	
	TabularSectionRow = Items.InventoryDistribution.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "InventoryDistribution");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "InventoryDistribution", StructureData);
	EndIf;
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryDistributionCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.InventoryDistribution.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF COSTS ALLOCATION TS ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure CostAllocationProductsOnChange(Item)
	
	TabularSectionRow = Items.CostAllocation.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "CostAllocation");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "CostAllocation", StructureData);
	EndIf;
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure CostingCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.CostAllocation.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure CostsGlExpenseAccountOnChange(Item)
	
	CurData = Items.Costs.CurrentData;
	If CurData <> Undefined Then
		
		StructureData = New Structure("
		|TabName,
		|Object,
		|GLExpenseAccount,
		|IncomeAndExpenseItems,
		|IncomeAndExpenseItemsFilled,
		|ExpenseItem");
		StructureData.Object = Object;
		StructureData.TabName = "Costs";
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
	EndIf;
	
EndProcedure

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

#EndRegion

#Region CopyPasteRows

&AtClient
Procedure ProductsCopyRows(Command)
	CopyRowsTabularPart("Products");
EndProcedure

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
Procedure ProductsPasteRows(Command)
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
	
	
	If TabularPartName = "Inventory" Then 
		
		Count = Object[TabularPartName].Count();
		
		For iterator = 1 To CountOfPasted Do
			
			Row = Object[TabularPartName][Count - iterator];
			
			DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
			DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
			
			
			Items[TabularPartName].SelectedRows.Add(Row.GetID());
			
			
		EndDo; 
		
	ElsIf  TabularPartName = "InventoryDistribution"  Then
		
		Count = Object[TabularPartName].Count();
		
		For iterator = 1 To CountOfPasted Do
			
			Row = Object[TabularPartName][Count - iterator];	
			
			DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, "InventoryDistribution");

			Items[TabularPartName].SelectedRows.Add(Row.GetID());

		EndDo; 	
		
		
	EndIf;   	

	
EndProcedure

&AtServer 
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructureData = New Structure;
		
		StructureData.Insert("TabName", TabularPartName);
		StructureData.Insert("Object", Object);
		StructureData.Insert("Products", Row.Products);
		StructureData.Insert("Characteristic", Row.Characteristic);
		StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		
		If UseDefaultTypeOfAccounting And TabularPartName <> "Products" Then
			AddGLAccountsToStructure(ThisObject, TabularPartName, StructureData, Row);
		EndIf;
		
		StructureData = GetDataProductsOnChange(StructureData);
		
		If Not ValueIsFilled(Row.Characteristic) Then
			Row.Characteristic = StructureData.Characteristic;
		EndIf;
		
		
		If TabularPartName = "Inventory" OR TabularPartName = "Products" Then 
			
			If Not ValueIsFilled(Row.MeasurementUnit) Then
				Row.MeasurementUnit = StructureData.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure InventoryCopyRows(Command)
	CopyRowsTabularPart("Inventory"); 
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	PasteRowsTabularPart("Inventory");
EndProcedure

&AtClient
Procedure InventoryDistributionCopyRows(Command)
	CopyRowsTabularPart("InventoryDistribution");
EndProcedure

&AtClient
Procedure InventoryDistributionPasteRows(Command)
	PasteRowsTabularPart("InventoryDistribution");   
EndProcedure

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion