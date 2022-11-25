#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Catalog attributes names which values you can apply batch changing to.
//
// Returns:
//   Array (String) - catalog attributes names.
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// SaaSTechnology.ExportImportData

// Catalog attributes names used to control the uniqueness of items.
//
// Returns:
//   Array (String) - catalog attributes names.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("Report");
	Result.Add("VariantKey");
	
	Return Result;
	
EndFunction

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#EndIf