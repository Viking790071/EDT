
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FileOwner = Parameters.FileOwner;
	
	CurrentRef = CommonClientServer.StructureProperty(Parameters, "CurrentRow");
	ListOpenedFromFileCard = ValueIsFilled(CurrentRef);
	Items.FileOwner.Visible = ListOpenedFromFileCard;
	If ListOpenedFromFileCard AND FileOwner = Undefined Then
		FileOwner = Common.ObjectAttributeValue(CurrentRef, "FileOwner");
		Parameters.FileOwner = FileOwner;
	EndIf;
	If Parameters.FileOwner = Undefined Then
		Raise NStr("ru = 'Список присоединенных файлов можно посмотреть
		                             |только в форме объекта-владельца.'; 
		                             |en = 'You can see a list of attached files
		                             |only in object-owner form.'; 
		                             |pl = 'Załączoną listę plików
		                             |można przeglądać tylko w formularzu właściciela obiektu.';
		                             |es_ES = 'Lista de archivos adjuntados solo puede
		                             |verse en el formulario del propietario del objetivo.';
		                             |es_CO = 'Lista de archivos adjuntados solo puede
		                             |verse en el formulario del propietario del objetivo.';
		                             |tr = 'Ekli dosya listesi sadece 
		                             |bir nesne sahibi şeklinde görülebilir.';
		                             |it = 'Puoi vedere l''elenco di file allegati
		                             |solo nel modulo dell''oggetto-titolare.';
		                             |de = 'Die angehängte Dateiliste kann
		                             |nur in Form eines Objektbesitzers betrachtet werden.'");
	EndIf;
	
	OwnerType = TypeOf(Parameters.FileOwner);
	If Metadata.DefinedTypes.FilesOwner.Type.ContainsType(OwnerType) Then
		FullOwnerName = Metadata.FindByType(OwnerType).Name;
		If Metadata.Catalogs.Find(FullOwnerName + "AttachedFiles") = Undefined Then
			IsFilesCatalogItemsOwner = True;
		EndIf;
	EndIf;
	
	Items.FormEdit.OnlyInAllActions           = Parameters.SimpleForm;
	Items.FormOpen.OnlyInAllActions                 = Parameters.SimpleForm;
	Items.FormFinishEditing.OnlyInAllActions = Parameters.SimpleForm;
	Items.ListImportantAttributes.Visible                    = Not Parameters.SimpleForm;
	Preview                                                = Parameters.SimpleForm;
	
	ShowSizeColumn = FilesOperationsInternalServerCall.GetShowSizeColumn();
	If Not ShowSizeColumn Then
		Items.ListSize.Visible = False;
	EndIf;
	
	If Not IsBlankString(Parameters.FormCaption) Then
		Title = Parameters.FormCaption;
	ElsIf ListOpenedFromFileCard Then
		Title = Title + " (" + String(TypeOf(FileOwner)) + " " + String(FileOwner) + ")";
	EndIf;
	
	If ValueIsFilled(Parameters.SendOptions) Then
		SendOptions = Parameters.SendOptions;
	Else
		SendOptions = FilesOperationsInternal.PrepareSendingParametersStructure();
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Title = NStr("ru = 'Выбор присоединенного файла'; en = 'Select attached file'; pl = 'Wybierz załączony plik';es_ES = 'Seleccionar el archivo adjuntado';es_CO = 'Seleccionar el archivo adjuntado';tr = 'Ekli dosya seç';it = 'Selezione di un file allegato';de = 'Wählen Sie die angehängte Datei aus'");
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	FilesSettings = FilesOperationsInternal.FilesSettings();
	
	FilesStorageCatalogName = Undefined;
	
	ErrorTitle = NStr("ru = 'Ошибка при настройке динамического списка присоединенных файлов.'; en = 'Error setting up the dynamic list of attached files.'; pl = 'Wystąpił błąd podczas konfigurowania dynamicznej listy załączonych plików.';es_ES = 'Ha ocurrido un error al configurar la lista dinámica de los archivos adjuntados.';es_CO = 'Ha ocurrido un error al configurar la lista dinámica de los archivos adjuntados.';tr = 'Ekli dosyaların dinamik listesini yapılandırırken bir hata oluştu.';it = 'Errore durante l''impostazione dell''elenco dinamico dei file allegati.';de = 'Bei der Konfiguration der dynamischen Liste der angehängten Dateien ist ein Fehler aufgetreten.'");
	ErrorEnd = NStr("ru = 'В этом случае настройка динамического списка невозможна.'; en = 'Cannot set up the dynamic list.'; pl = 'W tym przypadku konfiguracja listy dynamicznej nie jest obsługiwana.';es_ES = 'En el caso la configuración de la lista dinámica no se admite.';es_CO = 'En el caso la configuración de la lista dinámica no se admite.';tr = 'Bu durumda, dinamik liste yapılandırılamaz.';it = 'Impossibile impostare l''elenco dinamico';de = 'In diesem Fall wird die dynamische Listenkonfiguration nicht unterstützt.'");
	
	FilesStorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(
		Parameters.FileOwner, "", ErrorTitle, ErrorEnd);
		
	FileCatalogType = Type("CatalogRef." + FilesStorageCatalogName);
	
	ExceptionsArrayOfCreateFilesByTemplate = New Array;
	
	MetadataOfCatalogWithFiles = Metadata.FindByType(FileCatalogType);
	
	FileVersionsStorageCatalogName = FilesOperationsInternal.FilesVersionsStorageCatalogName(
		Parameters.FileOwner, "", ErrorTitle, ErrorEnd);
	
	CanCreateFileGroups = MetadataOfCatalogWithFiles.Hierarchical;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then 
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		HasRightToUseTemplates = ModuleAccessManagement.HasRight("Read", Catalogs.FileFolders.Templates);
	Else
		HasRightToUseTemplates = AccessRight("Read", Metadata.Catalogs.Files) AND AccessRight("Read", Metadata.Catalogs.FileFolders)
	EndIf;
	
	If NOT HasRightToUseTemplates Or FilesSettings.DontCreateFilesByTemplate.Find(Metadata.FindByType(TypeOf(FileOwner))) <> Undefined Then
		Items.AppendFileByTemplate.Visible = False;
		Items.ListContextMenuAddFileFromTemplate.Visible = False;
	EndIf;
	
	CanCreateFileVersions = IsFilesCatalogItemsOwner;
	
	SetUpDynamicList(FilesStorageCatalogName);
	
	If Not CanCreateFileGroups Then
		HideGroupCreationButtons();
	EndIf;
	
	HasRightToAdd = True;
	
	If NOT AccessRight("InteractiveInsert", MetadataOfCatalogWithFiles) Then
		HideAddButtons();
		HasRightToAdd = False;
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		ReadOnly = Not AccessRight("Edit", MetadataOfCatalogWithFiles);
	Else	
		ReadOnly = Parameters.ReadOnly Or NOT AccessRight("Edit", MetadataOfCatalogWithFiles)
			Or NOT AccessRight("Edit", Parameters.FileOwner.Metadata());
	EndIf;
	
	If ReadOnly Then
		HideChangeButtons();
		HasRightToAdd = False;
	EndIf;
	
	AllFormCommandsNames = GetFormCommandNames();
	ItemNames = New Array;
	
	For Each FormItem In Items Do
		
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If AllFormCommandsNames.Find(FormItem.CommandName) <> Undefined
			Or AllFormCommandsNames.Find(FormItem.Name) <> Undefined Then
				ItemNames.Add(FormItem.Name);
		EndIf;
		
	EndDo;
	
	FormButtonItemNames = New FixedArray(ItemNames);
	
	OnChangeUseOfSigningOrEncryptionAtServer();
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormChange.Visible = False;
		Items.FormChange82.Visible = True;
		Items.FormCopy.OnlyInAllActions = False;
		Items.SetDeletionMark.OnlyInAllActions = False;
	EndIf;
	
	UsePreview = Common.CommonSettingsStorageLoad(
		FileCatalogType,
		"Preview");
	
	If UsePreview <> Undefined Then
		Preview = UsePreview;
	EndIf;
	
	Items.FileDataURL.Visible = Preview;
	Items.Preview.Check       = Preview;
	
	PreviewEnabledExtensions = FilesOperationsInternal.ExtensionsListForPreview();
	
	UpdateCloudServiceNote();
	
	Items.SyncSettings.Visible = AccessRight("Edit", Metadata.Catalogs.FileSynchronizationAccounts);
	HasDigitalSignature = Common.SubsystemExists("StandardSubsystems.DigitalSignature");
	Items.PrintWithStamp.Visible = HasDigitalSignature;
	
	Items.CompareFiles.Visible = Not CommonClientServer.IsLinuxClient()
		                             AND Not CommonClientServer.IsWebClient();
	
	RestrictedExtensions = FilesOperationsInternal.DeniedExtensionsList();
	
	SetConditionalAppearance();
	
	FilesOperationsOverridable.OnCreateFilesListForm(ThisObject);
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "FormOpenFileDirectory", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "ListContextMenuOpenFileDirectory", "Visible", False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If HasRightToAdd Then
		ScanCommandAvailable                                    = FilesOperationsInternalClient.ScanCommandAvailable();
		Items.AppendFileFromScanner.Visible                      = ScanCommandAvailable;
		Items.ListContextMenuAddFileFromScanner.Visible = ScanCommandAvailable;
	EndIf;
	
	SetFileCommandsAvailability();
	
	If CommonClientServer.IsMobileClient() Then
		ThisObject.Enabled = False;
		CommonClientServer.MessageToUser(NStr("en = 'Work with attached files is not supported in the mobile interface.'; ru = 'Работа с присоединенными файлами не поддерживается в мобильном интерфейсе.';pl = 'Praca z załączonymi plikami nie jest obsługiwana w interfejsie mobilnym.';es_ES = 'El trabajo con archivos adjuntos no es compatible con la interfaz móvil.';es_CO = 'El trabajo con archivos adjuntos no es compatible con la interfaz móvil.';tr = 'Ekli dosyalarla çalışma mobil arayüzde desteklenmiyor.';it = 'Il lavoro con i file allegati non è supportato nell''interfaccia mobile.';de = 'Angehängte Dateien können in der mobilen Schnittstelle nicht bearbeitet werden.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_ConstantsSet")
		AND (Upper(Source) = Upper("UseDigitalSignature")
		Or Upper(Source) = Upper("UseEncryption")) Then
		
		AttachIdleHandler("SigningOrEncryptionUsageOnChange", 0.3, True);
		Return;
	ElsIf EventName = "Write_File" Then
	
		FileRef = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
		If TypeOf(FileRef) <> FileCatalogType Then
			Return;
		EndIf;

		If Parameter.Property("IsNew") AND Parameter.IsNew Then
			
			Items.List.Refresh();
			Items.List.CurrentRow = FileRef;
			SetFileCommandsAvailability();
			
		Else
			If FileCommandsAvailable() AND Items.List.CurrentData <> Undefined 
				 AND FileRef = Items.List.CurrentData.Ref Then
				SetFileCommandsAvailability();
			EndIf;
		EndIf;
	ElsIf EventName = "Write_FileFolders" Then
		Items.List.Refresh();
		SetFileCommandsAvailability();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationSynchronizationDateURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "OpenJournal" Then
		
		StandardProcessing = False;
		FilterParameters = EventLogFilterData(Account);
		EventLogClient.OpenEventLog(FilterParameters, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	If Items.List.ChoiceMode Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	CurrentData = Items.List.CurrentData;
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.IsFolder Then
		ShowValue(, RowSelected);
		Return;
	EndIf;
	
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
Procedure ListOnActivateRow(Item)
	
	UpdateFileCommandAvailability();
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	
	If Clone Then
		
		If NOT FileCommandsAvailable() Then
			Return;
		EndIf;
		
		FormParameters = New Structure;
		FormParameters = New Structure("CopyingValue", Item.CurrentData.Ref);
		
		If Item.CurrentData.IsFolder Then
			OpenForm("DataProcessor.FilesOperations.Form.GroupOfFiles", FormParameters);
		Else
			FilesOperationsClient.CopyFileSSL(FileOwner, Item.CurrentData.Ref, FormParameters);
		EndIf;
		
	Else
		
		AppendFile();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	OpenFileCard();
	
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
	
	FileNamesArray = New Array;
	ListItemsArray = New Array;
	
	If TypeOf(DragParameters.Value) = Type("File")
		AND DragParameters.Value.IsFile() Then
		
		If StrCompare(FilesStorageCatalogName, "Files") <> 0 Then
			FileNamesArray.Add(DragParameters.Value.FullName);
		Else
			DragFiles(FileOwner, DragParameters.Value, DragParameters.Action);
			Return;
		EndIf;
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() > 0 Then
			
			DraggedItemType = TypeOf(DragParameters.Value[0]);
			If DraggedItemType = Type("CatalogRef.Files") Then
				FilesOperationsInternalClient.MoveFilesToAttachedFiles(
					DragParameters.Value,
					FileOwner);
				Return;
			EndIf;
			If TypeOf(DragParameters.Value[0]) = Type("File") Then
				If StrCompare(FilesStorageCatalogName, "Files") <> 0 Then
					For Each Value In DragParameters.Value Do
						If TypeOf(Value) = Type("File") AND Value.IsFile() Then
							FileNamesArray.Add(Value.FullName);
						EndIf;
					EndDo;
				Else
					DragFiles(FileOwner, DragParameters.Value, DragParameters.Action);
					Return;
				EndIf;
			ElsIf TypeOf(DragParameters.Value[0]) = FileCatalogType Then 
				For Each Value In DragParameters.Value Do
					ListItemsArray.Add(Value);
				EndDo;
			EndIf;
		EndIf;
		
	EndIf;
	
	If FileNamesArray.Count() > 0 Then
		FilesOperationsInternalClient.AddFilesWithDrag(
		Parameters.FileOwner, UUID, FileNamesArray);
	EndIf;
	
	If ListItemsArray.Count() > 0 AND CanCreateFileGroups Then
		StandardProcessing = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

///////////////////////////////////////////////////////////////////////////////////
// File command handlers

&AtClient
Procedure Add(Command)
	
	AppendFile();
	
EndProcedure

&AtClient
Procedure AppendFileByTemplate(Command)
	
	AddingOptions = New Structure;
	AddingOptions.Insert("ResultHandler",          Undefined);
	AddingOptions.Insert("FileOwner",                 FileOwner);
	AddingOptions.Insert("OwnerForm",                 ThisObject);
	AddingOptions.Insert("FilesStorageCatalogName", FilesStorageCatalogName);
	FilesOperationsInternalClient.AddBasedOnTemplate(AddingOptions);
	
EndProcedure

&AtClient
Procedure AppendFileFromScanner(Command)
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("FilesOwner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	AddingOptions = New Structure;
	AddingOptions.Insert("ResultHandler", Undefined);
	AddingOptions.Insert("FileOwner", FileOwner);
	AddingOptions.Insert("OwnerForm", ThisObject);
	AddingOptions.Insert("DontOpenCardAfterCreateFromFIle", True);
	AddingOptions.Insert("IsFile", False);
	FilesOperationsInternalClient.AddFromScanner(AddingOptions);
	
EndProcedure

&AtClient
Procedure OpenFileForViewing(Command)
	
	OpenFile();
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	FileRef = Items.List.CurrentData.Ref;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(FileRef,
		Undefined, UUID, Undefined, Undefined);
	FilesOperationsClient.OpenFileDirectory(FileData);

	
EndProcedure

&AtClient
Procedure Update(Command)
	
	Items.List.Refresh();
	
	AttachIdleHandler("UpdateFileCommandAvailability", 0.1, True);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData.Encrypted Or CurrentData.SignedWithDS Or CurrentData.FileBeingEdited Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataAndWorkingDirectory(Items.List.CurrentRow);
	FilesOperationsInternalClient.UpdateFromFileOnHardDriveWithNotification(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted
		OR (CurrentData.FileBeingEdited AND CurrentData.CurrentUserEditsFile) Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(CurrentData.Ref, , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure Copy(Command)
	
	Items.List.CopyRow();
	
EndProcedure

&AtClient
Procedure SetDeletionMark(Command)
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		QuestionTemplate = ?(CurrentData.DeletionMark,
			NStr("ru='Снять с ""%1"" пометку на удаление?'; en = 'Do you want to clear a deletion mark for ""%1""?'; pl = 'Oczyścić znacznik usunięcia dla ""%1""?';es_ES = '¿Eliminar la marca para borrar para ""%1""?';es_CO = '¿Eliminar la marca para borrar para ""%1""?';tr = '""%1"" için silme işareti kaldırılsın mı?';it = 'Volete rimuovere il contrassegno per l''eliminazione per ""%1""?';de = 'Löschzeichen für ""%1"" löschen?'"),
			NStr("ru='Пометить ""%1"" на удаление?'; en = 'Do you want to mark %1 for deletion?'; pl = 'Zaznaczyć ""%1"" do usunięcia?';es_ES = '¿Marcar ""%1"" para borrar?';es_CO = '¿Marcar ""%1"" para borrar?';tr = '""%1"" silinmek üzere işaretlensin mi?';it = 'Volete contrassegnare %1 per l''eliminazione?';de = 'Markieren Sie ""%1"" zum Löschen?'"));
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionTemplate, CurrentData.Description);
		AdditionalParameters = New Structure("FileRef", CurrentData.Ref);
		Notification = New NotifyDescription("AfterQuestionAboutDeletionMark", ThisObject, AdditionalParameters);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
	EndIf;
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	OpenFileCard();
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	OnSendFilesViaEmail(SendOptions, Items.List.SelectedRows, FileOwner, UUID);
	
	FilesOperationsInternalClient.SendFilesViaEmail(
		Items.List.SelectedRows, UUID, SendOptions);
	
EndProcedure

&AtClient
Procedure PrintFiles(Command)
	
	SystemInfo = New SystemInfo;
	If SystemInfo.PlatformType <> PlatformType.Windows_x86 
		AND SystemInfo.PlatformType <> PlatformType.Windows_x86_64 Then
			ShowMessageBox(, NStr("ru = 'Печать файлов возможна только в Windows.'; en = 'Printing files is available only in Windows.'; pl = 'Drukowanie plików jest możliwe tylko w Windows.';es_ES = 'Es posible imprimir los archivos solo en Windows.';es_CO = 'Es posible imprimir los archivos solo en Windows.';tr = 'Dosya yalnızca Windows''ta yazdırılabilir.';it = 'Il file di stampa sono disponibili solo in Windows.';de = 'Dateien können nur unter Windows gedruckt werden.'"));
			Return;
	EndIf;
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() > 0 Then
		FilesOperationsClient.PrintFiles(SelectedRows, ThisObject.UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintWithStamp(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DocumentWithStamp = FilesOperationsInternalServerCall.SpreadsheetDocumentWithStamp(CurrentData.Ref, CurrentData.Ref);
	FilesOperationsInternalClient.PrintFileWithStamp(DocumentWithStamp);
	
EndProcedure

&AtClient
Procedure Preview(Command)
	
	Preview = Not Preview;
	Items.Preview.Check = Preview;
	SetPreviewVisibility(Preview);
	SavePreviewOption(FileCatalogType, Preview);
	
	#If WebClient Then
	UpdatePreview();
	#EndIf
	
EndProcedure

&AtClient
Procedure SyncSettings(Command)
	
	SyncSetup = SynchronizationSettingsParameters(FileOwner);
	
	If ValueIsFilled(SyncSetup.Account) Then
		ValueType = Type("InformationRegisterRecordKey.FileSynchronizationSettings");
		WriteParameters = New Array(1);
		WriteParameters[0] = SyncSetup;
		
		RecordKey = New(ValueType, WriteParameters);
	
		WriteParameters = New Structure;
		WriteParameters.Insert("Key", RecordKey);
	Else
		WriteParameters = SyncSetup;
	EndIf;
	
	OpenForm("InformationRegister.FileSynchronizationSettings.Form.SimpleRecordFormSettings", WriteParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure CreateGroup(Command)
	
	FormParameters = New Structure;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined AND CurrentData.FileOwner <> FileOwner Then
		CurrentData = Undefined;
	EndIf;
	
	If CurrentData <> Undefined Then
		FormParameters.Insert("Parent", CurrentData.Ref);
	Else
		FormParameters.Insert("Parent", FileOwner);
	EndIf;
	
	FormParameters.Insert("FileOwner",  FileOwner);
	FormParameters.Insert("IsNewGroup", True);
	FormParameters.Insert("FilesStorageCatalogName", FilesStorageCatalogName);
	
	OpenForm("DataProcessor.FilesOperations.Form.GroupOfFiles", FormParameters);
	
EndProcedure

&AtClient
Procedure ImportFiles(Command)
	#If WebClient Then
		WarningText =  NStr("ru = 'В Веб-клиенте импорт файлов не поддерживается.
		                                  |Используйте команду ""Создать"" в списке файлов.'; 
		                                  |en = 'File import is not supported in Web client.
		                                  |Click ""Create"" in the file list.'; 
		                                  |pl = 'Import plików nie jest obsługiwany w kliencie sieci Web.
		                                  |Użyj polecenia Utwórz w liście plików.';
		                                  |es_ES = 'Importación de archivos no está admitida en el cliente web.
		                                  |Utilizar el comando Crear en la lista de archivos.';
		                                  |es_CO = 'Importación de archivos no está admitida en el cliente web.
		                                  |Utilizar el comando Crear en la lista de archivos.';
		                                  |tr = 'Web istemcide dosya içe aktarma desteklenmez. 
		                                  |Dosyalar listesinde Oluştur komutunu kullanın.';
		                                  |it = 'L''importazione di file non supportata in Client web.
		                                  |Clicca ""Creare"" nell''elenco di file.';
		                                  |de = 'Der Dateiimport wird im Webclient nicht unterstützt.
		                                  |Verwenden Sie die Liste Befehl in Dateien erstellen.'");
		ShowMessageBox(, WarningText);
		Return;
	#EndIf
	
	FileNamesArray = FilesOperationsInternalClient.FilesToImport();
	
	If FileNamesArray.Count() = 0 Then
		Return;
	EndIf;
	
	DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("FilesOwner"));
	If DCParameterValue = Undefined Then
		FileOwner = Undefined;
	Else
		FileOwner = DCParameterValue.Value;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding",            FileOwner);
	FormParameters.Insert("FileNamesArray",              FileNamesArray);
	CurrentData = Items.List.CurrentData;
	GroupOfFiles = Undefined;
	If CurrentData <> Undefined AND CurrentData.IsFolder Then
		GroupOfFiles = CurrentData.Ref;
	EndIf;
	FormParameters.Insert("GroupOfFiles",                  GroupOfFiles);
	OpenForm("DataProcessor.FilesOperations.Form.FilesImportForm", FormParameters);
EndProcedure

&AtClient
Procedure ImportFolder(Command)
	
	#If WebClient Then
		WarningText = NStr("ru = 'В веб-клиенте импорт папок недоступен.
			                             |Используйте команду ""Создать"" в списке файлов.'; 
			                             |en = 'Folder import is not available in Web client.
			                             |Click ""Create"" in the file list.'; 
			                             |pl = 'Import folderów jest niedostępny w kliencie sieci Web.
			                             |Użyj polecenia Utwórz w liście plików.';
			                             |es_ES = 'Importación de carpetas no está disponible en el cliente web.
			                             |Utilizar el comando Crear en la lista de archivos.';
			                             |es_CO = 'Importación de carpetas no está disponible en el cliente web.
			                             |Utilizar el comando Crear en la lista de archivos.';
			                             |tr = 'Web istemcide klasörler içe aktarılamaz.
			                             |Dosyalar listesinde Oluştur komutunu kullanın.';
			                             |it = 'L''importazione di cartelle non è disponibile in Client web.
			                             |Clicca ""Creare"" nell''elenco di file.';
			                             |de = 'Der Import von Ordnern ist im Webclient nicht verfügbar.
			                             |Verwenden Sie die Liste Befehl in Dateien erstellen.'");
		ShowMessageBox(, WarningText);
		Return;
	#EndIf
	
	OpenFileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	OpenFileDialog.FullFileName = "";
	OpenFileDialog.Filter = NStr("ru = 'Все файлы(*.*)|*.*'; en = 'All files (*.*)|*.*'; pl = 'Wszystkie pliki(*.*)|*.*';es_ES = 'Todos archivos (*.*)|*.*';es_CO = 'Todos archivos (*.*)|*.*';tr = 'Tüm dosyalar (*. *) | *. *';it = 'Tutti i file (*.*) | *.*';de = 'Alle Dateien (*.*)|*.*'");
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("ru = 'Выберите каталог'; en = 'Select directory'; pl = 'Wybierz folder';es_ES = 'Seleccionar el directorio';es_CO = 'Seleccionar el directorio';tr = 'Dizini seçin';it = 'Selezionare la directory';de = 'Wählen Sie das Verzeichnis aus'");
	If Not OpenFileDialog.Choose() Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FolderForAdding",            FileOwner);
	FormParameters.Insert("DirectoryOnHardDrive",                OpenFileDialog.Directory);
	FormParameters.Insert("FilesStorageCatalogName", FilesStorageCatalogName);
	CurrentData = Items.List.CurrentData;
	GroupOfFiles = Undefined;
	If CurrentData <> Undefined AND CurrentData.IsFolder Then
		GroupOfFiles = CurrentData.Ref;
	EndIf;
	FormParameters.Insert("GroupOfFiles",      GroupOfFiles);
	
	OpenForm("DataProcessor.FilesOperations.Form.FolderImportForm", FormParameters);
	
EndProcedure

&AtClient
Procedure SaveFolder(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Or Not CurrentData.IsFolder Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExportFolder",                  CurrentData.Ref);
	FormParameters.Insert("FilesStorageCatalogName",  FilesStorageCatalogName);
	FormParameters.Insert("FileVersionsStorageCatalogName", FileVersionsStorageCatalogName);
	OpenForm("DataProcessor.FilesOperations.Form.ExportFolderForm", FormParameters);
	
EndProcedure

&AtClient
Procedure CompareFiles(Command)
	
	SelectedRowsCount = Items.List.SelectedRows.Count();
	
	If SelectedRowsCount = 2 Then
		
		Ref1 = Items.List.SelectedRows[0];
		Ref2 = Items.List.SelectedRows[1];
		
		Extension = Lower(Items.List.CurrentData.Extension);
		
		FilesOperationsInternalClient.CompareFiles(UUID, Ref1, Ref2, Extension);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MoveToGroup(Command)
	If Items.List.SelectedRows.Count() > 0 Then
		OpeningParameters = New Structure;
		OpeningParameters.Insert("FilesOwner", FileOwner);
		OpeningParameters.Insert("FilesToMove", Items.List.SelectedRows);
		OpenForm("DataProcessor.FilesOperations.Form.SelectGroup", OpeningParameters, ThisObject);
	EndIf;
EndProcedure

//////////////////////////////////////////////////////////////////////////////////
// Command handlers to support digital signature and encryption.

&AtClient
Procedure Sign(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileBeingEdited
		OR CurrentData.Encrypted Then
		Return;
	EndIf;
	
	NotifyDescription      = New NotifyDescription("AddSignaturesCompeltion", ThisObject);
	AdditionalParameters = New Structure("ResultProcessing", NotifyDescription);
	FilesOperationsClient.SignFile(CurrentData.Ref, UUID, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure SaveWithDigitalSignature(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.SaveFileWithSignature(
		CurrentData.Ref, UUID);
	
EndProcedure

&AtClient
Procedure AddDSFromFile(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileBeingEdited
		OR CurrentData.Encrypted Then
		Return;
	EndIf;
	
	AttachedFile = CurrentData.Ref;
	
	FilesOperationsInternalClient.AddSignatureFromFile(
		AttachedFile,
		UUID,
		New NotifyDescription("AddSignaturesCompeltion", ThisObject));
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.FileBeingEdited
		OR CurrentData.Encrypted Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.GetFileDataAndVersionsCount(CurrentData.Ref);
	
	If ValueIsFilled(FileData.BeingEditedBy)
		OR FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("FileData",  FileData);
	HandlerParameters.Insert("ObjectRef", CurrentData.Ref);
	Handler = New NotifyDescription("EncryptAfterEncryptAtClient", ThisObject, HandlerParameters);
	
	FilesOperationsInternalClient.Encrypt(Handler, FileData, UUID);
	
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
Procedure Decrypt(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If NOT CurrentData.Encrypted Then
		Return;
	EndIf;
	
	ObjectRef = CurrentData.Ref;
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

///////////////////////////////////////////////////////////////////////////////////
// Command handlers to support collaboration in operations with files.

&AtClient
Procedure Edit(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If (CurrentData.FileBeingEdited AND NOT CurrentData.CurrentUserEditsFile)
		OR CurrentData.Encrypted
		OR CurrentData.SignedWithDS Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.EditWithNotification(Undefined, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	FilesArray = New Array;
	For Each ListItem In Items.List.SelectedRows Do
		RowData = Items.List.RowData(ListItem);
		
		If NOT RowData.FileBeingEdited
			OR NOT RowData.CurrentUserEditsFile Then
			Continue;
		EndIf;
		FilesArray.Add(RowData.Ref);
	EndDo;
	
	If FilesArray.Count() > 1 Then
		FormParameters = New Structure;
		FormParameters.Insert("FilesArray",                     FilesArray);
		FormParameters.Insert("CanCreateFileVersions", CanCreateFileVersions);
		FormParameters.Insert("BeingEditedBy",                      RowData.EditedByUser);
		
		OpenForm("DataProcessor.FilesOperations.Form.FormFinishEditing", FormParameters, ThisObject);
	ElsIf FilesArray.Count() = 1 Then 
		Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject);
		FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, RowData.Ref, UUID);
		If Not CanCreateFileVersions Then
			FileUpdateParameters.Insert("CreateNewVersion", False);
		EndIf;
		FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure Unlock(Command)
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.UnlockFiles(Items.List);
	SetFileCommandsAvailability();
	
EndProcedure

&AtClient
Procedure Lock(Command)
	
	If NOT FileCommandsAvailable() Then
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
			
			If ValueIsFilled(RowData.EditedByUser) Then
				Continue;
			EndIf;
			FilesArray.Add(RowData.Ref);
		EndDo;
		Handler = New NotifyDescription("SetFileCommandsAvailability", ThisObject, FilesArray);
		FilesOperationsInternalClient.LockWithNotification(Handler, FilesArray);
	EndIf;
	
EndProcedure


#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	List.ConditionalAppearance.Items.Clear();
	
	// Appearance of the file that is being edited by another user
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AnotherUserEditsFile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// Appearance of the file that is being edited by the current user
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("CurrentUserEditsFile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUser);
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("FileOwner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = FileOwner;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
EndProcedure

&AtClient
Procedure AppendFile()
	
	CurrentData = Items.List.CurrentData;
	GroupOfFiles = Undefined;
	If CurrentData <> Undefined AND CurrentData.IsFolder AND CurrentData.FileOwner = Parameters.FileOwner Then
		GroupOfFiles = CurrentData.Ref;
	EndIf;
	If IsFilesCatalogItemsOwner Then
		FilesOperationsInternalClient.AddFileFromFileSystem(Parameters.FileOwner, ThisObject);
	Else
		FilesOperationsClient.AddFiles(Parameters.FileOwner, UUID, , GroupOfFiles);
	EndIf;

EndProcedure

&AtClient
Procedure OpenFile()
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Encrypted Then
		Return;
	EndIf;
	
	If RestrictedExtensions.FindByValue(CurrentData.Extension) <> Undefined Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CurrentData", CurrentData);
		Notification = New NotifyDescription("OpenFileAfterConfirm", ThisObject, AdditionalParameters);
		FormParameters = New Structure("Key", "BeforeOpenFile");
		FormParameters.Insert("FileName",
			CommonClientServer.GetNameWithExtension(CurrentData.Description, CurrentData.Extension));
		OpenForm("CommonForm.SecurityWarning", FormParameters, , , , , Notification);
		Return;
	EndIf;
	
	FileBeingEdited = CurrentData.FileBeingEdited AND CurrentData.CurrentUserEditsFile;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID);
	If FileData.Encrypted Then
		// The file might be changed in another session
		NotifyChanged(CurrentData.Ref);
		Return;
	EndIf;
	
	FilesOperationsClient.OpenFile(FileData, FileBeingEdited);
	
EndProcedure

&AtClient
Procedure OpenFileCard()
	
	If NOT FileCommandsAvailable() Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key",              CurrentData.Ref);
	FormParameters.Insert("ReadOnly",    ReadOnly);
	FormParameters.Insert("SendOptions", SendOptions);
	
	If CurrentData.IsFolder Then
		OpenForm("DataProcessor.FilesOperations.Form.GroupOfFiles", FormParameters);
	Else
		FilesOperationsClient.OpenFileForm(CurrentData.Ref,, FormParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenFileAfterConfirm(Result, AdditionalParameters) Export
	
	If Result <> Undefined AND Result = "Continue" Then
		
		CurrentData = AdditionalParameters.CurrentData;
		
		FileBeingEdited = CurrentData.FileBeingEdited AND CurrentData.CurrentUserEditsFile;
		
		FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID);
		If FileData.Encrypted Then
			// The file might be changed in another session
			NotifyChanged(CurrentData.Ref);
			Return;
		EndIf;
		
		FilesOperationsClient.OpenFile(FileData, FileBeingEdited);
		
	EndIf;
	
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
Function FileCommandsAvailable()
	
	Return FilesOperationsInternalClient.FileCommandsAvailable(Items);
	
EndFunction

&AtServer
Procedure HideGroupCreationButtons()
	Items.CreateFolder.Visible                           = False;
	Items.ListContextMenuCreateGroup.Visible      = False;
	Items.ImportFolder.Visible                          = False;
	Items.SaveFolder.Visible                          = False;
	Items.MoveToGroup.Visible                        = False;
	Items.ListContextMenuMoveToGroup.Visible = False;
EndProcedure

&AtServer
Procedure HideAddButtons()
	
	Items.Add.Visible                           = False;
	Items.AddFromFileOnHardDrive.Visible             = False;
	Items.AppendFileByTemplate.Visible              = False;
	Items.AppendFileFromScanner.Visible              = False;
	Items.ListContextMenuAdd.Visible      = False;
	Items.ListContextMenuCreateGroup.Visible = False;
	Items.CreateFolder.Visible                      = False;
	Items.ListContextMenuCreateGroup.Visible = False;
	Items.FormCopy.Visible                   = False;
	Items.ListContextMenuCopy.Visible   = False;
	
EndProcedure

&AtServer
Procedure HideChangeButtons()
	
	CommandsNames = GetCommandsNamesOfObjectsChange();
	
	For each FormItem In Items Do
		
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Visible = False;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure DragFiles(FileOwner, DragValue, Action)
	
	FileNamesArray = New Array;
	
	ValueType = TypeOf(DragValue);
	If ValueType = Type("File") Then
		
		If DragValue.IsFile() Then
			FileNamesArray.Add(DragValue.FullName);
		EndIf;
		
	ElsIf TypeOf(DragValue) = Type("Array") Then
		
		For Each ReceivedFile In DragValue Do
			If ReceivedFile.IsFile() Then
				FileNamesArray.Add(ReceivedFile.FullName);
			EndIf;
		EndDo;
		
	EndIf;
	
	AddingOptions = New Structure;
	AddingOptions.Insert("ResultHandler", Undefined);
	AddingOptions.Insert("FullFileName", Undefined);
	AddingOptions.Insert("FileOwner", FileOwner);
	AddingOptions.Insert("OwnerForm", ThisObject);
	AddingOptions.Insert("NameOfFileToCreate", Undefined);
	AddingOptions.Insert("DontOpenCardAfterCreateFromFIle", True);
	
	For Each ReceivedFile In FileNamesArray Do
		AddingOptions.FullFileName = ReceivedFile;
		FilesOperationsInternalClient.AddFormFileSystemWithExtension(AddingOptions);
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure SetFileCommandsAvailability(Result = Undefined, ExecutionParameters = Undefined) Export
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		CommandsNames = New Array;
		CommandsNames.Add("Add");
		CommandsNames.Add("AppendFileFromScanner");
		CommandsNames.Add("AppendFileByTemplate");
	ElsIf TypeOf(Items.List.CurrentRow) <> FileCatalogType Then
		CommandsNames = New Array;
	Else
		AbilityToUnlockFile = FilesOperationsInternalClient.AbilityToUnlockFile(
			CurrentData.Ref,
			CurrentData.CurrentUserEditsFile,
			CurrentData.EditedByUser);
			
		CommandsNames = GetAvailableCommands(CurrentData, FilesBeingEditedInCloudService, AbilityToUnlockFile);
	EndIf;
	
	If CurrentData <> Undefined Then
		Items.PrintWithStamp.Visible = HasDigitalSignature
			AND (CurrentData.Extension = "mxl")
			AND CurrentData.SignedWithDS;
	EndIf;
	
	For each FormItemName In FormButtonItemNames Do
		
		FormItem = Items.Find(FormItemName);
		
		If CommandsNames.Find(FormItem.CommandName) <> Undefined
			Or CommandsNames.Find(FormItem.Name) <> Undefined Then
			
			If NOT FormItem.Enabled Then
				FormItem.Enabled = True;
			EndIf;
			
		ElsIf FormItem.Enabled Then
			FormItem.Enabled = False;
		EndIf;
	EndDo;
	
	AttachIdleHandler("UpdatePreview", 0.1, True);

EndProcedure

&AtClient
Procedure AfterQuestionAboutDeletionMark(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		SetClearDeletionMark(AdditionalParameters.FileRef);
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUpDynamicList(FilesStorageCatalogName)
	
	ListProperties = Common.DynamicListPropertiesStructure();
	
	QueryText = 
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.DeletionMark,
	|	CASE
	|		WHEN Files.DeletionMark = TRUE
	|			THEN ISNULL(Files.PictureIndex, 2) + 1
	|		ELSE ISNULL(Files.PictureIndex, 2)
	|	END AS PictureIndex,
	|	Files.Description AS Description,
	|	CAST(Files.Details AS STRING(500)) AS Details,
	|	Files.Author,
	|	Files.CreationDate,
	|	Files.Changed AS WasEditedBy,
	|	DATEADD(Files.UniversalModificationDate, SECOND, &SecondsToLocalTime) AS ChangeDate,
	|	CAST(Files.Size / 1024 AS NUMBER(10, 0)) AS Size,
	|	Files.SignedWithDS,
	|	Files.Encrypted,
	|	CASE
	|		WHEN Files.SignedWithDS
	|				AND Files.Encrypted
	|			THEN 2
	|		WHEN Files.Encrypted
	|			THEN 1
	|		WHEN Files.SignedWithDS
	|			THEN 0
	|		ELSE -1
	|	END AS SignedEncryptedPictureNumber,
	|	CASE
	|		WHEN NOT Files.BeingEditedBy IN (&EmptyUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FileBeingEdited,
	|	CASE
	|		WHEN Files.BeingEditedBy = &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CurrentUserEditsFile,
	|	CASE
	|		WHEN NOT Files.BeingEditedBy IN (&EmptyUsers)
	|				AND Files.BeingEditedBy <> &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AnotherUserEditsFile,
	|	Files.Extension AS Extension,
	|	CASE
	|		WHEN FilesSynchronizationWithCloudServiceStatuses.Account <> UNDEFINED
	|				AND Files.BeingEditedBy = UNDEFINED
	|			THEN FilesSynchronizationWithCloudServiceStatuses.Account
	|		ELSE Files.BeingEditedBy
	|	END AS BeingEditedBy,
	|	Files.BeingEditedBy AS EditedByUser,
	|	&IsFolder AS IsFolder,
	|	Files.FileOwner AS FileOwner,
	|	Files.StoreVersions AS StoreVersions
	|FROM
	|	&CatalogName AS Files
	|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|		ON Files.Ref = FilesSynchronizationWithCloudServiceStatuses.File
	|WHERE
	|	Files.FileOwner = &FilesOwner";
	
	FullCatalogName = "Catalog." + FilesStorageCatalogName;
	QueryText = StrReplace(QueryText, "&CatalogName", FullCatalogName);
	ListProperties.QueryText = StrReplace(QueryText, "&IsFolder",
		?(CanCreateFileGroups, "Files.IsFolder", "FALSE"));
		
	ListProperties.MainTable  = FullCatalogName;
	ListProperties.DynamicDataRead = True;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
	EmptyUsers = New Array;
	EmptyUsers.Add(Undefined);
	EmptyUsers.Add(Catalogs.Users.EmptyRef());
	EmptyUsers.Add(Catalogs.ExternalUsers.EmptyRef());
	EmptyUsers.Add(Catalogs.FileSynchronizationAccounts.EmptyRef());
	
	List.Parameters.SetParameterValue("FilesOwner",      Parameters.FileOwner);
	List.Parameters.SetParameterValue("CurrentUser", Users.AuthorizedUser());
	List.Parameters.SetParameterValue("EmptyUsers",  EmptyUsers);
	
	UniversalDate = CurrentSessionDate();
	List.Parameters.SetParameterValue("SecondsToLocalTime",
		ToLocalTime(UniversalDate, SessionTimeZone()) - UniversalDate);
	
EndProcedure


&AtClientAtServerNoContext
Function GetFormCommandNames()
	
	CommandsNames = GetCommandsNamesOfObjectsChange();
	For Each CommandName In GetSimpleObjectCommandNames() Do
		CommandsNames.Add(CommandName);
	EndDo;
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetCommandsNamesOfObjectsChange()
	
	CommandsNames = New Array;
	
	// Commands that depend on object states
	CommandsNames.Add("EndEdit");
	CommandsNames.Add("Lock");
	CommandsNames.Add("Unlock");
	CommandsNames.Add("Edit");
	CommandsNames.Add("SetDeletionMark");
	CommandsNames.Add("ContextMenuMarkForDeletion");
	
	CommandsNames.Add("Sign");
	CommandsNames.Add("AddDSFromFile");
	CommandsNames.Add("SaveWithDigitalSignature");
	
	CommandsNames.Add("Encrypt");
	CommandsNames.Add("Decrypt");
	
	CommandsNames.Add("Print");
	CommandsNames.Add("PrintWithStamp");
	
	CommandsNames.Add("Send");
	
	CommandsNames.Add("UpdateFromFileOnHardDrive");
	
	// Commands that do not depend on object states
	CommandsNames.Add("Add");
	CommandsNames.Add("AddFromFileOnHardDrive");
	CommandsNames.Add("AppendFileByTemplate");
	CommandsNames.Add("AppendFileFromScanner");
	CommandsNames.Add("OpenFileProperties");
	CommandsNames.Add("Copy");
	CommandsNames.Add("ImportFiles");
	CommandsNames.Add("ImportFolder");
	
	CommandsNames.Add("MoveToGroup");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetSimpleObjectCommandNames()
	
	CommandsNames = New Array;
	
	// Simple commands that are available to any user that reads the files.
	CommandsNames.Add("OpenFileDirectory");
	CommandsNames.Add("OpenFileForViewing");
	CommandsNames.Add("SaveAs");
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Function GetAvailableCommands(CurrentFileData, FilesBeingEditedInCloudService, AbilityToUnlockFile)
	
	CommandsNames = GetFormCommandNames();
	
	CurrentUserEditsFile = CurrentFileData.CurrentUserEditsFile;
	FileBeingEdited                  = CurrentFileData.FileBeingEdited;
	FileSigned                       = CurrentFileData.SignedWithDS;
	FileEncrypted                     = CurrentFileData.Encrypted;
	FileRef                         = CurrentFileData.Ref;
	
	If FileBeingEdited Then
		If CurrentUserEditsFile Then
			DeleteCommandFromArray(CommandsNames, "UpdateFromFileOnHardDrive");
		Else
			DeleteCommandFromArray(CommandsNames, "EndEdit");
			If Not AbilityToUnlockFile Then
				DeleteCommandFromArray(CommandsNames, "Unlock");
			EndIf;
			DeleteCommandFromArray(CommandsNames, "Edit");
		EndIf;
		DeleteCommandFromArray(CommandsNames, "SetDeletionMark");
		DeleteCommandFromArray(CommandsNames, "ContextMenuMarkForDeletion");
		DeleteDSCommands(CommandsNames);
		
		DeleteCommandFromArray(CommandsNames, "UpdateFromFileOnHardDrive");
		DeleteCommandFromArray(CommandsNames, "SaveAs");
		
		DeleteCommandFromArray(CommandsNames, "Encrypt");
		DeleteCommandFromArray(CommandsNames, "Decrypt");
	Else
		DeleteCommandFromArray(CommandsNames, "EndEdit");
		DeleteCommandFromArray(CommandsNames, "Unlock");
	EndIf;
	
	If CurrentFileData.IsFolder Then
		DeleteCommandFromArray(CommandsNames, "Edit");
		DeleteCommandFromArray(CommandsNames, "Sign");
		DeleteCommandFromArray(CommandsNames, "AddDSFromFile");
		DeleteCommandFromArray(CommandsNames, "SaveWithDigitalSignature");
		DeleteCommandFromArray(CommandsNames, "Encrypt");
		DeleteCommandFromArray(CommandsNames, "Decrypt");
		DeleteCommandFromArray(CommandsNames, "UpdateFromFileOnHardDrive");
		DeleteCommandFromArray(CommandsNames, "OpenFileProperties");
		DeleteCommandFromArray(CommandsNames, "Copy");
		DeleteCommandFromArray(CommandsNames, "OpenFileDirectory");
		DeleteCommandFromArray(CommandsNames, "OpenFileForViewing");
		DeleteCommandFromArray(CommandsNames, "SaveAs");
		DeleteCommandFromArray(CommandsNames, "Lock");
		DeleteCommandFromArray(CommandsNames, "Send");
		DeleteCommandFromArray(CommandsNames, "PrintWithStamp");
		DeleteCommandFromArray(CommandsNames, "Print");
	EndIf;
	
	If FileSigned Then
		DeleteCommandFromArray(CommandsNames, "EndEdit");
		DeleteCommandFromArray(CommandsNames, "Unlock");
		DeleteCommandFromArray(CommandsNames, "Edit");
		DeleteCommandFromArray(CommandsNames, "UpdateFromFileOnHardDrive");
	EndIf;
	
	If FileEncrypted Then
		DeleteDSCommands(CommandsNames);
		DeleteCommandFromArray(CommandsNames, "EndEdit");
		DeleteCommandFromArray(CommandsNames, "Unlock");
		DeleteCommandFromArray(CommandsNames, "Edit");
		
		DeleteCommandFromArray(CommandsNames, "UpdateFromFileOnHardDrive");
		
		DeleteCommandFromArray(CommandsNames, "Encrypt");
		
		DeleteCommandFromArray(CommandsNames, "OpenFileDirectory");
		DeleteCommandFromArray(CommandsNames, "OpenFileForViewing");
		DeleteCommandFromArray(CommandsNames, "SaveAs");
	Else
		DeleteCommandFromArray(CommandsNames, "Decrypt");
	EndIf;
	
	If FilesBeingEditedInCloudService Then
		
		DeleteCommandFromArray(CommandsNames, "Add");
		DeleteCommandFromArray(CommandsNames, "AddFromFileOnHardDrive");
		DeleteCommandFromArray(CommandsNames, "AppendFileByTemplate");
		DeleteCommandFromArray(CommandsNames, "AppendFileFromScanner");
		DeleteCommandFromArray(CommandsNames, "Copy");
		
		DeleteCommandFromArray(CommandsNames, "CreateFolder");
		DeleteCommandFromArray(CommandsNames, "MoveToGroup");
		DeleteCommandFromArray(CommandsNames, "SetDeletionMark");
		DeleteCommandFromArray(CommandsNames, "ContextMenuMarkForDeletion");
		DeleteCommandFromArray(CommandsNames, "Lock");
		
		DeleteCommandFromArray(CommandsNames, "ImportFiles");
		DeleteCommandFromArray(CommandsNames, "ImportFolder");
		
	EndIf;
	
	
	Return CommandsNames;
	
EndFunction

&AtClientAtServerNoContext
Procedure DeleteDSCommands(CommandsNames)
	
	DeleteCommandFromArray(CommandsNames, "Sign");
	DeleteCommandFromArray(CommandsNames, "AddDSFromFile");
	DeleteCommandFromArray(CommandsNames, "SaveWithDigitalSignature");
	
EndProcedure

&AtClientAtServerNoContext
Procedure DeleteCommandFromArray(Array, CommandName)
	
	Position = Array.Find(CommandName);
	
	If Position = Undefined Then
		Return;
	EndIf;
	
	Array.Delete(Position);
	
EndProcedure

&AtClient
Procedure SigningOrEncryptionUsageOnChange()
	
	OnChangeUseOfSigningOrEncryptionAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeUseOfSigningOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject);
	
EndProcedure

// Continues Sign and AddDSFromFile procedures execution.
&AtClient
Procedure AddSignaturesCompeltion(Success, Context) Export
	
	If Success = True Then
		SetFileCommandsAvailability();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SavePreviewOption(FileCatalogType, Preview)
	Common.CommonSettingsStorageSave(FileCatalogType, "Preview", Preview);
EndProcedure

&AtServerNoContext
Procedure OnSendFilesViaEmail(SendOptions, Val FilesToSend, FilesOwner, UUID)
	FilesOperationsOverridable.OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID);
EndProcedure

&AtServerNoContext
Procedure SetClearDeletionMark(FileRef)
	FileRef.GetObject().SetDeletionMark(Not FileRef.DeletionMark);
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
	If CurrentData <> Undefined AND PreviewEnabledExtensions.FindByValue(CurrentData.Extension) <> Undefined Then
		
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
	
	If NOT ValueIsFilled(FileDataURL) Then
		Items.FileDataURL.NonselectedPictureText = NonSelectedPictureText;
	EndIf;

EndProcedure

&AtServer
Procedure UpdateCloudServiceNote()
	
	NoteVisibility = False;
	
	If GetFunctionalOption("UseFileSync") Then
		
		SynchronizationInfo = FilesOperationsInternal.SynchronizationInfo(FileOwner.Ref);
		
		If SynchronizationInfo.Count() > 0  Then
			
			FilesBeingEditedInCloudService = True;
			Account = SynchronizationInfo.Account;
			NoteVisibility = True;
			
			FolderAddressInCloudService = FilesOperationsInternalClientServer.AddressInCloudService(
				SynchronizationInfo.Service, SynchronizationInfo.Href);
				
			StringParts = New Array;
			StringParts.Add(NStr("ru = 'Работа с файлами ведется в облачном сервисе'; en = 'File operations are carried out in cloud service'; pl = 'Praca z plikami jest prowadzona w serwisie w chmurze';es_ES = 'Operaciones con archivos se realizan en el servicio de nube';es_CO = 'Operaciones con archivos se realizan en el servicio de nube';tr = 'Dosya yönetimi bulut hizmetinde gerçekleştirilir.';it = 'Le operazioni con i file sono eseguite nel servizio Cloud.';de = 'Die Dateiverwaltung erfolgt im Cloud-Service'"));
			StringParts.Add(" ");
			StringParts.Add(New FormattedString(SynchronizationInfo.AccountDescription,,,, FolderAddressInCloudService));
			StringParts.Add(".  ");
			Items.NoteDecoration.Title = New FormattedString(StringParts);
			
			Items.DecorationPictureSyncStatus.Visible = NOT SynchronizationInfo.Synchronized;
			Items.DecorationSyncDate.ToolTipRepresentation =?(SynchronizationInfo.Synchronized, ToolTipRepresentation.None, ToolTipRepresentation.Button);
			
			StringParts.Clear();
			StringParts.Add(NStr("ru = 'Синхронизировано'; en = 'Synchronized'; pl = 'Synchronizuje się';es_ES = 'Se está sincronizando';es_CO = 'Se está sincronizando';tr = 'Senkronize edildi';it = 'Sincronizzato';de = 'Synchronisiert'"));
			StringParts.Add(": ");
			StringParts.Add(New FormattedString(Format(SynchronizationInfo.SynchronizationDate, "DLF=DD"),,,, "OpenJournal"));
			Items.DecorationSyncDate.Title = New FormattedString(StringParts);
			
		EndIf;
		
	EndIf;
	
	Items.CloudServiceNoteGroup.Visible = NoteVisibility;
	
EndProcedure

&AtServerNoContext
Function EventLogFilterData(Service)
	Return FilesOperationsInternal.EventLogFilterData(Service);
EndFunction

&AtServer
Function SynchronizationSettingsParameters(FileOwner)
	
	FileOwnerType = Common.MetadataObjectID(FileCatalogType);
	
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

&AtClient
Procedure UpdateFileCommandAvailability()
	
	SetFileCommandsAvailability();
	
EndProcedure

#EndRegion
