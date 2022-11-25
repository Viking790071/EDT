#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	OpenFormsToCopy = Parameters.OpenFormsToCopy;
	Items.ActiveUsersGroup.Visible    = Parameters.HasActiveUsersRecipients;
	Items.OpenFormsWithSettingsBeingCopiedGroup.Visible = ValueIsFilled(OpenFormsToCopy);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ActiveUserListClick(Item)
	
	StandardSubsystemsClient.OpenActiveUserList();
	
EndProcedure

&AtClient
Procedure OpenFormsURLProcessingMessage(Item, FormattedStringURL, StandardProcessing)
	ShowMessageBox(, OpenFormsToCopy);
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Copy(Command)
	
	If Parameters.Action <> "CopyAndClose" Then
		Close();
	EndIf;
	
	Result = New Structure("Action", Parameters.Action);
	Notify("CopySettingsToActiveUsers", Result);
	
EndProcedure

#EndRegion
