#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification data processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	AttributesToSkip = New Array;
	AttributesToSkip.Add("UsersType");
	AttributesToSkip.Add("User");
	AttributesToSkip.Add("MainSuppliedProfileAccessGroup");
	AttributesToSkip.Add("AccessKinds.*");
	AttributesToSkip.Add("AccessValues.*");
	
	Return AttributesToSkip;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	IsFolder
	|	OR Profile <> Value(Catalog.AccessGroupProfiles.Administrator)
	|	  AND IsAuthorizedUser(EmployeeResponsible)";

EndProcedure

// End StandardSubsystems.AccessManagement

// SaaSTechnology.ExportImportData

// See DataExportImportOverridable.OnRegisterDataExportHandlers. 
Procedure BeforeExportObject(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel) Export
	
	AccessManagementInternal.BeforeExportObject(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel);
	
EndProcedure

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	
	Fields.Add("Description");
	Fields.Add("User");
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	If Not ValueIsFilled(Data.User) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	Presentation = AccessManagementInternalClientServer.PresentationAccessGroups(Data);
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Sets a deletion mark for access groups if the deletion mark is set for the access group profile.
//  It is required, for example, upon deleting the predefined profiles of access groups, since the 
// platform does not call object handlers when setting the deletion mark for former predefined items 
// upon the database configuration update.
// 
// 
//
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure MarkForDeletionSelectedProfilesAccessGroups(HasChanges = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile <> VALUE(Catalog.AccessGroupProfiles.Administrator)
	|	AND AccessGroups.Profile.DeletionMark
	|	AND NOT AccessGroups.DeletionMark
	|	AND NOT AccessGroups.Predefined";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		AccessGroupObject = Selection.Ref.GetObject();
		AccessGroupObject.DeletionMark = True;
		InfobaseUpdate.WriteObject(AccessGroupObject);
		InformationRegisters.AccessGroupsTables.UpdateRegisterData(Selection.Ref);
		InformationRegisters.AccessGroupsValues.UpdateRegisterData(Selection.Ref);
		UsersForUpdate = UsersForRolesUpdate(Undefined, AccessGroupObject);
		AccessManagement.UpdateUserRoles(UsersForUpdate);
		HasChanges = True;
	EndDo;
	
EndProcedure

// Updates access kinds of access groups for the specified profile.
//  It is possible not to remove access kinds from the access group,
// which are deleted in the access group profile, if access values are assigned in the access group 
// by the type of access to be deleted.
// 
// 
// Parameters:
//  Profile - CatalogRef.AccessGroupsProfiles - an access group profile.
//
//  UpdatingAccessGroupsWithObsoleteSettings - Boolean - update access groups.
//
// Returns:
//  Boolean - if True, an access group is changed, if False, nothing is changed.
//           
//
Function UpdateProfileAccessGroups(Profile, UpdatingAccessGroupsWithObsoleteSettings = False) Export
	
	AccessGroupUpdated = False;
	
	ProfileAccessKinds = Common.ObjectAttributeValue(Profile, "AccessKinds").Unload();
	Index = ProfileAccessKinds.Count() - 1;
	While Index >= 0 Do
		Row = ProfileAccessKinds[Index];
		
		Filter = New Structure("AccessKind", Row.AccessKind);
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(Row.AccessKind);
		
		If AccessKindProperties = Undefined Then
			ProfileAccessKinds.Delete(Row);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	NOT(AccessGroups.Profile <> &Profile
	|				AND NOT(&Profile = VALUE(Catalog.AccessGroupProfiles.Administrator)
	|						AND AccessGroups.Ref = VALUE(Catalog.AccessGroups.Administrators)))";
	
	Query.SetParameter("Profile", Profile.Ref);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		// Checking if an access group must or can be updated.
		AccessGroup = Selection.Ref.GetObject();
		
		If AccessGroup.Ref = Administrators
		   AND AccessGroup.Profile <> Catalogs.AccessGroupProfiles.Administrator Then
			// Setting the Administrator profile if it is not set.
			AccessGroup.Profile = Catalogs.AccessGroupProfiles.Administrator;
		EndIf;
		
		// Checking access kind content.
		AccessKindsContentChanged = False;
		HasAccessKindsToDeleteWithSpecifiedAccessValues = False;
		If AccessGroup.AccessKinds.Count() <> ProfileAccessKinds.FindRows(New Structure("PresetAccessKind", False)).Count() Then
			AccessKindsContentChanged = True;
		Else
			For each AccessKindRow In AccessGroup.AccessKinds Do
				If ProfileAccessKinds.FindRows(New Structure("AccessKind, PresetAccessKind", AccessKindRow.AccessKind, False)).Count() = 0 Then
					AccessKindsContentChanged = True;
					If AccessGroup.AccessValues.Find(AccessKindRow.AccessKind, "AccessKind") <> Undefined Then
						HasAccessKindsToDeleteWithSpecifiedAccessValues = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
		
		If AccessKindsContentChanged
		   AND ( UpdatingAccessGroupsWithObsoleteSettings
		       OR NOT HasAccessKindsToDeleteWithSpecifiedAccessValues ) Then
			// Updating an access group.
			// 1. Deleting unused access kinds and access values (if any).
			CurrentRowNumber = AccessGroup.AccessKinds.Count()-1;
			While CurrentRowNumber >= 0 Do
				CurrentAccessKind = AccessGroup.AccessKinds[CurrentRowNumber].AccessKind;
				If ProfileAccessKinds.FindRows(New Structure("AccessKind, PresetAccessKind", CurrentAccessKind, False)).Count() = 0 Then
					AccessKindValuesRows = AccessGroup.AccessValues.FindRows(New Structure("AccessKind", CurrentAccessKind));
					For each ValueRow In AccessKindValuesRows Do
						AccessGroup.AccessValues.Delete(ValueRow);
					EndDo;
					AccessGroup.AccessKinds.Delete(CurrentRowNumber);
				EndIf;
				CurrentRowNumber = CurrentRowNumber - 1;
			EndDo;
			// 2. Adding new access kinds (if any).
			For each AccessKindRow In ProfileAccessKinds Do
				If NOT AccessKindRow.PresetAccessKind 
				   AND AccessGroup.AccessKinds.Find(AccessKindRow.AccessKind, "AccessKind") = Undefined Then
					
					NewRow = AccessGroup.AccessKinds.Add();
					NewRow.AccessKind   = AccessKindRow.AccessKind;
					NewRow.AllAllowed = AccessKindRow.AllAllowed;
				EndIf;
			EndDo;
		EndIf;
		
		If AccessGroup.Modified() Then
			
			If Not InfobaseUpdate.InfobaseUpdateInProgress()
			   AND Not InfobaseUpdate.IsCallFromUpdateHandler() Then
				
				LockDataForEdit(AccessGroup.Ref, AccessGroup.DataVersion);
			EndIf;
			
			AccessGroup.AdditionalProperties.Insert("DoNotUpdateUsersRoles");
			InfobaseUpdate.WriteObject(AccessGroup);
			AccessGroupUpdated = True;
			
			If Not InfobaseUpdate.InfobaseUpdateInProgress()
			   AND Not InfobaseUpdate.IsCallFromUpdateHandler() Then
				
				UnlockDataForEdit(AccessGroup.Ref);
			EndIf;
			
		EndIf;
	EndDo;
	
	Return AccessGroupUpdated;
	
EndFunction

// Returns a reference to a parent group of personal access groups.
//  If the parent group is not found, it will be created.
//
// Parameters:
//  DoNotCreate - Boolean, if True, the parent is not automatically created and the function returns 
//                 Undefined if the parent is not found.
//
// Returns:
//  CatalogRef.AccessGroups - a parent group reference.
//
Function PersonalAccessGroupsParent(Val DoNotCreate = False, ItemsGroupDescription = Undefined) Export
	
	SetPrivilegedMode(True);
	
	ItemsGroupDescription = NStr("ru = 'Персональные группы доступа'; en = 'Personal access groups'; pl = 'Osobiste grupy dostępu';es_ES = 'Grupos de acceso personal';es_CO = 'Grupos de acceso personal';tr = 'Kişisel erişim grupları';it = 'Gruppi personali di accesso';de = 'Persönliche Zugriffsgruppen'");
	
	Query = New Query;
	Query.SetParameter("ItemsGroupDescription", ItemsGroupDescription);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Description LIKE &ItemsGroupDescription
	|	AND AccessGroups.IsFolder";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ItemsGroup = Selection.Ref;
	ElsIf DoNotCreate Then
		ItemsGroup = Undefined;
	Else
		ItemsGroupObject = CreateFolder();
		ItemsGroupObject.Description = ItemsGroupDescription;
		ItemsGroupObject.Write();
		ItemsGroup = ItemsGroupObject.Ref;
	EndIf;
	
	Return ItemsGroup;
	
EndFunction

Function AccessKindsOrAccessValuesChanged(PreviousValues, CurrentObject) Export
	
	If PreviousValues.Ref <> CurrentObject.Ref Then
		Return True;
	EndIf;
	
	AccessKinds     = PreviousValues.AccessKinds.Unload();
	AccessValues = PreviousValues.AccessValues.Unload();
	
	If AccessKinds.Count()     <> CurrentObject.AccessKinds.Count()
	 Or AccessValues.Count() <> CurrentObject.AccessValues.Count() Then
		
		Return True;
	EndIf;
	
	Filter = New Structure("AccessKind, AllAllowed");
	For Each Row In CurrentObject.AccessKinds Do
		FillPropertyValues(Filter, Row);
		If AccessKinds.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Filter = New Structure("AccessKind, AccessValue");
	For Each Row In CurrentObject.AccessValues Do
		FillPropertyValues(Filter, Row);
		If AccessValues.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function UsersForRolesUpdate(PreviousValues, DataItem) Export
	
	If PreviousValues = Undefined Then
		PreviousValues = New Structure("Ref, Profile, DeletionMark")
	EndIf;
	
	// Updating roles for added, remaining, and removed users.
	Query = New Query;
	
	Query.SetParameter("NewMembers", ?(TypeOf(DataItem) <> Type("ObjectDeletion"),
		DataItem.Users.UnloadColumn("User"), New Array));
	
	Query.SetParameter("OldMembers", ?(DataItem.Ref = PreviousValues.Ref,
		PreviousValues.Users.Unload().UnloadColumn("User"), New Array));
	
	If TypeOf(DataItem)         =  Type("ObjectDeletion")
	 Or DataItem.Profile         <> PreviousValues.Profile
	 Or DataItem.DeletionMark <> PreviousValues.DeletionMark Then
		
		// Selecting all access group members.
		Query.Text =
		"SELECT DISTINCT
		|	UserGroupCompositions.User AS User
		|FROM
		|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|WHERE
		|	(UserGroupCompositions.UsersGroup IN (&OldMembers)
		|			OR UserGroupCompositions.UsersGroup IN (&NewMembers))";
	Else
		// Selecting changes of access group members.
		Query.Text =
		"SELECT
		|	Data.User AS User
		|FROM
		|	(SELECT DISTINCT
		|		UserGroupCompositions.User AS User,
		|		-1 AS RowChangeKind
		|	FROM
		|		InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|	WHERE
		|		UserGroupCompositions.UsersGroup IN(&OldMembers)
		|	
		|	UNION ALL
		|	
		|	SELECT DISTINCT
		|		UserGroupCompositions.User,
		|		1
		|	FROM
		|		InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|	WHERE
		|		UserGroupCompositions.UsersGroup IN(&NewMembers)) AS Data
		|
		|GROUP BY
		|	Data.User
		|
		|HAVING
		|	SUM(Data.RowChangeKind) <> 0";
	EndIf;
	
	Return Query.Execute().Unload().UnloadColumn("User");
	
EndFunction

Function UsersForRolesUpdateByProfile(Profiles) Export
	
	Query = New Query;
	Query.SetParameter("Profiles", Profiles);
	
	Query.Text =
	"SELECT DISTINCT
	|	UserGroupCompositions.User AS User
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON UserGroupCompositions.UsersGroup = AccessGroupsUsers.User
	|			AND (AccessGroupsUsers.Ref.Profile IN (&Profiles))";
	
	Return Query.Execute().Unload().UnloadColumn("User");
	
EndFunction

Function ProfileAccessGroups(Profiles) Export
	
	Query = New Query;
	Query.SetParameter("Profiles", Profiles);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile IN(&Profiles)
	|	AND NOT AccessGroups.IsFolder";
	QueryResult = Query.Execute();
	
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

Procedure RegisterRefs(RefsKind, Val RefsToAdd) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	RefsKindProperties = RefsKindProperties(RefsKind);
	
	SetPrivilegedMode(True);
	References = StandardSubsystemsServer.ApplicationParameter(
		RefsKindProperties.ApplicationParameterName);
	SetPrivilegedMode(False);
	
	If TypeOf(References) <> Type("Array") Then
		References = New Array;
	EndIf;
	
	HasChanges = False;
	If RefsToAdd = Null Then
		If References.Count() > 0 Then
			References = New Array;
			HasChanges = True;
		EndIf;
		
	ElsIf References.Count() = 1
	        AND References[0] = Undefined Then
		
		Return; // Previously more than 300 references were added.
	Else
		If TypeOf(RefsToAdd) <> Type("Array") Then
			RefsToAdd = CommonClientServer.ValueInArray(RefsToAdd);
		EndIf;
		For Each RefToAdd In RefsToAdd Do
			If References.Find(RefToAdd) <> Undefined Then
				Continue;
			EndIf;
			References.Add(RefToAdd);
			HasChanges = True;
		EndDo;
		If References.Count() > 300 Then
			References = New Array;
			References.Add(Undefined);
			HasChanges = True;
		EndIf;
	EndIf;
	
	If Not HasChanges Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	StandardSubsystemsServer.SetApplicationParameter(
		RefsKindProperties.ApplicationParameterName, References);
	SetPrivilegedMode(False);
	
EndProcedure

Function RegisteredRefs(RefsKind) Export
	
	If Common.DataSeparationEnabled() Then
		Return New Array;
	EndIf;
	
	RefsKindProperties = RefsKindProperties(RefsKind);
	
	SetPrivilegedMode(True);
	References = StandardSubsystemsServer.ApplicationParameter(
		RefsKindProperties.ApplicationParameterName);
	SetPrivilegedMode(False);
	
	If TypeOf(References) <> Type("Array") Then
		References = New Array;
	EndIf;
	
	If References.Count() = 1
	   AND References[0] = Undefined Then
		
		Return References;
	EndIf;
	
	CheckedRefs = New Array;
	For Each Ref In References Do
		If RefsKindProperties.ValidTypes.ContainsType(TypeOf(Ref)) Then
			CheckedRefs.Add(Ref);
		EndIf;
	EndDo;
	
	Return CheckedRefs;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to support data exchange in DIB.

// For internal use only.
Procedure RestoreAdministratorsAccessGroupMembers(DataItem) Export
	
	If DataItem.PredefinedDataName <> "Administrators" Then
		Return;
	EndIf;
	
	DataItem.Users.Clear();
	
	Query = New Query;
	Query.SetParameter("PredefinedDataName", "Administrators");
	Query.Text =
	"SELECT DISTINCT
	|	AccessGroupsUsers.User
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref.PredefinedDataName = &PredefinedDataName";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If DataItem.Users.Find(Selection.User, "User") = Undefined Then
			DataItem.Users.Add().User = Selection.User;
		EndIf;
	EndDo;
	
EndProcedure

// For internal use only.
Procedure DeleteMembersOfAdministratorsAccessGroupWithoutIBUser() Export
	
	AdministratorsAccessGroup = Administrators.GetObject();
	
	Index = AdministratorsAccessGroup.Users.Count() - 1;
	While Index >= 0 Do
		CurrentUser = AdministratorsAccessGroup.Users[Index].User;
		If TypeOf(CurrentUser) = Type("CatalogRef.Users") Then
			IBUserID = Common.ObjectAttributeValue(CurrentUser,
				"IBUserID");
		Else
			IBUserID = Undefined;
		EndIf;
		If TypeOf(IBUserID) = Type("UUID") Then
			InfobaseUser = InfoBaseUsers.FindByUUID(
				IBUserID);
		Else
			InfobaseUser = Undefined;
		EndIf;
		If InfobaseUser = Undefined Then
			AdministratorsAccessGroup.Users.Delete(Index);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	If AdministratorsAccessGroup.Modified() Then
		AdministratorsAccessGroup.Write();
	EndIf;
	
EndProcedure


// For internal use only.
Procedure RegisterAccessGroupChangedOnImport(DataItem) Export
	
	PreviousValues = Common.ObjectAttributesValues(DataItem.Ref,
		"Ref, Profile, DeletionMark, Users, AccessKinds, AccessValues");
	
	RegistrationRegistration = False;
	AccessGroup = DataItem.Ref;
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		RegistrationRegistration = True;
		
	ElsIf PreviousValues.Ref <> DataItem.Ref Then
		RegistrationRegistration = True;
		AccessGroup = UsersInternal.ObjectRef(DataItem);
	
	ElsIf DataItem.DeletionMark <> PreviousValues.DeletionMark
	      Or DataItem.Profile         <> PreviousValues.Profile Then
		
		RegistrationRegistration = True;
	Else
		HasMembers = DataItem.Users.Count() <> 0;
		HasOldMembers = Not PreviousValues.Users.IsEmpty();
		
		If HasMembers <> HasOldMembers
		 Or AccessKindsOrAccessValuesChanged(PreviousValues, DataItem) Then
			
			RegistrationRegistration = True;
		EndIf;
	EndIf;
	
	If RegistrationRegistration Then
		RegisterRefs("AccessGroups", AccessGroup);
	EndIf;
	
	UsersForUpdate = UsersForRolesUpdate(PreviousValues, DataItem);
	
	RegisterRefs("Users", UsersForUpdate);
	
EndProcedure

// For internal use only.
Procedure UpdateAccessGroupsAuxiliaryDataChangedOnImport() Export
	
	If Common.DataSeparationEnabled() Then
		// Changes of the access groups in SWP are blocked and are not imported into the data area.
		Return;
	EndIf;
	
	ChangedAccessGroups = RegisteredRefs("AccessGroups");
	If ChangedAccessGroups.Count() = 0 Then
		Return;
	EndIf;
	
	If ChangedAccessGroups.Count() = 1
	   AND ChangedAccessGroups[0] = Undefined Then
		
		InformationRegisters.AccessGroupsTables.UpdateRegisterData();
		InformationRegisters.AccessGroupsValues.UpdateRegisterData();
	Else
		InformationRegisters.AccessGroupsTables.UpdateRegisterData(ChangedAccessGroups);
		InformationRegisters.AccessGroupsValues.UpdateRegisterData(ChangedAccessGroups);
	EndIf;
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		AccessManagementInternal.ScheduleAccessGroupsSetsUpdate();
	EndIf;
	
	RegisterRefs("AccessGroups", Null);
	
EndProcedure

// For internal use only.
Procedure RegisterUsersOfUserGroupChangedOnImport(DataItem) Export
	
	PreviousValues = Common.ObjectAttributesValues(DataItem.Ref,
		"Ref, DeletionMark, Content");
	
	AttributeName = ?(TypeOf(DataItem.Ref) = Type("CatalogRef.ExternalUsersGroups"),
		"ExternalUser", "User");
	
	If PreviousValues.Ref = DataItem.Ref Then
		OldUsers = PreviousValues.Content.Unload().UnloadColumn(AttributeName);
	Else
		OldUsers = New Array;
	EndIf;
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		UsersForUpdate = OldUsers;
	Else
		NewUsers = DataItem.Content.UnloadColumn(AttributeName);
		
		If PreviousValues.Ref <> DataItem.Ref Then
			UsersForUpdate = NewUsers;
		Else
			UsersForUpdate = New Array;
			All = DataItem.DeletionMark <> PreviousValues.DeletionMark;
			
			For Each User In OldUsers Do
				If All Or NewUsers.Find(User) = Undefined Then
					UsersForUpdate.Add(User);
				EndIf;
			EndDo;
			
			For Each User In NewUsers Do
				If All Or OldUsers.Find(User) = Undefined Then
					UsersForUpdate.Add(User);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If UsersForUpdate.Count() > 0 Then
		RegisterRefs("UserGroups",
			UsersInternal.ObjectRef(DataItem));
	EndIf;
	
	RegisterRefs("Users", UsersForUpdate);
	
EndProcedure

// For internal use only.
Procedure UpdateAuxiliaryDataOfUserGroupsChangedOnImport() Export
	
	If Common.DataSeparationEnabled() Then
		// Changes of the access groups in SWP are blocked and are not imported into the data area.
		Return;
	EndIf;
	
	ChangedUserGroups = RegisteredRefs("UserGroups");
	If ChangedUserGroups.Count() = 0 Then
		Return;
	EndIf;
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		AccessManagementInternal.ScheduleAccessGroupsSetsUpdate();
	EndIf;
	
	RegisterRefs("UserGroups", Null);
	
EndProcedure

// For internal use only.
Procedure RegisterUserChangedOnImport(DataItem) Export
	
	PreviousValues = Common.ObjectAttributesValues(DataItem.Ref,
		"Ref, DeletionMark, Invalid");
	
	RegistrationRegistration = False;
	User = DataItem.Ref;
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		RegistrationRegistration = True;
		
	ElsIf PreviousValues.Ref <> DataItem.Ref Then
		RegistrationRegistration = True;
		User = UsersInternal.ObjectRef(DataItem);
	
	ElsIf DataItem.Invalid <> PreviousValues.Invalid
		 Or DataItem.DeletionMark <> PreviousValues.DeletionMark Then
			
		RegistrationRegistration = True;
	EndIf;
	
	If Not RegistrationRegistration Then
		Return;
	EndIf;
	
	RegisterRefs("UserGroups",
		?(TypeOf(DataItem.Ref) = Type("CatalogRef.Users"),
			Catalogs.UserGroups.AllUsers,
			Catalogs.ExternalUsersGroups.AllExternalUsers));
	
	RegisterRefs("Users", User);
	
EndProcedure

// For internal use only.
Procedure UpdateUsersRolesChangedOnImport() Export
	
	If Common.DataSeparationEnabled() Then
		// Changes to profiles in SWP are blocked and are not imported into the data area.
		Return;
	EndIf;
	
	ChangedUsers = RegisteredRefs("Users");
	If ChangedUsers.Count() = 0 Then
		Return;
	EndIf;
	
	If ChangedUsers.Count() = 1
	   AND ChangedUsers[0] = Undefined Then
		
		AccessManagement.UpdateUserRoles();
	Else
		AccessManagement.UpdateUserRoles(ChangedUsers);
	EndIf;
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		AccessManagementInternal.ScheduleAccessGroupsSetsUpdate();
	EndIf;
	
	RegisterRefs("Users", Null);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

Procedure FillAdministratorsAccessGroupProfile() Export
	
	Object = Administrators.GetObject();
	If Object.Profile <> Catalogs.AccessGroupProfiles.Administrator Then
		Object.Profile = Catalogs.AccessGroupProfiles.Administrator;
		InfobaseUpdate.WriteData(Object);
	EndIf;
	
EndProcedure

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups";
	
	InfobaseUpdate.MarkForProcessing(Parameters,
		Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, "Catalog.AccessGroups");
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	AccessGroupProcessingErrorTemplate =
		NStr("ru = 'Не удалось обработать группу доступа ""%1"" по причине:
		           |%2'; 
		           |en = 'Cannot process the ""%1"" access group due to:
		           |%2'; 
		           |pl = 'Nie udało się przetworzyć grupę dostępu ""%1"" z powodu:
		           |%2';
		           |es_ES = 'No se ha podido procesar el grupo de acceso ""%1"" a causa de:
		           |%2';
		           |es_CO = 'No se ha podido procesar el grupo de acceso ""%1"" a causa de:
		           |%2';
		           |tr = 'Erişim grubu ""%1"" aşağıdaki nedenle işlenemedi: 
		           |%2';
		           |it = 'Non è possibile elaborare il gruppo di accesso ""%1"" a causa di:
		           |%2';
		           |de = 'Die Zugriffsgruppe ""%1"" konnte aus diesem Grund nicht bearbeitet werden:
		           |%2'");
	AccessGroupsTablesUpdateErrorTemplate =
		NStr("ru = 'Не удалось обновить таблицы группы доступа ""%1"" по причине:
		           |%2'; 
		           |en = 'Cannot update the ""%1"" access group tables due to:
		           |%2'; 
		           |pl = 'Aktualizacja tabeli dostępu ""%1"" nie powiodła się z powodu:
		           |%2';
		           |es_ES = 'No se ha podido actualizar las tablas del grupo de acceso ""%1"" a causa de:
		           |%2';
		           |es_CO = 'No se ha podido actualizar las tablas del grupo de acceso ""%1"" a causa de:
		           |%2';
		           |tr = 'Erişim grubu ""%1"" aşağıdaki nedenle güncellenemedi: 
		           |%2';
		           |it = 'Non è possibile aggiornare la tabella gruppo di accesso ""%1"" a causa di:
		           |%2';
		           |de = 'Die Zugriffsgruppentabellen ""%1"" konnten aus diesem Grund nicht aktualisiert werden:
		           |%2'");
	AccessGroupsValuesUpdateErrorTemplate =
		NStr("ru = 'Не удалось обновить значения доступа группы доступа ""%1"" по причине:
		           |%2'; 
		           |en = 'Cannot update access values of the ""%1"" access group due to:
		           |%2'; 
		           |pl = 'Aktualizacja wartości dostępu grupy dostępu ""%1"" nie powiodła się z powodu:
		           |%2';
		           |es_ES = 'No se ha podido actualizar los valores de acceso del grupo de acceso ""%1"" a causa de:
		           |%2';
		           |es_CO = 'No se ha podido actualizar los valores de acceso del grupo de acceso ""%1"" a causa de:
		           |%2';
		           |tr = 'Erişim grubun ""%1"" erişim değerleri aşağıdaki nedenle güncellenemedi: 
		           |%2';
		           |it = 'Impossibile aggiornare i valori di accesso per il gruppo di accesso ""%1"" a causa di:
		           |%2';
		           |de = 'Die Zugriffswerte der Zugriffsgruppe ""%1"" konnten aus diesem Grund nicht aktualisiert werden:
		           |%2'");
	
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog.AccessGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	While Selection.Next() Do
		LockItem.SetValue("Ref", Selection.Ref);
		
		BeginTransaction();
		Try
			ErrorTemplate = AccessGroupProcessingErrorTemplate;
			Lock.Lock();
			
			ErrorTemplate = AccessGroupsTablesUpdateErrorTemplate;
			InformationRegisters.AccessGroupsTables.UpdateRegisterData(Selection.Ref);
			
			ErrorTemplate = AccessGroupsValuesUpdateErrorTemplate;
			InformationRegisters.AccessGroupsValues.UpdateRegisterData(Selection.Ref);
			
			ErrorTemplate = AccessGroupProcessingErrorTemplate;
			CommitTransaction();
		Except
			RollbackTransaction();
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			ErrorInformation = ErrorInfo();
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				String(Selection.Ref),
				DetailErrorDescription(ErrorInformation));
			
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning, , , MessageText);
			Continue;
		EndTry;
		
		InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
		ObjectsProcessed = ObjectsProcessed + 1;
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "Catalog.AccessGroups") Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедуре Catalogs.AccessGroups.ProcessDataForMigrationToNewVersion не удалось
			           |обновить вспомогательные данные некоторых групп доступа (пропущены): %1'; 
			           |en = 'Procedure Catalogs.AccessGroups.ProcessDataForMigrationToNewVersion cannot
			           |update auxiliary data of some access groups (these groupos are skipped):%1'; 
			           |pl = 'Procedurze Catalogs.AccessGroups.ProcessDataForMigrationToNewVersion nie udało się
			           |zaktualizować danych należności niektórych grup dostępu (pominięte): %1';
			           |es_ES = 'El procedimiento Catalogs.AccessGroups.ProcessDataForMigrationToNewVersion no ha podido
			           |actualizar los datos auxiliares de unos grupos de acceso (saltados): %1';
			           |es_CO = 'El procedimiento Catalogs.AccessGroups.ProcessDataForMigrationToNewVersion no ha podido
			           |actualizar los datos auxiliares de unos grupos de acceso (saltados): %1';
			           |tr = 'Catalogs.AccessGroups.ProcessDataForMigrationToNewVersion prosedürü
			           |bazı erişim grupların yardımcı verilerini güncelleyemedi (bu gruplar atlandı):%1';
			           |it = 'La procedura Catalogs.AccessGroups.ProcessDataForMigrationToNewVersion 
			           |non può aggiornare i dati ausiliari di alcuni gruppi di accesso (questi gruppi saranno saltati):%1';
			           |de = 'Die Prozedur Catalogs.AccessGroups.ProcessDataForMigrationToNewVersion kann die Hilfsdaten einiger Zugriffsgruppen nicht
			           | aktualisieren (diese Gruppen werden übersprungen): %1'"), 
			ObjectsWithIssuesCount);
		
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information,
			Metadata.FindByFullName("Catalog.AccessGroups"),,
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедура Catalogs.AccessGroups.ProcessDataforMigrationToNewVersion
			           |обработала очередную порцию групп доступа: %1'; 
			           |en = 'The Catalogs.AccessGroups.ProcessDataforMigrationToNewVersion procedure 
			           |has processed access groups: %1'; 
			           |pl = 'Procedura Catalogs.AccessGroups.ProcessDataforMigrationToNewVersion
			           |przetworzyła kolejną partię grup dostępu: %1';
			           |es_ES = 'El procedimiento Catalogs.AccessGroups.ProcessDataforMigrationToNewVersion 
			           |ha procesado grupos de acceso:%1';
			           |es_CO = 'El procedimiento Catalogs.AccessGroups.ProcessDataforMigrationToNewVersion 
			           |ha procesado grupos de acceso:%1';
			           |tr = 'Catalogs.AccessGroups.ProcessDataforMigrationToNewVersion prosedürü, 
			           |sıradaki erişim grupların partisini işledi: %1';
			           |it = 'La procedura Catalogs.AccessGroups.ProcessDataforMigrationToNewVersion 
			           |ha elaborato i gruppi di accesso: %1';
			           |de = 'Prozedur Catalogs.AccessGroups.ProcessDataforMigrationToNewVersion
			           |hat einen weiteren Teil von Zugriffsgruppen verarbeitet: %1'"),
		ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For the RegisteredRefs function and the RegisteredRefs procedure.
Function RefsKindProperties(RefsKind)
	
	If RefsKind = "Profiles" Then
		AllowedTypes = New TypeDescription("CatalogRef.AccessGroupProfiles");
		ApplicationParameterName = "StandardSubsystems.AccessManagement.ProfilesChangedOnImport";
		
	ElsIf RefsKind = "AccessGroups" Then
		AllowedTypes = New TypeDescription("CatalogRef.AccessGroups");
		ApplicationParameterName = "StandardSubsystems.AccessManagement.AccessGroupsModifiedOnImport";
		
	ElsIf RefsKind = "UserGroups" Then
		AllowedTypes = New TypeDescription("CatalogRef.UserGroups,CatalogRef.ExternalUsersGroups");
		ApplicationParameterName = "StandardSubsystems.AccessManagement.UserGroupsModifiedOnImport";
		
	ElsIf RefsKind = "Users" Then
		AllowedTypes = New TypeDescription("CatalogRef.Users,CatalogRef.ExternalUsers");
		ApplicationParameterName = "StandardSubsystems.AccessManagement.UsersChangedOnImport";
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Недопустимое значение ""%1"" параметра RefsKind функции RefsKindProperties.'; en = 'Invalid value ""%1"" of the RefsKind parameter of the RefsKindProperties function.'; pl = 'Niedopuszczalna wartość ""%1"" parametru RefsKind funkcji RefsKindProperties.';es_ES = 'Valor no admitido ""%1"" del parámetro RefsKind de la función RefsKindProperties.';es_CO = 'Valor no admitido ""%1"" del parámetro RefsKind de la función RefsKindProperties.';tr = 'RefsKindProperties işlevin RefsKind parametresinin ""%1"" izin verilmeyen değeri.';it = 'Valore ""%1"" del parametro TipoLink della funzione ParametriTipiLink non è valido.';de = 'Ungültiger Wert ""%1"" des Parameters RefsKind der Funktion RefsKindProperties.'"),
			RefsKind);
	EndIf;
	
	Return New Structure("ValidTypes, ApplicationParameterName", AllowedTypes, ApplicationParameterName);
	
EndFunction

#EndRegion

#EndIf
