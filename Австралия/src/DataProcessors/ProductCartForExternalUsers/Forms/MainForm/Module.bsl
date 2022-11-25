#Region Variables

&AtClient
Var FormIsClosing;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	FillPropertyValues(ThisObject, ExternalUsers.ExternalUserAuthorizationData());
	DoOperationsByContracts = Common.ObjectAttributeValue(AuthorizedCounterparty, "DoOperationsByContracts");
	
	FillObjectData();
	
	If Parameters.Property("BasisRefsArray") Then
		If Parameters.Property("Quotation") And Not ValueIsFilled(Quotation) Then
			Quotation = Parameters.Quotation;
		EndIf;
		
		If DoOperationsByContracts And Not ValueIsFilled(Object.Contract) Then
			FillAttributeByBasis("Contract", Parameters.BasisRefsArray[0]);
			ContractOnChangeServer();
		ElsIf Not DoOperationsByContracts And Not ValueIsFilled(Object.Company) Then
			FillAttributeByBasis("Company", Parameters.BasisRefsArray[0]);
			CompanyOnChangeServer();
		EndIf;
	EndIf;
	
	SetDynamicListParameters();
	
	EnableFulltextSearchOnOpenSelection();
	
	// fix the Warehouse balance list flicker
	CommonClientServer.AddCompositionItem(ListWarehouseBalances.Filter, "Products", DataCompositionComparisonType.Equal, Catalogs.Products.EmptyRef());
	CommonClientServer.SetDynamicListParameter(ListWarehouseBalances, "Factor", 1);
	
	CommonClientServer.SetDynamicListParameter(ListInventory, "UseProductAccessGroupsTurnOff", Not GetFunctionalOption("UseProductAccessGroupsForExternalUsers"));
	
	SelectionSettingsCache = New Structure;
	
	SelectionSettingsCache.Insert("CurrentUser", Users.CurrentUser());
	SelectionSettingsCache.Insert("RequestQuantity", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "RequestQuantity", True));
	SelectionSettingsCache.Insert("RequestPrice", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "RequestPrice", True));
	SelectionSettingsCache.Insert("ShowCart", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "ShowCart", True));
	
	StockStatusFilter = DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "StockStatusFilter", Enums.StockStatusFilters.All);
	If StockStatusFilter = Enums.StockStatusFilters.Available Then
		CommonClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
		CommonClientServer.AddCompositionItem(ListCharacteristics.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
		CommonClientServer.AddCompositionItem(ListBatches.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
	EndIf;
	
	SelectionSettingsCache.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionSettingsCache.Insert("DiscountCardVisible", ValueIsFilled(Object.DiscountCard));
	
	SelectionSettingsCache.Insert("InaccessibleDataColor", StyleColors.InaccessibleDataColor);
	SelectionSettingsCache.Insert("AllowedToChangeAmount", False);
	SelectionSettingsCache.Insert("ShowBatch", True);
	SelectionSettingsCache.Insert("ShowAvailable", True);
	SelectionSettingsCache.Insert("ShowPrice", True);
	
	// Bundles
	ShowBundles = False;
	SelectionSettingsCache.Insert("ShowBundles", ShowBundles);
	
	If Not ShowBundles Then
		CommonClientServer.AddCompositionItem(
			ListInventory.SettingsComposer.FixedSettings.Filter,
			"IsBundle",
			DataCompositionComparisonType.Equal,
			False);
	EndIf;
	// End Bundles
	
	SelectionSettingsCache.Insert("AvailableWarehouses", AvailableWarehouses());
	SelectionSettingsCache.Insert("OneWarehouse", SelectionSettingsCache.AvailableWarehouses.Count() = 1);
	
	FillInContractSettingsCache();
	
	SetFormItemsProperties();
	SetConditionalAppearance();
	
	If Parameters.Property("BasisRefsArray") Then
		For Each Doc In Parameters.BasisRefsArray Do
			FillShoppingCartByBasis(Doc);
		EndDo;
	EndIf;
	
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
	
	If Exit And Object.ShoppingCart.Count() Then
		MessageText = NStr("en = 'The cart contains products. If you log out, they will be cleared.'; ru = 'В корзине содержится номенклатура. При завершении работы номенклатура будет удалена.';pl = 'Koszyk zawiera produkty. Jeśli wylogujesz, zostaną one wyczyszczone.';es_ES = 'La cesta contiene productos. Si cierra la sesión, se eliminarán.';es_CO = 'La cesta contiene productos. Si cierra la sesión, se eliminarán.';tr = 'Sepette ürünler var. Çıkış yaparsanız ürünler silinecek.';it = 'Il carrello contiene prodotti. Se si effettua il logout, questi verranno cancellati.';de = 'Es gibt Waren im Warenkorb. Beim Ausloggen werden sie gelöscht.'");
		Cancel = True;
	ElsIf Not FormIsClosing And Object.ShoppingCart.Count() Then
		Cancel = True;
		ShowQueryBox(New NotifyDescription("BeforeClosingQueryBoxHandler", ThisObject, New Structure("Exit", Exit)),
			NStr("en = 'The cart contains products. If you close it, they will be cleared. Close the cart?'; ru = 'В корзине содержится номенклатура. При закрытии корзины номенклатура будет удалена. Закрыть корзину?';pl = 'Koszyk zawiera produkty. Jeśli zamkniesz go, zostaną one wyczyszczone. Zamknąć koszyk?';es_ES = 'La cesta contiene productos. Si la cierra, se eliminarán. ¿Cerrar la cesta?';es_CO = 'La cesta contiene productos. Si la cierra, se eliminarán. ¿Cerrar la cesta?';tr = 'Sepette ürünler var. Sepeti kapatırsanız ürünler silinecek. Kapatılsın mı?';it = 'Il carrello contiene prodotti. Se si chiude il carrello, questi verranno cancellati. Chiudere il carrello?';de = 'Es gibt Waren im Warenkorb.  Wenn Sie den schließen, werden diese gelöscht. Den Warenkorb schließen?'"),
			QuestionDialogMode.YesNoCancel);
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
	UserSettingsSaving(UserSettingsToBeSaved);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If (EventName = "Document.SalesOrder.CopyTS"
		Or EventName = "Document.Quote.CopyTS")
		And TypeOf(Parameter) = Type("Array") Then
		
		If EventName = "Document.Quote.CopyTS" And Parameter.Count()
			And Not ValueIsFilled(Quotation) Then
			
			Quotation = Parameter[0];
			
		EndIf;
		
		If DoOperationsByContracts And Not ValueIsFilled(Object.Contract) Then
			FillAttributeByBasis("Contract", Parameter[0]);
			ContractOnChange(Undefined);
		ElsIf Not DoOperationsByContracts And Not ValueIsFilled(Object.Company) Then
			FillAttributeByBasis("Company", Parameter[0]);
			CompanyOnChange(Undefined);
		EndIf;
		
		If Object.ShoppingCart.Count() = 0 Then
			For Each Doc In Parameter Do
				FillShoppingCartByBasis(Doc);
			EndDo;
		Else
			ShowQueryBox(New NotifyDescription("FillByBasisQueryBoxHandler", ThisObject, Parameter),
				NStr("en = 'The cart contains products. Do you want to add more products from the document?'; ru = 'В корзине содержится номенклатура. Добавить номенклатуру из документа?';pl = 'Koszyk zawiera produkty. Czy chcesz dodać więcej produktów z dokumentu?';es_ES = 'La cesta contiene productos. ¿Desea añadir más productos desde el documento?';es_CO = 'La cesta contiene productos. ¿Desea añadir más productos desde el documento?';tr = 'Sepette ürünler var. Belgeden daha fazla ürün eklemek istiyor musunuz?';it = 'Il carrello contiene prodotti. Desideri aggiungere altri prodotti dal documento?';de = 'Es gibt Waren im Warenkorb. Möchten Sie noch weitere Produkte aus dem Dokument hinzufügen?'"),
				QuestionDialogMode.YesNoCancel);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByBasisQueryBoxHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		If DoOperationsByContracts And Not ValueIsFilled(Object.Contract) Then
			FillAttributeByBasis("Contract", AdditionalParameters[0]);
			ContractOnChange(Undefined);
		ElsIf Not DoOperationsByContracts And Not ValueIsFilled(Object.Company) Then
			FillAttributeByBasis("Company", AdditionalParameters[0]);
			CompanyOnChange(Undefined);
		EndIf;
		
		For Each Doc In AdditionalParameters Do
			FillShoppingCartByBasis(Doc);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StockStatusFilterOnChange(Item)
	
	FilterData = New Structure;
	FilterData.Insert("Available", StockStatusFilter = PredefinedValue("Enum.StockStatusFilters.Available"));
	
	ListFiltersChangeHandler(FilterData, DataCompositionComparisonType.Greater);
	
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
Procedure ContractOnChange(Item)
	
	ContractOnChangeServer();
	SetDynamicListParameters();
	FillInContractSettingsCache();
	SetFormItemsProperties();
	
	If Object.ShoppingCart.Count() > 0 Then
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "ShoppingCart", True);
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	CompanyOnChangeServer();
	SetDynamicListParameters();
	
	If Object.ShoppingCart.Count() > 0 Then
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "ShoppingCart", True);
	EndIf;
	
EndProcedure

&AtClient
Procedure DiscountCardOnChange(Item)
	
	Object.DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	SelectionSettingsCache.Insert("DiscountCardVisible", ValueIsFilled(Object.DiscountCard));
	SelectionSettingsCache.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	
	DiscountMarkupPercentVisible = SelectionSettingsCache.DiscountsMarkupsVisible Or SelectionSettingsCache.DiscountCardVisible;
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartDiscountMarkupPercent", "Visible", DiscountMarkupPercentVisible);
	
	If Object.ShoppingCart.Count() > 0 Then
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "ShoppingCart", True);
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
		
	EndIf;
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
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

#Region FormTableEventHandlersOfListProductsHierarchyTable

&AtClient
Procedure ListProductsHierarchyOnActivateRow(Item)
	
	AttachIdleHandler("SetListInventoryParentFilter", 0.2, True);
	
EndProcedure

&AtClient
Procedure ListProductsHierarchyDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	DragParameters.Action = DragAction.Cancel;
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListWarehouseBalancesTable

&AtClient
Procedure ListWarehouseBalancesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart(Item.CurrentData.StructuralUnit);
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfShoppingCartTable

&AtClient
Procedure ShoppingCartOnChange(Item)
	
	SetCartInfoLabelText();
	
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
		
		StructureData = CreateGeneralAttributeValuesStructure(CartRow);
		
		CalculateAmountInTabularSectionLine(StructureData);
		
		FillPropertyValues(CartRow, StructureData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShoppingCartQuantityOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(StringCart);
	
	CalculateAmountInTabularSectionLine(StructureData);
	
	FillPropertyValues(StringCart, StructureData);
	
EndProcedure

&AtClient
Procedure ShoppingCartMeasurementUnitOnChange(Item)
	
	CartRow = Items.ShoppingCart.CurrentData;
	
	If TypeOf(CartRow.MeasurementUnit) = Type("CatalogRef.UOM")
		And ValueIsFilled(CartRow.MeasurementUnit) Then
		
		NewFactor = GetUOMFactor(CartRow.MeasurementUnit);
		
	Else
		
		NewFactor = 1;
		
	EndIf;
	
	If CartRow.Factor <> 0 AND CartRow.Price <> 0 Then
		
		CartRow.Price = CartRow.Price * NewFactor / CartRow.Factor;
		
	EndIf;
	
	CartRow.Factor = NewFactor;
	
	StructureData = CreateGeneralAttributeValuesStructure(CartRow);
	
	CalculateAmountInTabularSectionLine(StructureData);
	
	FillPropertyValues(CartRow, StructureData);
	
EndProcedure

&AtClient
Procedure ShoppingCartPriceOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(StringCart);
	
	CalculateAmountInTabularSectionLine(StructureData);
	
	FillPropertyValues(StringCart, StructureData);
	
EndProcedure

&AtClient
Procedure ShoppingCartDiscountMarkupPercentOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(StringCart);
	
	CalculateAmountInTabularSectionLine(StructureData);
	
	FillPropertyValues(StringCart, StructureData);
	
EndProcedure

&AtClient
Procedure ShoppingCartAmountOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	If StringCart.DiscountMarkupPercent = 100 Then
		
		StringCart.Amount = 0;
		
	ElsIf StringCart.Quantity <> 0 Then
		
		StringCart.Price = StringCart.Amount / (1 - StringCart.DiscountMarkupPercent / 100) / StringCart.Quantity;
		
	EndIf;
	
	StructureData = CreateGeneralAttributeValuesStructure(StringCart);
	CalculateVATSUM(StructureData);
	FillPropertyValues(StringCart, StructureData);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure ShoppingCartVATRateOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(StringCart);
	CalculateVATSUM(StructureData);
	FillPropertyValues(StringCart, StructureData);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure ShoppingCartVATAmountOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure ShoppingCartSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ShoppingCartProducts" Then
		StandardProcessing = False;
		
		Product = Item.CurrentData.Products;
		GeneratePrintFormProducts(Product);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShoppingCartBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure ShoppingCartDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

&AtClient
Procedure ShoppingCartDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

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
Procedure AddToCart(Command)
	
	AddProductsToCart();
	
EndProcedure

&AtClient
Procedure GoToParent(Command)
	
	CurrentListCurrentData = GetCurrentListCurrentData();
	
	If CurrentListCurrentData <> Undefined Then
		
		Items.ListProductsHierarchy.CurrentRow = CurrentListCurrentData.Parent;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches
		And CurrentProductUseCharacteristics Then
		
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

&AtClient
Procedure CreateSalesOrder(Command)
	
	If DoOperationsByContracts And Not ValueIsFilled(Object.Contract) Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot create a Sales order. Contract is required.'; ru = 'Не удалось создать заказ покупателя. Поле ""Договор"" не заполнено.';pl = 'Nie można utworzyć Zamówienia sprzedaży. Wymagany jest Kontrakt.';es_ES = 'No se ha podido crear una orden de ventas. Se requiere un contrato.';es_CO = 'No se ha podido crear una orden de ventas. Se requiere un contrato.';tr = 'Satış siparişi oluşturulamıyor. Sözleşme gerekli.';it = 'Impossibile creare un ordine cliente. È necessario un contratto.';de = 'Fehler beim Erstellen eines Kundenauftrags. Vertrag ist ein Pflichtfeld.'"));

		Return;
	EndIf;
	
	If Not DoOperationsByContracts And Not ValueIsFilled(Object.Company) Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot create a Sales order. Company is required.'; ru = 'Не удалось создать заказ покупателя. Поле ""Организация"" не заполнено.';pl = 'Nie można utworzyć Zamówienia sprzedaży. Firma jest wymagana.';es_ES = 'No se ha podido crear una orden de ventas. Se requiere una empresa.';es_CO = 'No se ha podido crear una orden de ventas. Se requiere una empresa.';tr = 'Satış siparişi oluşturulamıyor. İş yeri gerekli.';it = 'Impossibile creare un ordine cliente. È necessaria un''azienda.';de = 'Fehler beim Erstellen eines Kundenauftrags. Fima ist ein Pflichtfeld.'"));

		Return;
	EndIf;
	
	If Object.ShoppingCart.Count() = 0 Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot create a Sales order. First, add products to the cart. Then try again.'; ru = 'Не удалось создать заказ покупателя. Добавьте номенклатуру в корзину и повторите попытку.';pl = 'Nie można utworzyć Zamówienia sprzedaży. Najpierw dodaj produkty do koszyka. Następnie spróbuj ponownie.';es_ES = 'No se ha podido crear una orden de ventas. Primero, añada productos a la cesta. Inténtelo de nuevo.';es_CO = 'No se ha podido crear una orden de ventas. Primero, añada productos a la cesta. Inténtelo de nuevo.';tr = 'Satış siparişi oluşturulamıyor. Sepete ürün ekleyip tekrar deneyin.';it = 'Impossibile creare un ordine cliente. Aggiungi prima i prodotti al carrello e riprova.';de = 'Fehler beim Erstellen eines Kundenauftrags. Fügen Sie die Produkte zum Warenkorb hinzu. Dann versuchen Sie erneut.'"));
			
		Return;
	EndIf;
	
	Cancel = False;
	
	CheckWarehousesFillIn(Cancel);
	CheckPricesFillIn(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterSelectionDeliveryInformation", ThisObject);
	OpenForm("DataProcessor.ProductCartForExternalUsers.Form.DeliveryInformation", New Structure("Counterparty", Object.Counterparty),
		ThisObject, True, , , NotificationDescriptionOnCloseSelection, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AfterSelectionDeliveryInformation(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		CreateDocumentSalesOrder(ClosingResult);
		
		OpenForm("Document.SalesOrder.Form.ListFormForExternalUsers");
		Notify("SalesOrderCreatedByExternalUser", );
		
		FormIsClosing = True;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Fill(Command)
	
	If Object.ShoppingCart.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("FillQueryBoxHandler", ThisObject),
			NStr("en = 'The cart contains products. Do you want to add more products from the document?'; ru = 'В корзине содержится номенклатура. Добавить номенклатуру из документа?';pl = 'Koszyk zawiera produkty. Czy chcesz dodać więcej produktów z dokumentu?';es_ES = 'La cesta contiene productos. ¿Desea añadir más productos desde el documento?';es_CO = 'La cesta contiene productos. ¿Desea añadir más productos desde el documento?';tr = 'Sepette ürünler var. Belgeden daha fazla ürün eklemek istiyor musunuz?';it = 'Il carrello contiene prodotti. Desideri aggiungere altri prodotti dal documento?';de = 'Es gibt Waren im Warenkorb. Möchten Sie noch weitere Produkte aus dem Dokument hinzufügen?'"),
			QuestionDialogMode.YesNoCancel);
	Else
		FillBasis();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillBasis()
	
	DocumentTypes = New ValueList;
	DocumentTypes.Add("Quote", 		BasisDocumentSynonym("Quote"));
	DocumentTypes.Add("SalesOrder", BasisDocumentSynonym("SalesOrder"));
	
	Descr = New NotifyDescription("BasisDocumentSelectEnd", ThisObject);
	DocumentTypes.ShowChooseItem(Descr, NStr("en = 'Select document type'; ru = 'Выберите тип документа';pl = 'Wybierz rodzaj dokumentu';es_ES = 'Seleccionar el tipo de documento';es_CO = 'Seleccionar el tipo de documento';tr = 'Belge türü seç';it = 'Seleziona il tipo di documento';de = 'Dokumententyp auswählen'"));
	
EndProcedure

&AtClient
Procedure FillQueryBoxHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillBasis();
	EndIf;
	
EndProcedure

&AtClient
Procedure BasisDocumentSelectEnd(SelectedElement, AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("Counterparty",	Object.Counterparty);
	If ValueIsFilled(Object.Contract) Then
		Filter.Insert("Company",	Object.Company);
		Filter.Insert("Contract", 	Object.Contract);
	ElsIf ValueIsFilled(Object.Company) Then
		Filter.Insert("Company",	Object.Company);
	EndIf;
	
	ParametersStructure = New Structure("Filter", Filter);
	
	FillByBasisEnd = New NotifyDescription("FillByBasisEnd", ThisObject, AdditionalParameters);
	OpenForm("Document." + SelectedElement.Value + ".Form.ChoiceFormForExternalUsers", ParametersStructure, ThisObject,,,,FillByBasisEnd);

EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		If DoOperationsByContracts And Not ValueIsFilled(Object.Contract) Then
			FillAttributeByBasis("Contract", Result);
			ContractOnChange(Undefined);
		ElsIf Not DoOperationsByContracts And Not ValueIsFilled(Object.Company) Then
			FillAttributeByBasis("Company", Result);
			CompanyOnChange(Undefined);
		EndIf;
		
		FillShoppingCartByBasis(Result);
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintProduct(Command)
	
	CurData = GetCurrentListCurrentData();
	If CurData <> Undefined Then
		GeneratePrintFormProducts(CurData.ProductsRef);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region FormInitialization

&AtServer
Procedure FillObjectData()
	
	FillCounterpartyData();
	
	Object.Date = CurrentSessionDate();
	Object.PricePeriod = Object.Date;
	
	Object.ProductsType.Add(Enums.ProductsTypes.InventoryItem);
	Object.ProductsType.Add(Enums.ProductsTypes.Service);
	
	If ValueIsFilled(Object.Counterparty) Then
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	DiscountCards.Ref AS Ref
		|FROM
		|	Catalog.DiscountCards AS DiscountCards
		|WHERE
		|	NOT DiscountCards.DeletionMark
		|	AND DiscountCards.CardOwner = &Counterparty";
		
		Query.SetParameter("Counterparty", Object.Counterparty);
		
		Selection = Query.Execute().Select();
		If Selection.Count() = 1 Then
			Selection.Next();
			Object.DiscountCard = Selection.Ref;
			Object.DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
			
			Items.DiscountCard.ChoiceList.Add(Object.DiscountCard);
		ElsIf Selection.Count() > 1 Then
			While Selection.Next() Do
				Items.DiscountCard.ChoiceList.Add(Selection.Ref);
			EndDo;
		EndIf;
		
	EndIf;

EndProcedure

&AtServer
Procedure FillCounterpartyData()
	
	Object.Counterparty = AuthorizedCounterparty;
	
	If DoOperationsByContracts Then
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	CounterpartyContracts.Ref AS Ref
		|FROM
		|	Catalog.CounterpartyContracts AS CounterpartyContracts
		|WHERE
		|	NOT CounterpartyContracts.DeletionMark
		|	AND CounterpartyContracts.Owner = &Owner
		|	AND (CounterpartyContracts.VisibleToExternalUsers
		|			OR &UseContractRestrictionsTurnOff)";
		
		Query.SetParameter("UseContractRestrictionsTurnOff",
			Not GetFunctionalOption("UseContractRestrictionsForExternalUsers"));
		Query.SetParameter("Owner", AuthorizedCounterparty);
		
		Selection = Query.Execute().Select();
		If Selection.Count() = 1 Then
			Selection.Next();
			Object.Contract = Selection.Ref;
			
			ContractOnChangeServer();
		Else
			ShowContract = True;
		EndIf;
		
	Else
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	Companies.Ref AS Ref
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	NOT Companies.DeletionMark";
		
		Selection = Query.Execute().Select();
		If Selection.Count() = 1 Then
			Selection.Next();
			Object.Company = Selection.Ref;
			
			CompanyOnChangeServer();
		Else
			ShowCompany = True;
		EndIf;
		
		CounterpartyOnChangeServer();
		
	EndIf;
	
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
	
	DiscountMarkupPercentVisible = SelectionSettingsCache.DiscountsMarkupsVisible Or SelectionSettingsCache.DiscountCardVisible;
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartDiscountMarkupPercent", "Visible", DiscountMarkupPercentVisible);
	CommonClientServer.SetFormItemProperty(Items, "DiscountCard", "Visible", Items.DiscountCard.ChoiceList.Count() > 0);
	
	AllowedToChangeAmount = SelectionSettingsCache.AllowedToChangeAmount;
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartPrice", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartAmount", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartVATAmount", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartTotal", "Enabled", AllowedToChangeAmount);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartGroupPrice", "Enabled", AllowedToChangeAmount);
	
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartBatch", "Visible", SelectionSettingsCache.ShowBatch);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartGroupPrice", "Visible", SelectionSettingsCache.ShowPrice);
	
	PriceVisible = (SelectionSettingsCache.ShowPrice And Not SelectionSettingsCache.PriceWithFormula);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryPrice", "Visible", PriceVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsPrice", "Visible", PriceVisible);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesPrice", "Visible", PriceVisible);
	
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListCharacteristicsGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonClientServer.SetFormItemProperty(Items, "ListBatchesGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	
	ListWarehouseBalancesVisible = (SelectionSettingsCache.ShowAvailable And Not SelectionSettingsCache.OneWarehouse);
	CommonClientServer.SetFormItemProperty(Items, "ListWarehouseBalances", "Visible", ListWarehouseBalancesVisible);
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartStructuralUnit", "Visible", ListWarehouseBalancesVisible);
	
	// Bundles
	CommonClientServer.SetFormItemProperty(Items, "ListShowBundlesWithThisProduct", "Visible", SelectionSettingsCache.ShowBundles);
	CommonClientServer.SetFormItemProperty(Items, "ListInventoryContextMenuShowBundlesWithThisProduct", "Visible", SelectionSettingsCache.ShowBundles);
	// End Bundles
	
	CommonClientServer.SetFormItemProperty(Items, "Contract", "Visible", ShowContract);
	CommonClientServer.SetFormItemProperty(Items, "DiscountMarkupKind", "Visible", ValueIsFilled(Object.DiscountMarkupKind));
	CommonClientServer.SetFormItemProperty(Items, "ShoppingCartProducts", "ReadOnly", True);
	
	CommonClientServer.SetFormItemProperty(Items, "BusinessProcessJobCreateBasedOn", "Visible", GetFunctionalOption("UseSupportForExternalUsers"));
	CommonClientServer.SetFormItemProperty(Items, "Company", "Visible", ShowCompany);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	// ListBatches
	ItemAppearance = ListBatches.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("DataParameters.ReferentialBatches");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", WebColors.Gray);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Available");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion

#Region FormCompletion

&AtClient
Procedure BeforeClosingQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
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
	
	FulltextSearchSetPartially = (UseFullTextSearch And Not RelevancyFullTextSearchIndex);
	
	InputHint = ?(FulltextSearchSetPartially,
		NStr("en = 'Update the full-text search index...'; ru = 'Необходимо обновить индекс полнотекстового поиска...';pl = 'Aktualizacja indeksu wyszukiwania pełnotekstowego...';es_ES = 'Actualizar el índice de la búsqueda de texto completo...';es_CO = 'Actualizar el índice de la búsqueda de texto completo...';tr = 'Tam metin arama dizinini güncelle...';it = 'L''indice della ricerca full-text deve essere aggiornato ...';de = 'Volltextsuchindex aktualisieren...'"),
		NStr("en = '(ALT+1) Enter search text ...'; ru = '(ALT+1) Введите текст поиска...';pl = '(ALT+1) Wprowadź wyszukiwany tekst...';es_ES = '(ALT+1) Introducir el texto de la búsqueda ...';es_CO = '(ALT+1) Introducir el texto de la búsqueda ...';tr = '(ALT+1) Arama metnini gir ...';it = '(ALT+1) Inserire testo di ricerca...';de = '(ALT + 1) Suchtext eingeben...'"));
		
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
Procedure AddProductsToCart(StructuralUnit = Undefined)
	
	CurrentListCurrentDataArray = GetCurrentListCurrentDataArray();
	
	If CurrentListCurrentDataArray = Undefined Then
		Return;
	EndIf;
	
	IsOneRow = CurrentListCurrentDataArray.Count() = 1;
	
	For Each CurrentListCurrentData In CurrentListCurrentDataArray Do
		
		CartRowData = New Structure;
		CartRowData.Insert("Products", CurrentListCurrentData.ProductsRef);
		CartRowData.Insert("Characteristic", CurrentListCurrentData.CharacteristicRef);
		CartRowData.Insert("Batch", CurrentListCurrentData.BatchRef);
		CartRowData.Insert("MeasurementUnit", CurrentListCurrentData.MeasurementUnit);
		CartRowData.Insert("Factor", CurrentListCurrentData.Factor);
		CartRowData.Insert("VATRate", GetVATRate(CurrentListCurrentData.VATRate));
		CartRowData.Insert("AvailableBasicUOM", CurrentListCurrentData.AvailableBasicUOM);
		If SelectionSettingsCache.OneWarehouse Then
			CartRowData.Insert("StructuralUnit", SelectionSettingsCache.AvailableWarehouses[0]);
		ElsIf StructuralUnit <> Undefined Then
			CartRowData.Insert("StructuralUnit", StructuralUnit);
		ElsIf Items.ListWarehouseBalances.CurrentRow <> Undefined Then
			ListWarehouseSelectedRows = Items.ListWarehouseBalances.SelectedRows;
			If ListWarehouseSelectedRows.Count() Then
				CartRowData.Insert("StructuralUnit", ListWarehouseSelectedRows[0].StructuralUnit);
			EndIf;
		EndIf;
		
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
		
		If (SelectionSettingsCache.RequestQuantity Or SelectionSettingsCache.RequestPrice) And IsOneRow Then
			
			CartRowData.Insert("SelectionSettingsCache", SelectionSettingsCache);
			
			NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterSelectionQuantityAndPrice", ThisObject, CartRowData);
			OpenForm("DataProcessor.ProductCartForExternalUsers.Form.QuantityAndPrice",
				CartRowData, ThisObject, True, , ,NotificationDescriptionOnCloseSelection , FormWindowOpeningMode.LockOwnerWindow);
			
		Else
			
			If CartRowData.Property("StructuralUnit") Then
				AddProductsToCartCompletion(CartRowData);
			Else
				StructuralUnitsMap = FillCartRowStructuralUnit(CartRowData);
				For Each StructuralUnitElem In StructuralUnitsMap Do
					CartRowData.Insert("StructuralUnit", StructuralUnitElem.Key);
					CartRowData.Quantity = StructuralUnitElem.Value;
					AddProductsToCartCompletion(CartRowData);
				EndDo;
			EndIf;
			
			If Not SelectionSettingsCache.ShowCart Then
				ShowUserNotification(
					Nstr("en = 'Item added to cart'; ru = 'Товар добавлен в корзину';pl = 'Pozycja została dodana do koszyka';es_ES = 'Artículo añadido a la cesta';es_CO = 'Artículo añadido a la cesta';tr = 'Öğe sepete eklendi';it = 'Articolo aggiunto al carrello';de = 'Artikel in den Warenkorb gelegt'"),
					,
					StringFunctionsClientServer.SubstituteParametersToString(
						"%1 %2 %3",
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
		
		If CartRowData.Property("StructuralUnit") Then
			AddProductsToCartCompletion(CartRowData);
		Else
			StructuralUnitsMap = FillCartRowStructuralUnit(CartRowData);
			For Each StructuralUnit In StructuralUnitsMap Do
				CartRowData.Insert("StructuralUnit", StructuralUnit.Key);
				CartRowData.Quantity = StructuralUnit.Value;
				AddProductsToCartCompletion(CartRowData);
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AddProductsToCartCompletion(CartRowData)
	
	Characteristic = ?(CartRowData.Characteristic = Undefined,
		Catalogs.ProductsCharacteristics.EmptyRef(),
		CartRowData.Characteristic);
	Batch = ?(CartRowData.Batch = Undefined, Catalogs.ProductsBatches.EmptyRef(), CartRowData.Batch);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Products", CartRowData.Products);
	FilterStructure.Insert("Characteristic", Characteristic);
	FilterStructure.Insert("Batch", Batch);
	FilterStructure.Insert("MeasurementUnit", CartRowData.MeasurementUnit);
	FilterStructure.Insert("Price", CartRowData.Price);
	FilterStructure.Insert("StructuralUnit", CartRowData.StructuralUnit);
	
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
Procedure GetDataCharacteristicOnChange(DataStructure)
	
	If ValueIsFilled(DataStructure.PriceKind) Then
		DataStructure.Insert("Price", DriveServer.GetProductsPriceByPriceKind(DataStructure));
	Else
		DataStructure.Insert("Price", 0);
	EndIf;
	
EndProcedure

&AtServer
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

&AtServer
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

&AtServer
Function FillCartRowStructuralUnit(CartRowData)
	
	ResultMap = New Map;
	
	Query = New Query;
	Query.Text = "SELECT
	|	ProductCart.StructuralUnit AS StructuralUnit,
	|	ProductCart.Products AS Products,
	|	ProductCart.Characteristic AS Characteristic,
	|	ProductCart.Batch AS Batch,
	|	ProductCart.Quantity AS Quantity
	|INTO TT_ProductCart
	|FROM
	|	&ProductCart AS ProductCart
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InventoryInWarehousesOfBalance.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehousesOfBalance.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristic
	|			THEN InventoryInWarehousesOfBalance.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatch
	|			THEN InventoryInWarehousesOfBalance.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SUM(CAST((ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) - ISNULL(ReservedProductsBalances.QuantityBalance, 0)) / &Factor AS NUMBER(15, 3))) AS Available
	|INTO TT_Balances
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			,
	|			Company = &Company
	|				AND Products = &Products
	|				AND &Characteristic
	|				AND &Batch) AS InventoryInWarehousesOfBalance
	|		LEFT JOIN AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit REFS Catalog.BusinessUnits
	|					AND SalesOrder <> UNDEFINED
	|					AND Products = &Products
	|					AND &Characteristic
	|					AND &Batch) AS ReservedProductsBalances
	|		ON InventoryInWarehousesOfBalance.StructuralUnit = ReservedProductsBalances.StructuralUnit
	|			AND InventoryInWarehousesOfBalance.Products = ReservedProductsBalances.Products
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.StructuralUnit,
	|	InventoryInWarehousesOfBalance.Products,
	|	CASE
	|		WHEN &UseCharacteristic
	|			THEN InventoryInWarehousesOfBalance.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatch
	|			THEN InventoryInWarehousesOfBalance.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Balances.StructuralUnit AS StructuralUnit,
	|	TT_Balances.Products AS Products,
	|	TT_Balances.Characteristic AS Characteristic,
	|	TT_Balances.Batch AS Batch,
	|	SUM(TT_Balances.Available - ISNULL(TT_ProductCart.Quantity, 0)) AS Available
	|FROM
	|	TT_Balances AS TT_Balances
	|		LEFT JOIN TT_ProductCart AS TT_ProductCart
	|		ON TT_Balances.Products = TT_ProductCart.Products
	|			AND TT_Balances.Characteristic = TT_ProductCart.Characteristic
	|			AND TT_Balances.Batch = TT_ProductCart.Batch
	|			AND TT_Balances.StructuralUnit = TT_ProductCart.StructuralUnit
	|
	|GROUP BY
	|	TT_Balances.StructuralUnit,
	|	TT_Balances.Products,
	|	TT_Balances.Characteristic,
	|	TT_Balances.Batch
	|
	|HAVING
	|	SUM(TT_Balances.Available - ISNULL(TT_ProductCart.Quantity, 0)) > 0";
	
	Query.SetParameter("ProductCart", Object.ShoppingCart.Unload());
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("Products", CartRowData.Products);
	Query.SetParameter("Factor", CartRowData.Factor);
	Query.SetParameter("UseBatch", ValueIsFilled(CartRowData.Batch));
	Query.SetParameter("UseCharacteristic", ValueIsFilled(CartRowData.Characteristic));
	
	If ValueIsFilled(CartRowData.Characteristic) Then
		Query.Text = StrReplace(Query.Text, "&Characteristic", "Characteristic = &Characteristic");
		Query.SetParameter("Characteristic", CartRowData.Characteristic);
	Else
		Query.SetParameter("Characteristic", True);
	EndIf;
	
	If ValueIsFilled(CartRowData.Batch) Then
		Query.Text = StrReplace(Query.Text, "&Batch", "Batch = &Batch");
		Query.SetParameter("Batch", CartRowData.Batch);
	Else
		Query.SetParameter("Batch", True);
	EndIf;
	
	Quantity = CartRowData.Quantity;
	
	Selection = Query.Execute().Select();
	While Selection.Next() And Quantity > 0 Do
		If Selection.Available <= Quantity Then
			ResultMap.Insert(Selection.StructuralUnit, Selection.Available);
			Quantity = Quantity - Selection.Available;
		Else
			ResultMap.Insert(Selection.StructuralUnit, Quantity);
			Quantity = 0;
		EndIf;
	EndDo;
	
	If Quantity > 0 Then
		ResultMap.Insert(Catalogs.BusinessUnits.EmptyRef(), Quantity);
	EndIf;
	
	Return ResultMap;
	
EndFunction

&AtServer
Procedure FillShoppingCartByBasis(BasisDocument)
	
	CartRowData = New Structure("
		|Products,
		|Characteristic,
		|Batch,
		|MeasurementUnit,
		|VATRate,
		|Price,
		|DiscountMarkupPercent,
		|Quantity,
		|Taxable,
		|Amount,
		|VATAmount,
		|Total");
	
	CartRowData.Insert("StructuralUnit", BasisDocumentStructuralUnit(BasisDocument));
	
	BasisInventory = BasisDocument.Inventory;
	For Each Row In BasisInventory Do
		FillPropertyValues(CartRowData, Row);
		AddProductsToCartCompletion(CartRowData);
	EndDo;
	
EndProcedure

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
	
	ResetListWarehouseBalancesCurrentRow();
	
EndProcedure

&AtServer
Procedure ResetListWarehouseBalancesCurrentRow()
	
	Items.ListWarehouseBalances.SelectedRows.Clear();
	Items.ListWarehouseBalances.CurrentRow = Undefined;
	
EndProcedure

&AtClient
Procedure SetListInventoryParentFilter()
	
	SelectedGroups = Items.ListProductsHierarchy.SelectedRows;
	
	SelectedGroupsCount = SelectedGroups.Count();
	
	If SelectedGroupsCount = 0
		Or SelectedGroupsCount = 1
		And Not ValueIsFilled(SelectedGroups[0]) Then
		
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

&AtServer
Procedure SetCartInfoLabelText()
	
	CartInfoLabelPattern = 
		NStr("en = 'Cart items: %1
			|Total: %2 %3'; 
			|ru = 'Позиций в корзине: %1
			|Итого: %2 %3';
			|pl = 'Pozycje w koszyku: %1
			|Łącznie: %2 %3';
			|es_ES = 'Artículos de la cesta: %1
			|Total:%2%3';
			|es_CO = 'Artículos de la cesta: %1
			|Total:%2%3';
			|tr = 'Sepet öğeleri: %1
			|Toplam: %2 %3';
			|it = 'Articoli carrello: %1
			|Totale: %2 %3';
			|de = 'Artikel im Warenkorb: %1
			|Gesamt: %2%3'");
	
	CartInfoLabel = StringFunctionsClientServer.SubstituteParametersToString(
		CartInfoLabelPattern,
		Format(Object.ShoppingCart.Count(), "NZ="),
		Format(Object.ShoppingCart.Total("Total"), "ND=15; NFD=2; NZ="),
		Object.DocumentCurrency);
	
EndProcedure

&AtClient
Procedure SetCartShowHideLabelText()
	
	If SelectionSettingsCache.ShowCart Then
		CartShowHideLabel = Nstr("en = 'Hide cart content'; ru = 'Скрыть содержимое корзины';pl = 'Ukryj zawartość koszyka';es_ES = 'Ocultar el contenido de la cesta';es_CO = 'Ocultar el contenido de la cesta';tr = 'Sepet içeriğini gizle';it = 'Nascondi contenuto carrello';de = 'Warenkorbinhalt ausblenden'");
	Else
		CartShowHideLabel = Nstr("en = 'Show cart content'; ru = 'Показать содержимое корзины';pl = 'Pokaż zawartość koszyka';es_ES = 'Mostrar el contenido de la cesta';es_CO = 'Mostrar el contenido de la cesta';tr = 'Sepet içeriğini göster';it = 'Mostra contenuto carrello';de = 'Warenkorbinhalt anzeigen'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function BasisDocumentSynonym(DocumentName)
	Return Metadata.Documents[DocumentName].Synonym;
EndFunction

&AtClientAtServerNoContext
Function CreateGeneralAttributeValuesStructure(TabRow)
	
	StructureData = New Structure("
		|Amount,
		|Quantity,
		|Total,
		|Price,
		|Products,
		|Characteristic,
		|DiscountMarkupPercent,
		|VATAmount,
		|VATRate,
		|Batch,
		|MeasurementUnit,
		|StructuralUnit,
		|IsBundle");
	
	FillPropertyValues(StructureData, TabRow);
	Return StructureData;
	
EndFunction

#EndRegion

#Region Other

&AtServerNoContext
Function AvailableWarehouses()
	
	AvailableWarehouses = New Array;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	BusinessUnits.Ref AS Ref
	|FROM
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	NOT BusinessUnits.DeletionMark
	|	AND BusinessUnits.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		AvailableWarehouses.Add(Selection.Ref);
	EndDo;
	
	Return AvailableWarehouses;
	
EndFunction

&AtServer
Procedure ContractOnChangeServer()
	
	If ValueIsFilled(Object.Contract) Then
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	CounterpartyContracts.Company AS Company,
		|	CounterpartyContracts.DiscountMarkupKind AS DiscountMarkupKind,
		|	CounterpartyContracts.PriceKind AS PriceKind,
		|	CounterpartyContracts.SettlementsCurrency AS DocumentCurrency,
		|	Counterparties.VATTaxation AS VATTaxation,
		|	ISNULL(PriceTypes.PriceIncludesVAT, FALSE) AS AmountIncludesVAT
		|FROM
		|	Catalog.CounterpartyContracts AS CounterpartyContracts
		|		INNER JOIN Catalog.Counterparties AS Counterparties
		|		ON CounterpartyContracts.Owner = Counterparties.Ref
		|		LEFT JOIN Catalog.PriceTypes AS PriceTypes
		|		ON CounterpartyContracts.PriceKind = PriceTypes.Ref
		|WHERE
		|	CounterpartyContracts.Ref = &Ref";
		
		Query.SetParameter("Ref", Object.Contract);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			FillPropertyValues(Object, Selection);
		EndIf;
		
		ParentCompany = DriveServer.GetCompany(Object.Company);
		
		If ValueIsFilled(Object.PriceKind) Then
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
		EndIf;
		
	Else
		
		Object.Company = Undefined;
		ParentCompany = Undefined;
		Object.DiscountMarkupKind = Undefined;
		Object.PriceKind = Undefined;
		Object.DocumentCurrency = Undefined;
		Object.VATTaxation = Undefined;
		Object.PriceKindCurrency = Undefined;
		Object.PriceCalculationMethod = Undefined;
		Object.DynamicPriceKindBasic = Undefined;
		Object.DynamicPriceKindPercent = 0;
		Object.AmountIncludesVAT = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CompanyOnChangeServer()
	
	If ValueIsFilled(Object.Company) Then
		ParentCompany = DriveServer.GetCompany(Object.Company);
	Else
		ParentCompany = Undefined;
	EndIf;
	
EndProcedure

&AtServer
Procedure CounterpartyOnChangeServer()
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	Counterparties.DiscountMarkupKind AS DiscountMarkupKind,
	|	Counterparties.PriceKind AS PriceKind,
	|	Counterparties.SettlementsCurrency AS DocumentCurrency,
	|	Counterparties.VATTaxation AS VATTaxation,
	|	ISNULL(PriceTypes.PriceIncludesVAT, FALSE) AS AmountIncludesVAT
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|		LEFT JOIN Catalog.PriceTypes AS PriceTypes
	|		ON Counterparties.PriceKind = PriceTypes.Ref
	|WHERE
	|	Counterparties.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Counterparty);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Object, Selection);
	EndIf;
	
	If ValueIsFilled(Object.PriceKind) Then
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
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePrintFormProducts(Product)
	
	RefsArray = New Array;
	RefsArray.Add(Product);
	
	OpenParameters = New Structure("PrintManagerName, TemplatesNames, CommandParameter, PrintParameters");
	OpenParameters.PrintManagerName = "Catalog.Products";
	OpenParameters.TemplatesNames   = "ProductCardForExternalUsers";
	OpenParameters.CommandParameter	 = RefsArray;
	
	PrintParameters = New Structure("FormTitle, ID, AdditionalParameters");
	PrintParameters.FormTitle = NStr("en = 'Product card'; ru = 'Карточка номенклатуры';pl = 'Karta produktu';es_ES = 'Tarjeta del producto';es_CO = 'Tarjeta del producto';tr = 'Ürün kartı';it = 'Scheda articolo';de = 'Produktkarte'");
	PrintParameters.ID = "ProductCardForExternalUsers";
	PrintParameters.AdditionalParameters = New Structure("Company", Object.Company);
	OpenParameters.PrintParameters = PrintParameters;
	
	If Not PrintManagementClientDrive.DisplayPrintOption(RefsArray, OpenParameters, FormOwner, UniqueKey, OpenParameters.PrintParameters) Then
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisObject, UniqueKey);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInContractSettingsCache()
	
	SelectionSettingsCache.Insert("PriceWithFormula", (Object.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula));
	SelectionSettingsCache.Insert("PricesKindPriceIncludesVAT",
		?(ValueIsFilled(Object.PriceKind),
			Common.ObjectAttributeValue(Object.PriceKind, "PriceIncludesVAT"),
			Object.AmountIncludesVAT));
	SelectionSettingsCache.Insert("DiscountsMarkupsVisible", ValueIsFilled(Object.DiscountMarkupKind));
	SelectionSettingsCache.Insert("DiscountMarkupPercent",
		?(ValueIsFilled(Object.DiscountMarkupKind),
			Common.ObjectAttributeValue(Object.DiscountMarkupKind, "Percent"),
			0));
	
EndProcedure

&AtServer
Function BasisDocumentStructuralUnit(BasisDocument)
	
	Result = Catalogs.BusinessUnits.EmptyRef();
	
	If TypeOf(BasisDocument) = Type("DocumentRef.SalesOrder") Then
		Result = Common.ObjectAttributeValue(BasisDocument, "StructuralUnitReserve");
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillAttributeByBasis(AttributeName, BasisRef)
	
	Object[AttributeName] = Common.ObjectAttributeValue(BasisRef, AttributeName);
	
EndProcedure

#EndRegion

#Region CreatingSalesOrder

&AtClient
Procedure CheckWarehousesFillIn(Cancel)
	
	Filter = New Structure;
	Filter.Insert("StructuralUnit", PredefinedValue("Catalog.BusinessUnits.EmptyRef"));
	
	EmptyWarehousesRows = Object.ShoppingCart.FindRows(Filter);
	
	If EmptyWarehousesRows.Count() > 0 Then
		
		Lines = "";
		For Each Row In EmptyWarehousesRows Do
			Lines = Lines + ?(Lines="", "#", ", #") + Row.LineNumber;
		EndDo;
		
		CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot create a Sales order. Warehouse is required in the following lines: %1.'; ru = 'Не удалось создать заказ покупателя. Требуется указать склад в следующих строках: %1.';pl = 'Nie można utworzyć Zamówienia sprzedaży. Magazyn jest wymagany w następujących wierszach: %1.';es_ES = 'No se ha podido crear una orden de ventas. Se requiere un almacén en las siguientes líneas: %1.';es_CO = 'No se ha podido crear una orden de ventas. Se requiere un almacén en las siguientes líneas: %1.';tr = 'Satış siparişi oluşturulamıyor. Şu satırlarda Ambar gerekli: %1.';it = 'Impossibile creare un ordine cliente. Il magazzino è richiesto nelle righe seguenti: %1.';de = 'Fehler beim Erstellen eines Kundenauftrags. Lager ist in den folgenden Zeilen erforderlich: %1.'"),
			Lines));
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckPricesFillIn(Cancel)
	
	Filter = New Structure;
	Filter.Insert("Price", 0);
	
	EmptyPriceRows = Object.ShoppingCart.FindRows(Filter);
	
	If EmptyPriceRows.Count() > 0 Then
		
		Lines = "";
		For Each Row In EmptyPriceRows Do
			Lines = Lines + ?(Lines="", "#", ", #") + Row.LineNumber;
		EndDo;
		
		CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot create a Sales order. Price is required in the following lines: %1.
				|Contact your manager so that they fill in the prices. Then try again.'; 
				|ru = 'Не удалось создать заказ покупателя. Требуется указать цену в следующих строках: %1.
				|Попросите менеджера заполнить цены и повторите попытку.';
				|pl = 'Nie można utworzyć Zamówienia sprzedaży. Cena jest wymagana w następujących wierszach: %1.
				|Skontaktuj się z Twoim kierownikiem, aby wypełnił ceny. Następnie spróbuj ponownie.';
				|es_ES = 'No se ha podido crear una orden de ventas. Se requiere el precio en las siguientes líneas:%1.
				| Póngase en contacto con su gestor para que rellene los precios. Inténtelo de nuevo.';
				|es_CO = 'No se ha podido crear una orden de ventas. Se requiere el precio en las siguientes líneas:%1.
				| Póngase en contacto con su gestor para que rellene los precios. Inténtelo de nuevo.';
				|tr = 'Satış siparişi oluşturulamıyor. Şu satırlarda fiyat gerekli: %1.
				|Fiyatları doldurması için yöneticinize başvurun. Ardından, tekrar deneyin.';
				|it = 'Impossibile creare un ordine cliente. Il prezzo è richiesto nelle seguenti righe: %1.
				|Contatta il tuo responsabile affinché inserisca i prezzi e riprova.';
				|de = 'Fehler beim Erstellen eines Kundenauftrags. Preis ist in den folgenden Zeilen erforderlich: %1.
				| Kontaktieren Sie Ihren Manager für Auffüllen von den Preisen. Dann versuchen Sie erneut.'"),
			Lines));
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateDocumentSalesOrder(DeliveryInformation)
	
	Warehouses = Object.ShoppingCart.Unload(, "StructuralUnit");
	Warehouses.GroupBy("StructuralUnit");
	
	DocumentDate = CurrentSessionDate();
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	SalesTaxRate = DriveServer.CounterpartySalesTaxRate(Object.Counterparty, AccountingPolicy.RegisteredForSalesTax);
	
	If GetFunctionalOption("UseSalesOrderStatuses") Then
		OrderState = Catalogs.SalesOrderStatuses.Open;
	Else
		OrderState = Constants.SalesOrdersInProgressStatus.Get();
	EndIf;
	
	If ValueIsFilled(DeliveryInformation.ShippingAddress) Then
		SalesRep = Common.ObjectAttributeValue(DeliveryInformation.ShippingAddress, "SalesRep");
	EndIf;
	
	If Not ValueIsFilled(SalesRep) Then
		SalesRep = Common.ObjectAttributeValue(Object.Counterparty, "SalesRep");
	EndIf;
	
	If DoOperationsByContracts Then
		Department = Common.ObjectAttributeValue(Object.Contract, "Department");
	Else
		Department = Common.ObjectAttributeValue(Object.Counterparty, "Department");
	EndIf;
	
	Author = Users.CurrentUser();
	OperationKind = Enums.OperationTypesSalesOrder.OrderForSale;
	PostingIsAllowed = True;
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	InventoryItem = Enums.ProductsTypes.InventoryItem;
	
	BeginTransaction();
	
	Try
		
		For Each Row In Warehouses Do
			
			DocumentObject = Documents.SalesOrder.CreateDocument();
			
			DriveServer.FillDocumentHeader(
				DocumentObject,
				OperationKind,,,
				PostingIsAllowed);
			
			FillPropertyValues(DocumentObject, Object);
			FillPropertyValues(DocumentObject, DeliveryInformation);
			
			WorkWithVAT.ProcessingCompanyVATNumbers(DocumentObject, "CompanyVATNumber");
			
			DocumentObject.Date					 	= DocumentDate;
			DocumentObject.OperationKind 			= OperationKind;
			DocumentObject.StructuralUnitReserve 	= Row.StructuralUnit;
			DocumentObject.OrderState 				= OrderState;
			DocumentObject.SalesRep 				= SalesRep;
			DocumentObject.SalesStructuralUnit 		= Department;
			DocumentObject.SalesTaxRate 			= SalesTaxRate;
			DocumentObject.ShipmentDatePosition 	= Enums.AttributeStationing.InHeader;
			
			If ValueIsFilled(DocumentObject.SalesTaxRate) Then
				DocumentObject.SalesTaxPercentage = Common.ObjectAttributeValue(DocumentObject.SalesTaxRate, "Rate");
			EndIf;
			
			If ValueIsFilled(DocumentObject.ShippingAddress) Then
				DeliveryData = ShippingAddressesServer.GetDeliveryAttributesForAddress(DocumentObject.ShippingAddress);
				
				FillPropertyValues(DocumentObject, DeliveryData,,"SalesRep,ContactPerson");
				If ValueIsFilled(DeliveryData.SalesRep) Then
					DocumentObject.SalesRep = DeliveryData.SalesRep;
				EndIf;
			EndIf;
			
			If ValueIsFilled(Quotation) Then
				DocumentObject.BasisDocument = Quotation;
			EndIf;
			
			DocumentObject.Author = Author;
			
			StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(DocumentObject.Date, DocumentObject.DocumentCurrency, DocumentObject.Company);
			DocumentObject.ExchangeRate = StructureByCurrency.Rate;
			DocumentObject.Multiplicity = StructureByCurrency.Repetition;
			DocumentObject.ContractCurrencyExchangeRate = DocumentObject.ExchangeRate;
			DocumentObject.ContractCurrencyMultiplicity = DocumentObject.Multiplicity;
			
			ShoppingCartRows = Object.ShoppingCart.FindRows(New Structure("StructuralUnit", Row.StructuralUnit));
			For Each ProductRow In ShoppingCartRows Do
				NewRow = DocumentObject.Inventory.Add();
				FillPropertyValues(NewRow, ProductRow);
				
				ProductsType = Common.ObjectAttributeValue(NewRow.Products, "ProductsType");
				NewRow.ProductsTypeInventory = (ProductsType = InventoryItem);
			EndDo;
			
			If UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInDocument(DocumentObject);
			EndIf;
			
			DocumentObject.RecalculateSalesTax();
			
			DocumentObject.Write(DocumentWriteMode.Posting);
			
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		ErrorDescription = NStr("en = 'Cannot create a Sales order due to an unexpected error.
			|Contact the support team. Details: %1.'; 
			|ru = 'Не удалось создать заказ покупателя из-за непредвиденной ошибки.
			|Обратитесь в службу поддержки. Подробнее: %1.';
			|pl = 'Nie można utworzyć Zamówienia sprzedaży z powodu nieoczekiwanego błędu.
			|Skontaktuj się z zespołem pomocy technicznej. Szczegóły: %1.';
			|es_ES = 'No se ha podido crear una orden de ventas debido a un error inesperado.
			|Póngase en contacto con el equipo de soporte. Detalles:%1';
			|es_CO = 'No se ha podido crear una orden de ventas debido a un error inesperado.
			|Póngase en contacto con el equipo de soporte. Detalles:%1';
			|tr = 'Beklenmedik bir hata nedeniyle Satış siparişi oluşturulamıyor.
			|Destek ekibine başvurun. Ayrıntılar: %1.';
			|it = 'Impossibile creare un ordine cliente a causa di un errore imprevisto.
			|Contatta il team di assistenza. Dettagli: %1.';
			|de = 'Fehler beim Erstellen eines Kundenauftrags wegen eines unerwarteten Fehlers.
			|Kontaktieren Sie die Unterstützungsgruppe. Details: %1.'");
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			ErrorDescription,
			BriefErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion

#Region Initialize

FormIsClosing = False;

#EndRegion
