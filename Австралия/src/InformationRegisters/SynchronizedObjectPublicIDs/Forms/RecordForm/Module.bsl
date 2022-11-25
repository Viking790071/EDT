#Region EventHandlers

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	NewUUID = New UUID(IDAsString);
	If Record.ID <> NewUUID Then
		Record.ID = NewUUID;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	IDAsString = Record.ID;
	
EndProcedure

#EndRegion