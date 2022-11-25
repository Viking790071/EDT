///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

#Region FilesImport

// Shows a file selection dialog box and places the selected file into a temporary storage.
// This method provides the functionality of both BeginPuttingFile and BeginPuttingFiles global 
// context methods. Its return value is not affected by availability of 1C:Enterprise Extension.
// Restrictions:
//   Not used to select catalogs -this option is not supported in the web client mode.
//
// Parameters:
//   CompletionHandler - NotifyDescription - contains details of the procedure that will be called 
//                             after the file with the following parameters is imported:
//      * FileThatWasPut - Undefined - a user canceled the selection.
//                       - Structure    - user has selected a file.
//                           ** Storage  - String - placing data to a temporary storage.
//                           ** Name       - String - in thin client and web client with the file 
//                                        system extension installed, it is a local path where the 
//                                        file was received. In web client without the file system 
//                                        extension, it is the name of a file with extension.
//      * AdditionalParameters - Arbitrary - value that was specified when creating object
//                                NotifyDescription.
//   ImportParameters         - Structure - see FileSystemClient.FileImportParameters. 
//   FileName                  - String - the full path to the file that will be offered to the user 
//                             at the beginning of interactive selection or will be put to the temporary storage in noninteractive. 
//                             If noninteractive mode is selected and the parameter is not filled, an exception will be called.
//   AddressInTempStorage - String - the address where the file will be saved.
//
// Example:
//   Notification = New NotifyDescription("SelectFileAfterPutFiles", ThisObject, Context);
//   ImportParameters = FileSystemClient.FileImportParameters();
//   ImportParameters.FormID = UUID;
//   FileSystemClient.ImportFile(Notification, ImportParameters);
//
Procedure ImportFile(
		CompletionHandler, 
		ImportParameters = Undefined, 
		FileName = "",
		AddressInTempStorage = "") Export
	
	If ImportParameters = Undefined Then
		ImportParameters = FileImportParameters();
	ElsIf Not ImportParameters.Interactively
		AND IsBlankString(FileName) Then
		Raise NStr("ru = 'Не указано имя файла для загрузки в неинтерактивном режиме.'; en = 'Import in non-interactive mode failed. The name of the file to import is not specified.'; pl = 'Importowanie w trybie nieinteraktywnym nie powiodło się. Nie określono nazwy pliku do importu.';es_ES = 'Error al importar en modo no interactivo. No se ha especificado el nombre del archivo a importar.';es_CO = 'Error al importar en modo no interactivo. No se ha especificado el nombre del archivo a importar.';tr = 'İnteraktif olmayan modda içe aktarım hatası. İçe aktarılacak dosyanın adı belirtilmedi.';it = 'Importazione in modalità non interattiva non riuscita. Il nome del file da importare non è specificato.';de = 'Der Import im nicht-interaktiven Modus ist fehlgeschlagen. Der Name der zu importierenden Datei ist nicht angegeben.'");
	EndIf;
	
	If Not ValueIsFilled(ImportParameters.FormID) Then
		ImportParameters.FormID = New UUID;
	EndIf;
	
	FileDetails = New TransferableFileDescription(FileName, AddressInTempStorage);
	ImportParameters.Insert("FilesToUpload", FileDetails);
	
	ImportParameters.Dialog.FullFileName     = FileName;
	ImportParameters.Dialog.Multiselect = False;
	ShowPutFile(CompletionHandler, ImportParameters);
	
EndProcedure

// Shows a file selection dialog and puts the selected files to a temporary storage.
// This method provides the functionality of both BeginPuttingFile and BeginPuttingFiles global 
// context methods. Its return value is not affected by availability of 1C:Enterprise Extension.
// Restrictions:
//   Not used to select catalogs -this option is not supported in the web client mode.
//   Multiple selection in the web client is only supported if 1C:Enterprise Extension is available.
//
// Parameters:
//   CompletionHandler - NotifyDescription - contains the description of the procedure that will be 
//                             called after the files with the following parameters will be imported:
//      * FilesThatWerePut - Undefined - a user canceled the selection.
//                        - Array - contains objects of the Structure type. The user selected the file.
//                           ** Storage  - String - placing data to a temporary storage.
//                           ** Name       - String - in thin client and web client with the file 
//                                        system extension installed, it is a local path where the 
//                                        file was received. In web client without the file system 
//                                        extension, it is the name of a file with extension.
//                           ** FullName - String - in thin client and web client with the file 
//                                         system extension installed, it is a local path where the 
//                                         file was received. In web client without the file system 
//                                         extension, it takes the value "".
//                           ** FileName  - String - a name of a file with extension.
//      * AdditionalParameters - Arbitrary - a value that was specified when creating the NotifyDescription object.
//   ImportParameters    - Structure - see FileSystemClient.FileImportParameters. 
//   FilesToUpload     - Array - contains objects of the TransferableFileDetails type. Can be filled 
//                        completely. In this case the files being imported will be saved to the specified addresses. 
//                        Can be filled partially. Only the names of the array items are filled. In 
//                        this case the files being imported will be placed in new temporary storages. Array can be empty. 
//                        In this case the files to put are defined by the values specified in the ImportParameters parameter. 
//                        If noninteractive mode is selected in import parameters, and the 
//                        FilesToUpload parameter is not filled, an exception will be called.
//
// Example:
//   Notification = New NotifyDescription("LoadExtensionAfterPutFiles", ThisObject, Context);
//   ImportParameters = FileSystemClient.FileImportParameters();
//   ImportParameters.FormID = UUID;
//   FileSystemClient.ImportFiles(Notification, ImportParameters);
//
Procedure ImportFiles(
		CompletionHandler, 
		ImportParameters = Undefined,
		FilesToUpload = Undefined) Export
	
	If ImportParameters = Undefined Then
		ImportParameters = FileImportParameters();
	EndIf;
	
	If Not ImportParameters.Interactively
		AND (FilesToUpload = Undefined 
		Or (TypeOf(FilesToUpload) = Type("Array")
		AND FilesToUpload.Count() = 0)) Then
		
		Raise NStr("ru = 'Не указаны файлы для загрузки в неинтерактивном режиме.'; en = 'Import in non-interactive mode failed. The files to import are not specified.'; pl = 'Importowanie w trybie nieinteraktywnym nie powiodło się. Nie określono plików do importu.';es_ES = 'Error al importar en modo no interactivo. No se han especificado los archivos a importar.';es_CO = 'Error al importar en modo no interactivo. No se han especificado los archivos a importar.';tr = 'İnteraktif olmayan modda içe aktarım hatası. İçe aktarılacak dosyalar belirtilmedi.';it = 'Importazione in modalità non interattiva non riuscita. I file da importare non sono specificati.';de = 'Der Import im nicht-interaktiven Modus ist fehlgeschlagen. Die zu importierenden Dateien sind nicht angegeben.'");
		
	EndIf;
	
	If FilesToUpload = Undefined Then
		FilesToUpload = New Array;
	EndIf;
	
	If Not ValueIsFilled(ImportParameters.FormID) Then
		ImportParameters.FormID = New UUID;
	EndIf;
	
	ImportParameters.Dialog.Multiselect = True;
	ImportParameters.Insert("FilesToUpload", FilesToUpload);
	ShowPutFile(CompletionHandler, ImportParameters);
	
EndProcedure

#EndRegion

#Region ModifiesStoredData

// Gets the file and saves it to the local file system of the user.
//
// Parameters:
//   CompletionHandler      - NotifyDescription, Undefined - contains the description of the 
//                             procedure that will be called after completion with the following parameters:
//      * ReceivedFiles         - Undefined - files are not received.
//                                - Array - contains objects of the TransferredFileDescription type. Saved files.
//      * AdditionalParameters - Arbitrary - a value that was specified when creating the NotifyDescription object.
//   AddressInTempStorage - String - placing data to a temporary storage.
//   FileName                  - String - a full path according to which the received file and the 
//                             file name with an extension must be saved.
//   SavingParameters       - Structure - see FileSystemClient.FileSavingParameters 
//
// Example:
//   Notification = New NotifyDescription("SaveCertificateAfterFilesReceipt", ThisObject, Context);
//   SavingParameters = FileSystemClient.FileSavingParameters();
//   FileSystemClient.SaveFile(Notification, Context.CertificateAddress, FileName, SavingParameters);
//
Procedure SaveFile(CompletionHandler, AddressInTempStorage, FileName = "",
	SavingParameters = Undefined) Export
	
	If SavingParameters = Undefined Then
		SavingParameters = FileSavingParameters();
	EndIf;
	
	FileData = New TransferableFileDescription(FileName, AddressInTempStorage);
	
	FilesToSave = New Array;
	FilesToSave.Add(FileData);
	
	ShowDownloadFiles(CompletionHandler, FilesToSave, SavingParameters);
	
EndProcedure

// Gets the files and saves them to the local file system of the user.
// To save files in noninteractive mode, the Name property of the FilesToSave parameter must have 
// the full path to the file being saved, or if the Name property contains only the file name with 
// extension, the Directory property of the Dialog item of the SavingParameters parameter is to be filled. 
// Otherwise, an exception will be called.
//
// Parameters:
//   CompletionHandler - NotifyDescription, Undefined - contains the description of the procedure 
//                             that will be called after completion with the following parameters:
//     * ReceivedFiles         - Undefined - files are not received.
//                               - Array - contains objects of the TransferredFileDescription type. Saved files.
//     * AdditionalParameters - Arbitrary - value that was specified when creating object
//                               NotifyDescription.
//   FilesToSave     - Array - contains objects of the TransferredFileDescription type.
//     * Storage - placing data to a temporary storage.
//     * Name      - String - a full path according to which the received file and the file name with an extension must be saved.
//   SavingParameters  - Structure - see FileSystemClient.FileSavingParameters 
//
// Example:
//   Notification = New NotifyDescription("SavePrintFormToFileAfterGetFiles", ThisObject);
//   SavingParameters = FileSystemClient.FilesSavingParameters();
//   FileSystemClient.SaveFiles(Notification, FilesToGet, SavingParameters);
//
Procedure SaveFiles(CompletionHandler, FilesToSave, SavingParameters = Undefined) Export
	
	If SavingParameters = Undefined Then
		SavingParameters = FilesSavingParameters();
	EndIf;
	
	ShowDownloadFiles(CompletionHandler, FilesToSave, SavingParameters);
	
EndProcedure

#EndRegion

#Region Parameters

// Initializes a parameter structure to import the file from the file system.
// To be used in FileSystemClient.ImportFile and FileSystemClient.ImportFiles
//
// Returns:
//  Structure - with the following properties:
//    * FormID                  - UUID - a UUID of the form used to place the file.
//                                           If the parameter is filled, the DeleteFromTempStorage 
//                                          global context method is to be called after completing 
//                                          the operation with the binary data. Default value is 
//                                          Undefined.
//    * Interactively                        - Boolean - indicates interactive mode usage when a 
//                                          file selection dialog is showed to the user. Default 
//                                          value is True.
//    * Dialog                              - FileSelectionDialog - for the properties, see the Syntax Assistant.
//                                          It is used if the Interactively property is True and 1C:
//                                          Enterprise Extension is applied.
//    * SuggestionText                   - String - a text of suggestion to install the extension. 
//                                          If the parameter takes the value "", the standard suggestion text will be output.
//                                          Default value is "".
//    * ActionBeforeStartPutFiles - NotifyDescription, Undefined - contains details of the procedure 
//                                          to be called right before starting to place a file in a 
//                                          temporary storage. If the parameter is Undefined, no 
//                                          procedure will be called before placing a file. Default 
//                                          value is Undefined. Parameters of the procedure being called:
//        ** FilesToPut         - RefToFile, Array - a reference to a file ready to be placed in a temporary storage.
//                                   If multiple files were imported, it contains an array of references.
//        ** CancelPuttingFile   - Boolean - indicates whether file putting was canceled. If the 
//                                   parameter is set to True in the handler procedure body, the file is not placed.
//        ** AdditionalParameters - Arbitrary - a value that was specified when creating the NotifyDescription object.
//
// Example:
//  ImportParameters = FileSystemClient.FileImportParameters();
//  ImportParameters.Dialog.Title = NStr("en = 'Select a document'");
//  ImportParameters.Dialog.Filter = NStr("en = 'MS Word files (*.doc;*.docx)|*.doc;*.docx|All files (*.*)|*.*'");
//  FileSystemClient.ImportFile(Notification, ImportParameters);
//
Function FileImportParameters() Export
	
	ImportParameters = OperationContext(FileDialogMode.Open);
	ImportParameters.Insert("FormID", Undefined);
	ImportParameters.Insert("AcrtionBeforeStartPutFiles", Undefined);
	Return ImportParameters;
	
EndFunction

// Initializes a parameter structure to save the file to the file system.
// To be used in FileSystemClient.SaveFile.
//
// Returns:
//  Structure - with the following properties:
//    * Interactively     - Boolean - indicates interactive mode usage when a file selection dialog 
//                       is showed to the user. Default value is True.
//                       
//    * Dialog           - FileSelectionDialog - for the properties, see the Syntax Assistant.
//                       It is used if the Interactively property is True and 1C:Enterprise 
//                       Extension is applied.
//    * SuggestionText - String - a text of suggestion to install the extension. If the parameter 
//                       takes the value "", the standard suggestion text will be output.
//                       Default value is "".
//
// Example:
//  SavingParameters = FileSystemClient.FileSavingParameters();
//  SavingParameters.Dialog.Title = NStr("en = 'Save key operation profile to file");
//  SavingParameters.Dialog.Filter = "Key operation profile files (*.xml)|*.xml";
//  FileSystemClient.SaveFile(Undefined, SaveKeyOperationsProfileToServer(), , SavingParameters);
//
Function FileSavingParameters() Export
	
	Return OperationContext(FileDialogMode.Save);
	
EndFunction

// Initializes a parameter structure to save the file to the file system.
// To be used in FileSystemClient.SaveFiles.
//
// Returns:
//  Structure - with the following properties:
//    * Interactively     - Boolean - indicates interactive mode usage when a file selection dialog 
//                       is showed to the user. Default value is True.
//                       
//    * Dialog           - FileSelectionDialog - for the properties, see the Syntax Assistant.
//                       It is used if the Interactively property is True and 1C:Enterprise 
//                       Extension is applied.
//    * SuggestionText - String - a text of suggestion to install the extension. If the parameter 
//                       takes the value "", the standard suggestion text will be output.
//                       Default value is "".
//
// Example:
//  SavingParameters = FileSystemClient.FilesSavingParameters();
//  SavingParameters.Dialog.Title = NStr("en ='Select a folder to save generated document'");
//  FileSystemClient.SaveFiles(Notification, FilesToGet, SavingParameters);
//
Function FilesSavingParameters() Export
	
	Return OperationContext(FileDialogMode.ChooseDirectory);
	
EndFunction

// Initializes a parameter structure to open the file.
// To be used in FileSystemClient.OpenFile.
//
// Returns:
//  Structure - with the following properties:
//    *Encoding         - String - a text file encoding. If the parameter is not specified, the text 
//                       format will be determined automatically. See the code list in the Syntax 
//                       Assistant in the Write method details of the text document. Default value is "".
//    *ForEditing - Boolean - True to open the file for editing, False otherwise. If the parameter 
//                       takes the True value, waiting for application closing, and if in the
//                       FileLocation parameter the address is stored in the temporary storage, it updates the file data.
//                       Default value is False.
//
Function FileOpeningParameters() Export
	
	Context = New Structure;
	Context.Insert("Encoding", "");
	Context.Insert("ForEditing", False);
	Return Context;
	
EndFunction

#EndRegion

#Region RunExternalApplications

// Opens a file for viewing or editing.
// If the file is opened from the binary data in a temporary storage, it is previously saved to the 
// temporary directory.
//
// Parameters:
//  FileLocation    - String - the full path to the file in the file system or a file data address 
//                       in a temporary storage.
//  CompletionHandler - NotifyDescription, Undefined - the description of the procedure that gets 
//                       the method result with the following parameters:
//    * FileIsChanged             - Boolean - the file is changed on a hard drive or the binary data in a temporary storage.
//    * AdditionalParameters - Arbitrary - value that was specified when creating object
//                              NotifyDescription.
//  FileName             - String - the name of the file with an extension or the file extension without the dot. 
//                       If the FileLocation parameter contains the address in a temporary storage and the parameter
//                       FileName is empty, an exception is thrown.
//  OpeningParameters    - Structure - see FileSystemClient.FileOpeningParameters. 
//
Procedure OpenFile(
		FileLocation,
		CompletionHandler = Undefined,
		FileName = "",
		OpeningParameters = Undefined) Export
		
	If OpeningParameters = Undefined Then
		OpeningParameters = FileOpeningParameters();
	EndIf;
	
	OpeningParameters.Insert("CompletionHandler", CompletionHandler);
	If IsTempStorageURL(FileLocation) Then
		
		If IsBlankString(FileName) Then
			Raise NStr("ru = 'Не указано имя файла.'; en = 'The file name is not specified.'; pl = 'Nie określono nazwy pliku.';es_ES = 'No se ha especificado el nombre del archivo.';es_CO = 'No se ha especificado el nombre del archivo.';tr = 'Dosya adı belirtilmedi.';it = 'Nome file non specificato.';de = 'Der Dateiname is nicht angegeben.'");
		EndIf;
		
		PathToFile = TempFileFullName(FileName);
		
		OpeningParameters.Insert("PathToFile", PathToFile);
		OpeningParameters.Insert("AddressOfBinaryDataToUpdate", FileLocation);
		OpeningParameters.Insert("DeleteAfterDataUpdate", True);
		
		SavingParameters = FileSavingParameters();
		SavingParameters.Interactively = False;
		
		NotifyDescription = New NotifyDescription(
			"OpenFileAfterSaving", FileSystemInternalClient, OpeningParameters);
		
		SaveFile(NotifyDescription, FileLocation, PathToFile, SavingParameters);
		
	Else
		FileSystemInternalClient.OpenFileAfterSaving(New Structure("FullName", FileLocation), OpeningParameters);
	EndIf;
	
EndProcedure

// Opens a URL in an application associated with URL protocol.
//
// Valid protocols: http, https, e1c, v8help, mailto, tel, skype.
//
// Do not use protocol file:// to open Explorer or a file.
// - To Open Explorer, use OpenExplorer. 
// - To open a file in an associated application, use OpenFileInViewer. 
//
// Parameters:
//  URL - Reference - a link to open.
//  Notification - NotifyDescription - notification on file open attempt.
//      If the notification is not specified and an error occurs, the method shows a warning.
//      - ApplicationStarted - Boolean - True if the external application opened successfully.
//      - AdditionalParameters - Arbitrary - a value that was specified when creating the NotifyDescription object.
//
// Example:
//  FileSystemClient.OpenURL("e1cib/navigationpoint/startpage"); // Home page.
//  FileSystemClient.OpenURL("v8help://1cv8/QueryLanguageFullTextSearchInData");
//  FileSystemClient.OpenURL("https://1c.ru");
//  FileSystemClient.OpenURL("mailto:help@1c.ru");
//  FileSystemClient.OpenURL("skype:echo123?call");
//
Procedure OpenURL(URL, Val Notification = Undefined) Export
	
	// ACC:534-off safe start methods are provided with this function
	
	Context = New Structure;
	Context.Insert("URL", URL);
	Context.Insert("Notification", Notification);
	
	ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Не удалось перейти по ссылке ""%1"" по причине:
		           |Неверно задана навигационная ссылка.'; 
		           |en = 'Cannot open URL ""%1"".
		           |The URL is invalid.'; 
		           |pl = 'Nie można otworzyć adresu URL ""%1"".
		           |Adres URL jest nieprawidłowy.';
		           |es_ES = 'No se puede abrir la URL ""%1"".
		           |La URL no es válida.';
		           |es_CO = 'No se puede abrir la URL ""%1"".
		           |La URL no es válida.';
		           |tr = '""%1"" URL''si açılamıyor.
		           |URL geçersiz.';
		           |it = 'Impossibile aprire l''URL ""%1"". 
		           | URL non valido.';
		           |de = 'Kann URL ""%1"" nicht öffnen.
		           |Das URL ist ungültig.'"),
		URL);
	
	If Not FileSystemInternalClient.IsAllowedRef(URL) Then 
		
		FileSystemInternalClient.OpenURLNotifyOnError(ErrorDescription, Context);
		
	ElsIf FileSystemInternalClient.IsWebURL(URL)
		Or CommonInternalClient.IsURL(URL) Then 
		
		Try
		
#If ThickClientOrdinaryApplication Then
			
			// Platform design feature: GotoURL is not supported by ordinary applications running in the thick client mode.
			Notification = New NotifyDescription(
				,, Context,
				"OpenURLOnProcessError", FileSystemInternalClient);
			BeginRunningApplication(Notification, URL);
#Else
			GotoURL(URL);
#EndIf
			
			If Notification <> Undefined Then 
				ApplicationStarted = True;
				ExecuteNotifyProcessing(Notification, ApplicationStarted);
			EndIf;
			
		Except
			FileSystemInternalClient.OpenURLNotifyOnError(ErrorDescription, Context);
		EndTry;
		
	ElsIf FileSystemInternalClient.IsHelpRef(URL) Then 
		
		OpenHelp(URL);
		
	Else 
		
		Notification = New NotifyDescription(
			"OpenURLAfterCheckFileSystemExtension", FileSystemInternalClient, Context);
		
		SuggestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для открытия ссылки ""%1"" необходимо установить расширение для работы с 1С:Предприятием.'; en = 'To open URL ""%1"", install 1C:Enterprise Extension.'; pl = 'Aby otworzyć adres URL ""%1"", zainstaluj 1C:Enterprise Extension.';es_ES = 'Para abrir la URL ""%1"", instale 1C:Enterprise Extension.';es_CO = 'Para abrir la URL ""%1"", instale 1C:Enterprise Extension.';tr = '""%1"" URL''sini açmak için 1C:Enterprise Extension yükleyin.';it = 'Per aprire l''URL ""%1"", installare 1C:Enterprise Extension.';de = 'Um URL ""%1"" zu öffnen, installieren Sie die 1C:Enterprise Extension.'"),
			URL);
		AttachFileOperationsExtension(Notification, SuggestionText, False);
		
	EndIf;
	
	// ACC:534-on
	
EndProcedure

#EndRegion

#Region Miscellaneous

// Suggests the user to install 1C:Enterprise Extension in the web client.
// The function to be incorporated in the beginning of code areas that process files.
//
// Parameters:
//  OnCloseNotifyDescription - NotifyDescription - the description of the procedure to be called 
//          once a form is closed. Parameters:
//    - ExtensionAttached - Boolean - True if the extension is attached.
//    - AdditionalParameters - Arbitrary - the parameters specified in OnCloseNotifyDescription.
//  SuggestionText - String - a message text. If the text is not specified, the default text is displayed.
//  CanContinueWithoutInstalling - If True, displays the ContinueWithoutInstalling button. If False, 
//          displays the Cancel button.
//
// Example:
//
//  Notification = New NotifyDescription("PrintDocumentCompletion", ThisObject);
//  MessageText = NStr("en = 'To print the document, install 1C:Enterprise Extension.'");
//  FileSystemClient.AttachFileOperationsExtension(Notification, MessageText);
//
//  Procedure PrintDocumentCompletion(ExtensionAttached, AdditionalParameters) Export
//    If ExtensionAttached Then
//     // Script that print a document only if the file system extension is attached.
//     // ...
//    Else
//     // Script that print a document if the file system extension is not attached.
//     // ...
//    EndIf.
//
Procedure AttachFileOperationsExtension(
		OnCloseNotifyDescription, 
		SuggestionText = "",
		CanContinueWithoutInstalling = True) Export
	
	NotificationDescriptionCompletion = New NotifyDescription(
		"StartFileSystemExtensionAttachingWhenAnsweringToInstallationQuestion", FileSystemInternalClient,
		OnCloseNotifyDescription);
	
#If Not WebClient Then
	// In the thin, thick, and web clients the extension is always attached.
	ExecuteNotifyProcessing(NotificationDescriptionCompletion, "AttachmentNotRequired");
	Return;
#EndIf
	
	Context = New Structure;
	Context.Insert("NotifyDescriptionCompletion", NotificationDescriptionCompletion);
	Context.Insert("SuggestionText",             SuggestionText);
	Context.Insert("CanContinueWithoutInstalling", CanContinueWithoutInstalling);
	
	Notification = New NotifyDescription(
		"StartFileSystemExtensionAttachingOnSetExtension", FileSystemInternalClient, Context);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

// Initializes a parameter structure to interact with the file system.
//
// Parameters:
//  DialogMode - FileSelectionDialogMode - the run mode of generating file selection dialog.
//
// Returns:
//  Structure - see FileSystemClient.FileImportParameters and FileSystemClient.FileSavingParameters
//
Function OperationContext(DialogMode)
	
	Context = New Structure();
	Context.Insert("Dialog", New FileDialog(DialogMode));
	Context.Insert("Interactively", True);
	Context.Insert("SuggestionText", "");
	
	Return Context;
	
EndFunction

// Places the selected files into a temporary storage.
// See FileSystemClient.ImportFile and FileSystemClient.ImportFiles. 
//
Procedure ShowPutFile(CompletionHandler, PutParameters)
	
	PutParameters.Insert("CompletionHandler", CompletionHandler);
	NotifyDescription = New NotifyDescription(
		"ShowPutFileOnAttachFileSystemExtension", FileSystemInternalClient, PutParameters);
	AttachFileOperationsExtension(NotifyDescription, PutParameters.SuggestionText);
	
EndProcedure

// Saves files from temporary storage to the file system.
// See FileSystemClient.SaveFile and FileSystemClient.SaveFiles. 
//
Procedure ShowDownloadFiles(CompletionHandler, FilesToSave, ReceivingParameters)
	
	ReceivingParameters.Insert("FilesToGet",      FilesToSave);
	ReceivingParameters.Insert("CompletionHandler", CompletionHandler);
	
	NotifyDescription = New NotifyDescription(
		"ShowDownloadFilesOnAttachFileSystemExtension", FileSystemInternalClient, ReceivingParameters);
	AttachFileOperationsExtension(NotifyDescription, ReceivingParameters.SuggestionText);
	
EndProcedure

// Gets the path to save the file in the temporary files catalog.
//
// Parameters:
//  FileName - String - the name of the file with an extension or the file extension without the dot.
//
// Returns:
//  String - path to save the file.
//
Function TempFileFullName(Val FileName)

#If WebClient Then
	
	Return ?(StrFind(FileName, ".") = 0, 
		Format(CommonClient.SessionDate(), "DF=yyyyMMddHHmmss") + "." + FileName, FileName);
	
#Else
	
	ExtensionPosition = StrFind(FileName, ".");
	If ExtensionPosition = 0 Then
		Return GetTempFileName(FileName);
	Else
		Return TempFilesDir() + FileName;
	EndIf;
	
#EndIf

EndFunction

#EndRegion