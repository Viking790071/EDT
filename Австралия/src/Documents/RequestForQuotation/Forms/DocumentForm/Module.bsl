#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		False,
		Parameters.FillingValues);
		
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
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
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.RequestForQuotation.TabularSections.Suppliers,
		DataLoadSettings,
		ThisObject);
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.RequestForQuotation.TabularSections.Products,
		ProductsDataLoadSettings,
		ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	Items.SuppliersDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
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

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProducts

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

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Products.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		SelectionParameters = DriveClient.GetMatrixParameters(ThisObject, "Products", False);
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

#Region FormTableItemsEventHandlersSuppliers

&AtClient
Procedure SuppliersContactPersonOnChange(Item)
	
	CurrentData = Items.Suppliers.CurrentData;
	CurrentData.Email = "";
	
	If ValueIsFilled(CurrentData.ContactPerson) Then
		CurrentData.Email = GetContactPersonEmail(CurrentData.ContactPerson);
	EndIf;
	
EndProcedure

&AtClient
Procedure SuppliersCounterpartyOnChange(Item)
	
	CurrentData = Items.Suppliers.CurrentData;
	CurrentData.Email = "";
	
	If ValueIsFilled(CurrentData.Counterparty) Then
		
		CurrentData.ContactPerson = GetDefaultContactPerson(CurrentData.Counterparty);
		
		If ValueIsFilled(CurrentData.ContactPerson) Then
			CurrentData.Email = GetContactPersonEmail(CurrentData.ContactPerson);
		Else
			CurrentData.Email = GetCounterpartyEmail(CurrentData.Counterparty);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName	= "Products";
	DocumentPresentaion	= NStr("en = 'request for quotation'; ru = 'запрос коммерческого предложения';pl = 'zapytanie ofertowe';es_ES = 'solicitud de presupuesto';es_CO = 'solicitud de presupuesto';tr = 'satın alma talebi';it = 'RICHIESTA DI OFFERTA';de = 'Angebotsanfrage'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, False, False);
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
	ShowInputValue(
		New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)),
		CurBarcode,
		NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

// End Peripherals

#EndRegion

#Region Private

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
Procedure CompanyOnChangeAtServer()
	ProcessingCompanyVATNumbers(False);	
EndProcedure

&AtServerNoContext
Function GetDefaultContactPerson(ContactPersonRef)
	
	Return Catalogs.ContactPersons.GetDefaultContactPerson(ContactPersonRef);
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	MeasurementUnit = Common.ObjectAttributeValue(StructureData.Products, "MeasurementUnit");
	
	StructureData.Insert("MeasurementUnit", MeasurementUnit);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetContactPersonEmail(ContactPersonRef)
	
	Return DriveServer.GetContactInformation(ContactPersonRef, Catalogs.ContactInformationKinds.ContactPersonEmail);
	
EndFunction

&AtServerNoContext
Function GetCounterpartyEmail(CounterpartyRef)
	
	Return DriveServer.GetContactInformation(CounterpartyRef, Catalogs.ContactInformationKinds.CounterpartyEmail);
	
EndFunction

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

#Region WorkWithPick

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Products");
			
			If Not IsBlankString(EventLogMonitorErrorText) Then
				WriteErrorReadingDataFromStorage();
			EndIf;
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogClient.AddMessageForEventLog("Error", , EventLogMonitorErrorText);
	
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName)
	
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
		
		EventLogMonitorErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			ErrorText,
			InventoryAddressInStorage,
			TabularSectionName);
		
		Return;
		
	Else
		
		EventLogMonitorErrorText = "";
		
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			TabularSectionName = "Products";
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			// Clear products
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

// Peripherals

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
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
			AND BarcodeData.Count() <> 0 Then
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit = Common.ObjectAttributeValue(BarcodeData.Products, "MeasurementUnit");
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
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			AND BarcodeData.Count() = 0 Then
			
			UnknownBarcodes.Add(CurBarcode);
			
		Else
			
			FilterParameters = New Structure;
			FilterParameters.Insert("Products",			BarcodeData.Products);
			FilterParameters.Insert("Characteristic",	BarcodeData.Characteristic);
			FilterParameters.Insert("MeasurementUnit",	BarcodeData.MeasurementUnit);
			TSRowsArray = Object.Products.FindRows(FilterParameters);
			
			If TSRowsArray.Count() = 0 Then
				
				NewRow = Object.Products.Add();
				FillPropertyValues(NewRow, BarcodeData);
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit),
					BarcodeData.MeasurementUnit,
					BarcodeData.StructureProductsData.MeasurementUnit);
				
				Items.Products.CurrentRow = NewRow.GetID();
				
			Else
				
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				Items.Products.CurrentRow = NewRow.GetID();
				
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
			New Structure("UnknownBarcodes", UnknownBarcodes),
			ThisObject,
			,
			,
			,
			Notification);
		
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
		
		MessageString = NStr("en = 'Barcode is not found: %1; quantity: %2'; ru = 'Данные по штрихкоду не найдены: %1; количество: %2';pl = 'Kod kreskowy nie został znaleziony: %1; ilość: %2';es_ES = 'Código de barras no encontrado: %1; cantidad: %2';es_CO = 'Código de barras no encontrado: %1; cantidad: %2';tr = 'Barkod bulunamadı: %1; miktar: %2';it = 'Il codice a barre non è stato trovato: %1%; quantità:%2%';de = 'Barcode wird nicht gefunden: %1; Menge: %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			MessageString,
			CurUndefinedBarcode.Barcode,
			CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

#EndRegion

#Region LibraryHandlers

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

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure LoadFromFileProducts(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, ProductsDataLoadSettings);
	
	ProductsDataLoadSettings.Insert("TabularSectionFullName",	"RequestForQuotation.Products");
	ProductsDataLoadSettings.Insert("Title",					NStr("en = 'Import products from file'; ru = 'Загрузка запасов из файла';pl = 'Importuj produkty z pliku';es_ES = 'Importar los productos del archivo';es_CO = 'Importar los productos del archivo';tr = 'Ürünleri dosyadan içe aktar';it = 'Importazione articoli da file';de = 'Produkte aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(ProductsDataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure LoadFromFileSuppliers(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"RequestForQuotation.Suppliers");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import suppliers from file'; ru = 'Загрузить поставщиков из файла';pl = 'Importuj dostawców z pliku';es_ES = 'Importar proveedores del archivo';es_CO = 'Importar proveedores del archivo';tr = 'Tedarikçileri dosyadan içe aktar';it = 'Importa fornitori dal file';de = 'Lieferanten aus Datei importieren'"));
	
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
// End StandardSubsystems.DataImportFromExternalSource

#EndRegion