#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification data processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// SaaSTechnology.ExportImportData

// Returns the catalog attributes that naturally form a catalog item key.
// 
//
// Returns:
//  Array - an array of attribute names that form a natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("Code");
	
	Return Result;
	
EndFunction

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#EndIf
