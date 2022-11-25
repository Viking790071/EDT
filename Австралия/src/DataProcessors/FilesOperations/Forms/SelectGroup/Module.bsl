
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SetUpDynamicList();
	SetConditionalAppearance();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	List.ConditionalAppearance.Items.Clear();
	List.Group.Items.Clear();
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("FileOwner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Parameters.FilesOwner;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	GroupingItem = List.Group.Items.Add(Type("DataCompositionGroupField"));
	GroupingItem.Use = True;
	GroupingItem.Field = New DataCompositionField("FileOwner");
	
EndProcedure

&AtServer
Procedure SetUpDynamicList()
	
	FilesOwner = Parameters.FilesOwner;
	
	ErrorTitle = NStr("ru = 'Ошибка при настройке динамического списка присоединенных файлов.'; en = 'Error setting up the dynamic list of attached files.'; pl = 'Wystąpił błąd podczas konfigurowania dynamicznej listy załączonych plików.';es_ES = 'Ha ocurrido un error al configurar la lista dinámica de los archivos adjuntados.';es_CO = 'Ha ocurrido un error al configurar la lista dinámica de los archivos adjuntados.';tr = 'Ekli dosyaların dinamik listesini yapılandırırken bir hata oluştu.';it = 'Errore durante l''impostazione dell''elenco dinamico dei file allegati.';de = 'Bei der Konfiguration der dynamischen Liste der angehängten Dateien ist ein Fehler aufgetreten.'");
	ErrorEnd = NStr("ru = 'В этом случае настройка динамического списка невозможна.'; en = 'Cannot set up the dynamic list.'; pl = 'W tym przypadku konfiguracja listy dynamicznej nie jest obsługiwana.';es_ES = 'En el caso la configuración de la lista dinámica no se admite.';es_CO = 'En el caso la configuración de la lista dinámica no se admite.';tr = 'Bu durumda, dinamik liste yapılandırılamaz.';it = 'Impossibile impostare l''elenco dinamico';de = 'In diesem Fall wird die dynamische Listenkonfiguration nicht unterstützt.'");
	FilesStorageCatalogName = FilesOperationsInternal.FileStoringCatalogName(
		FilesOwner, "", ErrorTitle, ErrorEnd);
	
	FileCatalogType = Type("CatalogRef." + FilesStorageCatalogName);
	MetadataOfCatalogWithFiles = Metadata.FindByType(FileCatalogType);
	CanCreateFileGroups = MetadataOfCatalogWithFiles.Hierarchical;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	
	QueryText = 
	"SELECT
	|	Files.Ref AS Ref,
	|	Files.DeletionMark AS DeletionMark,
	|	CASE
	|		WHEN Files.DeletionMark = TRUE
	|			THEN ISNULL(Files.PictureIndex, 2) + 1
	|		ELSE ISNULL(Files.PictureIndex, 2)
	|	END AS PictureIndex,
	|	Files.Description AS Description,
	|	&IsFolder AS IsFolder,
	|	Files.FileOwner AS FileOwner
	|FROM
	|	&CatalogName AS Files
	|WHERE
	|	Files.FileOwner = &FilesOwner
	|	AND &FilterGroups";
	
	FullCatalogName = "Catalog." + FilesStorageCatalogName;
	QueryText = StrReplace(QueryText, "&CatalogName", FullCatalogName);
	QueryText = StrReplace(QueryText, "&FilterGroups", "Files.IsFolder");
	ListProperties.QueryText = StrReplace(QueryText, "&IsFolder",
		?(CanCreateFileGroups, "Files.IsFolder", "FALSE"));
		
	ListProperties.MainTable  = FullCatalogName;
	ListProperties.DynamicDataRead = True;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	List.Parameters.SetParameterValue("FilesOwner", FilesOwner);
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	MoveFilesToGroup(Parameters.FilesToMove, Value);
	NotifyChanged(TypeOf(Parameters.FilesToMove[0]));
	Notify("Write_File", New Structure, Parameters.FilesToMove);
	Close();
EndProcedure

&AtServerNoContext
Procedure MoveFilesToGroup(Val Files, Val Folder)
	BeginTransaction();
	Try
		For Each FileRef In Files Do
			FileObject = FileRef.GetObject();
			FileObject.Parent = Folder;
			FileObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

&AtClient
Procedure CreateGroup(Command)
	Parent = Undefined;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		Parent = CurrentData.Ref;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Parent",       Parent);
	FormParameters.Insert("FileOwner",  FilesOwner);
	FormParameters.Insert("IsNewGroup", True);
	FormParameters.Insert("FilesStorageCatalogName", FilesStorageCatalogName);
	
	OpenForm("DataProcessor.FilesOperations.Form.GroupOfFiles", FormParameters, ThisObject);
EndProcedure

#EndRegion
