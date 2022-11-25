
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If ValueIsFilled(Record.Recipient) Then
		
		Items.Recipient.Visible = False;
		
	EndIf;
	
EndProcedure

#EndRegion
