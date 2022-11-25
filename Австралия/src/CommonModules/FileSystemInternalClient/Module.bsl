///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

#Region FilesImportFromFileSystem

// The procedure that follows FileSystemClient.ShowPutFile.
Procedure ShowPutFileOnAttachFileSystemExtension(ExtensionAttached, Context) Export
	
	Dialog               = Context.Dialog;
	Interactively         = Context.Interactively;
	FilesToUpload     = Context.FilesToUpload;
	FormID   = Context.FormID;
	CompletionHandler = Context.CompletionHandler;
	
	ProcessingResultsParameters = New Structure;
	ProcessingResultsParameters.Insert("MultipleChoice",   Dialog.Multiselect);
	ProcessingResultsParameters.Insert("CompletionHandler", CompletionHandler);
	
	If Not ExtensionAttached
		AND Not Interactively Then
		Raise NStr("ru = 'Невозможно загрузить файл без установленного расширения работы с файлами.'; en = 'Cannot upload the file because the file system extension is not installed.'; pl = 'Nie można przesłać pliku ponieważ rozszerzenie systemu plików nie jest zainstalowane.';es_ES = 'No se puede cargar el archivo porque la extensión del sistema de archivos no está instalada.';es_CO = 'No se puede cargar el archivo porque la extensión del sistema de archivos no está instalada.';tr = 'Dosya sistem uzantısı yüklenmediğinden dosya karşıya yüklenemiyor.';it = 'Impossibile caricare il file poiché l''estensione del file di sistema non è installata.';de = 'Die Datei kann nicht hochgeladen werden, da die Dateisystemerweiterung nicht installiert ist.'");
	EndIf;
	
	If Dialog.Multiselect Then
		
		FilesToPut = ?(Interactively, Dialog, FilesToUpload);
		NotifyDescription = New NotifyDescription(
			"ProcessPutFilesResult", ThisObject, ProcessingResultsParameters);
		
		If ValueIsFilled(FormID) Then
			BeginPuttingFiles(NotifyDescription, FilesToPut, Interactively,
				FormID, Context.AcrtionBeforeStartPutFiles);
		Else
			BeginPuttingFiles(NotifyDescription, FilesToPut, Interactively, ,
				Context.AcrtionBeforeStartPutFiles);
		EndIf;
		
	Else
		
		FileToPut = ?(Interactively, Dialog, FilesToUpload.Name);
		NotifyDescription = New NotifyDescription(
			"ProcessPutFileResult", ThisObject, ProcessingResultsParameters);
			
		If ValueIsFilled(FormID) Then
			BeginPutFile(NotifyDescription, FilesToUpload.Location, FileToPut,
				Interactively, FormID, Context.AcrtionBeforeStartPutFiles);
		Else
			BeginPutFile(NotifyDescription, FilesToUpload.Location, FileToPut,
				Interactively, , Context.AcrtionBeforeStartPutFiles);
		EndIf;
		
	EndIf;
	
EndProcedure

// Putting files completion.
Procedure ProcessPutFilesResult(FilesThatWerePut, ProcessingResultsParameters) Export
	
	ProcessPutFileResult(FilesThatWerePut <> Undefined, FilesThatWerePut, Undefined,
		ProcessingResultsParameters);
	
EndProcedure

// Putting file completion.
Procedure ProcessPutFileResult(SelectionDone, AddressOrSelectionResult, SelectedFileName,
		ProcessingResultsParameters) Export
	
	If SelectionDone = True Then
		
		If TypeOf(AddressOrSelectionResult) = Type("Array") Then
			
			FilesThatWerePut = New Array;
			For Each FileToPut In AddressOrSelectionResult Do
				
				FileProperties = New Structure("Name, FullName, Location");
				FillPropertyValues(FileProperties, FileToPut);
				
				FileProperties.Insert("FileName", FileToPut.Name);
				If Not IsBlankString(FileToPut.FullName) Then
					FileProperties.Name = FileToPut.FullName;
				EndIf;
				
				FilesThatWerePut.Add(FileProperties);
				
			EndDo;
			
		Else
			
			FilesThatWerePut = New Structure;
			FilesThatWerePut.Insert("Location", AddressOrSelectionResult);
			FilesThatWerePut.Insert("Name",      SelectedFileName);
			
		EndIf;
		
	Else
		FilesThatWerePut = Undefined;
	EndIf;
	
	ExecuteNotifyProcessing(ProcessingResultsParameters.CompletionHandler, FilesThatWerePut);
	
EndProcedure

#EndRegion

#Region ModifiesStoredDataToFileSystem

// The procedure that follows FileSystemClient.ShowDownloadFiles procedure.
Procedure ShowDownloadFilesOnAttachFileSystemExtension(ExtensionAttached, Context) Export
	
	If ExtensionAttached Then
		
		If Context.Interactively Then
			ShowDownloadFilesToDirectory(Context);
		ElsIf Not IsBlankString(Context.Dialog.Directory)Then
			Context.Dialog = Context.Dialog.Directory;
			ShowDownloadFilesToDirectory(Context);
		Else
			
			DirectoryReceiptNotification = New NotifyDescription(
				"ShowDownloadFilesAfterGetTempFilesDirectory", ThisObject, Context);
			BeginGettingTempFilesDir(DirectoryReceiptNotification);
				
		EndIf;
		
	Else
		
		For Each FileToReceive In Context.FilesToGet Do
			GetFile(FileToReceive.Location, FileToReceive.Name, True);
		EndDo;
		
		If Context.CompletionHandler <> Undefined Then
			ExecuteNotifyProcessing(Context.CompletionHandler, Undefined);
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure that follows FileSystemClient.ShowDownloadFiles procedure.
Procedure ShowDownloadFilesAfterGetTempFilesDirectory(TemporaryFileDirectoryName, Context) Export
	
	Context.Dialog = TemporaryFileDirectoryName;
	ShowDownloadFilesToDirectory(Context);
	
EndProcedure

// The procedure that follows FileSystemClient.ShowDownloadFiles procedure.
Procedure ShowDownloadFilesToDirectory(Context)
	
	CompletionNotification = New NotifyDescription("NotifyGetFilesCompletion", ThisObject, Context);
	BeginGettingFiles(CompletionNotification, Context.FilesToGet,
		Context.Dialog, Context.Interactively);
	
EndProcedure

// The procedure that follows FileSystemClient.ShowDownloadFiles procedure.
Procedure NotifyGetFilesCompletion(ReceivedFiles, AdditionalParameters) Export
	
	If AdditionalParameters.CompletionHandler <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.CompletionHandler, ReceivedFiles);
	EndIf;
	
EndProcedure

#EndRegion

#Region OpeningFiles

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileAfterSaving(SavedFiles, OpeningParameters) Export
	
	If SavedFiles = Undefined Then
		ExecuteNotifyProcessing(OpeningParameters.CompletionHandler, False);
	Else
		
		FileDetails = 
			?(TypeOf(SavedFiles) = Type("Array"), 
				SavedFiles[0], 
				SavedFiles);
		
		OpeningParameters.Insert("PathToFile", FileDetails.FullName);
		CompletionHandler = New NotifyDescription(
			"OpenFileAfterEditingCompletion", ThisObject, OpeningParameters);
		
		OpenFileInViewer(FileDetails.FullName, CompletionHandler, OpeningParameters.ForEditing);
		
	EndIf;
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
// Opens the file in the application associated with the file type.
// Prevents executable files from opening.
//
// Parameters:
//  PathToFile        - String - the full path to the file to open.
//  Notification - NotifyDescription - notification on file open attempt.
//                    If the notification is not specified and an error occurs, the method shows a warning.
//   - ApplicationStarted      - Boolean - True if the external application opened successfully.
//   - AdditionalParameters - Arbitrary - a value that was specified when creating the NotifyDescription object.
//  ForEditing - Boolean - True to open the file for editing, False otherwise.
//  
// Example:
//  CommonUseClient.OpenFileInViewer(DocumentsDir() + "test.pdf");
//  CommonUseClient.OpenFileInViewer(DocumentsDir() + "test.xlsx");
//
Procedure OpenFileInViewer(FilePath, Val Notification = Undefined,
		Val ForEditing = False)
	
	FileInfo = New File(FilePath);
	
	Context = New Structure;
	Context.Insert("FileInfo",          FileInfo);
	Context.Insert("Notification",        Notification);
	Context.Insert("ForEditing", ForEditing);
	
	Notification = New NotifyDescription(
		"OpenFileInViewerAfterCheckFileSystemExtension", ThisObject, Context);
	
	SuggestionText = NStr("ru = 'Для открытия файла необходимо установить расширение для работы с 1С:Предприятием.'; en = 'To open the file, install 1C:Enterprise Extension.'; pl = 'Aby otworzyć plik, zainstaluj 1C:Enterprise Extension.';es_ES = 'Para abrir el archivo, instale 1C:Enterprise Extension.';es_CO = 'Para abrir el archivo, instale 1C:Enterprise Extension.';tr = 'Dosyayı açmak için 1C:Enterprise Extension yükleyin.';it = 'Per aprire il file, installare 1C:Enterprise Extension.';de = 'Um die Datei zu öffnen, installieren Sie die 1C:Enterprise Extension.'");
	FileSystemClient.AttachFileOperationsExtension(Notification, SuggestionText, False);
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileInViewerAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	FileInfo = Context.FileInfo;
	If ExtensionAttached Then
		
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterCheckIfExists", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		FileInfo.BeginCheckingExistence(Notification);
		
	Else
		
		ErrorDescription = NStr("ru = 'Не установлено расширение для работы с 1С:Предприятием, открытие файла недоступно.'; en = 'Cannot open the file because 1C:Enterprise Extension is not installed.'; pl = 'Nie można otworzyć pliku ponieważ nie zainstalowano rozszerzenia 1C:Enterprise Extension.';es_ES = 'No se puede abrir el archivo porque 1C:Enterprise Extension no está instalada.';es_CO = 'No se puede abrir el archivo porque 1C:Enterprise Extension no está instalada.';tr = '1C:Enterprise Extension yüklü olmadığı için dosya açılamıyor.';it = 'Impossibile aprire il file poiché 1C:Enterprise Extension non è installato.';de = 'Kann die Datei nicht öffnen, denn 1C:Enterprise Extension ist nicht installiert.'");
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
		
	EndIf;
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileInViewerAfterCheckIfExists(Exists, Context) Export
	
	FileInfo = Context.FileInfo;
	If Exists Then
		 
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterCheckIsFIle", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		FileInfo.BeginCheckingIsFile(Notification);
		
	Else 
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не найден файл, который требуется открыть:
			           |%1.'; 
			           |en = 'Cannot find the file to open:
			           |%1.'; 
			           |pl = 'Nie można znaleźć pliku, który trzeba otworzyć:
			           |%1.';
			           |es_ES = 'No se ha encontrado archivo que se requiere abrir:
			           |%1.';
			           |es_CO = 'No se ha encontrado archivo que se requiere abrir:
			           |%1.';
			           |tr = 'Açılacak dosya bulunamadı:
			           |%1.';
			           |it = 'Impossibile trovare il file da aprire: 
			           |%1.';
			           |de = 'Kann die zu öffnende Datei nicht finden:
			           |%1.'"),
			FileInfo.FullName);
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
		
	EndIf;
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileInViewerAfterCheckIsFIle(IsFile, Context) Export
	
	// ACC:534-off safe start methods are provided with this function
	
	FileInfo = Context.FileInfo;
	If IsFile Then
		
		If IsBlankString(FileInfo.Extension) Then 
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Имя файла не содержит расширения:
				           |%1.'; 
				           |en = 'The file name is missing extension:
				           |%1.'; 
				           |pl = 'Nazwa pliku nie zawiera rozszerzenia:
				           |%1.';
				           |es_ES = 'Al nombre del archivo le falta la extensión:
				           |%1.';
				           |es_CO = 'Al nombre del archivo le falta la extensión:
				           |%1.';
				           |tr = 'Dosya adında uzantı eksik:
				           |%1.';
				           |it = 'Il nome del file non presenta estensione: 
				           |%1.';
				           |de = 'Der Dateiname enthält keine Erweiterung:
				           |%1.'"),
				FileInfo.FullName);
			
			OpenFileInViewerNotifyOnError(ErrorDescription, Context);
			Return;
			
		EndIf;
		
		If IsExecutableFileExtension(FileInfo.Extension) Then 
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Исполняемые файлы открывать запрещено:
				           |%1.'; 
				           |en = 'Opening executable files is disabled:
				           |%1.'; 
				           |pl = 'Otwieranie Opening wykonywalnych plików jest wyłączone:
				           |%1.';
				           |es_ES = 'Se ha desactivado la apertura de archivos ejecutables:
				           |%1.';
				           |es_CO = 'Se ha desactivado la apertura de archivos ejecutables:
				           |%1.';
				           |tr = 'Yürütülebilir dosyaların açılması devre dışı bırakıldı:
				           |%1.';
				           |it = 'L''apertura di file eseguibili è disattivata: 
				           |%1.';
				           |de = 'Öffnen von ausführbaren Dateien ist deaktiviert:
				           |%1.'"),
				FileInfo.FullName);
			
			OpenFileInViewerNotifyOnError(ErrorDescription, Context);
			Return;
			
		EndIf;
		
		Notification          = Context.Notification;
		WaitForCompletion = Context.ForEditing;
		
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterStartApplication", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		BeginRunningApplication(Notification, FileInfo.FullName,, WaitForCompletion);
		
	Else 
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не найден файл, который требуется открыть:
			           |%1.'; 
			           |en = 'Cannot find the file to open:
			           |%1.'; 
			           |pl = 'Nie można znaleźć pliku, który trzeba otworzyć:
			           |%1.';
			           |es_ES = 'No se ha encontrado archivo que se requiere abrir:
			           |%1.';
			           |es_CO = 'No se ha encontrado archivo que se requiere abrir:
			           |%1.';
			           |tr = 'Açılacak dosya bulunamadı:
			           |%1.';
			           |it = 'Impossibile trovare il file da aprire: 
			           |%1.';
			           |de = 'Kann die zu öffnende Datei nicht finden:
			           |%1.'"),
			FileInfo.FullName);
			
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
		
	EndIf;
	
	// ACC:534-on
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileInViewerAfterStartApplication(ReturnCode, Context) Export 
	
	Notification = Context.Notification;
	
	If Notification <> Undefined Then 
		ApplicationStarted = (ReturnCode = 0);
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileInViewerOnProcessError(ErrorInformation, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	OpenFileInViewerNotifyOnError("", Context);
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileAfterEditingCompletion(ApplicationStarted, OpeningParameters) Export
	
	If ApplicationStarted
		AND OpeningParameters.Property("AddressOfBinaryDataToUpdate") Then
		
		Notification = New NotifyDescription(
			"OpenFileAfterDataUpdateInStorage", ThisObject, OpeningParameters);
			
		BeginPutFile(Notification, OpeningParameters.AddressOfBinaryDataToUpdate,
			OpeningParameters.PathToFile, False);
		
	Else
		ExecuteNotifyProcessing(OpeningParameters.CompletionHandler, ApplicationStarted);
	EndIf;
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileAfterDataUpdateInStorage(IsDataUpdated, DataAddress, FileName,
		OpeningParameters) Export
	
	If OpeningParameters.Property("DeleteAfterDataUpdate") Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("IsDataUpdated", IsDataUpdated);
		AdditionalParameters.Insert("OpeningParameters", OpeningParameters);
		
		NotifyDescription = New NotifyDescription(
			"OpenFileAfterTempFileDeletion", ThisObject, AdditionalParameters);
			
		BeginDeletingFiles(NotifyDescription, FileName);
		
	Else
		ExecuteNotifyProcessing(OpeningParameters.CompletionHandler, IsDataUpdated);
	EndIf;
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileAfterTempFileDeletion(AdditionalParameters) Export
	
	ExecuteNotifyProcessing(AdditionalParameters.OpeningParameters.CompletionHandler,
		AdditionalParameters.IsDataUpdated);
	
EndProcedure

// The procedure that follows FileSystemClient.OpenFile.
Procedure OpenFileInViewerNotifyOnError(ErrorDescription, Context)
	
	If Not IsBlankString(ErrorDescription) Then 
		ShowMessageBox(, ErrorDescription);
	EndIf;
	
	ApplicationStarted = False;
	ExecuteNotifyProcessing(Context.Notification, ApplicationStarted);
	
EndProcedure

// Parameters:
//  Extension - String - the Extension property of the File object.
//
Function IsExecutableFileExtension(Val Extension)
	
	Extension = Upper(Extension);
	
	// Windows
	Return Extension = ".BAT" // Batch File
		Or Extension = ".BIN" // Binary Executable
		Or Extension = ".CMD" // Command Script
		Or Extension = ".COM" // MS-DOS application
		Or Extension = ".CPL" // Control Panel Extension
		Or Extension = ".EXE" // Executable file
		Or Extension = ".GADGET" // Binary Executable
		Or Extension = ".HTA" // HTML Application
		Or Extension = ".INF1" // Setup Information File
		Or Extension = ".INS" // Internet Communication Settings
		Or Extension = ".INX" // InstallShield Compiled Script
		Or Extension = ".ISU" // InstallShield Uninstaller Script
		Or Extension = ".JOB" // Windows Task Scheduler Job File
		Or Extension = ".LNK" // File Shortcut
		Or Extension = ".MSC" // Microsoft Common Console Document
		Or Extension = ".MSI" // Windows Installer Package
		Or Extension = ".MSP" // Windows Installer Patch
		Or Extension = ".MST" // Windows Installer Setup Transform File
		Or Extension = ".OTM" // Microsoft Outlook macro
		Or Extension = ".PAF" // Portable Application Installer File
		Or Extension = ".PIF" // Program Information File
		Or Extension = ".PS1" // Windows PowerShell Cmdlet
		Or Extension = ".REG" // Registry Data File
		Or Extension = ".RGS" // Registry Script
		Or Extension = ".SCT" // Windows Scriptlet
		Or Extension = ".SHB" // Windows Document Shortcut
		Or Extension = ".SHS" // Shell Scrap Object
		Or Extension = ".U3P" // U3 Smart Application
		Or Extension = ".VB"  // VBScript File
		Or Extension = ".VBE" // VBScript Encoded Script
		Or Extension = ".VBS" // VBScript File
		Or Extension = ".VBSCRIPT" // Visual Basic Script
		Or Extension = ".WS"  // Windows Script
		Or Extension = ".WSF" // Windows Script
	// Linux
		Or Extension = ".CSH" // C Shell Script
		Or Extension = ".KSH" // Unix Korn Shell Script
		Or Extension = ".OUT" // Executable file
		Or Extension = ".RUN" // Executable file
		Or Extension = ".SH"  // Shell Script macOS
	// 
		Or Extension = ".ACTION" // Automator Action
		Or Extension = ".APP" // Executable file
		Or Extension = ".COMMAND" // Terminal Command
		Or Extension = ".OSX" // Executable file
		Or Extension = ".WORKFLOW" // Automator Workflow
	// Other
		Or Extension = ".AIR" // Adobe AIR distribution package
		Or Extension = ".COFFIE" // CoffeeScript (JavaScript) script
		Or Extension = ".JAR" // Java archive
		Or Extension = ".JS"  // JScript File
		Or Extension = ".JSE" // JScript Encoded File
		Or Extension = ".PLX" // Perl executable file
		Or Extension = ".PYC" // Python compiled file
		Or Extension = ".PYO"; // Python optimized code
	
EndFunction

#EndRegion

#Region OpenURL

// Continue the CommonClient.OpenURL procedure.
Procedure OpenURLAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	// ACC:534-off safe start methods are provided with this function
	
	URL = Context.URL;
	
	If ExtensionAttached Then
		
		Notification          = Context.Notification;
		WaitForCompletion = (Notification <> Undefined);
		
		Notification = New NotifyDescription(
			"OpenURLAfterStartApplication", ThisObject, Context,
			"OpenURLOnProcessError", ThisObject);
		BeginRunningApplication(Notification, URL,, WaitForCompletion);
		
	Else
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Расширение для работы с файлами не установлено, переход по ссылке ""%1"" невозможен.'; en = 'Cannot follow the link ""%1"" because the file system extension is not installed.'; pl = 'Nie można otworzyć odnośnika ""%1"" ponieważ rozszerzenie do pracy z plikami nie jest zainstalowane.';es_ES = 'La extensión para usar los archivos no está instalada, no se puede pasar por el enlace ""%1"".';es_CO = 'La extensión para usar los archivos no está instalada, no se puede pasar por el enlace ""%1"".';tr = 'Dosya uzantısı yüklü değil, ""%1"" bağlantısına geçilemez.';it = 'Impossibile seguire il file ""%1"" poiché l''estensione del file di sistema non è installata.';de = 'Der link ""%1"" ist nicht möglich denn die Dateisystemerweiterung ist nicht installiert.'"),
			URL);
		OpenURLNotifyOnError(ErrorDescription, Context);
	EndIf;
	
	// ACC:534-on
	
EndProcedure

// Continue the CommonClient.OpenURL procedure.
Procedure OpenURLAfterStartApplication(ReturnCode, Context) Export 
	
	Notification = Context.Notification;
	
	If Notification <> Undefined Then 
		ApplicationStarted = (ReturnCode = 0 Or ReturnCode = Undefined);
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenURL procedure.
Procedure OpenURLOnProcessError(ErrorInformation, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	OpenURLNotifyOnError("", Context);
	
EndProcedure

// Continue the CommonClient.OpenURL procedure.
Procedure OpenURLNotifyOnError(ErrorDescription, Context) Export
	
	Notification = Context.Notification;
	
	If Notification = Undefined Then
		If Not IsBlankString(ErrorDescription) Then 
			ShowMessageBox(, ErrorDescription);
		EndIf;
	Else 
		ApplicationStarted = False;
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Checks whether the passed string is a web URL.
// 
// Parameters:
//  String - String - passed URL.
//
Function IsWebURL(String) Export
	
	Return StrStartsWith(String, "http://")  // a usual connection.
		Or StrStartsWith(String, "https://");// a secure connection.
	
EndFunction

// Checks whether the passed string is a reference to the online help.
// 
// Parameters:
//  String - String - passed URL.
//
Function IsHelpRef(String) Export
	
	Return StrStartsWith(String, "v8help://");
	
EndFunction

// Checks whether the passed string is a valid reference to the protocol whitelist.
// 
// Parameters:
//  String - String - passed URL.
//
Function IsAllowedRef(String) Export
	
	Return StrStartsWith(String, "e1c:")
		Or StrStartsWith(String, "e1cib/")
		Or StrStartsWith(String, "e1ccs/")
		Or StrStartsWith(String, "v8help:")
		Or StrStartsWith(String, "http:")
		Or StrStartsWith(String, "https:")
		Or StrStartsWith(String, "mailto:")
		Or StrStartsWith(String, "tel:")
		Or StrStartsWith(String, "skype:");
	
EndFunction

#EndRegion

#Region FileSystemExtension

// The procedure that follows FileSystemClient.StartFileSystemExtensionAttaching.
Procedure StartFileSystemExtensionAttachingOnSetExtension(Attached, Context) Export
	
	// If the extension is already installed, there is no need to ask about it
	If Attached Then
		ExecuteNotifyProcessing(Context.NotifyDescriptionCompletion, "AttachmentNotRequired");
		Return;
	EndIf;
	
	// The extension is not available for the macOS web client.
	If CommonClient.IsMacOSClient() Then
		ExecuteNotifyProcessing(Context.NotifyDescriptionCompletion);
		Return;
	EndIf;
	
	ParameterName = "StandardSubsystems.SuggestFileSystemExtensionInstallation";
	FirstCallDuringSession = ApplicationParameters[ParameterName] = Undefined;
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, SuggestFileSystemExtensionInstallation());
	EndIf;
	
	SuggestFileSystemExtensionInstallation = ApplicationParameters[ParameterName] Or FirstCallDuringSession;
	If Context.CanContinueWithoutInstalling AND Not SuggestFileSystemExtensionInstallation Then
		
		ExecuteNotifyProcessing(Context.NotifyDescriptionCompletion);
		
	Else 
		
		FormParameters = New Structure;
		FormParameters.Insert("SuggestionText", Context.SuggestionText);
		FormParameters.Insert("CanContinueWithoutInstalling", Context.CanContinueWithoutInstalling);
		OpenForm(
			"CommonForm.FileSystemExtensionInstallationQuestion", 
			FormParameters,,,,, 
			Context.NotifyDescriptionCompletion);
		
	EndIf;
	
EndProcedure

// The procedure that follows FileSystemClient.StartFileSystemExtensionAttaching.
Procedure StartFileSystemExtensionAttachingWhenAnsweringToInstallationQuestion(Action, ClosingNotification) Export
	
	ExtensionAttached = (Action = "ExtensionAttached" Or Action = "AttachmentNotRequired");
	
#If WebClient Then
	If Action = "DoNotPrompt"
		Or Action = "ExtensionAttached" Then
		
		SystemInfo = New SystemInfo();
		ClientID = SystemInfo.ClientID;
		ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"] = False;
		CommonServerCall.CommonSettingsStorageSave(
			"ApplicationSettings/SuggestFileSystemExtensionInstallation", ClientID, False);
		
	EndIf;
#EndIf
	
	ExecuteNotifyProcessing(ClosingNotification, ExtensionAttached);
	
EndProcedure

// The procedure that follows FileSystemClient.StartFileSystemExtensionAttaching.
Function SuggestFileSystemExtensionInstallation()
	
	SystemInformation = New SystemInfo();
	ClientID = SystemInformation.ClientID;
	Return CommonServerCall.CommonSettingsStorageLoad(
		"ApplicationSettings/SuggestFileSystemExtensionInstallation", ClientID, True);
	
EndFunction

#EndRegion

#EndRegion