////////////////////////////////////////////////////////////////////////////////
// File operations subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

// Returns the file binary data.
// If the file binary data is not found in the infobase or in the volumes, an exception will be called.
//
// Parameters:
//  AttachedFile - DefinedType.AttachedFile - a reference to the catalog item with the file.
//
// Returns:
//  BinaryData - binary data of the attached file.
//
Function FileBinaryData(Val AttachedFile) Export
	
	CommonClientServer.CheckParameter("FilesOperations.FileBinaryData", "AttachedFile", 
		AttachedFile, Metadata.DefinedTypes.AttachedFile.Type);
		
	SetPrivilegedMode(True);
	
	FileObject = FilesOperationsInternal.FileObject(AttachedFile);
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase Then

		Result = FileFromInfobaseStorage(FileObject.Ref);
		If Result <> Undefined Then
			Return Result.Get();
		EndIf;
		
		// Record to the event log.
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Двоичные данные файла отсутствуют в регистре BinaryFileData
			           |
			           |Ссылка на файл: ""%1"".'; 
			           |en = 'Binary file data is missing from the BinaryFileData register.
			           |
			           |Reference to file: ""%1"".'; 
			           |pl = 'Brak danych binarnych pliku w rejestrze BinaryFileData
			           |
			           |Odnośnik do pliku: ""%1"".';
			           |es_ES = 'No hay datos binarios del archivo en el registro BinaryFileData
			           |
			           |Enlace al archivo: ""%1"".';
			           |es_CO = 'No hay datos binarios del archivo en el registro BinaryFileData
			           |
			           |Enlace al archivo: ""%1"".';
			           |tr = 'BinaryFileData kaydedicide dosyanın ikili verileri mevcut değil
			           |
			           |Dosya linki: ""%1"".';
			           |it = 'I dati del file binario mancano dal registro BinaryFileData.
			           |
			           |Riferimento al file: ""%1"".';
			           |de = 'Binärdaten der Datei sind im Register BinärDatenDatei nicht verfügbar
			           |
			           |Verweis auf die Datei: ""%1"".'"),
			GetURL(AttachedFile));
		WriteLogEvent(NStr("ru = 'Файлы.Открытие файла'; en = 'Files.File opens'; pl = 'Pliki.Otwórz plik';es_ES = 'Archivo.Abrir el archivo';es_CO = 'Archivo.Abrir el archivo';tr = 'Dosyalar. Dosyayı aç';it = 'File.Apertura file';de = 'Dateien. Datei öffnen'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs[AttachedFile.Metadata().Name],
			AttachedFile,
			ErrorMessage);
		
		FileOwnerPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Присоединен к %1 : %2'; en = 'Attached to %1 : %2'; pl = 'Dołączony do %1 : %2';es_ES = 'Conectado con %1 : %2';es_CO = 'Conectado con %1 : %2';tr = 'Aşağıdaki ile bağlı %1: %2';it = 'Allegato a %1 : %2';de = 'Angehängt an %1: %2'"),
				String(TypeOf(FileObject.FileOwner)),
				FileObject.FileOwner);
		
		Raise FilesOperationsInternalClientServer.ErrorFileNotFoundInFileStorage(
			FileObject.Description + "." + FileObject.Extension,
			False,
			FileOwnerPresentation);
	Else
		FullPath = FilesOperationsInternal.FullVolumePath(FileObject.Volume) + FileObject.PathToFile;
		
		Try
			Return New BinaryData(FullPath);
		Except
			// Record to the event log.
			ErrorMessage = ErrorTextWhenYouReceiveFile(ErrorInfo(), AttachedFile);
			WriteLogEvent(NStr("ru = 'Файлы.Получение файла из тома'; en = 'Files.Receive the file from the volume'; pl = 'Pliki. Odbierz plik z woluminu';es_ES = 'Archivos.Recibir un archivo del volumen';es_CO = 'Archivos.Recibir un archivo del volumen';tr = 'Dosyalar. Dosyayı disk bölümünden al.';it = 'File.Ricevere file dal volume';de = 'Dateien. Empfangen Sie eine Datei vom Volumen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs[AttachedFile.Metadata().Name],
				AttachedFile,
				ErrorMessage);
			
			FileOwnerPresentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Присоединен к %1 : %2'; en = 'Attached to %1 : %2'; pl = 'Dołączony do %1 : %2';es_ES = 'Conectado con %1 : %2';es_CO = 'Conectado con %1 : %2';tr = 'Aşağıdaki ile bağlı %1: %2';it = 'Allegato a %1 : %2';de = 'Angehängt an %1: %2'"),
					String(TypeOf(FileObject.FileOwner)),
					FileObject.FileOwner);
				
			Raise FilesOperationsInternalClientServer.ErrorFileNotFoundInFileStorage(
				FileObject.Description + "." + FileObject.Extension,
				,
				FileOwnerPresentation);
				
		EndTry;
	EndIf;
	
EndFunction

// Returns the structured file information. It is used in variety of file operation commands and as 
// FileData parameter value in other procedures and functions.
//
// Parameters:
//  AttachedFile - DefinedType.AttachedFile - a reference to the catalog item with the file.
//
//  FormID - UUID - a form UUID. The method puts the file to the temporary storage of this form and 
//                       returns the address in the RefToBinaryFileData property.
//                       
//
//  GetRefToBinaryData - Boolean - if False, reference to the binary data in the RefToBinaryFileData 
//                 is not received thus significantly speeding up execution for large binary data.
//
//  ForEditing - Boolean - if you specify True, a file will be locked for editing.
//
// Returns:
//  Structure - with the following properties:
//    * RefToBinaryFileData        - String - an address in the temporary storage where data is located.
//    * RelativePath                  - String - a relative file path.
//    * ModificationDateUniversal       - Date   - file change date.
//    * FileName                           - String - a file name.
//    * Description                       - String - a file description in the file storage catalog.
//    * Extension                         - String - a file extension without fullstop.
//    * Size                             - Number  - a file size.
//    * EditedBy                        - CatalogRef.Users, CatalogRef.ExternalUsers,
//                                           Undefined - a reference to the user that locked the file.
//    * SignedDS                         - Boolean - shows that file is signed.
//    * Encrypted                         - Boolean - shows that file is encrypted.
//    * FileBeingEdited                  - Boolean - shows that file is locked for editing.
//    * CurrentUserEditsFile - boolean - shows that file is locked for editing by the current user.
//    * Encoding                          - String - an encoding, in which the file is saved. See 
//                                                    the supported encoding list in the help to the GetBinaryDataFromString global context method.
//
Function FileData(Val AttachedFile,
                    Val FormID = Undefined,
                    Val GetBinaryDataRef = True,
                    Val ForEditing = False) Export
	
	InfobaseUpdate.CheckObjectProcessed(AttachedFile);
	
	CommonClientServer.CheckParameter("FilesOperations.FileData", "AttachedFile",
		AttachedFile, Metadata.DefinedTypes.AttachedFile.Type);
		
	FileObject = AttachedFile.GetObject();
	CommonClientServer.Validate(FileObject <> Undefined, 
		StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не найден присоединенный файл ""%1"" (%2)'; en = 'Attached file ""%1"" is not found (%2)'; pl = 'Załączony plik ""%1"" nie został znaleziony (%2)';es_ES = 'Archivo adjuntado ""%1"" no encontrado (%2)';es_CO = 'Archivo adjuntado ""%1"" no encontrado (%2)';tr = 'Ekli dosya ""%1"" bulunamadı (%2)';it = 'Il file allegato ""%1"" (%2) non è stato trovato';de = 'Angehängte Datei ""%1"" wird nicht gefunden (%2)'"),
			String(AttachedFile), AttachedFile.Metadata()));
	
	If ForEditing AND Not ValueIsFilled(FileObject.BeingEditedBy) Then
		FileObject.Lock();
		FilesOperationsInternal.LockFileForEditingServer(FileObject);
	EndIf;
	
	SetPrivilegedMode(True);
	
	RefToBinaryFileData = Undefined;
	
	VersionsStorageSupported = (TypeOf(AttachedFile) = Type("CatalogRef.Files"));
	FilesVersioningUsed = VersionsStorageSupported
								AND AttachedFile.StoreVersions
								AND ValueIsFilled(AttachedFile.CurrentVersion);
	
	If GetBinaryDataRef Then
		If FilesVersioningUsed Then
			BinaryData = FileBinaryData(AttachedFile.CurrentVersion);
		Else
			BinaryData = FileBinaryData(AttachedFile);
		EndIf;
		If TypeOf(FormID) = Type("UUID") Then
			RefToBinaryFileData = PutToTempStorage(BinaryData, FormID);
		Else
			RefToBinaryFileData = PutToTempStorage(BinaryData);
		EndIf;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("Ref",                       AttachedFile);
	Result.Insert("BinaryFileDataRef",  RefToBinaryFileData);
	Result.Insert("RelativePath",            GetObjectID(FileObject.FileOwner) + "\");
	Result.Insert("UniversalModificationDate", FileObject.UniversalModificationDate);
	Result.Insert("FileName",                     FileObject.Description + "." + FileObject.Extension);
	Result.Insert("Description",                 FileObject.Description);
	Result.Insert("Extension",                   FileObject.Extension);
	Result.Insert("Size",                       FileObject.Size);
	Result.Insert("BeingEditedBy",                  FileObject.BeingEditedBy);
	Result.Insert("SignedWithDS",                   FileObject.SignedWithDS);
	Result.Insert("Encrypted",                   FileObject.Encrypted);
	Result.Insert("StoreVersions",                FileObject.StoreVersions);
	Result.Insert("DeletionMark",              FileObject.DeletionMark);
	Result.Insert("LoanDate",                    FileObject.LoanDate);
	Result.Insert("Owner",                     FileObject.FileOwner);
	Result.Insert("CurrentVersionAuthor",           FileObject.Changed);
	Result.Insert("URL", GetURL(AttachedFile));
	
	FileObjectMetadata = Metadata.FindByType(TypeOf(AttachedFile));
	HasAbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", FileObjectMetadata);
	
	If HasAbilityToStoreVersions AND ValueIsFilled(AttachedFile.CurrentVersion) Then
		FilesOperationsInternalServerCall.FillAdditionalFileData(Result, AttachedFile, AttachedFile.CurrentVersion);
	Else
		FilesOperationsInternalServerCall.FillAdditionalFileData(Result, AttachedFile, Undefined);
	EndIf;
	
	Result.Insert("FileBeingEdited",            ValueIsFilled(FileObject.BeingEditedBy));
	Result.Insert("CurrentUserEditsFile",
		?(Result.FileBeingEdited, FileObject.BeingEditedBy = Users.AuthorizedUser(), False) );
		
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		If FileObject.Encrypted Then
			Result.Insert("EncryptionCertificatesArray", ModuleDigitalSignature.EncryptionCertificates(AttachedFile));
		EndIf;
	EndIf;
	
	Encoding = ?(FilesVersioningUsed, FileEncoding(AttachedFile.CurrentVersion, FileObject.Extension),
		FileEncoding(AttachedFile, FileObject.Extension));
	Result.Insert("Encoding", Encoding);
	
	Return Result;
	
EndFunction

// Finds all files attached to an object and adds references to them to the Files property.
//
// Parameters:
//  FileOwner - DefinedType.AttachedFilesOwner - a reference to the object that is file owner.
//  Files         - Array - an array where references to objects are added:
//                  * DefinedType.AttachedFile - (return value),
//                  a reference to the catalog item with file.
//
Procedure FillFilesAttachedToObject(Val FileOwner, Val Files) Export
	
	If TypeOf(FileOwner) = Type("CatalogRef.MetadataObjectIDs") Then
		Return;
	EndIf;
	
	OwnersTypes = Metadata.InformationRegisters.FilesExist.Dimensions.ObjectWithFiles.Type.Types();
	If OwnersTypes.Find(TypeOf(FileOwner)) <> Undefined Then
		
		LocalFileArray = FilesOperationsInternal.AllSubordinateFiles(FileOwner);
		For Each FileRef In LocalFileArray Do
			Files.Add(FileRef);
		EndDo;
		
	EndIf;
	
EndProcedure

// Returns a new reference to a file for the specified file owner.
// In particular, the reference is used when adding a file to the AddFile function.
//
// Parameters:
//  FilesOwner - DefinedType.AttachedFilesOwner - a file folder or an object, to which you need to 
//                   attach the file.
//
//  CatalogName - Undefined - find catalog by the owner (valid if catalog is unique, otherwise, an 
//                   exception is thrown).
//
//                 - String - the *AttachedFiles catalog name that is different from the default 
//                            <OwnerName>AttachedFiles.
//  
// Returns:
//  DefinedType.AttachedFile - a reference to the new and not yet written catalog item with the file.
//
Function NewRefToFile(FilesOwner, CatalogName = Undefined) Export
	
	ErrorTitle = NStr("ru = 'Ошибка при получении новой ссылки на присоединенный файл.'; en = 'Error when getting new references to the attached file.'; pl = 'Wystąpił błąd podczas pobierania nowego linku do załączonego pliku.';es_ES = 'Ha ocurrido un error al recibir una nueva referencia al archivo adjuntado.';es_CO = 'Ha ocurrido un error al recibir una nueva referencia al archivo adjuntado.';tr = 'Eklenen dosyaya yeni referans alınırken bir hata oluştu.';it = 'Errore durante la ricezione di nuovi riferimenti ai file allegati.';de = 'Beim Empfang eines neuen Verweises auf die angehängte Datei ist ein Fehler aufgetreten.'");
	
	CatalogName = FilesOperationsInternal.FileStoringCatalogName(
		FilesOwner, CatalogName, ErrorTitle);
	
	Return Catalogs[CatalogName].GetRef();
	
EndFunction

// Updates file properties without considering versions, which are binary data, text, modification 
// date, and also other optional properties. Use only for files that do not store versions.
//
// Parameters:
//  AttachedFile - DefinedType.AttachedFile - a reference to the catalog item with the file.
//  FileInfo - Structure - with the following properties:
//     <required>
//     * FileAddressInTempStorage - String - an address of file new binary data.
//     * TempTextStorageAddress - String - an address of text new binary data, extracted from a file.
//                                                 
//     <optional>
//     * BaseName               - String - if a property is not specified or not filled, it will not 
//                                                 be changed.
//     * ModificationDateUniversal   - Date   - last file modification date. If the property is not 
//                                                 specified or is blank, the current session date 
//                                                 is set.
//     * Extension                     - String - a new file extension.
//     * EditedBy                    - Ref - a user who edits the file.
//     * Encoding                      - String - optional. Encoding, in which the file is saved.
//                                                 See the list of supported encodings in the help 
//                                                 to the GetBinaryDataFromString global context method.
//
Procedure RefreshFile(Val AttachedFile, Val FileInfo) Export
	
	FilesOperationsInternal.RefreshFile(FileInfo, AttachedFile);
	
EndProcedure

// Returns attached file form name by owner.
//
// Parameters:
//  FilesOwner - DefinedType.AttachedFilesOwner - a file folder or an object, to which you need to 
//                       attach the file.
//
// Returns:
//  String - a full name of an attached file form by owner.
//
Function FilesObjectFormNameByOwner(Val FilesOwner) Export
	
	ErrorTitle = NStr("ru = 'Ошибка при получении имени формы присоединенного файла.'; en = 'Error when getting attached file form name.'; pl = 'Wystąpił błąd podczas pobierania nazwy formularza załączonego pliku.';es_ES = 'Ha ocurrido un error al recibir un nombre del formulario del archivo adjuntado.';es_CO = 'Ha ocurrido un error al recibir un nombre del formulario del archivo adjuntado.';tr = 'Ekli dosyanın form adı alınırken bir hata oluştu.';it = 'Errore durante la ricezione del nome del modulo del file allegato.';de = 'Beim Empfang eines Formularnamens der angehängten Datei ist ein Fehler aufgetreten.'");
	ErrorEnd = NStr("ru = 'В этом случае получение формы невозможно.'; en = 'Cannot receive form.'; pl = 'W tym przypadku formularz nie może zostać odebrany.';es_ES = 'En este caso, el formulario no puede recibirse.';es_CO = 'En este caso, el formulario no puede recibirse.';tr = 'Bu durumda, form alınamaz.';it = 'Impossibile ricevere il modulo.';de = 'In diesem Fall kann das Formular nicht empfangen werden.'");
	
	CatalogName = FilesOperationsInternal.FileStoringCatalogName(
		FilesOwner, "", ErrorTitle, ErrorEnd);
	
	FullMetadataObjectName = "Catalog." + CatalogName;
	
	AttachedFileMetadata = Metadata.FindByFullName(FullMetadataObjectName);
	
	If AttachedFileMetadata.DefaultObjectForm = Undefined Then
		FormName = FullMetadataObjectName + ".ObjectForm";
	Else
		FormName = AttachedFileMetadata.DefaultObjectForm.FullName();
	EndIf;
	
	Return FormName;
	
EndFunction

// Defines the possibility of attaching the file to add to the file owner.
//
// Parameters:
//  FilesOwner - DefinedType.AttachedFilesOwner - a file folder or an object, to which you need to 
//                       attach the file.
//  CatalogName - String - if specified, a check of adding in the definite file storage is executed.
//                            Otherwise, the catalog name will be defined by the owner.
//
// Returns:
//  Boolean - if True, files can be attached to the object.
//
Function CanAttachFilesToObject(FilesOwner, CatalogName = "") Export
	
	CatalogName = FilesOperationsInternal.FileStoringCatalogName(
		FilesOwner, CatalogName);
		
	CatalogAttachedFiles = Metadata.Catalogs.Find(CatalogName);
	
	StoredFileTypes = Metadata.DefinedTypes.AttachedFile.Type;
	
	Return CatalogAttachedFiles <> Undefined
		AND AccessRight("Insert", CatalogAttachedFiles)
		AND StoredFileTypes.ContainsType(Type("CatalogRef." + CatalogName));
	
EndFunction

// Adds a new file to the specified file owner based on the file from the file system.
// If the file owner supports version storage, the first file version will be created.
// 
// Parameters:
//   FilesOwner    - DefinedType.AttachedFilesOwner - a file folder or an object, to which you need 
//                       to attach the file.
//   FilePathOnHardDrive - String - a full file path on the hard drive, including a name and an extension of the file.
//                       File needs to be on the server.
//
// Returns:
//  DefinedType.AttachedFile - a reference to the catalog item with the created file.
//
Function CreateFileBasedOnFileOnHardDrive(FilesOwner, FilePathOnHardDrive) Export
	
	File = New File(FilePathOnHardDrive);
	
	BinaryData = New BinaryData(FilePathOnHardDrive);
	TempFileStorageAddress = PutToTempStorage(BinaryData);
	
	TempTextStorageAddress = "";
	
	If FilesOperationsInternal.ExtractTextFilesOnServer() Then
		// The scheduled job will extract a text.
		TempTextStorageAddress = ""; 
	Else
		// An attempt to extract a text if the server is under Windows.
		If FilesOperationsInternal.IsWindowsPlatform() Then
			Text = FilesOperationsInternalClientServer.ExtractText(FilePathOnHardDrive);
			TempTextStorageAddress = New ValueStorage(Text);
		EndIf;
	EndIf;
	
	FileInfo = FilesOperationsClientServer.FileInfo("FileWithVersion", File);
	FileInfo.TempFileStorageAddress = TempFileStorageAddress;
	FileInfo.TempTextStorageAddress = TempTextStorageAddress;
	Return FilesOperationsInternalServerCall.CreateFileWithVersion(FilesOwner, FileInfo);
	
EndFunction

// Handler of the subscription to FormGetProcessing event for overriding file form.
//
// Parameters:
//  Source                 - CatalogManager - the "*AttachedFiles" catalog manager.
//  FormKind                 - String - a standard form name.
//  Parameters                - Structure - structure parameters.
//  SelectedForm           - String - name or metadata object of opened form.
//  AdditionalInformation - Structure - an additional information of the form opening.
//  StandardProcessing     - Boolean - a flag of standard (system) event processing execution.
//
Procedure DetermineAttachedFileForm(Source, FormType, Parameters,
				SelectedForm, AdditionalInformation, StandardProcessing) Export
	
	IsVersionForm = False;
	
	If Source <> Undefined Then
		IsVersionForm = Common.HasObjectAttribute("ParentVersion", Metadata.FindByType(TypeOf(Source)));
	EndIf;
	
	If FormType = "FolderForm" Then
		SelectedForm = "DataProcessor.FilesOperations.Form.GroupOfFiles";
		StandardProcessing = False;
	ElsIf FormType = "ObjectForm" Then
		If Not IsVersionForm Then
			SelectedForm = "DataProcessor.FilesOperations.Form.AttachedFile";
			StandardProcessing = False;
		EndIf;
	ElsIf FormType = "ListForm" Then
		If Not IsVersionForm Then
			SelectedForm = "DataProcessor.FilesOperations.Form.AttachedFiles";
			StandardProcessing = False;
		EndIf;
	EndIf;
	
EndProcedure

// The BeforeWrite event handler of file owning objects.
// Defined for the Document objects only.
//
// Parameters:
//  Source        - DocumentObject           - standard parameter of the BeforeWrite event.
//  Cancel           - Boolean                   - standard parameter of the BeforeWrite event.
//  WriteMode     - DocumentWriteMode     - standard parameter of the BeforeWrite event.
//  PostingMode - DocumentPostingMode - standard parameter of the BeforeWrite event.
//
Procedure SetDeletionMarkOfDocumentsBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.DeletionMark <> Common.ObjectAttributeValue(Source.Ref, "DeletionMark") Then
		MarkForDeletionAttachedFiles(Source);
	EndIf;
	
EndProcedure

// The BeforeWrite event handler of file owning objects.
// Defined for objects, except for Document.
//
// Parameters:
//  Source - Object - the BeforeWrite event standard parameter, for example, CatalogObject.
//                      Exception - DocumentObject.
//  Cancel    - Boolean - standard parameter of the BeforeWrite event.
//
Procedure SetFilesDeletionMarkBeforeWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	If Source.DeletionMark <> Common.ObjectAttributeValue(Source.Ref, "DeletionMark") Then
		MarkForDeletionAttachedFiles(Source);
	EndIf;
	
EndProcedure

// Initializes a structure of parameters for adding a file.
// Use this function in FilesOperations.AddToFile.
//
// Parameters:
//   AdditionalAttributes - String, Array - comma-separated names of attached file attributes, or an 
//                           array of attribute names.
//                           - Structure - a collection of additional attributes. Missing standard properties will be
//                           added to the collection.
//
// Returns:
//   Structure - with the following properties:
//      * Author                       - CatalogRef.Users, CatalogRef.ExternalUsers,
//                                    CatalogRef.FileSynchronizationAccounts - a user or a file 
//                                    synchronization account on whose behalf a file will be created.
//                                    The default value is Undefined.
//      * FilesOwner              - DefinedType.AttachedFilesOwner - a file folder, or an object for 
//                                    attaching the file.
//                                    The default value is Undefined.
//      * NameWithoutExtension            - String - a file name without an extension.
//                                    The default value is "" (an empty string).
//      * ExtensionWithoutPointt          - String - a file extension (without a dot at the beginning).
//                                    The default value is "" (an empty string).
//      * ModificationTimeUniversal - Date - a date and a time of file modification (UTC). If the parameter value is
//                                    Undefined, the file modification time will be set to the 
//                                    result of the CurrentUniversalDate() function.
//                                    The default value is Undefined.
//      * FilesGroup                - DefinedType.AttachedFile - a folder of the files catalog that 
//                                    will store the file.
//                                    The default value is Undefined.
//      * Internal                   - Boolean - if True, the file will be hidden from users.
//                                    The default value is False.
//      * <AttributeName>             - Arbitrary - a value of a file attribute specified in the 
//                                    AdditionalAttributes parameter.
//                                    The default value is Undefined.
//
Function FileAddingOptions(AdditionalAttributes = Undefined) Export
	
	Return FilesOperationsInternalClientServer.FileAddingOptions(AdditionalAttributes);
	
EndFunction

// Creates an object in the catalog to storage the file and fills attributes with passed properties.
//
// Parameters:
//  FileParameters - Structure - parameters with file data.
//       * Author                        - Ref - a user that created the file.
//       * FilesOwner               - DefinedType.AttachedFilesOwner - a file folder or an object, 
//                                        to which you need to attach the file.
//       * BaseName             - String - file name without extension.
//       * ExtensionWithoutDot           - String - a file extension (without dot in the beginning).
//       * ModificationTimeUniversal  - Date   - a file modification date and time (UTC +0:00). If 
//                                        it is not specified, use CurrentUniversalDate().
//       * FilesGroup                 - Reference - a catalog group with files, where a new file will be added.
//       * Encoding                    - String - optional. Encoding, in which the file is saved.
//                                        See the list of supported encodings in the help to the global context method
//                                        GetBinaryDataFromString.
//  FileAddressInTemporaryStorage      - String - an address indicating binary data in the temporary storage.
//  TextTemporaryStorageAddress      - String - an address of a file extracted from the text in the temporary storage.
//  Details                            - String - the text file description.
//
//  NewRefToFile                   - Undefined - create a new reference to the file in the standard 
//                                        catalog or in unique nonstandard catalog. If file owner 
//                                        have more than one directories, reference to the file must 
//                                        be passed to avoid an exception.
//                                        - Reference - a reference to the file storage catalog item,
//                                        that is to be used when adding a file.
//                                        It must correspond to one of catalog types, where owner 
//                                        files are stored. A reference can be received by the NewFileRef function.
// Returns:
//  DefinedType.AttachedFile - a reference to created attached file.
//
Function AppendFile(FileParameters,
                     Val FileAddressInTempStorage,
                     Val TempTextStorageAddress = "",
                     Val Details = "",
                     Val NewRefToFile = Undefined) Export

	Author =              FileParameters.Author;
	FilesOwner =     FileParameters.FilesOwner;
	NameWithoutExtension  =  FileParameters.BaseName;
	ExtensionWithoutPoint = FileParameters.ExtensionWithoutPoint;
	GroupOfFiles = Undefined;
	If FileParameters.Property("GroupOfFiles") 
		AND ValueIsFilled(FileParameters.GroupOfFiles)
		AND Not FilesOperationsInternal.IsFilesFolder(FilesOwner) Then
		GroupOfFiles = FileParameters.GroupOfFiles;
	EndIf;
	ModificationTimeUniversal = FileParameters.ModificationTimeUniversal;

	If ExtensionWithoutPoint = Undefined Then
		FileNameParts = StrSplit(NameWithoutExtension, ".", False);
		If FileNameParts.Count() > 1 Then
			ExtensionWithoutPoint = FileNameParts[FileNameParts.Count()-1];
			NameWithoutExtension = Left(NameWithoutExtension, StrLen(NameWithoutExtension) - (StrLen(ExtensionWithoutPoint)+1));
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(ModificationTimeUniversal)
		Or ModificationTimeUniversal > CurrentUniversalDate() Then
		ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;
	
	BinaryData = GetFromTempStorage(FileAddressInTempStorage);
	
	ErrorTitle = NStr("ru = 'Ошибка при добавлении присоединенного файла.'; en = 'Error when adding attached file.'; pl = 'Wystąpił błąd podczas dodawania załączonego pliku.';es_ES = 'Ha ocurrido un error al añadir el archivo adjuntado.';es_CO = 'Ha ocurrido un error al añadir el archivo adjuntado.';tr = 'Eklenen dosya eklenirken bir hata oluştu.';it = 'Errore durante l''aggiunta del file allegato.';de = 'Beim Hinzufügen der angehängten Datei ist ein Fehler aufgetreten.'");
	
	If NewRefToFile = Undefined Then
		CatalogName = FilesOperationsInternal.FileStoringCatalogName(FilesOwner, "", ErrorTitle,
			NStr("ru = 'В этом случае параметр ""NewFileRef"" должен быть указан.'; en = 'In this case parameter ""NewFileRef"" must be specified.'; pl = 'W tym przypadku należy podać parametr ""NewFileRef"".';es_ES = 'En este caso, el parámetro NewFileRef tiene que especificarse.';es_CO = 'En este caso, el parámetro NewFileRef tiene que especificarse.';tr = 'Bu durumda, ""NewFileRef"" parametresi belirtilmelidir.';it = 'In questo caso deve essere indicato il parametro ""NewFileRef"".';de = 'In diesem Fall muss der Parameter ""NewFileRef"" angegeben werden.'"));
		
		NewRefToFile = Catalogs[CatalogName].GetRef();
	Else
		If Not Catalogs.AllRefsType().ContainsType(TypeOf(NewRefToFile))
			Or Not ValueIsFilled(NewRefToFile) Then
			
			Raise NStr("ru = 'Ошибка при добавлении присоединенного файла.
				|Ссылка на новый файл не заполнена.'; 
				|en = 'An error occurred when adding the attached file.
				|Reference to a new file is not specified.'; 
				|pl = 'Błąd podczas dodawania dołączonego pliku.
				|Nie podano linku do nowego pliku.';
				|es_ES = 'Error al añadir el archivo adjuntado.
				|Referencia al nuevo archivo no se ha rellenado.';
				|es_CO = 'Error al añadir el archivo adjuntado.
				|Referencia al nuevo archivo no se ha rellenado.';
				|tr = 'Eklenen dosya eklenirken hata oluştu. 
				|Yeni referans dosyası doldurulmadı.';
				|it = 'Si è verificato un errore durante l''aggiunta del file allegato.
				|Non è indicato un riferimento a un nuovo file.';
				|de = 'Fehler beim Hinzufügen der angehängten Datei.
				|Der Verweis auf die neue Datei ist nicht gefüllt.'");
		EndIf;
		
		CatalogName = FilesOperationsInternal.FileStoringCatalogName(
			FilesOwner, NewRefToFile.Metadata().Name, ErrorTitle);
	EndIf;
	
	AttachedFile = Catalogs[CatalogName].CreateItem();
	AttachedFile.SetNewObjectRef(NewRefToFile);
	
	AttachedFile.FileOwner                = FilesOwner;
	AttachedFile.UniversalModificationDate = ModificationTimeUniversal;
	AttachedFile.CreationDate                 = CurrentSessionDate();
	AttachedFile.Details                     = Details;
	AttachedFile.Description                 = NameWithoutExtension;
	AttachedFile.Extension                   = ExtensionWithoutPoint;
	AttachedFile.FileStorageType             = FilesOperationsInternal.FilesStorageTyoe();
	AttachedFile.Size                       = BinaryData.Size();
	If GroupOfFiles <> Undefined Then
		AttachedFile.Parent = GroupOfFiles;
	EndIf;
	
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	ExtractText = Metadata.Catalogs[CatalogName].FullTextSearch = FullTextSearchUsing;
	If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		BeginTransaction();
		Try
			OwnTransactionOpen = True;
			FilesOperationsInternal.WriteFileToInfobase(NewRefToFile, BinaryData);
			AttachedFile.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			AttachedFile.PathToFile = "";
			
			If ExtractText Then
				TextExtractionResult = FilesOperationsInternal.ExtractText(TempTextStorageAddress, 
					BinaryData, AttachedFile.Extension);
				AttachedFile.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
				AttachedFile.TextStorage = TextExtractionResult.TextStorage;
			Else
				AttachedFile.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
				AttachedFile.TextStorage = New ValueStorage("");
			EndIf;
			
			AttachedFile.Author = Author;
			AttachedFile.Fill(Undefined);
			AttachedFile.Write();			
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
			ErrorInformation = ErrorInfo();
			
			MessageTemplate = NStr("ru = 'Ошибка при добавлении присоединенного файла ""%1"":
				|%2'; 
				|en = 'An error occurred when adding attached file ""%1"":
				|%2'; 
				|pl = 'Błąd podczas dodawania dołączonego pliku ""%1"":
				|%2';
				|es_ES = 'Error al añadir el archivo vinculado ""%1"":
				|%2';
				|es_CO = 'Error al añadir el archivo vinculado ""%1"":
				|%2';
				|tr = 'Ekli dosya 
				|eklenirken bir hata oluştu ""%1"" :%2';
				|it = 'Si è verificato un errore durante l''aggiunta del file allegato ""%1"":
				|%2';
				|de = 'Fehler beim Hinzufügen einer angehängten Datei ""%1"":
				|%2'");
			EventLogComment = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				NameWithoutExtension + "." + ExtensionWithoutPoint,
				DetailErrorDescription(ErrorInformation));
			
			WriteLogEvent(
				NStr("ru = 'Файлы.Добавление присоединенного файла'; en = 'Files.Adding attached file'; pl = 'Plik. Dodawanie załączonego pliku';es_ES = 'Archivo.Añadiendo un archivo adjuntado';es_CO = 'Archivo.Añadiendo un archivo adjuntado';tr = 'Dosya. Ekli dosyanın eklenmesi.';it = 'File.Aggiunta file allegato';de = 'Datei. Hinzufügen einer angehängten Datei'",
				CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				EventLogComment);
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				NameWithoutExtension + "." + ExtensionWithoutPoint,
				BriefErrorDescription(ErrorInformation));
		EndTry;
	Else
		Try
			// Adding the file to a volume with sufficient free space.
			FileInfo = FilesOperationsInternal.AddFileToVolume(BinaryData, ModificationTimeUniversal,
				NameWithoutExtension, ExtensionWithoutPoint, , AttachedFile.Encrypted);
			AttachedFile.Volume = FileInfo.Volume;
			AttachedFile.PathToFile = FileInfo.PathToFile;
			
			If ExtractText Then
				TextExtractionResult = FilesOperationsInternal.ExtractText(TempTextStorageAddress, 
					BinaryData, AttachedFile.Extension);
				AttachedFile.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
				AttachedFile.TextStorage = TextExtractionResult.TextStorage;
			Else
				AttachedFile.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
				AttachedFile.TextStorage = New ValueStorage("");
			EndIf;
			
			AttachedFile.Author = Author;
			AttachedFile.Fill(Undefined);
			
			AttachedFile.Write();
			If FilesOperationsInternalServerCall.IsDirectoryFiles(FilesOwner) Then
				
				FileInfo = FilesOperationsClientServer.FileInfo("FileWithVersion");
				FileInfo.TempFileStorageAddress = FileAddressInTempStorage;
				FileInfo.TempTextStorageAddress = TempTextStorageAddress;
				FileInfo.WriteToHistory = True;
				FileInfo.BaseName = NameWithoutExtension;
				FileInfo.ExtensionWithoutPoint = AttachedFile.Extension;
				
				Version = FilesOperationsInternal.CreateVersion(AttachedFile.Ref, FileInfo);
				FilesOperationsInternal.UpdateVersionInFile(AttachedFile.Ref, Version, TempTextStorageAddress);
				
			EndIf;
			
		Except
			ErrorInformation = ErrorInfo();
			
			MessageTemplate = NStr("ru = 'Ошибка при добавлении присоединенного файла ""%1"":
				|%2'; 
				|en = 'An error occurred when adding attached file ""%1"":
				|%2'; 
				|pl = 'Błąd podczas dodawania dołączonego pliku ""%1"":
				|%2';
				|es_ES = 'Error al añadir el archivo vinculado ""%1"":
				|%2';
				|es_CO = 'Error al añadir el archivo vinculado ""%1"":
				|%2';
				|tr = 'Ekli dosya 
				|eklenirken bir hata oluştu ""%1"" :%2';
				|it = 'Si è verificato un errore durante l''aggiunta del file allegato ""%1"":
				|%2';
				|de = 'Fehler beim Hinzufügen einer angehängten Datei ""%1"":
				|%2'");
			EventLogComment = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				NameWithoutExtension + "." + ExtensionWithoutPoint,
				DetailErrorDescription(ErrorInformation));
			
			WriteLogEvent(
				NStr("ru = 'Файлы.Добавление присоединенного файла'; en = 'Files.Adding attached file'; pl = 'Plik. Dodawanie załączonego pliku';es_ES = 'Archivo.Añadiendo un archivo adjuntado';es_CO = 'Archivo.Añadiendo un archivo adjuntado';tr = 'Dosya. Ekli dosyanın eklenmesi.';it = 'File.Aggiunta file allegato';de = 'Datei. Hinzufügen einer angehängten Datei'",
				CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				EventLogComment);
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				NameWithoutExtension + "." + ExtensionWithoutPoint,
				BriefErrorDescription(ErrorInformation));
		EndTry;
	EndIf;
	
	If FileParameters.Property("Encoding")
		AND Not IsBlankString(FileParameters.Encoding) Then
		
		FilesOperationsInternalServerCall.WriteFileVersionEncoding(AttachedFile.Ref, FileParameters.Encoding);
		
	EndIf;
	
	Return AttachedFile.Ref;
	
EndFunction

// Returns a structure containing personal settings for operations with files.
//
// Returns:
//  Structure - with the following properties:
//    * ShowLockedFilesOnExit        - Boolean - available only if the "Stored files" subsystem is 
//                                                                  available.
//    * AskEditingModeOnOpenFile    - Boolean -exists only if the File operations subsystem is 
//                                                                  implemented. 
//    * ShowColumnSize                          - Boolean - available only if the "Stored files" 
//                                                                  subsystem is available.
//    * DoubleClickAction                     - String - exists only if the File operations 
//                                                                  subsystem is implemented.
//    * FilesVersionsComparisonMethod                      - String - exists only if the File 
//                                                                  operations subsystem is implemented.
//    * GraphicalSchemasExtension                       - String - a list of extensions for graphical schemas.
//    * GraphicalSchemasOpeningMethod                   - EnumRef.OpenFileToViewOpeningMethods - a 
//        method to open graphical schemas.
//    * TextFilesExtension                         - String - an open document format file extension.
//    * TextFilesOpeningMethod                     - EnumRef.OpenFileToViewOpeningMethods - a method 
//        of opening text files.
//    * LocalFIlesCacheMaxSize           - Number - determines the maximum size of the local file cache.
//    * ConfirmOnDeleteFromLocalFilesCache    - Boolean - ask the question when deleting files from the local cache.
//    * ShowInformationThatFileNotChanged          - Boolean - show files when the job is completed.
//    * ShowTooltipsOnEditFIles       - Boolean - show tooltips in web client when editing files.
//                                                                  
//    * PathToLocalFilesCache                        - String - a path to local file cache.
//    * IsFullUser                      - Boolean - True if a user has full access.
//    * DeleteFileFromLocalFilesCacheOnCompleteEditing - Boolean - delete files from the local cache 
//                                                                              when complete editing.
//
Function FilesOperationSettings() Export
	
	Return FilesOperationsInternalClientServer.PersonalFilesOperationsSettings();
	
EndFunction

// Returns maximum file size.
//
// Returns:
//  Number - number of bytes (integer).
//
Function MaxFileSize() Export
	
	SetPrivilegedMode(True);
	
	SeparationEnabledAndAvailableUsage = (Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable());
		
	ConstantName = ?(SeparationEnabledAndAvailableUsage, "MaxDataAreaFileSize", "MaxFileSize");
	
	MaxFileSize = Constants[ConstantName].Get();
	
	If NOT ValueIsFilled(MaxFileSize) Then
		MaxFileSize = 52428800; // 50*1024*1024 = 50 MB
	EndIf;
	
	If SeparationEnabledAndAvailableUsage Then
		GlobalMaxFileSize = Constants.MaxFileSize.Get();
		GlobalMaxFileSize = ?(ValueIsFilled(GlobalMaxFileSize),
			GlobalMaxFileSize, 52428800);
		MaxFileSize           = Min(MaxFileSize, GlobalMaxFileSize);
	EndIf;
	
	Return MaxFileSize;
	
EndFunction

// Returns maximum provider file size.
//
// Returns:
//  Number - number of bytes (integer).
//
Function MaxFileSizeCommon() Export
	
	SetPrivilegedMode(True);
	
	MaxFileSize = Constants.MaxFileSize.Get();
	
	If MaxFileSize = Undefined
	 OR MaxFileSize = 0 Then
		
		MaxFileSize = 50*1024*1024; // 50 MB
	EndIf;
	
	Return MaxFileSize;
	
EndFunction

// Saves settings of operations with files.
//
// Parameters:
//  FilesOperationsSettings - Structure - settings of operations with files and their values.
//     * ShowInfoFileNotModified        - Boolean - optional. Show message if the file has not been 
//                                                                 modified.
//     * ShowLockedFilesOnExit      - Boolean - optional. Show files on exit.
//     * ShowSizeColumn                        - Boolean - optional. Display size column in the file 
//                                                                 list forms.
//     * TextFilesExtension                       - String - an open document format file extension.
//     * TextFilesOpeningMethod                   - EnumRef.OpenFileToViewOpeningMethods  - a method 
//         of opening text files.
//     * GraphicalSchemasExtension                     - String - a list of graphical file extensions.
//     * ShowTooltipsOnEditFiles     - Boolean - optional. Show tooltips in web client when editing 
//                                                                 files.
//     * AskEditingModeOnOpenFile  - Boolean - optional. Select editing mode when opening the file.
//                                                                 
//     * FileVersionsComparisonMethod                    - EnumRef.FileVersionsComparisonMethods -
//                                                        Optional. Files and versions comparison method
//     * DoubleClickAction                   - EnumRef.DoubleClickFilesActions - optional.
//     * GraphicalSchemasOpeningMethod                 - EnumRef.OpenFileToViewOpeningMethods -
//                                                        Optional. a method to open graphical schemas.
//
Procedure SaveFilesOperationSettings(FilesOperationSettings) Export
	
	FilesOperationSettingsObjectsKeys = FilesOperationSettingsObjectsKeys();
	
	For Each Setting In FilesOperationSettings Do
		
		ObjectKeySettings = FilesOperationSettingsObjectsKeys[Setting.Key];
		If ObjectKeySettings <> Undefined Then
			If StrStartsWith(ObjectKeySettings, "OpenFileSettings\") Then
				SettingFilesType = StrReplace(ObjectKeySettings, "OpenFileSettings\", "");
				Common.CommonSettingsStorageSave(ObjectKeySettings,
					StrReplace(Setting.Key, SettingFilesType, ""), Setting.Value);
			Else
				Common.CommonSettingsStorageSave(ObjectKeySettings, Setting.Key, Setting.Value);
			EndIf;
			
		EndIf;
	
	EndDo;
	
EndProcedure

// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	AttributesToEdit = New Array;
	AttributesToEdit.Add("Details");
	AttributesToEdit.Add("BeingEditedBy");
	
	Return AttributesToEdit;
	
EndFunction

// Transfers files from the Files catalog to the attached files with the file owner object and marks 
// the transferred files for deletion.
//
// For use in infobase update procedures if a transition is made from using file storage in the 
// Files catalog to store files as attached to the file owner object.
// The procudure is executed sequentially for each item of the file owner object(catalog, CCT, 
// document item etc.).
//
// Parameters:
//   FilesOwner - DefinedType.AttachedFilesOwner - an object that is owner and file destination.
//   CatalogName - String - if a conversion to the specified storage is required.
//
// Returns:
//  Map - files:
//   * Key     - CatalogRef.Files - a transferred files that is marked for deletion after transferring it.
//   * Value - DefinedType.AttachedFile - the created file.
//
Function ConvertFilesToAttachedFiles(Val FilesOwner, CatalogName = Undefined) Export
	
	Result = New Map;
	If Not Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		Return Result;
	EndIf;
	
	ErrorTitle = NStr("ru = 'Ошибка при конвертации присоединенных файлов подсистемы Работа с файлами
	                             |в присоединенные файлы подсистемы Присоединенные файлы.'; 
	                             |en = 'An error occurred when converting attached files of the ""File operations"" subsystem
	                             |into attached files of the ""Attached files"" subsystem.'; 
	                             |pl = 'Wystąpił błąd podczas konwertowania załączonych plików podsystemu.
	                             |Praca z plikami w załączonych plikach podsystemu Załączone pliki';
	                             |es_ES = 'Ha ocurrido un error al convertir los archivos adjuntados del subsistema.
	                             |Trabajar con archivos para los archivos adjuntados del Subsistema de archivos adjuntados.';
	                             |es_CO = 'Ha ocurrido un error al convertir los archivos adjuntados del subsistema.
	                             |Trabajar con archivos para los archivos adjuntados del Subsistema de archivos adjuntados.';
	                             |tr = 'Alt sistem ekli dosyaları dönüştürülürken bir hata oluştu 
	                             |Ekli dosyalar alt sisteminin ekli dosyalarıyla çalışın.';
	                             |it = 'Si è verificato un errore durante la conversione dei file allegati del sotto sistema ""Operazioni file""
	                             |in file allegati del sotto sistema ""File allegati"".';
	                             |de = 'Beim Konvertieren der mit dem Subsystem verbundenen Dateien ist ein Fehler aufgetreten.
	                             |Arbeiten Sie mit Dateien zu angehängten Dateien des Subsystems für angehängte Dateien.'");
	
	CatalogName = FilesOperationsInternal.FileStoringCatalogName(
		FilesOwner, CatalogName, ErrorTitle);
		
	SetPrivilegedMode(True);
	
	SourceFiles = FilesOperationsInternalServerCall.GetAllSubordinateFiles(FilesOwner);
	AttachedFileManager = Catalogs[CatalogName];
	
	BeginTransaction();
	Try
		
		For Each SourceFile In SourceFiles Do
			SourceFileObject = SourceFile.GetObject();
			// Set an exclusive lock on the source file in order to ensure that at the time of writing it its 
			// attribute values will not change.
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.Catalogs.Files.FullName());
			DataLockItem.SetValue("Ref", SourceFileObject.Ref);
			DataLock.Lock();

			If ValueIsFilled(SourceFileObject.CurrentVersion) Then
				CurrentVersionObject = SourceFileObject.CurrentVersion.GetObject();
				// Set an exclusive lock on the current source file version in order to ensure that at the time of 
				// writing it its attribute values will not change.
				DataLock = New DataLock;
				DataLockItem = DataLock.Add(Metadata.Catalogs.FilesVersions.FullName());
				DataLockItem.SetValue("Ref", CurrentVersionObject.Ref);
				DataLock.Lock();
			Else
				CurrentVersionObject = SourceFileObject;
			EndIf;
			
			NewRef = AttachedFileManager.GetRef();
			AttachedFile = AttachedFileManager.CreateItem();
			AttachedFile.SetNewObjectRef(NewRef);
			
			AttachedFile.FileOwner                = FilesOwner;
			AttachedFile.Description                 = SourceFileObject.Description;
			AttachedFile.Author                        = SourceFileObject.Author;
			AttachedFile.UniversalModificationDate = CurrentVersionObject.UniversalModificationDate;
			AttachedFile.CreationDate                 = SourceFileObject.CreationDate;
			
			AttachedFile.Encrypted                   = SourceFileObject.Encrypted;
			AttachedFile.Changed                      = CurrentVersionObject.Author;
			AttachedFile.Details                     = SourceFileObject.Details;
			AttachedFile.SignedWithDS                   = SourceFileObject.SignedWithDS;
			AttachedFile.Size                       = CurrentVersionObject.Size;
			
			AttachedFile.Extension                   = CurrentVersionObject.Extension;
			AttachedFile.BeingEditedBy                  = SourceFileObject.BeingEditedBy;
			AttachedFile.TextStorage               = SourceFileObject.TextStorage;
			AttachedFile.FileStorageType             = CurrentVersionObject.FileStorageType;
			AttachedFile.DeletionMark              = SourceFileObject.DeletionMark;
			
			// If the file is stored in a volume, make a reference to the existing file.
			AttachedFile.Volume                          = CurrentVersionObject.Volume;
			AttachedFile.PathToFile                   = CurrentVersionObject.PathToFile;
			
			For Each EncryptionCertificateRow In SourceFileObject.DeleteEncryptionCertificates Do
				NewRow = AttachedFile.DeleteEncryptionCertificates.Add();
				FillPropertyValues(NewRow, EncryptionCertificateRow);
			EndDo;
			
			If ValueIsFilled(SourceFileObject.CurrentVersion) Then
				For Each DigitalSignatureString In CurrentVersionObject.DeleteDigitalSignatures Do
					NewRow = AttachedFile.DeleteDigitalSignatures.Add();
					FillPropertyValues(NewRow, DigitalSignatureString);
				EndDo;
			EndIf;
			AttachedFile.Fill(Undefined);
			
			AttachedFile.Write();
			
			If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
				FileStorage = FileFromInfobaseStorage(CurrentVersionObject.Ref);
				
				// If the file's binary data is missing in the infobase, skip moving it but keep the file card.
				// This is possible after performing the clearing unnecessary files or due to incorrect exchange or import errors.
				If FileStorage <> Undefined Then
					RecordManager = InformationRegisters.FilesBinaryData.CreateRecordManager();
					RecordManager.File = NewRef;
					RecordManager.Read();
					RecordManager.File = NewRef;
					RecordManager.FileBinaryData = New ValueStorage(FileStorage.Get(), New Deflation(9));
					RecordManager.Write();
				EndIf;
			EndIf;
			
			CurrentVersionObject.DeletionMark = True;
			SourceFileObject.DeletionMark = True;
			
			// Delete references to volume in the old file, to prevent file deleting.
			If CurrentVersionObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
				CurrentVersionObject.PathToFile = "";
				CurrentVersionObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				SourceFileObject.PathToFile = "";
				SourceFileObject.Volume = "";
				If ValueIsFilled(SourceFileObject.CurrentVersion) Then
					FilesOperationsInternal.MarkForDeletionFileVersions(SourceFileObject.Ref, CurrentVersionObject.Ref);
				EndIf;
			EndIf;
			
			If ValueIsFilled(SourceFileObject.CurrentVersion) Then
				CurrentVersionObject.AdditionalProperties.Insert("FileConversion", True);
				CurrentVersionObject.Write();
			EndIf;
			
			SourceFileObject.AdditionalProperties.Insert("FileConversion", True);
			SourceFileObject.Write();
			Result.Insert(SourceFileObject.Ref, NewRef);
			
		EndDo;
		
		CommitTransaction();
	
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
	
EndFunction

// Converts files from the File operations subsystem to the Attached files subsystem.
//
// The procedure is used in the infobase update procedures, if any file owner object is transfered 
// from using one subsystem to another.
// The procudure is executed sequentially for each item of the file owner object(catalog, CCT, 
// document item etc.).
//
// Parameters:
//   FilesOwner - Reference - a reference to the object being converted.
//   CatalogName - String - if a conversion to the specified storage is required.
//
Procedure ChangeFilesStoragecatalog(Val FilesOwner, CatalogName = Undefined) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		Return;
	EndIf;
	
	ErrorTitle = NStr("ru = 'Ошибка при конвертации присоединенных файлов подсистемы Работа с файлами
	                             |в присоединенные файлы подсистемы Присоединенные файлы.'; 
	                             |en = 'An error occurred when converting attached files of the ""File operations"" subsystem
	                             |into attached files of the ""Attached files"" subsystem.'; 
	                             |pl = 'Wystąpił błąd podczas konwertowania załączonych plików podsystemu.
	                             |Praca z plikami w załączonych plikach podsystemu Załączone pliki';
	                             |es_ES = 'Ha ocurrido un error al convertir los archivos adjuntados del subsistema.
	                             |Trabajar con archivos para los archivos adjuntados del Subsistema de archivos adjuntados.';
	                             |es_CO = 'Ha ocurrido un error al convertir los archivos adjuntados del subsistema.
	                             |Trabajar con archivos para los archivos adjuntados del Subsistema de archivos adjuntados.';
	                             |tr = 'Alt sistem ekli dosyaları dönüştürülürken bir hata oluştu 
	                             |Ekli dosyalar alt sisteminin ekli dosyalarıyla çalışın.';
	                             |it = 'Si è verificato un errore durante la conversione dei file allegati del sotto sistema ""Operazioni file""
	                             |in file allegati del sotto sistema ""File allegati"".';
	                             |de = 'Beim Konvertieren der mit dem Subsystem verbundenen Dateien ist ein Fehler aufgetreten.
	                             |Arbeiten Sie mit Dateien zu angehängten Dateien des Subsystems für angehängte Dateien.'");
	
	CatalogName = FilesOperationsInternal.FileStoringCatalogName(
		FilesOwner, CatalogName, ErrorTitle);
		
	SetPrivilegedMode(True);
	
	SourceFiles = FilesOperationsInternalServerCall.GetAllSubordinateFiles(FilesOwner);
	AttachedFileManager = Catalogs[CatalogName];
	
	BeginTransaction();
	Try
		
		For Each SourceFile In SourceFiles Do
			SourceFileObject = SourceFile.GetObject();
			// Set an exclusive lock on the source file in order to ensure that at the time of writing it its 
			// attribute values will not change.
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.Catalogs.Files.FullName());
			DataLockItem.SetValue("Ref", SourceFileObject.Ref);
			DataLock.Lock();

			If ValueIsFilled(SourceFileObject.CurrentVersion) Then
				CurrentVersionObject = SourceFileObject.CurrentVersion.GetObject();
				// Set an exclusive lock on the current source file version in order to ensure that at the time of 
				// writing it its attribute values will not change.
				DataLock = New DataLock;
				DataLockItem = DataLock.Add(Metadata.Catalogs.FilesVersions.FullName());
				DataLockItem.SetValue("Ref", CurrentVersionObject.Ref);
				DataLock.Lock();
			Else
				CurrentVersionObject = SourceFileObject;
			EndIf;
			
			NewRef = AttachedFileManager.GetRef();
			AttachedFile = AttachedFileManager.CreateItem();
			AttachedFile.SetNewObjectRef(NewRef);
			
			AttachedFile.FileOwner                = FilesOwner;
			AttachedFile.Description                 = SourceFileObject.Description;
			AttachedFile.Author                        = SourceFileObject.Author;
			AttachedFile.UniversalModificationDate = CurrentVersionObject.UniversalModificationDate;
			AttachedFile.CreationDate                 = SourceFileObject.CreationDate;
			
			AttachedFile.Encrypted                   = SourceFileObject.Encrypted;
			AttachedFile.Changed                      = CurrentVersionObject.Author;
			AttachedFile.Details                     = SourceFileObject.Details;
			AttachedFile.SignedWithDS                   = SourceFileObject.SignedWithDS;
			AttachedFile.Size                       = CurrentVersionObject.Size;
			
			AttachedFile.Extension                   = CurrentVersionObject.Extension;
			AttachedFile.BeingEditedBy                  = SourceFileObject.BeingEditedBy;
			AttachedFile.TextStorage               = SourceFileObject.TextStorage;
			AttachedFile.FileStorageType             = CurrentVersionObject.FileStorageType;
			AttachedFile.DeletionMark              = SourceFileObject.DeletionMark;
			
			// If the file is stored in a volume, make a reference to the existing file.
			AttachedFile.Volume                          = CurrentVersionObject.Volume;
			AttachedFile.PathToFile                   = CurrentVersionObject.PathToFile;
			
			For Each EncryptionCertificateRow In SourceFileObject.DeleteEncryptionCertificates Do
				NewRow = AttachedFile.DeleteEncryptionCertificates.Add();
				FillPropertyValues(NewRow, EncryptionCertificateRow);
			EndDo;
			
			If ValueIsFilled(SourceFileObject.CurrentVersion) Then
				For Each DigitalSignatureString In CurrentVersionObject.DeleteDigitalSignatures Do
					NewRow = AttachedFile.DeleteDigitalSignatures.Add();
					FillPropertyValues(NewRow, DigitalSignatureString);
				EndDo;
			EndIf;
			AttachedFile.Fill(Undefined);
			
			AttachedFile.Write();
			
			If AttachedFile.FileStorageType = Enums.FileStorageTypes.InInfobase Then
				FileStorage = FileFromInfobaseStorage(CurrentVersionObject.Ref);
				
				RecordManager = InformationRegisters.FilesBinaryData.CreateRecordManager();
				RecordManager.File = NewRef;
				RecordManager.Read();
				RecordManager.File = NewRef;
				RecordManager.FileBinaryData = New ValueStorage(FileStorage.Get(), New Deflation(9));
				RecordManager.Write();
			EndIf;
			
			CurrentVersionObject.DeletionMark = True;
			SourceFileObject.DeletionMark = True;
			
			// Delete references to volume in the old file, to prevent file deleting.
			If CurrentVersionObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
				CurrentVersionObject.PathToFile = "";
				CurrentVersionObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				SourceFileObject.PathToFile = "";
				SourceFileObject.Volume = "";
				If ValueIsFilled(SourceFileObject.CurrentVersion) Then
					FilesOperationsInternal.MarkForDeletionFileVersions(SourceFileObject.Ref, CurrentVersionObject.Ref);
				EndIf;
			EndIf;
			
			If ValueIsFilled(SourceFileObject.CurrentVersion) Then
				CurrentVersionObject.AdditionalProperties.Insert("FileConversion", True);
				CurrentVersionObject.Write();
			EndIf;
			
			SourceFileObject.AdditionalProperties.Insert("FileConversion", True);
			SourceFileObject.Write();
			
		EndDo;
		
		CommitTransaction();
	
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// OnWriteAtServer event handler of the file owner managed form.
//
// Parameters:
//  Cancel - Boolean  - standard parameter of OnWriteAtServer managed form event.
//  CurrentObject   - Object - standard parameter of OnWriteAtServer managed form event.
//  WriteParameters - Structure - standard parameter of OnWriteAtServer managed form event.
//  Parameters       - FormDataStructure - the Managed form parameters property.
//
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters, Parameters) Export
	
	If ValueIsFilled(Parameters.CopyingValue) Then
		
		FilesOperationsInternal.CopyAttachedFiles(
			Parameters.CopyingValue, CurrentObject);
	EndIf;
	
EndProcedure

// Places hyperlinks and fields of attached files on the managed form.
//
// Parameters:
//  Form               - ClientApplicationForm - a form.
//  ItemsToAdd - Structure, Array - parameters of attached file controls to place on the form, or an 
//                      array of such structures.
//                       Properties: see FilesOperations.FilesHyperlink and FilesOperations. 
//                      FileField.
//
// Example:
//  1. Adding hyperlink of attached files:
//   HyperlinkParameters = FilesOperations.FilesHyperlink();
//   HyperlinkParameters.Placement = "CommandBar";
//   FilesOperations.OnCreateAtServer(ThisObject, HyperlinkParameters);
//
//  2. Adding image field:
//   FieldParameters = FilesOperations.FileField();
//   FieldParameters.DataPath = "Object.PictureFile";
//   FieldParameters.ImageDataPath = "PictureAddress";
//   FilesOperations.OnCreateAtServer(ThisObject, FieldParameters);
//
//  3. Adding several controls:
//   ItemsToAdd = New Array;
//   ItemsToAdd.Add(HyperlinkParameters);
//   ItemsToAdd.Add(FieldParameters);
//   FilesOperations.OnCreateAtServer(ThisObject, ItemsToAdd);
//
Procedure OnCreateAtServer(Form, ItemsToAdd = Undefined) Export
	
	If ItemsToAdd = Undefined Then
		Return;
	EndIf;
		
	If TypeOf(ItemsToAdd) = Type("Structure") Then
		ItemParameters = ItemsToAdd;
		ItemsToAdd = New Array;
		ItemsToAdd.Add(ItemParameters);
	EndIf;
	
	ItemsCount = ItemsToAdd.Count();
	For Index = 1 To ItemsCount Do
		
		ItemToAdd = ItemsToAdd[ItemsCount - Index];
		If ItemToAdd.Property("Visible")
			AND Not ItemToAdd.Visible Then
			ItemsToAdd.Delete(ItemsCount - Index);
		EndIf;
		
	EndDo;
	
	If ItemsToAdd.Count() = 0 Then
		Return;
	EndIf;
	
	FormAttributes = Form.GetAttributes();
	
	AttributesToAdd = New Array;
	If FormAttributeByName(FormAttributes, "FilesOperationsParameters") = Undefined Then
		AttributesToAdd.Add(New FormAttribute("FilesOperationsParameters", New TypeDescription()));
	EndIf;
	
	For Index = 0 To ItemsToAdd.UBound() Do
		
		ItemNumber = Format(Index, "NZ=0; NG=");
		ItemToAdd = ItemsToAdd[Index];
		
		If ItemToAdd.Property("DataPath") Then
			
			If StrFind(ItemToAdd.DataPath, ".") Then
				FullDataPath = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
					ItemToAdd.DataPath, ".", True, True);
			Else
				FullDataPath = New Array;
				FullDataPath.Add(ItemToAdd.DataPath);
			EndIf;
			
			PlacementAttribute = FormAttributeByName(FormAttributes, FullDataPath[0]);
			If PlacementAttribute <> Undefined Then
				
				PathToAttribute = FullDataPath[0];
				For AttributeIndex = 1 To FullDataPath.UBound() Do
					
					SubordinateAttributes = Form.GetAttributes(PathToAttribute);
					PlacementAttribute   = FormAttributeByName(SubordinateAttributes, FullDataPath[AttributeIndex]);
					If PlacementAttribute = Undefined Then
						Break;
					EndIf;
					
					PathToAttribute = PathToAttribute + FullDataPath[AttributeIndex];
					
				EndDo;
				
			EndIf;
			
			If PlacementAttribute = Undefined Then
				
				AttachedAttachedFiles = Metadata.DefinedTypes.AttachedFile.Type;
				PlacementAttribute = New FormAttribute("AttachedFileField" + ItemNumber, AttachedAttachedFiles);
				AttributesToAdd.Add(PlacementAttribute);
				
				PlacementAttribute = Form["AttachedFileField" + ItemNumber];
				ItemToAdd.DataPath = "AttachedFileField" + ItemNumber;
				
			EndIf;
			
			If ItemToAdd.Property("ShowPreview")
				AND ItemToAdd.ShowPreview Then
				
				If FormAttributeByName(FormAttributes, ItemToAdd.PathToPictureData) = Undefined Then
					
					PictureAttribute = New FormAttribute("AttachedFilePictureField" + ItemNumber,
						New TypeDescription("String"));
					AttributesToAdd.Add(PictureAttribute);
					
					ItemToAdd.PathToPictureData = "AttachedFilePictureField" + ItemNumber;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If AttributesToAdd.Count() > 0 Then
		Form.ChangeAttributes(AttributesToAdd);
	EndIf;
	
	FilesOperationsParameters = New Array;
	For Index = 0 To ItemsToAdd.UBound() Do
		
		ItemNumber = Format(Index, "NZ=0; NG=");
		GroupName = "AttachedFilesManagementGroup" + ItemNumber;
		
		ItemToAdd = ItemsToAdd[Index];
		FullOwnerDataPath = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
			ItemToAdd.Owner, ".", True, True);
		
		AttachedFilesOwner = FormAttributeByName(FormAttributes, FullOwnerDataPath[0]);
		If AttachedFilesOwner = Undefined Then
			Continue;
		EndIf;
		
		PathToAttribute = FullOwnerDataPath[0];
		For AttributeIndex = 1 To FullOwnerDataPath.UBound() Do
			
			SubordinateAttributes         = Form.GetAttributes(PathToAttribute);
			AttachedFilesOwner = FormAttributeByName(SubordinateAttributes, FullOwnerDataPath[AttributeIndex]);
			If AttachedFilesOwner = Undefined Then
				Break;
			EndIf;
			
			PathToAttribute = PathToAttribute + FullOwnerDataPath[AttributeIndex];
			
		EndDo;
		
		AttachedFilesOwner = Form[FullOwnerDataPath[0]];
		For Counter = 1 To FullOwnerDataPath.UBound() Do
			AttachedFilesOwner = AttachedFilesOwner[FullOwnerDataPath[Counter]];
		EndDo;
		
		FilesStorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(
			AttachedFilesOwner, "", "", "");
			
		FileCatalogType = Type("CatalogRef." + FilesStorageCatalogName);
		MetadataOfCatalogWithFiles = Metadata.FindByType(FileCatalogType);
		
		If Not AccessRight("Read", MetadataOfCatalogWithFiles) Then
			Continue;
		EndIf;
		
		AdditionAvailable = AccessRight("InteractiveInsert", MetadataOfCatalogWithFiles);
		UpdateAvailable = AccessRight("Update", MetadataOfCatalogWithFiles);
		
		ItemParameters = New Structure;
		ItemParameters.Insert("OneFileOnly"          , False);
		ItemParameters.Insert("MaxSize"      , 0);
		ItemParameters.Insert("SelectionDialogFilter"     , "");
		ItemParameters.Insert("DisplayCount"    , False);
		ItemParameters.Insert("PathToPictureData"  , "");
		ItemParameters.Insert("PathToPlacementAttribute", "");
		ItemParameters.Insert("NonselectedPictureText", "");
		FillPropertyValues(ItemParameters, ItemToAdd);
		
		FormItemParameters = New Structure;
		FormItemParameters.Insert("NameOfGroup",          GroupName);
		FormItemParameters.Insert("ItemNumber",      ItemNumber);
		FormItemParameters.Insert("UpdateAvailable",  UpdateAvailable);
		FormItemParameters.Insert("AdditionAvailable", AdditionAvailable);
		
		If ItemToAdd.Property("DataPath") Then
			
			ItemParameters.PathToPlacementAttribute = ItemToAdd.DataPath;
			CreateFileField(Form, ItemToAdd, AttachedFilesOwner, FormItemParameters);
			
		Else
			CreateFilesHyperlink(Form, ItemToAdd, AttachedFilesOwner, FormItemParameters);
		EndIf;
		
		ItemParameters.Insert("PathToOwnerData", ItemToAdd.Owner);
		FilesOperationsParameters.Add(ItemParameters);
		
	EndDo;
	
	Form["FilesOperationsParameters"] = New FixedArray(FilesOperationsParameters);
	
EndProcedure

// Initializes parameter structure to place a hyperlink of attached files on the form.
//
// Returns:
//  Structure - a hyperlink placement parameters. Properties:
//    * Owner                   - String - name of an attribute that contains a reference to attached file owner.
//                                 Default value is "Object.Ref".
//    * Placement                 - String, Undefined - if a group form name or a command bar are 
//                                 specified, hyperlink will be placed to the specified group or panel. 
//                                 If a form item name is specified, a hyperlink will be inserted before the specified item. 
//                                 If parameter value is Undefined or item is not found, hyperlink 
//                                 will be added on the form after all existing items.
//                                 Default value is "AttachedFilesManagement".
//    * Title                  - String - a hyperlink title. Default value is "Files".
//    * DisplayTitleRight  - Boolean - if parameter value is True, title will be displayed after 
//                                 addition commands, otherwise, it will be displayed before addition commands.
//                                 Default value is True.
//    * DisplayCount       - Boolean - if parameter is True, it displays the number of attached 
//                                 files in the title. The default value is True.
//    * AddFiles             - Boolean - if you specify True, commands for adding files will be missing.
//                                 The default value is True.
//    * FigureDisplay          - String - a string presentation of the FigureDisplay property for 
//                                 commands of adding attached files. Default value is Auto.
//    * Visibility                  - Boolean - if parameter takes the False value, hyperlink will 
//                                 not be placed to the form. The parameter makes sense only if 
//                                 visibility in the FilesOperationsOverridable.OnDefineFilesHyperlink procedure is globally disabled.
//
Function FilesHyperlink() Export
	
	HyperlinkParameters = New Structure;
	HyperlinkParameters.Insert("Owner",                  "Object.Ref");
	HyperlinkParameters.Insert("Placement",                "AttachedFilesManagement");
	HyperlinkParameters.Insert("Title",                 NStr("ru = 'Файлы'; en = 'Files'; pl = 'Pliki';es_ES = 'Archivos';es_CO = 'Archivos';tr = 'Dosyalar';it = 'File';de = 'Dateien'"));
	HyperlinkParameters.Insert("DisplayTitleRight", True);
	HyperlinkParameters.Insert("DisplayCount",      True);
	HyperlinkParameters.Insert("AddFiles",            True);
	HyperlinkParameters.Insert("ShapeRepresentation",         "Auto");
	HyperlinkParameters.Insert("Visible",                 True);
	
	FilesOperationsOverridable.OnDefineFilesHyperlink(HyperlinkParameters);
	
	Return HyperlinkParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Managing file volumes

// Determines the existence of current file storage volumes.
// If there is at least one file storage volume, True will be returned.
//
// Returns:
//  Boolean - if True, at least one working volume exisits.
//
Function HasFileStorageVolumes() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

// Returns references to objects with files.
//
// Use with ConvertFilesToAttachedFiles function.
//
// Parameters:
//  FilesOwnersTableName - String - a full name of the metadata object that can own attached files.
//                            
//
// Returns:
//  Array - with the following values:
//   * Reference - a reference to the object that has at least one attached file.
//
Function ReferencesToObjectsWithFiles(Val FilesOwnersTableName) Export
	
	Return FilesOperationsInternal.ReferencesToObjectsWithFiles(FilesOwnersTableName);
	
EndFunction

// Adds a digital signature to file
//
// Parameters:
//  AttachedFile - DefinedType.AttachedFile - a reference to the catalog item with the file.
//
//  SignatureProperties    - Structure - contains data that the Sign procedure of the 
//                       DigitalSignatureClient returns as a result.
//                     - Array - an array of structures described above:
//                     
//  FormID - UUID - if specified, it is used when locking an object.
//
Procedure AddSignatureToFile(AttachedFile, SignatureProperties, FormID = Undefined) Export
	
	If Common.IsReference(TypeOf(AttachedFile)) Then
		AttributesStructure = Common.ObjectAttributesValues(AttachedFile, "BeingEditedBy, Encrypted");
		AttachedFileRef = AttachedFile;
	Else
		AttributesStructure = New Structure("BeingEditedBy, Encrypted");
		AttributesStructure.BeingEditedBy = AttachedFile.BeingEditedBy;
		AttributesStructure.Encrypted  = AttachedFile.Encrypted;
		AttachedFileRef = AttachedFile.Ref;
	EndIf;
	
	CommonClientServer.CheckParameter("AttachedFiles.AddSignatureToFile", "AttachedFile", 
		AttachedFileRef, Metadata.DefinedTypes.AttachedFile.Type);
		
	If ValueIsFilled(AttributesStructure.BeingEditedBy) Then
		Raise FilesOperationsInternalClientServer.FileUsedByAnotherProcessCannotBeSignedMessageString(AttachedFileRef);
	EndIf;
	
	If AttributesStructure.Encrypted Then
		Raise FilesOperationsInternalClientServer.EncryptedFileCannotBeSignedMessageString(AttachedFileRef);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		ModuleDigitalSignature.AddSignature(AttachedFile, SignatureProperties, FormID);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Managing file encodings

// Returns a file encoding.
//
// Parameters:
//  AttachedFile - DefinedType.AttachedFiles - a file, whose encoding needs to be determined.
//                                                             
//  Extension        - String - file extension.
//
// Returns:
//  Encoding - String - file encoding.
//
Function FileEncoding(AttachedFile, Extension = "") Export
	
	Encoding = FilesOperationsInternalServerCall.GetFileVersionEncoding(AttachedFile);
	If Not ValueIsFilled(Encoding) Then
		
		BinaryData = FileBinaryData(AttachedFile);
		If BinaryData <> Undefined Then
		
			Encoding = EncodingFromBinaryData(BinaryData);
			If Not ValueIsFilled(Encoding)
				AND StrEndsWith(Lower(Extension), "xml") Then
				
				Encoding = EncodingFromXMLNotification(BinaryData);
				If Lower(Encoding) = "utf-8" Then
					Encoding = Lower(Encoding) + "_WithoutBOM";
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Encoding;
	
EndFunction

// Returns the encoding received from file binary data if the file contains the BOM signature in the 
// beginning.
//
// Parameters:
//  BinaryData - file binary data.
//
// Returns:
//  String - file encoding. If the file does not contain the BOM signature, returns a blank string.
//           
//
Function EncodingFromBinaryData(BinaryData)

	DataReading        = New DataReader(BinaryData);
	BinaryDataBuffer = DataReading.ReadIntoBinaryDataBuffer(5);
	
	Return BOMEncoding(BinaryDataBuffer);

EndFunction

// Returns the encoding received from file binary data if the file contains the XML notification.
// 
//
// Parameters:
//  BinaryData - file binary data.
//
// Returns:
//  XMLEncoding - String - file encoding. If you cannot read the XML notification, returns a blank 
//                          string.
//
Function EncodingFromXMLNotification(BinaryData)
	
	BinaryDataBuffer = GetBinaryDataBufferFromBinaryData(BinaryData);
	MemoryStream = New MemoryStream(BinaryDataBuffer);
	XMLReader = New XMLReader;
	XMLReader.OpenStream(MemoryStream);
	Try
		XMLReader.MoveToContent();
		XMLEncoding = XMLReader.XMLEncoding;
	Except
		XMLEncoding = "";
	EndTry;
	XMLReader.Close();
	MemoryStream.Close();
	
	Return XMLEncoding;
	
EndFunction

// Returns the text encoding received from the BOM signature in the beginning.
//
// Parameters:
//  BinaryDataBuffer - a collection of bytes to define encoding.
//
// Returns:
//  Encoding - String - file encoding. If the file does not contain the BOM signature, returns a 
//                       blank string.
//
Function BOMEncoding(BinaryDataBuffer)
	
	ReadBytes = New Array(5);

	UBound = BinaryDataBuffer.Size - 1;
	For Index = 0 To 4 Do
		If Index < BinaryDataBuffer.Size Then
			ReadBytes[Index] = BinaryDataBuffer[Index];
		Else
			ReadBytes[Index] = NumberFromHexString("0xA5");
		EndIf;
	EndDo;
	
	If ReadBytes[0] = NumberFromHexString("0xFE")
		AND ReadBytes[1] = NumberFromHexString("0xFF") Then
		Encoding = "UTF-16BE";
	ElsIf ReadBytes[0] = NumberFromHexString("0xFF")
		AND ReadBytes[1] = NumberFromHexString("0xFE") Then
		If ReadBytes[2] = NumberFromHexString("0x00")
			AND ReadBytes[3] = NumberFromHexString("0x00") Then
			Encoding = "UTF-32LE";
		Else
			Encoding = "UTF-16LE";
		EndIf;
	ElsIf ReadBytes[0] = NumberFromHexString("0xEF")
		AND ReadBytes[1] = NumberFromHexString("0xBB")
		AND ReadBytes[2] = NumberFromHexString("0xBF") Then
		Encoding = "UTF-8";
	ElsIf ReadBytes[0] = NumberFromHexString("0x00")
		AND ReadBytes[1] = NumberFromHexString("0x00")
		AND ReadBytes[2] = NumberFromHexString("0xFE")
		AND ReadBytes[3] = NumberFromHexString("0xFF") Then
		Encoding = "UTF-32BE";
	ElsIf ReadBytes[0] = NumberFromHexString("0x0E")
		AND ReadBytes[1] = NumberFromHexString("0xFE")
		AND ReadBytes[2] = NumberFromHexString("0xFF") Then
		Encoding = "SCSU";
	ElsIf ReadBytes[0] = NumberFromHexString("0xFB")
		AND ReadBytes[1] = NumberFromHexString("0xEE")
		AND ReadBytes[2] = NumberFromHexString("0x28") Then
		Encoding = "BOCU-1";
	ElsIf ReadBytes[0] = NumberFromHexString("0x2B")
		AND ReadBytes[1] = NumberFromHexString("0x2F")
		AND ReadBytes[2] = NumberFromHexString("0x76")
		AND (ReadBytes[3] = NumberFromHexString("0x38")
			Or ReadBytes[3] = NumberFromHexString("0x39")
			Or ReadBytes[3] = NumberFromHexString("0x2B")
			Or ReadBytes[3] = NumberFromHexString("0x2F")) Then
		Encoding = "UTF-7";
	ElsIf ReadBytes[0] = NumberFromHexString("0xDD")
		AND ReadBytes[1] = NumberFromHexString("0x73")
		AND ReadBytes[2] = NumberFromHexString("0x66")
		AND ReadBytes[3] = NumberFromHexString("0x73") Then
		Encoding = "UTF-EBCDIC";
	Else
		Encoding = "";
	EndIf;
	
	Return Encoding;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Returns keys of file operation setting objects.
// 
Function FilesOperationSettingsObjectsKeys()
	
	FilesOperationSettingsObjectsKeys = New Map;
	
	FilesOperationSettingsObjectsKeys.Insert("PromptForEditModeOnOpenFile" ,"OpenFileSettings");
	FilesOperationSettingsObjectsKeys.Insert("ActionOnDoubleClick",                  "OpenFileSettings");
	FilesOperationSettingsObjectsKeys.Insert("ShowSizeColumn" ,                      "ApplicationSettings");
	FilesOperationSettingsObjectsKeys.Insert("ShowLockedFilesOnExit",     "ApplicationSettings");
	FilesOperationSettingsObjectsKeys.Insert("FileVersionsComparisonMethod",                   "FileComparisonSettings");
	
	FilesOperationSettingsObjectsKeys.Insert("TextFilesExtension" ,      "OpenFileSettings\TextFiles");
	FilesOperationSettingsObjectsKeys.Insert("TextFilesOpeningMethod" ,  "OpenFileSettings\TextFiles");
	FilesOperationSettingsObjectsKeys.Insert("GraphicalSchemasExtension" ,    "OpenFileSettings\GraphicalSchemas");
	FilesOperationSettingsObjectsKeys.Insert("GraphicalSchemasOpeningMethod" ,"OpenFileSettings\GraphicalSchemas");
	FilesOperationSettingsObjectsKeys.Insert("ShowTooltipsOnEditFiles" ,"ApplicationSettings");
	FilesOperationSettingsObjectsKeys.Insert("ShowFileNotModifiedFlag" ,   "ApplicationSettings");
	
	Return FilesOperationSettingsObjectsKeys;
	
EndFunction

// Marks or unmarks attached files for deletion.
Procedure MarkForDeletionAttachedFiles(Val Source, CatalogName = Undefined)
	
	If Source.IsNew() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	SourceRefDeletionMark = Common.ObjectAttributeValue(Source.Ref, "DeletionMark");
	
	If Source.DeletionMark = SourceRefDeletionMark Then
		Return;
	EndIf;
	
	Try
		CatalogNames = FilesOperationsInternal.FileStorageCatalogNames(
			TypeOf(Source.Ref));
	Except
		ErrorPresentation = BriefErrorDescription(ErrorInfo());
		Raise NStr("ru = 'Ошибка при пометке на удаление присоединенных файлов.'; en = 'Error when marking attached files for deletion.'; pl = 'Wystąpił błąd podczas oznaczania załączonych plików do usunięcia.';es_ES = 'Ha ocurrido un error al marcar los archivos adjuntados para borrar.';es_CO = 'Ha ocurrido un error al marcar los archivos adjuntados para borrar.';tr = 'Eklenen dosyalar silme için işaretlenirken bir hata oluştu.';it = 'Errore mentre si contrassegnano i file allegati per l''eliminazione.';de = 'Beim Markieren der angehängten Dateien zum Löschen ist ein Fehler aufgetreten.'")
			+ Chars.LF
			+ ErrorPresentation;
	EndTry;
	
	Query = New Query;
	Query.SetParameter("FileOwner", Source.Ref);
	
	QueryText =
		"SELECT ALLOWED
		|	Files.Ref AS Ref,
		|	Files.BeingEditedBy AS BeingEditedBy
		|FROM
		|	&CatalogName AS Files
		|WHERE
		|	Files.FileOwner = &FileOwner";
	
	For each CatalogNameDescription In CatalogNames Do
		
		FullCatalogName = "Catalog." + CatalogNameDescription.Key;
		Query.Text = StrReplace(QueryText, "&CatalogName", FullCatalogName);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			If Source.DeletionMark AND ValueIsFilled(Selection.BeingEditedBy) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '""%1"" не может быть удален,
					           |т.к. содержит присоединенный файл ""%2"",
					           |занятый для редактирования.'; 
					           |en = '""%1"" cannot be deleted
					           |as it contains attached file ""%2""
					           |locked for editing.'; 
					           |pl = 'Nie można 
					           |usunąć ""%1"", ponieważ zawiera on dołączany
					           |plik ""%2"" zablokowany do edycji.';
					           |es_ES = '""%1"" no puede
					           |borrarse, porque contiene el archivo
					           |adjuntado ""%2"" seleccionado para editar.';
					           |es_CO = '""%1"" no puede
					           |borrarse, porque contiene el archivo
					           |adjuntado ""%2"" seleccionado para editar.';
					           |tr = '""%1"" silinemiyor çünkü
					           |düzenlemeye karşı kilitlenmiş ekli
					           |""%2"" dosyasını içeriyor.';
					           |it = '""%1"" non può essere eliminato
					           |poiché contiene il file allegato ""%2""
					           |bloccato per la modifica.';
					           |de = '""%1"" kann nicht
					           |gelöscht werden, also. Enthält angehängte
					           |Datei ""%2"" zur Bearbeitung übernommen.'"),
					String(Source.Ref),
					String(Selection.Ref));
			EndIf;
			FileObject = Selection.Ref.GetObject();
			FileObject.Lock();
			FileObject.SetDeletionMark(Source.DeletionMark);
		EndDo;
	EndDo;
	
EndProcedure

// Returns error message text containing a reference to the item of a file storage catalog.
// 
//
Function ErrorTextWhenYouReceiveFile(Val ErrorInformation, Val File)
	
	ErrorMessage = BriefErrorDescription(ErrorInformation);
	
	If File <> Undefined Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |
			           |Ссылка на файл: ""%2"".'; 
			           |en = '%1
			           |
			           |Ref to file: ""%2"".'; 
			           |pl = '%1
			           |
			           |Odnośnik do pliku: ""%2"".';
			           |es_ES = '%1
			           |
			           |Referencia al archivo: ""%2"".';
			           |es_CO = '%1
			           |
			           |Referencia al archivo: ""%2"".';
			           |tr = '%1
			           |
			           |Dosya linki: ""%2"".';
			           |it = '%1
			           |
			           |Rif al file: ""%2"".';
			           |de = '%1
			           |
			           |Ref zu Datei: ""%2"".'"),
			ErrorMessage,
			GetURL(File) );
	EndIf;
	
	Return ErrorMessage;
	
EndFunction

// Returns attached file owner ID.
Function GetObjectID(Val FilesOwner)
	
	QueryText =
		"SELECT
		|	FilesExist.ObjectID
		|FROM
		|	InformationRegister.FilesExist AS FilesExist
		|WHERE
		|	FilesExist.ObjectWithFiles = &ObjectWithFiles";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ObjectWithFiles", FilesOwner);
	ExecutionResult = Query.Execute();
	
	If ExecutionResult.IsEmpty() Then
		Return "";
	EndIf;
	
	Selection = ExecutionResult.Select();
	Selection.Next();
	
	Return Selection.ObjectID;
	
EndFunction

// Returns file binary data from the infobase.
//
// Parameters:
//   FileRef - a reference to file or its version.
//
// Returns:
//   ValueStorage - file binary data.
//
Function FileFromInfobaseStorage(FileRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	FilesBinaryData.File,
	|	FilesBinaryData.FileBinaryData
	|FROM
	|	InformationRegister.FilesBinaryData AS FilesBinaryData
	|WHERE
	|	FilesBinaryData.File = &FileRef";
	
	Query.SetParameter("FileRef", FileRef);
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.FileBinaryData, Undefined);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// BeforeWrite event handler for filling attached file attributes.
//
// Parameters:
//  Source   - CatalogObject - the "*AttachedFiles" catalog object.
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure ExecuteActionsBeforeWriteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If TypeOf(Source) = Type("CatalogObject.FilesVersions") Then
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("FileConversion") Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		// Checking the Add right.
		If NOT FilesOperationsInternal.HasRight("AddFiles", Source.FileOwner) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недостаточно прав для добавления файлов в папку ""%1"".'; en = 'Insufficient rights to add files to folder ""%1"".'; pl = 'Niewystarczające uprawnienia do dodawania plików do folderu ""%1"".';es_ES = 'Insuficientes derechos para añadir archivos a la carpeta ""%1"".';es_CO = 'Insuficientes derechos para añadir archivos a la carpeta ""%1"".';tr = '""%1"" Klasörüne dosya eklemek için yeterli haklar yok.';it = 'Autorizzazioni insufficienti per aggiungere file alla cartella ""%1"".';de = 'Unzureichende Rechte zum Hinzufügen von Dateien zum Ordner ""%1"".'"),
				String(Source.FileOwner));
		EndIf;
	Else
		
		DeletionMarkChanged = 
			Source.DeletionMark <> Common.ObjectAttributeValue(Source.Ref, "DeletionMark");
			
		If DeletionMarkChanged Then
			// Checking the "Deletion mark" right.
			If NOT FilesOperationsInternal.HasRight("FilesDeletionMark", Source.FileOwner) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Недостаточно прав для пометки файлов на удаление в папке ""%1"".'; en = 'Insufficient rights to mark files for deletion in folder ""%1"".'; pl = 'Niewystarczające uprawnienia do oznaczania plików do usunięcia w folderze ""%1"".';es_ES = 'Insuficientes derechos para marcar los archivos para borrar en la carpeta ""%1"".';es_CO = 'Insuficientes derechos para marcar los archivos para borrar en la carpeta ""%1"".';tr = '""%1"" klasöründe silinecek dosyaları işaretlemek için yeterli haklar yok.';it = 'Autorizzazioni insufficienti per contrassegnare i file per l''eliminazione nella cartella ""%1"".';de = 'Unzureichende Rechte zum Markieren von Dateien zum Löschen im Ordner ""%1"".'"),
					String(Source.FileOwner));
			EndIf;
		EndIf;
		
		If DeletionMarkChanged AND ValueIsFilled(Source.BeingEditedBy) Then
				
			If Source.BeingEditedBy = Users.AuthorizedUser() Then
				
				ErrorText = NStr("ru = 'Действие недоступно, так как файл ""%1"" занят для редактирования.'; en = 'Action is not available as the ""%1"" file is locked for editing.'; pl = 'Akcja nie jest dostępna, ponieważ plik ""%1"" jest zajęty dla edycji.';es_ES = 'Acción no disponible, porque el archivo ""%1"" está ocupado para editar.';es_CO = 'Acción no disponible, porque el archivo ""%1"" está ocupado para editar.';tr = 'Dosya ""%1"" düzenleme için kilitlendiğinden işlem yapılamıyor.';it = 'Azione non disponibile poiché il file ""%1"" è bloccato per la modifica.';de = 'Die Aktion ist nicht verfügbar, da die Datei ""%1"" für die Bearbeitung belegt ist.'");
				Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorText, Source.Description);
				
			Else
				ErrorText = NStr("ru = 'Действие недоступно, так как файл ""%1"" занят для редактирования
					|пользователем %2.'; 
					|en = 'Action is not available as user %2 is editing
					|the ""%1"" file.'; 
					|pl = 'Akcja nie jest dostępna, ponieważ plik ""%1"" jest zajęty dla edycji
					|użytkownikiem %2.';
					|es_ES = 'Acción no disponible, porque el archivo ""%1"" está ocupado para editar
					|por usuario %2.';
					|es_CO = 'Acción no disponible, porque el archivo ""%1"" está ocupado para editar
					|por usuario %2.';
					|tr = 'Dosya %1kullanıcı tarafından düzenlemek için 
					|sunulduğundan%2 işlem yapılamıyor.';
					|it = 'Azione non disponibile poiché l''utente %2 sta modificando
					|il file ""%1"".';
					|de = 'Die Aktion ist nicht verfügbar, da die Datei ""%1"" für die Bearbeitung
					|durch den Benutzer belegt ist %2.'");
				Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
				Source.Description,
				String(Source.BeingEditedBy));
				
			EndIf;
			
		EndIf;
		
		WriteSignedObject = False;
		If Source.AdditionalProperties.Property("WriteSignedObject") Then
			WriteSignedObject = Source.AdditionalProperties.WriteSignedObject;
		EndIf;
		
		If WriteSignedObject <> True Then
			
			AttributesStructure = Common.ObjectAttributesValues(Source.Ref,
				"SignedWithDS, Encrypted, BeingEditedBy");
			
			RefSigned    = AttributesStructure.SignedWithDS;
			RefEncrypted  = AttributesStructure.Encrypted;
			RefEditedBy = AttributesStructure.BeingEditedBy;
			RefLocked       = ValueIsFilled(AttributesStructure.BeingEditedBy);
			Locked = ValueIsFilled(Source.BeingEditedBy);
			
			If Not Source.IsFolder AND Source.SignedWithDS AND RefSigned AND Locked AND Not RefLocked Then
				Raise NStr("ru = 'Подписанный файл нельзя редактировать.'; en = 'Signed file cannot be edited.'; pl = 'Nie można edytować podpisanego pliku.';es_ES = 'Archivo firmado no puede editarse.';es_CO = 'Archivo firmado no puede editarse.';tr = 'İmzalı dosya düzenlenemez.';it = 'Il file firmato non può essere modificato.';de = 'Signierte Datei kann nicht bearbeitet werden.'");
			EndIf;
			
			If Not Source.IsFolder AND Source.Encrypted AND RefEncrypted AND Source.SignedWithDS AND NOT RefSigned Then
				Raise NStr("ru = 'Зашифрованный файл нельзя подписывать.'; en = 'Encrypted file cannot be signed.'; pl = 'Nie można podpisać zaszyfrowanego pliku.';es_ES = 'Archivo cifrado no puede firmarse.';es_CO = 'Archivo cifrado no puede firmarse.';tr = 'Şifrelenmiş dosya imzalanamaz.';it = 'Il file codificato non può essere firmato.';de = 'Verschlüsselte Datei kann nicht signiert werden.'");
			EndIf;
			
		EndIf;
		
		CatalogSupportsPossibitityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", Metadata.FindByType(TypeOf(Source)));
		
		If Not Source.IsFolder AND CatalogSupportsPossibitityToStoreVersions AND ValueIsFilled(Source.CurrentVersion) Then
			
			CurrentVersionAttributes = Common.ObjectAttributesValues(
				Source.CurrentVersion, "Description");
			
			// Checking whether the file name equals its current version.
			// If the names are different, assigning the file card name to the version name.
			If CurrentVersionAttributes.Description <> Source.Description
			   AND ValueIsFilled(Source.CurrentVersion) Then
				
				DataLock = New DataLock;
				DataLockItem = DataLock.Add(
					Metadata.FindByType(TypeOf(Source.CurrentVersion)).FullName());
				
				DataLockItem.SetValue("Ref", Source.CurrentVersion);
				DataLock.Lock();
				
				Object = Source.CurrentVersion.GetObject();
				
				If Object <> Undefined Then
					SetPrivilegedMode(True);
					Object.Description = Source.Description;
					// So as not to start the CopyFilesVersionAttributesToFile subscription.
					Object.AdditionalProperties.Insert("FileRenaming", True);
					Object.Write();
					SetPrivilegedMode(False);
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Source.FileOwner) Then
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не заполнен владелец в файле
			           |""%1"".'; 
			           |en = 'Owner in file
			           |""%1"" is not entered.'; 
			           |pl = 'Nie jest wypełniony właściciel w pliku
			           |""%1"".';
			           |es_ES = 'Propietario no rellenado en el archivo
			           |""%1"".';
			           |es_CO = 'Propietario no rellenado en el archivo
			           |""%1"".';
			           |tr = '
			           |Dosya oluşturan bilgisi doldurulmamıştır ""%1"".';
			           |it = 'Il proprietario nel file
			           |""%1"" non è entrato.';
			           |de = 'Der Besitzer ist in der Datei
			           |""%1"" nicht eingetragen.'"),
			Source.Description);
		
		If InfobaseUpdate.InfobaseUpdateInProgress() Then
			
			WriteLogEvent(
				NStr("ru = 'Файлы.Ошибка записи файла при обновлении ИБ'; en = 'Files.Error writing file during infobase updating'; pl = 'Pliki. Wystąpił błąd podczas zapisywania pliku w trakcie aktualizacji bazy informacyjnej';es_ES = 'Archivos. Ha ocurrido un error al inscribir el archivo durante la actualización de la infobase';es_CO = 'Archivos. Ha ocurrido un error al inscribir el archivo durante la actualización de la infobase';tr = 'Dosyalar. Infobase güncellenirken dosya kayıt hatası oluştu';it = 'File.Errore nella registrazione del file durante l''aggiornamento del DB';de = 'Dateien. Fehler beim Schreiben der Datei während IB Aktualisierung'",
				     CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				Source.Ref,
				ErrorDescription);
		Else
			Raise ErrorDescription;
		EndIf;
		
	EndIf;
	
	If Source.IsFolder Then
		Source.PictureIndex = 2;
	Else
		Source.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(Source.Extension);
	EndIf;
	
	If Source.IsNew() AND Not ValueIsFilled(Source.Author) Then
		Source.Author = Users.AuthorizedUser();
	EndIf;
	
EndProcedure

// BeforeDelete event handler for deletion data associated with the attached file.
//
// Parameters:
//  Source   - CatalogObject - the "*AttachedFiles" catalog object.
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure ExecuteActionsBeforeDeleteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If TypeOf(Source) = Type("CatalogObject.FilesVersions") Then
		Return;
	EndIf;
	
	FilesOperationsInternal.BeforeDeleteAttachedFileServer(
		Source.Ref,
		Source.FileOwner,
		Source.Volume,
		Source.FileStorageType,
		Source.PathToFile);
	
EndProcedure

// Handler of the OnWrite event for updating data associated with the attached file.
//
// Parameters:
//  Source   - CatalogObject - the "*AttachedFiles" catalog object.
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//
Procedure ExecuteActionsOnWriteAttachedFile(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		WriteFileDataToRegisterDuringExchange(Source);
		Return;
	EndIf;
	
	If TypeOf(Source) = Type("CatalogObject.FilesVersions") Then
		Return;
	EndIf;
	
	FilesOperationsInternal.OnWriteAttachedFileServer(
		Source.FileOwner, Source.Ref);
		
	FilesOperationsInternal.UpdateTextExtractionQueueState(
		Source.Ref, Source.TextExtractionStatus);
	
EndProcedure

Procedure WriteFileDataToRegisterDuringExchange(Val Source)
	
	Var FileBinaryData;
	
	If Source.AdditionalProperties.Property("FileBinaryData", FileBinaryData) Then
		RecordSet = InformationRegisters.FilesBinaryData.CreateRecordSet();
		RecordSet.Filter.File.Use = True;
		RecordSet.Filter.File.Value = Source.Ref;
		
		Record = RecordSet.Add();
		Record.File = Source.Ref;
		Record.FileBinaryData = New ValueStorage(FileBinaryData, New Deflation(9));
		
		RecordSet.DataExchange.Load = True;
		RecordSet.Write();
		
		Source.AdditionalProperties.Delete("FileBinaryData");
	EndIf;
	
EndProcedure

// Handler of the BeforeWrite event of attached file owner.
// Marks for deletion related files.
//
// Parameters:
//  Source - Object - attached file owner, except for DocumentObject.
//  Cancel    - Boolean - shows whether writing is canceled.
// 
Procedure SetAttachedFilesDeletionMarks(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	MarkForDeletionAttachedFiles(Source);

EndProcedure

// Handler of the BeforeWrite event of attached file owner.
// Marks for deletion related files.
//
// Parameters:
//  Source        - DocumentObject - the attached file owner.
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//  WriteMode - Boolean - a parameter passed to the BeforeWrite event subscription.
//  PostingMode - Boolean - a parameter passed to the BeforeWrite event subscription.
// 
Procedure SetAttachedDocumentFilesDeletionMark(Source, Cancel, WriteMode, PostingMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	MarkForDeletionAttachedFiles(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attached file management.

Procedure CreateFilesHyperlink(Form, ItemToAdd, AttachedFilesOwner, HyperlinkParameters)
	
	GroupName          = HyperlinkParameters.NameOfGroup;
	ItemNumber      = HyperlinkParameters.ItemNumber;
	AdditionAvailable = HyperlinkParameters.AdditionAvailable;
	
	FormCommandProperties = New Structure;
	FormCommandProperties.Insert("Representation", ButtonRepresentation.Text);
	FormCommandProperties.Insert("Action", "Attachable_AttachedFilesPanelCommand");
	
	If ItemToAdd.Placement = "CommandBar" Then
		PlacementItem = Form.CommandBar;
	Else
		PlacementItem = Form.Items.Find(ItemToAdd.Placement);
	EndIf;
	
	GroupKind = FormGroupType.CommandBar;
	IsButtonsGroup = False;
	If PlacementItem <> Undefined
		AND TypeOf(PlacementItem) = Type("FormGroup") Then
		
		IsButtonsGroup = PlacementItem.Type = FormGroupType.ButtonGroup
			OR PlacementItem.Type = FormGroupType.CommandBar;
		GroupKind = ?(IsButtonsGroup, FormGroupType.ButtonGroup, GroupKind);
		If PlacementItem.Type = FormGroupType.UsualGroup
			OR PlacementItem.Type = FormGroupType.Page
			OR IsButtonsGroup Then
			
			ParentElement   = PlacementItem;
			PlacementItem = Undefined;
		EndIf;
		
	EndIf;
	
	PlacementOnFormGroup = Form.Items.Insert(GroupName, Type("FormGroup"), 
		ParentElement, PlacementItem);
	PlacementOnFormGroup.Type = GroupKind;
	
	SubmenuAdd = Undefined;
	If ItemToAdd.AddFiles
		AND AdditionAvailable Then
		
		SubmenuAdd = Form.Items.Add("AddingFileSubmenu" + ItemNumber, Type("FormGroup"),
			PlacementOnFormGroup);
		
		SubmenuAdd.Type         = FormGroupType.Popup;
		SubmenuAdd.Picture    = PictureLib.Clip;
		SubmenuAdd.Title   = NStr("ru = 'Присоединить файлы'; en = 'Attach files'; pl = 'Załącz pliki';es_ES = 'Adjuntar archivos';es_CO = 'Adjuntar archivos';tr = 'Dosya ekle';it = 'Allegare file';de = 'Datei anhängen'");
		SubmenuAdd.ToolTip   = NStr("ru = 'Присоединить файлы'; en = 'Attach files'; pl = 'Załącz pliki';es_ES = 'Adjuntar archivos';es_CO = 'Adjuntar archivos';tr = 'Dosya ekle';it = 'Allegare file';de = 'Datei anhängen'");
		SubmenuAdd.Representation = ButtonRepresentation.Picture;
		
		ImportFile           = Form.Commands.Add("AttachedFilesManagementImportFile_" + ItemNumber);
		ImportFile.Action  = "Attachable_AttachedFilesPanelCommand";
		ImportFile.ToolTip = NStr("ru = 'Загрузить файл с диска'; en = 'Upload file from a hard drive.'; pl = 'Załaduj plik z dysku.';es_ES = 'Cargar el archivo desde el disco duro.';es_CO = 'Cargar el archivo desde el disco duro.';tr = 'Sabit sürücüden karşıya dosya yükle.';it = 'Caricare file da disco rigido.';de = 'Datei aus einer Festplatte hochladen.'");
		ImportFile.Title = NStr("ru = 'Загрузить...'; en = 'Upload...'; pl = 'Załaduj...';es_ES = 'Cargar...';es_CO = 'Cargar...';tr = 'Karşıya yükle...';it = 'Caricamento...';de = 'Hochladen...'");
		
		LoadButton = AddButtonOnForm(Form, "AttachedFilesManagementImportFile" + ItemNumber, PlacementOnFormGroup, ImportFile.Name);
		LoadButton.Picture    = PictureLib.Clip;
		LoadButton.Visible   = False;
		LoadButton.Representation = ButtonRepresentation.Picture;
		
		If ValueIsFilled(ItemToAdd.ShapeRepresentation) Then
			LoadButton.ShapeRepresentation = ButtonShapeRepresentation[ItemToAdd.ShapeRepresentation];
			SubmenuAdd.ShapeRepresentation = ButtonShapeRepresentation[ItemToAdd.ShapeRepresentation];
		EndIf;
		
		LoadButtonFromSubmenu = AddButtonOnForm(Form, "ImportFileFromSubmenu" + ItemNumber, SubmenuAdd, ImportFile.Name);
		LoadButtonFromSubmenu.Representation = ButtonRepresentation.Text;
		
		CreateByTemplate = Form.Commands.Add("AttachedFilesManagementCreateByTemplate_" + ItemNumber);
		CreateByTemplate.Title = NStr("ru = 'Создать по шаблону...'; en = 'Create from template...'; pl = 'Utwórz na podstawie szablonu...';es_ES = 'Crear desde la plantilla...';es_CO = 'Crear desde la plantilla...';tr = 'Şablondan oluştur...';it = 'Creare da modello...';de = 'Nach Vorlage generieren...'");
		FillPropertyValues(CreateByTemplate, FormCommandProperties);
		
		AddButtonOnForm(Form, "CreateByTemplate" + ItemNumber, SubmenuAdd, CreateByTemplate.Name);
		
		Scan = Form.Commands.Add("AttachedFilesManagementScan_" + ItemNumber);
		Scan.Title = NStr("ru = 'Сканировать...'; en = 'Scan...'; pl = 'Skanuj...';es_ES = 'Escanear...';es_CO = 'Escanear...';tr = 'Tara...';it = 'Scansione...';de = 'Scannen...'");
		FillPropertyValues(Scan, FormCommandProperties);
		
		AddButtonOnForm(Form, "Scan" + ItemNumber, SubmenuAdd, Scan.Name);
		
	EndIf;
	
	OpenListCommand = Form.Commands.Add("AttachedFilesManagementOpenList_" + ItemNumber);
	FillPropertyValues(OpenListCommand, FormCommandProperties);
	
	If ItemToAdd.DisplayTitleRight
		OR Not ItemToAdd.AddFiles Then
		GoToHyperlink = AddButtonOnForm(Form, "AttachedFilesManagementOpenList" + ItemNumber,
			PlacementOnFormGroup, OpenListCommand.Name);
	Else
		GoToHyperlink = Form.Items.Insert("AttachedFilesManagementOpenList" + ItemNumber,
			Type("FormButton"), PlacementOnFormGroup, SubmenuAdd);
			
		GoToHyperlink.CommandName = OpenListCommand.Name;
	EndIf;
	
	GoToHyperlink.Type = ?(IsButtonsGroup, FormButtonType.CommandBarHyperlink, FormButtonType.Hyperlink);
	GoToHyperlink.Title = ItemToAdd.Title;
	If ItemToAdd.DisplayCount Then
		
		AttachedFilesCount = FilesOperationsInternalServerCall.AttachedFilesCount(AttachedFilesOwner);
		If AttachedFilesCount > 0 Then
			GoToHyperlink.Title = GoToHyperlink.Title + " ("
				+ Format(AttachedFilesCount, "NG=") + ")";
		EndIf;
		
	EndIf;
			
EndProcedure

Procedure CreateFileField(Form, ItemToAdd, AttachedFilesOwner, FileFieldParameters)
	
	GroupName          = FileFieldParameters.NameOfGroup;
	ItemNumber      = FileFieldParameters.ItemNumber;
	UpdateAvailable  = FileFieldParameters.UpdateAvailable;
	AdditionAvailable = FileFieldParameters.AdditionAvailable;
	
	FormCommandProperties = New Structure;
	FormCommandProperties.Insert("Action",    "Attachable_AttachedFilesPanelCommand");
	FormCommandProperties.Insert("Representation", ButtonRepresentation.Text);
	
	FormCommandPropertiesPicture = New Structure;
	FormCommandPropertiesPicture.Insert("Action",    "Attachable_AttachedFilesPanelCommand");
	FormCommandPropertiesPicture.Insert("Representation", ButtonRepresentation.Picture);
	
	LoadButtonProperties = New Structure;
	LoadButtonProperties.Insert("Title",            NStr("ru = 'Загрузить...'; en = 'Upload...'; pl = 'Załaduj...';es_ES = 'Cargar...';es_CO = 'Cargar...';tr = 'Karşıya yükle...';it = 'Caricamento...';de = 'Hochladen...'"));
	LoadButtonProperties.Insert("Representation",          ButtonRepresentation.Text);
	LoadButtonProperties.Insert("ToolTipRepresentation", ToolTipRepresentation.None);
	
	SelectionButtonProperties = New Structure;
	SelectionButtonProperties.Insert("Title",            NStr("ru = 'Выбрать из присоединенных...'; en = 'Select from attached files...'; pl = 'Wybierz z załączonych plików...';es_ES = 'Seleccionar de los archivos adjuntados...';es_CO = 'Seleccionar de los archivos adjuntados...';tr = 'Ekli dosyalardan seç...';it = 'Selezionare dai file allegati...';de = 'Aus angehängten Dateien auswählen...'"));
	SelectionButtonProperties.Insert("Representation",          ButtonRepresentation.Text);
	SelectionButtonProperties.Insert("ToolTipRepresentation", ToolTipRepresentation.None);
	
	GroupPropertiesWithoutDisplay = New Structure;
	GroupPropertiesWithoutDisplay.Insert("Type",                 FormGroupType.UsualGroup);
	GroupPropertiesWithoutDisplay.Insert("Title",           "");
	GroupPropertiesWithoutDisplay.Insert("ToolTip",           "");
	GroupPropertiesWithoutDisplay.Insert("Group",         ChildFormItemsGroup.Vertical);
	GroupPropertiesWithoutDisplay.Insert("ShowTitle", False);
	
	If StrFind(ItemToAdd.DataPath, ".") Then
		FullDataPath = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
			ItemToAdd.DataPath, ".", True, True);
	Else
		FullDataPath = New Array;
		FullDataPath.Add(ItemToAdd.DataPath);
	EndIf;
	
	PlacementAttribute = Form[FullDataPath[0]];
	For Counter = 1 To FullDataPath.UBound() Do
		PlacementAttribute = PlacementAttribute[FullDataPath[Counter]];
	EndDo;
	
	ItemToAdd.AddFiles = ItemToAdd.AddFiles AND AdditionAvailable;
	PlacementItem = Form.Items.Find(ItemToAdd.Placement);
	
	If PlacementItem <> Undefined
		AND TypeOf(PlacementItem) = Type("FormGroup")
		AND (PlacementItem.Type = FormGroupType.UsualGroup
		OR PlacementItem.Type = FormGroupType.Page) Then
		
		ParentElement   = PlacementItem;
		PlacementItem = Undefined;
		
	EndIf;
	
	PlacementOnFormGroup = Form.Items.Insert(GroupName, Type("FormGroup"), 
		ParentElement, PlacementItem);
	
	OneFileOnlyText = ?(ItemToAdd.OneFileOnly, "OneFileOnly", "");
	FillPropertyValues(PlacementOnFormGroup, GroupPropertiesWithoutDisplay);
	
	HeaderGroup = Form.Items.Add(
		"AttachedFilesManagementGroupHeader" + ItemNumber,
		Type("FormGroup"), PlacementOnFormGroup);
	
	FillPropertyValues(HeaderGroup, GroupPropertiesWithoutDisplay);
	HeaderGroup.Group = ChildFormItemsGroup.AlwaysHorizontal;
	
	If ItemToAdd.ShowPreview Then
		
		PreviewItem = Form.Items.Add("AttachedFilePictureField" + ItemNumber,
			Type("FormField"), PlacementOnFormGroup);
		
		PreviewItem.Type                        = FormFieldType.PictureField;
		PreviewItem.TextColor                 = StyleColors.NotSelectedPictureTextColor;
		PreviewItem.DataPath                = ItemToAdd.PathToPictureData;
		PreviewItem.Hyperlink                = True;
		PreviewItem.PictureSize             = PictureSize.Proportionally;
		PreviewItem.TitleLocation         = FormItemTitleLocation.None;
		PreviewItem.AutoMaxWidth     = False;
		PreviewItem.AutoMaxHeight     = False;
		PreviewItem.VerticalStretch     = True;
		PreviewItem.EnableDrag    = True;
		PreviewItem.HorizontalStretch   = True;
		PreviewItem.NonselectedPictureText   = ItemToAdd.NonselectedPictureText;
		PreviewItem.FileDragMode = FileDragMode.AsFileRef;
		
		PreviewContextMenu = PreviewItem.ContextMenu;
		PreviewContextMenu.EnableContentChange = False;
		
		ContextMenuAddGroup = Form.Items.Add("FileAddingGroupContextMenu" + ItemNumber,
			Type("FormGroup"), PreviewContextMenu);
		
		ContextMenuAddGroup.Type = FormGroupType.ButtonGroup;
		
		If ValueIsFilled(PlacementAttribute)
			AND Common.IsReference(TypeOf(PlacementAttribute)) Then
			
			RefToBinaryData = Undefined;
			
			DataParameters = FilesOperationsClientServer.FileDataParameters();
			DataParameters.RaiseException = False;
			DataParameters.FormID = Form.UUID;
			
			FileData = FileData(PlacementAttribute, DataParameters);
			If FileData <> Undefined Then
				
				RefToBinaryData = FileData.BinaryFileDataRef;
				BinaryDataValue = GetFromTempStorage(RefToBinaryData);
				If BinaryDataValue = Undefined Then
					PreviewItem.TextColor = StyleColors.ErrorNoteText;
					PreviewItem.NonselectedPictureText = NStr("ru = 'Изображение отсутствует'; en = 'No image'; pl = 'Brak obrazów';es_ES = 'Sin imagen';es_CO = 'Sin imagen';tr = 'Görsel yok';it = 'Nessuna immagine';de = 'Kein Bild'");
				EndIf;
				
			EndIf;
			
			Form[ItemToAdd.PathToPictureData] = RefToBinaryData;
			
		EndIf;
		
		PreviewItem.SetAction("Click", "Attachable_PreviewFieldClick");
		PreviewItem.SetAction("Drag",
			"Attachable_PreviewFieldDrag");
		PreviewItem.SetAction("DragCheck",
			"Attachable_PreviewFieldDragCheck");
		
	EndIf;
	
	If Not IsBlankString(ItemToAdd.Title) Then
		
		TitleDecoration = Form.Items.Add("AttachedFilesManagementTitle" + ItemNumber,
			Type("FormDecoration"), HeaderGroup);
		
		TitleDecoration.Type                      = FormDecorationType.Label;
		TitleDecoration.Title                = ItemToAdd.Title + ":";
		TitleDecoration.VerticalStretch   = False;
		TitleDecoration.HorizontalStretch = False;
		
	EndIf;
	
	If ItemToAdd.OutputFileTitle Then
		
		FileTitle = Form.Commands.Add("AttachedFileTitle_" + OneFileOnlyText + ItemNumber);
		FillPropertyValues(FileTitle, FormCommandProperties);
		
		TitleHyperlink = Form.Items.Add("AttachedFileTitle" + ItemNumber,
			Type("FormButton"), HeaderGroup);
		
		TitleHyperlink.Type = FormButtonType.Hyperlink;
		TitleHyperlink.CommandName = FileTitle.Name;
		TitleHyperlink.AutoMaxWidth = False;
		If Not ValueIsFilled(PlacementAttribute) Then
			FileTitle.ToolTip       = "";
			TitleHyperlink.Title = NStr("ru = 'загрузить'; en = 'upload'; pl = 'załaduj';es_ES = 'cargar';es_CO = 'cargar';tr = 'karşıya yükle';it = 'caricare';de = 'hochladen'");
		ElsIf Common.IsReference(TypeOf(PlacementAttribute)) Then
			FileTitle.ToolTip       = NStr("ru = 'Открыть файл'; en = 'Open file'; pl = 'Otwórz plik';es_ES = 'Abrir el archivo';es_CO = 'Abrir el archivo';tr = 'Dosyayı aç';it = 'Aprire file';de = 'Datei öffnen'");
			AttachedFileAttributes  = Common.ObjectAttributesValues(PlacementAttribute, "Description, Extension");
			TitleHyperlink.Title = AttachedFileAttributes.Description
				+ ?(StrStartsWith(AttachedFileAttributes.Extension, "."), "", ".")
				+ AttachedFileAttributes.Extension;
		EndIf;
		
	EndIf;
	
	PictureAdd = ?(ItemToAdd.ShowPreview, PictureLib.Camera,
		PictureLib.Clip);
	
	If ItemToAdd.ShowCommandBar Then
		
		CommandBar = Form.Items.Add("AttachedFilesManagementCommandBar" + ItemNumber,
			Type("FormGroup"), HeaderGroup);
		
		CommandBar.Type = FormGroupType.CommandBar;
		CommandBar.HorizontalStretch = True;
		
		SubmenuAdd = Form.Items.Add("AddingFileSubmenu" + ItemNumber,
			Type("FormGroup"), CommandBar);
		
		SubmenuAdd.Type         = FormGroupType.Popup;
		SubmenuAdd.Picture    = PictureAdd;
		SubmenuAdd.Title   = NStr("ru = 'Заменить'; en = 'Overwrite'; pl = 'Zastąp';es_ES = 'Volver a escribir';es_CO = 'Volver a escribir';tr = 'Üzerine yaz';it = 'Sovrascrivere';de = 'Umschreiben'");
		SubmenuAdd.Representation = ButtonRepresentation.Picture;
		
		SubmenuGroup = Form.Items.Add("FileAddingGroup" + ItemNumber,
			Type("FormGroup"), SubmenuAdd);
			
		SubmenuGroup.Type = FormGroupType.ButtonGroup;
		
	EndIf;
	
	If ItemToAdd.AddFiles Then
		
		ImportFile = Form.Commands.Add("AttachedFilesManagementImportFile_" 
			+ OneFileOnlyText + ItemNumber);
		ImportFile.Action  = "Attachable_AttachedFilesPanelCommand";
		ImportFile.ToolTip = NStr("ru = 'Загрузить файл с диска'; en = 'Upload file from a hard drive.'; pl = 'Załaduj plik z dysku.';es_ES = 'Cargar el archivo desde el disco duro.';es_CO = 'Cargar el archivo desde el disco duro.';tr = 'Sabit sürücüden karşıya dosya yükle.';it = 'Caricare file da disco rigido.';de = 'Datei aus einer Festplatte hochladen.'");
		
		If ItemToAdd.ShowCommandBar Then
			
			LoadButton = AddButtonOnForm(Form, "AttachedFilesManagementImportFile" + ItemNumber,
				CommandBar, ImportFile.Name);
			
			LoadButton.Picture    = PictureAdd;
			LoadButton.Visible   = False;
			LoadButton.Representation = ButtonRepresentation.Picture;
			
			LoadButtonFromSubmenu = AddButtonOnForm(Form, "AttachedFilesManagementImportFileFromSubmenu" + ItemNumber,
				SubmenuGroup, ImportFile.Name);
			
			FillPropertyValues(LoadButtonFromSubmenu, LoadButtonProperties);
			
		EndIf;
		
		If ItemToAdd.ShowPreview Then
			
			LoadButtonFromContextMenu = AddButtonOnForm(Form, 
				"AttachedFilesManagementImportFileFromContextMenu" + ItemNumber,
				ContextMenuAddGroup, ImportFile.Name);
			
			FillPropertyValues(LoadButtonFromContextMenu, LoadButtonProperties);
			
		EndIf;
		
		If Not ItemToAdd.OneFileOnly Then
			
			CreateByTemplate = Form.Commands.Add("AttachedFilesManagementCreateByTemplate_" + ItemNumber);
			CreateByTemplate.Title = NStr("ru = 'Создать по шаблону...'; en = 'Create from template...'; pl = 'Utwórz na podstawie szablonu...';es_ES = 'Crear desde la plantilla...';es_CO = 'Crear desde la plantilla...';tr = 'Şablondan oluştur...';it = 'Creare da modello...';de = 'Nach Vorlage generieren...'");
			FillPropertyValues(CreateByTemplate, FormCommandProperties);
		
			If ItemToAdd.ShowCommandBar Then
				AddButtonOnForm(Form, "AttachedFilesManagementCreateByTemplate" + ItemNumber,
					SubmenuGroup, CreateByTemplate.Name);
			EndIf;
			
			If ItemToAdd.ShowPreview Then
				AddButtonOnForm(Form, "AttachedFilesManagementCreateByTemplateFromContextMenu" + ItemNumber,
					ContextMenuAddGroup, CreateByTemplate.Name);
			EndIf;
		
			Scan = Form.Commands.Add("AttachedFilesManagementScan_" + ItemNumber);
			Scan.Title = NStr("ru = '" + ?(Common.IsMobileClient(), "Take a photograph", "Scan")+ "...'");
			FillPropertyValues(Scan, FormCommandProperties);
		
			If ItemToAdd.ShowCommandBar Then
				AddButtonOnForm(Form, "AttachedFilesManagementScan" + ItemNumber,
					SubmenuGroup, Scan.Name);
			EndIf;
			
			If ItemToAdd.ShowPreview Then
				AddButtonOnForm(Form, "AttachedFilesManagementScanFromContextMenu" + ItemNumber,
					ContextMenuAddGroup, Scan.Name);
			EndIf;
					
		EndIf;
				
	EndIf;
	
	If ItemToAdd.SelectFile
		AND UpdateAvailable Then
		
		SelectFile           = Form.Commands.Add("AttachedFilesManagementSelectFile_" + ItemNumber);
		SelectFile.Action  = "Attachable_AttachedFilesPanelCommand";
		SelectFile.ToolTip = NStr("ru = 'Выбрать файл из присоединенных'; en = 'Select a file from attached ones.'; pl = 'Wybierz jeden z załączonych plików.';es_ES = 'Seleccionar un archivo de los adjuntos.';es_CO = 'Seleccionar un archivo de los adjuntos.';tr = 'Ekli olanlardan dosya seç.';it = 'Selezionare un file tra gli allegati.';de = 'Eine Datei aus angehängten Dateien auswählen.'");
		
		If ItemToAdd.ShowCommandBar Then
			
			ChooseFileButton = AddButtonOnForm(Form, "AttachedFilesManagementSelectFile" + ItemNumber,
				SubmenuAdd, SelectFile.Name);
			
			FillPropertyValues(ChooseFileButton, SelectionButtonProperties);
			
		EndIf;
		
		If ItemToAdd.ShowPreview Then
			
			ChooseFromContextMenuButton = AddButtonOnForm(Form, 
				"SelectFileFromContextMenu" + ItemNumber, PreviewContextMenu, SelectFile.Name);
			FillPropertyValues(ChooseFromContextMenuButton, SelectionButtonProperties);
			
		EndIf;
		
	EndIf;
	
	If ItemToAdd.ViewFile Then
		
		ViewFile = Form.Commands.Add("AttachedFilesManagementViewFile_" + ItemNumber);
		ViewFile.Title = NStr("ru = 'Просмотреть'; en = 'View'; pl = 'Widok';es_ES = 'Ver';es_CO = 'Ver';tr = 'Görüntüle';it = 'Visualizzare';de = 'Ansicht'");
		FillPropertyValues(ViewFile, FormCommandProperties);
		
		If ItemToAdd.OneFileOnly Then
			ViewFile.Picture = PictureLib.OpenSelectedFile;
			ViewFile.Representation = ButtonRepresentation.Picture;
		EndIf;
		
		If ItemToAdd.ShowCommandBar Then
			AddButtonOnForm(Form, "ViewFile" + ItemNumber, CommandBar, ViewFile.Name);
		EndIf;
		
	EndIf;
	
	If ItemToAdd.ClearFile
		AND UpdateAvailable Then
		
		ClearFile           = Form.Commands.Add("AttachedFilesManagementClear_" + ItemNumber);
		ClearFile.Picture  = PictureLib.Clear;
		ClearFile.Title = NStr("ru = 'Очистить'; en = 'Clear'; pl = 'Wyczyść';es_ES = 'Eliminar';es_CO = 'Eliminar';tr = 'Temizle';it = 'Cancellare';de = 'Löschen'");
		ClearFile.ToolTip = ClearFile.Title;
		FillPropertyValues(ClearFile, FormCommandPropertiesPicture);
		
		If ItemToAdd.ShowCommandBar Then
			AddButtonOnForm(Form, "ClearFile" + ItemNumber, CommandBar, ClearFile.Name);
		EndIf;
		
		If ItemToAdd.ShowPreview Then
			AddButtonOnForm(Form, "ClearFromContextMenu" + ItemNumber,
				PreviewContextMenu, ClearFile.Name);
		EndIf;
		
	EndIf;
	
	EditFile = Undefined;
	If ItemToAdd.EditFile = "InForm" Then
		
		EditFile           = Form.Commands.Add("AttachedFilesManagementOpenForm" + ItemNumber);
		EditFile.Picture  = PictureLib.Magnifier;
		EditFile.Title = NStr("ru = 'Открыть карточку'; en = 'Open card'; pl = 'Otwórz kartę';es_ES = 'Abrir versión tarjeta';es_CO = 'Abrir versión tarjeta';tr = 'Kartı aç';it = 'Aprire scheda';de = 'Karte öffnen'");
		EditFile.ToolTip = NStr("ru = 'Открыть карточку присоединенного файла'; en = 'Open the attached file card.'; pl = 'Otwórz załączoną kartę pliku.';es_ES = 'Abrir la tarjeta del archivo adjunto.';es_CO = 'Abrir la tarjeta del archivo adjunto.';tr = 'Ekli dosya kartını aç.';it = 'Aprire la scheda file allegata.';de = 'Die Karte der angehängten Datei öffnen.'");
		FillPropertyValues(EditFile, FormCommandPropertiesPicture);
		
		If ItemToAdd.ShowCommandBar Then
			AddButtonOnForm(Form, "EditFile" + ItemNumber, CommandBar, EditFile.Name);
		EndIf;
		
		If ItemToAdd.ShowPreview Then
			AddButtonOnForm(Form, "EditFromContextMenu" + ItemNumber,
				PreviewContextMenu, EditFile.Name);
		EndIf;
		
	ElsIf ItemToAdd.EditFile = "Directly"
		AND UpdateAvailable Then
		
		EditFile           = Form.Commands.Add("AttachedFilesManagementEditFile_" + ItemNumber);
		EditFile.Picture  = PictureLib.Change;
		EditFile.Title = NStr("ru = 'Редактировать'; en = 'Edit'; pl = 'Edytuj';es_ES = 'Editar';es_CO = 'Editar';tr = 'Düzenle';it = 'Modificare';de = 'Bearbeiten'");
		EditFile.ToolTip = NStr("ru = 'Открыть файл для редактирования'; en = 'Open the file for editing.'; pl = 'Otwórz plik do edytowania.';es_ES = 'Abra el archivo para editarlo.';es_CO = 'Abra el archivo para editarlo.';tr = 'Düzenleme için dosyayı aç.';it = 'Aprire file per la modifica.';de = 'Die Datei zur Bearbeitung öffnen.'");
		FillPropertyValues(EditFile, FormCommandPropertiesPicture);
		
		PutFile           = Form.Commands.Add("AttachedFilesManagementPlaceFile_" + ItemNumber);
		PutFile.Picture  = PictureLib.EndFileEditing;
		PutFile.Title = NStr("ru = 'Закончить редактирование'; en = 'Commit'; pl = 'Zatwierdź';es_ES = 'Fijar';es_CO = 'Fijar';tr = 'Uygula';it = 'Bloccare';de = 'Commit'");
		PutFile.ToolTip = NStr("ru = 'Сохранить и освободить файл в информационной базе'; en = 'Save the file and release it.'; pl = 'Zapisz plik i zwolnij go.';es_ES = 'Guardar el archivo y lanzarlo.';es_CO = 'Guardar el archivo y lanzarlo.';tr = 'Dosyayı kaydet ve serbest bırak.';it = 'Salvare file e rilasciarlo.';de = 'Die Datei speichern und freigeben.'");
		FillPropertyValues(PutFile, FormCommandPropertiesPicture);
		
		CancelEdit = Form.Commands.Add(
			"AttachedFilesManagementCancelEditing_" + ItemNumber);
		
		CancelEdit.Picture  = PictureLib.UnlockFile;
		CancelEdit.Title = NStr("ru = 'Отменить редактирование'; en = 'Cancel editing'; pl = 'Anuluj edytowanie';es_ES = 'Cancelar la edición';es_CO = 'Cancelar la edición';tr = 'Düzenlemeyi iptal et';it = 'Annullare modifiche';de = 'Bearbeiten abbrechen'");
		CancelEdit.ToolTip = NStr("ru = 'Освободить занятый файл'; en = 'Release a locked file.'; pl = 'Zwolnij zablokowany plik.';es_ES = 'Lanzar un archivo bloqueado.';es_CO = 'Lanzar un archivo bloqueado.';tr = 'Kilitli dosyayı serbest bırak.';it = 'Rilasciare un file bloccato.';de = 'Eine gesperrte Datei freigeben.'");
		FillPropertyValues(CancelEdit, FormCommandPropertiesPicture);
		
		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
		FileDataParameters.RaiseException = False;
		FileDataParameters.GetBinaryDataRef = False;
		
		PlacementFileData = FileData(PlacementAttribute, FileDataParameters);
		
		If ItemToAdd.ShowCommandBar Then
			
			DirectEditingGroup = Form.Items.Add(
				"DirectEditingGroup" + ItemNumber,
				Type("FormGroup"), CommandBar);
			
			DirectEditingGroup.Type = FormGroupType.ButtonGroup;
			DirectEditingGroup.Representation = ButtonGroupRepresentation.Compact;
		
			EditButton = AddButtonOnForm(Form,
				"AttachedFilesManagementEditFile" + ItemNumber,
				DirectEditingGroup, EditFile.Name);
		
			PlaceButton = AddButtonOnForm(Form, "AttachedFilesManagementPlaceFile" + ItemNumber,
				DirectEditingGroup, PutFile.Name);
		
			CancelButton = AddButtonOnForm(Form, "AttachedFilesManagementCancelEditing" + ItemNumber,
				DirectEditingGroup, CancelEdit.Name);
			
			SetEditingAvailability(PlacementFileData, EditButton, CancelButton, PlaceButton);
			
		EndIf;
		
		If ItemToAdd.ShowPreview Then
			
			EditingGroupInMenu = Form.Items.Add(
				"EditingGroupInMenu" + ItemNumber,
				Type("FormGroup"), PreviewContextMenu);
			
			EditingGroupInMenu.Type = FormGroupType.ButtonGroup;
			
			EditButton = AddButtonOnForm(Form, "EditFileFromContextMenu" + ItemNumber,
				EditingGroupInMenu, EditFile.Name);
		
			CancelButton = AddButtonOnForm(Form, "PutFileFromContextMenu" + ItemNumber,
				EditingGroupInMenu, PutFile.Name);
		
			PlaceButton = AddButtonOnForm(Form, "CancelEditFromContextMenu" + ItemNumber,
				EditingGroupInMenu, CancelEdit.Name);
			
			SetEditingAvailability(PlacementFileData, EditButton, CancelButton, PlaceButton);
			
		EndIf;
		
	EndIf;
EndProcedure

Procedure SetEditingAvailability(FileData, EditButton, CancelButton, PlaceButton)
	
	If FileData <> Undefined Then
		
		EditButton.Enabled = Not FileData.FileBeingEdited;
		CancelButton.Enabled = FileData.FileBeingEdited
			AND FileData.CurrentUserEditsFile;
		PlaceButton.Enabled = FileData.FileBeingEdited
			AND FileData.CurrentUserEditsFile;
		
	Else
		
		CancelButton.Enabled = False;
		PlaceButton.Enabled = False;
		EditButton.Enabled = False;
		
	EndIf;

EndProcedure

Function AddButtonOnForm(Form, ButtonName, Parent, CommandName)
	
	FormButton = Form.Items.Add(ButtonName,
		Type("FormButton"), Parent);

	FormButton.CommandName = CommandName;
	
	Return FormButton;
	
EndFunction

Function FormAttributeByName(FormAttributes, AttributeName)
	
	For Each Attribute In FormAttributes Do
		If Attribute.Name = AttributeName Then
			Return Attribute;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion
