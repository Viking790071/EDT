
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Filter = "modified";
	
	Device               = Parameters.Device;
	
	DeviceSettings = PeripheralsOfflineServerCall.GetDeviceParameters(Device);
	
	EquipmentType        = DeviceSettings.EquipmentType;
	InfobaseNode         = DeviceSettings.InfobaseNode;
	MaximumCode          = DeviceSettings.MaximumCode;
	
	ExchangeRule         = Parameters.ExchangeRule;
	
	PeripheralsOfflineServerCall.RefreshProductProduct(ExchangeRule);
	
	FilterOnChangeAtServer();
	
	If Not ValueIsFilled(InfobaseNode) Then
		Items.ProductsRegisterChanges.Visible                = False;
		Items.GoodsContextMenuRegisterChanges.Visible = False;
	EndIf;
	
	Title = "Products" + " " + NStr("en = 'for'; ru = 'за';pl = 'za';es_ES = 'para';es_CO = 'para';tr = 'için';it = 'per';de = 'für'") + " " + Device;
	
	// Conditional appearance
	SetConditionalAppearance();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure FilterOnChange(Item)
	
	Status(NStr("en = 'Goods table is being updated...'; ru = 'Выполняется обновление таблицы товаров...';pl = 'Trwa aktualizacja tabeli towarów...';es_ES = 'Tabla de mercancías se está actualizando...';es_CO = 'Tabla de mercancías se está actualizando...';tr = 'Mal tablosu güncelleniyor...';it = 'La tabella delle merci è aggiornato ...';de = 'Warentabelle wird aktualisiert...'"));
	
	FilterOnChangeAtServer();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersProducts

&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	SelectedRow = Products.FindByID(SelectedRow);
	If SelectedRow <> Undefined Then
		ShowValue(Undefined, SelectedRow.Products);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RecordChanges(Command)
	
	ErrorDescription = "";
	CodesArray = New Array;
	RowArray = New Array;
	
	For Each SelectedRow In Items.Products.SelectedRows Do
		FoundString = Products.FindByID(SelectedRow);
		RowArray.Add(FoundString);
		CodesArray.Add(FoundString.Code);
	EndDo;
	
	If CodesArray.Count() > 0 Then
		Result = RecordChangesAtServer(CodesArray, ErrorDescription);
		If Result Then
			For Each TSRow In RowArray Do
				TSRow.PictureIndexAreChanges = 1;
			EndDo;
			Notify("Record_CodesOfGoodsPeripheral", New Structure, Undefined);
		Else
			ShowMessageBox(Undefined, NStr("en = 'During the change registration an error occurred:'; ru = 'В процессе регистрации изменений произошла ошибка:';pl = 'Podczas rejestracji zmian wystąpił błąd:';es_ES = 'Durante el registro de cambios se ha ocurrido un error:';es_CO = 'Durante el registro de cambios se ha ocurrido un error:';tr = 'Değişiklik kaydı sırasında bir hata oluştu:';it = 'Durante la registrazione del cambiamento è verificato un errore:';de = 'Während der Änderungsregistrierung trat ein Fehler auf:'") + " " + ErrorDescription);
		EndIf;
	Else
		ShowMessageBox(Undefined, NStr("en = 'Rows for change registration are not selected'; ru = 'Не выбраны строки для регистрации изменений';pl = 'Nie wybrano wierszy do rejestracji zmian';es_ES = 'Filas para el registro de cambios no se han seleccionado';es_CO = 'Filas para el registro de cambios no se han seleccionado';tr = 'Değişiklik kaydı sırasında bir hata oluştu:';it = 'Righe per la registrazione cambiamento non sono selezionati';de = 'Zeilen für die Änderungsregistrierung sind nicht ausgewählt'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsClear(Command)
	
	DeviceArray = New Array;
	DeviceArray.Add(Device);
	
	Completed = 0;
	
	NotificationOnImplementation = New NotifyDescription(
		"ExchangeWithEquipmentEnd",
		ThisObject,
	);
	
	PeripheralsOfflineClient.AsynchronousClearProductsInEquipmentOffline(EquipmentType, DeviceArray, , , NotificationOnImplementation);
	
EndProcedure

&AtClient
Procedure ProductsReload(Command)
	
	DeviceArray = New Array;
	DeviceArray.Add(Device);
	
	Completed = 0;
	
	NotificationOnImplementation = New NotifyDescription(
		"ExchangeWithEquipmentEnd",
		ThisObject,
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(EquipmentType, DeviceArray, , , NotificationOnImplementation, False);
	
EndProcedure

&AtClient
Procedure ExchangeWithEquipmentEnd(Result, Parameters) Export
	
	If Result Then
		FilterOnChangeAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsExport(Command)
	
	DeviceArray = New Array;
	DeviceArray.Add(Device);
	
	Completed = 0;
	
	NotificationOnImplementation = New NotifyDescription(
		"ExportProductsEnd",
		ThisObject,
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(EquipmentType, DeviceArray, , , NotificationOnImplementation, True);
	
EndProcedure

&AtClient
Procedure ExportProductsEnd(Result, Parameters) Export
	
	If Result Then
		Notify("Writing_ExchangeRulesWithPeripheralsOffline", New Structure, Undefined);
		FilterOnChangeAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure TagsPrinting(Command)
	
	AddressInStorage = GetDataToPrintPriceTags();
	If AddressInStorage <> Undefined Then
	
		ParameterStructure = New Structure("AddressInStorage", AddressInStorage);
		
		OpenForm(
			"DataProcessor.PrintLabelsAndTags.Form.Form",
			ParameterStructure,            // Parameters
			,                              // Owner
			New UUID                       // Uniqueness
		);
	
	EndIf;

EndProcedure

&AtClient
Procedure PrintProductCodes(Command)
	
	ObjectsArray = New Array;
	ObjectsArray.Add(New Structure("ExchangeRule, Device", ExchangeRule, Device));
	PrintManagementClient.ExecutePrintCommand(
		"Catalog.ExchangeWithOfflinePeripheralsRules",
		"ProductCodes",
		ObjectsArray,
		Undefined,
		Undefined
	);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	FilterOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure DeleteChangesRegistrationForSelectedStrings(Command)
	
	ErrorDescription = "";
	RowArray = New Array;
	CodesArray = New Array;
	
	For Each SelectedRow In Items.Products.SelectedRows Do
		FoundString = Products.FindByID(SelectedRow);
		RowArray.Add(FoundString);
		CodesArray.Add(FoundString.Code);
	EndDo;
	
	If CodesArray.Count() > 0 Then
		Result = DeleteChangeRecordsAtServer(CodesArray, ErrorDescription);
		If Result Then
			For Each TSRow In RowArray Do
				TSRow.PictureIndexAreChanges = 0;
			EndDo;
			Notify("Record_CodesOfGoodsPeripheral", New Structure, Undefined);
		Else
			ShowMessageBox(Undefined, NStr("en = 'An error occurred during the change registration deletion:'; ru = 'В процессе удаления регистрации изменений произошла ошибка:';pl = 'Podczas usuwania rejestracji zmian wystąpił błąd:';es_ES = 'Ha ocurrido un error durante la eliminación del registro de cambios:';es_CO = 'Ha ocurrido un error durante la eliminación del registro de cambios:';tr = 'Değişiklik kayıt silme işlemi sırasında bir hata oluştu:';it = 'Si è verificato un errore durante la cancellazione di registrazione cambiamento:';de = 'Beim Löschen der Änderungsregistrierung ist ein Fehler aufgetreten:'") + " " + ErrorDescription);
		EndIf;
	Else
		ShowMessageBox(Undefined, NStr("en = 'Rows for change registration deletion are not selected'; ru = 'Не выбраны строки для удаления регистрации изменений';pl = 'Nie wybrano wierszy do usunięcia rejestracji zmian';es_ES = 'Filas para la eliminación del registro de cambios no se han seleccionado';es_CO = 'Filas para la eliminación del registro de cambios no se han seleccionado';tr = 'Değişiklik kayıt silme için satırlar seçili değil';it = 'Righe per il cambiamento di registrazione la cancellazione non sono selezionati';de = 'Zeilen zum Löschen der Änderungsregistrierung sind nicht ausgewählt'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region OnAttributeChange

&AtServer
Procedure FilterOnChangeAtServer()
	
	ExportParameters = PeripheralsOfflineServerCall.GetDeviceParameters(Device);
	
	If Filter = "modified" Then
		ExportParameters.Insert("PartialExport", True);
		Table = PeripheralsOfflineServerCall.GetGoodsTableForExport(Device, ExportParameters);
	ElsIf Filter = "With errors" Then
		ExportParameters.Insert("PartialExport", False);
		Table = PeripheralsOfflineServerCall.GetGoodsTableForExport(Device, ExportParameters).Copy(New Structure("HasErrors", True));
	Else
		ExportParameters.Insert("PartialExport", False);
		Table = PeripheralsOfflineServerCall.GetGoodsTableForExport(Device, ExportParameters);
	EndIf;
	
	If Table <> Undefined Then
		Products.Load(Table);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetDataToPrintPriceTags()
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	ISNULL(CatalogPeripherals.ExchangeRule.StructuralUnit, UNDEFINED) AS StructuralUnit,
	|	ISNULL(CashRegisters.Owner, UNDEFINED) AS Company,
	|	ISNULL(CatalogPeripherals.ExchangeRule.StructuralUnit.RetailPriceKind, UNDEFINED) AS PriceKind
	|FROM
	|	Catalog.Peripherals AS CatalogPeripherals
	|		LEFT JOIN Catalog.CashRegisters AS CashRegisters
	|		ON (CashRegisters.Peripherals = CatalogPeripherals.Ref)
	|WHERE
	|	CatalogPeripherals.Ref = &Device");
	
	Query.SetParameter("Device", Device);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	
	TableProducts = New ValueTable;
	TableProducts.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	TableProducts.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsCharacteristics"));
	TableProducts.Columns.Add("Batch", New TypeDescription("CatalogRef.ProductsBatches"));
	TableProducts.Columns.Add("MeasurementUnit", New TypeDescription("CatalogRef.UOM"));
	TableProducts.Columns.Add("Quantity", New TypeDescription("Number"));
	TableProducts.Columns.Add("Order", New TypeDescription("Number"));
	
	IndexOf = 1;
	For Each SelectedRow In Items.Products.SelectedRows Do
		
		TSRow = Products.FindByID(SelectedRow);
		
		NewRow = TableProducts.Add();
		NewRow.Products = TSRow.Products;
		NewRow.Characteristic = TSRow.Characteristic;
		NewRow.Batch = TSRow.Batch;
		NewRow.MeasurementUnit = TSRow.MeasurementUnit;
		NewRow.Quantity = 1;
		NewRow.Order = IndexOf;
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
	// Prepare actions structure for labels and price tags printing processor
	ActionsStructure = New Structure;
	ActionsStructure.Insert("FillCompany", Selection.Company);
	ActionsStructure.Insert("FillWarehouse", Selection.StructuralUnit);
	ActionsStructure.Insert("FillKindPrices", Selection.PriceKind);
	ActionsStructure.Insert("FillExchangeRule", ExchangeRule);
	ActionsStructure.Insert("ShowColumnNumberOfDocument", True);
	
	ActionsStructure.Insert("SetPrintModeFromDocument");
	ActionsStructure.Insert("SetMode", "TagsPrinting");
	ActionsStructure.Insert("FillOutPriceTagsQuantityOnDocument");
	ActionsStructure.Insert("FillProductsTable");
	
	// Data preparation for filling tabular section of labels and price tags printing processor
	ResultStructure = New Structure;
	ResultStructure.Insert("Inventory", TableProducts);
	ResultStructure.Insert("ActionsStructure", ActionsStructure);
	
	Return PutToTempStorage(ResultStructure);
	
EndFunction

&AtServer
Function RecordChangesAtServer(CodesArray, ErrorDescription = "")
	
	ReturnValue = True;
	
	Try
		BeginTransaction();
		Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
		For Each Code In CodesArray Do
			
			Set.Filter.ExchangeRule.Value = ExchangeRule;
			Set.Filter.ExchangeRule.Use = True;
			
			Set.Filter.Code.Value = Code;
			Set.Filter.Code.Use = True;
			
			ExchangePlans.RecordChanges(InfobaseNode, Set);
			
		EndDo;
		CommitTransaction();
	Except
		ReturnValue = False;
		ErrorDescription = ErrorInfo().Definition;
	EndTry;
	
	Return ReturnValue;
	
EndFunction

&AtServer
Function DeleteChangeRecordsAtServer(CodesArray, ErrorDescription = "")
	
	ReturnValue = True;
	
	Try
		BeginTransaction();
		Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
		For Each Code In CodesArray Do
			
			Set.Filter.ExchangeRule.Value = ExchangeRule;
			Set.Filter.ExchangeRule.Use = True;
			
			Set.Filter.Code.Value = Code;
			Set.Filter.Code.Use = True;
			
			ExchangePlans.DeleteChangeRecords(InfobaseNode, Set);
			
		EndDo;
		CommitTransaction();
		
		If Filter = "modified" Then
			FilterOnChangeAtServer();
		EndIf;
		
	Except
		ReturnValue = False;
		ErrorDescription = ErrorInfo().Definition;
	EndTry;
	
	Return ReturnValue;
	
EndFunction

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorRed	= WebColors.Red;
	ColorAuto	= New Color();

	// Offline cash register
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Barcode");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Used");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("EquipmentType");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.PeripheralTypes.CashRegistersOffline;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRed);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<Barcode not defined>'; ru = '<Штрихкод не определен>';pl = '<Nie określono kodu kreskowego>';es_ES = '<Código de barras no definido>';es_CO = '<Código de barras no definido>';tr = '<Barkod belirlenmedi>';it = '<Codice a barre non definito>';de = '<Barcode nicht definiert>'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProductsBarcode");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Offline cash register'; ru = 'ККМ Offline';pl = 'Kasa fiskalna offline';es_ES = 'Caja registradora offline';es_CO = 'Caja registradora offline';tr = 'Çevrimdışı yazar kasa';it = 'Registratore di cassa Offline';de = 'Offline-Kasse'");
	
	// Scales
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Barcode");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Used");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("EquipmentType");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.PeripheralTypes.LabelsPrintingScales;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorAuto);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<Barcode will be generated during exporting>'; ru = '<Штрихкод будет создан во время выгрузки>';pl = '<Kod kreskowy zostanie wygenerowany podczas eksportowania>';es_ES = '<Código de barras se generará durante la exportación>';es_CO = '<Código de barras se generará durante la exportación>';tr = '<Barkod dışa aktarım esnasında oluşturulacaktır>';it = '<Il codice a barre sarà generato durante l''esportazione>';de = '<Barcode wird während Export generiert>'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProductsBarcode");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Scales'; ru = 'Весы';pl = 'Wagi';es_ES = 'Escalas';es_CO = 'Escalas';tr = 'Ölçekler';it = 'Bilance';de = 'Waagen'");
	
	// ProductsPrice
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Price");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Used");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRed);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<Price not defined>'; ru = '<Цена не определена>';pl = '<Nie określono ceny>';es_ES = '<Precio no definido>';es_CO = '<Precio no definido>';tr = '<Fiyat belirlenmedi>';it = '<Prezzo non definito>';de = '<Preis nicht definiert>'"));
	ItemAppearance.Appearance.SetParameterValue("HorizontalAlign", HorizontalAlign.Left);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProductsPrice");
	FieldAppearance.Use = True;
	
	// ProductsDescription
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Description");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Used");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRed);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<Desciption not defined>'; ru = '<Описание не определено>';pl = '<Nie określono opisu>';es_ES = '<Descripción no definida>';es_CO = '<Descripción no definida>';tr = '<Tanım belirlenmedi>';it = '<Descrizione non definita>';de = '<Beschreibung nicht definiert>'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProductsDescription");
	FieldAppearance.Use = True;
	
	// ProductsCode
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Code");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Greater;
	DataFilterItem.RightValue		= New DataCompositionField("MaximumCode");
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("MaximumCode");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue		= 0;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRed);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProductsCode");
	FieldAppearance.Use = True;
	
	// Products
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Used");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorAuto);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Products");
	FieldAppearance.Use = True;
	
	// ProductsTextNeededSeriesIndication
	
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.NeededSeriesIndication");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Products.Used");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRed);
	ItemAppearance.Appearance.SetParameterValue(
		"Text", 
		NStr("en = '<You need to specify series of the product on shipment to retail from this warehouse>'; ru = '<При отгрузке в розницу с этого склада необходимо указать серию номенклатуры>';pl = '<Musisz wybrać serie produktu do wysyłki do sprzedaży detalicznej z tego magazynu>';es_ES = '<Es necesario especificar la serie del producto que se envía a la venta al por menor desde este almacén>';es_CO = '<Es necesario especificar la serie del producto que se envía a la venta al por menor desde este almacén>';tr = '<Bu ambardan perakendeye teslim esnasında ürünün serisini belirtmeniz gerekli>';it = '<è necessario specificare le serie di articoli in spedizione per la vendita al dettaglio da questo magazzino>';de = '<Sie sollen Serien des Product zur Lieferung für Einzelhandel aus diesem Lager eingeben>'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProductsTextNeededSeriesIndication");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion
