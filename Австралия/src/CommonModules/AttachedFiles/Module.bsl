////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete.
// Use the FilesOperations.FileBinaryData.
// Returns binary data of the attached file.
//
// Parameters:
//  AttachedFile - CatalogRef - a reference to the catalog called "*AttachedFiles".
//
// Returns:
//  BinaryData - binary data of the attached file.
//
Function GetBinaryFileData(Val AttachedFile) Export
	
	Return FilesOperations.FileBinaryData(AttachedFile);
	
EndFunction

// Obsolete.
// Use the FilesOperations.FileData.
// Returns file data structure. It is used in variety of file operation commands and as FileData 
// parameter value in other procedures and functions.
//
// Parameters:
//  AttachedFile - CatalogRef - a reference to the catalog called "*AttachedFiles".
//
//  FormID - UUID - a form ID that is used when getting a file binary data.
//                       
//
//  GetRefToBinaryData - Boolean - if False, reference to the binary data is not received thus 
//                 significantly speeding up execution for large binary data.
//
//  ForEditing - Boolean - if you specify True, then a free file will be locked for editing.
//
// Returns:
//  Structure - with the following properties:
//    * RefToBinaryFileData        - String - an address in the temporary storage.
//    * RelativePath                  - String - a relative file path.
//    * ModificationDateUniversal       - Date   - file change date.
//    * FileName                           - String - a file name without fullstop.
//    * Description                       - String - a file description in the file storage catalog.
//    * Extension                         - String - a file extension without fullstop.
//    * Size                             - Number  - a file size.
//    * EditedBy                        - CatalogRef.Users, CatalogRef.ExternalUsers,
//                                           CatalogRef.FilesSynchronizationAccounts, Undefined.
//    * SignedDS                         - Boolean - True if file is signed.
//    * Encrypted                         - Boolean - True if file is encrypted.
//    * FileBeingEdited                  - Boolean - True, is file is locked for editing.
//    * CurrentUserEditsFile - boolean - True if a file is locked for editing by the current user.
//
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetBinaryDataRef = True,
                            Val ForEditing = False) Export

	Return FilesOperations.FileData(AttachedFile, 
	                    FormID,
	                    GetBinaryDataRef,
	                    ForEditing);

EndFunction

// Obsolete.
// Use FilesOperations.FillAttachedFilesToObject.
// Fills the array with references to object files.
//
// Parameters:
//  Object       - Ref - a reference to object that can contain the attached files.
//  FilesArray - Array - an array where references to objects are added:
//                  * CatalogRef - (return value) reference to the attached file.
//
Procedure GetAttachedToObjectFiles(Val Object, Val FilesArray) Export
	
	FilesOperations.FillFilesAttachedToObject(Object, FilesArray);
	
EndProcedure

// Obsolete.
// Use FilesOperations.AddFile.
// Creates an object in the catalog to storage the file and fills attributes with passed properties.
//
// Parameters:
//  FileParameters - Structure - parameters with file data.
//       * Author                        - Ref - a user that created the file.
//       * FilesOwher               - Reference - an object for adding file.
//       * BaseName             - String - file name without extension.
//       * ExtensionWithoutDot           - String - a file extension (without dot in the beginning).
//       * ModificationTimeUniversal  - Date   - a file modification date and time (UTC +0:00). If 
//                                            it is not specified, use CurrentUniversalDate.
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
//                                        files are stored.
// Returns:
//  CatalogRef - a reference to created attached file.
//
Function AddAttachedFile(FileParameters,
                     Val FileAddressInTempStorage,
                     Val TempTextStorageAddress = "",
                     Val Details = "",
                     Val NewRefToFile = Undefined) Export

	Return FilesOperations.AppendFile(FileParameters,
		FileAddressInTempStorage,
		TempTextStorageAddress,
		Details,
		NewRefToFile);
	
EndFunction

// Obsolete. Use the AddAttachedFile function.
//
// Creates an object in the catalog to storage the file and fills attributes with passed properties.
//
// Parameters:
//  FilesOwher                 - Reference - an object for adding file.
//  NameWithoutExtension               - String - file name without extension.
//  ExtensionWithoutDot             - String - a file extension (without dot in the beginnning).
//  ModificationTime                 - Date   - (not used) file change date and time (local time).
//  ModificationTimeUniversal    - Date   - a file modification date and time (UTC +0:00). If it is 
//                                            not specified, use CurrentUniversalDate.
//  FileAddressInTemporaryStorage - String - an address indicating binary data in the temporary storage.
//  TextTemporaryStorageAddress - an address of a file extracted from the text in the temporary storage.
//  Details                       - String - a text file description.
//
//  NewRefToFile              - Undefined - create a new reference to the file in the standard 
//                                   catalog or in unique nonstandard catalog. If file owner have 
//                                   more than one directories, reference to the file must be passed 
//                                   to avoid an exception.
//                                 - Reference - a reference to the file storage catalog item that 
//                                   must be used to add the file.
//                                   It must correspond to one of catalog types, where owner files 
//                                   are stored.
//
// Returns:
//  CatalogRef - a reference to created attached file.
//
Function AppendFile(Val FilesOwner,
                     Val NameWithoutExtension,
                     Val ExtensionWithoutPoint = Undefined,
                     Val ModificationTime = Undefined,
                     Val ModificationTimeUniversal = Undefined,
                     Val FileAddressInTempStorage,
                     Val TempTextStorageAddress = "",
                     Val Details = "",
                     Val NewRefToFile = Undefined) Export
	
	FileParameters = New Structure;
	FileParameters.Insert("Author",                       Undefined);
	FileParameters.Insert("FilesOwner",              FilesOwner);
	FileParameters.Insert("BaseName",            NameWithoutExtension);
	FileParameters.Insert("ExtensionWithoutPoint",          ExtensionWithoutPoint);
	FileParameters.Insert("ModificationTimeUniversal", ModificationTimeUniversal);
	
	Return FilesOperations.AppendFile(FileParameters,
		FileAddressInTempStorage,
		TempTextStorageAddress,
		Details,
		NewRefToFile);
	
EndFunction

// Obsolete.
// Use FilesOperations.NewRefToFile.
// Returns a new reference to the file for the specified owner that can be passed to the AppendFile 
// function.
//
// Parameters:
//  FilesOwher - Reference - a reference to object for adding file.
//
//  CatalogName - Undefined - find catalog by the owner (valid if catalog is unique, otherwise, an 
//                   exception is thrown).
//
//                 - String - the *AttachedFiles catalog name that is different from the default 
//                            <OwnerName>AttachedFiles.
//  
// Returns:
//  CatalogRef - a reference to new attached file.
//
Function NewRefToFile(FilesOwner, CatalogName = Undefined) Export
	
	Return FilesOperations.NewRefToFile(FilesOwner, CatalogName);
	
EndFunction

// Obsolete.
// Use FilesOperations.UpdateFile.
// Updates file properties, which are binary data, text, modification date, and also other optional 
// properties.
//
// Parameters:
//  AttachedFile - CatalogRef - a reference to the catalog called "*AttachedFiles".
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
//
Procedure UpdateAttachedFile(Val AttachedFile, Val FileInfo) Export
	
	FilesOperations.RefreshFile(AttachedFile, FileInfo);
	
EndProcedure

// Obsolete.
// Use FilesOperations.AttachedFilesObjectFormNameByOwner.
// Returns attached file form name by owner.
//
// Parameters:
//  FilesOwner - Reference - a reference to object, by which a form name is determined.
//
// Returns:
//  String - an attached file form name by owner.
//
Function GetAttachedFileObjectFormNameByOwner(Val FilesOwner) Export
	
	Return FilesOperations.FilesObjectFormNameByOwner(FilesOwner);
	
EndFunction

// Obsolete.
// Use FilesOperations.CanAttachFilesToObject.
// Defines the existence of object attached files storage and "Adding file to the storage" right 
// (attached file catalog).
//
// Parameters:
//  FilesOwner - Reference - a reference to checked object.
//  CatalogName - String - if a check of adding to the specified storage is required.
//
// Returns:
//  Boolean - if True, files can be attached to the object.
//
Function CanAttachFilesToObject(FilesOwner, CatalogName = "") Export
	
	Return FilesOperations.CanAttachFilesToObject(FilesOwner, CatalogName);
	
EndFunction

// Obsolete. Use FilesOperations.ChangeFilesStorageDirectory.
// Converts files from the File operations subsystem to the Attached files subsystem.
// Requires File operations subsystem.
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
Procedure ConvertFilesToAttachedFiles(Val FilesOwner, CatalogName = Undefined) Export
	
	FilesOperations.ChangeFilesStoragecatalog(FilesOwner, CatalogName);
	
EndProcedure

// Obsolete. Use FilesOperations.RefsToObjectsWithFiles.
// Returns references to the objects with files from the File operations subsystem.
// Requires File operations subsystem.
//
// Use with ConvertFilesToAttachedFiles function.
//
// Parameters:
//  FilesOwnersTable - String - a full name of metadata that can own attached files.
//                            
//
// Returns:
//  Array - with the following values:
//   * Reference - a reference to the object that has at least one attached file.
//
Function ReferencesToObjectsWithFiles(Val FilesOwnersTable) Export
	
	Return FilesOperations.ReferencesToObjectsWithFiles(FilesOwnersTable);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures that are attachable to managed form events.

// Obsolete. Use FilesOperations.OnWriteAtServer.
// Handler of the OnWriteAtServer event of the attached file owner form.
//
// Parameters:
//  Cancel - Boolean  - standard parameter of OnWriteAtServer managed form event.
//  CurrentObject   - Object - standard parameter of OnWriteAtServer managed form event.
//  WriteParameters - Structure - standard parameter of OnWriteAtServer managed form event.
//  Parameters       - FormDataStructure - the Managed form parameters property.
//
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters, Parameters) Export
	
	FilesOperations.OnWriteAtServer(Cancel, CurrentObject, WriteParameters, Parameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures that are called from the manager module of catalogs with attached files.


// Obsolete. Use FilesOperations.AttributesEditedInGroupProcessing.
// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	Return FilesOperations.AttributesToEditInBatchProcessing();
	
EndFunction


// Obsolete. Use FilesOperations.AddSignatureToFile.
////////////////////////////////////////////////////////////////////////////////
// DIgital signature operations.
// Obsolete. Use FilesOperations.AddSignatureToFile.
// Adds a signature to file.
// Parameters:
//  AttachedFile - Reference - a reference to the attached file.
//
//  SignatureProperties    - Structure - contains data that the Sign procedure of the 
//                       DigitalSignatureClient returns as a result.
//                     - Array - an array of structures described above:
//                     
//  FormID - UUID - if specified, it is used when locking an object.
//
Procedure AddSignatureToFile(AttachedFile, SignatureProperties, FormID = Undefined) Export
	
	FilesOperations.AddSignatureToFile(AttachedFile, SignatureProperties, FormID);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.


// Obsolete.
// Use FilesOperations.DefiineAttachedFileForm.
// Handler of the FormGetProcessing event for overriding attached file form.
//
// Parameters:
//  Source                 - CatalogManager - the "*AttachedFiles" catalog manager.
//  FormKind                 - String - a standard form name.
//  Parameters                - Structure - structure parameters.
//  SelectedForm           - String - name or metadata object of opened form.
//  AdditionalInformation - Structure - an additional information of the form opening.
//  StandardProcessing     - Boolean - a flag of standard (system) event processing execution.
//
Procedure OverrideAttachedFileForm(Source, FormType, Parameters,
			SelectedForm, AdditionalInformation, StandardProcessing) Export
	
	FilesOperations.DetermineAttachedFileForm(Source, FormType, Parameters,
			SelectedForm, AdditionalInformation, StandardProcessing)
	
EndProcedure

// Obsolete.
// Use FilesOperations.SetDeletionMarkOfFilesBeforeWrite.
// Handler of the BeforeWrite event of attached file owner.
// Marks for deletion related files.
//
// Parameters:
//  Source - Object - attached file owner, except for DocumentObject.
//  Cancel    - Boolean - shows whether writing is canceled.
// 
Procedure SetAttachedFilesDeletionMarks(Source, Cancel) Export
	
	FilesOperations.SetAttachedFilesDeletionMarks(Source, Cancel);
	
EndProcedure

// Obsolete.
// Use FilesOperations.SetDeletionMarkOfDocumentFilesBeforeWrite.
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
	
	FilesOperations.SetAttachedDocumentFilesDeletionMark(Source, Cancel, WriteMode, PostingMode);
	
EndProcedure

#EndRegion

#EndRegion

