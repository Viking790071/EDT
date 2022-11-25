#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If CommonClientServer.IsWebClient() Then
		Items.NowInLocalFileCache.Visible = False;
		Items.CleanUpWorkingDirectory.Visible = False;
	EndIf;
	
	FillParametersAtServer();
	
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If NOT FilesOperationsInternalClient.FileSystemExtensionAttached() Then
		StandardSubsystemsClient.SetFormStorage(ThisObject, True);
		AttachIdleHandler("ShowFileSystemExtensionRequiredMessageBox", 0.1, True);
		Cancel = True;
		Return;
	EndIf;
	
	UserWorkingDirectory = FilesOperationsInternalClient.UserWorkingDirectory();
	
	UpdateWorkDirectoryCurrentStatus();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UserWorkDirectoryChoiceStart(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If NOT FilesOperationsInternalClient.FileSystemExtensionAttached() Then
		Return;
	EndIf;
	
	// Selecting a new path to a working directory.
	DirectoryName = UserWorkingDirectory;
	Title = NStr("ru = 'Выберите рабочий каталог'; en = 'Select a working directory'; pl = 'Wybierz katalog roboczy';es_ES = 'Seleccione un catálogo de trabajo';es_CO = 'Seleccione un catálogo de trabajo';tr = 'Çalışma dizini seç';it = 'Seleziona una directory di lavoro';de = 'Wählen Sie ein Arbeitsverzeichnis aus'");
	If Not FilesOperationsInternalClient.ChoosePathToWorkingDirectory(DirectoryName, Title, False) Then
		Return;
	EndIf;
	
	SetNewWorkDirectory(DirectoryName);
	
EndProcedure

&AtClient
Procedure LocalFilesCacheOnChangeMaxSize(Item)
	
	SaveParameters();
	
EndProcedure

&AtClient
Procedure ConfirmOnDeleteFromLocalFIlesCacheOnChange(Item)
	
	SaveParameters();
	
EndProcedure

&AtClient
Procedure DeleteFileFromLocalFilesCacheOnFinishEditOnChange(Item)
	
	If DeleteFileFromLocalFileCacheOnCompleteEdit Then
		Items.ConfirmOnDeleteFilesFromLocalCache.Enabled = True;
	Else
		Items.ConfirmOnDeleteFilesFromLocalCache.Enabled = False;
		ConfirmOnDeleteFilesFromLocalCache                      = False;
	EndIf;
	
	SaveParameters();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ShowFileSystemExtensionRequiredMessageBox()
	
	StandardSubsystemsClient.SetFormStorage(ThisObject, False);
	FilesOperationsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
	
EndProcedure

&AtClient
Procedure FileListExecute()
	
	OpenForm("DataProcessor.FilesOperations.Form.FilesInMainWorkingDirectory", , ThisObject, , , ,
		New NotifyDescription("FilesListClose", ThisObject));
	
EndProcedure

&AtClient
Procedure CleanUpLocalFileCache(Command)
	
	QuestionText =
		NStr("ru = 'Из рабочего каталога будут удалены все файлы,
		           |кроме занятых для редактирования.
		           |
		           |Продолжить?'; 
		           |en = 'All files
		           |except for ones locked for editing will be deleted from the working directory.
		           |
		           |Continue?'; 
		           |pl = 'Z katalogu roboczego zostaną usunięte wszystkie pliki, 
		           |oprócz zajętych do edycji.
		           |
		           |Kontynuować?';
		           |es_ES = 'Del catálogo de trabajo serán eliminados todos los archivos
		           |excepto los que se usan para editar.
		           |
		           |¿Continuar?';
		           |es_CO = 'Del catálogo de trabajo serán eliminados todos los archivos
		           |excepto los que se usan para editar.
		           |
		           |¿Continuar?';
		           |tr = 'Çalışma dizininden, 
		           |düzenleme için kullanılan dosyalar hariç tüm dosyaları silinecektir. 
		           |
		           |Devam etmek istiyor musunuz?';
		           |it = 'Tutti i file
		           |tranne quelli bloccati per la modifica saranno cancellati dalla directory di lavoro.
		           |
		           |Continuare?';
		           |de = 'Alle Dateien werden aus dem Arbeitsverzeichnis gelöscht,
		           |mit Ausnahme der Dateien, die zur Bearbeitung belegt sind.
		           |
		           |Fortsetzen?'");
	Handler = New NotifyDescription("ClearLocalFileCacheCompletionAfterAnswerQuestionContinue", ThisObject);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DefaultPathToWorkingDirectory(Command)
	
	SetNewWorkDirectory(FilesOperationsInternalClient.SelectPathToUserDataDirectory());
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SaveParameters()
	
	StructuresArray = New Array;
	
	Item = New Structure;
	Item.Insert("Object",    "LocalFileCache");
	Item.Insert("Settings", "PathToLocalFileCache");
	Item.Insert("Value",  UserWorkingDirectory);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "LocalFileCache");
	Item.Insert("Settings", "LocalFileCacheMaxSize");
	Item.Insert("Value", LocalFileCacheMaxSize * 1048576);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "LocalFileCache");
	Item.Insert("Settings", "DeleteFileFromLocalFileCacheOnCompleteEdit");
	Item.Insert("Value", DeleteFileFromLocalFileCacheOnCompleteEdit);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "LocalFileCache");
	Item.Insert("Settings", "ConfirmOnDeleteFilesFromLocalCache");
	Item.Insert("Value", ConfirmOnDeleteFilesFromLocalCache);
	StructuresArray.Add(Item);
	
	CommonServerCall.CommonSettingsStorageSaveArray(StructuresArray, True);
	
EndProcedure

&AtClient
Procedure ClearLocalFileCacheCompletionAfterAnswerQuestionContinue(Response, ExecutionParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Handler = New NotifyDescription("ClearLocalFileCacheCompletion", ThisObject);
	// ClearAll = True.
	FilesOperationsInternalClient.CleanUpWorkingDirectory(Handler, WorkingDirectoryFileSize, 0, True);
	
EndProcedure

&AtClient
Procedure ClearLocalFileCacheCompletion(Result, ExecutionParameters) Export
	
	UpdateWorkDirectoryCurrentStatus();
	
	ShowUserNotification(NStr("ru = 'Рабочий каталог'; en = 'Working directory'; pl = 'Katalog roboczy';es_ES = 'Directorio en marcha';es_CO = 'Directorio en marcha';tr = 'Çalışma dizini';it = 'Directory di lavoro';de = 'Arbeitsverzeichnis'"),, NStr("ru = 'Очистка рабочего каталога успешно завершена.'; en = 'Working directory is cleaned up successfully.'; pl = 'Oczyszczenie katalogu roboczego zostało zakończone pomyślnie.';es_ES = 'El catálogo de trabajo se ha terminado con éxito.';es_CO = 'El catálogo de trabajo se ha terminado con éxito.';tr = 'Çalışma dizinini temizleme başarıyla tamamlandı.';it = 'La directory di lavoro è stata pulita con successo.';de = 'Die Reinigung des Arbeitsverzeichnisses ist erfolgreich abgeschlossen.'"));
	
EndProcedure

&AtClient
Procedure FilesListClose(Result, AdditionalParameters) Export
	
	UpdateWorkDirectoryCurrentStatus();
	
EndProcedure

&AtServer
Procedure FillParametersAtServer()
	
	DeleteFileFromLocalFileCacheOnCompleteEdit = Common.CommonSettingsStorageLoad(
		"LocalFileCache", "DeleteFileFromLocalFileCacheOnCompleteEdit");
	
	If DeleteFileFromLocalFileCacheOnCompleteEdit = Undefined Then
		DeleteFileFromLocalFileCacheOnCompleteEdit = False;
	EndIf;
	
	ConfirmOnDeleteFilesFromLocalCache = Common.CommonSettingsStorageLoad(
		"LocalFileCache", "ConfirmOnDeleteFilesFromLocalCache");
	
	If ConfirmOnDeleteFilesFromLocalCache = Undefined Then
		ConfirmOnDeleteFilesFromLocalCache = False;
	EndIf;
	
	MaxSize = Common.CommonSettingsStorageLoad(
		"LocalFileCache", "LocalFileCacheMaxSize");
	
	If MaxSize = Undefined Then
		MaxSize = 100*1024*1024; // 100 MB
		Common.CommonSettingsStorageSave(
			"LocalFileCache", "LocalFileCacheMaxSize", MaxSize);
	EndIf;
	LocalFileCacheMaxSize = MaxSize / 1048576;
	
	If DeleteFileFromLocalFileCacheOnCompleteEdit Then
		Items.ConfirmOnDeleteFilesFromLocalCache.Enabled = True;
	Else
		Items.ConfirmOnDeleteFilesFromLocalCache.Enabled = False;
		ConfirmOnDeleteFilesFromLocalCache                      = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateWorkDirectoryCurrentStatus()
	
#If NOT WebClient Then
	FilesArray = FindFiles(UserWorkingDirectory, "*.*");
	WorkingDirectoryFileSize = 0;
	TotalCount = 0;
	
	FilesOperationsInternalClient.GetFileListSize(
		UserWorkingDirectory,
		FilesArray,
		WorkingDirectoryFileSize,
		TotalCount); 
	
	WorkingDirectoryFileSize = WorkingDirectoryFileSize / 1048576;
#EndIf
	
EndProcedure

&AtClient
Procedure SetNewWorkDirectory(NewDirectory)
	
	If NewDirectory = UserWorkingDirectory Then
		Return;
	EndIf;
	
#If Not WebClient Then
	Handler = New NotifyDescription(
		"SetNewWorkDirectoryCompletion", ThisObject, NewDirectory);
	
	FilesOperationsInternalClient.MoveWorkingDirectoryContent(
		Handler, UserWorkingDirectory, NewDirectory);
#Else
	SetNewWorkDirectoryCompletion(-1, NewDirectory);
#EndIf
	
EndProcedure

&AtClient
Procedure SetNewWorkDirectoryCompletion(Result, NewDirectory) Export
	
	If Result <> -1 Then
		If Result <> True Then
			Return;
		EndIf;
	EndIf;
	
	UserWorkingDirectory = NewDirectory;
	
	SaveParameters();
	
EndProcedure

#EndRegion
