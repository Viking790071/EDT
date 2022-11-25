
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SetUpDynamicList();
	
	User = Users.CurrentUser();
	
	List.Parameters.SetParameterValue("BeingEditedBy", User);
	
	ShowSizeColumn = FilesOperationsInternalServerCall.GetShowSizeColumn();
	If ShowSizeColumn = False Then
		Items.ListCurrentVersionSize.Visible = False;
	EndIf;
	
	ApplicationShutdown = Undefined;
	If Parameters.Property("ApplicationShutdown", ApplicationShutdown) Then 
		Response = ApplicationShutdown;
		If Response = True Then
			Items.ShowLockedFilesOnExit.Visible = Response;
			Items.CommandBarGroup.Visible                     = Response;
		EndIf;
	EndIf;
	
	ShowLockedFilesOnExit = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", 
		"ShowLockedFilesOnExit", True);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	OnCloseAtServer();
	StandardSubsystemsClient.SetClientParameter(
		"LockedFilesCount", LockedFilesCount);
	
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	
	LockedFilesCount = FilesOperationsInternal.LockedFilesCount();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

// Processing the Choice event of the list.
//
&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Item.CurrentData.Ref, Undefined, UUID);
	FilesOperationsInternalClient.OpenFileWithNotification(Undefined, FileData);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("SetCommandsAvailability", 0.1, True);
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	FilesOperationsClient.OpenFileForm(CurrentData.Ref, True);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	Items.List.Refresh();
	
	AttachIdleHandler("SetCommandsAvailability", 0.1, True);
	
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID);
	FilesOperationsClient.OpenFile(FileData);
	
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	FilesOperationsClient.OpenFileForm(CurrentData.Ref, True);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(
		CurrentData.Ref, Undefined, UUID);
	FilesOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataAndWorkingDirectory(CurrentData.Ref);
	FilesOperationsInternalClient.UpdateFromFileOnHardDriveWithNotification(New NotifyDescription("UpdateEditedFilesList", ThisObject), FileData, UUID);
	
EndProcedure

&AtClient
Procedure Unlock(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileUnlockParameters = FilesOperationsInternalClient.FileUnlockParameters(
		New NotifyDescription("UpdateEditedFilesList", ThisObject), CurrentData.Ref);
	FileUnlockParameters.StoreVersions = CurrentData.StoreVersions;
	FileUnlockParameters.CurrentUserEditsFile = True;
	FileUnlockParameters.BeingEditedBy = CurrentData.BeingEditedBy;
	FilesOperationsInternalClient.UnlockFileWithNotification(FileUnlockParameters);
	Items.List.Refresh();
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FilesOperationsInternalClient.SaveFileChangesWithNotification(
		Undefined,
		CurrentData.Ref,
		UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(
		CurrentData.Ref, , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(
		New NotifyDescription("UpdateEditedFilesList", ThisObject), CurrentData.Ref, UUID);
	FileUpdateParameters.StoreVersions = CurrentData.StoreVersions;
	FileUpdateParameters.CurrentUserEditsFile = True;
	FileUpdateParameters.BeingEditedBy = CurrentData.BeingEditedBy;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	StructuresArray = New Array;
	StructuresArray.Add(SettingDescription(
		"ApplicationSettings",
		"ShowLockedFilesOnExit",
		ShowLockedFilesOnExit));
	
	CommonServerCall.CommonSettingsStorageSaveArray(StructuresArray, True);
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetCommandsAvailability()
	
	Enabled = Items.List.CurrentRow <> Undefined;
	
	Items.FormFinishEditing.Enabled = Enabled;
	Items.ListContextMenuFinishEditing.Enabled = Enabled;
	
	Items.FormOpenFile.Enabled = Enabled;
	Items.ListContextMenuOpen.Enabled = Enabled;
	
	Items.FormOpenFileProperties.Enabled = Enabled;
	
	Items.ListContextMenuSaveChanges.Enabled = Enabled;
	Items.ListContextMenuOpenFileDirectory.Enabled = Enabled;
	Items.ListContextMenuSaveAs.Enabled = Enabled;
	Items.ListContextMenuUnlock.Enabled = Enabled;
	Items.ListContextMenuUpdateFromFileOnDisk.Enabled = Enabled;
	
EndProcedure

&AtClient
Function SettingDescription(Object, Setting, Value)
	
	Item = New Structure;
	Item.Insert("Object", Object);
	Item.Insert("Settings", Setting);
	Item.Insert("Value", Value);
	
	Return Item;
	
EndFunction

&AtServer
Procedure SetUpDynamicList()
	
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT
		|	VALUETYPE(FilesInfo.File) AS FileType
		|FROM
		|	InformationRegister.FilesInfo AS FilesInfo
		|WHERE
		|	FilesInfo.BeingEditedBy = &BeingEditedBy";
	
	Query.SetParameter("BeingEditedBy", Users.CurrentUser());
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	TypesArray = QueryResult.Unload().UnloadColumn("FileType");
	SetPrivilegedMode(False);
	
	QueryText = "";
	For Each CatalogType In TypesArray Do
		CatalogMetadata = Metadata.FindByType(CatalogType);
		If Not AccessRight("Update", CatalogMetadata) Then
			Continue;
		EndIf;
		If Not StrEndsWith(CatalogMetadata.Name, "AttachedFilesVersions") AND CatalogMetadata.Name <> "FilesVersions" Then
			If Not IsBlankString(QueryText) Then
				QueryText = QueryText + "
				|
				|UNION ALL
				|
				|	SELECT";
			Else
				QueryText = QueryText + "
				|	SELECT ALLOWED";
			EndIf;
			
			QueryText = QueryText + "
			|	Files.BeingEditedBy,
			|	Files.PictureIndex,
			|	Files.Description,
			|	Files.Details,
			|	Files.Ref,
			|	Files.FileOwner,
			|	Files.StoreVersions AS StoreVersions,
			|	Files.Size / 1024
			|FROM
			|	" + CatalogMetadata.FullName() + " AS Files
			|WHERE
			|	Files.BeingEditedBy = &BeingEditedBy"
		EndIf;
	EndDo;
		
	If Not IsBlankString(QueryText) Then
		ListProperties = Common.DynamicListPropertiesStructure();
		ListProperties.QueryText                 = QueryText;
		ListProperties.DynamicDataRead = False;
		Common.SetDynamicListProperties(Items.List, ListProperties);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateEditedFilesList(Result, AdditionalParameters) Export
	Items.List.Refresh();
EndProcedure

#EndRegion
