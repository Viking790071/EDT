
#Region GeneralPurposeProceduresAndFunctions

// Recalculate the price of document tabular section.
//
&AtClient
Procedure RefillTabularSectionPricesByPriceKind()
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",			ParentCompany);
	DataStructure.Insert("PriceKind",				Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
		
	For Each TSRow In Object.Inventory Do
		TSRow.Price = 0;
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		TSRow.Products);
		TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		TabularSectionRow.Insert("Price",				0);
		DocumentTabularSection.Add(TabularSectionRow);
	EndDo;
		
	DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
		
	For Each TSRow In DocumentTabularSection Do
  		SearchStructure = New Structure;
		SearchStructure.Insert("Products",		TSRow.Products);
		SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		SearchResult = Object.Inventory.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			ResultRow.Price = TSRow.Price;
			ResultRow.Amount = ResultRow.Quantity * ResultRow.NewPrice - ResultRow.Quantity * ResultRow.Price;
		EndDo;		
	EndDo;
	
EndProcedure

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.Property("PriceKind") Then
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.NewPrice - TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure

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
		
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure;
	
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
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

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServerNoContext
Procedure GetDataStructuralUnitOnChange(StructureData, StructuralUnit)
	
	StructureData.Insert("RetailPriceKind", StructuralUnit.RetailPriceKind);
	StructureData.Insert("PriceCurrency", StructuralUnit.RetailPriceKind.PriceCurrency);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		StructureData.Insert("MarkupGLAccount", StructuralUnit.MarkupGLAccount);
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
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", True);
				StructureProductsData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
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
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
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
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
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

&AtServer
Procedure SetPriceTypesChoiceList()

	WorkWithForm.SetChoiceParametersByCompany(Object.Company, ThisForm, "PriceKind");
	
EndProcedure

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

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
		
	If Object.Inventory.Count() = 0 Then
		NewRow = Object.Inventory.Add();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly  	= Not AllowedEditDocumentPrices;
	Items.InventoryNewPrice.ReadOnly = Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 	= Not AllowedEditDocumentPrices;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	SetIncomeAndExpenseItemsVisibility();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
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
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	LineCount = Object.Inventory.Count();
	
	FilledAtLeastOneColumn = False;
	If LineCount = 1 Then
		FilledAtLeastOneColumn = ValueIsFilled(Object.Inventory[0].Products)
			Or ValueIsFilled(Object.Inventory[0].Characteristic)
			Or ValueIsFilled(Object.Inventory[0].Batch)
			Or ValueIsFilled(Object.Inventory[0].Quantity)
			Or ValueIsFilled(Object.Inventory[0].MeasurementUnit)
			Or ValueIsFilled(Object.Inventory[0].Price)
			Or ValueIsFilled(Object.Inventory[0].NewPrice);
	EndIf;
	
	Items.EditInList.Check = LineCount > 1 OR FilledAtLeastOneColumn;
	
	If LineCount > 0 Then
		Items.Inventory.CurrentRow = Object.Inventory[0].GetID();
	EndIf;
	
	SetEditInListFragmentOption();
	IncomeAndExpenseItemsOnChangeConditions();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
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

// Procedure - EditByList command handler.
//
&AtClient
Procedure EditInList(Command)
	
	SetEditInListOption();

EndProcedure

// Procedure - Set edit by list option.
//
&AtClient
Procedure SetEditInListOption()
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	
	LineCount = Object.Inventory.Count();
	
	FilledAtLeastOneColumn = False;
	If LineCount = 1 Then
		FilledAtLeastOneColumn = ValueIsFilled(Object.Inventory[0].Products)
			OR ValueIsFilled(Object.Inventory[0].Characteristic)
			OR ValueIsFilled(Object.Inventory[0].Batch)
			OR ValueIsFilled(Object.Inventory[0].Quantity)
			OR ValueIsFilled(Object.Inventory[0].MeasurementUnit)
			OR ValueIsFilled(Object.Inventory[0].Price)
			OR ValueIsFilled(Object.Inventory[0].NewPrice);
	EndIf;
	
	If Not Items.EditInList.Check
		  AND (LineCount > 1
		 OR FilledAtLeastOneColumn) Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("SetEditInListEndOption", ThisObject), 
			NStr("en = 'All lines will be hidden. Continue?'; ru = 'Все строки будут свернуты. Продолжить?';pl = 'Wszystkie wiersze zostaną ukryte. Kontynuować?';es_ES = 'Todas las líneas se ocultarán. ¿Continuar?';es_CO = 'Todas las líneas se ocultarán. ¿Continuar?';tr = 'Bütün hatlar gizlenecek. Devam et?';it = 'Tutte le linee saranno nascosti. Continuare?';de = 'Alle Zeilen werden ausgeblendet. Fortsetzen?'"),
			QuestionDialogMode.YesNo
		);
        Return;
	EndIf;
	
	SetEditInListFragmentOption();
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Items.EditInList.Check = True;
        Return;
    EndIf;
    
    RevaluationAmount = Object.Inventory.Total("Amount");
    
    Object.Inventory.Clear();
    NewRow = Object.Inventory.Add();
    NewRow.Amount = RevaluationAmount;
    
    Items.Inventory.CurrentRow = NewRow.GetID();
    
    SetEditInListFragmentOption();

EndProcedure

&AtServer
Procedure SetEditInListFragmentOption()
	
	If Items.EditInList.Check Then
		Items.Inventory.Visible = True;
		Items.InventoryTotalAmount.Visible = True;
		Items.Amount.Visible = False; 
		Items.DecorationSplitter.Visible = False;
	Else
		Items.Inventory.Visible = False;
		Items.InventoryTotalAmount.Visible = False;
		Items.Amount.Visible = True;
		Items.DecorationSplitter.Visible = True;
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
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

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
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	GetDataStructuralUnitOnChange(StructureData, Object.StructuralUnit);
	
	Object.PriceKind = StructureData.RetailPriceKind;
	Object.DocumentCurrency = StructureData.PriceCurrency;
	
	If UseDefaultTypeOfAccounting Then
		Object.Correspondence = StructureData.MarkupGLAccount;
	EndIf;
	
	LineCount = Object.Inventory.Count();
	
	FilledAtLeastOneColumn = False;
	If LineCount = 1 Then
		FilledAtLeastOneColumn = ValueIsFilled(Object.Inventory[0].Products)
			OR ValueIsFilled(Object.Inventory[0].Characteristic)
			OR ValueIsFilled(Object.Inventory[0].Batch)
			OR ValueIsFilled(Object.Inventory[0].Quantity)
			OR ValueIsFilled(Object.Inventory[0].MeasurementUnit)
			OR ValueIsFilled(Object.Inventory[0].Price)
			OR ValueIsFilled(Object.Inventory[0].NewPrice);
	EndIf;
	
	If LineCount > 1 OR FilledAtLeastOneColumn Then 
		RefillTabularSectionPricesByPriceKind();
	EndIf;
	
EndProcedure

&AtClient
Procedure RegisterExpenseOnChange(Item)
	
	If Object.RegisterExpense Then 
		Object.RegisterIncome = False;
		Object.IncomeItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
	Else
		Object.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
	EndIf;
	
	IncomeAndExpenseItemsOnChangeConditions();
	
EndProcedure

&AtClient
Procedure RegisterIncomeOnChange(Item)
	
	If Object.RegisterIncome Then 
		Object.RegisterExpense = False;
		Object.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
	Else
		Object.IncomeItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
	EndIf;
	
	IncomeAndExpenseItemsOnChangeConditions();
	
EndProcedure

&AtClient
Procedure PriceKindOnChange(Item)
	
	SetPriceTypesChoiceList();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure CorrespondenceOnChange(Item)
	
	Structure = New Structure("Object,Correspondence,ExpenseItem,IncomeItem,Manual");
	Structure.Object = Object;
	FillPropertyValues(Structure, Object);
	
	CorrespondenceOnChangeAtServer(Structure);
	
	IncomeAndExpenseItemsOnChangeConditions();
	
EndProcedure

&AtServer
Procedure CorrespondenceOnChangeAtServer(Structure)
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
	SetIncomeAndExpenseItemsVisibility();
	
EndProcedure

&AtServer
Procedure SetIncomeAndExpenseItemsVisibility()
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, 
		"RegisterExpense, RegisterIncome");
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.InventoryNewPrice);
	
	Return Fields;
	
EndFunction

&AtClient
Procedure IncomeAndExpenseItemsOnChangeConditions()
	
	Items.ExpenseItem.Visible = Not UseDefaultTypeOfAccounting
						Or TypeOfCorrespondence(Object.Correspondence) = PredefinedValue("Enum.GLAccountsTypes.OtherExpenses");
	Items.IncomeItem.Visible = Not UseDefaultTypeOfAccounting
						Or TypeOfCorrespondence(Object.Correspondence) = PredefinedValue("Enum.GLAccountsTypes.OtherIncome");
	
	Items.ExpenseItem.Enabled = Object.RegisterExpense;
	Items.IncomeItem.Enabled = Object.RegisterIncome;
	
	If Items.RegisterExpense.Visible Then
		Items.ExpenseItem.TitleLocation = FormItemTitleLocation.None;
	Else
		Items.ExpenseItem.TitleLocation = FormItemTitleLocation.Auto;
	EndIf;
	
	If Items.RegisterIncome.Visible Then
		Items.IncomeItem.TitleLocation = FormItemTitleLocation.None;
	Else
		Items.IncomeItem.TitleLocation = FormItemTitleLocation.Auto;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function TypeOfCorrespondence(Correspondence)
	
	Return Common.ObjectAttributeValue(Correspondence, "TypeOfAccount");
	
EndFunction

#Region EventHandlersOfTheInventoryTabularSectionAttributes

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", ParentCompany);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("DocumentCurrency",  Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", True);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
					
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("Products",   TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("Price",			 TabularSectionRow.Price);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
				
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
				
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
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
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.NewPrice = TabularSectionRow.Amount / TabularSectionRow.Quantity + TabularSectionRow.Price;
	EndIf;
	
EndProcedure

// Procedure - event  handler OnChange input field NewPrice.
//
&AtClient
Procedure InventoryNewPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();

EndProcedure

// Procedure - handler of event BeforeDelete of tabular section Inventory.
//
&AtClient
Procedure InventoryBeforeDelete(Item, Cancel)
	
	If Object.Inventory.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

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

#EndRegion

#EndRegion
