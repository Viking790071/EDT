
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandExecuteParameters.Source = Undefined Then
		Return;
	EndIf;
	
	FillingValues = New Structure;
	
	FillingValues.Insert("Inventory", New Array);
	
	FillingValues.Insert("PriceKind", CommandExecuteParameters.Source.FilterPriceType);
	
	SelectedRows = CommandExecuteParameters.Source.Cart;
	
	For Each Row In SelectedRows Do
		
		If CheckProduct(Row.Products) Then
			
			FillingValues.Inventory.Add(DataAboutProduct(Row.Products));
			
		EndIf;
		
	EndDo;
	
	OpenForm("Document.Quote.ObjectForm", New Structure("FillingValues", FillingValues));
	
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
	
	InventoryLine = New Structure;
	InventoryLine.Insert("Products", Product);
	InventoryLine.Insert("Quantity", 1);
	InventoryLine.Insert("Price", 0);
	InventoryLine.Insert("MeasurementUnit", Product.MeasurementUnit);
	InventoryLine.Insert("VATRate", Product.VATRate);
	InventoryLine.Insert("IsBundle", Product.IsBundle);
	
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
