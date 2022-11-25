
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	ConditionalAppearance.Items.Clear();
	FilesOperationsInternalServerCall.FillConditionalAppearanceOfFilesList(List);
	FilesOperationsInternalServerCall.FillConditionalAppearanceOfFoldersList(Folders);
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Property("Folder") And Parameters.Folder <> Undefined Then
		InitialFolder = Parameters.Folder;
	Else
		InitialFolder = Common.FormDataSettingsStorageLoad("Files", "CurrentFolder");
		If InitialFolder = Undefined Then // An attempt to import settings, saved in the previous versions.
			InitialFolder = Common.FormDataSettingsStorageLoad("FileStorage", "CurrentFolder");
		EndIf;
	EndIf;
	
	If InitialFolder = Catalogs.FileFolders.EmptyRef() Or InitialFolder = Undefined Then
		InitialFolder = Catalogs.FileFolders.Templates;
	EndIf;
	
	If Parameters.Property("SendOptions") Then
		SendOptions = Parameters.SendOptions;
	Else
		SendOptions = FilesOperationsInternal.PrepareSendingParametersStructure();
	EndIf;
	
	Items.Folders.CurrentRow = InitialFolder;
	
	List.Parameters.SetParameterValue(
		"Owner", InitialFolder);
	List.Parameters.SetParameterValue(
		"CurrentUser", Users.CurrentUser());
		
	EmptyUsers = New Array;
	EmptyUsers.Add(Undefined);
	EmptyUsers.Add(Catalogs.Users.EmptyRef());
	EmptyUsers.Add(Catalogs.ExternalUsers.EmptyRef());
	EmptyUsers.Add(Catalogs.FileSynchronizationAccounts.EmptyRef());
	List.Parameters.SetParameterValue(
		"EmptyUsers",  EmptyUsers);
	
	ShowSizeColumn = FilesOperationsInternalServerCall.GetShowSizeColumn();
	If ShowSizeColumn = False Then
		Items.ListCurrentVersionSize.Visible = False;
	EndIf;
	
	UseHierarchy = True;
	SetHierarchy(UseHierarchy);
	
	OnChangeUseSignOrEncryptionAtServer();
	
	FillPropertyValues(ThisObject, FolderRightsSettings(Items.Folders.CurrentRow));
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormChange.Visible = False;
		Items.FormChange82.Visible = True;
	EndIf;
	
	UsePreview = Common.CommonSettingsStorageLoad(
		"Files",
		"Preview");
	
	If UsePreview <> Undefined Then
		Preview = UsePreview;
		Items.FileDataURL.Visible = UsePreview;
		Items.Preview.Check = UsePreview;
	EndIf;
	
	PreviewEnabledExtensions = FilesOperationsInternal.ExtensionsListForPreview();
	
	Items.CloudServiceNoteGroup.Visible = False;
	UseFileSync = GetFunctionalOption("UseFileSync");
	
	Items.FoldersContextMenuSyncSettings.Visible = AccessRight("Edit", Metadata.Catalogs.FileSynchronizationAccounts);
	Items.Compare.Visible = Not CommonClientServer.IsLinuxClient()
		And Not CommonClientServer.IsWebClient();
	
	UniversalDate = CurrentSessionDate();
	List.Parameters.SetParameterValue("SecondsToLocalTime",
		ToLocalTime(UniversalDate, SessionTimeZone()) - UniversalDate);
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "FormOpenFileDirectory", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "ListContextMenuOpenFileDirectory", "Visible", False);
		
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		
		IsExternalUser = True;
		
		Items.FormSubmenuCreate.Visible								 = False;
		Items.FormImportFiles.Visible								 = False;
		Items.FormFolderImport.Visible								 = False;
		Items.FormCreateFolder.Visible								 = False;
		Items.FormChange.Visible									 = False;
		Items.FormMoveToFolder.Visible								 = False;
		Items.FormLock.Visible										 = False;
		Items.FormEdit.Visible										 = False;
		Items.FormSaveChanges.Visible								 = False;
		Items.FormFinishEditing.Visible								 = False;
		Items.Send.Visible											 = False;
		Items.FormUnlock.Visible									 = False;
		Items.FormUpdateFromFileOnDisk.Visible						 = False;
		Items.FormOpenFileDirectory.Visible							 = False;
		Items.Compare.Visible										 = False;
		Items.FormCommandsGroup.Visible								 = False;
		Items.FormDigitalSignatureAndEncryptionCommandsGroup.Visible = False;
		Items.FormGlobalCommands.Visible							 = False;
		
		Items.ListSignedEncryptedPictureNumber.Visible	= False;
		Items.ListEditedBy.Visible						= False;
		Items.ListCurrentVersionSize.Visible			= False;
		Items.ListAuthor.Visible						= False;
		Items.ListCreationDate.Visible					= False;
		Items.ListEditing.Visible						= False;
		Items.ListRef.Visible							= False;
		
		Items.List.ContextMenu.Enabled	= False;
		For Each ChildItem In Items.List.ContextMenu.ChildItems Do
			ChildItem.Visible = False;
		EndDo;
		
		Items.List.ReadOnly = True;
		
		Items.FormSaveAs.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBarAndInAdditionalSubmenu;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.FormCreateFromScanner.Visible = FilesOperationsInternalClient.ScanCommandAvailable();
	
	SetFileCommandsAvailability();
	
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

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_ConstantsSet")
		And (Upper(Source) = Upper("UseDigitalSignature")
		Or Upper(Source) = Upper("UseEncryption")) Then
		
		AttachIdleHandler("OnChangeSignatureOrEncryptionUsage", 0.3, True);
		Return;
	ElsIf EventName = "Write_FileFolders" Then
		Items.Folders.Refresh();
		Items.List.Refresh();
		
		If Source <> Undefined Then
			Items.Folders.CurrentRow = Source;
		EndIf;
	ElsIf EventName = "Write_File" Then
		Items.List.Refresh();
		If TypeOf(Parameter) = Type("Structure") And Parameter.Property("File") Then
			Items.List.CurrentRow = Parameter.File;
		ElsIf Source <> Undefined Then
			Items.List.CurrentRow = Source;
		EndIf;
	EndIf;
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.FileFolders.Form.ChoiceForm") Then
		
		If SelectedValue = Undefined Then
			Return;
		EndIf;
		
		SelectedRows = Items.List.SelectedRows;
		FilesOperationsInternalClient.MoveFilesToFolder(SelectedRows, SelectedValue);
		
		For Each SelectedRow In SelectedRows Do
			Notify("Write_File", New Structure("Event", "FileDataChanged"), SelectedRow);
		EndDo;
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SetHierarchy(Settings["UseHierarchy"]);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationSynchronizationDateURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "OpenJournal" Then
		
		StandardProcessing = False;
		FilterParameters      = EventLogFilterData(Items.Folders.CurrentData.Account);
		EventLogClient.OpenEventLog(FilterParameters, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion


#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	If IsExternalUser Then
		OpenFileExecute();
		Return;
	EndIf;
	
	If TypeOf(RowSelected) = Type("DynamicListGroupRow") Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	HowToOpen = FilesOperationsInternalClientServer.PersonalFilesOperationsSettings().ActionOnDoubleClick;
	
	If HowToOpen = "OpenCard" Then
		ShowValue(, RowSelected);
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(RowSelected,
		Undefined, UUID, Undefined, FilePreviousURL);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	Handler = New NotifyDescription("ListSelectionAfterEditModeChoice", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.SelectModeAndEditFile(Handler, FileData, True);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	If Items.Folders.CurrentRow = Undefined Then
		Cancel = True;
		Return;
	EndIf; 
	
	If Items.Folders.CurrentRow.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf; 
	
	FileOwner = Items.Folders.CurrentRow;
	BasisFile = Items.List.CurrentRow;
	
	Cancel = True;
	
	If Clone Then
		FilesOperationsClient.CopyFileSSL(FileOwner, BasisFile);
	Else
		FilesOperationsInternalClient.AppendFile(Undefined, FileOwner, ThisObject, 2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	If FilesBeingEditedInCloudService Then
		DragParameters.Action = DragAction.Cancel;
		DragParameters.Value = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
	DragToFolder(Undefined, DragParameters.Value, DragParameters.Action);
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData <> Undefined Then
		URL = GetURL(Items.List.CurrentData.Ref);
	EndIf;
	IdleHandlerSetFileCommandsAccessibility();
	
EndProcedure

#EndRegion

#Region FolderFormTableItemsEventHandlers

&AtClient
Procedure FoldersOnActivateRow(Item)
	
	AttachIdleHandler("SetCommandsAvailabilityOnChangeFolder", 0.1, True);
	
	If UseFileSync Then
		AttachIdleHandler("SetFilesSynchronizationNoteVisibility", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure FoldersDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure FoldersDrag(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
	DragToFolder(Row, DragParameters.Value, DragParameters.Action);
EndProcedure

&AtClient
Procedure FoldersOnChange(Item)
	Items.List.Refresh();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportFilesExecute()
	
	Handler = New NotifyDescription("ImportFilesAfterExtensionInstalled", ThisObject);
	FilesOperationsInternalClient.ShowFileSystemExtensionInstallationQuestion(Handler);
	
EndProcedure

&AtClient
Procedure FolderImport(Command)
	
	Handler = New NotifyDescription("ImportFolderAfterExtensionInstalled", ThisObject);
	FilesOperationsInternalClient.ShowFileSystemExtensionInstallationQuestion(Handler);
	
EndProcedure

&AtClient
Procedure FolderExportExecute()
	
	FormParameters = New Structure;
	FormParameters.Insert("ExportFolder", Items.Folders.CurrentRow);
	
	Handler = New NotifyDescription("ExportFolderAfterInstallExtension", ThisObject, FormParameters);
	FilesOperationsInternalClient.ShowFileSystemExtensionInstallationQuestion(Handler);
	
EndProcedure

&AtClient
Procedure AppendFile(Command)
	
	FilesOperationsInternalClient.AddFileFromFileSystem(Items.Folders.CurrentRow, ThisObject);
	
EndProcedure

&AtClient
Procedure AppendFileByTemplate(Command)
	
	AddingOptions = New Structure;
	AddingOptions.Insert("ResultHandler",                    Undefined);
	AddingOptions.Insert("FileOwner",                           Items.Folders.CurrentRow);
	AddingOptions.Insert("OwnerForm",                           ThisObject);
	AddingOptions.Insert("DontOpenCardAfterCreateFromFIle", True);
	FilesOperationsInternalClient.AddBasedOnTemplate(AddingOptions);
	
EndProcedure

&AtClient
Procedure AppendFileFromScanner(Command)
	
	AddingOptions = New Structure;
	AddingOptions.Insert("ResultHandler", Undefined);
	AddingOptions.Insert("FileOwner", Items.Folders.CurrentRow);
	AddingOptions.Insert("OwnerForm", ThisObject);
	AddingOptions.Insert("DontOpenCardAfterCreateFromFIle", True);
	AddingOptions.Insert("IsFile", True);
	FilesOperationsInternalClient.AddFromScanner(AddingOptions);
	
EndProcedure

&AtClient
Procedure CreateFolderExecute()
	
	NewFolderParameters = New Structure("Parent", Items.Folders.CurrentRow);
	OpenForm("Catalog.FileFolders.ObjectForm", NewFolderParameters, Items.Folders);
	
EndProcedure

&AtClient
Procedure UseHierarchy(Command)
	
	UseHierarchy = Not UseHierarchy;
	If UseHierarchy And (Items.List.CurrentData <> Undefined) Then 
		
		If Items.List.CurrentData.Property("FileOwner") Then 
			Items.Folders.CurrentRow = Items.List.CurrentData.FileOwner;
		Else
			Items.Folders.CurrentRow = Undefined;
		EndIf;	
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;	
	SetHierarchy(UseHierarchy);
	
EndProcedure

&AtClient
Procedure OpenFileExecute()
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Items.List.CurrentRow, 
		Undefined, UUID, Undefined, FilePreviousURL);
	FilesOperationsClient.OpenFile(FileData, False);
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject);
	FilesOperationsInternalClient.EditWithNotification(Handler, Items.List.CurrentRow);
	
EndProcedure

&AtClient
Function FileCommandsAvailable()
	
	Return FilesOperationsInternalClient.FileCommandsAvailable(Items);
	
EndFunction

&AtClient
Procedure EndEdit(Command)
	
	FilesArray = New Array;
	For Each ListItem In Items.List.SelectedRows Do
		RowData = Items.List.RowData(ListItem);
		
		If Not RowData.FileBeingEdited
			OR Not RowData.CurrentUserEditsFile Then
			Continue;
		EndIf;
		FilesArray.Add(RowData.Ref);
	EndDo;
	
	If FilesArray.Count() > 1 Then
		FormParameters = New Structure;
		FormParameters.Insert("FilesArray",                     FilesArray);
		FormParameters.Insert("CanCreateFileVersions", True);
		FormParameters.Insert("BeingEditedBy",                      RowData.BeingEditedBy);
		
		OpenForm("DataProcessor.FilesOperations.Form.FormFinishEditing", FormParameters, ThisObject);
	ElsIf FilesArray.Count() = 1 Then
		Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject);
		FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, RowData.Ref, UUID);
		FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure Lock(Command)
	
	If Not FileCommandsAvailable() Then
		Return;
	EndIf;
	
	FilesCount = Items.List.SelectedRows.Count();
	
	If FilesCount = 1 Then
		Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject);
		FilesOperationsInternalClient.LockWithNotification(Handler, Items.List.CurrentRow);
	ElsIf FilesCount > 1 Then
		FilesArray = New Array;
		For Each ListItem In Items.List.SelectedRows Do
			RowData = Items.List.RowData(ListItem);
			
			If ValueIsFilled(RowData.BeingEditedBy) Then
				Continue;
			EndIf;
			FilesArray.Add(RowData.Ref);
		EndDo;
		Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject, FilesArray);
		FilesOperationsInternalClient.LockWithNotification(Handler, FilesArray);
	EndIf;
	
EndProcedure

&AtClient
Procedure Unlock(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FilesOperationsInternalClient.UnlockFiles(Items.List);
	SetFileCommandsAvailability();
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject);
	
	FilesOperationsInternalClient.SaveFileChangesWithNotification(
		Handler,
		Items.List.CurrentRow,
		UUID);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Items.List.CurrentRow,
		Undefined, UUID, Undefined, FilePreviousURL);
	FilesOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(
		Items.List.CurrentRow, , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataAndWorkingDirectory(Items.List.CurrentRow);
	FilesOperationsInternalClient.UpdateFromFileOnHardDriveWithNotification(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	Cancel = True;
	
	FormOpenParameters = New Structure("Key, SendOptions", Item.CurrentRow, SendOptions);
	OpenForm("Catalog.Files.ObjectForm", FormOpenParameters);
	
EndProcedure

&AtClient
Procedure MoveToFolder(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Title",    NStr("ru = 'Выбор папки'; en = 'Choosing a folder'; pl = 'Wybór folderu';es_ES = 'Selección de carpeta';es_CO = 'Selección de carpeta';tr = 'Klasör seçimi';it = 'Scegliendo una cartella';de = 'Ordnerauswahl'"));
	FormParameters.Insert("CurrentFolder", Items.Folders.CurrentRow);
	FormParameters.Insert("ChoiceMode",  True);
	
	OpenForm("Catalog.FileFolders.ChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure Sign(Command)
	
	NotifyDescription      = New NotifyDescription("SignCompletion", ThisObject);
	AdditionalParameters = New Structure("ResultProcessing", NotifyDescription);
	FilesOperationsClient.SignFile(Items.List.CurrentRow, UUID, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	ObjectRef = Items.List.CurrentRow;
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(ObjectRef);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	Handler = New NotifyDescription("EncryptAfterEncryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Encrypt(Handler, FileData, UUID);
	
EndProcedure

&AtClient
Procedure Decrypt(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	ObjectRef = Items.List.CurrentRow;
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(ObjectRef);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData", FileData);
	HandlerParameters.Insert("ObjectRef", ObjectRef);
	Handler = New NotifyDescription("DecryptAfterDecryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Decrypt(
		Handler,
		FileData.Ref,
		UUID,
		FileData);
	
EndProcedure

&AtClient
Procedure AddSignatureFromFile(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FilesOperationsInternalClient.AddSignatureFromFile(
		Items.List.CurrentRow,
		UUID,
		New NotifyDescription("SetFileCommandsAvailability", ThisObject));
	
EndProcedure

&AtClient
Procedure SaveWithSignature(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FilesOperationsInternalClient.SaveFileWithSignature(
		Items.List.CurrentRow, UUID);
	
EndProcedure

&AtClient
Procedure Update(Command)
	
	Items.Folders.Refresh();
	Items.List.Refresh();
	
	AttachIdleHandler("SetCommandsAvailabilityOnChangeFolder", 0.1, True);
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	OnSendFilesViaEmail(SendOptions, Items.List.SelectedRows, Items.Folders.CurrentData.Ref , UUID);
	
	FilesOperationsInternalClient.SendFilesViaEmail(
		Items.List.SelectedRows, UUID, SendOptions, True);
	
EndProcedure

&AtClient
Procedure PrintFiles(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	SystemInfo = New SystemInfo;
	If SystemInfo.PlatformType <> PlatformType.Windows_x86 
	   And SystemInfo.PlatformType <> PlatformType.Windows_x86_64 Then
		ShowMessageBox(, NStr("ru = 'Печать файлов возможна только в Windows.'; en = 'Printing files is available only in Windows.'; pl = 'Drukowanie plików jest możliwe tylko w Windows.';es_ES = 'Es posible imprimir los archivos solo en Windows.';es_CO = 'Es posible imprimir los archivos solo en Windows.';tr = 'Dosya yalnızca Windows''ta yazdırılabilir.';it = 'Il file di stampa sono disponibili solo in Windows.';de = 'Dateien können nur unter Windows gedruckt werden.'"));
		Return;
	EndIf;
	
	SelectedRows = Items.List.SelectedRows;
	If SelectedRows.Count() > 0 Then
		FilesOperationsClient.PrintFiles(SelectedRows, ThisObject.UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure Preview(Command)
	
	Preview = Not Preview;
	Items.Preview.Check = Preview;
	SetPreviewVisibility(Preview);
	SavePreviewOption("Files", Preview);
	
	#If WebClient Then
	UpdatePreview();
	#EndIf
	
EndProcedure

&AtClient
Procedure SyncSettings(Command)
	
	SyncSetup = SynchronizationSettingsParameters(Items.Folders.CurrentData.Ref);
	
	If ValueIsFilled(SyncSetup.Account) Then
		ValueType = Type("InformationRegisterRecordKey.FileSynchronizationSettings");
		WriteParameters = New Array(1);
		WriteParameters[0] = SyncSetup;
		
		RecordKey = New(ValueType, WriteParameters);
	
		WriteParameters = New Structure;
		WriteParameters.Insert("Key", RecordKey);
	Else
		SyncSetup.Insert("IsFile", True);
		WriteParameters = SyncSetup;
	EndIf;
	
	OpenForm("InformationRegister.FileSynchronizationSettings.Form.SimpleRecordFormSettings", WriteParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure Compare(Command)
	SelectedRowsCount = Items.List.SelectedRows.Count();
	
	If SelectedRowsCount = 2 OR SelectedRowsCount = 1 Then
		If SelectedRowsCount = 2 Then
			Ref1 = Items.List.SelectedRows[0];
			Ref2 = Items.List.SelectedRows[1];
		ElsIf SelectedRowsCount = 1 Then
			Ref1 = Items.List.CurrentData.Ref;
			Ref2 = Items.List.CurrentData.ParentVersion;
		EndIf;
		
		Extension = Lower(Items.List.CurrentData.Extension);
		
		FilesOperationsInternalClient.CompareFiles(UUID, Ref1, Ref2, Extension);
		
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ImportFilesAfterExtensionInstalled(Result, ExecutionParameters) Export
	If Not Result Then
		FilesOperationsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	OpenFileDialog = New FileDialog(FileDialogMode.Open);
	OpenFileDialog.FullFileName = "";
	OpenFileDialog.Filter = NStr("ru = 'Все файлы(*.*)|*.*'; en = 'All files (*.*)|*.*'; pl = 'Wszystkie pliki(*.*)|*.*';es_ES = 'Todos archivos (*.*)|*.*';es_CO = 'Todos archivos (*.*)|*.*';tr = 'Tüm dosyalar (*.*)|*.*';it = 'Tutti i file (*.*) | *.*';de = 'Alle Dateien (*.*)|*.*'");
	OpenFileDialog.Multiselect = True;
	OpenFileDialog.Title = NStr("ru = 'Выберите файлы'; en = 'Select files'; pl = 'Wybrać pliki';es_ES = 'Seleccionar archivos';es_CO = 'Seleccionar archivos';tr = 'Dosyaları seçin';it = 'Selezionare file';de = 'Dateien wählen'");
	If Not OpenFileDialog.Choose() Then
		Return;
	EndIf;
	
	FileNamesArray = New Array;
	For Each FileName In OpenFileDialog.SelectedFiles Do
		FileNamesArray.Add(FileName);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding", Items.Folders.CurrentRow);
	FormParameters.Insert("FileNamesArray",   FileNamesArray);
	
	OpenForm("DataProcessor.FilesOperations.Form.FilesImportForm", FormParameters);
EndProcedure

&AtClient
Procedure ImportFolderAfterExtensionInstalled(Result, ExecutionParameters) Export
	
	If Not Result Then
		FilesOperationsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	OpenFileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	OpenFileDialog.FullFileName = "";
	OpenFileDialog.Filter = NStr("ru = 'Все файлы(*.*)|*.*'; en = 'All files (*.*)|*.*'; pl = 'Wszystkie pliki(*.*)|*.*';es_ES = 'Todos archivos (*.*)|*.*';es_CO = 'Todos archivos (*.*)|*.*';tr = 'Tüm dosyalar (*.*)|*.*';it = 'Tutti i file (*.*) | *.*';de = 'Alle Dateien (*.*)|*.*'");
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("ru = 'Выберите каталог'; en = 'Select directory'; pl = 'Wybierz folder';es_ES = 'Seleccionar el directorio';es_CO = 'Seleccionar el directorio';tr = 'Dizini seçin';it = 'Selezionare la directory';de = 'Wählen Sie das Verzeichnis aus'");
	If Not OpenFileDialog.Choose() Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding", Items.Folders.CurrentRow);
	FormParameters.Insert("DirectoryOnHardDrive",     OpenFileDialog.Directory);
	
	OpenForm("DataProcessor.FilesOperations.Form.FolderImportForm", FormParameters);

EndProcedure

&AtClient
Procedure ExportFolderAfterInstallExtension(Result, FormParameters) Export
	
	If Not Result Then
		FilesOperationsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	OpenForm("DataProcessor.FilesOperations.Form.ExportFolderForm", FormParameters);
	
EndProcedure

&AtClient
Procedure DragToFolder(FolderForAdding, DragValue, Action)
	If FolderForAdding = Undefined Then
		FolderForAdding = Items.Folders.CurrentRow;
		If FolderForAdding = Undefined Then
			Return;
		EndIf;
	EndIf;
	
	ValueType = TypeOf(DragValue);
	If ValueType = Type("File") Then
		If FolderForAdding.IsEmpty() Then
			Return;
		EndIf;
		If DragValue.IsFile() Then
			AddingOptions = New Structure;
			AddingOptions.Insert("ResultHandler", Undefined);
			AddingOptions.Insert("FullFileName", DragValue.FullName);
			AddingOptions.Insert("FileOwner", FolderForAdding);
			AddingOptions.Insert("OwnerForm", ThisObject);
			AddingOptions.Insert("NameOfFileToCreate", Undefined);
			AddingOptions.Insert("DontOpenCardAfterCreateFromFIle", True);
			FilesOperationsInternalClient.AddFormFileSystemWithExtension(AddingOptions);
		Else
			FileNamesArray = New Array;
			FileNamesArray.Add(DragValue.FullName);
			FilesOperationsInternalClient.OpenDragFormFromOutside(FolderForAdding, FileNamesArray);
		EndIf;
	ElsIf TypeOf(DragValue) = Type("Array") Then
		FolderIndex = DragValue.Find(FolderForAdding);
		If FolderIndex <> Undefined Then
			DragValue.Delete(FolderIndex);
		EndIf;
		
		If DragValue.Count() = 0 Then
			Return;
		EndIf;
		
		ValueType = TypeOf(DragValue[0]);
		If ValueType = Type("File") Then
			If FolderForAdding.IsEmpty() Then
				Return;
			EndIf;
			
			FileNamesArray = New Array;
			For Each ReceivedFile In DragValue Do
				FileNamesArray.Add(ReceivedFile.FullName);
			EndDo;
			FilesOperationsInternalClient.OpenDragFormFromOutside(FolderForAdding, FileNamesArray);
			
		ElsIf ValueType = Type("CatalogRef.Files") Then
			If FolderForAdding.IsEmpty() Then
				Return;
			EndIf;
			If Action = DragAction.Copy Then
				
				FilesOperationsInternalServerCall.CopyFiles(
					DragValue,
					FolderForAdding);
				
				Items.Folders.Refresh();
				Items.List.Refresh();
				
				If DragValue.Count() = 1 Then
					NotificationTitle = NStr("ru = 'Файл скопирован.'; en = 'File is copied.'; pl = 'Plik został skopiowany.';es_ES = 'Archivo se ha copiado.';es_CO = 'Archivo se ha copiado.';tr = 'Dosya kopyalandı.';it = 'File viene copiato.';de = 'Die Datei wird kopiert.'");
					NotificationText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Файл ""%1""
						           |скопирован в папку ""%2""'; 
						           |en = 'File ""%1"" 
						           |was copied into folder ""%2""'; 
						           |pl = 'Plik ""%1""
						           |został skopiowany do folderu ""%2""';
						           |es_ES = 'El archivo ""%1""
						           |ha sido copiado en la carpeta ""%2""';
						           |es_CO = 'El archivo ""%1""
						           |ha sido copiado en la carpeta ""%2""';
						           |tr = '""%1""
						           |dosya ""%2"" klasöre kopyalandı';
						           |it = 'Il file ""%1""
						           |è stato copiato nella cartella ""%2""';
						           |de = 'Datei ""%1""
						           |in den Ordner ""%2"" kopiert'"),
						DragValue[0],
						String(FolderForAdding));
				Else
					NotificationTitle = NStr("ru = 'Файлы скопированы.'; en = 'Files are copied.'; pl = 'Pliki zostały skopiowane.';es_ES = 'Archivos se han copiado.';es_CO = 'Archivos se han copiado.';tr = 'Dosyalar kopyalandı.';it = 'I file vengono copiati.';de = 'Dateien werden kopiert.'");
					NotificationText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Файлы (%1 шт.) скопированы в папку ""%2""'; en = 'Files (%1 pcs) were copied into folder ""%2""'; pl = 'Pliki (%1 szt.) zostały skopiowane do folderu ""%2""';es_ES = 'Archivos (%1 pcs) se han copiado en la carpeta ""%2""';es_CO = 'Archivos (%1 pcs) se han copiado en la carpeta ""%2""';tr = 'Dosyalar (%1 adet) ""%2"" klasörüne kopyalandı';it = 'File (%1 unita) vengono copiati nella cartella ""%2""';de = 'Dateien (%1 Stk.) wurden in den Ordner %2"" kopiert'"),
						DragValue.Count(),
						String(FolderForAdding));
				EndIf;
				ShowUserNotification(NotificationTitle, , NotificationText, PictureLib.Information32);
			Else
				
				OwnerIsSet = FilesOperationsInternalServerCall.SetFileOwner(DragValue, FolderForAdding);
				If OwnerIsSet <> True Then
					Return;
				EndIf;
				
				Items.Folders.Refresh();
				Items.List.Refresh();
				
				If DragValue.Count() = 1 Then
					NotificationTitle = NStr("ru = 'Файл перенесен.'; en = 'File has been moved'; pl = 'Plik został przeniesiony';es_ES = 'Archivo se ha movido.';es_CO = 'Archivo se ha movido.';tr = 'Dosya taşındı';it = 'Il file è stato spostato.';de = 'Die Datei wurde verschoben.'");
					NotificationText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Файл ""%1""
						           |перенесен в папку ""%2""'; 
						           |en = 'File ""%1"" 
						           |was moved into folder ""%2""'; 
						           |pl = 'Plik ""%1""
						           |został przeniesiony do folderu ""%2""';
						           |es_ES = 'El archivo ""%1""
						           |ha sido movido en la carpeta ""%2""';
						           |es_CO = 'El archivo ""%1""
						           |ha sido movido en la carpeta ""%2""';
						           |tr = '""%1""
						           |dosya ""%2"" klasöre taşındı';
						           |it = 'Il file ""%1"" 
						           |è stato spostato nella cartella ""%2""';
						           |de = 'Die Datei ""%1""
						           |wurde in den Ordner ""%2"" verschoben.'"),
						String(DragValue[0]),
						String(FolderForAdding));
				Else
					NotificationTitle = NStr("ru = 'Файлы перенесены.'; en = 'Files have been moved.'; pl = 'Pliki zostały przeniesione';es_ES = 'Archivos se han movido.';es_CO = 'Archivos se han movido.';tr = 'Dosyalar taşındı.';it = 'I file sono stati spostati.';de = 'Dateien werden verschoben.'");
					NotificationText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Файлы (%1 шт.) перенесены в папку ""%2""'; en = 'Files (%1 pcs) were moved into folder ""%2""'; pl = 'Pliki (%1 szt.) zostały przeniesione do folderu ""%2""';es_ES = 'Archivos (%1 pcs) se han movido a la carpeta ""%2""';es_CO = 'Archivos (%1 pcs) se han movido a la carpeta ""%2""';tr = 'Dosyalar (%1 adet) ""%2"" klasörüne taşındı';it = 'File (%1 unita) vengono trasferiti nella cartella ""%2""';de = 'Dateien (%1 Stk.) wurden in den Ordner ""%2"" verschoben'"),
						String(DragValue.Count()),
						String(FolderForAdding));
				EndIf;
				ShowUserNotification(NotificationTitle, , NotificationText, PictureLib.Information32);
			EndIf;
			
		ElsIf ValueType = Type("CatalogRef.FileFolders") Then
			LoopFound = False;
			ParentChanged = FilesOperationsInternalServerCall.ChangeFoldersParent(DragValue, FolderForAdding, LoopFound);
			If ParentChanged <> True Then
				If LoopFound = True Then
					If DragValue.Count() = 1 Then
						MessageText = NStr("ru = 'Перемещение невозможно.
							|Папка ""%1"" является дочерней для перемещаемой папки ""%2"".'; 
							|en = 'Cannot transfer.
							|The ""%1"" folder is subordinate for the ""%2"" folder you want to transfer.'; 
							|pl = 'Przemieszczenie nie jest możliwe.
							|Folder ""%1"" jest podrzędny w stosunku do przemieszczanego folderu ""%2"".';
							|es_ES = 'Es imposible mover.
							|La carpeta ""%1"" es subordinada para la carpeta movida ""%2"".';
							|es_CO = 'Es imposible mover.
							|La carpeta ""%1"" es subordinada para la carpeta movida ""%2"".';
							|tr = 'Taşınamaz.
							|Klasör ""%1"" taşınan ""%2"" klasörün alt klasörüdür.';
							|it = 'Impossibile trasferire.
							|La cartella ""%1"" è subordinata per la cartella ""%2"" che si vuole trasferire.';
							|de = 'Eine Verschiebung ist unmöglich.
							|Der Ordner ""%1"" ist ein Unterordner für den zu verschiebenden Ordner ""%2"".'");
					Else
						MessageText = NStr("ru = 'Перемещение невозможно.
							|Папка ""%1"" является дочерней для одной из перемещаемых папок.'; 
							|en = 'Cannot transfer.
							|The ""%1"" folder is subordinate for one of the transferred folders.'; 
							|pl = 'Przemieszczenie nie jest możliwe.
							|Folder ""%1"" jest podrzędny w stosunku do jednego z przemieszczanych folderów.';
							|es_ES = 'Es imposible mover.
							|La carpeta ""%1"" es subordinada para una de las carpetas movidas.';
							|es_CO = 'Es imposible mover.
							|La carpeta ""%1"" es subordinada para una de las carpetas movidas.';
							|tr = 'Taşınamaz.
							|Klasör ""%1"" taşınan klasörlerden birinin alt klasörüdür.';
							|it = 'Trasferimento impossibile.
							|La cartella ""%1"" è subordinata per una delle cartelle trasferite.';
							|de = 'Eine Bewegung ist unmöglich.
							|Der Ordner ""%1"" ist ein Unterordner für einen der zu verschiebenden Ordner.'");
					EndIf;
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, FolderForAdding, DragValue[0]);
					ShowMessageBox(, MessageText);
				EndIf;
				Return;
			EndIf;
			
			Items.Folders.Refresh();
			Items.List.Refresh();
			
			If DragValue.Count() = 1 Then
				Items.Folders.CurrentRow = DragValue[0];
				NotificationTitle = NStr("ru = 'Папка перенесена.'; en = 'Folder has been moved.'; pl = 'Folder został przeniesiony';es_ES = 'Carpeta se ha movido.';es_CO = 'Carpeta se ha movido.';tr = 'Klasör taşındı.';it = 'La cartella è stata spostata.';de = 'Der Ordner wurde verschoben.'");
				NotificationText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Папка ""%1""
					           |перенесена в папку ""%2""'; 
					           |en = 'Folder ""%1""
					           |is moved to folder ""%2""'; 
					           |pl = 'Folder ""%1""
					           |został przeniesiony do folderu ""%2""';
					           |es_ES = 'La carpeta ""%1""
					           |ha sido movida en la carpeta ""%2""';
					           |es_CO = 'La carpeta ""%1""
					           |ha sido movida en la carpeta ""%2""';
					           |tr = '""%1""
					           |klasör ""%2"" klasöre taşındı';
					           |it = 'La cartella ""%1""
					           |è stata trasferita nella cartella ""%2""';
					           |de = 'Der Ordner ""%1""
					           |wurde in den Ordner ""%2"" verschoben'"),
					String(DragValue[0]),
					String(FolderForAdding));
			Else
				NotificationTitle = NStr("ru = 'Папки перенесены.'; en = 'Folders have been moved.'; pl = 'Foldery zostały przeniesione';es_ES = 'Carpetas se han movido.';es_CO = 'Carpetas se han movido.';tr = 'Klasörler taşındı.';it = 'Le cartelle sono state spostate.';de = 'Ordner werden verschoben.'");
				NotificationText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Папки (%1 шт.) перенесены в папку ""%2""'; en = 'Folders (%1 pcs.)  moved to folder ""%2""'; pl = 'Foldery (%1 szt.) zostały przeniesione do folderu ""%2""';es_ES = 'Carpetas (%1 pcs.) se han movido a la carpeta ""%2""';es_CO = 'Carpetas (%1 pcs.) se han movido a la carpeta ""%2""';tr = 'Klasörler (%1 adet) ""%2"" klasörüne taşındı';it = 'Cartelle (%1 pz) spostate nella cartella ""%2""';de = 'Die Ordner (%1 Stk.) werden in den Ordner ""%2"" verschoben'"),
					String(DragValue.Count()),
					String(FolderForAdding));
			EndIf;
			ShowUserNotification(NotificationTitle, , NotificationText, PictureLib.Information32);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure EncryptAfterEncryptAtClient(Result, ExecutionParameters) Export
	If Not Result.Success Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FilesOperationsInternalClient.UserWorkingDirectory();
	
	FilesArrayInWorkingDirectoryToDelete = New Array;
	
	EncryptServer(
		Result.DataArrayToStoreInDatabase,
		Result.ThumbprintsArray,
		FilesArrayInWorkingDirectoryToDelete,
		WorkingDirectoryName,
		ExecutionParameters.ObjectRef);
	
	FilesOperationsInternalClient.InformOfEncryption(
		FilesArrayInWorkingDirectoryToDelete,
		ExecutionParameters.FileData.Owner,
		ExecutionParameters.ObjectRef);
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtServer
Procedure EncryptServer(DataArrayToStoreInDatabase, ThumbprintsArray, 
	FilesArrayInWorkingDirectoryToDelete,
	WorkingDirectoryName, ObjectRef)
	
	Encrypt = True;
	FilesOperationsInternal.WriteEncryptionInformation(
		ObjectRef,
		Encrypt,
		DataArrayToStoreInDatabase,
		Undefined,  // UUID
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryToDelete,
		ThumbprintsArray);
	
EndProcedure

&AtClient
Procedure DecryptAfterDecryptAtClient(Result, ExecutionParameters) Export
	
	If Result = False Or Not Result.Success Then
		Return;
	EndIf;
	
	WorkingDirectoryName = FilesOperationsInternalClient.UserWorkingDirectory();
	
	DecryptServer(
		Result.DataArrayToStoreInDatabase,
		WorkingDirectoryName,
		ExecutionParameters.ObjectRef);
	
	FilesOperationsInternalClient.InformOfDecryption(
		ExecutionParameters.FileData.Owner,
		ExecutionParameters.ObjectRef);
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtServer
Procedure DecryptServer(DataArrayToStoreInDatabase, 
	WorkingDirectoryName, ObjectRef)
	
	Encrypt = False;
	ThumbprintsArray = New Array;
	FilesArrayInWorkingDirectoryToDelete = New Array;
	
	FilesOperationsInternal.WriteEncryptionInformation(
		ObjectRef,
		Encrypt,
		DataArrayToStoreInDatabase,
		Undefined,  // UUID
		WorkingDirectoryName,
		FilesArrayInWorkingDirectoryToDelete,
		ThumbprintsArray);
	
EndProcedure

&AtClient
Procedure SignCompletion(Result, ExecutionParameters) Export
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtClient
Procedure SetCommandsAvailabilityOnChangeFolder()
	
	If Items.Folders.CurrentRow <> CurrentFolder Then
		CurrentFolder = Items.Folders.CurrentRow;
		FillPropertyValues(ThisObject, FolderRightsSettings(Items.Folders.CurrentRow));
		Items.FormCreateFolder.Enabled = FoldersModification;
		
		If Items.Find("FoldersContextMenuCreate") <> Undefined Then
			Items.FoldersContextMenuCreate.Enabled = FoldersModification;
		EndIf;
		If Items.Find("FoldersContextMenuCopy") <> Undefined Then
			Items.FoldersContextMenuCopy.Enabled = FoldersModification;
		EndIf;
		If Items.Find("FoldersContextMenuMarkForDeletion") <> Undefined Then
			Items.FoldersContextMenuMarkForDeletion.Enabled = FoldersModification;
		EndIf;
		If Items.Find("FoldersContextMenuMoveItem") <> Undefined Then
			Items.FoldersContextMenuMoveItem.Enabled = FoldersModification;
		EndIf;
		
	EndIf;
	
	If Items.Folders.CurrentRow = Undefined Or Items.Folders.CurrentRow.IsEmpty() Then
		
		Items.FormSubmenuCreate.Enabled = False;
		
		Items.FormCreateFromFile.Enabled = False;
		Items.FormCreateFromTemplate.Enabled = False;
		Items.FormCreateFromScanner.Enabled = False;
		
		If Items.Find("FormCopy") <> Undefined Then
			Items.FormCopy.Enabled = False;
		EndIf;
		
		If Items.Find("ListContextMenuCopy") <> Undefined Then
			Items.ListContextMenuCopy.Enabled = False;
		EndIf;
		
		If Items.Find("FormMarkForDeletion") <> Undefined Then
			Items.FormMarkForDeletion.Enabled = False;
		EndIf;
		
		If Items.Find("ListContextMenuMarkForDeletion") <> Undefined Then
			Items.ListContextMenuMarkForDeletion.Enabled = False;
		EndIf;
		
		If Items.Find("ListContextMenuCreate") <> Undefined Then
			Items.ListContextMenuCreate.Enabled = False;
		EndIf;
		
		If Items.Find("FormImportFiles") <> Undefined Then
			Items.FormImportFiles.Enabled = False;
		EndIf;
		
		If Items.Find("ListContextMenuImportFiles") <> Undefined Then
			Items.ListContextMenuImportFiles.Enabled = False;
		EndIf;
		
		Items.FoldersContextMenuFolderImport.Enabled = False;
		
	Else
		Items.FormSubmenuCreate.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		Items.FormCreateFromFile.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		Items.FormCreateFromTemplate.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		Items.FormCreateFromScanner.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		If Items.Find("ListContextMenuCreate") <> Undefined Then
			Items.ListContextMenuCreate.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		EndIf;
		If Items.Find("FormCreateFolder") <> Undefined Then
			Items.FormCreateFolder.Enabled = Not FilesBeingEditedInCloudService;
		EndIf;
		If Items.Find("FormFolderImport") <> Undefined Then
			Items.FormFolderImport.Enabled = Not FilesBeingEditedInCloudService;
		EndIf;
		If Items.Find("FormMoveToFolder") <> Undefined Then
			Items.FormMoveToFolder.Enabled = Not FilesBeingEditedInCloudService;
		EndIf;
		
		Items.FormUnlock.Enabled = Not FilesBeingEditedInCloudService;
		Items.ListContextMenuMoveToFolder.Enabled = Not FilesBeingEditedInCloudService;
		Items.ListContextMenuUnlock.Enabled = Not FilesBeingEditedInCloudService;
		
		If Items.Find("FormCopy") <> Undefined Then
			Items.FormCopy.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		EndIf;
	
		If Items.Find("ListContextMenuMarkForDeletion") <> Undefined Then
			Items.ListContextMenuMarkForDeletion.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		EndIf;
		If Items.Find("FormMarkForDeletion") <> Undefined Then
			Items.FormMarkForDeletion.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		EndIf;
		
		If Items.Find("FormCopy") <> Undefined Then
			Items.FormCopy.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		EndIf;
		
		If Items.Find("ListContextMenuCopy") <> Undefined Then
			Items.ListContextMenuCopy.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		EndIf;
		
		If Items.Find("FormMarkForDeletion") <> Undefined Then
			Items.FormMarkForDeletion.Enabled = FilesDeletionMark And Not FilesBeingEditedInCloudService;
		EndIf;
		If Items.Find("ListContextMenuMarkForDeletion") <> Undefined Then
			Items.ListContextMenuMarkForDeletion.Enabled = FilesDeletionMark And Not FilesBeingEditedInCloudService;
		EndIf;
		
		If Items.Find("FormImportFiles") <> Undefined Then
		Items.FormImportFiles.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		EndIf;
		If Items.Find("ListContextMenuImportFiles") <> Undefined Then
		Items.ListContextMenuImportFiles.Enabled = AddFiles  And Not FilesBeingEditedInCloudService;
		EndIf;
		
		If Items.Find("FoldersContextMenuFolderImport") <> Undefined Then
		Items.FoldersContextMenuFolderImport.Enabled = AddFiles And Not FilesBeingEditedInCloudService;
		EndIf;
	EndIf;
	
	If Items.Folders.CurrentRow <> Undefined Then
		AttachIdleHandler("FolderIdleHandlerOnActivateRow", 0.2, True);
	EndIf; 
	
EndProcedure

&AtClient
Procedure SetFilesSynchronizationNoteVisibility()
	
	FilesBeingEditedInCloudService = False;
	
	If Items.Folders.CurrentRow = Undefined Or Items.Folders.CurrentRow.IsEmpty() Then
		
		Items.CloudServiceNoteGroup.Visible = False;
		
	Else
		
		Items.CloudServiceNoteGroup.Visible = Items.Folders.CurrentData.FolderSynchronizationEnabled;
		FilesBeingEditedInCloudService = Items.Folders.CurrentData.FolderSynchronizationEnabled;
		
		If Items.Folders.CurrentData.FolderSynchronizationEnabled Then
			
			FolderAddressInCloudService = FilesOperationsInternalClientServer.AddressInCloudService(
				Items.Folders.CurrentData.AccountService, Items.Folders.CurrentData.Href);
				
			StringParts = New Array;
			StringParts.Add(NStr("ru = 'Работа с файлами этой папки ведется в облачном сервисе'; en = 'Operations with files of this folder are carried out in cloud service'; pl = 'Praca z plikami tego folderu jest prowadzona w serwisie w chmurze';es_ES = 'Operaciones con archivos de esta carpeta se realizan en el servicio de nube';es_CO = 'Operaciones con archivos de esta carpeta se realizan en el servicio de nube';tr = 'Bu klasörün dosya yönetimi bulut hizmetinde gerçekleştirilir.';it = 'Le operazioni con file di questa cartella sono fatte in servizio cloud';de = 'Dateien in diesem Ordner werden im Cloud-Service bearbeitet'"));
			StringParts.Add(" ");
			StringParts.Add(New FormattedString(Items.Folders.CurrentData.AccountDescription, , , , FolderAddressInCloudService));
			StringParts.Add(".  ");
			Items.NoteDecoration.Title = New FormattedString(StringParts);
			
			SynchronizationInfo = SynchronizationInfo(Items.Folders.CurrentData.Ref);
			If ValueIsFilled(SynchronizationInfo) Then
				Items.DecorationPictureSyncSettings.Visible  = Not SynchronizationInfo.Synchronized;
				Items.DecorationSyncDate.ToolTipRepresentation = ?(SynchronizationInfo.Synchronized, ToolTipRepresentation.None, ToolTipRepresentation.Button);
				Items.DecorationSyncDate.Visible            = True;
				
				StringParts.Clear();
				StringParts.Add(NStr("ru = 'Синхронизировано'; en = 'Synchronized'; pl = 'Synchronizuje się';es_ES = 'Se está sincronizando';es_CO = 'Se está sincronizando';tr = 'Senkronize edildi';it = 'Sincronizzato';de = 'Synchronisiert'"));
				StringParts.Add(": ");
				StringParts.Add(New FormattedString(Format(SynchronizationInfo.SynchronizationDate, "DLF=DD"),,,, "OpenJournal"));
				Items.DecorationSyncDate.Title = New FormattedString(StringParts);
			Else
				
				Items.DecorationPictureSyncSettings.Visible  = False;
				Items.DecorationSyncDate.ToolTipRepresentation = ToolTipRepresentation.None;
				Items.DecorationSyncDate.Visible            = False;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SynchronizationInfo(FileOwner)
	
	Return FilesOperationsInternal.SynchronizationInfo(FileOwner);
	
EndFunction

&AtClient
Procedure FolderIdleHandlerOnActivateRow()
	
	If Items.Folders.CurrentRow <> List.Parameters.Items.Find("Owner").Value Then
		// The right list and command availability by right settings are being updated.
		// The procedure of calling the OnActivateRow handler of the List table is performed by the platform.
		UpdateAndSaveFilesListParameters();
	Else
		// The procedure of calling the OnActivateRow handler of the List table is performed by the application.
		IdleHandlerSetFileCommandsAccessibility();
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FolderRightsSettings(Folder)
	
	RightsSettings = New Structure;
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Value = ValueIsFilled(Folder);
		RightsSettings.Insert("FoldersModification", True);
		RightsSettings.Insert("FilesModification", Value);
		RightsSettings.Insert("AddFiles", Value);
		RightsSettings.Insert("FilesDeletionMark", Value);
		Return RightsSettings;
	EndIf;
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	
	RightsSettings.Insert("FoldersModification",
		ModuleAccessManagement.HasRight("FoldersModification", Folder));
	
	RightsSettings.Insert("FilesModification",
		ModuleAccessManagement.HasRight("FilesModification", Folder));
	
	RightsSettings.Insert("AddFiles",
		ModuleAccessManagement.HasRight("AddFiles", Folder));
	
	RightsSettings.Insert("FilesDeletionMark",
		ModuleAccessManagement.HasRight("FilesDeletionMark", Folder));
	
	Return RightsSettings;
	
EndFunction

&AtServerNoContext
Function FileData(Val AttachedFile, Val FormID = Undefined, Val GetBinaryDataRef = True)
	
	Return FilesOperations.FileData(AttachedFile, FormID, GetBinaryDataRef);
	
EndFunction

&AtClient
Procedure IdleHandlerSetFileCommandsAccessibility()
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtClient
Procedure SetFileCommandsAvailability(Result = Undefined, ExecutionParameters = Undefined) Export
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined
		And TypeOf(Items.List.CurrentRow) <> Type("DynamicListGroupRow") Then
		
		SetCommandsAvailability(
			CurrentData.CurrentUserEditsFile,
			CurrentData.BeingEditedBy,
			CurrentData.SignedWithDS,
			CurrentData.Encrypted);
	Else
		MakeCommandsUnavailable();
	EndIf;
	AttachIdleHandler("UpdatePreview", 0.1, True);
	
EndProcedure

&AtClient
Procedure MakeCommandsUnavailable()
	
	Items.FormFinishEditing.Enabled = False;
	Items.ListContextMenuFinishEditing.Enabled = False;
	
	Items.FormSaveChanges.Enabled = False;
	Items.ListContextMenuSaveChanges.Enabled = False;
	
	Items.FormUnlock.Enabled = False;
	Items.ListContextMenuUnlock.Enabled = False;
	
	Items.FormLock.Enabled = False;
	Items.ListContextMenuLock.Enabled = False;
	
	Items.FormEdit.Enabled = False;
	Items.ListContextMenuEdit.Enabled = False;
	
	Items.FormMoveToFolder.Enabled = False;
	Items.ListContextMenuMoveToFolder.Enabled = False;
	
	Items.FormSign.Enabled = False;
	Items.ListContextMenuSign.Enabled = False;
	
	Items.FormSaveWithSignature.Enabled = False;
	Items.ListContextMenuSaveWithSignature.Enabled = False;
	
	Items.FormEncrypt.Enabled = False;
	Items.ListContextMenuEncrypt.Enabled = False;
	
	Items.FormDecrypt.Enabled = False;
	Items.ListContextMenuDecrypt.Enabled = False;
	
	Items.FormAddSignatureFromFile.Enabled = False;
	Items.ListContextMenuAddSignatureFromFile.Enabled = False;
	
	Items.FormUpdateFromFileOnDisk.Enabled = False;
	Items.ListContextMenuUpdateFromFileOnDisk.Enabled = False;
	
	Items.FormSaveAs.Enabled = False;
	Items.ListContextMenuSaveAs.Enabled = False;
	
	Items.FormOpenFileDirectory.Enabled = False;
	Items.ListContextMenuOpenFileDirectory.Enabled = False;
	
	Items.FormOpen.Enabled = False;
	Items.ListContextMenuOpen.Enabled = False;
	
	Items.Print.Enabled = False;
	Items.ListContextMenuPrint.Enabled = False;
	
	Items.Send.Enabled = False;
	
EndProcedure

&AtClient
Procedure SetCommandsAvailability(EditedByCurrentUser, EditedBy, SignedWithDS, Encrypted)
	
	EditedByAnother = ValueIsFilled(EditedBy) And Not EditedByCurrentUser;
	
	Items.FormFinishEditing.Enabled                 = FilesModification And EditedByCurrentUser;
	Items.ListContextMenuFinishEditing.Enabled = FilesModification And EditedByCurrentUser;
	
	Items.FormSaveChanges.Enabled                 = FilesModification And EditedByCurrentUser;
	Items.ListContextMenuSaveChanges.Enabled = FilesModification And EditedByCurrentUser;
	
	Items.FormUnlock.Enabled                 = FilesModification And ValueIsFilled(EditedBy) And Not FilesBeingEditedInCloudService;;
	Items.ListContextMenuUnlock.Enabled = FilesModification And ValueIsFilled(EditedBy) And Not FilesBeingEditedInCloudService;;
	
	Items.FormLock.Enabled                 = FilesModification And Not ValueIsFilled(EditedBy) And Not SignedWithDS;
	Items.ListContextMenuLock.Enabled = FilesModification And Not ValueIsFilled(EditedBy) And Not SignedWithDS;
	
	Items.FormEdit.Enabled                 = FilesModification And Not SignedWithDS And Not EditedByAnother;
	Items.ListContextMenuEdit.Enabled = FilesModification And Not SignedWithDS And Not EditedByAnother;
	
	Items.FormMoveToFolder.Enabled                 = FilesModification And Not SignedWithDS And Not FilesBeingEditedInCloudService;
	Items.ListContextMenuMoveToFolder.Enabled = FilesModification And Not SignedWithDS And Not FilesBeingEditedInCloudService;
	
	Items.FormSign.Enabled                 = FilesModification And Not ValueIsFilled(EditedBy);
	Items.ListContextMenuSign.Enabled = FilesModification And Not ValueIsFilled(EditedBy);
	
	Items.FormSaveWithSignature.Enabled                 = SignedWithDS;
	Items.ListContextMenuSaveWithSignature.Enabled = SignedWithDS;
	
	Items.FormEncrypt.Enabled                 = FilesModification And Not ValueIsFilled(EditedBy) And Not Encrypted;
	Items.ListContextMenuEncrypt.Enabled = FilesModification And Not ValueIsFilled(EditedBy) And Not Encrypted;
	
	Items.FormDecrypt.Enabled                 = FilesModification And Encrypted;
	Items.ListContextMenuDecrypt.Enabled = FilesModification And Encrypted;
	
	Items.FormAddSignatureFromFile.Enabled                 = FilesModification And Not ValueIsFilled(EditedBy);
	Items.ListContextMenuAddSignatureFromFile.Enabled = FilesModification And Not ValueIsFilled(EditedBy);
	
	Items.FormUpdateFromFileOnDisk.Enabled                 = FilesModification And Not SignedWithDS And Not FilesBeingEditedInCloudService;
	Items.ListContextMenuUpdateFromFileOnDisk.Enabled = FilesModification And Not SignedWithDS And Not FilesBeingEditedInCloudService;
	
	Items.FormSaveAs.Enabled                 = True;
	Items.ListContextMenuSaveAs.Enabled = True;
	
	Items.FormOpenFileDirectory.Enabled                 = True;
	Items.ListContextMenuOpenFileDirectory.Enabled = True;
	
	Items.FormOpen.Enabled                 = True;
	Items.ListContextMenuOpen.Enabled = True;
	
	Items.Print.Enabled                      = True;
	Items.ListContextMenuPrint.Enabled = True;
	
	Items.Send.Enabled                      = True;
	Items.ListContextMenuSend.Enabled = True;
	
EndProcedure

&AtServer
Procedure SetHierarchy(Mark)
	
	If Mark = Undefined Then 
		Return;
	EndIf;
	
	Items.FormUseHierarchy.Check = Mark;
	If Mark = True Then 
		Items.Folders.Visible = True;
	Else
		Items.Folders.Visible = False;
	EndIf;
	List.Parameters.SetParameterValue("UseHierarchy", Mark);
	
EndProcedure

&AtClient
Procedure ListSelectionAfterEditModeChoice(Result, ExecutionParameters) Export
	ResultOpen = "Open";
	ResultEdit = "Edit";
	
	If Result = ResultEdit Then
		Handler = New NotifyDescription("SelectionListAfterEditFile", ThisObject, ExecutionParameters);
		FilesOperationsInternalClient.EditFile(Handler, ExecutionParameters.FileData);
	ElsIf Result = ResultOpen Then
		FilesOperationsInternalClient.OpenFileWithNotification(Undefined, ExecutionParameters.FileData, UUID); 
	EndIf;
EndProcedure

&AtClient
Procedure SelectionListAfterEditFile(Result, ExecutionParameters) Export
	
	NotifyChanged(ExecutionParameters.FileData.Ref);
	
	SetFileCommandsAvailability();
	
EndProcedure

&AtClient
Procedure OnChangeSignatureOrEncryptionUsage()
	
	OnChangeUseSignOrEncryptionAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeUseSignOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject);
	
EndProcedure

&AtServerNoContext
Procedure SavePreviewOption(FileCatalogType, Preview)
	Common.CommonSettingsStorageSave(FileCatalogType, "Preview", Preview);
EndProcedure

&AtServerNoContext
Procedure OnSendFilesViaEmail(SendOptions, Val FilesToSend, FilesOwner, UUID)
	FilesOperationsOverridable.OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID);
EndProcedure

&AtClient
Procedure SetPreviewVisibility(UsePreview)
	
	Items.FileDataURL.Visible = UsePreview;
	Items.Preview.Check = UsePreview;
	
EndProcedure

&AtClient
Procedure UpdatePreview()
	
	If Not Preview Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined And PreviewEnabledExtensions.FindByValue(CurrentData.Extension) <> Undefined Then
		
		Try
			FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID,, FileDataURL);
			FileDataURL = FileData.BinaryFileDataRef;
		Except
			// If the file does not exist, an exception will be called.
			FileDataURL         = Undefined;
			NonSelectedPictureText = NStr("ru = 'Предварительный просмотр недоступен по причине:'; en = 'Preview is not available due to:'; pl = 'Podgląd jest niedostępny z powodu:';es_ES = 'Vista previa no disponible a causa de:';es_CO = 'Vista previa no disponible a causa de:';tr = 'Ön izleme aşağıdaki nedenle imkansız:';it = 'L''anteprima non è disponibile a causa di:';de = 'Die Vorschau ist aus diesem Grund nicht verfügbar:'") + Chars.LF + BriefErrorDescription(ErrorInfo());
		EndTry;
		
	Else
		
		FileDataURL         = Undefined;
		NonSelectedPictureText = NStr("ru = 'Нет данных для предварительного просмотра'; en = 'No data for preview'; pl = 'Brak danych do podglądu';es_ES = 'No hay datos para la vista previa';es_CO = 'No hay datos para la vista previa';tr = 'Ön gösterilecek veri yok';it = 'Nessun dato per l''anteprima';de = 'Keine Vorschau-Daten'");
		
	EndIf;
	
	If Not ValueIsFilled(FileDataURL) Then
		Items.FileDataURL.NonselectedPictureText = NonSelectedPictureText;
	EndIf;
	
EndProcedure

&AtServer
Function SynchronizationSettingsParameters(FileOwner)
	
	FileOwnerType = Common.MetadataObjectID(Type("CatalogRef.Files"));
	
	Filter = New Structure(
	"FileOwner, FileOwnerType, Account",
		FileOwner,
		FileOwnerType,
		Catalogs.FileSynchronizationAccounts.EmptyRef());
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileSynchronizationSettings.FileOwner,
		|	FileSynchronizationSettings.FileOwnerType,
		|	FileSynchronizationSettings.Account
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|WHERE
		|	FileSynchronizationSettings.FileOwner = &FileOwner
		|	AND FileSynchronizationSettings.FileOwnerType = &FileOwnerType";
	
	Query.SetParameter("FileOwner", FileOwner);
	Query.SetParameter("FileOwnerType", FileOwnerType);
	
	QueryResult = Query.Execute();
	
	DetailedRecordsSelection = QueryResult.Select();
	
	If DetailedRecordsSelection.Count() = 1 Then
		While DetailedRecordsSelection.Next() Do
			Filter.Account = DetailedRecordsSelection.Account;
		EndDo;
	EndIf;
	
	Return Filter;
	
EndFunction

&AtServer
Procedure UpdateAndSaveFilesListParameters()
	
	Common.FormDataSettingsStorageSave(
		"Files", 
		"CurrentFolder", 
		Items.Folders.CurrentRow);
	
	List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	
EndProcedure

&AtServerNoContext
Function EventLogFilterData(AccountService)
	Return FilesOperationsInternal.EventLogFilterData(AccountService);
EndFunction

#EndRegion
