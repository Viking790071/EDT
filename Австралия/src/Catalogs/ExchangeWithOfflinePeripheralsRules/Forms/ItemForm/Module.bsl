
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Configure();
	
	Items.Pages.CurrentPage = Items.PageSelectionChanged;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ProductQuantity = Products.Count();
	If ProductQuantity > 0 Then
		If Products[ProductQuantity-1].Code > CurrentObject.MaximumCode AND CurrentObject.MaximumCode <> 0 Then
			CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'In the Goods tabular section, rows with a code that exceeds the maximum allowed value are detected: %1. Edit a maximum code or reduce the number of goods for export using filter.'; ru = 'В табличной части ""Товары"" найдены строки с кодом, превышающим максимальное допустимое значение: %1. Измените максимальный код или уменьшите количество товаров к выгрузке при помощи отбора.';pl = 'W sekcji tabelarycznej Towary wykryto wiersze z kodem przekraczającym maksymalną dozwoloną wartość: %1. Edytuj maksymalny kod lub zmniejsz liczbę towarów do eksportu za pomocą filtru.';es_ES = 'En la sección tabular de Mercancías, filas con un código que excede el valor máximo permitido, se han detectado: %1. Editar un código máximo, o reducir la cantidad de mercancías para exportar utilizando el filtro.';es_CO = 'En la sección tabular de Mercancías, filas con un código que excede el valor máximo permitido, se han detectado: %1. Editar un código máximo, o reducir la cantidad de mercancías para exportar utilizando el filtro.';tr = '""Ürünler"" tablo bölümünde, maksimum olabilecek değerini aşan kodlu satırlar bulundu:%1. Maksimum kodunu değiştirin veya dışa aktarılacak ürün sayısını filtre yardımı ile azaltın.';it = 'Nella sezione ""Merci"" della tabella sono state trovate righe con codice che supera il valore massimo consentito: %1. Modificare il codice massimo o ridurre la quantità di merci da scaricare usando un filtro.';de = 'Im Tabellenabschnitt ""Waren"" werden Zeilen mit einem Code gefunden, der den maximal zulässigen Wert überschreitet: %1. Bearbeiten Sie einen maximalen Code oder reduzieren Sie die Anzahl der Waren für den Export mit Filter.'"), CurrentObject.MaximumCode),,"Products",,Cancel);
			Return;
		EndIf;
	EndIf;
	
	If ProductsDataIsRead Then
		UpdateListOfProductsOnServer();
	EndIf;
	
	CurrentObject.DataCompositionSettings = New ValueStorage(SettingsComposer.GetSettings());

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ProductsDataIsRead Then
		
		If Products.Count() > 0 Then
			ApplyChangesToServer(CurrentObject);
		Else
			PeripheralsOfflineServerCall.RefreshProductProduct(CurrentObject.Ref);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Writing_ExchangeRulesWithPeripheralsOffline", WriteParameters, Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure LinkerSettingsOnChangeSettingsSelection(Item)
	Items.Pages.CurrentPage = Items.PageSelectionChanged;
	SelectionChanged = True;
EndProcedure

&AtClient
Procedure PeripheralsTypeOnChange(Item)
	
	Configure();
	Items.Pages.CurrentPage = Items.PageSelectionChanged;
	
EndProcedure

&AtClient
Procedure MaximumCodeOnChange(Item)
	
	// Maximum Changed  code - control is required.
	Status(NStr("en = 'Updating the goods list...'; ru = 'Выполняется обновление списка товаров...';pl = 'Aktualizacja listy towarów...';es_ES = 'Actualizando la lista de mercancías...';es_CO = 'Actualizando la lista de mercancías...';tr = 'Mal listesi güncelleniyor...';it = 'Aggiornamento dell''elenco merci ...';de = 'Aktualisierung der Warenliste...'"));
	UpdateListOfProductsOnServer();
	Items.Pages.CurrentPage = Items.PageProductsList;
	
EndProcedure

&AtClient
Procedure PrefixWeightGoodsOnChange(Item)
	Items.Pages.CurrentPage = Items.PageSelectionChanged;
EndProcedure

&AtClient
Procedure PeripheralsTypeCleaning(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersProducts

&AtClient
Procedure ProductsOnActivateCell(Item)
	
	If TypeOf(Item)=Type("FormTable") AND TypeOf(Item.CurrentItem)=Type("FormField") Then
		
		Name = Item.CurrentItem.Name;
		
		If Item.CurrentData = Undefined Then
			Return;
		EndIf;
		
		If Name = "ProductsCode" Then
			
			OldCode = Items.Products.CurrentData.Code;
			Items.ProductsCode.ChoiceList.LoadValues(FreeCodes());
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsOnStartEdit(Item, NewRow, Copy)
	
	OldCode = Items.Products.CurrentData.Code;
	
EndProcedure

&AtClient
Procedure ProductsBeforeEndOfEditing(Item, NewRow, CancelEdit, Cancel)
	
	CurrentData = Items.Products.CurrentData;
	
	If CurrentData.Code = OldCode Then
		Return;
	EndIf;
	
	If Not CancelEdit Then
		
		FoundString = FindRowOfProductsWithCode(CurrentData.Code, CurrentData.GetID());
		If FoundString <> Undefined Then
			
			FoundString = Products.FindByID(FoundString);
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'This code is already assigned for products %1'; ru = 'Такой код уже назначен для номенклатуры %1';pl = 'Ten kod jest już przypisany do produktów %1';es_ES = 'Este código se ha ya asignado a los productos %1';es_CO = 'Este código se ha ya asignado a los productos %1';tr = 'Bu kod ürünler için zaten atandı%1';it = 'Questo codice è già stato assegnato all''articolo %1';de = 'Dieser Code ist bereits für Produkte vergeben %1'"),
				FoundString.Products)
				+ ?(ValueIsFilled(FoundString.Characteristic), " " + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Variant: %1'; ru = 'Вариант: %1';pl = 'Wariant: %1';es_ES = 'Variante: %1';es_CO = 'Variante: %1';tr = 'Varyant: %1';it = 'Variante: %1';de = 'Variante: %1'"),
						FoundString.Characteristic),
					"")
				+ ?(ValueIsFilled(FoundString.Batch), " " + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Batch: %1'; ru = 'Партия: %1';pl = 'Partia: %1';es_ES = 'Paquete: %1';es_CO = 'Paquete: %1';tr = 'Parti: %1';it = 'Lotto: %1';de = 'Charge: %1'"),
						FoundString.Batch),
					"")
				+ ?(ValueIsFilled(FoundString.MeasurementUnit), " " + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Measurement unit: %1'; ru = 'Единица измерения: %1';pl = 'Jednostka miary: %1';es_ES = 'Unidad de medida: %1';es_CO = 'Unidad de medida: %1';tr = 'Ölçü birimi: %1';it = 'Unità di misura: %1';de = 'Maßeinheit: %1'"),
						FoundString.MeasurementUnit), 
					"")
				+ NStr("en = '. Places are exchanged.'; ru = '. Выполнен обмен местами.';pl = '. Wymiana miejsc.';es_ES = '. Sitios se han intercambiado.';es_CO = '. Sitios se han intercambiado.';tr = '.Yerler değiştirildi.';it = '. I posti sono stati cambiati.';de = '. Orte werden ausgetauscht.'");
			
			CurrentData.ChangedByUser = True;
			FoundString.ChangedByUser = True;
			
			TempStructure = StringStructure(FoundString);
			FillPropertyValues(FoundString, CurrentData,, "Code, ChangedByUser");
			CurrentData.Code = OldCode;
			FillPropertyValues(CurrentData, TempStructure);
			
			Items.Products.CurrentRow = FoundString.GetID();
			
			If ValueIsFilled(FoundString.Products) Then
				ShowMessageBox(, ErrorDescription);
			EndIf;
			
		Else
			
			CurrentData.New				= True;
			CurrentData.ChangedByUser	= True;
			HandleChangingProductCodeOnServer(CurrentData.Code);
			
		EndIf;
		
	Else
		CurrentData.Code = OldCode;
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure ProductsBeforeDeleting(Item, Cancel)
	
	Cancel = True;
	
	If Not EditingProductsCodesAvailable Then
		Return;
	EndIf;
	
	For Each SelectedRow In Items.Products.SelectedRows Do
		CurrentData = Products.FindByID(SelectedRow);
		If ValueIsFilled(CurrentData.Products) AND CurrentData.Used Then
			ShowMessageBox(, (NStr("en = 'After deletion, new product codes will be assigned to products that meet the specified filter.'; ru = 'Номенклатуре, соответствующей заданному отбору, после удаления будут заново назначены коды товаров.';pl = 'Po usunięciu nowe kody produktów zostaną przypisane do produktów, które spełniają kryteria filtru.';es_ES = 'Después de haber borrado, nuevos códigos de productos se asignarán a los productos que cumplen el filtro especificado.';es_CO = 'Después de haber borrado, nuevos códigos de productos se asignarán a los productos que cumplen el filtro especificado.';tr = 'Belirlenen filtreye uygun ürünler için, silindikten sonra yeniden ürün kodları atanacak.';it = 'Dopo l''eliminazione, nuovi codice articolo saranno assegnati agli articoli che corrispondono ai filtri specificati.';de = 'Nach dem Löschen werden neue Produktcodes den Produkten zugewiesen, die den angegebenen Filter erfüllen.'")));
			Break;
		EndIf;
	EndDo;
	
	// Changing data by users
	For Each SelectedRow In Items.Products.SelectedRows Do
		
		CurrentData = Products.FindByID(SelectedRow);
		
		If Not ValueIsFilled(CurrentData.Products) Then
			// Data in the row have been cleared already
			Continue;
		EndIf;
		
		CurrentData.Products   = Undefined;
		CurrentData.Characteristic = Undefined;
		CurrentData.Batch = Undefined;
		CurrentData.MeasurementUnit = Undefined;
		CurrentData.Used   = Undefined;
		CurrentData.Description   = Undefined;
		CurrentData.Weight        = Undefined;
		CurrentData.Barcode       = Undefined;
		CurrentData.Price           = Undefined;
		
		CurrentData.ChangedByUser = True;
		
	EndDo;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field <> Items.ProductsCode Then
		
		SelectedRow = Products.FindByID(SelectedRow);
		If SelectedRow <> Undefined Then
			ShowValue(, SelectedRow.Products);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateProductsList(Command)
	
	Status(NStr("en = 'Updating the goods list...'; ru = 'Выполняется обновление списка товаров...';pl = 'Aktualizacja listy towarów...';es_ES = 'Actualizando la lista de mercancías...';es_CO = 'Actualizando la lista de mercancías...';tr = 'Mal listesi güncelleniyor...';it = 'Aggiornamento dell''elenco merci ...';de = 'Aktualisierung der Warenliste...'"));
	RefreshListOfGoodsAtServerReOpen();
	
EndProcedure

&AtClient
Procedure ShowProductList(Command)
	
	Status(NStr("en = 'Updating the goods list...'; ru = 'Выполняется обновление списка товаров...';pl = 'Aktualizacja listy towarów...';es_ES = 'Actualizando la lista de mercancías...';es_CO = 'Actualizando la lista de mercancías...';tr = 'Mal listesi güncelleniyor...';it = 'Aggiornamento dell''elenco merci ...';de = 'Aktualisierung der Warenliste...'"));
	UpdateListOfProductsOnServer();
	Items.Pages.CurrentPage = Items.PageProductsList;
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	// Change data
	For Each SelectedRow In Items.Products.SelectedRows Do
		
		CurrentData = Products.FindByID(SelectedRow);
		IndexOfCurrentRow = Products.IndexOf(CurrentData);
		If IndexOfCurrentRow > 0 Then
			
			PurposeRow = Products[IndexOfCurrentRow-1];
			
			PurposeRow.ChangedByUser = True;
			CurrentData.ChangedByUser = True;
			
			Code = PurposeRow.Code;
			PurposeRow.Code = CurrentData.Code;
			CurrentData.Code = Code;
			
			Products.Move(IndexOfCurrentRow,-1);
			
		Else
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	// Changing data by users
	Quantity = Items.Products.SelectedRows.Count()-1;
	For LineNumber = 0 To Quantity Do
		
		CurrentData = Products.FindByID(Items.Products.SelectedRows[Quantity-LineNumber]);
		
		IndexOfCurrentRow = Products.IndexOf(CurrentData);
		If IndexOfCurrentRow < Products.Count()-1 Then
			
			PurposeRow = Products[IndexOfCurrentRow+1];
			
			PurposeRow.ChangedByUser = True;
			CurrentData.ChangedByUser = True;
			
			Code = PurposeRow.Code;
			PurposeRow.Code = CurrentData.Code;
			CurrentData.Code = Code;
			
			Products.Move(IndexOfCurrentRow,1);
			
		Else
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RestoreSelectionSettingsByDefault(Command)
	ImportFilterSettingsByDefault();
EndProcedure

&AtClient
Procedure DeleteFreeGoodsCodesInListEnd(Command)
	
	If Products.Count() > 0 Then
		TSRow = Products[Products.Count() - 1];
		If Not ValueIsFilled(TSRow.Products) Then
			RemoveFreeCodesProductsOnServer();
		Else
			ShowMessageBox(Undefined,NStr("en = 'No data to delete'; ru = 'Нет данных для удаления';pl = 'Brak danych do usunięcia';es_ES = 'No hay datos para borrar';es_CO = 'No hay datos para borrar';tr = 'Silinecek veri yok';it = 'Nessun dato da cancellare';de = 'Keine Daten zum Löschen'"));
		EndIf;
	Else
		ShowMessageBox(Undefined,NStr("en = 'No data to delete'; ru = 'Нет данных для удаления';pl = 'Brak danych do usunięcia';es_ES = 'No hay datos para borrar';es_CO = 'No hay datos para borrar';tr = 'Silinecek veri yok';it = 'Nessun dato da cancellare';de = 'Keine Daten zum Löschen'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Other

&AtServer
Function FreeCodes()
	
	FreeCodes = New Array;
	ProductQuantity = Products.Count();
	If ProductQuantity > 0 Then
		
		For Each TSRow In Products.FindRows(New Structure("Products", Catalogs.Products.EmptyRef())) Do
			FreeCodes.Add(TSRow.Code);
		EndDo;
		If ValueIsFilled(Products[ProductQuantity-1].Products) Then
			FreeCodes.Add(Products[ProductQuantity-1].Code + 1);
		EndIf;
		
	EndIf;
	
	Return FreeCodes;
	
EndFunction

&AtServer
Procedure ImportFilterSettingsByDefault()
	
	If Object.PeripheralsType = Enums.PeripheralTypes.CashRegistersOffline Then
		DataCompositionSchema = Catalogs.ExchangeWithOfflinePeripheralsRules.GetTemplate("CRProductCodesUpdate");
	ElsIf Object.PeripheralsType = Enums.PeripheralTypes.LabelsPrintingScales Then
		DataCompositionSchema = Catalogs.ExchangeWithOfflinePeripheralsRules.GetTemplate("PLUProductCodesUpdate");
	Else
		Raise NStr("en = 'Incorrect peripherals type'; ru = 'Некорректный тип подключаемого оборудования';pl = 'Nieprawidłowy typ urządzeń peryferyjnych';es_ES = 'Tipo de periféricos incorrecto';es_CO = 'Tipo de periféricos incorrecto';tr = 'Bağlanan ekipmanın türü yanlış';it = 'Tipo di periferiche non corretto';de = 'Falscher Peripherietyp'");
	EndIf;
	
	SettingsComposer.Initialize(
		New DataCompositionAvailableSettingsSource(PutToTempStorage(DataCompositionSchema, UUID))
	);
	
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	
EndProcedure

&AtServer
Procedure Configure()
	
	If Object.PeripheralsType = Enums.PeripheralTypes.CashRegistersOffline Then
		DataCompositionSchema = Catalogs.ExchangeWithOfflinePeripheralsRules.GetTemplate("CRProductCodesUpdate");
	ElsIf Object.PeripheralsType = Enums.PeripheralTypes.LabelsPrintingScales Then
		DataCompositionSchema = Catalogs.ExchangeWithOfflinePeripheralsRules.GetTemplate("PLUProductCodesUpdate");
	Else
		Raise NStr("en = 'Incorrect peripherals type'; ru = 'Некорректный тип подключаемого оборудования';pl = 'Nieprawidłowy typ urządzeń peryferyjnych';es_ES = 'Tipo de periféricos incorrecto';es_CO = 'Tipo de periféricos incorrecto';tr = 'Bağlanan ekipmanın türü yanlış';it = 'Tipo di periferiche non corretto';de = 'Falscher Peripherietyp'");
	EndIf;
	
	SettingsComposer.Initialize(
		New DataCompositionAvailableSettingsSource(PutToTempStorage(DataCompositionSchema, UUID))
	);
	
	If ValueIsFilled(Object.Ref) Then
		
		Query = New Query(
		"SELECT
		|	ExchangeWithOfflinePeripheralsRules.DataCompositionSettings AS DataCompositionSettings
		|FROM
		|	Catalog.ExchangeWithOfflinePeripheralsRules AS ExchangeWithOfflinePeripheralsRules
		|WHERE
		|	ExchangeWithOfflinePeripheralsRules.Ref = &ExchangeRule");
		
		Query.SetParameter("ExchangeRule", Object.Ref);
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		If Selection.Next() Then
			DataCompositionSettings = Selection.DataCompositionSettings.Get();
			If ValueIsFilled(DataCompositionSettings) Then
				SettingsComposer.LoadSettings(DataCompositionSettings);
			Else
				SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
			EndIf;
		EndIf;
		
	Else
		SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	EndIf;
	
	SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	
	Items.WeighingUnits.Visible = Object.PeripheralsType = Enums.PeripheralTypes.LabelsPrintingScales;
	Items.WeightProductPrefix.Visible = Object.PeripheralsType = Enums.PeripheralTypes.LabelsPrintingScales;
	
	EditingProductsCodesAvailable = IsInRole("FullRights") OR Object.PeripheralsType = Enums.PeripheralTypes.LabelsPrintingScales;
	
	Items.ProductsDelete.Enabled                         = EditingProductsCodesAvailable;
	Items.ProductsMoveDown.Enabled                 = EditingProductsCodesAvailable;
	Items.ProductsMoveUp.Enabled                = EditingProductsCodesAvailable;
	Items.ProductsContextMenuDelete.Enabled          = EditingProductsCodesAvailable;
	Items.GoodsContextMenuMoveUp.Enabled = EditingProductsCodesAvailable;
	Items.ProductsContextMenuMoveDown.Enabled  = EditingProductsCodesAvailable;
	Items.ProductsCode.ReadOnly                          = Not EditingProductsCodesAvailable;
	
	Items.ProductsDeleteFreeCodesEndOfTheListGoods.Visible = IsInRole("FullRights");
	
EndProcedure

&AtServer
Function AddressLinkerSettingsITemporaryStorage()
	
	AddressLinkerSettingsITemporaryStorage = PutToTempStorage(SettingsComposer.GetSettings());
	
	Return AddressLinkerSettingsITemporaryStorage;
	
EndFunction

&AtServer
Procedure WriteCodeInTable(Table, Data, Code, Used)
	
	VTRow = Table.Find(Code, "Code");
	If VTRow = Undefined Then
		VTRow = Table.Add();
		VTRow.New = True;
	EndIf;
	
	VTRow.ChangedAutomatically = True;
	
	FillPropertyValues(VTRow, Data);
	
	VTRow.Code             = Code;
	VTRow.Used    = Used;
	
EndProcedure

&AtServer
Function ProductsTable(Products, PriceKind)
	
	Query = New Query(
	"SELECT
	|	ProductCodes.Code AS Code,
	|	ProductCodes.New AS New,
	|	ProductCodes.ChangedByUser AS ChangedByUser,
	|	ProductCodes.ChangedAutomatically AS ChangedAutomatically,
	|	ProductCodes.Used AS Used,
	|	ProductCodes.Products AS Products,
	|	ProductCodes.Characteristic AS Characteristic,
	|	ProductCodes.Batch AS Batch,
	|	ProductCodes.MeasurementUnit AS MeasurementUnit
	|INTO ProductCodes
	|FROM
	|	&ValueTable AS ProductCodes
	|INDEX BY ProductCodes.Products, ProductCodes.Characteristic, ProductCodes.Batch, ProductCodes.MeasurementUnit
	|;
	|
	|SELECT ALLOWED
	|	ProductCodes.New AS New,
	|	ProductCodes.ChangedByUser AS ChangedByUser,
	|	ProductCodes.ChangedAutomatically AS ChangedAutomatically,
	|	ProductCodes.Used AS Used,
	|	ProductCodes.Code AS Code,
	|	ProductCodes.Products AS Products,
	|	ISNULL(ProductCodes.Products.Description,"""") AS ProductsDescription,
	|	ISNULL(ProductCodes.Products.DescriptionFull,"""") AS ProductsDescriptionFull,
	|	ProductCodes.Characteristic AS Characteristic,
	|	ISNULL(ProductCodes.Characteristic.Description,"""") AS CharacteristicDescription,
	|	ISNULL(ProductCodes.Characteristic.Description,"""") AS CharacteristicDescriptionFull,
	|	ProductCodes.Batch AS Batch,
	|	ISNULL(ProductCodes.Batch.Description,"""") AS BatchDescription,
	|	ProductCodes.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(ProductCodes.MeasurementUnit.Description, """") AS MeasurementUnitDescription,
	|	ISNULL(Barcodes.Barcode, """") AS Barcode,
	|	(ISNULL(ProductCodes.MeasurementUnit.Factor, 1)
	|		/ ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1)) *
	|	ISNULL(PricesSliceLast.Price, 0) AS Price,
	|	TRUE AS Weight
	|FROM
	|	ProductCodes AS ProductCodes
	|		LEFT JOIN InformationRegister.Barcodes AS Barcodes
	|		ON ProductCodes.Products = Barcodes.Products
	|			AND ProductCodes.Characteristic = Barcodes.Characteristic
	|			AND ProductCodes.Batch = Barcodes.Batch
	|			AND ProductCodes.MeasurementUnit = Barcodes.MeasurementUnit
	|			AND &LabelsWithPrintScales
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&CurrentDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON ProductCodes.Products = PricesSliceLast.Products
	|			AND ProductCodes.Characteristic = PricesSliceLast.Characteristic
	|TOTALS
	|	MAX(Barcode)
	|BY
	|	Code");
	
	ReplaceString = "TRUE";
	
	If Parameters.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales Then
		ReplaceString = "Barcodes.Barcode LIKE & BarcodeFormat";
		Query.SetParameter("BarcodeFormat", InformationRegisters.Barcodes.WeightBarcodeFormat(Parameters.WeightProductPrefix));
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&LabelsWithPrintScales", ReplaceString);

	Query.SetParameter("PriceKind",		PriceKind);
	Query.SetParameter("CurrentDate",	EndOfDay(CurrentSessionDate()));
	Query.SetParameter("ValueTable",	Products);
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("Used",          New TypeDescription("Boolean"));
	ProductsTable.Columns.Add("Code",                   New TypeDescription("Number"));
	ProductsTable.Columns.Add("Products",          New TypeDescription("CatalogRef.Products"));
	ProductsTable.Columns.Add("Characteristic",        New TypeDescription("CatalogRef.ProductsCharacteristics"));
	ProductsTable.Columns.Add("Batch",                New TypeDescription("CatalogRef.ProductsBatches"));
	ProductsTable.Columns.Add("MeasurementUnit",      New TypeDescription("CatalogRef.UOM"));
	ProductsTable.Columns.Add("Description",          New TypeDescription("String"));
	ProductsTable.Columns.Add("DescriptionFull",    New TypeDescription("String"));
	ProductsTable.Columns.Add("Barcode",              New TypeDescription("String"));
	ProductsTable.Columns.Add("Price",                  New TypeDescription("Number"));
	ProductsTable.Columns.Add("Weight",               New TypeDescription("Boolean"));
	ProductsTable.Columns.Add("New",                 New TypeDescription("Boolean"));
	ProductsTable.Columns.Add("ChangedByUser", New TypeDescription("Boolean"));
	ProductsTable.Columns.Add("ChangedAutomatically", New TypeDescription("Boolean"));
	
	SelectionOnCodes = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionOnCodes.Next() Do
		
		NewRow = ProductsTable.Add();
		
		Selection = SelectionOnCodes.Select();
		While Selection.Next() Do
			
			If Not ValueIsFilled(NewRow.Code) Then
				NewRow.Used          = Selection.Used;
				NewRow.Code                   = Selection.Code;
				NewRow.Products          = Selection.Products;
				NewRow.Characteristic        = Selection.Characteristic;
				NewRow.Batch                = Selection.Batch;
				NewRow.MeasurementUnit              = Selection.MeasurementUnit;
				NewRow.Description          = DriveServer.GetProductsPresentationForPrinting(
						Selection.ProductsDescription,
						Selection.CharacteristicDescription)
					+ ?(ValueIsFilled(Selection.MeasurementUnitDescription),
						", (" + Selection.MeasurementUnitDescription + ")",
						""
				);
				NewRow.DescriptionFull          =  DriveServer.GetProductsPresentationForPrinting(
						Selection.ProductsDescriptionFull,
						Selection.CharacteristicDescriptionFull)
					+ ?(ValueIsFilled(Selection.MeasurementUnitDescription),
						", (" + Selection.MeasurementUnitDescription + ")",
						""
				);
				NewRow.Price                  = Selection.Price;
				NewRow.Barcode              = TrimAll(Selection.Barcode);
				NewRow.Weight               = Selection.Weight;
				NewRow.New                 = Selection.New;
				NewRow.ChangedByUser = Selection.ChangedByUser;
				NewRow.ChangedAutomatically = Selection.ChangedAutomatically;
			Else
				NewRow.Barcode = NewRow.Barcode + ", " + TrimAll(Selection.Barcode);
			EndIf;
			
		EndDo;
		
	EndDo;
	
	ProductsTable.Sort("Code");
	Return ProductsTable;
	
EndFunction

&AtServer
Procedure ExportIDFromRegister(CurrentObject)
	
	Table = PeripheralsOfflineServerCall.GetGoodsTableForRule(CurrentObject.Ref, CurrentObject.StructuralUnit.RetailPriceKind);
	
	If Table <> Undefined Then
		Products.Load(Table);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateProductsTable(ProductCodes, ExchangeRule, PriceKind, AdressOnSettings)
	
	If Object.PeripheralsType = Enums.PeripheralTypes.CashRegistersOffline Then
		DataCompositionSchema = Catalogs.ExchangeWithOfflinePeripheralsRules.GetTemplate("CRProductCodesUpdate");
	ElsIf Object.PeripheralsType = Enums.PeripheralTypes.LabelsPrintingScales Then
		DataCompositionSchema = Catalogs.ExchangeWithOfflinePeripheralsRules.GetTemplate("PLUProductCodesUpdate");
	Else
		Raise NStr("en = 'Incorrect peripherals type'; ru = 'Некорректный тип подключаемого оборудования';pl = 'Nieprawidłowy typ urządzeń peryferyjnych';es_ES = 'Tipo de periféricos incorrecto';es_CO = 'Tipo de periféricos incorrecto';tr = 'Bağlanan ekipmanın türü yanlış';it = 'Tipo di periferiche non corretto';de = 'Falscher Peripherietyp'");
	EndIf;
	
	// Preparation of layout compositing of data composition, importing settings
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Composer.LoadSettings(GetFromTempStorage(AdressOnSettings));
	Composer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	
	// Filling out the report structure and selected fields.
	Composer.Settings.Structure.Clear();
	
	GroupDetailedRecords = Composer.Settings.Structure.Add(Type("DataCompositionGroup"));
	GroupDetailedRecords.Use = True;
	
	Composer.Settings.Selection.Items.Clear();
	
	SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField("Products");
	SelectedField.Use = True;
	
	If GetFunctionalOption("UseCharacteristics") Then
		SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedField.Field          = New DataCompositionField("Characteristic");
		SelectedField.Use = True;
	EndIf;
	
	If GetFunctionalOption("UseBatches") Then
		SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedField.Field          = New DataCompositionField("Batch");
		SelectedField.Use = True;
	EndIf;
	
	If GetFunctionalOption("UseSeveralUnitsForProduct") Then
		SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedField.Field          = New DataCompositionField("MeasurementUnit");
		SelectedField.Use = True;
	EndIf;
	
	SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField("MatchesSelection");
	SelectedField.Use = True;
	
	SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField("Code");
	SelectedField.Use = True;
	
	SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField("Used");
	SelectedField.Use = True;
	
	// Layout composition and query execution.
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Composer.GetSettings(), , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	Parameter = CompositionTemplate.ParameterValues.Find("Date");
	If Parameter <> Undefined Then
		Parameter.Value = CurrentSessionDate();
	EndIf;
	Parameter = CompositionTemplate.ParameterValues.Find("PriceKind");
	If Parameter <> Undefined Then
		Parameter.Value = PriceKind;
	EndIf;
	Parameter = CompositionTemplate.ParameterValues.Find("ExchangeRule");
	If Parameter <> Undefined Then
		Parameter.Value = ExchangeRule;
	EndIf;
	Parameter = CompositionTemplate.ParameterValues.Find("WeighingUnits");
	If Parameter <> Undefined Then
		Parameter.Value = Object.WeighingUnits;
	EndIf;
	Parameter = CompositionTemplate.ParameterValues.Find("BarcodeFormat");
	If Parameter <> Undefined Then
		Parameter.Value = InformationRegisters.Barcodes.WeightBarcodeFormat(Object.WeightProductPrefix);
	EndIf;
	
	Query = New Query(
	"SELECT
	|	&ExchangeRule AS ExchangeRule,
	|	ProductCodes.Code AS Code,
	|	ProductCodes.Used AS Used,
	|	ProductCodes.Products AS Products,
	|	ProductCodes.Characteristic AS Characteristic,
	|	ProductCodes.Batch AS Batch,
	|	ProductCodes.MeasurementUnit AS MeasurementUnit
	|INTO ProductCodes
	|FROM
	|	&ValueTable AS ProductCodes
	|
	|INDEX BY
	|	Products,
	|	Characteristic,
	|	Batch,
	|	MeasurementUnit");
	Query.Text = Query.Text + ";" + StrReplace(CompositionTemplate.DataSets.DataSet.Query, "InformationRegister.ProductsCodesPeripheralOffline", "ProductCodes");
	
	// Filling the parameters from filter composer fields of the form settings data processor.
	For Each Parameter In CompositionTemplate.ParameterValues Do
		Query.Parameters.Insert(Parameter.Name, Parameter.Value);
	EndDo;
	
	TableProductCodes = ProductCodes.Unload();
	TableProductCodes.Indexes.Add("Code");
	
	Query.SetParameter("ValueTable", TableProductCodes);
	
	If TableProductCodes.Count() > 0 Then
		Code = TableProductCodes[TableProductCodes.Count() - 1].Code + 1;
	Else
		Code = 1;
	EndIf;
	
	FreeCodes = New ValueTable;
	FreeCodes.Columns.Add("Code", New TypeDescription("Number"));
	For Each TSRow In Products.FindRows(New Structure("Products", Catalogs.Products.EmptyRef())) Do
		NewRow = FreeCodes.Add();
		NewRow.Code = TSRow.Code;
	EndDo;
	
	Selection =  Query.Execute().Select();
	While Selection.Next() Do
		If Selection.MatchesSelection Then
			If Not ValueIsFilled(Selection.Code) Then
				If FreeCodes.Count() = 0 Then
					WriteCodeInTable(TableProductCodes, Selection, Code, True);
					Code = Code + 1;
				Else
					WriteCodeInTable(TableProductCodes, Selection, FreeCodes[0].Code, True);
					FreeCodes.Delete(0);
				EndIf;
			Else
				WriteCodeInTable(TableProductCodes, Selection, Selection.Code, True);
			EndIf;
		Else
			WriteCodeInTable(TableProductCodes, Selection, Selection.Code, False);
		EndIf;
	EndDo;
	
	ProductCodes.Load(ProductsTable(TableProductCodes, PriceKind));
	
EndProcedure

&AtServer
Procedure UpdateListOfProductsOnserverFirstOpening()
	
	PeripheralsOfflineServerCall.RefreshProductProduct(Object.Ref);
	ExportIDFromRegister(Object.Ref);
	
EndProcedure

&AtServer
Procedure RefreshListOfGoodsAtServerReOpen()
	
	FoundStrings = Products.FindRows(New Structure("New, ChangedByUser", True, False));
	For Each TSRow In FoundStrings Do
		
		If Not ValueIsFilled(TSRow.Products) Then
			// Data in the row have been cleared already
			Continue;
		EndIf;
		
		TSRow.Products   = Undefined;
		TSRow.Characteristic = Undefined;
		TSRow.Batch         = Undefined;
		TSRow.MeasurementUnit = Undefined;
		TSRow.Used   = Undefined;
		TSRow.Description   = Undefined;
		TSRow.Weight        = Undefined;
		TSRow.Barcode       = Undefined;
		TSRow.Price           = Undefined;
		
	EndDo;
	
	// Deleting free unwritten codes from the table end.
	IndexOfLastRow = Products.Count() - 1;
	For LineNumber = -IndexOfLastRow To 0 Do
		TSRow = Products[-LineNumber];
		If Not ValueIsFilled(TSRow.Products) AND TSRow.New Then
			Products.Delete(-LineNumber);
		Else
			Break;
		EndIf;
	EndDo;
	
	UpdateProductsTable(Products, Object.Ref, Object.StructuralUnit.RetailPriceKind, AddressLinkerSettingsITemporaryStorage());
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure UpdateListOfProductsOnServer()
	
	If Not ProductsDataIsRead Then
		// First opening of a product list
		UpdateListOfProductsOnserverFirstOpening();
		
		If SelectionChanged OR Not ValueIsFilled(Object.Ref) Then
			RefreshListOfGoodsAtServerReOpen();
		EndIf;
		
		ProductsDataIsRead = True;
	Else
		RefreshListOfGoodsAtServerReOpen();
	EndIf;
	
	SelectionChanged = False;
	
EndProcedure

&AtClient
Function StringStructure(String)
	
	TSRow = New Structure;
	TSRow.Insert("Used");
	TSRow.Insert("Products");
	TSRow.Insert("Characteristic");
	TSRow.Insert("Batch");
	TSRow.Insert("MeasurementUnit");
	TSRow.Insert("Description");
	TSRow.Insert("Price");
	TSRow.Insert("Barcode");
	TSRow.Insert("Weight");
	
	FillPropertyValues(TSRow, String);
	
	Return TSRow;
	
EndFunction

&AtServer
Procedure ApplyChangesToServer(CurrentObject)
	
	BeginTransaction();
	
	// Writing product codes modified by the user
	FoundStrings = Products.FindRows(New Structure("ChangedByUser, New", True, False));
	For Each TSRow In FoundStrings Do
		RecordManager = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordManager();
		FillPropertyValues(RecordManager, TSRow);
		RecordManager.ExchangeRule = CurrentObject.Ref;
		RecordManager.Write();
	EndDo;
	
	// Writing automatically added rows
	FoundStrings = Products.FindRows(New Structure("ChangedAutomatically, ChangedByUser, New", True, False, False));
	For Each TSRow In FoundStrings Do
		RecordManager = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordManager();
		FillPropertyValues(RecordManager, TSRow);
		RecordManager.ExchangeRule = CurrentObject.Ref;
		RecordManager.Write();
	EndDo;
	
	// Writing the new product codes
	FoundStrings = Products.FindRows(New Structure("New", True));
	For Each TSRow In FoundStrings Do
		RecordManager = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordManager();
		FillPropertyValues(RecordManager, TSRow);
		RecordManager.ExchangeRule = CurrentObject.Ref;
		RecordManager.Write();
	EndDo;
	
	CommitTransaction();
	
	For Each TSRow In Products Do
		TSRow.ChangedByUser = False;
		TSRow.ChangedAutomatically = False;
		TSRow.New                 = False;
	EndDo;
	
EndProcedure

&AtServer
Function FindRowOfProductsWithCode(Code, ID)
	
	ReturnValue = Undefined;
	
	FoundStrings = Products.FindRows(New Structure("Code", Code));
	If FoundStrings.Count() > 1 Then
		For Each FoundString In FoundStrings Do
			If FoundString.GetID() <> ID Then
				ReturnValue = FoundString.GetID();
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

&AtServer
Procedure HandleChangingProductCodeOnServer(CurrentCode)
	
	ProductQuantity = Products.Count();
	If ProductQuantity > 0 Then
		
		MaximumTableID = Products[ProductQuantity-1].Code;
		If MaximumTableID = CurrentCode Then
			If ProductQuantity > 1 Then
				MaximumTableID = Products[ProductQuantity-2].Code;
			EndIf;
		EndIf;
		
		If MaximumTableID > OldCode Then
			
			NewRow = Products.Add();
			NewRow.Code = OldCode;
			NewRow.ChangedByUser = True;
			
		EndIf;
		
		Difference = CurrentCode - MaximumTableID;
		While Difference > 1 Do
			
			NewRow = Products.Add();
			NewRow.New = True;
			NewRow.ChangedByUser = True;
			
			MaximumTableID = MaximumTableID + 1;
			NewRow.Code = MaximumTableID;
			Difference = Difference - 1;
			
		EndDo;
	EndIf;
	
	Products.Sort("Code");
	
EndProcedure

&AtServer
Procedure RemoveFreeCodesProductsOnServer()
	
	BeginTransaction();
	
	RowToDeleteArray = New Array;
	
	// Deleting free product codes from the list end.
	IndexOfLastRow = Products.Count() - 1;
	For LineNumber = -IndexOfLastRow To 0 Do
		TSRow = Products[-LineNumber];
		If Not ValueIsFilled(TSRow.Products) Then
			
			RecordManager = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordManager();
			FillPropertyValues(RecordManager, TSRow);
			RecordManager.ExchangeRule = Object.Ref;
			RecordManager.Delete();
			
			RowToDeleteArray.Add(TSRow);
			
		Else
			Break;
		EndIf;
	EndDo;
	
	CommitTransaction();
	
	For Each TSRow In RowToDeleteArray Do
		Products.Delete(TSRow);
	EndDo;
	
EndProcedure

#EndRegion
