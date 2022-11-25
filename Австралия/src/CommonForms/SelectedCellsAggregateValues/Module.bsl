#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Parameters:
	//   If the Calculation parameter is passed, the SpreadsheetDocument and SelectedAreas parameters are not used.
	//   Calculation - Structure - Result returned by  StandardSubsystemsClientServer.CalculateCells() function.
	//   SpreadsheetDocument - SpreadsheetDocument - A table used for calculations.
	//   SelectedAreas - Array - Document areas that require calculation.
	//       See the return value of StandardSubsystemsClient.SelectedAreas().
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Calculation = CommonClientServer.StructureProperty(Parameters, "Calculation");
	If TypeOf(Calculation) <> Type("Structure") Then
		Calculation = StandardSubsystemsClientServer.CalculateCells(Parameters.SpreadsheetDocument, Parameters.SelectedAreas);
	EndIf;
	FillPropertyValues(ThisObject, Calculation);
	
	DigitsInNumbers    = Max(0, NumberOfDigits(Amount), NumberOfDigits(Minimum), NumberOfDigits(Maximum));
	AverageDigits = Max(DigitsInNumbers, NumberOfDigits(Mean));
	
	NumberFormat = "NFD=" + String(DigitsInNumbers) + "; NZ=0";
	Items.Amount.EditFormat    = NumberFormat;
	Items.Minimum.EditFormat  = NumberFormat;
	Items.Maximum.EditFormat = NumberFormat;
	Items.Mean.EditFormat  = "NFD=" + String(AverageDigits) + "; NZ=0";
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		CommonClientServer.SetFormItemProperty(Items, "Close", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "Help", "OnlyInAllActions", True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Function NumberOfDigits(Number)
	Return StrLen(Max(Number,-Number)%1)-2;
EndFunction

#EndRegion