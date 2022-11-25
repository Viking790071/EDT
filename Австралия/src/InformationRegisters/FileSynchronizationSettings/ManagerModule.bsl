#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function CurrentSynchronizationSettings() Export
	
	SetPrivilegedMode(True);
	
	RefreshSynchronizationSettings();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileSynchronizationSettings.FileOwner,
		|	MetadataObjectIDs.Ref AS OwnerID,
		|	CASE
		|		WHEN VALUETYPE(MetadataObjectIDs.Ref) <> VALUETYPE(FileSynchronizationSettings.FileOwner)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS IsCatalogItemSetup,
		|	FileSynchronizationSettings.FileOwnerType,
		|	FileSynchronizationSettings.FilterRule,
		|	FileSynchronizationSettings.IsFile,
		|	FileSynchronizationSettings.Synchronize,
		|	FileSynchronizationSettings.Account,
		|	FileSynchronizationSettings.Description
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|		ON (VALUETYPE(FileSynchronizationSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
		|WHERE
		|	FileSynchronizationSettings.Account <> VALUE(Catalog.FileSynchronizationAccounts.EmptyRef)";
		
	Return Query.Execute().Unload();
	
EndFunction

Procedure RefreshSynchronizationSettings()
	
	MetadataCatalogs = Metadata.Catalogs;
	
	FilesOwnersTable = New ValueTable;
	FilesOwnersTable.Columns.Add("FileOwner",     New TypeDescription("CatalogRef.MetadataObjectIDs"));
	FilesOwnersTable.Columns.Add("FileOwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	FilesOwnersTable.Columns.Add("IsFile",           New TypeDescription("Boolean"));
	
	For Each Catalog In MetadataCatalogs Do
		If Catalog.Attributes.Find("FileOwner") <> Undefined Then
			
			FilesOwnersTypes = Catalog.Attributes.FileOwner.Type.Types();
			For Each OwnerType In FilesOwnersTypes Do
				NewRow                              = FilesOwnersTable.Add();
				NewRow.FileOwner                = Common.MetadataObjectID(OwnerType);
				NewRowOwnerBlankRefValue = NewRow.FileOwner.EmptyRefValue;
				NewRow.FileOwnerType            = Common.MetadataObjectID(Catalog);
				If Not StrEndsWith(Catalog.Name, "AttachedFiles") Then
					NewRow.IsFile = True;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	ExceptionsArray = FilesOperationsInternal.OnDefineFilesSynchronizationExceptionObjects();
	For each ObjectException In ExceptionsArray Do
		FoundRow = FilesOwnersTable.Find(Common.MetadataObjectID(ObjectException), "FileOwner");
		If FoundRow <> Undefined Then
			FilesOwnersTable.Delete(FoundRow);
		EndIf;
	EndDo;
	
	RecordSelection = Select();
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	FilesOwnersTable.FileOwner AS FileOwner,
		|	FilesOwnersTable.FileOwnerType AS FileOwnerType,
		|	FilesOwnersTable.IsFile AS IsFile
		|INTO FilesOwnersTable
		|FROM
		|	&FilesOwnersTable AS FilesOwnersTable
		|
		|INDEX BY
		|	FileOwner,
		|	IsFile
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FileSynchronizationSettings.FileOwner,
		|	FileSynchronizationSettings.FileOwnerType AS FileOwnerType,
		|	FileSynchronizationSettings.IsFile AS IsFile,
		|	MetadataObjectIDs.Ref AS ObjectID,
		|	FileSynchronizationSettings.Description
		|INTO SubordinateSettings
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|		ON (VALUETYPE(FileSynchronizationSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
		|WHERE
		|	VALUETYPE(FileSynchronizationSettings.FileOwner) <> TYPE(Catalog.MetadataObjectIDs)
		|
		|INDEX BY
		|	ObjectID,
		|	IsFile,
		|	FileOwnerType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FileSynchronizationSettings.FileOwner,
		|	FileSynchronizationSettings.FileOwnerType AS FileOwnerType,
		|	FileSynchronizationSettings.IsFile,
		|	FALSE AS NewSetting,
		|	FileSynchronizationSettings.Description
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|		LEFT JOIN FilesOwnersTable AS FilesOwnersTable
		|		ON FileSynchronizationSettings.FileOwner = FilesOwnersTable.FileOwner
		|			AND FileSynchronizationSettings.IsFile = FilesOwnersTable.IsFile
		|			AND FileSynchronizationSettings.FileOwnerType = FilesOwnersTable.FileOwnerType
		|WHERE
		|	FilesOwnersTable.FileOwner IS NULL 
		|	AND VALUETYPE(FileSynchronizationSettings.FileOwner) = TYPE(Catalog.MetadataObjectIDs)
		|
		|UNION ALL
		|
		|SELECT
		|	SubordinateSettings.FileOwner,
		|	SubordinateSettings.FileOwnerType,
		|	SubordinateSettings.IsFile,
		|	FALSE,
		|	SubordinateSettings.Description
		|FROM
		|	SubordinateSettings AS SubordinateSettings
		|		LEFT JOIN FilesOwnersTable AS FilesOwnersTable
		|		ON SubordinateSettings.FileOwnerType = FilesOwnersTable.FileOwnerType
		|			AND SubordinateSettings.IsFile = FilesOwnersTable.IsFile
		|			AND SubordinateSettings.ObjectID = FilesOwnersTable.FileOwner
		|WHERE
		|	FilesOwnersTable.FileOwner IS NULL ";
	
	Query.Parameters.Insert("FilesOwnersTable", FilesOwnersTable);
	CommonSettingsTable = Query.Execute().Unload();
	
	SettingsForDelete = CommonSettingsTable.FindRows(New Structure("NewSetting", False));
	For Each Setting In SettingsForDelete Do
		RecordManager = CreateRecordManager();
		RecordManager.FileOwner = Setting.FileOwner;
		RecordManager.FileOwnerType = Setting.FileOwnerType;
		RecordManager.Delete();
	EndDo;
	
EndProcedure

#EndRegion

#EndIf