#Region Internal

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.FileSynchronizationAccounts.FullName(), "");
EndProcedure

// Used when exporting files to go to the service (STL).
//
Procedure ExportFile(Val FileObject, Val NewFileName) Export
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		
		FullPath = FullVolumePath(FileObject.Volume) + FileObject.PathToFile;
		FileCopy(FullPath, NewFileName);
		
	Else // Enums.FilesStorageTypes.InInfobase
		
		FileBinaryData = FilesOperations.FileBinaryData(FileObject.Ref);
		FileBinaryData.Write(NewFileName);
		
	EndIf;
	
	FillFilePathOnSend(FileObject);
	
EndProcedure

// Used when importing files to go to the service (STL).
//
Procedure LoadFile(Val FileObject, Val PathToFile) Export
	
	BinaryData = New BinaryData(PathToFile);
	
	If FilesStorageTyoe() = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		
		If TypeOf(FileObject.Ref) = Type("CatalogRef.FilesVersions") Then
			VersionNumber = FileObject.VersionNumber;
		Else
			VersionNumber = "";
		EndIf;
		
		// Adding file to a volume with sufficient free space
		FileInfo = AddFileToVolume(BinaryData, 
			FileObject.UniversalModificationDate, FileObject.Description, FileObject.Extension,
			VersionNumber, FilePathOnGetHasFlagEncrypted(FileObject));
		
		FileObject.Volume = FileInfo.Volume;
		FileObject.PathToFile = FileInfo.PathToFile;
		FileObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive;
		FileObject.StorageFile = New ValueStorage(Undefined);
		
	Else
		
		FileObject.AdditionalProperties.Insert("FileBinaryData", BinaryData);
		FileObject.StorageFile = New ValueStorage(Undefined);
		FileObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
		FileObject.PathToFile = "";
		FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures used for data exchange.

// Returns the array of catalogs that own files.
//
// Returns: Array (MetadataObject).
//
Function FilesCatalogs() Export
	
	Result = New Array();
	
	MetadataCollections = New Array();
	MetadataCollections.Add(Metadata.Catalogs);
	MetadataCollections.Add(Metadata.Documents);
	MetadataCollections.Add(Metadata.BusinessProcesses);
	MetadataCollections.Add(Metadata.Tasks);
	MetadataCollections.Add(Metadata.ChartsOfAccounts);
	MetadataCollections.Add(Metadata.ExchangePlans);
	MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
	
	For Each MetadataCollection In MetadataCollections Do
		
		For Each MetadataObject In MetadataCollection Do
			
			ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
			BlankRef = ObjectManager.EmptyRef();
			FileStorageCatalogNames = FileStorageCatalogNames(BlankRef, True);
			
			For Each FileStoringCatalogName In FileStorageCatalogNames Do
				Result.Add(Metadata.Catalogs[FileStoringCatalogName.Key]);
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Result.Add(Metadata.Catalogs.FilesVersions);
	
	Return Result;
	
EndFunction

// Returns an array of metadata objects used for storing binary file data in the infobase.
// 
//
// Returns: Array (MetadataObject).
//
Function InfobaseFileStoredObjects() Export
	
	Result = New Array();
	Result.Add(Metadata.InformationRegisters.FilesBinaryData);
	Return Result;
	
EndFunction

// Returns a file extension.
//
// Object - CatalogObject,
//
Function FileExtention(Object) Export
	
	Return Object.Extension;
	
EndFunction

// Returns objects that have attached files (using the "File operations" subsystem).
//
// Used together with the AttachedFiles.ConvertFilesInAttached() function.
//
// Parameters:
//  FilesOwnersTable - String - a full name of metadata that can own attached files.
//                            
//
Function ReferencesToObjectsWithFiles(Val FilesOwnersTable) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ObjectsWithFiles.Ref AS Ref
	|FROM
	|	&Table AS ObjectsWithFiles
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				Catalog.Files AS Files
	|			WHERE
	|				Files.FileOwner = ObjectsWithFiles.Ref)";
	
	Query.Text = StrReplace(Query.Text, "&Table", FilesOwnersTable);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Checks the current user right when using the limit for a folder or file.
// 
//
// Parameters:
//   Folder - CatalogRef.FilesFolders, CatalogRef.Files - a file folder.
//       - CatalogRef - owner of the files.
//
// Usage locations:
//   ReportsMailing.FillMailingParametersWithDefaultParameters().
//   Catalog.ReportsMailings.Forms.ItemForm.FolderAndFilesChangeRight().
//
Function RightToAddFilesToFolder(Folder) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		Return ModuleAccessManagement.HasRight("AddFiles", Folder);
	EndIf;
	
	Return True;
	
EndFunction

// Writes attachments to a folder.
// 
// Parameters: see the ExecuteDelivery procedure description of the ReportsMailing module.
//
Procedure OnExecuteDeliveryToFolder(DeliveryParameters, Attachments) Export
	
	// Transfer attachments to the table
	SetPrivilegedMode(True);
	
	AttachmentsTable = New ValueTable;
	AttachmentsTable.Columns.Add("FileName",              New TypeDescription("String"));
	AttachmentsTable.Columns.Add("FullFilePath",      New TypeDescription("String"));
	AttachmentsTable.Columns.Add("File",                  New TypeDescription("File"));
	AttachmentsTable.Columns.Add("FileRef",            New TypeDescription("CatalogRef.Files"));
	AttachmentsTable.Columns.Add("FileNameWithoutExtension", Metadata.Catalogs.Files.StandardAttributes.Description.Type);
	
	SetPrivilegedMode(False);
	
	For Each Attachment In Attachments Do
		TableRow = AttachmentsTable.Add();
		TableRow.FileName              = Attachment.Key;
		TableRow.FullFilePath      = Attachment.Value;
		TableRow.File                  = New File(TableRow.FullFilePath);
		TableRow.FileNameWithoutExtension = TableRow.File.BaseName;
	EndDo;
	
	// Searching the existing files
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	Files.Ref,
	|	Files.Description
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner
	|	AND Files.Description IN(&FileNamesArray)";
	
	Query.SetParameter("FileOwner", DeliveryParameters.Folder);
	Query.SetParameter("FileNamesArray", AttachmentsTable.UnloadColumn("FileNameWithoutExtension"));
	
	ExistingFiles = Query.Execute().Unload();
	For Each File In ExistingFiles Do
		TableRow = AttachmentsTable.Find(File.Description, "FileNameWithoutExtension");
		TableRow.FileRef = File.Ref;
	EndDo;
	
	Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Рассылка отчетов ""%1"", %2'; en = 'Report distribution ""%1"", %2'; pl = 'Wysyłka raportów ""%1"", %2';es_ES = 'Distribución del informe ""%1"", %2';es_CO = 'Distribución del informe ""%1"", %2';tr = 'Rapor dağıtımı ""%1"", %2';it = 'Distribuzione report ""%1"", %2';de = 'Berichtsverteilung %1, %2'"),
		"'"+ DeliveryParameters.BulkEmail +"'",
		Format(DeliveryParameters.ExecutionDate, "DLF=DT"));
	
	For Each Attachment In AttachmentsTable Do
		
		FileInfo = FilesOperationsClientServer.FileInfo("FileWithVersion", Attachment.File);
		FileInfo.TempFileStorageAddress = PutToTempStorage(New BinaryData(Attachment.FullFilePath));
		FileInfo.BaseName = Attachment.FileNameWithoutExtension;
		FileInfo.Comment = Comment;
		
		// Record
		If ValueIsFilled(Attachment.FileRef) Then
			VersionRef = CreateVersion(Attachment.FileRef, FileInfo);
			UpdateVersionInFile(Attachment.FileRef, VersionRef, FileInfo.TempTextStorageAddress);
		Else
			Attachment.FileRef = FilesOperationsInternalServerCall.CreateFileWithVersion(DeliveryParameters.Folder, FileInfo); 
		EndIf;
		
		// Filling the reference to file
		If DeliveryParameters.AddReferences <> "" Then
			DeliveryParameters.RecipientReportsPresentation = StrReplace(
				DeliveryParameters.RecipientReportsPresentation,
				Attachment.FullFilePath,
				GetInfoBaseURL() + "#" + GetURL(Attachment.FileRef));
		EndIf;
		
		// Clearing
		DeleteFromTempStorage(FileInfo.TempFileStorageAddress);
	EndDo;
	
EndProcedure

// Sets a deletion mark for all versions of the specified file.
Procedure MarkForDeletionFileVersions(Val FileRef, Val VersionException) Export
	
	FullVersionsCatalogName = Metadata.FindByType(TypeOf(VersionException)).FullName();
	
	QueryText =
	"SELECT
	|	FilesVersions.Ref AS Ref
	|FROM
	|	Catalog." + Metadata.FindByType(FullVersionsCatalogName) + " AS FilesVersions
	|WHERE
	|	FilesVersions.Owner = &Owner
	|	AND NOT FilesVersions.DeletionMark
	|	AND FilesVersions.Ref <> &Except";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Owner", FileRef);
	Query.SetParameter("Except", VersionException);
	VersionsSelection = Query.Execute().Unload();
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		For Each Version In VersionsSelection Do
			LockItem = Lock.Add(FullVersionsCatalogName);
			LockItem.SetValue("Ref", Version.Ref);
		EndDo;
		Lock.Lock();
		
		For Each Version In VersionsSelection Do
			VersionObject = Version.Ref.GetObject();
			VersionObject.DeletionMark = True;
			VersionObject.AdditionalProperties.Insert("FileConversion", True);
			VersionObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns the map of catalog names and Boolean values for the specified owner.
// 
// 
// Parameters:
//  FilesOwher - Reference - an object for adding file.
// 
Function FileStorageCatalogNames(FilesOwner, DoNotRaiseException = False) Export
	
	If TypeOf(FilesOwner) = Type("Type") Then
		FilesOwnerType = FilesOwner;
	Else
		FilesOwnerType = TypeOf(FilesOwner);
	EndIf;
	
	OwnerMetadata = Metadata.FindByType(FilesOwnerType);
	
	CatalogNames = New Map;
	
	StandardMainCatalogName = OwnerMetadata.Name
		+ ?(StrEndsWith(OwnerMetadata.Name, "AttachedFiles"), "", "AttachedFiles");
		
	If Metadata.Catalogs.Find(StandardMainCatalogName) <> Undefined Then
		CatalogNames.Insert(StandardMainCatalogName, True);
	ElsIf Metadata.DefinedTypes.FilesOwner.Type.ContainsType(FilesOwnerType) Then
		CatalogNames.Insert("Files", True);
	EndIf;
	
	// Redefining the default catalog for attached file storage.
	FilesOperationsOverridable.OnDefineFileStorageCatalogs(
		FilesOwnerType, CatalogNames);
	
	DefaultCatalogIsSpecified = False;
	
	For each KeyAndValue In CatalogNames Do
		
		If Metadata.Catalogs.Find(KeyAndValue.Key) = Undefined Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при определении имен справочников для хранения файлов.
				           |У владельца файлов типа ""%1""
				           |указан несуществующий справочник ""%2"".'; 
				           |en = 'An error occurred when defining names of catalogs for file storage.
				           |Non-existing catalog ""%2""
				           |is specified for the owner of files of type ""%1"".'; 
				           |pl = 'Błąd przy ustalaniu nazw przewodników do przechowywania plików.
				           |U właściciela plików rodzaju ""%1""
				           |jest podany nieistniejący przewodnik ""%2"".';
				           |es_ES = 'Ha ocurrido un error al determinar los nombres de catálogos para guardar los archivos.
				           |En el propietario de archivos del ""%1""
				           |tipo el catálogo inexistente ""%2"" está especificado.';
				           |es_CO = 'Ha ocurrido un error al determinar los nombres de catálogos para guardar los archivos.
				           |En el propietario de archivos del ""%1""
				           |tipo el catálogo inexistente ""%2"" está especificado.';
				           |tr = 'Dosyaları depolamak için katalog adları belirlenirken bir hata oluştu. 
				           |"
" tür dosya sahibinde ""%1"" varolmayan %2 katalog belirtildi.';
				           |it = 'Si è verificato un errore durante la definizione dei nome dei cataloghi per l''archiviazione del file.
				           |Il catalogo inesistente ""%2""
				           |è indicato per il proprietario dei file di tipo ""%1"".';
				           |de = 'Fehler bei der Definition von Namen der Kataloge für die Dateiablage.
				           |Der Eigentümer des Dateityps ""%1""
				           |hat einen nicht existierendes Katalog ""%2"".'"),
				String(FilesOwnerType),
				String(KeyAndValue.Key));
				
		ElsIf Not StrEndsWith(KeyAndValue.Key, "AttachedFiles") AND Not KeyAndValue.Key ="Files" Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при определении имен справочников для хранения файлов.
				           |У владельца файлов типа ""%1""
				           |указано имя справочника ""%2""
				           |без окончания ""AttachedFiles"".'; 
				           |en = 'An error occurred when defining names of catalogs for file storage.
				           |Catalog name ""%2""
				           |without ending ""AttachedFiles""
				           |is specified for the file owner of type ""%1"".'; 
				           |pl = 'Błąd przy ustalaniu nazw katalogów do przechowywania plików.
				           |U właściciela plików ""%2""
				           |bez zakończenia ""AttachedFiles""
				           | ""%1"".';
				           |es_ES = 'Ha ocurrido un error al determinar los nombres de catálogos para guardar los archivos.
				           |En el propietario de archivos del tipo ""%1""
				           | el nombre del catálogo ""%2""
				           |está especificado sin acabar ""AttachedFiles"".';
				           |es_CO = 'Ha ocurrido un error al determinar los nombres de catálogos para guardar los archivos.
				           |En el propietario de archivos del tipo ""%1""
				           | el nombre del catálogo ""%2""
				           |está especificado sin acabar ""AttachedFiles"".';
				           |tr = 'Dosyaları depolamak için katalog adları belirlenirken bir hata oluştu. 
				           |"
" tür dosya sahibinde ""%1"" katalog 
				           |adı ""%2"" ""AttachedFiles"" takısı olmadan belirtildi.';
				           |it = 'Si è verificato un errore durante la definizione dei nome dei cataloghi per l''archiviazione file.
				           |Il nome del catalogo ""%2""
				           | che non finisce in ""AttachedFiles""
				           | è indicato per il proprietario del file di tipo ""%1"".';
				           |de = 'Bei der Definition von Namen der Kataloge für die Dateiablage ist ein Fehler aufgetreten.
				           |Der Katalogname ""%2""
				           |ohne Endung ""AttachedFiles""
				           |wird für den Dateibesitzer vom Typ ""%1"" angegeben.'"),
				String(FilesOwnerType),
				String(KeyAndValue.Key));
			
		ElsIf KeyAndValue.Value = Undefined Then
			CatalogNames.Insert(KeyAndValue.Key, False);
			
		ElsIf KeyAndValue.Value = True Then
			If DefaultCatalogIsSpecified Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Ошибка при определении имен справочников для хранения файлов.
					           |У владельца файлов типа ""%1""
					           |основной справочник указан более одного раза.'; 
					           |en = 'An error occurred when defining names of catalogs for file storage.
					           |The main catalog is specified more than once for the owner of files of type
					           |""%1"".'; 
					           |pl = 'Błąd przy ustalaniu nazw przewodników do przechowywania plików.
					           |U właściciela plików rodzaju ""%1""
					           |podstawowy przewodnik został podany więcej niż jeden raz.';
					           |es_ES = 'Ha ocurrido un error al determinar los nombre de catálogos para guardar los archivos.
					           |El propietario de archivos del tipo ""%1""
					           |tiene el catálogo principal especificado más de una vez.';
					           |es_CO = 'Ha ocurrido un error al determinar los nombre de catálogos para guardar los archivos.
					           |El propietario de archivos del tipo ""%1""
					           |tiene el catálogo principal especificado más de una vez.';
					           |tr = 'Dosyaları depolamak için katalog adları belirlenirken bir hata oluştu. 
					           | "
"tür dosya sahibi %1 ana katalog birden fazla kez belirtildi.';
					           |it = 'Si è verificato un errore durante la definizione dei nomi dei cataloghi per l''archiviazione dei file.
					           |Il catalogo principale è indicato più di una volta per il proprietario dei file di tipo
					           |""%1"".';
					           |de = 'Fehler bei der Definition von Namen der Kataloge für die Dateiablage.
					           |Der Eigentümer von Dateien vom Typ ""%1""
					           |hat den Hauptkatalog mehr als einmal.'"),
					String(FilesOwnerType),
					String(KeyAndValue.Key));
			EndIf;
			DefaultCatalogIsSpecified = True;
		EndIf;
	EndDo;
	
	If CatalogNames.Count() = 0 Then
		
		If DoNotRaiseException Then
			Return CatalogNames;
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при определении имен справочников для хранения файлов.
			           |У владельца файлов типа ""%1""
			           |не имеется справочников для хранения файлов.'; 
			           |en = 'An error occurred when defining catalog names for storing the files.
			           |The owner of files of type ""%1""
			           |does not have catalogs for storing files.'; 
			           |pl = 'Błąd przy ustalaniu nazw przewodników do przechowywania plików.
			           |U właściciela plików rodzaju ""%1""
			           |nie ma poradników do przechowywania plików.';
			           |es_ES = 'Ha ocurrido un error al determinar los nombre de catálogos para guardar los archivos.
			           |El propietario de archivos del tipo ""%1""
			           |no tiene catálogos para guardar los archivos.';
			           |es_CO = 'Ha ocurrido un error al determinar los nombre de catálogos para guardar los archivos.
			           |El propietario de archivos del tipo ""%1""
			           |no tiene catálogos para guardar los archivos.';
			           |tr = 'Dosyaları depolamak için katalog adları belirlenirken bir hata oluştu. 
			           |""
			           |%1"" tür dosya sahibinin dosyaların depolanacağı katalogları yok.';
			           |it = 'Si è verificato un errore durante la definizione dei nomi del catalogo per l''archiviazione dei file.
			           |Il proprietario di file del tipo ""%1""
			           |non ha cataloghi per l''archiviazione dei file.';
			           |de = 'Fehler bei der Definition von Namen der Kataloge für die Dateiablage.
			           |Der ""%1""
			           |Dateieigentümer hat keine Kataloge zum Speichern von Dateien.'"),
			String(FilesOwnerType));
	EndIf;
	
	Return CatalogNames;
	
EndFunction

// Creates copies of all Source attached files for the Recipient.
// Source and Recipient must be objects of the same type.
//
// Parameters:
//  Source   - Reference - an object with attached files for copying.
//  Recipient - Reference - an object, to which the attached files are copied to.
//
Procedure CopyAttachedFiles(Val Source, Val Recipient) Export
	
	DigitalSignatureAvailable = Undefined;
	ModuleDigitalSignatureInternal = Undefined;
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	EndIf;
	
	CopiedFiles = AllSubordinateFiles(Source.Ref);
	For Each CopiedFile In CopiedFiles Do
		If DigitalSignatureAvailable = Undefined Then
			DigitalSignatureAvailable = (ModuleDigitalSignatureInternal <> Undefined) 
				AND (ModuleDigitalSignatureInternal.DigitalSignatureAvailable(TypeOf(CopiedFile)));
		EndIf;
		If Common.ObjectAttributeValue(CopiedFile, "DeletionMark") Then
			Continue;
		EndIf;
		BeginTransaction();
		Try
			ObjectManager = Common.ObjectManagerByRef(CopiedFile);
			FileCopy = CopiedFile.Copy();
			FileCopyRef = ObjectManager.GetRef();
			FileCopy.SetNewObjectRef(FileCopyRef);
			FileCopy.FileOwner = Recipient.Ref;
			FileCopy.BeingEditedBy = Catalogs.Users.EmptyRef();
			
			FileCopy.TextStorage = CopiedFile.TextStorage;
			FileCopy.TextExtractionStatus = CopiedFile.TextExtractionStatus;
			FileCopy.StorageFile = CopiedFile.StorageFile;
			
			BinaryData = FilesOperations.FileBinaryData(CopiedFile);
			FileCopy.FileStorageType = FilesStorageTyoe();
			
			If FilesStorageTyoe() = Enums.FileStorageTypes.InInfobase Then
				WriteFileToInfobase(FileCopyRef, BinaryData);
			Else
				// Add the file to a volume with sufficient free space.
				FileInfo = AddFileToVolume(BinaryData, FileCopy.UniversalModificationDate,
					FileCopy.Description, FileCopy.Extension);
				FileCopy.PathToFile = FileInfo.PathToFile;
				FileCopy.Volume = FileInfo.Volume;
			EndIf;
			FileCopy.Write();
			
			If DigitalSignatureAvailable Then
				SetSignatures = ModuleDigitalSignature.SetSignatures(CopiedFile);
				ModuleDigitalSignature.AddSignature(FileCopy.Ref, SetSignatures);
				
				SourceCertificates = ModuleDigitalSignature.EncryptionCertificates(CopiedFile);
				ModuleDigitalSignature.WriteEncryptionCertificates(FileCopy, SourceCertificates);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
EndProcedure

// Returns file object structure.
//
Function FileObject(Val AttachedFile) Export
	
	FileObject = Undefined;
	
	FileObjectMetadata = Metadata.FindByType(TypeOf(AttachedFile));
	
	// This is the file catalog.
	If Common.HasObjectAttribute("FileOwner", FileObjectMetadata) Then
		// With the ability to store versions.
		If Common.HasObjectAttribute("CurrentVersion", FileObjectMetadata) AND ValueIsFilled(AttachedFile.CurrentVersion) Then
			FileObject = Common.ObjectAttributesValues(AttachedFile.CurrentVersion, 
					"Ref, FileStorageType, Description,Extension,Volume,PathToFile");
			FileObject.Insert("FileOwner", AttachedFile.FileOwner);
		// Without the ability to store versions.
		Else
			FileObject = Common.ObjectAttributesValues(AttachedFile, 
				"Ref, FileStorageType,FileOwner,Description,Extension,Volume,PathToFile");
		EndIf;
	// This is a catalog of file versions.
	ElsIf Common.HasObjectAttribute("ParentVersion", FileObjectMetadata) Then
		FileObject = Common.ObjectAttributesValues(AttachedFile, 
			"Ref, FileStorageType,Description,Extension,Volume,PathToFile");
		FileObject.Insert("FileOwner",
			Common.ObjectAttributeValue(AttachedFile.Owner, "FileOwner"));
	EndIf;
	
	Return FileObject;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Clear unused files

Function QueryTextToClearFiles(FileOwner, Setting, ExceptionsArray, ExceptionItem, DataForReport = False) Export
	
	FullFilesCatalogName = Setting.FileOwnerType.FullName;
	FilesObjectMetadata = Metadata.FindByFullName(FullFilesCatalogName);
	HasAbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", FilesObjectMetadata);
	If HasAbilityToStoreVersions Then
		CatalogFilesVersions = Common.MetadataObjectID(FilesObjectMetadata.Attributes.CurrentVersion.Type.Types()[0]);
		FullFilesVersionsCatalogName = CatalogFilesVersions.FullName;
		
		If Setting.ClearingPeriod <> Enums.FilesCleanupPeriod.ByRule Then
			If DataForReport Then
				QueryText = 
				"SELECT 
				|	VALUETYPE(Files.FileOwner) AS FileOwner,
				|	FilesVersions.Size /1024 /1024 AS IrrelevantFilesVolume";
			Else
				QueryText = 
				"SELECT 
				|	Files.Ref AS FileRef,
				|	FilesVersions.Ref AS VersionRef";
			EndIf;
			QueryText = QueryText + "
			|FROM
			|	" + FullFilesCatalogName + " AS Files
			|		INNER JOIN " + FullFilesVersionsCatalogName + " AS FilesVersions
			|		ON Files.Ref = FilesVersions.Owner
			|WHERE
			|	FilesVersions.CreationDate <= &ClearingPeriod
			|	AND NOT Files.DeletionMark
			|	AND VALUETYPE(Files.FileOwner) = &OwnerType
			|	AND CASE
			|			WHEN FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
			|				THEN FilesVersions.Volume <> VALUE(Catalog.FileStorageVolumes.EmptyRef)
			|						OR (CAST(FilesVersions.PathToFile AS STRING(100))) <> """"
			|			ELSE TRUE
			|		END
			|	";
		Else
			AttributesArrayWithDateType = New Array;
			
			ObjectType = FileOwner;
			AllCatalogs = Catalogs.AllRefsType();
			AllDocuments = Documents.AllRefsType();
			HasTypeDate = False;
			
			QueryText = 
			"SELECT
			|	" + ObjectType.Name + ".Ref,";
			If AllCatalogs.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
				Catalog = Metadata.Catalogs[ObjectType.Name];
				For Each Attribute In Catalog.Attributes Do
					QueryText = QueryText + Chars.LF + ObjectType.Name + "." + Attribute.Name + ",";
				EndDo;
			ElsIf  
				AllDocuments.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
				Document = Metadata.Documents[ObjectType.Name];
				For Each Attribute In Document.Attributes Do
					If Attribute.Type = New TypeDescription("Date") Then
						QueryText = QueryText + Chars.LF + "DATEDIFF(" + Attribute.Name + ", &CurrentDate, DAY) AS DaysBeforeDeletionFrom" + Attribute.Name + ",";
					EndIf;
					QueryText = QueryText + Chars.LF + ObjectType.Name + "." + Attribute.Name + ",";
				EndDo;
			EndIf;
			If DataForReport Then
				QueryText = QueryText + "
				|	VALUETYPE(Files.FileOwner) AS FileOwner,
				|	FilesVersions.Size /1024 /1024 AS IrrelevantFilesVolume";
			Else
				QueryText = QueryText + "
				|	Files.Ref AS FileRef,
				|	FilesVersions.Ref AS VersionRef";
			EndIf;
			QueryText = QueryText + "
			|FROM
			|	" + ObjectType.FullName+ " AS " + ObjectType.Name + "
			|	INNER JOIN "+ FullFilesCatalogName + " AS Files
			|			INNER JOIN " + FullFilesVersionsCatalogName + " AS FilesVersions
			|			ON Files.Ref = FilesVersions.Owner
			|		ON " + ObjectType.Name + ".Ref = Files.FileOwner
			|WHERE
			|	NOT Files.DeletionMark
			|	AND NOT ISNULL(FilesVersions.DeletionMark, False)
			|	AND CASE
			|			WHEN FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
			|				THEN FilesVersions.Volume <> VALUE(Catalog.FileStorageVolumes.EmptyRef)
			|						OR (CAST(FilesVersions.PathToFile AS STRING(100))) <> """"
			|			ELSE TRUE
			|		END
			|	AND VALUETYPE(Files.FileOwner) = &OwnerType";
		EndIf;
	Else
		If Setting.ClearingPeriod <> Enums.FilesCleanupPeriod.ByRule Then
			If DataForReport Then
				QueryText = 
				"SELECT
				|	VALUETYPE(Files.FileOwner) AS FileOwner,
				|	Files.Size /1024 /1024 AS IrrelevantFilesVolume";
			Else
				QueryText = 
				"SELECT
				|	Files.Ref AS FileRef";
			EndIf;
			QueryText = QueryText + "
			|FROM
			|	Catalog." + Setting.FileOwnerType.Name + " AS Files
			|		INNER JOIN " + FileOwner.FullName + " AS CatalogFiles
			|		ON Files.FileOwner = CatalogFiles.Ref
			|WHERE
			|	Files.CreationDate <= &ClearingPeriod
			|	AND NOT Files.DeletionMark
			|	AND CASE
			|			WHEN Files.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
			|				THEN (CAST(Files.PathToFile AS STRING(100))) <> """"
			|						OR NOT Files.Volume = VALUE(Catalog.FileStorageVolumes.EmptyRef)
			|			ELSE TRUE
			|		END
			|	AND VALUETYPE(Files.FileOwner) = &OwnerType
			|	";
		Else
			AttributesArrayWithDateType = New Array;
			
			ObjectType = FileOwner;
			AllCatalogs = Catalogs.AllRefsType();
			AllDocuments = Documents.AllRefsType();
			HasTypeDate = False;
			QueryText = 
			"SELECT
			|	CatalogFiles.Ref,
			|	VALUETYPE(Files.FileOwner) AS FileOwner,
			|	Files.Size /1024 /1024 AS IrrelevantFilesVolume,";
			If AllCatalogs.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
				Catalog = Metadata.Catalogs[ObjectType.Name];
				For Each Attribute In Catalog.Attributes Do
					QueryText = QueryText + Chars.LF + "CatalogFiles." + Attribute.Name + ",";
				EndDo;
			ElsIf AllDocuments.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
				Document = Metadata.Documents[ObjectType.Name];
				For Each Attribute In Document.Attributes Do
					If Attribute.Type = New TypeDescription("Date") Then
						QueryText = QueryText + Chars.LF + "DATEDIFF(" + Attribute.Name + ", &CurrentDate, DAY) AS DaysBeforeDeletionFrom" + Attribute.Name + ",";
					EndIf;
					QueryText = QueryText + Chars.LF + "CatalogFiles." + Attribute.Name + ",";
				EndDo;
			EndIf;
			QueryText = QueryText + "
			|	Files.Ref AS FileRef
			|FROM
			|	Catalog." + Setting.FileOwnerType.Name + " AS Files
			|		LEFT JOIN " + FileOwner.FullName + " AS CatalogFiles
			|		ON Files.FileOwner = CatalogFiles.Ref
			|WHERE
			|	NOT Files.DeletionMark
			|	AND CASE
			|			WHEN Files.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
			|				THEN (CAST(Files.PathToFile AS STRING(100))) <> """"
			|						OR NOT Files.Volume = VALUE(Catalog.FileStorageVolumes.EmptyRef)
			|			ELSE TRUE
			|		END
			|	AND VALUETYPE(Files.FileOwner) = &OwnerType";
		EndIf;
	EndIf;
	
	If ExceptionsArray.Count() > 0 Then
		QueryText = QueryText + "
		|	AND NOT Files.FileOwner IN HIERARCHY (&ExceptionsArray)";
	EndIf;
	If ExceptionItem <> Undefined Then
		QueryText = QueryText + "
		|	AND Files.FileOwner IN HIERARCHY (&ExceptionItem)";
	EndIf;
	If HasAbilityToStoreVersions AND Setting.Action = Enums.FilesCleanupOptions.CleanUpVersions Then
		QueryText =  QueryText + "
		|	AND FilesVersions.Ref <> Files.CurrentVersion
		|	AND FilesVersions.ParentVersion <> VALUE(Catalog.FilesVersions.EmptyRef)";
	EndIf;
	
	Return QueryText;
	
EndFunction

Function FullFilesVolumeQueryText() Export
	MetadataCatalogs = Metadata.Catalogs;
	AddFieldAlias = True;
	QueryText = "";
	For Each Catalog In MetadataCatalogs Do
		If Catalog.Attributes.Find("FileOwner") <> Undefined Then
			
			FilesOwnersTypes = Catalog.Attributes.FileOwner.Type.Types();
			
			HasAbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", Catalog);
			If HasAbilityToStoreVersions Then
				CatalogFilesVersions =
					Common.MetadataObjectID(Catalog.Attributes.CurrentVersion.Type.Types()[0]);
				FullFilesVersionsCatalogName = CatalogFilesVersions.FullName;
			
				QueryText = QueryText + ?(IsBlankString(QueryText),"", " UNION ALL") + "
					|
					|SELECT
					|	VALUETYPE(Files.FileOwner) AS FileOwner,
					|	SUM(ISNULL(FilesVersions.Size, Files.Size) / 1024 / 1024) AS TotalFileSize
					|FROM
					|	Catalog." + Catalog.Name + " AS Files
					|		LEFT JOIN "+ FullFilesVersionsCatalogName + " AS FilesVersions
					|		ON Files.Ref = FilesVersions.Owner
					|WHERE
					|	NOT Files.DeletionMark
					|	AND NOT ISNULL(FilesVersions.DeletionMark, FALSE)
					|
					|GROUP BY
					|	VALUETYPE(Files.FileOwner)";
					
				If AddFieldAlias Then
					AddFieldAlias = False;
				EndIf;
			Else
				QueryText = QueryText + ?(IsBlankString(QueryText),"", " UNION ALL") + "
					|
					|SELECT
					|	VALUETYPE(Files.FileOwner) " + ?(AddFieldAlias, "AS FileOwner,",",") + "
					|	Files.Size / 1024 / 1024 " + ?(AddFieldAlias, "AS TotalFileSize","") + "
					|FROM
					|	Catalog." + Catalog.Name + " AS Files
					|WHERE
					|	NOT Files.DeletionMark";
				
				If AddFieldAlias Then
					AddFieldAlias = False;
				EndIf;
			EndIf;
				
		EndIf;
	EndDo;
	
	Return QueryText;
	
EndFunction

Function CheckFilesIntegrity(FilesTableOnHardDrive, Volume) Export
	
	MetadataCatalogs = Metadata.Catalogs;
	Query = New Query;
	FileTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	
	AddFieldAlias = True;
	
	For Each CatalogFiles In FileTypes Do
		CatalogMetadata = Metadata.FindByType(CatalogFiles);
		If CatalogMetadata.Attributes.Find("FileOwner") <> Undefined Then
			HasAbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", CatalogMetadata);
			
			Query.Text = Query.Text + ?(IsBlankString(Query.Text),"", " UNION ALL") + "
				|
				|SELECT
				|	CatalogAttachedFiles.Ref " + ?(AddFieldAlias, "AS Ref,",",") + "
				|	CatalogAttachedFiles.Extension " + ?(AddFieldAlias, "AS Extension,",",") + "
				|	CatalogAttachedFiles.Description " + ?(AddFieldAlias, "AS Description,",",") + "
				|	CatalogAttachedFiles.Volume " + ?(AddFieldAlias, "AS Volume,",",") + "
				|	CatalogAttachedFiles.Changed " + ?(AddFieldAlias, "AS WasEditedBy,",",") + "
				|	CatalogAttachedFiles.UniversalModificationDate " + ?(AddFieldAlias, "AS FileModificationDate,",",") + "
				|	CatalogAttachedFiles.PathToFile " + ?(AddFieldAlias, "AS PathToFile","") + "
				|FROM
				|	Catalog." + CatalogMetadata.Name + " AS CatalogAttachedFiles
				|WHERE
				|	CatalogAttachedFiles.Volume = &Volume
				|	AND CatalogAttachedFiles.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
				|	AND NOT CatalogAttachedFiles.DeletionMark";
			If HasAbilityToStoreVersions Then
				CatalogFilesVersions = Metadata.FindByType(CatalogMetadata.Attributes.CurrentVersion.Type.Types()[0]);
				Query.Text = Query.Text + "
					|	AND CatalogAttachedFiles.CurrentVersion = VALUE(Catalog." + CatalogFilesVersions.Name + ".EmptyRef)";
			EndIf;
			
			If AddFieldAlias Then
				AddFieldAlias = False;
			EndIf;
		ElsIf CatalogMetadata.Attributes.Find("ParentVersion") <> Undefined Then
			Query.Text = Query.Text + ?(IsBlankString(Query.Text),"", " UNION ALL") + "
				|
				|SELECT
				|	CatalogAttachedFiles.Ref " + ?(AddFieldAlias, "AS Ref,",",") + "
				|	CatalogAttachedFiles.Extension " + ?(AddFieldAlias, "AS Extension,",",") + "
				|	CatalogAttachedFiles.Description " + ?(AddFieldAlias, "AS Description,",",") + "
				|	CatalogAttachedFiles.Volume " + ?(AddFieldAlias, "AS Volume,",",") + "
				|	CatalogAttachedFiles.Author " + ?(AddFieldAlias, "AS WasEditedBy,",",") + "
				|	CatalogAttachedFiles.UniversalModificationDate " + ?(AddFieldAlias, "AS FileModificationDate,",",") + "
				|	CatalogAttachedFiles.PathToFile " + ?(AddFieldAlias, "AS PathToFile","") + "
				|FROM
				|	Catalog." + CatalogMetadata.Name + " AS CatalogAttachedFiles
				|WHERE
				|	CatalogAttachedFiles.Volume = &Volume
				|	AND CatalogAttachedFiles.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
				|	AND NOT CatalogAttachedFiles.DeletionMark";
			
			If AddFieldAlias Then
				AddFieldAlias = False;
			EndIf;
			
		EndIf;
	EndDo;

	Query.SetParameter("Volume", Volume);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	FullVolumePath = FullVolumePath(Volume);
	
	While Selection.Next() Do
		
		VersionRef = Selection.Ref;
		PathToFile   = Selection.PathToFile;
		
		If ValueIsFilled(Selection.PathToFile) AND ValueIsFilled(Selection.Volume) Then
			
			// Removing the extra point if the file has no extension.
			If VersionRef.Extension = "" AND StrEndsWith(PathToFile, ".") Then
				PathToFile = Left(PathToFile, StrLen(PathToFile) - 1);
			EndIf;
			
			FullFilePath = FullVolumePath + PathToFile;
			ExistingFile = FilesTableOnHardDrive.FindRows(New Structure("FullName", FullFilePath));
			
			If ExistingFile.Count() = 0 Then
				
				NonExistingFile = FilesTableOnHardDrive.Add();
				NonExistingFile.VerificationStatus = NStr("ru = 'Отсутствуют данные в томе на диске'; en = 'No data in volume on disk'; pl = 'Brak danych w woluminie na dysku';es_ES = 'No hay datos en el tomo en el disco';es_CO = 'No hay datos en el tomo en el disco';tr = 'Disk biriminde veri yok';it = 'Nessun dato nel volume sul disco';de = 'Keine Daten im Volume auf der Festplatte'");
				NonExistingFile.File = VersionRef;
				NonExistingFile.FullName = FullFilePath;
				NonExistingFile.Extension = VersionRef.Extension;
				NonExistingFile.Name = VersionRef.Description;
				NonExistingFile.Volume = Volume;
				NonExistingFile.WasEditedBy = Selection.WasEditedBy;
				NonExistingFile.EditDate = Selection.FileModificationDate;
				NonExistingFile.Count = 1;
				
			Else
				
				ExistingFile[0].File = VersionRef;
				ExistingFile[0].VerificationStatus = NStr("ru = 'Целостные данные'; en = 'Integral data'; pl = 'Holistyczne dane';es_ES = 'Datos enteros';es_CO = 'Datos enteros';tr = 'Bütünsel veriler';it = 'Dati integrali';de = 'Ganzheitliche Daten'");
				
			EndIf;
			
		EndIf;
		
	EndDo;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Managing file volumes

// Returns the file storage type.
// 
// Returns:
//  Boolean. If true, files are stored in volumes on the hard disk.
//
Function StoreFilesInVolumesOnHardDrive() Export
	
	SetPrivilegedMode(True);
	
	StoreFilesInVolumesOnHardDrive = Constants.StoreFilesInVolumesOnHardDrive.Get();
	
	Return StoreFilesInVolumesOnHardDrive;
	
EndFunction

// Returns the file storage type, which shows whether the files are stored in volumes.
// If there are no file storage volumes, files are stored in the infobase.
//
// Returns:
//  EnumsRef.FilesStorageTypes.
//
Function FilesStorageTyoe() Export
	
	SetPrivilegedMode(True);
	
	StoreFilesInVolumesOnHardDrive = Constants.StoreFilesInVolumesOnHardDrive.Get();
	
	If StoreFilesInVolumesOnHardDrive Then
		
		If FilesOperations.HasFileStorageVolumes() Then
			Return Enums.FileStorageTypes.InVolumesOnHardDrive;
		Else
			Return Enums.FileStorageTypes.InInfobase;
		EndIf;
		
	Else
		Return Enums.FileStorageTypes.InInfobase;
	EndIf;

EndFunction

// Checks whether there is at least one file in one of the volumes.
//
// Returns:
//  Boolean.
//
Function HasFilesInVolumes() Export
	
	If FilesInVolumesCount() <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns a full path of the volume depending on the OS.
Function FullVolumePath(VolumeRef) Export
	
	SystemInfo = New SystemInfo;
	ServerPlatformType = SystemInfo.PlatformType;

	SetPrivilegedMode(True);
	If ServerPlatformType = PlatformType.Windows_x86
		Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		Return VolumeRef.FullPathWindows;
	Else
		Return VolumeRef.FullPathLinux;
	EndIf;
	
EndFunction

// Adds a file to one of the volumes (that has free space).
//
// Parameters:
//   BinaryDataOrPath  - BinaryData, String - binary data of a file or a full file path on hard drive.
//   ModificationTimeUniversal - Date - universal time, which will be set to the file as the last 
//                                        modification time.
//   NameWithoutExtension       - String - a file name without extension.
//   Extension             - String - a file extension without point.
//   VersionNumber            - String - the file version number. If specified, the file name for 
//                                     storage on the hard drive is formed as follows:
//                                     BaseName + "." + VersionNumber + "." + Extension otherwise, 
//                                     BaseName + "." + Extension
//   Encrypted             - Boolean - if True, the extension ".p7m" will be added to the full file name.
//   DateToPlaceInVolume - Date   - if it is not specified, the current session time is used.
//  
//  Returns:
//    Structure - with the following properties:
//      * Volume         - CatalogRef.FilesStorageVolumes - the volume, in which the file was placed.
//      * FilePath  - String - a path, by which the file was placed in the volume.
//
Function AddFileToVolume(BinaryDataOrPath, ModificationTimeUniversal, NameWithoutExtension, Extension,
	VersionNumber = "", Encrypted = False, PutInVolumeDate = Undefined) Export
	
	ExpectedTypes = New Array;
	ExpectedTypes.Add(Type("BinaryData"));
	ExpectedTypes.Add(Type("String"));
	CommonClientServer.CheckParameter("FilesOperationsInternal.AddFileToVolume", "BinaryDataOrPath", BinaryDataOrPath,	
		New TypeDescription(ExpectedTypes));
		
	SetPrivilegedMode(True);
	
	VolumeRef = Catalogs.FileStorageVolumes.EmptyRef();
	
	BriefDescriptionOfAllErrors   = ""; // Errors from all volumes
	DetailedDescriptionOfAllErrors = ""; // For the event log.
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileStorageVolumes.Ref
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes
		|WHERE
		|	FileStorageVolumes.DeletionMark = FALSE
		|
		|ORDER BY
		|	FileStorageVolumes.FillOrder";

	Selection = Query.Execute().Select();
	
	If Selection.Count() = 0 Then
		Raise NStr("ru = 'Нет ни одного тома для размещения файла.'; en = 'There is no volume available for storing the file.'; pl = 'Nie ma żadnego woluminu dla alokacji plików.';es_ES = 'No hay tomos para colocar archivos.';es_CO = 'No hay tomos para colocar archivos.';tr = 'Dosyaların yerleştirileceği birimler yok.';it = 'Non c''è nemmeno un tomo per l''archiviazione del file.';de = 'Es gibt keine Volumes zum Platzieren einer Datei.'");
	EndIf;
	
	While Selection.Next() Do
		
		VolumeRef = Selection.Ref;
		
		VolumePath = FullVolumePath(VolumeRef);
		// Adding a slash mark at the end if it is not there.
		VolumePath = CommonClientServer.AddLastPathSeparator(VolumePath);
		
		// Generating the file name to be stored on the hard disk as follows:
		// - file name.version number.file extension.
		If IsBlankString(VersionNumber) Then
			FileName = NameWithoutExtension + "." + Extension;
		Else
			FileName = NameWithoutExtension + "." + VersionNumber + "." + Extension;
		EndIf;
		
		If Encrypted Then
			FileName = FileName + "." + "p7m";
		EndIf;
		
		Try
			
			If TypeOf(BinaryDataOrPath) = Type("BinaryData") Then
				FileSize = BinaryDataOrPath.Size();
			Else // Otherwise, this is a path to a file on the hard drive.
				SourceFile = New File(BinaryDataOrPath);
				If SourceFile.Exist() Then
					FileSize = SourceFile.Size();
				Else
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось добавить файл ""%1"" ни в один из томов, т.к. он отсутствует.
						|Возможно, файл удален антивирусной программой.
						|Обратитесь к администратору.'; 
						|en = 'Cannot add the ""%1"" file to any volume as it is missing.
						|The file might have been deleted by an antivirus software.
						|Contact administrator.'; 
						|pl = 'Nie udało się dodać pliku ""%1"" do żadnego z woluminów ponieważ go brakuje.
						|Plik może być usunięty przez oprogramowanie antywirusowe.
						|Skontaktuj się z administratorem.';
						|es_ES = 'No se ha podido añadir el archivo ""%1"" en ninguno de los tomos porque está ausente.
						|Es posible que el archivo haya sido eliminado por el programa antivirus.
						|Diríjase al administrador.';
						|es_CO = 'No se ha podido añadir el archivo ""%1"" en ninguno de los tomos porque está ausente.
						|Es posible que el archivo haya sido eliminado por el programa antivirus.
						|Diríjase al administrador.';
						|tr = 'Birimlerden hiçbirine ""%1"" dosyası eksik olduğundan dolayı eklenemedi. 
						|Dosya virüsten koruma programı tarafından silinmiş olabilir. 
						|Lütfen sistem yöneticinize başvurun.';
						|it = 'Impossibile aggiungere il file ""%1"" a un qualsiasi volume, poiché è mancante.
						|Il file potrebbe essere stato eliminato da un software antivirus.
						|Contattare l''amministratore.';
						|de = 'Die Datei ""%1"" konnte keinem der Volumes hinzugefügt werden, da sie fehlt.
						|Die Datei wurde möglicherweise von einem Antivirenprogramm gelöscht.
						|Bitte wenden Sie sich an den Administrator.'"),
						FileName);
						
					Raise ErrorText;
					
				EndIf;
			EndIf;
			
			// If MaxSize = 0, there is no limit to the file size on the volume.
			If VolumeRef.MaxSize <> 0 Then
				
				CurrentSizeInBytes =
					FilesOperationsInternalServerCall.CalculateFileSizeInVolume(VolumeRef.Ref);
				
				NewSizeInBytes = CurrentSizeInBytes + FileSize;
				NewSize = NewSizeInBytes / (1024 * 1024);
				
				If NewSize > VolumeRef.MaxSize Then
					
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Превышен максимальный размер тома (%1 Мб).'; en = 'The maximum volume size (%1 MB) is exceeded.'; pl = 'Przekroczono maksymalny rozmiar woluminu (%1 MB).';es_ES = 'Tamaño del volumen máximo excedido (%1 MB).';es_CO = 'Tamaño del volumen máximo excedido (%1 MB).';tr = 'Maksimum birim boyutu aşıldı (%1MB).';it = 'La dimensione del volume massimo (%1 MB) è stata superata.';de = 'Die maximale Volumen-Größe wurde überschritten (%1 MB).'"),
						VolumeRef.MaxSize);
				EndIf;
			EndIf;
			
			Date = CurrentSessionDate();
			If PutInVolumeDate <> Undefined Then
				Date = PutInVolumeDate;
			EndIf;
			
			// The use of the absolute date format "DF" in the next line is correct, as the date is not meant 
			// for user view.
			DateFolder = Format(Date, "DF=yyyymmdd") + GetPathSeparator();
			
			VolumePath = VolumePath + DateFolder;
			
			FileNameWithPath = FilesOperationsInternalClientServer.GetUniqueNameWithPath(VolumePath, FileName);
			FullFileNameWithPath = VolumePath + FileNameWithPath;
			
			If TypeOf(BinaryDataOrPath) = Type("BinaryData") Then
				BinaryDataOrPath.Write(FullFileNameWithPath);
			Else // Otherwise, this is a path to a file on the hard drive.
				FileCopy(BinaryDataOrPath, FullFileNameWithPath);
			EndIf;
			
			// Setting file change time equal to the change time of the current version.
			FileOnHardDrive = New File(FullFileNameWithPath);
			FileOnHardDrive.SetModificationUniversalTime(ModificationTimeUniversal);
			FileOnHardDrive.SetReadOnly(True);
			
			Return New Structure("Volume,PathToFile", VolumeRef, DateFolder + FileNameWithPath); 
			
		Except
			ErrorInformation = ErrorInfo();
			
			If DetailedDescriptionOfAllErrors <> "" Then
				DetailedDescriptionOfAllErrors = DetailedDescriptionOfAllErrors + Chars.LF + Chars.LF;
				BriefDescriptionOfAllErrors   = BriefDescriptionOfAllErrors   + Chars.LF + Chars.LF;
			EndIf;
			
			ErrorDescriptionTemplate =
				NStr("ru = 'Ошибка при добавлении файла ""%1""
				           |в том ""%2"" (%3):
				           |""%4"".'; 
				           |en = 'An error occurred when adding file ""%1""
				           |to volume ""%2"" (%3):
				           |""%4"".'; 
				           |pl = 'Błąd podczas dodawania pliku ""%1""
				           |do woluminu ""%2"" (%3):
				           |""%4"".';
				           |es_ES = 'Error al añadir el archivo ""%1""
				           |en el tomo ""%2"" (%3): 
				           |""%4"".';
				           |es_CO = 'Error al añadir el archivo ""%1""
				           |en el tomo ""%2"" (%3): 
				           |""%4"".';
				           |tr = '""%1"" 
				           |Dosyası eklenirken hata oluştu ""%2"" (%3): 
				           |""%4"".';
				           |it = 'Errore durante l''aggiunta del file ""%1""
				           |nel tomo ""%2"" (%3):
				           |""%4"".';
				           |de = 'Fehler beim Hinzufügen einer Datei ""%1""
				           |in das Volume ""%2"" (%3):
				           |""%4"".'");
			
			DetailedDescriptionOfAllErrors = DetailedDescriptionOfAllErrors
				+ StringFunctionsClientServer.SubstituteParametersToString(
					ErrorDescriptionTemplate,
					FileName,
					String(VolumeRef),
					VolumePath,
					DetailErrorDescription(ErrorInformation));
			
			BriefDescriptionOfAllErrors = BriefDescriptionOfAllErrors
				+ StringFunctionsClientServer.SubstituteParametersToString(
					ErrorDescriptionTemplate,
					FileName,
					String(VolumeRef),
					VolumePath,
					BriefErrorDescription(ErrorInformation));
			
			// Move to the next volume.
			Continue;
		EndTry;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	// Writing an event log record for the administrator, it includes the errors from all volumes.
	// 
	ErrorMessageTemplate = NStr("ru = 'Не удалось добавить файл ни в один из томов.
		|Список ошибок:
		|
		|%1'; 
		|en = 'Cannot add the file to any volume.
		|List of errors:
		|
		|%1'; 
		|pl = 'Nie udało się dodać pliku do żadnego z woluminów.
		|Lista błędów:
		|
		|%1';
		|es_ES = 'No se ha podido añadir archivo en ninguno de los tomos.
		|Lista de errores:
		|
		|%1';
		|es_CO = 'No se ha podido añadir archivo en ninguno de los tomos.
		|Lista de errores:
		|
		|%1';
		|tr = 'Birimlerden hiçbirine dosya eklenemedi. 
		|Hata listesi:
		|
		|%1';
		|it = 'Impossibile aggiungere il file ad alcun volume.
		|Elenco errori:
		|
		|%1';
		|de = 'Die Datei konnte zu keinem der Volumes hinzugefügt werden.
		|Fehlerliste:
		|
		|%1'");
	
	WriteLogEvent(
		NStr("ru = 'Файлы.Добавление файла'; en = 'Files.Add file'; pl = 'Pliki. Dodawanie pliku';es_ES = 'Archivos. Añadiendo un archivo';es_CO = 'Archivos. Añadiendo un archivo';tr = 'Dosyalar. Dosyanın eklenmesi';it = 'File.Aggiunta del file';de = 'Dateien. Hinzufügen einer Datei'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Error,,,
		StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate, DetailedDescriptionOfAllErrors));
	
	If Users.IsFullUser() Then
		ExceptionString = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate, BriefDescriptionOfAllErrors);
	Else
		// Message to end user.
		ExceptionString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось добавить файл:
			           |""%1.%2"".
			           |
			           |Обратитесь к администратору.'; 
			           |en = 'Cannot add file:
			           |""%1.%2"".
			           |
			           |Contact the administrator.'; 
			           |pl = 'Nie udało się dodać pliku:
			           |""%1.%2"".
			           |
			           |Skontaktuj się z administratorem.';
			           |es_ES = 'No se ha podido añadir archivo:
			           |""%1.%2"".
			           |
			           |Diríjase al administrador.';
			           |es_CO = 'No se ha podido añadir archivo:
			           |""%1.%2"".
			           |
			           |Diríjase al administrador.';
			           |tr = 'Dosya eklenemedi: 
			           |""%1.%2"" 
			           |
			           |Lütfen sistem yöneticinize başvurun.';
			           |it = 'Non è stato possibile aggiungere il file:
			           |""%1.%2"".
			           |
			           |Rivolgetevi all''amministratore.';
			           |de = 'Die Datei konnte nicht hinzugefügt werden:
			           |""%1.%2"".
			           |
			           |Wenden Sie sich an den Administrator.'"),
			NameWithoutExtension, Extension);
	EndIf;
	
	Raise ExceptionString;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Access management.

Function IsFilesOrFilesVersionsCatalog(FullName) Export
	
	NameParts = StrSplit(FullName, ".", False);
	If NameParts.Count() <> 2 Then
		Return False;
	EndIf;
	
	If Upper(NameParts[0]) <> Upper("Catalog")
	   AND Upper(NameParts[0]) <> Upper("Catalog") Then
		Return False;
	EndIf;
	
	If StrEndsWith(Upper(NameParts[1]), Upper("AttachedFiles"))
	 Or Upper(NameParts[1]) = Upper("Files")
	 Or Upper(NameParts[1]) = Upper("FilesVersions") Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Digital signature and encryption for files.

Function DigitalSignatureAvailable(FileType) Export
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		Return ModuleDigitalSignatureInternal.DigitalSignatureAvailable(FileType);
	EndIf;
	
	Return False;
	
EndFunction

// Controls the visibility of items and commands depending on the availability and use of digital 
// signature and encryption.
//
Procedure CryptographyOnCreateFormAtServer(Form, IsListForm = True, RowsPictureOnly = False) Export
	
	Items = Form.Items;
	
	DigitalSigning = False;
	Encryption = False;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature")
		AND Not CommonClientServer.IsMacOSWebClient() Then
	
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		If ModuleDigitalSignatureInternal.UseInteractiveAdditionOfDigitalSignaturesAndEncryption() Then
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			DigitalSigning    = ModuleDigitalSignature.UseDigitalSignature();
			Encryption               = ModuleDigitalSignature.UseEncryption();
		EndIf;
		
	EndIf;
	
	If IsListForm Then
		If Common.IsCatalog(Metadata.FindByFullName(Form.List.MainTable)) Then
			FilesTable = Common.ObjectManagerByFullName(Form.List.MainTable);
			Available = DigitalSignatureAvailable(TypeOf(FilesTable.EmptyRef()));
		Else
			Available = True;
		EndIf;
	Else
		Available = DigitalSignatureAvailable(TypeOf(Form.Object.Ref));
	EndIf;
	Used = (DigitalSigning Or Encryption) AND Available;
	
	If IsListForm Then
		Items.ListSignedEncryptedPictureNumber.Visible = Used;
	EndIf;
	
	If Not RowsPictureOnly Then
		Items.FormDigitalSignatureAndEncryptionCommandsGroup.Visible = Used;
		
		If IsListForm Then
			Items.ListContextMenuDigitalSignatureAndEncryptionCommandsGroup.Visible = Used;
		Else
			Items.DigitalSignaturesGroup.Visible = DigitalSigning;
			Items.EncryptionCertificatesGroup.Visible = Encryption;
		EndIf;
	EndIf;
	
	If Not Used Then
		Return;
	EndIf;
	
	If Not RowsPictureOnly Then
		Items.FormDigitalSignatureCommandsGroup.Visible = DigitalSigning;
		Items.FormEncryptionCommandsGroup.Visible = Encryption;
		
		If IsListForm Then
			Items.ListContextMenuDigitalSignatureCommandsGroup.Visible = DigitalSigning;
			Items.ListContextMenuEncryptionCommandsGroup.Visible = Encryption;
		EndIf;
	EndIf;
	
	If DigitalSigning AND Encryption Then
		Header = NStr("ru = 'Электронная подпись и шифрование'; en = 'Digital signature and encryption'; pl = 'Podpis cyfrowy i szyfrowanie';es_ES = 'Firma digital y codificación';es_CO = 'Firma digital y codificación';tr = 'Dijital imza ve şifreleme';it = 'Firma digitale e crittografia';de = 'Digitale Unterschrift und Verschlüsselung'");
		Tooltip = NStr("ru = 'Наличие электронной подписи или шифрования'; en = 'Digital signature or encryption availability'; pl = 'Istnienie podpisu cyfrowego lub szyfrowania';es_ES = 'Existencia de la firma digital o la codificación';es_CO = 'Existencia de la firma digital o la codificación';tr = 'Elektronik imza veya şifrelerin varlığı';it = 'Firma elettronica o disponibilità codifica';de = 'Vorhandensein von digitaler Unterschrift oder Verschlüsselung'");
		Picture  = PictureLib["SignedEncryptedTitle"];
	ElsIf DigitalSigning Then
		Header = NStr("ru = 'Электронная подпись'; en = 'Digital signature'; pl = 'Podpis cyfrowy';es_ES = 'Firma digital';es_CO = 'Firma digital';tr = 'Dijital imza';it = 'Firma digitale';de = 'Digitale Signatur'");
		Tooltip = NStr("ru = 'Наличие электронной подписи'; en = 'Digital signature existence'; pl = 'Obecność podpisu cyfrowego';es_ES = 'Existencia de la firma digital';es_CO = 'Existencia de la firma digital';tr = 'Dijital imza varlığı';it = 'Esistenza di firma digitale';de = 'Verfügbarkeit der digitalen Unterschrift'");
		Picture  = PictureLib["SignedWithDS"];
	Else // Encryption
		Header = NStr("ru = 'Шифрование'; en = 'Encryption'; pl = 'Szyfrowanie';es_ES = 'Codificación';es_CO = 'Codificación';tr = 'Şifreleme';it = 'Codifica';de = 'Verschlüsselung'");
		Tooltip = NStr("ru = 'Наличие шифрования'; en = 'Encryption existence'; pl = 'Istnienie szyfrowania';es_ES = 'Existencia de la codificación';es_CO = 'Existencia de la codificación';tr = 'Şifreleme varlığı';it = 'Esistenza di crittografia';de = 'Verschlüsselung Existenz'");
		Picture  = PictureLib["Encrypted"];
	EndIf;
	
	If IsListForm Then
		Items.ListSignedEncryptedPictureNumber.HeaderPicture = Picture;
		Items.ListSignedEncryptedPictureNumber.ToolTip = Tooltip;
	EndIf;
	
	If Not RowsPictureOnly Then
		Items.FormDigitalSignatureAndEncryptionCommandsGroup.Title = Header;
		Items.FormDigitalSignatureAndEncryptionCommandsGroup.ToolTip = Header;
		Items.FormDigitalSignatureAndEncryptionCommandsGroup.Picture  = Picture;
		
		If IsListForm Then
			Items.ListContextMenuDigitalSignatureAndEncryptionCommandsGroup.Title = Header;
			Items.ListContextMenuDigitalSignatureAndEncryptionCommandsGroup.ToolTip = Header;
			Items.ListContextMenuDigitalSignatureAndEncryptionCommandsGroup.Picture  = Picture;
		EndIf;
	EndIf;
	
	ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	ModuleDigitalSignatureInternal.RegisterSignaturesList(Form, "DigitalSignatures");
	
EndProcedure

// For internal use only.
Procedure MoveSignaturesCheckResults(SignaturesInForm, SignedFile) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
		
	ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
	If Not ModuleDigitalSignatureInternal.DigitalSignatureAvailable(TypeOf(SignedFile)) Then
		Return;
	EndIf;
		
	ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
	SignaturesInObject = ModuleDigitalSignature.SetSignatures(SignedFile);
	
	If SignaturesInForm.Count() <> SignaturesInObject.Count() Then
		Return; // If the object was changed, the test results are not transferred.
	EndIf;
	
	If SignaturesInForm.Count() = 0 Then
		Return;
	EndIf;
	
	Properties = New Structure("SignatureValidationDate, SignatureCorrect", Null, Null);
	FillPropertyValues(Properties, SignaturesInObject[0]);
	If Properties.SignatureValidationDate = Null
	 Or Properties.SignatureCorrect = Null Then
		Return; // If the object does not have check attributes, the check results are not transferred.
	EndIf;
	
	For Each Row In SignaturesInForm Do
		RowInObject = SignaturesInObject.Get(SignaturesInForm.IndexOf(Row));
		If Row.SignatureDate         <> RowInObject.SignatureDate
		 Or Row.Comment         <> RowInObject.Comment
		 Or Row.CertificateOwner <> RowInObject.CertificateOwner
		 Or Row.Thumbprint           <> RowInObject.Thumbprint
		 Or Row.SignatureSetBy <> RowInObject.SignatureSetBy Then
			Return; // If the object was changed, the test results are not transferred.
		EndIf;
	EndDo;
	
	For Each Row In SignaturesInForm Do
		RowInObject = SignaturesInObject.Get(SignaturesInForm.IndexOf(Row));
		FillPropertyValues(Properties, RowInObject);
		If Row.SignatureValidationDate = Properties.SignatureValidationDate
		   AND Row.SignatureCorrect        = Properties.SignatureCorrect Then
			Continue; // Do not set the modification if the test results match.
		EndIf;
		FillPropertyValues(Properties, Row);
		FillPropertyValues(RowInObject, Properties);
		ModuleDigitalSignature.UpdateSignature(SignedFile, RowInObject);
	EndDo;
	
EndProcedure

// Places the encrypted files in the database and checks the Encrypted flag to the file and all its versions.
//
// Parameters:
//  FileRef - CatalogRef.Files - file.
//  Encrypt - Boolean - if True, encrypt file, otherwise, decrypt it.
//  DataArrayToAddToBase - an array of structures.
//  UUID - UUID - a form UUID.
//  WorkingDirectoryName - String - a working directory.
//  FilesArrayInWorkingDirectoryToDelete - Array - files to be deleted from the register.
//  ThumbprintsArray  - Array - an array of certificate thumbprints used for encryption.
//
Procedure WriteEncryptionInformation(FileRef, Encrypt, DataArrayToStoreInDatabase, UUID, 
	WorkingDirectoryName, FilesArrayInWorkingDirectoryToDelete, ThumbprintsArray) Export
	
	BeginTransaction();
	Try
		CurrentVersionTextTempStorageAddress = "";
		MainFileTempStorageAddress      = "";
		For Each DataToWriteAtServer In DataArrayToStoreInDatabase Do
			
			If TypeOf(DataToWriteAtServer.VersionRef) <> Type("CatalogRef.FilesVersions") Then
				MainFileTempStorageAddress = DataToWriteAtServer.TempStorageAddress;
				Continue;
			EndIf;
			
			TempStorageAddress = DataToWriteAtServer.TempStorageAddress;
			VersionRef = DataToWriteAtServer.VersionRef;
			TempTextStorageAddress = DataToWriteAtServer.TempTextStorageAddress;
			
			If VersionRef = FileRef.CurrentVersion Then
				CurrentVersionTextTempStorageAddress = TempTextStorageAddress;
			EndIf;
			
			FullFileNameInWorkingDirectory = "";
			InWorkingDirectoryForRead = True; // not used
			InOwnerWorkingDirectory = True;
			FullFileNameInWorkingDirectory = FilesOperationsInternalServerCall.GetFullFileNameFromRegister(VersionRef, 
				WorkingDirectoryName, InWorkingDirectoryForRead, InOwnerWorkingDirectory);
				
			If Not IsBlankString(FullFileNameInWorkingDirectory) Then
				FilesArrayInWorkingDirectoryToDelete.Add(FullFileNameInWorkingDirectory);
			EndIf;
			
			FilesOperationsInternalServerCall.DeleteFromRegister(VersionRef);
			
			FileInfo = FilesOperationsClientServer.FileInfo("FileWithVersion");
			FileInfo.BaseName = VersionRef.FullDescr;
			FileInfo.Comment = VersionRef.Comment;
			FileInfo.TempFileStorageAddress = TempStorageAddress;
			FileInfo.ExtensionWithoutPoint = VersionRef.Extension;
			FileInfo.Modified = VersionRef.CreationDate;
			FileInfo.ModificationTimeUniversal = VersionRef.UniversalModificationDate;
			FileInfo.Size = VersionRef.Size;
			FileInfo.ModificationTimeUniversal = VersionRef.UniversalModificationDate;
			FileInfo.NewTextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			FileInfo.Encrypted = Encrypt;
			FileInfo.StoreVersions = False;
			UpdateFileVersion(FileRef, FileInfo, VersionRef, UUID);
			
			// For the option of storing files on hard drive (on the server), deleting the File from the temporary storage after receiving it.
			If Not IsBlankString(DataToWriteAtServer.FileAddress) AND IsTempStorageURL(DataToWriteAtServer.FileAddress) Then
				DeleteFromTempStorage(DataToWriteAtServer.FileAddress);
			EndIf;
			
		EndDo;
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
		DataLockItem.SetValue("Ref", FileRef);
		DataLock.Lock();
		
		FileObject = FileRef.GetObject();
		LockDataForEdit(FileRef, , UUID);
		
		FileObject.Encrypted = Encrypt;
		FileObject.TextStorage = New ValueStorage("");
		FileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		
		// To write a previously signed object.
		FileObject.AdditionalProperties.Insert("WriteSignedObject", True);
		
		If Encrypt Then
			If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
				ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
				ModuleDigitalSignatureInternal.AddEncryptionCertificates(FileRef, ThumbprintsArray);
			EndIf;
		Else
			If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
				ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
				ModuleDigitalSignatureInternal.ClearEncryptionCertificates(FileRef);
			EndIf;
		EndIf;
		
		FileMetadata = Metadata.FindByType(TypeOf(FileRef));
		FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
		
		If Not Encrypt AND CurrentVersionTextTempStorageAddress <> "" Then
			
			If FileMetadata.FullTextSearch = FullTextSearchUsing Then
				TextExtractionResult = ExtractText(CurrentVersionTextTempStorageAddress);
				FileObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
				FileObject.TextStorage = TextExtractionResult.TextStorage;
			Else
				FileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
				FileObject.TextStorage = New ValueStorage("");
			EndIf;
			
		EndIf;
		
		AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", FileMetadata);
		If Not FileObject.StoreVersions Or (AbilityToStoreVersions AND Not ValueIsFilled(FileObject.CurrentVersion)) Then
			UpdateFileBinaryDataAtServer(FileObject, MainFileTempStorageAddress);
		EndIf;
		
		FileObject.Write();
		
		UnlockDataForEdit(FileRef, UUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Accounting control.

// See AccountingAuditOverridable.OnDefineChecks 
Procedure OnDefineChecks(ChecksGroups, Checks) Export
	
	CheckSSL = Checks.Add();
	CheckSSL.GroupID          = "SystemChecks";
	CheckSSL.Description                 = NStr("ru='Поиск ссылок на несуществующие файлы в томах хранения'; en = 'Search for links to non-existing files in storage volumes'; pl = 'Wyszukiwanie linków do nieistniejących plików w woluminach przechowywania';es_ES = 'Búsqueda de enlaces a los archivos inexistentes en los tomos de guardar';es_CO = 'Búsqueda de enlaces a los archivos inexistentes en los tomos de guardar';tr = 'Depolama birimlerinde varolmayan dosyalara bağlantılar bulma';it = 'Ricerca di collegamenti ai file non esistenti nei volumi di archiviazione';de = 'Suche nach Links zu nicht existierenden Dateien auf Speichermedien'");
	CheckSSL.Reasons                      = NStr("ru='Файл был физически удален или перемещен на диске вследствие работы антивирусных программ,
		|непреднамеренных действий администратора и.т.д.'; 
		|en = 'File was deleted or transferred on the hard drive due to anti-virus programs,
		|unintentional actions of the administrator, etc.'; 
		|pl = 'Plik został fizycznie usunięty lub przeniesiony na dysku w wyniku działania programów antywirusowych,
		|niezamierzonych działań administratora itp.';
		|es_ES = 'El archivo ha sido eliminado físicamente o movido en el disco al funcionar los programas de antivirus,
		|acciones no premeditadas del administrador etc.';
		|es_CO = 'El archivo ha sido eliminado físicamente o movido en el disco al funcionar los programas de antivirus,
		|acciones no premeditadas del administrador etc.';
		|tr = 'Dosya, 
		|virüsten koruma programları, istenmeyen yönetici eylemleri vb. nedeniyle fiziksel olarak silinmiş veya disk üzerinde taşınmıştır.';
		|it = 'Il file è stato eliminato o trasferito su disco fisso a causa di programmi antivirus,
		|azioni non intenzionali dell''amministratore, ecc...';
		|de = 'Die Datei wurde physisch gelöscht oder auf der Festplatte verschoben, aufgrund von Antivirensoftware,
		|unbeabsichtigten Administratoraktionen usw.'");
	CheckSSL.Recommendation                 = NStr("ru='• Пометить файл в программе на удаление;
		|• Или восстановить файл на диске в томе из резервной копии.'; 
		|en = '• Mark file in the application for deletion.
		|• Or restore the file on hard drive in the volume from the backup.'; 
		|pl = '• Odznaczyć plik w programie do usuwania;
		|• Lub przywrócić plik na dysku na woluminie z kopii zapasowej.';
		|es_ES = '• Marcar el archivo para borrar en el programa;
		|• O restablecer el archivo en el disco en el tomo de la copia de respaldo.';
		|es_CO = '• Marcar el archivo para borrar en el programa;
		|• O restablecer el archivo en el disco en el tomo de la copia de respaldo.';
		|tr = '* Silmek için programdaki dosyayı etiketleyin; 
		|* Veya yedekten birimdeki sürücüde dosyayı geri yükleyin.';
		|it = '• Contrassegnare il file nell''applicazione per la cancellazione.
		|• O ripristinare il file su disco rigido nel volume da backup.';
		|de = '• Markieren Sie die Datei im Programm zum Löschen;
		|• Oder stellen Sie die Datei auf der Festplatte im Datenträger von der Sicherungskopie wieder her.'");
	CheckSSL.ID                = "StandardSubsystems.ReferenceToNonexistingFilesInVolumeCheck";
	CheckSSL.CheckHandler           = "FilesOperationsInternal.ReferenceToNonexistingFilesInVolumeCheck";
	CheckSSL.AccountingChecksContext = "SystemChecks";
	CheckSSL.Disabled                    = True;
	
EndProcedure

// Checks non-existent files on the hard drive, in the case when attached files are stored in volumes.
//
Procedure ReferenceToNonexistingFilesInVolumeCheck(CheckSSL, CheckParameters) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AvailableVolumes = AvailableVolumes(CheckParameters);
	If AvailableVolumes.Count() = 0 Then
		Return;
	EndIf;
	
	ModuleSaaS = Undefined;
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
	EndIf;
	
	MetadataObjectKinds = New Array;
	MetadataObjectKinds.Add(Metadata.Catalogs);
	MetadataObjectKinds.Add(Metadata.Documents);
	MetadataObjectKinds.Add(Metadata.ChartsOfAccounts);
	MetadataObjectKinds.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataObjectKinds.Add(Metadata.Tasks);
	
	For Each MetadataObjectKind In MetadataObjectKinds Do
		For Each MetadataObject In MetadataObjectKind Do
			If ModuleSaaS <> Undefined 
				AND Not ModuleSaaS.IsSeparatedMetadataObject(MetadataObject.FullName()) Then
				Continue;
			EndIf;
			If Not CheckAttachedFilesObject(MetadataObject) Then
				Continue;
			EndIf;
			SearchRefsToNonExistentFilesInVolumes(MetadataObject, CheckParameters, AvailableVolumes);
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Extracting text for a full text search.

Procedure ExtractTextFromFiles() Export
	
	SetPrivilegedMode(True);
	
	If NOT IsWindowsPlatform() Then
		Return; // Text extraction is available only under Windows.
	EndIf;
	
	NameWithFileExtension = "";
	
	WriteLogEvent(
		NStr("ru = 'Файлы.Извлечение текста'; en = 'Files.Text extraction'; pl = 'Pliki. Ekstrakcja tekstu';es_ES = 'Archivos.Extracción del texto';es_CO = 'Archivos.Extracción del texto';tr = 'Dosyalar. Metin özütleme';it = 'File.Estrazione testo';de = 'Dateien. Text extrahieren'",
		     CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		,
		NStr("ru = 'Начато регламентное извлечения текста'; en = 'Scheduled text extraction started'; pl = 'Rozpoczęto planową ekstrakcję tekstu';es_ES = 'Extracción del texto programado está iniciada';es_CO = 'Extracción del texto programado está iniciada';tr = 'Zamanlanmış metin çıkarma işlemi başlatıldı';it = 'L''estrazione testo pianificata è stata avviata';de = 'Die geplante Textextraktion wird gestartet'"));
	
	Query = New Query(QueryTextToExtractText());
	FilesToExtractText = Query.Execute().Unload();
	
	IsWindowsPlatform = IsWindowsPlatform();
	
	For Each FileWithoutText In FilesToExtractText Do
		
		DeleteTemporaryFile = False;
		
		BeginTransaction();
		Try
			
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileWithoutText.Ref)).FullName());
			DataLockItem.SetValue("Ref", FileWithoutText.Ref);
			Try
				DataLock.Lock();
			Except
				// The locked files will be processed next time.
				RollbackTransaction();
				Continue;
			EndTry;
			
			FileObject = FileWithoutText.Ref.GetObject();
			If FileObject = Undefined Then // file is already deleted in another session
				RollbackTransaction();
				Continue;
			EndIf;
				
			Try
				FileObject.Lock();
			Except
				// The locked files will be processed next time.
				RollbackTransaction();
				Continue;
			EndTry;
			
			If Not IsWindowsPlatform Then // Cannot extract text.
				FileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
				FileObject.TextStorage = New ValueStorage("");
				Continue;
			EndIf;
			
			NameWithFileExtension = FileObject.Description + "." + FileObject.Extension;
			
			If IsItemFilesOperations(FileObject.Ref) Then
				ObjectMetadata = Metadata.FindByType(TypeOf(FileObject.Ref));
				AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", ObjectMetadata);
				If AbilityToStoreVersions AND ValueIsFilled(FileObject.CurrentVersion.Ref) Then
					FileWithBinaryDataName = FileWithBinaryDataName(FileObject.CurrentVersion.Ref);
				Else
					FileWithBinaryDataName = FileWithBinaryDataName(FileObject.Ref);
				EndIf;
			EndIf;
			
			DeleteTemporaryFile = FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase 
				AND Not IsBlankString(FileWithBinaryDataName);
			TextExtractionResult = ExtractTextFromFileOnHardDrive(FileWithBinaryDataName, FileWithoutText.Encoding);
			FileObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
			FileObject.TextStorage = TextExtractionResult.TextStorage;
			
			OnWriteExtractedText(FileObject);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(
				NStr("ru = 'Файлы.Извлечение текста'; en = 'Files.Text extraction'; pl = 'Pliki. Ekstrakcja tekstu';es_ES = 'Archivos.Extracción del texto';es_CO = 'Archivos.Extracción del texto';tr = 'Dosyalar. Metin özütleme';it = 'File.Estrazione testo';de = 'Dateien. Text extrahieren'",
				     CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось выполнить регламентное извлечение текста из файла
					           |""%1""
					           |по причине:
					           |""%2"".'; 
					           |en = 'Cannot complete scheduled text extraction from file
					           |""%1""
					           |due to:
					           |""%2"".'; 
					           |pl = 'Nie powiodło się planowe wyodrębnianie tekstu z pliku
					           |""%1""
					           |z powodu:
					           |""%2"".';
					           |es_ES = 'No se ha podido realizar la extracción del texto programada del archivo 
					           |""%1""
					           |a causa de:
					           |""%2"".';
					           |es_CO = 'No se ha podido realizar la extracción del texto programada del archivo 
					           |""%1""
					           |a causa de:
					           |""%2"".';
					           |tr = '
					           |"
"%1Nedeniyle "
" dosyasının metni düzenli olarak ayıklayamadı: ""%2"".';
					           |it = 'Impossibile completare l''estrazione testo programmata da file
					           |""%1""
					           |a causa di:
					           |""%2"".';
					           |de = 'Die routinemäßige Extraktion von Text aus der
					           |""%1""
					           |Datei war nicht möglich, aufgrund von:
					           |""%2"".'"),
					NameWithFileExtension,
					DetailErrorDescription(ErrorInfo()) ));
		EndTry;
		
		If DeleteTemporaryFile Then
			Try
				DeleteFiles(FileWithBinaryDataName);
			Except
				WriteLogEvent(NStr("ru = 'Файлы.Извлечение текста'; en = 'Files.Text extraction'; pl = 'Pliki. Ekstrakcja tekstu';es_ES = 'Archivos.Extracción del texto';es_CO = 'Archivos.Extracción del texto';tr = 'Dosyalar. Metin özütleme';it = 'File.Estrazione testo';de = 'Dateien. Text extrahieren'",	CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			EndTry;
		EndIf;
		
	EndDo;
	
	WriteLogEvent(
		NStr("ru = 'Файлы.Извлечение текста'; en = 'Files.Text extraction'; pl = 'Pliki. Ekstrakcja tekstu';es_ES = 'Archivos.Extracción del texto';es_CO = 'Archivos.Extracción del texto';tr = 'Dosyalar. Metin özütleme';it = 'File.Estrazione testo';de = 'Dateien. Text extrahieren'",
		     CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		,
		NStr("ru = 'Закончено регламентное извлечение текста'; en = 'Scheduled text extraction completed'; pl = 'Planowana ekstrakcja teksu została zakończona';es_ES = 'Extracción del texto programado está finalizada';es_CO = 'Extracción del texto programado está finalizada';tr = 'Zamanlanmış metin çıkarma işlemi tamamlandı';it = 'Terminata l''estrazione di routine del testo';de = 'Geplante Textextraktion ist abgeschlossen'"));
	
EndProcedure

// Returns True if the file text is extracted on the server (not on the client).
//
// Returns:
//  Boolean. False if the text is not extracted on the server, in other words, it can and should be 
//                 extracted on the client.
//
Function ExtractTextFilesOnServer() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.ExtractTextFilesOnServer.Get();
	
EndFunction

// Returns True if the server operates under Windows.
Function IsWindowsPlatform() Export
	
	SystemInfo = New SystemInfo;
	ServerPlatformType = SystemInfo.PlatformType;
	
	Return (ServerPlatformType = PlatformType.Windows_x86) 
		Or (ServerPlatformType = PlatformType.Windows_x86_64);
	
EndFunction

// Writes to the server the text extraction results that are the extracted text and the TextExtractionStatus.
Procedure RecordTextExtractionResult(FileOrVersionRef, ExtractionResult,
	TempTextStorageAddress) Export
	
	FileOrVersionObject = FileOrVersionRef.GetObject();
	FileOrVersionObject.Lock();
	
	If Not IsBlankString(TempTextStorageAddress) Then
		
		FileMetadata = Metadata.FindByType(FileOrVersionRef);
		FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
		If FileMetadata.FullTextSearch = FullTextSearchUsing Then
			TextExtractionResult = ExtractText(TempTextStorageAddress);
			FileOrVersionObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
			FileOrVersionObject.TextStorage = TextExtractionResult.TextStorage;
		Else
			FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			FileOrVersionObject.TextStorage = New ValueStorage("");
		EndIf;
		DeleteFromTempStorage(TempTextStorageAddress);
		
	EndIf;
	
	If ExtractionResult = "NotExtracted" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	ElsIf ExtractionResult = "Extracted" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
	ElsIf ExtractionResult = "FailedExtraction" Then
		FileOrVersionObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction;
	EndIf;
	
	OnWriteExtractedText(FileOrVersionObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other functions.

Function ExtensionsListForPreview() Export
	
	// See also the PictureFormat enumerstion.
	ExtensionsForPreview = New ValueList;
	ExtensionsForPreview.Add("bmp");
	ExtensionsForPreview.Add("emf");
	ExtensionsForPreview.Add("gif");
	ExtensionsForPreview.Add("ico");
	ExtensionsForPreview.Add("icon");
	ExtensionsForPreview.Add("jpg");
	ExtensionsForPreview.Add("jpeg");
	ExtensionsForPreview.Add("png");
	ExtensionsForPreview.Add("tiff");
	ExtensionsForPreview.Add("tif");
	ExtensionsForPreview.Add("wmf");
	
	Return ExtensionsForPreview;
	
EndFunction

Function DeniedExtensionsList() Export
	
	DeniedExtensionsList = New ValueList;
	DeniedExtensionsList.Add("ade");
	DeniedExtensionsList.Add("adp");
	DeniedExtensionsList.Add("app");
	DeniedExtensionsList.Add("bas");
	DeniedExtensionsList.Add("bat");
	DeniedExtensionsList.Add("chm");
	DeniedExtensionsList.Add("class");
	DeniedExtensionsList.Add("cmd");
	DeniedExtensionsList.Add("com");
	DeniedExtensionsList.Add("cpl");
	DeniedExtensionsList.Add("crt");
	DeniedExtensionsList.Add("dll");
	DeniedExtensionsList.Add("exe");
	DeniedExtensionsList.Add("fxp");
	DeniedExtensionsList.Add("hlp");
	DeniedExtensionsList.Add("hta");
	DeniedExtensionsList.Add("ins");
	DeniedExtensionsList.Add("isp");
	DeniedExtensionsList.Add("jse");
	DeniedExtensionsList.Add("js");
	DeniedExtensionsList.Add("lnk");
	DeniedExtensionsList.Add("mda");
	DeniedExtensionsList.Add("mdb");
	DeniedExtensionsList.Add("mde");
	DeniedExtensionsList.Add("mdt");
	DeniedExtensionsList.Add("mdw");
	DeniedExtensionsList.Add("mdz");
	DeniedExtensionsList.Add("msc");
	DeniedExtensionsList.Add("msi");
	DeniedExtensionsList.Add("msp");
	DeniedExtensionsList.Add("mst");
	DeniedExtensionsList.Add("ops");
	DeniedExtensionsList.Add("pcd");
	DeniedExtensionsList.Add("pif");
	DeniedExtensionsList.Add("prf");
	DeniedExtensionsList.Add("prg");
	DeniedExtensionsList.Add("reg");
	DeniedExtensionsList.Add("scf");
	DeniedExtensionsList.Add("scr");
	DeniedExtensionsList.Add("sct");
	DeniedExtensionsList.Add("shb");
	DeniedExtensionsList.Add("shs");
	DeniedExtensionsList.Add("url");
	DeniedExtensionsList.Add("vb");
	DeniedExtensionsList.Add("vbe");
	DeniedExtensionsList.Add("vbs");
	DeniedExtensionsList.Add("wsc");
	DeniedExtensionsList.Add("wsf");
	DeniedExtensionsList.Add("wsh");
	
	Return DeniedExtensionsList;
	
EndFunction

Function PrepareSendingParametersStructure() Export
	
	Return New Structure("Recipient,Subject,Text", Undefined, "", "");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File exchange.

// Preparation of parameters and preliminary checks before creating a file initial image.
//
Function PrepareDataToCreateFileInitialImage(ParametersStructure) Export
	
	Result = New Structure("DataReady, ConfirmationRequired, QuestionText", True, False, "");
	
	Node 							= ParametersStructure.Node;
	UUIDOfForm 	= ParametersStructure.UUIDOfForm;
	Language 							= ParametersStructure.Language;
	FullWindowsFileInfobaseName 	= ParametersStructure.FullWindowsFileInfobaseName;
	FileInfobaseFullNameLinux 		= ParametersStructure.FileInfobaseFullNameLinux;
	WindowsVolumesFilesArchivePath = ParametersStructure.WindowsVolumesFilesArchivePath;
	PathToVolumeFilesArchiveLinux 	= ParametersStructure.PathToVolumeFilesArchiveLinux;
	
	VolumesFilesArchivePath = "";
	FullFileInfobaseName = "";
	
	HasFilesInVolumes = False;
	
	If FilesOperations.HasFileStorageVolumes() Then
		HasFilesInVolumes = HasFilesInVolumes();
	EndIf;
	
	SystemInfo = New SystemInfo;
	ServerPlatformType = SystemInfo.PlatformType;
	
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		VolumesFilesArchivePath = WindowsVolumesFilesArchivePath;
		FullFileInfobaseName = FullWindowsFileInfobaseName;
		
		If Not Common.FileInfobase() Then
			If HasFilesInVolumes AND Not IsBlankString(VolumesFilesArchivePath) AND (Left(VolumesFilesArchivePath, 2) <> "\\"
				OR StrFind(VolumesFilesArchivePath, ":") <> 0) Then
				
				CommonClientServer.MessageToUser(
					NStr("ru = 'Путь к архиву с файлами томов должен быть
					           |в формате UNC (\\servername\resource)'; 
					           |en = 'Path to the archive with volume files must have
					           |the UNC format (\\servername\resource)'; 
					           |pl = 'Ścieżka do archiwum z plikami woluminów musi być
					           |w formacie UNC (\\servername\resource)';
					           |es_ES = 'La ruta al archivo con documentos de tomos debe ser
					           |en el formato UNC (\\servername\resource)';
					           |es_CO = 'La ruta al archivo con documentos de tomos debe ser
					           |en el formato UNC (\\servername\resource)';
					           |tr = 'Birim dosyalarıyla arşiv yolu
					           | UNC biçiminde olmalıdır (\\servername\resource)';
					           |it = 'Il percorso all''archivio con file di volume deve avere
					           |formato UNC (\\servername\resource)';
					           |de = 'Der Pfad zum Archiv der Volumendatei muss
					           |im UNC-Format sein (\\servername\resource).'"),
					,
					"WindowsVolumesFilesArchivePath");
				Result.DataReady = False;
			EndIf;
			If Not IsBlankString(FullFileInfobaseName) AND (Left(FullFileInfobaseName, 2) <> "\\" OR StrFind(FullFileInfobaseName, ":") <> 0) Then
				CommonClientServer.MessageToUser(
					NStr("ru = 'Путь к файловой базе должен быть
					           |в формате UNC (\\servername\resource)'; 
					           |en = 'Path to the file base must have
					           |the UNC format (\\servername\resource)'; 
					           |pl = 'Ścieżka do plików bazy musi być
					           |w formacie UNC (\\servername\resource)';
					           |es_ES = 'La ruta a la base de archivos debe ser
					           |en el formato UNC (\\servername\resource)';
					           |es_CO = 'La ruta a la base de archivos debe ser
					           |en el formato UNC (\\servername\resource)';
					           |tr = 'Birim dosyalarını arşivleme yolu UNC biçiminde 
					           |olmalıdır (\\ servername \ resource)';
					           |it = 'Il percorso per la base file deve avere
					           |formato UNC (\\servername\resource)';
					           |de = 'Der Dateibasispfad muss
					           |im UNC-Format sein (\\servername\resource).'"),
					,
					"FullWindowsFileInfobaseName");
				Result.DataReady = False;
			EndIf;
		EndIf;
	Else
		VolumesFilesArchivePath = PathToVolumeFilesArchiveLinux;
		FullFileInfobaseName = FileInfobaseFullNameLinux;
	EndIf;
	
	If IsBlankString(FullFileInfobaseName) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите полное имя файловой базы (файл 1cv8.1cd)'; en = 'Specify the full name of the file infobase (1cv8.1cd file)'; pl = 'Określ pełną nazwę bazy plików (plik 1cv8.1cd)';es_ES = 'Especificar un nombre completo de la base de archivos (archivo 1cv8.1cd)';es_CO = 'Especificar un nombre completo de la base de archivos (archivo 1cv8.1cd)';tr = 'Dosya Infobase''inin tam adını belirtin (1cv8.1cd dosyası)';it = 'Indicare il nome completo dell''infobase del file (1cv8.1cd file)';de = 'Geben Sie einen vollständigen Namen der Dateibasis an (Datei 1cv8.1cd)'"),,
			"FullWindowsFileInfobaseName");
		Result.DataReady = False;
	ElsIf Result.DataReady Then
		InfobaseFile = New File(FullFileInfobaseName);
		
		If HasFilesInVolumes Then
			If IsBlankString(VolumesFilesArchivePath) Then
				CommonClientServer.MessageToUser(
					NStr("ru = 'Укажите полное имя архива с файлами томов (файл *.zip)'; en = 'Specify the full name of the archive with volume files (it is a *.zip file)'; pl = 'Określ pełną nazwę archiwum z plikami woluminów (plik *.zip)';es_ES = 'Especificar un nombre completo de un archivo con documentos del volumen (archivo *.zip)';es_CO = 'Especificar un nombre completo de un archivo con documentos del volumen (archivo *.zip)';tr = 'Birim dosyaları ile arşivin tam adını belirtin (dosya * .zip)';it = 'Specifica il nome completo dell''archivio con i file volume (è un file *.zip)';de = 'Geben Sie einen vollständigen Namen eines Archivs mit Volumen-Dateien an (Datei *.zip)'"),, 
					"WindowsVolumesFilesArchivePath");
				Result.DataReady = False;
			Else
				File = New File(VolumesFilesArchivePath);
				
				If File.Exist() AND InfobaseFile.Exist() Then
					Result.QuestionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Файлы ""%1"" и ""%2"" уже существуют.
							           |Заменить существующие файлы?'; 
							           |en = 'Files ""%1"" and ""%2"" already exist.
							           |Overwrite existing files?'; 
							           |pl = 'Pliki ""%1"" oraz ""%2"" już istnieją.
							           |Zastąpić istniejące pliki?';
							           |es_ES = 'Los archivos ""%1"" y ""%2"" ya existen.
							           |¿Reemplazar los archivos existentes?';
							           |es_CO = 'Los archivos ""%1"" y ""%2"" ya existen.
							           |¿Reemplazar los archivos existentes?';
							           |tr = '""%1"" ve ""%2"" dosyaları zaten mevcut.
							           |Mevcut dosyaların üstüne yazılsın mı?';
							           |it = 'I file ""%1"" e ""%2"" esistono già.
							           |Sorascrivere i file esistenti?';
							           |de = 'Die Dateien ""%1"" und ""%2"" sind bereits vorhanden.
							           |Bestehende Dateien ersetzen?'"), VolumesFilesArchivePath, FullFileInfobaseName);
					Result.ConfirmationRequired = True;
				ElsIf File.Exist() Then
					Result.QuestionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Файл ""%1"" уже существует.
							           |Заменить существующий файл?'; 
							           |en = 'File ""%1"" already exists.
							           |Replace the existing file?'; 
							           |pl = 'Plik ""%1"" już istnieje.
							           |Zastąpić istniejący plik?';
							           |es_ES = 'El archivo ""%1"" ya existe.
							           |¿Reemplazar el archivo existente?';
							           |es_CO = 'El archivo ""%1"" ya existe.
							           |¿Reemplazar el archivo existente?';
							           |tr = '""%1"" dosyası zaten mevcut.
							           |Mevcut dosya değiştirilsin mi?';
							           |it = 'Il file ""%1"" già esiste.
							           |Sostituire il file esistente?';
							           |de = 'Die Datei ""%1"" existiert bereits.
							           |Bestehende Datei ersetzen?'"), VolumesFilesArchivePath);
					Result.ConfirmationRequired = True;
				EndIf;
			EndIf;
		EndIf;
		
		If Result.DataReady Then
			If InfobaseFile.Exist() AND NOT Result.ConfirmationRequired Then
				Result.QuestionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Файл ""%1"" уже существует.
						           |Заменить существующий файл?'; 
						           |en = 'File ""%1"" already exists.
						           |Replace the existing file?'; 
						           |pl = 'Plik ""%1"" już istnieje.
						           |Zastąpić istniejący plik?';
						           |es_ES = 'El archivo ""%1"" ya existe.
						           |¿Reemplazar el archivo existente?';
						           |es_CO = 'El archivo ""%1"" ya existe.
						           |¿Reemplazar el archivo existente?';
						           |tr = '""%1"" dosyası zaten mevcut.
						           |Mevcut dosya değiştirilsin mi?';
						           |it = 'Il file ""%1"" già esiste.
						           |Sostituire il file esistente?';
						           |de = 'Die Datei ""%1"" existiert bereits.
						           |Bestehende Datei ersetzen?'"), FullFileInfobaseName);
				Result.ConfirmationRequired = True;
			EndIf;
			
			// Create a temporary directory.
			DirectoryName = GetTempFileName();
			CreateDirectory(DirectoryName);
			
			// Creating a temporary file directory.
			FileDirectoryName = GetTempFileName();
			CreateDirectory(FileDirectoryName);
			
			// To pass a file directory path to the OnSendFileData handler.
			SaveSetting("FileExchange", "TemporaryDirectory", FileDirectoryName);
			
			// Adding variables to the parameters that are required to create the initial image.
			ParametersStructure.Insert("DirectoryName", DirectoryName);
			ParametersStructure.Insert("FileDirectoryName", FileDirectoryName);
			ParametersStructure.Insert("HasFilesInVolumes", HasFilesInVolumes);
			ParametersStructure.Insert("VolumesFilesArchivePath", VolumesFilesArchivePath);
			ParametersStructure.Insert("FullFileInfobaseName", FullFileInfobaseName);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Create file initial image on the server.
//
Procedure CreateFileInitialImageAtServer(Parameters, StorageAddress) Export
	
	Try
		
		ConnectionString = "File=""" + Parameters.DirectoryName + """;"
						 + "Locale=""" + Parameters.Language + """;";
		ExchangePlans.CreateInitialImage(Parameters.Node, ConnectionString);  // Actual creation of the initial image.
		
		If Parameters.HasFilesInVolumes Then
			ZIP = New ZipFileWriter;
			ZIP.Open(Parameters.VolumesFilesArchivePath);
			
			TemporaryFiles = New Array;
			TemporaryFiles = FindFiles(Parameters.FileDirectoryName, "*.*");
			
			For Each TempFile In TemporaryFiles Do
				If TempFile.IsFile() Then
					TemporaryFilePath = TempFile.FullName;
					ZIP.Add(TemporaryFilePath);
				EndIf;
			EndDo;
			
			ZIP.Write();
			
			DeleteFiles(Parameters.FileDirectoryName); // Deleting along with all the files inside.
		EndIf;
		
	Except
		
		DeleteFiles(Parameters.DirectoryName);
		Raise;
		
	EndTry;
	
	TemporaryInfobaseFilePath = Parameters.DirectoryName + "\1Cv8.1CD";
	MoveFile(TemporaryInfobaseFilePath, Parameters.FullFileInfobaseName);
	
	// clearing
	DeleteFiles(Parameters.DirectoryName);
	
EndProcedure

// Preparation of parameters and preliminary checks before creating a server initial image.
//
Function PrepareDataToCreateServerInitialImage(ParametersStructure) Export
	
	Result = New Structure("DataReady, ConfirmationRequired, QuestionText", True, False, "");
	
	Node 							= ParametersStructure.Node;
	ConnectionString 				= ParametersStructure.ConnectionString;
	WindowsVolumesFilesArchivePath = ParametersStructure.WindowsVolumesFilesArchivePath;
	PathToVolumeFilesArchiveLinux 	= ParametersStructure.PathToVolumeFilesArchiveLinux;
	
	VolumesFilesArchivePath = "";
	FullFileInfobaseName = "";
	
	HasFilesInVolumes = False;
	
	If FilesOperations.HasFileStorageVolumes() Then
		HasFilesInVolumes = HasFilesInVolumes();
	EndIf;
	
	SystemInfo = New SystemInfo;
	ServerPlatformType = SystemInfo.PlatformType;
	
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		VolumesFilesArchivePath = WindowsVolumesFilesArchivePath;
		
		If HasFilesInVolumes Then
			If Not IsBlankString(VolumesFilesArchivePath)
			   AND (Left(VolumesFilesArchivePath, 2) <> "\\"
			 OR StrFind(VolumesFilesArchivePath, ":") <> 0) Then
				
				CommonClientServer.MessageToUser(
					NStr("ru = 'Путь к архиву с файлами томов должен быть
					           |в формате UNC (\\servername\resource).'; 
					           |en = 'Path to the archive with volume files must have
					           |the UNC format (\\servername\resource).'; 
					           |pl = 'Ścieżka do archiwum z plikami woluminów musi być
					           |w formacie UNC (\\servername\resource).';
					           |es_ES = 'La ruta al archivo con documentos de tomos debe ser
					           |en el formato UNC (\\servername\resource)';
					           |es_CO = 'La ruta al archivo con documentos de tomos debe ser
					           |en el formato UNC (\\servername\resource)';
					           |tr = 'Birim dosyalarıyla arşiv yolu 
					           |UNC biçiminde olmalıdır (\\servername\resource).';
					           |it = 'Il percorso all''archivio con file di volume deve avere
					           |formato UNC (\\servername\resource).';
					           |de = 'Der Pfad zum Archiv der Volumendatei muss
					           |im UNC-Format (\\servername\resource) vorliegen.'"),
					,
					"WindowsVolumesFilesArchivePath");
				Result.DataReady = False;
			EndIf;
		EndIf;
		
	Else
		VolumesFilesArchivePath = PathToVolumeFilesArchiveLinux;
	EndIf;
	
	If Result.DataReady Then
		If HasFilesInVolumes AND IsBlankString(VolumesFilesArchivePath) Then
				CommonClientServer.MessageToUser(
					NStr("ru = 'Укажите полное имя архива с файлами томов (файл *.zip)'; en = 'Specify the full name of the archive with volume files (it is a *.zip file)'; pl = 'Określ pełną nazwę archiwum z plikami woluminów (plik *.zip)';es_ES = 'Especificar un nombre completo de un archivo con documentos del volumen (archivo *.zip)';es_CO = 'Especificar un nombre completo de un archivo con documentos del volumen (archivo *.zip)';tr = 'Birim dosyaları ile arşivin tam adını belirtin (dosya * .zip)';it = 'Specifica il nome completo dell''archivio con i file volume (è un file *.zip)';de = 'Geben Sie einen vollständigen Namen eines Archivs mit Volumen-Dateien an (Datei *.zip)'"),
					,
					"WindowsVolumesFilesArchivePath");
				Result.DataReady = False;
		Else
			If HasFilesInVolumes Then
				File = New File(VolumesFilesArchivePath);
				If File.Exist() Then
					Result.QuestionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Файл ""%1"" уже существует.
							           |Заменить существующий файл?'; 
							           |en = 'File ""%1"" already exists.
							           |Replace the existing file?'; 
							           |pl = 'Plik ""%1"" już istnieje.
							           |Zastąpić istniejący plik?';
							           |es_ES = 'El archivo ""%1"" ya existe.
							           |¿Reemplazar el archivo existente?';
							           |es_CO = 'El archivo ""%1"" ya existe.
							           |¿Reemplazar el archivo existente?';
							           |tr = '""%1"" dosyası zaten mevcut.
							           |Mevcut dosya değiştirilsin mi?';
							           |it = 'Il file ""%1"" già esiste.
							           |Sostituire il file esistente?';
							           |de = 'Die Datei ""%1"" existiert bereits.
							           |Bestehende Datei ersetzen?'"), VolumesFilesArchivePath);
					Result.ConfirmationRequired = True;
				EndIf;
			EndIf;
			
			// Create a temporary directory.
			DirectoryName = GetTempFileName();
			CreateDirectory(DirectoryName);
			
			// Creating a temporary file directory.
			FileDirectoryName = GetTempFileName();
			CreateDirectory(FileDirectoryName);
			
			// To pass a file directory path to the OnSendFileData handler.
			SaveSetting("FileExchange", "TemporaryDirectory", FileDirectoryName);
			
			// Adding variables to the parameters that are required to create the initial image.
			ParametersStructure.Insert("HasFilesInVolumes", HasFilesInVolumes);
			ParametersStructure.Insert("FilePath", VolumesFilesArchivePath);
			ParametersStructure.Insert("DirectoryName", DirectoryName);
			ParametersStructure.Insert("FileDirectoryName", FileDirectoryName);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Create server initial image on the server.
//
Procedure CreateServerInitialImageAtServer(Parameters, ResultAddress) Export
	
	Try
		
		ExchangePlans.CreateInitialImage(Parameters.Node, Parameters.ConnectionString);
		
		If Parameters.HasFilesInVolumes Then
			ZIP = New ZipFileWriter;
			ZIPPath = Parameters.FilePath;
			ZIP.Open(ZIPPath);
			
			TemporaryFiles = New Array;
			TemporaryFiles = FindFiles(Parameters.FileDirectoryName, "*.*");
			
			For Each TempFile In TemporaryFiles Do
				If TempFile.IsFile() Then
					TemporaryFilePath = TempFile.FullName;
					ZIP.Add(TemporaryFilePath);
				EndIf;
			EndDo;
			
			ZIP.Write();
			DeleteFiles(Parameters.FileDirectoryName); // Deleting along with all the files inside.
		EndIf;
		
	Except
		
		DeleteFiles(Parameters.DirectoryName);
		Raise;
		
	EndTry;
	
	// clearing
	DeleteFiles(Parameters.DirectoryName);
	
EndProcedure

// Adds files to volumes and sets references in FileVersions.
//
Function AddFilesToVolumes(WindowsArchivePath, PathToArchiveLinux) Export
	
	FullFileNameZip = "";
	SystemInfo = New SystemInfo;
	ServerPlatformType = SystemInfo.PlatformType;
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		FullFileNameZip = WindowsArchivePath;
	Else
		FullFileNameZip = PathToArchiveLinux;
	EndIf;
	
	DirectoryName = GetTempFileName();
	CreateDirectory(DirectoryName);
	
	ZIP = New ZipFileReader(FullFileNameZip);
	ZIP.ExtractAll(DirectoryName, ZIPRestoreFilePathsMode.DontRestore);
	
	FilesPathsMap = New Map;
	
	For Each ZIPItem In ZIP.Items Do
		FullFilePath = DirectoryName + "\" + ZIPItem.Name;
		UUID = ZIPItem.BaseName;
		
		FilesPathsMap.Insert(UUID, FullFilePath);
	EndDo;
	
	FilesStorageTyoe = FilesStorageTyoe();
	FilesToAttach = New Array;
	BeginTransaction();
	Try
		FilesOperationsInternalServerCall.AddFilesToVolumesWhenPlacing(
			FilesPathsMap, FilesStorageTyoe);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
		
	// Clearing recent change records.
	For Each ExchangePlan In Metadata.ExchangePlans Do
		ExchangePlanName      = ExchangePlan.Name;
		ExchangePlanManager = ExchangePlans[ExchangePlanName];
		
		ThisNode = ExchangePlanManager.ThisNode();
		Selection = ExchangePlanManager.Select();
		
		While Selection.Next() Do
			
			ExchangePlanObject = Selection.GetObject();
			If ExchangePlanObject.Ref <> ThisNode Then
				FilesOperationsInternalServerCall.DeleteChangeRecords(ExchangePlanObject.Ref);
			EndIf;
		EndDo;
		
	EndDo;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Scheduled job handlers.

// TextExtraction scheduled job handler.
// Extracts text from files on the hard disk.
//
Procedure ExtractTextFromFilesAtServer() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.TextExtraction);
	
	ExtractTextFromFiles();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Extracting text.

// Returns text for a query used to get files with unextracted text.
//
// Parameters:
//  GetAllFiles - Boolean - the initial value is False. If True, disables individual file selection.
//                     
//
// Returns:
//  String - a query text.
//
Function QueryTextToExtractText(GetAllFiles = False, AdditionalFields = False) Export
	
	// Generating the query text for all attached file catalogs
	QueryText = "";
	
	FileTypes = Metadata.DefinedTypes.AttachedFile.Type.Types();
	
	TotalCatalogNames = New Array;
	
	For Each Type In FileTypes Do
		FilesDirectoryMetadata = Metadata.FindByType(Type);
		DontUseFullTextSearch = Metadata.ObjectProperties.FullTextSearchUsing.DontUse;
		If FilesDirectoryMetadata.FullTextSearch = DontUseFullTextSearch Then
			Continue;
		EndIf;
		TotalCatalogNames.Add(FilesDirectoryMetadata.Name);
	EndDo;
	
	FilesNumberInSelection = Int(100 / TotalCatalogNames.Count());
	FilesNumberInSelection = ?(FilesNumberInSelection < 10, 10, FilesNumberInSelection);
	
	For each CatalogName In TotalCatalogNames Do
	
		If NOT IsBlankString(QueryText) Then
			QueryText = QueryText + "
				|
				|UNION ALL
				|
				|";
		EndIf;
		
		QueryText = QueryText + QueryTextForFilesWithUnextractedText(CatalogName,
			FilesNumberInSelection, GetAllFiles, AdditionalFields);
		EndDo;
		
	Return QueryText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Moves ProhibitedFileExtensionList and OpenDocumentFileExtensionList constants.
Procedure MoveExtensionConstants() Export
	
	SetPrivilegedMode(True);
	
	If Not Common.DataSeparationEnabled() Then
		
		DeniedExtensionsList = Constants.DeniedExtensionsList.Get();
		Constants.DeniedDataAreaExtensionsList.Set(DeniedExtensionsList);
		
		FilesExtensionsListOpenDocument = Constants.FilesExtensionsListOpenDocument.Get();
		Constants.FilesExtensionsListDocumentDataAreas.Set(FilesExtensionsListOpenDocument);
		
	EndIf;	
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// Scanning

Function ScannerParametersInEnumerations(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber) Export 
	
	If PermissionNumber = 200 Then
		Permission = Enums.ScannedImageResolutions.dpi200;
	ElsIf PermissionNumber = 300 Then
		Permission = Enums.ScannedImageResolutions.dpi300;
	ElsIf PermissionNumber = 600 Then
		Permission = Enums.ScannedImageResolutions.dpi600;
	ElsIf PermissionNumber = 1200 Then
		Permission = Enums.ScannedImageResolutions.dpi1200;
	EndIf;
	
	If ChromaticityNumber = 0 Then
		Chromaticity = Enums.ImageColorDepths.Monochrome;
	ElsIf ChromaticityNumber = 1 Then
		Chromaticity = Enums.ImageColorDepths.Grayscale;
	ElsIf ChromaticityNumber = 2 Then
		Chromaticity = Enums.ImageColorDepths.Color;
	EndIf;
	
	If RotationNumber = 0 Then
		Rotation = Enums.PictureRotationOptions.NoRotation;
	ElsIf RotationNumber = 90 Then
		Rotation = Enums.PictureRotationOptions.Right90;
	ElsIf RotationNumber = 180 Then
		Rotation = Enums.PictureRotationOptions.Right180;
	ElsIf RotationNumber = 270 Then
		Rotation = Enums.PictureRotationOptions.Left90;
	EndIf;
	
	If PaperSizeNumber = 0 Then
		PaperSize = Enums.PaperSizes.NotDefined;
	ElsIf PaperSizeNumber = 11 Then
		PaperSize = Enums.PaperSizes.A3;
	ElsIf PaperSizeNumber = 1 Then
		PaperSize = Enums.PaperSizes.A4;
	ElsIf PaperSizeNumber = 5 Then
		PaperSize = Enums.PaperSizes.A5;
	ElsIf PaperSizeNumber = 6 Then
		PaperSize = Enums.PaperSizes.B4;
	ElsIf PaperSizeNumber = 2 Then
		PaperSize = Enums.PaperSizes.B5;
	ElsIf PaperSizeNumber = 7 Then
		PaperSize = Enums.PaperSizes.B6;
	ElsIf PaperSizeNumber = 14 Then
		PaperSize = Enums.PaperSizes.C4;
	ElsIf PaperSizeNumber = 15 Then
		PaperSize = Enums.PaperSizes.C5;
	ElsIf PaperSizeNumber = 16 Then
		PaperSize = Enums.PaperSizes.C6;
	ElsIf PaperSizeNumber = 3 Then
		PaperSize = Enums.PaperSizes.USLetter;
	ElsIf PaperSizeNumber = 4 Then
		PaperSize = Enums.PaperSizes.USLegal;
	ElsIf PaperSizeNumber = 10 Then
		PaperSize = Enums.PaperSizes.USExecutive;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Permission", Permission);
	Result.Insert("Chromaticity", Chromaticity);
	Result.Insert("Rotation", Rotation);
	Result.Insert("PaperSize", PaperSize);
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Clear unused files

Procedure ClearExcessiveFiles(Parameters = Undefined, ResultAddress = Undefined) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ExcessiveFilesClearing);
	
	SetPrivilegedMode(True);
	
	CleanupSettings = InformationRegisters.FilesClearingSettings.CurrentClearSettings();
	
	FilesClearingSettings = CleanupSettings.FindRows(New Structure("IsCatalogItemSetup", False));
	
	For Each Setting In FilesClearingSettings Do
		
		ExceptionsArray = New Array;
		DetailedSettings = CleanupSettings.FindRows(New Structure(
		"OwnerID, IsCatalogItemSetup",
			Setting.FileOwner,
			True));
		If DetailedSettings.Count() > 0 Then
			For Each ExceptionItem In DetailedSettings Do
				ExceptionsArray.Add(ExceptionItem.FileOwner);
				ClearUnusedFilesData(ExceptionItem);
			EndDo;
		EndIf;
		
		ClearUnusedFilesData(Setting, ExceptionsArray);
	EndDo;
	

EndProcedure

Function ExceptionItemsOnClearFiles() Export
	
	Return FilesSettings().DontClearFiles;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See StandardSubsystemsServer.OnSendDataToSlave. 
Procedure OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient) Export
	
	WhenSendingFile(DataItem, ItemSend, InitialImageCreation, Recipient);
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToMaster. 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	WhenSendingFile(DataItem, ItemSend);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave. 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender) Export
	
	WhenReceivingFile(DataItem, GetItem, Sender);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster. 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender) Export
	
	WhenReceivingFile(DataItem, GetItem);
	
EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(Array) Export
	
	Array.Add(Metadata.InformationRegisters.FilesInWorkingDirectory.FullName());
	Array.Add(Metadata.InformationRegisters.FilesInfo.FullName());
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("Read", Metadata.Catalogs.Files)
		Or ModuleToDoListServer.UserTaskDisabled("FilesToEdit") Then
		Return;
	EndIf;
	
	LockedFilesCount = LockedFilesCount();
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.Files.FullName());
	
	For Each Section In Sections Do
		
		EditedFilesID = "FilesToEdit" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID  = EditedFilesID;
		UserTask.HasUserTasks       = LockedFilesCount > 0;
		UserTask.Presentation  = NStr("ru = 'Редактируемые файлы'; en = 'Files to edit'; pl = 'Edytowane pliki';es_ES = 'Archivos en edición';es_CO = 'Archivos en edición';tr = 'Düzenlenen dosyalar';it = 'File da modificare';de = 'Dateien werden bearbeitet'");
		UserTask.Count     = LockedFilesCount;
		UserTask.Important         = False;
		UserTask.Form          = "DataProcessor.FilesOperations.Form.FilesToEdit";
		UserTask.Owner       = Section;
		
	EndDo;
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.FileFolders.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.Files.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.FilesVersions.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.FileStorageVolumes.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// File synchronization with cloud service.
	
	// Import to the FilesStorageVolumes is prohibited.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.FileStorageVolumes.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Dependencies) Export
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.TextExtraction;
	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
		Dependence.FunctionalOption = ModuleFullTextSearchServer.UseFullTextSearch();
	EndIf;
	Dependence.AvailableSaaS = False;
	
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.ExcessiveFilesClearing;
	Dependence.UseExternalResources = True;
	
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.FileSynchronization;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseFileSync;
	Dependence.UseExternalResources = True;
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.FilesVersions, True);
	Lists.Insert(Metadata.Catalogs.FileFolders, True);
	Lists.Insert(Metadata.Catalogs.Files, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillAvailableRightsForObjectsRightsSettings. 
Procedure OnFillAvailableRightsForObjectsRightsSettings(AvailableRights) Export
	
	////////////////////////////////////////////////////////////
	// Catalog.FileFolders
	
	// Read folders and files right.
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FileFolders.FullName();
	Right.Name           = "Read";
	Right.Title     = NStr("ru = 'Чтение'; en = 'Read'; pl = 'Do odczytu';es_ES = 'Leer';es_CO = 'Leer';tr = 'Oku';it = 'Lettura';de = 'Lesen'");
	Right.ToolTip     = NStr("ru = 'Чтение папок и файлов'; en = 'Reading folders and files'; pl = 'Odczyt folderów i plików';es_ES = 'Leyendo carpetas y archivos';es_CO = 'Leyendo carpetas y archivos';tr = 'Klasörleri ve dosyaları okuma';it = 'Lettura cartelle e file';de = 'Lesen von Ordnern und Dateien'");
	Right.InitialValue = True;
	// Rights for standard access restriction templates.
	Right.ReadInTables.Add("*");
	
	// Change folders right
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FileFolders.FullName();
	Right.Name           = "FoldersModification";
	Right.Title     = NStr("ru = 'Изменение
	                                 |папок'; 
	                                 |en = 'Change
	                                 |folders'; 
	                                 |pl = 'Zmiana
	                                 |folderów';
	                                 |es_ES = 'Cambio
	                                 |de carpetas';
	                                 |es_CO = 'Cambio
	                                 |de carpetas';
	                                 |tr = 'Klasörlerin 
	                                 |değişikliği';
	                                 |it = 'Modificare
	                                 |cartelle';
	                                 |de = 'Ordner
	                                 |ändern'");
	Right.ToolTip     = NStr("ru = 'Добавление, изменение и
	                                 |пометка удаления папок файлов'; 
	                                 |en = 'Add, change, and
	                                 |set a deletion mark for folders with files'; 
	                                 |pl = 'Dodawanie, zmiana i
	                                 |oznaczanie usuwania folderów plików';
	                                 |es_ES = 'Añadir, cambiar y
	                                 |marcar para borrar las carpetas de archivos';
	                                 |es_CO = 'Añadir, cambiar y
	                                 |marcar para borrar las carpetas de archivos';
	                                 |tr = 'Dosya klasörlerini ekleme, 
	                                 |değiştirme ve etiketleme';
	                                 |it = 'Aggiungere, modificare e
	                                 |impostare un contrassegno di eliminazione per le cartelle con file';
	                                 |de = 'Hinzufügen, Ändern und
	                                 |Markieren von Dateiordnern'");
	// Rights that are required for this right.
	Right.RequiredRights.Add("Read");
	// Rights for standard access restriction templates.
	Right.ChangeInTables.Add(Metadata.Catalogs.FileFolders.FullName());
	
	// Change files right
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FileFolders.FullName();
	Right.Name           = "FilesModification";
	Right.Title     = NStr("ru = 'Изменение
	                                 |файлов'; 
	                                 |en = 'Change 
	                                 |files'; 
	                                 |pl = 'Zmiana
	                                 |plików';
	                                 |es_ES = 'Cambio
	                                 |de archivos';
	                                 |es_CO = 'Cambio
	                                 |de archivos';
	                                 |tr = 'Dosyaları 
	                                 |değiştirme';
	                                 |it = 'Modificare 
	                                 |file';
	                                 |de = 'Dateien
	                                 |ändern'");
	Right.ToolTip     = NStr("ru = 'Изменение файлов в папке'; en = 'Change files in folder'; pl = 'Zmiana pliku w folderze';es_ES = 'Cambiar los archivos en la carpeta';es_CO = 'Cambiar los archivos en la carpeta';tr = 'Klasördeki dosyaları değiştir';it = 'Modificare i file nella cartella';de = 'Ändern Sie die Dateien im Ordner'");
	// Rights that are required for this right.
	Right.RequiredRights.Add("Read");
	// Rights for standard access restriction templates.
	Right.ChangeInTables.Add("*");
	
	// Add files right
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FileFolders.FullName();
	Right.Name           = "AddFiles";
	Right.Title     = NStr("ru = 'Добавление
	                                 |файлов'; 
	                                 |en = 'Add
	                                 |files'; 
	                                 |pl = 'Dodawanie
	                                 |plików';
	                                 |es_ES = 'Añadir
	                                 |archivos';
	                                 |es_CO = 'Añadir
	                                 |archivos';
	                                 |tr = 'Dosyaları 
	                                 | ekleme';
	                                 |it = 'Aggiunta
	                                 |di file';
	                                 |de = 'Dateien
	                                 |hinzufügen'");
	Right.ToolTip     = NStr("ru = 'Добавление файлов в папку'; en = 'Add files to folder'; pl = 'Dodawanie plików do folderu';es_ES = 'Agregar los archivos a la carpeta';es_CO = 'Agregar los archivos a la carpeta';tr = 'Klasöre dosya ekle';it = 'Aggiungi file alla cartella';de = 'Dateien zum Ordner hinzufügen'");
	// Rights that are required for this right.
	Right.RequiredRights.Add("FilesModification");
	
	// File deletion mark right.
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FileFolders.FullName();
	Right.Name           = "FilesDeletionMark";
	Right.Title     = NStr("ru = 'Пометка
	                                 |удаления'; 
	                                 |en = 'Deletion 
	                                 |mark'; 
	                                 |pl = 'Oznaczanie
	                                 |usunięcia';
	                                 |es_ES = 'Marcar para
	                                 |borrar';
	                                 |es_CO = 'Marcar para
	                                 |borrar';
	                                 |tr = 'Silme 
	                                 |işareti';
	                                 |it = 'Contrassegno 
	                                 |di eliminazione';
	                                 |de = 'Markierung
	                                 |entfernen'");
	Right.ToolTip     = NStr("ru = 'Пометка удаления файлов в папке'; en = 'File deletion mark in the folder'; pl = 'Znacznik usunięcia pliku w folderze';es_ES = 'Marca de borrado del archivo en la carpeta';es_CO = 'Marca de borrado del archivo en la carpeta';tr = 'Klasördeki dosya silme işareti';it = 'File contrassegnato per l''eliminazione nella cartella';de = 'Dateilöschmarkierung im Ordner'");
	// Rights that are required for this right.
	Right.RequiredRights.Add("FilesModification");
	
	Right = AvailableRights.Add();
	Right.RightsOwner  = Metadata.Catalogs.FileFolders.FullName();
	Right.Name           = "RightsManagement";
	Right.Title     = NStr("ru = 'Управление
	                                 |правами'; 
	                                 |en = 'Right 
	                                 |management'; 
	                                 |pl = 'Zarządzanie
	                                 |uprawnieniami';
	                                 |es_ES = 'Gestión
	                                 |de derechos';
	                                 |es_CO = 'Gestión
	                                 |de derechos';
	                                 |tr = 'Haklar 
	                                 | yönetimi';
	                                 |it = 'Gestione
	                                 |diritti';
	                                 |de = 'Rechte
	                                 |verwalten'");
	Right.ToolTip     = NStr("ru = 'Управление правами папки'; en = 'Folder right management'; pl = 'Zarządzanie prawami folderu';es_ES = 'Gestión de los derechos de la carpeta';es_CO = 'Gestión de los derechos de la carpeta';tr = 'Klasör doğru yönetimi';it = 'Cartella Gestione destra';de = 'Ordner Rechteverwaltung'");
	// Rights that are required for this right.
	Right.RequiredRights.Add("Read");
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionsKinds. 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	Details = Details + "
		|Catalog.FileFolders.Read.RightsSettings.Catalog.FileFolders
		|Catalog.FileFolders.Update.RightsSettings.Catalog.FileFolders
		|";
	
	FilesOwnersTypes = Metadata.DefinedTypes.FilesOwner.Type.Types();
	For Each OwnerType In FilesOwnersTypes Do
		
		OwnerMetadata = Metadata.FindByType(OwnerType);
		If OwnerMetadata = Undefined Then
			Continue;
		EndIf;
		
		FullOwnerName = OwnerMetadata.FullName();
		
		Details = Details + "
			|Catalog.FilesVersions.Read.Object." + FullOwnerName + "
			|Catalog.FilesVersions.Update.Object." + FullOwnerName + "
			|Catalog.Files.Read.Object." + FullOwnerName + "
			|Catalog.Files.Update.Object." + FullOwnerName + "
			|";
		
	EndDo;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2"; // When updating to 1.0.5.2 the handler will start.
	Handler.Procedure = "FilesOperationsInternalServerCall.FillVersionNumberFromCatalogCode";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2"; // When updating to 1.0.5.2 the handler will start.
	Handler.Procedure = "FilesOperationsInternalServerCall.FillFileStorageTypeInInfobase";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.7"; // When updating to 1.0.5.7 the handler will start.
	Handler.Procedure = "FilesOperationsInternalServerCall.ChangeIconIndex";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.3"; // When updating to 1.0.6.3 the handler will start.
	Handler.SharedData = True;
	Handler.Procedure = "FilesOperationsInternalServerCall.FillVolumePaths";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.7.1";
	Handler.Procedure = "FilesOperationsInternalServerCall.OverwriteAllFiles";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.2.2";
	Handler.Procedure = "FilesOperationsInternalServerCall.FillFileModificationDate";
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.1.2";
	Handler.Procedure = "FilesOperationsInternalServerCall.MoveFilesFromInfobaseToInformationRegister";
	
	Handler = Handlers.Add();
	Handler.Version = "1.2.1.2";
	Handler.Procedure = "FilesOperationsInternalServerCall.FillLoanDate";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.1.6";
	Handler.Procedure = "FilesOperationsInternal.MoveExtensionConstants";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.Procedure = "FilesOperationsInternalServerCall.ReplaceRightsInFileFolderRightsSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.SharedData = True;
	Handler.InitialFilling = True;
	Handler.Procedure = "FilesOperationsInternal.UpdateDeniedExtensionsList";
	Handler.ExecutionMode = "Seamless";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.InitialFilling = True;
	Handler.Procedure = "FilesOperationsInternal.UpdateProhibitedExtensionListInDataArea";
	Handler.ExecutionMode = "Seamless";
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		
		Handler = Handlers.Add();
		Handler.Version = "2.4.1.49";
		Handler.Comment =
			NStr("ru = 'Перенос электронных подписей и сертификатов шифрования
			           |из табличных частей в регистры сведений.'; 
			           |en = 'Transfer digital signatures and encryption certificates from
			           |tabular sections to information registers.'; 
			           |pl = 'Przenoszenie cyfrowych podpisów i certyfikatów szyfrowania
			           |z tabelarycznych części do rejestrów informacji.';
			           |es_ES = 'El traslado de las firmas electrónicas y certificados de cifrado
			           |de las partes de tabla en el registro de información.';
			           |es_CO = 'El traslado de las firmas electrónicas y certificados de cifrado
			           |de las partes de tabla en el registro de información.';
			           |tr = 'Elektronik imzaları ve şifreleme sertifikalarını tablo 
			           |parçalarından bilgi kayıtlarına aktarma.';
			           |it = 'Trasferimento delle firme elettroniche e dei certificati di cifratura
			           |dalle parti tabellari nel registro delle informazioni.';
			           |de = 'Übertragung von digitalen Signaturen und Verschlüsselungszertifikaten
			           |von tabellarischen Teilen in Datenregistern.'");
		Handler.ID = New UUID("d70f378a-41f5-4b0a-a1a7-f4ba27c7f91b");
		Handler.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters";
		Handler.ExecutionMode = "Deferred";
		Handler.DeferredProcessingQueue = 1;
		Handler.UpdateDataFillingProcedure = "FilesOperationsInternalServerCall.RegisterObjectsToMoveDigitalSignaturesAndEncryptionCertificates";
		Handler.ObjectsToRead      = StrConcat(FilesOperationsInternalServerCall.FullCatalogsNamesOfAttachedFiles(), ", ");
		Handler.ObjectsToChange    = FilesOperationsInternalServerCall.ObjectsToModifyOnTransferDigitalSignaturesAndEncryptionResults();
		Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
		Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "InformationRegisters.FilesBinaryData.ProcessDataForMigrationToNewVersion";
		Priority.Order = "Any";
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion";
		Priority.Order = "Any";
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion";
		Priority.Order = "Any";
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "Catalogs.Files.ProcessDataForMigrationToNewVersion";
		Priority.Order = "Any";
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesFromFIleVersionsToFiles";
		Priority.Order = "Any";
		
		Handler = Handlers.Add();
		Handler.Version = "2.4.1.62";
		Handler.Comment =
			NStr("ru = 'Перенос электронных подписей с версий файлов на файлы.'; en = 'Transfer digital signatures from file versions to files.'; pl = 'Przesyłanie podpisów cyfrowych z wersji plików do plików.';es_ES = 'Traslado de firmas electrónicas con versiones de archivos a los archivos.';es_CO = 'Traslado de firmas electrónicas con versiones de archivos a los archivos.';tr = 'Elektronik imzaları dosya sürümlerinden dosyalara aktarma.';it = 'Trasferire firme digitali dalle versioni di file ai file.';de = 'Übertragung von digitalen Signaturen aus Dateiversionen in Dateien.'");
		Handler.ID = New UUID("d0a26f83-8dd3-4965-93a6-8469c9c91998");
		Handler.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesFromFIleVersionsToFiles";
		Handler.ExecutionMode = "Deferred";
		Handler.DeferredProcessingQueue = 2;
		Handler.UpdateDataFillingProcedure = "FilesOperationsInternalServerCall.RegisterObjectsToMoveDigitalSignaturesFromFileVersionsToFiles";
		Handler.ObjectsToRead      = FilesOperationsInternalServerCall.ObjectsOnTransferDigitalSignaturesFromFilesVersionsToFiles(True);
		Handler.ObjectsToChange    = FilesOperationsInternalServerCall.ObjectsOnTransferDigitalSignaturesFromFilesVersionsToFiles(False);
		Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
		Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "InformationRegisters.FilesBinaryData.ProcessDataForMigrationToNewVersion";
		Priority.Order = "Any";
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion";
		Priority.Order = "Any";
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters";
		Priority.Order = "Any";
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.50";
	Handler.Comment =
			NStr("ru = 'Перенос двоичных данных файлов в регистр сведений Двоичные данные файлов.'; en = 'Transfer binary file data to the Binary file data information register.'; pl = 'Przesyłanie plików danych binarnych do informacji o rejestrze Pliki danych binarnych.';es_ES = 'Traslado de los datos binarios de archivos al registro de información Datos binarios de archivos.';es_CO = 'Traslado de los datos binarios de archivos al registro de información Datos binarios de archivos.';tr = 'İkili veri dosyalarını ikili veri dosyalarının kayıt bilgilerini aktarma.';it = 'Trasferire dati file binario dal registro informazioni dei dati del file Binario.';de = 'Übertragung von Binärdatei-Daten ins Informationsregister von Binärdatei-Daten.'");
	Handler.ID = New UUID("bb2c6a93-98b0-4a01-8793-6b82f316490e");
	Handler.Procedure = "InformationRegisters.FilesBinaryData.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.DeferredProcessingQueue = 2;
	Handler.UpdateDataFillingProcedure = "InformationRegisters.FilesBinaryData.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead      = "Catalog.FilesVersions";
	Handler.ObjectsToChange    = "InformationRegister.FilesBinaryData";
	Handler.ObjectsToLock   = "Catalog.Files, Catalog.FilesVersions";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesFromFIleVersionsToFiles";
	Priority.Order = "Any";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.Comment =
			NStr("ru = 'Перенос информации о наличии файлов в регистр сведений Наличие файлов.'; en = 'Transfer information about file existence to the File existence information register.'; pl = 'Przekazywanie informacji o obecności plików w informacji o rejestrze Obecność plików.';es_ES = 'Traslado de infirmación de presencia de archivos al registro d información Presencia de archivos.';es_CO = 'Traslado de infirmación de presencia de archivos al registro d información Presencia de archivos.';tr = 'Kayıt bilgilerindeki dosyaların varlığı hakkında bilgi aktarımı Dosyaların varlığı.';it = 'Trasferire informazioni sull''esistenza del file al registro informazioni dell''esistenza del file.';de = 'Übertragung von Informationen der Dateiverfügbarkeit in das Datenregister Verfügbarkeit von Dateien.'");
	Handler.ID = New UUID("a84931bb-dfd5-4525-ab4a-1a0646e17334");
	Handler.Procedure = "InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "InformationRegisters.FilesExist.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead      = "Catalog.Files";
	Handler.ObjectsToChange    = "InformationRegister.FilesExist";
	Handler.ObjectsToLock   = "Catalog.Files";
	Handler.DeferredProcessingQueue = 3;
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "Catalogs.Files.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.Comment =
			NStr("ru = 'Перенос информации о файлах в регистр сведений Сведения о файлах.'; en = 'Transfer file information to the ""File information"" information register.'; pl = 'Przenoszenie informacji o pliku do rejestru Informacji o plikach.';es_ES = 'Traslado de información de archivos al registro de información Información de archivos.';es_CO = 'Traslado de información de archivos al registro de información Información de archivos.';tr = 'Dosyalar ile ilgili bilgilerin kayıt bilgi dosyası bilgisine aktarılması.';it = 'Trasferire informazioni file al registro informazioni ""Informazioni file"".';de = 'Übertragen von Informationen zu Dateien in das Dateiinformationsregister Dateiinformationen.'");
	Handler.ID = New UUID("5137a43e-75aa-4a68-ba2f-525a3a646af8");
	Handler.Procedure = "InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.ObjectsToRead      = "Catalog.Files";
	Handler.ObjectsToChange    = "InformationRegister.FilesInfo";
	Handler.ObjectsToLock   = "Catalog.Files";
	Handler.DeferredProcessingQueue = 4;
	Handler.UpdateDataFillingProcedure = "InformationRegisters.FilesInfo.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.FilesBinaryData.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "Catalogs.Files.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesFromFIleVersionsToFiles";
	Priority.Order = "Any";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.3.56";
	Handler.Comment =
			NStr("ru = 'Обновление универсальной даты и типа хранения элементов справочника Файлы.'; en = 'Update universal date and storage type of the ""Files"" catalog items.'; pl = 'Zaktualizuj uniwersalną datę i typ przechowywania elementów katalogu Pliki.';es_ES = 'Actualización de la fecha universal y del tipo de guarda de elementos del catálogo Archivos.';es_CO = 'Actualización de la fecha universal y del tipo de guarda de elementos del catálogo Archivos.';tr = 'Genel tarih ve Dosyalar katalogu öğeleri depolama türünü güncelleştirme.';it = 'Aggiornare data universale e tipo di archiviazione degli elementi di catalogo ""File"".';de = 'Aktualisieren Sie das universelle Datum und den Speichertyp des Dateiverzeichnisses.'");
	Handler.ID = New UUID("8b417c47-dd46-45ce-b59b-c675059c9020");
	Handler.Procedure = "Catalogs.Files.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.ObjectsToRead      = "Catalog.Files";
	Handler.ObjectsToChange    = "Catalog.Files";
	Handler.ObjectsToLock   = "Catalog.Files, Catalog.FilesVersions";
	Handler.DeferredProcessingQueue = 5;
	Handler.UpdateDataFillingProcedure = "Catalogs.Files.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "FilesOperationsInternalServerCall.MoveDigitalSignaturesAndEncryptionCertificatesToInformationRegisters";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.FilesExist.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.FilesBinaryData.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.FilesInfo.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Any";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.SharedData = True;
	Handler.Procedure = "FilesOperationsInternal.UpdateVolumePathLinux";
	Handler.ExecutionMode = "Seamless";
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.FileFolderOperations";
	NewName  = "Role.AddEditFoldersAndFiles";
	Common.AddRenaming(Total, "2.4.1.1", OldName, NewName, Library);
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	FilesOperationSettings = FilesOperationsServiceCached.FilesOperationSettings();
	
	Parameters.Insert("PersonalFilesOperationsSettings", New FixedStructure(
		FilesOperationSettings.PersonalSettings));
	
	Parameters.Insert("CommonFilesOperationsSettings", New FixedStructure(
		FilesOperationSettings.CommonSettings));
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	FilesOperationSettings = FilesOperationsServiceCached.FilesOperationSettings();
	
	Parameters.Insert("PersonalFilesOperationsSettings", New FixedStructure(
		FilesOperationSettings.PersonalSettings));
		
	LockedFilesCount = 0;
	If Common.SeparatedDataUsageAvailable() Then
		User = UsersClientServer.AuthorizedUser();
		If TypeOf(User) = Type("CatalogRef.Users") Then
			LockedFilesCount = LockedFilesCount();
		EndIf;
	EndIf;
	
	Parameters.Insert("LockedFilesCount", LockedFilesCount);
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If GetFunctionalOption("StoreFilesInVolumesOnHardDrive") Then
		Catalogs.FileStorageVolumes.AddRequestsToUseExternalResourcesForAllVolumes(PermissionRequests);
	EndIf;
	
EndProcedure

// See DataExportImportOverridable.OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport. 
Procedure OnFillCommonDataTypesThatDoNotRequireMappingRefsOnImport(Types) Export
	
	// During data export the references to the FileStorageVolumes catalog are cleared, and during data 
	// import the import is performed according to the volume settings of the infobase, to which the 
	// data is imported (not according to the volume settings of the infobase, from which the data is 
	// exported).
	Types.Add(Metadata.Catalogs.FileStorageVolumes);
	
EndProcedure

// See ReportsOptionsOverridable.CustomizeReportOptions. 
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.IrrelevantFilesVolume);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.VolumeIntegrityCheck);
EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters. 
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	
	QueryText = 
		"SELECT
		|	COUNT(1) AS Count
		|FROM
		|	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.FileSynchronizationAccounts", Selection.Count());
	
EndProcedure

#EndRegion

#Region Private

// Returns the URL to the file (to an attribute or temporary storage).
Function FileURL(FileRef, UUID) Export
	
	If IsItemFilesOperations(FileRef) Then
		Return FilesOperationsInternalServerCall.GetURLToOpen(FileRef, UUID);
	EndIf;
	
	Return Undefined;
	
EndFunction

// On write subscription handler of the attached file.
//
Procedure OnWriteAttachedFileServer(FilesOwner, Source) Export
	
	SetPrivilegedMode(True);
	BeginTransaction();
	Try
	
		RecordChanged = False;
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.InformationRegisters.FilesExist.FullName());
		DataLockItem.SetValue("ObjectWithFiles", FilesOwner);
		DataLock.Lock();
		
		RecordManager = InformationRegisters.FilesExist.CreateRecordManager();
		RecordManager.ObjectWithFiles = FilesOwner;
		RecordManager.Read();
		
		If NOT ValueIsFilled(RecordManager.ObjectWithFiles) Then
			RecordManager.ObjectWithFiles = FilesOwner;
			RecordChanged = True;
		EndIf;
		
		If NOT RecordManager.HasFiles Then
			RecordManager.HasFiles = True;
			RecordChanged = True;
		EndIf;
		
		If IsBlankString(RecordManager.ObjectID) Then
			RecordManager.ObjectID = GetNextObjectID();
			RecordChanged = True;
		EndIf;
		
		If RecordChanged Then
			RecordManager.Write();
		EndIf;
		
		If Not Source.IsFolder Then
			RecordManager = InformationRegisters.FilesInfo.CreateRecordManager();
			FillPropertyValues(RecordManager, Source);
			RecordManager.File = Source;
			If Source.SignedWithDS AND Source.Encrypted Then
				RecordManager.SignedEncryptedPictureNumber = 2;
			ElsIf Source.Encrypted Then
				RecordManager.SignedEncryptedPictureNumber = 1;
			ElsIf Source.SignedWithDS Then
				RecordManager.SignedEncryptedPictureNumber = 0;
			Else
				RecordManager.SignedEncryptedPictureNumber = -1;
			EndIf;
			
			RecordManager.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// The internal function is used when creating the initial image.
// Always executed on the server.
//
Procedure CopyFileOnCreateInitialImage(FullPath, NewFilePath)
	
	Try
		// If the file is in the volume, copy it to the temporary directory (during the initial image generation).
		FileCopy(FullPath, NewFilePath);
		TemporaryFile = New File(NewFilePath);
		TemporaryFile.SetReadOnly(False);
	Except
		// Cannot register, possibly the file is not found.
		// The missing file can be restored later, so the exception is ignored in order not to stop the 
		// initial image creation.
	EndTry;
	
EndProcedure

// An internal function that stores binary file data to a value storage.
// 
//
Function PutBinaryDataInStorage(Volume, PathToFile, UUID)
	
	FullPath = FullVolumePath(Volume) + PathToFile;
	UUID = UUID;
	
	BinaryData = New BinaryData(FullPath);
	Return New ValueStorage(BinaryData);
	
EndFunction

Procedure ClearDataOnVersion(FileRef)
	
	FileNameWithPath = "";
	FileNameWithPathForDeletion = "";
	
	BeginTransaction();
	
	Try
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
		DataLockItem.SetValue("Ref", FileRef);
		DataLock.Lock();
		
		FileObject = FileRef.GetObject();
		
		CommentText = NStr("ru = 'Файл удален при очистке ненужных файлов.'; en = 'The file was deleted while cleaning up unused files.'; pl = 'Plik usunięty podczas czyszczenia niepotrzebnych plików.';es_ES = 'El archivo ha sido eliminado al limpiar los archivos no necesarios.';es_CO = 'El archivo ha sido eliminado al limpiar los archivos no necesarios.';tr = 'Gereksiz dosyaları temizlerken dosya silinir.';it = 'Il file è stato eliminato durante la pulizia dei file non utilizzati.';de = 'Datei wurde gelöscht, wenn nicht benötigte Dateien bereinigt wurden.'")
			+ " " + Format(CurrentSessionDate(),"DLF=D") + Chars.LF;
		
		If FileObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			FileNameWithPath = FullVolumePath(FileObject.Volume) + FileObject.PathToFile;
			FileNameWithPathForDeletion = FileNameWithPath + ".del";
			FileOnHardDrive = New File(FileNameWithPath);
			If FileOnHardDrive.Exist() Then
				FileOnHardDrive.SetReadOnly(False);
				// Moving file to a temporary one.
				MoveFile(FileNameWithPath, FileNameWithPathForDeletion);
				FileObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				FileObject.PathToFile = "";
				FileObject.Comment = CommentText + FileObject.Comment;
				FileObject.Write();
				FileObject.SetDeletionMark(True);
				// Deleting the temporary file, because file data was successfully updated.
				DeleteFiles(FileNameWithPathForDeletion);
			EndIf;
		Else
			FilesOperationsInternalServerCall.DeleteRecordFromRegisterOfFilesBinaryData(FileRef);
			FileObject.Comment = CommentText + FileObject.Comment;
			FileObject.Write();
			FileObject.SetDeletionMark(True);
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		If Not IsBlankString(FileNameWithPath) Then
			
			// Write an error to the event log.
			WriteLogEvent(NStr("ru = 'Очистка ненужных файлов'; en = 'Clear unused files'; pl = 'Oczyszczenie niepotrzebnych plików';es_ES = 'Limpiar archivos no necesarios';es_CO = 'Limpiar archivos no necesarios';tr = 'Kullanılmayan dosyaları temizle';it = 'Cancellare file non utilizzati';de = 'Unnötige Dateien bereinigen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,, FileRef, DetailErrorDescription(ErrorInfo()));
			
			// Returning the file to its original place in case of an error.
			MoveFile(FileNameWithPathForDeletion, FileNameWithPath);
			
		EndIf;
		
	EndTry;
	
EndProcedure

Procedure ClearDataAboutFile(FileRef)
	
	FileNameWithPath = "";
	FileNameWithPathForDeletion = "";
	
	BeginTransaction();
	
	Try
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
		DataLockItem.SetValue("Ref", FileRef);
		DataLock.Lock();
		
		FileObject = FileRef.GetObject();
		
		DetailsText = NStr("ru = 'Файл удален при очистке ненужных файлов.'; en = 'The file was deleted while cleaning up unused files.'; pl = 'Plik usunięty podczas czyszczenia niepotrzebnych plików.';es_ES = 'El archivo ha sido eliminado al limpiar los archivos no necesarios.';es_CO = 'El archivo ha sido eliminado al limpiar los archivos no necesarios.';tr = 'Gereksiz dosyaları temizlerken dosya silinir.';it = 'Il file è stato eliminato durante la pulizia dei file non utilizzati.';de = 'Datei wurde gelöscht, wenn nicht benötigte Dateien bereinigt wurden.'")
			+ " " + Format(CurrentSessionDate(),"DLF=D") + Chars.LF;
		
		If FileObject.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			FileNameWithPath = FullVolumePath(FileObject.Volume) + FileObject.PathToFile;
			FileNameWithPathForDeletion = FileNameWithPath + ".del";
			FileOnHardDrive = New File(FileNameWithPath);
			If FileOnHardDrive.Exist() Then
				FileOnHardDrive.SetReadOnly(False);
				// Moving file to a temporary one.
				MoveFile(FileNameWithPath, FileNameWithPathForDeletion);
				FileObject.Volume = Catalogs.FileStorageVolumes.EmptyRef();
				FileObject.PathToFile = "";
				FileObject.Details = DetailsText + FileObject.Details;
				FileObject.Write();
				FileObject.SetDeletionMark(True);
				// Deleting the temporary file, because file data was successfully updated.
				DeleteFiles(FileNameWithPathForDeletion);
			EndIf;
		Else
			FilesOperationsInternalServerCall.DeleteRecordFromRegisterOfFilesBinaryData(FileRef);
			FileObject.Details = DetailsText + FileObject.Details;
			FileObject.Write();
			FileObject.SetDeletionMark(True);
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		If Not IsBlankString(FileNameWithPath) Then
			
			// Write an error to the event log.
			WriteLogEvent(NStr("ru = 'Очистка ненужных файлов'; en = 'Clear unused files'; pl = 'Oczyszczenie niepotrzebnych plików';es_ES = 'Limpiar archivos no necesarios';es_CO = 'Limpiar archivos no necesarios';tr = 'Kullanılmayan dosyaları temizle';it = 'Cancellare file non utilizzati';de = 'Unnötige Dateien bereinigen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,, FileRef, DetailErrorDescription(ErrorInfo()));
			
			// Returning the file to its original place in case of an error.
			MoveFile(FileNameWithPathForDeletion, FileNameWithPath);
			
		EndIf;
		
	EndTry;
	
EndProcedure

// To pass a file directory path to the OnSendFileData handler.
//
Procedure SaveSetting(ObjectKey, SettingsKey, Settings) 
	
	SetPrivilegedMode(True);
	CommonSettingsStorage.Save(ObjectKey, SettingsKey, Settings);
	
EndProcedure

// Returns the number of files stored in volumes.
Function FilesInVolumesCount()
	
	FilesInVolumesCount = 0;
	
	FilesOperationsInternalServerCall.DetermineFilesInVolumesCount(FilesInVolumesCount);
	
	Return FilesInVolumesCount;
	
EndFunction

// For internal use only.
//
Procedure WhenSendingFile(DataItem, ItemSend, Val InitialImageCreation = False, Recipient = Undefined)
	
	// For non-DIB exchanges, the normal exchange session algorithm is used, not the creation of the 
	// initial image, since the parameter CreateInitialImage that equals True means initial data export.
	If InitialImageCreation AND Recipient <> Undefined 
		AND Not IsDistributedInfobaseNode(Recipient.Ref) Then
		InitialImageCreation = False;
	EndIf;
	
	If ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// No overriding for standard processing.
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.FilesVersions") Then
		
		If InitialImageCreation Then
			
			If DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
				
				If Recipient <> Undefined
					AND Recipient.AdditionalProperties.Property("AllocateFilesToInitialImage") Then
					
					// Storing the file data from a hard-disk volume to an internal catalog attribute.
					PutFileInCatalogAttribute(DataItem);
					
				Else
					
					// Copying the file from a hard-disk volume to the directory used for initial image creation.
					FileDirectoryName = String(CommonSettingsStorage.Load("FileExchange", "TemporaryDirectory"));
					
					FullPath = FullVolumePath(DataItem.Volume) + DataItem.PathToFile;
					UUID = DataItem.Ref.UUID();
					
					NewFilePath = CommonClientServer.GetFullFileName(
							FileDirectoryName,
							UUID);
					
					CopyFileOnCreateInitialImage(FullPath, NewFilePath);
					
				EndIf;
				
			Else
				
				// If the file is stored in the infobase, it will be exported as a part of VersionsStoredFiles 
				// information register during the initial image creation.
				
			EndIf;
			
		Else
			ProcessFileSendingByStorageType(DataItem);
			FillFilePathOnSend(DataItem);
		EndIf;
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.FilesBinaryData")
		AND Not InitialImageCreation Then
		
		// Exporting the register during the initial image creation only.
		ItemSend = DataItemSend.Ignore;
		
	ElsIf NOT InitialImageCreation 
		AND IsItemFilesOperations(DataItem)
		AND TypeOf(DataItem) <> Type("CatalogObject.MetadataObjectIDs") Then
		// Catalog MetadataObjectIDs catalog can pass according to the IsItemFilesOperations, but cannot be 
		// processed here.
		ProcessFileSendingByStorageType(DataItem);
	EndIf;
	
EndProcedure

// For internal use only.
//
Procedure WhenReceivingFile(DataItem, GetItem, Sender = Undefined)
	
	ProcessReceivedFiles = False;
	If GetItem = DataItemReceive.Ignore Then
		
		// No overriding for standard processing.
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.Files") Then
		
		If GetFileProhibited(DataItem) Then
			GetItem = DataItemReceive.Ignore;
			Return;
		EndIf;
		ProcessReceivedFiles = True;
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.FilesVersions")
		Or (IsItemFilesOperations(DataItem)
			AND TypeOf(DataItem) <> Type("CatalogObject.MetadataObjectIDs")) Then
		
		// Catalog MetadataObjectIDs catalog can pass according to the IsItemFilesOperations, but cannot be 
		// processed here.
		If GetFileVersionProhibited(DataItem) Then
			GetItem = DataItemReceive.Ignore;
			Return;
		EndIf;
		ProcessReceivedFiles = True;
		
	EndIf;
	
	If ProcessReceivedFiles Then
		
		If Sender <> Undefined AND ExchangePlans.IsChangeRecorded(Sender.Ref, DataItem) Then
				// Object collision (changes are registered both on the master node and on the subordinate one).
				GetItem = DataItemReceive.Ignore;
				Return;
		EndIf;
			
		// Deleting existing files from volumes, because once a file is received, it is stored to a volume 
		// or an infobase even if its earlier version is already stored there.
		If NOT DataItem.IsNew() Then
			
			FileVersion = Common.ObjectAttributesValues(DataItem.Ref, "FileStorageType, Volume, PathToFile");
			
			If FileVersion.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
				
				OldPathInVolume = FullVolumePath(FileVersion.Volume) + FileVersion.PathToFile;
				
				DeleteFileInVolume(OldPathInVolume);
				
			EndIf;
			
		EndIf;
		
		BinaryData = DataItem.StorageFile.Get();
		If FilesStorageTyoe() = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			
			// An item came with storage in the database by exchange, but the destination base stores items in volumes.
			// Placing a file in the volume from an internal attribute and changing FileStorageType to InVolumesOnHardDrive.
			MetadataType = Metadata.FindByType(TypeOf(DataItem));
			If Common.HasObjectAttribute("FileOwner", MetadataType) Then
				// This is the file catalog.
				VersionNumber = "";
			Else
				// This is a catalog of file versions.
				VersionNumber = DataItem.VersionNumber;
			EndIf;
			
			If BinaryData = Undefined Then
				
				DataItem.Volume = Undefined;
				DataItem.PathToFile = Undefined;
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось добавить файл ""%1"" ни в один из томов, т.к. он отсутствует.
						|Возможно, файл удален антивирусной программой.
						|Обратитесь к администратору.'; 
						|en = 'Cannot add the ""%1"" file to any volume as it is missing.
						|The file might have been deleted by an antivirus software.
						|Contact administrator.'; 
						|pl = 'Nie udało się dodać pliku ""%1"" do żadnego z woluminów ponieważ go brakuje.
						|Plik może być usunięty przez oprogramowanie antywirusowe.
						|Skontaktuj się z administratorem.';
						|es_ES = 'No se ha podido añadir el archivo ""%1"" en ninguno de los tomos porque está ausente.
						|Es posible que el archivo haya sido eliminado por el programa antivirus.
						|Diríjase al administrador.';
						|es_CO = 'No se ha podido añadir el archivo ""%1"" en ninguno de los tomos porque está ausente.
						|Es posible que el archivo haya sido eliminado por el programa antivirus.
						|Diríjase al administrador.';
						|tr = 'Birimlerden hiçbirine ""%1"" dosyası eksik olduğundan dolayı eklenemedi. 
						|Dosya virüsten koruma programı tarafından silinmiş olabilir. 
						|Lütfen sistem yöneticinize başvurun.';
						|it = 'Impossibile aggiungere il file ""%1"" a un qualsiasi volume, poiché è mancante.
						|Il file potrebbe essere stato eliminato da un software antivirus.
						|Contattare l''amministratore.';
						|de = 'Die Datei ""%1"" konnte keinem der Volumes hinzugefügt werden, da sie fehlt.
						|Die Datei wurde möglicherweise von einem Antivirenprogramm gelöscht.
						|Bitte wenden Sie sich an den Administrator.'"),
						DataItem.Description + "." + DataItem.Extension);
				
				WriteLogEvent(NStr("ru = 'Файлы.Добавление файла в том'; en = 'Files.Add file to the volume'; pl = 'Pliki.Dodanie pliku do woluminu';es_ES = 'Archivos.Añadir el archivo al tomo';es_CO = 'Archivos.Añadir el archivo al tomo';tr = 'Dosyalar. Dosyanın birime eklenmesi';it = 'File.Aggiunta file al volume';de = 'Dateien. Hinzufügen einer Datei zum Volumen'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error, MetadataType, DataItem.Ref, ErrorText);
				
			Else
				
				FileInfo = AddFileToVolume(BinaryData,
					DataItem.UniversalModificationDate, DataItem.Description, DataItem.Extension,
					VersionNumber, FilePathOnGetHasFlagEncrypted(DataItem)); 
				DataItem.Volume = FileInfo.Volume;
				DataItem.PathToFile = FileInfo.PathToFile;
				
			EndIf;
			
			DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive;
			DataItem.StorageFile = New ValueStorage(Undefined);
			
		Else
			
			If TypeOf(BinaryData) = Type("BinaryData") Then
				DataItem.AdditionalProperties.Insert("FileBinaryData", BinaryData);
			EndIf;
			
			DataItem.StorageFile = New ValueStorage(Undefined);
			DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			DataItem.PathToFile = "";
			DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillFilePathOnSend(DataItem)
	
	If TypeOf(DataItem) <> Type("CatalogObject.FilesVersions") Then
		DataItem.PathToFile = "";
		Return;
	EndIf;
	
	DataEncrypted = Common.ObjectAttributeValue(DataItem.Owner, "Encrypted");
	DataItem.PathToFile = ?(DataEncrypted, ".p7m", "");
	
EndProcedure

Function FilePathOnGetHasFlagEncrypted(DataItem)
	
	If TypeOf(DataItem) <> Type("CatalogObject.FilesVersions") Then
		Return DataItem.Encrypted;
	EndIf;
	
	Return StrEndsWith(DataItem.PathToFile, ".p7m");
	
EndFunction

// Returns True if it is the metadata item, related to the FilesOperations subsystem.
//
Function IsItemFilesOperations(DataItem)
	
	DataItemType = TypeOf(DataItem);
	If DataItemType = Type("ObjectDeletion") Then
		Return False;
	EndIf;
	
	ItemMetadata = DataItem.Metadata();
	
	Return Common.IsCatalog(ItemMetadata)
		AND (Metadata.DefinedTypes.AttachedFileObject.Type.ContainsType(DataItemType)
			OR (Metadata.DefinedTypes.AttachedFile.Type.ContainsType(DataItemType)));
	
EndFunction

// Writes binary file data to the infobase.
//
// Parameters:
//  AttachedFile - Reference - a reference to the attached file.
//  BinaryData     - BinaryData to be written.
//
Procedure WriteFileToInfobase(Val AttachedFile, Val BinaryData) Export
	
	SetPrivilegedMode(True);
	
	RecordManager                     = InformationRegisters.FilesBinaryData.CreateRecordManager();
	RecordManager.File                = AttachedFile;
	RecordManager.FileBinaryData = New ValueStorage(BinaryData, New Deflation(9));
	RecordManager.Write(True);
	
EndProcedure

// Returns new object ID.
//  To receive a new ID it selects the last object ID
// from the AttachmentExistence register, increases its value by one unit and returns the result.
// 
//
// Returns:
//  Row (10) - a new object ID.
//
Function GetNextObjectID() Export
	
	// Calculating new object ID.
	Result = "0000000000"; // Matching the length of ObjectID resource
	
	QueryText =
	"SELECT TOP 1
	|	FilesExist.ObjectID AS ObjectID
	|FROM
	|	InformationRegister.FilesExist AS FilesExist
	|
	|ORDER BY
	|	ObjectID DESC";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ID = Selection.ObjectID;
		
		If IsBlankString(ID) Then
			Return Result;
		EndIf;
		
		// The calculation rules used are similar to regular addition: when the current digit is filled, the 
		// next digit is incremented by one and the current digit is reset to zero.
		// 
		//  Valid digit values are characters
		// [0..9] and [a..z]. Thus, one digit can contain
		// 36 values.
		
		Position = 10; // 9- index of the 10th character
		While Position > 0 Do
			
			Char = Mid(ID, Position, 1);
			
			If Char = "z" Then
				ID = Left(ID, Position-1) + "0" + Right(ID, 10 - Position);
				Position = Position - 1;
				Continue;
				
			ElsIf Char = "9" Then
				NewChar = "a";
			Else
				NewChar = Char(CharCode(Char)+1);
			EndIf;
			
			ID = Left(ID, Position-1) + NewChar + Right(ID, 10 - Position);
			Break;
		EndDo;
		
		Result = ID;
	EndIf;
	
	Return Result;
	
EndFunction

// See FilesFunctionsInternalSaaS.UpdateTextExtractionQueueState 
Procedure UpdateTextExtractionQueueState(TextSource, TextExtractionState) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.FilesManagerSaaS") Then
		
		If Common.DataSeparationEnabled()
		   AND Common.SeparatedDataUsageAvailable() Then
			
			ModuleFilesManagerInternalSaaS = Common.CommonModule("FilesManagerInternalSaaS");
			ModuleFilesManagerInternalSaaS.UpdateTextExtractionQueueState(TextSource, TextExtractionState);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

Procedure UpdateDeniedExtensionsList() Export
	
	DeniedExtensionsToImportList = DeniedExtensionsList();
	
	DeniedExtensionsListInDatabase = Constants.DeniedExtensionsList.Get();
	DeniedExtensionsArray = StrSplit(DeniedExtensionsListInDatabase, " ");
	UpdateDeniedExtensionsList = False;
	For Each Extension In DeniedExtensionsToImportList Do
		If DeniedExtensionsArray.Find(Upper(Extension)) = Undefined Then
			UpdateDeniedExtensionsList = True;
			DeniedExtensionsArray.Add(Upper(Extension));
		EndIf;
	EndDo;
	DeniedExtensionsListInDatabase = StrConcat(DeniedExtensionsArray, " ");
	If UpdateDeniedExtensionsList Then
		Constants.DeniedExtensionsList.Set(DeniedExtensionsListInDatabase);
	EndIf;
	
EndProcedure

Procedure UpdateProhibitedExtensionListInDataArea() Export
	
	DeniedExtensionsToImportList = DeniedExtensionsList();
	
	UpdateDeniedDataAreaExtensionsList = False;
	DeniedDataAreaExtensionsList = Constants.DeniedDataAreaExtensionsList.Get();
	DeniedDataAreaExtensionsArray = StrSplit(DeniedDataAreaExtensionsList, " ");
	For Each Extension In DeniedExtensionsToImportList Do
		If DeniedDataAreaExtensionsArray.Find(Upper(Extension)) = Undefined Then
			DeniedDataAreaExtensionsArray.Add(Upper(Extension));
			UpdateDeniedDataAreaExtensionsList = True;
		EndIf;
	EndDo;
	DeniedDataAreaExtensionsList = StrConcat(DeniedDataAreaExtensionsArray, " ");
	If UpdateDeniedDataAreaExtensionsList Then
		Constants.DeniedDataAreaExtensionsList.Set(DeniedDataAreaExtensionsList);
	EndIf;
	
EndProcedure

// Returns the catalog name for the specified owner or raises an exception if multiple catalogs are 
// found.
// 
// Parameters:
//  FilesOwner  - Reference - an object for adding file.
//  CatalogName  - String. If this parameter is filled, it checks for the catalog among the file 
//                    owner storage catalogs.
//                    If it is not filled, returns the main catalog name.
//  Errortitle - String - an error title.
//                  - Undefined - do not raise an exception and return a blank string.
//  ParameterName    - String - name of the parameter used to determine the catalog name.
//  ErrorEnd - String - an error end (only for the case, when ParameterName = Undefined).
// 
Function FileStoringCatalogName(FilesOwner, CatalogName = "",
	ErrorTitle = Undefined, ErrorEnd = Undefined) Export
	
	DoNotRaiseException = (ErrorTitle = Undefined);
	CatalogNames = FileStorageCatalogNames(FilesOwner, DoNotRaiseException);
	
	If CatalogNames.Count() = 0 Then
		If DoNotRaiseException Then
			Return "";
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			ErrorTitle + Chars.LF
			+ NStr("ru = 'У владельца файлов ""%1"" типа ""%2""
			             |нет справочников для хранения файлов.'; 
			             |en = 'File owner ""%1"" of type ""%2""
			             |does not have catalogs for the file storage.'; 
			             |pl = 'U właściciela plików ""%1"" rodzaju ""%2""
			             |nie ma poradników do przechowywania plików.';
			             |es_ES = 'El propietario de los archivos ""%1"" del tipo ""%2""
			             |no tiene catálogos para guardar archivos.';
			             |es_CO = 'El propietario de los archivos ""%1"" del tipo ""%2""
			             |no tiene catálogos para guardar archivos.';
			             |tr = '""%1"" tip ""%2"" 
			             |dosyalarının sahibinin, dosyaları depolamak için dizinleri yok.';
			             |it = 'Il proprietario del file ""%1"" del tipo ""%2""
			             |non ha cataloghi per l''archiviazione del file.';
			             |de = 'Der Eigentümer der Datei ""%1"" des Typs ""%2""
			             |hat keine Kataloge zum Speichern von Dateien.'"),
			String(FilesOwner),
			String(TypeOf(FilesOwner)));
	EndIf;
	
	If ValueIsFilled(CatalogName) Then
		If CatalogNames[CatalogName] <> Undefined Then
			Return CatalogName;
		EndIf;
	
		If DoNotRaiseException Then
			Return "";
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			ErrorTitle + Chars.LF
			+ NStr("ru = 'У владельца файлов ""%1"" типа ""%2""
			             |нет справочника ""%3"" для хранения файлов.'; 
			             |en = 'File owner ""%1"" of type ""%2""
			             |does not have catalog ""%3"" for the file storage.'; 
			             |pl = 'U właściciela plików ""%1"" rodzaju ""%2""
			             |nie ma poradnika ""%3"" do przechowywania plików.';
			             |es_ES = 'El propietario de los archivos ""%1"" del tipo ""%2""
			             |no tiene catálogo ""%3"" para guardar archivos.';
			             |es_CO = 'El propietario de los archivos ""%1"" del tipo ""%2""
			             |no tiene catálogo ""%3"" para guardar archivos.';
			             |tr = '""%1"" tip ""%2"" 
			             |dosyalarının sahibinin, dosyaları depolamak için ""%3"" dizinleri yok.';
			             |it = 'Il proprietario del file ""%1"" del tipo ""%2""
			             | non ha un catalogo ""%3"" per l''archiviazione del file.';
			             |de = 'Der Eigentümer der Datei ""%1"" des Typs ""%2""
			             |hat kein Verzeichnis ""%3"" zum Speichern von Dateien.'"),
			String(FilesOwner),
			String(TypeOf(FilesOwner)),
			String(CatalogName));
	EndIf;
	
	DefaultCatalog = "";
	For each KeyAndValue In CatalogNames Do
		If KeyAndValue.Value = True Then
			DefaultCatalog = KeyAndValue.Key;
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(DefaultCatalog) Then
		Return DefaultCatalog;
	EndIf;
		
	If DoNotRaiseException Then
		Return "";
	EndIf;
	
	ErrorReasonTemplate = 
		NStr("ru = 'У владельца файлов ""%1"" типа ""%2""
			|не указан основной справочник для хранения файлов.'; 
			|en = 'File owner ""%1"" of type ""%2""
			|did not specify a main catalog for the file storage.'; 
			|pl = 'Do przechowywania plików ""%1"" rodzaju ""%2""
			|nie określono głównego poradnika do przechowywania plików.';
			|es_ES = 'Para el propietario de archivos ""%1"" del tipo ""%2""
			|no está indicado catálogo principal para guardar los archivos.';
			|es_CO = 'Para el propietario de archivos ""%1"" del tipo ""%2""
			|no está indicado catálogo principal para guardar los archivos.';
			|tr = '""%2"" türünde ""%1"" dosya sahibi
			|dosya saklama için ana katalog belirlemedi.';
			|it = 'Il proprietario del file ""%1"" del tipo ""%2""
			|non ha indicato un catalogo principale per l''archiviazione del file.';
			|de = 'Der Eigentümer der Datei ""%1"" des Typs ""%2""
			|hat nicht das Hauptverzeichnis für die Speicherung von Dateien.'") + Chars.LF;
			
	ErrorReason = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorReasonTemplate, String(FilesOwner), String(TypeOf(FilesOwner)));
		
	ErrorText = ErrorTitle + Chars.LF
		+ ErrorReason + Chars.LF
		+ ErrorEnd;
		
	Raise TrimAll(ErrorText);
	
EndFunction

// Returns the map of catalog names and Boolean values for the specified owner.
// 
// 
// Parameters:
//  FilesOwher - Reference - an object for adding file.
// 
Function FilesVersionsStorageCatalogsNames(FilesOwner, DoNotRaiseException = False)
	
	If TypeOf(FilesOwner) = Type("Type") Then
		FilesOwnerType = FilesOwner;
	Else
		FilesOwnerType = TypeOf(FilesOwner);
	EndIf;
	
	OwnerMetadata = Metadata.FindByType(FilesOwnerType);
	
	CatalogNames = New Map;
	StandardMainCatalogName = OwnerMetadata.Name + "AttachedFilesVersions";
	If Metadata.Catalogs.Find(StandardMainCatalogName) <> Undefined Then
		CatalogNames.Insert(StandardMainCatalogName, True);
	EndIf;
	
	If Metadata.DefinedTypes.FilesOwner.Type.ContainsType(FilesOwnerType) Then
		CatalogNames.Insert("FilesVersions", True);
	EndIf;
	
	DefaultCatalogIsSpecified = False;
	
	For each KeyAndValue In CatalogNames Do
		
		If Metadata.Catalogs.Find(KeyAndValue.Key) = Undefined Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при определении имен справочников для хранения версий файлов.
				           |У владельца файлов типа ""%1""
				           |указан несуществующий справочник ""%2"".'; 
				           |en = 'An error occurred when determining catalog names for storing file versions.
				           |File owner of the ""%1"" type
				           |has the non-existing catalog ""%2"".'; 
				           |pl = 'Błąd przy ustalaniu nazw poradników do przechowywania wersji plików.
				           |U właściciela plików rodzaju ""%1""
				           |podano nieistniejący poradnik ""%2"".';
				           |es_ES = 'Error al determinar los nombres de catálogos para guardar las versiones de archivos.
				           |Para el propietario de archivos del tipo ""%1""
				           |está indicado un catálogo inexistente ""%2"".';
				           |es_CO = 'Error al determinar los nombres de catálogos para guardar las versiones de archivos.
				           |Para el propietario de archivos del tipo ""%1""
				           |está indicado un catálogo inexistente ""%2"".';
				           |tr = 'Dosyaları depolamak için katalog adları belirlenirken bir hata oluştu. 
				           |"
" tür dosya sahibinde ""%1"" varolmayan %2 katalog belirtildi.';
				           |it = 'Si è verificato un errore durante l''indicazione dei nomi dei cataloghi per l''archiviazione delle versioni di file.
				           |Il proprietario del file del tipo ""%1""
				           |possiede il catalogo non esistente ""%2"".';
				           |de = 'Fehler bei der Definition von Verzeichnisnamen für das Speichern von Dateiversionen.
				           |Der Eigentümer des Dateityps ""%1""
				           |hat ein nicht existierendes Verzeichnis ""%2"".'"),
				String(FilesOwnerType),
				String(KeyAndValue.Key));
				
		ElsIf Not StrEndsWith(KeyAndValue.Key, "AttachedFilesVersions") AND Not KeyAndValue.Key ="FilesVersions" Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при определении имен справочников для хранения версий файлов.
				           |У владельца файлов типа ""%1""
				           |указано имя справочника ""%2""
				           |без окончания ""AttachedFilesVersions"".'; 
				           |en = 'An error occurred when determining catalog names for storing file versions.
				           |File owner of the ""%1"" type
				           |has the ""%2"" catalog name specified
				           |without the ""AttachedFilesVersions"" ending.'; 
				           |pl = 'Błąd przy ustalaniu nazw poradników do przechowywania wersji plików.
				           |U właściciela plików rodzaju ""%1""
				           |podano imię poradnika ""%2""
				           |bez zakończenia ""AttachedFilesVersions"".';
				           |es_ES = 'Error al determinar los nombres de catálogos para guardar las versiones de archivos.
				           |Para el propietario de archivos del tipo ""%1""
				           |está indicado un nombre de catálogo ""%2""
				           |sin acabar ""AttachedFilesVersions"".';
				           |es_CO = 'Error al determinar los nombres de catálogos para guardar las versiones de archivos.
				           |Para el propietario de archivos del tipo ""%1""
				           |está indicado un nombre de catálogo ""%2""
				           |sin acabar ""AttachedFilesVersions"".';
				           |tr = 'Dosyaları depolamak için katalog adları belirlenirken bir hata oluştu. 
				           |"
" tür dosya sahibinde ""%1"" katalog 
				           |adı ""%2"" ""AttachedFilesVersions"" takısı olmadan belirtildi.';
				           |it = 'Si è verificato un errore durante l''indicazione dei nomi dei cataloghi per l''archiviazione delle versioni di file.
				           |Il proprietario del file del tipo ""%1""
				           |presenta il nome del catalogo ""%2"" indicato senza
				           |la fine ""AttachedFilesVersions"".';
				           |de = 'Beim Bestimmen von Katalognamen für das Speichern von Dateiversionen ist ein Fehler aufgetreten.
				           |Der Dateibesitzer vom Typ ""%1""
				           |hat den Katalognamen ""%2""
				           |ohne die Endung ""AttachedFilesVersions"" angegeben.'"),
				String(FilesOwnerType),
				String(KeyAndValue.Key));
			
		ElsIf KeyAndValue.Value = Undefined Then
			CatalogNames.Insert(KeyAndValue.Key, False);
			
		ElsIf KeyAndValue.Value = True Then
			If DefaultCatalogIsSpecified Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Ошибка при определении имен справочников для хранения версий файлов.
					           |У владельца файлов типа ""%1""
					           |основной справочник версий указан более одного раза.'; 
					           |en = 'An error occurred while determining catalog names for storing file versions.
					           |The main version catalog is specified more than once for the owner of files of the ""%1""
					           |type.'; 
					           |pl = 'Błąd przy ustalaniu nazw poradników do przechowywania wersji plików.
					           |U właściciela plików rodzaju ""%1""
					           |główny poradnik wersji jest podany więcej niż jeden raz.';
					           |es_ES = 'Error al determinar los nombres de catálogos para guardar las versiones de archivos.
					           |Para el propietario de archivos del tipo ""%1""
					           |está indicado un catálogo principal de versiones más de una vez.';
					           |es_CO = 'Error al determinar los nombres de catálogos para guardar las versiones de archivos.
					           |Para el propietario de archivos del tipo ""%1""
					           |está indicado un catálogo principal de versiones más de una vez.';
					           |tr = 'Dosyaları depolamak için katalog adları belirlenirken bir hata oluştu. 
					           | "
"tür dosya sahibi %1 ana katalog birden fazla kez belirtildi.';
					           |it = 'Si è verificato un errore durante l''indicazione dei nomi dei cataloghi per l''archiviazione delle versioni di file.
					           |Il catalogo della versione principale è indicato più di una volta per il proprietario dei file di tipo ""%1""
					           |.';
					           |de = 'Fehler bei der Definition von Verzeichnisnamen für das Speichern von Dateiversionen.
					           |Der Eigentümer des Dateityps ""%1""
					           |hat das Hauptverzeichnis der Version mehr als einmal.'"),
					String(FilesOwnerType),
					String(KeyAndValue.Key));
			EndIf;
			DefaultCatalogIsSpecified = True;
		EndIf;
	EndDo;
	
	Return CatalogNames;
	
EndFunction

// Returns the catalog name for the specified owner or raises an exception if multiple catalogs are 
// found.
// 
// Parameters:
//  FilesOwner  - Reference - an object for adding file.
//  CatalogName  - String. If this parameter is filled, it checks for the catalog among the file 
//                    owner storage catalogs.
//                    If it is not filled, returns the main catalog name.
//  Errortitle - String - an error title.
//                  - Undefined - do not raise an exception and return a blank string.
//  ParameterName    - String - name of the parameter used to determine the catalog name.
//  ErrorEnd - String - an error end (only for the case, when ParameterName = Undefined).
// 
Function FilesVersionsStorageCatalogName(FilesOwner, CatalogName = "",
	ErrorTitle = Undefined, ErrorEnd = Undefined) Export
	
	DoNotRaiseException = (ErrorTitle = Undefined);
	CatalogNames = FilesVersionsStorageCatalogsNames(FilesOwner, DoNotRaiseException);
	
	If CatalogNames.Count() = 0 Then
		Return "";
	EndIf;
	
	DefaultCatalog = "";
	For each KeyAndValue In CatalogNames Do
		If KeyAndValue.Value = True Then
			DefaultCatalog = KeyAndValue.Key;
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(DefaultCatalog) Then
		Return DefaultCatalog;
	EndIf;
		
	If DoNotRaiseException Then
		Return "";
	EndIf;
	
	ErrorReasonTemplate = 
		NStr("ru = 'У владельца версий файлов ""%1""
			|не указан основной справочник для хранения версий файлов.'; 
			|en = 'Main catalog to save file versions is not specified for the ""%1""
			|file version owner.'; 
			|pl = 'U właściciela wersji plików ""%1""
			|nie został określony podstawowy poradnik dla przechowywania wersji plików.';
			|es_ES = 'Para el propietario de las versiones de archivos ""%1""
			|no está indicado un catálogo principal para guardar las versiones de archivos.';
			|es_CO = 'Para el propietario de las versiones de archivos ""%1""
			|no está indicado un catálogo principal para guardar las versiones de archivos.';
			|tr = '""%1""
			|Dosya sürüm sahibinin, dosya sürümlerini depolamak için ana katalogu belirtilmemiştir.';
			|it = 'Il catalogo principale per salvare le versioni del file non è indicato per il proprietario della versione di file ""%1""
			|.';
			|de = 'Der Eigentümer der ""%1""
			|Version der Datei hat nicht das Hauptverzeichnis für die Speicherung der Versionen der Dateien.'") + Chars.LF;
			
	ErrorReason = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorReasonTemplate, String(FilesOwner));
		
	ErrorText = ErrorTitle + Chars.LF
		+ ErrorReason + Chars.LF
		+ ErrorEnd;
		
	Raise TrimAll(ErrorText);
	
EndFunction

// Cancels file editing.
//
// Parameters:
//  AttachedFile - a Reference or an Object of the attached file that needs to be released.
//
Procedure UnlockFile(Val AttachedFile) Export
	
	BeginTransaction();
	Try
	
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			DataLock              = New DataLock;
			DataLockItem       = DataLock.Add(Metadata.FindByType(TypeOf(AttachedFile)).FullName());
			DataLockItem.SetValue("Ref", AttachedFile);
			DataLock.Lock();
			FileObject = AttachedFile.GetObject();
		Else
			FileObject = AttachedFile;
		EndIf;
		
		If ValueIsFilled(FileObject.BeingEditedBy) Then
			FileObject.BeingEditedBy = Catalogs.Users.EmptyRef();
			FileObject.Write();
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function LockedFilesCount(Val FileOwner = Undefined, Val BeingEditedBy = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT COUNT(1) AS Count
		|FROM
		|	InformationRegister.FilesInfo AS FilesInfo
		|WHERE
		|	FilesInfo.BeingEditedBy <> VALUE(Catalog.Users.EmptyRef)";
	
	If BeingEditedBy = Undefined Then 
		BeingEditedBy = Users.AuthorizedUser();
	EndIf;
		
	Query.Text = Query.Text + " AND FilesInfo.BeingEditedBy = &BeingEditedBy ";
	Query.SetParameter("BeingEditedBy", BeingEditedBy);
	
	If FileOwner <> Undefined Then 
		Query.Text = Query.Text + " AND FilesInfo.FileOwner = &FileOwner ";
		Query.SetParameter("FileOwner", FileOwner);
	EndIf;
	
	Selection = Query.Execute().Unload().UnloadColumn("Count");
	Return Selection[0];
	
EndFunction

// Stores encrypted file data to a storage and sets the Encrypted flag for the file.
//
// Parameters:
//  AttachedFile  - a reference to the attached file.
//  EncryptedData - structure with the following property:
//                          TempStorageAddress - String - an address of the encrypted binary data.
//  ThumbprintsArray    - an Array of Structures containing certificate thumbprints.
// 
Procedure Encrypt(Val AttachedFile, Val EncryptedData, Val ThumbprintsArray) Export
	
	BeginTransaction();
	Try
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(AttachedFile)).FullName());
			DataLockItem.SetValue("Ref", AttachedFile);
			DataLock.Lock();
			AttachedFileObject = AttachedFile.GetObject();
		Else
			AttachedFileObject = AttachedFile;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
			ModuleDigitalSignatureInternal.AddEncryptionCertificates(AttachedFile, ThumbprintsArray);
		EndIf;
		
		AttributesValues = New Structure;
		AttributesValues.Insert("Encrypted", True);// Encrypted move to information register
		AttributesValues.Insert("TextStorage", New ValueStorage(""));
		UpdateFileBinaryDataAtServer(AttachedFileObject, EncryptedData.TempStorageAddress, AttributesValues);
		
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			AttachedFileObject.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Stores decrypted file data to a storage and removes the Encrypted flag from the file.
// 
// Parameters:
//  AttachedFile  - a reference to the attached file.
//  EncryptedData - structure with the following property:
//                          TempStorageAddress - String - an address of the decrypted binary data.
//
Procedure Decrypt(Val AttachedFile, Val DecryptedData) Export
	
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	
	BeginTransaction();
	Try
		
		CatalogMetadata = Metadata.FindByType(TypeOf(AttachedFile));
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			AttachedFileObject = AttachedFile.GetObject();
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(CatalogMetadata.FullName());
			DataLockItem.SetValue("Ref", AttachedFile);
			DataLock.Lock();
		Else
			AttachedFileObject = AttachedFile;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
			ModuleDigitalSignatureInternal.ClearEncryptionCertificates(AttachedFile);
		EndIf;
		
		AttributesValues = New Structure;
		AttributesValues.Insert("Encrypted", False);
		
		BinaryData = GetFromTempStorage(DecryptedData.TempStorageAddress);
		If CatalogMetadata.FullTextSearch = FullTextSearchUsing Then
			TextExtractionResult = ExtractText(DecryptedData.TempTextStorageAddress, BinaryData,
				AttachedFile.Extension);
			AttachedFileObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
			AttributesValues.Insert("TextStorage", TextExtractionResult.ExtractedText);
		Else
			AttachedFileObject.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
			AttributesValues.Insert("TextStorage", New ValueStorage(""));
		EndIf;
		
		UpdateFileBinaryDataAtServer(AttachedFileObject, BinaryData, AttributesValues);
		
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			AttachedFileObject.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Defines if catalog metadata has the Internal optional attribute.
//
// Parameters:
//  CatalogName - String - a catalog name in metadata.
//
// Returns:
//  Boolean - there is the Internal attribute.
//
Function HasInternalAttribute(Val CatalogName) Export
	
	MetadataObject  = Metadata.Catalogs[CatalogName];
	AttributeInternal = MetadataObject.Attributes.Find("Internal");
	Return AttributeInternal <> Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File exchange support

// Internal functions. Deletes files from the server .
// 
Procedure DeleteFileInVolume(FileToDeleteName)
	
	// Deleting file
	TemporaryFile = New File(FileToDeleteName);
	If TemporaryFile.Exist() Then
		
		Try
			TemporaryFile.SetReadOnly(False);
			DeleteFiles(FileToDeleteName);
		Except
			WriteLogEvent(
				NStr("ru = 'Файлы.Удаление файлов в томе'; en = 'Files.Delete files from the volume'; pl = 'Pliki.Usuwanie plików w woluminie';es_ES = 'Archivos.Eliminar archivos en el tomo';es_CO = 'Archivos.Eliminar archivos en el tomo';tr = 'Dosyalar. Dosyaları birimden sil';it = 'File.Eliminare file dal volume';de = 'Dateien.Löschen von Dateien in einem Volume'",
				     CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
	// Deleting the file directory if the directory is empty after the file deletion
	Try
		FilesArrayInDirectory = FindFiles(TemporaryFile.Path, "*.*");
		If FilesArrayInDirectory.Count() = 0 Then
			DeleteFiles(TemporaryFile.Path);
		EndIf;
	Except
		WriteLogEvent(
			NStr("ru = 'Файлы.Удаление файлов в томе'; en = 'Files.Delete files from the volume'; pl = 'Pliki.Usuwanie plików w woluminie';es_ES = 'Archivos.Eliminar archivos en el tomo';es_CO = 'Archivos.Eliminar archivos en el tomo';tr = 'Dosyalar. Dosyaları birimden sil';it = 'File.Eliminare file dal volume';de = 'Dateien.Löschen von Dateien in einem Volume'",
			     CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////////////
// Operations with encodings

// The function returns a table of encoding names.
// Returns:
// Result (ValueList)
// - Value (String) - for example, "ibm852".
// - Presentation (String) - for example, "ibm852 (Central European DOS)".
//
Function Encodings() Export

	EncodingsList = New ValueList;
	
	EncodingsList.Add("ibm852",       NStr("ru = 'IBM852 (Центральноевропейская DOS)'; en = 'IBM852 (Central European DOS)'; pl = 'IBM852 (Europa Środkowa DOS)';es_ES = 'IBM852 (DOS centroeuropeo)';es_CO = 'IBM852 (DOS centroeuropeo)';tr = 'IBM852 (Orta Avrupa DOS)';it = 'ibm852 (DOS dell''Europa centrale)';de = 'IBM852 (Mitteleuropäische DOS)'"));
	EncodingsList.Add("ibm866",       NStr("ru = 'IBM866 (Кириллица DOS)'; en = 'IBM866 (Cyrillic DOS)'; pl = 'IBM866 (Cyrylica DOS)';es_ES = 'IBM866 (DOS cirílico)';es_CO = 'IBM866 (DOS cirílico)';tr = 'IBM866 (Kiril DOS)';it = 'IBM866 (cirillico DOS)';de = 'IBM866 (Kyrillische DOS)'"));
	EncodingsList.Add("iso-8859-1",   NStr("ru = 'ISO-8859-1 (Западноевропейская ISO)'; en = 'ISO-8859-1 (Western European ISO)'; pl = 'ISO-8859-1 (Europa Zachodnia ISO)';es_ES = 'ISO-8859-1 (ISO europeo occidental)';es_CO = 'ISO-8859-1 (ISO europeo occidental)';tr = 'ISO-8859-1 (Batı Avrupa ISO)';it = 'iso-8859-1 (ISO dell''Europa occidentale)';de = 'ISO-8859-1 (Westeuropäische ISO)'"));
	EncodingsList.Add("iso-8859-2",   NStr("ru = 'ISO-8859-2 (Центральноевропейская ISO)'; en = 'ISO-8859-2 (Central European ISO)'; pl = 'ISO-8859-2 (Europa Środkowa ISO)';es_ES = 'ISO-8859-2 (ISO europeo central)';es_CO = 'ISO-8859-2 (ISO europeo central)';tr = 'ISO-8859-2 (Orta Avrupa ISO)';it = 'ISO-8859-2 (centrale europea ISO)';de = 'ISO-8859-2 (Zentraleuropäische ISO)'"));
	EncodingsList.Add("iso-8859-3",   NStr("ru = 'ISO-8859-3 (Латиница 3 ISO)'; en = 'ISO-8859-3 (Latin 3 ISO)'; pl = 'ISO-8859-3 (Łaciński 3 ISO)';es_ES = 'ISO-8859-3 (ISO latino 3)';es_CO = 'ISO-8859-3 (ISO latino 3)';tr = 'ISO-8859-3 (Latin 3 ISO)';it = 'ISO-8859-3 (3 ISO Latino)';de = 'ISO-8859-3 (Lateinisch 3 ISO)'"));
	EncodingsList.Add("iso-8859-4",   NStr("ru = 'ISO-8859-4 (Балтийская ISO)'; en = 'ISO-8859-4 (Baltic ISO)'; pl = 'ISO-8859-4 (Bałtycki ISO)';es_ES = 'ISO-8859-4 (ISO báltico)';es_CO = 'ISO-8859-4 (ISO báltico)';tr = 'ISO-8859-4 (Baltik ISO)';it = 'ISO-8859-4 (ISO baltico)';de = 'ISO-8859-4 (Baltische ISO)'"));
	EncodingsList.Add("iso-8859-5",   NStr("ru = 'ISO-8859-5 (Кириллица ISO)'; en = 'ISO-8859-5 (Cyrillic ISO)'; pl = 'ISO-8859-5 (Cyrylica ISO)';es_ES = 'ISO-8859-5 (ISO Cirílico)';es_CO = 'ISO-8859-5 (ISO Cirílico)';tr = 'ISO-8859-5 (Kiril ISO)';it = 'ISO-8859-5 (cirillico ISO)';de = 'ISO-8859-5 (Kyrillische ISO)'"));
	EncodingsList.Add("iso-8859-7",   NStr("ru = 'ISO-8859-7 (Греческая ISO)'; en = 'ISO-8859-7 (Greek ISO)'; pl = 'ISO-8859-7 (Grecki ISO)';es_ES = 'ISO-8859-7 (ISO Griego)';es_CO = 'ISO-8859-7 (ISO Griego)';tr = 'ISO-8859-7 (Yunan ISO)';it = 'ISO-8859-7 (Greco ISO)';de = 'ISO-8859-7 (Griechische ISO)'"));
	EncodingsList.Add("iso-8859-9",   NStr("ru = 'ISO-8859-9 (Турецкая ISO)'; en = 'ISO-8859-9 (Turkish ISO)'; pl = 'ISO-8859-9 (Turecki ISO)';es_ES = 'ISO-8859-9 (ISO Turco)';es_CO = 'ISO-8859-9 (ISO Turco)';tr = 'ISO-8859-9 (Türkçe ISO)';it = 'ISO-8859-9 (ISO turco)';de = 'ISO-8859-9 (Türkische ISO)'"));
	EncodingsList.Add("iso-8859-15",  NStr("ru = 'ISO-8859-15 (Латиница 9 ISO)'; en = 'ISO-8859-15 (Latin 9 ISO)'; pl = 'ISO-8859-15 (Łaciński 9 ISO)';es_ES = 'ISO-8859-15 (ISO 9 latino)';es_CO = 'ISO-8859-15 (ISO 9 latino)';tr = 'ISO-8859-15 (Latin 9 ISO)';it = 'ISO-8859-15 (Latina 9 ISO)';de = 'ISO-8859-15 (Lateinisch 9 ISO)'"));
	EncodingsList.Add("koi8-r",       NStr("ru = 'KOI8-R (Кириллица KOI8-R)'; en = 'KOI8-R (Cyrillic KOI8-R)'; pl = 'KOI8-R (Cyrylica KOI8-R)';es_ES = 'KOI8-R (KOI8-R Cirílico)';es_CO = 'KOI8-R (KOI8-R Cirílico)';tr = 'KOI8-R (Kiril KOI8-R)';it = 'KOI8-R (cirillico KOI8-R)';de = 'KOI8-R (Kyrillisch KOI8-R)'"));
	EncodingsList.Add("koi8-u",       NStr("ru = 'KOI8-U (Кириллица KOI8-U)'; en = 'KOI8-U (Cyrillic KOI8-U)'; pl = 'KOI8-U (Cyrylica KOI8-U)';es_ES = 'KOI8-U (KOI8-U Cirílico)';es_CO = 'KOI8-U (KOI8-U Cirílico)';tr = 'KOI8-U (Kiril KOI8-U)';it = 'KOI8-U (cirillico KOI8-U)';de = 'KOI8-U (Kyrillisch KOI8-U)'"));
	EncodingsList.Add("us-ascii",     NStr("ru = 'US-ASCII (США)'; en = 'US-ASCII (USA)'; pl = 'US-ASCII (USA)';es_ES = 'US-ASCII (Estados Unidos)';es_CO = 'US-ASCII (Estados Unidos)';tr = 'US-ASCII (ABD)';it = 'US-ASCII (USA)';de = 'US-ASCII (USA)'"));
	EncodingsList.Add("utf-8",        NStr("ru = 'UTF-8 (Юникод UTF-8)'; en = 'UTF-8 (Unicode UTF-8)'; pl = 'UTF-8 (Unicode UTF-8)';es_ES = 'UTF-8 (UTF-8 Unicode)';es_CO = 'UTF-8 (UTF-8 Unicode)';tr = 'UTF-8 (Unicode UTF-8)';it = 'UTF-8 (Unicode UTF-8)';de = 'UTF-8 (Unicode UTF-8)'"));
	EncodingsList.Add("utf-8_WithoutBOM", NStr("ru = 'UTF-8 (Юникод UTF-8 без BOM)'; en = 'UTF-8 (Unicode UTF-8 without BOM)'; pl = 'UTF-8 (Unicode UTF-8 bez BOM)';es_ES = 'UTF-8 (Unicode UTF-8 sin BOM)';es_CO = 'UTF-8 (Unicode UTF-8 sin BOM)';tr = 'UTF-8 (Unicode UTF-8 ürün reçetesiz)';it = 'UTF-8 (Unicode UTF-8 senza BOM)';de = 'UTF-8 (Unicode UTF-8 ohne Stückliste)'"));
	EncodingsList.Add("windows-1250", NStr("ru = 'Windows-1250 (Центральноевропейская Windows)'; en = 'Windows-1250 (Central European Windows)'; pl = 'Windows-1250 (Europa Środkowa Windows)';es_ES = 'Windows-1250 (Windows Europeo Central)';es_CO = 'Windows-1250 (Windows Europeo Central)';tr = 'Windows-1250 (Orta Avrupa Windows)';it = 'Windows 1250 (centrale di Windows Europea)';de = 'Windows-1250 (Zentraleuropäisches Windows)'"));
	EncodingsList.Add("windows-1251", NStr("ru = 'windows-1251 (Кириллица Windows)'; en = 'windows-1251 (Cyrillic Windows)'; pl = 'windows-1251 (Cyrylica Windows)';es_ES = 'Windows-1251 (Windows Cirílico)';es_CO = 'Windows-1251 (Windows Cirílico)';tr = 'Windows-1251 (Kiril Windows)';it = 'finestre-1251 (cirillico Windows)';de = 'Windows-1251 (Kyrillisches Windows)'"));
	EncodingsList.Add("windows-1252", NStr("ru = 'Windows-1252 (Западноевропейская Windows)'; en = 'Windows-1252 (Western European Windows)'; pl = 'Windows-1252 (Europa Zachodnia Windows)';es_ES = 'Windows-1252 (Windows Europeo occidental)';es_CO = 'Windows-1252 (Windows Europeo occidental)';tr = 'Windows-1252 (Batı Avrupa Windows)';it = 'Windows-1252 (Western European di Windows)';de = 'Windows-1252 (Westeuropäisches Windows)'"));
	EncodingsList.Add("windows-1253", NStr("ru = 'Windows-1253 (Греческая Windows)'; en = 'Windows-1253 (Greek Windows)'; pl = 'Windows-1253 (Grecki Windows)';es_ES = 'Windows-1253 (Windows griego)';es_CO = 'Windows-1253 (Windows griego)';tr = 'Windows-1253 (Yunan Windows)';it = 'Windows 1253 (in greco Windows)';de = 'Windows-1253 (Griechisches Windows)'"));
	EncodingsList.Add("windows-1254", NStr("ru = 'Windows-1254 (Турецкая Windows)'; en = 'Windows-1254 (Turkish Windows)'; pl = 'Windows-1254 (Turecki Windows)';es_ES = 'Windows-1254 (Windows turco)';es_CO = 'Windows-1254 (Windows turco)';tr = 'Windows-1254 (Türkçe Windows)';it = 'Windows 1254 (Turkish Windows)';de = 'Windows-1254 (Türkisches Windows)'"));
	EncodingsList.Add("windows-1257", NStr("ru = 'Windows-1257 (Балтийская Windows)'; en = 'Windows-1257 (Baltic Windows)'; pl = 'Windows-1257 (Bałtycki Windows)';es_ES = 'Windows-1257 (Windows báltico)';es_CO = 'Windows-1257 (Windows báltico)';tr = 'Windows-1257 (Baltik Windows)';it = 'Windows-1257 (Baltic Windows)';de = 'Windows-1257 (Baltisches Windows)'"));
	
	Return EncodingsList;

EndFunction

// Gets the text file encoding specified by the user (if possible).
//
// Parameters:
//  FileVersion - a reference to a file version.
//
// Returns:
//  String - text encoding ID, or an blank string.
//
Function GetFileVersionEncoding(FileVersion)
	
	Return FilesOperationsInternalServerCall.GetFileVersionEncoding(FileVersion);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// The "on write" file version subscription.
//
Procedure FilesVersionsOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		WriteFileDataToRegisterDuringExchange(Source);
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("FileRenaming") Then
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("FileConversion") Then
		Return;
	EndIf;
	
	// Copying attributes from version to file.
	CurrentVersion = Source;
	If Not CurrentVersion.Ref.IsEmpty() Then
	
		FileRef = Source.Owner;
		
		FileAttributes = Common.ObjectAttributesValues(FileRef, 
			"PictureIndex, Size, CreationDate, Changed, Extension, Volume, PathToFile, UniversalModificationDate");
			
			If FileAttributes.Size <> CurrentVersion.Size 
				OR FileAttributes.CreationDate <> CurrentVersion.CreationDate
				OR FileAttributes.Extension <> CurrentVersion.Extension
				OR FileAttributes.Volume <> CurrentVersion.Volume
				OR FileAttributes.PathToFile <> CurrentVersion.PathToFile 
				OR FileAttributes.PictureIndex <> CurrentVersion.PictureIndex
				OR FileAttributes.UniversalModificationDate <> CurrentVersion.FileModificationDate Then
				BeginTransaction();
				Try
					DataLock = New DataLock;
					DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(FileRef)).FullName());
					DataLockItem.SetValue("Ref", FileRef);
					DataLock.Lock();
					FileObject = FileRef.GetObject();
					// Changing the picture index, it is possible that the version has appeared or the version picture index has changed.
					FileObject.PictureIndex = CurrentVersion.PictureIndex;
					
					// Copying attributes to speed up the restriction work at the level of records.
					FileObject.Size           = CurrentVersion.Size;
					FileObject.CreationDate     = CurrentVersion.CreationDate;
					FileObject.Changed          = CurrentVersion.Author;
					FileObject.Extension       = CurrentVersion.Extension;
					FileObject.Volume              = CurrentVersion.Volume;
					FileObject.PathToFile       = CurrentVersion.PathToFile;
					FileObject.FileStorageType = CurrentVersion.FileStorageType;
					FileObject.UniversalModificationDate = CurrentVersion.UniversalModificationDate;
					
					If Source.AdditionalProperties.Property("WriteSignedObject") Then
						FileObject.AdditionalProperties.Insert("WriteSignedObject",
							Source.AdditionalProperties.WriteSignedObject);
					EndIf;
					
					FileObject.Write();
					CommitTransaction();
				Except
					RollbackTransaction();
					Raise;
				EndTry;
			EndIf;
		
	EndIf;
	
	UpdateTextExtractionQueueState(Source.Ref, Source.TextExtractionStatus);
	
EndProcedure

// Subscription handler of the "before delete attached file" event.
Procedure BeforeDeleteAttachedFileServer(Val Ref,
                                                   Val FilesOwner,
                                                   Val Volume,
                                                   Val FileStorageType,
                                                   Val PathToFile) Export
	
	SetPrivilegedMode(True);
	
	If FilesOwner <> Undefined AND Not OwnerHasFiles(FilesOwner, Ref) Then
		
		BeginTransaction();
		Try
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.InformationRegisters.FilesExist.FullName());
			DataLockItem.SetValue("ObjectWithFiles", FilesOwner);
			DataLock.Lock();
			
			RecordManager = InformationRegisters.FilesExist.CreateRecordManager();
			RecordManager.ObjectWithFiles = FilesOwner;
			RecordManager.Read();
			If RecordManager.Selected() Then
				RecordManager.HasFiles = False;
				RecordManager.Write();
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndIf;
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive AND NOT Volume.IsEmpty() Then
		FullPath = FullVolumePath(Volume) + PathToFile;
		DeleteFileInVolume(FullPath);
	EndIf;
	
EndProcedure

Function OwnerHasFiles(Val FilesOwner, Val ExceptionFile = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Parameters.Insert("FilesOwner", FilesOwner);
	
	QueryText =
	"SELECT
	|	AttachedFiles.Ref
	|FROM
	|	&CatalogName AS AttachedFiles
	|WHERE
	|	AttachedFiles.FileOwner = &FilesOwner";
	
	If ExceptionFile <> Undefined Then
		QueryText = QueryText + "
			|	AND AttachedFiles.Ref <> &Ref";
		
		Query.Parameters.Insert("Ref", ExceptionFile);
	EndIf;
	
	CatalogNames = FileStorageCatalogNames(FilesOwner);
	
	For each KeyAndValue In CatalogNames Do
		Query.Text = StrReplace(
			QueryText, "&CatalogName", "Catalog." + KeyAndValue.Key);
		
		If NOT Query.Execute().IsEmpty() Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks the current user right when using the limit for a folder or file.
// 
// 
// Parameters:
//  Right        - a right name.
//  RightsOwner - CatalogRef.FilesFolders, CatalogRef.Files,
//                 <reference to the owner>.
//
Function HasRight(Right, RightsOwner) Export
	
	If Not IsFilesFolder(RightsOwner) Then
		Return True; 
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		
		If NOT ModuleAccessManagement.HasRight(Right, RightsOwner) Then
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Marks a file as editable.
//
// Parameters:
//  AttachedFile - a Reference or an Object of the attached file that needs to be marked.
//
Procedure LockFileForEditingServer(Val AttachedFile, User = Undefined) Export
	
	BeginTransaction();
	Try
		If Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile)) Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(AttachedFile)).FullName());
			DataLockItem.SetValue("Ref", AttachedFile);
			DataLock.Lock();
			
			FileObject = AttachedFile.GetObject();
			FileObject.Lock();
		Else
			FileObject = AttachedFile;
		EndIf;
		
		If User = Undefined Then
			FileObject.BeingEditedBy = Users.AuthorizedUser();
		Else
			FileObject.BeingEditedBy = User;
		EndIf;
		FileObject.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure WriteFileDataToRegisterDuringExchange(Source)
	
	Var FileBinaryData;
	
	If Source.AdditionalProperties.Property("FileBinaryData", FileBinaryData) Then
		RecordSet = InformationRegisters.FilesBinaryData.CreateRecordSet();
		RecordSet.Filter.File.Set(Source.Ref);
		
		Record = RecordSet.Add();
		Record.File = Source.Ref;
		Record.FileBinaryData = New ValueStorage(FileBinaryData);
		
		RecordSet.DataExchange.Load = True;
		RecordSet.Write();
		
		Source.AdditionalProperties.Delete("FileBinaryData");
	EndIf;
	
EndProcedure

Function GetFileProhibited(DataItem)
	
	Return DataItem.IsNew()
	      AND Not FilesOperationsInternalClientServer.CheckExtentionOfFileToDownload(
	             DataItem.Extension, False);
	
EndFunction

Function GetFileVersionProhibited(DataItem)
	
	Return DataItem.IsNew()
	      AND Not FilesOperationsInternalClientServer.CheckExtentionOfFileToDownload(
	             DataItem.Extension, False);
	
EndFunction

Procedure ProcessFileSendingByStorageType(DataItem)
	
	If DataItem.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		
		// Storing the file data from a hard-disk volume to an internal catalog attribute.
		PutFileInCatalogAttribute(DataItem);
		
	Else
		// Enums.FilesStorageTypes.InInfobase
		// If you can store file versions, binary data is taken from the current version.
		If DataItem.Metadata().Attributes.Find("CurrentVersion") <> Undefined
			AND ValueIsFilled(DataItem.CurrentVersion) Then
			BinaryDataSource = DataItem.CurrentVersion;
		Else
			BinaryDataSource = DataItem.Ref;
		EndIf;
		Try
			// Storing the file data from the infobase to an internal catalog attribute.
			AddressInTempStorage = FilesOperationsInternalServerCall.GetTemporaryStorageURL(BinaryDataSource);
			DataItem.StorageFile = New ValueStorage(GetFromTempStorage(AddressInTempStorage), New Deflation(9));
		Except
			// Probably the file is not found. Do not interrupt data sending.
			WriteLogEvent(EventLogEventForExchange(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			DataItem.StorageFile = New ValueStorage(Undefined);
		EndTry;
		
		DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
		DataItem.PathToFile = "";
		DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
		
	EndIf;
	
EndProcedure

Procedure PutFileInCatalogAttribute(DataItem)
	
	Try
		// Storing the file data from a hard-disk volume to an internal catalog attribute.
		DataItem.StorageFile = PutBinaryDataInStorage(DataItem.Volume, DataItem.PathToFile, DataItem.Ref.UUID());
	Except
		// Probably the file is not found. Do not interrupt data sending.
		WriteLogEvent(EventLogEventForExchange(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		DataItem.StorageFile = New ValueStorage(Undefined);
	EndTry;
	
	DataItem.FileStorageType = Enums.FileStorageTypes.InInfobase;
	DataItem.PathToFile = "";
	DataItem.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	
EndProcedure

// Returns array of attached files for the specified owner.
//
// Parameters:
//  FilesOwner - a reference to the owner of the attached files.
//
// Returns:
//  Array of references to the attached files.
//
Function AllSubordinateFiles(Val FilesOwner) Export
	
	SetPrivilegedMode(True);
	
	CatalogNames = FileStorageCatalogNames(FilesOwner);
	QueriesText = "";
	
	For each KeyAndValue In CatalogNames Do
		If ValueIsFilled(QueriesText) Then
			QueriesText = QueriesText + "
				|UNION ALL
				|
				|";
		EndIf;
		QueryText =
		"SELECT
		|	AttachedFiles.Ref
		|FROM
		|	&CatalogName AS AttachedFiles
		|WHERE
		|	AttachedFiles.FileOwner = &FilesOwner";
		QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + KeyAndValue.Key);
		QueriesText = QueriesText + QueryText;
	EndDo;
	
	Query = New Query(QueriesText);
	Query.SetParameter("FilesOwner", FilesOwner);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Returns a string constant for generating event log messages.
//
// Returns:
//   Row
//
Function EventLogEventForExchange() 
	
	Return NStr("ru = 'Файлы.Не удалось отправить файл при обмене данными'; en = 'Files.Cannot send file during data exchange'; pl = 'Pliki. Nie można wysłać pliku podczas wymiany danych';es_ES = 'Archivos.No se puede enviar el archivo durante el intercambio de datos';es_CO = 'Archivos.No se puede enviar el archivo durante el intercambio de datos';tr = 'Dosyalar. Veri değişimi sırasında dosya gönderilemiyor';it = 'File.Impossibile inviare file durante lo scambio dati';de = 'Dateien. Die Datei kann während des Datenaustauschs nicht gesendet werden'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Replaces the binary data of an infobase file with data in a temporary storage.
Procedure UpdateFileBinaryDataAtServer(Val AttachedFile,
	                                           Val FileAddressInBinaryDataTempStorage,
	                                           Val AttributesValues = Undefined)
	
	SetPrivilegedMode(True);
	IsReference = Catalogs.AllRefsType().ContainsType(TypeOf(AttachedFile));
	BeginTransaction();
	Try
		If IsReference Then
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(AttachedFile)).FullName());
			DataLockItem.SetValue("Ref", AttachedFile);
			DataLock.Lock();
			
			FileObject = AttachedFile.GetObject();
			FileObject.Lock();
			FileRef = AttachedFile;
		Else
			FileObject = AttachedFile;
			FileRef = FileObject.Ref;
		EndIf;
		
		If TypeOf(FileAddressInBinaryDataTempStorage) = Type("BinaryData") Then
			BinaryData = FileAddressInBinaryDataTempStorage;
		Else
			BinaryData = GetFromTempStorage(FileAddressInBinaryDataTempStorage);
		EndIf;
		
		FileObject.Changed = Users.AuthorizedUser();
		
		If TypeOf(AttributesValues) = Type("Structure") Then
			FillPropertyValues(FileObject, AttributesValues);
		EndIf;
		
		IsFileInInfobase = (FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase);
		If IsFileInInfobase Then
			UpdateFileBinaryDataInInfobase(FileObject, FileRef, BinaryData);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		If IsReference Then
			FileObject.Unlock();
		EndIf;
		Raise;
	EndTry;
	
	If Not IsFileInInfobase Then
		UpdateFileBinaryDataInVolume(FileObject, FileRef, BinaryData);
	EndIf;
	
	If IsReference Then
		FileObject.Unlock();
	EndIf;
	
EndProcedure

Procedure UpdateFileBinaryDataInInfobase(FileObject, FileRef, BinaryData)
	
	Try
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.InformationRegisters.FilesBinaryData.FullName());
		DataLockItem.SetValue("File", FileRef);
		DataLock.Lock();
		
		RecordManager = InformationRegisters.FilesBinaryData.CreateRecordManager();
		RecordManager.File = FileRef;
		RecordManager.Read();
		RecordManager.File = FileRef;
		RecordManager.FileBinaryData = New ValueStorage(BinaryData, New Deflation(9));
		RecordManager.Write();
		
		FileObject.Size = BinaryData.Size();
		FileObject.Write();
	Except
		WriteLogEvent(
		NStr("ru = 'Файлы.Обновление данных присоединенного файла в хранилище файлов'; en = 'Files.Updating attached file data in the file storage'; pl = 'Pliki. Aktualizowanie danych dołączonego pliku w magazynie plików';es_ES = 'Archivos.Actualizando los datos del archivo adjuntado en el almacenamiento de archivos';es_CO = 'Archivos.Actualizando los datos del archivo adjuntado en el almacenamiento de archivos';tr = 'Dosyalar. Ekli dosya verilerinin dosya deposunda güncellenmesi';it = 'File.Aggiornamento dati file allegati nell''archivio file';de = 'Dateien. Aktualisieren der angehängten Dateidaten im Dateispeicher'",
		CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Error,
		,
		,
		DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure UpdateFileBinaryDataInVolume(FileObject, FileRef, BinaryData)
	
	Try
		FullPath = FullVolumePath(FileObject.Volume) + FileObject.PathToFile;
		
		FileOnHardDrive = New File(FullPath);
		FileOnHardDrive.SetReadOnly(False);
		DeleteFiles(FullPath);
		
		FileInfo = AddFileToVolume(BinaryData, FileObject.UniversalModificationDate,
			FileObject.Description, FileObject.Extension,, FileObject.Encrypted);
		FileObject.PathToFile = FileInfo.PathToFile;
		FileObject.Volume = FileInfo.Volume;
		FileObject.Size = BinaryData.Size();
		FileObject.Write();
	Except
		ErrorInformation = ErrorInfo();
		WriteLogEvent(
			NStr("ru = 'Файлы.Запись файла на диск'; en = 'Files.Writing file to the hard disk'; pl = 'Pliki. Zapisywanie pliku na dysku';es_ES = 'Archivos.Grabar el archivo en el disco';es_CO = 'Archivos.Grabar el archivo en el disco';tr = 'Dosyalar. Dosyanın diske yazılması';it = 'File.Scrittura file su disco rigido';de = 'Dateien. Datei auf Festplatte schreiben'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs[FileRef.Metadata().Name],
			FileRef,
			ErrorTextWhenSavingFileInVolume(DetailErrorDescription(ErrorInformation), FileRef));
		
		Raise ErrorTextWhenSavingFileInVolume(BriefErrorDescription(ErrorInformation), FileRef);
	EndTry;
	
EndProcedure

// Creates a version of the saved file to save to infobase.
//
// Parameters:
//   FileRef     - CatalogRef.Files - a file, for which a new version is created.
//   FileInfo - Structure - see FilesOperationsClientServer.FIleInfo in the FileWIthVersion mode. 
//
// Returns:
//   CatalogRef.FilesVersions - the created version.
//
Function CreateVersion(FileRef, FileInfo) Export
	
	HasRightsToObject = Common.ObjectAttributesValues(FileRef, "Ref", True);
	If HasRightsToObject = Undefined Then
		Return Undefined;
	EndIf;

	FileStorage = Undefined;
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(FileInfo.ModificationTimeUniversal)
		Or FileInfo.ModificationTimeUniversal > CurrentUniversalDate() Then
		
		FileInfo.ModificationTimeUniversal = CurrentUniversalDate();
	EndIf;
	
	If Not ValueIsFilled(FileInfo.Modified)
		Or ToUniversalTime(FileInfo.Modified) > FileInfo.ModificationTimeUniversal Then
		
		FileInfo.Modified = CurrentSessionDate();
	EndIf;
	
	FilesOperationsInternalClientServer.CheckExtentionOfFileToDownload(FileInfo.ExtensionWithoutPoint);
	
	Version = Catalogs.FilesVersions.CreateItem();
	
	If FileInfo.NewVersionVersionNumber = Undefined Then
		Version.VersionNumber = FindMaxVersionNumber(FileRef) + 1;
	Else
		Version.VersionNumber = FileInfo.NewVersionVersionNumber;
	EndIf;
	
	Version.Owner = FileRef;
	Version.UniversalModificationDate = FileInfo.ModificationTimeUniversal;
	Version.FileModificationDate = FileInfo.Modified;
	
	Version.Comment = FileInfo.NewVersionComment;
	
	If FileInfo.NewVersionAuthor = Undefined Then
		Version.Author = Users.CurrentUser();
	Else
		Version.Author = FileInfo.NewVersionAuthor;
	EndIf;
	
	If FileInfo.NewVersionCreationDate = Undefined Then
		Version.CreationDate = CurrentSessionDate();
	Else
		Version.CreationDate = FileInfo.NewVersionCreationDate;
	EndIf;
	
	Version.FullDescr = FileInfo.BaseName;
	Version.Size = FileInfo.Size;
	Version.Extension = CommonClientServer.ExtensionWithoutPoint(FileInfo.ExtensionWithoutPoint);
	
	FilesStorageTyoe = FilesStorageTyoe();
	Version.FileStorageType = FilesStorageTyoe;

	If FileInfo.RefToVersionSource <> Undefined Then // Creating file from template
		
		TemplateFilesStorageType = FileInfo.RefToVersionSource.FileStorageType;
		
		If TemplateFilesStorageType = Enums.FileStorageTypes.InInfobase AND FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
			// Both template and the new File are in the base.
			// When creating a File from a template, the value storage is copied directly.
			BinaryData = FileInfo.TempFileStorageAddress.Get();
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive AND FilesStorageTyoe = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			//  If both template and the new File are on the hard drive, just copying the file.
			
			If Not FileInfo.RefToVersionSource.Volume.IsEmpty() Then
				FullTemplateFilePath = FullVolumePath(FileInfo.RefToVersionSource.Volume) 
					+ FileInfo.RefToVersionSource.PathToFile; 
				
				Information = AddFileToVolume(FullTemplateFilePath, FileInfo.ModificationTimeUniversal,
					FileInfo.BaseName, FileInfo.ExtensionWithoutPoint, Version.VersionNumber, FileInfo.Encrypted);
				Version.Volume = Information.Volume;
				Version.PathToFile = Information.PathToFile;
			EndIf;
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.InInfobase AND FilesStorageTyoe = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			// Template is in the base and the new FIle is on the hard drive.
			// In this case, the FileTempStorageAddress contains the ValueStorage with the file.
			Information = AddFileToVolume(FileInfo.TempFileStorageAddress.Get(),
				FileInfo.ModificationTimeUniversal, FileInfo.BaseName, FileInfo.ExtensionWithoutPoint,
				Version.VersionNumber, FileInfo.Encrypted);
			Version.Volume = Information.Volume;
			Version.PathToFile = Information.PathToFile;
			
		ElsIf TemplateFilesStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive AND FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
			// Template is on the hard drive, and the new File is in the base.
			If Not FileInfo.RefToVersionSource.Volume.IsEmpty() Then
				FullTemplateFilePath = FullVolumePath(FileInfo.RefToVersionSource.Volume) + FileInfo.RefToVersionSource.PathToFile; 
				BinaryData = New BinaryData(FullTemplateFilePath);
			EndIf;
			
		EndIf;
	Else // Creating the FIle object based on the selected file from the hard drive.
		
		BinaryData = GetFromTempStorage(FileInfo.TempFileStorageAddress);
		
		If Version.Size = 0 Then
			Version.Size = BinaryData.Size();
			FilesOperationsInternalClientServer.CheckFileSizeForImport(Version);
		EndIf;
		
		If FilesStorageTyoe = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			
			Information = AddFileToVolume(BinaryData,
				FileInfo.ModificationTimeUniversal, FileInfo.BaseName, FileInfo.ExtensionWithoutPoint,
				Version.VersionNumber); 
			Version.Volume = Information.Volume;
			Version.PathToFile = Information.PathToFile;
			
		EndIf;
		
	EndIf;
	
	Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	If Metadata.Catalogs.FilesVersions.FullTextSearch = FullTextSearchUsing Then
		If TypeOf(FileInfo.TempTextStorageAddress) = Type("ValueStorage") Then
			// When creating a File from a template, the value storage is copied directly.
			Version.TextStorage = FileInfo.TempTextStorageAddress;
			Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		ElsIf Not IsBlankString(FileInfo.TempTextStorageAddress) Then
			TextExtractionResult = ExtractText(FileInfo.TempTextStorageAddress);
			Version.TextStorage = TextExtractionResult.TextStorage;
			Version.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
		EndIf;
	EndIf;

	Version.Fill(Undefined);
	Version.Write();
	
	If FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
		WriteFileToInfobase(Version.Ref, BinaryData);
	EndIf;
	
	Return Version.Ref;
	
EndFunction

// It will rename file on the hard drive for the FilesVersions catalog if FileStorageType = InVolumesOnHardDrive.
Procedure RenameVersionFileOnHardDrive(Version, OldDescription, NewDescription, 
	UUID = Undefined) Export
	
	If Version.Volume.IsEmpty() Then
		Return;
	EndIf;	
	
	BeginTransaction();
	Try
		
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(Version)).FullName());
		DataLockItem.SetValue("Ref", Version);
		DataLock.Lock();
		
		VersionObject = Version.GetObject();
		LockDataForEdit(Version, , UUID);
		
		OldFullPath = FullVolumePath(Version.Volume) + Version.PathToFile; 
		
		FileOnHardDrive = New File(OldFullPath);
		FullPath = FileOnHardDrive.Path;
		NameWithoutExtension = FileOnHardDrive.BaseName;
		Extension = FileOnHardDrive.Extension;
		NewBaseName = StrReplace(NameWithoutExtension, OldDescription, NewDescription);
		
		NewFullPath = FullPath + NewBaseName + Extension;
		FullVolumePath = FullVolumePath(Version.Volume);
		NewPartialPath = Right(NewFullPath, StrLen(NewFullPath) - StrLen(FullVolumePath));
	
		MoveFile(OldFullPath, NewFullPath);
		VersionObject.PathToFile = NewPartialPath;
		VersionObject.Write();
		UnlockDataForEdit(Version, UUID);
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit(Version, UUID);
		Raise;
	EndTry;
	
EndProcedure

// Updates file properties without considering versions, which are binary data, text, modification 
// date, and also other optional properties.
//
Procedure RefreshFile(FileInfo, AttachedFile) Export
	
	CommonClientServer.CheckParameter("FilesOperations.FileBinaryData", "AttachedFile", 
		AttachedFile, Metadata.DefinedTypes.AttachedFile.Type);
	
	AttributesValues = New Structure;
	
	If FileInfo.Property("BaseName") AND ValueIsFilled(FileInfo.BaseName) Then
		AttributesValues.Insert("Description", FileInfo.BaseName);
	EndIf;
	
	If NOT FileInfo.Property("UniversalModificationDate")
		OR NOT ValueIsFilled(FileInfo.UniversalModificationDate)
		OR FileInfo.UniversalModificationDate > CurrentUniversalDate() Then
		
		// Filling current date in the universal time format.
		AttributesValues.Insert("UniversalModificationDate", CurrentUniversalDate());
	Else
		AttributesValues.Insert("UniversalModificationDate", FileInfo.UniversalModificationDate);
	EndIf;
	
	If FileInfo.Property("BeingEditedBy") Then
		AttributesValues.Insert("BeingEditedBy", FileInfo.BeingEditedBy);
	EndIf;
	
	If FileInfo.Property("Extension") Then
		AttributesValues.Insert("Extension", FileInfo.Extension);
	EndIf;
	
	If FileInfo.Property("Encoding")
		AND Not IsBlankString(FileInfo.Encoding) Then
		
		FilesOperationsInternalServerCall.WriteFileVersionEncoding(AttachedFile, FileInfo.Encoding);
		
	EndIf;
	
	BinaryData = GetFromTempStorage(FileInfo.FileAddressInTempStorage);
	
	FileMetadata = Metadata.FindByType(TypeOf(AttachedFile));
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	If FileMetadata.FullTextSearch = FullTextSearchUsing Then
		TextExtractionResult = ExtractText(FileInfo.TempTextStorageAddress, BinaryData,
			AttachedFile.Extension);
		AttributesValues.Insert("TextExtractionStatus", TextExtractionResult.TextExtractionStatus);
		AttributesValues.Insert("TextStorage", TextExtractionResult.TextStorage);
	Else
		AttributesValues.Insert("TextExtractionStatus", Enums.FileTextExtractionStatuses.NotExtracted);
		AttributesValues.Insert("TextStorage", New ValueStorage(""));
	EndIf;
	
	UpdateFileBinaryDataAtServer(AttachedFile, BinaryData, AttributesValues);
	
EndProcedure

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
Function UpdateFileVersion(FileRef,
	FileInfo,
	VersionRef = Undefined,
	UUIDOfForm = Undefined,
	User = Undefined) Export
	
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
	ObjectMetadata = Metadata.FindByType(TypeOf(FileRef));
	AbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", ObjectMetadata);
	FullTextSearchUsing = Metadata.ObjectProperties.FullTextSearchUsing.Use;
	
	VersionRefToCompareSize = VersionRef;
	If VersionRef <> Undefined Then
		VersionRefToCompareSize = VersionRef;
	ElsIf AbilityToStoreVersions AND ValueIsFilled(FileRef.CurrentVersion)Then
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
				FullPath = FullVolumePath(CurrentVersionVolume) + CurrentVersionFilePath; 
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
	
	If FileInfo.StoreVersions Then
		ErrorTitle = NStr("ru = 'Ошибка при записи новой версии присоединенных файлов.'; en = 'An error occurred while writing a new version of the attached files.'; pl = 'Błąd przy zapisie nowej wersji dołączonych plików.';es_ES = 'Error al guardar la nueva versión de los archivos adjuntos.';es_CO = 'Error al guardar la nueva versión de los archivos adjuntos.';tr = 'Eklenen dosyaların yeni sürümü kaydedilirken hata oluştu.';it = 'Si è verificato un errore durante la scrittura di una nuova versione dei file allegati.';de = 'Fehler beim Schreiben einer neuen Version von angehängten Dateien.'");
		ErrorEnd = NStr("ru = 'В этом случае запись версии файла невозможна.'; en = 'In this case, you cannot write the file version.'; pl = 'W tym przypadku zapis wersji pliku nie jest możliwy.';es_ES = 'En este caso es imposible guardar la versión del archivo.';es_CO = 'En este caso es imposible guardar la versión del archivo.';tr = 'Bu durumda dosya sürümü yazılamaz.';it = 'In questo caso, non è possibile scrivere la versione del file.';de = 'In diesem Fall kann die Dateiversion nicht aufgezeichnet werden.'");

		FileVersionsStorageCatalogName = FilesVersionsStorageCatalogName(
			TypeOf(FileRef.FileOwner), "", ErrorTitle, ErrorEnd);
			
		Version = Catalogs[FileVersionsStorageCatalogName].CreateItem();
		Version.ParentVersion = FileRef.CurrentVersion;
		Version.VersionNumber = FindMaxVersionNumber(FileRef) + 1;
	Else
		
		If VersionRef = Undefined Then
			Version = FileRef.CurrentVersion.GetObject();
		Else
			Version = VersionRef.GetObject();
		EndIf;
	
		LockDataForEdit(Version.Ref, , UUIDOfForm);
		VersionLocked = True;
		
		// Deleting file from the hard drive and replacing it with the new one.
		If Version.FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
			If NOT Version.Volume.IsEmpty() Then
				FullPath = FullVolumePath(Version.Volume) + Version.PathToFile; 
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
		
	EndIf;
	
	Version.Owner = FileRef;
	If User = Undefined Then
		Version.Author = Users.CurrentUser();
	Else
		Version.Author = User;
	EndIf;
	Version.UniversalModificationDate = ModificationTimeUniversal;
	Version.FileModificationDate = ModificationTime;
	Version.CreationDate = CurrentSessionDate();
	Version.Size = FileInfo.Size;
	Version.FullDescr = FileInfo.BaseName;
	Version.Description = FileInfo.BaseName;
	Version.Comment = FileInfo.Comment;
	Version.Extension = CommonClientServer.ExtensionWithoutPoint(FileInfo.ExtensionWithoutPoint);
	
	FilesStorageTyoe = FilesStorageTyoe();
	Version.FileStorageType = FilesStorageTyoe;
	
	If BinaryData = Undefined Then
		BinaryData = GetFromTempStorage(FileInfo.TempFileStorageAddress);
	EndIf;
	
	If Version.Size = 0 Then
		Version.Size = BinaryData.Size();
		FilesOperationsInternalClientServer.CheckFileSizeForImport(Version);
	EndIf;
		
	If FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
		
		// clearing fields
		Version.PathToFile = "";
		Version.Volume = Catalogs.FileStorageVolumes.EmptyRef();
	Else // hard drive storage
		
		FileEncrypted = False;
		If FileInfo.Encrypted <> Undefined Then
			FileEncrypted = FileInfo.Encrypted;
		EndIf;
		
		Information = AddFileToVolume(BinaryData,
			ModificationTimeUniversal, FileInfo.BaseName, Version.Extension,
			Version.VersionNumber, FileEncrypted); 
		Version.Volume        = Information.Volume;
		Version.PathToFile = Information.PathToFile;
		
	EndIf;
	
	If ObjectMetadata.FullTextSearch = FullTextSearchUsing Then
		TextExtractionResult = ExtractText(FileInfo.TempTextStorageAddress);
		Version.TextStorage = TextExtractionResult.TextStorage;
		Version.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
		If FileInfo.NewTextExtractionStatus <> Undefined Then
			Version.TextExtractionStatus = FileInfo.NewTextExtractionStatus;
		EndIf;
	Else
		Version.TextStorage = New ValueStorage("");
		Version.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
	Version.Fill(Undefined);
	Version.Write();
	
	If FilesStorageTyoe = Enums.FileStorageTypes.InInfobase Then
		WriteFileToInfobase(Version.Ref, BinaryData);
	EndIf;
	
	If VersionLocked Then
		UnlockDataForEdit(Version.Ref, UUIDOfForm);
	EndIf;
	
	FilesOperationsInternalServerCall.WriteFileVersionEncoding(Version.Ref, PreVersionEncoding);

	If HasSaveRight Then
		FileURL = GetURL(FileRef);
		UserWorkHistory.Add(FileURL);
	EndIf;
	
	Return Version.Ref;
	
EndFunction

// Substitutes the reference to the version in the File card.
//
// Parameters:
// FileRef - CatalogRef.Files - a file, in which a version is created.
// Version  - CatalogRef.FilesVersions - a file version.
// TextTempStorageAddress - String - contains the address in the temporary storage, where the binary 
//                                           data with the text file, or the ValueStorage that 
//                                           directly contains the binary data with the text file are located.
//  UUID - a form UUID.
//
Procedure UpdateVersionInFile(FileRef,
								Version,
								Val TempTextStorageAddress,
								UUID = Undefined) Export
	
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
		
		FileObject.CurrentVersion = Version.Ref;
		If CatalogMetadata.FullTextSearch = FullTextSearchUsing Then
			If TypeOf(TempTextStorageAddress) = Type("ValueStorage") Then
				// When creating a File from a template, the value storage is copied directly.
				FileObject.TextStorage = TempTextStorageAddress;
			Else
				TextExtractionResult = ExtractText(TempTextStorageAddress);
				FileObject.TextStorage = TextExtractionResult.TextStorage;
				FileObject.TextExtractionStatus = TextExtractionResult.TextExtractionStatus;
			EndIf;
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

// Finds the maximum version number for this File object. If there is no versions, then 0.
// Parameters:
//  FileRef  - CatalogRef.Files - a reference to the file.
//
// Returns:
//   Number  - max version number.
//
Function FindMaxVersionNumber(FileRef)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(MAX(Versions.VersionNumber), 0) AS MaxNumber
	|FROM
	|	Catalog.FilesVersions AS Versions
	|WHERE
	|	Versions.Owner = &File";
	
	Query.Parameters.Insert("File", FileRef);
		
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		If Selection.MaxNumber = Null Then
			Return 0;
		EndIf;
		
		Return Number(Selection.MaxNumber);
	EndIf;
	
	Return 0;
EndFunction

// Returns error message text containing a reference to the item of a file storage catalog.
// 
//
Function ErrorTextWhenSavingFileInVolume(Val ErrorMessage, Val File)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Ошибка, при сохранении файла в томе:
		           |""%1"".
		           |
		           |Ссылка на файл: ""%2"".'; 
		           |en = 'An error occurred when saving a file to volume:
		           |""%1"".
		           |
		           |Reference to the file: ""%2"".'; 
		           |pl = 'Błąd podczas zapisywania pliku w woluminie:
		           |""%1"".
		           |
		           |Odnośnik do pliku: ""%2"".';
		           |es_ES = 'Error al guardar el archivo en el tomo:
		           |""%1"".
		           |
		           |Enlace al archivo: ""%2"".';
		           |es_CO = 'Error al guardar el archivo en el tomo:
		           |""%1"".
		           |
		           |Enlace al archivo: ""%2"".';
		           |tr = 'Dosya birimde 
		           | kaydedilirken bir hata oluştu: ""%1"". 
		           |
		           | Referans dosyası: ""%2""';
		           |it = 'Errore, durante il salvataggio del file nel tomo:
		           |""%1"".
		           |
		           |Link al file: ""%2"".';
		           |de = 'Fehler beim Speichern einer Datei im Volume:
		           |""%1"".
		           |
		           |Dateiverweis: ""%2"".'"),
		ErrorMessage,
		GetURL(File) );
	
EndFunction

/////////////////////////////////////////////////////////////////////////////////////
// Event handlers of a file item form.

Procedure ItemFormOnCreateAtServer(Context, Cancel, StandardProcessing, Parameters, ReadOnly, CustomizeFormObject = False) Export
	
	Items = Context.Items;
	
	FileCreated = Parameters.IsNew;
	
	ColumnsArray = New Array;
	For Each ColumnDetails In Context.FormAttributeToValue("DigitalSignatures").Columns Do
		ColumnsArray.Add(ColumnDetails.Name);
	EndDo;
	SignatureTableColumnsDetails = New FixedArray(ColumnsArray);
	
	CurrentUser = Users.AuthorizedUser();
	
	If ValueIsFilled(Parameters.CopyingValue) Then
		InfobaseUpdate.CheckObjectProcessed(Parameters.CopyingValue);
		If Parameters.CreateMode = "FromTemplate" Then
			ObjectValue = FillFileDataByTemplate(Context, ObjectValue, Parameters, CustomizeFormObject)
		Else
			ObjectValue = FillFileDataFromCopy(Context, ObjectValue, Parameters, CustomizeFormObject);
		EndIf;
	Else
		If ValueIsFilled(Parameters.AttachedFile) Then
			ObjectValue = Parameters.AttachedFile.GetObject();
		Else
			ObjectValue = Parameters.Key.GetObject();
		EndIf;
		InfobaseUpdate.CheckObjectProcessed(ObjectValue, Context);
	EndIf;
	ObjectValue.Fill(Undefined);
	
	Context.CatalogName = ObjectValue.Metadata().Name;
	
	ErrorTitle = NStr("ru = 'Ошибка при настройке формы элемента присоединенных файлов.'; en = 'An error occurred when setting up an attached file item form.'; pl = 'Błąd podczas konfiguracji formularzu elementu dołączonych plików.';es_ES = 'Error al ajustar el formulario del elemento de los archivos adjuntos.';es_CO = 'Error al ajustar el formulario del elemento de los archivos adjuntos.';tr = 'Ekli dosyaların unsur biçimi yapılandırırken bir hata oluştu.';it = 'Si è verificato un errore durante l''impostazione di un modulo di elemento del file allegato.';de = 'Fehler beim Einrichten des Formulars der angehängten Artikelinformation.'");
	ErrorEnd = NStr("ru = 'В этом случае настройка формы элемента невозможна.'; en = 'In this case, you cannot set item forms.'; pl = 'W tym przypadku konfiguracja formularzu elementu nie jest możliwe.';es_ES = 'En este caso es imposible ajustar el formulario del elemento.';es_CO = 'En este caso es imposible ajustar el formulario del elemento.';tr = 'Bu durumda, unsur biçimi yapılandırılamaz.';it = 'In questo caso, non è possibile impostare moduli di elemento.';de = 'In diesem Fall ist die Einstellung der Elementform nicht möglich.'");
	
	FileVersionsStorageCatalogName = FilesVersionsStorageCatalogName(
		TypeOf(ObjectValue.FileOwner), "", ErrorTitle, ErrorEnd);
	
	CanCreateFileVersions = TypeOf(ObjectValue.Ref) = Type("CatalogRef.Files");
	Context.CanCreateFileVersions = CanCreateFileVersions; 
	
	If CustomizeFormObject Then
		Items.StoreVersions0.Visible = CanCreateFileVersions;
		SetUpFormObject(ObjectValue, Context);
	Else
		ValueToFormData(ObjectValue, Context.Object);
		Items.StoreVersions.Visible = CanCreateFileVersions;
	EndIf;
	
	CryptographyOnCreateFormAtServer(Context, False);
	FillSignatureList(Context, Parameters.CopyingValue);
	FillEncryptionList(Context, Parameters.CopyingValue);
	
	CommonSettings = FilesOperationsInternalClientServer.CommonFilesOperationsSettings();
	
	FileExtensionInList = FilesOperationsInternalClientServer.FileExtensionInList(
		CommonSettings.TestFilesExtensionsList, Context.Object.Extension);
	
	If FileExtensionInList Then
		If CanCreateFileVersions AND Context.Object.Property("CurrentVersion") AND ValueIsFilled(Context.Object.CurrentVersion) Then
			CurrentFileVersion = Context.Object.CurrentVersion;
		Else
			CurrentFileVersion = Context.Object.Ref;
		EndIf;
		If ValueIsFilled(CurrentFileVersion) Then
			
			EncodingValue = FilesOperationsInternalServerCall.GetFileVersionEncoding(
				CurrentFileVersion);
			
			EncodingsList = Encodings();
			ListItem = EncodingsList.FindByValue(EncodingValue);
			If ListItem = Undefined Then
				Context.Encoding = EncodingValue;
			Else
				Context.Encoding = ListItem.Presentation;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Context.Encoding) Then
			Context.Encoding = NStr("ru = 'По умолчанию'; en = 'Default'; pl = 'Domyślnie';es_ES = 'Por defecto';es_CO = 'Por defecto';tr = 'Varsayılan';it = 'Predefinito';de = 'Standard'");
		EndIf;
		
	Else
		Context.Items.Encoding.Visible = False;
	EndIf;
	
	If GetFunctionalOption("UseFileSync") Then
		Context.FileToEditeInCloud = FileToEditeInCloud(Context.Object.Ref);
	EndIf;
	
	If ReadOnly
		OR NOT AccessRight("Update", Context.Object.FileOwner.Metadata()) Then
		SetChangeButtonsInvisible(Context.Items);
	EndIf;
	
	If NOT ReadOnly
		AND NOT Context.Object.Ref.IsEmpty() AND CustomizeFormObject Then
		LockDataForEdit(Context.Object.Ref, , Context.UUID);
	EndIf;
	
	OwnerType = TypeOf(ObjectValue.FileOwner);
	Context.Items.FileOwner.Title = OwnerType;
	
EndProcedure

Function FillFileDataByTemplate(Context, ObjectValue, Parameters, CustomizeFormObject)
	
	ObjectToCopy             = Parameters.CopyingValue.GetObject();
	Context.CopyingValue = Parameters.CopyingValue;
	
	ObjectValue = Catalogs[Parameters.FilesStorageCatalogName].CreateItem();
	
	FillPropertyValues(
		ObjectValue,
		ObjectToCopy,
		"Description,
		|Encrypted,
		|Details,
		|SignedWithDS,
		|Size,
		|Extension,
		|FileOwner,
		|TextStorage,
		|DeletionMark");
		
	ObjectValue.FileOwner                = Parameters.FileOwner;
	CreationDate                                = CurrentSessionDate();
	ObjectValue.CreationDate                 = CreationDate;
	ObjectValue.UniversalModificationDate = ToUniversalTime(CreationDate);
	ObjectValue.Author                        = Users.AuthorizedUser();
	ObjectValue.FileStorageType             = FilesStorageTyoe();
	ObjectValue.StoreVersions                = ?(Parameters.FilesStorageCatalogName = "Files",
		ObjectToCopy.StoreVersions, False);
	
	Return ObjectValue;
	
EndFunction

Function FillFileDataFromCopy(Context, ObjectValue, Parameters, CustomizeFormObject)

	ObjectToCopy = Parameters.CopyingValue.GetObject();
	Context.CopyingValue = Parameters.CopyingValue;
	
	MetadataObject = ObjectToCopy.Metadata();
	ObjectValue = Catalogs[MetadataObject.Name].CreateItem();
	
	AttributesToExclude = "Parent,Owner,LoanDate,Changed,Code,DeletionMark,BeingEditedBy,Volume,PredefinedDataName,Predefined,PathToFile,TextExtractionStatus";
	If MetadataObject.Attributes.Find("CurrentVersion") <> Undefined Then
		AttributesToExclude = AttributesToExclude + ",CurrentVersion";
	EndIf;
	
	FillPropertyValues(ObjectValue,ObjectToCopy, , AttributesToExclude);
	ObjectValue.Author            = Users.AuthorizedUser();
	ObjectValue.FileStorageType = FilesStorageTyoe();
	
	Return ObjectValue;
	
EndFunction

Procedure SetUpFormObject(Val NewObject, Context)
	
	NewObjectType = New Array;
	NewObjectType.Add(TypeOf(NewObject));
	NewAttribute = New FormAttribute("Object", New TypeDescription(NewObjectType));
	NewAttribute.StoredData = True;
	
	AttributesToAdd = New Array;
	AttributesToAdd.Add(NewAttribute);
	
	Context.ChangeAttributes(AttributesToAdd);
	Context.ValueToFormAttribute(NewObject, "Object");
	For each Item In Context.Items Do
		If TypeOf(Item) = Type("FormField")
			AND StrStartsWith(Item.DataPath, "PrototypeObject[0].")
			AND StrEndsWith(Item.Name, "0") Then
			
			ItemName = Left(Item.Name, StrLen(Item.Name) -1);
			
			If Context.Items.Find(ItemName) <> Undefined  Then
				Continue;
			EndIf;
			
			NewItem = Context.Items.Insert(ItemName, TypeOf(Item), Item.Parent, Item);
			NewItem.DataPath = "Object." + Mid(Item.DataPath, StrLen("PrototypeObject[0].") + 1);
			
			If Item.Type = FormFieldType.CheckBoxField Or Item.Type = FormFieldType.PictureField Then
				PropertiesToExclude = "Name, DataPath";
			Else
				PropertiesToExclude = "Name, DataPath, SelectedText, TypeLink";
			EndIf;
			FillPropertyValues(NewItem, Item, , PropertiesToExclude);
			Item.Visible = False;
		EndIf;
	EndDo;
	
	Placement = NewObject.FileOwner;
	
	If Not NewObject.IsNew() Then
		Context.URL = GetURL(NewObject);
	EndIf;
	
EndProcedure

Procedure FillEncryptionList(Context, Val Source = Undefined) Export
	If Not ValueIsFilled(Source) Then
		Source = Context.Object;
	EndIf;
	
	Context.EncryptionCertificates.Clear();
	
	If Source.Encrypted Then
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			EncryptionCertificates = ModuleDigitalSignature.EncryptionCertificates(Source.Ref);
			
			For Each EncryptionCertificate In EncryptionCertificates Do
				
				NewRow = Context.EncryptionCertificates.Add();
				NewRow.Presentation = EncryptionCertificate.Presentation;
				NewRow.Thumbprint = EncryptionCertificate.Thumbprint;
				NewRow.SequenceNumber = EncryptionCertificate.SequenceNumber;
				
				CertificateBinaryData = EncryptionCertificate.Certificate;
				If CertificateBinaryData <> Undefined Then
					
					NewRow.CertificateAddress = PutToTempStorage(
						CertificateBinaryData, Context.UUID);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	TitleText = NStr("ru = 'Разрешено расшифровывать'; en = 'Decryption allowed'; pl = 'Rozszyfrowywanie dozwolone';es_ES = 'Descodificación permitida';es_CO = 'Descodificación permitida';tr = 'Şifre çözme izni verildi';it = 'Decodifica permessa';de = 'Entschlüsselung ist erlaubt'");
	
	If Context.EncryptionCertificates.Count() <> 0 Then
		TitleText =TitleText + " (" + Format(Context.EncryptionCertificates.Count(), "NG=") + ")";
	EndIf;
	
	Context.Items.EncryptionCertificatesGroup.Title = TitleText;
	
EndProcedure

Procedure FillSignatureList(Context, Val Source = Undefined) Export
	If Not ValueIsFilled(Source) Then
		Source = Context.Object;
	EndIf;
	
	Context.DigitalSignatures.Clear();
	
	DigitalSignatures = DigitalSignaturesList(Source, Context.UUID);
	
	For Each FileDigitalSignature In DigitalSignatures Do
		
		NewRow = Context.DigitalSignatures.Add();
		FillPropertyValues(NewRow, FileDigitalSignature);
		
		FilesOperationsInternalClientServer.FillSignatureStatus(NewRow);
		
		CertificateBinaryData = FileDigitalSignature.Certificate.Get();
		If CertificateBinaryData <> Undefined Then 
			NewRow.CertificateAddress = PutToTempStorage(
				CertificateBinaryData, Context.UUID);
		EndIf;
		
	EndDo;
	
	TitleText = NStr("ru = 'Электронные подписи'; en = 'Digital signatures'; pl = 'Podpisy cyfrowe';es_ES = 'Firmas digitales';es_CO = 'Firmas digitales';tr = 'Dijital imzalar';it = 'Firme digitali';de = 'Digitale Signaturen'");
	
	If Context.DigitalSignatures.Count() <> 0 Then
		TitleText = TitleText + " (" + String(Context.DigitalSignatures.Count()) + ")";
	EndIf;
	
	Context.Items.DigitalSignaturesGroup.Title = TitleText;
	
EndProcedure

Function DigitalSignaturesList(Source, UUID)
	
	DigitalSignatures = New Array;
	
	If Source.SignedWithDS Then
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			DigitalSignatures = ModuleDigitalSignature.SetSignatures(Source.Ref);
			
			For Each FileDigitalSignature In DigitalSignatures Do
				
				FileDigitalSignature.Insert("Object", Source.Ref);
				SignatureAddress = PutToTempStorage(FileDigitalSignature.Signature, UUID);
				FileDigitalSignature.Insert("SignatureAddress", SignatureAddress);
			EndDo;
	
		EndIf;
		
	EndIf;
	
	Return DigitalSignatures;
	
EndFunction

Function StgnaturesListToSend(Source, UUID, FileName)
	
	DigitalSignatures = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		
		DigitalSignatures = DigitalSignaturesList(Source, UUID);
		DataFileNameContent = CommonClientServer.ParseFullFileName(FileName);
		
		ModuleDigitalSignatureInternalClientServer = Common.CommonModule("DigitalSignatureInternalClientServer");
		ModuleDigitalSignatureInternal             = Common.CommonModule("DigitalSignatureInternal");
		
		For Each FileDigitalSignature In DigitalSignatures Do
			
			SignatureFileName = ModuleDigitalSignatureInternalClientServer.SignatureFileName(DataFileNameContent.BaseName,
				String(FileDigitalSignature.CertificateOwner));
			FileDigitalSignature.Insert("FileName", SignatureFileName);
			
			DataByCertificate = ModuleDigitalSignatureInternal.DataByCertificate(FileDigitalSignature, UUID);
			FileDigitalSignature.Insert("CertificateAddress", DataByCertificate.CertificateAddress);
			
			CertificateFileName = ModuleDigitalSignatureInternalClientServer.CertificateFileName(DataFileNameContent.BaseName,
				String(FileDigitalSignature.CertificateOwner), DataByCertificate.CertificateExtension);
				
			FileDigitalSignature.Insert("CertificateFileName", CertificateFileName);
			
		EndDo;
	EndIf;
	
	Return DigitalSignatures;
	
EndFunction

Procedure SetChangeButtonsInvisible(Items)
	
	CommandsNames = GetObjectChangeCommandsNames();
	
	For each FormItem In Items Do
	
		If TypeOf(FormItem) <> Type("FormButton") Then
			Continue;
		EndIf;
		
		If CommandsNames.Find(FormItem.CommandName) <> Undefined Then
			FormItem.Visible = False;
		EndIf;
	EndDo;
	
EndProcedure

Function GetObjectChangeCommandsNames()
	
	CommandsNames = New Array;
	
	CommandsNames.Add("DigitallySignFile");
	CommandsNames.Add("AddDSFromFile");
	
	CommandsNames.Add("DeleteDigitalSignature");
	
	CommandsNames.Add("Edit");
	CommandsNames.Add("EndEdit");
	CommandsNames.Add("Unlock");
	
	CommandsNames.Add("Encrypt");
	CommandsNames.Add("Decrypt");
	
	CommandsNames.Add("StandardCopy");
	CommandsNames.Add("UpdateFromFileOnHardDrive");
	
	CommandsNames.Add("StandardWrite");
	CommandsNames.Add("StandardWriteAndClose");
	CommandsNames.Add("StandardSetDeletionMark");
	
	Return CommandsNames;
	
EndFunction

Function FilesSettings() Export
	
	FilesSettings = New Structure;
	FilesSettings.Insert("DontClearFiles",            New Array);
	FilesSettings.Insert("DontSynchronizeFiles",   New Array);
	FilesSettings.Insert("DontOutputToInterface",      New Array);
	FilesSettings.Insert("DontCreateFilesByTemplate", New Array);
	FilesSettings.Insert("FilesWithoutFolders",             New Array);
	
	SSLSubsystemsIntegration.OnDefineFilesSynchronizationExceptionObjects(FilesSettings.DontSynchronizeFiles);
	FilesOperationsOverridable.OnDefineSettings(FilesSettings);
	
	Return FilesSettings;
	
EndFunction

Procedure GenerateFilesListToSendViaEmail(Result, FileAttachment, FormID) Export
	
	FileDataAndBinaryData = FilesOperations.FileData(FileAttachment, FormID);
	FileName      = CommonClientServer.GetNameWithExtension(FileDataAndBinaryData.Description, FileDataAndBinaryData.Extension);
	FileDetails = FileDetails(FileName, FileDataAndBinaryData.BinaryFileDataRef);
	Result.Add(FileDetails);
	
	If FileAttachment.SignedWithDS Then
		SignaturesList = StgnaturesListToSend(FileAttachment, FormID, FileName);
		For each FileDigitalSignature In SignaturesList Do
			FileDetails = FileDetails(FileDigitalSignature.FileName, FileDigitalSignature.SignatureAddress);
			Result.Add(FileDetails);
			
			If ValueIsFilled(FileDigitalSignature.CertificateAddress) Then
				FileDetails = FileDetails(FileDigitalSignature.CertificateFileName, FileDigitalSignature.CertificateAddress);
				Result.Add(FileDetails);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

Function FileDetails(FileName, AddressInTempStorage)
	
	FileDetails = New Structure;
	FileDetails.Insert("Presentation",             FileName);
	FileDetails.Insert("AddressInTempStorage", AddressInTempStorage);
	
	Return FileDetails;
	
EndFunction


/////////////////////////////////////////////////////////////////////////////////////
// Clear unused files.

Procedure ClearUnusedFilesData(ClearingSetup, ExceptionsArray = Undefined)
	
	If ClearingSetup.Action = Enums.FilesCleanupOptions.DoNotClear Then
		Return;
	EndIf;
	
	If ExceptionsArray = Undefined Then
		ExceptionsArray = New Array;
	EndIf;
	
	OwnersTree = SelectDataByRule(ClearingSetup, ExceptionsArray);
	
	If OwnersTree.Rows.Count() = 0 Then
		Return;
	EndIf;
	
	For Each File In OwnersTree.Rows Do
		
		If ClearingSetup.IsFile Then
			
			If ClearingSetup.Action = Enums.FilesCleanupOptions.CleanUpFilesAndVersions Then
				FileForMark = File.FileRef.GetObject();
				// Skipping deletion if the file is locked for editing.
				If ValueIsFilled(FileForMark.BeingEditedBy) Then
					Continue;
				EndIf;
				FileForMark.SetDeletionMark(True);
			EndIf;
			
			For Each Version In File.Rows Do
				ClearDataOnVersion(Version.VersionRef);
			EndDo;
			
		Else
			ClearDataAboutFile(File.FileRef);
		EndIf;
		
	EndDo;

EndProcedure

Function SelectDataByRule(ClearingSetup, ExceptionsArray)
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	ClearByRule = ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.ByRule;
	If ClearByRule Then
		ComposerSettings = ClearingSetup.FilterRule.Get();
		If ComposerSettings <> Undefined Then
			SettingsComposer.LoadSettings(ClearingSetup.FilterRule.Get());
		EndIf;
	EndIf;
	
	DataCompositionSchema = New DataCompositionSchema;
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	DataCompositionSchema.TotalFields.Clear();
	
	If ClearingSetup.IsCatalogItemSetup Then
		FileOwner = ClearingSetup.OwnerID;
		ExceptionItem = ClearingSetup.FileOwner;
	Else
		FileOwner = ClearingSetup.FileOwner;
		ExceptionItem = Undefined;
	EndIf;
	
	DataCompositionSchema.DataSets[0].Query = QueryTextToClearFiles(
		FileOwner,
		ClearingSetup,
		ExceptionsArray,
		ExceptionItem);
	
	Structure = SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("FileRef");
	
	If ClearingSetup.IsFile Then
	
		VersionsStructure = Structure.Structure.Add(Type("DataCompositionGroup"));
	
		SelectedField = VersionsStructure.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedField.Field = New DataCompositionField("VersionRef");
	
	EndIf;
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Settings = SettingsComposer.GetSettings();
	
	Parameter = SettingsComposer.Settings.DataParameters.Items.Find("OwnerType");
	Parameter.Value = TypeOf(FileOwner.EmptyRefValue);
	Parameter.Use = True;
	
	Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ClearingPeriod");
	If Parameter <> Undefined Then
		If ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverOneMonth Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -1);
		ElsIf ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverOneYear Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -12);
		ElsIf ClearingSetup.ClearingPeriod = Enums.FilesCleanupPeriod.OverSixMonths Then
			ClearingPeriodValue = AddMonth(BegOfDay(CurrentSessionDate()), -6);
		EndIf;
		Parameter.Value = ClearingPeriodValue;
		Parameter.Use = True;
	EndIf;
	
	CurrentDateParameter = SettingsComposer.Settings.DataParameters.Items.Find("CurrentDate");
	If CurrentDateParameter <> Undefined Then
		CurrentDateParameter.Value = CurrentSessionDate();
		CurrentDateParameter.Use = True;
	EndIf;
	
	If ExceptionsArray.Count() > 0 Then
		Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ExceptionsArray");
		Parameter.Value = ExceptionsArray;
		Parameter.Use = True;
	EndIf;
	
	If ClearingSetup.IsCatalogItemSetup Then
		Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ExceptionItem");
		Parameter.Value = ExceptionItem;
		Parameter.Use = True;
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionProcessor = New DataCompositionProcessor;
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	ValuesTree = New ValueTree;
	
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, SettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	OutputProcessor.SetObject(ValuesTree);
	OutputProcessor.Output(DataCompositionProcessor);
	
	Return ValuesTree;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File synchronization

Procedure SetFilesSynchronizationScheduledJobParameter(Val ParameterName, Val ParameterValue) Export
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", Metadata.ScheduledJobs.FileSynchronization);
	If Not Common.DataSeparationEnabled() Then
		JobParameters.Insert("MethodName", Metadata.ScheduledJobs.FileSynchronization.MethodName);
	EndIf;
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	If JobsList.Count() = 0 Then
		JobParameters.Insert(ParameterName, ParameterValue);
		ScheduledJobsServer.AddJob(JobParameters);
	Else
		JobParameters = New Structure(ParameterName, ParameterValue);
		For Each Job In JobsList Do
			ScheduledJobsServer.ChangeJob(Job, JobParameters);
		EndDo;
	EndIf;

EndProcedure

Function IsFilesFolder(OwnerObject) Export
	
	Return TypeOf(OwnerObject) = Type("CatalogRef.FileFolders");
	
EndFunction

Function FileToEditeInCloud(File)
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	FilesSynchronizationWithCloudServiceStatuses.File
		|FROM
		|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
		|WHERE
		|	FilesSynchronizationWithCloudServiceStatuses.File = &File";
	
	Query.SetParameter("File", File);
	
	QueryResult = Query.Execute();
	
	DetailedRecordsSelection = QueryResult.Select();
	
	While DetailedRecordsSelection.Next() Do
		Return True;
	EndDo;
	
	Return False;
	
EndFunction

Function OnDefineFilesSynchronizationExceptionObjects() Export
	
	Return FilesSettings().DontSynchronizeFiles;
	
EndFunction

Function QueryTextToSynchronizeFIles(FileOwner, SyncSetup, ExceptionsArray, ExceptionItem)
	
	ObjectType = FileOwner;
	OwnerTypePresentation = Common.ObjectKindByType(TypeOf(ObjectType.EmptyRefValue));
	FullFilesCatalogName = SyncSetup.FileOwnerType.FullName;
	FilesObjectMetadata = Metadata.FindByFullName(FullFilesCatalogName);
	HasAbilityToStoreVersions = Common.HasObjectAttribute("CurrentVersion", FilesObjectMetadata);
	HasTypeDate = False;
	
	QueryText = "";
	
	CatalogFiles = Common.MetadataObjectByID(SyncSetup.FileOwnerType);
	AbilityToCreateGroups = CatalogFiles.Hierarchical;
	
	If TypeOf(FileOwner) <> Type("CatalogRef.MetadataObjectIDs") Then
		CatalogFolders = Common.MetadataObjectByID(SyncSetup.OwnerID);
	Else
		CatalogFolders = Common.MetadataObjectByID(FileOwner);
	EndIf;
	
	If Not IsBlankString(QueryText) Then
		QueryText= QueryText + "
		|
		|UNION ALL
		|";
	EndIf;
	
	QueryText = QueryText + "SELECT
	|	CatalogFolders.Ref,";
	
	AddAvailableFilterFields(QueryText, ObjectType);
	
	QueryText = QueryText + "
	|	CatalogFiles.Ref AS FileRef,";
	
	If AbilityToCreateGroups Then
		
		QueryText = QueryText + "
		|	CASE WHEN CatalogFiles.IsFolder THEN
		|		CatalogFiles.Description
		|	ELSE
		|		CatalogFiles.Description + ""."" + CatalogFiles.Extension
		|	END AS Description,
		|	CatalogFiles.DeletionMark AS DeletionMark,
		|	CatalogFiles.FileOwner AS Parent,
		|	FALSE AS IsFolder,";
		
		FilterByFolders = "CatalogFiles.IsFolder 
		| OR (NOT CatalogFiles.IsFolder AND CatalogFiles.SignedWithDS = FALSE AND CatalogFiles.Encrypted = FALSE) ";
		
	Else
		
		QueryText = QueryText + "
		|	CatalogFiles.Description + ""."" + CatalogFiles.Extension AS Description,
		|	CatalogFiles.DeletionMark AS DeletionMark,
		|	CatalogFiles.FileOwner AS Parent,
		|	FALSE AS IsFolder,";
		
		FilterByFolders = " CatalogFiles.SignedWithDS = FALSE AND CatalogFiles.Encrypted = FALSE ";
		
	EndIf;
	
	QueryText = QueryText + "
	|	TRUE AS InInfobase,
	|	FALSE AS IsOnServer,
	|	UNDEFINED AS Changes,
	|	ISNULL(FilesSynchronizationWithCloudServiceStatuses.Href, """") AS Href,
	|	ISNULL(FilesSynchronizationWithCloudServiceStatuses.Etag, """") AS Etag,
	|	FALSE AS Processed,
	|	DATETIME(1, 1, 1, 0, 0, 0) AS SynchronizationDate,
	|	CAST("""" AS STRING(36)) AS UID1C,
	|	"""" AS ToHref,
	|	"""" AS ToEtag,
	|	"""" AS ParentServer,
	|	"""" AS ServerDescription,
	|	FALSE AS ModifiedAtServer,
	|	UNDEFINED AS Level,
	|	"""" AS ParentOrdering,
	|	" + ?(HasAbilityToStoreVersions, "TRUE", "FALSE") + " AS IsFile
	|FROM
	|	Catalog." + CatalogFiles.Name + " AS CatalogFiles
	|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|		ON (FilesSynchronizationWithCloudServiceStatuses.File = CatalogFiles.Ref)
	|		LEFT JOIN " + OwnerTypePresentation+ "." + CatalogFolders.Name + " AS CatalogFolders
	|		ON (CatalogFiles.FileOwner = CatalogFolders.Ref)
	|WHERE
	|	" + FilterByFolders + " AND VALUETYPE(CatalogFiles.FileOwner) = &OwnerType";
	
	If ExceptionsArray.Count() > 0 Then
		QueryText = QueryText + "
			|	AND NOT CatalogFolders.Ref IN HIERARCHY (&ExceptionsArray)";
	EndIf;
	
	If ExceptionItem <> Undefined Then
		QueryText = QueryText + "
			|	AND CatalogFolders.Ref IN HIERARCHY (&ExceptionItem)";
	EndIf;
	
	QueryText = QueryText + "
	|UNION ALL
	|
	|SELECT
	|	CatalogFolders.Ref,";
	
	AddAvailableFilterFields(QueryText, ObjectType);
	
	QueryText = QueryText + "
	|	CatalogFolders.Ref,
	|	" + ?(OwnerTypePresentation = "Document",
		"CatalogFolders.Presentation", "CatalogFolders.Description") + ",
	|	CatalogFolders.DeletionMark,";
	
	If Common.IsCatalog(CatalogFolders) AND CatalogFolders.Hierarchical Then
		QueryText = QueryText + "
		|	CASE
		|		WHEN CatalogFolders.Parent = VALUE(Catalog." + CatalogFolders.Name + ".EmptyRef)
		|			THEN UNDEFINED
		|		ELSE CatalogFolders.Parent
		|	END,";
	Else
		QueryText = QueryText + "Undefined,";
	EndIf;
	
	QueryText = QueryText + "
	|	TRUE,
	|	TRUE,
	|	FALSE,
		|	UNDEFINED,
	|	ISNULL(FilesSynchronizationWithCloudServiceStatuses.Href, """"),
	|	"""",
	|	FALSE,
	|	DATETIME(1, 1, 1, 0, 0, 0),
	|	"""",
	|	"""",
	|	"""",
	|	"""",
	|	"""",
	|	FALSE, 
	|	UNDEFINED,
	|	"""",
	|	" + ?(HasAbilityToStoreVersions, "TRUE", "FALSE") + "
	|FROM
	|	" + OwnerTypePresentation + "." + CatalogFolders.Name + " AS CatalogFolders
	|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|		ON (FilesSynchronizationWithCloudServiceStatuses.File = CatalogFolders.Ref
	|			AND FilesSynchronizationWithCloudServiceStatuses.Account = &Account)
	|		WHERE
	|			TRUE";
	
	If ExceptionsArray.Count() > 0 Then
		QueryText = QueryText + "
			|	AND NOT CatalogFolders.Ref IN HIERARCHY (&ExceptionsArray)";
	EndIf;
	
	If ExceptionItem <> Undefined Then
		QueryText = QueryText + "
			|	AND CatalogFolders.Ref IN HIERARCHY (&ExceptionItem)";
	
	EndIf;
		
	Return QueryText;
	
EndFunction

Function IsFilesOwner(OwnerObject)
	
	FilesTypesArray = Metadata.DefinedTypes.AttachedFilesOwner.Type.Types();
	Return FilesTypesArray.Find(TypeOf(OwnerObject)) <> Undefined;
	
EndFunction

Procedure AddAvailableFilterFields(QueryText, ObjectType)
	
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();
	
	If AllCatalogs.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
		Catalog = Metadata.Catalogs[ObjectType.Name];
		For Each Attribute In Catalog.Attributes Do
			QueryText = QueryText + Chars.LF + "CatalogFolders." + Attribute.Name + " AS " + Attribute.Name +",";
		EndDo;
	ElsIf AllDocuments.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
		Document = Metadata.Documents[ObjectType.Name];
		For Each Attribute In Document.Attributes Do
			If Attribute.Type.ContainsType(Type("Date")) Then
				QueryText = QueryText + Chars.LF + "DATEDIFF(" + Attribute.Name + ", &CurrentDate, DAY) AS DaysBeforeDeletionFrom" + Attribute.Name + ",";
			EndIf;
			QueryText = QueryText + Chars.LF + "CatalogFolders." + Attribute.Name + ",";
		EndDo;
	EndIf;
	
EndProcedure

// Checks if an HTTP request failed and throws an exception.
Function CheckHTTP1CException(Response, ServerAddress)
	Result = New Structure("Success, ErrorText");
	
	If (Response.StatusCode >= 400) AND (Response.StatusCode <= 599) Then
		
		ErrorTemplate = NStr("ru = 'Не удалось синхронизировать файл по адресу %2, т.к. сервер вернул HTTP код: %1. %3'; en = 'Cannot synchronize the file at %2, as the server returned HTTP code: %1. %3'; pl = 'Nie udało się zsynchronizować pliku z adresem %2, ponieważ serwer zwrócił kod HTTP : %1. %3';es_ES = 'No se ha podido sincronizar el archivo según la dirección %2, porque el servidor ha devuelto el código HTTP: %1. %3';es_CO = 'No se ha podido sincronizar el archivo según la dirección %2, porque el servidor ha devuelto el código HTTP: %1. %3';tr = 'Sunucu HTTP kodunu iade ettiği için %2 adreste dosya eşleştirilemedi: %1. %3';it = 'Non è stato possibile sincronizzare il file all''indirizzo %2, poiché il server ha ritornato un codice HTTP: %1. %3';de = 'Die Datei konnte nicht mit der Adresse synchronisiert werden %2, da der Server den HTTP-Code zurückgab: %1. %3'");
		ErrorInformation = Response.GetBodyAsString();
		
		Result.Success = False;
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, 
			Response.StatusCode, DecodeString(ServerAddress, StringEncodingMethod.URLInURLEncoding), ErrorInformation);
		
		Return Result;
		
	EndIf;
	
	Result.Success = True;
	Return Result;
	
EndFunction

// Performs the webdav protocol method.
Function PerformWebdavMethod(MethodName, Href, TitlesMap, ExchangeStructure, XMLQuery="", ProtocolText = Undefined)

	HrefStructure = URIStructureDecoded(Href);
	
	HTTP = CreateHTTPConnectionWebdav(HrefStructure, ExchangeStructure, 20);
	
	HTTPWebdavQuery = New HTTPRequest(HrefStructure.PathAtServer, TitlesMap);
	
	If ValueIsFilled(XMLQuery) Then
		HTTPWebdavQuery.SetBodyFromString(XMLQuery);
	EndIf;
	
	If ProtocolText<>Undefined Then
		ProtocolText = ProtocolText + ?(IsBlankString(ProtocolText), "", Chars.LF)
			+ MethodName + " " + Href + Chars.LF + Chars.LF + XMLQuery + Chars.LF;
	EndIf; 
	
	ExchangeStructure.Response = HTTP.CallHTTPMethod(MethodName, HTTPWebdavQuery);
	
	If ProtocolText <> Undefined Then
		ProtocolText = ProtocolText + ?(IsBlankString(ProtocolText), "", Chars.LF) + "HTTP RESPONSE "
			+ ExchangeStructure.Response.StatusCode + Chars.LF + Chars.LF;
		For each ResponseTitle In ExchangeStructure.Response.Headers Do
			ProtocolText = ProtocolText+ResponseTitle.Key + ": " + ResponseTitle.Value + Chars.LF;
		EndDo; 
		ProtocolText = ProtocolText + Chars.LF + ExchangeStructure.Response.GetBodyAsString() + Chars.LF;
	EndIf; 
	
	Return CheckHTTP1CException(ExchangeStructure.Response, Href);
	
EndFunction

// Updates the unique service attribute of the file on the webdav server.
Function UpdateFileUID1C(Href, UID1C, SynchronizationParameters)
	
	HTTPTitles                  = New Map;
	HTTPTitles["User-Agent"]   = "1C Enterprise 8.3";
	HTTPTitles["Content-type"] = "text/xml";
	HTTPTitles["Accept"]       = "text/xml";
	
	XMLQuery = "<?xml version=""1.0"" encoding=""utf-8""?>
				|<D:propertyupdate xmlns:D=""DAV:"" xmlns:U=""tsov.pro"">
				|  <D:set><D:prop>
				|    <U:UID1C>%1</U:UID1C>
				|  </D:prop></D:set>
				|</D:propertyupdate>";
	XMLQuery = StringFunctionsClientServer.SubstituteParametersToString(XMLQuery, UID1C);
	
	Return PerformWebdavMethod("PROPPATCH", Href, HTTPTitles, SynchronizationParameters, XMLQuery);
	
EndFunction

// Reads the unique service attribute of the file on the webdav server.
Function GetUID1C(Href, SynchronizationParameters)

	HTTPTitles                 = New Map;
	HTTPTitles["User-Agent"]   = "1C Enterprise 8.3";
	HTTPTitles["Content-type"] = "text/xml";
	HTTPTitles["Accept"]       = "text/xml";
	HTTPTitles["Depth"]        = "0";
	
	Result = PerformWebdavMethod("PROPFIND",Href,HTTPTitles,SynchronizationParameters,
					"<?xml version=""1.0"" encoding=""utf-8""?>
					|<D:propfind xmlns:D=""DAV:"" xmlns:U=""tsov.pro""><D:prop>
					|<U:UID1C />
					|</D:prop></D:propfind>");
	
	If Result.Success Then
		XmlContext = DefineXMLContext(SynchronizationParameters.Response.GetBodyAsString());
		
		FoundEtag = CalculateXPath("//*[local-name()='propstat'][contains(./*[local-name()='status'],'200 OK')]/*[local-name()='prop']/*[local-name()='UID1C']",XmlContext).IterateNext();
		If FoundEtag <> Undefined Then
			Return FoundEtag.TextContent;
		EndIf;
	Else
		WriteToEventLogOfFilesSynchronization(Result.ErrorText, SynchronizationParameters.Account, EventLogLevel.Error);
	EndIf;
	
	Return "";

EndFunction

// Checks if the webdav server supports user properties for the file.
Function CheckUID1CAbility(Href, UID1C, SynchronizationParameters)
	
	UpdateFileUID1C(Href, UID1C, SynchronizationParameters);
	Return ValueIsFilled(GetUID1C(Href, SynchronizationParameters));
	
EndFunction

// Runs MCKOL on the webdav server.
Function CallMKCOLMethod(Href, SynchronizationParameters)

	HTTPTitles               = New Map;
	HTTPTitles["User-Agent"] = "1C Enterprise 8.3";
	Return PerformWebdavMethod("MKCOL", Href, HTTPTitles, SynchronizationParameters);

EndFunction

// Runs DELETE on the webdav server.
Function CallDELETEMethod(Href, SynchronizationParameters)
	
	HrefWithoutSlash = EndWithoutSlash(Href);
	HTTPTitles               = New Map;
	HTTPTitles["User-Agent"] = "1C Enterprise 8.3";
	Return PerformWebdavMethod("DELETE", HrefWithoutSlash, HTTPTitles, SynchronizationParameters);
	
EndFunction

// Receives Etag of the file on the server.
Function GetEtag(Href, SynchronizationParameters)
	
	HTTPTitles                 = New Map;
	HTTPTitles["User-Agent"]   = "1C Enterprise 8.3";
	HTTPTitles["Content-type"] = "text/xml";
	HTTPTitles["Accept"]       = "text/xml";
	HTTPTitles["Depth"]        = "0";
	
	Result = PerformWebdavMethod("PROPFIND",Href,HTTPTitles,SynchronizationParameters,
					"<?xml version=""1.0"" encoding=""utf-8""?>
					|<D:propfind xmlns:D=""DAV:""><D:prop>
					|<D:getetag />
					|</D:prop></D:propfind>");
	
	If Result.Success Then
		
		XmlContext = DefineXMLContext(SynchronizationParameters.Response.GetBodyAsString());
		
		FoundEtag = CalculateXPath("//*[local-name()='propstat'][contains(./*[local-name()='status'],'200 OK')]/*[local-name()='prop']/*[local-name()='getetag']",XmlContext).IterateNext();
		
		If FoundEtag <> Undefined Then
			Return FoundEtag.TextContent;
		EndIf;
	
	Else
		WriteToEventLogOfFilesSynchronization(Result.ErrorText, SynchronizationParameters.Account, EventLogLevel.Error);
	EndIf;
	
	Return "";
	
EndFunction

// Initializes the HTTPConnection object.
Function CreateHTTPConnectionWebdav(HrefStructure, SynchronizationParameters, Timeout)
	
	InternetProxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClientServer = Common.CommonModule("GetFilesFromInternetClientServer");
		InternetProxy = ModuleNetworkDownloadClientServer.GetProxy("https");
	EndIf;
	
	SecureConnection = Undefined;
	If HrefStructure.Schema = "https" Then 
		SecureConnection = CommonClientServer.NewSecureConnection();
	EndIf;
	
	If Not ValueIsFilled(HrefStructure.Port) Then
		HTTP = New HTTPConnection(
			HrefStructure.Host,
			,
			SynchronizationParameters.Username,
			SynchronizationParameters.Password,
			InternetProxy,
			Timeout,
			SecureConnection);
	Else
		HTTP = New HTTPConnection(
			HrefStructure.Host,
			HrefStructure.Port,
			SynchronizationParameters.Username,
			SynchronizationParameters.Password,
			InternetProxy,
			Timeout,
			SecureConnection);
	EndIf;
	
	Return HTTP;
	
EndFunction

// Calls the GET method at the webdav server and returns the imported file address in the temporary storage.
Function CallGETMethod(Href, Etag, SynchronizationParameters, FileModificationDate = Undefined, FileLength = Undefined)

	Result = New Structure("Success, TempDataAddress, ErrorText");
	HrefStructure = URIStructureDecoded(Href);
	
	Timeout = ?(FileLength <> Undefined, CalculateTimeout(FileLength), 43200);
	HTTP = CreateHTTPConnectionWebdav(HrefStructure, SynchronizationParameters, Timeout);
	
	HTTPTitles               = New Map;
	HTTPTitles["User-Agent"] = "1C Enterprise 8.3";
	HTTPTitles["Accept"]     = "application/octet-stream";
	
	HTTPWebdavQuery = New HTTPRequest(HrefStructure.PathAtServer, HTTPTitles);
	
	SynchronizationParameters.Response = HTTP.Get(HTTPWebdavQuery);
	
	Result = CheckHTTP1CException(SynchronizationParameters.Response, Href);
	If NOT Result.Success Then
		Return Result;
	EndIf;
	
	FileWithBinaryData = SynchronizationParameters.Response.GetBodyAsBinaryData();
	
	Etag = ?(SynchronizationParameters.Response.Headers["ETag"] = Undefined, "", SynchronizationParameters.Response.Headers["ETag"]);
	FileModificationDate = ?(SynchronizationParameters.Response.Headers["Last-Modified"] = Undefined,CurrentUniversalDate(),RFC1123Date(SynchronizationParameters.Response.Headers["Last-Modified"]));
	FileLength = FileWithBinaryData.Size();
	
	TempDataAddress = PutToTempStorage(FileWithBinaryData);
	
	Result.Insert("ImportedFileAddress", TempDataAddress);
	Return Result;

EndFunction

// Places the file on the webdav server using the PUT method and returns the assigned etag to a variable.
Function CallPUTMethod(Href, FileRef, SynchronizationParameters, IsFile)
	
	FileWithBinaryData = FilesOperations.FileBinaryData(FileRef);
	
	HrefStructure = URIStructureDecoded(Href);
	
	Timeout = CalculateTimeout(FileWithBinaryData.Size());
	HTTP = CreateHTTPConnectionWebdav(HrefStructure, SynchronizationParameters, Timeout);
	
	HTTPTitles = New Map;
	HTTPTitles["User-Agent"]   = "1C Enterprise 8.3";
	HTTPTitles["Content-Type"] = "application/octet-stream";
	
	HTTPWebdavQuery = New HTTPRequest(HrefStructure.PathAtServer, HTTPTitles);
	
	HTTPWebdavQuery.SetBodyFromBinaryData(FileWithBinaryData);
	
	SynchronizationParameters.Response = HTTP.Put(HTTPWebdavQuery);
	
	CheckHTTP1CException(SynchronizationParameters.Response, Href);
	
	Return GetEtag(Href,SynchronizationParameters);
	
EndFunction

// Imports file from server, creating a new version.
Function ImportFileFromServer(FileParameters, IsFile = Undefined)
	
	FileName                 = FileParameters.FileName;
	Href                     = FileParameters.Href;
	Etag                     = FileParameters.Etag;
	FileModificationDate     = FileParameters.FileModificationDate;
	FileLength               = FileParameters.FileLength;
	ForUser          = FileParameters.ForUser;
	OwnerObject           = FileParameters.OwnerObject;
	ExistingFileRef = FileParameters.ExistingFileRef;
	SynchronizationParameters   = FileParameters.SynchronizationParameters;
	
	
	EventText = NStr("ru = 'Загрузка файла с сервера: %1'; en = 'Import file from server: %1'; pl = 'Pobieranie pliku z serwera: %1';es_ES = 'Descargo del archivo del servidor: %1';es_CO = 'Descargo del archivo del servidor: %1';tr = 'Dosyanın sunucudan içe aktarılması: %1';it = 'Importare file da server: %1';de = 'Datei vom Server herunterladen: %1'");
	
	WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, FileParameters.FileName), SynchronizationParameters.Account);
	
	ImportResult = CallGETMethod(Href, Etag, SynchronizationParameters, FileModificationDate, FileLength);
	
	If IsFile = Undefined Then
		IsFile = IsFilesOwner(FileParameters.OwnerObject);
	EndIf;
	
	If ImportResult.Success AND ImportResult.ImportedFileAddress <> Undefined Then
		
		ImportedFileAddress = ImportResult.ImportedFileAddress;
		
		FileNameStructure = New File(FileParameters.FileName);
		
		If ExistingFileRef = Undefined Then
			
			FileToAddParameters = New Structure;
			
			If StrStartsWith(OwnerObject.Metadata().FullName(), "Catalog") AND OwnerObject.IsFolder Then
				FileToAddParameters.Insert("GroupOfFiles", OwnerObject);
				FileOwner = OwnerObject.FileOwner;
			Else
				FileOwner = OwnerObject;
			EndIf;
			
			FileToAddParameters.Insert("FilesOwner", FileOwner);
			
			FileToAddParameters.Insert("Author", SynchronizationParameters.FilesAuthor);
			FileToAddParameters.Insert("BaseName", FileNameStructure.BaseName);
			FileToAddParameters.Insert("ExtensionWithoutPoint", CommonClientServer.ExtensionWithoutPoint(FileNameStructure.Extension));
			FileToAddParameters.Insert("Modified", ToLocalTime(FileModificationDate, SessionTimeZone()));
			FileToAddParameters.Insert("ModificationTimeUniversal", FileModificationDate);
			
			NewFile = FilesOperations.AppendFile(FileToAddParameters, ImportedFileAddress);
			
			LockFileForEditingServer(NewFile, SynchronizationParameters.FilesAuthor);
			
		Else
			
			Mode = ?(ExistingFileRef.StoreVersions, "FileWithVersion", "File");
			FileInfo = FilesOperationsClientServer.FileInfo(Mode);
			
			FileInfo.BaseName              = FileNameStructure.BaseName;
			FileInfo.TempFileStorageAddress = ImportedFileAddress;
			FileInfo.ExtensionWithoutPoint            = CommonClientServer.ExtensionWithoutPoint(FileNameStructure.Extension);	
			FileInfo.ModificationTimeUniversal   = FileModificationDate;
			
			If FileInfo.StoreVersions Then
				FileInfo.NewVersionAuthor          = SynchronizationParameters.FilesAuthor;
			EndIf;
			
			Result = FilesOperationsInternalServerCall.SaveFileChanges(ExistingFileRef, FileInfo, True, "", "", False);
			
			NewFile = ExistingFileRef;
			
		EndIf;
		
		UID1CFile = String(NewFile.Ref.UUID());
		UpdateFileUID1C(Href, UID1CFile, SynchronizationParameters);
		
		RememberRefServerData(NewFile.Ref, Href, Etag, IsFile, OwnerObject, False, SynchronizationParameters.Account);
		
		MessageText = NStr("ru = 'Загружен файл из облачного сервиса: ""%1""'; en = 'File is imported from the cloud service: ""%1""'; pl = 'Pobrany plik z usługi w chmurze: ""%1""';es_ES = 'Archivo descargado del servicio de nube: ""%1""';es_CO = 'Archivo descargado del servicio de nube: ""%1""';tr = 'Bulut hizmetinden dosya yüklendi: ""%1""';it = 'Il file è stato importato dal servizio cloud: ""%1""';de = 'Datei, die vom Cloud-Service heruntergeladen wurde: ""%1"".'");
		StatusForEventLog = EventLogLevel.Information;
	Else
		MessageText = NStr("ru = 'Не удалось загрузить файл ""%1"" из облачного сервиса по причине:'; en = 'Cannot import the ""%1"" file from the cloud service due to:'; pl = 'Nie udało się pobrać pliku ""%1"" z usługi w chmurze z powodu:';es_ES = 'No se ha podido descargar el archivo ""%1"" del servicio de nube a causa de:';es_CO = 'No se ha podido descargar el archivo ""%1"" del servicio de nube a causa de:';tr = 'Dosya ""%1"" aşağıdaki nedenle bulut hizmetinden içe aktarılamadı:';it = 'Impossibile importare il file ""%1"" dal servizio cloud a causa di:';de = 'Der Download der Datei ""%1"" aus dem Cloud-Service konnte aus folgendem Grund nicht durchgeführt werden:'") + " " + Chars.LF + ImportResult.ErrorText;
		StatusForEventLog = EventLogLevel.Error;
	EndIf;
	
	WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(MessageText, FileName), SynchronizationParameters.Account, StatusForEventLog);
	
	Return NewFile;

EndFunction

// Writes an event into an event log.
Procedure WriteToEventLogOfFilesSynchronization(MessageText, Account, EventLogLevelToSet = Undefined)

	If EventLogLevelToSet = Undefined Then
		EventLogLevelToSet = EventLogLevel.Information;
	EndIf;

	WriteLogEvent(FilesOperationsClientServer.EventLogEventSynchronization(),
					EventLogLevelToSet,,
					Account,
					MessageText);
	
EndProcedure

// Returns date transformed to the Date type from the RFC 1123 format.
Function RFC1123Date(HTTPDateAsString)

	MonthsNames = "janfebmaraprmayjunjulaugsepoctnovdec";
	// rfc1123-date = wkday "," SP date1 SP time SP "GMT".
	FirstSpacePosition = StrFind(HTTPDateAsString, " ");//date comes from the first space to the second space.
	SubstringDate = Mid(HTTPDateAsString,FirstSpacePosition + 1);
	SubstringTime = Mid(SubstringDate, 13);
	SubstringDate = Left(SubstringDate, 11);
	FirstSpacePosition = StrFind(SubstringTime, " ");
	SubstringTime = Left(SubstringTime,FirstSpacePosition - 1);
	// date1 = 2DIGIT SP month SP 4DIGIT.
	SubstringDay = Left(SubstringDate, 2);
	SubstringMonth = Format(Int(StrFind(MonthsNames,Lower(Mid(SubstringDate,4,3))) / 3)+1, "ND=2; NZ=00; NLZ=");
	SubstringYear = Mid(SubstringDate, 8);
	// time = 2DIGIT ":" 2DIGIT ":" 2DIGIT.
	SubstringHour = Left(SubstringTime, 2);
	SubstringMinute = Mid(SubstringTime, 4, 2);
	SubstringSecond = Right(SubstringTime, 2);
	
	Return Date(SubstringYear + SubstringMonth + SubstringDay + SubstringHour + SubstringMinute + SubstringSecond);
	
EndFunction

// Reads basic status of the directory on the server. Used to check the connection.
Procedure ReadDirectoryParameters(CheckResult, HttpAddress, ExchangeStructure)

	HTTPAddressStructure = URIStructureDecoded(HttpAddress);
	ServerAddress = EncodeURIByStructure(HTTPAddressStructure);
	
	Try
		// receiving the directory
		HTTPTitles = New Map;
		HTTPTitles["User-Agent"]   = "1C Enterprise 8.3";
		HTTPTitles["Content-type"] = "text/xml";
		HTTPTitles["Accept"]       = "text/xml";
		HTTPTitles["Depth"]        = "0";
		
		Result = PerformWebdavMethod("PROPFIND", ServerAddress, HTTPTitles, ExchangeStructure,
						"<?xml version=""1.0"" encoding=""utf-8""?>
						|<D:propfind xmlns:D=""DAV:"" xmlns:U=""tsov.pro""><D:prop>
						|<D:quota-used-bytes /><D:quota-available-bytes />
						|</D:prop></D:propfind>"
						, CheckResult.ResultProtocol);
		
		If Result.Success = False Then
			WriteToEventLogOfFilesSynchronization(Result.ErrorText, ExchangeStructure.Account, EventLogLevel.Error);
			Return;
		EndIf;
		
		XMLDocumentContext = DefineXMLContext(ExchangeStructure.Response.GetBodyAsString());
		
		XPathResult = CalculateXPath("//*[local-name()='response']",XMLDocumentContext);
		
		FoundResponse = XPathResult.IterateNext();
		
		While FoundResponse <> Undefined Do
			
			FoundPropstat = CalculateXPath("./*[local-name()='propstat'][contains(./*[local-name()='status'],'200 OK')]/*[local-name()='prop']", XMLDocumentContext, FoundResponse).IterateNext();
			
			If FoundPropstat<>Undefined Then
				For each PropstatChildNode In FoundPropstat.ChildNodes Do
					If PropstatChildNode.LocalName = "quota-available-bytes" Then
						Try
							SizeInMegabytes = Round(Number(PropstatChildNode.TextContent)/1024/1024, 1);
						Except
							SizeInMegabytes = 0;
						EndTry;
						
						FreeSpaceInformation = NStr("ru = 'Свободное место : %1 Мб'; en = 'Free space : %1 MB'; pl = 'Wolna przestrzeń : %1 MB';es_ES = 'Espacio libre: %1 Mb';es_CO = 'Espacio libre: %1 Mb';tr = 'Boş yer: %1 MB';it = 'Spazio libero: %1 MB';de = 'Freier Platz: %1 MB'");
						
						CheckResult.ResultText = CheckResult.ResultText + ?(IsBlankString(CheckResult.ResultText), "", Chars.LF)
							+ StringFunctionsClientServer.SubstituteParametersToString(FreeSpaceInformation, SizeInMegabytes);
					ElsIf PropstatChildNode.LocalName = "quota-used-bytes" Then
						Try
							SizeInMegabytes = Round(Number(PropstatChildNode.TextContent)/1024/1024, 1);
						Except
							SizeInMegabytes = 0;
						EndTry;
						
						OccupiedSpaceInformation = NStr("ru = 'Занято : %1 Мб'; en = 'Occupied : %1 MB'; pl = 'Zajęta przestrzeń : %1 MB';es_ES = 'Ocupado: %1 Mb';es_CO = 'Ocupado: %1 Mb';tr = 'Dolu: %1 MB';it = 'Utilizzato : %1 Mb';de = 'Belegt: %1 MB'");
						
						CheckResult.ResultText = CheckResult.ResultText + ?(IsBlankString(CheckResult.ResultText), "", Chars.LF)
							+ StringFunctionsClientServer.SubstituteParametersToString(OccupiedSpaceInformation, SizeInMegabytes);
					EndIf; 
				EndDo; 
			EndIf; 
			
			FoundResponse = XPathResult.IterateNext();
			
		EndDo;
	
	Except
		ErrorDescription = ErrorDescription();
		CheckResult.ResultText = CheckResult.ResultText + ?(IsBlankString(CheckResult.ResultText), "", Chars.LF) + ErrorDescription;
		WriteToEventLogOfFilesSynchronization(ErrorDescription, ExchangeStructure.Account, EventLogLevel.Error);
		Cancel = True;
		CheckResult.Cancel = True;
	EndTry; 
	
EndProcedure

// Returns URI structure
Function URIStructureDecoded(Val URIString)
	
	URIString = TrimAll(URIString);
	
	// Schema
	Schema = "";
	Position = StrFind(URIString, "://");
	If Position > 0 Then
		Schema = Lower(Left(URIString, Position - 1));
		URIString = Mid(URIString, Position + 3);
	EndIf;

	// Connection string and path on the server.
	ConnectionString = URIString;
	PathAtServer = "";
	Position = StrFind(ConnectionString, "/");
	If Position > 0 Then
		// First slash included
		PathAtServer = Mid(ConnectionString, Position);
		ConnectionString = Left(ConnectionString, Position - 1);
	EndIf;
		
	// User details and server name.
	AuthorizationString = "";
	ServerName = ConnectionString;
	Position = StrFind(ConnectionString, "@");
	If Position > 0 Then
		AuthorizationString = Left(ConnectionString, Position - 1);
		ServerName = Mid(ConnectionString, Position + 1);
	EndIf;
	
	// Username and password.
	Username = AuthorizationString;
	Password = "";
	Position = StrFind(AuthorizationString, ":");
	If Position > 0 Then
		Username = Left(AuthorizationString, Position - 1);
		Password = Mid(AuthorizationString, Position + 1);
	EndIf;
	
	// The host and port.
	Host = ServerName;
	Port = "";
	Position = StrFind(ServerName, ":");
	If Position > 0 Then
		Host = Left(ServerName, Position - 1);
		Port = Mid(ServerName, Position + 1);
	EndIf;
	
	Result = New Structure;
	Result.Insert("Schema", Lower(Schema));
	Result.Insert("Username", Username);
	Result.Insert("Password", Password);
	Result.Insert("ServerName", Lower(ServerName));
	Result.Insert("Host", Lower(Host));
	Result.Insert("Port", ?(IsBlankString(Port), Undefined, Number(Port)));
	Result.Insert("PathAtServer", DecodeString(EndWithoutSlash(PathAtServer),StringEncodingMethod.URLInURLEncoding)); 
	
	// A path on the server will always have the first but not the last slash, it is universal for files and folders.
	Return Result; 
	
EndFunction

// Returns URI, composed from a structure.
Function EncodeURIByStructure(Val URIStructure, IncludingPathAtServer = True)
	Result = "";
	
	// Protocol
	If Not IsBlankString(URIStructure.Schema) Then
		Result = Result + URIStructure.Schema + "://";
	EndIf;
	
	// Authorization
	If Not IsBlankString(URIStructure.Username) Then
		Result = Result + URIStructure.Username + ":" + URIStructure.Password + "@";
	EndIf;
		
	// Everything else
	Result = Result + URIStructure.Host;
	If ValueIsFilled(URIStructure.Port) Then
		Result = Result + ":" + ?(TypeOf(URIStructure.Port) = Type("Number"), Format(URIStructure.Port, "NG=0"), URIStructure.Port);
	EndIf;
	
	Result = Result + ?(IncludingPathAtServer, EndWithoutSlash(URIStructure.PathAtServer), "");
	
	// Always without the final slash
	Return Result; 
	
EndFunction

// Returns a string that is guaranteed to begin with a forward slash.
Function StartWithSlash(Val InitialString)
	Return ?(Left(InitialString,1)="/", InitialString, "/"+InitialString);
EndFunction 

// Returns a string that is guaranteed to end without a forward slash.
Function EndWithoutSlash(Val InitialString)
	Return ?(Right(InitialString,1)="/", Left(InitialString, StrLen(InitialString)-1), InitialString);
EndFunction

// Returns the result of comparing the tow URI paths, regardless of having the starting and final 
// forward slash, encoding of special characters, as well as the server address.
Function IsIdenticalURIPaths(URI1, URI2, SensitiveToRegister = True)
	
	// Ensures identity regardless of slashes and encoding.
	URI1Structure = URIStructureDecoded(URI1); 
	URI2Structure = URIStructureDecoded(URI2);
	If NOT SensitiveToRegister Then
		URI1Structure.PathAtServer = Lower(URI1Structure.PathAtServer);
		URI2Structure.PathAtServer = Lower(URI2Structure.PathAtServer);
	EndIf; 
	
	Return EncodeURIByStructure(URI1Structure,True) = EncodeURIByStructure(URI2Structure,True);
	
EndFunction

// Returns the file name according to Href.
Function FileNameByHref(Href)

	URI = EndWithoutSlash(Href);
	URILength = StrLen(URI);
	
	// Finding the last slash, after it the file name is located.
	
	For Cnt = 1 To URILength Do
		URISymbol = Mid(URI,URILength - Cnt + 1, 1);
		If URISymbol = "/" Then
			Return DecodeString(Mid(URI,URILength - Cnt + 2), StringEncodingMethod.URLEncoding);
		EndIf;
	EndDo;
	
	Return DecodeString(URI,StringEncodingMethod.URLEncoding);

EndFunction

// Saves data about Href and Etag of a file or folder to the database.
Procedure RememberRefServerData(
		Ref,
		Href,
		Etag,
		IsFile,
		FileOwner,
		IsFolder,
		Account = Undefined)

	RegisterRecord = InformationRegisters.FilesSynchronizationWithCloudServiceStatuses.CreateRecordManager();
	RegisterRecord.File                        = Ref;
	RegisterRecord.Href                        = Href;
	RegisterRecord.Etag                        = Etag;
	RegisterRecord.UUID1C   = ?(TypeOf(Ref) = Type("String"), "", Ref.UUID());
	RegisterRecord.IsFile                     = IsFile;
	RegisterRecord.IsFileOwner            = IsFolder;
	RegisterRecord.FileOwner               = FileOwner;
	RegisterRecord.Account               = Account;
	RegisterRecord.Synchronized             = False;
	RegisterRecord.SynchronizationDateStart     = CurrentSessionDate();
	RegisterRecord.SynchronizationDateCompletion = CurrentSessionDate() + 1800; // 30 minutes
	RegisterRecord.SessionNumber                 = InfoBaseSessionNumber();
	RegisterRecord.Write(True);
	
EndProcedure

// Saves data about Href and Etag of a file or folder to the database.
Procedure SetSynchronizationStatus(FileInfo, Account = Undefined)

	RegisterRecord = InformationRegisters.FilesSynchronizationWithCloudServiceStatuses.CreateRecordManager();
	RegisterRecord.File                        = FileInfo.FileRef;
	RegisterRecord.Href                        = FileInfo.ToHref;
	RegisterRecord.Etag                        = FileInfo.ToEtag;
	RegisterRecord.UUID1C   = FileInfo.FileRef.UUID();
	RegisterRecord.IsFile                     = FileInfo.IsFile;
	RegisterRecord.IsFileOwner            = FileInfo.IsFolder;
	RegisterRecord.FileOwner               = FileInfo.Parent;
	RegisterRecord.Synchronized             = FileInfo.Processed;
	RegisterRecord.SynchronizationDateStart     = CurrentSessionDate();
	RegisterRecord.SynchronizationDateCompletion = CurrentSessionDate();
	RegisterRecord.SessionNumber                 = InfoBaseSessionNumber();
	
	RegisterRecord.Account               = Account;
	
	RegisterRecord.Write(True);
	
EndProcedure

// Deletes data about Href and Etag of a file or folder to the database.
Procedure DeleteRefServerData(Ref, Account)

	RegisterSet = InformationRegisters.FilesSynchronizationWithCloudServiceStatuses.CreateRecordSet();
	RegisterSet.Filter.File.Set(Ref);
	RegisterSet.Filter.Account.Set(Account);
	RegisterSet.Write(True);

EndProcedure

// Defines xml context
Function DefineXMLContext(XMLText)
	
	ReadXMLText = New XMLReader;
	ReadXMLText.SetString(XMLText);
	DOMBuilderForXML = New DOMBuilder;
	DocumentDOMForXML = DOMBuilderForXML.Read(ReadXMLText);
	NamesResolverForXML = New DOMNamespaceResolver(DocumentDOMForXML);
	Return New Structure("DOMDocument,DOMDereferencer", DocumentDOMForXML, NamesResolverForXML); 
	
EndFunction

// Calculates xpath expression for xml context.
Function CalculateXPath(Expression, Context, ContextNode = Undefined)
	
	Return Context.DOMDocument.EvaluateXPathExpression(Expression,?(ContextNode=Undefined,Context.DOMDocument,ContextNode),Context.DOMDereferencer);
	
EndFunction

// Returns Href, calculated for a row from a file table by the search of all parents method.
Function CalculateHref(FilesRow,FilesTable)
	// Recursively collecting descriptions.
	FilesRowsFound = FilesTable.Find(FilesRow.Parent,"FileRef");
	If FilesRowsFound = Undefined Then
		Return ?(ValueIsFilled(FilesRow.Description), FilesRow.Description +"/","");
	Else
		Return CalculateHref(FilesRowsFound,FilesTable) + FilesRow.Description +"/";
	EndIf; 
EndFunction

// Returns a file table row by URI, while considering the possible different spelling of URI (for 
// example, encoded, relative or absolute, and so on).
Function FindRowByURI(SoughtURI, TableWithURI, URIColumn)

	For each TableRow In TableWithURI Do
		If IsIdenticalURIPaths(SoughtURI,TableRow[URIColumn]) Then
			Return TableRow;
		EndIf; 
	EndDo; 
	
	Return Undefined;
	
EndFunction

// The level of the file row is calculated by a recursive algorithm.
Function LevelRecursively(FilesRow,FilesTable)
	
	// Equals to the level in the database or on the server, depending on where it is less.
	FilesRowsFound = FilesTable.FindRows(New Structure("FileRef", FilesRow.Parent));
	AdditionCount = ?(FilesRowsFound.Count() = 0, 0, 1);
	For each FilesRowFound In FilesRowsFound Do
		AdditionCount = AdditionCount + LevelRecursively(FilesRowFound,FilesTable);
	EndDo;
	
	Return AdditionCount;
	
EndFunction

// The file level on the webdav server is calculated using a recursive algorithm.
Function RecursivelyLevelAtServer(FilesRow,FilesTable) 
	
	FilesRowsFound = FilesTable.FindRows(New Structure("FileRef", FilesRow.ParentServer));
	AdditionCount = ?(FilesRowsFound.Count() = 0, 0, 1);
	For each FilesRowFound In FilesRowsFound Do
		AdditionCount = AdditionCount + RecursivelyLevelAtServer(FilesRowFound, FilesTable);
	EndDo;
	
	Return AdditionCount;
	
EndFunction

// Calculates the levels of all rows in the file table.
Procedure CalculateLevelRecursively(FilesTable)
	FilesTable.Indexes.Add("FileRef");
	For each FilesRow In FilesTable Do
		
		If NOT ValueIsFilled(FilesRow.FileRef) Then
			Continue;
		EndIf;
		
		// Equals to the level in the database or on the server, depending on where it is less.
		LevelInBase    = LevelRecursively(FilesRow, FilesTable);
		LevelAtServer = RecursivelyLevelAtServer(FilesRow, FilesTable);
		If LevelAtServer = 0 Then
			FilesRow.Level            = LevelInBase;
			FilesRow.ParentOrdering = FilesRow.Parent;
		Else
			If LevelInBase <= LevelAtServer Then
				FilesRow.Level            = LevelInBase;
				FilesRow.ParentOrdering = FilesRow.Parent;
			Else
				FilesRow.Level            = LevelAtServer;
				FilesRow.ParentOrdering = FilesRow.ParentServer;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// When changing the server path to folder, you must replace the paths to the subordinate files, which is what this procedure does.
Procedure RecursivelyRefreshSUbordinateItemsRefs(FilesRow,val ToHref,val ToHref2,FilesTable)

	// Changing the root reference, it always has to be encoded.
	FilesRow.ToHref = StrReplace(
							DecodeString(EndWithoutSlash(FilesRow.ToHref), StringEncodingMethod.URLInURLEncoding),
							DecodeString(EndWithoutSlash(ToHref), StringEncodingMethod.URLInURLEncoding),
							DecodeString(EndWithoutSlash(ToHref2), StringEncodingMethod.URLInURLEncoding));
	
	FoundSubordinateRows = FilesTable.FindRows(New Structure("ParentServer", FilesRow.Ref));
	For each SubordinateRow In FoundSubordinateRows Do
		RecursivelyRefreshSUbordinateItemsRefs(SubordinateRow,ToHref,ToHref2,FilesTable);
	EndDo; 

EndProcedure

// Recursively imports the list of files from the server into the file table.
Procedure ImportFilesTreeRecursively(CurrentRowsOfFilesTree, HttpAddress, SynchronizationParameters, Cancel=False)

	HTTPAddressStructure   = URIStructureDecoded(HttpAddress);
	CloudServiceAddress = EncodeURIByStructure(HTTPAddressStructure, False);
	ServerAddress          = EncodeURIByStructure(HTTPAddressStructure);
	
	Try
		// Receiving the directory
		HTTPTitles = New Map;
		HTTPTitles["User-Agent"] = "1C Enterprise 8.3";
		HTTPTitles["Content-type"] = "text/xml";
		HTTPTitles["Accept"] = "text/xml";
		HTTPTitles["Depth"] = "1";
		
		Result = PerformWebdavMethod("PROPFIND", ServerAddress, HTTPTitles, SynchronizationParameters,
						"<?xml version=""1.0"" encoding=""utf-8""?>
						|<D:propfind xmlns:D=""DAV:"" xmlns:U=""tsov.pro""><D:prop>
						|<D:getetag /><U:UID1C /><D:resourcetype />
						|<D:getlastmodified /><D:getcontentlength />
						|</D:prop></D:propfind>");
		
		If Result.Success = False Then
			WriteToEventLogOfFilesSynchronization(ErrorDescription(), SynchronizationParameters.Account, EventLogLevel.Error);
			Return;
		EndIf;
		
		XMLDocumentContext = DefineXMLContext(SynchronizationParameters.Response.GetBodyAsString());
		
		XPathResult = CalculateXPath("//*[local-name()='response']", XMLDocumentContext);
		
		FoundResponse = XPathResult.IterateNext();
		
		While FoundResponse <> Undefined Do
			
			// There is always Href, otherwise, it is a critical error.
			FoundHref = CalculateXPath("./*[local-name()='href']", XMLDocumentContext, FoundResponse).IterateNext();
			If FoundHref = Undefined Then
				ErrorText = NStr("ru = 'Ошибка ответа от сервера: не найден HREF в %1'; en = 'An error occurred when receiving a server response: HREF is not found in %1'; pl = 'Błąd odpowiedzi od serwera: nie znaleziono HREF w %1';es_ES = 'Error de la respuesta del servidor: no encontrado HREF en %1';es_CO = 'Error de la respuesta del servidor: no encontrado HREF en %1';tr = 'Sunucudan yanıt hatası: %1''de HREF bulunamadı';it = 'Si è verificato un errore durante la ricezione di una risposta del server: HREF non trovato in %1';de = 'Serverantwortfehler: HREF nicht gefunden in %1'");
				Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorText, ServerAddress);
			EndIf; 
			
			HrefText = EndWithoutSlash(StartWithSlash(FoundHref.TextContent));
			
			If IsIdenticalURIPaths(CloudServiceAddress + HrefText, ServerAddress) Then
				FoundResponse = XPathResult.IterateNext();
				Continue;
			EndIf; 
			
			NewFilesTreeRow = CurrentRowsOfFilesTree.Add();
			// Always encoded
			NewFilesTreeRow.Href = CloudServiceAddress + HrefText;
			NewFilesTreeRow.FileName = FileNameByHref(NewFilesTreeRow.Href);
			NewFilesTreeRow.Etag = "";
			NewFilesTreeRow.UID1C = "";
			NewFilesTreeRow.IsFolder = Undefined;
			
			FoundPropstat = CalculateXPath("./*[local-name()='propstat'][contains(./*[local-name()='status'],'200 OK')]/*[local-name()='prop']", XMLDocumentContext, FoundResponse).IterateNext();
			
			If FoundPropstat <> Undefined Then
				For each PropstatChildNode In FoundPropstat.ChildNodes Do
					If PropstatChildNode.LocalName = "resourcetype" Then
						NewFilesTreeRow.IsFolder = CalculateXPath("./*[local-name()='collection']", XMLDocumentContext, PropstatChildNode).IterateNext() <> Undefined;
					ElsIf PropstatChildNode.LocalName = "UID1C" Then
						NewFilesTreeRow.UID1C = PropstatChildNode.TextContent;
					ElsIf PropstatChildNode.LocalName = "getetag" Then
						NewFilesTreeRow.Etag = PropstatChildNode.TextContent;
					ElsIf PropstatChildNode.LocalName = "getlastmodified" Then
						NewFilesTreeRow.ModificationDate = RFC1123Date(PropstatChildNode.TextContent);//UTC
					ElsIf PropstatChildNode.LocalName = "getcontentlength" Then
						NewFilesTreeRow.Length = Number(StrReplace(PropstatChildNode.TextContent," ",""));
					EndIf;
				EndDo;
			EndIf;
			
			// If there was no UID, we try to receive it separately, it is necessary, for example, for owncloud.
			If NOT ValueIsFilled(NewFilesTreeRow.UID1C) Then
				NewFilesTreeRow.UID1C = GetUID1C(NewFilesTreeRow.Href, SynchronizationParameters);
			EndIf;
			
			FoundResponse = XPathResult.IterateNext();
			
		EndDo;
	
	Except
		WriteToEventLogOfFilesSynchronization(ErrorDescription(), SynchronizationParameters.Account, EventLogLevel.Error);
		Cancel = True;
	EndTry;
	
	For each FilesTreeRow In CurrentRowsOfFilesTree Do
		If FilesTreeRow.IsFolder = True Then
			ImportFilesTreeRecursively(FilesTreeRow.Rows, FilesTreeRow.Href, SynchronizationParameters, Cancel);
		EndIf;
	EndDo;
	
EndProcedure

// Imports new folders and files from webdav server that are not yet in the database, and reflects them in the file table.
Procedure ImportNewAttachedFiles(FilesTreeRows, FilesTable, SynchronizationParameters, OwnerObject = Undefined)
	
	For each FilesTreeRow In FilesTreeRows Do
		
		If FilesTreeRow.IsFolder Then
			// The folder is determined first by UID1C if not found, by the old Href, since The UID can be lost 
			// when editing, and the new Href cannot be found in the base yet if the UID was lost when edited 
			// and the folder is moved to another folder (Href has changed), then it will be imported into the 
			// new folder card. Search by Href is justified, because it is unique for each folder on the file server.
			CurrentFilesFolder = Undefined;
			// Theoretically, you can also search files by Etag, but the question of duplicates will arise, therefore, do not look further.
			
			If Not IsBlankString(FilesTreeRow.UID1C) Then
			
				Query = New Query;
				Query.Text = 
					"SELECT TOP 1
					|	FilesSynchronizationWithCloudServiceStatuses.File AS Ref
					|FROM
					|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
					|WHERE
					|	FilesSynchronizationWithCloudServiceStatuses.UUID1C = &UUID1C";
					
				Query.SetParameter("UUID1C", New UUID(FilesTreeRow.UID1C));
				QueryResult = Query.Execute();
				
				DetailedRecordsSelection = QueryResult.Select();
				
				While DetailedRecordsSelection.Next() Do
					CurrentFilesFolder = DetailedRecordsSelection;
				EndDo;
				
			EndIf;
			
			If (CurrentFilesFolder = Undefined) AND (FilesTable.Find(FilesTreeRow.Href, "Href") = Undefined) Then
				// This is a new folder on the server. Import it, but first check the possibility of storing UID1C, 
				// and if it is not possible do not import the folder.
				
				If Not IsFilesFolder(OwnerObject) Then
					Continue;
				EndIf;
				
				If NOT CheckUID1CAbility(FilesTreeRow.Href, String(New UUID), SynchronizationParameters) Then
					EventText = NStr("ru = 'Невозможно сохранение дополнительных свойств файла, он не будет загружен: %1'; en = 'Cannot save additional file properties. The file will not be imported: %1'; pl = 'Nie można zapisać dodatkowych właściwości pliku, nie będzie on pobrany: %1';es_ES = 'Es imposible guardar las propiedades adicionales de los archivos, no será descargado: %1';es_CO = 'Es imposible guardar las propiedades adicionales de los archivos, no será descargado: %1';tr = 'Dosyanın ek özellikleri kaydedilemedi, dosya içe aktarılamaz: %1';it = 'Impossibile salvare proprietà aggiuntive di file. Il file non sarà importato: %1';de = 'Es ist nicht möglich, zusätzliche Dateieigenschaften zu speichern, sie werden nicht geladen: %1'");
					WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, FilesTreeRow.FileName), SynchronizationParameters.Account);
					Continue;
				EndIf;
				
				Try
					
					CurrentFilesFolder = FilesOperationsInternalServerCall.CreateFilesFolder(FilesTreeRow.FileName, OwnerObject, SynchronizationParameters.FilesAuthor);
					
					FilesTreeRow.UID1C = String(CurrentFilesFolder.UUID());
					UpdateFileUID1C(FilesTreeRow.Href, FilesTreeRow.UID1C, SynchronizationParameters);
					
					NewFilesTableRow                    = FilesTable.Add();
					NewFilesTableRow.FileRef         = CurrentFilesFolder;
					NewFilesTableRow.DeletionMark    = False;
					NewFilesTableRow.Parent           = OwnerObject;
					NewFilesTableRow.IsFolder           = True;
					NewFilesTableRow.UID1C              = FilesTreeRow.UID1C;
					NewFilesTableRow.InInfobase          = True;
					NewFilesTableRow.IsOnServer      = True;
					NewFilesTableRow.ModifiedAtServer   = False;
					NewFilesTableRow.Changes          = CurrentFilesFolder;
					NewFilesTableRow.Href               = "";
					NewFilesTableRow.Etag               = "";
					NewFilesTableRow.ToHref             = FilesTreeRow.Href;
					NewFilesTableRow.ToEtag             = FilesTreeRow.Etag;
					NewFilesTableRow.ParentServer     = OwnerObject;
					NewFilesTableRow.Description       = FilesTreeRow.FileName;
					NewFilesTableRow.ServerDescription = FilesTreeRow.FileName;
					NewFilesTableRow.Processed          = True;
					NewFilesTableRow.IsFile            = True;
					
					RememberRefServerData(
						NewFilesTableRow.FileRef,
						NewFilesTableRow.ToHref,
						NewFilesTableRow.ToEtag,
						NewFilesTableRow.IsFile,
						NewFilesTableRow.Parent,
						NewFilesTableRow.IsFolder,
						SynchronizationParameters.Account);
					
					EventText = NStr("ru = 'Загружена папка с сервера:  %1'; en = 'Folder from the server is imported: %1'; pl = 'Pobrano folder z serwera: %1';es_ES = 'Carpeta descargada del servidor: %1';es_CO = 'Carpeta descargada del servidor: %1';tr = 'Sunucudaki klasör içe aktarıldı: %1';it = 'Cartella importata dal server: %1';de = 'Ein Ordner wurde vom Server heruntergeladen: %1'");
					WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, NewFilesTableRow.ServerDescription), SynchronizationParameters.Account);
					
				Except
					WriteToEventLogOfFilesSynchronization(ErrorDescription() ,SynchronizationParameters.Account);
				EndTry;
				
			Else
				// Updating ToHref
				PreviousFIlesTableRow = FilesTable.Find(CurrentFilesFolder.Ref, "FileRef");
				If PreviousFIlesTableRow <> Undefined Then
					PreviousFIlesTableRow.ToHref             = FilesTreeRow.Href;
					PreviousFIlesTableRow.ToEtag             = FilesTreeRow.Etag;
					PreviousFIlesTableRow.ParentServer     = OwnerObject;
					PreviousFIlesTableRow.ServerDescription = FilesTreeRow.FileName;
					PreviousFIlesTableRow.IsOnServer      = True;
					PreviousFIlesTableRow.ModifiedAtServer   = NOT IsIdenticalURIPaths(PreviousFIlesTableRow.ToHref,PreviousFIlesTableRow.Href);
				EndIf;
			EndIf;
			
			// Now it is a parent for subordinate rows.
			ImportNewAttachedFiles(FilesTreeRow.Rows, FilesTable, SynchronizationParameters, CurrentFilesFolder.Ref);
			
		Else 
			// This is a file
			// The file is determined first by UID1C. If it is not found, by the old Href, since The UID can be 
			// lost when editing, and the new Href cannot be found in the base yet if the UID was lost when 
			// edited and the file is moved to another folder (Href has changed), then it will be imported into 
			// the new file card. Search by Href is justified, because it is unique for each file on the file server.
			
			// The file will be skipped because the user added it to an incorrect folder that has no owner.
			If OwnerObject = Undefined Or TypeOf(OwnerObject) = Type("CatalogRef.MetadataObjectIDs") Then
				Return;
			EndIf;
			
			CurrentFile = FindRowByURI(FilesTreeRow.Href, FilesTable, "Href");
			
			If (CurrentFile = Undefined) OR (FilesTable.Find(CurrentFile.FileRef ,"FileRef") = Undefined) Then
				// This is a new file on the server, importing it.
				If NOT CheckUID1CAbility(FilesTreeRow.Href, String(New UUID), SynchronizationParameters) Then
					EventText = NStr("ru = 'Невозможно сохранение дополнительных свойств файла, он не будет загружен: %1'; en = 'Cannot save additional file properties. The file will not be imported: %1'; pl = 'Nie można zapisać dodatkowych właściwości pliku, nie będzie on pobrany: %1';es_ES = 'Es imposible guardar las propiedades adicionales de los archivos, no será descargado: %1';es_CO = 'Es imposible guardar las propiedades adicionales de los archivos, no será descargado: %1';tr = 'Dosyanın ek özellikleri kaydedilemedi, dosya içe aktarılamaz: %1';it = 'Impossibile salvare proprietà aggiuntive di file. Il file non sarà importato: %1';de = 'Es ist nicht möglich, zusätzliche Dateieigenschaften zu speichern, sie werden nicht geladen: %1'");
					WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, FilesTreeRow.FileName), SynchronizationParameters.Account, EventLogLevel.Error);
					Continue;
				EndIf;
				
				Try
					
					FileParameters = New Structure;
					FileParameters.Insert("FileName",                 FilesTreeRow.FileName);
					FileParameters.Insert("Href",                     FilesTreeRow.Href);
					FileParameters.Insert("Etag",                     FilesTreeRow.Etag);
					FileParameters.Insert("FileModificationDate",     FilesTreeRow.ModificationDate);
					FileParameters.Insert("FileLength",               FilesTreeRow.Length);
					FileParameters.Insert("ForUser",          SynchronizationParameters.FilesAuthor);
					FileParameters.Insert("OwnerObject",           OwnerObject);
					FileParameters.Insert("ExistingFileRef", Undefined);
					FileParameters.Insert("SynchronizationParameters",   SynchronizationParameters);
					ExistingFileRef = ImportFileFromServer(FileParameters);
					
					FilesTreeRow.UID1C = String(ExistingFileRef.Ref.UUID());
					
					NewFilesTableRow                    = FilesTable.Add();
					NewFilesTableRow.FileRef         = ExistingFileRef;
					NewFilesTableRow.DeletionMark    = False;
					NewFilesTableRow.Parent           = OwnerObject;
					NewFilesTableRow.IsFolder           = False;
					NewFilesTableRow.UID1C              = FilesTreeRow.UID1C;
					NewFilesTableRow.InInfobase          = False;
					NewFilesTableRow.IsOnServer      = True;
					NewFilesTableRow.ModifiedAtServer   = False;
					NewFilesTableRow.Href               = "";
					NewFilesTableRow.Etag               = "";
					NewFilesTableRow.ToHref             = FilesTreeRow.Href;
					NewFilesTableRow.ToEtag             = FilesTreeRow.Etag;
					NewFilesTableRow.ParentServer     = OwnerObject;
					NewFilesTableRow.Description       = FilesTreeRow.FileName;
					NewFilesTableRow.ServerDescription = FilesTreeRow.FileName;
					NewFilesTableRow.Processed          = True;
					NewFilesTableRow.IsFile            = True;
					
				Except
					WriteToEventLogOfFilesSynchronization(ErrorDescription(), SynchronizationParameters.Account, EventLogLevel.Error);
				EndTry;
				
			Else
				// Updating ToHref
				PreviousFIlesTableRow                    = FilesTable.Find(CurrentFile.FileRef,"FileRef");
				PreviousFIlesTableRow.ToHref             = FilesTreeRow.Href;
				PreviousFIlesTableRow.ToEtag             = FilesTreeRow.Etag;
				PreviousFIlesTableRow.ParentServer     = OwnerObject;
				PreviousFIlesTableRow.ServerDescription = FilesTreeRow.FileName;
				PreviousFIlesTableRow.IsOnServer      = True;
				PreviousFIlesTableRow.ModifiedAtServer   = NOT IsIdenticalURIPaths(PreviousFIlesTableRow.ToHref, PreviousFIlesTableRow.Href);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillDataFromCloudService(FilesTreeRows, FilesTable, SynchronizationParameters, OwnerObject = Undefined)
	
	SubsystemFilesOPerationsExists = Common.SubsystemExists("StandardSubsystems.FilesOperations");
	
	For each FilesTreeRow In FilesTreeRows Do
		
		If FilesTreeRow.IsFolder = True Then //folders
			// The folder is determined first by UID1C if not found, by the old Href, since The UID can be lost 
			// when editing, and the new Href cannot be found in the base yet if the UID was lost when edited 
			// and the folder is moved to another folder (Href has changed), then it will be imported into the 
			// new folder card. Search by Href is justified, because it is unique for each folder on the file server.
			CurrentFilesFolder = Undefined;
			// Theoretically, you can also search files by Etag, but the question of duplicates will arise, therefore, do not look further.
			
			If Not IsBlankString(FilesTreeRow.UID1C) Then
			
				Query = New Query;
				Query.Text = 
					"SELECT
					|	FilesSynchronizationWithCloudServiceStatuses.File
					|FROM
					|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
					|WHERE
					|	FilesSynchronizationWithCloudServiceStatuses.UUID1C = &UUID1C";
					
				Query.SetParameter("UUID1C", New UUID(FilesTreeRow.UID1C));
				
				QueryResult = Query.Execute();
				
				DetailedRecordsSelection = QueryResult.Select();
				
				
				While DetailedRecordsSelection.Next() Do
					CurrentFilesFolder = DetailedRecordsSelection.File;
				EndDo;
				
			EndIf;
			
			If CurrentFilesFolder = Undefined Then
				CurrentFilesFolder = FindRowByURI(FilesTreeRow.Href, FilesTable, "Href");// can be marked for deletion, then it has no Href and it will not be found.
			EndIf; 
			
			If CurrentFilesFolder = Undefined OR FilesTable.Find(CurrentFilesFolder.Ref, "FileRef") = Undefined Then
				Continue;
			EndIf;
			
			If (CurrentFilesFolder <> Undefined) OR (FilesTable.Find(CurrentFilesFolder.Ref,"FileRef") <> Undefined) Then
				PreviousFIlesTableRow = FilesTable.Find(CurrentFilesFolder.Ref, "FileRef");
				
				PreviousFIlesTableRow.ToHref = FilesTreeRow.Href;
				PreviousFIlesTableRow.ToEtag = FilesTreeRow.Etag;
				PreviousFIlesTableRow.ParentServer = OwnerObject;
				PreviousFIlesTableRow.ServerDescription = FilesTreeRow.FileName;
				PreviousFIlesTableRow.IsOnServer = True;
				PreviousFIlesTableRow.ModifiedAtServer = NOT IsIdenticalURIPaths(PreviousFIlesTableRow.ToHref,PreviousFIlesTableRow.Href);
			EndIf; 
			// Now it is a parent for subordinate rows.
			FillDataFromCloudService(FilesTreeRow.Rows, FilesTable, SynchronizationParameters, CurrentFilesFolder.Ref);
			
		Else 
			// This is a file
			// The file is determined first by UID1C. If it is not found, by the old Href, since The UID can be 
			// lost when editing, and the new Href cannot be found in the base yet if the UID was lost when 
			// edited and the file is moved to another folder (Href has changed), then it will be imported into 
			// the new file card. Search by Href is justified, because it is unique for each file on the file server.
			
			CurrentFile = FindRowByURI(FilesTreeRow.Href, FilesTable, "Href");
			
			If (CurrentFile <> Undefined) AND (FilesTable.Find(CurrentFile.FileRef,"FileRef") <> Undefined) Then
				// Updating ToHref
				PreviousFIlesTableRow = FilesTable.Find(CurrentFile.FileRef,"FileRef");
				PreviousFIlesTableRow.ToHref = FilesTreeRow.Href;
				PreviousFIlesTableRow.ToEtag = FilesTreeRow.Etag;
				PreviousFIlesTableRow.ParentServer = OwnerObject;
				PreviousFIlesTableRow.ServerDescription = FilesTreeRow.FileName;
				PreviousFIlesTableRow.IsOnServer = True;
				PreviousFIlesTableRow.ModifiedAtServer = NOT IsIdenticalURIPaths(PreviousFIlesTableRow.ToHref,PreviousFIlesTableRow.Href);
			EndIf; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure

// Prepares an exchange structure containing values for the duration of the exchange session.
Function MainSynchronizationObjects(Account)

	ReturnStructure = New Structure("ServerAddressStructure, Response, Username, Password");
	Query = New Query;
	Query.Text = "SELECT
	               |	FileSynchronizationAccounts.Ref AS Account,
	               |	FileSynchronizationAccounts.Service AS ServerAddress,
	               |	FileSynchronizationAccounts.RootDirectory AS RootDirectory,
	               |	FileSynchronizationAccounts.FilesAuthor AS FilesAuthor
	               |FROM
	               |	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
	               |WHERE
	               |	FileSynchronizationAccounts.Ref = &Ref
	               |	AND FileSynchronizationAccounts.DeletionMark = FALSE";
	
	Query.SetParameter("Ref", Account);
	
	Result = Query.Execute().Unload();
	
	If Result.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	For each ResultColumn In Result.Columns Do
		ReturnStructure.Insert(ResultColumn.Name,Result[0][ResultColumn.Name]);
	EndDo; 
	
	If Not IsBlankString(ReturnStructure.RootDirectory) Then
		ReturnStructure.ServerAddress = ReturnStructure.ServerAddress + "/" + ReturnStructure.RootDirectory;
	EndIf;
	
	If IsBlankString(ReturnStructure.FilesAuthor) Then
		ReturnStructure.FilesAuthor = Account;
	EndIf;
	
	ReturnStructure.ServerAddressStructure = URIStructureDecoded(ReturnStructure.ServerAddress);
	
	SetPrivilegedMode(True);
	ReturnStructure.Username =  Common.ReadDataFromSecureStorage(Account, "Username");
	ReturnStructure.Password = Common.ReadDataFromSecureStorage(Account);
	SetPrivilegedMode(False);
	
	Return ReturnStructure;

EndFunction

Procedure SynchronizeFilesWithCloudService(Account)
	
	SynchronizationParameters = MainSynchronizationObjects(Account);
	
	If SynchronizationParameters = Undefined Then
		Return;
	EndIf;
	
	EventText = NStr("ru = 'Начало синхронизации файлов с облачным сервисом.'; en = 'Start of synchronization of files with cloud service.'; pl = 'Rozpocznij synchronizację plików z usługą w chmurze.';es_ES = 'Inicio de la sincronización de archivos con el servicio de nube.';es_CO = 'Inicio de la sincronización de archivos con el servicio de nube.';tr = 'Dosyaları bulut hizmeti ile eşleşme başlangıcı';it = 'Avvio sincronizzazione dei file con servizio cloud.';de = 'Starten Sie die Synchronisierung von Dateien mit dem Cloud-Service.'");
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);
	
	ExecuteFilesSynchronizationWithCloudService(SynchronizationParameters);
	
	EventText = NStr("ru = 'Завершена синхронизация файлов с облачным сервисом'; en = 'Synchronization of files with the cloud service is completed'; pl = 'Synchronizacja plików z usługą w chmurze została zakończona';es_ES = 'Sincronización de archivos con el servicio de nube terminada';es_CO = 'Sincronización de archivos con el servicio de nube terminada';tr = 'Dosyaları bulut hizmeti ile eşleşmesi tamamlanmıştır';it = 'Sincronizzazione dei file con servizio cloud completata';de = 'Die Synchronisation der Dateien mit dem Cloud-Service ist abgeschlossen.'");
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);

EndProcedure

Procedure ExecuteFilesSynchronizationWithCloudService(SynchronizationParameters)
	
	ServerFilesTree = GenerateStructureOfServerFilesTree();
	ServerAddress        = EncodeURIByStructure(SynchronizationParameters.ServerAddressStructure);
	
	Cancel = False;
	SynchronizationCompleted = True;
	
	// Root record about the synchronization start
	RememberRefServerData("", "", "", False, Undefined, False, SynchronizationParameters.Account);
	
	ImportFilesTreeRecursively(ServerFilesTree.Rows, ServerAddress, SynchronizationParameters, Cancel);
	
	If Cancel = True Then
		
		EventText = NStr("ru = 'Не удалось загрузить структуру файлов с сервера, синхронизация не выполнена.'; en = 'Cannot import file structure from the server. Synchronization did not occur.'; pl = 'Nie można załadować struktury plików z serwera, synchronizacja nie powiodła się.';es_ES = 'No se ha podido descargar la estructura de archivos del servidor, sincronización no realizada.';es_CO = 'No se ha podido descargar la estructura de archivos del servidor, sincronización no realizada.';tr = 'Dosyaların yapısı sunucudan içe aktarılamadı, eşleşme yapılmadı.';it = 'Impossibile importare la struttura di file dal server. Non si è verificata la sincronizzazione.';de = 'Die Dateistruktur konnte nicht vom Server geladen werden, die Synchronisation wird nicht durchgeführt.'");
		WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account, EventLogLevel.Error);
		Return;
		
	EndIf;
	
	// Comparing it with the file tree in the system, synchronization by UUID.
	FilesTable = SelectDataByRules(SynchronizationParameters.Account);
	
	For each TableRow In FilesTable Do
		TableRow.UID1C = String(TableRow.FileRef.UUID());
	EndDo;
	
	// Looping through the tree, importing and adding missing ones at the base to the table, and filling attributes from the server according to the old ones.
	ImportNewAttachedFiles(ServerFilesTree.Rows, FilesTable, SynchronizationParameters);
	
	CalculateLevelRecursively(FilesTable);
	FilesTable.Indexes.Add("FileRef");
	
	FilesTable.Sort("Level, ParentOrdering, IsFolder DESC");
	
	// Looping through the table and deciding what to do with files and folders.
	For Each TableRow In FilesTable Do
		
		If TableRow.Processed Then
			SetSynchronizationStatus(TableRow, SynchronizationParameters.Account);
			Continue;
		EndIf;
		
		UpdateFileSynchronizationStatus = False;
		
		CreatedNewInBase            = (NOT ValueIsFilled(TableRow.Href)) AND (NOT ValueIsFilled(TableRow.ToHref));
		
		ModifiedInBase                = ValueIsFilled(TableRow.Changes);// something has changed
		ModifiedContentAtServer = ValueIsFilled(TableRow.ToEtag) AND (TableRow.Etag <> TableRow.ToEtag);// content has changed
		ModifiedAtServer            = ModifiedContentAtServer OR TableRow.ModifiedAtServer;// name, subordination or content has changed
		
		DeletedInBase                 = TableRow.DeletionMark;
		DeletedAtServer             = ValueIsFilled(TableRow.Href) AND NOT ValueIsFilled(TableRow.ToHref);
		
		BeginTransaction();
		
		Try
			
			If CreatedNewInBase AND NOT DeletedInBase Then
				// Import file to the cloud server
				UpdateFileSynchronizationStatus = CreateFileInCloudService(ServerAddress, SynchronizationParameters, TableRow, FilesTable);
				
			ElsIf DeletedAtServer AND NOT DeletedInBase Then
				
				UpdateFileSynchronizationStatus = DeleteFileInCloudService(SynchronizationParameters, TableRow);
				
			ElsIf (ModifiedInBase OR ModifiedAtServer) AND NOT (DeletedInBase OR DeletedAtServer) Then
				
				If ModifiedAtServer AND NOT ModifiedInBase Then
					UpdateFileSynchronizationStatus = ModifyFileInCloudService(ModifiedContentAtServer, UpdateFileSynchronizationStatus, SynchronizationParameters, TableRow);
				EndIf;
				
			EndIf;
			
			If UpdateFileSynchronizationStatus Then
				// Writing updates to the information register of statuses.
				If TableRow.DeletionMark Then
					// Deleting the last Href not to identify it again.
					DeleteRefServerData(TableRow.FileRef,  SynchronizationParameters.Account);
				Else
					SetSynchronizationStatus(TableRow, SynchronizationParameters.Account);
				EndIf;
			EndIf;
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
			TableRow.SynchronizationDate = CurrentSessionDate();
			SetSynchronizationStatus(TableRow, SynchronizationParameters.Account);
			
			SynchronizationCompleted = False;
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Не удалось синхронизировать файл ""%1"" по причине:'; en = 'Cannot synchronize the ""%1"" file due to:'; pl = 'Nie udało się zsynchronizować pliku ""%1"" z powodu:';es_ES = 'No se ha podido sincronizar el archivo ""%1"" a causa de:';es_CO = 'No se ha podido sincronizar el archivo ""%1"" a causa de:';tr = 'Dosya ""%1"" aşağıdaki nedenle eşleşmedi:';it = 'Impossibile sincronizzare il file ""%1"" a causa di:';de = 'Die Datei ""%1"" konnte aus diesem Grund nicht synchronisiert werden:'"), String(TableRow.FileRef))
				+ Chars.LF + DetailErrorDescription(ErrorInfo());
			WriteToEventLogOfFilesSynchronization(ErrorText, SynchronizationParameters.Account, EventLogLevel.Error);
		EndTry;
		
	EndDo;
	
	WriteSynchronizationResult(SynchronizationParameters.Account, SynchronizationCompleted);
	
EndProcedure

Procedure WriteSynchronizationResult(Account, Val SynchronizationCompleted)
	
	RecordSet = InformationRegisters.FilesSynchronizationWithCloudServiceStatuses.CreateRecordSet();
	RecordSet.Filter.File.Set("", True);
	RecordSet.Filter.Account.Set(Account, True);
	RecordSet.Read();
	If RecordSet.Count() > 0 Then
		Record                             = RecordSet.Get(0);
		Record.SynchronizationDateCompletion = CurrentSessionDate();
		Record.Synchronized             = SynchronizationCompleted;
		RecordSet.Write();
	EndIf;

EndProcedure

Function GenerateStructureOfServerFilesTree()
	
	ServerFilesTree = New ValueTree;
	ServerFilesTree.Columns.Add("Href");
	ServerFilesTree.Columns.Add("UID1C");
	ServerFilesTree.Columns.Add("Etag");
	ServerFilesTree.Columns.Add("FileName");
	ServerFilesTree.Columns.Add("IsFolder");
	ServerFilesTree.Columns.Add("ModificationDate");
	ServerFilesTree.Columns.Add("Length");
	Return ServerFilesTree;
	
EndFunction

Function ModifyFileInCloudService(Val ModifiedContentAtServer, UpdateFileSynchronizationStatus, Val SynchronizationParameters, Val TableRow)
	
	// importing from the server
	If TableRow.IsFolder Then
		// It is possible to track renaming.
		TableRowObject                 = TableRow.FileRef.GetObject();
		TableRowObject.Description    = TableRow.ServerDescription;
		TableRowObject.Parent        = Undefined;
		TableRowObject.DeletionMark = False;
		TableRowObject.Write();
		
		TableRow.Description    = TableRow.ServerDescription;
		TableRow.Changes       = TableRow.FileRef;
		TableRow.Parent        = TableRow.ParentServer;
		TableRow.DeletionMark = False;
		
	Else
		
		FileNameStructure = New File(TableRow.ServerDescription);
		NewFileExtension = CommonClientServer.ExtensionWithoutPoint(FileNameStructure.Extension);
		// Importing only if the content has changed, that is, Etag, otherwise, updating attributes.
		If ModifiedContentAtServer OR (NewFileExtension <> TableRow.FileRef.Extension) Then
			
			FileParameters = New Structure;
			FileParameters.Insert("FileName",                 TableRow.ServerDescription);
			FileParameters.Insert("Href",                     TableRow.ToHref);
			FileParameters.Insert("Etag",                     TableRow.ToEtag);
			FileParameters.Insert("FileModificationDate",     Undefined);
			FileParameters.Insert("FileLength",               Undefined);
			FileParameters.Insert("ForUser",          SynchronizationParameters.FilesAuthor);
			FileParameters.Insert("OwnerObject",           TableRow.Parent);
			FileParameters.Insert("ExistingFileRef", TableRow.FileRef);
			FileParameters.Insert("SynchronizationParameters",   SynchronizationParameters);
			
			ImportFileFromServer(FileParameters, TableRow.IsFile);
			
		EndIf;
		
		TableRowObject                 = TableRow.FileRef.GetObject();
		TableRowObject.Description    = FileNameStructure.BaseName;
		TableRowObject.DeletionMark = False;
		TableRowObject.Write();
		
		TableRow.Description    = TableRow.ServerDescription;
		TableRow.Changes       = TableRow.FileRef;
		TableRow.Parent        = TableRow.ParentServer;
		TableRow.DeletionMark = False;
		
	EndIf;
	
	TableRow.Processed = True;
	TableRow.SynchronizationDate = CurrentSessionDate();
	
	EventText = NStr("ru = 'Обновлен объект в базе: %1'; en = 'Object in the base is updated: %1'; pl = 'Zaktualizowany obiekt bazy danych: %1';es_ES = 'Objeto actualizado en la base: %1';es_CO = 'Objeto actualizado en la base: %1';tr = 'Veritabanındaki nesne güncellendi: %1';it = 'L''oggetto nella base è stato aggiornato:%1';de = 'Aktualisiertes Objekt in der Datenbank: %1'");
	WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, TableRow.Description), SynchronizationParameters.Account);
	
	Return True;
	
EndFunction

Function DeleteFileInCloudService(Val SynchronizationParameters, Val TableRow)
	
	Var EventText;
	
	If Not ValueIsFilled(TableRow.FileRef) Then
		Return False;
	EndIf;
	
	If Not IsFileRef(TableRow.FileRef) Then
		TableRow.Processed = True;
		Return False;
	EndIf;
	
	BeginTransaction();
	Try
		
		UnlockFile(TableRow.FileRef);
		TableRow.FileRef.GetObject().SetDeletionMark(True, False);
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		EventText = NStr("ru = 'Не удалено в базе: %1'; en = 'Not deleted in the infobase: %1'; pl = 'Nieusunięte w bazie danych: %1';es_ES = 'No eliminado en la base: %1';es_CO = 'No eliminado en la base: %1';tr = 'Veritananında silinmedi: %1';it = 'Non eliminato nella basedati: %1';de = 'Nicht aus der Datenbank gelöscht: %1'");
		WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, TableRow.Description), SynchronizationParameters.Account);
		Return False;
		
	EndTry;
	
	TableRow.DeletionMark = True;
	TableRow.Changes       = TableRow.FileRef;
	TableRow.Processed       = True;
	TableRow.SynchronizationDate  = CurrentSessionDate();
	
	EventText = NStr("ru = 'Удалено в базе: %1'; en = 'Deleted in base: %1'; pl = 'Usunięte w bazie danych: %1';es_ES = 'Eliminado en la base: %1';es_CO = 'Eliminado en la base: %1';tr = 'Veritabanında silindi: %1';it = 'Eliminato nella base dati: %1';de = 'Aus der Datenbank gelöscht: %1'");
	WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, TableRow.Description), SynchronizationParameters.Account);
	
	Return True;

EndFunction

Function IsFile(File)
		
	Return Not IsFilesFolder(File);
	
EndFunction

Function IsFileRef(OwnerObject)
	
	FilesTypesArray = Metadata.DefinedTypes.AttachedFile.Type.Types();
	Return FilesTypesArray.Find(TypeOf(OwnerObject)) <> Undefined;
	
EndFunction

Function CalculateTimeout(Size)
	
	Timeout = Int(Size / 8192); // size in megabytes * 128
	If Timeout < 10 Then
		Return 10;
	ElsIf Timeout > 43200 Then
		Return 43200;
	EndIf;
	
	Return Timeout;
	
EndFunction

Function CreateFileInCloudService(Val ServerAddress, Val SynchronizationParameters, Val TableRow, Val FilesTable)
	
	// sending the new one to server
	TableRow.Description = CommonClientServer.ReplaceProhibitedCharsInFileName(TableRow.Description, "-");
	TableRow.ToHref       = EndWithoutSlash(ServerAddress) + StartWithSlash(EndWithoutSlash(CalculateHref(TableRow,FilesTable)));
	
	If Common.ObjectIsFolder(TableRow.FileRef) Then
		CallMKCOLMethod(TableRow.ToHref, SynchronizationParameters);
	ElsIf TableRow.IsFolder Then
		CallMKCOLMethod(TableRow.ToHref, SynchronizationParameters);
	Else
		TableRow.ToEtag = CallPUTMethod(TableRow.ToHref, TableRow.FileRef, SynchronizationParameters, TableRow.IsFile);
	EndIf;
	
	UpdateFileUID1C(TableRow.ToHref, TableRow.UID1C, SynchronizationParameters);
	
	TableRow.ParentServer     = TableRow.Parent;
	TableRow.ServerDescription = TableRow.Description;
	TableRow.IsOnServer      = True;
	TableRow.Processed          = True;
	TableRow.SynchronizationDate  = CurrentSessionDate();
	
	ObjectIsFolder = Common.ObjectIsFolder(TableRow.FileRef);
	If Not TableRow.IsFile
		AND Not TableRow.IsFolder
		AND Not ObjectIsFolder Then
		If Common.ObjectAttributeValue(TableRow.FileRef, "BeingEditedBy") <> SynchronizationParameters.FilesAuthor Then
			LockFileForEditingServer(TableRow.FileRef, SynchronizationParameters.FilesAuthor);
		EndIf;
	ElsIf Not TableRow.IsFolder AND Not ObjectIsFolder Then
		FileData = FilesOperationsInternalServerCall.FileData(TableRow.FileRef);
		FilesOperationsInternalServerCall.LockFile(FileData, , , SynchronizationParameters.FilesAuthor);
	EndIf;
	
	EventText = NStr("ru = 'Создан объект в облачном сервисе %1'; en = 'Object is created in cloud service %1'; pl = 'Utworzono obiekt w usłudze chmurowej %1';es_ES = 'Se ha creado un objeto en el servicio de nube %1';es_CO = 'Se ha creado un objeto en el servicio de nube %1';tr = 'Bulut hizmetinde nesne oluşturuldu %1';it = 'L''oggetto è stato creato nel servizio cloud %1';de = 'Ein Objekt im Cloud-Service erstellt %1'");
	WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, TableRow.Description), SynchronizationParameters.Account);
	
	Return True;
	
EndFunction

Function SelectDataByRules(Account, Synchronize = TRUE)
	
	SynchronizationSettingQuiery = New Query;
	SynchronizationSettingQuiery.Text = "SELECT
	                                     |	FileSynchronizationSettings.FileOwner,
	                                     |	FileSynchronizationSettings.FileOwnerType,
	                                     |	MetadataObjectIDs.Ref AS OwnerID,
	                                     |	CASE
	                                     |		WHEN VALUETYPE(MetadataObjectIDs.Ref) <> VALUETYPE(FileSynchronizationSettings.FileOwner)
	                                     |			THEN TRUE
	                                     |		ELSE FALSE
	                                     |	END AS IsCatalogItemSetup,
	                                     |	FileSynchronizationSettings.FilterRule,
	                                     |	FileSynchronizationSettings.IsFile,
	                                     |	FileSynchronizationSettings.Account
	                                     |FROM
	                                     |	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
	                                     |		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	                                     |		ON (VALUETYPE(FileSynchronizationSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
	                                     |WHERE
	                                     |	FileSynchronizationSettings.Synchronize = &Synchronize
	                                     |	AND FileSynchronizationSettings.Account = &Account";
	
	SynchronizationSettingQuiery.SetParameter("Account",    Account);
	SynchronizationSettingQuiery.SetParameter("Synchronize", Synchronize);
	SynchronizationSettings = SynchronizationSettingQuiery.Execute().Unload();
	
	FilesTable = Undefined;
	
	For Each Setting In SynchronizationSettings Do
		
		CatalogFiles = Common.MetadataObjectByID(Setting.FileOwnerType);
		If NOT Common.MetadataObjectAvailableByFunctionalOptions(CatalogFiles) Then
			Continue;
		EndIf;
		
		AbilityToCreateGroups = CatalogFiles.Hierarchical;
		
		FilesTree = SelectDataBySynchronizationRule(Setting);
		If FilesTable = Undefined Then
			
			FilesTable = New ValueTable;
			For Each Column In FilesTree.Columns Do
				FilesTable.Columns.Add(Column.Name);
			EndDo;
			
		EndIf;
		
		If Setting.IsCatalogItemSetup Then
			RootDirectory = Setting.OwnerID;
		Else
			RootDirectory = Setting.FileOwner;
		EndIf;
		
		For Each FilesRow In FilesTree.Rows Do
			
			NewRow = FilesTable.Add();
			FillPropertyValues(NewRow, FilesRow);
			
			If NewRow.FileRef = Undefined Then
				NewRow.FileRef = RootDirectory;
			EndIf;
			
			If NewRow.Parent = Undefined Then
				NewRow.Parent = RootDirectory;
			EndIf;
			
			If AbilityToCreateGroups AND Setting.IsCatalogItemSetup Then
				If ValueIsFilled(FilesRow.FileRef.Parent) Then
					NewRow.Parent = FilesRow.FileRef.Parent;
				EndIf;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT
		|	CASE
		|		WHEN VALUETYPE(FileSynchronizationSettings.FileOwner) = TYPE(Catalog.MetadataObjectIDs)
		|			THEN FileSynchronizationSettings.FileOwner
		|		ELSE MetadataObjectIDs.Ref
		|	END AS FileRef,
		|	FileSynchronizationSettings.IsFile AS IsFile,
		|	FileSynchronizationSettings.Account AS Account,
		|	FileSynchronizationSettings.FileOwner AS FileOwner,
		|	FileSynchronizationSettings.FileOwnerType AS FileOwnerType
		|INTO TTVirtualRootFolders
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|		ON (VALUETYPE(FileSynchronizationSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
		|WHERE
		|	FileSynchronizationSettings.Synchronize = &Synchronize
		|	AND FileSynchronizationSettings.Account = &Account
		|
		|INDEX BY
		|	Account
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TTVirtualRootFolders.FileRef AS FileRef,
		|	TTVirtualRootFolders.IsFile AS IsFile,
		|	FALSE AS DeletionMark,
		|	TRUE AS IsFolder,
		|	TRUE AS InInfobase,
		|	FALSE AS IsOnServer,
		|	FALSE AS Processed,
		|	FALSE AS ModifiedAtServer,
		|	FilesSynchronizationWithCloudServiceStatuses.Href AS Href,
		|	FilesSynchronizationWithCloudServiceStatuses.Etag AS Etag,
		|	FilesSynchronizationWithCloudServiceStatuses.UUID1C AS UUID1C,
		|	TTVirtualRootFolders.FileOwner,
		|	TTVirtualRootFolders.FileOwnerType
		|FROM
		|	TTVirtualRootFolders AS TTVirtualRootFolders
		|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
		|		ON TTVirtualRootFolders.Account = FilesSynchronizationWithCloudServiceStatuses.Account
		|			AND TTVirtualRootFolders.FileRef = FilesSynchronizationWithCloudServiceStatuses.File
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TTVirtualRootFolders";
		
	Query.SetParameter("Account", Account);
	Query.SetParameter("Synchronize", Synchronize);
	QueryResult = Query.Execute();
	
	DetailedRecordsSelection = QueryResult.Select();
	
	VirtualFoldersArray = New Array;
	
	While DetailedRecordsSelection.Next() Do
		If VirtualFoldersArray.Find(DetailedRecordsSelection.FileRef) <> Undefined Then
			Continue;
		EndIf;
		VirtualFoldersArray.Add(DetailedRecordsSelection.FileRef);
		VirtualRootFolderString = FilesTable.Add();
		FillPropertyValues(VirtualRootFolderString, DetailedRecordsSelection);
		VirtualRootFolderString.Description = StrReplace(DetailedRecordsSelection.FileRef.Synonym, ":", "");
	EndDo;
	
	Return FilesTable;
	
EndFunction

Function SelectDataBySynchronizationRule(SyncSetup)
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	ComposerSettings = SyncSetup.FilterRule.Get();
	If ComposerSettings <> Undefined Then
		SettingsComposer.LoadSettings(SyncSetup.FilterRule.Get());
	EndIf;
	
	DataCompositionSchema = New DataCompositionSchema;
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	DataCompositionSchema.TotalFields.Clear();
	
	If SyncSetup.IsCatalogItemSetup Then
		FileOwner = SyncSetup.OwnerID;
		ExceptionItem = SyncSetup.FileOwner;
	Else
		FileOwner = SyncSetup.FileOwner;
		ExceptionItem = Undefined;
	EndIf;
	
	ExceptionsArray = New Array;
	DataCompositionSchema.DataSets[0].Query = QueryTextToSynchronizeFIles(
		FileOwner,
		SyncSetup,
		ExceptionsArray,
		ExceptionItem);
		
	Structure = SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("FileRef");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Description");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("DeletionMark");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Parent");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("IsFolder");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("InInfobase");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("IsOnServer");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Changes");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Href");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Etag");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Processed");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("SynchronizationDate");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("UID1C");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ToHref");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ToEtag");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ParentServer");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ServerDescription");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ModifiedAtServer");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("Level");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("ParentOrdering");
	
	SelectedField = Structure.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field = New DataCompositionField("IsFile");
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Settings = SettingsComposer.GetSettings();
	
	Parameter = SettingsComposer.Settings.DataParameters.Items.Find("Account");
	Parameter.Value = SyncSetup.Account;
	Parameter.Use = True;
	
	Parameter = SettingsComposer.Settings.DataParameters.Items.Find("OwnerType");
	Parameter.Value = TypeOf(FileOwner.EmptyRefValue);
	Parameter.Use = True;
	
	If ExceptionsArray.Count() > 0 Then
		Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ExceptionsArray");
		Parameter.Value = ExceptionsArray;
		Parameter.Use = True;
	EndIf;
	
	If SyncSetup.IsCatalogItemSetup Then
		Parameter = SettingsComposer.Settings.DataParameters.Items.Find("ExceptionItem");
		Parameter.Value = ExceptionItem;
		Parameter.Use = True;
	EndIf;
	
	TemplateComposer         = New DataCompositionTemplateComposer;
	DataCompositionProcessor = New DataCompositionProcessor;
	OutputProcessor           = New DataCompositionResultValueCollectionOutputProcessor;
	ValuesTree            = New ValueTree;
	
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, SettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	OutputProcessor.SetObject(ValuesTree);
	OutputProcessor.Output(DataCompositionProcessor);
	
	Return ValuesTree;
	
EndFunction

Procedure ScheduledFileSynchronizationWebdav(Parameters = Undefined, ResultAddress = Undefined) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.FileSynchronization);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	               |	FileSynchronizationAccounts.Ref,
	               |	FileSynchronizationAccounts.Service
	               |FROM
	               |	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
	               |		LEFT JOIN Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
	               |		ON FileSynchronizationSettings.Account = FileSynchronizationAccounts.Ref
	               |WHERE
	               |	NOT FileSynchronizationAccounts.DeletionMark
	               |	AND FileSynchronizationSettings.Synchronize";
	
	Result = Query.Execute().Unload();
	For each Selection In Result Do
		If IsBlankString(Selection.Service) Then
			Continue;
		EndIf;
		SynchronizeFilesWithCloudService(Selection.Ref);
	EndDo;
	
	ReleaseCapturedFiles();
	
EndProcedure

Procedure ExecuteConnectionCheck(Account, CheckResult) Export 

	CheckResult = New Structure("ResultText,ResultProtocol,Cancel","","",False);
	
	SynchronizationParameters = MainSynchronizationObjects(Account);
	
	ServerAddress = EncodeURIByStructure(SynchronizationParameters.ServerAddressStructure);
	
	EventText = NStr("ru = 'Начата проверка синхронизации файлов'; en = 'File synchronization check is started'; pl = 'Rozpoczęto sprawdzanie synchronizacji plików';es_ES = 'Prueba de sincronización de archivos empezada';es_CO = 'Prueba de sincronización de archivos empezada';tr = 'Dosya eşleşmesinin doğrulanması başladı';it = 'Controllo della sincronizzazione dei file iniziato';de = 'Dateisynchronisationsprüfung gestartet'") + " " + Account.Description;
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);
	
	ReadDirectoryParameters(CheckResult,ServerAddress, SynchronizationParameters);
	
	EventText = NStr("ru = 'Завершена проверка синхронизации файлов'; en = 'File synchronization check is completed'; pl = 'Kontrola synchronizacji plików zakończona';es_ES = 'Prueba de sincronización de archivos finalizada';es_CO = 'Prueba de sincronización de archivos finalizada';tr = 'Dosya eşleşmesinin doğrulanması tamamlandı';it = 'Verifica della sincronizzazione file completata';de = 'Dateisynchronisationsprüfung abgeschlossen'") + " " + Account.Description;
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);

EndProcedure

Procedure UnlockLockedFilesBackground(CallParameters, AddressInStorage) Export
	ReleaseCapturedFiles();
EndProcedure

Procedure ReleaseCapturedFiles()
	
	Query = New Query;
	
	Query.Text = 
		"SELECT
		|	FileSynchronizationAccounts.Ref AS Account
		|INTO InactiveAccounts
		|FROM
		|	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
		|WHERE
		|	FileSynchronizationAccounts.DeletionMark
		|
		|UNION ALL
		|
		|SELECT
		|	FileSynchronizationAccounts.Ref
		|FROM
		|	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
		|WHERE
		|	NOT FileSynchronizationAccounts.DeletionMark
		|	OR NOT FileSynchronizationAccounts.Ref IN
		|				(SELECT
		|					FileSynchronizationSettings.Account
		|				FROM
		|					InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|				WHERE
		|					FileSynchronizationSettings.Synchronize)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InactiveAccounts.Account
		|FROM
		|	InactiveAccounts AS InactiveAccounts
		|WHERE
		|	InactiveAccounts.Account IN
		|			(SELECT
		|				FilesSynchronizationWithCloudServiceStatuses.Account
		|			FROM
		|				InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses)";
	
	QueryResult = Query.Execute();
	
	SelectionAccount = QueryResult.Select();
	
	While SelectionAccount.Next() Do
		ReleaseAccountCapturedFiles(SelectionAccount.Account);
	EndDo;
	
EndProcedure

// Releasing files captured by user accounts marked for deletion or with synchronization settings disabled.
//
Procedure ReleaseAccountCapturedFiles(Account = Undefined)
	
	SynchronizationParameters = MainSynchronizationObjects(Account);
	
	If SynchronizationParameters = Undefined Then
		Return;
	EndIf;
	
	CloudServiceAddress = EncodeURIByStructure(SynchronizationParameters.ServerAddressStructure, False);
	ServerAddress = EncodeURIByStructure(SynchronizationParameters.ServerAddressStructure);
	
	EventText = NStr("ru = 'Начало освобождения файлов, захваченных облачным сервисом.'; en = 'Start of file release from the cloud service.'; pl = 'Początek wydania plików przechwyconych przez usługę w chmurze.';es_ES = 'Inicio de liberación de archivos, capturados por el servicio de nube.';es_CO = 'Inicio de liberación de archivos, capturados por el servicio de nube.';tr = 'Bulut hizmeti tarafından meşgul edilen dosyaları serbest bırakma başlangıcı.';it = 'Avvio del rilascio del file dal servizio cloud.';de = 'Beginn der Freigabe der vom Cloud-Service erfassten Dateien.'");
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);
	
	Try
		
		ServerFilesTree = New ValueTree;
		ServerFilesTree.Columns.Add("Href");
		ServerFilesTree.Columns.Add("UID1C");
		ServerFilesTree.Columns.Add("Etag");
		ServerFilesTree.Columns.Add("FileName");
		ServerFilesTree.Columns.Add("IsFolder");
		ServerFilesTree.Columns.Add("ModificationDate");
		ServerFilesTree.Columns.Add("Length");
		
		Cancel = False;
		ImportFilesTreeRecursively(ServerFilesTree.Rows, ServerAddress, SynchronizationParameters, Cancel);
		If Cancel = True Then
			ErrorText = NStr("ru = 'При загрузке структуры файлов с сервера произошла ошибка, синхронизация не выполнена.'; en = 'An error occurred when importing file structure from server. Synchronization not performed.'; pl = 'Wystąpił błąd podczas ładowania struktury plików z serwera, synchronizacja nie powiodła się.';es_ES = 'Al descargar la estructura del servidor se ha producido un error, sincronización no realizada.';es_CO = 'Al descargar la estructura del servidor se ha producido un error, sincronización no realizada.';tr = 'Dosyaların yapısı sunucudan içe aktarılırken bir hata oluştu, eşleşme yapılamadı.';it = 'Si è verificato un errore durante l''importazione della struttura di file dal server. Sincronizzazione non effettuata.';de = 'Beim Laden der Dateistruktur vom Server ist ein Fehler aufgetreten, die Synchronisation wird nicht durchgeführt.'");
			Raise ErrorText;
		EndIf;
		
		// Comparing it with the file tree in the system, synchronization by UUID.
		FilesTable = SelectDataByRules(Account, False);
		
		If FilesTable <> Undefined Then
		
			CalculateLevelRecursively(FilesTable);
			FilesTable.Sort("IsFolder ASC, Level DESC, ParentOrdering DESC");
			// Looping through the table and deciding what to do with files and folders.
			For Each TableRow In FilesTable Do
				
				If TableRow.Processed Then
					Continue;
				EndIf;
				
				BeginTransaction();
				
				Try
					
					If ValueIsFilled(TableRow.Href) Then
						// deleting on the server
						CallDELETEMethod(TableRow.Href, SynchronizationParameters);
						
						EventText = NStr("ru = 'Удален объект в облачном сервисе %1'; en = 'Object is deleted in cloud service %1'; pl = 'Usunięto obiekt w usłudze chmurowej %1';es_ES = 'Objeto eliminado en el servicio de nube %1';es_CO = 'Objeto eliminado en el servicio de nube %1';tr = 'Bulun hizmetimdeki nesne silindi %1';it = 'L''oggetto è stato eliminato nel servizio cloud %1';de = 'Das Objekt im Cloud-Service wurde entfernt %1'");
						WriteToEventLogOfFilesSynchronization(StringFunctionsClientServer.SubstituteParametersToString(EventText, TableRow.ServerDescription), SynchronizationParameters.Account);
					EndIf;
					
					TableRow.ParentServer = Undefined;
					TableRow.ServerDescription = "";
					TableRow.IsOnServer = False;
					TableRow.Processed = True;
					
					If Not TableRow.IsFolder Then
						UnlockFile(TableRow.FileRef);
					EndIf;
					
					// Deleting the last Href not to identify it again.
					DeleteRefServerData(TableRow.FileRef, Account);
					CommitTransaction();
					
				Except
					RollbackTransaction();
					WriteToEventLogOfFilesSynchronization(ErrorDescription(), SynchronizationParameters.Account, EventLogLevel.Error);
				EndTry;
				
			EndDo;
		EndIf;
		
	Except
		WriteToEventLogOfFilesSynchronization(ErrorDescription(), SynchronizationParameters.Account, EventLogLevel.Error);
	EndTry;
	
	EventText = NStr("ru = 'Завершено освобождения файлов, захваченных облачным сервисом'; en = 'Releasing of files from the cloud service is completed'; pl = 'Zakończono wydawanie plików przechwyconych przez usługę w chmurze';es_ES = 'Final de liberación de archivos, capturados por el servicio de nube';es_CO = 'Final de liberación de archivos, capturados por el servicio de nube';tr = 'Bulut hizmeti tarafından meşgul edilen dosyaları serbest bırakma tamamlandı.';it = 'Rilascio dei file dal servizio cloud completato';de = 'Die Freigabe von Dateien aus dem Cloud-Service ist abgeschlossen'");
	WriteToEventLogOfFilesSynchronization(EventText, SynchronizationParameters.Account);
	
EndProcedure

Function EventLogFilterData(Account) Export
	
	Filter = New Structure;
	Filter.Insert("EventLogEvent", FilesOperationsClientServer.EventLogEventSynchronization());
	
	Query = New Query;
	Query.Text = "SELECT
	|	FilesSynchronizationWithCloudServiceStatuses.SessionNumber AS SessionNumber,
	|	FilesSynchronizationWithCloudServiceStatuses.SynchronizationDateStart AS SynchronizationDateStart,
	|	FilesSynchronizationWithCloudServiceStatuses.SynchronizationDateCompletion AS SynchronizationDateCompletion
	|FROM
	|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
	|WHERE
	|	FilesSynchronizationWithCloudServiceStatuses.File = """"
	|	AND FilesSynchronizationWithCloudServiceStatuses.Account = &Account";
	
	Query.SetParameter("Account", Account);
	
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		
		SessionsList = New ValueList;
		SessionsList.Add(QueryResult.SessionNumber);
		
		Filter.Insert("Data", Account);
		Filter.Insert("StartDate",                 QueryResult.SynchronizationDateStart);
		Filter.Insert("EndDate",              QueryResult.SynchronizationDateCompletion);
		Filter.Insert("Session",                      SessionsList);
	
	EndIf;
	
	Return Filter;
	
EndFunction

Function SynchronizationInfo(FileOwner = Undefined) Export
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
		|	FilesSynchronizationWithCloudServiceStatuses.Account AS Account,
		|	FilesSynchronizationWithCloudServiceStatuses.SynchronizationDateStart AS SynchronizationDate,
		|	FilesSynchronizationWithCloudServiceStatuses.SessionNumber AS SessionNumber,
		|	FilesSynchronizationWithCloudServiceStatuses.Synchronized AS Synchronized,
		|	FilesSynchronizationWithCloudServiceStatuses.SynchronizationDateCompletion AS SynchronizationDateCompletion,
		|	FilesSynchronizationWithCloudServiceStatuses.Href AS Href,
		|	FilesSynchronizationWithCloudServiceStatuses.Account.Description AS AccountDescription,
		|	FilesSynchronizationWithCloudServiceStatuses.Account.Service AS Service
		|FROM
		|	InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS FilesSynchronizationWithCloudServiceStatuses
		|		LEFT JOIN InformationRegister.FilesSynchronizationWithCloudServiceStatuses AS CloudServiceFileSynchronizationStatusesRoot
		|		ON FilesSynchronizationWithCloudServiceStatuses.Account = CloudServiceFileSynchronizationStatusesRoot.Account
		|			AND (CloudServiceFileSynchronizationStatusesRoot.File = """""""")
		|WHERE
		|	FilesSynchronizationWithCloudServiceStatuses.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	Table = Query.Execute().Unload();
	
	While Table.Count() > 0  Do
		Result = Common.ValueTableRowToStructure(Table[0]);
		Return Result;
	EndDo;
	
	Return New Structure();
	
EndFunction

Procedure UpdateVolumePathLinux() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileStorageVolumes.Ref
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes
		|WHERE
		|	FileStorageVolumes.FullPathLinux LIKE ""%/\""";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(Metadata.Catalogs.FileStorageVolumes.FullName());
			DataLockItem.SetValue("Ref", Selection.Ref);
			DataLock.Lock();
			Volume = Selection.Ref.GetObject();
			Volume.FullPathLinux = StrReplace(Volume.FullPathLinux , "/\", "/");
			Volume.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось обработать том хранения файлов: %1 по причине:
				|%2'; 
				|en = 'Cannot process file storage volume: %1 due to:
				|%2'; 
				|pl = 'Nie udało się przetworzyć wolumin przechowywania plików: %1 z powodu:
				|%2';
				|es_ES = 'No se ha podido procesar el tomo de guardar de archivos: %1 a causa de: 
				|%2';
				|es_CO = 'No se ha podido procesar el tomo de guardar de archivos: %1 a causa de: 
				|%2';
				|tr = 'Dosya depolama birimi işlenemedi: %1, nedeni:
				|%2';
				|it = 'Impossibile elaborare il volume di archiviazione del file: %1 a causa di:
				|%2';
				|de = 'Das Datei-Speichervolumen konnte nicht verarbeitet werden: %1 aus dem Grund:
				|%2'"), 
				Selection.Ref, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Selection.Ref.Metadata(), Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
EndProcedure

// Returns the flag showing whether the node belongs to DIB exchange plan.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node that requires receiving the function value.
// 
// Returns:
//   True - the node belongs to DIB exchange plan. Otherwise, False.
//
Function IsDistributedInfobaseNode(Val InfobaseNode)
	
	Return FilesOperationsServiceCached.IsDistributedInfobaseNode(
		InfobaseNode.Metadata().FullName());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Accounting control.

Procedure SearchRefsToNonExistentFilesInVolumes(MetadataObject, CheckParameters, AvailableVolumes)
	
	ModuleAccountingAudit = Common.CommonModule("AccountingAudit");
	
	Attributes = MetadataObject.Attributes;
	
	QueryText =
	"SELECT TOP 1000
	|	MetadataObject.Ref AS ObjectWithIssue,
	|	&OwnerField AS Owner,
	|	REFPRESENTATION(MetadataObject.Ref) AS File,
	|	REFPRESENTATION(MetadataObject.Volume) AS Volume,
	|	MetadataObject.PathToFile AS PathToFile,
	|	FileStorageVolumes.FullPathLinux AS FullPathLinux,
	|	FileStorageVolumes.FullPathWindows AS FullPathWindows
	|FROM
	|	&MetadataObject AS MetadataObject
	|		INNER JOIN Catalog.FileStorageVolumes AS FileStorageVolumes
	|		ON MetadataObject.Volume = FileStorageVolumes.Ref
	|WHERE
	|	MetadataObject.Ref > &Ref
	|	AND MetadataObject.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
	|	AND MetadataObject.Volume IN(&AvailableVolumes)
	|
	|ORDER BY
	|	MetadataObject.Ref";
	
	FullName    = MetadataObject.FullName();
	QueryText = StrReplace(QueryText, "&MetadataObject", FullName);
	If FullName = "Catalog.FilesVersions" Then
		QueryText = StrReplace(QueryText, "&OwnerField", "REFPRESENTATION(MetadataObject.Owner) ");
	Else
		QueryText = StrReplace(QueryText, "&OwnerField", "Undefined ");
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref",        Catalogs.FileStorageVolumes.EmptyRef());
	Query.SetParameter("AvailableVolumes", AvailableVolumes);
	
	Result = Query.Execute().Unload();
	
	While Result.Count() > 0 Do
		
		For Each ResultString In Result Do
			
			PathToFile = "";
			If Common.IsLinuxServer() Then
				PathToFile = ResultString.FullPathLinux + ResultString.PathToFile;
			Else
				PathToFile = ResultString.FullPathWindows + ResultString.PathToFile;
			EndIf;
			
			If Not ValueIsFilled(PathToFile) Then
				Continue;
			EndIf;
			
			CheckedFile = New File(PathToFile);
			If CheckedFile.Exist() Then
				Continue;
			EndIf;
				
			ObjectRef = ResultString.ObjectWithIssue;
			
			If ResultString.Owner <> Undefined Then
				IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Версия ""%1"" файла ""%2"" не существует в томе ""%3"".'; en = 'Version ""%1"" of the ""%2"" file does not exist in the ""%3"" volume.'; pl = 'Wersja ""%1"" pliku ""%2"" nie istnieje w woluminie ""%3"".';es_ES = 'La versión ""%1"" del archivo ""%2"" no existe en el tomo ""%3"".';es_CO = 'La versión ""%1"" del archivo ""%2"" no existe en el tomo ""%3"".';tr = '""%1"" dosyanın ""%2"" sürümü ""%3"" biriminde mevcut değil.';it = 'La versione ""%1"" del file ""%2"" non esiste nel volume ""%3"".';de = 'Die Version ""%1"" der Datei ""%2"" existiert nicht im Volume ""%3"".'"),
					ResultString.File, ResultString.Owner, ResultString.Volume);
			Else
				IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Файл ""%1"" не существует в томе ""%2"".'; en = 'There is no file ""%1"" in the ""%2"" volume.'; pl = 'Plik ""%1"" nie istnieje w woluminie ""%2"".';es_ES = 'El archivo ""%1"" no existe en el tomo ""%2"".';es_CO = 'El archivo ""%1"" no existe en el tomo ""%2"".';tr = 'Dosya ""%1"" ""%2"" biriminde mevcut değil.';it = 'Non c''è nessun file ""%1"" nel volume ""%2"".';de = 'Die Datei ""%1"" existiert nicht im Volume ""%2"".'"),
					ResultString.File, ResultString.Volume);
			EndIf;
			
			Issue = ModuleAccountingAudit.IssueDetails(ObjectRef, CheckParameters);
			
			Issue.IssueSummary = IssueSummary;
			If Attributes.Find("EmployeeResponsible") <> Undefined Then
				Issue.Insert("EmployeeResponsible", Common.ObjectAttributeValue(ObjectRef, "EmployeeResponsible"));
			EndIf;
			
			ModuleAccountingAudit.WriteIssue(Issue, CheckParameters);

		EndDo;
		
		Query.SetParameter("Ref", ResultString.ObjectWithIssue);
		Result = Query.Execute().Unload();
		
	EndDo;
	
EndProcedure

Function CheckAttachedFilesObject(MetadataObject)
	
	If StrEndsWith(MetadataObject.Name, "AttachedFiles") Or MetadataObject.FullName() = "Catalog.FilesVersions" Then
		Attributes = MetadataObject.Attributes;
		If Attributes.Find("PathToFile") <> Undefined AND Attributes.Find("Volume") <> Undefined Then
			Return True;
		Else
			Return False;
		EndIf;
	Else
		Return False;
	EndIf;
	
EndFunction

Function AvailableVolumes(CheckParameters)
	
	AvailableVolumes = New Array;
	
	Query = New Query(
		"SELECT
		|	FileStorageVolumes.Ref AS VolumeRef,
		|	FileStorageVolumes.Description AS VolumePresentation,
		|	CASE
		|		WHEN &IsLinuxServer
		|			THEN FileStorageVolumes.FullPathLinux
		|		ELSE FileStorageVolumes.FullPathWindows
		|	END AS FullPath
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes");
	
	Query.SetParameter("IsLinuxServer", Common.IsLinuxServer());
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		
		If Not VolumeAvailable(Result.VolumeRef, Result.VolumePresentation, Result.FullPath, CheckParameters) Then
			Continue;
		EndIf;
		
		AvailableVolumes.Add(Result.VolumeRef);
		
	EndDo;
	
	Return AvailableVolumes;
	
EndFunction

Function VolumeAvailable(Volume, VolumePresentation, Path, CheckParameters)
	
	If IsBlankString(Path) Then
		
		IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'У тома хранения файлов ""%1"" не задан путь к сетевому каталогу. Сохранение файлов в него невозможно.'; en = 'File storage volume ""%1"" does not have a path to network directory. You cannot save files to it.'; pl = 'W woluminie przechowywania plików ""%1"" nie określono ścieżkę do sieciowego katalogu. Zapisywanie plików w niego jest niemożliwe.';es_ES = 'Para el tomo de guarda de archivos ""%1"" no está especificada la ruta al catálogo de red. Is imposible guardar los archivos en él.';es_CO = 'Para el tomo de guarda de archivos ""%1"" no está especificada la ruta al catálogo de red. Is imposible guardar los archivos en él.';tr = 'Dosya depolama birimin ""%1"" ağ kataloğu kısayolu bulunamadı. Dosyaların depolanması mümkün değil.';it = 'Il volume di archiviazione file ""%1"" non ha un percorso alla directory di rete. Non è possibile salvarvi i file.';de = 'Das Datei-Speichervolumen ""%1"" hat keinen Pfad zum Netzwerkverzeichnis. Es ist nicht möglich, Dateien darin zu speichern.'"), 
			VolumePresentation);
		WriteVolumeIssue(Volume, IssueSummary, CheckParameters);
		Return False;
		
	EndIf;
		
	TestDirectoryName = Path + "CheckAccess" + GetPathSeparator();
	
	Try
		CreateDirectory(TestDirectoryName);
		DeleteFiles(TestDirectoryName);
	Except
		
		IssueSummary = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Том хранения файлов ""%1"" недоступен по причине: 
				|%2
				|
				|Указанный сетевой каталог мог быть отключен или к нему отсутствуют права доступа.
				|Невозможна работа со всеми файлами, хранящимися в этом томе.'; 
				|en = 'File storage volume ""%1"" is unavailable due to: 
				|%2
				|
				|The specified network directory might have been disabled or you do not have access rights.
				|You cannot work with all files stored in this volume.'; 
				|pl = 'Wolumin przechowywania plików ""%1"" jest niedostępny z powodu: 
				|%2
				|
				|Podany w folder sieciowy mógł być wyłączony lub brak do niego prawa dostępu.
				|Nie jest możliwa praca ze wszystkimi plikami znajdującymi się w tym woluminie.';
				|es_ES = 'El tomo de guarda de archivos ""%1"" no está disponible a causa de: 
				|%2
				|
				|Puede que el catálogo de red indicado haya sido desconectado o no haya derechos de acceso.
				|Es imposible usar todos los archivos guardados en este tomo.';
				|es_CO = 'El tomo de guarda de archivos ""%1"" no está disponible a causa de: 
				|%2
				|
				|Puede que el catálogo de red indicado haya sido desconectado o no haya derechos de acceso.
				|Es imposible usar todos los archivos guardados en este tomo.';
				|tr = 'Dosya depolama birimi ""%1"" nedeniyle kullanılamaz: 
				|%2
				|
				|belirtilen ağ dizini devre dışı bırakılabilir veya erişim hakları yoktur. 
				|Bu birimde depolanan tüm dosyalarla çalışmak imkansızdır.';
				|it = 'Il volume di archiviazione ""%1"" non disponibile a causa di: 
				|%2
				|
				|La directory di rete specificata potrebbe essere stata disabilitata o si potrebbe non disporre di diritti sufficiente per accedervi. 
				|Non è possibile lavorare con tutti i file archiviati in questo volume.';
				|de = 'Datei-Speichervolumen ""%1"" ist nicht verfügbar, da:
				|%2
				|
				|Das angegebene Netzwerkverzeichnis möglicherweise deaktiviert wurde oder keine Zugriffsrechte darauf hat.
				|Es ist nicht möglich, mit allen in diesem Volume gespeicherten Dateien zu arbeiten.'"),
				Path, BriefErrorDescription(ErrorInfo()));
		IssueSummary = IssueSummary + Chars.LF;
		WriteVolumeIssue(Volume, IssueSummary, CheckParameters);
		Return False;
		
	EndTry;
	
	Return True;
	
EndFunction

Procedure WriteVolumeIssue(Volume, IssueSummary, CheckParameters)
	
	ModuleAccountingAudit = Common.CommonModule("AccountingAudit");
	
	Issue = ModuleAccountingAudit.IssueDetails(Volume, CheckParameters);
	Issue.IssueSummary = IssueSummary;
	ModuleAccountingAudit.WriteIssue(Issue, CheckParameters);
	
EndProcedure

// Extracting text for a full text search.

Function QueryTextForFilesWithUnextractedText(CatalogName, FilesNumberInSelection,
	GetAllFiles, AdditionalFields)
	
	If AdditionalFields Then
		QueryText =
		"SELECT TOP 1
		|	Files.Ref AS Ref,
		|	ISNULL(InformationRegisterFIleEncodings.Encoding, """") AS Encoding,
		|	Files.Extension AS Extension,
		|	Files.Description AS Description
		|FROM
		|	&CatalogName AS Files
		|		LEFT JOIN InformationRegister.FileEncoding AS InformationRegisterFIleEncodings
		|		ON (InformationRegisterFIleEncodings.File = Files.Ref)
		|WHERE
		|	Files.TextExtractionStatus IN (
		|		VALUE(Enum.FileTextExtractionStatuses.NotExtracted),
		|		VALUE(Enum.FileTextExtractionStatuses.EmptyRef))";
	Else
		QueryText =
		"SELECT TOP 1
		|	Files.Ref AS Ref,
		|	ISNULL(InformationRegisterFIleEncodings.Encoding, """") AS Encoding
		|FROM
		|	&CatalogName AS Files
		|		LEFT JOIN InformationRegister.FileEncoding AS InformationRegisterFIleEncodings
		|		ON (InformationRegisterFIleEncodings.File = Files.Ref)
		|WHERE
		|	Files.TextExtractionStatus IN (
		|		VALUE(Enum.FileTextExtractionStatuses.NotExtracted),
		|		VALUE(Enum.FileTextExtractionStatuses.EmptyRef))";
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		If CatalogName = "FilesVersions" Then
			QueryText = QueryText + "
				|	AND NOT Files.Owner.Encrypted";
		Else
			QueryText = QueryText + "
				|	AND NOT Files.Encrypted";
		EndIf;
	EndIf;
	
	QueryText = StrReplace(QueryText, "TOP 1", ?(
		GetAllFiles,
		"",
		"TOP " + Format(FilesNumberInSelection, "NG=; NZ=")));
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + CatalogName);
	
	Return QueryText;
	
EndFunction

// Gets a full path to file on the hard drive.
// Parameters:
//  ObjectRef - CatalogRef.FilesVersions.
//                 CatalogRef.*AttachedFiles.
//
// Returns:
//   String - a full path to the file on the hard drive.
Function FileWithBinaryDataName(ObjectRef) 
	
	FullFileName = "";
	
	If ObjectRef.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		
		FileStorage = FilesOperations.FileFromInfobaseStorage(ObjectRef);
		FileBinaryData = FileStorage.Get();
		
		If TypeOf(FileBinaryData) <> Type("BinaryData") Then
			Return "";
		EndIf;
		
		FullFileName = GetTempFileName(ObjectRef.Extension);
		FileBinaryData.Write(FullFileName);
	Else
		If NOT ObjectRef.Volume.IsEmpty() Then
			FullFileName = FullVolumePath(ObjectRef.Volume) + ObjectRef.PathToFile;
		EndIf;
	EndIf;
	
	Return FullFileName;
	
EndFunction

Procedure OnWriteExtractedText(FileObject)
	
	If IsItemFilesOperations(FileObject) Then
		FilesOperationsInternalServerCall.OnWriteExtractedText(FileObject);
	EndIf;
	
EndProcedure

// Extracts a text from a temporary storage or from binary data and returns extraction status.
Function ExtractText(Val TempTextStorageAddress, Val BinaryData = Undefined, Val Extension = Undefined) Export
	
	Result = New Structure("TextExtractionStatus, TextStorage");
	
	If IsTempStorageURL(TempTextStorageAddress) Then
		ExtractedText = RowFromTempStorage(TempTextStorageAddress);
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		Result.TextStorage = New ValueStorage(ExtractedText, New Deflation(9));
		Return Result;
	EndIf;
		
	If ExtractTextFilesOnServer() Then
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		Result.TextStorage = New ValueStorage("");
		Return Result; // The text will be extracted earlier in the scheduled job.
	EndIf;
	
	If Not IsWindowsPlatform() Or BinaryData = Undefined Then
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
		Result.TextStorage = New ValueStorage("");
		Return Result;
	EndIf;
	
	// The text is extracted right away, not in the scheduled job.
	TempFileName = GetTempFileName(Extension);
	BinaryData.Write(TempFileName);
	Result = ExtractTextFromFileOnHardDrive(TempFileName);
	Try
		DeleteFiles(TempFileName);
	Except
		WriteLogEvent(NStr("ru = 'Файлы.Извлечение текста'; en = 'Files.Text extraction'; pl = 'Pliki. Ekstrakcja tekstu';es_ES = 'Archivos.Extracción del texto';es_CO = 'Archivos.Extracción del texto';tr = 'Dosyalar. Metin özütleme';it = 'File.Estrazione testo';de = 'Dateien. Text extrahieren'",	CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	Return Result;
		
EndFunction

Function ExtractTextFromFileOnHardDrive(Val FileName, Val Encoding = Undefined) 
	
	Cancel = False;
	ExtractedText = FilesOperationsInternalClientServer.ExtractText(FileName, Cancel, Encoding);
	
	Result = New Structure("TextExtractionStatus, TextStorage");
	If Cancel Then
		// If there is no handler to extract the text, it is not an error.
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.FailedExtraction;
	Else
		Result.TextExtractionStatus = Enums.FileTextExtractionStatuses.Extracted;
		Result.TextStorage = New ValueStorage(ExtractedText, New Deflation(9));
	EndIf;
	Return Result;
	
EndFunction

// Receives a row from a temporary storage (transfer from client to server, done via temporary 
// storage).
//
Function RowFromTempStorage(TempTextStorageAddress)
	
	If IsBlankString(TempTextStorageAddress) Then
		Return "";
	EndIf;
	
	TempFileName = GetTempFileName();
	GetFromTempStorage(TempTextStorageAddress).Write(TempFileName);
	
	TextFile = New TextReader(TempFileName, TextEncoding.UTF8);
	Text = TextFile.Read();
	TextFile.Close();
	
	Try
		DeleteFiles(TempFileName);
	Except
		WriteLogEvent(NStr("ru = 'Файлы.Извлечение текста'; en = 'Files.Text extraction'; pl = 'Pliki. Ekstrakcja tekstu';es_ES = 'Archivos.Extracción del texto';es_CO = 'Archivos.Extracción del texto';tr = 'Dosyalar. Metin özütleme';it = 'File.Estrazione testo';de = 'Dateien. Text extrahieren'",	CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,	DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Text;
	
EndFunction

#EndRegion
