#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Returns a list of attributes which can be edited with the use of the batch modification processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	Return AttachedFiles.AttributesToEditInBatchProcessing();
	
EndFunction

#EndRegion

#EndIf
