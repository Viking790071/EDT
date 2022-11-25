
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	List.Parameters.SetParameterValue(
		"CurrentUser", Users.CurrentUser());
	
	FilesOperationsInternalServerCall.FillConditionalAppearanceOfFilesList(List);
	
	OnChangeUseOfSigningOrEncryptionAtServer();
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormChange.Visible = False;
		Items.FormChange82.Visible = True;
	EndIf;
	
	URL = "e1cib/app/" + ThisObject.FormName;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_FileFolders" Then
		Items.List.Refresh();
	ElsIf EventName = "Write_File" Then
		Items.List.Refresh();
		If TypeOf(Parameter) = Type("Structure") AND Parameter.Property("File") Then
			Items.List.CurrentRow = Parameter.File;
		ElsIf Source <> Undefined Then
			Items.List.CurrentRow = Source;
		EndIf;
	ElsIf Upper(EventName) = Upper("Write_ConstantsSet")
	   AND (Upper(Source) = Upper("UseDigitalSignature")
		  Or Upper(Source) = Upper("UseEncryption")) Then
		AttachIdleHandler("SigningOrEncryptionUsageOnChange", 0.3, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Items.List.CurrentData.Ref, Undefined, UUID);
	FilesOperationsInternalClient.OpenFileWithNotification(Undefined, FileData);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	SetFileCommandsAvailability();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure View(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Items.List.CurrentData.Ref, Undefined, UUID);
	FilesOperationsClient.OpenFile(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(Items.List.CurrentData.Ref, , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure Unlock(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("UnlockCompletion", ThisObject);
	CurrentData = Items.List.CurrentData;
	FileUnlockParameters = FilesOperationsInternalClient.FileUnlockParameters(Handler, Items.List.CurrentData.Ref);
	FileUnlockParameters.StoreVersions = CurrentData.StoreVersions;	
	FileUnlockParameters.CurrentUserEditsFile = CurrentData.EditedByCurrentUser;
	FileUnlockParameters.BeingEditedBy = CurrentData.BeingEditedBy;	
	FilesOperationsInternalClient.UnlockFileWithNotification(FileUnlockParameters);
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure Update(Command)
	
	Items.List.Refresh();
	AttachIdleHandler("SetFileCommandsAvailability", 0.1, True);
	
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("AttachedFile", CurrentData.Ref);
	
	OpenForm("DataProcessor.FilesOperations.Form.AttachedFile", FormParameters);
	
EndProcedure

&AtClient
Procedure SetDeletionMark(Command)
	SetClearDeletionMark(Items.List.SelectedRows);
	Items.List.Refresh();
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	Cancel = True;
	SetClearDeletionMark(Items.List.SelectedRows);
	Items.List.Refresh();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UnlockCompletion(Result, ExecutionParameters) Export
	SetFileCommandsAvailability();
EndProcedure

// File commands are available. There is at least one row in the list and grouping is not selected.
&AtClient
Function FileCommandsAvailable()
	
	If Items.List.CurrentData = Undefined Then 
		Return False;
	EndIf;
	
	If TypeOf(Items.List.CurrentData.Ref) = Type("DynamicListGroupRow") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure SetFileCommandsAvailability()
	
	If Items.List.CurrentData <> Undefined Then
		
		If TypeOf(Items.List.CurrentData.Ref) <> Type("DynamicListGroupRow") Then
			
			SetCommandsAvailability(Items.List.CurrentData.EditedByCurrentUser,
				Items.List.CurrentData.BeingEditedBy);
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetClearDeletionMark(Val SelectedRows)
	
	If TypeOf(SelectedRows) = Type("Array") Then
		For each SelectedRow In SelectedRows Do
			File = SelectedRow.File.GetObject();
			File.SetDeletionMark(NOT File.DeletionMark);
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCommandsAvailability(EditedByCurrentUser, BeingEditedBy)
	
	Items.FormUnlock.Enabled = ValueIsFilled(BeingEditedBy);
	Items.ListContextMenuUnlock.Enabled = ValueIsFilled(BeingEditedBy);
	
EndProcedure

&AtClient
Procedure SigningOrEncryptionUsageOnChange()
	
	OnChangeUseOfSigningOrEncryptionAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeUseOfSigningOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject,, True);
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("AttachedFile", CurrentData.Ref);
	
	OpenForm("DataProcessor.FilesOperations.Form.AttachedFile", FormParameters);
	
EndProcedure

#EndRegion
