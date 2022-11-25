#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CurrentFolder = Common.ObjectAttributesValues(Ref,
		"Description, Parent, DeletionMark");
	
	If IsNew() Or CurrentFolder.Parent <> Parent Then
		// Check rights to a source folder.
		If NOT FilesOperationsInternal.HasRight("FoldersModification", CurrentFolder.Parent) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недостаточно прав для перемещения из папки файлов ""%1"".'; en = 'Insufficient rights to move the ""%1"" files from the folder.'; pl = 'Niewystarczające uprawnienia do przemieszczenia z folderu plików ""%1"".';es_ES = 'Insuficientes derechos para mover de la carpeta de archivos ""%1"".';es_CO = 'Insuficientes derechos para mover de la carpeta de archivos ""%1"".';tr = '""%1"" dosya klasörünü taşımak için haklar yetersiz.';it = 'Permessi insufficienti per lo spostamento dalla cartella dei file ""%1"".';de = 'Nicht genügend Rechte, um aus dem Dateiordner ""%1"" zu wechseln.'"),
				String(?(ValueIsFilled(CurrentFolder.Parent), CurrentFolder.Parent, NStr("ru = 'Папки'; en = 'Folders'; pl = 'Foldery';es_ES = 'Carpetas';es_CO = 'Carpetas';tr = 'Klasörler';it = 'Cartelle';de = 'Ordner'"))));
		EndIf;
		// Check rights to a destination folder.
		If NOT FilesOperationsInternal.HasRight("FoldersModification", Parent) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недостаточно прав для добавления подпапок в папку файлов ""%1"".'; en = 'Insufficient rights to add subfolders to file folder ""%1"".'; pl = 'Niewystarczające uprawnienia do dodawania podfolderów do folderu plików ""%1"".';es_ES = 'Insuficientes derechos para añadir subcarpetas a la carpeta de archivos ""%1"".';es_CO = 'Insuficientes derechos para añadir subcarpetas a la carpeta de archivos ""%1"".';tr = '""%1"" dosya klasörüne alt klasörleri eklemek için haklar yetersiz';it = 'Autorizzazioni insufficienti per aggiungere sottocartelle alla cartella ""%1"".';de = 'Unzureichende Rechte zum Hinzufügen von Unterordnern zum Dateiordner ""%1"".'"),
				String(?(ValueIsFilled(Parent), Parent, NStr("ru = 'Папки'; en = 'Folders'; pl = 'Foldery';es_ES = 'Carpetas';es_CO = 'Carpetas';tr = 'Klasörler';it = 'Cartelle';de = 'Ordner'"))));
		EndIf;
	EndIf;
	
	If DeletionMark AND CurrentFolder.DeletionMark <> True Then
		
		// Checking the "Deletion mark" right.
		If NOT FilesOperationsInternal.HasRight("FoldersModification", Ref) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недостаточно прав для изменения папки файлов ""%1"".'; en = 'Insufficient rights to change file folder ""%1"".'; pl = 'Niewystarczające uprawnienia do zmiany folderu ""%1"".';es_ES = 'Insuficientes derechos para cambiar la carpeta de archivos ""%1"".';es_CO = 'Insuficientes derechos para cambiar la carpeta de archivos ""%1"".';tr = '""%1"" dosya klasörünü değiştirmek için haklar yetersiz.';it = 'Autorizzazioni insufficienti per cambiare la cartella dei file""%1"".';de = 'Unzureichende Rechte zum Ändern des Dateiordners ""%1"".'"),
				String(Ref));
		EndIf;
	EndIf;
	
	If DeletionMark <> CurrentFolder.DeletionMark AND Not Ref.IsEmpty() Then
		// Filtering files and trying to mark them for deletion.
		Query = New Query;
		Query.Text = 
			"SELECT
			|	Files.Ref,
			|	Files.BeingEditedBy
			|FROM
			|	Catalog.Files AS Files
			|WHERE
			|	Files.FileOwner = &Ref";
		
		Query.SetParameter("Ref", Ref);
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			If ValueIsFilled(Selection.BeingEditedBy) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
				                     NStr("ru = 'Папку %1 нельзя удалить, т.к. она содержит файл ""%2"", занятый для редактирования.'; en = 'Folder %1 cannot be deleted as it contains file ""%2"" that is locked for editing.'; pl = 'Folderu %1 nie można usunąć, ponieważ zawiera on plik ""%2"" zajęty dla redagowania.';es_ES = 'La carpeta %1 no puede borrarse, porque contiene el archivo ""%2"" que está bloqueado para editar.';es_CO = 'La carpeta %1 no puede borrarse, porque contiene el archivo ""%2"" que está bloqueado para editar.';tr = 'Klasör %1, düzenleme için kilitli olan ""%2"" dosyasını içerdiğinden silinemez.';it = 'La cartella %1 non può essere cancellata, perché contiene il file ""%2"", occupato per la modifica.';de = 'Der Ordner %1 kann nicht gelöscht werden, da er die Datei ""%2"" enthält, die für die Bearbeitung gesperrt ist.'"),
				                     String(Ref),
				                     String(Selection.Ref));
			EndIf;

			FileObject = Selection.Ref.GetObject();
			FileObject.Lock();
			FileObject.SetDeletionMark(DeletionMark);
		EndDo;
	EndIf;
	
	AdditionalProperties.Insert("PreviousIsNew", IsNew());
	
	If NOT IsNew() Then
		
		If Description <> CurrentFolder.Description Then // folder is renamed
			FolderWorkingDirectory         = FilesOperationsInternalServerCall.FolderWorkingDirectory(Ref);
			FolerParentWorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(CurrentFolder.Parent);
			If FolerParentWorkingDirectory <> "" Then
				
				// Adding a slash mark at the end if it is not there.
				FolerParentWorkingDirectory = CommonClientServer.AddLastPathSeparator(
					FolerParentWorkingDirectory);
				
				InheritedFolerWorkingDirectoryPrevious = FolerParentWorkingDirectory
					+ CurrentFolder.Description + GetPathSeparator();
					
				If InheritedFolerWorkingDirectoryPrevious = FolderWorkingDirectory Then
					
					NewFolderWorkingDirectory = FolerParentWorkingDirectory
						+ Description + GetPathSeparator();
					
					FilesOperationsInternalServerCall.SaveFolderWorkingDirectory(Ref, NewFolderWorkingDirectory);
				EndIf;
			EndIf;
		EndIf;
		
		If Parent <> CurrentFolder.Parent Then // Folder is moved to another folder.
			FolderWorkingDirectory               = FilesOperationsInternalServerCall.FolderWorkingDirectory(Ref);
			FolerParentWorkingDirectory       = FilesOperationsInternalServerCall.FolderWorkingDirectory(CurrentFolder.Parent);
			NewFolderParentWorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(Parent);
			
			If FolerParentWorkingDirectory <> "" OR NewFolderParentWorkingDirectory <> "" Then
				
				InheritedFolerWorkingDirectoryPrevious = FolerParentWorkingDirectory;
				
				If FolerParentWorkingDirectory <> "" Then
					InheritedFolerWorkingDirectoryPrevious = FolerParentWorkingDirectory
						+ CurrentFolder.Description + GetPathSeparator();
				EndIf;
				
				// Working directory is created automatically from a parent.
				If InheritedFolerWorkingDirectoryPrevious = FolderWorkingDirectory Then
					If NewFolderParentWorkingDirectory <> "" Then
						
						NewFolderWorkingDirectory = NewFolderParentWorkingDirectory
							+ Description + GetPathSeparator();
						
						FilesOperationsInternalServerCall.SaveFolderWorkingDirectory(Ref, NewFolderWorkingDirectory);
					Else
						FilesOperationsInternalServerCall.CleanUpWorkingDirectory(Ref);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.PreviousIsNew Then
		FolderWorkingDirectory = FilesOperationsInternalServerCall.FolderWorkingDirectory(Parent);
		If FolderWorkingDirectory <> "" Then
			
			// Adding a slash mark at the end if it is not there.
			FolderWorkingDirectory = CommonClientServer.AddLastPathSeparator(
				FolderWorkingDirectory);
			
			FolderWorkingDirectory = FolderWorkingDirectory
				+ Description + GetPathSeparator();
			
			FilesOperationsInternalServerCall.SaveFolderWorkingDirectory(Ref, FolderWorkingDirectory);
		EndIf;
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	CreationDate = CurrentSessionDate();
	EmployeeResponsible = Users.CurrentUser();
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	FoundProhibitedCharsArray = CommonClientServer.FindProhibitedCharsInFileName(Description);
	If FoundProhibitedCharsArray.Count() <> 0 Then
		Cancel = True;
		
		Text = NStr("ru = 'Наименование папки содержит запрещенные символы ( \ / : * ? "" < > | .. )'; en = 'Folder name contains forbidden characters ( \ / : * ? "" < > | .. )'; pl = 'Nazwa folderu zawiera niedozwolone znaki (\ /: *? "" < > | ..)';es_ES = 'Nombre de la carpeta contiene los símbolos prohibidos ( \ / : * ? "" < > | .. )';es_CO = 'Nombre de la carpeta contiene los símbolos prohibidos ( \ / : * ? "" < > | .. )';tr = 'Klasör adı yasaklanmış karakterler içeriyor (\ /: *? ""< >| ..)';it = 'Il nome della cartella contiene caratteri non permessi ( \ / : * ? "" < > | .. )';de = 'Ordnername enthält verbotene Zeichen (\ /: *? "" < > | ..)'");
		CommonClientServer.MessageToUser(Text, ThisObject, "Description");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf