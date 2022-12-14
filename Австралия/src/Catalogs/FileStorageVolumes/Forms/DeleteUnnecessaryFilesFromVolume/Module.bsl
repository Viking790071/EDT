#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Parameters.Property("FileStorageVolume", FileStorageVolume);
	
	FillExcessFilesTable();
	UnnecessaryFilesCount = UnnecessaryFiles.Count();
	
	DateFolder = Format(CurrentSessionDate(), "DF=yyyymmdd") + GetPathSeparator();
	
	CopyFilesBeforeDelete                = False;
	Items.PathToFolderToCopy.Enabled = False;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationDetailsClick(Item)
	
	ReportParameters = New Structure();
	ReportParameters.Insert("GenerateOnOpen", True);
	ReportParameters.Insert("Filter", New Structure("Volume", FileStorageVolume));
	
	OpenForm("Report.VolumeIntegrityCheck.ObjectForm", ReportParameters);
	
EndProcedure

&AtClient
Procedure FolderPathForCopyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CommonClient.ShowFileSystemExtensionInstallationQuestion(New NotifyDescription("AttachFileSystemExtensionSelectFileCompletion", ThisObject), , False);
	
EndProcedure

&AtClient
Procedure AttachFileSystemExtensionSelectFileCompletion(ExtensionAttached, AdditionalParameters) Export
	
	If Not ExtensionAttached Then
		Return;
	EndIf;
	
	Mode = FileDialogMode.ChooseDirectory;
	OpenFileDialog = New FileDialog(Mode);
	OpenFileDialog.FullFileName     = "";
	OpenFileDialog.Directory            = PathToFolderToCopy;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title          = Title;
	
	OpenFileDialog.Show(New NotifyDescription("FolderPathForCopyStartChoiceCompletion", ThisObject, New Structure("OpenFileDialog", OpenFileDialog)));
	
EndProcedure

&AtClient
Procedure FolderPathForCopyStartChoiceCompletion(SelectedFiles, AdditionalParameters) Export
	
	OpenFileDialog = AdditionalParameters.OpenFileDialog;
	
	If SelectedFiles = Undefined Then
		Items.FormDeleteUnnecessaryFiles.Enabled = False;
	Else
		PathToFolderToCopy                     = OpenFileDialog.Directory;
		PathToFolderToCopy                     = CommonClientServer.AddLastPathSeparator(PathToFolderToCopy);
		Items.FormDeleteUnnecessaryFiles.Enabled = ValueIsFilled(PathToFolderToCopy);
	EndIf;

EndProcedure

&AtClient
Procedure DestinationDirectoryOnChange(Item)
	
	PathToFolderToCopy                     = CommonClientServer.AddLastPathSeparator(PathToFolderToCopy);
	Items.FormDeleteUnnecessaryFiles.Enabled = ValueIsFilled(PathToFolderToCopy);
	
EndProcedure

&AtClient
Procedure CopyFilesBeforeDeleteOnChange(Item)
	
	If Not CopyFilesBeforeDelete Then
		PathToFolderToCopy                      = "";
		Items.PathToFolderToCopy.Enabled = False;
		Items.FormDeleteUnnecessaryFiles.Enabled  = True;
	Else
		Items.PathToFolderToCopy.Enabled = True;
		If ValueIsFilled(PathToFolderToCopy) Then
			Items.FormDeleteUnnecessaryFiles.Enabled = True;
		Else
			Items.FormDeleteUnnecessaryFiles.Enabled = False;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeleteUnnecessaryFiles(Command)
	
	If UnnecessaryFilesCount = 0 Then
		ShowMessageBox(, NStr("ru = '?????? ???? ???????????? ?????????????? ?????????? ???? ??????????'; en = 'This disk has no excess files'; pl = 'Nie ma ??adnych zb??dnych plik??w na dysku';es_ES = 'No hay ning??n archivo de sobra en el disco';es_CO = 'No hay ning??n archivo de sobra en el disco';tr = 'Diskte fazla dosya yok';it = 'Questo disco non ha file in eccesso';de = 'Es gibt keine einzige zus??tzliche Datei auf der Festplatte'"));
		Return;
	EndIf;
	
	CommonClient.ShowFileSystemExtensionInstallationQuestion(New NotifyDescription("AttachFileSystemExtensionCompletion", ThisObject), , False);
	
EndProcedure

&AtClient
Procedure AttachFileSystemExtensionCompletion(ExtensionAttached, AdditionalParameters) Export
	
	If Not ExtensionAttached Then
		ShowMessageBox(, NStr("ru = '???????????????????? ???????????? ?? ?????????????? ???? ??????????????????????. ???????????? ?? ?????????????? ?? ?????????????????????????????? ?????????????????????? ?? ?????? ?????????????? ????????????????????.'; en = 'File operation extension is not set. You cannot use files with not set extension in web client.'; pl = 'Rozszerzenie pracy z plikami nie jest zainstalowano. Praca z plikami z nieustalonym rozszerzeniem w web kliencie jest niemo??liwe.';es_ES = 'La extensi??n de operaciones con archivos no est?? establecido. Es imposible usar los archivos con extensiones no especificadas en el cliente web.';es_CO = 'La extensi??n de operaciones con archivos no est?? establecido. Es imposible usar los archivos con extensiones no especificadas en el cliente web.';tr = 'Dosya uzant??s?? y??kl?? de??il. Bir web istemcisinde y??kl?? olmayan bir uzant??ya sahip dosyalarla ??al????mak m??mk??n de??ildir.';it = 'Estensione di operazione file non impostata. Impossibile utilizzare i file senza estensione impostata nel web client.';de = 'Die Dateierweiterung ist nicht installiert. Das Arbeiten mit Dateien mit einer deinstallierten Erweiterung im Webclient ist nicht m??glich.'"));
		Return;
	EndIf;
	
	If Not CopyFilesBeforeDelete Then
		AfterCheckWriteToDirectory(True, New Structure);
	Else
		FolderForCopying = New File(PathToFolderToCopy);
		FolderForCopying.BeginCheckingExistence(New NotifyDescription("FolderExistanceCheckCompletion", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure FolderExistanceCheckCompletion(Exists, AdditionalParameters) Export
	
	If Not Exists Then
		ShowMessageBox(, NStr("ru = '???????? ?? ???????????????? ?????????????????????? ??????????????????????.'; en = 'Path to the directory for copying is incorrect.'; pl = '??cie??ka do folderu kopiowania jest nieprawid??owa.';es_ES = 'Ruta al cat??logo de copiar incorrecta.';es_CO = 'Ruta al cat??logo de copiar incorrecta.';tr = 'Kopya dizini yolu yanl????t??r.';it = 'Il percorso alla directory per la copia non ?? corretto.';de = 'Der Pfad zum Kopierverzeichnis ist falsch.'"));
	Else
		RightToWriteToDirectory(New NotifyDescription("AfterCheckWriteToDirectory", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCheckWriteToDirectory(Result, AdditionalParameters) Export
	
	If Not Result Then
		Return;
	EndIf;
	
	If UnnecessaryFiles.Count() = 0 Then
		Return;
	EndIf;
	
	FinalNotificationParameters = New Structure;
	FinalNotificationParameters.Insert("FilesArrayWithErrors", New Array);
	FinalNotificationParameters.Insert("NumberOfDeletedFiles",  0);
	FinalNotification = New NotifyDescription("AfterProcessFiles", ThisObject, FinalNotificationParameters);
	
	ExecuteNotifyProcessing(New NotifyDescription("ProcessNextFile", ThisObject,
		New Structure("FinalNotification, CurrentFile", FinalNotification, Undefined), "ProcessNextFileError", ThisObject));
	
EndProcedure

&AtClient
Procedure ProcessNextFile(Result, AdditionalParameters) Export
	
	CurrentFile       = AdditionalParameters.CurrentFile;
	LastIteration = False;
	
	If CurrentFile = Undefined Then
		CurrentFile = UnnecessaryFiles.Get(0);
	Else
		
		FileLines        = UnnecessaryFiles.FindRows(New Structure("Name", CurrentFile.Name));
		CurrentFileIndex = UnnecessaryFiles.IndexOf(CurrentFile);
		If CurrentFileIndex = UnnecessaryFiles.Count() - 1 Then
			LastIteration = True;
		Else
			CurrentFile = UnnecessaryFiles.Get(CurrentFileIndex + 1);
		EndIf;
		
	EndIf;
	
	CurrentFileName       = CurrentFile.Name;
	CurrentFileFullName = CurrentFile.FullName;
	DirectoryForCopying  = PathToFolderToCopy + DateFolder + GetPathSeparator();
	
	CurrentFileParameters = New Structure;
	CurrentFileParameters.Insert("FinalNotification",    AdditionalParameters.FinalNotification);
	CurrentFileParameters.Insert("CurrentFile",           CurrentFile);
	CurrentFileParameters.Insert("LastIteration",     LastIteration);
	CurrentFileParameters.Insert("DirectoryForCopying", DirectoryForCopying);
	
	If Not IsBlankString(PathToFolderToCopy) Then
		
		File = New File(CurrentFileFullName);
		File.BeginCheckingExistence(New NotifyDescription("CheckFileExistEnd", ThisObject, CurrentFileParameters));
		
	Else
		
		BeginDeletingFiles(New NotifyDescription("ProcessNextFileDeletionEnd", ThisObject, CurrentFileParameters,
			"ProcessNextFileError", ThisObject), CurrentFileFullName);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFileExistEnd(FileExists, AdditionalParameters) Export
	
	If Not FileExists Then
		ExecuteNotifyProcessing(AdditionalParameters.FinalNotification);
	Else
		CurrentDayDirectory = New File(AdditionalParameters.DirectoryForCopying);
		CurrentDayDirectory.BeginCheckingExistence(New NotifyDescription("DayDirectoryExistEnd", ThisObject, AdditionalParameters));
	EndIf;
	
EndProcedure

&AtClient
Procedure DayDirectoryExistEnd(DirectoryExist, AdditionalParameters) Export
	
	If Not DirectoryExist Then
		BeginCreatingDirectory(New NotifyDescription("CreateDayDirectoryEnd", ThisObject, AdditionalParameters), AdditionalParameters.DirectoryForCopying);
	Else
		FileTargetName = AdditionalParameters.DirectoryForCopying + AdditionalParameters.CurrentFile.Name;
		File = New File(FileTargetName);
		File.BeginCheckingExistence(New NotifyDescription("CheckTargetFileExistEnd", ThisObject, AdditionalParameters));
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateDayDirectoryEnd(DirectoryName, AdditionalParameters) Export
	
	FileTargetName = AdditionalParameters.DirectoryForCopying + AdditionalParameters.CurrentFile.Name;
	File = New File(FileTargetName);
	File.BeginCheckingExistence(New NotifyDescription("CheckTargetFileExistEnd", ThisObject, AdditionalParameters));
	
EndProcedure

&AtClient
Procedure CheckTargetFileExistEnd(FileExists, AdditionalParameters) Export
	
	DirectoryForCopying  = AdditionalParameters.DirectoryForCopying;
	CurrentFileName       = AdditionalParameters.CurrentFile.Name;
	CurrentFileFullName = AdditionalParameters.CurrentFile.FullName;
	
	If Not FileExists Then
		FileTargetName = DirectoryForCopying + CurrentFileName;
	Else
		FileSeparatedName = StrSplit(CurrentFileName, ".");
		NameWithoutExtension    = FileSeparatedName.Get(0);
		Extension          = FileSeparatedName.Get(1);
		FileTargetName    = DirectoryForCopying + NameWithoutExtension + "_" + String(New UUID) + "." + Extension;
	EndIf;
		
	BeginMovingFile(New NotifyDescription("ProcessNextFileMoveEnd", ThisObject, AdditionalParameters,
		"ProcessNextFileError", ThisObject), CurrentFileFullName, FileTargetName);
	
EndProcedure

&AtClient
Procedure ProcessNextFileMoveEnd(Result, AdditionalParameters) Export
	
	ProcessesNextFileEnd(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ProcessNextFileDeletionEnd(AdditionalParameters) Export
	
	ProcessesNextFileEnd(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ProcessesNextFileEnd(AdditionalParameters)
	
	CurrentFile                  = AdditionalParameters.CurrentFile;
	FinalNotification           = AdditionalParameters.FinalNotification;
	FinalNotificationParameters = FinalNotification.AdditionalParameters;
	
	FinalNotificationParameters.Insert("NumberOfDeletedFiles", FinalNotificationParameters.NumberOfDeletedFiles + 1);
	
	If AdditionalParameters.LastIteration Then
		ExecuteNotifyProcessing(FinalNotification);
	Else
		ExecuteNotifyProcessing(New NotifyDescription("ProcessNextFile", ThisObject,
			New Structure("FinalNotification, CurrentFile", FinalNotification, CurrentFile), "ProcessNextFileError", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessNextFileError(ErrorInformation, StandardProcessing, AdditionalParameters) Export
	
	CurrentFile      = AdditionalParameters.CurrentFile;
	CurrentFileName = CurrentFile.Name;
	
	FinalNotification           = AdditionalParameters.FinalNotification;
	FinalNotificationParameters = FinalNotification.AdditionalParameters;
	
	ErrorStructure = New Structure;
	ErrorStructure.Insert("Name",    CurrentFileName);
	ErrorStructure.Insert("Error", BriefErrorDescription(ErrorInformation));
	
	FilesArrayWithErrors = FinalNotificationParameters.FilesArrayWithErrors;
	FilesArrayWithErrors.Add(ErrorStructure);
	FinalNotificationParameters.Insert("FilesArrayWithErrors", FilesArrayWithErrors);
	
	ProcessErrorMessage(CurrentFile.FullName, DetailErrorDescription(ErrorInformation));
	
	If AdditionalParameters.LastIteration Then
		ExecuteNotifyProcessing(FinalNotification);
	Else
		ExecuteNotifyProcessing(New NotifyDescription("ProcessNextFile", ThisObject,
			New Structure("FinalNotification, CurrentFile", FinalNotification, CurrentFile), "ProcessNextFileError", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterProcessFiles(Result, AdditionalParameters) Export
	
	NumberOfDeletedFiles  = AdditionalParameters.NumberOfDeletedFiles;
	FilesArrayWithErrors = AdditionalParameters.FilesArrayWithErrors;
	
	If NumberOfDeletedFiles <> 0 Then
		NotificationText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????????????? ????????????: %1'; en = 'Files removed: %1'; pl = 'Usuni??tych plik??w: %1';es_ES = 'Eliminado archivos: %1';es_CO = 'Eliminado archivos: %1';tr = 'Silinen dosya: %1';it = 'File rimossi: %1';de = 'Gel??schte Dateien: %1'"),
			NumberOfDeletedFiles);
		ShowUserNotification(
			NStr("ru = '?????????????????? ???????????????? ???????????? ????????????.'; en = 'Excess files have been removed.'; pl = 'Zako??czono usuwanie zb??dnych plik??w.';es_ES = 'Se han eliminado los archivos de sobra.';es_CO = 'Se han eliminado los archivos de sobra.';tr = 'Fazla dosya silindi.';it = 'I file in eccesso sono stati rimossi.';de = 'Das L??schen nicht ben??tigter Dateien ist abgeschlossen.'"),
			,
			NotificationText,
			PictureLib.Information32);
	EndIf;
	
	If FilesArrayWithErrors.Count() > 0 Then
		ErrorsReport = New SpreadsheetDocument;
		GenerateErrorsReport(ErrorsReport, FilesArrayWithErrors);
		ErrorsReport.Show();
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillExcessFilesTable()
	
	FilesTableOnHardDrive = New ValueTable;
	TableColumns       = FilesTableOnHardDrive.Columns;
	TableColumns.Add("Name");
	TableColumns.Add("File");
	TableColumns.Add("BaseName");
	TableColumns.Add("FullName");
	TableColumns.Add("Path");
	TableColumns.Add("Volume");
	TableColumns.Add("Extension");
	TableColumns.Add("VerificationStatus");
	TableColumns.Add("Count");
	TableColumns.Add("WasEditedBy");
	TableColumns.Add("EditDate");

	VolumePath = FilesOperationsInternal.FullVolumePath(FileStorageVolume);
	
	FilesArray = FindFiles(VolumePath,"*", True);
	For Each File In FilesArray Do
		
		If Not File.IsFile() Then
			Continue;
		EndIf;
		
		NewRow = FilesTableOnHardDrive.Add();
		NewRow.Name              = File.Name;
		NewRow.BaseName = File.BaseName;
		NewRow.FullName        = File.FullName;
		NewRow.Path             = File.Path;
		NewRow.Extension       = File.Extension;
		NewRow.VerificationStatus   = NStr("ru = '???????????? ?????????? (???????? ???? ??????????, ???? ???????????????? ?? ?????? ??????????????????????)'; en = 'Excess files (they exist on disk but no information on them is available)'; pl = 'Zb??dne pliki (s?? na dysku, ale brakuje o nich informacji)';es_ES = 'Archivos innecesarios (hay en el disco pero no hay informaci??n de ellos)';es_CO = 'Archivos innecesarios (hay en el disco pero no hay informaci??n de ellos)';tr = 'Fazlal??k dosyalar (diskte mevcut, ancak onlar ile ilgili veri yok)';it = 'File in eccesso (esistono sul disco ma non sono disponibili informazioni su di essi)';de = 'Nicht ben??tigte Dateien (es gibt einige auf der Festplatte, aber keine Informationen dar??ber sind verf??gbar)'");
		NewRow.Count       = 1;
		NewRow.Volume              = FileStorageVolume;
		
	EndDo;
	
	FilesOperationsInternal.CheckFilesIntegrity(FilesTableOnHardDrive, FileStorageVolume);
	FilesTableOnHardDrive.Indexes.Add("VerificationStatus");
	ExcessFilesArray = FilesTableOnHardDrive.FindRows(
		New Structure("VerificationStatus", NStr("ru = '???????????? ?????????? (???????? ???? ??????????, ???? ???????????????? ?? ?????? ??????????????????????)'; en = 'Excess files (they exist on disk but no information on them is available)'; pl = 'Zb??dne pliki (s?? na dysku, ale brakuje o nich informacji)';es_ES = 'Archivos innecesarios (hay en el disco pero no hay informaci??n de ellos)';es_CO = 'Archivos innecesarios (hay en el disco pero no hay informaci??n de ellos)';tr = 'Fazlal??k dosyalar (diskte mevcut, ancak onlar ile ilgili veri yok)';it = 'File in eccesso (esistono sul disco ma non sono disponibili informazioni su di essi)';de = 'Nicht ben??tigte Dateien (es gibt einige auf der Festplatte, aber keine Informationen dar??ber sind verf??gbar)'")));
	
	For Each File In ExcessFilesArray Do
		NewRow = UnnecessaryFiles.Add();
		FillPropertyValues(NewRow, File);
	EndDo;
	
	UnnecessaryFiles.Sort("Name");
	
EndProcedure

&AtClient
Procedure RightToWriteToDirectory(SourceNotification)
	
	If IsBlankString(PathToFolderToCopy) Then
		ExecuteNotifyProcessing(SourceNotification, True);
		Return
	EndIf;
	
	DirectoryName = PathToFolderToCopy + "CheckAccess\";
	
	DirectoryDeletionParameters  = New Structure("SourceNotification, DirectoryName", SourceNotification, DirectoryName);
	DirectoryCreationNotification = New NotifyDescription("AfterCreateDirectory", ThisObject, DirectoryDeletionParameters, "AfterDirectoryCreationError", ThisObject);
	BeginCreatingDirectory(DirectoryCreationNotification, DirectoryName);
	
EndProcedure

&AtClient
Procedure AfterDirectoryCreationError(ErrorInformation, StandardProcessing, AdditionalParameters) Export
	
	ProcessAccessRightsError(ErrorInformation, AdditionalParameters.SourceNotification);
	
EndProcedure

&AtClient
Procedure AfterCreateDirectory(Result, AdditionalParameters) Export
	
	BeginDeletingFiles(New NotifyDescription("AfterDeleteDirectory", ThisObject, AdditionalParameters, "AfterDirectoryDeletionError", ThisObject), AdditionalParameters.DirectoryName);
	
EndProcedure

&AtClient
Procedure AfterDeleteDirectory(AdditionalParameters) Export
	
	ExecuteNotifyProcessing(AdditionalParameters.SourceNotification, True);
	
EndProcedure

&AtClient
Procedure AfterDirectoryDeletionError(ErrorInformation, StandardProcessing, AdditionalParameters) Export
	
	ProcessAccessRightsError(ErrorInformation, AdditionalParameters.SourceNotification);
	
EndProcedure

&AtClient
Procedure ProcessAccessRightsError(ErrorInformation, SourceNotification)
	
	ErrorTemplate = NStr("ru = '???????? ???????????????? ?????? ?????????????????????? ??????????????????????.
	|???????????????? ?????????????? ????????????, ???? ???????? ?????????????? ????????????????
	|???????????? 1??:??????????????????????, ???? ?????????? ???????? ?????????????? ?? ???????????????????? ????????????????.
	|
	|%1'; 
	|en = 'Directory path for copying is incorrect. 
	|An account on whose behalf 1C: Enterprise server is running 
	|might not have access rights to the specified directory.
	|
	|%1'; 
	|pl = '??cie??ka katalogu do kopiowania jest nieprawid??owa.
	|By?? mo??e konto, w imieniu kt??rego pracuje
	|serwer 1C:Enterprise, nie posiada praw dost??pu do wskazanego katalogu.
	|
	|%1';
	|es_ES = 'La ruta al cat??logo de copiar no es correcta.
	|Es posible que la cuenta que usa
	|el servidor de 1C:Enterprise no tenga derechos de acceso al cat??logo del tomo.
	|
	|%1';
	|es_CO = 'La ruta al cat??logo de copiar no es correcta.
	|Es posible que la cuenta que usa
	|el servidor de 1C:Enterprise no tenga derechos de acceso al cat??logo del tomo.
	|
	|%1';
	|tr = 'Birim yolu do??ru de??il. 
	|1C:Enterprise sunucusunun 
	|??al????t?????? hesap, disk b??l??m?? dizinine eri??im haklar??na sahip de??ildir. 
	|
	|%1';
	|it = 'Percorso di directory errato per la copiatura. 
	|Un account in base al quale il server di 1C: Enterprise ?? in esecuzione
	|potrebbe non avere i diritti di accesso alla directory indicata.
	|
	|%1';
	|de = 'Der zu kopierende Verzeichnispfad ist falsch.
	|Es ist m??glich, dass das Konto, f??r das der
	|1C:Enterprise Server ausgef??hrt wird, keine Zugriffsrechte f??r das angegebene Verzeichnis hat.
	|
	|%1'");
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, BriefErrorDescription(ErrorInformation));
	CommonClientServer.MessageToUser(ErrorText, , , "PathToFolderToCopy");
	
	ExecuteNotifyProcessing(SourceNotification, False);
	
EndProcedure

&AtServer
Procedure ProcessErrorMessage(FileName, ErrorInformation)
	
	WriteLogEvent(NStr("ru = '??????????.???????????? ???????????????? ???????????? ????????????'; en = 'Files.Cannot delete excess files'; pl = 'Pliki. B????d usuwania zb??dnych plik??w';es_ES = 'Archivos.Error de eliminar los archivos de sobra';es_CO = 'Archivos.Error de eliminar los archivos de sobra';tr = 'Dosyalar. Gereksiz dosyalar?? silme hatas??';it = 'File.Impossibile eliminare file in eccesso';de = 'Dateien.Fehler beim L??schen nicht ben??tigter Dateien'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,,,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????? ???????????????? ?????????? ?? ??????????
				|""%1""
				|???????????????? ????????????:
				|""%2"".'; 
				|en = 'When deleting file from disk
				|""%1""
				|an error occurred:
				|""%2"".'; 
				|pl = 'Podczas usuwania pliku z dysku
				|""%1""
				|zaistnia?? b????d:
				|""%2"".';
				|es_ES = 'Al eliminar el archivo del disco
				|""%1""
				|se ha producido un error:
				|""%2"".';
				|es_CO = 'Al eliminar el archivo del disco
				|""%1""
				|se ha producido un error:
				|""%2"".';
				|tr = 'Bir dosya diskten silindi??inde 
				|""%1""
				|bir hata olu??tu: 
				|""%2"".';
				|it = 'Si ?? verificato un errore 
				|durante l''eliminazione del file dal disco ""%1""
				|:
				|""%2"".';
				|de = 'Beim L??schen einer Datei von der Festplatte
				|""%1""
				|tritt ein Fehler auf:
				|""%2"".'"),
			FileName,
			ErrorInformation));
		
EndProcedure

&AtServer
Procedure GenerateErrorsReport(ErrorsReport, FilesArrayWithErrors)
	
	TabTemplate = Catalogs.FileStorageVolumes.GetTemplate("ReportTemplate");
	
	AreaHeader = TabTemplate.GetArea("Title");
	AreaHeader.Parameters.Details = NStr("ru = '?????????? ?? ????????????????:'; en = 'Files with errors:'; pl = 'Pliki z b????dami:';es_ES = 'Archivos con errores:';es_CO = 'Archivos con errores:';tr = 'Hatal?? dosyalar:';it = 'I file con errori:';de = 'Dateien mit Fehlern:'");
	ErrorsReport.Put(AreaHeader);
	
	AreaRow = TabTemplate.GetArea("Row");
	
	For Each FileWithError In FilesArrayWithErrors Do
		AreaRow.Parameters.Name = FileWithError.Name;
		AreaRow.Parameters.Error = FileWithError.Error;
		ErrorsReport.Put(AreaRow);
	EndDo;
	
EndProcedure

#EndRegion