
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
			
			FillingValues.Insert("StructuralUnit", CommandExecuteParameters.Source.FilterWarehouse);
			
		EndIf;
		
		SelectedRows = CommandExecuteParameters.Source.Items.List.SelectedRows;
		
		For Each Row In SelectedRows Do
			
			FillingValues.Inventory.Add(DataAboutProduct(Row));
			
		EndDo;
		
	ElsIf CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.ItemForm" Then
		
		FillingValues.Inventory.Add(DataAboutProduct(CommandExecuteParameters.Source.Object.Ref));
		
	EndIf;
	
	OpenForm("Document.SalesInvoice.ObjectForm", New Structure("FillingValues", FillingValues));
	
EndProcedure

&AtServer
Function DataAboutProduct(Val Product)
	
	ProductAttribures = Common.ObjectAttributesValues(Product, "MeasurementUnit, VATRate, IsBundle");
	
	InventoryLine = New Structure;
	InventoryLine.Insert("Products", Product);
	InventoryLine.Insert("Quantity", 1);
	InventoryLine.Insert("Price", 0);
	InventoryLine.Insert("MeasurementUnit", ProductAttribures.MeasurementUnit);
	InventoryLine.Insert("VATRate", ProductAttribures.VATRate);
	InventoryLine.Insert("IsBundle", ProductAttribures.IsBundle);
	
	Return InventoryLine;
	
EndFunction
