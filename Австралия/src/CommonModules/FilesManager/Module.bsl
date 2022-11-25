#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use FilesOperations.FilesOperationsSettings().
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
//    * ShowInformationThatFileNotChanged          - Boolean - show file when the job is completed.
//    * ShowTooltipsOnEditFIles       - Boolean - show tooltips in web client when editing files.
//                                                                  
//    * PathToLocalFilesCache                        - String - a path to local file cache.
//    * IsFullUser                      - Boolean - True if a user has full access.
//    * DeleteFileFromLocalFilesCacheOnCompleteEditing - Boolean - delete files from the local cache 
//                                                                              when complete editing.
//
Function FilesOperationSettings() Export
	
	Return FilesOperations.FilesOperationSettings();
	
EndFunction

// Obsolete. Use FilesOperations.SaveFilesOperationsSettings().
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
	
	FilesOperations.SaveFilesOperationSettings(FilesOperationSettings);
	
EndProcedure

// Obsolete. Use FilesOperations.MaxFileSize().
// Returns maximum file size.
//
// Returns:
//  Number - number of bytes (integer).
//
Function MaxFileSize() Export
	
	Return FilesOperations.MaxFileSize();
	
EndFunction

// Obsolete. Use FilesOperations.MaxFileSizeCommon().
// Returns maximum provider file size.
//
// Returns:
//  Number - number of bytes (integer).
//
Function MaxFileSizeCommon() Export
	
	Return FilesOperations.MaxFileSizeCommon();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Managing file volumes

// Obsolete. Use FilesOperations.HasHasFileStorageVolumes().
// Whether there is at least one file storage volume.
//
// Returns:
//  Boolean - if True, at least one working volume exisits.
//
Function HasFileStorageVolumes() Export
	
	Return FilesOperations.HasFileStorageVolumes();
	
EndFunction

#EndRegion

#EndRegion
