#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("FileConversion") Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("FilePlacementInVolumes") Then
		Return;
	EndIf;
	
	If IsNew() Then
		ParentVersion = Owner.CurrentVersion;
	EndIf;
	
	If Not IsNew() Then
		DeletionMarkSet = DeletionMark AND Not DeletionMarkInIB();
	EndIf;
	
	// Setting an icon index upon object write.
	PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(Extension);
	
	If TextExtractionStatus.IsEmpty() Then
		TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
	If TypeOf(Owner) = Type("CatalogRef.Files") Then
		Description = TrimAll(FullDescr);
	EndIf;
	
	If Owner.CurrentVersion = Ref Then
		If DeletionMark = True AND Owner.DeletionMark <> True Then
			Raise NStr("ru = 'Активную версию нельзя удалить.'; en = 'Active version cannot be deleted.'; pl = 'Nie można usunąć aktywnej wersji.';es_ES = 'Versión del archivo no puede borrarse.';es_CO = 'Versión del archivo no puede borrarse.';tr = 'Aktif sürüm silinemez.';it = 'Versione attiva non può essere eliminata.';de = 'Aktive Version kann nicht gelöscht werden.'");
		EndIf;
	ElsIf ParentVersion.IsEmpty() Then
		If DeletionMark = True AND Owner.DeletionMark <> True Then
			Raise NStr("ru = 'Первую версию нельзя удалить.'; en = 'The first version cannot be deleted.'; pl = 'Pierwsza wersja nie może zostać usunięta.';es_ES = 'La primera versión no puede borrarse.';es_CO = 'La primera versión no puede borrarse.';tr = 'İlk sürüm silinemez.';it = 'La prima versione non può essere eliminato.';de = 'Die erste Version kann nicht gelöscht werden.'");
		EndIf;
	ElsIf DeletionMark = True AND Owner.DeletionMark <> True Then
		// Clearing a reference to a parent version for versions that are child to the marked one, 
		// specifying parent version of the version to be deleted.
		Query = New Query;
		Query.Text = 
			"SELECT
			|	FilesVersions.Ref AS Ref
			|FROM
			|	Catalog." + Metadata.FindByType(TypeOf(Ref)).Name + " AS FilesVersions
			|WHERE
			|	FilesVersions.ParentVersion = &ParentVersion";
		
		Query.SetParameter("ParentVersion", Ref);
		
		Result = Query.Execute();
		BeginTransaction();
		Try
			If Not Result.IsEmpty() Then
				Selection = Result.Select();
				Selection.Next();
				
				DataLock = New DataLock;
				DataLockItem = DataLock.Add(Metadata.FindByType(TypeOf(Selection.Ref)).FullName());
				DataLockItem.SetValue("Ref", Selection.Ref);
				DataLock.Lock();
				
				Object = Selection.Ref.GetObject();
				
				LockDataForEdit(Object.Ref);
				Object.ParentVersion = ParentVersion;
				Object.Write();
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnHardDrive Then
		If NOT Volume.IsEmpty() AND Common.RefExists(Volume) Then
			FullPath = FilesOperationsInternal.FullVolumePath(Volume) + PathToFile; 
			Try
				File = New File(FullPath);
				File.SetReadOnly(False);
				DeleteFiles(FullPath);
				
				PathWithSubdirectory = File.Path;
				FilesArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
				If FilesArrayInDirectory.Count() = 0 Then
					DeleteFiles(PathWithSubdirectory);
				EndIf;
				
			Except
				
				WriteLogEvent(NStr("ru = 'Файлы.Ошибка удаления файла.'; en = 'Files.File deletion error.'; pl = 'Pliki.Błąd usuwania pliku.';es_ES = 'Archivos.Error de eliminar el archivo';es_CO = 'Archivos.Error de eliminar el archivo';tr = 'Dosyalar. Dosya silme hatası.';it = 'Errore eliminazione Files.File.';de = 'Dateien.Fehler beim Löschen von Dateien.'", 
					CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,,
					File, ErrorDescription());
				
			EndTry;
		EndIf;
	EndIf;
	
	// Check DataExchange.Import starting from this row.
	// Firstly physically delete the file, and then delete information on it in the infobase.
	// Otherwise, file location information will be unavailable.
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Returns the current deletion mark value in the infobase.
Function DeletionMarkInIB()
	
	SetPrivilegedMode(True);
	FilesVersionsCatalogName = Metadata.FindByType(TypeOf(Ref)).Name;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FilesVersions.DeletionMark
		|FROM
		|	Catalog." + FilesVersionsCatalogName + " AS FilesVersions
		|WHERE
		|	FilesVersions.Ref = &Ref";
	
	Query.SetParameter("Ref", Ref);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.DeletionMark;
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndIf