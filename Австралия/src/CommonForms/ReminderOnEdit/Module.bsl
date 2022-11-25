
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DontShowAgain = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SystemInfo = New SystemInfo;
	
	If StrFind(SystemInfo.UserAgentInformation, "Firefox") <> 0 Then
		Items.Additions.CurrentPage = Items.MozillaFireFox;
	Else
		Items.Additions.CurrentPage = Items.Empty;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ContinueExecute(Command)
	
	If DontShowAgain = True Then
		CommonServerCall.CommonSettingsStorageSave(
			"ApplicationSettings", "ShowTooltipsOnEditFiles", False,,, True);
	EndIf;
	
	Close(True);
	
EndProcedure

#EndRegion
