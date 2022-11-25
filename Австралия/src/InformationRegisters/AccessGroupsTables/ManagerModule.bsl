#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Updates the register data based on the result of changing the role rights saved when updating the 
// RolesRights information register.
//
Procedure UpdateRegisterDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.AccessManagement.RoleRightMetadataObjects");
	
	If LastChanges = Undefined Then
		UpdateRegisterData();
	Else
		MetadataObjects = New Array;
		For each ChangesPart In LastChanges Do
			If TypeOf(ChangesPart) = Type("FixedArray") Then
				For each MetadataObject In ChangesPart Do
					If MetadataObjects.Find(MetadataObject) = Undefined Then
						MetadataObjects.Add(MetadataObject);
					EndIf;
				EndDo;
			Else
				MetadataObjects = Undefined;
				Break;
			EndIf;
		EndDo;
		
		UpdateRegisterData(, MetadataObjects);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Updates the register data when changing the profile role content or access group profiles.
// 
// 
// Parameters:
//  AccessGroups - CatalogRef.AccessGroups.
//                - Array of values of the type specified above.
//                - Undefined - without filter.
//
//  Tables - CatalogRef.MetadataObjectsIDs.
//                - Array of values of the type specified above.
//                - Undefined - without filter.
//
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateRegisterData(AccessGroups = Undefined,
                                 Tables       = Undefined,
                                 HasChanges = Undefined) Export
	
	If TypeOf(Tables) = Type("Array") Or TypeOf(Tables) = Type("FixedArray") Then
		RecordsCount = Tables.Count();
		If RecordsCount = 0 Then
			Return;
		ElsIf RecordsCount > 500 Then
			Tables = Undefined;
		EndIf;
	EndIf;
	
	If Catalogs.ExtensionsVersions.ExtensionsChangedDynamically() Then
		Raise NStr("ru = 'Расширения конфигурации обновлены, требуется перезапустить сеанс.'; en = 'Configuration extensions are updated, restart the session.'; pl = 'Rozszerzenia konfiguracji są zaktualizowane, musisz zrestartować sesję.';es_ES = 'Extensiones de la configuración actualizadas, se requiere reiniciar la sesión.';es_CO = 'Extensiones de la configuración actualizadas, se requiere reiniciar la sesión.';tr = 'Yapılandırma uzantıları güncellendi, oturumu yeniden başlatın.';it = 'Le estensioni di configurazione sono state aggiornate, riavvia la sessione.';de = 'Konfigurationserweiterungen aktualisiert, Sitzungsneustart erforderlich.'");
	EndIf;
	
	InformationRegisters.RolesRights.CheckRegisterData();
	
	SetPrivilegedMode(True);
	
	BlankRecordsQuery = New Query;
	BlankRecordsQuery.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|WHERE
	|	AccessGroupsTables.Table = VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|WHERE
	|	AccessGroupsTables.AccessGroup = VALUE(Catalog.AccessGroups.EmptyRef)";
	
	TemporaryTablesQueriesText =
	"SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.Update AS Update,
	|	ExtensionsRolesRights.Insert AS Insert,
	|	ExtensionsRolesRights.ReadWithoutRestriction AS ReadWithoutRestriction,
	|	ExtensionsRolesRights.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|	ExtensionsRolesRights.InsertWithoutRestriction AS InsertWithoutRestriction,
	|	ExtensionsRolesRights.RowChangeKind AS RowChangeKind
	|INTO ExtensionsRolesRights
	|FROM
	|	&ExtensionsRolesRights AS ExtensionsRolesRights
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.Update AS Update,
	|	ExtensionsRolesRights.Insert AS Insert,
	|	ExtensionsRolesRights.ReadWithoutRestriction AS ReadWithoutRestriction,
	|	ExtensionsRolesRights.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|	ExtensionsRolesRights.InsertWithoutRestriction AS InsertWithoutRestriction
	|INTO RolesRights
	|FROM
	|	ExtensionsRolesRights AS ExtensionsRolesRights
	|WHERE
	|	ExtensionsRolesRights.RowChangeKind = 1
	|
	|UNION ALL
	|
	|SELECT
	|	RolesRights.MetadataObject,
	|	RolesRights.Role,
	|	RolesRights.Update,
	|	RolesRights.Insert,
	|	RolesRights.ReadWithoutRestriction,
	|	RolesRights.UpdateWithoutRestriction,
	|	RolesRights.InsertWithoutRestriction
	|FROM
	|	InformationRegister.RolesRights AS RolesRights
	|		LEFT JOIN ExtensionsRolesRights AS ExtensionsRolesRights
	|		ON RolesRights.MetadataObject = ExtensionsRolesRights.MetadataObject
	|			AND RolesRights.Role = ExtensionsRolesRights.Role
	|WHERE
	|	ExtensionsRolesRights.MetadataObject IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Profile AS Profile
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|		ON AccessGroups.Profile = AccessGroupProfiles.Ref
	|			AND (AccessGroups.Profile <> VALUE(Catalog.AccessGroupProfiles.Administrator))
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroupProfiles.DeletionMark)
	|			AND (&AccessGroupFilterCriterion1)
	|			AND (TRUE IN
	|				(SELECT TOP 1
	|					TRUE AS TrueValue
	|				FROM
	|					Catalog.AccessGroups.Users AS AccessGroupsMembers
	|				WHERE
	|					AccessGroupsMembers.Ref = AccessGroups.Ref))
	|
	|INDEX BY
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessGroups.Profile AS Ref
	|INTO Profiles
	|FROM
	|	AccessGroups AS AccessGroups
	|
	|INDEX BY
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfileRoles.Ref AS Profile,
	|	RolesRights.MetadataObject AS Table,
	|	RolesRights.MetadataObject.EmptyRefValue AS TableType,
	|	MAX(RolesRights.Update) AS Update,
	|	MAX(RolesRights.Update)
	|		AND MAX(RolesRights.Insert) AS Insert,
	|	MAX(RolesRights.ReadWithoutRestriction) AS ReadWithoutRestriction,
	|	MAX(RolesRights.UpdateWithoutRestriction) AS UpdateWithoutRestriction,
	|	MAX(RolesRights.UpdateWithoutRestriction)
	|		AND MAX(RolesRights.InsertWithoutRestriction) AS InsertWithoutRestriction
	|INTO ProfileTables
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|		INNER JOIN Profiles AS Profiles
	|		ON (Profiles.Ref = ProfileRoles.Ref)
	|		INNER JOIN RolesRights AS RolesRights
	|		ON (&TableFilterCriterion1)
	|			AND (RolesRights.Role = ProfileRoles.Role)
	|			AND (NOT RolesRights.Role.DeletionMark)
	|			AND (NOT RolesRights.MetadataObject.DeletionMark)
	|
	|GROUP BY
	|	ProfileRoles.Ref,
	|	RolesRights.MetadataObject,
	|	RolesRights.MetadataObject.EmptyRefValue
	|
	|INDEX BY
	|	RolesRights.MetadataObject
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfileTables.Table AS Table,
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileTables.Update AS Update,
	|	ProfileTables.Insert AS Insert,
	|	ProfileTables.ReadWithoutRestriction AS ReadWithoutRestriction,
	|	ProfileTables.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|	ProfileTables.InsertWithoutRestriction AS InsertWithoutRestriction,
	|	ProfileTables.TableType AS TableType
	|INTO NewData
	|FROM
	|	ProfileTables AS ProfileTables
	|		INNER JOIN AccessGroups AS AccessGroups
	|		ON (AccessGroups.Profile = ProfileTables.Profile)
	|
	|INDEX BY
	|	ProfileTables.Table,
	|	AccessGroups.Ref";
	
	QueryText =
	"SELECT
	|	NewData.Table,
	|	NewData.AccessGroup,
	|	NewData.Update,
	|	NewData.Insert,
	|	NewData.ReadWithoutRestriction,
	|	NewData.UpdateWithoutRestriction,
	|	NewData.InsertWithoutRestriction,
	|	NewData.TableType,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("Table",       "&TableFilterCriterion2"));
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion2"));
	Fields.Add(New Structure("Update"));
	Fields.Add(New Structure("Insert"));
	Fields.Add(New Structure("ReadWithoutRestriction"));
	Fields.Add(New Structure("UpdateWithoutRestriction"));
	Fields.Add(New Structure("InsertWithoutRestriction"));
	Fields.Add(New Structure("TableType"));
	
	Query = New Query;
	Query.SetParameter("ExtensionsRolesRights", AccessManagementInternal.ExtensionsRolesRights());
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessGroupsTables", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, Tables, "Tables",
		"&TableFilterCriterion1:RolesRights.MetadataObject
		|&TableFilterCriterion2:OldData.Table");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref
		|&AccessGroupFilterCriterion2:OldData.AccessGroup");
		
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.AccessGroupsTables");
	
	BeginTransaction();
	Try
		Lock.Lock();
		Results = BlankRecordsQuery.ExecuteBatch();
		If Not Results[0].IsEmpty() Then
			StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
			RecordSet = CreateRecordSet();
			RecordSet.Filter.Table.Set(Catalogs.MetadataObjectIDs.EmptyRef());
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		If Not Results[1].IsEmpty() Then
			StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
			RecordSet = CreateRecordSet();
			RecordSet.Filter.AccessGroup.Set(Catalogs.AccessGroups.EmptyRef());
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		
		If AccessGroups <> Undefined
		   AND Tables        = Undefined Then
			
			FilterDimensions = "AccessGroup";
		Else
			FilterDimensions = Undefined;
		EndIf;
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.AccessGroupsTables);
		Data.Insert("EditStringContent", Query.Execute().Unload());
		Data.Insert("FilterDimensions",       FilterDimensions);
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateInformationRegister(Data, HasCurrentChanges);
		If HasCurrentChanges Then
			StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
			HasChanges = True;
		EndIf;
		
		If HasCurrentChanges
		   AND AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
			
			// Scheduling access update.
			ChangesContent = Data.EditStringContent.Copy(, "Table");
			ChangesContent.GroupBy("Table");
			AccessManagementInternal.ScheduleAccessUpdateOnChangeAccessGroupsTables(ChangesContent);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf
