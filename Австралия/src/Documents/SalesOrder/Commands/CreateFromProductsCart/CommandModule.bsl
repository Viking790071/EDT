
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandExecuteParameters.Source = Undefined Then
		Return;
	EndIf;
	
	FillingValues = New Structure;
	
	FillingValues.Insert("Inventory", New Array);
	
	If CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.ListForm" Then
		FillingValues.Insert("PriceKind", CommandExecuteParameters.Source.FilterPriceType);
		If ValueIsFilled(CommandExecuteParameters.Source.FilterWarehouse) Then
			FillingValues.Insert("StructuralUnitReserve", CommandExecuteParameters.Source.FilterWarehouse);
		EndIf;
	ElsIf CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.CartForm" Then
		FillingValues.Insert("PriceKind", CommandExecuteParameters.Source.FormOwner.FilterPriceType);
		If ValueIsFilled(CommandExecuteParameters.Source.FormOwner.FilterWarehouse) Then
			FillingValues.Insert("StructuralUnitReserve", CommandExecuteParameters.Source.FormOwner.FilterWarehouse);
		EndIf;
	EndIf;
	
	SelectedRows = CommandExecuteParameters.Source.Cart;
	
	For Each Row In SelectedRows Do
		
		If CheckProduct(Row.Products) Then
			
			FillingValues.Inventory.Add(DataAboutProduct(Row.Products));
			
		EndIf;
		
	EndDo;
	
	OpenForm("Document.SalesOrder.ObjectForm", New Structure("FillingValues", FillingValues));
	
	If CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.ListForm" Then
		CommandExecuteParameters.Source.Cart.Clear();
		CommandExecuteParameters.Source.RefreshLabelSelectedProducts();
	ElsIf CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.CartForm" Then
		CommandExecuteParameters.Source.MoveToDocument = True;
		CommandExecuteParameters.Source.Close();
	EndIf;
	
EndProcedure

&AtServer
Function DataAboutProduct(Product)
	
	ProductAttribures = Common.ObjectAttributesValues(Product, "MeasurementUnit, VATRate, IsBundle, ProductsType");
	
	InventoryLine = New Structure;
	InventoryLine.Insert("Products", Product);
	InventoryLine.Insert("Quantity", 1);
	InventoryLine.Insert("Price", 0);
	InventoryLine.Insert("MeasurementUnit", ProductAttribures.MeasurementUnit);
	InventoryLine.Insert("VATRate", ProductAttribures.VATRate);
	InventoryLine.Insert("IsBundle", ProductAttribures.IsBundle);
	ProductsTypeInventory = (ProductAttribures.ProductsType = Enums.ProductsTypes.InventoryItem);
	InventoryLine.Insert("ProductsTypeInventory", ProductsTypeInventory);
	
	Return InventoryLine;
	
EndFunction

&AtServer
Function CheckProduct(Product)
	
	Result = False;
	
	ProductType = Common.ObjectAttributeValue(Product, "ProductsType");
	
	If ProductType = Enums.ProductsTypes.InventoryItem
		OR ProductType = Enums.ProductsTypes.Work
		OR ProductType = Enums.ProductsTypes.Service Then
		
		Result = True;
		
	EndIf;
	
	Return Result;
	
EndFunction
