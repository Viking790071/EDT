#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("RateSource");
	Result.Add("Markup");
	Result.Add("MainCurrency");
	Result.Add("RateCalculationFormula");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

#EndRegion

#EndRegion

#EndIf