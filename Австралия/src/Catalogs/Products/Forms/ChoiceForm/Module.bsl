
#Region FormEventHandlers

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

&AtClient
Procedure FilterBalancesOnChange(Item)	
	SetFilterParametersServer();	
EndProcedure

&AtClient
Procedure FilterWarehouseOnChange(Item)	
	SetFilterParametersServer();	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("PriceKind") And ValueIsFilled(Parameters.PriceKind) Then
		Items.FilterPriceType.ReadOnly = True;
		FilterPriceType = Parameters.PriceKind;
	Else
		FilterPriceType = Catalogs.PriceTypes.GetMainKindOfSalePrices();
	EndIf;
	
	If ValueIsFilled(Parameters.FilterWarehouse) Then
		
		FilterBalances = 1;
		FilterWarehouse = Parameters.FilterWarehouse;
		
	EndIf;
	
	If ValueIsFilled(Parameters.FilterBalancesCompany) Then
		
		FilterBalancesCompany = Parameters.FilterBalancesCompany;
		
	EndIf;
	
	FillFilterHierarchy();
	FillFilterCategories();
	
	SetFilterParametersServer();
	
	// StandardSubsystems.BatchObjectModification
	If Items.Find("ListBatchObjectChanging") <> Undefined Then
		Items.ListBatchObjectChanging.Visible = AccessRight("Edit", Metadata.Catalogs.Products);
	EndIf;
	// End StandardSubsystems.BatchObjectModification
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	Items.FormDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	NativeLanguagesSupportServer.ChangeListQueryTextForCurrentLanguage(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(FilterHierarchyCategories) Then
		FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsHierarchy");
	EndIf;
	
	FilterHierarchyCategoriesOnChangeAtClient();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowBalancesOnChange(Item)
	
	SetFilterParametersServer();
	
EndProcedure

&AtClient
Procedure ShowPricesOnChange(Item)
	
	SetFilterParametersServer();
	
EndProcedure

&AtClient
Procedure PricesFromOnChange(Item)
	
	SetListFilterItemPrices(PricesFrom, PricesTo);
	
EndProcedure

&AtClient
Procedure PricesToOnChange(Item)
	
	SetListFilterItemPrices(PricesFrom, PricesTo);
	
EndProcedure

&AtClient
Procedure FilterPriceTypeOnChange(Item)
	
	SetListQueryParameters();
	
EndProcedure

&AtClient
Procedure FilterPriceTypeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure FilterHierarchyCategoriesOnChange(Item)
	
	FilterHierarchyCategoriesOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure FilterHierarchyOnActivateRow(Item)
	
	If Items.FilterHierarchy.CurrentData <> Undefined Then
		
		NewValue = Items.FilterHierarchy.CurrentData.Value;
		NewDescription = Items.FilterHierarchy.CurrentData.Description;
		
		For Each FilterItem In List.SettingsComposer.FixedSettings.Filter.Items Do
			
			If TypeOf(FilterItem) = Type("DataCompositionFilterItem") And String(FilterItem.LeftValue) = "Parent" Then
				
				If FilterItem.RightValue = NewValue
					And FilterItem.Presentation = NewDescription
					And FilterItem.Use Then
					
					Return;
					
				Else
					
					SetFilterHierarchy();
					Return;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If Not Items.FilterHierarchy.CurrentData.Description = NStr("en = '<Show all>'; ru = '<Показать все>';pl = '<Pokaż wszystkie>';es_ES = '<Mostrar todo>';es_CO = '<Mostrar todo>';tr = '<Tümünü göster>';it = '<Mostra tutto>';de = '<Alle anzeigen>'") Then
			SetFilterHierarchy();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterCategoriesOnActivateRow(Item)
	
	If FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsCategories") 
		And Items.FilterCategories.CurrentData <> Undefined
		And CurrentFilterCategory <> Items.FilterCategories.CurrentData.Value Then
		
		AttachIdleHandler("FilterCategoriesOnActivateRowAtClient", 0.2, True);
		CurrentItem = Items.FilterCategories;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = NOT Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Bundles
&AtClient
Procedure ShowBundlesWithThisProduct(Command)
	
	If Items.ListShowBundlesWithThisProduct.Check Then
		
		CommonClientServer.DeleteDynamicListFilterGroupItems(List, "Ref");
		Items.ListShowBundlesWithThisProduct.Check = False;
		
		Return;
		
	EndIf;
	
	DataCurrentRows = Items.List.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		FilterByBundlesWithThisProduct(DataCurrentRows.Ref);
		
		Items.ListShowBundlesWithThisProduct.Check = True;
		
	EndIf;
	
EndProcedure
// End Bundles

#EndRegion

#Region Private

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FilterCategoriesOnActivateRowAtClient()
	
	If FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsHierarchy") Then
		
		CurrentFilterCategory = PredefinedValue("Catalog.ProductsCategories.EmptyRef");
		
	ElsIf FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsCategories") Then
		
		If Items.FilterCategories.CurrentData = Undefined Then
			Return;
		EndIf;
		
		CurrentFilterCategory = Items.FilterCategories.CurrentData.Value;
		
	EndIf;
	
	FilterCategoriesOnActivateRowAtServer();
	
EndProcedure

&AtServer
Procedure FilterCategoriesOnActivateRowAtServer()
	
	CommonClientServer.SetDynamicListFilterItem(List, "ProductsCategory", CurrentFilterCategory, DataCompositionComparisonType.InHierarchy,, ValueIsFilled(CurrentFilterCategory));
	NativeLanguagesSupportServer.ChangeListQueryTextForCurrentLanguage(ThisObject);
	
EndProcedure

&AtClient
Procedure FilterHierarchyCategoriesOnChangeAtClient()
	
	If FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsCategories") Then
		
		Items.PagesHierarchyGroups.CurrentPage = Items.PageCategories;
		Items.FilterCategories.CurrentRow = 0;
		CommonClientServer.SetDynamicListFilterItem(List, "Parent", , , , False);
		AttachIdleHandler("FilterCategoriesOnActivateRowAtClient", 0.2, True);
		
	ElsIf FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsHierarchy") Then
		
		Items.PagesHierarchyGroups.CurrentPage = Items.PageHierarchy;
		Items.FilterHierarchy.CurrentRow = 0;
		AttachIdleHandler("FilterCategoriesOnActivateRowAtClient", 0.2, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetFilterHierarchy()
	
	If Items.FilterHierarchy.CurrentData <> Undefined Then
		
		ItIsFilterHierarchy = ValueIsFilled(Items.FilterHierarchy.CurrentData.Value);
		
		RightValue		= Undefined;
		Comparison		= DataCompositionComparisonType.Equal;
		Usage			= True;
		Presentation	= Items.FilterHierarchy.CurrentData.Description;
		
		If ItIsFilterHierarchy Then
			
			Comparison = DataCompositionComparisonType.InHierarchy;
			RightValue = Items.FilterHierarchy.CurrentData.Value;
			
		ElsIf Items.FilterHierarchy.CurrentData.Description = NStr("en = '<Show all>'; ru = '<Показать все>';pl = '<Pokaż wszystkie>';es_ES = '<Mostrar todo>';es_CO = '<Mostrar todo>';tr = '<Tümünü göster>';it = '<Mostra tutto>';de = '<Alle anzeigen>'") Then
			
			Usage = False;
			
		ElsIf Items.FilterHierarchy.CurrentData.Description = NStr("en = '<Without group>'; ru = '<Без групп>';pl = '<Bez grupy>';es_ES = '<Sin el grupo>';es_CO = '<Without group>';tr = '<Grup olmadan>';it = '<Senza gruppo>';de = '<Ohne Gruppe>'") Then
			
			RightValue = PredefinedValue("Catalog.Products.EmptyRef");
			
		EndIf;
		
		CommonClientServer.SetDynamicListFilterItem(List, "Parent", RightValue, Comparison, Presentation, Usage);
		
		CurrentFilterHierarchy = RightValue;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillFilterHierarchy(GroupOfCurrentRow = Undefined)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Products.Ref AS Value,
		|	Products.Description AS Description,
		|	Products.DeletionMark AS DeletionMark,
		|	CASE
		|		WHEN Products.DeletionMark
		|			THEN 1
		|		ELSE 0
		|	END AS Picture
		|FROM
		|	Catalog.Products AS Products
		|WHERE
		|	Products.IsFolder
		|
		|ORDER BY
		|	Description HIERARCHY";
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	AllGroups = Tree.Rows.Insert(0);
	AllGroups.Value = Catalogs.Products.EmptyRef();
	AllGroups.Description = NStr("en = '<Show all>'; ru = '<Показать все>';pl = '<Pokaż wszystkie>';es_ES = '<Mostrar todo>';es_CO = '<Mostrar todo>';tr = '<Tümünü göster>';it = '<Mostra tutto>';de = '<Alle anzeigen>'");
	AllGroups.Picture = -1;
	
	NoGroups = Tree.Rows.Add();
	NoGroups.Value = Catalogs.Products.EmptyRef();
	NoGroups.Description = NStr("en = '<Without group>'; ru = '<Без групп>';pl = '<Bez grupy>';es_ES = '<Sin el grupo>';es_CO = '<Sin el grupo>';tr = '<Grup olmadan>';it = '<Senza gruppo>';de = '<Ohne Gruppe>'");
	NoGroups.Picture = -1;
	
	ValueToFormAttribute(Tree, "FilterHierarchy");
	
	RowID = Undefined;
	If GroupOfCurrentRow <> Undefined Then
		RowID = IDInTreeByValue(FilterHierarchy, GroupOfCurrentRow);
	EndIf;
	
	If RowID <> Undefined Then
		Items.FilterHierarchy.CurrentRow = RowID;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillFilterCategories(CategoryOfCurrentRow = Undefined)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductsCategories.Ref AS Value,
		|	ProductsCategories.Description AS Description
		|FROM
		|	Catalog.ProductsCategories AS ProductsCategories
		|
		|ORDER BY
		|	Description HIERARCHY";
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	If Tree.Rows.Count() > 1 Then
		
		NoCategories = Tree.Rows.Insert(0);
		NoCategories.Value = Catalogs.Products.EmptyRef();
		NoCategories.Description = NStr("en = '<Show all>'; ru = '<Показать все>';pl = '<Pokaż wszystkie>';es_ES = '<Mostrar todo>';es_CO = '<Mostrar todo>';tr = '<Tümünü göster>';it = '<Mostra tutto>';de = '<Alle anzeigen>'");
		
	EndIf;
	
	ValueToFormAttribute(Tree, "FilterCategories");
	
	RowID = Undefined;
	If CategoryOfCurrentRow <> Undefined Then
		RowID = IDInTreeByValue(FilterCategories, CategoryOfCurrentRow);
	EndIf;
	
	If RowID <> Undefined Then
		Items.FilterCategories.CurrentRow = RowID;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IDInTreeByValue(Tree, Value)
	
	TreeItems = Tree.GetItems();
	
	For Each Item In TreeItems Do
		
		If Item = Value Then
			Return Item.GetID();
		EndIf;
		
		ID = IDInTreeByValue(Item, Value);
		
		If ID <> Undefined Then
			Return ID;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure SetFilterParametersServer()
	
	UseQuantityInList = FilterBalances <> 0 OR ShowBalances;
	UsePricesInList = ShowPrices;
	
	SetQueryTextList();
	SetListFilterItemBalances(List, FilterBalances);
	If UsePricesInList Then
		SetListFilterItemPrices(PricesFrom, PricesTo);
	Else
		SetListFilterItemPrices(0, 0);
	EndIf;
	SetListQueryParameters();
	SetVisibleEnabled();
	
EndProcedure

&AtServer
Procedure SetListFilterItemBalances(ListForFilter, FilterBalances)
	
	If FilterBalances = 2 Then
		
		FilterComparisonType = DataCompositionComparisonType.LessOrEqual;
		
	Else
		
		FilterComparisonType = DataCompositionComparisonType.Greater;
		
	EndIf;
	
	SetElements = ListForFilter.SettingsComposer.FixedSettings.Filter;
	GroupInStock = CommonClientServer.CreateFilterItemGroup(SetElements.Items, "FilterItemInStock", DataCompositionFilterItemsGroupType.OrGroup);
	
	ArrayProductsType = New Array;
	ArrayProductsType.Add(Enums.ProductsTypes.Service);
	ArrayProductsType.Add(Enums.ProductsTypes.Work);
	
	CommonClientServer.AddCompositionItem(
		GroupInStock,
		"ProductsType",
		DataCompositionComparisonType.InList,
		ArrayProductsType,
		NStr("en = 'Products type'; ru = 'Тип номенклатуры';pl = 'Rodzaje produktów';es_ES = 'Tipo de productos';es_CO = 'Tipo de productos';tr = 'Ürün türü';it = 'Tipo di articolo';de = 'Produkttyp'"),
		FilterBalances = 1);
	
	CommonClientServer.SetFilterItem(
		GroupInStock,
		"QuantityBalance",
		0,
		FilterComparisonType,
		NStr("en = 'Quantity balance'; ru = 'Количество остаток';pl = 'Ilość Saldo';es_ES = 'Saldo de cantidad';es_CO = 'Saldo de cantidad';tr = 'Miktar bakiyesi';it = 'Saldo quantità';de = 'Mengenbilanz'"),
		FilterBalances <> 0);
	
EndProcedure

&AtServer
Procedure SetListFilterItemPrices(PricesFrom, PricesTo)

	SetElements = List.SettingsComposer.Settings.Filter.Items;
	GroupPrices = CommonClientServer.CreateFilterItemGroup(SetElements, "FilterItemPrices", DataCompositionFilterItemsGroupType.AndGroup);
	CommonClientServer.AddCompositionItem(GroupPrices, "Price", DataCompositionComparisonType.GreaterOrEqual, PricesFrom, "PricesFrom", PricesFrom <> 0);
	CommonClientServer.AddCompositionItem(GroupPrices, "Price", DataCompositionComparisonType.LessOrEqual, PricesTo, "PricesTo", PricesTo <> 0);
	
	TemplatePrices = NStr("en = 'Prices %1 %2'; ru = 'Цены %1 %2';pl = 'Ceny %1 %2';es_ES = 'Precios %1 %2';es_CO = 'Precios %1 %2';tr = 'Fiyatlar %1 %2';it = 'Prezzi %1 %2';de = 'Preise %1 %2'");
	PriceFrom = ?(PricesFrom <> 0, NStr("en = 'from'; ru = 'от';pl = 'od';es_ES = 'desde';es_CO = 'desde';tr = 'itibaren';it = 'da';de = 'von'") + " " + PricesFrom, "");
	PriceTo = ?(PricesTo <> 0, NStr("en = 'to'; ru = 'до';pl = 'do';es_ES = 'hasta';es_CO = 'hasta';tr = 'kadar';it = 'a';de = 'An'") + " " + PricesTo, "");
	
	Items.GroupPrices.Title = StringFunctionsClientServer.SubstituteParametersToString(TemplatePrices, PriceFrom, PriceTo);
	
EndProcedure

&AtServer
Procedure SetListQueryParameters()
	
	CommonClientServer.SetDynamicListParameter(List, "PricePeriod", CurrentSessionDate());
	CommonClientServer.SetDynamicListParameter(List, "PriceType", FilterPriceType);
	
	If FilterBalances = 2 Then
		CommonClientServer.SetDynamicListParameter(List, "AllTypes",	False);
	Else
		CommonClientServer.SetDynamicListParameter(List, "AllTypes",	True);
	EndIf;
	
	If ValueIsFilled(FilterWarehouse) Then
		CommonClientServer.SetDynamicListParameter(List, "AllWarehouses",	False);
		CommonClientServer.SetDynamicListParameter(List, "Warehouse",		FilterWarehouse);
	Else
		CommonClientServer.SetDynamicListParameter(List, "AllWarehouses",	True);
		CommonClientServer.SetDynamicListParameter(List, "Warehouse",		PredefinedValue("Catalog.BusinessUnits.EmptyRef"));
	EndIf;
	
	If ValueIsFilled(FilterBalancesCompany) Then
		CommonClientServer.SetDynamicListParameter(List, "AllCompanies",	False);
		CommonClientServer.SetDynamicListParameter(List, "Company",		FilterBalancesCompany);
	Else
		CommonClientServer.SetDynamicListParameter(List, "AllCompanies",	True);
		CommonClientServer.SetDynamicListParameter(List, "Company",		PredefinedValue("Catalog.Companies.EmptyRef"));
	EndIf;
	
	NativeLanguagesSupportServer.ChangeListQueryTextForCurrentLanguage(ThisObject);
	
EndProcedure

&AtServer
Procedure SetVisibleEnabled()
	
	Items.FilterWarehouse.Visible	= (FilterBalances = 1);
	Items.Balance.Visible			= ShowBalances;
	
	Items.FilterPriceType.Enabled	= ShowPrices;
	Items.PricesFromTo.Enabled		= ShowPrices;
	Items.Price.Visible				= ShowPrices;
	
EndProcedure

&AtServer
Function SetQueryTextList()
	
	List.QueryText = 
	"SELECT ALLOWED
	|	CatalogProducts.Ref AS Ref,
	|	CatalogProducts.Ref AS Products,
	|	CatalogProducts.DeletionMark,
	|	CatalogProducts.Parent,
	|	CatalogProducts.IsFolder,
	|	CatalogProducts.Code,
	|	CatalogProducts.Description,
	|	CatalogProducts.SKU,
	|	CatalogProducts.ChangeDate,
	|	CAST(CatalogProducts.DescriptionFull AS STRING(1000)) AS DescriptionFull,
	|	CatalogProducts.BusinessLine,
	|	CatalogProducts.ProductsCategory,
	|	CatalogProducts.Vendor,
	|	CatalogProducts.Manufacturer,
	|	CatalogProducts.Warehouse,
	|	CatalogProducts.ReplenishmentMethod,
	|	CatalogProducts.ReplenishmentDeadline,
	|	CatalogProducts.VATRate,
	|	CatalogProducts.ProductsType,
	|	CatalogProducts.Cell,
	|	CatalogProducts.PriceGroup,
	|	CatalogProducts.UseCharacteristics,
	|	CatalogProducts.UseBatches AS UseReservation,
	|	CatalogProducts.UseBatches AS UseBatches,
	|	CatalogProducts.IsBundle AS IsBundle,
	|	CatalogProducts.OrderCompletionDeadline,
	|	CatalogProducts.TimeNorm,
	|	CatalogProducts.CountryOfOrigin,
	|	CatalogProducts.UseSerialNumbers,
	|	CatalogProducts.GuaranteePeriod,
	|	CatalogProducts.WriteOutTheGuaranteeCard,
	|	Substring(CatalogProducts.Comment, 1, 1000) AS Comment,
	|	&PricePeriod,
	|	&PriceType,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|				OR CatalogProducts.UseBatches
	|			THEN 2
	|		ELSE 0
	|	END + CASE
	|		WHEN CatalogProducts.DeletionMark
	|			THEN 1
	|		ELSE 0
	|	END + CASE
	|		WHEN CatalogProducts.IsBundle
	|			THEN 6
	|		ELSE 0
	|	END AS PictureIndex,
	|	ISNULL(SuppliersProducts.SKU, """") AS SupplierSKU,";
	
	If UsePricesInList And UseQuantityInList Then
		
		List.QueryText = List.QueryText + "
		|	ISNULL(PricesSliceLast.MeasurementUnit, CatalogProducts.MeasurementUnit) AS MeasurementUnit,
		|	ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS Factor,
		|	ISNULL(PricesSliceLast.Price, 0) AS Price,
		|	CASE
		|		WHEN PricesSliceLast.MeasurementUnit REFS Catalog.UOM
		|			THEN ISNULL(InventoryInWarehouses.QuantityBalance, 0) / PricesSliceLast.MeasurementUnit.Factor
		|		ELSE ISNULL(InventoryInWarehouses.QuantityBalance, 0)
		|	END AS QuantityBalance
		|FROM
		|	Catalog.Products AS CatalogProducts
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				,
		|				(&AllCompanies 
		|					OR Company = &Company)
		|				AND (&AllWarehouses
		|					OR StructuralUnit = &Warehouse)) AS InventoryInWarehouses
		|		ON (InventoryInWarehouses.Products = CatalogProducts.Ref)
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&PricePeriod,
		|				PriceKind = &PriceType) AS PricesSliceLast
		|		ON (PricesSliceLast.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef))
		|			AND PricesSliceLast.Products = CatalogProducts.Ref
		|		LEFT JOIN Catalog.SuppliersProducts AS SuppliersProducts
		|		ON CatalogProducts.ProductCrossReference = SuppliersProducts.Ref
		|WHERE
		|	NOT CatalogProducts.IsFolder
		|	AND (&AllTypes 
		|		OR CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))";
		
	ElsIf UsePricesInList Then
		
		List.QueryText = List.QueryText + "
		|	ISNULL(PricesSliceLast.MeasurementUnit, CatalogProducts.MeasurementUnit) AS MeasurementUnit,
		|	ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS Factor,
		|	ISNULL(PricesSliceLast.Price, 0) AS Price,
		|	0 AS QuantityBalance
		|FROM
		|	Catalog.Products AS CatalogProducts
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&PricePeriod,
		|				PriceKind = &PriceType) AS PricesSliceLast
		|		ON (PricesSliceLast.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef))
		|			AND (PricesSliceLast.Products = CatalogProducts.Ref)
		|		LEFT JOIN Catalog.SuppliersProducts AS SuppliersProducts
		|		ON CatalogProducts.ProductCrossReference = SuppliersProducts.Ref
		|WHERE
		|	NOT CatalogProducts.IsFolder
		|	AND (&AllTypes 
		|		OR CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))";
		
	ElsIf UseQuantityInList Then
		
		List.QueryText = List.QueryText + "
		|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
		|	1 AS Factor,
		|	0 AS Price,
		|	ISNULL(InventoryInWarehouses.QuantityBalance, 0) AS QuantityBalance
		|FROM
		|	Catalog.Products AS CatalogProducts
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				,
		|				(&AllCompanies 
		|					OR Company = &Company)
		|				AND (&AllWarehouses
		|					OR StructuralUnit = &Warehouse)) AS InventoryInWarehouses
		|		ON (InventoryInWarehouses.Products = CatalogProducts.Ref)
		|		LEFT JOIN Catalog.SuppliersProducts AS SuppliersProducts
		|		ON CatalogProducts.ProductCrossReference = SuppliersProducts.Ref
		|WHERE
		|	NOT CatalogProducts.IsFolder
		|	AND (&AllTypes 
		|		OR CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))";
		
	Else
		
		List.QueryText = List.QueryText + "
		|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
		|	1 AS Factor,
		|	0 AS Price,
		|	0 AS QuantityBalance
		|FROM
		|	Catalog.Products AS CatalogProducts
		|		LEFT JOIN Catalog.SuppliersProducts AS SuppliersProducts
		|		ON CatalogProducts.ProductCrossReference = SuppliersProducts.Ref
		|WHERE
		|	NOT CatalogProducts.IsFolder
		|	AND (&AllTypes 
		|		OR CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))";
		
	EndIf;
	
EndFunction

// Bundles

&AtClient
Procedure FilterByBundlesWithThisProduct(Products)
	
	ListOfBundles = New ValueList;
	GetBundles(Products, ListOfBundles);
	
	ItemArray = CommonClientServer.FindFilterItemsAndGroups(
		List.SettingsComposer.FixedSettings.Filter,
		"Ref");
	
	If ItemArray.Count() = 0 Then
		CommonClientServer.AddCompositionItem(
			List.SettingsComposer.FixedSettings.Filter,
			"Ref",
			DataCompositionComparisonType.InList,
			ListOfBundles);
	Else
		CommonClientServer.ChangeFilterItems(
			List.SettingsComposer.FixedSettings.Filter,
			"Ref",
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

#EndRegion

#Region LibrariesHandlers

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription",	New Structure("FullMetadataObjectName, Type", "Products", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		Items.List.Refresh();
		ShowMessageBox(,NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
		
	ElsIf ImportResult = Undefined Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

#EndRegion

#EndRegion
