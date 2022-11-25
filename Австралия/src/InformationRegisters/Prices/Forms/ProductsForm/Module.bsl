#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.List.ReadOnly = NOT AllowedEditDocumentPrices;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Undefined, PricesFields());
	// Prices precision end
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.Price);
	
	Return Fields;
	
EndFunction

#EndRegion
