#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Products") Then
		
		Products = Parameters.Filter.Products;
		
		If Not Products.ProductsType = Enums.ProductsTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en = 'Reorder point settings is used only for inventories'; ru = 'Управление запасами используется только для запасов';pl = 'Stany mini/maks są używane tylko w przypadku zapasów';es_ES = 'Configuraciones del punto de reordenación se utilizan solo para inventarios';es_CO = 'Configuraciones del punto de reordenación se utilizan solo para inventarios';tr = 'Yeni sipariş noktası ayarları sadece stoklar için kullanılır';it = 'Le impostazioni dei punti di riordino sono utilizzate solo per le scorte';de = 'Einstellungen Nachbestellpunkt werden nur für Bestände verwendet'");
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
