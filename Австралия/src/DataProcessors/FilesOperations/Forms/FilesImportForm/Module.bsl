
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.FolderForAdding = Undefined Then
		Raise NStr("ru='Обработка не предназначена для непосредственного использования.'; en = 'The data processor is not intended for direct usage.'; pl = 'Opracowanie nie jest przeznaczone do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanıma yönelik değil.';it = 'L''elaboratore dati non è inteso per un uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
	EndIf;
	
	GroupOfFiles = Parameters.GroupOfFiles;
	FolderForAdding = Parameters.FolderForAdding;
	FolderToAddAsString = Common.SubjectString(FolderForAdding);
	StoreVersions = FilesOperationsInternalServerCall.IsDirectoryFiles(FolderForAdding);
	Items.StoreVersions.Visible = StoreVersions;
	
	If TypeOf(Parameters.FileNamesArray) = Type("Array") Then
		For Each FilePath In Parameters.FileNamesArray Do
			MovedFile = New File(FilePath);
			NewItem = SelectedFiles.Add();
			NewItem.Path = FilePath;
			NewItem.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(MovedFile.Extension);
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.FilesOperations.Form.SelectEncoding") Then
		If TypeOf(SelectedValue) <> Type("Structure") Then
			Return;
		EndIf;
		FileTextEncoding = SelectedValue.Value;
		EncodingPresentation = SelectedValue.Presentation;
		SetCodingCommandPresentation(EncodingPresentation);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSelectedFiles

&AtClient
Procedure SelectedFilesOnAddStart(Item, Cancel, Clone)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AddExecute()
	
	ClearMessages();
	
	FieldsNotFilled = False;
	
	If SelectedFiles.Count() = 0 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Нет файлов для добавления.'; en = 'No files to add.'; pl = 'Brak plików do dodania.';es_ES = 'No hay archivos para añadir.';es_CO = 'No hay archivos para añadir.';tr = 'Eklenecek dosyalar yok.';it = 'Nessun file da aggiungere.';de = 'Keine Dateien zum Hinzufügen'"), , "SelectedFiles");
		FieldsNotFilled = True;
	EndIf;
	
	If FieldsNotFilled = True Then
		Return;
	EndIf;
	
	SelectedFileValueList = New ValueList;
	For Each ListLine In SelectedFiles Do
		SelectedFileValueList.Add(ListLine.Path);
	EndDo;
	
#If WebClient Then
	
	OperationArray = New Array;
	
	For Each ListLine In SelectedFiles Do
		CallDetails = New Array;
		CallDetails.Add("PutFiles");
		
		FilesToPut = New Array;
		Details = New TransferableFileDescription(ListLine.Path, "");
		FilesToPut.Add(Details);
		CallDetails.Add(FilesToPut);
		
		CallDetails.Add(Undefined); // not used
		CallDetails.Add(Undefined); // not used
		CallDetails.Add(False);         // Interactively = False
		
		OperationArray.Add(CallDetails);
	EndDo;
	
	If NOT RequestUserPermission(OperationArray) Then
		// User did not give a permission.
		Close();
		Return;
	EndIf;	
#EndIf	
	
	AddedFiles = New Array;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("AddedFiles", AddedFiles);
	Handler = New NotifyDescription("AddExecuteCompletion", ThisObject, HandlerParameters);
	
	ExecutionParameters = FilesOperationsInternalClient.FilesImportParameters();
	ExecutionParameters.ResultHandler          = Handler;
	ExecutionParameters.Owner                      = FolderForAdding;
	ExecutionParameters.SelectedFiles                = SelectedFileValueList; 
	ExecutionParameters.Comment                   = Comment;
	ExecutionParameters.StoreVersions                 = StoreVersions;
	ExecutionParameters.DeleteFilesAfterAdd   = DeleteFilesAfterAdd;
	ExecutionParameters.Recursively                    = False;
	ExecutionParameters.FormID            = UUID;
	ExecutionParameters.AddedFiles              = AddedFiles;
	ExecutionParameters.Encoding                     = FileTextEncoding;
	ExecutionParameters.GroupOfFiles                  = GroupOfFiles;
	
	FilesOperationsInternalClient.ExecuteFilesImport(ExecutionParameters);
EndProcedure

&AtClient
Procedure SelectFilesExecute()
	
	Handler = New NotifyDescription("SelectFilesExecuteAfterInstallExtension", ThisObject);
	FilesOperationsInternalClient.ShowFileSystemExtensionInstallationQuestion(Handler);
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	OpenForm("DataProcessor.FilesOperations.Form.SelectEncoding", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetCodingCommandPresentation(Presentation)
	
	Commands.SelectEncoding.Title = Presentation;
	
EndProcedure

&AtClient
Procedure AddExecuteCompletion(Result, ExecutionParameters) Export
	Close();
	
	Source = Undefined;
	AddedFilesCount = Result.AddedFiles.Count();
	If AddedFilesCount > 0 Then
		Source = Result.AddedFiles[AddedFilesCount - 1].FileRef;
	EndIf;
	Notify("Write_File", New Structure("IsNew", True), Source);
EndProcedure

&AtClient
Procedure SelectFilesExecuteAfterInstallExtension(ExtensionInstalled, ExecutionParameters) Export
	If Not ExtensionInstalled Then
		Return;
	EndIf;
	
	Mode = FileDialogMode.Open;
	
	OpenFileDialog = New FileDialog(Mode);
	OpenFileDialog.FullFileName = "";
	Filter = NStr("ru = 'Все файлы(*.*)|*.*'; en = 'All files (*.*)|*.*'; pl = 'Wszystkie pliki(*.*)|*.*';es_ES = 'Todos archivos (*.*)|*.*';es_CO = 'Todos archivos (*.*)|*.*';tr = 'Tüm dosyalar (*.*)|*.*';it = 'Tutti i file (*.*) | *.*';de = 'Alle Dateien (*.*)|*.*'");
	OpenFileDialog.Filter = Filter;
	OpenFileDialog.Multiselect = True;
	OpenFileDialog.Title = NStr("ru = 'Выберите файлы'; en = 'Select files'; pl = 'Wybrać pliki';es_ES = 'Seleccionar archivos';es_CO = 'Seleccionar archivos';tr = 'Dosyaları seçin';it = 'Selezionare file';de = 'Dateien wählen'");
	If OpenFileDialog.Choose() Then
		SelectedFiles.Clear();
		
		FilesArray = OpenFileDialog.SelectedFiles;
		For Each FileName In FilesArray Do
			MovedFile = New File(FileName);
			NewItem = SelectedFiles.Add();
			NewItem.Path = FileName;
			NewItem.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(MovedFile.Extension);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion
