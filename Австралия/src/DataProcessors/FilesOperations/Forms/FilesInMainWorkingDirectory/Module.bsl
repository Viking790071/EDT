
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FillList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FillListInForm();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData = Undefined Then
		CommandsAvailability = False;
	Else
		CommandsAvailability = True;
	EndIf;
	
	Items.FormDeleteFromLocalFileCache.Enabled = CommandsAvailability;
	Items.ListContextMenuDeleteFromLocalFileCache.Enabled = CommandsAvailability;
	
	Items.FormFinishEditing.Enabled = CommandsAvailability;
	Items.ListContextMenuFinishEditing.Enabled = CommandsAvailability;
	
	Items.FormUnlock.Enabled = CommandsAvailability;
	Items.ListContextMenuUnlock.Enabled = CommandsAvailability;
	
	Items.FormOpenFileDirectory.Enabled = CommandsAvailability;
	Items.ListContextMenuOpenFileDirectory.Enabled = CommandsAvailability;
	
	Items.FormOpenCard.Enabled = CommandsAvailability;
	Items.ListContextMenuOpenCard.Enabled = CommandsAvailability;
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	Cancel = True;
	OpenCardExecute();
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	Cancel = True;
	DeleteFromLocalFilesCacheExecute();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeleteFromLocalFileCache(Command)
	DeleteFromLocalFilesCacheExecute();
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileData(TableRow.Version);
	Handler = New NotifyDescription("EndEditingCompletion", ThisObject);
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, FileData.Ref, UUID);
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure OpenCard(Command)
	OpenCardExecute();
EndProcedure

&AtClient
Procedure UnlockExecute()
	
	Handler = New NotifyDescription("UnlockAfterInstallExtension", ThisObject);
	FilesOperationsInternalClient.ShowFileSystemExtensionInstallationQuestion(Handler);
	
EndProcedure

&AtClient
Procedure OpenFileDirectoryExecute()
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileData(TableRow.Version);
	FilesOperationsInternalClient.FileDirectory(Undefined, FileData);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure EndEditingCompletion(Result, ExecutionParameters) Export
	
	FillList();
	FillListInForm();
	
EndProcedure

&AtClient
Procedure UnlockAfterInstallExtension(Result, ExecutionParameters) Export
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("RefsArray", New Array);
	
	For Each Item In Items.List.SelectedRows Do
		RowData = Items.List.RowData(Item);
		Ref = RowData.Version;
		ExecutionParameters.RefsArray.Add(Ref);
	EndDo;
	
	ExecutionParameters.Insert("IndexOf", 0);
	ExecutionParameters.Insert("UBound", ExecutionParameters.RefsArray.UBound());
	
	UnlockInLoop(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure UnlockInLoop(ExecutionParameters)
	
	FilesOperationsInternalClient.RegisterHandlerDetails(
		ExecutionParameters, ThisObject, "UnlockLoopContinue");
	
	CallParameters = New Structure;
	CallParameters.Insert("ResultHandler",               ExecutionParameters);
	CallParameters.Insert("ObjectRef",                       Undefined);
	CallParameters.Insert("Version",                             Undefined);
	CallParameters.Insert("StoreVersions",                      Undefined);
	CallParameters.Insert("CurrentUserEditsFile", Undefined);
	CallParameters.Insert("BeingEditedBy",                        Undefined);
	CallParameters.Insert("UUID",            Undefined);
	CallParameters.Insert("DontAskQuestion",                   False);
	
	For Index = ExecutionParameters.IndexOf To ExecutionParameters.UBound Do
		ExecutionParameters.IndexOf = Index;
		CallParameters.Version = ExecutionParameters.RefsArray[Index];
		
		FilesOperationsInternalClient.UnlockFileAfterInstallExtension(
			Undefined, CallParameters);
		
		If ExecutionParameters.AsynchronousDialog.Open = True Then
			Return;
		EndIf;
	EndDo;
	
	FillList();
	FillListInForm();
	
EndProcedure

&AtClient
Procedure UnlockLoopContinue(Result, ExecutionParameters) Export
	
	ExecutionParameters.AsynchronousDialog.Open = False;
	ExecutionParameters.IndexOf = ExecutionParameters.IndexOf + 1;
	UnlockInLoop(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure FillListInForm()
	
	UserWorkingDirectory = FilesOperationsInternalClient.UserWorkingDirectory();
	
	List.Clear();
	
	For Each Row In FilesValuesListInRegister Do
		
		FullPath = UserWorkingDirectory + Row.Value.PartialPath;
		File = New File(FullPath);
		If File.Exist() Then
			NewRow = List.Add();
			NewRow.ChangeDate    = ToLocalTime(Row.Value.UniversalModificationDate);
			NewRow.FileName         = Row.Value.FullDescr;
			NewRow.PictureIndex   = Row.Value.PictureIndex;
			NewRow.Size           = Format(Row.Value.Size / 1024, "ND=10; NZ=0"); // in KB
			NewRow.Version           = Row.Value.Ref;
			NewRow.BeingEditedBy      = Row.Value.BeingEditedBy;
			NewRow.ToEdit = ValueIsFilled(Row.Value.BeingEditedBy);
			NewRow.File             = Row.Value.File;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure DeleteByLink(RefToDelete)
	
	ItemsCount = List.Count();
	
	For Number = 0 To ItemsCount - 1 Do
		Row = List[Number];
		Ref = Row.Version;
		If Ref = RefToDelete Then
			List.Delete(Number);
			Return;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillList()
	
	ListInRegister = ListInRegister();
	FilesValuesListInRegister.Clear();
	
	For Each Row In ListInRegister Do
		FilesValuesListInRegister.Add(Row);
	EndDo;

EndProcedure

&AtClient
Procedure DeleteFromLocalFilesCacheExecute()
	
	QuestionText = NStr("ru = 'Удалить выбранные файлы из рабочего каталога?'; en = 'Delete the selected files from the working directory?'; pl = 'Usunąć wybrane pliki z katalogu roboczego?';es_ES = '¿Eliminar los archivos seleccionados del catálogo?';es_CO = '¿Eliminar los archivos seleccionados del catálogo?';tr = 'Seçilen dosyalar ana çalışma dizininden silinsin mi?';it = 'Elimina i file selezionati dalla directory di lavoro?';de = 'Ausgewählte Dateien aus dem Arbeitsverzeichnis löschen?'");
	Handler = New NotifyDescription("DeleteFromLocalCacheAfterAnswerQuestion", ThisObject);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteFromLocalCacheAfterAnswerQuestion(Response, ExecutionParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("RefsArray", New Array);
	For Each LoopNumber In Items.List.SelectedRows Do
		RowData = Items.List.RowData(LoopNumber);
		ExecutionParameters.RefsArray.Add(RowData.Version);
	EndDo;
	
	ExecutionParameters.Insert("IndexOf", 0);
	ExecutionParameters.Insert("UBound", ExecutionParameters.RefsArray.UBound());
	ExecutionParameters.Insert("Ref", Undefined);
	ExecutionParameters.Insert("HasLockedFiles", False);
	ExecutionParameters.Insert("DirectoryName", FilesOperationsInternalClient.UserWorkingDirectory());

	DeleteFromLocalFilesCacheInLoop(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure DeleteFromLocalFilesCacheInLoop(ExecutionParameters)
	
	FilesOperationsInternalClient.RegisterHandlerDetails(ExecutionParameters, ThisObject, "DeleteFromLocalCacheLoopContinue");
	
	For Index = ExecutionParameters.IndexOf To ExecutionParameters.UBound Do
		ExecutionParameters.IndexOf = Index;
		ExecutionParameters.Ref = ExecutionParameters.RefsArray[Index];
		
		If FileLocked(ExecutionParameters.Ref) Then
			Rows = List.FindRows(New Structure("Version", ExecutionParameters.Ref));
			Rows[0].ToEdit = True;
			ExecutionParameters.HasLockedFiles = True;
			ExecutionParameters.AsynchronousDialog.Open = False;
			ExecutionParameters.IndexOf = ExecutionParameters.IndexOf + 1;
			Continue;
		EndIf;
		
		ExecutionParameters.Insert("FileNameWithPath",
			FilesOperationsInternalServerCall.GetFullFileNameFromRegister(
				ExecutionParameters.Ref, ExecutionParameters.DirectoryName, False, False));
		
		FilesOperationsInternalClient.DeleteFileFromWorkingDirectory(
			ExecutionParameters, ExecutionParameters.Ref);
		
		If ExecutionParameters.AsynchronousDialog.Open = True Then
			Return;
		EndIf;
		
		If ExecutionParameters.FileNameWithPath <> "" Then
			FileOnHardDrive = New File(ExecutionParameters.FileNameWithPath);
			If NOT FileOnHardDrive.Exist() Then
				DeleteByLink(ExecutionParameters.Ref);
			EndIf;
		Else
			DeleteByLink(ExecutionParameters.Ref);
		EndIf;
	EndDo;
	
	If ExecutionParameters.HasLockedFiles Then
		ShowMessageBox(,
			NStr("ru = 'Нельзя удалять из рабочего каталога файлы,
			           |занятые для редактирования.'; 
			           |en = 'Cannot delete files locked for editing
			           |from the working directory.'; 
			           |pl = 'Nie można usunąć z katalogu roboczego pliki,
			           |zajęte dla edycji.';
			           |es_ES = 'No se puede eliminar del catálogo en función los archivos
			           |ocupados para editar.';
			           |es_CO = 'No se puede eliminar del catálogo en función los archivos
			           |ocupados para editar.';
			           |tr = 'Düzenlenecek 
			           | çalışma dizinindeki dosyalar silinemez.';
			           |it = 'Impossibile eliminare file bloccati per la modifica
			           |dalla directory di lavoro.';
			           |de = 'Sie können keine Dateien aus dem Arbeitsverzeichnis löschen,
			           |die zur Bearbeitung belegt sind.'"));
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure DeleteFromLocalCacheLoopContinue(Result, ExecutionParameters) Export
	
	// Completing operations with the file.
	If ExecutionParameters.FileNameWithPath <> "" Then
		FileOnHardDrive = New File(ExecutionParameters.FileNameWithPath);
		If NOT FileOnHardDrive.Exist() Then
			DeleteByLink(ExecutionParameters.Ref);
		EndIf;
	Else
		DeleteByLink(ExecutionParameters.Ref);
	EndIf;
	
	// Continue loop.
	ExecutionParameters.AsynchronousDialog.Open = False;
	ExecutionParameters.IndexOf = ExecutionParameters.IndexOf + 1;
	DeleteFromLocalFilesCacheInLoop(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure OpenCardExecute()
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	ShowValue(, TableRow.File);
	
EndProcedure

&AtServer
Function ListInRegister()
	
	SetPrivilegedMode(True);
	
	ValueList = New Array;
	CurrentUser = Users.CurrentUser();
	
	// Finding a record in the information register for each record and taking the Version and EditedBy fields from there.
	QueryToRegister = New Query;
	QueryToRegister.SetParameter("User", CurrentUser);
	QueryToRegister.Text =
	"SELECT
	|	FilesInWorkingDirectory.File AS Ref,
	|	FilesInWorkingDirectory.ForReading AS ForReading,
	|	FilesInWorkingDirectory.Size AS Size,
	|	FilesInWorkingDirectory.Path AS Path,
	|	FilesInWorkingDirectory.File.UniversalModificationDate AS UniversalModificationDate,
	|	FilesInWorkingDirectory.File.Description AS FullDescr,
	|	FilesInWorkingDirectory.File.PictureIndex AS PictureIndex,
	|	FilesInWorkingDirectory.File.BeingEditedBy AS BeingEditedBy,
	|	FilesInWorkingDirectory.File AS File
	|FROM
	|	InformationRegister.FilesInWorkingDirectory AS FilesInWorkingDirectory
	|WHERE
	|	FilesInWorkingDirectory.User = &User
	|	AND FilesInWorkingDirectory.InOwnerWorkingDirectory = FALSE";
	
	QueryResult = QueryToRegister.Execute(); 
	
	If NOT QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			Record = New Structure;
			Record.Insert("UniversalModificationDate", Selection.UniversalModificationDate);
			Record.Insert("FullDescr",           Selection.FullDescr);
			Record.Insert("PictureIndex",               Selection.PictureIndex);
			Record.Insert("Size",                       Selection.Size);
			Record.Insert("Ref",                       Selection.Ref);
			Record.Insert("BeingEditedBy",                  Selection.BeingEditedBy);
			Record.Insert("ForReading",                     Selection.ForReading);
			Record.Insert("PartialPath",                Selection.Path);
			// This is a catalog of file versions.
			If Common.HasObjectAttribute("ParentVersion", Metadata.FindByType(TypeOf(Selection.Ref))) Then
				Record.Insert("File", Selection.Ref.Owner);
			Else
				Record.Insert("File", Selection.Ref);
			EndIf;
			ValueList.Add(Record);
		EndDo;
	EndIf;
	
	Return ValueList;
	
EndFunction

&AtServerNoContext
Function FileLocked(Ref)

	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	StorageCatalogName = Metadata.FindByType(TypeOf(Ref)).Name;
	
	If StorageCatalogName = "FilesVersions" Or StrEndsWith(StorageCatalogName, "AttachedFilesVersions") Then
		Query.Text = 
			"SELECT TOP 1
			|	TRUE AS TrueValue
			|FROM
			|	Catalog." + StorageCatalogName + " AS FilesVersions
			|WHERE
			|	FilesVersions.Ref = &Ref
			|	AND FilesVersions.Owner.BeingEditedBy <> VALUE(Catalog.Users.EmptyRef)";
	Else
		Query.Text = 
			"SELECT TOP 1
			|	TRUE AS TrueValue
			|FROM
			|	Catalog." + StorageCatalogName + " AS Files
			|WHERE
			|	Files.Ref = &Ref
			|	AND Files.BeingEditedBy <> VALUE(Catalog.Users.EmptyRef)";		
	EndIf;
	
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

#EndRegion
