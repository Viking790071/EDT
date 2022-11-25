
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandExecuteParameters.Source = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CommandExecuteParameters.Source) = Type("ClientApplicationForm") And CommandExecuteParameters.Source.Modified Then
		CommandExecuteParameters.Source.Write();
	EndIf;
	
	FillingValues = New Structure;
	
	FillingValues.Insert("Inventory", New Array);
	
	If CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.ListForm" Then
		
		FillingValues.Insert("PriceKind", CommandExecuteParameters.Source.FilterPriceType);
		
		SelectedRows = CommandExecuteParameters.Source.Items.List.SelectedRows;
		
		For Each Row In SelectedRows Do
			
			If CheckProduct(Row) Then
			
				FillingValues.Inventory.Add(DataAboutProduct(Row));
			
			EndIf;
			
		EndDo;
		
	ElsIf CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.ItemForm" Then
		
		If CheckProduct(CommandExecuteParameters.Source.Object.Ref) Then
			
			FillingValues.Inventory.Add(DataAboutProduct(CommandExecuteParameters.Source.Object.Ref));
			
		EndIf;
		
	EndIf;
	
	OpenForm("Document.Quote.ObjectForm", New Structure("FillingValues", FillingValues));
	
EndProcedure

&AtServer
Function DataAboutProduct(Val Product)
	
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
Function CheckProduct(Val Product)
	
	Result = False;
	
	ProductType = Common.ObjectAttributeValue(Product, "ProductsType");
	
	If ProductType = Enums.ProductsTypes.InventoryItem
		OR ProductType = Enums.ProductsTypes.Work
		OR ProductType = Enums.ProductsTypes.Service Then
		
		Result = True;
		
	EndIf;
	
	Return Result;
	
EndFunction
