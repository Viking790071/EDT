
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure AccessUpdateAtRecordLevel(Command)
	
	OpenForm("InformationRegister.DataAccessKeysUpdate.Form.AccessUpdateAtRecordLevel");
	
EndProcedure

#EndRegion
