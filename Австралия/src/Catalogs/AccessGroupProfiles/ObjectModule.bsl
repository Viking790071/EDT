#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var PreviousValues; // Values of some attributes and tabular sections of the profile before it is changed for use in the 
                      // OnWrite event handler.

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	InformationRegisters.RolesRights.CheckRegisterData();
	
	PreviousValues = Common.ObjectAttributesValues(Ref,
		"Ref, DeletionMark, Roles, Purpose, AccessKinds, AccessValues");
	
	// Checking roles.
	AdministratorRoles = New Array;
	AdministratorRoles.Add("Role.FullRights");
	AdministratorRoles.Add("Role.SystemAdministrator");
	RoleIDs = Common.MetadataObjectIDs(AdministratorRoles);
	ProcessedRoles = New Map;
	Index = Roles.Count();
	While Index > 0 Do
		Index = Index - 1;
		Role = Roles[Index].Role;
		If ProcessedRoles.Get(Role) <> Undefined Then
			Roles.Delete(Index);
			Continue;
		EndIf;
		ProcessedRoles.Insert(Role, True);
		If Ref = Catalogs.AccessGroupProfiles.Administrator Then
			Continue;
		EndIf;
		If Role = RoleIDs["Role.FullRights"]
		 Or Role = RoleIDs["Role.SystemAdministrator"] Then
			
			Roles.Delete(Index);
		EndIf;
	EndDo;
	
	If Not AdditionalProperties.Property("DoNotUpdateAttributeSuppliedProfileChanged") Then
		SuppliedProfileChanged =
			Catalogs.AccessGroupProfiles.SuppliedProfileChanged(ThisObject);
	EndIf;
	
	InterfaceSimplified = AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
	
	If InterfaceSimplified Then
		// Updating descriptions for personal access groups of this profile (if any).
		Query = New Query;
		Query.SetParameter("Profile",      Ref);
		Query.SetParameter("Description", Description);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &Profile
		|	AND AccessGroups.User <> UNDEFINED
		|	AND AccessGroups.User <> VALUE(Catalog.Users.EmptyRef)
		|	AND AccessGroups.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
		|	AND AccessGroups.Description <> &Description";
		ChangedAccessGroups = Query.Execute().Unload().UnloadColumn("Ref");
		If ChangedAccessGroups.Count() > 0 Then
			For each AccessGroupRef In ChangedAccessGroups Do
				PersonalAccessGroupObject = AccessGroupRef.GetObject();
				PersonalAccessGroupObject.Description = Description;
				PersonalAccessGroupObject.DataExchange.Load = True;
				PersonalAccessGroupObject.Write();
			EndDo;
			AdditionalProperties.Insert(
				"PersonalAccessGroupsWithUpdatedDescription", ChangedAccessGroups);
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	CheckSuppliedDataUniqueness();
	
	// When setting a deletion mark, the deletion mark is also set for the profile access groups.
	If DeletionMark AND PreviousValues.DeletionMark = False Then
		Query = New Query;
		Query.SetParameter("Profile", Ref);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	(NOT AccessGroups.DeletionMark)
		|	AND AccessGroups.Profile = &Profile";
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			LockDataForEdit(Selection.Ref);
			AccessGroupObject = Selection.Ref.GetObject();
			AccessGroupObject.DeletionMark = True;
			AccessGroupObject.Write();
		EndDo;
	EndIf;
	
	If AdditionalProperties.Property("UpdateProfileAccessGroups") Then
		Catalogs.AccessGroups.UpdateProfileAccessGroups(Ref, True);
	EndIf;
	
	TablesContentChangesOnChangeRoles = UpdateUsersRolesOnChangeProfileRoles();
	
	If TablesContentChangesOnChangeRoles.Count() > 0 Then
		ProfileAccessGroups = Catalogs.AccessGroups.ProfileAccessGroups(Ref);
		InformationRegisters.AccessGroupsTables.UpdateRegisterData(ProfileAccessGroups,
			TablesContentChangesOnChangeRoles);
	EndIf;
	
	If Catalogs.AccessGroupProfiles.AccessKindsOrValuesOrAssignmentChanged(PreviousValues, ThisObject)
	 Or DeletionMark <> PreviousValues.DeletionMark Then
		
		If ProfileAccessGroups = Undefined Then
			ProfileAccessGroups = Catalogs.AccessGroups.ProfileAccessGroups(Ref);
		EndIf;
		InformationRegisters.AccessGroupsValues.UpdateRegisterData(ProfileAccessGroups);
	EndIf;
	
	Catalogs.AccessGroupProfiles.UpdateAuxiliaryProfilesDataChangedOnImport();
	Catalogs.AccessGroups.UpdateAccessGroupsAuxiliaryDataChangedOnImport();
	Catalogs.AccessGroups.UpdateUsersRolesChangedOnImport();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("VerifiedObjectAttributes") Then
		Common.DeleteNotCheckedAttributesFromArray(
			CheckedAttributes, AdditionalProperties.VerifiedObjectAttributes);
	EndIf;
	
	CheckSuppliedDataUniqueness(True, Cancel);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If IsFolder Then
		Return;
	EndIf;
	
	If CopiedObject.Ref = Catalogs.AccessGroupProfiles.Administrator Then
		Roles.Clear();
	EndIf;
	
	SuppliedDataID = Undefined;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Function UpdateUsersRolesOnChangeProfileRoles()
	
	Query = New Query;
	Query.SetParameter("Profile", Ref);
	Query.SetParameter("OldProfileRoles", ?(Ref = PreviousValues.Ref,
		PreviousValues.Roles.Unload(), Roles.Unload(New Array)));
	
	Query.Text =
	"SELECT
	|	OldProfileRoles.Role
	|INTO OldProfileRoles
	|FROM
	|	&OldProfileRoles AS OldProfileRoles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Data.Role
	|INTO ModifiedRoles
	|FROM
	|	(SELECT
	|		OldProfileRoles.Role AS Role,
	|		-1 AS RowChangeKind
	|	FROM
	|		OldProfileRoles AS OldProfileRoles
	|	
	|	UNION ALL
	|	
	|	SELECT DISTINCT
	|		NewProfileRoles.Role,
	|		1
	|	FROM
	|		Catalog.AccessGroupProfiles.Roles AS NewProfileRoles
	|	WHERE
	|		NewProfileRoles.Ref = &Profile) AS Data
	|
	|GROUP BY
	|	Data.Role
	|
	|HAVING
	|	SUM(Data.RowChangeKind) <> 0
	|
	|INDEX BY
	|	Data.Role";
	
	QueryText =
	"SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.Insert AS Insert,
	|	ExtensionsRolesRights.Update AS Update,
	|	ExtensionsRolesRights.ReadWithoutRestriction AS ReadWithoutRestriction,
	|	ExtensionsRolesRights.InsertWithoutRestriction AS InsertWithoutRestriction,
	|	ExtensionsRolesRights.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|	ExtensionsRolesRights.View AS View,
	|	ExtensionsRolesRights.InteractiveInsert AS InteractiveInsert,
	|	ExtensionsRolesRights.Edit AS Edit,
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
	|	ExtensionsRolesRights.Insert AS Insert,
	|	ExtensionsRolesRights.Update AS Update,
	|	ExtensionsRolesRights.ReadWithoutRestriction AS ReadWithoutRestriction,
	|	ExtensionsRolesRights.InsertWithoutRestriction AS InsertWithoutRestriction,
	|	ExtensionsRolesRights.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|	ExtensionsRolesRights.View AS View,
	|	ExtensionsRolesRights.InteractiveInsert AS InteractiveInsert,
	|	ExtensionsRolesRights.Edit AS Edit
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
	|	RolesRights.Insert,
	|	RolesRights.Update,
	|	RolesRights.ReadWithoutRestriction,
	|	RolesRights.InsertWithoutRestriction,
	|	RolesRights.UpdateWithoutRestriction,
	|	RolesRights.View,
	|	RolesRights.InteractiveInsert,
	|	RolesRights.Edit
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
	|SELECT DISTINCT
	|	RolesRights.MetadataObject
	|FROM
	|	RolesRights AS RolesRights
	|		INNER JOIN ModifiedRoles AS ModifiedRoles
	|		ON RolesRights.Role = ModifiedRoles.Role";
	
	Query.Text = Query.Text + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|" + QueryText;
	
	Query.SetParameter("ExtensionsRolesRights", AccessManagementInternal.ExtensionsRolesRights());
	QueriesResults = Query.ExecuteBatch();
	
	If NOT AdditionalProperties.Property("DoNotUpdateUsersRoles")
	   AND NOT QueriesResults[1].IsEmpty() Then
		
		UsersForRolesUpdate = Catalogs.AccessGroups.UsersForRolesUpdateByProfile(Ref);
		AccessManagement.UpdateUserRoles(UsersForRolesUpdate);
	EndIf;
	
	Return QueriesResults[4].Unload().UnloadColumn("MetadataObject");
	
EndFunction

Procedure CheckSuppliedDataUniqueness(FillChecking = False, Cancel = False)
	
	// Checking the supplied data for uniqueness.
	If SuppliedDataID <> New UUID("00000000-0000-0000-0000-000000000000") Then
		SetPrivilegedMode(True);
		
		Query = New Query;
		Query.SetParameter("SuppliedDataID", SuppliedDataID);
		Query.Text =
		"SELECT
		|	AccessGroupProfiles.Ref AS Ref,
		|	AccessGroupProfiles.Description AS Description
		|FROM
		|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
		|WHERE
		|	AccessGroupProfiles.SuppliedDataID = &SuppliedDataID";
		
		Selection = Query.Execute().Select();
		If Selection.Count() > 1 Then
			
			BriefErrorPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при записи профиля ""%1"".
				           |Поставляемый профиль уже существует:'; 
				           |en = 'An error occurred when writing profile ""%1"".
				           |Supplied profile already exists:'; 
				           |pl = 'Wystąpił błąd podczas zapisywania profilu ""%1"".
				           |Dostarczony profil już istnieje:';
				           |es_ES = 'Ha ocurrido un error durante al inscribir el perfil ""%1""
				           |Perfil proporcionado ya existe:';
				           |es_CO = 'Ha ocurrido un error durante al inscribir el perfil ""%1""
				           |Perfil proporcionado ya existe:';
				           |tr = 'Profil ""%1"" yazılırken bir hata oluştu.
				           |Sağlanan profil zaten mevcut:';
				           |it = 'Si è verificato un errore durante la registrazione del profilo ""%1"".
				           |Il profilo fornito esiste già:';
				           |de = 'Fehler beim Schreiben des Profils ""%1"".
				           |Das angegebene Profil existiert bereits:'"),
				Description);
			
			DetailedErrorPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при записи профиля ""%1"".
				           |Идентификатор поставляемых данных ""%2"" уже используется в профиле:'; 
				           |en = 'An error occurred when writing profile ""%1"".
				           |Supplied data ID ""%2"" is already used in the profile:'; 
				           |pl = 'Wystąpił błąd podczas zapisywania profilu ""%1"".
				           |Dostarczony identyfikator danych ""%2"" jest już używany w profilu:';
				           |es_ES = 'Ha ocurrido un error al inscribir el perfil ""%1"".
				           |Identificador de datos proporcionados ""%2"" ya se utiliza en el perfil:';
				           |es_CO = 'Ha ocurrido un error al inscribir el perfil ""%1"".
				           |Identificador de datos proporcionados ""%2"" ya se utiliza en el perfil:';
				           |tr = 'Profil ""%1"" yazılırken bir hata oluştu.
				           |Sağlanan verinin ""%2"" kimliği profilde zaten mevcut:';
				           |it = 'Si è verificato un errore durante la registrazione del profilo ""%1"".
				           |ID dati fornita ""%2"" già utilizzata nel profilo:';
				           |de = 'Fehler beim Schreiben des Profils ""%1"".
				           |Die Kennung der gelieferten Daten ""%2"" wird bereits im Profil verwendet:'"),
				Description,
				String(SuppliedDataID));
			
			While Selection.Next() Do
				If Selection.Ref <> Ref Then
					
					BriefErrorPresentation = BriefErrorPresentation
						+ Chars.LF + """" + Selection.Description + """.";
					
					DetailedErrorPresentation = DetailedErrorPresentation
						+ Chars.LF + """" + Selection.Description + """ ("
						+ String(Selection.Ref.UUID())+ ")."
				EndIf;
			EndDo;
			
			If FillChecking Then
				CommonClientServer.MessageToUser(BriefErrorPresentation,,,, Cancel);
			Else
				WriteLogEvent(
					NStr("ru = 'Управление доступом.Нарушение однозначности поставляемого профиля'; en = 'Access management.Violation of supplied profile uniqueness'; pl = 'Zarządzanie dostępem.Naruszenie jednoznaczności dostarczanego profilu';es_ES = 'Gestión de acceso.Violación de unicidad del perfil suministrado';es_CO = 'Gestión de acceso.Violación de unicidad del perfil suministrado';tr = 'Erişim kontrolü. Sağlanan profilin tek değerliliğin ihlali';it = 'Gestione accesso. Violazione univocità profilo fornito';de = 'Zugangskontrolle. Verletzung der Eindeutigkeit des angegebenen Profils'",
					     CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error, , , DetailedErrorPresentation);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
