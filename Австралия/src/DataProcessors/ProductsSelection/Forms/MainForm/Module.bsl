#Region Variables

&AtClient
Var FormIsClosing;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var InformationAboutDocument;
	
	DataProcessors.ProductsSelection.CheckParametersFilling(Parameters, Cancel);
	
	FillObjectData();
	FillInformationAboutDocument(InformationAboutDocument);
	
	SetDynamicListParameters();
	
	If ValueIsFilled(Parameters.Title) Then
		
		AutoTitle = False;
		Title = Parameters.Title;
		
	EndIf;
	
	If Object.TotalAmount > 0 Then
		
		Items.CartInfoLabel.ToolTip = NStr(
			"en = 'Total items = ""number of items in the document"" + ""number of items in the cart""
		    	|Grand total = ""cost of items in the document"" + ""cost of items in the cart""'; 
		    	|ru = 'Всего позиций = ""количество позиций в документе"" + ""количество позиций в корзине""
		    	|Всего = ""итоговая сумма документа"" + ""итоговая сумма корзины""';
		    	|pl = 'Łącznie pozycji = ""ilość pozycji w dokumencie"" + ""ilość pozycji w koszyku""
		    	|Łączna suma = ""koszt pozycji w dokumencie"" + ""koszt pozycji w koszyku""';
		    	|es_ES = 'Total de artículos = ""número de artículos en el documento"" + ""número de artículos en la cesta""
		    	| Total general = ""coste de artículos en el documento"" + ""coste de artículos en la cesta""';
		    	|es_CO = 'Total de artículos = ""número de artículos en el documento"" + ""número de artículos en la cesta""
		    	| Total general = ""coste de artículos en el documento"" + ""coste de artículos en la cesta""';
		    	|tr = 'Toplam öğe = ""belgedeki öğe sayısı"" + ""sepetteki öğe sayısı""
		    	|Genel toplam = ""belgedeki öğelerin maliyeti"" + ""sepetteki öğelerin maliyeti""';
		    	|it = 'Elementi totali = ""numero di elementi nel documento"" + ""numero di elementi nel carrello""
		    	|Totale generale = ""Costo degli elementi nel documento"" + ""costo degli elementi nel carrello""';
		    	|de = 'Gesamtpositionen = ""Anzahl der Positionen im Dokument"" + ""Anzahl der Positionen im Warenkorb""
		    	|Gesamtsumme = ""Kosten der Positionen im Dokument"" + ""Kosten der Positionen im Warenkorb"".'");
		
	EndIf;
	
	EnableFulltextSearchOnOpenSelection();
	
	// fix the Warehouse balance list flicker
	CommonClientServer.AddCompositionItem(ListWarehouseBalances.Filter, "Products", DataCompositionComparisonType.Equal, Catalogs.Products.EmptyRef());
	CommonClientServer.SetDynamicListParameter(ListWarehouseBalances, "Factor", 1);
	
	SelectionSettingsCache = New Structure;
	
	SelectionSettingsCache.Insert("CurrentUser", Users.CurrentUser());
	SelectionSettingsCache.Insert("PriceWithFormula", (Object.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula));
	
	SelectionSettingsCache.Insert("RequestQuantity", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "RequestQuantity", True));
	SelectionSettingsCache.Insert("RequestPrice", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "RequestPrice", True));
	SelectionSettingsCache.Insert("ShowCart", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "ShowCart", True));
	
	StockStatusFilter = DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "StockStatusFilter", Enums.StockStatusFilters.All);
	If StockStatusFilter = Enums.StockStatusFilters.InStock Then
		CommonClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "InStock", DataCompositionComparisonType.Greater, 0);
		CommonClientServer.AddCompositionItem(ListCharacteristics.SettingsComposer.FixedSettings.Filter, "InStock", DataCompositionComparisonType.Greater, 0);
		CommonClientServer.AddCompositionItem(ListBatches.SettingsComposer.FixedSettings.Filter, "InStock", DataCompositionComparisonType.Greater, 0);
	ElsIf StockStatusFilter = Enums.StockStatusFilters.Available Then
		CommonClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
		CommonClientServer.AddCompositionItem(ListCharacteristics.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
		CommonClientServer.AddCompositionItem(ListBatches.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
	EndIf;
	
	ShowPrice = False;
	If Parameters.Property("ShowPrice") Then
		ShowPrice = Parameters.ShowPrice;
	EndIf;
	SelectionSettingsCache.Insert("ShowPrice", ShowPrice);
	
	If SelectionSettingsCache.ShowPrice And Not SelectionSettingsCache.PriceWithFormula Then
		ShowItemsWithPriceOnly = DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser,
			"ShowItemsWithPriceOnly");
	Else
		ShowItemsWithPriceOnly = False;
	EndIf;
	
	If ShowItemsWithPriceOnly Then
		
		CommonClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter,
			"Price",
			DataCompositionComparisonType.Filled,
			0);
		
		CommonClientServer.AddCompositionItem(ListCharacteristics.SettingsComposer.FixedSettings.Filter,
			"Price",
			DataCompositionComparisonType.Filled,
			0);
		
		CommonClientServer.AddCompositionItem(ListBatches.SettingsComposer.FixedSettings.Filter,
			"Price",
			DataCompositionComparisonType.Filled,
			0);
		
	EndIf;
	
	StockWarehouse = Object.StructuralUnit;
	CommonClientServer.SetDynamicListParameter(ListInventory,		"StockWarehouse", StockWarehouse);
	CommonClientServer.SetDynamicListParameter(ListCharacteristics,	"StockWarehouse", StockWarehouse);
	CommonClientServer.SetDynamicListParameter(ListBatches,			"StockWarehouse", StockWarehouse);
			
	SelectionSettingsCache.Insert("PricesKindPriceIncludesVAT",
		?(ValueIsFilled(Object.PriceKind),
			Common.ObjectAttributeValue(Object.PriceKind, "PriceIncludesVAT"),
			Object.AmountIncludesVAT));
	SelectionSettingsCache.Insert("DiscountsMarkupsVisible", Parameters.DiscountsMarkupsVisible);
	SelectionSettingsCache.Insert("DiscountMarkupPercent",
		?(ValueIsFilled(Object.DiscountMarkupKind),
			Common.ObjectAttributeValue(Object.DiscountMarkupKind, "Percent"),
			0));
	SelectionSettingsCache.Insert("InformationAboutDocument", InformationAboutDocument);
	
	SelectionSettingsCache.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionSettingsCache.Insert("DiscountCardVisible", Parameters.DiscountCardVisible);
	
	SelectionSettingsCache.Insert("InaccessibleDataColor", StyleColors.InaccessibleDataColor);
	
	// Manually changing of the price is invalid for the CRReceipt document with a retail warehouse
	AllowedToChangeAmount = True;
	If Parameters.Property("IsCRReceipt") Then
		If ValueIsFilled(Object.StructuralUnit) Then
			AllowedToChangeAmount = Not Common.ObjectAttributeValue(Object.StructuralUnit, "StructuralUnitType") = Enums.BusinessUnitsTypes.Retail;
		EndIf;
	EndIf;
	
	SelectionSettingsCache.Insert("AllowedToChangeAmount", AllowedToChangeAmount
		AND DriveAccessManagementReUse.AllowedEditDocumentPrices());
		
	ShowBatch = False;
	If Parameters.Property("ShowBatch") Then
		ShowBatch = Parameters.ShowBatch;
	EndIf;
	SelectionSettingsCache.Insert("ShowBatch", ShowBatch);
	
	ShowAvailable = False;
	If Parameters.Property("ShowAvailable") Then
		ShowAvailable = Parameters.ShowAvailable;
	EndIf;
	SelectionSettingsCache.Insert("ShowAvailable", ShowAvailable);
	
	FilterCellVisible = False;
	If Parameters.Property("FilterCellVisible") Then
		FilterCellVisible = ShowAvailable And Parameters.FilterCellVisible;
	EndIf;
	SelectionSettingsCache.Insert("FilterCellVisible", FilterCellVisible);
	
	If SelectionSettingsCache.FilterCellVisible Then
		StockCell 	= Object.Cell;
		Cell 		= Object.Cell;
	Else
		Cell = Undefined;
	EndIf;	
		
	CommonClientServer.SetDynamicListParameter(ListInventory,		"StockCell", Cell);
	CommonClientServer.SetDynamicListParameter(ListCharacteristics,	"StockCell", Cell);
	CommonClientServer.SetDynamicListParameter(ListBatches,			"StockCell", Cell);
	
	// Bundles
	ShowBundles = False;
	If Parameters.Property("ShowBundles") Then
		ShowBundles = Parameters.ShowBundles;
	EndIf;
	SelectionSettingsCache.Insert("ShowBundles", ShowBundles);
	
	If Not ShowBundles Then
		CommonClientServer.AddCompositionItem(
			ListInventory.SettingsComposer.FixedSettings.Filter,
			"IsBundle",
			DataCompositionComparisonType.Equal,
			False);
	EndIf;
	// End Bundles
	
	CrossReferenceVisible = False;
	If Parameters.Property("Counterparty") Then
		CommonClientServer.SetDynamicListParameter(ListInventory, "Counterparty", Parameters.Counterparty);
		CrossReferenceVisible =  
			Catalogs.SuppliersProducts.CounterpartyUsesProductCrossReferences(Parameters.Counterparty);
	Else
		CommonClientServer.SetDynamicListParameter(ListInventory, "Counterparty", Catalogs.Counterparties.EmptyRef());		
	EndIf;
	
	Items.ListInventoryCrossReference.Visible = CrossReferenceVisible;
	Items.ShoppingCartCrossReference.Visible = CrossReferenceVisible;
	
	SetConditionalAppearance();
	
	SetFormItemsProperties();
	
	NativeLanguagesSupportServer.ChangeListQueryTextForCurrentLanguage(ThisObject,
		"ListInventory",
		"ListInventory",
		Metadata.Catalogs.Products);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	SetCartInfoLabelText();
	SetCartShowHideLabelText()
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	If Not FormIsClosing AND Not Exit Then
		If Object.ShoppingCart.Count() Then
			Cancel = True;
			ShowQueryBox(New NotifyDescription("BeforeClosingQueryBoxHandler", ThisObject),
					NStr("en = 'Add selected rows to document?'; ru = 'Добавить отмеченные позиции в документ?';pl = 'Dodać wybrane wiersze do dokoumentu?';es_ES = '¿Añadir las filas seleccionadas al documento?';es_CO = '¿Añadir las filas seleccionadas al documento?';tr = 'Seçilen satırlar belgeye eklensin mi?';it = 'Aggiungere le righe selezionate al documento?';de = 'Ausgewählte Zeilen zum Dokument hinzufügen?'"),
					QuestionDialogMode.YesNoCancel);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	UserSettingsToBeSaved = New Structure;
	UserSettingsToBeSaved.Insert("RequestQuantity", SelectionSettingsCache.RequestQuantity);
	UserSettingsToBeSaved.Insert("RequestPrice", SelectionSettingsCache.RequestPrice);
	UserSettingsToBeSaved.Insert("ShowCart", SelectionSettingsCache.ShowCart);
	UserSettingsToBeSaved.Insert("StockStatusFilter", StockStatusFilter);
	If SelectionSettingsCache.ShowPrice And Not SelectionSettingsCache.PriceWithFormula Then
		UserSettingsToBeSaved.Insert("ShowItemsWithPriceOnly", ShowItemsWithPriceOnly);
	EndIf;
	UserSettingsSaving(UserSettingsToBeSaved);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandler

&AtClient
Procedure StockStatusFilterOnChange(Item)
	
	FilterData = New Structure;
	
	FilterData.Insert("InStock",	StockStatusFilter = PredefinedValue("Enum.StockStatusFilters.InStock"));
	FilterData.Insert("Available",	StockStatusFilter = PredefinedValue("Enum.StockStatusFilters.Available"));
	
	ListFiltersChangeHandler(FilterData, DataCompositionComparisonType.Greater);
	
EndProcedure

&AtClient
Procedure StockWarehouseOnChange(Item)
	
	CommonClientServer.SetDynamicListParameter(ListInventory,		"StockWarehouse", StockWarehouse);
	CommonClientServer.SetDynamicListParameter(ListCharacteristics,	"StockWarehouse", StockWarehouse);
	CommonClientServer.SetDynamicListParameter(ListBatches,			"StockWarehouse", StockWarehouse);
	
	ProductRow = Items.ListInventory.CurrentData;
	If ProductRow <> Undefined Then
		CurrentProductReferentialBatches = ProductRow.ReferentialBatches;
		CommonClientServer.SetDynamicListParameter(ListBatches, "ReferentialBatches", CurrentProductReferentialBatches);
	EndIf;
	
	StockCellOnChange(Undefined);
	
EndProcedure

&AtClient
Procedure ShowItemsWithPriceOnlyOnChange(Item)
	
	ListFiltersChangeHandler(New Structure("Price", ShowItemsWithPriceOnly), DataCompositionComparisonType.Filled);
	
EndProcedure

&AtClient
Procedure SearchTextClearing(Item, StandardProcessing)
	
	SearchAndSetFilter("");
	
EndProcedure

&AtClient
Procedure SearchTextEditTextChange(Item, Text, StandardProcessing)
	
	SearchAndSetFilter(Text);
	
EndProcedure

&AtClient
Procedure CartShowHideLabelClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectionSettingsCache.ShowCart = Not SelectionSettingsCache.ShowCart;
	SetCartShowHideLabelText();
	
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCart", "Visible", SelectionSettingsCache.ShowCart);
	
EndProcedure

&AtClient
Procedure StockCellOnChange(Item)
	
	CommonClientServer.SetDynamicListParameter(ListInventory,		"StockCell", StockCell);
	CommonClientServer.SetDynamicListParameter(ListCharacteristics,	"StockCell", StockCell);
	CommonClientServer.SetDynamicListParameter(ListBatches,			"StockCell", StockCell);
	
	ProductRow = Items.ListInventory.CurrentData;
	If ProductRow <> Undefined Then
		CurrentProductReferentialBatches = ProductRow.ReferentialBatches;
		CommonClientServer.SetDynamicListParameter(ListBatches, "ReferentialBatches", CurrentProductReferentialBatches);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListInventoryTable

&AtClient
Procedure ListInventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If CurrentProductUseCharacteristics
		Or CurrentProductUseBatches Then
		
		If CurrentProductUseCharacteristics Then
			ShowCharacteristicsList();
		Else
			CurrentCharacteristic = PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef");
			ShowBatchesList();
		EndIf;
		
	Else
		
		AddProductsToCart();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListInventoryOnActivateRow(Item)
	
	DataCurrentRows = Items.ListInventory.CurrentData;
	
	If DataCurrentRows <> Undefined Then
		
		CurrentProduct = DataCurrentRows.ProductsRef;
		CurrentProductUseCharacteristics = DataCurrentRows.UseCharacteristics;
		CurrentProductUseBatches = DataCurrentRows.UseBatches And SelectionSettingsCache.ShowBatch;
		CurrentProductReferentialBatches = DataCurrentRows.ReferentialBatches;
		CurrentCrossReference = DataCurrentRows.CrossReference;
		
	EndIf;
		
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ListInventoryDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListCharacteristicsTable

&AtClient
Procedure ListCharacteristicsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If CurrentProductUseBatches Then
				
		ShowBatchesList();
		
	Else
		
		AddProductsToCart();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListCharacteristicsOnActivateRow(Item)
	
	DataCurrentRows = Items.ListCharacteristics.CurrentData;
	
	If DataCurrentRows <> Undefined Then
		
		CurrentCharacteristic = DataCurrentRows.CharacteristicRef;
		CurrentCrossReference = DataCurrentRows.CrossReference;
		
	EndIf;
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ListCharacteristicsDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListBatchesTable

&AtClient
Procedure ListBatchesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

&AtClient
Procedure ListBatchesOnActivateRow(Item)
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ListBatchesDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListWarehouseBalancesTable

&AtClient
Procedure ListWarehouseBalancesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

&AtClient
Procedure ListWarehouseBalancesDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListProductsHierarchyTable

&AtClient
Procedure ListProductsHierarchyOnActivateRow(Item)
	
	AttachIdleHandler("SetListInventoryParentFilter", 0.2, True);
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfShoppingCartTable

&AtClient
Procedure ShoppingCartOnChange(Item)
	
	SetCartInfoLabelText();
	
EndProcedure

&AtClient
Procedure ShoppingCartProductsOnChange(Item)
	
	CartRow = Items.ShoppingCart.CurrentData;
	
	DataStructure = New Structure();
	DataStructure.Insert("Company", Object.Company);
	DataStructure.Insert("Products", CartRow.Products);
	DataStructure.Insert("Characteristic", CartRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
		DataStructure.Insert("PriceKind", Object.PriceKind);
		DataStructure.Insert("ProcessingDate", Object.Date);
		DataStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
		DataStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	EndIf;
	
	GetDataProductsOnChange(DataStructure);
	
	CartRow.MeasurementUnit = DataStructure.MeasurementUnit;
	CartRow.Factor = DataStructure.Factor;
	CartRow.Price = DataStructure.Price;
	CartRow.VATRate = GetVATRate(DataStructure.VATRate);
	CartRow.Taxable = GetTaxable(DataStructure.Products);
	
	CalculateAmountInTabularSectionLine(CartRow);
	
EndProcedure

&AtClient
Procedure ShoppingCartCharacteristicOnChange(Item)
	
	CartRow = Items.ShoppingCart.CurrentData;
	
	If ValueIsFilled(Object.PriceKind) Then
		
		DataStructure = New Structure();
		DataStructure.Insert("Products",			CartRow.Products);
		DataStructure.Insert("Characteristic",		CartRow.Characteristic);
		DataStructure.Insert("PriceKind",			Object.PriceKind);
		DataStructure.Insert("ProcessingDate",		Object.Date);
		DataStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
		DataStructure.Insert("Factor",				CartRow.Factor);
		DataStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		DataStructure.Insert("Company",				Object.Company);
		
		GetDataCharacteristicOnChange(DataStructure);
		
		CartRow.Price = DataStructure.Price;
		
		CalculateAmountInTabularSectionLine(CartRow);

	EndIf;
	
EndProcedure

&AtClient
Procedure ShoppingCartQuantityOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure

&AtClient
Procedure ShoppingCartMeasurementUnitOnChange(Item)
	
	CartRow = Items.ShoppingCart.CurrentData;
	
	If TypeOf(CartRow.MeasurementUnit) = Type("CatalogRef.UOM")
		AND ValueIsFilled(CartRow.MeasurementUnit) Then
		
		NewFactor = GetUOMFactor(CartRow.MeasurementUnit);
		
	Else
		
		NewFactor = 1;
		
	EndIf;
	
	If CartRow.Factor <> 0 AND CartRow.Price <> 0 Then
		
		CartRow.Price = CartRow.Price * NewFactor / CartRow.Factor;
		
	EndIf;
	
	CartRow.Factor = NewFactor;
	
	CalculateAmountInTabularSectionLine(CartRow);
	
EndProcedure

&AtClient
Procedure ShoppingCartPriceOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure

&AtClient
Procedure ShoppingCartDiscountMarkupPercentOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure

&AtClient
Procedure ShoppingCartAmountOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	If StringCart.DiscountMarkupPercent = 100 Then
		
		StringCart.Amount = 0;
		
	ElsIf StringCart.Quantity <> 0 Then
		
		StringCart.Price = StringCart.Amount / (1 - StringCart.DiscountMarkupPercent / 100) / StringCart.Quantity;
		
	EndIf;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure ShoppingCartVATRateOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure ShoppingCartVATAmountOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure MoveToDocument(Command)
	
	If Object.ShoppingCart.Count() = 0 Then
		
		If (Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts 
			And Items.ListInventory.CurrentData = Undefined)
			Or (Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics 
			And Items.ListCharacteristics.CurrentData = Undefined) 
			Or (Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches 
			And Items.ListBatches.CurrentData = Undefined) Then
			
			MoveToDocumentAndClose();
			
		Else
		
			Mode = QuestionDialogMode.YesNo;
			Notification = New NotifyDescription("MoveToDocumentEnd", ThisObject);
			TextQuery = NStr("en = 'Selected items were not added to the cart. 
							|Do you want to automatically add them to the Products table?'; 
							|ru = 'Выбранные товары не были добавлены в корзину. 
							|Добавить их в табличную часть ""Номенклатура"" автоматически?';
							|pl = 'Wybrane elementy nie zostały dodane do koszyka. 
							|Czy chcesz automatycznie je dodać do tabeli Produkty?';
							|es_ES = 'Los artículos seleccionados no se han añadido al carrito. 
							|¿Quiere añadirlos automáticamente a la tabla de Productos?';
							|es_CO = 'Los artículos seleccionados no se han añadido al carrito. 
							|¿Quiere añadirlos automáticamente a la tabla de Productos?';
							|tr = 'Seçilen öğeler sepete eklenmedi. 
							|Bunları otomatik olarak Ürünler tablosuna eklemek ister misiniz?';
							|it = 'Gli elementi selezionati non sono stati aggiunti al carrello. 
							|Vuoi aggiungerli automaticamente alla tabella Articoli?';
							|de = 'Die ausgewählten Positionen wurden nicht der Karte hinzugefügt. 
							|Möchten Sie sie zur Produkttabelle automatisch hinzufügen lassen?'"); 
			ShowQueryBox(Notification, TextQuery, Mode, 0); 
		
		EndIf;
		
	Else
		
		MoveToDocumentAndClose();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MoveToDocumentEnd(Result, ParametersStructure) Export
	
	If Result = DialogReturnCode.Yes Then
		
		If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
			
			AddRowsToShoppingCart("ListInventory");
			
		ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
			
			AddRowsToShoppingCart("ListCharacteristics");
			
		ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
			
			AddRowsToShoppingCart("ListBatches");
			
		EndIf;
		
	EndIf;
	
	MoveToDocumentAndClose();
	
EndProcedure

&AtClient
Procedure TransitionSearch(Command)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		SetCurrentFormItem(Items.ListInventorySearchText);
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		SetCurrentFormItem(Items.ListCharacteristicsSearchText);
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		SetCurrentFormItem(Items.ListBatchesSearchText);
	EndIf;
	
EndProcedure

&AtClient
Procedure TransitionProductsList(Command)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		SetCurrentFormItem(Items.ListInventory);
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		SetCurrentFormItem(Items.ListCharacteristics);
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		SetCurrentFormItem(Items.ListBatches);
	EndIf;
	
EndProcedure

&AtClient
Procedure TransitionHierarchy(Command)
	
	SetCurrentFormItem(Items.ListProductsHierarchy);
	
EndProcedure

&AtClient
Procedure TransitionCart(Command)
	
	If Not SelectionSettingsCache.ShowCart Then
		
		SelectionSettingsCache.ShowCart = True;
		SetCartShowHideLabelText();
		CommonClientServer.SetFormItemProperty(Items, "ShoppingCart", "Visible", SelectionSettingsCache.ShowCart);
		
	EndIf;
	
	SetCurrentFormItem(Items.ShoppingCart);
	
EndProcedure

&AtClient
Procedure RequestQuantity(Command)
	
	SelectionSettingsCache.RequestQuantity = Not SelectionSettingsCache.RequestQuantity;
	CommonClientServer.SetFormItemProperty(Items, "FormCommandsSettingsRequestQuantity", "Check", SelectionSettingsCache.RequestQuantity);
	
EndProcedure

&AtClient
Procedure RequestPrice(Command)
	
	SelectionSettingsCache.RequestPrice = Not SelectionSettingsCache.RequestPrice;
	CommonClientServer.SetFormItemProperty(Items, "FormCommandsSettingsRequestPrice", "Check", SelectionSettingsCache.RequestPrice);
	
EndProcedure

&AtClient
Procedure InformationAboutDocument(Command)
	
	OpenForm("DataProcessor.ProductsSelection.Form.InformationAboutDocument",
		SelectionSettingsCache.InformationAboutDocument,
		ThisObject, True, , , Undefined, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AddToCart(Command)
	
	AddProductsToCart();
	
EndProcedure

&AtClient
Procedure SubstituteGoods(Command)
	
	If Items.ListInventorySubstituteGoods.Check Then
		
		CommonClientServer.DeleteDynamicListFilterGroupItems(ListInventory, "ProductsRef");
		Items.ListInventorySubstituteGoods.Check = False;
		
		Return;
		
	EndIf;
	
	DataCurrentRows = Items.ListInventory.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		FilterBySubstituteGoods(DataCurrentRows.ProductsRef);
		
		Items.ListInventorySubstituteGoods.Check = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToParent(Command)
	
	CurrentListCurrentData = GetCurrentListCurrentData();
	
	If CurrentListCurrentData <> Undefined Then
		
		Items.ListProductsHierarchy.CurrentRow = CurrentListCurrentData.Parent;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReservationDetails(Command)
	
	CurrentListCurrentData = GetCurrentListCurrentData();
	If CurrentListCurrentData = Undefined Then
		Return;
	EndIf;
	
	DetailsParameters = New Structure;
	DetailsParameters.Insert("Company", Object.Company);
	DetailsParameters.Insert("Products", CurrentListCurrentData.ProductsRef);
	DetailsParameters.Insert("Characteristic", CurrentListCurrentData.CharacteristicRef);
	DetailsParameters.Insert("Batch", CurrentListCurrentData.BatchRef);
	
	OpenForm("DataProcessor.ProductsSelection.Form.ReservationDetails",
		DetailsParameters, ThisObject, True, , , Undefined, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
// Command is temporarily disabled
Procedure ChangePrice(Command)
	
	CurrentListCurrentData = GetCurrentListCurrentData();
	
	If CurrentListCurrentData <> Undefined Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("Period", Object.PricePeriod);
		ParametersStructure.Insert("PriceKind", Object.PriceKind);
		ParametersStructure.Insert("Products", CurrentListCurrentData.ProductsRef);
		ParametersStructure.Insert("Characteristic", CurrentListCurrentData.CharacteristicRef);
		ParametersStructure.Insert("MeasurementUnit", CurrentListCurrentData.MeasurementUnit);
		
		NotifyDescription = New NotifyDescription("UpdateListAfterPriceChange", ThisObject);
		
		RecordKey = GetPricesRecordKey(ParametersStructure);
		
		If RecordKey.RecordExists Then
			
			RecordKey.Delete("RecordExists");
			
			ParametersArray = New Array;
			ParametersArray.Add(RecordKey);
			
			RecordKeyRegister = New("InformationRegisterRecordKey.Prices", ParametersArray);
			
			OpenForm(
				"InformationRegister.Prices.RecordForm",
				New Structure("Key", RecordKeyRegister),
				ThisObject,
				,
				,
				,
				NotifyDescription,
				FormWindowOpeningMode.LockOwnerWindow);
			
		Else
			
			OpenForm(
				"InformationRegister.Prices.RecordForm",
				New Structure("FillingValues", ParametersStructure),
				ThisObject,
				,
				,
				,
				NotifyDescription,
				FormWindowOpeningMode.LockOwnerWindow);
			
		EndIf; 
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches
		AND CurrentProductUseCharacteristics Then
		
		ShowCharacteristicsList();
		
	Else
		
		ShowInventoryList();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BackToProducts(Command)
	ShowInventoryList();
EndProcedure

// Bundles
&AtClient
Procedure ShowBundlesWithThisProduct(Command)
	
	If Items.ListShowBundlesWithThisProduct.Check Then
		
		CommonClientServer.DeleteDynamicListFilterGroupItems(ListInventory, "ProductsRef");
		Items.ListShowBundlesWithThisProduct.Check = False;
		
		Return;
		
	EndIf;
	
	DataCurrentRows = Items.ListInventory.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		FilterByBundlesWithThisProduct(DataCurrentRows.ProductsRef);
		
		Items.ListShowBundlesWithThisProduct.Check = True;
		
	EndIf;
	
EndProcedure
// End Bundles

#EndRegion

#Region InternalProceduresAndFunctions

#Region FormInitialization

&AtServer
Procedure FillObjectData()
	
	FillPropertyValues(Object, Parameters);
	
	PriceKindAttributesValues = Common.ObjectAttributesValues(
		Object.PriceKind,
		"PriceCurrency,
		|PricesBaseKind,
		|Percent,
		|PriceCalculationMethod");
	
	Object.PriceKindCurrency = PriceKindAttributesValues.PriceCurrency;
	Object.PriceCalculationMethod = PriceKindAttributesValues.PriceCalculationMethod;
	
	If PriceKindAttributesValues.PriceCalculationMethod = Enums.PriceCalculationMethods.CalculatedDynamic Then
		
		Object.DynamicPriceKindBasic = PriceKindAttributesValues.PricesBaseKind;
		Object.DynamicPriceKindPercent = PriceKindAttributesValues.Percent;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInformationAboutDocument(InformationAboutDocument)
	
	DataProcessors.ProductsSelection.InformationAboutDocumentStructure(InformationAboutDocument);
	FillPropertyValues(InformationAboutDocument, Object);
	InformationAboutDocument.Insert("DiscountsMarkupsVisible", Parameters.DiscountsMarkupsVisible);
	
EndProcedure

&AtServer
Procedure SetDynamicListParameters()
	
	ListsArray = New Array;
	ListsArray.Add(ListInventory);
	ListsArray.Add(ListCharacteristics);
	ListsArray.Add(ListBatches);
	
	ExchangeRate = DriveServer.GetExchangeRate(Object.Company, Object.PriceKindCurrency, Object.DocumentCurrency, Object.Date);
	
	For Each DynamicList In ListsArray Do
		
		DynamicList.Parameters.SetParameterValue("PriceKindCurrencyRate",			ExchangeRate.InitRate);
		DynamicList.Parameters.SetParameterValue("PriceKindCurrencyMultiplicity",	ExchangeRate.RepetitionBeg);
		DynamicList.Parameters.SetParameterValue("DocumentCurrencyRate",			ExchangeRate.Rate);
		DynamicList.Parameters.SetParameterValue("DocumentCurrencyMultiplicity",	ExchangeRate.Repetition);
		// Percent = 0 for the dynamical prices kinds, therefore the price does not change.
		DynamicList.Parameters.SetParameterValue("DynamicPriceKindPercent", 		Object.DynamicPriceKindPercent);
		
	EndDo;
	
	ListsArray.Add(ListProductsHierarchy);
	ListsArray.Add(ListWarehouseBalances);
	
	// Parameters filled in a special way
	ParemeterCompany = New DataCompositionParameter("Company");
	ParemeterPriceKind = New DataCompositionParameter("PriceKind");
	
	For Each DynamicList In ListsArray Do
		For Each ListParameter In DynamicList.Parameters.Items Do
			
			ObjectAttributeValue = Undefined;
			If ListParameter.Parameter = ParemeterCompany Then
				
				DynamicList.Parameters.SetParameterValue(ListParameter.Parameter, DriveServer.GetCompany(Object.Company));
				
			ElsIf ListParameter.Parameter = ParemeterPriceKind Then
				
				If ValueIsFilled(Object.DynamicPriceKindBasic) Then
					DynamicList.Parameters.SetParameterValue("PriceKind", Object.DynamicPriceKindBasic);
				Else
					DynamicList.Parameters.SetParameterValue("PriceKind", Object.PriceKind);
				EndIf;
				
			ElsIf Object.Property(ListParameter.Parameter, ObjectAttributeValue) Then
				
				If PickProductsInDocuments.IsValuesList(ObjectAttributeValue) Then
					ObjectAttributeValue = PickProductsInDocuments.ValueListIntoArray(ObjectAttributeValue);
				EndIf;
				
				DynamicList.Parameters.SetParameterValue(ListParameter.Parameter, ObjectAttributeValue);
				
			EndIf;
			
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetFormItemsProperties()
	
	PickProductsInDocuments.SetChoiceParameters(Items.ShoppingCartProducts, Object.ProductsType);
	
	CommonClientServer.SetFormItemProperty(Items, "FormCommandsSettingsRequestQuantity", "Check", SelectionSettingsCache.RequestQuantity);
	CommonClientServer.SetFormItemProperty(Items, "FormCommandsSettingsRequestPrice", "Check", SelectionSettingsCache.RequestPrice);
	
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCart", "Visible", SelectionSettingsCache.ShowCart);
	
	UseSeveralUnitsForProduct = GetFunctionalOption("UseSeveralUnitsForProduct");
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryMeasurementUnit", "Visible", UseSeveralUnitsForProduct);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsMeasurementUnit", "Visible", UseSeveralUnitsForProduct);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartMeasurementUnit", "Visible", UseSeveralUnitsForProduct);
	
	PriceKindIsFilled = ValueIsFilled(Object.PriceKind);
	CommonClientServer.SetFormItemProperty(Items, "ProductsListContextMenuChangePrice", "Enabled", PriceKindIsFilled);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsContextMenuPriceSetNew", "Enabled", PriceKindIsFilled);
	
	DiscountMarkupPercentVisible = SelectionSettingsCache.DiscountsMarkupsVisible Or SelectionSettingsCache.DiscountCardVisible;
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartDiscountMarkupPercent", "Visible", DiscountMarkupPercentVisible);
	
	AllowedToChangeAmount = SelectionSettingsCache.AllowedToChangeAmount;
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartPrice", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartAmount", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartVATAmount", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartTotal", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ProductsListContextMenuChangePrice", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsContextMenuPriceSetNew", "Enabled", AllowedToChangeAmount);
	
	ReservationEnabled = GetFunctionalOption("UseInventoryReservation");
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryReserve", "Visible", ReservationEnabled);
	CommonClientServer.SetFormItemProperty(Items, "ListWarehouseBalancesReserve", "Visible", ReservationEnabled);
	
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartBatch", "Visible", SelectionSettingsCache.ShowBatch);
	
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartGroupPrice", "Visible", SelectionSettingsCache.ShowPrice);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryPriceGroup", "Visible", SelectionSettingsCache.ShowPrice);
	
	PriceVisible = (SelectionSettingsCache.ShowPrice And Not SelectionSettingsCache.PriceWithFormula);
	
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryPrice", "Visible", PriceVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryShowItemsWithPriceOnly", "Visible", PriceVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsShowItemsWithPriceOnly", "Visible", PriceVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsPrice", "Visible", PriceVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesShowItemsWithPriceOnly", "Visible", PriceVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesPrice", "Visible", PriceVisible);
	
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryStockWarehouse", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryStockCell", "Visible", SelectionSettingsCache.FilterCellVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryInStock", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsStockWarehouse", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsStockCell", "Visible", SelectionSettingsCache.FilterCellVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsInStock", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesStockWarehouse", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesStockCell", "Visible", SelectionSettingsCache.FilterCellVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesInStock", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListWarehouseBalances", "Visible", SelectionSettingsCache.ShowAvailable);
	
	// Bundles
	CommonClientServer.SetFormItemProperty(Items, "ListShowBundlesWithThisProduct", "Visible", SelectionSettingsCache.ShowBundles);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryContextMenuShowBundlesWithThisProduct", "Visible", SelectionSettingsCache.ShowBundles);
	// End Bundles
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	FontWarehouse	= StyleFonts.FontDialogAndMenu;
	FontInventory	= New Font(FontWarehouse,,,False,,True);
	ColorGray		= WebColors.Gray;
	
	// ListInventory
	
	ItemAppearance = ListInventory.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("CountOfCrossReferences");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Greater;
	DataFilterItem.RightValue		= 1;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'drill down to see cross-references'; ru = 'детализация до номенклатуры поставщиков';pl = 'przesuń na dół, aby zobaczyć powiązane informacje';es_ES = 'clasificar para ver las referencias cruzadas';es_CO = 'clasificar para ver las referencias cruzadas';tr = 'çapraz referansları görmek için detaydan özete bakın';it = 'analizzare in dettaglio per visualizzare i riferimenti incrociati';de = 'drill down um die Herstellerartikelnummern anzusehen'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorGray);
	ItemAppearance.Appearance.SetParameterValue("Font", FontInventory);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("CrossReference");
	FieldAppearance.Use = True;
	
	// ListBatches
	
	ItemAppearance = ListBatches.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("DataParameters.ReferentialBatches");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorGray);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Available");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InStock");
	FieldAppearance.Use = True;
	
	// ListWarehouseBalances
	
	ItemAppearance = ListWarehouseBalances.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("StructuralUnit");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= New DataCompositionField("DocumentStructuralUnit");
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", FontWarehouse);
	
EndProcedure

#EndRegion

#Region FormCompletion

&AtClient
Procedure MoveToDocumentAndClose()
	FormIsClosing = True;
	Close(PutCartToTempStorage());
EndProcedure

&AtServer
Function PutCartToTempStorage() 
	
	CartAddressInStorage = PutToTempStorage(Object.ShoppingCart.Unload(), Object.OwnerFormUUID);
	
	ResultStructure = New Structure;
	ResultStructure.Insert("CartAddressInStorage", 	CartAddressInStorage);
	ResultStructure.Insert("OwnerFormUUID", 		Object.OwnerFormUUID);
	ResultStructure.Insert("StockWarehouse", 		StockWarehouse);
	ResultStructure.Insert("StockCell", 			StockCell);
	
	Return ResultStructure;
	
EndFunction

&AtClient
Procedure BeforeClosingQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		MoveToDocumentAndClose();
	ElsIf QueryResult = DialogReturnCode.No Then
		FormIsClosing = True;
		Close();
	EndIf;

EndProcedure

&AtServerNoContext
Procedure UserSettingsSaving(UserSettingsToBeSaved)
	For Each UserSetting In UserSettingsToBeSaved Do
		DriveServer.SetUserSetting(UserSetting.Value, UserSetting.Key);
	EndDo;
EndProcedure

#EndRegion

#Region FullTextAndContextSearch

&AtServer
Procedure EnableFulltextSearchOnOpenSelection()
	
	// temporarily disabled
	UseFullTextSearch = False;
	
	If UseFullTextSearch Then
		
		RelevancyFullTextSearchIndex = FullTextSearch.IndexTrue();
		
		If Not RelevancyFullTextSearchIndex Then
			
			// in the unseparated IB, the index is considered recent within a day
			RelevancyFullTextSearchIndex = FullTextSearch.UpdateDate() >= (CurrentSessionDate() - (1*24*60*60));
			
		EndIf;
		
	EndIf;
	
	SetSearchStringInputHintOnServer();
	
EndProcedure

&AtServer
Procedure SetSearchStringInputHintOnServer()
	
	FulltextSearchSetPartially = (UseFullTextSearch AND Not RelevancyFullTextSearchIndex);
	
	InputHint = ?(FulltextSearchSetPartially,
		NStr("en = 'Update the full-text search index...'; ru = 'Необходимо обновить индекс полнотекстового поиска...';pl = 'Aktualizacja indeksu wyszukiwania pełnotekstowego...';es_ES = 'Actualizar el índice de la búsqueda de texto completo...';es_CO = 'Actualizar el índice de la búsqueda de texto completo...';tr = 'Tam metin arama dizinini güncelle...';it = 'L''indice della ricerca full-text deve essere aggiornato ...';de = 'Aktualisieren Sie den Volltextsuchindex...'"),
		NStr("en = '(ALT+1) Enter search text ...'; ru = '(ALT+1) Введите текст поиска...';pl = '(ALT+1) Wprowadź wyszukiwany tekst...';es_ES = '(ALT+1) Introducir el texto de la búsqueda ...';es_CO = '(ALT+1) Introducir el texto de la búsqueda ...';tr = '(ALT+1) Arama metnini gir ...';it = '(ALT+1) Inserire testo di ricerca ...';de = '(ALT + 1) Suchtext eingeben...'"));
		
	Items.ListInventorySearchText.InputHint = InputHint;
	Items.ListCharacteristicsSearchText.InputHint = InputHint;
	Items.ListBatchesSearchText.InputHint = InputHint;
	
EndProcedure

&AtClient
Procedure SearchAndSetFilter(Text)
	
	If UseFullTextSearch Then
		FulltextSearchOnClient(Text);
	Else
		ContextSearchOnClient(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure FulltextSearchOnClient(Text)
	
	If IsBlankString(Text) Then
		
		DriveClient.DeleteListFilterItem(ListInventory, "ProductsRef");
		DriveClient.DeleteListFilterItem(ListCharacteristics, "CharacteristicRef");
		
	Else
		
		SearchResult = Undefined;
		ErrorDescription = FullTextSearchOnServerWithoutContext(Text, SearchResult);
		
		If IsBlankString(ErrorDescription) Then
			
			// Products
			Use = SearchResult.Products.Count() > 0;
			
			ItemArray = CommonClientServer.FindFilterItemsAndGroups(
				ListInventory.SettingsComposer.FixedSettings.Filter,
				"ProductsRef");
				
			If ItemArray.Count() = 0 Then
				CommonClientServer.AddCompositionItem(
					ListInventory.SettingsComposer.FixedSettings.Filter,
					"ProductsRef",
					DataCompositionComparisonType.InList,
					SearchResult.Products,
					,
					Use);
			Else
				CommonClientServer.ChangeFilterItems(
					ListInventory.SettingsComposer.FixedSettings.Filter,
					"ProductsRef",
					,
					SearchResult.Products,
					DataCompositionComparisonType.InList,
					Use);
			EndIf;
			
			// Characteristics
			Use = SearchResult.ProductsCharacteristics.Count() > 0;
			
			CharacteristicItemsArray = CommonClientServer.FindFilterItemsAndGroups(
				ListCharacteristics.SettingsComposer.FixedSettings.Filter,
				"CharacteristicRef");
				
			If CharacteristicItemsArray.Count() = 0 Then
				CommonClientServer.AddCompositionItem(
					ListCharacteristics.SettingsComposer.FixedSettings.Filter,
					"CharacteristicRef",
					DataCompositionComparisonType.InList,
					SearchResult.ProductsCharacteristics,
					,
					Use);
			Else
				CommonClientServer.ChangeFilterItems(
					ListCharacteristics.SettingsComposer.FixedSettings.Filter,
					"CharacteristicRef",
					,
					SearchResult.ProductsCharacteristics,
					DataCompositionComparisonType.InList,
					Use);
			EndIf;
			
		Else
			
			ShowMessageBox(Undefined,
				ErrorDescription,
				5,
				NStr("en = 'Search...'; ru = 'Поиск...';pl = 'Wyszukiwanie...';es_ES = 'Buscando...';es_CO = 'Buscando...';tr = 'Ara...';it = 'Ricerca...';de = 'Sucht...'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FullTextSearchOnServerWithoutContext(SearchString, SearchResult)
	
	ErrorDescription = "";
	SearchResult = PickProductsInDocumentsOverridable.SearchGoods(SearchString, ErrorDescription);
	
	Return ErrorDescription;
	
EndFunction

&AtClient
Procedure ContextSearchOnClient(Text)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		FieldsArray = New Array;
		FieldsArray.Add("ProductsRef.Description");
		FieldsArray.Add("ProductsRef.DescriptionFull");
		FieldsArray.Add("ProductsRef.SKU");
		FieldsArray.Add("ProductsCategory.Description");
		FieldsArray.Add("PriceGroup.Description");
		
		ContextSearchFilterSetting(ListInventory, FieldsArray, Text);
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		
		FieldsArray = New Array;
		FieldsArray.Add("CharacteristicRef.Description");
		
		ContextSearchFilterSetting(ListCharacteristics, FieldsArray, Text);
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		
		FieldsArray = New Array;
		FieldsArray.Add("BatchRef.Description");
		
		ContextSearchFilterSetting(ListBatches, FieldsArray, Text);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContextSearchFilterSetting(ListAttribute, FieldsArray, SearchText)
	
	FieldsGroupPresentation = "Context search";
	
	If IsBlankString(SearchText) Then
		
		CommonClientServer.DeleteDynamicListFilterGroupItems(
			ListAttribute,
			,
			FieldsGroupPresentation);
		
	Else
		
		ItemArray = CommonClientServer.FindFilterItemsAndGroups(
			ListAttribute.SettingsComposer.FixedSettings.Filter,
			,
			FieldsGroupPresentation);
			
		If ItemArray.Count() = 0 Then
			
			FilterGroup = CommonClientServer.CreateFilterItemGroup(
				ListAttribute.SettingsComposer.FixedSettings.Filter.Items,
				FieldsGroupPresentation,
				DataCompositionFilterItemsGroupType.OrGroup);
			
			For Each FilterField In FieldsArray Do
				CommonClientServer.AddCompositionItem(
					FilterGroup,
					FilterField,
					DataCompositionComparisonType.Contains,
					SearchText,
					,
					True);
			EndDo;
			
		Else
			
			For Each FilterField In FieldsArray Do
				CommonClientServer.ChangeFilterItems(
					ItemArray[0],
					FilterField,
					,
					SearchText,
					DataCompositionComparisonType.Contains,
					True);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CartAddingProductAndCalculations

&AtClient
Procedure AddProductsToCart()
	
	CurrentListCurrentDataArray = GetCurrentListCurrentDataArray();
	
	If CurrentListCurrentDataArray = Undefined Then
		Return;
	EndIf;
	
	IsOneRow = CurrentListCurrentDataArray.Count() = 1;
	
	For Each CurrentListCurrentData In CurrentListCurrentDataArray Do
		
		CartRowData = New Structure;
		
		CartRowData.Insert("CrossReference", CurrentListCurrentData.CrossReference);
		CartRowData.Insert("Products", CurrentListCurrentData.ProductsRef);
		CartRowData.Insert("Characteristic", CurrentListCurrentData.CharacteristicRef);
		CartRowData.Insert("Batch", CurrentListCurrentData.BatchRef);
		CartRowData.Insert("MeasurementUnit", CurrentListCurrentData.MeasurementUnit);
		CartRowData.Insert("Factor", CurrentListCurrentData.Factor);
		CartRowData.Insert("VATRate", GetVATRate(CurrentListCurrentData.VATRate));
		CartRowData.Insert("AvailableBasicUOM", CurrentListCurrentData.AvailableBasicUOM);
		
		If SelectionSettingsCache.PriceWithFormula Then
			
			ParametersStructure = New Structure("PriceKind, Products, Characteristic, MeasurementUnit");
			FillPropertyValues(ParametersStructure, CartRowData);
			ParametersStructure.PriceKind = Object.PriceKind;
			ParametersStructure.Insert("Company", Object.Company);
			
			Price = PriceGenerationFormulaServerCall.GetPriceByFormula(ParametersStructure);
			CartRowData.Insert("Price", CalculateProductsPrice(CartRowData.VATRate, Price));
			
		Else
			
			CartRowData.Insert("Price", CalculateProductsPrice(CartRowData.VATRate, CurrentListCurrentData.Price));
			
		EndIf;
		
		CartRowData.Insert("DiscountMarkupPercent", SelectionSettingsCache.DiscountMarkupPercent + SelectionSettingsCache.DiscountPercentByDiscountCard);
		CartRowData.Insert("Quantity", 1);
		CartRowData.Insert("Taxable", GetTaxable(CartRowData.Products));
		
		If (SelectionSettingsCache.RequestQuantity Or SelectionSettingsCache.RequestPrice) AND IsOneRow Then
			
			CartRowData.Insert("SelectionSettingsCache", SelectionSettingsCache);
			
			NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterSelectionQuantityAndPrice", ThisObject, CartRowData);
			OpenForm("DataProcessor.ProductsSelection.Form.QuantityAndPrice",
				CartRowData, ThisObject, True, , ,NotificationDescriptionOnCloseSelection , FormWindowOpeningMode.LockOwnerWindow);
			
		Else
			
			AddProductsToCartCompletion(CartRowData);
			
			If Not SelectionSettingsCache.ShowCart Then
				ShowUserNotification(
					Nstr("en = 'Item added to cart'; ru = 'Товар добавлен в корзину';pl = 'Pozycja dodana do koszyka';es_ES = 'Artículo añadido a la cesta';es_CO = 'Artículo añadido a la cesta';tr = 'Öğe sepete eklendi';it = 'Articolo aggiunto al carrello';de = 'Artikel in den Warenkorb gelegt'"),
					,
					StringFunctionsClientServer.SubstituteParametersToString("%1 %2 %3 %4",
					    CartRowData.CrossReference,
						CartRowData.Products,
						CartRowData.Characteristic,
						CartRowData.Batch));
			EndIf;
			
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure AfterSelectionQuantityAndPrice(ClosingResult, CartRowData) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		CartRowData.Quantity = ClosingResult.Quantity;
		CartRowData.Price = ClosingResult.Price;
		CartRowData.MeasurementUnit = ClosingResult.MeasurementUnit;
		CartRowData.Factor = ClosingResult.Factor;
		
		AddProductsToCartCompletion(CartRowData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddProductsToCartCompletion(CartRowData)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Products", CartRowData.Products);
	FilterStructure.Insert("Characteristic", CartRowData.Characteristic);
	FilterStructure.Insert("Batch", CartRowData.Batch);
	FilterStructure.Insert("MeasurementUnit", CartRowData.MeasurementUnit);
	FilterStructure.Insert("Price", CartRowData.Price);
	
	FoundRows = Object.ShoppingCart.FindRows(FilterStructure);
		
	If FoundRows.Count() = 0 Then
		
		CartRow = Object.ShoppingCart.Add();
		FillPropertyValues(CartRow, CartRowData);
		
	Else
		
		CartRow = FoundRows[0];
		CartRow.Quantity = CartRow.Quantity + CartRowData.Quantity;
		
	EndIf;
	
	CalculateAmountInTabularSectionLine(CartRow);
	
	SetCartInfoLabelText();
	
EndProcedure

&AtServerNoContext
Procedure GetDataProductsOnChange(DataStructure)
	
	DataStructure.Insert("MeasurementUnit", DataStructure.Products.MeasurementUnit);
	DataStructure.Insert("Factor", 1);
	
	If ValueIsFilled(DataStructure.PriceKind) Then
		DataStructure.Insert("Price", DriveServer.GetProductsPriceByPriceKind(DataStructure));
	Else
		DataStructure.Insert("Price", 0);
	EndIf;
	
	DataStructure.Insert("VATRate", DataStructure.Products.VATRate);
	
EndProcedure

&AtServerNoContext
Procedure GetDataCharacteristicOnChange(DataStructure)
	
	If ValueIsFilled(DataStructure.PriceKind) Then
		DataStructure.Insert("Price", DriveServer.GetProductsPriceByPriceKind(DataStructure));
	Else
		DataStructure.Insert("Price", 0);
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
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
	StringCart.IsBundle = GetIsBundle(StringCart.Products);
	
EndProcedure

&AtClient
Procedure CalculateVATSUM(StringCart)
	
	VATRate = DriveReUse.GetVATRateValue(StringCart.VATRate);
	
	StringCart.VATAmount = ?(Object.AmountIncludesVAT, 
									StringCart.Amount - (StringCart.Amount) / ((VATRate + 100) / 100),
									StringCart.Amount * VATRate / 100);
	
EndProcedure

&AtClient
Function CalculateProductsPrice(VATRate, Price)
	
	PricesKindPriceIncludesVAT = SelectionSettingsCache.PricesKindPriceIncludesVAT;
	
	If Object.AmountIncludesVAT = PricesKindPriceIncludesVAT Then
		
		Return Price;
		
	ElsIf Object.AmountIncludesVAT > PricesKindPriceIncludesVAT Then
		
		VATRateValue = DriveReUse.GetVATRateValue(VATRate);
		Return Price * (100 + VATRateValue) / 100;
		
	Else
		
		VATRateValue = DriveReUse.GetVATRateValue(VATRate);
		Return Price * 100 / (100 + VATRateValue);
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function GetIsBundle(Product)
	
	Return Common.ObjectAttributeValue(Product, "IsBundle");
	
EndFunction

&AtServerNoContext
Function GetTaxable(Product)
	
	Return Common.ObjectAttributeValue(Product, "Taxable");
	
EndFunction

&AtServerNoContext
Function GetUOMFactor(MeasurementUnit)
	
	Return Common.ObjectAttributeValue(MeasurementUnit, "Factor");
	
EndFunction

&AtClient
Function GetVATRate(VATRate)
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If ValueIsFilled(VATRate) Then
			
			Return VATRate;
			
		Else
			
			Return GetCompanyVATRate(Object.Company);
		
		EndIf;
		
	Else
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			
			Return PredefinedValue("Catalog.VATRates.Exempt");
			
		Else
			
			Return PredefinedValue("Catalog.VATRates.ZeroRate");
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function GetCompanyVATRate(Company)
	
	Return InformationRegisters.AccountingPolicy.GetDefaultVATRate(, Company);
	
EndFunction

#EndRegion

#Region ListsManagement

// Bundles

&AtClient
Procedure FilterByBundlesWithThisProduct(Products)
	
	ListOfBundles = New ValueList;
	GetBundles(Products, ListOfBundles);
	
	ItemArray = CommonClientServer.FindFilterItemsAndGroups(
		ListInventory.SettingsComposer.FixedSettings.Filter,
		"ProductsRef");
	
	If ItemArray.Count() = 0 Then
		CommonClientServer.AddCompositionItem(
			ListInventory.SettingsComposer.FixedSettings.Filter,
			"ProductsRef",
			DataCompositionComparisonType.InList,
			ListOfBundles);
	Else
		CommonClientServer.ChangeFilterItems(
			ListInventory.SettingsComposer.FixedSettings.Filter,
			"ProductsRef",
			,
			ListOfBundles,
			DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure GetBundles(Products, ListOfBundles)
	
	ListOfBundles.Clear();
	
	QueryText = "SELECT
	|	BundlesComponents.BundleProduct AS BundleProduct,
	|	BundlesComponents.BundleCharacteristic AS BundleCharacteristic
	|FROM
	|	InformationRegister.BundlesComponents AS BundlesComponents
	|WHERE
	|	BundlesComponents.Products = &Products";
	
	Query = New Query(QueryText);
	Query.SetParameter("Products", Products);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ListOfBundles.Add(Selection.BundleProduct);
		
	EndDo;
	
EndProcedure

// End Bundles

&AtClient
Procedure FilterBySubstituteGoods(Products)
	
	ListSubstituteGoods = New ValueList;
	GetSubstituteGoods(Products, ListSubstituteGoods);
	
	ItemArray = CommonClientServer.FindFilterItemsAndGroups(
		ListInventory.SettingsComposer.FixedSettings.Filter,
		"ProductsRef");
	
	If ItemArray.Count() = 0 Then
		CommonClientServer.AddCompositionItem(
			ListInventory.SettingsComposer.FixedSettings.Filter,
			"ProductsRef",
			DataCompositionComparisonType.InList,
			ListSubstituteGoods);
	Else
		CommonClientServer.ChangeFilterItems(
			ListInventory.SettingsComposer.FixedSettings.Filter,
			"ProductsRef",
			,
			ListSubstituteGoods,
			DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure GetSubstituteGoods(Products, ListSubstituteGoods)
	
	ListSubstituteGoods.Clear();
	
	QueryText = "SELECT
	|	Analogs.Products AS Products,
	|	Analogs.Analog AS Analog,
	|	Analogs.Priority AS Priority,
	|	Analogs.Comment AS Comment
	|FROM
	|	InformationRegister.SubstituteGoods AS Analogs
	|WHERE
	|	Analogs.Products = &Products
	|
	|ORDER BY
	|	Analogs.Priority";
	
	Query = New Query(QueryText);
	Query.SetParameter("Products", Products);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ListSubstituteGoods.Add(Selection.Analog);
		
	EndDo;
	
	ListSubstituteGoods.Insert(0, Products);
	
EndProcedure

&AtClient
Procedure ShowInventoryList()
	
	CommonClientServer.SetFormItemProperty(Items, "ListProductsHierarchy", "Enabled", True);
	
	Items.ListProductsHierarchy.TextColor = New Color();
	
	Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts;
	SetCurrentFormItem(Items.ListInventory);
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ShowCharacteristicsList()
	
	ItemArray = CommonClientServer.FindFilterItemsAndGroups(
		ListCharacteristics.SettingsComposer.FixedSettings.Filter, "Owner");
		
	If ItemArray.Count() = 0 Then
		CommonClientServer.AddCompositionItem(
			ListCharacteristics.SettingsComposer.FixedSettings.Filter,
			"Owner",
			DataCompositionComparisonType.Equal,
			CurrentProduct);
	Else
		CommonClientServer.ChangeFilterItems(
			ListCharacteristics.SettingsComposer.FixedSettings.Filter,
			"Owner",
			,
			CurrentProduct,
			DataCompositionComparisonType.Equal);
	EndIf;
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		CommonClientServer.SetFormItemProperty(Items, "ListProductsHierarchy", "Enabled", False);
		Items.ListProductsHierarchy.TextColor = SelectionSettingsCache.InaccessibleDataColor;
	EndIf;
	
	Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics;
	SetCurrentFormItem(Items.ListCharacteristics);
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ShowBatchesList()
	
	ItemArray = CommonClientServer.FindFilterItemsAndGroups(
		ListBatches.SettingsComposer.FixedSettings.Filter,
		"Owner");
		
	If ItemArray.Count() = 0 Then
		CommonClientServer.AddCompositionItem(
			ListBatches.SettingsComposer.FixedSettings.Filter,
			"Owner",
			DataCompositionComparisonType.Equal,
			CurrentProduct);
	Else
		CommonClientServer.ChangeFilterItems(
		ListBatches.SettingsComposer.FixedSettings.Filter,
		"Owner",
		,
		CurrentProduct,
		DataCompositionComparisonType.Equal);
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(ListBatches, "Characteristic", CurrentCharacteristic);
	CommonClientServer.SetDynamicListParameter(ListBatches, "CrossReference", CurrentCrossReference);
	CommonClientServer.SetDynamicListParameter(ListBatches, "ReferentialBatches", CurrentProductReferentialBatches);
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		CommonClientServer.SetFormItemProperty(Items, "ListProductsHierarchy", "Enabled", False);
		Items.ListProductsHierarchy.TextColor = SelectionSettingsCache.InaccessibleDataColor;
		
		CommonClientServer.SetFormItemProperty(Items, "ListBatchesBackToProducts", "Visible", False);
		
	Else
		
		CommonClientServer.SetFormItemProperty(Items, "ListBatchesBackToProducts", "Visible", True);
		
	EndIf;
	
	Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches;
	SetCurrentFormItem(Items.ListBatches);
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure SetListWarehouseBalancesFilters()
	
	If Not SelectionSettingsCache.ShowAvailable Then
		Return;
	EndIf;
	
	FilterValueProduct = Undefined;
	FilterValueCharacteristic = Undefined;
	FilterValueBatch = Undefined;
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		CurrentRowData = Items.ListInventory.CurrentData;
		If CurrentRowData <> Undefined Then
			FilterValueProduct = CurrentRowData.ProductsRef;
		EndIf;
		
		CommonClientServer.DeleteFilterItems(ListWarehouseBalances.Filter, "Characteristic");
		CommonClientServer.DeleteFilterItems(ListWarehouseBalances.Filter, "Batch");
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		
		FilterValueProduct = CurrentProduct;
		
		CurrentRowData = Items.ListCharacteristics.CurrentData;
		If CurrentRowData <> Undefined Then
			FilterValueCharacteristic = CurrentRowData.CharacteristicRef;
		EndIf;
		
		CommonClientServer.DeleteFilterItems(ListWarehouseBalances.Filter, "Batch");
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		
		FilterValueProduct = CurrentProduct;
		FilterValueCharacteristic = CurrentCharacteristic;
		
		CurrentRowData = Items.ListBatches.CurrentData;
		If CurrentRowData <> Undefined Then
			FilterValueBatch = CurrentRowData.BatchRef;
		EndIf;
		
	Else
		Return;
	EndIf;
	
	FiltersProducts = CommonClientServer.FindFilterItemsAndGroups(
		ListWarehouseBalances.Filter, "Products");
		
	If FiltersProducts.Count() = 0 Then
		CommonClientServer.AddCompositionItem(
			ListWarehouseBalances.Filter,
			"Products",
			DataCompositionComparisonType.Equal,
			FilterValueProduct);
	Else
		CommonClientServer.ChangeFilterItems(
			ListWarehouseBalances.Filter,
			"Products",
			,
			FilterValueProduct,
			DataCompositionComparisonType.Equal);
	EndIf;
	
	If FilterValueCharacteristic <> Undefined Then
		
		FiltersCharacteristic = CommonClientServer.FindFilterItemsAndGroups(
			ListWarehouseBalances.Filter, "Characteristic");
			
		If FiltersCharacteristic.Count() = 0 Then
			CommonClientServer.AddCompositionItem(
				ListWarehouseBalances.Filter,
				"Characteristic",
				DataCompositionComparisonType.Equal,
				FilterValueCharacteristic);
		Else
			CommonClientServer.ChangeFilterItems(
				ListWarehouseBalances.Filter,
				"Characteristic",
				,
				FilterValueCharacteristic,
				DataCompositionComparisonType.Equal);
		EndIf;
		
	EndIf;
	
	If FilterValueBatch <> Undefined Then
		
		FiltersBatch = CommonClientServer.FindFilterItemsAndGroups(
			ListWarehouseBalances.Filter, "Batch");
			
		If FiltersBatch.Count() = 0 Then
			CommonClientServer.AddCompositionItem(
				ListWarehouseBalances.Filter,
				"Batch",
				DataCompositionComparisonType.Equal,
				FilterValueBatch);
		Else
			CommonClientServer.ChangeFilterItems(
				ListWarehouseBalances.Filter,
				"Batch",
				,
				FilterValueBatch,
				DataCompositionComparisonType.Equal);
		EndIf;
		
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(
		ListWarehouseBalances,
		"Factor",
		?(CurrentRowData = Undefined
			Or CurrentRowData.Factor = 0,
			1,
			CurrentRowData.Factor));
	
EndProcedure

&AtClient
Procedure SetListInventoryParentFilter()
	
	SelectedGroups = Items.ListProductsHierarchy.SelectedRows;
	
	SelectedGroupsCount = SelectedGroups.Count();
	
	If SelectedGroupsCount = 0
		Or SelectedGroupsCount = 1
			AND Not ValueIsFilled(SelectedGroups[0]) Then
		
		CommonClientServer.DeleteDynamicListFilterGroupItems(ListInventory, "Parent");
		
	Else
		
		ItemArray = CommonClientServer.FindFilterItemsAndGroups(
			ListInventory.SettingsComposer.FixedSettings.Filter, "Parent");
			
		If ItemArray.Count() = 0 Then
			CommonClientServer.AddCompositionItem(
				ListInventory.SettingsComposer.FixedSettings.Filter,
				"Parent",
				DataCompositionComparisonType.InHierarchy,
				SelectedGroups);
		Else
			CommonClientServer.ChangeFilterItems(
				ListInventory.SettingsComposer.FixedSettings.Filter,
				"Parent",
				,
				SelectedGroups,
				DataCompositionComparisonType.InHierarchy);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListFiltersChangeHandler(FilterData, DataCompositionComparisonType)
	
	ListsArray = New Array;
	ListsArray.Add(ListInventory);
	ListsArray.Add(ListCharacteristics);
	ListsArray.Add(ListBatches);
	
	For Each CurrentList In ListsArray Do
		
		For Each FilterItem In FilterData Do
		
			If FilterItem.Value Then
				
				ItemArray = CommonClientServer.FindFilterItemsAndGroups(
					CurrentList.SettingsComposer.FixedSettings.Filter,
					FilterItem.Key);
				
				If ItemArray.Count() = 0 Then
					CommonClientServer.AddCompositionItem(
						CurrentList.SettingsComposer.FixedSettings.Filter,
						FilterItem.Key,
						DataCompositionComparisonType,
						0);
				Else
					CommonClientServer.ChangeFilterItems(
						CurrentList.SettingsComposer.FixedSettings.Filter,
						FilterItem.Key,
						,
						0,
						DataCompositionComparisonType);
				EndIf;
				
			Else
				
				CommonClientServer.DeleteDynamicListFilterGroupItems(CurrentList, FilterItem.Key);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Common

&AtClient
Function GetCurrentListCurrentDataArray()
	
	CurrentListCurrentData = New Array;
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		SelectedRows = Items.ListInventory.SelectedRows;
		For Each SelectedRow In SelectedRows Do
			CurrentListCurrentData.Add(Items.ListInventory.RowData(SelectedRow));
		EndDo;
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		
		SelectedRows = Items.ListCharacteristics.SelectedRows;
		For Each SelectedRow In SelectedRows Do
			CurrentListCurrentData.Add(Items.ListCharacteristics.RowData(SelectedRow));
		EndDo;
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		
		SelectedRows = Items.ListBatches.SelectedRows;
		For Each SelectedRow In SelectedRows Do
			CurrentListCurrentData.Add(Items.ListBatches.RowData(SelectedRow));
		EndDo;
		
	EndIf;
	
	Return CurrentListCurrentData;
	
EndFunction

&AtClient
Function GetCurrentListCurrentData()
	
	CurrentListCurrentData = Undefined;
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		CurrentListCurrentData = Items.ListInventory.CurrentData;
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		
		CurrentListCurrentData = Items.ListCharacteristics.CurrentData;
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		
		CurrentListCurrentData = Items.ListBatches.CurrentData;
		
	EndIf;
	
	Return CurrentListCurrentData;
	
EndFunction

&AtClient
Procedure SetCurrentFormItem(Item)
	CurrentItem = Item;
EndProcedure

&AtClient
Procedure SetCartInfoLabelText()
	
	If Object.TotalAmount > 0 Then
		If SelectionSettingsCache.ShowPrice Then
		
			CartInfoLabelPattern  = 
				NStr("en = 'Cart items: %1
					|Total: %2 %3
					|Total items: %4
					|Grand total: %5 %6'; 
					|ru = 'Позиций в корзине: %1
					|Итого: %2 %3
					|Всего позиций: %4\
					|Всего: %5 %6';
					|pl = 'Pozycje w koszyku: %1
					|Łącznie: %2 %3
					|Łącznie pozycji: %4
					|Łączna suma: %5 %6';
					|es_ES = 'Artículos de la cesta: %1
					|Total: %2 %3
					|Total de artículos: %4
					|Total general: %5 %6';
					|es_CO = 'Artículos de la cesta: %1
					|Total: %2 %3
					|Total de artículos: %4
					|Total general: %5 %6';
					|tr = 'Sepet öğeleri: %1
					|Toplam: %2 %3
					|Toplam öğe: %4
					|Genel toplam: %5 %6';
					|it = 'Elementi del carrello: %1
					|Totale: %2 %3
					|Elementi totali: %4
					|Totale complessivo: %5 %6';
					|de = 'Warenkorb-Artikel: %1
					|Gesamt: %2 %3
					|Gesamtzahl der Artikel: %4
					|Gesamtsumme: %5 %6'");
			
			CartInfoLabel = StringFunctionsClientServer.SubstituteParametersToString(
				CartInfoLabelPattern,
				Format(Object.ShoppingCart.Count(), "NZ="),
				Format(Object.ShoppingCart.Total("Total"), "ND=15; NFD=2; NZ="),
				Object.DocumentCurrency,
				Format(Object.ShoppingCart.Count() + Object.TotalItems, "NZ="),
				Format(Object.ShoppingCart.Total("Total") + Object.TotalAmount, "ND=15; NFD=2; NZ="),
				Object.DocumentCurrency);
			
		Else
			
			CartInfoLabelPattern  = 
				NStr("en = 'Cart items: %1
					|Total items: %2'; 
					|ru = 'Позиций в корзине: %1
					|Всего позиций: %2';
					|pl = 'Pozycje w koszyku: %1
					|Łącznie pozycji: %2';
					|es_ES = 'Artículos de la cesta: %1
					|Total de artúclos: %2';
					|es_CO = 'Artículos de la cesta: %1
					|Total de artúclos: %2';
					|tr = 'Sepet öğeleri: %1
					|Toplam öğe: %2';
					|it = 'Elementi carrello: %1
					|Elementi totali: %2';
					|de = 'Warenkorb-Artikel: %1
					|Gesamtzahl der Artikel: %2'");
			
			CartInfoLabel = StringFunctionsClientServer.SubstituteParametersToString(
				CartInfoLabelPattern,
				Format(Object.ShoppingCart.Count(), "NZ="),
				Format(Object.ShoppingCart.Count() + Object.TotalItems, "NZ="));
			
		EndIf;
	Else
		If SelectionSettingsCache.ShowPrice Then
		
			CartInfoLabelPattern = 
				NStr("en = 'Cart items: %1
					|Total: %2 %3'; 
					|ru = 'Позиций в корзине: %1
					|Итого: %2 %3';
					|pl = 'Pozycje w koszyku: %1
					|Łącznie: %2 %3';
					|es_ES = 'Artículos de la cesta: %1
					|Total:%2 %3';
					|es_CO = 'Artículos de la cesta: %1
					|Total:%2 %3';
					|tr = 'Sepet öğeleri: %1
					|Toplam: %2 %3';
					|it = 'Articoli carrello: %1
					|Totale: %2 %3';
					|de = 'Artikel im Warenkorb: %1
					|Gesamt: %2 %3'");
		
			CartInfoLabel = StringFunctionsClientServer.SubstituteParametersToString(
				CartInfoLabelPattern,
				Format(Object.ShoppingCart.Count(), "NZ="),
				Format(Object.ShoppingCart.Total("Total"), "ND=15; NFD=2; NZ="),
				Object.DocumentCurrency);
		Else
			
			CartInfoLabelPattern = NStr("en = 'Cart items: %1'; ru = 'Позиций в корзине: %1';pl = 'Pozycje w koszyku: %1';es_ES = 'Artículos de la cesta: %1';es_CO = 'Artículos de la cesta: %1';tr = 'Sepet öğeleri: %1';it = 'Articoli del carrello: %1';de = 'Warenkorbartikel: %1'");
		
			CartInfoLabel = StringFunctionsClientServer.SubstituteParametersToString(
				CartInfoLabelPattern,
				Format(Object.ShoppingCart.Count(), "NZ="));
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCartShowHideLabelText()
	
	If SelectionSettingsCache.ShowCart Then
		CartShowHideLabel = Nstr("en = 'Hide cart content'; ru = 'Скрыть содержимое корзины';pl = 'Ukryj zawartość koszyka';es_ES = 'Ocultar el contenido de la cesta';es_CO = 'Ocultar el contenido de la cesta';tr = 'Sepet içeriğini gizle';it = 'Nascondi contenuto carrello';de = 'Warenkorbinhalt ausblenden'");
	Else
		CartShowHideLabel = Nstr("en = 'Show cart content'; ru = 'Показать содержимое корзины';pl = 'Pokaż zawartość koszyka';es_ES = 'Mostrar el contenido de la cesta';es_CO = 'Mostrar el contenido de la cesta';tr = 'Sepet içeriğini göster';it = 'Mostra contenuto carrello';de = 'Warenkorbinhalt anzeigen'");
	EndIf;
	
EndProcedure

#EndRegion

#Region Other

&AtServerNoContext
Function GetPricesRecordKey(ParametersStructure)
	
	Return InformationRegisters.Prices.GetRecordKey(ParametersStructure);
	
EndFunction

&AtClient
Procedure UpdateListAfterPriceChange(ClosingResult, AdditionalParameters)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		Items.ListInventory.Refresh();
		
	Else
		
		Items.ListCharacteristics.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

&AtClient
Procedure AddRowsToShoppingCart(StringNameTable)
	
	ArraySelectedRows = Items[StringNameTable].SelectedRows;
	For Each ItemArray In ArraySelectedRows Do
		AddRowToShoppingCart(ItemArray, StringNameTable);
	EndDo;
	
EndProcedure

&AtClient
Procedure AddRowToShoppingCart(ItemArray, StringNameTable)
	
	DataRowInventory = Items[StringNameTable].RowData(ItemArray);
	
	RowShoppingCart = Object.ShoppingCart.Add();
	
	RowShoppingCart.Products		= DataRowInventory.ProductsRef;
	RowShoppingCart.CrossReference	= DataRowInventory.CrossReference;
	RowShoppingCart.Quantity		= 1;
	RowShoppingCart.Price			= DataRowInventory.Price;
	RowShoppingCart.MeasurementUnit	= DataRowInventory.MeasurementUnit;
	RowShoppingCart.Factor			= DataRowInventory.Factor;
	RowShoppingCart.VATRate			= GetVATRate(DataRowInventory.VATRate);
	RowShoppingCart.Taxable			= GetTaxable(DataRowInventory.ProductsRef);
	
	If StringNameTable = "ListCharacteristics" Then
		RowShoppingCart.Characteristic	= DataRowInventory.CharacteristicRef;
	ElsIf StringNameTable = "ListBatches" Then
		RowShoppingCart.Characteristic	= DataRowInventory.CharacteristicRef;
		RowShoppingCart.Batch			= DataRowInventory.BatchRef;
	EndIf;
		
	CalculateAmountInTabularSectionLine(RowShoppingCart);
	
EndProcedure

#EndRegion

#Region Initialize

FormIsClosing = False;

#EndRegion
