
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Manager = ExchangePlans[Parameters.Node.Metadata().Name];
	
	SystemInfo = New SystemInfo;
	If Parameters.Node = Manager.ThisNode() Then
		Raise
			NStr("ru = 'Создание начального образа для данного узла невозможно.'; en = 'Initial image cannot be created for this node.'; pl = 'Nie można utworzyć obrazu początkowego dla tego węzła..';es_ES = 'No se puede crear la imagen inicial para este nodo.';es_CO = 'No se puede crear la imagen inicial para este nodo.';tr = 'Bu ünite için ilk resim oluşturulamıyor.';it = 'L''immagine iniziale non può essere creata per questo nodo.';de = 'Es kann kein Basis-Image für diesen Knoten erstellt werden.'");
	Else
		InfobaseType = 0; // file base
		DBMSType = "";
		Node = Parameters.Node;
		CanCreateFileInfobase = True;
		If SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
			CanCreateFileInfobase = False;
		EndIf;
		
		LocaleCodes = GetAvailableLocaleCodes();
		FileModeInfobaseLanguage = Items.Find("FileModeInfobaseLanguage");
		ClientServerModeInfobaseLanguage = Items.Find("ClientServerModeInfobaseLanguage");
		
		For Each Code In LocaleCodes Do
			Presentation = LocaleCodePresentation(Code);
			FileModeInfobaseLanguage.ChoiceList.Add(Code, Presentation);
			ClientServerModeInfobaseLanguage.ChoiceList.Add(Code, Presentation);
		EndDo;
		
		Language = InfoBaseLocaleCode();
		
	EndIf;
	
	HasFilesInVolumes = False;
	
	If FilesOperations.HasFileStorageVolumes() Then
		HasFilesInVolumes = FilesOperationsInternal.HasFilesInVolumes();
	EndIf;
	
	WindowsOSServers = SystemInfo.PlatformType = PlatformType.Windows_x86
				   OR SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	If Common.FileInfobase() Then
		Items.FileInfobaseFullNameLinux.Visible = NOT WindowsOSServers;
		Items.FullFileInfobaseName.Visible = WindowsOSServers;
	EndIf;
	
	If HasFilesInVolumes Then
		If WindowsOSServers Then
			Items.FullFileInfobaseName.AutoMarkIncomplete = True;
			Items.VolumesFilesArchivePath.AutoMarkIncomplete = True;
		Else
			Items.FileInfobaseFullNameLinux.AutoMarkIncomplete = True;
			Items.PathToVolumeFilesArchiveLinux.AutoMarkIncomplete = True;
		EndIf;
	Else
		Items.PathToVolumeFilesArchiveGroup.Visible = False;
	EndIf;
	
	If Not Common.FileInfobase() Then
		Items.VolumesFilesArchivePath.InputHint = NStr("ru = '\\имя сервера\resource\files.zip'; en = '\\server name\resource\files.zip'; pl = '\\server name\resource\files.zip';es_ES = '\\ nombre del servidor\recurso\archivos.zip';es_CO = '\\ nombre del servidor\recurso\archivos.zip';tr = '\\server name\resource\files.zip';it = '\\server name\resource\files.zip';de = '\\ Servername \ Ressource \ Dateien.zip'");
		Items.VolumesFilesArchivePath.ChoiceButton = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.FormPages.CurrentPage = Items.RawData;
	Items.CreateInitialImage.Visible = True;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InfobaseVariantOnChange(Item)
	
	// Switch the parameters page.
	Pages = Items.Find("Pages");
	Pages.CurrentPage = Pages.ChildItems[InfobaseType];
	
	If ThisObject.InfobaseType = 0 Then
		Items.VolumesFilesArchivePath.InputHint = "";
		Items.VolumesFilesArchivePath.ChoiceButton = True;
	Else
		Items.VolumesFilesArchivePath.InputHint = NStr("ru = '\\имя сервера\resource\files.zip'; en = '\\server name\resource\files.zip'; pl = '\\server name\resource\files.zip';es_ES = '\\ nombre del servidor\recurso\archivos.zip';es_CO = '\\ nombre del servidor\recurso\archivos.zip';tr = '\\server name\resource\files.zip';it = '\\server name\resource\files.zip';de = '\\ Servername \ Ressource \ Dateien.zip'");
		Items.VolumesFilesArchivePath.ChoiceButton = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure PathToVolumeFilesArchiveStartChoice(Item, ChoiceData, StandardProcessing)
	
	SaveFileHandler(
		Item,
		"WindowsVolumesFilesArchivePath",
		StandardProcessing,
		"files.zip",
		"Archives zip(*.zip)|*.zip");
	
EndProcedure

&AtClient
Procedure FileInfobaseFullNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SaveFileHandler(
		Item,
		"FullWindowsFileInfobaseName",
		StandardProcessing,
		"1Cv8.1CD",
		"Any file(*.*)|*.*");
	
EndProcedure

&AtClient
Procedure FileBaseFullNameOnChange(Item)
	
	FullWindowsFileInfobaseName = TrimAll(FullWindowsFileInfobaseName);
	PathStructure = CommonClientServer.ParseFullFileName(FullWindowsFileInfobaseName);
	If NOT IsBlankString(PathStructure.Path) Then
		PathToFile = PathStructure.Path;
		If IsBlankString(PathStructure.Extension) Then
			PathToFile = PathStructure.FullName;
			FullWindowsFileInfobaseName = CommonClientServer.AddLastPathSeparator(PathStructure.FullName);
			FullWindowsFileInfobaseName = FullWindowsFileInfobaseName + "1Cv8.1CD";
		EndIf;
		
		DirectoriesArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(PathToFile, "\", True);
		FullPath = "";
		
		If Not CommonClientServer.IsWebClient()
			AND DirectoriesArray.Count() > 0 Then
			File = New File(DirectoriesArray[0]);
			
			CurrentArray = New Array;
			CurrentArray.Add(DirectoriesArray[0]);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("FullPath", File.FullName);
			AdditionalParameters.Insert("DirectoriesArray",
				CommonClientServer.ArraysDifference(DirectoriesArray, CurrentArray));

			Notification = New NotifyDescription("ExistenceCheckFileBaseFullNameCompletion", ThisObject, AdditionalParameters);
			File.BeginCheckingExistence(Notification);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateInitialImage(Command)
	
	ClearMessages();
	If InfobaseType = 0 AND NOT CanCreateFileInfobase Then
		
		Raise
			NStr("ru = 'Создание начального образа файловой информационной базы
			           |на данной платформе не поддерживается.'; 
			           |en = 'Creating initial image of the file infobase is not supported
			           |on this platform.'; 
			           |pl = 'Tworzenie obrazu początkowego
			           |bazy informacyjnej nie jest obsługiwane na tej platformie.';
			           |es_ES = 'Creación de la imagen inicial de la
			           |infobase de archivos no se admite en esta plataforma.';
			           |es_CO = 'Creación de la imagen inicial de la
			           |infobase de archivos no se admite en esta plataforma.';
			           |tr = 'Bu platformda veritabanı dosyasının 
			           |ilk resminin oluşturulması desteklenmemektedir.';
			           |it = 'Creazione immagine iniziale dell''infobase del file non supportata
			           |su questa piattaforma.';
			           |de = 'Die Erstellung des Basis-Image der
			           |Dateiinfobase wird auf dieser Plattform nicht unterstützt.'");
	Else
		ProgressPercent = 0;
		ProgressAdditionalInformation = "";
		JobParameters = New Structure;
		JobParameters.Insert("Node", Node);
		JobParameters.Insert("WindowsVolumesFilesArchivePath", WindowsVolumesFilesArchivePath);
		JobParameters.Insert("PathToVolumeFilesArchiveLinux", PathToVolumeFilesArchiveLinux);
		
		If InfobaseType = 0 Then
			// File initial image.
			JobParameters.Insert("UUIDOfForm", UUID);
			JobParameters.Insert("Language", Language);
			JobParameters.Insert("FullWindowsFileInfobaseName", FullWindowsFileInfobaseName);
			JobParameters.Insert("FileInfobaseFullNameLinux", FileInfobaseFullNameLinux);
			JobParameters.Insert("JobDescription", NStr("ru = 'Создание файлового начального образа'; en = 'Create initial file image'; pl = 'Tworzenie plikowego obrazu początkowego';es_ES = 'Crear una imagen inicial de archivo';es_CO = 'Crear una imagen inicial de archivo';tr = 'Dosya başlangıç görüntüsü oluşturma';it = 'Crea immagine iniziale del file';de = 'Erstellen eines Datei-Startimages'"));
			JobParameters.Insert("ProcedureDescription", "FilesOperationsInternal.CreateFileInitialImageAtServer");
		Else
			// Server initial image.
			ConnectionString =
				"Srvr="""       + Server + """;"
				+ "Ref="""      + InfobaseName + """;"
				+ "DBMS="""     + DBMSType + """;"
				+ "DBSrvr="""   + DatabaseServer + """;"
				+ "DB="""       + DatabaseName + """;"
				+ "DBUID="""    + DatabaseUser + """;"
				+ "DBPwd="""    + UserPassword + """;"
				+ "SQLYOffs=""" + Format(DateOffset, "NG=") + """;"
				+ "Locale="""   + Language + """;"
				+ "SchJobDn=""" + ?(SetScheduledJobLock, "Y", "N") + """;";
			
			JobParameters.Insert("ConnectionString", ConnectionString);
			JobParameters.Insert("JobDescription", NStr("ru = 'Создание серверного начального образа'; en = 'Create initial server image'; pl = 'Tworzenie serwerowego obrazu początkowego';es_ES = 'Crear una imagen inicial de servidor';es_CO = 'Crear una imagen inicial de servidor';tr = 'Sunucu tabanlı ilk görüntü oluşturma';it = 'Crea immagine iniziale del server';de = 'Erstellen eines Server-Startimages'"));
			JobParameters.Insert("ProcedureDescription", "FilesOperationsInternal.CreateServerInitialImageAtServer");
		EndIf;
		Result = PrepareDataToCreateInitialImage(JobParameters, InfobaseType);
		If TypeOf(Result) = Type("Structure") Then
			If Result.DataReady Then
				JobParametersAddress = PutToTempStorage(JobParameters, UUID);
				NotifyDescription = New NotifyDescription("RunCreateInitialImage", ThisObject);
				If Result.ConfirmationRequired Then
					ShowQueryBox(NotifyDescription, Result.QuestionText, QuestionDialogMode.YesNo);
				Else
					ExecuteNotifyProcessing(NotifyDescription, DialogReturnCode.Yes);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ExistenceCheckFileBaseFullNameCompletion(Exists, AdditionalParameters) Export
	
	If Not Exists Then
		Notification = New NotifyDescription("CreateDirectoryCompletion", ThisObject, AdditionalParameters);
		BeginCreatingDirectory(Notification, AdditionalParameters.FullPath);
		Return;
	EndIf;
	
	ContinueExistenceCheckFileBaseFullName(AdditionalParameters.FullPath,
		AdditionalParameters.DirectoriesArray);
	
EndProcedure

&AtClient
Procedure ContinueExistenceCheckFileBaseFullName(FullPath, DirectoriesArray)
	If DirectoriesArray.Count() = 0 Then
		Return;
	EndIf;
	
	File = New File(FullPath + "\" + DirectoriesArray[0]);
			
	CurrentArray = New Array;
	CurrentArray.Add(DirectoriesArray[0]);
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("FullPath", File.FullName);
	NotificationParameters.Insert("DirectoriesArray",
		CommonClientServer.ArraysDifference(DirectoriesArray, CurrentArray));
	
	Notification = New NotifyDescription("ExistenceCheckFileBaseFullNameCompletion", ThisObject, NotificationParameters);
	File.BeginCheckingExistence(Notification);
EndProcedure

&AtClient
Procedure CreateDirectoryCompletion(DirectoryName, AdditionalParameters) Export
	
	ContinueExistenceCheckFileBaseFullName(DirectoryName, AdditionalParameters.DirectoriesArray);
	
EndProcedure

&AtClient
Procedure SaveFileHandler(Item,
	                                PropertyName,
                                    StandardProcessing,
                                    FileName,
                                    Filter = "")
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item",     Item);
	AdditionalParameters.Insert("PropertyName", PropertyName);
	AdditionalParameters.Insert("FileName",    FileName);
	AdditionalParameters.Insert("Filter",      Filter);
	
	NotificationOfAttachingFilesOperationsExtension = New NotifyDescription(
		"FileSaveHandlerAfterAttachFilesOperationsExtension",
		ThisObject, AdditionalParameters);
	
	BeginAttachingFileSystemExtension(NotificationOfAttachingFilesOperationsExtension);
	
EndProcedure

&AtClient
Procedure FileSaveHandlerAfterAttachFilesOperationsExtension(Attached, AdditionalParameters) Export
	
	If Not Attached Then
		FilesOperationsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Save);
	
	Dialog.Title                = NStr("ru = 'Выберите файл для сохранения'; en = 'Select file to download'; pl = 'Wybierz plik, który chcesz zapisać';es_ES = 'Seleccione un archivo para guardar';es_CO = 'Seleccione un archivo para guardar';tr = 'Kaydedilecek dosyayı seçin';it = 'Seleziona file da scaricare';de = 'Wählen Sie eine Datei zum Speichern aus'");
	Dialog.Multiselect       = False;
	Dialog.Preview  = False;
	Dialog.Filter                   = AdditionalParameters.Filter;
	Dialog.FullFileName           =
		?(ThisObject[AdditionalParameters.PropertyName] = "",
		AdditionalParameters.FileName,
		ThisObject[AdditionalParameters.PropertyName]);
	
	ChoiceDialogNotifyDescription = New NotifyDescription(
		"FileSaveHandlerAfterChoiceInDialog",
		ThisObject, AdditionalParameters);
	Dialog.Show(ChoiceDialogNotifyDescription);
	
EndProcedure

&AtClient
Procedure FileSaveHandlerAfterChoiceInDialog(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined
		AND SelectedFiles.Count() = 1 Then
		
		ThisObject[AdditionalParameters.PropertyName] = SelectedFiles[0];
		If AdditionalParameters.Item = Items.FullFileInfobaseName Then
			FileBaseFullNameOnChange(AdditionalParameters.Item);
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PrepareDataToCreateInitialImage(JobParameters, InfobaseType)
	
	// Writing the parameters of attaching node to constant.
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		Cancel = False;
		
		DataExchangeCreationWizard = DataProcessors["DataExchangeCreationWizard"].Create();
		DataExchangeCreationWizard.Initializing(JobParameters.Node);
		
		Try
			DataProcessors["DataExchangeCreationWizard"].ExportConnectionSettingsForSubordinateDIBNode(
				DataExchangeCreationWizard);
		Except
			Cancel = True;
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			
			WriteLogEvent(NStr("ru = 'Обмен данными'; en = 'Data exchange'; pl = 'Wymiana danych';es_ES = 'Intercambio de datos';es_CO = 'Intercambio de datos';tr = 'Veri değişimi';it = 'Scambio dati';de = 'Datenaustausch'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If Cancel Then
			Return Undefined;
		EndIf;
		
	EndIf;
	
	If InfobaseType = 0 Then
		// File initial image.
		// Function of processing, checking and preparing parameters.
		Result = FilesOperationsInternal.PrepareDataToCreateFileInitialImage(JobParameters);
	Else
		// Server initial image.
		// Function of processing, checking and preparing parameters.
		Result = FilesOperationsInternal.PrepareDataToCreateServerInitialImage(JobParameters);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure RunCreateInitialImage(Result, Context) Export
	
	If Result = DialogReturnCode.Yes Then
		ProgressPercent = 0;
		ProgressAdditionalInformation = "";
		GoToWaitPage();
		AttachIdleHandler("StartInitialImageCreation", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure StartInitialImageCreation()
	
	Result = CreateInitialImageAtServer(InfobaseType);
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Running" Then
		CompletionNotification = New NotifyDescription("CreateInitialImageAtServerCompletion", ThisObject);
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		IdleParameters.OutputProgressBar = True;
		IdleParameters.ExecutionProgressNotification = New NotifyDescription("CreateInitialImageAtServerProgress", ThisObject);;
		TimeConsumingOperationsClient.WaitForCompletion(Result, CompletionNotification, IdleParameters);
	ElsIf Result.Status = "Completed" Then
		GoToWaitPage();
		ProgressPercent = 100;
		ProgressAdditionalInformation = "";
		// Go to the page with the result with a 1 sec delay.
		AttachIdleHandler("ExecuteGoResult", 1, True);
	Else
		Raise NStr("ru = 'Не удалось создать начальный образ по причине:'; en = 'Cannot create an initial image due to:'; pl = 'Tworzenie obrazu początkowego nie powiodło się z powodu:';es_ES = 'No se ha podido crear una imagen inicial a causa de:';es_CO = 'No se ha podido crear una imagen inicial a causa de:';tr = 'İlk görüntü aşağıdaki nedenle oluşturulamadı:';it = 'Non è possibile creare una immagine iniziale a causa di:';de = 'Fehler beim Erstellen des Basis-Images aufgrund von:'") + " " + Result.BriefErrorPresentation; 
	EndIf;

EndProcedure

&AtClient
Procedure GoToWaitPage()
	Items.FormPages.CurrentPage = Items.InitialImageCreationWaiting;
	Items.CreateInitialImage.Visible = False;
EndProcedure

&AtServer
Function CreateInitialImageAtServer(Val Action)
	
	If IsTempStorageURL(JobParametersAddress) Then
		JobParameters = GetFromTempStorage(JobParametersAddress);
		If TypeOf(JobParameters) = Type("Structure") Then
			// Starting background job.
			ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
			ExecutionParameters.BackgroundJobDescription = JobParameters.JobDescription;
			
			Return TimeConsumingOperations.ExecuteInBackground(JobParameters.ProcedureDescription, JobParameters, ExecutionParameters);
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Procedure CreateInitialImageAtServerCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		ProgressPercent = 0;
		ProgressAdditionalInformation = NStr("ru = 'Действие отменено администратором.'; en = 'Action is canceled by administrator'; pl = 'Działanie zostało anulowane przez administratora.';es_ES = 'Acción cancelada por administrador.';es_CO = 'Acción cancelada por administrador.';tr = 'Eylem yönetici tarafından iptal edildi';it = 'L''azione è stata cancellata dall''amministratore';de = 'Die Aktion wurde vom Administrator abgebrochen.'");
		ExecuteGoResult();
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		ProgressPercent = 0;
		Items.StatusDone.Title = NStr("ru = 'Не удалось создать начальный образ по причине:'; en = 'Cannot create an initial image due to:'; pl = 'Tworzenie obrazu początkowego nie powiodło się z powodu:';es_ES = 'No se ha podido crear una imagen inicial a causa de:';es_CO = 'No se ha podido crear una imagen inicial a causa de:';tr = 'İlk görüntü aşağıdaki nedenle oluşturulamadı:';it = 'Non è possibile creare una immagine iniziale a causa di:';de = 'Fehler beim Erstellen des Basis-Images aufgrund von:'") + " " + Result.BriefErrorPresentation;
		ExecuteGoResult();
		Return;
	EndIf;
	
	ProgressPercent = 100;
	ProgressAdditionalInformation = "";
	ExecuteGoResult();
	
EndProcedure

&AtClient
Procedure CreateInitialImageAtServerProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	If Progress.Progress <> Undefined Then
		ProgressStructure = Progress.Progress;
		ProgressPercent = ProgressStructure.Percent;
		ProgressAdditionalInformation = ProgressStructure.Text;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoResult()
	Items.FormPages.CurrentPage = Items.Result;
	Items.CreateInitialImage.Visible = False;
	
	If ProgressPercent = 100 Then
		CompleteInitialImageCreation(Node);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CompleteInitialImageCreation(ExchangeNode)
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.CompleteInitialImageCreation(ExchangeNode);
	EndIf;
	
EndProcedure

#EndRegion
