#Region EventHandlers

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
		
		If ValueIsFilled(CommandExecuteParameters.Source.FilterWarehouse) Then
			
			FillingValues.Insert("Warehouse", CommandExecuteParameters.Source.FilterWarehouse);
			
		EndIf;
		
		SelectedRows = CommandExecuteParameters.Source.Items.List.SelectedRows;
		
		For Each Row In SelectedRows Do
			
			If CheckProduct(Row) Then
				
				FillingValues.Inventory.Add(DataAboutProduct(Row));
				
			EndIf;
			
		EndDo;
		
		If SelectedRows.Count() = 1 
			And FillingValues.Inventory.Count() = 1 Then
			
			FillingValues.Insert("Counterparty", FillingValues.Inventory[0].Vendor);
			
		EndIf;
		
	ElsIf CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.ItemForm" Then
		
		If CheckProduct(CommandExecuteParameters.Source.Object.Ref) Then
			
			DataAboutProduct = DataAboutProduct(CommandExecuteParameters.Source.Object.Ref);
			
			FillingValues.Insert("Counterparty", DataAboutProduct.Vendor);
			FillingValues.Inventory.Add(DataAboutProduct);
			
		EndIf;
		
	EndIf;
	
	OpenForm("Document.PurchaseOrder.ObjectForm", New Structure("FillingValues", FillingValues));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function DataAboutProduct(Val Product)
	
	ProductAttribures = Common.ObjectAttributesValues(Product, "MeasurementUnit, VATRate, IsBundle, Vendor");
	
	InventoryLine = New Structure;
	InventoryLine.Insert("Products", Product);
	InventoryLine.Insert("Quantity", 1);
	InventoryLine.Insert("Price", 0);
	InventoryLine.Insert("MeasurementUnit", ProductAttribures.MeasurementUnit);
	InventoryLine.Insert("VATRate", ProductAttribures.VATRate);
	InventoryLine.Insert("Vendor", ProductAttribures.Vendor);
	
	If Constants.UseProductCrossReferences.Get() Then
		
		InventoryLine.Insert("Counterparty", ProductAttribures.Vendor);
		Catalogs.SuppliersProducts.FindCrossReferenceByParameters(InventoryLine);
		InventoryLine.Delete("Counterparty");
		
	EndIf;
	
	Return InventoryLine;
	
EndFunction

&AtServer
Function CheckProduct(Val Product)
	
	Result = False;
	
	ObjectAttributes = Common.ObjectAttributesValues(Product, "ProductsType, IsBundle");
	
	If ObjectAttributes.ProductsType = Enums.ProductsTypes.InventoryItem
		And Not ObjectAttributes.IsBundle Then
		
		Result = True;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion