#Region Variables

&AtClient
Var ShoppingCartRowNumber;
&AtClient
Var ShoppingCartColumnName;
&AtClient
Var FormIsClosing;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Products") Then
		
		Products = Parameters.Products;
		ProductsCategory = Common.ObjectAttributeValue(Products, "ProductsCategory");
		
		MessageText = "";
		If Not ValueIsFilled(Products) Then
			MessageText = NStr("en = 'Product is required.'; ru = 'Укажите номенклатуру.';pl = 'Wymagany jest produkt.';es_ES = 'Se requiere un producto.';es_CO = 'Se requiere un producto.';tr = 'Ürün gerekli.';it = 'È richiesto l''articolo.';de = 'Produkte ist ein Pflichtfeld.'");
		ElsIf Products.ProductsType = Enums.ProductsTypes.Service Then
			MessageText = NStr("en = 'Service tracking by variant is disabled.
				|To turn it on, go to Settings > Purchases/Warehouse,
				|and under ""Inventory (Products)"", select ""Inventory accounting by variants"".'; 
				|ru = 'Учет услуг по вариантам отключен.
				|Чтобы включить его, перейдите в меню Настройки > Закупки/Склад
				|и в разделе ""Запасы (номенклатура)"" установите флажок ""Учет запасов в разрезе вариантов"".';
				|pl = 'Śledzenie usług według wariantów jest wyłączone.
				|W celu włączenia przejdź do Ustawienia > Zakup/Magazyn,
				|i w ""Zapasy (Produkty)"", zaznacz ""Ewidencja zapasów według wariantów"".';
				|es_ES = 'El rastreo de servicio por variantes está desactivado.
				|Para activarlo, ir a Configuraciones > Compras/Almacenes,
				|y en ""Inventario (productos)"", seleccione ""Contabilidad de inventario por variantes"".';
				|es_CO = 'El rastreo de servicio por variantes está desactivado.
				|Para activarlo, ir a Configuraciones > Compras/Almacenes,
				|y en ""Inventario (productos)"", seleccione ""Contabilidad de inventario por variantes"".';
				|tr = 'Varyantlara göre hizmet takibi kapalı.
				|Açmak için, Ayarlar > Satın alma / Ambar sayfasının
				|""Stok (Ürünler)"" bölümünde ""Varyantlara göre envanter muhasebesi""ni seçin.';
				|it = 'Il tracciamento del servizio per variante è disattivato.
				|Per attivarlo, andare in Impostazioni > Acquisti/Magazzino,
				|e in ""Scorte (Articoli)"", selezionare ""Contabilità scorte secondo varianti"".';
				|de = 'Dienstleistungsverfolgung nach Variante ist deaktiviert. Um sie zu aktivieren:
				|. Gehen Sie zu Einstellungen > Einkäufe / Lager,
				| und aktivieren Sie ""Bestandsbuhhaltung nach Varianten"" unter ""Bestand (Produkte)"".'");
		ElsIf Not Products.UseCharacteristics Then
			MessageText = NStr("en = 'Inventory tracking by variant is disabled.
				|To turn it on, go to Settings > Purchases/Warehouse,
				|and under ""Inventory (Products)"", select ""Inventory accounting by variants"".'; 
				|ru = 'Учет запасов по вариантам отключен.
				|Чтобы включить его, перейдите в меню Настройки > Закупки/Склад
				|и в разделе ""Запасы (номенклатура)"" установите флажок ""Учет запасов в разрезе вариантов"".';
				|pl = 'Śledzenie zapasów według wariantów jest wyłączone.
				|W celu włączenia przejdź do Ustawienia > Zakup/Magazyn,
				|i w ""Zapasy (Produkty)"", zaznacz ""Ewidencja zapasów według wariantów"".';
				|es_ES = 'El rastreo de inventario por variantes está desactivado.
				|Para activarlo, ir a Configuraciones > Compras/Almacenes,
				|y en ""Inventario (productos)"", seleccione ""Contabilidad de inventario por variantes"".';
				|es_CO = 'El rastreo de inventario por variantes está desactivado.
				|Para activarlo, ir a Configuraciones > Compras/Almacenes,
				|y en ""Inventario (productos)"", seleccione ""Contabilidad de inventario por variantes"".';
				|tr = 'Varyantlara göre stok takibi kapalı.
				|Açmak için, Ayarlar > Satın alma / Ambar sayfasının
				|""Stok (Ürünler)"" bölümünde ""Varyantlara göre envanter muhasebesi""ni seçin.';
				|it = 'Il tracciamento delle scorte per variante è disattivato.
				|Per attivarlo, andare in Impostazioni > Acquisti/Magazzino,
				|e in ""Scorte (Articoli)"", selezionare ""Contabilità scorte secondo varianti"".';
				|de = 'Bestandsverfolgung nach Variante ist deaktiviert. Um sie zu aktivieren:
				|. Gehen Sie zu Einstellungen > Einkäufe / Lager,
				| und aktivieren Sie ""Bestandsbuchhaltung nach Varianten"" unter ""Bestand (Produkte)"".'");
		EndIf;
		
		If Not IsBlankString(MessageText) Then
			CommonClientServer.MessageToUser(MessageText,,,,Cancel);
			Return;
		EndIf;
		
		If Parameters.ShowNotificationAboutPrices Then
			MessageText = NStr("en = 'Several lines contain the same variant.
				|After you save your work, they will merge into a single line.'; 
				|ru = 'Несколько строк содержат одинаковый вариант.
				|После записи данных они будут объединены в одну строку.';
				|pl = 'Kilka wierszy zawierają jednakowe warianty.
				|Po zapisaniu pracy zostaną one scalone w jeden wiersz.';
				|es_ES = 'Varias líneas contienen la misma variante.
				|Después de guardar su trabajo, se fusionarán en una sola línea.';
				|es_CO = 'Varias líneas contienen la misma variante.
				|Después de guardar su trabajo, se fusionarán en una sola línea.';
				|tr = 'Aynı varyantı içeren birkaç satır mevcut.
				|Çalışmalarınızı kaydettiğinizde bunlar tek bir satırda birleştirilecek.';
				|it = 'Diverse righe contengono la stessa variante.
				|Dopo aver salvato il lavoro, saranno unite in una singola riga.';
				|de = 'Mehrere Zeilen enthalten dieselbe Variante.
				| Nachdem Sie Ihre Arbeit speichern, werden diese in eine einzige Zeile zusammengefügt.'");
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
		Parameters.Property("Company", Company);
		Parameters.Property("StructuralUnit", StructuralUnit);
		Parameters.Property("OwnerFormUUID", OwnerFormUUID);
		Parameters.Property("AmountIncludesVAT", AmountIncludesVAT);
		Parameters.Property("DocumentCurrency", DocumentCurrency);
		Parameters.Property("ShowPrice", ShowPrice);
		Parameters.Property("VATTaxation", VATTaxation);
		
		CreateListTable();
		SetConditionalAppearance();
		
		// Prepare PricesFillingStructure
		
		PricesFillingStructure = New Structure;
		PricesFillingStructure.Insert("DocumentCurrencyMultiplicity");
		PricesFillingStructure.Insert("DocumentCurrencyRate");
		PricesFillingStructure.Insert("DynamicPriceKindPercent");
		PricesFillingStructure.Insert("PriceKind");
		PricesFillingStructure.Insert("PriceKindCurrencyMultiplicity");
		PricesFillingStructure.Insert("PriceKindCurrencyRate");
		PricesFillingStructure.Insert("PricePeriod");
		PricesFillingStructure.Insert("DiscountMarkupPercent");
		
		PriceKind = Parameters.PriceKind;
		PriceKindAttributesValues = Common.ObjectAttributesValues(PriceKind,
			"PriceCurrency,
			|PricesBaseKind,
			|Percent,
			|PriceCalculationMethod");
		PriceKindCurrency = PriceKindAttributesValues.PriceCurrency;
		ExchangeRate = DriveServer.GetExchangeRate(Company, PriceKindCurrency, DocumentCurrency, Parameters.Date);
		
		PricesFillingStructure.DocumentCurrencyMultiplicity = ExchangeRate.Repetition;
		PricesFillingStructure.DocumentCurrencyRate = ExchangeRate.Rate;
		If PriceKindAttributesValues.PriceCalculationMethod = Enums.PriceCalculationMethods.CalculatedDynamic Then
			PricesFillingStructure.DynamicPriceKindPercent = PriceKindAttributesValues.Percent;
		Else
			PricesFillingStructure.DynamicPriceKindPercent = 0;
		EndIf;
		PricesFillingStructure.PriceKind = PriceKind;
		PricesFillingStructure.PriceKindCurrencyMultiplicity = ExchangeRate.RepetitionBeg;
		PricesFillingStructure.PriceKindCurrencyRate = ExchangeRate.InitRate;
		PricesFillingStructure.PricePeriod = Parameters.PricePeriod;
		DiscountMarkupKind = Parameters.DiscountMarkupKind;
		If ValueIsFilled(DiscountMarkupKind) Then
			PricesFillingStructure.DiscountMarkupPercent = Common.ObjectAttributeValue(DiscountMarkupKind, "Percent");
		Else
			PricesFillingStructure.DiscountMarkupPercent = 0;
		EndIf;
		FillListTable(Parameters.SelectedProducts, Parameters.ProductsPrices, PricesFillingStructure);
		
	Else
		
		Items.FormSelect.Enabled = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ShowPrice Then
		For Each SelectedVariantsRow In SelectedVariants Do
			If SelectedVariantsRow.Quantity <> 0 Then
				CalculateAmountInTabularSectionLine(SelectedVariantsRow);
			EndIf;
		EndDo;
	EndIf;
	
	RefreshCartInfoLabel();
	
	ThisObject.CurrentItem = Items.ShoppingCart;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	If Not FormIsClosing AND Not Exit Then
		If WereMadeChanges Then
			Cancel = True;
			ShowQueryBox(New NotifyDescription("BeforeClosingQueryBoxHandler", ThisObject),
					NStr("en = 'Add selected variants to document?'; ru = 'Добавить выбранные варианты в документ?';pl = 'Dodać wybrane warianty do dokumentu?';es_ES = '¿Añadir las variantes seleccionadas al documento?';es_CO = '¿Añadir las variantes seleccionadas al documento?';tr = 'Seçilen varyantlar belgeye eklensin mi?';it = 'Aggiungere varianti selezionate al documento?';de = 'Ausgewählte Varianten zum Dokument hinzufügen?'"),
					QuestionDialogMode.YesNoCancel);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region ShoppingCartFormTableItemsEventHandlers

&AtClient
Procedure ShoppingCartOnChange(Item)
	
	NameParts = StrSplit(Items.ShoppingCart.CurrentItem.Name, "_");
	SelectedRow = Items.ShoppingCart.CurrentRow;
	
	If NameParts.Count() = 2 Then
		
		ColumnName = NameParts[1];
		
		If ColumnName <> "RowName" Then
			
			ShoppingCartRowNumber = SelectedRow;
			ShoppingCartColumnName = ColumnName;
			
		EndIf;
		
	EndIf;
	
	// Selected variants
	Filter = New Structure;
	Filter.Insert("Name", ShoppingCartColumnName);
	ColumnValues = ColumnsMap.FindRows(Filter);
	If ColumnValues.Count() Then
		ColumnValue = ColumnValues[0].Value;
		
		Filter.Name = ShoppingCart[ShoppingCartRowNumber].RowName;
		RowValues = RowsMap.FindRows(Filter);
		
		If RowValues.Count() Then
			
			RowValue = RowValues[0].Value;
			
			Filter = New Structure;
			Filter.Insert("ColumnValue", ColumnValue);
			Filter.Insert("RowValue", RowValue);
			RowsToChange = SelectedVariants.FindRows(Filter);
			For Each RowToChange In RowsToChange Do
				RowToChange.Quantity = ShoppingCart[ShoppingCartRowNumber][ShoppingCartColumnName];
				CalculateAmountInTabularSectionLine(RowToChange);
			EndDo;
			
		EndIf;
		
	EndIf;
	
	WereMadeChanges = True;
	
	RefreshCartInfoLabel();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	MoveToDocumentAndClose();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure BeforeClosingQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		MoveToDocumentAndClose();
	ElsIf QueryResult = DialogReturnCode.No Then
		FormIsClosing = True;
		Close();
	EndIf;

EndProcedure

&AtClient
Procedure MoveToDocumentAndClose()
	
	FormIsClosing = True;
	Close(PutCartToTempStorage());
	
EndProcedure

&AtServer
Function PutCartToTempStorage()
	
	// Clear empty rows
	Filter = New Structure;
	Filter.Insert("Quantity", 0);
	
	EmptyRows = SelectedVariants.FindRows(Filter);
	
	For Each EmptyRow In EmptyRows Do
		SelectedVariants.Delete(EmptyRow);
	EndDo;
	
	CartAddressInStorage = PutToTempStorage(SelectedVariants.Unload(), OwnerFormUUID);
	ReturnStructure = New Structure;
	ReturnStructure.Insert("CartAddressInStorage", CartAddressInStorage);
	ReturnStructure.Insert("OwnerFormUUID", OwnerFormUUID);
	ReturnStructure.Insert("FilterProducts", Products);
	ReturnStructure.Insert("WereMadeChanges", WereMadeChanges);
	
	Return ReturnStructure;
	
EndFunction

&AtServer
Procedure CreateListTable()
	
	SetOfCharacteristicProperties = Common.ObjectAttributeValue(ProductsCategory, "SetOfCharacteristicProperties");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	AdditionalAttributes.Ref = &SetOfCharacteristicProperties
	|	AND NOT AdditionalAttributes.DeletionMark
	|
	|ORDER BY
	|	AdditionalAttributes.LineNumber";
	
	Query.SetParameter("SetOfCharacteristicProperties", SetOfCharacteristicProperties);
	
	AdditionalAttributes = Query.Execute().Unload();
	
	If AdditionalAttributes.Count() = 2 Then
		
		RowsCharacteristic = AdditionalAttributes[0].Property;
		ColumnsCharacteristic = AdditionalAttributes[1].Property;
		
		SelectedMatrix = New ValueTable;
		
		QS = New StringQualifiers(150);
		Array = New Array;
		Array.Add(Type("String"));
		TypeDescriptionS = New TypeDescription(Array, , QS);
		SelectedMatrix.Columns.Add("RowName", TypeDescriptionS, RowsCharacteristic.Title + "/" + ColumnsCharacteristic.Title);
		
		QS = New StringQualifiers(10);
		TypeDescriptionS10 = New TypeDescription(Array, , QS);
		
		QN = New NumberQualifiers(10, 0);
		Array = New Array;
		Array.Add(Type("Number"));
		TypeDescriptionN = New TypeDescription(Array, , ,QN);
		
		// Columns
		If ColumnsCharacteristic.AdditionalValuesUsed Then
			
			Query = New Query;
			Query.Text = 
				"SELECT
				|	ObjectsPropertiesValues.Ref AS Value,
				|	ObjectsPropertiesValues.Description AS Description
				|FROM
				|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
				|WHERE
				|	NOT ObjectsPropertiesValues.IsFolder
				|	AND NOT ObjectsPropertiesValues.DeletionMark
				|	AND ObjectsPropertiesValues.Owner = &ColumnsCharacteristic
				|
				|ORDER BY
				|	ObjectsPropertiesValues.Description";
			
			Query.SetParameter("ColumnsCharacteristic", ColumnsCharacteristic);
			QueryResult = Query.Execute();
			SelectionDetailRecords = QueryResult.Select();
			
			Counter = 0;
			
			While SelectionDetailRecords.Next() Do
				
				ColumnMap = ColumnsMap.Add();
				ColumnMap.Name = "Column" + Format(Counter, "NZ=0; NG=0");
				ColumnMap.Value = SelectionDetailRecords.Value;
				
				SelectedMatrix.Columns.Add(ColumnMap.Name, TypeDescriptionN, SelectionDetailRecords.Description);
				
				Counter = Counter + 1;
				
			EndDo;
			
		Else
			
			Query = New Query;
			Query.Text =
				"SELECT DISTINCT
				|	VariantsProperties.Value AS Value
				|FROM
				|	Catalog.ProductsCharacteristics.AdditionalAttributes AS VariantsProperties
				|WHERE
				|	VariantsProperties.Property = &Property
				|	AND NOT VariantsProperties.Ref.DeletionMark
				|
				|ORDER BY
				|	Value";
			
			Query.SetParameter("Property", ColumnsCharacteristic);
			QueryResult = Query.Execute();
			SelectionDetailRecords = QueryResult.Select();
			
			Counter = 0;
			
			While SelectionDetailRecords.Next() Do
				
				ColumnMap = ColumnsMap.Add();
				ColumnMap.Name = "Column" + Format(Counter, "NZ=0; NG=0");
				ColumnMap.Value = SelectionDetailRecords.Value;
				
				SelectedMatrix.Columns.Add(ColumnMap.Name, TypeDescriptionN,  String(ColumnMap.Value));
				
				Counter = Counter + 1;
				
			EndDo;
		
		EndIf;
		
		// Rows
		If RowsCharacteristic.AdditionalValuesUsed Then
			
			Query = New Query;
			Query.Text = 
				"SELECT
				|	ObjectsPropertiesValues.Ref AS Value,
				|	ObjectsPropertiesValues.Description AS Name
				|FROM
				|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
				|WHERE
				|	NOT ObjectsPropertiesValues.IsFolder
				|	AND NOT ObjectsPropertiesValues.DeletionMark
				|	AND ObjectsPropertiesValues.Owner = &RowsCharacteristic
				|
				|ORDER BY
				|	ObjectsPropertiesValues.Description";
			
			Query.SetParameter("RowsCharacteristic", RowsCharacteristic);
			QueryResult = Query.Execute();
			SelectionDetailRecords = QueryResult.Select();
			
			While SelectionDetailRecords.Next() Do
				
				RowMap = RowsMap.Add();
				FillPropertyValues(RowMap, SelectionDetailRecords);
				
				SelectedMatrixRow = SelectedMatrix.Add();
				SelectedMatrixRow.RowName = RowMap.Name;
				
			EndDo;
			
		Else
			
			Query = New Query;
			Query.Text =
				"SELECT DISTINCT
				|	VariantsProperties.Value AS Value
				|FROM
				|	Catalog.ProductsCharacteristics.AdditionalAttributes AS VariantsProperties
				|WHERE
				|	VariantsProperties.Property = &RowsCharacteristic
				|	AND NOT VariantsProperties.Ref.DeletionMark
				|
				|ORDER BY
				|	Value";
			
			Query.SetParameter("RowsCharacteristic", RowsCharacteristic);
			QueryResult = Query.Execute();
			SelectionDetailRecords = QueryResult.Select();
			
			While SelectionDetailRecords.Next() Do
				
				RowMap = RowsMap.Add();
				RowMap.Name = String(SelectionDetailRecords.Value);
				RowMap.Value = SelectionDetailRecords.Value;
				
				SelectedMatrixRow = SelectedMatrix.Add();
				SelectedMatrixRow.RowName = RowMap.Name;
				
			EndDo;
		
		EndIf;
		
		// SelectedMatrix into ShoppingCart
		
		NewAttributes = New Array;
		
		For Each Column In SelectedMatrix.Columns Do
			If Column.Name <> "RowName" Then
				SelectedMatrix.FillValues(-1, Column.Name);
			EndIf;
			NewAttributes.Add(New FormAttribute(Column.Name, Column.ValueType, "ShoppingCart", Column.Title));
		EndDo;
		
		ChangeAttributes(NewAttributes);
		
		For Each Column In SelectedMatrix.Columns Do
			NewItem = Items.Add("ShoppingCart_" + Column.Name, Type("FormField"), Items.ShoppingCart);
			NewItem.Type = FormFieldType.InputField;
			NewItem.DataPath = "ShoppingCart." + Column.Name;
			NewItem.Width = 10;
			NewItem.MinValue = 0;
		EndDo;
		
		ValueToFormAttribute(SelectedMatrix, "ShoppingCart");
		
	EndIf;

EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	ListColumns = ShoppingCart.Unload().Columns;
	For Each Column In ListColumns Do
		
		If Column.Name = "RowName" Then
			
			// Shopping cart
			Item = ConditionalAppearance.Items.Add();
			
			ItemField = Item.Fields.Items.Add();
			ItemField.Field = New DataCompositionField("ShoppingCart_" + Column.Name);
			
			Item.Appearance.SetParameterValue("ReadOnly", True);
			Item.Appearance.SetParameterValue("BackColor", StyleColors.TableHeaderBackColor);
			
			Item.Use = True;
			
		Else
			
			// Shopping cart
			Item = ConditionalAppearance.Items.Add();
			
			ItemField = Item.Fields.Items.Add();
			ItemField.Field = New DataCompositionField("ShoppingCart_" + Column.Name);
			
			FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue		= New DataCompositionField("ShoppingCart." + Column.Name);
			FilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
			FilterItem.RightValue		= -1;
			
			Item.Appearance.SetParameterValue("BackColor", StyleColors.ColorChartMissingData);
			Item.Appearance.SetParameterValue("Text", "");
			Item.Appearance.SetParameterValue("ReadOnly", True);
			
			Item.Use = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillListTable(SelectedProducts, ProductsPrices, PricesFillingStructure)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductsCharacteristics.Ref AS Characteristic,
		|	ProductsCharacteristics.Owner AS Products
		|INTO Variants
		|FROM
		|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
		|WHERE
		|	ProductsCharacteristics.Owner = &Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ISNULL(InventoryInWarehousesBalance.Products, ReservedProductsBalance.Products) AS Products,
		|	ISNULL(InventoryInWarehousesBalance.Characteristic, ReservedProductsBalance.Characteristic) AS Characteristic,
		|	ISNULL(InventoryInWarehousesBalance.QuantityBalance, 0) AS InventoryInWarehousesBalance,
		|	ISNULL(ReservedProductsBalance.QuantityBalance, 0) AS ReservedProductsBalance
		|INTO TT_InventoryBalances
		|FROM
		|	AccumulationRegister.InventoryInWarehouses.Balance(
		|			,
		|			Company = &Company
		|				AND (StructuralUnit = &StructuralUnit
		|					OR &StructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef))
		|				AND (Products, Characteristic) IN
		|					(SELECT
		|						Variants.Products AS Products,
		|						Variants.Characteristic AS Characteristic
		|					FROM
		|						Variants AS Variants)) AS InventoryInWarehousesBalance
		|		FULL JOIN AccumulationRegister.ReservedProducts.Balance(
		|				,
		|				Company = &Company
		|					AND SalesOrder <> UNDEFINED
		|					AND StructuralUnit REFS Catalog.BusinessUnits
		|					AND (StructuralUnit = &StructuralUnit
		|						OR &StructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef))
		|					AND (Products, Characteristic) IN
		|						(SELECT
		|							Variants.Products AS Products,
		|							Variants.Characteristic AS Characteristic
		|						FROM
		|							Variants AS Variants)) AS ReservedProductsBalance
		|		ON InventoryInWarehousesBalance.Products = ReservedProductsBalance.Products
		|			AND InventoryInWarehousesBalance.Characteristic = ReservedProductsBalance.Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Variants.Products AS Products,
		|	Variants.Characteristic AS Characteristic,
		|	ISNULL(TT_InventoryBalances.InventoryInWarehousesBalance, 0) AS InStock,
		|	ISNULL(TT_InventoryBalances.InventoryInWarehousesBalance, 0) - ISNULL(TT_InventoryBalances.ReservedProductsBalance, 0) AS Available
		|INTO TT_AvailableInventory
		|FROM
		|	Variants AS Variants
		|		LEFT JOIN TT_InventoryBalances AS TT_InventoryBalances
		|		ON Variants.Products = TT_InventoryBalances.Products
		|			AND Variants.Characteristic = TT_InventoryBalances.Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_AvailableInventory.Products AS Products,
		|	TT_AvailableInventory.Characteristic AS Characteristic,
		|	SUM(TT_AvailableInventory.InStock) AS InStock,
		|	SUM(TT_AvailableInventory.Available) AS Available,
		|	ColumnValue.Value AS ColumnValue,
		|	RowValue.Value AS RowValue
		|FROM
		|	TT_AvailableInventory AS TT_AvailableInventory
		|		INNER JOIN Catalog.ProductsCharacteristics.AdditionalAttributes AS ColumnValue
		|		ON TT_AvailableInventory.Characteristic = ColumnValue.Ref
		|		INNER JOIN Catalog.ProductsCharacteristics.AdditionalAttributes AS RowValue
		|		ON TT_AvailableInventory.Characteristic = RowValue.Ref
		|WHERE
		|	ColumnValue.Property = &ColumnsCharacteristic
		|	AND RowValue.Property = &RowsCharacteristic
		|
		|GROUP BY
		|	TT_AvailableInventory.Products,
		|	TT_AvailableInventory.Characteristic,
		|	ColumnValue.Value,
		|	RowValue.Value";
	
	Query.SetParameter("Products", Products);
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("Company", Company);
	Query.SetParameter("RowsCharacteristic", RowsCharacteristic);
	Query.SetParameter("ColumnsCharacteristic", ColumnsCharacteristic);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		// Find row
		Filter = New Structure;
		Filter.Insert("Value", SelectionDetailRecords.RowValue);
		
		LinesWithRowName = RowsMap.FindRows(Filter);
		
		If LinesWithRowName.Count() > 0 Then
			
			Filter = New Structure;
			Filter.Insert("RowName", LinesWithRowName[0].Name);
			
			RowsToFill = ShoppingCart.FindRows(Filter);
			
			If RowsToFill.Count() > 0 Then
				
				CartRowToFill = RowsToFill[0];
				
				// Find column
				Filter = New Structure;
				Filter.Insert("Value", SelectionDetailRecords.ColumnValue);
				
				LinesWithColumnName = ColumnsMap.FindRows(Filter);
				
				If LinesWithColumnName.Count() > 0 Then
					
					ColumnName = LinesWithColumnName[0].Name;
					
					CartRowToFill[ColumnName] = 0;
					
					InventoryRow = SelectedProducts.Get(SelectionDetailRecords.Characteristic);
					If InventoryRow <> Undefined Then
						CartRowToFill[ColumnName] = InventoryRow;
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Prepare "Selected items" table with prices
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductsCharacteristics.Ref AS Characteristic,
		|	ProductsCharacteristics.Owner AS Products
		|INTO Variants
		|FROM
		|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
		|WHERE
		|	ProductsCharacteristics.Owner = &Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Variants.Products AS Products,
		|	Variants.Characteristic AS Characteristic,
		|	CAST(ISNULL(PricesSliceLast.Price, ISNULL(ProductsPricesSliceLast.Price, 0)) * (&PriceKindCurrencyRate * &DocumentCurrencyMultiplicity) / (&DocumentCurrencyRate * &PriceKindCurrencyMultiplicity) * (1 + &DynamicPriceKindPercent / 100) AS NUMBER(15, 2)) AS Price,
		|	ISNULL(PricesSliceLast.MeasurementUnit, ISNULL(ProductsPricesSliceLast.MeasurementUnit, Variants.Products.MeasurementUnit)) AS MeasurementUnit,
		|	ISNULL(UOM.Factor, ISNULL(ProductsUOM.Factor, 1)) AS Factor
		|INTO TT_Prices
		|FROM
		|	Variants AS Variants
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&PricePeriod,
		|				(Products, Characteristic) IN
		|						(SELECT
		|							Variants.Products AS Products,
		|							Variants.Characteristic AS Characteristic
		|						FROM
		|							Variants AS Variants)
		|					AND PriceKind = &PriceKind
		|					AND Active) AS PricesSliceLast
		|			LEFT JOIN Catalog.UOM AS UOM
		|			ON PricesSliceLast.MeasurementUnit = UOM.Ref
		|		ON Variants.Characteristic = PricesSliceLast.Characteristic
		|			AND Variants.Products = PricesSliceLast.Products
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&PricePeriod,
		|				Products IN
		|						(SELECT
		|							Variants.Products AS Products
		|						FROM
		|							Variants AS Variants)
		|					AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
		|					AND PriceKind = &PriceKind
		|					AND Active) AS ProductsPricesSliceLast
		|			LEFT JOIN Catalog.UOM AS ProductsUOM
		|			ON ProductsPricesSliceLast.MeasurementUnit = ProductsUOM.Ref
		|		ON Variants.Products = ProductsPricesSliceLast.Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_AvailableInventory.Products AS Products,
		|	TT_AvailableInventory.Characteristic AS Characteristic,
		|	ColumnValue.Value AS ColumnValue,
		|	RowValue.Value AS RowValue,
		|	TT_AvailableInventory.Price AS Price,
		|	TT_AvailableInventory.MeasurementUnit AS MeasurementUnit,
		|	TT_AvailableInventory.Factor AS Factor,
		|	&DiscountMarkupPercent AS DiscountMarkupPercent,
		|	&VATRate AS VATRate
		|FROM
		|	TT_Prices AS TT_AvailableInventory
		|		INNER JOIN Catalog.ProductsCharacteristics.AdditionalAttributes AS ColumnValue
		|		ON TT_AvailableInventory.Characteristic = ColumnValue.Ref
		|		INNER JOIN Catalog.ProductsCharacteristics.AdditionalAttributes AS RowValue
		|		ON TT_AvailableInventory.Characteristic = RowValue.Ref
		|WHERE
		|	ColumnValue.Property = &ColumnsCharacteristic
		|	AND RowValue.Property = &RowsCharacteristic";
	
	Query.SetParameter("ColumnsCharacteristic", ColumnsCharacteristic);
	Query.SetParameter("Company", Company);
	Query.SetParameter("DocumentCurrencyMultiplicity", PricesFillingStructure.DocumentCurrencyMultiplicity);
	Query.SetParameter("DocumentCurrencyRate", PricesFillingStructure.DocumentCurrencyRate);
	Query.SetParameter("DynamicPriceKindPercent", PricesFillingStructure.DynamicPriceKindPercent);
	Query.SetParameter("PriceKind", PricesFillingStructure.PriceKind);
	Query.SetParameter("PriceKindCurrencyMultiplicity", PricesFillingStructure.PriceKindCurrencyMultiplicity);
	Query.SetParameter("PriceKindCurrencyRate", PricesFillingStructure.PriceKindCurrencyRate);
	Query.SetParameter("PricePeriod", PricesFillingStructure.PricePeriod);
	Query.SetParameter("Products", Products);
	Query.SetParameter("RowsCharacteristic", RowsCharacteristic);
	Query.SetParameter("DiscountMarkupPercent", PricesFillingStructure.DiscountMarkupPercent);
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		Query.Text = StrReplace(Query.Text, "&VATRate", "TT_AvailableInventory.Products.VATRate");
	Else
		Query.SetParameter("VATRate",
			?(VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT,
				Catalogs.VATRates.Exempt,
				Catalogs.VATRates.ZeroRate));
	EndIf;
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	SelectedVariants.Clear();
	
	While SelectionDetailRecords.Next() Do
		
		NewRow = SelectedVariants.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		
		InventoryRow = SelectedProducts.Get(SelectionDetailRecords.Characteristic);
		If InventoryRow <> Undefined Then
			NewRow.Quantity = InventoryRow;
		EndIf;
		
		PriceRow = ProductsPrices.Get(SelectionDetailRecords.Characteristic);
		If PriceRow <> Undefined Then
			NewRow.Price = PriceRow;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshCartInfoLabel()
	
	If ShowPrice Then
		
		CartInfoLabelPattern = NStr("en = 'Cart items: %1 Total: %2 %3'; ru = 'Позиций в корзине: %1 Итого: %2 %3';pl = 'Pozycje w koszyku: %1 Łącznie: %2 %3';es_ES = 'Artículos de la cesta: %1Total:%2 %3';es_CO = 'Artículos de la cesta: %1Total:%2 %3';tr = 'Sepet öğeleri: %1 Toplam: %2 %3';it = 'Elementi carrello: %1 Totale: %2 %3';de = 'Warenkorb-Artikel: %1 Gesamtsumme: %2 %3'");
		
		CartInfoLabel = StringFunctionsClientServer.SubstituteParametersToString(
			CartInfoLabelPattern,
			Format(SelectedVariants.Total("Quantity"), "NZ="),
			Format(SelectedVariants.Total("Total"), "ND=15; NFD=2; NZ="),
			DocumentCurrency);
		
	Else
		
		CartInfoLabelPattern = NStr("en = 'Cart items: %1'; ru = 'Позиции в корзине: %1';pl = 'Pozycje w koszyku: %1';es_ES = 'Artículos de la cesta: %1';es_CO = 'Artículos de la cesta: %1';tr = 'Sepet öğeleri: %1';it = 'Articoli del carrello: %1';de = 'Warenkorbartikel: %1'");
		
		CartInfoLabel = StringFunctionsClientServer.SubstituteParametersToString(
			CartInfoLabelPattern,
			Format(SelectedVariants.Total("Quantity"), "NZ="));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(StringCart)
	
	StringCart.Amount = StringCart.Quantity * StringCart.Price;
	
	If StringCart.DiscountMarkupPercent <> 0
		AND StringCart.Quantity <> 0 Then
		
		StringCart.Amount = StringCart.Amount * (1 - StringCart.DiscountMarkupPercent / 100);
		
	EndIf;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure CalculateVATSUM(StringCart)
	
	VATRate = DriveReUse.GetVATRateValue(StringCart.VATRate);
	
	StringCart.VATAmount = ?(AmountIncludesVAT, 
		StringCart.Amount - (StringCart.Amount) / ((VATRate + 100) / 100),
		StringCart.Amount * VATRate / 100);
	
EndProcedure

#EndRegion

#Region Initialize

FormIsClosing = False;
ShoppingCartRowNumber = 0;
ShoppingCartColumnName = "RowName";

#EndRegion
