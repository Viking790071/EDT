#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.List.ReadOnly = NOT AllowedEditDocumentPrices;
	
	If Parameters.Filter.Property("Products") AND GetFunctionalOption("UseProductBundles") Then
		
		BundleAttributes = Common.ObjectAttributesValues(Parameters.Filter.Products, "IsBundle, BundlePricingStrategy");
		
		If BundleAttributes.IsBundle
			AND BundleAttributes.BundlePricingStrategy = Enums.ProductBundlePricingStrategy.PerComponentPricing Then
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
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

