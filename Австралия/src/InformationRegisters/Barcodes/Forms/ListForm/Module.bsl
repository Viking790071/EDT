
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Products") Then
		DriveClientServer.SetListFilterItem(List, "Products", Parameters.Products);
		If Parameters.Products.ProductsType <> Enums.ProductsTypes.InventoryItem Then
			AutoTitle = False;
			Title = NStr("en = 'Barcodes are stored only for inventories'; ru = 'Штрихкоды хранятся только для запасов';pl = 'Kody kreskowe są przechowywane tylko dla zapasów';es_ES = 'Códigos de barras se almacenan solo para inventarios';es_CO = 'Códigos de barras se almacenan solo para inventarios';tr = 'Barkodları sadece stoklar için saklanır';it = 'I codici a barre sono archiviati sono per scorte';de = 'Barcodes werden nur für Inventare gespeichert'");
			Items.List.ReadOnly = True;
		EndIf;
	EndIf;
	
	NewConditionalAppearance = List.ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, "MeasurementUnit", , "NotFilled");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "MeasurementUnit");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", New DataCompositionField("Products.MeasurementUnit"));
	
EndProcedure
