#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("PriceKind") And ValueIsFilled(Parameters.PriceKind) Then
		Items.FilterPriceType.ReadOnly = True;
		FilterPriceType = Parameters.PriceKind;
	Else
		FilterPriceType = Catalogs.PriceTypes.GetMainKindOfSalePrices();
	EndIf;
	
	FillFilterHierarchy();
	FillFilterCategories();
	LabelSelectedProducts = NStr("en = 'Drag-and-drop items to cart'; ru = 'Перетащите товары в корзину';pl = 'Przyciągnij i upuść do koszyka';es_ES = 'Arrastrar y colocar los artículos en el carrito';es_CO = 'Arrastrar y colocar los artículos en el carrito';tr = 'Öğeleri sürükleyip sepete bırakın';it = 'Trascina e lascia elementi nel carrello';de = 'Drag-and-Drop von Elementen in den Warenkorb'");
	
	SetFilterParametersServer();
	
	VariantsList = GetVariantsList();
	If VariantsCount Then
		Items.DecorationCart.Picture = PictureLib.VariantCart;
	EndIf;
	
	// StandardSubsystems.BatchObjectModification
	If Items.Find("ListBatchObjectChanging") <> Undefined Then
		Items.ChangeSelected.Visible = AccessRight("Edit", Metadata.Catalogs.Products);
	EndIf;
	// End StandardSubsystems.BatchObjectModification
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	Items.FormDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(FilterHierarchyCategories) Then
		FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsHierarchy");
	EndIf;
	
	FilterHierarchyCategoriesOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ProductsGroup" And ValueIsFilled(Parameter) Then
		
		NewGroup = Undefined;
		If TypeOf(Parameter) = Type("Array") And Parameter.Count() > 0 Then
			NewGroup = Parameter[0];
		ElsIf ValueIsFilled(Parameter) Then
			NewGroup = Parameter;
		EndIf;
		
		FillFilterHierarchy(NewGroup);
		
	ElsIf EventName = "Write_ProductsCategory" Then
		
		NewCategory = Undefined;
		If TypeOf(Parameter) = Type("Array") And Parameter.Count() > 0 Then
			NewCategory = Parameter[0];
		ElsIf ValueIsFilled(Parameter) Then
			NewCategory = Parameter;
		EndIf;
		
		FillFilterCategories(NewCategory);
		
	ElsIf EventName = "PriceChanged" And ShowPrices Then
		
		Items.List.Refresh();
		
	EndIf;

	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationCartClick(Item)
	
	OpenCart();
	
EndProcedure

&AtClient
Procedure DecorationCartDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationCartDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	AddToCart(DragParameters.Value);
	
EndProcedure

&AtClient
Procedure LabelSelectedProductsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SelectedProductsClick(Undefined);
	
EndProcedure

&AtClient
Procedure FilterBalancesOnChange(Item)
	SetFilterParametersServer();
EndProcedure

&AtClient
Procedure FilterWarehouseOnChange(Item)
	SetFilterParametersServer();
EndProcedure

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
			
			If String(FilterItem.LeftValue) = "Parent" Then
				
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
Procedure FilterHierarchyDragStart(Item, DragParameters, Perform)
	
	If Item.CurrentRow = Undefined Then
		
		Perform = False;
		
	Else
		
		HierarchyRow = FilterHierarchy.FindByID(Item.CurrentRow);
		If HierarchyRow = Undefined
			Or HierarchyRow.Description = NStr("en = '<Show all>'; ru = '<Показать все>';pl = '<Pokaż wszystkie>';es_ES = '<Mostrar todo>';es_CO = '<Mostrar todo>';tr = '<Tümünü göster>';it = '<Mostra tutto>';de = '<Alle anzeigen>'")
			Or HierarchyRow.Description = NStr("en = '<Without group>'; ru = '<Без групп>';pl = '<Bez grupy>';es_ES = '<Sin el grupo>';es_CO = '<Sin el grupo>';tr = '<Grup olmadan>';it = '<Senza gruppo>';de = '<Ohne Gruppe>'") Then
			
			Perform = False;
			
		Else
			
			DragParameters.Value = CommonClientServer.ValueInArray(HierarchyRow.Value);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterHierarchyDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If Row = Undefined Then
		
		DragParameters.Action = DragAction.Cancel;
		
	Else
		
		HierarchyRow = FilterHierarchy.FindByID(Row);
		
		If HierarchyRow = Undefined Or HierarchyRow.Description = NStr("en = '<Show all>'; ru = '<Показать все>';pl = '<Pokaż wszystkie>';es_ES = '<Mostrar todo>';es_CO = '<Mostrar todo>';tr = '<Tümünü göster>';it = '<Mostra tutto>';de = '<Alle anzeigen>'") Then
			
			DragParameters.Action = DragAction.Cancel;
			
		Else
			
			DragParameters.AllowedActions = DragAllowedActions.Move;
			DragParameters.Action = DragAction.Move;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterHierarchyDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array")
		And DragParameters.Value.Count() Then
		
		If Row <> Undefined Then
			
			HierarchyRow = FilterHierarchy.FindByID(Row);
			
			If HierarchyRow <> Undefined And HierarchyRow.Description <> NStr("en = '<Show all>'; ru = '<Показать все>';pl = '<Pokaż wszystkie>';es_ES = '<Mostrar todo>';es_CO = '<Mostrar todo>';tr = '<Tümünü göster>';it = '<Mostra tutto>';de = '<Alle anzeigen>'") Then
				
				ArrayToChange = New Array;
				
				For Each SelectedRow In DragParameters.Value Do
					
					If TypeOf(SelectedRow) = Type("CatalogRef.Products") Then
						
						ArrayToChange.Add(SelectedRow);
						
					EndIf;
					
				EndDo;
				
				MoveToGroup(ArrayToChange, HierarchyRow.Value);
				
			EndIf;
			
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
	
	If NOT Items.FilterSettingsAndAddInfo.Visible
		And FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsHierarchy") Then
		
		RefHiddenGroup = Items.FilterHierarchy.CurrentData.Value;
		
	Else 
		
		RefHiddenGroup = PredefinedValue("Catalog.Products.EmptyRef");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CopyWithRelatedData(Command)
	OpenForm("Catalog.Products.Form.CloneForm", New Structure("Product", Items.List.CurrentData.Ref));
EndProcedure

#EndRegion

#Region FormTableListItemsEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If FilterHierarchyCategories = PredefinedValue("Enum.ProductsFilterTypes.ProductsHierarchy") Then		
		
		If NOT Items.FilterSettingsAndAddInfo.Visible Then
			
			RefFolderProducts = RefHiddenGroup;
			
		Else
			
			RefFolderProducts = Items.FilterHierarchy.CurrentData.Value;
			
		EndIf;
		
		If Folder Then
			
			Cancel = True;
			
			ParentStructure = New Structure("Parent" , RefFolderProducts);
			AdditionalParameters = New Structure("AdditionalParameters, IsFolder", ParentStructure, True);
			
			OpenForm("Catalog.Products.FolderForm", AdditionalParameters);
			
			Return;
			
		Else
			
			ParentStructure = New FixedStructure("Parent" , RefFolderProducts);
			Item.AdditionalCreateParameters = ParentStructure;
			
		EndIf;
			
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddToCartFromList(Command)
	
	AddToCart(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure ChangeCategory(Command)
	
	FormParameters = New Structure;
	
	If Items.FilterCategories.CurrentData <> Undefined Then
		FormParameters.Insert("Key", Items.FilterCategories.CurrentData.Value);
	EndIf;
	
	OpenForm("Catalog.ProductsCategories.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure CreateGroup(Command)
	
	ParentValue = ?(Items.FilterHierarchy.CurrentData = Undefined,
		PredefinedValue("Catalog.Products.EmptyRef"),
		Items.FilterHierarchy.CurrentData.Value);
		
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", New Structure("Parent, IsFolder", ParentValue, True));
	FormParameters.Insert("IsFolder", True);
	
	OpenForm("Catalog.Products.FolderForm", FormParameters);
	
EndProcedure

&AtClient
Procedure MarkForDeletionGroup(Command)
	
	If Items.FilterHierarchy.CurrentData <> Undefined
		And ValueIsFilled(Items.FilterHierarchy.CurrentData.Value) Then
		
		CurrentTreeRow = FilterHierarchy.FindByID(Items.FilterHierarchy.CurrentData.GetID());
		CurrentTreeRow.DeletionMark = MarkForDeletionAtServer(CurrentTreeRow.Value);
		CurrentTreeRow.Picture = ?(CurrentTreeRow.DeletionMark, 1, 0);
		SetFlagInTree(CurrentTreeRow.GetItems(), "DeletionMark", CurrentTreeRow.DeletionMark);
		SetFlagInTree(CurrentTreeRow.GetItems(), "Picture", CurrentTreeRow.Picture);
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeGroup(Command)
		
	FormParameters = New Structure;
	
	If Items.FilterHierarchy.CurrentData <> Undefined Then
		FormParameters.Insert("Key", Items.FilterHierarchy.CurrentData.Value);
	EndIf;
	
	OpenForm("Catalog.Products.FolderForm", FormParameters);
	
EndProcedure

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

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

#EndRegion

#Region Private

#Region WorkWithCart

&AtClient
Procedure SelectedProductsClick(Item)
	
	OpenCart();
	
EndProcedure

&AtClient
Procedure OpenCart()
	
	If Cart.Count() Then
		CartParameters = WriteVariantToTempStorage();
		OpenCartContinue(CartParameters);
	Else
		Restore(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenCartContinue(CartParameters)
	
	CartFormParameters = New Structure;
	CartFormParameters.Insert("CartAddress", ?(ValueIsFilled(CartParameters), CartParameters.CartAddress, Undefined));
	CartFormParameters.Insert("FilterPriceType", FilterPriceType);
	CartFormParameters.Insert("OwnerUUID", UUID);
	
	NotifyCartClosing = New NotifyDescription("CartClosing", ThisObject);
	
	OpenForm("Catalog.Products.Form.CartForm",
		CartFormParameters,
		ThisObject,
		,,,
		NotifyCartClosing,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure CartClosing(Result, AdditionalParameters) Export
	
	Cart.Clear();
	
	If Result = Undefined Then
		// No save
	ElsIf Result = "SaveVariant" Then
		VariantsCount = VariantsCount + 1;
		Items.DecorationCart.Picture = PictureLib.VariantCart;
	ElsIf Result = "MoveToDocument" Then
		// No save
	Else
		// Save
		For Each Row In Result.Cart Do
			NewRow = Cart.Add();
			FillPropertyValues(NewRow, Row);
		EndDo;
	EndIf;
	
	RefreshLabelSelectedProducts();
	
EndProcedure

&AtClient
Procedure RefreshLabelSelectedProducts() Export
	
	If Cart.Count() = 0 Then
		LabelSelectedProducts = NStr("en = 'Drag-and-drop items to cart'; ru = 'Перетащите товары в корзину';pl = 'Przyciągnij i upuść do koszyka';es_ES = 'Arrastrar y colocar los artículos en el carrito';es_CO = 'Arrastrar y colocar los artículos en el carrito';tr = 'Öğeleri sürükleyip sepete bırakın';it = 'Trascina e lascia elementi nel carrello';de = 'Drag-and-Drop von Elementen in den Warenkorb'");
	Else
		ProductsQuantity = Cart.Total("Quantity");
		ProductsAmount = Cart.Total("Amount");
		LabelSelectedProducts = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cart
				|Quantity: %1
				|Total: %2 %3'; 
				|ru = 'Количество
				|в корзине: %1
				|Итого: %2 %3';
				|pl = 'Koszyk
				|Ilość: %1
				|Łącznie: %2 %3';
				|es_ES = 'Carrito
				|Cantidad: %1
				|Total: %2 %3';
				|es_CO = 'Carrito
				|Cantidad: %1
				|Total: %2 %3';
				|tr = 'Sepet
				|Miktar: %1
				|Toplam: %2 %3';
				|it = 'Carrello
				|Quantità: %1
				|Totale: %2 %3';
				|de = 'Warenkorb
				|Menge: %1
				|Insgesamt: %2 %3'"),
			ProductsQuantity,
			Format(ProductsAmount, "NFD=2; NZ=0"),
			?(ValueIsFilled(FilterPriceType),
				PriceTypeCurrency(FilterPriceType),
				""));
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PriceTypeCurrency(PriceType)
	
	Return Common.ObjectAttributeValue(PriceType, "PriceCurrency");
	
EndFunction

&AtClient
Procedure AddToCart(SelectedRows)
	
	If TypeOf(SelectedRows) = Type("Array") Then
		For Each SelectedRow In SelectedRows Do
			AddRowToCart(SelectedRow);
		EndDo;
	ElsIf TypeOf(SelectedRows) = Type("CatalogRef.Products") Then
		AddRowToCart(SelectedRows);
	EndIf;
	
	RefreshLabelSelectedProducts();
	
EndProcedure

&AtClient
Procedure AddRowToCart(SelectedRow)
	
	If TypeOf(SelectedRow) = Type("CatalogRef.Products") Then
		
		RowData = Items.List.RowData(SelectedRow);
		
		ChoiceStructure = New Structure(
			"Products,
			|MeasurementUnit,
			|Quantity,
			|Amount,
			|Price,
			|VATRate,
			|VATAmount,
			|ProductsType,
			|CountryOfOrigin,
			|IsBundle");
			
		FillPropertyValues(ChoiceStructure, RowData);
		
		ChoiceStructure.Quantity = 1;
		
		AddProductToCart(ChoiceStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Restore(Command)
	
	VariantsList = GetVariantsList();
	
	For Each Row In VariantsList Do
		Row.Presentation = StrGetLine(Row.Value, 1);
	EndDo;
	
	If VariantsList.Count() = 0 Then
		OpenCartContinue(Undefined);
	Else
		ShowChooseFromMenu(New NotifyDescription("RestoreEnd", ThisObject), VariantsList);
	EndIf;
	
EndProcedure

&AtClient
Procedure RestoreEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined And Result.Value <> Undefined Then
		CartParameters = RestoreAtServer(Result.Value);
		OpenCartContinue(CartParameters);
	EndIf;
	
EndProcedure

&AtServer
Function RestoreAtServer(SettingsKey)
	
	SettingsString = FormDataSettingsStorage.Load("ProductsCart", SettingsKey);
	Cart.Load(ValueFromStringInternal(SettingsString));
	FormDataSettingsStorage.Delete("ProductsCart", SettingsKey, InfoBaseUsers.CurrentUser().Name);
	VariantsCount = VariantsCount - 1;
	
	Items.DecorationCart.Picture = ?(VariantsCount > 0, PictureLib.VariantCart, PictureLib.EmptyCart);
	
	Return WriteVariantToTempStorage();
	
EndFunction

&AtServer
Function GetVariantsList()
	
	VariantsList = FormDataSettingsStorage.GetList("ProductsCart");
	VariantsCount = VariantsList.Count();
	Return VariantsList;
	
EndFunction

&AtServer
Function WriteVariantToTempStorage()
	
	SelectedProducts = Cart.Unload();
	CartAddressInTempStorage = PutToTempStorage(SelectedProducts, UUID);
	Result = New Structure("CartAddress, UUID", CartAddressInTempStorage, UUID);
	
	Return Result;
	
EndFunction

&AtClient
Procedure AddProductToCart(ChoiceStructure)
	
	SearchStructure = New Structure;
	SearchStructure.Insert("Products", ChoiceStructure.Products);
	CartRows = Cart.FindRows(SearchStructure);
	
	If CartRows.Count() = 0 Then
		CartRow = Cart.Add();
		FillPropertyValues(CartRow, ChoiceStructure);
	Else
		CartRow = CartRows[0];
		CartRow.Quantity = CartRow.Quantity + ChoiceStructure.Quantity;
		CartRow.Price = ChoiceStructure.Price;
	EndIf;
	
	If Not ShowPrices Then
		ChoiceStructure.Insert("PriceKind", FilterPriceType);
		ChoiceStructure.Insert("DocumentCurrency", PriceTypeCurrency(FilterPriceType));
		ChoiceStructure.Insert("Factor", 1);
		ChoiceStructure.Insert("Characteristic", PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef"));
		
		CartRow.Price = GetProductsPriceByPriceKind(ChoiceStructure);
	EndIf;
	
	CartRow.Amount = CartRow.Quantity * CartRow.Price;
	
	DriveClient.CalculateVATAmount(CartRow, True);
	
EndProcedure

&AtServer
Function GetProductsPriceByPriceKind(ChoiceStructure)
	
	ChoiceStructure.Insert("ProcessingDate", 	CurrentSessionDate());
	ChoiceStructure.Insert("Company", 			DriveReUse.GetUserDefaultCompany());
	
	Return DriveServer.GetProductsPriceByPriceKind(ChoiceStructure);
	
EndFunction

#EndRegion

#Region WorkWithFilters

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
			
		ElsIf Items.FilterHierarchy.CurrentData.Description = NStr("en = '<Without group>'; ru = '<Без групп>';pl = '<Bez grupy>';es_ES = '<Sin el grupo>';es_CO = '<Sin el grupo>';tr = '<Grup olmadan>';it = '<Senza gruppo>';de = '<Ohne Gruppe>'") Then
			
			RightValue = PredefinedValue("Catalog.Products.EmptyRef");
			
		EndIf;
		
		CommonClientServer.SetDynamicListFilterItem(List, "Parent", RightValue, Comparison, Presentation, Usage);
		
		CurrentFilterHierarchy = RightValue;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure MoveToGroup(ArrayOfProducts, NewParent)

	For Each ProductRef In ArrayOfProducts Do
		
		If ProductRef.Parent <> NewParent Then
			
			ProductObject = ProductRef.GetObject();
			ProductObject.Parent = NewParent;
			ProductObject.Write();
			
		EndIf;
		
	EndDo;
	
	If ArrayOfProducts[0].IsFolder Then
		
		FillFilterHierarchy();
		
		RowID = 0;
		CommonClientServer.GetTreeRowIDByFieldValue(
			"Value",
			RowID,
			FilterHierarchy.GetItems(),
			ArrayOfProducts[0],
			False);
		Items.FilterHierarchy.CurrentRow = RowID;
		
	Else
		
		Items.List.Refresh();
		
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
	|AUTOORDER";
	
	// MultilingualSupport
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text);
	// End MultilingualSupport
	
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
	|AUTOORDER";
	
	// MultilingualSupport
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text);
	// End MultilingualSupport
	
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
Procedure SetListFilterItemBalances(ListForFilter, FilterBalances)
	
	UseFilter = FilterBalances <> 0;
	
	If FilterBalances = 2 Then
		FilterComparisonType = DataCompositionComparisonType.LessOrEqual; 
	Else
		FilterComparisonType = DataCompositionComparisonType.Greater;
	EndIf;
	
	DriveClientServer.SetListFilterItem(ListForFilter, "QuantityBalance", 0, UseFilter, FilterComparisonType);
		
EndProcedure

&AtServer
Procedure SetListQueryParameters()
	
	CommonClientServer.SetDynamicListParameter(List, "Period", CurrentSessionDate());
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
	
EndProcedure

&AtServer
Procedure SetVisibleEnabled()
	
	Items.FilterWarehouse.Visible	= (FilterBalances = 1);
	Items.Balance.Visible			= ShowBalances And (FilterBalances < 2);
	
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
	|	&Period,
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
		|				&AllWarehouses
		|					OR StructuralUnit = &Warehouse) AS InventoryInWarehouses
		|		ON (InventoryInWarehouses.Products = CatalogProducts.Ref)
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&Period,
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
		|				&Period,
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
		|				&AllWarehouses
		|					OR StructuralUnit = &Warehouse) AS InventoryInWarehouses
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

&AtServerNoContext
Function MarkForDeletionAtServer(Product)
	
	ProductObject = Product.GetObject();
	ProductObject.SetDeletionMark(Not ProductObject.DeletionMark, True);
	
	Return ProductObject.DeletionMark
	
EndFunction

&AtClient
Procedure SetFlagInTree(ListOfItems, FlagName, FlagValue)
	
	For Each ListItem In ListOfItems Do
		
		ListItem[FlagName] = FlagValue;
		
		ListItemChilds = ListItem.GetItems();
		If ListItemChilds.Count() > 0 Then
			SetFlagInTree(ListItemChilds, FlagName, FlagValue);
		EndIf;
		
	EndDo;
	
EndProcedure

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

#Region WorkWithList

&AtClient
Procedure ListOnActivateRow(Item)
	
	ContextMenu = Items.List.ContextMenu;
	ListContextMenuCopyWithRelatedData = ContextMenu.ChildItems.ListContextMenuCopyWithRelatedData;
	
	If Item.SelectedRows.Count() > 1 Then
		ListContextMenuCopyWithRelatedData.Enabled = False;
	Else
		ListContextMenuCopyWithRelatedData.Enabled = True;
	EndIf;
	
EndProcedure

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
		ShowMessageBox(,NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'Importazione dati completata.';de = 'Der Datenimport ist abgeschlossen.'"));
		
	ElsIf ImportResult = Undefined Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion

#EndRegion
