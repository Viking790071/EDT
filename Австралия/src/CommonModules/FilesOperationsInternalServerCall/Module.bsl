
////////////////////////////////////////////////////////////////////////////////
// File operations subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Internal

Procedure UpdateAttachedFile(Val AttachedFile, Val FileInfo) Export
	
	FilesOperations.RefreshFile(AttachedFile, FileInfo);
	
EndProcedure

// Obsolete. Use FilesOperations.DefiineAttachedFileForm.
Procedure DetermineAttachedFileForm(Source,
                                                      FormType,
                                                      Parameters,
                                                      SelectedForm,
                                                      AdditionalInformation,
                                                      StandardProcessing) Export
	
	FilesOperations.DetermineAttachedFileForm(Source,
		FormType,
		Parameters,
		SelectedForm,
		AdditionalInformation,
		StandardProcessing);
		
EndProcedure

// See the AddAttachedFile ifunction in the FilesOperations module.
Function AppendFile(FileParameters,
                     Val FileAddressInTempStorage,
                     Val TempTextStorageAddress = "",
                     Val Details = "") Export
	
	Return FilesOperations.AppendFile(
		FileParameters,
		FileAddressInTempStorage,
		TempTextStorageAddress,
		Details);
	
EndFunction

// The procedure adds settings specific to the File operations subsystem.
//
// Parameters:
//  CommonSettings        - Structure - settings common for all users.
//  PersonalSettings - Structure - settings different for different users.
//  
Procedure AddFilesOperationsSettings(CommonSettings, PersonalSettings) Export
	
	SetPrivilegedMode(True);
	
	PersonalSettings.Insert("ActionOnDoubleClick", ActionOnDoubleClick());
	PersonalSettings.Insert("FileVersionsComparisonMethod",  FileVersionsComparisonMethod());
	
	PersonalSettings.Insert("PromptForEditModeOnOpenFile",
		PromptForEditModeOnOpenFile());
	
	PersonalSettings.Insert("IsFullUser",
		Users.IsFullUser(,, False));
	
	ShowLockedFilesOnExit = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", "ShowLockedFilesOnExit");
	
	If ShowLockedFilesOnExit = Undefined Then
		ShowLockedFilesOnExit = True;
		
		Common.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowLockedFilesOnExit",
			ShowLockedFilesOnExit);
	EndIf;
	
	PersonalSettings.Insert("ShowLockedFilesOnExit",
		ShowLockedFilesOnExit);
	
	PersonalSettings.Insert("ShowSizeColumn", GetShowSizeColumn());
	
EndProcedure

// It will return the total size of files in a volume (in bytes).
Function CalculateFileSizeInVolume(VolumeRef) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return 0;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(SUM(Versions.Size), 0) AS FilesSize
	|FROM
	|	Catalog.FilesVersions AS Versions
	|WHERE
	|	Versions.Volume = &Volume";
	
	Query.Parameters.Insert("Volume", VolumeRef);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FileSizeInVolume = Number(Selection.FilesSize);
	EndIf;
	
	OwnersTypes = Metadata.InformationRegisters.FilesExist.Dimensions.ObjectWithFiles.Type.Types();
	TotalCatalogNames = New Map;
	
	Query = New Query;
	Query.Parameters.Insert("Volume", VolumeRef);
	
	For Each Type In OwnersTypes Do
		
		If Type = Type("CatalogRef.MetadataObjectIDs") Then
			Continue;
		EndIf;
		
		CatalogNames = FilesOperationsInternal.FileStorageCatalogNames(Type, True);
		
		For each KeyAndValue In CatalogNames Do
			If TotalCatalogNames[KeyAndValue.Key] <> Undefined Then
				Continue;
			EndIf;
			AttachedFilesCatalogName = KeyAndValue.Key;
			TotalCatalogNames.Insert(KeyAndValue.Key, True);
		
			Query.Text =
			"SELECT
			|	ISNULL(SUM(AttachedFiles.Size), 0) AS FilesSize
			|FROM
			|	&CatalogName AS AttachedFiles
			|WHERE
			|	AttachedFiles.Volume = &Volume";
			Query.Text = StrReplace(Query.Text, "&CatalogName",
				"Catalog." + AttachedFilesCatalogName);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				FileSizeInVolume = FileSizeInVolume + Selection.FilesSize;
			EndIf
		EndDo;
	EndDo;
	
	Return FileSizeInVolume;
	
EndFunction

// Reads file version encoding.
//
// Parameters:
// VersionRef - a reference to file version.
//
// Returns:
//   Encoding string
Function GetFileVersionEncoding(VersionRef) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.FileEncoding.CreateRecordManager();
	RecordManager.File = VersionRef;
	RecordManager.Read();
	
	Return RecordManager.Encoding;
	
EndFunction

// Receives file data and its binary data.
//
// Parameters:
//  FileOrVersionRef - CatalogRef.Files, CatalogRef.FilesVersions - a file or a file version.
//  SignatureAddress - an URL, containing the signature file address in a temporary storage.
//  FormID  - UUID - a form UUID.
//
// Returns:
//   Structure - FileData and the file itself as BinaryData and file signature as BinaryData.
//
Function FileDataAndBinaryData(FileOrVersionRef, SignatureAddress = Undefined, FormID = Undefined) Export
	
	ObjectMetadata = Metadata.FindByType(TypeOf(FileOrVersionRef));
	IsFilesCatalog = Common.HasObjectAttribute("FileOwner", ObjectMetadata);
	AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", ObjectMetadata);
	If AbilityToStoreVersions AND ValueIsFilled(FileOrVersionRef.CurrentVersion) Then
		VersionRef = FileOrVersionRef.CurrentVersion;
		FileData = FileData(FileOrVersionRef, VersionRef);
	ElsIf IsFilesCatalog Then
		VersionRef = FileOrVersionRef;
		FileData = FileData(FileOrVersionRef);
	Else
		VersionRef = FileOrVersionRef;
		FileData = FileData(FileOrVersionRef.Owner, VersionRef);
	EndIf;
	
	BinaryData = Undefined;
	
	FileStorageType = VersionRef.FileStorageType;
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		If NOT VersionRef.Volume.IsEmpty() Then
			FullPath = FilesOperationsInternal.FullVolumePath(VersionRef.Volume) + VersionRef.PathToFile; 
			Try
				BinaryData = New BinaryData(FullPath);
			Except
				// Record to the event log.
				ErrorMessage = GenerateErrorTextOfGetFileFromVolumeForAdministrator(
					ErrorInfo(), VersionRef.Owner);
				
				WriteLogEvent(
					NStr("ru = 'Файлы.Открытие файла'; en = 'Files.File opens'; pl = 'Pliki.Otwórz plik';es_ES = 'Archivo.Abrir el archivo';es_CO = 'Archivo.Abrir el archivo';tr = 'Dosyalar. Dosyayı aç';it = 'File.Apertura file';de = 'Dateien. Datei öffnen'",
					     CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs.Files,
					VersionRef.Owner,
					ErrorMessage);
				
				Raise FilesOperationsInternalClientServer.ErrorFileNotFoundInFileStorage(
					VersionRef.FullDescr + "." + VersionRef.Extension);
			EndTry;
		EndIf;
	Else
		FileStorage = FilesOperations.FileFromInfobaseStorage(VersionRef);
		BinaryData = FileStorage.Get();
	EndIf;

	SignatureBinaryData = Undefined;
	If SignatureAddress <> Undefined Then
		SignatureBinaryData = GetFromTempStorage(SignatureAddress);
	EndIf;
	
	If FormID <> Undefined Then
		BinaryData = PutToTempStorage(BinaryData, FormID);
	EndIf;
	
	ReturnStructure = New Structure("FileData, BinaryData, SignatureBinaryData",
		FileData, BinaryData, SignatureBinaryData);
	
	Return ReturnStructure;
EndFunction

// Receives all subordinate files.
// Parameters:
//  FileOwner - AnyRef - a file owner.
//
// Returns:
//   Array - an array of files
Function GetAllSubordinateFiles(FileOwner) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Files.Ref AS Ref
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Create a folder of files.
//
// Parameters:
//   Name - String - a folder name
//   Parent - DefinedType.AttachedFilesOwner - a parent folder.
//   User - CatalogRef.Users - a person responsible for a folder.
//   FilesGroup - DefinedTYpe.AttachedFile - a group (for hierarchical file catalogs).
//
// Returns:
//   CatalogRef.FilesFolders.
//
Function CreateFilesFolder(Name, Parent, User = Undefined, GroupOfFiles = Undefined) Export
	
	If IsDirectoryFiles(Parent) Then
		Folder = Catalogs.FileFolders.CreateItem();
		Folder.EmployeeResponsible = ?(User <> Undefined, User, Users.CurrentUser());
		Folder.Parent = Parent;
	Else
		Folder = Catalogs[FilesOperationsInternal.FileStoringCatalogName(Parent)].CreateFolder();
		Folder.FileOwner = Parent;
		Folder.Author = ?(User <> Undefined, User, Users.CurrentUser());
		Folder.Parent = GroupOfFiles;
	EndIf;
	Folder.Description = Name;
	Folder.CreationDate = CurrentSessionDate();
	Folder.Fill(Undefined);
	Folder.Write();
	Return Folder.Ref;
	
EndFunction

// Creates a file in the database together with its version.
//
// Parameters:
//   Owner       - CatalogRef.FilesFolders, AnyRef - it will be set to the FileOwner attribute of 
//                    the created file.
//   FileInfo - Structure - see FilesOperationsClientServer.FIleInfo in the FileWIthVersion mode. 
//
// Returns:
//    CatalogRef.Files - a created file.
//
Function CreateFileWithVersion(FileOwner, FileInfo) Export
	
	BeginTransaction();
	Try
	
		// Creating a file card in the database.
		FileRef = CreateFile(FileOwner, FileInfo);
		Version = Catalogs.FilesVersions.EmptyRef();
		If FileInfo.StoreVersions Then
			// Creating a saved file version to save to the File card.
			Version = FilesOperationsInternal.CreateVersion(FileRef, FileInfo);
			// Inserting the reference to the version to the File card.
		EndIf;
		FilesOperationsInternal.UpdateVersionInFile(FileRef, Version, FileInfo.TempTextStorageAddress);
		
		If FileInfo.Encoding <> Undefined Then
			WriteFileVersionEncoding(
				?(Version = Catalogs.FilesVersions.EmptyRef(), FileRef, Version), FileInfo.Encoding);
		EndIf;
		
		HasSaveRight = AccessRight("SaveUserData", Metadata);
		If FileInfo.WriteToHistory AND HasSaveRight Then
			FileURL = GetURL(FileRef);
			UserWorkHistory.Add(FileURL);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	FilesOperationsOverridable.OnCreateFile(FileRef);
	
	Return FileRef;
	
EndFunction

// Releases the file.
//
// Parameters:
//   FileData - Structure - see FileData. 
//   UUID - UUID - a form UUID.
//
Procedure UnlockFile(FileData, UUID = Undefined) Export
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileData.Ref)).FullName());
		DataLockItem.SetValue("Ref", FileData.Ref);
		DataLock.Lock();
		
		FileObject = FileData.Ref.GetObject();
		
		LockDataForEdit(FileObject.Ref, , UUID);
		FileObject.BeingEditedBy = Catalogs.Users.EmptyRef();
		FileObject.LoanDate = Date("00010101000000");
		FileObject.Write();
		UnlockDataForEdit(FileObject.Ref, UUID);
		
		FilesOperationsOverridable.OnUnlockFile(FileData, UUID);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function UnlockFiles(Val Files) Export
	
	For Each AttachedFile In Files Do
		FilesOperationsInternal.UnlockFile(AttachedFile);
	EndDo;
	Return FilesOperationsInternal.LockedFilesCount();
	
EndFunction

// Locks a file for a checkout.
//
// Parameters:
//  FileData  - a structure with file data.
//  ErrorString - a string, where the error  reason is returned (for example, "File is locked by 
//                 other user").
//  UUID - a form UUID.
//
// Returns:
//   Boolean  - shows whether the operation is performed successfully.
//
Function LockFile(FileData, ErrorRow = "", UUID = Undefined, User = Undefined) Export
	
	ErrorRow = "";
	FilesOperationsOverridable.OnAttemptToLockFile(FileData, ErrorRow);
	If Not IsBlankString(ErrorRow) Then
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileData.Ref)).FullName());
		DataLockItem.SetValue("Ref", FileData.Ref);
		DataLock.Lock();
		
		FileObject = FileData.Ref.GetObject();
		
		LockDataForEdit(FileObject.Ref, , UUID);
		If User = Undefined Then
			FileObject.BeingEditedBy = Users.AuthorizedUser();
		Else
			FileObject.BeingEditedBy = User;
		EndIf;
		FileObject.LoanDate = CurrentSessionDate();
		FileObject.Write();
		UnlockDataForEdit(FileObject.Ref, UUID);
		
		CurrentVersionURL = FileData.CurrentVersionURL;
		OwnerWorkingDirectory = FileData.OwnerWorkingDirectory;
		
		FileData = FileData(FileData.Ref, ?(FileData.Version = FileData.Ref, Undefined, FileData.Version));
		FileData.CurrentVersionURL = CurrentVersionURL;
		FileData.OwnerWorkingDirectory = OwnerWorkingDirectory;
		
		FilesOperationsOverridable.OnLockFile(FileData, UUID);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
	
EndFunction

// THe function returns the structure containing various info on the file and version.
//
// Parameters:
//  FileOrVersionRef  - CatalogRef.Files, CatalogRef.FilesVersions - a file or a file version.
//
// Returns:
//   Structure - a structure with file data.
//
Function FileData(FileRef, VersionRef = Undefined, FormID = Undefined) Export
	
	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);
	
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;
	InfobaseUpdate.CheckObjectProcessed(FileRef);
	
	FileObject = FileRef.GetObject();
	
	FileData = New Structure;
	FileData.Insert("Ref", FileObject.Ref);
	FileData.Insert("BeingEditedBy", FileObject.BeingEditedBy);
	FileData.Insert("Owner", FileObject.FileOwner);
	
	FileObjectMetadata = Metadata.FindByType(TypeOf(FileRef));
	
	If Common.HasObjectAttribute("CurrentVersion", FileObjectMetadata) AND ValueIsFilled(FileRef.CurrentVersion) Then
		CurrentFileVersion = FileObject.CurrentVersion;
		// Without the ability to store versions.
	Else
		CurrentFileVersion = FileRef;
	EndIf;
	
	If VersionRef <> Undefined Then
		FileData.Insert("Version", VersionRef);
	Else
		FileData.Insert("Version", CurrentFileVersion);
	EndIf;
	
	FileData.Insert("CurrentVersion", CurrentFileVersion);
	FileData.Insert("StoreVersions", FileObject.StoreVersions);
	FileData.Insert("DeletionMark", FileObject.DeletionMark);
	FileData.Insert("Encrypted", FileObject.Encrypted);
	FileData.Insert("SignedWithDS", FileObject.SignedWithDS);
	FileData.Insert("LoanDate", FileObject.LoanDate);
	
	If VersionRef = Undefined Then
		FileData.Insert("BinaryFileDataRef",
			PutToTempStorage(FilesOperations.FileBinaryData(FileRef), FormID));
		FileData.Insert("URL", GetURL(FileRef));
		FileData.Insert("CurrentVersionAuthor", FileRef.Changed);
		FileData.Insert("Encoding", FilesOperations.FileEncoding(FileRef, FileObject.Extension));
	Else
		FileData.Insert("BinaryFileDataRef",
			PutToTempStorage(FilesOperations.FileBinaryData(VersionRef), FormID));
		FileData.Insert("URL", GetURL(FileObject.Ref));
		FileData.Insert("CurrentVersionAuthor", VersionRef.Author);
		FileData.Insert("Encoding", FilesOperations.FileEncoding(VersionRef, FileObject.Extension));
	EndIf;
	
	If FileData.Encrypted Then
		EncryptionCertificatesArray = EncryptionCertificates(FileData.Ref);
		FileData.Insert("EncryptionCertificatesArray", EncryptionCertificatesArray);
	EndIf;
	
	FillAdditionalFileData(FileData, FileObject, VersionRef);
	
	Return FileData;
	
EndFunction

Procedure FillAdditionalFileData(Result, AttachedFile, FileVersion = Undefined) Export
	
	CatalogSupportsPossibitityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", Metadata.FindByType(TypeOf(AttachedFile)));
	
	If CatalogSupportsPossibitityToStoreVersions AND ValueIsFilled(AttachedFile.CurrentVersion) Then
		CurrentFileVersion = AttachedFile.CurrentVersion;
	Else
		CurrentFileVersion = AttachedFile.Ref;
	EndIf;
	
	Result.Insert("CurrentVersion", CurrentFileVersion);
	
	If FileVersion <> Undefined Then
		Result.Insert("Version", FileVersion);
	ElsIf CatalogSupportsPossibitityToStoreVersions AND ValueIsFilled(AttachedFile.CurrentVersion) Then
		Result.Insert("Version", AttachedFile.CurrentVersion);
	Else
		Result.Insert("Version", AttachedFile.Ref);
	EndIf;
	
	If ValueIsFilled(FileVersion) Then
		VersionObject = FileVersion.GetObject();
		Result.Insert("Description",                 VersionObject.Description);
		Result.Insert("Extension",                   VersionObject.Extension);
		Result.Insert("Size",                       VersionObject.Size);
		Result.Insert("VersionNumber",                  VersionObject.Size);
		Result.Insert("UniversalModificationDate", VersionObject.UniversalModificationDate);
		Result.Insert("Volume",                          VersionObject.Volume);
		Result.Insert("Author",                        VersionObject.Author);
		Result.Insert("TextExtractionStatus",       VersionObject.TextExtractionStatus);
		Result.Insert("FullVersionDescription",     TrimAll(VersionObject.FullDescr));
		CurrentFileVersion = FileVersion;
	Else
		Result.Insert("Description",                 AttachedFile.Description);
		Result.Insert("Extension",                   AttachedFile.Extension);
		Result.Insert("Size",                       AttachedFile.Size);
		Result.Insert("VersionNumber",                  0);
		Result.Insert("UniversalModificationDate", AttachedFile.UniversalModificationDate);
		Result.Insert("Volume",                          AttachedFile.Volume);
		Result.Insert("Author",                        AttachedFile.Author);
		Result.Insert("TextExtractionStatus",       AttachedFile.TextExtractionStatus);
		Result.Insert("FullVersionDescription",     TrimAll(AttachedFile.Description));
		CurrentFileVersion = Result.Version;
	EndIf;
	
	KeyStructure = New Structure("File", CurrentFileVersion);
	RecordKey = InformationRegisters.FilesBinaryData.CreateRecordKey(KeyStructure);
	CurrentVersionURL = GetURL(RecordKey, "FileBinaryData");
	Result.Insert("CurrentVersionURL", CurrentVersionURL);
	
	CurrentVersionEncoding = GetFileVersionEncoding(CurrentFileVersion);
	Result.Insert("CurrentVersionEncoding", CurrentVersionEncoding);
	CurrentUser = Users.AuthorizedUser();
	ForReading = Result.BeingEditedBy <> CurrentUser;
	Result.Insert("ForReading", ForReading);
	
	InWorkingDirectoryForRead = True;
	InOwnerWorkingDirectory = False;
	DirectoryName = UserWorkingDirectory();
	
	If ValueIsFilled(CurrentFileVersion) Then
		FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(CurrentFileVersion, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
	
		Result.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
	EndIf;
	Result.Insert("InWorkingDirectoryForRead", InWorkingDirectoryForRead);
	Result.Insert("OwnerWorkingDirectory", "");
	
	EditedByCurrentUser = (Result.BeingEditedBy = CurrentUser);
	Result.Insert("CurrentUserEditsFile", EditedByCurrentUser);
	
	TextExtractionStatusString = "NotExtracted";
	If Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted Then
		TextExtractionStatusString = "NotExtracted";
	ElsIf Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted Then
		TextExtractionStatusString = "Extracted";
	ElsIf Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction Then
		TextExtractionStatusString = "FailedExtraction";
	EndIf;
	Result.Insert("TextExtractionStatus", TextExtractionStatusString);
	
	FolderForSaveAs = Common.CommonSettingsStorageLoad("ApplicationSettings", "FolderForSaveAs");
	Result.Insert("FolderForSaveAs", FolderForSaveAs);
	
EndProcedure

Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetBinaryDataRef = True,
                            Val ForEditing = False) Export
	
	Return FilesOperations.FileData(AttachedFile, 
                    FormID,
                    GetBinaryDataRef,
                    ForEditing);
EndFunction

Function FileDataToPrint(Val AttachedFile, Val FormID = Undefined) Export
	
	FileData = GetFileData(AttachedFile, FormID);
	Extension = Lower(FileData.Extension);
	If Extension = "mxl" Then
		FileBinaryData = GetFromTempStorage(FileData.BinaryFileDataRef);
		TempFileName = GetTempFileName();
		FileBinaryData.Write(TempFileName);
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(TempFileName);
		SafeModeSet = SafeMode() <> False;
		
		If TypeOf(SafeModeSet) = Type("String") Then
			SafeModeSet = True;
		EndIf;
	
		If Not SafeModeSet Then
			DeleteFiles(TempFileName);
		EndIf;
		FileData.Insert("SpreadsheetDocument", SpreadsheetDocument);
	EndIf;
	
	Return FileData;
	
EndFunction

// THe function returns the structure containing various info on the file and version.
Function FileDataToOpen(FileRef, VersionRef, FormID = Undefined,
	OwnerWorkingDirectory = Undefined, FilePreviousURL = Undefined) Export
	
	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);
	
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;
	
	If FilePreviousURL <> Undefined Then
		If NOT IsBlankString(FilePreviousURL) AND IsTempStorageURL(FilePreviousURL) Then
			DeleteFromTempStorage(FilePreviousURL);
		EndIf;
	EndIf;
	
	FileRef = FileRef;
	VersionRef = VersionRef;
	If Not ValueIsFilled(VersionRef) 
		AND Common.HasObjectAttribute("CurrentVersion", Metadata.FindByType(TypeOf(FileRef)))
		AND ValueIsFilled(FileRef.CurrentVersion) Then
		
		VersionRef = FileRef.CurrentVersion;
		
	EndIf;
	FileData = FileData(FileRef, VersionRef, FormID);
	
	If OwnerWorkingDirectory = Undefined Then
		OwnerWorkingDirectory = FolderWorkingDirectory(FileData.Owner);
	EndIf;
	FileData.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);
	
	If FileData.OwnerWorkingDirectory <> "" Then
		FileName = CommonClientServer.GetNameWithExtension(
			FileData.FullVersionDescription, FileData.Extension);
		FullFileNameInWorkingDirectory = OwnerWorkingDirectory + FileName;
		FileData.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
	EndIf;
	
	FileStorageType = FileData.Version.FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive AND FileData.Version <> Undefined Then
		
		SetPrivilegedMode(True);
		
		FileDataVolume = Catalogs.FileStorageVolumes.EmptyRef();
		FileDataFilePath = "";
		FileDataVolume = FileData.Version.Volume;
		FileDataFilePath = FileData.Version.PathToFile;
		
		If NOT FileDataVolume.IsEmpty() Then
			FullPath = FilesOperationsInternal.FullVolumePath(FileDataVolume) + FileDataFilePath; 
			Try
				BinaryData = New BinaryData(FullPath);
				// Working with the current version only. To work with the non-current version, receive a reference at the GetURLToOpen.
				FileData.CurrentVersionURL = PutToTempStorage(BinaryData, FormID);
			Except
				// Record to the event log.
				FileRef = ?(FileRef <> Undefined, FileRef, VersionRef);
				ErrorMessage = GenerateErrorTextOfGetFileFromVolumeForAdministrator(
					ErrorInfo(), FileRef);
				
				WriteLogEvent(
					NStr("ru = 'Файлы.Открытие файла'; en = 'Files.File opens'; pl = 'Pliki.Otwórz plik';es_ES = 'Archivo.Abrir el archivo';es_CO = 'Archivo.Abrir el archivo';tr = 'Dosyalar. Dosyayı aç';it = 'File.Apertura file';de = 'Dateien. Datei öffnen'",
					     CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs.Files,
					FileRef,
					ErrorMessage);
				
				If IsDirectoryFiles(FileData.Owner) Then
					OwnerPresentation = FullFolderPath(FileData.Owner);
				Else
					OwnerPresentation = FileData.Owner;
				EndIf;
				FileOwnerPresentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Присоединен к %1 : %2'; en = 'Attached to %1 : %2'; pl = 'Dołączony do %1 : %2';es_ES = 'Conectado con %1 : %2';es_CO = 'Conectado con %1 : %2';tr = 'Aşağıdaki ile bağlı %1: %2';it = 'Allegato a %1 : %2';de = 'Angehängt an %1: %2'"),
					String(TypeOf(FileData.Owner)),
					OwnerPresentation);
				
				Raise FilesOperationsInternalClientServer.ErrorFileNotFoundInFileStorage(
					FileData.FullVersionDescription + "." + FileData.Extension,
					,
					FileOwnerPresentation);
			EndTry;
		EndIf;
	EndIf;
	
	FilePreviousURL = FileData.CurrentVersionURL;
	
	Return FileData;
	
EndFunction

Function ImageFieldUpdateData(FileRef, DataGetParameters) Export
	
	FileData = ?(ValueIsFilled(FileRef), GetFileData(FileRef, DataGetParameters), Undefined);
	
	UpdateData = New Structure;
	UpdateData.Insert("FileData",   FileData);
	UpdateData.Insert("TextColor",    StyleColors.NotSelectedPictureTextColor);
	UpdateData.Insert("FileCorrupted", False);
	
	If FileData <> Undefined
		AND GetFromTempStorage(FileData.BinaryFileDataRef) = Undefined Then
		
		UpdateData.FileCorrupted = True;
		UpdateData.TextColor    = StyleColors.ErrorNoteText;
		
	EndIf;
	
	Return UpdateData;
	
EndFunction

Function AttachedFilesCount(FilesOwner, ReturnFilesData = False) Export
	
	OwnerFiles = New Structure;
	OwnerFiles.Insert("FilesCount", 0);
	OwnerFiles.Insert("FileData", Undefined);
	
	StorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(FilesOwner);
	If ValueIsFilled(StorageCatalogName) Then
	
		QueryText = 
		"SELECT ALLOWED DISTINCT
		|	CatalogFilesStorage.Ref AS File
		|FROM
		|	&CatalogName AS CatalogFilesStorage
		|WHERE
		|	CatalogFilesStorage.FileOwner = &FileOwner
		|	AND &IsFolder = FALSE
		|	AND &Internal = FALSE";
		QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + StorageCatalogName);
		
		QueryText = StrReplace(QueryText, "&Internal",
			?(FilesOperationsInternal.HasInternalAttribute(StorageCatalogName),
			"CatalogFilesStorage.Internal", "FALSE"));
			
		QueryText = StrReplace(QueryText, "&IsFolder", 
			?(Metadata.Catalogs[StorageCatalogName].Hierarchical,
			"CatalogFilesStorage.IsFolder", "FALSE"));
			
		Query = New Query(QueryText);
		Query.SetParameter("FileOwner", FilesOwner);
		FilesTable = Query.Execute().Unload();
		FilesCount = FilesTable.Count();
		
		OwnerFiles.FilesCount = FilesCount;
		If ReturnFilesData AND FilesCount > 0 Then
			OwnerFiles.FileData = FileData(FilesTable[0].File);
		EndIf;
		
	EndIf;
	
	Return ?(ReturnFilesData, OwnerFiles, OwnerFiles.FilesCount);
	
EndFunction

#EndRegion

#Region Private

// Saves the path to the user's working directory to the settings.
//
// Parameters:
//  DirectoryName - String - a file directory name.
//
Procedure SetUserWorkingDirectory(DirectoryName) Export
	
	SetPrivilegedMode(True);
	CommonServerCall.CommonSettingsStorageSave(
		"LocalFileCache", "PathToLocalFileCache", DirectoryName,,, True);
	
EndProcedure

// Returns a path to a user working directory in settings.
//
// Returns:
//  String - directory name.
//
Function UserWorkingDirectory()
	
	SetPrivilegedMode(True);
	DirectoryName = Common.CommonSettingsStorageLoad("LocalFileCache", "PathToLocalFileCache");
	If DirectoryName = Undefined Then
		DirectoryName = "";
	EndIf;
	
	Return DirectoryName;
	
EndFunction

Function IsDirectoryFiles(FilesOwner) Export
	
	Return FilesOperationsInternal.FileStoringCatalogName(FilesOwner) = "Files";
	
EndFunction

Function FileStoringCatalogName(FilesOwner) Export
	
	Return FilesOperationsInternal.FileStoringCatalogName(FilesOwner);
	
EndFunction

// Creates a file in the infobase.
//
// Parameters:
//   Owner       - CatalogRef.FilesFolders, AnyRef - it will be set to the FileOwner attribute of 
//                    the created file.
//   FileInfo - Structure - see FilesOperationsclientServer.FIleInfo in the File mode. 
//
// Returns:
//    CatalogRef.Files - a created file.
//
Function CreateFile(Val Owner, Val FileInfo)
	
	File = Catalogs[FileInfo.FilesStorageCatalogName].CreateItem();
	File.FileOwner = Owner;
	File.Description = FileInfo.BaseName;
	File.Author = ?(FileInfo.Author <> Undefined, FileInfo.Author, Users.CurrentUser());
	File.CreationDate = CurrentSessionDate();
	File.Details = FileInfo.Comment;
	File.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(Undefined);
	File.StoreVersions = FileInfo.StoreVersions;
	
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	If Metadata.Catalogs[FileInfo.FilesStorageCatalogName].FullTextSearch = FullTextSearchUsing Then
	
		If TypeOf(FileInfo.TempTextStorageAddress) = Type("ValueStorage") Then
			// When creating a File from a template, the value storage is copied directly.
			File.TextStorage = FileInfo.TempTextStorageAddress;
		ElsIf Not IsBlankString(FileInfo.TempTextStorageAddress) Then
			TextExtractionResult = FilesOperationsInternal.ExtractText(FileInfo.TempTextStorageAddress); 
			File.TextStorage = TextExtractionResult.TextStorage;
			File.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
		EndIf;
		
	Else
		File.TextStorage = New ValueStorage("");
		File.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
	File.Fill(Undefined);
	File.Write();
	Return File.Ref;
	
EndFunction

// Updates or creates a File version and returns a reference to the updated version (or False if the 
// file is not modified binary).
//
// Parameters:
//   FileRef     - CatalogRef.Files        - a file, for which a new version is created.
//   FileInfo - Structure                     - see FilesOperationsClientServer.FIleInfo in the 
//                                                    "FileWithVersion".
//   VersionRef   - CatalogRef.FilesVersions - a file version that needs to be updated.
//   UUIDOfForm                   - UUID - the UUID of the form that provides operation context.
//                                                    
//
// Returns:
//   CatalogRef.FilesVersions - created or modified version; it is Undefined if the file was not changed binary.
//
Function RefreshFileObject(FileRef,
	FileInfo,
	VersionRef = Undefined,
	UUIDOfForm = Undefined,
	User = Undefined)
	
	HasSaveRight = AccessRight("SaveUserData", Metadata);
	
	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);
	
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	ModificationTimeUniversal = FileInfo.ModificationTimeUniversal;
	If NOT ValueIsFilled(ModificationTimeUniversal)
		OR ModificationTimeUniversal > CurrentUniversalDate() Then
		ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;
	
	ModificationTime = FileInfo.Modified;
	If NOT ValueIsFilled(ModificationTime)
		OR ToUniversalTime(ModificationTime) > ModificationTimeUniversal Then
		ModificationTime = CurrentSessionDate();
	EndIf;
	
	FilesOperationsInternalClientServer.CheckExtentionOfFileToDownload(FileInfo.ExtensionWithoutPoint);
	
	CurrentVersionSize = 0;
	BinaryData = Undefined;
	CurrentVersionFileStorageType = Enums.FileStorageTypes.InInfobase;
	CurrentVersionVolume = Undefined;
	CurrentVersionFilePath = Undefined;
	
	CatalogMetadata = Metadata.FindByType(TypeOf(FileRef));
	CatalogSupportsPossibitityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", CatalogMetadata);
	
	VersionRefToCompareSize = VersionRef;
	If VersionRef <> Undefined Then
		VersionRefToCompareSize = VersionRef;
	ElsIf CatalogSupportsPossibitityToStoreVersions AND ValueIsFilled(FileRef.CurrentVersion) Then
		VersionRefToCompareSize = FileRef.CurrentVersion;
	Else
		VersionRefToCompareSize = FileRef;
	EndIf;
	
	PreVersionEncoding = GetFileVersionEncoding(VersionRefToCompareSize);
	
	AttributesStructure = Common.ObjectAttributesValues(VersionRefToCompareSize, 
		"Size, FileStorageType, Volume, PathToFile");
	CurrentVersionSize = AttributesStructure.Size;
	CurrentVersionFileStorageType = AttributesStructure.FileStorageType;
	CurrentVersionVolume = AttributesStructure.Volume;
	CurrentVersionFilePath = AttributesStructure.PathToFile;
	
	FileStorage = Undefined;
	If FileInfo.Size = CurrentVersionSize Then
		PreviousVersionBinaryData = Undefined;
		
		If CurrentVersionFileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			If NOT CurrentVersionVolume.IsEmpty() Then
				FullPath = FilesOperationsInternal.FullVolumePath(CurrentVersionVolume) + CurrentVersionFilePath; 
				PreviousVersionBinaryData = New BinaryData(FullPath);
			EndIf;
		Else
			FileStorage = FilesOperations.FileFromInfobaseStorage(VersionRefToCompareSize);
			PreviousVersionBinaryData = FileStorage.Get();
		EndIf;
		
		BinaryData = GetFromTempStorage(FileInfo.TempFileStorageAddress);
		
		If PreviousVersionBinaryData = BinaryData Then
			Return Undefined; // If the file is not changed binary, returning False.
		EndIf;
	EndIf;
	
	OldStorageType = Undefined;
	VersionLocked = False;
	Version = Undefined;
	
	If VersionRef = Undefined Then
		Version = FileRef.GetObject();
	EndIf;
	
	LockDataForEdit(Version.Ref, , UUIDOfForm);
	VersionLocked = True;
	
	// Deleting file from the hard drive and replacing it with the new one.
	If Version.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		If NOT Version.Volume.IsEmpty() Then
			FullPath = FilesOperationsInternal.FullVolumePath(Version.Volume) + Version.PathToFile; 
			FileOnHardDrive = New File(FullPath);
			If FileOnHardDrive.Exist() Then
				FileOnHardDrive.SetReadOnly(False);
				DeleteFiles(FullPath);
			EndIf;
			PathWithSubdirectory = FileOnHardDrive.Path;
			FilesArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
			If FilesArrayInDirectory.Count() = 0 Then
				DeleteFiles(PathWithSubdirectory);
			EndIf;
		EndIf;
	EndIf;
	
	If User = Undefined Then
		Version.Changed = Users.AuthorizedUser();
	Else
		Version.Changed = User;
	EndIf;
	Version.UniversalModificationDate = ModificationTimeUniversal;
	Version.Size                       = FileInfo.Size;
	Version.Description                 = FileInfo.BaseName;
	Version.Details                     = FileInfo.Comment;
	Version.Extension                   = CommonClientServer.ExtensionWithoutPoint(FileInfo.ExtensionWithoutPoint);
	
	FilesStorageTyoe = FilesOperationsInternal.FilesStorageTyoe();
	Version.FileStorageType = FilesStorageTyoe;
	
	If BinaryData = Undefined Then
		BinaryData = GetFromTempStorage(FileInfo.TempFileStorageAddress);
	EndIf;
	
	If FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
		
		FileStorage = New ValueStorage(BinaryData);
			
		If Version.Size = 0 Then
			FileBinaryData = FileStorage.Get();
			Version.Size = FileBinaryData.Size();
			
			FilesOperationsInternalClientServer.CheckFileSizeForImport(Version);
		EndIf;
		
		// clearing fields
		Version.PathToFile = "";
		Version.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	Else // hard drive storage
		
		If Version.Size = 0 Then
			Version.Size = BinaryData.Size();
			FilesOperationsInternalClientServer.CheckFileSizeForImport(Version);
		EndIf;
		
		FileEncrypted = False;
		If FileInfo.Encrypted <> Undefined Then
			FileEncrypted = FileInfo.Encrypted;
		EndIf;
		
		Information = FilesOperationsInternal.AddFileToVolume(BinaryData,
			ModificationTimeUniversal, FileInfo.BaseName, Version.Extension,
			"", FileEncrypted); 
		Version.Volume = Information.Volume;
		Version.PathToFile = Information.PathToFile;
		FileStorage = New ValueStorage(Undefined); // clearing the ValueStorage
		
	EndIf;
	
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	If CatalogMetadata.FullTextSearch = FullTextSearchUsing Then
		
		If FileInfo.TempTextStorageAddress <> Undefined Then
			If FilesOperationsInternal.ExtractTextFilesOnServer() Then
				Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			Else
				TextExtractionResult = FilesOperationsInternal.ExtractText(FileInfo.TempTextStorageAddress); 
				Version.TextStorage = TextExtractionResult.TextStorage;
				Version.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
			EndIf;
		Else
			Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		EndIf;
		
		If FileInfo.NewTextExtractionStatus <> Undefined Then
			Version.TextExtractionStatus = FileInfo.NewTextExtractionStatus;
		EndIf;
		
	Else
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;

	If Version.Size = 0 Then
		If FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
			FileBinaryData = FileStorage.Get();
			Version.Size = FileBinaryData.Size();
		EndIf;
	EndIf;
	
	Version.Fill(Undefined);
	Version.Write();
	
	If FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
		WriteFileToInfobase(Version.Ref, FileStorage);
	EndIf;
	
	If VersionLocked Then
		UnlockDataForEdit(Version.Ref, UUIDOfForm);
	EndIf;
	
	WriteFileVersionEncoding(Version.Ref, PreVersionEncoding);

	If HasSaveRight Then
		FileURL = GetURL(FileRef);
		UserWorkHistory.Add(FileURL);
	EndIf;
	
	Return Version.Ref;
	
EndFunction

// Updates or creates a file version and unlocks it.
//
// Parameters:
//   FileData                  - Structure - a structure with file data.
//   FileInfo               - Structure - see FilesOperationsClientServer.FIleInfo in the  FileWithVersion mode.
//   DontChangeRecordInWorkingDirectory - Boolean  - do not change record the FilesInWorkingDirectory information register.
//   FullFilePath             - String    - specified if DontChangeRecordInWorkingDirectory = False.
//   UserWorkingDirecrtory   - String    - it is specified if DontChangeFilesInWorkingDirectory = False.
//   UUIDOfForm  - UUID - a unique form ID.
//
// Returns:
//   Boolean - True if the version is created (and file is binary changed).
//
Function SaveChangesAndUnlockFile(FileData, FileInfo,
	DontChangeRecordInWorkingDirectory, FullFilePath, UserWorkingDirectory, 
	UUIDOfForm = Undefined) Export
	
	FileDataCurrent = FileData(FileData.Ref);
	If Not FileDataCurrent.CurrentUserEditsFile AND NOT FileToSynchronizeByCloudService(FileData.Ref) Then
		Raise NStr("ru = 'Файл не занят текущим пользователем'; en = 'File is not used by the current user'; pl = 'Plik nie jest zajęty przez bieżącego użytkownika';es_ES = 'Archivo no está utilizado por el usuario actual';es_CO = 'Archivo no está utilizado por el usuario actual';tr = 'Dosya geçerli kullanıcı tarafından kullanılmıyor';it = 'Il file non viene utilizzato dall''utente attuale';de = 'Die Datei wird vom aktuellen Benutzer nicht verwendet'");
	EndIf;
	
	VersionNotCreated = False;
	
	BeginTransaction();
	Try
		PreviousVersion = FileData.CurrentVersion;
		FileInfo.Encrypted = FileData.Encrypted;
		FileInfo.Encoding  = FileData.Encoding;
		
		If TypeOf(FileData.Ref) = Type("CatalogRef.Files") Then
			NewVersion = FilesOperationsInternal.UpdateFileVersion(FileData.Ref, FileInfo,, UUIDOfForm);
		Else
			NewVersion = RefreshFileObject(FileData.Ref, FileInfo,, UUIDOfForm);
		EndIf;
		
		If NewVersion <> Undefined Then
			If FileInfo.StoreVersions Then
				FilesOperationsInternal.UpdateVersionInFile(FileData.Ref, NewVersion, FileInfo.TempTextStorageAddress, UUIDOfForm);
			Else
				UpdateTextInFile(FileData.Ref, FileInfo.TempTextStorageAddress, UUIDOfForm);
			EndIf;
			FileData.CurrentVersion = NewVersion;
		EndIf;
			
		UnlockFile(FileData, UUIDOfForm);
		
		If FileInfo.Encoding <> Undefined Then
			If Not ValueIsFilled(GetFileVersionEncoding(FileData.CurrentVersion)) Then
				WriteFileVersionEncoding(FileData.CurrentVersion, FileInfo.Encoding);
			EndIf;
		EndIf;
		
		If NewVersion <> Undefined AND NOT CommonClientServer.IsWebClient() AND Not DontChangeRecordInWorkingDirectory Then
			DeleteVersionAndPutFileInformationIntoRegister(PreviousVersion, NewVersion,
				FullFilePath, UserWorkingDirectory, FileData.OwnerWorkingDirectory <> "");
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return NewVersion <> Undefined;
	
EndFunction

// Receives file data and then updates or creates a File version and unlocks it.
// It is necessary for cases, when the FileData is missing on the client (for reasons of saving client-server calls).
//
// Parameters:
//   FileRef       - CatalogRef.Files - a file where a version is updated.
//   FileInfo   - Structure - see FilesOperationsClientServer.FIleInfo in the FileWIthVersion mode. 
//   FullFilePath             - String
//   UserWorkingDirectory   - String
//   UUIDOfForm  - UUID - a unique form ID.
//
// Returns:
//   Structure - with the following properties:
//     * Success     - Boolean    - True if the version is created (and file is binary changed).
//     * FileData - Structure - a structure with file data.
//
Function SaveChangesAndUnlockFileByRef(FileRef, FileInfo, 
	FullFilePath, UserWorkingDirectory, UUIDOfForm = Undefined) Export
	
	FileData = FileData(FileRef);
	VersionCreated = SaveChangesAndUnlockFile(FileData, FileInfo, False, FullFilePath, UserWorkingDirectory,
		UUIDOfForm);
	Return New Structure("Success,FileData", VersionCreated, FileData);
	
EndFunction

// It is designed to save file changes without unlocking it.
//
// Parameters:
//   FileData                  - Structure - a structure with file data.
//   FileInfo               - Structure - see FilesOperationsClientServer.FIleInfo in the  FileWithVersion mode.
//   DontChangeRecordInWorkingDirectory - Boolean  - do not change record the FilesInWorkingDirectory information register.
//   RelativeFilePath      - String    - a relative path without a working directory path, for example,
//                                              "А1/Order.doc"; Specified if DontChangeRecordInWorkingDirectory =
//                                              False.
//   FullFilePath             - String    - a path on the client in the working directory. It is specified if
//                                              DontChangeRecordInWorkingDirectory = False.
//   InUserWorkingDirectory    - Boolean    - file is in the user working directory.
//   UUIDOfForm  - UUID - a unique form ID.
//
// Returns:
//   Boolean  - True if the version is created (and file is binary changed).
//
Function SaveFileChanges(FileRef, FileInfo, 
	DontChangeRecordInWorkingDirectory, RelativeFilePath, FullFilePath, InOwnerWorkingDirectory,
	UUIDOfForm = Undefined) Export
	
	FileDataCurrent = FileData(FileRef);
	If Not FileDataCurrent.CurrentUserEditsFile AND NOT FileToSynchronizeByCloudService(FileRef) Then
		Raise NStr("ru = 'Файл не занят текущим пользователем'; en = 'File is not used by the current user'; pl = 'Plik nie jest zajęty przez bieżącego użytkownika';es_ES = 'Archivo no está utilizado por el usuario actual';es_CO = 'Archivo no está utilizado por el usuario actual';tr = 'Dosya geçerli kullanıcı tarafından kullanılmıyor';it = 'Il file non viene utilizzato dall''utente attuale';de = 'Die Datei wird vom aktuellen Benutzer nicht verwendet'");
	EndIf;
	
	VersionNotCreated = False;
	CurrentVersion = FileDataCurrent.CurrentVersion;
	
	BeginTransaction();
	Try
		
		OldVersion = ?(FileInfo.StoreVersions, FileRef.CurrentVersion, FileRef);
		FileInfo.Encrypted = FileDataCurrent.Encrypted;
		
		If TypeOf(FileRef.Ref) = Type("CatalogRef.Files") Then
			NewVersion = FilesOperationsInternal.UpdateFileVersion(FileRef.Ref, FileInfo,, UUIDOfForm, FileInfo.NewVersionAuthor);
		Else
			NewVersion = RefreshFileObject(FileRef.Ref, FileInfo,, UUIDOfForm);
		EndIf;
		
		If NewVersion <> Undefined Then
			CurrentVersion = NewVersion;
			If FileInfo.StoreVersions Then
				FilesOperationsInternal.UpdateVersionInFile(FileRef, NewVersion, FileInfo.TempTextStorageAddress, UUIDOfForm);
				
				If NOT CommonClientServer.IsWebClient() AND Not DontChangeRecordInWorkingDirectory Then
					DeleteFromRegister(OldVersion);
					WriteFullFileNameToRegister(NewVersion, RelativeFilePath, False, InOwnerWorkingDirectory);
				EndIf;
				
			Else
				UpdateTextInFile(FileRef, FileInfo.TempTextStorageAddress, UUIDOfForm);
			EndIf;
			
		EndIf;
		
		If FileInfo.Encoding <> Undefined Then
			If Not ValueIsFilled(GetFileVersionEncoding(CurrentVersion)) Then
				WriteFileVersionEncoding(CurrentVersion, FileInfo.Encoding);
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return NewVersion <> Undefined;
	
EndFunction

// Updates a text portion from a file in the file card.
//
// Parameters:
// FileRef - CatalogRef.Files - a file, in which a version is created.
// TextTempStorageAddress - String - contains the address in the temporary storage, where the binary 
//                                           data with the text file, or the ValueStorage that 
//                                           directly contains the binary data with the text file are located.
//  UUID - a form UUID.
//
Procedure UpdateTextInFile(FileRef,
                              Val TempTextStorageAddress,
                              UUID = Undefined)
	
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	
	BeginTransaction();
	Try
		
		CatalogMetadata = Metadata.FindByType(TypeOf(FileRef));
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(CatalogMetadata.FullName());
		DataLockItem.SetValue("Ref", FileRef);
		DataLock.Lock(); 
		
		FileObject = FileRef.GetObject();
		LockDataForEdit(FileObject.Ref, , UUID);
		
		If CatalogMetadata.FullTextSearch = FullTextSearchUsing Then
			TextExtractionResult = FilesOperationsInternal.ExtractText(TempTextStorageAddress);
			FileObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
			FileObject.TextStorage = TextExtractionResult.TextStorage;
		Else
			FileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			FileObject.TextStorage = New ValueStorage("");
		EndIf;
		
		FileObject.Write();
		UnlockDataForEdit(FileObject.Ref, UUID);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Creates a new file similarly to the specified one and returns a reference to it.
// Parameters:
//  SourceFile  - CatalogRef.Files - the existing file.
//  NewFileOwner - AnyRef - a file owner.
//
// Returns:
//   CatalogRef.Files - a new file.
//
Function CopyFileSSL(SourceFile, NewFileOwner)
	
	If SourceFile = Undefined Or SourceFile.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	ObjectManager = Common.ObjectManagerByRef(SourceFile);
	NewFile = SourceFile.Copy();
	FileCopyRef = ObjectManager.GetRef();
	NewFile.SetNewObjectRef(FileCopyRef);
	NewFile.FileOwner = NewFileOwner.Ref;
	NewFile.BeingEditedBy = Catalogs.Users.EmptyRef();
	
	NewFile.TextStorage = New ValueStorage(SourceFile.TextStorage.Get());
	NewFile.StorageFile  = New ValueStorage(SourceFile.StorageFile.Get());
	
	BinaryData = FilesOperations.FileBinaryData(SourceFile);
	BinaryDataInValueStorage = New ValueStorage(BinaryData);
	NewFile.FileStorageType = FilesOperationsInternal.FilesStorageTyoe();
	
	If FilesOperationsInternal.FilesStorageTyoe() = Enums.FileStorageTypes.InInfobase Then
		
		WriteFileToInfobase(FileCopyRef, BinaryDataInValueStorage);
		
	Else
		// Add the file to a volume with sufficient free space.
		FileInfo = FilesOperationsInternal.AddFileToVolume(BinaryData, NewFile.UniversalModificationDate,
		NewFile.Description, NewFile.Extension);
		NewFile.PathToFile = FileInfo.PathToFile;
		NewFile.Volume = FileInfo.Volume;
	EndIf;
	NewFile.Write();
	
	If NewFile.StoreVersions Then
		
		FileInfo = FilesOperationsClientServer.FileInfo("FileWithVersion");
		FileInfo.BaseName = NewFile.Description;
		FileInfo.Size = NewFile.CurrentVersion.Size;
		FileInfo.ExtensionWithoutPoint = NewFile.CurrentVersion.Extension;
		FileInfo.TempFileStorageAddress = BinaryDataInValueStorage;
		FileInfo.TempTextStorageAddress = NewFile.CurrentVersion.TextStorage;
		FileInfo.RefToVersionSource = NewFile.CurrentVersion;
		FileInfo.Encrypted = NewFile.Encrypted;
		Version = FilesOperationsInternal.CreateVersion(NewFile.Ref, FileInfo);
		FilesOperationsInternal.UpdateVersionInFile(NewFile.Ref, Version, NewFile.CurrentVersion.TextStorage);
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		DigitalSignatureAvailable = ModuleDigitalSignatureInternal.DigitalSignatureAvailable(TypeOf(SourceFile));
		If DigitalSignatureAvailable Then
			
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			
			If SourceFile.SignedWithDS Then
				
				FileObject = NewFile.GetObject();
				FileObject.SignedWithDS = True;
				FileObject.Write();

				DigitalSignaturesOfInitialFile = ModuleDigitalSignature.SetSignatures(SourceFile);
				For Each DS In DigitalSignaturesOfInitialFile Do
					RecordManager = InformationRegisters["DigitalSignatures"].CreateRecordManager();
					RecordManager.SignedObject = NewFile;
					FillPropertyValues(RecordManager, DS);
					RecordManager.Write(True);
				EndDo;
				
			EndIf;
			
			If SourceFile.Encrypted Then
				
				FileObject = NewFile.GetObject();
				FileObject.Encrypted = True;
				
				DigitalSignaturesOfInitialFile = ModuleDigitalSignature.EncryptionCertificates(SourceFile);
				For Each Certificate In DigitalSignaturesOfInitialFile Do
					RecordManager = InformationRegisters["EncryptionCertificates"].CreateRecordManager();
					RecordManager.EncryptedObject = NewFile;
					FillPropertyValues(RecordManager, Certificate);
					RecordManager.Write(True);
				EndDo;
				// To write a previously signed object.
				FileObject.AdditionalProperties.Insert("WriteSignedObject", True);
				FileObject.Write();
				
			EndIf;
		EndIf;
	EndIf;
	
	FilesOperationsOverridable.FillFileAtributesFromSourceFile(NewFile, SourceFile);
	
	Return NewFile;
	
EndFunction

// Moves the File into other folder.
//
// Parameters:
//  FileData  - a structure with file data.
//  Folder - CatalogRef.FilesFolders - a reference to the folder, to which you need ot move the file.
//
Procedure MoveFileSSL(FileData, Folder) 
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileData.Ref)).FullName());
		DataLockItem.SetValue("Ref", FileData.Ref);
		DataLock.Lock();	
		FileObject = FileData.Ref.GetObject();
		FileObject.Lock();
		FileObject.FileOwner = Folder;
		FileObject.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Moves Files into other folder.
//
// Parameters:
//  ObjectsRef - Array - an array of file references.
//  Folder - CatalogRef.FilesFolders - a reference to the folder, to which you need ot move the files.
//
Function MoveFiles(ObjectsRef, Folder) Export 
	
	FilesData = New Array;
	
	For Each FileRef In ObjectsRef Do
		MoveFileSSL(FileRef, Folder);
		FileData = FileData(FileRef);
		FilesData.Add(FileData);
	EndDo;
	
	Return FilesData;
	
EndFunction

// Receives EditedByCurrentUser in the privileged mode.
// Parameters:
//  VersionRef  - CatalogRef.FilesVersions - a file version.
//
// Returns:
//   Boolean - True if a file is edited by the current user.
//
Function GetEditedByCurrentUser(VersionRef) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.BeingEditedBy AS BeingEditedBy
	|FROM
	|	Catalog.Files AS Files
	|		INNER JOIN Catalog.FilesVersions AS FilesVersions
	|		ON (TRUE)
	|WHERE
	|	FilesVersions.Ref = &Version
	|	AND Files.Ref = FilesVersions.Owner";
	
	Query.Parameters.Insert("Version", VersionRef);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		EditedByCurrentUser = (Selection.BeingEditedBy = Users.CurrentUser());
		Return EditedByCurrentUser;
	EndIf;
	
	Return False;
	
EndFunction

// Gets file data and performs a checkout. To reduce the number of client/server calls, GetFileData 
// and LockFile are combined into a single function.
// Parameters:
//  FileRef  - CatalogRef.Files - a file.
//  FileData  - Structure - a structure with file data.
//  ErrorString - a string, where the error  reason is returned (for example, "File is locked by 
//                 other user").
//  UUID - a form UUID.
//
// Returns:
//   Boolean  - shows whether the operation is performed successfully.
//
Function GetFileDataAndLockFile(FileRef, FileData, ErrorRow, UUID = Undefined) Export

	FileData = FileData(FileRef);

	ErrorRow = "";
	If NOT FilesOperationsClientServer.WhetherPossibleLockFile(FileData, ErrorRow) Then
		Return False;
	EndIf;	
	
	If Not ValueIsFilled(FileData.BeingEditedBy) Then
		
		ErrorRow = "";
		If Not LockFile(FileData, ErrorRow, UUID) Then 
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Receives FileData for files and places it into FileDataArray.
//  FilesArray - an array of file references.
//  FileDataArray - an array of structures with file data.
//
Procedure GetDataForFilesArray(Val FilesArray, FileDataArray) Export
	
	For Each File In FilesArray Do
		FileData = FileData(File);
		FileDataArray.Add(FileData);
	EndDo;
	
EndProcedure

// Gets file data for opening and performs a checkout. To reduce the number of client/server calls, 
// FileDataToOpen and LockFile are combined into a single function.
// Parameters:
//  FileRef  - CatalogRef.Files - a file.
//  FileData  - Structure - a structure with file data.
//  ErrorString - a string, where the error  reason is returned (for example, "File is locked by 
//                 other user").
//  UUID - a form UUID.
//  OwnerWorkingDirectory - String - a working directory of the file owner.
//
// Returns:
//   Boolean  - shows whether the operation is performed successfully.
//
Function GetFileDataToOpenAndLockFile(FileRef,
	FileData,
	ErrorRow,
	UUID = Undefined,
	OwnerWorkingDirectory = Undefined,
	VersionRef = Undefined) Export

	FileData = FileDataToOpen(FileRef, VersionRef, UUID, OwnerWorkingDirectory);

	ErrorRow = "";
	If NOT FilesOperationsClientServer.WhetherPossibleLockFile(FileData, ErrorRow) Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(FileData.BeingEditedBy) Then
		
		ErrorRow = "";
		If Not LockFile(FileData, ErrorRow, UUID) Then 
			Return False;
		EndIf;
	EndIf;
	
	Return True;
EndFunction

// Executes PutInTempStorage (if the file is stored on the hard drive) and returns a URL of the file in the storage.
// Parameters:
// VersionRef - a file version.
//  FormID - a form UUID.
//
// Returns:
//   String  - URL in the temporary storage.
//
Function GetURLToOpen(VersionRef, FormID = Undefined) Export
	
	HasRightsToObject = Common.ObjectAttributesValues(VersionRef, "Ref", True);
	
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;
	
	Return PutToTempStorage(FilesOperations.FileBinaryData(VersionRef));
	
EndFunction

// Executes FileData and calculates OwnerWorkingDirectory.
//
// Parameters:
//  FileOrVersionRef     - CatalogRef.Files, CatalogRef.FilesVersions - a file or a file version.
//  UserWorkingDirectory - String - the user working directory is returned in it.
//
// Returns:
//   Structure - a structure with file data.
//
Function FileDataAndWorkingDirectory(FileOrVersionRef, OwnerWorkingDirectory = Undefined) Export
	
	FileData = FileData(FileOrVersionRef);
	FileMetadata = Metadata.FindByType(TypeOf(FileOrVersionRef));
	AbilityToStoreVersions = False;
	If Common.HasObjectAttribute("FileOwner", FileMetadata) Then 
		FileRef = FileOrVersionRef;
		VersionRef = Undefined;
		AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", FileMetadata);
	Else
		FileRef = Undefined;
		VersionRef = FileOrVersionRef;
	EndIf;
	
	If OwnerWorkingDirectory = Undefined Then
		OwnerWorkingDirectory = FolderWorkingDirectory(FileData.Owner);
	EndIf;
	FileData.Insert("OwnerWorkingDirectory", OwnerWorkingDirectory);
	
	If FileData.OwnerWorkingDirectory <> "" Then
		
		FullFileNameInWorkingDirectory = "";
		DirectoryName = ""; // Path to a local cache is not used here.
		InWorkingDirectoryForRead = True; // not used
		InOwnerWorkingDirectory = True;
		
		If VersionRef <> Undefined Then
			FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(VersionRef, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		ElsIf AbilityToStoreVersions AND ValueIsFilled(FileRef.CurrentVersion) Then
			FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(FileRef.CurrentVersion, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		Else
			FullFileNameInWorkingDirectory = GetFullFileNameFromRegister(FileRef, DirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
		EndIf;
		
		FileData.Insert("FullFileNameInWorkingDirectory", FullFileNameInWorkingDirectory);
	EndIf;
	
	Return FileData;
EndFunction

// Makes GetFileData and calculates the number of file versions.
// Parameters:
//  FileRef  - CatalogRef.Files - a file.
//
// Returns:
//   Structure - a structure with file data.
//
Function GetFileDataAndVersionsCount(FileRef) Export
	
	FileData = FileData(FileRef);
	VersionsCount = GetVersionsCount(FileRef);
	FileData.Insert("VersionsCount", VersionsCount);
	
	Return FileData;
	
EndFunction

// Generates an error text for writing to the event log.
// Parameters:
//  FunctionErrorInformation  - ErrorInformation
//  FileRef  - CatalogRef.Files - a file.
//
// Returns:
//   String - an error description
//
Function GenerateErrorTextOfGetFileFromVolumeForAdministrator(FunctionErrorInfornation, FileRef)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Ссылка на файл: ""%1"".
		           |""%2"".'; 
		           |en = 'Link to file: ""%1"".
		           |""%2"".'; 
		           |pl = 'Odnośnik do pliku: ""%1"".
		           |""%2"".';
		           |es_ES = 'Referencia al archivo: ""%1"".
		           |""%2"".';
		           |es_CO = 'Referencia al archivo: ""%1"".
		           |""%2"".';
		           |tr = 'Dosya referansı: ""%1"". 
		           |""%2"".';
		           |it = 'Collegamento al file: ""%1"".
		           |""%2""';
		           |de = 'Ref auf die Datei: ""%1"".
		           |""%2"".'"),
		GetURL(FileRef),
		DetailErrorDescription(FunctionErrorInfornation));
	
EndFunction

// Unlocking File with receiving data.
// Parameters:
//  FileRef  - CatalogRef.Files - a file.
//  FileData  - a structure with file data.
//  UUID - a form UUID.
//
Procedure GetFileDataAndUnlockFile(FileRef, FileData, UUID = Undefined) Export
	
	FileData = FileData(FileRef);
	UnlockFile(FileData, UUID);
	
EndProcedure

// To save file changes without unlocking it.
//
// Parameters:
//   FileRef                   - Structure - a structure with file data.
//   FileInfo               - Structure - see FilesOperationsClientServer.FIleInfo in the  FileWithVersion mode.
//   RelativeFilePath      - String    - a relative path without a working directory path, for example,
//                                              "А1/Order.doc"; Specified if DontChangeRecordInWorkingDirectory =
//                                              False.
//   FullFilePath             - String    - a path on the client in the working directory. It is specified if
//                                              DontChangeRecordInWorkingDirectory = False.
//   InUserWorkingDirectory    - Boolean    - file is in the user working directory.
//   UUIDOfForm  - UUID - a unique form ID.
//
// Returns:
//   Structure - with the following properties:
//     * Success     - Boolean    - True if the version is created (and file is binary changed).
//     * FileData - Structure - a structure with file data.
//
Function GetFileDataAndSaveFileChanges(FileRef, FileInfo, 
	RelativeFilePath, FullFilePath, InOwnerWorkingDirectory,
	UUIDOfForm = Undefined) Export
	
	FileData = FileData(FileRef);
	If Not FileData.CurrentUserEditsFile Then
		Raise NStr("ru = 'Файл не занят текущим пользователем'; en = 'File is not used by the current user'; pl = 'Plik nie jest zajęty przez bieżącego użytkownika';es_ES = 'Archivo no está utilizado por el usuario actual';es_CO = 'Archivo no está utilizado por el usuario actual';tr = 'Dosya geçerli kullanıcı tarafından kullanılmıyor';it = 'Il file non viene utilizzato dall''utente attuale';de = 'Die Datei wird vom aktuellen Benutzer nicht verwendet'");
	EndIf;
	
	VersionCreated = SaveFileChanges(FileRef, FileInfo, 
		False, RelativeFilePath, FullFilePath, InOwnerWorkingDirectory,
		UUIDOfForm);
	Return New Structure("Success,FileData", VersionCreated, FileData);	
	
EndFunction

// Receives the synthetic working directory of the folder on the hard drive (it can come from the parent folder).
// Parameters:
//  FolderRef  - CatalogRef.FilesFolders - a file owner.
//
// Returns:
//   String  - a working directory.
//
Function FolderWorkingDirectory(FolderRef) Export
	
	If Not IsDirectoryFiles(FolderRef) Then
		Return ""
	EndIf;
	
	SetPrivilegedMode(True);
	
	WorkingDirectory = "";
	
	// Prepare a filter structure by dimensions.
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Folder", FolderRef);
	FilterStructure.Insert("User", Users.CurrentUser());
	
	// Receive structure with the data of record resources.
	ResourcesStructure = InformationRegisters.FileWorkingDirectories.Get(FilterStructure);
	
	// Getting a path from the register
	WorkingDirectory = ResourcesStructure.Path;
	
	If NOT IsBlankString(WorkingDirectory) Then
		// Adding a slash mark at the end if it is not there.
		WorkingDirectory = CommonClientServer.AddLastPathSeparator(WorkingDirectory);
	EndIf;
	
	Return WorkingDirectory;
	
EndFunction

// Saves a folder working directory to the information register.
// Parameters:
//  FolderRef  - CatalogRef.FilesFolders - a file owner.
//  OwnerWorkingDirectory - String - a working directory of the folder owner.
//
Procedure SaveFolderWorkingDirectory(FolderRef, FolderWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.FileWorkingDirectories.CreateRecordSet();
	
	RecordSet.Filter.Folder.Set(FolderRef);
	RecordSet.Filter.User.Set(Users.CurrentUser());
	
	NewRecord = RecordSet.Add();
	NewRecord.Folder = FolderRef;
	NewRecord.User = Users.CurrentUser();
	NewRecord.Path = FolderWorkingDirectory;
	
	RecordSet.Write();
	
EndProcedure

// Saves a folder working directory to the information register and replaces paths in the 
// FilesInWorkingDirectory information register.
//
// Parameters:
//  FolderRef  - CatalogRef.FilesFolders - a file owner.
//  FolderWorkingDirectory - String - a folder working directory.
//  DirectoryNamePreviousValue - a previous value of the working directory.
//
Procedure SaveFolderWorkingDirectoryAndReplacePathsInRegister(FolderRef,
                                                        FolderWorkingDirectory,
                                                        DirectoryNamePreviousValue) Export
	
	SaveFolderWorkingDirectory(FolderRef, FolderWorkingDirectory);
	
	// Changing paths in the FilesInWorkingDirectory information register below.
	SetPrivilegedMode(True);
	
	ListForChange = New Array;
	CurrentUser = Users.CurrentUser();
	
	// Finding a record in the information register for each record and taking the Version and EditedBy fields from there.
	QuieryToRegister = New Query;
	QuieryToRegister.SetParameter("User", CurrentUser);
	QuieryToRegister.SetParameter("Path", DirectoryNamePreviousValue + "%");
	QuieryToRegister.Text =
	"SELECT
	|	FilesInWorkingDirectory.File AS File,
	|	FilesInWorkingDirectory.Path AS Path,
	|	FilesInWorkingDirectory.Size AS Size,
	|	FilesInWorkingDirectory.PutFileInWorkingDirectoryDate AS PutFileInWorkingDirectoryDate,
	|	FilesInWorkingDirectory.ForReading AS ForReading
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|WHERE
	|	FilesInWorkingDirectory.User = &User
	|	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = TRUE
	|	AND FilesInWorkingDirectory.Path LIKE &Path";
	
	QueryResult = QuieryToRegister.Execute(); 
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		NewPath = Selection.Path;
		NewPath = StrReplace(NewPath, DirectoryNamePreviousValue, FolderWorkingDirectory);
		
		RecordStructure = New Structure;
		RecordStructure.Insert("File",                         Selection.File);
		RecordStructure.Insert("Path",                         NewPath);
		RecordStructure.Insert("Size",                       Selection.Size);
		RecordStructure.Insert("PutFileInWorkingDirectoryDate", Selection.PutFileInWorkingDirectoryDate);
		RecordStructure.Insert("ForReading",                     Selection.ForReading);
		
		ListForChange.Add(RecordStructure);
		
	EndDo;
	
	For Each RecordStructure In ListForChange Do
		
		InOwnerWorkingDirectory = True;
		WriteRecordStructureToRegister(
			RecordStructure.File,
			RecordStructure.Path,
			RecordStructure.Size,
			RecordStructure.PutFileInWorkingDirectoryDate,
			RecordStructure.ForReading,
			InOwnerWorkingDirectory);
		
	EndDo;
	
EndProcedure

// After changing the path, write it again with the same values of other fields.
// Parameters:
//  Version - CatalogRef.FilesVersions - a version.
//  Path - String - a relative path inside the working directory.
//  Size  - file size in bytes.
//  PutFileInWorkingDirectoryDate - a date of putting the file to the working directory.
//  ForRead - Boolean - a file is placed for reading.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Procedure WriteRecordStructureToRegister(File,
                                          Path,
                                          Size,
                                          PutFileInWorkingDirectoryDate,
                                          ForReading,
                                          InOwnerWorkingDirectory)
	
	HasRightsToObject = Common.ObjectAttributesValues(File, "Ref", True);
	
	If HasRightsToObject = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Create a record set.
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.File.Set(File);
	RecordSet.Filter.User.Set(Users.CurrentUser());

	NewRecord = RecordSet.Add();
	NewRecord.File = File;
	NewRecord.Path = Path;
	NewRecord.Size = Size;
	NewRecord.PutFileInWorkingDirectoryDate = PutFileInWorkingDirectoryDate;
	NewRecord.User = Users.CurrentUser();

	NewRecord.ForReading = ForReading;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;
	
	RecordSet.Write();
	
EndProcedure

// Clears a folder working directory at the information register.
// Parameters:
//  FolderRef  - CatalogRef.FilesFolders - a file owner.
//
Procedure CleanUpWorkingDirectory(FolderRef) Export
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.FileWorkingDirectories.CreateRecordSet();
	
	RecordSet.Filter.Folder.Set(FolderRef);
	RecordSet.Filter.User.Set(Users.CurrentUser());
	
	// Do not add records into the set to clear everything.
	RecordSet.Write();
	
	// Clearing working directories for child folders.
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileFolders.Ref AS Ref
	|FROM
	|	Catalog.FileFolders AS FileFolders
	|WHERE
	|	FileFolders.Parent = &Ref";
	
	Query.SetParameter("Ref", FolderRef);
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		CleanUpWorkingDirectory(Selection.Ref);
	EndDo;
	
EndProcedure

// Finds a record in the FilesInWorkingDirectory information register by a path on the hard drive.
//
// Parameters:
//  FileName - a name of the file with a relative path (without a path to the working directory).
//
// Returns:
//  Structure with the following properties:
//    Version            - CatalogRef.FilesVersions - a found version.
//    PutDate     - a date of putting the file to the working directory.
//    File          - Ref - file owner.
//    VersionNumber       - Number - a version number.
//    InReadRegister - Boolean - the ForRead resource value.
//    InFileCodeRegister - Number. Here the file code is placed.
//    InFolderRegister    - CatalogRef.FilesFolders - a file folder.
//
Function FindInRegisterByPath(FileName) Export
	
	SetPrivilegedMode(True);
	
	FoundProperties = New Structure;
	FoundProperties.Insert("FileIsInRegister", False);
	FoundProperties.Insert("File", Catalogs.FilesVersions.GetRef());
	FoundProperties.Insert("PutFileDate");
	FoundProperties.Insert("Owner");
	FoundProperties.Insert("VersionNumber");
	FoundProperties.Insert("InRegisterForReading");
	FoundProperties.Insert("FileCodeInRegister");
	FoundProperties.Insert("InRegisterFolder");
	
	// Finding a record in the information register for each one by path and getting the field from there.
	// Version, Size, and PutFileInWorkingDirectoryDate.
	QuieryToRegister = New Query;
	QuieryToRegister.SetParameter("FileName", FileName);
	QuieryToRegister.SetParameter("User", Users.CurrentUser());
	QuieryToRegister.Text =
	"SELECT
	|	FilesInWorkingDirectory.File AS File,
	|	FilesInWorkingDirectory.PutFileInWorkingDirectoryDate AS PutFileDate,
	|	FilesInWorkingDirectory.ForReading AS InRegisterForReading,
	|	CASE
	|		WHEN VALUETYPE(FilesInWorkingDirectory.File) = TYPE(Catalog.FilesVersions)
	|			THEN FilesInWorkingDirectory.File.Owner
	|		ELSE FilesInWorkingDirectory.File
	|	END AS Owner,
	|	CASE
	|		WHEN VALUETYPE(FilesInWorkingDirectory.File) = TYPE(Catalog.FilesVersions)
	|			THEN FilesInWorkingDirectory.File.VersionNumber
	|		ELSE 0
	|	END AS VersionNumber,
	|	CASE
	|		WHEN VALUETYPE(FilesInWorkingDirectory.File) = TYPE(Catalog.FilesVersions)
	|			THEN FilesInWorkingDirectory.File.Owner.FileOwner
	|		ELSE FilesInWorkingDirectory.File.FileOwner
	|	END AS InRegisterFolder
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|WHERE
	|	FilesInWorkingDirectory.Path = &FileName
	|	AND FilesInWorkingDirectory.User = &User";
	
	QueryResult = QuieryToRegister.Execute(); 
	
	If NOT QueryResult.IsEmpty() Then
		FoundProperties.FileIsInRegister = True;
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(FoundProperties, Selection);
	EndIf;
	
	Return FoundProperties;
	
EndFunction

// Finds information on FileVersions in the FilesInWorkingDirectory information register (a path to 
// the version file in a working directory and its status to read or to edit).
// Parameters:
//  Version - CatalogRef.FilesVersions - a version.
//  DirectoryName - a working directory path.
//  InWorkingdirectoryForRead - Boolean - a file is placed for reading.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Function GetFullFileNameFromRegister(Version,
                                         DirectoryName,
                                         InWorkingDirectoryForRead,
                                         InOwnerWorkingDirectory) Export
	
	HasRightsToObject = Common.ObjectAttributesValues(Version, "Ref", True);
	
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	FullFileName = "";
	
	// Prepare a filter structure by dimensions.
	FilterStructure = New Structure;
	FilterStructure.Insert("File", Version.Ref);

	FilterStructure.Insert("User", Users.AuthorizedUser());
	
	// Receive structure with the data of record resources.
	ResourcesStructure = InformationRegisters.FilesInWorkingDirectory.Get(FilterStructure);
	
	// Getting a path from the register
	FullFileName = ResourcesStructure.Path;
	InWorkingDirectoryForRead = ResourcesStructure.ForReading;
	InOwnerWorkingDirectory = ResourcesStructure.InOwnerWorkingDirectory;
	If FullFileName <> "" AND InOwnerWorkingDirectory = False Then
		FullFileName = DirectoryName + FullFileName;
	EndIf;
	
	Return FullFileName;
	
EndFunction

// Writing information about a file path to the FilesInWorkingDirectory information register.
// Parameters:
//  CurrentVersion - CatalogRef.FilesVersions - a version.
//  FullFileName - a name with its path in the working directory.
//  ForRead - Boolean - a file is placed for reading.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Procedure WriteFullFileNameToRegister(CurrentVersion,
                                         FullFileName,
                                         ForReading,
                                         InOwnerWorkingDirectory) Export
	
	SetPrivilegedMode(True);
	
	// Create a record set.
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.File.Set(CurrentVersion.Ref);
	RecordSet.Filter.User.Set(Users.CurrentUser());

	NewRecord = RecordSet.Add();
	NewRecord.File = CurrentVersion.Ref;
	NewRecord.Path = FullFileName;
	NewRecord.Size = CurrentVersion.Size;
	NewRecord.PutFileInWorkingDirectoryDate = CurrentSessionDate();
	NewRecord.User = Users.CurrentUser();

	NewRecord.ForReading = ForReading;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;
	
	RecordSet.Write();
	
EndProcedure

// Delete a record about the specified version of the file from the FilesInWorkingDirectory information register.
// Parameters:
//  Version - CatalogRef.FilesVersions - a version.
//
Procedure DeleteFromRegister(File) Export
	
	HasRightsToObject = Common.ObjectAttributesValues(File, "Ref", True);
	If HasRightsToObject = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.File.Set(File);
	RecordSet.Filter.User.Set(Users.AuthorizedUser());
	
	RecordSet.Write();
	
EndProcedure

// Delete all records from the FilesInWorkingDirectory information register except for the records 
// about files locked by the current user.
//
Procedure ClearAllExceptLocked() Export
	
	// Filtering all in the information register. Looping through and finding those ones that are not 
	//  locked by the current user and deleting all, considering that they have already been deleted on the hard drive.
	
	SetPrivilegedMode(True);
	
	ListDelete = New Array;
	CurrentUser = Users.CurrentUser();
	
	// Finding a record in the information register for each record and taking the Version and EditedBy fields from there.
	QuieryToRegister = New Query;
	QuieryToRegister.SetParameter("User", CurrentUser);
	QuieryToRegister.Text =
	"SELECT
	|	FilesInWorkingDirectory.File AS File,
	|	FilesInfo.BeingEditedBy AS BeingEditedBy
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|		LEFT JOIN InformationRegister.FilesInfo AS FilesInfo
	|		ON FilesInWorkingDirectory.File = FilesInfo.File
	|WHERE
	|	FilesInWorkingDirectory.User = &User
	|	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = FALSE";
	
	QueryResult = QuieryToRegister.Execute(); 
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
				
			If Selection.BeingEditedBy <> CurrentUser Then
				ListDelete.Add(Selection.File);
			EndIf;
			
		EndDo;
	EndIf;
	
	SetPrivilegedMode(True);
	For Each File In ListDelete Do
		// Create a record set.
		RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
		
		RecordSet.Filter.File.Set(File);
		RecordSet.Filter.User.Set(CurrentUser);
		
		RecordSet.Write();
	EndDo;
	
EndProcedure

// Delete a record about the previous version in the FilesInWorkingDirectory information register and write the new one.
// Parameters:
//  OldVersion - CatalogRef.FilesVersions - an old version.
//  NewVersion - CatalogRef.FilesVersions - a new version.
//  FullFileName - a name with its path in the working directory.
//  DirectoryName - a working directory path.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Procedure DeleteVersionAndPutFileInformationIntoRegister(OldVersion,
                                                       NewVersion,
                                                       FullFileName,
                                                       DirectoryName,
                                                       InOwnerWorkingDirectory)
	
	DeleteFromRegister(OldVersion);
	ForReading = True;
	PutFileInformationInRegister(NewVersion, FullFileName, DirectoryName, ForReading, 0, InOwnerWorkingDirectory);
	
EndProcedure

// Writing information about a file path to the FilesInWorkingDirectory information register.
//  Version - CatalogRef.FilesVersions - a version.
//  FullPath - String - a full file path.
//  DirectoryName - a working directory path.
//  ForRead - Boolean - a file is placed for reading.
//  FileSize  - file size in bytes.
//  InOwnerWorkingDirectory - Boolean - a file is in owner working directory (not in the main working directory).
//
Procedure PutFileInformationInRegister(Version,
                                         FullPath,
                                         DirectoryName,
                                         ForReading,
                                         FileSize,
                                         InOwnerWorkingDirectory) Export
	FullFileName = FullPath;
	
	If InOwnerWorkingDirectory = False Then
		If StrFind(FullPath, DirectoryName) = 1 Then
			FullFileName = Mid(FullPath, StrLen(DirectoryName) + 1);
		EndIf;
	EndIf;
	
	HasRightsToObject = Common.ObjectAttributesValues(Version, "Ref", True);
	
	If HasRightsToObject = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Create a record set.
	RecordSet = InformationRegisters.FilesInWorkingDirectory.CreateRecordSet();
	
	RecordSet.Filter.File.Set(Version.Ref);
	RecordSet.Filter.User.Set(Users.AuthorizedUser());

	NewRecord = RecordSet.Add();
	NewRecord.File = Version.Ref;
	NewRecord.Path = FullFileName;

	If FileSize <> 0 Then
		NewRecord.Size = FileSize;
	Else
		NewRecord.Size = Version.Size;
	EndIf;

	NewRecord.PutFileInWorkingDirectoryDate = CurrentSessionDate();
	NewRecord.User = Users.AuthorizedUser();
	NewRecord.ForReading = ForReading;
	NewRecord.InOwnerWorkingDirectory = InOwnerWorkingDirectory;

	RecordSet.Write();
	
EndProcedure

// Generates a report for files with errors.
//
// Parameters:
//   ArrayOfFilesNamesWithErrors - a string array of paths to files.
//
// Returns:
//   SpreadsheetDocument with a report.
//
Function FilesImportGenerateReport(ArrayOfFilesNamesWithErrors) Export
	
	Document = New SpreadsheetDocument;
	Template = Catalogs.Files.GetTemplate("ReportTemplate");
	
	AreaHeader = Template.GetArea("Title");
	AreaHeader.Parameters.Details = NStr("ru = 'Не удалось загрузить следующие файлы:'; en = 'Cannot import the following files:'; pl = 'Nie można zaimportować następujących plików:';es_ES = 'No se puede importar los siguientes archivos:';es_CO = 'No se puede importar los siguientes archivos:';tr = 'Aşağıdaki dosyalar içe aktarılamıyor:';it = 'Non è possibile importare i seguenti file:';de = 'Folgende Dateien können nicht importiert werden:'");
	Document.Put(AreaHeader);
	
	AreaRow = Template.GetArea("Row");

	For Each Selection In ArrayOfFilesNamesWithErrors Do
		AreaRow.Parameters.Name = Selection.FileName;
		AreaRow.Parameters.Error = Selection.Error;
		Document.Put(AreaRow);
	EndDo;
	
	Report = New SpreadsheetDocument;
	Report.Put(Document);

	Return Report;
	
EndFunction

// Sorts an array of structures by the Date field on the server, since there is no ValueTable on the thin client.
//
// Parameters:
// StructuresArray - an array of file description structures.
//
Procedure SortStructuresArray(StructuresArray) Export
	
	FilesTable = New ValueTable;
	FilesTable.Columns.Add("Path");
	FilesTable.Columns.Add("Version");
	FilesTable.Columns.Add("Size");
	
	FilesTable.Columns.Add("PutFileInWorkingDirectoryDate", New TypeDescription("Date"));
	
	For Each Row In StructuresArray Do
		NewRow = FilesTable.Add();
		FillPropertyValues(NewRow, Row, "Path, Size, Version, PutFileInWorkingDirectoryDate");
	EndDo;
	
	// Sorting by date means that in the beginning there will be items, placed in the working directory long ago.
	FilesTable.Sort("PutFileInWorkingDirectoryDate Asc");  
	
	StructuresArrayReturn = New Array;
	
	For Each Row In FilesTable Do
		Record = New Structure;
		Record.Insert("Path", Row.Path);
		Record.Insert("Size", Row.Size);
		Record.Insert("Version", Row.Version);
		Record.Insert("PutFileInWorkingDirectoryDate", Row.PutFileInWorkingDirectoryDate);
		StructuresArrayReturn.Add(Record);
	EndDo;
	
	StructuresArray = StructuresArrayReturn;
	
EndProcedure

// Returns the setting Ask the editing mode when opening file.
// Returns:
//   Boolean -  ask the editing mode when opening file.
//
Function PromptForEditModeOnOpenFile()
	PromptForEditModeOnOpenFile = 
		Common.CommonSettingsStorageLoad("OpenFileSettings", "PromptForEditModeOnOpenFile");
	If PromptForEditModeOnOpenFile = Undefined Then
		PromptForEditModeOnOpenFile = True;
		Common.CommonSettingsStorageSave("OpenFileSettings", "PromptForEditModeOnOpenFile", PromptForEditModeOnOpenFile);
	EndIf;
	
	Return PromptForEditModeOnOpenFile;
EndFunction

// Calculating ActionByDoubleClick. If it is for the first time, setting the correct value.
//
// Returns:
//   String - action by double click.
//
Function ActionOnDoubleClick()
	
	HowToOpen = Common.CommonSettingsStorageLoad(
		"OpenFileSettings", "ActionOnDoubleClick");
	
	If HowToOpen = Undefined
	 OR HowToOpen = Enums.DoubleClickFileActions.EmptyRef() Then
		
		HowToOpen = Enums.DoubleClickFileActions.OpenFile;
		
		Common.CommonSettingsStorageSave(
			"OpenFileSettings", "ActionOnDoubleClick", HowToOpen);
	EndIf;
	
	If HowToOpen = Enums.DoubleClickFileActions.OpenFile Then
		Return "OpenFile";
	Else
		Return "OpenCard";
	EndIf;
	
EndFunction

// The function changes FileOwner for the objects as Catalog.File, and returns True if successful.
// Parameters:
//  RefsToFilesArray - Array - an array of files.
//  NewFileOwner  - AnyRef - the new file owner.
//
// Returns:
//   Boolean  - shows whether the operation is performed successfully.
//
Function SetFileOwner(ArrayOfRefsToFiles, NewFileOwner) Export
	If ArrayOfRefsToFiles.Count() = 0 Or Not ValueIsFilled(NewFileOwner) Then
		Return False;
	EndIf;
	
	// Parent is the same, you do not have to do anything.
	If ArrayOfRefsToFiles.Count() > 0 AND (ArrayOfRefsToFiles[0].FileOwner = NewFileOwner) Then
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		For Each ReceivedFile In ArrayOfRefsToFiles Do
			LockItem = Lock.Add(Metadata.FindByType(TypeOf(ReceivedFile)).FullName());
			LockItem.SetValue("Ref",ReceivedFile);
		EndDo;
		Lock.Lock();
	
		For Each ReceivedFile In ArrayOfRefsToFiles Do
			FileObject = ReceivedFile.GetObject();
			FileObject.Lock();
			FileObject.FileOwner = NewFileOwner;
			FileObject.Write();
		EndDo;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
	
EndFunction

// The function changes the Parent property to objects of the Catalog.FileFolders type. It returns 
// True if successful In the variable LoopFound it returns True if one of the folders is transferred to its child folder.
//
// Parameters:
//  RefsToFilesArray - Array - an array of files.
//  NewParent  - AnyRef - a new file owner.
//  LoopFound - Boolean - returns True if a loop is found.
//
// Returns:
//   Boolean  - shows whether the operation is performed successfully.
//
Function ChangeFoldersParent(ArrayOfRefsToFiles, NewParent, LoopFound) Export
	LoopFound = False;
	
	If ArrayOfRefsToFiles.Count() = 0 Then
		Return False;
	EndIf;
	
	// Parent is the same, you do not have to do anything.
	If ArrayOfRefsToFiles.Count() = 1 AND (ArrayOfRefsToFiles[0].Parent = NewParent) Then
		Return False;
	EndIf;
	
	If HasLoop(ArrayOfRefsToFiles, NewParent) Then
		LoopFound = True;
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		For Each ReceivedFile In ArrayOfRefsToFiles Do
			LockItem = Lock.Add(Metadata.FindByType(TypeOf(ReceivedFile)).FullName());
			LockItem.SetValue("Ref",ReceivedFile);
		EndDo;
		Lock.Lock();
	
		For Each ReceivedFile In ArrayOfRefsToFiles Do
			FileObject = ReceivedFile.GetObject();
			FileObject.Lock();
			FileObject.Parent = NewParent;
			FileObject.Write();
		EndDo;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
	
EndFunction

// Receives data to move file from one list of attached files to other.
//
// Parameters:
// FileArray - an array of references to files or CatalogRef.Files.
// FileOwner - AnyRef - a file owner.
//
// Returns:
//   ValueTable - description of files.
//
Function GetDataToTransferToAttachedFiles(FileArray, FileOwner) Export

	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.Description AS Description
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	Query.SetParameter("FileOwner", FileOwner);
	TabularResult = Query.Execute().Unload();
	
	Result = New Map;
	For Each FileRef In FilesArray Do
		
		If TabularResult.Find(FileRef, "Ref") <> Undefined Then 
			Result.Insert(FileRef, "Ignore");
		ElsIf TabularResult.Find(FileRef.Description, "Description") <> Undefined Then 
			Result.Insert(FileRef, "Refresh");
		Else
			Result.Insert(FileRef, "Copy");
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Copies files when transferring them from one list of attached files to another.
//
// Parameters:
//   FileArray - Array - an array of references to files or CatalogRef.Files.
//   FileOwner - AnyRef - a file owner.
//
// Returns:
//   CatalogRef.Files - a copied file.
//
Function CopyFileInAttachedOnes(FileArray, FileOwner) Export
	
	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;
	
	For Each FileRef In FilesArray Do
		
		Source = FileRef;
		SourceObject = Source.GetObject();
		
		DestinationObject = SourceObject.Copy();
		DestinationObject.FileOwner = FileOwner;
		DestinationObject.Write();
		
		Destination = DestinationObject.Ref;
		
		If Not Source.CurrentVersion.IsEmpty() Then
			
			FileStorage = Undefined;
			If Source.CurrentVersion.FileStorageType = Enums.FileStorageTypes.InInfobase Then 
				FileStorage = FilesOperations.FileFromInfobaseStorage(Source.CurrentVersion);
			EndIf;
			
			FileInfo = FilesOperationsClientServer.FileInfo("FileWithVersion");
			FileInfo.BaseName = Destination.Description;
			FileInfo.Size = Source.CurrentVersion.Size;
			FileInfo.ExtensionWithoutPoint = Source.CurrentVersion.Extension;
			FileInfo.TempFileStorageAddress = FileStorage;
			FileInfo.TempTextStorageAddress = Source.CurrentVersion.TextStorage;
			FileInfo.RefToVersionSource = Source.CurrentVersion;
			Version = FilesOperationsInternal.CreateVersion(Destination, FileInfo);
			FilesOperationsInternal.UpdateVersionInFile(Destination, Version, Source.CurrentVersion.TextStorage);
		EndIf;
		
	EndDo;
	
	Return Destination;
	
EndFunction

// Updates file versions of the same name when transferring them from one list of attached files to another.
//
// Parameters:
//   FileArray - an array of references to files or CatalogRef.Files.
//   FileOwner - AnyRef - a file owner.
//
// Returns:
//   CatalogRef.Files - a copied file.
//
Function UpdateFileInAttachedOnes(FileArray, FileOwner) Export
	
	If TypeOf(FileArray) = Type("Array") Then 
		FilesArray = FileArray;
	Else
		FilesArray = New Array;
		FilesArray.Add(FileArray);
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Files.Ref AS Ref,
	|	Files.Description AS FullDescr
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	Query.SetParameter("FileOwner", FileOwner);
	
	TabularResult = Query.Execute().Unload();
	For Each FileRef In FilesArray Do
		
		FoundRow = TabularResult.Find(FileRef.Description, "FullDescr");
		
		Source = FileRef;
		Destination = FoundRow.Ref;
		
		If Not Source.CurrentVersion.IsEmpty() Then
			
			FileStorage = Undefined;
			If Source.CurrentVersion.FileStorageType = Enums.FileStorageTypes.InInfobase Then 
				FileStorage = FilesOperations.FileFromInfobaseStorage(Source.CurrentVersion);
			EndIf;
			
			FileInfo = FilesOperationsClientServer.FileInfo("FileWithVersion");
			FileInfo.BaseName = Destination.Description;
			FileInfo.Size = Source.CurrentVersion.Size;
			FileInfo.ExtensionWithoutPoint = Source.CurrentVersion.Extension;
			FileInfo.TempFileStorageAddress = FileStorage;
			FileInfo.TempTextStorageAddress = Source.CurrentVersion.TextStorage;
			FileInfo.RefToVersionSource = Source.CurrentVersion;
			Version = FilesOperationsInternal.CreateVersion(Destination, FileInfo);
			FilesOperationsInternal.UpdateVersionInFile(Destination, Version, Source.CurrentVersion.TextStorage);
		EndIf;
		
	EndDo;
	
	Return Destination;
	
EndFunction

// Fills the conditional appearance of the file list.
//
// Parameters:
// List - a dynamic list.
//
Procedure FillConditionalAppearanceOfFilesList(List) Export
	
	DCConditionalAppearance = List.SettingsComposer.Settings.ConditionalAppearance;
	DCConditionalAppearance.UserSettingID = "MainAppearance";
	
	Item = DCConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Filled;
	Filter.LeftValue = New DataCompositionField("BeingEditedBy");
	
	If HasDuplicateItem(DCConditionalAppearance.Items, Item) Then
		DCConditionalAppearance.Items.Delete(Item);
	EndIf;
	
	Item = DCConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FileLockedByCurrentUser);
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("BeingEditedBy");
	Filter.RightValue = Users.CurrentUser();
	
	If HasDuplicateItem(DCConditionalAppearance.Items, Item) Then
		DCConditionalAppearance.Items.Delete(Item);
	EndIf;
	
EndProcedure

// Fills conditional appearance of the folder list.
//
// Parameters:
// List - a dynamic list.
//
Procedure FillConditionalAppearanceOfFoldersList(Folders) Export
	
	DCConditionalAppearance = Folders.SettingsComposer.Settings.ConditionalAppearance;
	DCConditionalAppearance.UserSettingID = "MainAppearance";
	
	Item = DCConditionalAppearance.Items.Add();
	Item.Use = True;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	Filter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.Use = True;
	Filter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.LeftValue = New DataCompositionField("FolderSynchronizationEnabled");
	Filter.RightValue = True;
	
	If HasDuplicateItem(DCConditionalAppearance.Items, Item) Then
		DCConditionalAppearance.Items.Delete(Item);
	EndIf;
	
EndProcedure

// Receives file data to open and reads from the common settings of FolderToSaveAs.
//
// Parameters:
//  FileOrVersionRef     - CatalogRef.Files, CatalogRef.FilesVersions - a file or a file version.
//  FormID      - UUID - a form UUID.
//  OwnerWorkingDirectory - String - a working directory of the file owner.
//
// Returns:
//   Structure - a structure with file data.
//
Function FileDataToSave(FileRef, VersionRef = Undefined, FormID = Undefined, OwnerWorkingDirectory = Undefined) Export

	FileData = FileDataToOpen(FileRef, VersionRef, FormID, OwnerWorkingDirectory);
	
	FolderForSaveAs = Common.CommonSettingsStorageLoad("ApplicationSettings", "FolderForSaveAs");
	FileData.Insert("FolderForSaveAs", FolderForSaveAs);

	Return FileData;
EndFunction

// Receives FileData and VersionURL of all subordinate files.
// Parameters:
//  FileRef - CatalogRef.Files - file.
//  FormID - a form UUID.
//
// Returns:
//   Array - an array of structures with file data.
Function FileDataAndURLOfAllFileVersions(FileRef, FormID) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	FilesVersions.Ref AS Ref
		|FROM
		|	Catalog.FilesVersions AS FilesVersions
		|WHERE
		|	FilesVersions.Owner = &FileRef";
	
	Query.SetParameter("FileRef", FileRef);
	Result = Query.Execute();
	Selection = Result.Select();
	
	ReturnArray = New Array;
	While Selection.Next() Do
		
		VersionRef = Selection.Ref;
		FileData = FileData(FileRef, VersionRef);
		VersionURL = GetTemporaryStorageURL(VersionRef, FormID);
		
		ReturnStructure = New Structure("FileData, VersionURL, VersionRef", 
			FileData, VersionURL, VersionRef);
		ReturnArray.Add(ReturnStructure);
	EndDo;
	
	// If versions are not stored, encrypting the file.
	If Not FileRef.StoreVersions Or Not ValueIsFilled(FileRef.CurrentVersion) Then
		FileData = FileData(FileRef);
		VersionURL = GetTemporaryStorageURL(FileRef, FormID);
		
		ReturnStructure = New Structure("FileData, VersionURL, VersionRef", 
			FileData, VersionURL, FileRef);
		ReturnArray.Add(ReturnStructure);
	EndIf;
	
	Return ReturnArray;
EndFunction

// Executes PutInTempStorage (if the file is stored on the hard drive) and returns a URL of the file in the storage.
// Parameters:
//  VersionRef  - CatalogRef.FilesVersions - a file version.
//  FormID - a form UUID.
//
// Returns:
//   String - link.
Function GetTemporaryStorageURL(VersionRef, FormID = Undefined) Export
	Address = "";
	
	FileStorageType = VersionRef.FileStorageType;
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		If NOT VersionRef.Volume.IsEmpty() Then
			FullPath = FilesOperationsInternal.FullVolumePath(VersionRef.Volume) + VersionRef.PathToFile; 
			Try
				BinaryData = New BinaryData(FullPath);
				Address = PutToTempStorage(BinaryData, FormID);
			Except
				// Record to the event log.
				ErrorMessage = GenerateErrorTextOfGetFileFromVolumeForAdministrator(
					ErrorInfo(), VersionRef.Owner);
				
				WriteLogEvent(
					NStr("ru = 'Файлы.Открытие файла'; en = 'Files.File opens'; pl = 'Pliki.Otwórz plik';es_ES = 'Archivo.Abrir el archivo';es_CO = 'Archivo.Abrir el archivo';tr = 'Dosyalar. Dosyayı aç';it = 'File.Apertura file';de = 'Dateien. Datei öffnen'",
					     CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.Catalogs.Files,
					VersionRef.Owner,
					ErrorMessage);
				
				Raise FilesOperationsInternalClientServer.ErrorFileNotFoundInFileStorage(
					VersionRef.FullDescr + "." + VersionRef.Extension);
			EndTry;
		EndIf;
	Else
		FileStorage = FilesOperations.FileFromInfobaseStorage(VersionRef);
		BinaryData = FileStorage.Get();
		Address = PutToTempStorage(BinaryData, FormID);
	EndIf;
	
	Return Address;
	
EndFunction

// Gets an array of encryption certificates.
// Parameters:
//  Ref  - CatalogRef.Files - a file.
//
// Returns:
//   Array - an array of structures
Function EncryptionCertificates(Ref) Export
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		Return ModuleDigitalSignature.EncryptionCertificates(Ref);
	EndIf;
	
	Return Undefined;
	
EndFunction

// Adds a signature to the file version and marks the file as signed.
Procedure AddSignatureToFile(FileRef, SignatureProperties, FormID) Export
	
	AttributesStructure = Common.ObjectAttributesValues(FileRef, "BeingEditedBy, Encrypted");
	
	BeingEditedBy = AttributesStructure.BeingEditedBy;
	If ValueIsFilled(BeingEditedBy) Then
		Raise FilesOperationsInternalClientServer.FileUsedByAnotherProcessCannotBeSignedMessageString(FileRef);
	EndIf;
	
	Encrypted = AttributesStructure.Encrypted;
	If Encrypted Then
		ExceptionString = FilesOperationsInternalClientServer.EncryptedFileCannotBeSignedMessageString(FileRef);
		Raise ExceptionString;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	
	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	ModuleDigitalSignature.AddSignature(FileRef, SignatureProperties, FormID);
	
EndProcedure

// Adds a file to volumes when the "Store initial image files" command is performed.
// Parameters:
//  FilesPathsMap - Map - a mapping of file UUID and a file path on the hard drive.
//  FileStorageTyep - Enums.FilesStorageTypes - a storage type of files.
Procedure AddFilesToVolumesWhenPlacing(FilesPathsMap, FileStorageType) Export
	
	Selection = Catalogs.FilesVersions.Select();
	
	While Selection.Next() Do
		
		Object = Selection.GetObject();
		
		If Object.FileStorageType <> Enums.FileStorageTypes.InVolumesOnHardDrive Then
			Continue;
		EndIf;
		
		UUID = String(Object.Ref.UUID());
		
		FullFilePathOnHardDrive = FilesPathsMap.Get(UUID);
		FullPathNew = "";
		
		If FullFilePathOnHardDrive = Undefined Then
			Continue;
		EndIf;
		
		FileStorage = Undefined;
		
		// In the destination base, the files must be stored in the infobase (even if they were stored in 
		// volumes in the source database).
		If FileStorageType = Enums.FileStorageTypes.InInfobase Then
			
			Object.FileStorageType = Enums.FileStorageTypes.InInfobase;
			Object.PathToFile = "";
			Object.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			
			BinaryData = New BinaryData(FullFilePathOnHardDrive);
			FileStorage = New ValueStorage(BinaryData);
			
		Else // In the destination base files must be stored in volumes on the disk. Moving the unzipped file to the volume.
			
			FileInitial = New File(FullFilePathOnHardDrive);
			FullPathNew = FileInitial.Path + Object.Description + "." + Object.Extension;
			MoveFile(FullFilePathOnHardDrive, FullPathNew);
			
			// Add the file to a volume with sufficient free space.
			FileInfo = FilesOperationsInternal.AddFileToVolume(FullPathNew, Object.UniversalModificationDate,
				Object.Description, Object.Extension, Object.VersionNumber, Object.Owner.Encrypted); 
			Object.Volume = FileInfo.Volume;
			Object.PathToFile = FileInfo.PathToFile;
			
		EndIf;
		
		Object.AdditionalProperties.Insert("FilePlacementInVolumes", True); // To pass the record of signed files.
		Object.Write();
		
		If FileStorageType = Enums.FileStorageTypes.InInfobase Then
			WriteFileToInfobase(Object.Ref, FileStorage);	
		EndIf;
		
		If NOT IsBlankString(FullPathNew) Then
			DeleteFiles(FullPathNew);
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes the registration of changes after placing them into volumes.
// Parameters:
//  ExchangePlanRef - ExchangePlan.Ref - an exchange plan.
Procedure DeleteChangeRecords(ExchangePlanRef) Export
	
	ExchangePlans.DeleteChangeRecords(ExchangePlanRef, Metadata.Catalogs.FilesVersions);
	ExchangePlans.DeleteChangeRecords(ExchangePlanRef, Metadata.Catalogs.Files);
	ExchangePlans.DeleteChangeRecords(ExchangePlanRef, Metadata.InformationRegisters.FilesBinaryData);
	
EndProcedure

// Text extraction

// Writes the extracted text.
//
// Parameters:
//  CurrentVersion  - CatalogRef.FilesVersions - a file version.
//
Procedure OnWriteExtractedText(CurrentVersion) Export
	
	FileLocked = False;
	
	// Write it if it is not a version.
	If Common.HasObjectAttribute("FileOwner", Metadata.FindByType(TypeOf(CurrentVersion))) Then
		InfobaseUpdate.WriteData(CurrentVersion);
		Return;
	EndIf;
	
	File = CurrentVersion.Owner;
	If File.CurrentVersion = CurrentVersion.Ref Then
		Try
			LockDataForEdit(File);
			FileLocked = True;
		Except
			// Exception if the object is already locked, including the Lock method.
			Return;
		EndTry;
	EndIf;
	
	BeginTransaction();
	Try
		CurrentVersion.DataExchange.Load = True;
		CurrentVersion.Write();
		
		If File.CurrentVersion = CurrentVersion.Ref Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(File)).FullName());
			DataLockItem.SetValue("Ref", File);
			DataLock.Lock();
			
			FileObject = File.GetObject();
			FileObject.TextStorage = CurrentVersion.TextStorage;
			FileObject.DataExchange.Load = True;
			FileObject.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		If FileLocked Then
			UnlockDataForEdit(File);
		EndIf;
		
		Raise;
	EndTry;
	
	If FileLocked Then
		UnlockDataForEdit(File);
	EndIf;
	
EndProcedure

// Settings

// Calculating from the FilesVersionsComparisonMethod settings.
//
// Returns:
//   String - a file version comparison method.
//
Function FileVersionsComparisonMethod()
	
	ComparisonMethod = Common.CommonSettingsStorageLoad(
		"FileComparisonSettings", "FileVersionsComparisonMethod");
	
	If ComparisonMethod = Enums.FileVersionsComparisonMethods.MicrosoftOfficeWord Then
		Return "MicrosoftOfficeWord";
		
	ElsIf ComparisonMethod = Enums.FileVersionsComparisonMethods.OpenOfficeOrgWriter Then
		Return "OpenOfficeOrgWriter";
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function ShowTooltipsOnEditFiles(Value = Undefined) Export
	
	SetPrivilegedMode(True);
	If Value <> Undefined Then
		CommonServerCall.CommonSettingsStorageSave(
			"ApplicationSettings", "ShowTooltipsOnEditFiles", Value,,, True);
		RefreshReusableValues();
	EndIf;
	
EndFunction

// Informative

// The function returns the number of Files locked by the current user by owner.
// 
// Parameters:
//  FileOwner  - AnyRef - file owner.
//
// Returns:
//   Number  - a number of locked files.
//
Function FilesLockedByCurrentUserCount(FileOwner) Export
	
	Return FilesOperationsInternal.LockedFilesCount(FileOwner);
	
EndFunction

// Receives the value of the ShowSizeColumn setting.
// Returns:
//   Boolean - show size column.
//
Function GetShowSizeColumn() Export
	ShowSizeColumn = Common.CommonSettingsStorageLoad("ApplicationSettings", "ShowSizeColumn");
	If ShowSizeColumn = Undefined Then
		ShowSizeColumn = False;
		Common.CommonSettingsStorageSave("ApplicationSettings", "ShowSizeColumn", ShowSizeColumn);
	EndIf;
	
	Return ShowSizeColumn;
	
EndFunction

// Returns the number of files in volumes.
// Returns:
//   Number - the number of files in volumes.
//
Function CountFilesInVolumes()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(COUNT(FilesInVolumes.File), 0) AS FilesCount
	|FROM
	|	(SELECT
	|		FilesInfo.File AS File
	|	FROM
	|		InformationRegister.FilesInfo AS FilesInfo
	|	WHERE
	|		FilesInfo.File.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)) AS FilesInVolumes
	|		LEFT JOIN Catalog.FilesVersions AS FilesVersions
	|		ON FilesInVolumes.File = FilesVersions.Owner
	|			AND (FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive))";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.FilesCount;
	EndIf;
	
	Return 0;
	
EndFunction

// Receives the number of file versions.
// Parameters:
//  FileRef - CatalogRef.Files - file.
//
// Returns:
//   Number - the number of versions
Function GetVersionsCount(FileRef)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(*) AS Count
	|FROM
	|	Catalog.FilesVersions AS FilesVersions
	|WHERE
	|	FilesVersions.Owner = &FileRef";
	
	Query.SetParameter("FileRef", FileRef);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Number(Selection.Count);
	
EndFunction

// Returns True if there is looping (if a folder is moved into its own child folder).
// Parameters:
//  RefsToFilesArray - Array - an array of files.
//  NewParent  - AnyRef - a new file owner.
//
// Returns:
//   Boolean  - has looping.
//
Function HasLoop(Val ArrayOfRefsToFiles, NewParent)
	
	If ArrayOfRefsToFiles.Find(NewParent) <> Undefined Then
		Return True; // found looping
	EndIf;
	
	Parent = NewParent.Parent;
	If Parent.IsEmpty() Then // got to root
		Return False;
	EndIf;
	
	If HasLoop(ArrayOfRefsToFiles, Parent) Then
		Return True; // found looping
	EndIf;
	
	Return False;
	
EndFunction

// Returns True if the specified item of the FilesFolders has a child node with this name.
//
// Parameters:
//  FolderName					 - String					     - a folder name.
//  Parent					 - DefinedType.AttachedFilesOwner	 - folder parent.
//  FirstFolderWithSameName	 - DefinedType.AttachedFilesOwner	 - the first found folder with the specified name.
// 
// Returns:
//  Boolean - has a child item with this name.
//
Function HasFolderWithThisName(FolderName, Parent, FirstFolderWithSameName) Export
	
	FirstFolderWithSameName = Catalogs.FileFolders.EmptyRef();
	
	QueryToFolders = New Query;
	QueryToFolders.SetParameter("Description", FolderName);
	QueryToFolders.SetParameter("Parent", Parent);
	QueryToFolders.Text =
	"SELECT ALLOWED TOP 1
	|	FileFolders.Ref AS Ref
	|FROM
	|	Catalog.FileFolders AS FileFolders
	|WHERE
	|	FileFolders.Description = &Description
	|	AND FileFolders.Parent = &Parent";
	
	If TypeOf(Parent) <> Type("CatalogRef.FileFolders") Then
		FilesStorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(Parent);
		QueryToFolders.Text = StrReplace(QueryToFolders.Text, ".FileFolders", "." + FilesStorageCatalogName);
	EndIf;
	
	QueryResult = QueryToFolders.Execute(); 
	
	If NOT QueryResult.IsEmpty() Then
		QuerySelection = QueryResult.Unload();
		FirstFolderWithSameName = QuerySelection[0].Ref;
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function FullFolderPath(Folder)
	
	FullPath = "";
	
	FolderParent = Common.ObjectAttributeValue(Folder.Ref, "Parent");
	
	If ValueIsFilled(FolderParent) Then
	
		FullPath = "";
		While ValueIsFilled(FolderParent) Do
			
			FullPath = String(FolderParent) + "\" + FullPath;
			FolderParent = Common.ObjectAttributeValue(FolderParent, "Parent");
			If Not ValueIsFilled(FolderParent) Then
				Break;
			EndIf;
			
		EndDo;
		
		FullPath = FullPath + String(Folder.Ref);
		
		If Not IsBlankString(FullPath) Then
			FullPath = """" + FullPath + """";
		EndIf;
	
	EndIf;
	
	Return FullPath;
	
EndFunction

// Returns the number of files in volumes in the FilesInVolumesCount parameter.
Procedure DetermineFilesInVolumesCount(FilesInVolumesCount) Export
	
	FilesInVolumesCount = FilesInVolumesCount + CountFilesInVolumes();
	
EndProcedure

// If there is a duplicate item in the list conditional appearance.
// Parameters:
// Items - an item array of the list conditional appearance.
// SearchItem - an item of the list conditional appearance.
//
// Returns:
//   Boolean - has duplicate item.
//
Function HasDuplicateItem(Items, SearchItem)
	
	For Each Item In Items Do
		If Item <> SearchItem Then
			
			If Item.Appearance.Items.Count() <> SearchItem.Appearance.Items.Count() Then
				Continue;
			EndIf;
			
			DifferentItemFound = False;
			
			// Iterating all appearance items, and if there is at least one different, click Continue.
			ItemsCount = Item.Appearance.Items.Count();
			For Index = 0 To ItemsCount - 1 Do
				Item1 = Item.Appearance.Items[Index];
				Item2 = SearchItem.Appearance.Items[Index];
				
				If Item1.Use AND Item2.Use Then
					If Item1.Parameter <> Item2.Parameter OR Item1.Value <> Item2.Value Then
						DifferentItemFound = True;
						Break;
					EndIf;
				EndIf;
			EndDo;
			
			If DifferentItemFound Then
				Continue;
			EndIf;
			
			If Item.Filter.Items.Count() <> SearchItem.Filter.Items.Count() Then
				Continue;
			EndIf;
			
			// Iterating all filter items, and if there is at least one different, click Continue.
			ItemsCount = Item.Filter.Items.Count();
			For Index = 0 To ItemsCount - 1 Do
				Item1 = Item.Filter.Items[Index];
				Item2 = SearchItem.Filter.Items[Index];
				
				If Item1.Use AND Item2.Use Then
					If Item1.ComparisonType <> Item2.ComparisonType
						OR Item1.LeftValue <> Item2.LeftValue
						OR Item1.RightValue <> Item2.RightValue Then
						
						DifferentItemFound = True;
						Break;
						
					EndIf;
				EndIf;
			EndDo;
			
			If DifferentItemFound Then
				Continue;
			EndIf;
			
			// If you iterated all appearance and filter items and they are all the same, it is a duplicate.
			Return True;
			
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function FileToSynchronizeByCloudService(File)
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	COUNT(FilesSynchronizationWithCloudServiceStatuses.File) AS File
		|FROM
		|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
		|WHERE
		|	FilesSynchronizationWithCloudServiceStatuses.File = &File";
	
	Query.SetParameter("File", File);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function HasAccessRight(Right, Ref) Export
	
	Return AccessRight(Right, Ref.Metadata());
	
EndFunction

Function ImageAddingOptions(FilesOwner) Export
	
	AddingOptions = New Structure;
	AddingOptions.Insert("InsertRight", HasAccessRight("Insert", FilesOwner));
	AddingOptions.Insert("OwnerFiles" , AttachedFilesCount(FilesOwner, True));
	
	Return AddingOptions;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Fills in the VersionNumber(Number) from the Code(String) data in the FilesVersions.
Procedure FillVersionNumberFromCatalogCode() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	FilesVersions.Ref,
	|	FilesVersions.DeletionMark,
	|	FilesVersions.Code,
	|	FilesVersions.VersionNumber,
	|	FilesVersions.Owner.DeletionMark AS OwnerMarkedForDeletion,
	|	FilesVersions.Owner.CurrentVersion
	|FROM
	|	Catalog.FilesVersions AS FilesVersions";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.VersionNumber = 0 Then 
			
			TypesDetails = New TypeDescription("Number");
			CodeNumber = TypesDetails.AdjustValue(Selection.Code);
			If CodeNumber <> 0 Then
				Object = Selection.Ref.GetObject();
				Object.VersionNumber = CodeNumber;
				
				// Correcting the situation that used to be acceptable, but now is not: the active version is marked for deletion, but the owner
				// - no.
				If Selection.DeletionMark = True AND Selection.OwnerMarkedForDeletion = False AND Selection.CurrentVersion = Selection.Ref Then
					Object.DeletionMark = False;
				EndIf;
				
				InfobaseUpdate.WriteData(Object);
			EndIf
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Fills in the FileStorageType in the FilesVersions catalog by the InBase value.
Procedure FillFileStorageTypeInInfobase() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FilesVersions.Ref
	|FROM
	|	Catalog.FilesVersions AS FilesVersions";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		
		If Object.FileStorageType.IsEmpty() Then
			Object.FileStorageType = Enums.FileStorageTypes.InInfobase;
			InfobaseUpdate.WriteData(Object);
		EndIf;
		
	EndDo;
	
EndProcedure

// In the FilesVersions and Files catalog it increases PictureIndex two times.
Procedure ChangeIconIndex() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FilesVersions.Ref
	|FROM
	|	Catalog.FilesVersions AS FilesVersions";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.DataExchange.Load = True;
		Object.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(Object.Extension);
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.Ref
	|FROM
	|	Catalog.Files AS Files";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.DataExchange.Load = True;
		Object.PictureIndex = Object.CurrentVersion.PictureIndex;
		Object.Write();
	EndDo;
	
EndProcedure

// Called when updating to 1.0.6.3 and fills in the paths of FilesStorageVolumes.
Procedure FillVolumePaths() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileStorageVolumes.Ref
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.FullPathLinux = Object.FullPathWindows;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Rewrites all items in the Files catalog.
Procedure OverwriteAllFiles() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.Ref
	|FROM
	|	Catalog.Files AS Files";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.Write();
	EndDo;
	
EndProcedure

// In the FilesVersions catalog fills in the FileModificationDate from the creation date.
Procedure FillFileModificationDate() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FilesVersions.Ref
		|FROM
		|	Catalog.FilesVersions AS FilesVersions";

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Object = Selection.Ref.GetObject();
		
		If Object.FileModificationDate = Date("00010101000000") Then
			Object.FileModificationDate = Object.CreationDate;
			Object.Write();
		EndIf;
		
	EndDo;
	
	OverwriteAllFiles(); // To transfer values from the FileModificationDate from version to file.
	
EndProcedure

// Creates new files by analogy with the specified ones.
// Parameters:
//  FilesArray  - Array - an array of files CatalogRef.Files - the existing files.
//  NewFileOwner - AnyRef - a file owner.
//
Procedure CopyFiles(FilesArray, NewFileOwner) Export
	
	For each File In FilesArray Do
		NewFile = CopyFileSSL(File, NewFileOwner);
	EndDo;
	
EndProcedure

// Writes FileStorage to the infobase.
//
// Parameters:
// VersionRef - a reference to file version.
// FileStorage - ValueStorage with file binary data that need to be written.
//
Procedure WriteFileToInfobase(VersionRef, FileStorage)
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.FilesBinaryData.CreateRecordManager();
	RecordManager.File = VersionRef;
	RecordManager.FileBinaryData = FileStorage;
	RecordManager.Write(True);
	
EndProcedure

// Deletes record in the StoredVersionsFiles
//
// Parameters:
// File - a reference to file.
//
Procedure DeleteRecordFromRegisterOfFilesBinaryData(File) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.FilesBinaryData.CreateRecordSet();
	RecordSet.Filter.File.Set(File);
	RecordSet.Write();
	
EndProcedure

// Transfers the binary file from FileStorage of the FilesVersions to the StoredFilesVersions information register.
Procedure MoveFilesFromInfobaseToInformationRegister() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FilesVersions.Ref
	|FROM
	|	Catalog.FilesVersions AS FilesVersions
	|WHERE
	|	FilesVersions.FileStorageType = &FileStorageType";
		
	Query.SetParameter("FileStorageType", Enums.FileStorageTypes.InInfobase);	

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Object = Selection.Ref.GetObject();
		
		DataToStorage = Object.StorageFile.Get();
		If TypeOf(DataToStorage) = Type("BinaryData") Then
			WriteFileToInfobase(Selection.Ref, Object.StorageFile);
			Object.StorageFile = New ValueStorage(""); // clearing the value
			InfobaseUpdate.WriteData(Object);
		EndIf;
		
	EndDo;
	
EndProcedure

// Fills in the LoanDate field with the current field.
Procedure FillLoanDate() Export
	
	SetPrivilegedMode(True);
	
	LoanDate = CurrentSessionDate();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Files.Ref
		|FROM
		|	Catalog.Files AS Files";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If ValueIsFilled(Selection.Ref.BeingEditedBy) Then
			Object = Selection.Ref.GetObject();
			// To write a previously signed object.
			Object.AdditionalProperties.Insert("WriteSignedObject", True);
			Object.LoanDate = LoanDate;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndDo;
	
EndProcedure

// Renames old rights to new ones.
Procedure ReplaceRightsInFileFolderRightsSettings() Export
	
	If NOT Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	
	ReplacementTable = ModuleAccessManagement.TableOfRightsReplacementInObjectsRightsSettings();
	
	Row = ReplacementTable.Add();
	Row.OwnersType = Catalogs.FileFolders.EmptyRef();
	Row.OldName = "ReadFoldersAndFiles";
	Row.NewName  = "Read";
	
	Row = ReplacementTable.Add();
	Row.OwnersType = Catalogs.FileFolders.EmptyRef();
	Row.OldName = "AddFoldersAndFiles";
	Row.NewName  = "AddFiles";
	
	Row = ReplacementTable.Add();
	Row.OwnersType = Catalogs.FileFolders.EmptyRef();
	Row.OldName = "FoldersAndFilesEdit";
	Row.NewName  = "FilesModification";
	
	Row = ReplacementTable.Add();
	Row.OwnersType = Catalogs.FileFolders.EmptyRef();
	Row.OldName = "FoldersAndFilesEdit";
	Row.NewName  = "FoldersModification";
	
	Row = ReplacementTable.Add();
	Row.OwnersType = Catalogs.FileFolders.EmptyRef();
	Row.OldName = "FolderAndFileDeletionMark";
	Row.NewName  = "FilesDeletionMark";
	
	ModuleAccessManagement.ReplaceRightsInObjectsRightsSettings(ReplacementTable);
	
EndProcedure

// Checks the Encypted flag for the file.
Procedure CheckEncryptedFlag(FileRef, Encrypted, UUID = Undefined) Export
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
		DataLockItem.SetValue("Ref", FileRef);
		DataLock.Lock();
		
		FileObject = FileRef.GetObject();
		LockDataForEdit(FileRef, , UUID);
		
		FileObject.Encrypted = Encrypted;
		// To write a previously signed object.
		FileObject.AdditionalProperties.Insert("WriteSignedObject", True);
		FileObject.Write();
		UnlockDataForEdit(FileRef, UUID);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates the size of the file and current version. It is required when importing the encrypted file via email.
Procedure UpdateSizeOfFileAndVersion(FileData, FileSize, UUID) Export
	
	BeginTransaction();
	Try
		
		VersionObject = FileData.Version.GetObject();
		VersionObject.Lock();
		VersionObject.Size = FileSize;
		// To write a previously signed object.
		VersionObject.AdditionalProperties.Insert("WriteSignedObject", True);
		VersionObject.Write();
		VersionObject.Unlock();
		
		FileObject = FileData.Ref.GetObject();
		LockDataForEdit(FileObject.Ref, , UUID);
		// To write a previously signed object.
		FileObject.AdditionalProperties.Insert("WriteSignedObject", True);
		FileObject.Write();
		UnlockDataForEdit(FileObject.Ref, UUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Receives the number of versions with non-extracted text.
Procedure GetUnextractedTextVersionCount(AdditionalParameters, AddressInTempStorage) Export
	
	FilesCount = 0;
	
	FileTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	
	For Each Type In FileTypes Do
		
		FilesDirectoryMetadata = Metadata.FindByType(Type);
		
		Query = New Query;
		
		QueryText = 
			"SELECT
			|	ISNULL(COUNT(Files.Ref), 0) AS FilesCount
			|FROM
			|	&CatalogName AS Files
			|WHERE
			|	Files.TextExtractionStatus IN (VALUE(Enum.FileTextExtractionStatuses.NotExtracted), VALUE(Enum.FileTextExtractionStatuses.EmptyRef))";
	
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			If Type = Type("CatalogRef.FilesVersions") Then
				QueryText = QueryText + "
					|	AND NOT Files.Owner.Encrypted";
			Else
				QueryText = QueryText + "
					|	AND NOT Files.Encrypted";
			EndIf;
		EndIf;
	
		QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + FilesDirectoryMetadata.Name);
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			FilesCount = FilesCount + Selection.FilesCount;
		EndIf
		
	EndDo;
	
	PutToTempStorage(FilesCount, AddressInTempStorage);
	
EndProcedure

// Writes the file version encoding.
//
// Parameters:
// VersionRef - CatalogRef.FilesVersions - a reference to the file version.
// Encoding - String - new encoding of the file version.
//
Procedure WriteFileVersionEncoding(VersionRef, Encoding) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.FileEncoding.CreateRecordManager();
	RecordManager.File = VersionRef;
	RecordManager.Encoding = Encoding;
	RecordManager.Write(True);
	
EndProcedure

// Writes the file version encoding.
//
// Parameters:
// VersionRef - a reference to file version.
// Encoding - an encoding row.
// ExtractedText - a text, extracted from the file.
//
Procedure WriteFileVersionEncodingAndExtractedText(VersionRef, Encoding, ExtractedText) Export
	
	WriteFileVersionEncoding(VersionRef, Encoding);
	WriteTextExtractionResultOnWrite(VersionRef, Enums.FileTextExtractionStatuses.Extracted, 
		ExtractedText);
	
EndProcedure

// Writes to the server the text extraction results that are the extracted text and the TextExtractionStatus.
Procedure WriteTextExtractionResultOnWrite(VersionRef, ExtractionResult, TempTextStorageAddress)
	
	FileLocked = False;
	
	VersionMetadata = Metadata.FindByType(TypeOf(VersionRef));
	If Common.HasObjectAttribute("ParentVersion", VersionMetadata) Then
		File = VersionRef.Owner;
		
		If File.CurrentVersion = VersionRef Then
			
			Try
				LockDataForEdit(File);
				FileLocked = True;
			Except
				// Exception if the object is already locked, including the Lock method.
				Return;
			EndTry;
			
		EndIf;
	Else
		File = VersionRef;
	EndIf;
	
	Text = "";
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	
	BeginTransaction();
	Try
		VersionLock = New DataLock;
		DataLockItem = VersionLock.Add(Metadata.FindByType(TypeOf(VersionRef)).FullName());
		DataLockItem.SetValue("Ref", VersionRef);
		VersionLock.Lock();
		
		VersionObject = VersionRef.GetObject();
		If VersionMetadata.FullTextSearch = FullTextSearchUsing Then
			If Not IsBlankString(TempTextStorageAddress) Then
				
				If Not IsTempStorageURL(TempTextStorageAddress) Then
					VersionObject.TextStorage = New ValueStorage(TempTextStorageAddress, New Deflation(9));
					VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
				Else
					TextExtractionResult = FilesOperationsInternal.ExtractText(TempTextStorageAddress);
					VersionObject.TextStorage = TextExtractionResult.TextStorage;
					VersionObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
				EndIf;
				
			EndIf;
		Else
			VersionObject.TextStorage = New ValueStorage("");
			VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		EndIf;
		
		If ExtractionResult = "NotExtracted" Then
			VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		ElsIf ExtractionResult = "Extracted" Then
			VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		ElsIf ExtractionResult = "FailedExtraction" Then
			VersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction;
		EndIf;
	
		// To write a previously signed object.
		VersionObject.AdditionalProperties.Insert("WriteSignedObject", True);
		VersionObject.Write();
		
		If TypeOf(File) = Type("CatalogRef.Files") Then
			FileToCompare = File.CurrentVersion;
		Else
			FileToCompare = VersionRef;
		EndIf;
		
		If FileToCompare = VersionRef Then
			FileLock = New DataLock;
			DataLockItem = FileLock.Add(Metadata.FindByType(TypeOf(File)).FullName());
			DataLockItem.SetValue("Ref", File);
			FileLock.Lock();
			
			FileObject = File.GetObject();
			FileObject.TextStorage = VersionObject.TextStorage;
			// To write a previously signed object.
			FileObject.AdditionalProperties.Insert("WriteSignedObject", True);
			FileObject.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		If FileLocked Then
			UnlockDataForEdit(File);
		EndIf;
		
		Raise;
	EndTry;
	
	If FileLocked Then
		UnlockDataForEdit(File);
	EndIf;
	
EndProcedure

Procedure RegisterObjectsToMoveDigitalSignaturesFromFileVersionsToFiles(Parameters) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DigitalSignatures.SignedObject AS Ref
	|FROM
	|	InformationRegisterDigitalSignatures AS DigitalSignatures
	|WHERE
	|	VALUETYPE(DigitalSignatures.SignedObject) = TYPE(Catalog.FilesVersions)";
	
	Query.Text = StrReplace(Query.Text,
		"InformationRegisterDigitalSignatures", "InformationRegister." + "DigitalSignatures");
	
	RefsArray = Query.Execute().Unload().UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, RefsArray);
	
EndProcedure

Procedure MoveDigitalSignaturesFromFIleVersionsToFiles(Parameters) Export
	
	ProcessingCompleted = True;
	
	ReferencesSelection = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, "Catalog.FilesVersions");
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	RefsArray = New Array;
	Lock = New DataLock;
	LockItemByVersion = Lock.Add("InformationRegister." + "DigitalSignatures");
	LockItemByFile  = Lock.Add("InformationRegister." + "DigitalSignatures");
	
	While ReferencesSelection.Next() Do
		VersionRef = ReferencesSelection.Ref;
		LockItemByVersion.SetValue("SignedObject", VersionRef);
		FileRef = Common.ObjectAttributeValue(VersionRef, "Owner");
		If ValueIsFilled(FileRef) Then
			LockItemByVersion.SetValue("SignedObject", FileRef);
		EndIf;
		BeginTransaction();
		Try
			Lock.Lock();
			
			RecordSetByVersion = InformationRegisters["DigitalSignatures"].CreateRecordSet();
			RecordSetByVersion.Filter.SignedObject.Set(VersionRef);
			RecordSetByVersion.Read();
			
			If RecordSetByVersion.Count() > 0 Then
				If ValueIsFilled(FileRef) Then
					RecordSetByFile = InformationRegisters["DigitalSignatures"].CreateRecordSet();
					RecordSetByFile.Filter.SignedObject.Set(FileRef);
					RecordSetByFile.Read();
					If RecordSetByFile.Count() = 0 Then
						For Each Record In RecordSetByVersion Do
							NewRecord = RecordSetByFile.Add();
							FillPropertyValues(NewRecord, Record);
							NewRecord.SignedObject = FileRef;
						EndDo;
						RecordSetByFile.Write();
					EndIf;
				EndIf;
				RecordSetByVersion.Clear();
				RecordSetByVersion.Write();
			EndIf;
			
			InfobaseUpdate.MarkProcessingCompletion(VersionRef);
			ObjectsProcessed = ObjectsProcessed + 1;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			// If you cannot process an object, try again.
			ObjectsProcessed = ObjectsProcessed - 1;
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось обработать версию файла ""%1"" по причине:
				           |%2'; 
				           |en = 'Cannot process the ""%1"" file version due to: 
				           |%2'; 
				           |pl = 'Nie można przetworzyć wersji pliku ""%1"", ponieważ:
				           |%2';
				           |es_ES = 'No se ha podido procesar la versión del archivo ""%1"" a causa de:
				           |%2';
				           |es_CO = 'No se ha podido procesar la versión del archivo ""%1"" a causa de:
				           |%2';
				           |tr = '""%1"" dosya sürümü şu nedenle işlenemedi: 
				           |%2';
				           |it = 'Impossibile elaborare la versione ""%1"" del file a causa di: 
				           |%2';
				           |de = 'Die Version der Datei ""%1"" konnte aus diesem Grund nicht verarbeitet werden:
				           |%2'"),
				VersionRef,
				DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning, Metadata.Catalogs.FilesVersions, VersionRef, MessageText);
		EndTry;
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "Catalog.FilesVersions") Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедуре MoveDigitalSignaturesFromFIleVersionsToFiles не удалось обработать некоторые версии файлов (пропущены): %1'; en = 'The MoveDigitalSignaturesFromFIleVersionsToFiles procedure cannot process some file versions (skipped): %1'; pl = 'Procedurze MoveDigitalSignaturesFromFIleVersionsToFiles nie udało się opracować niektóre wersje plików (pominięte): %1';es_ES = 'El procedimiento MoveDigitalSignaturesFromFIleVersionsToFiles no ha podido procesar unas versiones de archivos (saltados): %1';es_CO = 'El procedimiento MoveDigitalSignaturesFromFIleVersionsToFiles no ha podido procesar unas versiones de archivos (saltados): %1';tr = 'MoveDigitalSignaturesFromFIleVersionsToFiles işlemi bazı dosya sürümlerini işleyemedi (atlandı): %1';it = 'La procedura MoveDigitalSignaturesFromFIleVersionsToFiles non è stata in grado di elaborare alcune versioni di file (ignorate): %1';de = 'Die Prozedur MoveDigitalSignaturesFromFIleVersionsToFiles kann einige Dateiversionen nicht verarbeiten (übersprungen): %1'"),
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information,
			Metadata.Catalogs.FilesVersions,
			,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Процедура MoveDigitalSignaturesFromFIleVersionsToFiles обработала очередную порцию версий файлов: %1'; en = 'The MoveDigitalSignaturesFromFIleVersionsToFiles procedure has processed files: %1'; pl = 'Procedura MoveDigitalSignaturesFromFIleVersionsToFiles przetworzyła pliki: %1';es_ES = 'El procedimiento MoveDigitalSignaturesFromFIleVersionsToFiles ha procesado los archivos: %1';es_CO = 'El procedimiento MoveDigitalSignaturesFromFIleVersionsToFiles ha procesado los archivos: %1';tr = 'MoveDigitalSignaturesFromFIleVersionsToFiles işlemi sıradaki dosyaların sürümlerini işledi : %1';it = 'La procedura MoveDigitalSignaturesFromFIleVersionsToFiles ha elaborato i seguenti file: %1';de = 'Die Prozedur MoveDigitalSignaturesFromFIleVersionsToFiles hat Dateien verarbeitet: %1'"),
				ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Function ObjectsOnTransferDigitalSignaturesFromFilesVersionsToFiles(ToRead) Export
	
	If ToRead Then
		Return "Catalog.FilesVersions, "
		      + Metadata.InformationRegisters["DigitalSignatures"].FullName();
	Else
		Return Metadata.InformationRegisters["DigitalSignatures"].FullName();
	EndIf;
	
EndFunction

// Registers objects that need update of records in the registry at the InfobaseUpdate exchange plan.
// 
//
Procedure RegisterObjectsToMoveDigitalSignaturesAndEncryptionCertificates(Parameters) Export
	
	TwoTabularSectionsQueryText =
	"SELECT
	|	Files.Ref AS Ref
	|FROM
	|	ObjectsTable AS Files
	|WHERE
	|	(TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					TabularSectionDeleteEncryptionCertificates AS DeleteEncryptionCertificates
	|				WHERE
	|					DeleteEncryptionCertificates.Ref = Files.Ref)
	|			OR TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					TabularSectionDeleteDigitalSignatures AS DeleteDigitalSignatures
	|				WHERE
	|					DeleteDigitalSignatures.Ref = Files.Ref))";
	
	TabularSectionsDeleteEncryptionResultsQueryText =
	"SELECT
	|	Files.Ref AS Ref
	|FROM
	|	ObjectsTable AS Files
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				TabularSectionDeleteEncryptionCertificates AS DeleteEncryptionCertificates
	|			WHERE
	|				DeleteEncryptionCertificates.Ref = Files.Ref)";
	
	TabularSectionsDeleteDigitalSignaturesQueryText =
	"SELECT
	|	Files.Ref AS Ref
	|FROM
	|	ObjectsTable AS Files
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				TabularSectionDeleteDigitalSignatures AS DeleteDigitalSignatures
	|			WHERE
	|				DeleteDigitalSignatures.Ref = Files.Ref)";
	
	Query = New Query;
	FullCatalogsNames = FullCatalogsNamesOfAttachedFiles();
	
	For Each FullName In FullCatalogsNames Do
		MetadataObject = Metadata.FindByFullName(FullName);
		
		HasTabularSectionDeleteEncryptionResults =
			MetadataObject.TabularSections.Find("DeleteEncryptionCertificates") <> Undefined;
		
		HasTabularSectionDeleteDigitalSignatures =
			MetadataObject.TabularSections.Find("DeleteDigitalSignatures") <> Undefined;
		
		If HasTabularSectionDeleteEncryptionResults AND HasTabularSectionDeleteDigitalSignatures Then
			CurrentQueryText = TwoTabularSectionsQueryText;
			
		ElsIf HasTabularSectionDeleteEncryptionResults Then
			CurrentQueryText = TabularSectionsDeleteEncryptionResultsQueryText;
			
		ElsIf HasTabularSectionDeleteDigitalSignatures Then
			CurrentQueryText = TabularSectionsDeleteDigitalSignaturesQueryText;
		Else 
			Continue;
		EndIf;
		
		If ValueIsFilled(Query.Text) Then
			Query.Text = Query.Text + "
			|
			|UNION ALL
			|
			|";
		EndIf;
		
		CurrentQueryText = StrReplace(CurrentQueryText, "ObjectsTable", FullName);
		
		CurrentQueryText = StrReplace(CurrentQueryText,
			"TabularSectionDeleteEncryptionCertificates", FullName + ".DeleteEncryptionCertificates");
		
		CurrentQueryText = StrReplace(CurrentQueryText,
			"TabularSectionDeleteDigitalSignatures", FullName + ".DeleteDigitalSignatures");
		
		Query.Text = Query.Text + CurrentQueryText;
	EndDo;
	
	RefsArray = Query.Execute().Unload().UnloadColumn("Ref"); 
	
	InfobaseUpdate.MarkForProcessing(Parameters, RefsArray);
	
EndProcedure

Procedure MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters(Parameters) Export
	
	ProcessingCompleted = True;
	
	FullCatalogsNames = FullCatalogsNamesOfAttachedFiles();
	
	For Each FullCatalogName In FullCatalogsNames Do
		MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegistersForTable(Parameters,
			FullCatalogName, ProcessingCompleted);
	EndDo;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Function FullCatalogsNamesOfAttachedFiles() Export
	
	Array = New Array;
	
	For Each AttachedFileType In Metadata.DefinedTypes.AttachedFile.Type.Types() Do
		FullName = Metadata.FindByType(AttachedFileType).FullName();
		If StrEndsWith(Upper(FullName), Upper("AttachedFilesVersions")) Then
			Continue;
		EndIf;
		Array.Add(Metadata.FindByType(AttachedFileType).FullName());
	EndDo;
	
	If Array.Find("Catalog.Files") = Undefined Then
		Array.Add("Catalog.Files");
	EndIf;
	
	If Array.Find("Catalog.FilesVersions") = Undefined Then
		Array.Add("Catalog.FilesVersions");
	EndIf;
	
	Return Array;
	
EndFunction

Function ObjectsToModifyOnTransferDigitalSignaturesAndEncryptionResults() Export
	
	Return Metadata.InformationRegisters["DigitalSignatures"].FullName() + ", "
	      + Metadata.InformationRegisters["EncryptionCertificates"].FullName();
	
EndFunction

// Allows you to move items of the DeleteDigitalSignatures and DeleteEncryptionCertificates tabular 
// sections to the DigitalSignatures and EncryptionCertificates information registers.
//
// Parameters:
//  UpdateParameters        - Structure - structure of deferred update handler parameters.
//
//  FullMetadataObjectName - String - a full name of metadata object, from which tabular section data is moved.
//                                        DeleteDigitalSignatures and DeleteEncryptionCertificates.
//  ProcessingCompleted         - Boolean - True if all data is processed when updating the infobase.
//
Procedure MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegistersForTable(UpdateParameters, FullMetadataObjectName, ProcessingCompleted)
	
	MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
	
	If MetadataObject = Undefined Then
		Raise NStr("ru = 'Не указан объект для обработки электронных подписей и сертификатов шифрования.'; en = 'Object for processing digital signatures and encryption certificates is not specified.'; pl = 'Nie jest określony obiekt do obsługi podpisów cyfrowych i certyfikatów szyfrowania.';es_ES = 'No está indicado un objeto de procesar las firmas electrónicas y los certificados de cifrado.';es_CO = 'No está indicado un objeto de procesar las firmas electrónicas y los certificados de cifrado.';tr = 'E-imzaları ve şifreleme sertifikalarını işlemek için nesne belirtilmedi.';it = 'Non è indicato un oggetto per l''elaborazione delle firme elettroniche e dei certificati di cifratura.';de = 'Das Objekt zur Verarbeitung von digitalen Signaturen und Verschlüsselungszertifikaten ist nicht spezifiziert.'");
	EndIf;
	
	HasTabularSectionOfDigitalSignature = MetadataObject.TabularSections.Find("DeleteDigitalSignatures") <> Undefined;
	HasTabularSectionOfEncryptionCertificate = MetadataObject.TabularSections.Find("DeleteEncryptionCertificates") <> Undefined;
	
	ReferencesSelection = InfobaseUpdate.SelectRefsToProcess(UpdateParameters.PositionInQueue, FullMetadataObjectName);
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	RefsArray = New Array;
	
	BeginTransaction();
	Try
		While ReferencesSelection.Next() Do
			RefsArray.Add(ReferencesSelection.Ref);
		EndDo;
		
		If HasTabularSectionOfDigitalSignature Then
			MoveDigitalSignatureDataToInformationRegister(RefsArray,
				FullMetadataObjectName, MetadataObject);
		EndIf;
		
		If HasTabularSectionOfEncryptionCertificate Then
			MoveCertificatesDataToInformationRegister(RefsArray, FullMetadataObjectName);
		EndIf;
		
		For Each ObjectWithDigitalSignature In RefsArray Do
			InfobaseUpdate.MarkProcessingCompletion(ObjectWithDigitalSignature);
		EndDo;
		ObjectsProcessed = RefsArray.Count();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		// If you cannot process an object, try again.
		ObjectsWithIssuesCount = ObjectsWithIssuesCount + RefsArray.Count();
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось обработать объект: %1 по причине:
			           |%2'; 
			           |en = 'Cannot process the object: %1 due to:
			           |%2'; 
			           |pl = 'Nie udało się przetworzyć obiekt: %1 z powodu:
			           |%2';
			           |es_ES = 'No se ha podido procesar el objeto: %1 a causa de:
			           |%2';
			           |es_CO = 'No se ha podido procesar el objeto: %1 a causa de:
			           |%2';
			           |tr = 'Nesne işlenemedi: %1 Nedeni: 
			           |%2';
			           |it = 'Impossibile elaborare l''oggetto: %1 a causa di:
			           |%2';
			           |de = 'Das Objekt konnte nicht verarbeitet werden: %1 aus folgendem Grund:
			           |%2'"),
			MetadataObject,
			DetailErrorDescription(ErrorInfo()));
		
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Warning, MetadataObject, , MessageText);
	EndTry;
	
	If Not InfobaseUpdate.DataProcessingCompleted(UpdateParameters.PositionInQueue, FullMetadataObjectName) Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедуре MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters не удалось обработать некоторые объекты (пропущены): %1'; en = 'The MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters procedure cannot process some objects (skipped): %1'; pl = 'Procedurze MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters nie udało się opracować niektóre obiekty (pominięte): %1';es_ES = 'El procedimiento MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters no ha podido procesar unos objetos (saltados): %1';es_CO = 'El procedimiento MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters no ha podido procesar unos objetos (saltados): %1';tr = 'MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters işlemi bazı nesneleri işleyemedi (atlandı): %1';it = 'La procedura TrasferireFirmeElettronicheECertificatiDiCifraturaNeiRegistriInformazioni non è stata in grado di elaborare alcuni oggetti (ignorati): %1';de = 'Die Prozedur MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters kann einige Objekte nicht verarbeiten (übersprungen): %1'"),
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information,
			MetadataObject,
			,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Процедура MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters обработала очередную порцию объектов: %1'; en = 'The MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters procedure has processed objects: %1'; pl = 'Procedura MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters przetworzyła obiekty: %1';es_ES = 'El procedimiento MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters ha procesado una porción de objetos: %1';es_CO = 'El procedimiento MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters ha procesado una porción de objetos: %1';tr = 'MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters işlemi sıradaki nesne partisini işledi: %1';it = 'La procedura TrasferireFirmeElettronicheECertificatiDiCifraturaNeiRegistriInformazioni ha elaborato un ulteriore porzione di oggetti: %1';de = 'Die Prozedur MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters hat Objekte verarbeitet: %1'"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

// For the MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegistersForTable procedure.
Procedure MoveDigitalSignatureDataToInformationRegister(ObjectsArray, FullMetadataObjectName, MetadataObject)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TabularSectionDigitalSignatures.Ref AS SignedObject,
	|	TabularSectionDigitalSignatures.SignatureDate,
	|	TabularSectionDigitalSignatures.SignatureFileName,
	|	TabularSectionDigitalSignatures.Comment,
	|	TabularSectionDigitalSignatures.CertificateOwner,
	|	TabularSectionDigitalSignatures.Thumbprint,
	|	TabularSectionDigitalSignatures.Signature,
	|	TabularSectionDigitalSignatures.SignatureSetBy,
	|	TabularSectionDigitalSignatures.LineNumber AS SequenceNumber,
	|	TabularSectionDigitalSignatures.Certificate, 
	|	TabularSectionDigitalSignatures.SignatureCorrect AS SignatureCorrect,
	|	TabularSectionDigitalSignatures.SignatureValidationDate AS SignatureValidationDate
	|FROM
	|	" + FullMetadataObjectName + ".DeleteDigitalSignatures AS TabularSectionDigitalSignatures
	|WHERE
	|	TabularSectionDigitalSignatures.Ref IN(&ObjectsArray)
	|TOTALS
	|	BY SignedObject";
	
	If MetadataObject = Metadata.Catalogs.FilesVersions Then
		Query.Text = StrReplace(Query.Text,
			"TabularSectionDigitalSignatures.Ref AS SignedObject",
			"TabularSectionDigitalSignatures.Ref.Owner AS SignedObject");
	EndIf;
	
	TSAttributes = MetadataObject.TabularSections.DeleteDigitalSignatures.Attributes;
	
	If TSAttributes.Find("SignatureCorrect") = Undefined Then
		Query.Text = StrReplace(Query.Text, "TabularSectionDigitalSignatures.SignatureCorrect", "FALSE");
	EndIf;
	
	If TSAttributes.Find("SignatureValidationDate") = Undefined Then
		Query.Text = StrReplace(Query.Text, "TabularSectionDigitalSignatures.SignatureValidationDate", "Undefined");
	EndIf;
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	DataExported = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	For Each Row In DataExported.Rows Do
		If Not ValueIsFilled(Row.SignedObject) Then
			Continue;
		EndIf;
		RecordSet = InformationRegisters["DigitalSignatures"].CreateRecordSet();
		RecordSet.Filter.SignedObject.Set(Row.SignedObject);
		For Each Substring In Row.Rows Do
			FillPropertyValues(RecordSet.Add(), Substring);
		EndDo;
		// A parallel update with a non-standard mark of data processing execution is used.
		RecordSet.DataExchange.Load = True;
		RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		RecordSet.DataExchange.Recipients.AutoFill = False;
		RecordSet.Write();
	EndDo;
	
EndProcedure

// For the MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegistersForTable procedure.
Procedure MoveCertificatesDataToInformationRegister(ObjectsArray, FullMetadataObjectName)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TabularSectionEncryptionCertificates.Ref AS EncryptedObject,
	|	TabularSectionEncryptionCertificates.Thumbprint,
	|	TabularSectionEncryptionCertificates.Certificate,
	|	TabularSectionEncryptionCertificates.LineNumber AS SequenceNumber,
	|	TabularSectionEncryptionCertificates.Presentation
	|FROM
	|	" + FullMetadataObjectName + ".DeleteEncryptionCertificates AS TabularSectionEncryptionCertificates
	|WHERE
	|	TabularSectionEncryptionCertificates.Ref IN(&ObjectsArray)
	|TOTALS
	|	BY EncryptedObject";
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	DataExported = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	For Each Row In DataExported.Rows Do
		RecordSet = InformationRegisters["EncryptionCertificates"].CreateRecordSet();
		RecordSet.Filter.EncryptedObject.Set(Row.EncryptedObject);
		For Each Substring In Row.Rows Do
			FillPropertyValues(RecordSet.Add(), Substring);
		EndDo;
		// A parallel update with a non-standard mark of data processing execution is used.
		RecordSet.DataExchange.Load = True;
		RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
		RecordSet.DataExchange.Recipients.AutoFill = False;
		RecordSet.Write();
	EndDo;
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////
///// Common file functions
// See this procedure in the FilesOperationsInternal module.
Procedure RecordTextExtractionResult(FileOrVersionRef,
                                            ExtractionResult,
                                            TempTextStorageAddress) Export
	
	FilesOperationsInternal.RecordTextExtractionResult(
		FileOrVersionRef,
		ExtractionResult,
		TempTextStorageAddress);
	
EndProcedure

// For internal use only.
Procedure CheckSignatures(SourceData, RowsData) Export
	
	SignatureValidationDate = CurrentSessionDate();
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	
	CryptoManager = ModuleDigitalSignature.CryptoManager("SignatureCheck");
	
	For each SignatureRow In RowsData Do
		ErrorDescription = "";
		SignatureCorrect = ModuleDigitalSignature.VerifySignature(CryptoManager,
			SourceData, SignatureRow.SignatureAddress, ErrorDescription, SignatureRow.SignatureDate);
		
		SignatureRow.SignatureValidationDate = CurrentSessionDate();
		SignatureRow.SignatureCorrect   = SignatureCorrect;
		SignatureRow.ErrorDescription = ErrorDescription;
		
		FilesOperationsInternalClientServer.FillSignatureStatus(SignatureRow);
	EndDo;
	
EndProcedure

// Returns number ascending. Take the previous value from the ScannedFilesNumbers information register.
// Parameters:
// Owner - AnyRef - a file owner.
//
// Returns:
//   Number  - a new number for scanning.
//
Function GetNewNumberToScan(Owner) Export
	
	// Prepare a filter structure by dimensions.
	FilterStructure = New Structure;
	FilterStructure.Insert("Owner", Owner);
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.ScannedFilesNumbers");
		LockItem.SetValue("Owner", Owner);
		Lock.Lock();
	
		// Receive structure with the data of record resources.
		ResourcesStructure = InformationRegisters.ScannedFilesNumbers.Get(FilterStructure);
		
		// Receive the max number from the register.
		Number = ResourcesStructure.Number;
		Number = Number + 1; // increasing by 1
		
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		
		// Writing a new number to the register.
		RecordSet = InformationRegisters.ScannedFilesNumbers.CreateRecordSet();
		
		RecordSet.Filter.Owner.Set(Owner);
		
		NewRecord = RecordSet.Add();
		NewRecord.Owner = Owner;
		NewRecord.Number = Number;
		
		RecordSet.Write();
		
		SetPrivilegedMode(False);
		SetSafeModeDisabled(False);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Number;
	
EndFunction

// Enters the number to the ScannedFilesNumbers information register.
//
// Parameters:
// Owner - AnyRef - a file owner.
// NewNumber -  Number  - max number for scanning.
//
Procedure EnterMaxNumberToScan(Owner, NewNumber) Export
	
	// Prepare a filter structure by dimensions.
	FilterStructure = New Structure;
	FilterStructure.Insert("Owner", Owner);
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.ScannedFilesNumbers");
		LockItem.SetValue("Owner", Owner);
		Lock.Lock();   		
		
		// Receive structure with the data of record resources.
		ResourcesStructure = InformationRegisters.ScannedFilesNumbers.Get(FilterStructure);
		   
		// Receive the max number from the register.
		Number = ResourcesStructure.Number;
		If NewNumber <= Number Then // Somebody has already written the bigger number.
			RollbackTransaction();
			Return;
		EndIf;
		
		Number = NewNumber;
		
		// Writing a new number to the register.
		RecordSet = InformationRegisters.ScannedFilesNumbers.CreateRecordSet();
		
		RecordSet.Filter.Owner.Set(Owner);
		
		NewRecord = RecordSet.Add();
		NewRecord.Owner = Owner;
		NewRecord.Number = Number;
		
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function PutFilesInTempStorage(Parameters) Export
	
	Var ZipFileWriter, ArchiveName;
	
	Result = New Array;
	
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	UsedFilesNames = New Map;
	
	For Each FileAttachment In Parameters.FilesArray Do
		FilesOperationsInternal.GenerateFilesListToSendViaEmail(Result, FileAttachment, Parameters.FormID);
	EndDo;
	
	Return Result;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////////
// Print the spreadsheet document with the digital signature stamp.

Function SpreadsheetDocumentWithStamp(FileRef, Ref) Export
	
	FileData    = FilesOperations.FileData(FileRef);
	TempFile = GetTempFileName(".mxl");
	BinaryData = GetFromTempStorage(FileData.BinaryFileDataRef);
	BinaryData.Write(TempFile);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(TempFile);
	
	DeleteFiles(TempFile);
	
	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	
	StampParameters = New Structure;
	StampParameters.Insert("MarkText", "");
	StampParameters.Insert("Logo");
	
	DigitalSignatures = ModuleDigitalSignature.SetSignatures(Ref);
	
	FileOwner = Common.ObjectAttributeValue(Ref, "FileOwner");
	
	FileInfo = New Structure;
	FileInfo.Insert("FileOwner", FileOwner);
	
	Stamps = New Array;
	For Each Signature In DigitalSignatures Do
		Certificate = Signature.Certificate;
		CryptoCertificate = New CryptoCertificate(Certificate.Get());
		FilesOperationsOverridable.OnPrintFileWithStamp(StampParameters, CryptoCertificate);
		
		Stamp = ModuleDigitalSignature.DigitalSignatureVisualizationStamp(CryptoCertificate,
			Signature.SignatureDate, StampParameters.MarkText, StampParameters.Logo);
		Stamps.Add(Stamp);
	EndDo;
	
	ModuleDigitalSignature.AddStampsToSpreadsheetDocument(SpreadsheetDocument, Stamps);
	
	Return SpreadsheetDocument;
EndFunction

#EndRegion
