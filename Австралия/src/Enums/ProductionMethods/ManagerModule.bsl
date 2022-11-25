#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	AllowedValues = New Array;
	AllowedValues.Add(InHouseProduction);
	
	// begin Drive.FullVersion
	If Constants.CanReceiveSubcontractingServices.Get() Then
		AllowedValues.Add(Subcontracting);
	EndIf;
	// end Drive.FullVersion
	
	Parameters.Filter.Insert("Ref", New FixedArray(AllowedValues));
	
EndProcedure

#EndRegion

#EndIf