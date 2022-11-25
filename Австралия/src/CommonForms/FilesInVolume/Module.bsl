
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Volume = Parameters.Volume;
	
	// Determining available file storages.
	FillFileStorageNames();
	
	If FileStorageNames.Count() = 0 Then
		Raise NStr("ru = 'Не найдены хранилища файлов.'; en = 'File storages are not found.'; pl = 'Nie znaleziono magazynów plików';es_ES = 'Almacenamientos de archivos no encontrados.';es_CO = 'Almacenamientos de archivos no encontrados.';tr = 'Dosya depoları bulunamadı.';it = 'Gli archivi di file non si trovano.';de = 'Dateispeicher wurden nicht gefunden.'");
		
	ElsIf FileStorageNames.Count() = 1 Then
		Items.FileStoragePresentation.Visible = False;
	EndIf;
	
	FileStorageName = Common.CommonSettingsStorageLoad(
		"CommonForm.FilesInVolume.FilterByStorages", 
		String(Volume.UUID()) );
	
	If FileStorageName = ""
	 OR FileStorageNames.FindByValue(FileStorageName) = Undefined Then
	
		FileVersionItem = FileStorageNames.FindByValue("FilesVersions");
		
		If FileVersionItem = Undefined Then
			FileStorageName = FileStorageNames[0].Value;
			FileStoragePresentation = FileStorageNames[0].Presentation;
		Else
			FileStorageName = FileVersionItem.Value;
			FileStoragePresentation = FileVersionItem.Presentation;
		EndIf;
	Else
		FileStoragePresentation = FileStorageNames.FindByValue(FileStorageName).Presentation;
	EndIf;
	
	SetUpDynamicList(FileStorageName);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FileStoragePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("FileStoragePresentationStartChoiceSelectionMade", ThisObject);
	ShowChooseFromList(NotifyDescription, FileStorageNames, Items.FileStoragePresentation,
		FileStorageNames.FindByValue(FileStorageName));
		
EndProcedure

&AtClient
Procedure FileStoragePresentationStartChoiceSelectionMade(CurrentStorage, AdditionalParameters) Export
	
	If TypeOf(CurrentStorage) = Type("ValueListItem") Then
		FileStorageName = CurrentStorage.Value;
		FileStoragePresentation = CurrentStorage.Presentation;
		SetUpDynamicList(FileStorageName);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenFileCard();
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	
	OpenFileCard();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetUpDynamicList(Val StorageName)
	
	ListProperties = Common.DynamicListPropertiesStructure();
	
	QueryText =
	"SELECT
	|	FileStorage.Ref AS Ref,
	|	FileStorage.PictureIndex AS PictureIndex,
	|	FileStorage.PathToFile AS PathToFile,
	|	FileStorage.Size AS Size,
	|	FileStorage.Author AS Author,
	|	&AreAttachedFiles AS AreAttachedFiles
	|FROM
	|	&CatalogName AS FileStorage
	|WHERE
	|	FileStorage.Volume = &Volume";
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + StorageName);
	QueryText = StrReplace(QueryText, "&AreAttachedFiles", ?(
		Upper(StorageName) = Upper("FilesVersions"), "FALSE", "TRUE"));
		
	ListProperties.MainTable = "Catalog." + StorageName;
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
	List.Parameters.SetParameterValue("Volume", Volume);
	
	SaveSelectionSettings(Volume, FileStorageName);
	
EndProcedure

&AtServer
Procedure FillFileStorageNames()
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		MetadataCatalogs = Metadata.Catalogs;
		FileStorageNames.Add(MetadataCatalogs.FilesVersions.Name, MetadataCatalogs.FilesVersions.Presentation());
		
		For each Catalog In Metadata.Catalogs Do
			If StrEndsWith(Catalog.Name, "AttachedFiles") Then
				FileStorageNames.Add(Catalog.Name, Catalog.Presentation());
			EndIf;
		EndDo;
	EndIf;
	
	FileStorageNames.SortByPresentation();
	
EndProcedure

&AtServerNoContext
Procedure SaveSelectionSettings(Volume, CurrentSettings)
	
	Common.CommonSettingsStorageSave(
		"CommonForm.FilesInVolume.FilterByStorages",
		String(Volume.UUID()),
		CurrentSettings);
	
EndProcedure

&AtClient
Procedure OpenFileCard()
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AreAttachedFiles Then
		FilesOperationsClient.OpenFileForm(CurrentData.Ref);
	Else
		ShowValue(, CurrentData.Ref);
	EndIf;
	
EndProcedure

#EndRegion
