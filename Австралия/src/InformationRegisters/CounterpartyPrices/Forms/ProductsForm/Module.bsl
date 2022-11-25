
#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Products") Then
		
		Products = Parameters.Filter.Products;
		
		If Products.ProductsType <> Enums.ProductsTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en = 'Supplier prices can be entered only for products with the Inventory type'; ru = 'Цены контрагентов можно вводить только для номенклатуры с типом Запас';pl = 'Ceny dostawcy mogą być wprowadzone tylko dla pozycji typu Zapas';es_ES = 'Precios del proveedor pueden introducirse solo para los productos con el tipo Inventario';es_CO = 'Precios del proveedor pueden introducirse solo para los productos con el tipo Inventario';tr = 'Tedarikçi fiyatları sadece Stok türü ürünler için girilebilir';it = 'I prezzi fornitore possono essere inseriti solo per gli articoli di tipo Scorta';de = 'Lieferantenpreise können nur für Produkte mit dem Bestandstyp eingegeben werden'");
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
