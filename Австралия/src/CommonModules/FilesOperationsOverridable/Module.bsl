////////////////////////////////////////////////////////////////////////////////
// File operations subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

// Overriding the attached file settings.
//
// Parameters:
//   Settings - Structure - with the following properties:
//     * DontClearFiles - Array - objects, whose files are not to be displayed in the file clearing 
//                                 settings (for example, internal documents).
//     * DontSynchronizeFiles - Array - objects, whose files are not to be displayed in the 
//                                 synchronization settings with cloud services (for example, internal documents).
//     * DontCreateFilesByTemplate - Array - objects for whose files the ability to create files by 
//                                 templates is disabled.
//
// Example:
//       Settings.DontClearFiles.Add(Metadata.Catalogs._DemoProducts);
//       Settings.DontSynchronizeFiles.Add(Metadata.Catalogs._DemoPartners);
//       Settings.DontCreateFilesByTemplates.Add(Metadata.Catalogs._DemoPartners);
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Overrides the list of catalogs that store files for a specific owner type.
// 
// Parameters:
//  TypeFileOwner  - Type - the type of object reference, to which the file is added.
//
//  CatalogsNames - Map - contains catalogs names in keys.
//                      To override the catalog name, pass the name as key and True as value to make 
//                      it a default one.
//                      The default catalog is used for user interaction.
//                       To specify the default catalog, set the map value to True.
//                      
//                      The algorithm implies that only one value is True.
//
// Example:
//       If TypeFileOwner = Type("CatalogRef._DemoProducts") Then
//       	CatalogsNames["_DemoProductsAttachedFiles"] = False;
//       	CatalogsNames.Insert("Files", True);
//       EndIf
//
Procedure OnDefineFileStorageCatalogs(TypeFileOwner, CatalogNames) Export
	
EndProcedure

// Allows you to cancel a file lock based on the analysis of the structure with the file data.
//
// Parameters:
//  FileData    - Structure - with file data.
//  ErrorDescription - String - an error text if the file is not locked.
//                   If it is not blank, the file cannot be locked.
//
Procedure OnAttemptToLockFile(FileData, ErrorDescription = "") Export
	
EndProcedure

// Called when creating a file. For example, it can be used to process logically related data that 
// needs to be changed when creating new files.
//
// Parameters:
//  File - CatalogRef.Files - a reference to the created file.
//
Procedure OnCreateFile(File) Export
	
EndProcedure

// Called after copying a file from the source file to fill in such attributes of the new file that 
// are not provided in the SL and were added to the Files or FilesVersions catalog in the configuration.
//
// Parameters:
//  NewFile    - CatalogRef.Files - a reference to a new file that needs filling.
//  SourceFile - CatalogRef.Files - a reference to the source file, from which you need to copy attributes.
//
Procedure FillFileAtributesFromSourceFile(NewFile, SourceFile) Export
	
EndProcedure

// Called when locking a file Allows you to change the structure with the file data before locking.
//
// Parameters:
//  FileData - Structure - that contains the information about file, see the FilesOperations.
//                FileData function.
//
//  UUID  - UUID - a form UUID.
//
Procedure OnLockFile(FileData, UUID) Export
	
EndProcedure

// Called when unlocking a file Allows you to change the structure with the file data before unlocking.
//
// Parameters:
//  FileData - Structure - that contains the information about file, see the FilesOperations.
//                FileData function.
//
//  UUID -  UUID - a form UUID.
//
Procedure OnUnlockFile(FileData, UUID) Export
	
EndProcedure

// Allows you to define the parameters of the email message before sending the file by email.
//
// Parameters:
//  FilesToSend  - Array - a list of files to send.
//  SendingParameters - Structure - returned parameter, see EmailOperationsClient. EmailSendingParameters.
//  FilesOwner    - DefinedType.AttachedFilesOwner - an object that owns files.
//  UUID - UUID - a UUID required for storing data to a temporary storage.
//                
//
Procedure OnSendFilesViaEmail(SendOptions, FilesToSend, FilesOwner, UUID) Export
	
	
	
EndProcedure

// Allows you to define the parameters of digital signature stamps in a signed spreadsheet document.
// 
//
// Parameters:
//  StampParameters - Structure - the returned parameter with the following properties:
//      * MarkText         - String - description of the original signed document location.
//      * Logo              - Picture - a logo that will be displayed in the stamp.
//  Certificate      - CryptoCertificate - a certificate, according to which the digital signature stamp is generated.
//
Procedure OnPrintFileWithStamp(StampParameters, Certificate) Export
	
EndProcedure

// Allows to change the standard form of the file list.
//
// Parameters:
//    Form - ClientApplicationForm - a file list form.
Procedure OnCreateFilesListForm(Form) Export
	
EndProcedure

// Allows you to change the file standard form
//
// Parameters:
//    Form - ClientApplicationForm - a file form.
Procedure OnCreateFilesItemForm(Form) Export
	
EndProcedure

// It allows to change parameter structure to place a hyperlink of attached files on the form.
//
// Parameters:
//  HyperlinkParameters - Structure - see FilesOperations.FilesHyperlink. 
//
// Example:
//  HyperlinkParameters.Placement = "CommandBar";
//
Procedure OnDefineFilesHyperlink(HyperlinkParameters) Export
	
EndProcedure

#EndRegion

