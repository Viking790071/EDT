
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Parameters.DirectoryOnHardDrive) Then
		Raise NStr("ru='Обработка не предназначена для непосредственного использования.'; en = 'The data processor is not intended for direct usage.'; pl = 'Opracowanie nie jest przeznaczone do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanıma yönelik değil.';it = 'L''elaboratore dati non è inteso per un uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
	EndIf;
	
	GroupOfFiles = Parameters.GroupOfFiles;
	Directory = Parameters.DirectoryOnHardDrive;
	FolderForAdding = Parameters.FolderForAdding;
	FolderToAddAsString = Common.SubjectString(FolderForAdding);
	DirectoriesChoice = True;
	StoreVersions = FilesOperationsInternalServerCall.IsDirectoryFiles(FolderForAdding);
	Items.StoreVersions.Visible = StoreVersions;
	
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

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SelectedDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	// Code is called only from IE or thin client, check on the web client is not required.
	Mode = FileDialogMode.ChooseDirectory;
	
	OpenFileDialog = New FileDialog(Mode);
	
	OpenFileDialog.Directory = Directory;
	OpenFileDialog.FullFileName = "";
	Filter = NStr("ru = 'Все файлы(*.*)|*.*'; en = 'All files (*.*)|*.*'; pl = 'Wszystkie pliki(*.*)|*.*';es_ES = 'Todos archivos (*.*)|*.*';es_CO = 'Todos archivos (*.*)|*.*';tr = 'Tüm dosyalar (*. *) | *. *';it = 'Tutti i file (*.*) | *.*';de = 'Alle Dateien (*.*)|*.*'");
	OpenFileDialog.Filter = Filter;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("ru = 'Выберите каталог'; en = 'Select directory'; pl = 'Wybierz folder';es_ES = 'Seleccionar el directorio';es_CO = 'Seleccionar el directorio';tr = 'Dizini seçin';it = 'Selezionare la directory';de = 'Wählen Sie das Verzeichnis aus'");
	If OpenFileDialog.Choose() Then
		
		If DirectoriesChoice = True Then 
			
			Directory = OpenFileDialog.Directory;
			
		EndIf;
		
	EndIf;
		
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportExecute()
	
	If IsBlankString(Directory) Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Не выбран каталог для импорта.'; en = 'Catalog for import is not selected.'; pl = 'Nie wybrano katalogu do importu.';es_ES = 'Catálogo para importación no se ha seleccionado.';es_CO = 'Catálogo para importación no se ha seleccionado.';tr = 'İçe aktarım kataloğu seçilmedi.';it = 'L''anagrafica per l''importazione non è selezionata.';de = 'Katalog zum Importieren ist nicht ausgewählt.'"), , "Directory");
		Return;
		
	EndIf;
	
	If FolderForAdding.IsEmpty() Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите папку.'; en = 'Specify the folder.'; pl = 'Określ folder.';es_ES = 'Especificar la carpeta.';es_CO = 'Especificar la carpeta.';tr = 'Klasörü belirleyin.';it = 'Specificare la cartella.';de = 'Geben Sie den Ordner an.'"), , "FolderForAdding");
		Return;
	EndIf;
	
	SelectedFiles = New ValueList;
	SelectedFiles.Add(Directory);
	
	Handler = New NotifyDescription("ImportCompletion", ThisObject);
	
	ExecutionParameters = FilesOperationsInternalClient.FilesImportParameters();
	ExecutionParameters.ResultHandler          = Handler;
	ExecutionParameters.Owner                      = FolderForAdding;
	ExecutionParameters.SelectedFiles                = SelectedFiles; 
	ExecutionParameters.Comment                   = Details;
	ExecutionParameters.StoreVersions                 = StoreVersions;
	ExecutionParameters.DeleteFilesAfterAdd   = DeleteFilesAfterAdd;
	ExecutionParameters.Recursively                    = True;
	ExecutionParameters.FormID            = UUID;
	ExecutionParameters.Encoding                     = FileTextEncoding;
	ExecutionParameters.GroupOfFiles                  = GroupOfFiles;
	FilesOperationsInternalClient.ExecuteFilesImport(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure ImportCompletion(Result, ExecutionParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	Close();
	Notify("Write_FileFolders", New Structure, Result.FolderForAddingCurrent);
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

#EndRegion
