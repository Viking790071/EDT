#Region EventHandlers

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
			FillingValues.Insert("Warehouse", CommandExecuteParameters.Source.FilterWarehouse);
		EndIf;
	ElsIf CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.CartForm" Then
		FillingValues.Insert("PriceKind", CommandExecuteParameters.Source.FormOwner.FilterPriceType);
		If ValueIsFilled(CommandExecuteParameters.Source.FormOwner.FilterWarehouse) Then
			FillingValues.Insert("Warehouse", CommandExecuteParameters.Source.FormOwner.FilterWarehouse);
		EndIf;
	EndIf;
	
	SelectedRows = CommandExecuteParameters.Source.Cart;
	
	For Each Row In SelectedRows Do
		
		If CheckProduct(Row.Products) Then
		
			FillingValues.Inventory.Add(DataAboutProduct(Row.Products));
		
		EndIf;
		
	EndDo;
	
	OpenForm("Document.PurchaseOrder.ObjectForm", New Structure("FillingValues", FillingValues));
	
	If CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.ListForm" Then
		CommandExecuteParameters.Source.Cart.Clear();
		CommandExecuteParameters.Source.RefreshLabelSelectedProducts();
	ElsIf CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.CartForm" Then
		CommandExecuteParameters.Source.MoveToDocument = True;
		CommandExecuteParameters.Source.Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function DataAboutProduct(Product)
	
	ProductAttribures = Common.ObjectAttributesValues(Product, "MeasurementUnit, VATRate, IsBundle");
	
	InventoryLine = New Structure;
	InventoryLine.Insert("Products", Product);
	InventoryLine.Insert("Quantity", 1);
	InventoryLine.Insert("Price", 0);
	InventoryLine.Insert("MeasurementUnit", ProductAttribures.MeasurementUnit);
	InventoryLine.Insert("VATRate", ProductAttribures.VATRate);
	
	Return InventoryLine;
	
EndFunction

&AtServer
Function CheckProduct(Product)
	
	Result = False;
	
	ObjectAttributes = Common.ObjectAttributesValues(Product, "ProductsType, IsBundle");
	
	If ObjectAttributes.ProductsType = Enums.ProductsTypes.InventoryItem
		And Not ObjectAttributes.IsBundle Then
		
		Result = True;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion