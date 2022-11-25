////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete.
// Use FilesOperationsClient.OpenFile.
// Opens a file for viewing or editing.
//  If the file is opened for viewing, then it receives the file at the user working directory,
// searches for the file there and suggests to open the existing one or to receive the file from the server.
//  When the file is opened for editing, the procedure opens it in the working directory (if it exists)
// or retrieves the file from the server.
//
// Parameters:
//  FileData       - Structure - the file data.
//  ForEditing - Boolean - True to open the file for editing, False otherwise.
//
Procedure OpenFile(Val FileData, Val ForEditing = False) Export
	
	FilesOperationsClient.OpenFile(FileData, ForEditing);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.AddFiles.
// File adding command handler.
//  Suggests the user to select files in the file selection dialog box and
// attempts to put the selected files to a file storage when:
// - file does not exceed the maximum allowed size,
// - file has a valid extension,
// - volume has enough space (when storing files in volumes),
// - other conditions.
//
// Parameters:
//  FileOwner      - Reference - file owner.
//  FormID - UUID - the managed form ID.
//  Filter             - String - an optional parameter that lets you set the filter for the file to 
//                       be select, for example, when you select a picture for a product.
//                       
//
Procedure AddFiles(Val FileOwner, Val FormID, Val Filter = "") Export
	
	FilesOperationsClient.AddFiles(FileOwner, FormID, Filter);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.SignFile.
// Signs the attached file.
//
// Parameters:
//  AttachedFile      - CatalogRef - a reference to the catalog called "*AttachedFiles".
//  FormID      - UUID - the managed form ID.
//  AdditionalParameters - Undefined - the standard behavior (see below).
//                          - Structure - with the following properties:
//       * FileData            - Structure - file data. If the property is not filled, it is filled automatically in the procedure.
//       * ResultProcessing    - NotifyDescription - when calling, a value of the Boolean type is 
//                                  passed. If True, the file is successfully signed, otherwise, it 
//                                  is not signed. If there is no property, a notification will not be called.
//
Procedure SignFile(AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	FilesOperationsClient.SignFile(AttachedFile, FormID, AdditionalParameters);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.SaveWithDS.
// Saves the file with a digital signature.
// Used in the file save command handler.
//
// Parameters:
//  AttachedFile - CatalogRef - a reference to the catalog called "*AttachedFiles".
//  FileData        - Structure - (optional) - the file data.
//  FormID - UUID - the managed form ID.
//
Procedure SaveWithDigitalSignature(Val AttachedFile, Val FileData, Val FormID) Export
	
	FilesOperationsClient.SaveWithDigitalSignature(AttachedFile, FormID);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.SaveFileAs.
// Saves a file to the directory on disk.
// Also used as an auxiliary function when saving a file with digital signature.
//
// Parameters:
//  FileData  - Structure - the file data.
//
// Returns:
//  String - the saved file name.
//
Procedure SaveFileAs(Val FileData) Export
	
	FilesOperationsClient.SaveFileAs(FileData);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.GoToFileForm.
// Opens the common form of attached file from the attached file catalog item form.
//  Closes the item form.
// 
// Parameters:
//  Form     - ClientApplicationForm - the form of attached file catalog.
//
Procedure GoToAttachedFileForm(Val Form) Export
	
	AttachedFile = Form.Key;
	
	Form.Close();
	
	For Each Window In GetWindows() Do
		
		Content = Window.GetContent();
		
		If Content = Undefined Then
			Continue;
		EndIf;
		
		If Content.FormName = "DataProcessor.FilesOperations.Form.AttachedFile" Then
			If Content.Parameters.Property("AttachedFile")
				AND Content.Parameters.AttachedFile = AttachedFile Then
				Window.Activate();
				Return;
			EndIf;
		EndIf;
		
	EndDo;
	
	FilesOperationsClient.OpenFileForm(AttachedFile);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.OpenFilesSelectionForm.
// Opens the file selection form.
// Used in selection handler for overriding the default behavior.
//
// Parameters:
//  FilesOwner       - Reference - a reference to object with files.
//  FormItem         - FormTable, FormField - a form item that will receive the selection 
//                         notification.
//  StandardProcessing - Boolean - (return value) always set to False.
//
Procedure OpenFileChoiceForm(Val FilesOwner, Val FormItem, StandardProcessing = False) Export
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("FileOwner", FilesOwner);
	
	OpenForm("DataProcessor.FilesOperations.Form.AttachedFiles", FormParameters, FormItem);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.OpenFileForm.
// Opens the form of the attached file.
// Can be used as an attached file opening handler.
//
// Parameters:
//  AttachedFile   - CatalogRef - a reference to the catalog called "*AttachedFiles".
//  StandardProcessing - Boolean - (return value) always set to False.
//
Procedure OpenAttachedFileForm(Val AttachedFile, StandardProcessing = False) Export
	
	FilesOperationsClient.OpenFileForm(AttachedFile, StandardProcessing);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.FileData.
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
//                                           Undefined - a reference to the user that locked the file.
//    * SignedDS                         - Boolean - True if file is signed.
//    * Encrypted                         - Boolean - True if file is encrypted.
//    * FileBeingEdited                  - Boolean - True, is file is locked for editing.
//    * CurrentUserEditsFile - boolean - True if a file is locked for editing by the current user.
//
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetBinaryDataRef = True,
                            Val ForEditing = False) Export
	
	Return FilesOperationsClient.FileData(AttachedFile, FormID, GetBinaryDataRef,ForEditing);
	
EndFunction

// Obsolete.
// Use FilesOperationsClient.GetFile.
// Receives a file from the file storage to the user working directory.
// This is the analog of the View or Edit interactive actions without opening the received file.
//   The ReadOnly property of the received file will be set if the file is locked.
// is file for editing or not. If it is not locked, the read only mode is set.
//   If there is an existing file in the working directory, it will be deleted and replaced by the file
// received from the file storage.
//
// Parameters:
//  Notification - NotifyDescription - a notification that runs after the file is received in the 
//   user working directory. As a result the Structure returns with the following properties:
//     * FullFileName - String - a full file name with a path.
//     * ErrorDescription - String - an error text if the file is not received.
//
//  AttachedFile - CatalogRef - a reference to the catalog called "*AttachedFiles".
//  FormID - UUID - the managed form ID.
//
//  AdditionalParameters - Undefined - use the default values.
//     - Structure - with optional properties:
//         * ForEditing - Boolean    - the initial value is False. If True, the file will be locked 
//                                           for editing.
//         * FileData       - Structure - file properties that can be passed for acceleration if 
//                                           they were previously received by the client from the server.
//
Procedure GetAttachedFile(Notification, AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	FilesOperationsClient.GetAttachedFile(
		Notification,
		AttachedFile,
		FormID,
		AdditionalParameters);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.PutFile instead.
// Places the file from the user working directory into the file storage.
// It is the analogue of the Finish Editing interactive action.
//
// Parameters:
//  Notification - NotifyDescription - a method to be called after putting a file to a file storage.
//    As a result the Structure returns with the following properties:
//     * ErrorDescription - String - an error text if the file is not put.
//
//  AttachedFile - CatalogRef - a reference to the catalog called "*AttachedFiles".
//  FormID - UUID - the managed form ID.
//
//  AdditionalParameters - Undefined - use the default values.
//     - Structure - with optional properties:
//         * FullFileName - String - if filled, the specified file will be placed in the user 
//                                     working directory, and then in the file storage.
//         * FileData    - Structure - file properties that can be passed for acceleration if they 
//                                        were previously received by the client from the server.
//
Procedure PutAttachedFile(Notification, AttachedFile, FormID, AdditionalParameters = Undefined) Export
	
	FilesOperationsClient.PutAttachedFile(
		Notification,
		AttachedFile,
		FormID,
		AdditionalParameters);
	
EndProcedure

// Obsolete.
// Use FilesOperationsClient.PrintFiles.
// Prints files.
//
// Parameters:
//  FilesData       - Array - an array of structures with file data.
//  FormID - UUID - the managed form ID.
//
Procedure PrintFiles(FilesData, FormID) Export
	
	FilesOperationsClient.PrintFiles(FilesData, FormID);

EndProcedure

#EndRegion

#EndRegion
