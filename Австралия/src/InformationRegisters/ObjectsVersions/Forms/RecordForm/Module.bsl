
#Region EventHandlers

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	Cancel = True;
EndProcedure

#EndRegion
