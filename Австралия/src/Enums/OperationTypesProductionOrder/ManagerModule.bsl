#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Count() = 0 Then
		AllowedValues = New Array;
		AllowedValues.Add(Assembly);
		AllowedValues.Add(Disassembly);
		// begin Drive.FullVersion
		If Constants.UseProductionSubsystem.Get() Then
			AllowedValues.Add(Production);
		EndIf;
		// end Drive.FullVersion
		Parameters.Filter.Insert("Ref", New FixedArray(AllowedValues));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf