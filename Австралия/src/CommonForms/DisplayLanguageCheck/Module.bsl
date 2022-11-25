
#Region FormCommandsEventHandlers

&AtClient
Procedure CommandOK(Command)
	
	If DoNotShowAgain Then
		DriveServer.SetUserSetting(True, "DoNotShowDisplayLanguageCheck");
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion