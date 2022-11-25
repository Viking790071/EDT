
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		Cancel = True;
	Else
		ReadOnly = True;
	EndIf;
	
EndProcedure

#EndRegion
