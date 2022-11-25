#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Record In ThisObject Do
		
		If Record.Products = Catalogs.Products.EmptyRef() 
			And Not Record.ZeroInvoice Then
			
			TextMessage = "";
			
			If Not AdditionalProperties.Property("AllowEmptyRecords") 
				Or Not AdditionalProperties.AllowEmptyRecords Then
				
				Cancel = True;
				
				TextMessage = NStr("en = 'Products are required.'; ru = 'Требуется указать номенклатуру.';pl = 'Produkty są wymagane.';es_ES = 'Se requieren productos.';es_CO = 'Se requieren productos.';tr = 'Ürünler gerekli.';it = 'Sono richiesti gli articoli.';de = 'Produkte sind erforderlich.'");
				
				CommonClientServer.MessageToUser(TextMessage);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf