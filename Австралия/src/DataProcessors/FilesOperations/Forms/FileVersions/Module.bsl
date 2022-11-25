#Region Variables

&AtClient
Var Ref1;

&AtClient
Var Ref2;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ErrorTitle = NStr("ru = 'Ошибка при настройке динамического списка присоединенных файлов.'; en = 'Error setting up the dynamic list of attached files.'; pl = 'Wystąpił błąd podczas konfigurowania dynamicznej listy załączonych plików.';es_ES = 'Ha ocurrido un error al configurar la lista dinámica de los archivos adjuntados.';es_CO = 'Ha ocurrido un error al configurar la lista dinámica de los archivos adjuntados.';tr = 'Ekli dosyaların dinamik listesini yapılandırırken bir hata oluştu.';it = 'Errore durante l''impostazione dell''elenco dinamico dei file allegati.';de = 'Bei der Konfiguration der dynamischen Liste der angehängten Dateien ist ein Fehler aufgetreten.'");
	ErrorEnd = NStr("ru = 'В этом случае настройка динамического списка невозможна.'; en = 'Cannot set up the dynamic list.'; pl = 'W tym przypadku konfiguracja listy dynamicznej nie jest obsługiwana.';es_ES = 'En el caso la configuración de la lista dinámica no se admite.';es_CO = 'En el caso la configuración de la lista dinámica no se admite.';tr = 'Bu durumda, dinamik liste yapılandırılamaz.';it = 'Impossibile impostare l''elenco dinamico';de = 'In diesem Fall wird die dynamische Listenkonfiguration nicht unterstützt.'");
	
	FileVersionsStorageCatalogName = FilesOperationsInternal.FilesVersionsStorageCatalogName(
		Parameters.File.FileOwner, "", ErrorTitle, ErrorEnd);
		
	If Not IsBlankString(FileVersionsStorageCatalogName) Then
		SetUpDynamicList(FileVersionsStorageCatalogName);
	EndIf;
	
	CommandCompareVisibility = 
		Not CommonClientServer.IsLinuxClient() AND Not CommonClientServer.IsWebClient();
	Items.FormCompareFileVersions.Visible = CommandCompareVisibility;
	Items.ContextMenuListCompareFileVersions.Visible = CommandCompareVisibility;
	
	FileCardUUID = Parameters.FileCardUUID;
	
	List.Parameters.SetParameterValue("Owner", Parameters.File);
	VersionOwner = Parameters.File;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Items.FormOpenFileVersion.Picture = PictureLib.Magnifier;
		Items.FormOpenFileVersion.Representation = ButtonRepresentation.Picture;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MakeActiveExecute()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	NewActiveVersion = CurrentData.Ref;
	
	FileData = FilesOperationsInternalServerCall.FileData(CurrentData.Owner, CurrentData.Ref);
	
	If ValueIsFilled(FileData.BeingEditedBy) Then
		ShowMessageBox(, NStr("ru = 'Смена активной версии разрешена только для незанятых файлов.'; en = 'You can change active version only for files that are not used.'; pl = 'Zmiana aktywnej wersji jest dozwolona tylko dla nieużywanych plików.';es_ES = 'Está permitido cambiar la versión activa solo para los archivos que no están ocupados.';es_CO = 'Está permitido cambiar la versión activa solo para los archivos que no están ocupados.';tr = 'Aktif sürüm sadece kilitlenmeyen dosyalar için değiştirilebilir.';it = 'Puoi modificare la versione attiva solo per i file non in uso.';de = 'Das Ändern der aktiven Version ist nur für unbenutzte Dateien erlaubt.'"));
	ElsIf FileData.SignedWithDS Then
		ShowMessageBox(, NStr("ru = 'Смена активной версии разрешена только для неподписанных файлов.'; en = 'You can change active version only for files that are not signed.'; pl = 'Zmiana aktywnej wersji jest dozwolone tylko dla niepodpisanych plików.';es_ES = 'Está permitido cambiar la versión activa solo para los archivos que no están firmados.';es_CO = 'Está permitido cambiar la versión activa solo para los archivos que no están firmados.';tr = 'Aktif sürüm sadece imzalanmayan dosyalar için değiştirilebilir.';it = 'Puoi modificare la versione attiva solo per i file non firmati.';de = 'Das Ändern der aktiven Version ist nur für unsignierte Dateien erlaubt.'"));
	Else
		ChangeActiveFileVersion(NewActiveVersion);
		Notify("Write_File", New Structure("Event", "ActiveVersionChanged"), Parameters.File);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File"
	   AND Parameter.Property("Event")
	   AND (    Parameter.Event = "EditFinished"
	      Or Parameter.Event = "VersionSaved") Then
		
		If Parameters.File = Source Then
			
			Items.List.Refresh();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Owner, CurrentData.Ref, UUID);
	FilesOperationsInternalClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure OpenCard(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("DataProcessor.FilesOperations.Form.AttachedFileVersion", FormOpenParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("DataProcessor.FilesOperations.Form.AttachedFileVersion", FormOpenParameters);
		
	EndIf;
	
EndProcedure

// Compare two selected versions.
&AtClient
Procedure Compare(Command)
	
	SelectedRowsCount = Items.List.SelectedRows.Count();
	If SelectedRowsCount <> 2 AND SelectedRowsCount <> 1 Then
		ShowMessageBox(, NStr("ru='Для просмотра отличий необходимо выбрать две версии файла.'; en = 'To see the differences, select two file versions.'; pl = 'Aby wyświetlić różnice należy wybrać dwie wersje pliku.';es_ES = 'Para ver las diferencias es necesario seleccionar dos versiones del archivo.';es_CO = 'Para ver las diferencias es necesario seleccionar dos versiones del archivo.';tr = 'Farklılıkları görüntülemek için dosyanın iki sürümü seçilmelidir.';it = 'Per visualizzare le differenze è necessario selezionare due versioni del file.';de = 'Um die Unterschiede zu sehen, sollten Sie zwei Versionen der Datei auswählen.'"));
		Return;
	EndIf;
		
	If SelectedRowsCount = 2 Then
		Ref1 = Items.List.SelectedRows[0];
		Ref2 = Items.List.SelectedRows[1];
	ElsIf SelectedRowsCount = 1 Then
		Ref1 = Items.List.CurrentData.Ref;
		Ref2 = Items.List.CurrentData.ParentVersion;
	EndIf;
	
	Extension = Lower(Items.List.CurrentData.Extension);
	FilesOperationsInternalClient.CompareFiles(UUID, Ref1, Ref2, Extension, VersionOwner);
	
EndProcedure

&AtClient
Procedure OpenVersion(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Owner, CurrentData.Ref ,UUID);
	FilesOperationsInternalClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(CurrentData.Owner, CurrentData.Ref , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ChangeActiveFileVersion(Version)
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		
		DataLockItem = Lock.Add(Metadata.FindByType(TypeOf(Version.Owner)).FullName());
		DataLockItem.SetValue("Ref", Version.Owner);
		
		DataLockItem = Lock.Add(Metadata.FindByType(TypeOf(Version)).FullName());
		DataLockItem.SetValue("Ref", Version);
		
		Lock.Lock();
		
		LockDataForEdit(Version.Owner, , FileCardUUID);
		LockDataForEdit(Version, , FileCardUUID);
		
		FileObject = Version.Owner.GetObject();
		If FileObject.SignedWithDS Then
			Raise NStr("ru = 'У подписанного файла нельзя изменять активную версию.'; en = 'Cannot change active version of the signed file.'; pl = 'U podpisanego pliku nie można zmieniać aktywną wersję.';es_ES = 'No se puede cambiar la versión activa del archivo firmado.';es_CO = 'No se puede cambiar la versión activa del archivo firmado.';tr = 'İmzalanan dosyanın aktif versiyonu değiştirilemez.';it = 'Impossibile modificare la versione attiva del file firmato.';de = 'Eine signierte Datei kann nicht mit der aktiven Version geändert werden.'");
		EndIf;
		FileObject.CurrentVersion = Version;
		FileObject.TextStorage = Version.TextStorage;
		FileObject.Write();
		
		VersionObject = Version.GetObject();
		VersionObject.Write();
		
		UnlockDataForEdit(FileObject.Ref, FileCardUUID);
		UnlockDataForEdit(Version, FileCardUUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetUpDynamicList(FileVersionsStorageCatalogName)
	
	ListProperties = Common.DynamicListPropertiesStructure();
	
	QueryText = 
		"SELECT ALLOWED
		|	FilesVersions.Code AS Code,
		|	FilesVersions.Size AS Size,
		|	FilesVersions.Comment AS Comment,
		|	FilesVersions.Author AS Author,
		|	FilesVersions.CreationDate AS CreationDate,
		|	FilesVersions.FullDescr AS FullDescr,
		|	FilesVersions.ParentVersion AS ParentVersion,
		|	FilesVersions.PictureIndex,
		|	CASE
		|		WHEN FilesVersions.DeletionMark
		|			THEN FilesVersions.PictureIndex + 1
		|		ELSE FilesVersions.PictureIndex
		|	END AS CurrentPictureIndex,
		|	FilesVersions.DeletionMark AS DeletionMark,
		|	FilesVersions.Owner AS Owner,
		|	FilesVersions.Ref AS Ref,
		|	CASE
		|		WHEN FilesVersions.Owner.CurrentVersion = FilesVersions.Ref
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS IsCurrent,
		|	FilesVersions.Extension AS Extension,
		|	FilesVersions.VersionNumber AS VersionNumber
		|FROM
		|	Catalog." + FileVersionsStorageCatalogName + " AS FilesVersions
		|WHERE
		|	FilesVersions.Owner = &Owner";
	
	FullCatalogName = "Catalog." + FileVersionsStorageCatalogName;
	QueryText = StrReplace(QueryText, "&CatalogName", FullCatalogName);
	
	ListProperties.MainTable  = FullCatalogName;
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
EndProcedure

#EndRegion
