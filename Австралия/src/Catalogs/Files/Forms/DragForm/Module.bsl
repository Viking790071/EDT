
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FolderForAdding = Parameters.FolderForAdding;
	
	For Each FilePath In Parameters.FileNamesArray Do
		ListFileNames.Add(FilePath);
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If WebClient Then
	WarningText =
		NStr("ru = 'В веб-клиенте импорт файлов недоступен. Используйте команду ""Добавить"" в списке файлов.'; en = 'File import is not available in web client. Use the ""Add"" command in the file list.'; pl = 'W kliencie sieci Web import plików nie jest dostępny. Użyj polecenia ""Dodaj"" na liście plików.';es_ES = 'En el cliente web no está disponible la importación de archivos. Use el comando ""Añadir"" en la lista de archivos.';es_CO = 'En el cliente web no está disponible la importación de archivos. Use el comando ""Añadir"" en la lista de archivos.';tr = 'Web istemcisinde dosya içe aktarımı yapılamaz. Dosya listesinde ""Ekle"" komutunu kullanın.';it = 'L''importazione del file non è disponibile nel client web. Utilizzare il comando ""Aggiungere"" nell''elenco del file.';de = 'Der Dateiimport ist im Webclient nicht verfügbar. Verwenden Sie den Befehl ""Hinzufügen"" in der Dateiliste.'");
	ShowMessageBox(, WarningText);
	Cancel = True;
	Return;
#EndIf
	
	StoreVersions = True;
	DirectoriesOnly = True;
	
	For Each FilePath In ListFileNames Do
		FillFileList(FilePath, FilesTree.GetItems(), True, DirectoriesOnly);
	EndDo;
	
	If DirectoriesOnly Then
		Title = NStr("ru = 'Загрузка папок'; en = 'Importing folders'; pl = 'Import folderów';es_ES = 'Importación de la carpeta';es_CO = 'Importación de la carpeta';tr = 'Klasörü içe aktarma';it = 'Importazione cartelle';de = 'Ordner importieren'");
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

#Region FIlesTreeFormTableItemsEventHandlers

&AtClient
Procedure FilesTreeMarkOnChamge(Item)
	DataItem = FilesTree.FindByID(Items.FilesTree.CurrentRow);
	SetMark(DataItem, DataItem.Check);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportFiles()
	
	ClearMessages();
	
	FieldsNotFilled = False;
	
	PseudoFileSystem = New Map; // Mapping of a path to a directory, files and folders in it.
	
	SelectedFiles = New ValueList;
	For Each FileNested In FilesTree.GetItems() Do
		If FileNested.Check = True Then
			SelectedFiles.Add(FileNested.FullPath);
		EndIf;
	EndDo;
	
	For Each FileNested In FilesTree.GetItems() Do
		FillFileSystem(PseudoFileSystem, FileNested);
	EndDo;
	
	If SelectedFiles.Count() = 0 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Нет файлов для добавления.'; en = 'No files to add.'; pl = 'Brak plików do dodania.';es_ES = 'No hay archivos para añadir.';es_CO = 'No hay archivos para añadir.';tr = 'Eklenecek dosyalar yok.';it = 'Nessun file da aggiungere.';de = 'Keine Dateien zum Hinzufügen'"), , "SelectedFiles");
		FieldsNotFilled = True;
	EndIf;
	
	If FolderForAdding.IsEmpty() Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите папку.'; en = 'Specify the folder.'; pl = 'Określ folder.';es_ES = 'Especificar la carpeta.';es_CO = 'Especificar la carpeta.';tr = 'Klasörü belirleyin.';it = 'Specificare la cartella.';de = 'Geben Sie den Ordner an.'"), , "FolderForAdding");
		FieldsNotFilled = True;
	EndIf;
	
	If FieldsNotFilled = True Then
		Return;
	EndIf;
	
	ExecutionParameters = FilesOperationsInternalClient.FilesImportParameters();
	ExecutionParameters.ResultHandler = New NotifyDescription("AddRunAfterImport", ThisObject);
	ExecutionParameters.Owner = FolderForAdding;
	ExecutionParameters.SelectedFiles = SelectedFiles; 
	ExecutionParameters.Comment = Comment;
	ExecutionParameters.StoreVersions = StoreVersions;
	ExecutionParameters.DeleteFilesAfterAdd = DeleteFilesAfterAdd;
	ExecutionParameters.Recursively = True;
	ExecutionParameters.FormID = UUID;
	ExecutionParameters.PseudoFileSystem = PseudoFileSystem;
	ExecutionParameters.Encoding = FileTextEncoding;
	FilesOperationsInternalClient.ExecuteFilesImport(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	OpenForm("DataProcessor.FilesOperations.Form.SelectEncoding", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AddRunAfterImport(Result, ExecutionParameters) Export
	Close();
	If Result <> Undefined Then
		Notify("Write_FileFolders", New Structure, Result.FolderForAddingCurrent);
	EndIf;
EndProcedure

&AtClient
Procedure FillFileList(FilePath, Val TreeItems, TopLevelItem, DirectoriesOnly = Undefined)
	
	MovedFile = New File(FilePath);
	
	NewItem = TreeItems.Add();
	NewItem.FullPath = MovedFile.FullName;
	NewItem.FileName = MovedFile.Name;
	NewItem.Check = True;
	
	If MovedFile.IsDirectory() Then
		NewItem.PictureIndex = 2; // folder
	Else
		NewItem.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(MovedFile.Extension);
	EndIf;
		
	If MovedFile.IsDirectory() Then
		
		Path = MovedFile.FullName + GetPathSeparator();
		
		FilesFound = FindFiles(Path, "*.*");
		
		FileSorted = New Array;
		
		// first folders
		For Each FileNested In FilesFound Do
			If FileNested.IsDirectory() Then
				FileSorted.Add(FileNested.FullName);
			EndIf;
		EndDo;
		
		// then files
		For Each FileNested In FilesFound Do
			If NOT FileNested.IsDirectory() Then
				FileSorted.Add(FileNested.FullName);
			EndIf;
		EndDo;
		
		For Each FileNested In FileSorted Do
			FillFileList(FileNested, NewItem.GetItems(), False);
		EndDo;
		
	Else
		
		If TopLevelItem Then
			DirectoriesOnly = False;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillFileSystem(PseudoFileSystem, TreeItem)
	If TreeItem.Check = True Then
		SubordinateItems = TreeItem.GetItems();
		If SubordinateItems.Count() <> 0 Then
			
			FilesAndSubdirectories = New Array;
			For Each FileNested In SubordinateItems Do
				FillFileSystem(PseudoFileSystem, FileNested);
				
				If FileNested.Check = True Then
					FilesAndSubdirectories.Add(FileNested.FullPath);
				EndIf;
			EndDo;
			
			PseudoFileSystem.Insert(TreeItem.FullPath, FilesAndSubdirectories);
		EndIf;
	EndIf;
EndProcedure

// Recursively marks all child items.
&AtClient
Procedure SetMark(TreeItem, Mark)
	SubordinateItems = TreeItem.GetItems();
	
	For Each FileNested In SubordinateItems Do
		FileNested.Check = Mark;
		SetMark(FileNested, Mark);
	EndDo;
EndProcedure

&AtServer
Procedure SetCodingCommandPresentation(Presentation)
	
	Commands.SelectEncoding.Title = Presentation;
	
EndProcedure

#EndRegion
