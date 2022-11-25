
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Property("Parent") Then
		Object.Parent = Parameters.Parent;
	EndIf;
	
	UpdateCommandsAvailabilityByRightsSetting();
	
	WorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(Object.Ref);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	RefreshFullPath();
	
	UpdateCloudServiceNote();
	Items.FormSyncSettings.Visible = AccessRight("Edit", Metadata.Catalogs.FileSynchronizationAccounts);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.Properties
	
	If EventName = "Write_ObjectRightsSettings" Then
		UpdateCommandsAvailabilityByRightsSetting();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	WorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(Object.Ref);
	
	UpdateCommandsAvailabilityByRightsSetting();
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterChangeSettingsRightsOwnerInForm();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ParentOnChange(Item)
	
	RefreshFullPath();
	
EndProcedure

&AtClient
Procedure OwnerWorkingDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	Handler           = New NotifyDescription("FileSystemExtensionAttachedOwnerWorkingDirectorySelectionStartFollowUp", ThisObject);
	FilesOperationsInternalClient.ShowFileSystemExtensionInstallationQuestion(Handler);
	
EndProcedure

&AtClient
Procedure OwnerWorkingDirectoryClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ParentRef = Object.Parent;
	ParentWorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(ParentRef);
	FolderWorkingDirectory    = FilesOperationsInternalServerCall.FolderWorkingDirectory(Object.Ref);
	
	InheritedFolderWorkingDirectory = ParentWorkingDirectory
		+ Object.Description + GetPathSeparator();
	
	If IsBlankString(ParentWorkingDirectory) Then
		
		WorkingDirectory = ""; // New working directory of a folder.
		FilesOperationsInternalServerCall.CleanUpWorkingDirectory(Object.Ref);
		
	ElsIf InheritedFolderWorkingDirectory <> FolderWorkingDirectory Then
		
		WorkingDirectory = InheritedFolderWorkingDirectory; // New working directory of a folder.
		FilesOperationsInternalServerCall.SaveFolderWorkingDirectory(Object.Ref, WorkingDirectory);
	EndIf;
	
	RefreshDataRepresentation();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SyncSettings(Command)
	
	SyncSetup = SynchronizationSettingsParameters(Object.Ref);
	
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

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtClient
Procedure FileSystemExtensionAttachedOwnerWorkingDirectorySelectionStartFollowUp(Result, AdditionalParameters) Export
	
	If Not FilesOperationsInternalClient.FileSystemExtensionAttached() Then
		FilesOperationsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		If Write()= False Then
			Return;
		EndIf;
	EndIf;
	
	ClearMessages();
	
	Directory = "";
	Mode = FileDialogMode.ChooseDirectory;
	
	OpenFileDialog = New FileDialog(Mode);
	OpenFileDialog.Directory = WorkingDirectory;
	OpenFileDialog.FullFileName = "";
	Filter = NStr("ru = 'Все файлы(*.*)|*.*'; en = 'All files (*.*)|*.*'; pl = 'Wszystkie pliki(*.*)|*.*';es_ES = 'Todos archivos (*.*)|*.*';es_CO = 'Todos archivos (*.*)|*.*';tr = 'Tüm dosyalar (*.*)|*.*';it = 'Tutti i file (*.*) | *.*';de = 'Alle Dateien (*.*)|*.*'");
	OpenFileDialog.Filter = Filter;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("ru = 'Выберите каталог'; en = 'Select directory'; pl = 'Wybierz folder';es_ES = 'Seleccionar el directorio';es_CO = 'Seleccionar el directorio';tr = 'Dizini seçin';it = 'Selezionare la directory';de = 'Wählen Sie das Verzeichnis aus'");
	If OpenFileDialog.Choose() Then
		
		DirectoryName = OpenFileDialog.Directory;
		DirectoryName = CommonClientServer.AddLastPathSeparator(DirectoryName);
		
		// Creating a directory for files
		Try
			CreateDirectory(DirectoryName);
			TestDirectoryName = DirectoryName + "CheckAccess\";
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			// Not authorized to create a directory, or this path does not exist.
			
			ErrorText =
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неверный путь или отсутствуют права на запись в каталог ""%1""'; en = 'Incorrect path or insufficient rights to write to directory ""%1""'; pl = 'Błędna ścieżka lub niewystarczające prawa zapisu do katalogu ""%1""';es_ES = 'Ruta incorrecta o insuficientes derechos para inscribir al directorio ""%1""';es_CO = 'Ruta incorrecta o insuficientes derechos para inscribir al directorio ""%1""';tr = '""%1"" dizinine yazmak için yanlış yol veya yetersiz haklar';it = 'Percorso non corretto o di diritti insufficienti per scrivere nella directory ""%1""';de = 'Falscher Pfad oder unzureichende Rechte zum Schreiben in Verzeichnis ""%1""'"), DirectoryName);
			
			CommonClientServer.MessageToUser(ErrorText, , "WorkingDirectory");
			Return;
		EndTry;
		
		WorkingDirectory = DirectoryName;
		FilesOperationsInternalServerCall.SaveFolderWorkingDirectory(Object.Ref, WorkingDirectory);
		
	EndIf;
	
	RefreshDataRepresentation();
	
EndProcedure

&AtServer
Procedure RefreshFullPath()
	
	FolderParent = Common.ObjectAttributeValue(Object.Ref, "Parent");
	
	If ValueIsFilled(FolderParent) Then
	
		FullPath = "";
		While ValueIsFilled(FolderParent) Do
			
			FullPath = String(FolderParent) + "\" + FullPath;
			FolderParent = Common.ObjectAttributeValue(FolderParent, "Parent");
			If Not ValueIsFilled(FolderParent) Then
				Break;
			EndIf;
			
		EndDo;
		
		FullPath = FullPath + String(Object.Ref);
		
		If Not IsBlankString(FullPath) Then
			FullPath = """" + FullPath + """";
		EndIf;
	
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCommandsAvailabilityByRightsSetting()
	
	If NOT Common.SubsystemExists("StandardSubsystems.AccessManagement")
	 OR Items.Find("FormCommonCommandSetRights") = Undefined Then
		Return;
	EndIf;
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	
	If ValueIsFilled(Object.Ref)
	   AND NOT ModuleAccessManagement.HasRight("FoldersModification", Object.Ref) Then
		
		ReadOnly = True;
	EndIf;
	
	RightsManagement = ValueIsFilled(Object.Ref)
		AND ModuleAccessManagement.HasRight("RightsManagement", Object.Ref);
		
	If Items.FormCommonCommandSetRights.Visible <> RightsManagement Then
		Items.FormCommonCommandSetRights.Visible = RightsManagement;
	EndIf;
	
EndProcedure

// StandardSubsystems.Properties

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

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
Procedure UpdateCloudServiceNote()
	
	NoteVisibility = False;
	
	If GetFunctionalOption("UseFileSync") Then
	
		Query = New Query;
		Query.Text = 
			"SELECT TOP 1
			|	FilesSynchronizationWithCloudServiceStatuses.File,
			|	FilesSynchronizationWithCloudServiceStatuses.Href,
			|	FilesSynchronizationWithCloudServiceStatuses.Account.Description,
			|	FilesSynchronizationWithCloudServiceStatuses.Account.Service AS Service
			|FROM
			|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
			|WHERE
			|	FilesSynchronizationWithCloudServiceStatuses.File = &FileOwner";
		
		Query.SetParameter("FileOwner", Object.Ref);
		
		QueryResult = Query.Execute();
		
		DetailedRecordsSelection = QueryResult.Select();
		
		While DetailedRecordsSelection.Next() Do
			
			FolderAddressInCloudService = FilesOperationsInternalClientServer.AddressInCloudService(
				DetailedRecordsSelection.Service, DetailedRecordsSelection.Href);
			
			NoteVisibility = True;
			
			StringParts = New Array;
			StringParts.Add(NStr("ru = 'Работа с файлами ведется в облачном сервисе'; en = 'File operations are carried out in cloud service'; pl = 'Praca z plikami jest prowadzona w serwisie w chmurze';es_ES = 'Operaciones con archivos se realizan en el servicio de nube';es_CO = 'Operaciones con archivos se realizan en el servicio de nube';tr = 'Dosya yönetimi bulut hizmetinde gerçekleştirilir.';it = 'Le operazioni con i file sono eseguite nel servizio Cloud.';de = 'Die Dateiverwaltung erfolgt im Cloud-Service'"));
			StringParts.Add(" ");
			StringParts.Add(New FormattedString(DetailedRecordsSelection.AccountDescription, , , , FolderAddressInCloudService));
			Items.NoteDecoration.Title = New FormattedString(StringParts);
			
		EndDo;
		
	EndIf;
	
	Items.CloudServiceNoteGroup.Visible = NoteVisibility;
	
EndProcedure

#EndRegion
