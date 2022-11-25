
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Filter.Property("Recipient") Then
		Items.Recipient.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion
