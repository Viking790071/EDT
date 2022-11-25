#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	AllowedValues = New Array;
	AllowedValues.Add(Purchase);
	
	If Constants.UseSubcontractorManufacturers.Get() Or Constants.CanReceiveSubcontractingServices.Get() Then
		AllowedValues.Add(Processing);
	EndIf;
	
	UseProductionSubsystem = False;
	// begin Drive.FullVersion
	UseProductionSubsystem = Constants.UseProductionSubsystem.Get();
	// end Drive.FullVersion

	If UseProductionSubsystem Then
		AllowedValues.Add(Production);
	EndIf;
	
	If Constants.UseKitProcessing.Get() Or UseProductionSubsystem Then
		AllowedValues.Add(Assembly);
	EndIf;

	Parameters.Filter.Insert("Ref", New FixedArray(AllowedValues));
	
EndProcedure

#EndRegion

#EndIf