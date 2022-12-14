#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification┬ádata processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	AttributesToSkip = New Array;
	AttributesToSkip.Add("SuppliedDataID");
	AttributesToSkip.Add("SuppliedProfileChanged");
	AttributesToSkip.Add("Roles.DeleteRole");
	AttributesToSkip.Add("AccessKinds.*");
	AttributesToSkip.Add("AccessValues.*");
	
	Return AttributesToSkip;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AttachAdditionalTables
	|ThisList AS AccessGroupProfiles
	|
	|LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|	ON AccessGroups.Profile = AccessGroupProfiles.Ref
	|;
	|AllowReadUpdate
	|WHERE
	|	IsFolder
	|	OR Ref <> Value(Catalog.AccessGroupProfiles.Administrator)
	|	  AND IsAuthorizedUser(AccessGroups.EmployeeResponsible)";
	
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

#Region Internal

// The procedure updates descriptions of supplied profiles in access restriction parameters when a 
// configuration is modified.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateSuppliedProfilesDescription(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	SuppliedProfiles = SuppliedProfiles();
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccessManagement.SuppliedProfilesDescription",
			SuppliedProfiles, HasCurrentChanges);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.SuppliedProfilesDescription",
			?(HasCurrentChanges,
			  New FixedStructure("HasChanges", True),
			  New FixedStructure()) );
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// The procedure updates content of the predefined profiles in the access restriction options when a 
// configuration is modified.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdatePredefinedProfileComposition(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	PredefinedProfiles = Metadata.Catalogs.AccessGroupProfiles.GetPredefinedNames();
	
	BeginTransaction();
	Try
		HasDeletedItems = False;
		HasCurrentChanges = False;
		PreviousValue = Undefined;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccessManagement.AccessGroupPredefinedProfiles",
			PredefinedProfiles, , PreviousValue);
		
		If Not PredefinedProfilesMatch(PredefinedProfiles, PreviousValue, HasDeletedItems) Then
			HasCurrentChanges = True;
		EndIf;
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.AccessGroupPredefinedProfiles",
			?(HasDeletedItems,
			  New FixedStructure("HasDeletedItems", True),
			  New FixedStructure()) );
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

// The procedure updates the supplied catalog profiles according to the result of changing the 
// supplied profiles saved in access restriction settings.
//
Procedure UpdateSuppliedProfilesByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.AccessManagement.SuppliedProfilesDescription");
		
	If LastChanges = Undefined Then
		UpdateRequired = True;
	Else
		UpdateRequired = False;
		For each ChangesPart In LastChanges Do
			
			If TypeOf(ChangesPart) = Type("FixedStructure")
			   AND ChangesPart.Property("HasChanges")
			   AND TypeOf(ChangesPart.HasChanges) = Type("Boolean") Then
				
				If ChangesPart.HasChanges Then
					UpdateRequired = True;
					Break;
				EndIf;
			Else
				UpdateRequired = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If UpdateRequired Then
		UpdateSuppliedProfiles();
	EndIf;
	
EndProcedure

// Updates supplied profiles and when necessary updates access groups of these profiles.
// If any access group supplied profiles are not found, they are created.
//
// Update details are configured in the FillAccessGroupsSuppliedProfiles procedure of the 
// AccessManagementOverridable common module (see comments to the procedure).
//
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateSuppliedProfiles(HasChanges = Undefined) Export
	
	SuppliedProfiles = AccessManagementInternalCached.SuppliedProfilesDescription();
	
	ProfilesDetails    = SuppliedProfiles.ProfilesDetailsArray;
	UpdateParameters = SuppliedProfiles.UpdateParameters;
	
	UpdatedProfiles       = New Array;
	UpdatedAccessGroups = New Array;
	
	Query = New Query;
	Query.SetParameter("EmptyUniqueID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.SuppliedProfileChanged AS SuppliedProfileChanged,
	|	AccessGroupProfiles.SuppliedDataID AS SuppliedDataID,
	|	AccessGroupProfiles.Ref AS Ref,
	|	FALSE AS Found
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	NOT AccessGroupProfiles.IsFolder
	|	AND AccessGroupProfiles.SuppliedDataID <> &EmptyUniqueID";
	CurrentProfiles = Query.Execute().Unload();
	
	For Each ProfileProperties In ProfilesDetails Do
		
		CurrentProfileRow = CurrentProfiles.Find(
			New UUID(ProfileProperties.ID),
			"SuppliedDataID");
		
		ProfileUpdated = False;
		
		If CurrentProfileRow = Undefined Then
			// Creating a new supplied profile.
			If UpdateAccessGroupsProfile(ProfileProperties, True) Then
				HasChanges = True;
			EndIf;
			Profile = SuppliedProfileByID(ProfileProperties.ID);
			
		Else
			CurrentProfileRow.Found = True;
			
			Profile = CurrentProfileRow.Ref;
			If NOT CurrentProfileRow.SuppliedProfileChanged
			 OR UpdateParameters.UpdateModifiedProfiles Then
				// Updating a supplied profile.
				ProfileUpdated = UpdateAccessGroupsProfile(ProfileProperties, True);
			EndIf;
		EndIf;
		
		If UpdateParameters.UpdatingAccessGroups Then
			ProfileAccessGroupsUpdated = Catalogs.AccessGroups.UpdateProfileAccessGroups(
				Profile, UpdateParameters.UpdatingAccessGroupsWithObsoleteSettings);
			
			ProfileUpdated = ProfileUpdated OR ProfileAccessGroupsUpdated;
		EndIf;
		
		If ProfileUpdated Then
			HasChanges = True;
			UpdatedProfiles.Add(Profile);
		EndIf;
	EndDo;
	
	For Each CurrentProfileRow In CurrentProfiles Do
		If CurrentProfileRow.Found Then
			Continue;
		EndIf;
		If CurrentProfileRow.SuppliedProfileChanged Then
			Continue;
		EndIf;
		ProfileObject = CurrentProfileRow.Ref.GetObject();
		If ProfileObject.DeletionMark Then
			Continue;
		EndIf;
		ProfileObject.DeletionMark = True;
		InfobaseUpdate.WriteObject(ProfileObject);
		UpdatedProfiles.Add(ProfileObject.Ref);
		HasChanges = True;
	EndDo;
	
	UpdateAuxiliaryProfilesData(UpdatedProfiles, HasChanges);
	
EndProcedure

Procedure UpdateAuxiliaryProfilesData(Profiles = Undefined, HasChanges = False) Export
	
	If Profiles = Undefined Then
		InformationRegisters.AccessGroupsTables.UpdateRegisterData( , , HasChanges);
		InformationRegisters.AccessGroupsValues.UpdateRegisterData( , HasChanges);
		AccessManagementInternal.UpdateUserRoles( , , HasChanges);
		
	ElsIf Profiles.Count() > 0 Then
		ProfilesAccessGroups = Catalogs.AccessGroups.ProfileAccessGroups(Profiles);
		InformationRegisters.AccessGroupsTables.UpdateRegisterData(ProfilesAccessGroups, , HasChanges);
		InformationRegisters.AccessGroupsValues.UpdateRegisterData(ProfilesAccessGroups, HasChanges);
		
		// Updating user roles.
		UsersForUpdate =
			Catalogs.AccessGroups.UsersForRolesUpdateByProfile(Profiles);
		
		AccessManagementInternal.UpdateUserRoles(UsersForUpdate, , HasChanges);
	EndIf;
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not Users.IsFullUser()
		Or ModuleToDoListServer.UserTaskDisabled("AccessGroupProfiles") Then
		Return;
	EndIf;
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.AccessGroupProfiles.FullName());
	
	For Each Section In Sections Do
		
		IncompatibleAccessGroupsProfilesCount = IncompatibleAccessGroupsProfiles().Count();
		
		ProfileID = "IncompatibleWithCurrentVersion" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID = ProfileID;
		UserTask.HasUserTasks      = IncompatibleAccessGroupsProfilesCount > 0;
		UserTask.Presentation = NStr("ru = 'đŁđÁ Đüđżđ▓đ╝đÁĐüĐéđŞđ╝Đő Đü ĐéđÁđ║ĐâĐëđÁđ╣ đ▓đÁĐÇĐüđŞđÁđ╣'; en = 'Incompatible with current version'; pl = 'Niekompatybilny z aktualn─ů wersj─ů';es_ES = 'No es compatible con la versi├│n actual';es_CO = 'No es compatible con la versi├│n actual';tr = 'Mevcut s├╝r├╝mle uyumlu de─čil';it = 'Non compatibile con la versione corrente';de = 'Nicht kompatibel mit der aktuellen Version'");
		UserTask.Count    = IncompatibleAccessGroupsProfilesCount;
		UserTask.Owner      = Section;
		
		UserTask = ToDoList.Add();
		UserTask.ID = "AccessGroupProfiles";
		UserTask.HasUserTasks      = IncompatibleAccessGroupsProfilesCount > 0;
		UserTask.Important        = True;
		UserTask.Presentation = NStr("ru = 'đčĐÇđżĐäđŞđ╗đŞ đ│ĐÇĐâđ┐đ┐ đ┤đżĐüĐéĐâđ┐đ░'; en = 'Access group profiles'; pl = 'Profile grup dost─Öpu';es_ES = 'Perfiles del grupo de acceso';es_CO = 'Perfiles del grupo de acceso';tr = 'Eri┼čim grubu profilleri';it = 'Profili di gruppo di accesso';de = 'Zugriffsgruppenprofile'");
		UserTask.Count    = IncompatibleAccessGroupsProfilesCount;
		UserTask.Form         = "Catalog.AccessGroupProfiles.Form.ListForm";
		UserTask.FormParameters= New Structure("ProfilesWithRolesMarkedForDeletion", True);
		UserTask.Owner      = ProfileID;
		
	EndDo;
	
EndProcedure

#Region InfobaseUpdate

Procedure ClearRemovedRoles() Export 
	
	DefaulLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	AccessGroupProfilesRoles.Ref AS Ref
	|INTO TT_Refs
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		INNER JOIN Catalog.ExtensionObjectIDs AS ExtensionObjectIDs
	|		ON AccessGroupProfilesRoles.Role = ExtensionObjectIDs.Ref
	|			AND (ExtensionObjectIDs.DeletionMark)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	AccessGroupProfilesRoles.Ref
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		INNER JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON AccessGroupProfilesRoles.Role = MetadataObjectIDs.Ref
	|			AND (MetadataObjectIDs.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_Refs.Ref AS Ref
	|FROM
	|	TT_Refs AS TT_Refs";
	
	Selection = Query.Execute().Select();
	
	Query.Text =
	"SELECT
	|	ISNULL(ExtensionObjectIDs.Ref, MetadataObjectIDs.Ref) AS Role
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		LEFT JOIN Catalog.ExtensionObjectIDs AS ExtensionObjectIDs
	|		ON AccessGroupProfilesRoles.Role = ExtensionObjectIDs.Ref
	|			AND (ExtensionObjectIDs.DeletionMark)
	|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON AccessGroupProfilesRoles.Role = MetadataObjectIDs.Ref
	|			AND (MetadataObjectIDs.DeletionMark)
	|WHERE
	|	AccessGroupProfilesRoles.Ref = &Ref
	|	AND ISNULL(ExtensionObjectIDs.Ref, MetadataObjectIDs.Ref) IS NOT NULL ";
	
	While Selection.Next() Do
		
		Profile = Selection.Ref.GetObject();
		If Profile = Undefined Then
			Continue;
		EndIf;
		
		Query.SetParameter("Ref", Selection.Ref);
		
		SelectionDetailed = Query.Execute().Select();
		
		While SelectionDetailed.Next() Do
			
			ProfileRoles = Profile.Roles.FindRows(New Structure("Role", SelectionDetailed.Role));
			
			For Each RoleRow In ProfileRoles Do
				Profile.Roles.Delete(Profile.Roles.IndexOf(RoleRow));
			EndDo;
			
		EndDo;
		
		Try
			InfobaseUpdate.WriteObject(Profile);
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'đŁđÁ Đâđ┤đ░đ╗đżĐüĐî đĚđ░đ┐đŞĐüđ░ĐéĐî Đüđ┐ĐÇđ░đ▓đżĐçđŻđŞđ║ ""%1"". đčđżđ┤ĐÇđżđ▒đŻđÁđÁ: %2';pl = 'Nie mo┼╝na zapisa─ç katalogu ""%1"". Szczeg├│┼éy: %2';es_ES = 'Ha ocurrido un error al guardar el cat├ílogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el cat├ílogo ""%1"". Detalles: %2';tr = '""%1"" katalo─ču saklanam─▒yor. Ayr─▒nt─▒lar: %2';it = 'Impossibile salvare l''anagrafica ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", DefaulLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.AccessGroupProfiles,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion 

#EndRegion

#Region Private

// Returns a string of a unique ID of the supplied and predefined Administrator profile.
// 
//
Function AdministratorProfileID(Row = True) Export
	
	ID = "6c4b0307-43a4-4141-9c35-3dd7e9586d41";
	
	If Row Then
		Return ID;
	EndIf;
	
	Return New UUID(ID);
	
EndFunction

// Returns a reference to a supplied profile by ID.
//
// Parameters:
//  ID - String - a name or a unique ID of the supplied profile.
//
Function SuppliedProfileByID(ID, RaiseExceptionIfMissingInDatabase = False) Export
	
	SetPrivilegedMode(True);
	
	SuppliedProfiles = AccessManagementInternalCached.SuppliedProfilesDescription();
	ProfileProperties = SuppliedProfiles.ProfilesDetails.Get(String(ID));
	
	If ProfileProperties = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'đčĐÇđżĐäđŞđ╗Đî c đŞđ┤đÁđŻĐéđŞĐäđŞđ║đ░ĐéđżĐÇđżđ╝ ""%1""
			           |đŻđÁ đ┐đżĐüĐéđ░đ▓đ╗ĐĆđÁĐéĐüĐĆ đ▓ đ┐ĐÇđżđ│ĐÇđ░đ╝đ╝đÁ.'; 
			           |en = 'Profile with ID ""%1""
			           |is not supplied in the application.'; 
			           |pl = 'Profil z identyfikatorem ""%1""
			           |nie jest dostarczany w programie.';
			           |es_ES = 'El perfil con el identificador ""%1""
			           |no se suministra en el programa.';
			           |es_CO = 'El perfil con el identificador ""%1""
			           |no se suministra en el programa.';
			           |tr = '""%1"" kimlikli profile
			           |uygulamada eri┼čilemiyor.';
			           |it = 'Profilo con ID ""%1""
			           |non ├Ę fornito nell''applicazione.';
			           |de = 'Das Profil mit der Kennung ""%1""
			           |ist im Programm nicht enthalten.'"),
			String(ID));
	EndIf;
	
	Query = New Query;
	Query.SetParameter("SuppliedDataID",
		New UUID(ProfileProperties.ID));
	
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.SuppliedDataID = &SuppliedDataID";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	If RaiseExceptionIfMissingInDatabase Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'đčđżĐüĐéđ░đ▓đ╗ĐĆđÁđ╝Đőđ╣ đ┐ĐÇđżĐäđŞđ╗Đî Đü đŞđ┤đÁđŻĐéđŞĐäđŞđ║đ░ĐéđżĐÇđżđ╝ ""%1""
			           |đŻđÁ đŻđ░đ╣đ┤đÁđŻ đ▓ đŞđŻĐäđżĐÇđ╝đ░ĐćđŞđżđŻđŻđżđ╣ đ▒đ░đĚđÁ.'; 
			           |en = 'Supplied profile with ID ""%1""
			           |is not found in the infobase.'; 
			           |pl = 'Dostarczany profil z identyfikatorem ""%1""
			           |nie zosta┼é znaleziony w bazie informacyjnej.';
			           |es_ES = 'El perfil suministrado con el identificador ""%1""
			           |no se ha encontrado en la base de informaci├│n.';
			           |es_CO = 'El perfil suministrado con el identificador ""%1""
			           |no se ha encontrado en la base de informaci├│n.';
			           |tr = '""%1"" kimli─čine sahip profil
			           |Infobase''de bulunamad─▒.';
			           |it = 'Il profilo fornito con ID ""%1""
			           |non ├Ę stato trovato nel infobase.';
			           |de = 'Das angegebene Profil mit der Kennung ""%1""
			           |wurde nicht in der Informationsdatenbank gefunden.'"),
			String(ID));
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns a unique ID string of a supplied profile data.
// 
//
Function SuppliedProfileID(Profile) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Ref", Profile);
	
	Query.SetParameter("EmptyUniqueID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.SuppliedDataID
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.Ref = &Ref
	|	AND AccessGroupProfiles.SuppliedDataID <> &EmptyUniqueID";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		SuppliedProfiles = AccessManagementInternalCached.SuppliedProfilesDescription();
		
		ProfileProperties = SuppliedProfiles.ProfilesDetails.Get(
			String(Selection.SuppliedDataID));
		
		Return String(Selection.SuppliedDataID);
	EndIf;
	
	Return Undefined;
	
EndFunction

// Checks whether the supplied profile is changed compared to the procedure description.
// AccessManagementOverridable.FillAccessGroupsSuppliedProfiles().
//
// Parameters:
//  Profile - CatalogRef.AccessGroupsProfiles (returns the SuppliedProfileChanged attribute),
//                     
//               - CatalogObject.AccessGroupsProfiles (returns the result of object filling 
//                     comparison to description in the overridable common module).
//                      
//
// Returns:
//  Boolean.
//
Function SuppliedProfileChanged(Profile) Export
	
	If TypeOf(Profile) = Type("CatalogRef.AccessGroupProfiles") Then
		Return Common.ObjectAttributeValue(Profile, "SuppliedProfileChanged");
	EndIf;
	
	ProfilesDetails = AccessManagementInternalCached.SuppliedProfilesDescription().ProfilesDetails;
	ProfileProperties = ProfilesDetails.Get(String(Profile.SuppliedDataID));
	
	If ProfileProperties = Undefined Then
		Return False;
	EndIf;
	
	ProfileRolesDetails = ProfileRolesDetails(ProfileProperties);
	
	If Upper(Profile.Description) <> Upper(ProfileProperties.Description) Then
		Return True;
	EndIf;
	
	If Profile.Roles.Count()            <> ProfileRolesDetails.Count()
	 OR Profile.AccessKinds.Count()     <> ProfileProperties.AccessKinds.Count()
	 OR Profile.AccessValues.Count() <> ProfileProperties.AccessValues.Count()
	 OR Profile.Purpose.Count()      <> ProfileProperties.Purpose.Count() Then
		Return True;
	EndIf;
	
	For each Role In ProfileRolesDetails Do
		RoleMetadata = Metadata.Roles.Find(Role);
		If RoleMetadata = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'đčĐÇđŞ đ┐ĐÇđżđ▓đÁĐÇđ║đÁ đ┐đżĐüĐéđ░đ▓đ╗ĐĆđÁđ╝đżđ│đż đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
				           |ĐÇđżđ╗Đî ""%2"" đŻđÁ đŻđ░đ╣đ┤đÁđŻđ░ đ▓ đ╝đÁĐéđ░đ┤đ░đŻđŻĐőĐů.'; 
				           |en = 'When checking supplied profile ""%1"", 
				           |role ""%2"" was not found in the metadata.'; 
				           |pl = 'Podczas weryfikacji dostarczanego profilu ""%1""
				           |rola ""%2"" nie zosta┼éa znaleziona w metadanych.';
				           |es_ES = 'Al comprobar el perfil suministrado ""%1""
				           | el rol ""%2"" no se ha encontrado en metadatos.';
				           |es_CO = 'Al comprobar el perfil suministrado ""%1""
				           | el rol ""%2"" no se ha encontrado en metadatos.';
				           |tr = 'Sa─članan ""%1"" profili kontrol edilirken
				           |meta veride ""%2"" rol├╝ bulunamad─▒.';
				           |it = 'Durante in controllo del profilo fornito ""%1"", 
				           |il ruolo ""%2"" ├Ę stato trovato nei metadati.';
				           |de = 'Bei der ├ťberpr├╝fung des angegebenen Profils ""%1""
				           |wurde Rolle ""%2"" nicht in den Metadaten gefunden.'"),
				ProfileProperties.Description,
				Role);
		EndIf;
		RoleID = Common.MetadataObjectID(RoleMetadata);
		If Profile.Roles.FindRows(New Structure("Role", RoleID)).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	For each AccessKindDetails In ProfileProperties.AccessKinds Do
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessKindDetails.Key);
		Filter = New Structure;
		Filter.Insert("AccessKind",        AccessKindProperties.Ref);
		Filter.Insert("PresetAccessKind", AccessKindDetails.Value = "PresetAccessKind");
		Filter.Insert("AllAllowed",      AccessKindDetails.Value = "AllAllowedByDefault");
		If Profile.AccessKinds.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	For each AccessValueDetails In ProfileProperties.AccessValues Do
		Filter = New Structure;
		Query = New Query(StrReplace("SELECT Value(%1) AS Value", "%1", AccessValueDetails.AccessValue));
		Filter.Insert("AccessValue", Query.Execute().Unload()[0].Value);
		If Profile.AccessValues.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	For Each UsersType In ProfileProperties.Purpose Do
		Filter = New Structure;
		Filter.Insert("UsersType", UsersType);
		If Profile.Purpose.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks whether initial filling is done for an access group profile in an overridable module.
//
// Parameters:
//  Profile - CatalogRef.AccessGroupsProfiles.
//  
// Returns:
//  Boolean.
//
Function HasInitialProfileFilling(Val Profile) Export
	
	SuppliedDataID = String(Common.ObjectAttributeValue(
		Profile, "SuppliedDataID"));
	
	SuppliedProfiles = AccessManagementInternalCached.SuppliedProfilesDescription();
	ProfileProperties = SuppliedProfiles.ProfilesDetails.Get(SuppliedDataID);
	
	Return ProfileProperties <> Undefined;
	
EndFunction

// Determines whether the supplied profile is prohibited from editing.
// Not supplied profiles cannot be prohibited from editing.
//
// Parameters:
//  Profile - CatalogObject.AccessGroupsProfiles,
//                 DataFormStructure generated according to the object.
//  
// Returns:
//  Boolean.
//
Function ProfileChangeProhibition(Val Profile) Export
	
	If Profile.SuppliedDataID =
			New UUID(AdministratorProfileID()) Then
		// Changing the Administrator profile is always prohibited.
		Return True;
	EndIf;
	
	SuppliedProfiles = AccessManagementInternalCached.SuppliedProfilesDescription();
	
	ProfileProperties = SuppliedProfiles.ProfilesDetails.Get(
		String(Profile.SuppliedDataID));
	
	Return ProfileProperties <> Undefined
	      AND SuppliedProfiles.UpdateParameters.DenyProfilesChange;
	
EndFunction

// Returns the supplied profile assignment description.
//
// Parameters:
//  Profile - CatalogRef.AccessGroupsProfiles.
//
// Returns:
//  String.
//
Function SuppliedProfileDetails(Profile) Export
	
	SuppliedDataID = String(Common.ObjectAttributeValue(
		Profile, "SuppliedDataID"));
	
	SuppliedProfiles = AccessManagementInternalCached.SuppliedProfilesDescription();
	ProfileProperties = SuppliedProfiles.ProfilesDetails.Get(SuppliedDataID);
	
	Text = "";
	If ProfileProperties <> Undefined Then
		Text = ProfileProperties.Details;
	EndIf;
	
	Return Text;
	
EndFunction

// Creates a supplied profile in the AccessGroupsProfiles catalog, and allows to refill a previously 
// created supplied profile by its supplied description.
// 
//  Initial filling is searched by unique profile ID string.
//
// Parameters:
//  Profile - CatalogRef.AccessGroupsProfiles.
//                 If initial filling description is found for the profile, the profile content is 
//                 completely replaced.
//
// UpdateAccessGroups - Boolean, if True, access kinds of profile access groups are updated.
//
Procedure FillSuppliedProfile(Val Profile, Val UpdateAccessGroups) Export
	
	SuppliedDataID = String(Common.ObjectAttributeValue(
		Profile, "SuppliedDataID"));
	
	SuppliedProfiles = AccessManagementInternalCached.SuppliedProfilesDescription();
	ProfileProperties = SuppliedProfiles.ProfilesDetails.Get(SuppliedDataID);
	
	If ProfileProperties <> Undefined Then
		
		UpdateAccessGroupsProfile(ProfileProperties);
		
		If UpdateAccessGroups Then
			Catalogs.AccessGroups.UpdateProfileAccessGroups(Profile, True);
		EndIf;
	EndIf;
	
EndProcedure

// Returns a list of references to profiles containing unavailable roles or roles marked for deletion.
//
// Returns:
//  Array - an array of elements CatalogRef.AccessGroupsProfiles.
//
Function IncompatibleAccessGroupsProfiles() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Profiles.Ref AS Ref,
	|	Profiles.Purpose.(
	|		UsersType AS UsersType
	|	) AS Purpose,
	|	Profiles.Roles.(
	|		Role AS Role
	|	) AS Roles
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles";
	
	DataExported = Query.Execute().Unload();
	
	IncompatibleProfiles = New Array;
	UnavailableRolesByAssignment = New Map;
	
	For Each ProfileDetails In DataExported Do
		ProfileAssignment = AccessManagementInternalClientServer.ProfileAssignment(ProfileDetails);
		UnavailableRoles = UnavailableRolesByAssignment.Get(ProfileAssignment);
		If UnavailableRoles = Undefined Then
			UnavailableRoles = UsersInternalCached.UnavailableRoles(ProfileAssignment);
			UnavailableRolesByAssignment.Insert(ProfileAssignment, UnavailableRoles);
		EndIf;
		
		If ProfileDetails.Roles.Find(Undefined, "Role") <> Undefined Then
			IncompatibleProfiles.Add(ProfileDetails.Ref);
			Continue;
		EndIf;
		
		RolesDetails = Catalogs.MetadataObjectIDs.MetadataObjectsByIDs(
			ProfileDetails.Roles.UnloadColumn("Role"), True);
		
		For Each RoleDetails In RolesDetails Do
			If RoleDetails.Value = Undefined Then
				// A role, which is not available until the application restart, is not a problem.
				Continue;
			EndIf;
			
			If RoleDetails.Value = Null
			 Or UnavailableRoles.Get(RoleDetails.Value.Name) <> Undefined
			 Or Upper(Left(RoleDetails.Value.Name, StrLen("Delete"))) = Upper("Delete") Then
				
				IncompatibleProfiles.Add(ProfileDetails.Ref);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	Return IncompatibleProfiles;
	
EndFunction

// See Catalogs.AccessGroupsProfiles.SuppliedProfiles. 
Function SuppliedProfilesDescription() Export
	
	SuppliedProfiles = StandardSubsystemsServer.ApplicationParameter(
		"StandardSubsystems.AccessManagement.SuppliedProfilesDescription");
	
	If SuppliedProfiles = Undefined Then
		UpdateSuppliedProfilesDescription();
	EndIf;
	
	SuppliedProfiles = StandardSubsystemsServer.ApplicationParameter(
		"StandardSubsystems.AccessManagement.SuppliedProfilesDescription");
	
	Return SuppliedProfiles;
	
EndFunction

Function AccessKindsOrValuesOrAssignmentChanged(PreviousValues, CurrentObject) Export
	
	If PreviousValues.Ref <> CurrentObject.Ref Then
		Return True;
	EndIf;
	
	AccessKinds     = PreviousValues.AccessKinds.Unload();
	AccessValues = PreviousValues.AccessValues.Unload();
	Assignment      = PreviousValues.Purpose.Unload();
	
	If AccessKinds.Count()     <> CurrentObject.AccessKinds.Count()
	 Or AccessValues.Count() <> CurrentObject.AccessValues.Count()
	 Or Assignment.Count()      <> CurrentObject.Purpose.Count() Then
		
		Return True;
	EndIf;
	
	Filter = New Structure("AccessKind, PresetAccessKind, AllAllowed");
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
	
	Filter = New Structure("UsersType");
	For Each Row In CurrentObject.Purpose Do
		FillPropertyValues(Filter, Row);
		If Assignment.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to support data exchange in DIB.

// For internal use only.
Procedure RestoreExtensionsRolesComponents(DataItem) Export
	
	DeleteExtensionsRoles(DataItem);
	
	Query = New Query;
	Query.SetParameter("Profile", DataItem.Ref);
	Query.Text =
	"SELECT DISTINCT
	|	ProfileRoles.Role AS Role
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|WHERE
	|	ProfileRoles.Ref = &Profile
	|	AND VALUETYPE(ProfileRoles.Role) = TYPE(Catalog.ExtensionObjectIDs)";
	
	// Adding extension roles to new components of configuration roles.
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DataItem.Roles.Add().Role = Selection.Role;
	EndDo;
	
EndProcedure

// For internal use only.
Procedure DeleteExtensionsRoles(DataItem) Export
	
	Index = DataItem.Roles.Count() - 1;
	While Index >= 0 Do
		If TypeOf(DataItem.Roles[Index].Role) <> Type("CatalogRef.MetadataObjectIDs") Then
			DataItem.Roles.Delete(Index);
		EndIf;
		Index = Index - 1;
	EndDo;
	
EndProcedure

// For internal use only.
Procedure DeleteExtensionsRolesInAllAccessGroupsProfiles() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	ProfileRoles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|WHERE
	|	VALUETYPE(ProfileRoles.Role) <> TYPE(Catalog.MetadataObjectIDs)";
	
	HasChanges = False;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ProfileObject = Selection.Ref.GetObject();
		DeleteExtensionsRoles(ProfileObject);
		If ProfileObject.Modified() Then
			InfobaseUpdate.WriteObject(ProfileObject, False);
			HasChanges = True;
		EndIf;
	EndDo;
	
	If HasChanges Then
		InformationRegisters.AccessGroupsTables.UpdateRegisterData();
	EndIf;
	
EndProcedure

// For internal use only.
Procedure RegisterProfileChangedOnImport(DataItem) Export
	
	// Registering profiles for whose access groups you need to update information registers
	// AccessGroupsTables, AccessGroupsValues, DefaultAccessGroupsValues, and user roles.
	
	PreviousValues = Common.ObjectAttributesValues(DataItem.Ref,
		"Ref, DeletionMark, Roles, Purpose, AccessKinds, AccessValues");
	
	RegistrationRegistration = False;
	Profile = DataItem.Ref;
	
	If TypeOf(DataItem) = Type("ObjectDeletion") Then
		RegistrationRegistration = True;
		
	ElsIf PreviousValues.Ref <> DataItem.Ref Then
		RegistrationRegistration = True;
		Profile = UsersInternal.ObjectRef(DataItem);
		
	ElsIf PreviousValues.DeletionMark <> DataItem.DeletionMark
	      Or AccessKindsOrValuesOrAssignmentChanged(PreviousValues, DataItem) Then
		
		RegistrationRegistration = True;
	Else
		OldRoles = PreviousValues.Roles.Unload();
		If OldRoles.Count() <> DataItem.Roles.Count() Then
			RegistrationRegistration = True;
		Else
			For Each Row In DataItem.Roles Do
				If OldRoles.Find(Row.Role, "Role") = Undefined Then
					RegistrationRegistration = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If Not RegistrationRegistration Then
		Return;
	EndIf;
	
	Catalogs.AccessGroups.RegisterRefs("Profiles", Profile);
	
EndProcedure

// For internal use only.
Procedure UpdateAuxiliaryProfilesDataChangedOnImport() Export
	
	If Common.DataSeparationEnabled() Then
		// Changes to profiles in SWP are blocked and are not imported into the data area.
		Return;
	EndIf;
	
	ChangedProfiles = Catalogs.AccessGroups.RegisteredRefs("Profiles");
	
	If ChangedProfiles.Count() = 0 Then
		Return;
	EndIf;
	
	If ChangedProfiles.Count() = 1
	   AND ChangedProfiles[0] = Undefined Then
		
		UpdateAuxiliaryProfilesData();
	Else
		UpdateAuxiliaryProfilesData(ChangedProfiles);
	EndIf;
	
	Catalogs.AccessGroups.RegisterRefs("Profiles", Null);
	
EndProcedure

// Infobase update handlers.

// Fills in supplied data IDs upon match to the reference ID.
Procedure FillSuppliedDataIDs() Export
	
	SetPrivilegedMode(True);
	
	SuppliedProfiles = AccessManagementInternalCached.SuppliedProfilesDescription();
	
	SuppliedProfileReferences = New Array;
	
	For each ProfileDetails In SuppliedProfiles.ProfilesDetailsArray Do
		SuppliedProfileReferences.Add(GetRef(
			New UUID(ProfileDetails.ID)));
	EndDo;
	
	Query = New Query;
	Query.SetParameter("EmptyUniqueID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.SetParameter("SuppliedProfileReferences", SuppliedProfileReferences);
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.Ref
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.SuppliedDataID = &EmptyUniqueID
	|	AND AccessGroupProfiles.Ref IN (&SuppliedProfileReferences)";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ProfileObject = Selection.Ref.GetObject();
		ProfileObject.SuppliedDataID = Selection.Ref.UUID();
		InfobaseUpdate.WriteData(ProfileObject);
	EndDo;
	
EndProcedure

// Replaces a reference to CCT.AccessKinds with a blank reference of main type of access kind values.
Procedure ConvertAccessKindsIDs() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.Ref AS Ref
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	(TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					Catalog.AccessGroupProfiles.AccessKinds AS AccessKinds
	|				WHERE
	|					AccessKinds.Ref = AccessGroupProfiles.Ref
	|					AND VALUETYPE(AccessKinds.AccessKind) = TYPE(ChartOfCharacteristicTypes.DeleteAccessKinds))
	|			OR TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					Catalog.AccessGroupProfiles.AccessValues AS AccessValues
	|				WHERE
	|					AccessValues.Ref = AccessGroupProfiles.Ref
	|					AND VALUETYPE(AccessValues.AccessKind) = TYPE(ChartOfCharacteristicTypes.DeleteAccessKinds)))
	|
	|UNION ALL
	|
	|SELECT
	|	AccessGroups.Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	(TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					Catalog.AccessGroups.AccessKinds AS AccessKinds
	|				WHERE
	|					AccessKinds.Ref = AccessGroups.Ref
	|					AND VALUETYPE(AccessKinds.AccessKind) = TYPE(ChartOfCharacteristicTypes.DeleteAccessKinds))
	|			OR TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					Catalog.AccessGroups.AccessValues AS AccessValues
	|				WHERE
	|					AccessValues.Ref = AccessGroups.Ref
	|					AND VALUETYPE(AccessValues.AccessKind) = TYPE(ChartOfCharacteristicTypes.DeleteAccessKinds)))";
	
	Selection = Query.Execute().Select();
	
	If Selection.Count() = 0 Then
		Return;
	EndIf;
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		
		Index = Object.AccessKinds.Count()-1;
		While Index >= 0 Do
			Row = Object.AccessKinds[Index];
			Try
				AccessKindName = ChartsOfCharacteristicTypes.DeleteAccessKinds.GetPredefinedItemName(
					Row.AccessKind);
			Except
				AccessKindName = "";
			EndTry;
			AccessKindProperties = AccessKindsProperties.ByNames.Get(AccessKindName);
			If AccessKindProperties = Undefined Then
				Object.AccessKinds.Delete(Index);
			Else
				Row.AccessKind = AccessKindProperties.Ref;
			EndIf;
			Index = Index - 1;
		EndDo;
		
		Index = Object.AccessValues.Count()-1;
		While Index >= 0 Do
			Row = Object.AccessValues[Index];
			Try
				AccessKindName = ChartsOfCharacteristicTypes.DeleteAccessKinds.GetPredefinedItemName(
					Row.AccessKind);
			Except
				AccessKindName = "";
			EndTry;
			AccessKindProperties = AccessKindsProperties.ByNames.Get(AccessKindName);
			If AccessKindProperties = Undefined Then
				Object.AccessValues.Delete(Index);
			Else
				Row.AccessKind = AccessKindProperties.Ref;
				If Object.AccessKinds.Find(Row.AccessKind, "AccessKind") = Undefined Then
					Object.AccessValues.Delete(Index);
				EndIf;
			EndIf;
			Index = Index - 1;
		EndDo;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Function SuppliedProfiles()
	
	UpdateParameters = New Structure;
	// Properties of supplied profile updates.
	UpdateParameters.Insert("UpdateModifiedProfiles", True);
	UpdateParameters.Insert("DenyProfilesChange", True);
	// Properties of update of supplied profile access groups.
	UpdateParameters.Insert("UpdatingAccessGroups", True);
	UpdateParameters.Insert("UpdatingAccessGroupsWithObsoleteSettings", False);
	
	ProfilesDetails = New Array;
	
	SSLSubsystemsIntegration.OnFillSuppliedAccessGroupProfiles(
		ProfilesDetails, UpdateParameters);
	
	AccessManagementOverridable.OnFillSuppliedAccessGroupProfiles(
		ProfilesDetails, UpdateParameters);
	
	ErrorTitle =
		NStr("ru = 'đŚđ░đ┤đ░đŻĐő đŻđÁđ┤đżđ┐ĐâĐüĐéđŞđ╝ĐőđÁ đĚđŻđ░ĐçđÁđŻđŞĐĆ đ▓ đ┐ĐÇđżĐćđÁđ┤ĐâĐÇđÁ OnFillSuppliedAccessGroupProfiles
		           |đżđ▒ĐëđÁđ│đż đ╝đżđ┤Đâđ╗ĐĆ AccessManagementOverridable.'; 
		           |en = 'Invalid values in the OnFillSuppliedAccessGroupProfiles procedure
		           |of the AccessManagementOverridable common module.'; 
		           |pl = 'W procedurze OnFillSuppliedAccessGroupProfiles
		           |modu┼éu og├│lnego AccessManagementOverridable okre┼Ťlono niedozwolone warto┼Ťci.';
		           |es_ES = 'Valores no v├ílidos en el procedimiento OnFillSuppliedAccessGroupProfiles 
		           |del m├│dulo com├║n de AccessManagementOverridable.';
		           |es_CO = 'Valores no v├ílidos en el procedimiento OnFillSuppliedAccessGroupProfiles 
		           |del m├│dulo com├║n de AccessManagementOverridable.';
		           |tr = 'OnFillSuppliedAccessGroupProfiles ortak mod├╝l├╝n AccessManagementOverridable
		           |prosed├╝r├╝mde belirlenen de─čerler kabul edilemez.';
		           |it = 'Valori invalidi nella procedura OnFillSuppliedAccessGroupProfiles procedure
		           |del modulo comune AccessManagementOverridable .';
		           |de = 'Ung├╝ltige Werte im Verfahren OnFillSuppliedAccessGroupProfiles
		           |des gemeinsamen Moduls AccessManagementOverridable.'")
		+ Chars.LF
		+ Chars.LF;
	
	If UpdateParameters.DenyProfilesChange
	   AND NOT UpdateParameters.UpdateModifiedProfiles Then
		
		Raise ErrorTitle
			+ NStr("ru = 'đĽĐüđ╗đŞ đ▓ đ┐đ░ĐÇđ░đ╝đÁĐéĐÇđÁ UpdateParameters Đüđ▓đżđ╣ĐüĐéđ▓đż
			             |UpdateChangedProfiles đŞđ╝đÁđÁĐé đĚđŻđ░ĐçđÁđŻđŞđÁ False,
			             |Đéđżđ│đ┤đ░ đ▓ Đüđ▓đżđ╣ĐüĐéđ▓đÁ DenyProfilesChange ĐéđżđÂđÁ
			             |đ┤đżđ╗đÂđŻđż đ▒ĐőĐéĐî ĐâĐüĐéđ░đŻđżđ▓đ╗đÁđŻđż đĚđŻđ░ĐçđÁđŻđŞđÁ False.'; 
			             |en = 'When the UpdateChangedProfiles property 
			             |of the UpdateParameters parameter is set to False, 
			             |the DenyProfilesChange property 
			             |must also be set to False.'; 
			             |pl = 'Kiedy w parametrze UpdateParameters dla w┼éa┼Ťciwo┼Ťci
			             |UpdateChangedProfiles ustawiono False,
			             |dla w┼éa┼Ťciwo┼Ťci DenyProfilesChange r├│wnie┼╝
			             |musi by─ç ustawione False.';
			             |es_ES = 'Cuando la propiedad UpdateChangedProfiles 
			             |del par├ímetro UpdateParameters se establece en False, 
			             |la propiedad DenyProfilesChange 
			             |tambi├ęn se debe establecer en False.';
			             |es_CO = 'Cuando la propiedad UpdateChangedProfiles 
			             |del par├ímetro UpdateParameters se establece en False, 
			             |la propiedad DenyProfilesChange 
			             |tambi├ęn se debe establecer en False.';
			             |tr = 'UpdateParameters parametresinin 
			             |UpdateChangedProfiles ├Âzelli─či 
			             |False olarak ayarlanm─▒┼čsa, 
			             |DenyProfilesChange de False olmal─▒d─▒r.';
			             |it = 'Quando la propriet├á UpdateChangedProfiles 
			             |del parametro UpdateParameters ├Ę impostato su False, 
			             |anche la propriet├á DenyProfilesChange property 
			             |deve essere impostata su False.';
			             |de = 'Wenn die Eigenschaft UpdateChangedProfiles im Parameter UpdateParameters
			             |auf False gesetzt ist,
			             |sollte die Eigenschaft DenyProfilesChange ebenfalls
			             |auf False gesetzt sein.'");
	EndIf;
	
	// Description for filling the Administrator predefined profile.
	AdministratorProfileDetails = AccessManagement.NewAccessGroupProfileDescription();
	AdministratorProfileDetails.Name           = "Administrator";
	AdministratorProfileDetails.ID = AdministratorProfileID();
	AdministratorProfileDetails.Description  = NStr("ru = 'đÉđ┤đ╝đŞđŻđŞĐüĐéĐÇđ░ĐéđżĐÇ'; en = 'Administrator'; pl = 'Administrator';es_ES = 'Administrador';es_CO = 'Administrador';tr = 'Y├Ânetici';it = 'Amministratore';de = 'Administrator'");
	AdministratorProfileDetails.Roles.Add("SystemAdministrator");
	AdministratorProfileDetails.Roles.Add("FullRights");
	
	AdministratorProfileDetails.Details =
		NStr("ru = 'đčĐÇđÁđ┤đŻđ░đĚđŻđ░ĐçđÁđŻ đ┤đ╗ĐĆ:
		           |- đŻđ░ĐüĐéĐÇđżđ╣đ║đŞ đ┐đ░ĐÇđ░đ╝đÁĐéĐÇđżđ▓ ĐÇđ░đ▒đżĐéĐő đŞ đżđ▒Đüđ╗ĐâđÂđŞđ▓đ░đŻđŞĐĆ đŞđŻĐäđżĐÇđ╝đ░ĐćđŞđżđŻđŻđżđ╣ ĐüđŞĐüĐéđÁđ╝Đő,
		           |- đŻđ░ĐüĐéĐÇđżđ╣đ║đŞ đ┐ĐÇđ░đ▓ đ┤đżĐüĐéĐâđ┐đ░ đ┤ĐÇĐâđ│đŞĐů đ┐đżđ╗ĐîđĚđżđ▓đ░ĐéđÁđ╗đÁđ╣,
		           |- Đâđ┤đ░đ╗đÁđŻđŞĐĆ đ┐đżđ╝đÁĐçđÁđŻđŻĐőĐů đżđ▒ĐŐđÁđ║Đéđżđ▓,
		           |- đ▓ ĐÇđÁđ┤đ║đŞĐů Đüđ╗ĐâĐçđ░ĐĆĐů đ┤đ╗ĐĆ đ▓đŻđÁĐüđÁđŻđŞĐĆ đŞđĚđ╝đÁđŻđÁđŻđŞđ╣ đ▓ đ║đżđŻĐäđŞđ│ĐâĐÇđ░ĐćđŞĐÄ.
		           |
		           |đáđÁđ║đżđ╝đÁđŻđ┤ĐâđÁĐéĐüĐĆ đŻđÁ đŞĐüđ┐đżđ╗ĐîđĚđżđ▓đ░ĐéĐî đ┤đ╗ĐĆ ""đżđ▒ĐőĐçđŻđżđ╣"" ĐÇđ░đ▒đżĐéĐő đ▓ đŞđŻĐäđżĐÇđ╝đ░ĐćđŞđżđŻđŻđżđ╣ ĐüđŞĐüĐéđÁđ╝đÁ.'; 
		           |en = 'Used to:
		           |- Set up and maintain information system parameters
		           |- Assign access rights to users
		           |- Delete marked objects
		           |- Make changes to configuration (in rare cases).
		           |
		           |It is not recommended that you use it for regular information system operations.'; 
		           |pl = 'Przeznaczony do:
		           |- ustawiania parametr├│w pracy i obs┼éugi systemu informacyjnego,
		           |- ustawiania praw dost─Öpu innych u┼╝ytkownik├│w,
		           |- usuwania zaznaczonych obiekt├│w,
		           |- do wprowadzania zmian do konfiguracji (w rzadkich przypadkach).
		           |
		           |Zaleca si─Ö nie u┼╝ywa─ç go do ""zwyk┼éej"" pracy w systemie informacyjnym.';
		           |es_ES = 'Est├í destinado para:
		           |- ajuste de par├ímetros de trabajo y servicio del sistema de informaci├│n,
		           |- ajustes de derechos de acceso de otros usuarios,
		           |- eliminaci├│n de los objetos marcados,
		           |- en unos casos para realizar modificaciones en la configuraci├│n.
		           |
		           |Se recomienda no usar para el trabajo ""regular"" en el sistema de informaci├│n.';
		           |es_CO = 'Est├í destinado para:
		           |- ajuste de par├ímetros de trabajo y servicio del sistema de informaci├│n,
		           |- ajustes de derechos de acceso de otros usuarios,
		           |- eliminaci├│n de los objetos marcados,
		           |- en unos casos para realizar modificaciones en la configuraci├│n.
		           |
		           |Se recomienda no usar para el trabajo ""regular"" en el sistema de informaci├│n.';
		           |tr = 'A┼ča─č─▒daki ama├ž i├žin tasarlanm─▒┼čt─▒r: 
		           |- bilgi sisteminin i┼č ve bak─▒m ayarlar─▒, 
		           |- di─čer kullan─▒c─▒lar─▒n eri┼čim haklar─▒ ayarlar─▒, 
		           |- etiketli nesneleri silme, 
		           |- nadir durumlarda yap─▒land─▒rmada de─či┼čiklik yapmak. 
		           |
		           |Bilgi sisteminde ""normal"" bir ├žal─▒┼čma i├žin kullan─▒lmamas─▒ ├Ânerilir.';
		           |it = 'Utilizzato per:
		           |- Impostare e mantenere i parametri del sistema informatico
		           |- Assegnare diritti di accesso agli utenti
		           |- Eliminare gli oggetti contrassegnati
		           |- Fare modifiche alla configurazione (raramente).
		           |
		           |├ł sconsigliato l''utilizzo per operazioni standard del sistema informatico.';
		           |de = 'Bestimmt f├╝r:
		           |- Einstellungen der Betriebs- und Wartungsparameter des Informationssystems,
		           |- Einstellungen der Zugriffsrechte anderer Benutzer,
		           |- L├Âschen der markierten Objekte,
		           |- in seltenen F├Ąllen f├╝r ├änderungen an der Konfiguration.
		           |
		           |Es wird empfohlen, nicht f├╝r ""normale"" Arbeiten im Informationssystem zu verwenden.'")
		+ Chars.LF;
	
	ProfilesDetails.Add(AdministratorProfileDetails);
	
	If Not Common.DataSeparationEnabled() Then
		ProfilesDetails.Add(
			AccessManagementInternal.OpenExternalReportsAndDataProcessorsProfileDetails());
	EndIf;
	
	AllRoles = UsersInternal.AllRoles().Map;
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	
	// Transforming descriptions into mapping between IDs and properties for storage and quick 
	// processing.
	ProfilesProperties = New Map;
	ProfilesDetailsArray = New Array;
	For Each ProfileDetails In ProfilesDetails Do
		// Profile ID.
		If Not ValueIsFilled(ProfileDetails.ID) Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1"" đŻđÁ đĚđ░đ┐đżđ╗đŻđÁđŻđż Đüđ▓đżđ╣ĐüĐéđ▓đż đśđ┤đÁđŻĐéđŞĐäđŞđ║đ░ĐéđżĐÇ.'; en = 'The ID property is not filled in the ""%1"" profile description.'; pl = 'Identyfikator w┼éa┼Ťciwo┼Ťci nie jest wype┼éniony w ""%1"" opisie profilu.';es_ES = 'En la descripci├│n del perfil ""%1"" no est├í rellenada la propiedad Identificador.';es_CO = 'En la descripci├│n del perfil ""%1"" no est├í rellenada la propiedad Identificador.';tr = '""%1"" profil a├ž─▒klamas─▒nda kimlik ├Âzelli─či doldurulmad─▒.';it = 'Le propriet├á dell''ID non sono compilate nella descrizione profilo ""%1"".';de = 'Die Eigenschaft Identit├Ątsmerkmal wird in der Profilbeschreibung ""%1"" nicht ausgef├╝llt.'"),
				?(ValueIsFilled(ProfileDetails.Name), ProfileDetails.Name, ProfileDetails.Description));
				
		ElsIf Not StringFunctionsClientServer.IsUUID(ProfileDetails.ID) Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1"" Đâđ║đ░đĚđ░đŻ đŻđÁđ║đżĐÇĐÇđÁđ║ĐéđŻĐőđ╣ đŞđ┤đÁđŻĐéđŞĐäđŞđ║đ░ĐéđżĐÇ: ""%2"".'; en = 'Incorrect ID ""%2"" is specified in the ""%1"" profile description.'; pl = 'Nieprawid┼éowy identyfikator ""%1"" jest wskazany w opisie profilu: ""%2"".';es_ES = 'En la descripci├│n del perfil ""%1"" est├í indicado un identificador no correcto: ""%2"".';es_CO = 'En la descripci├│n del perfil ""%1"" est├í indicado un identificador no correcto: ""%2"".';tr = '""%1"" profil a├ž─▒klamas─▒nda yanl─▒┼č ""%2"" kimli─či belirtildi.';it = 'Un ID non corretto ""%2"" ├Ę specificato nella descrizione profilo ""%1"".';de = 'In der Beschreibung des Profils ""%1"" gibt es eine falsche Kennung: ""%2"".'"),
				?(ValueIsFilled(ProfileDetails.Name), ProfileDetails.Name, ProfileDetails.Description),
				ProfileDetails.ID);
		EndIf;
		
		// Profile purpose.
		If ProfileDetails.Purpose.Count() = 0 Then
			ProfileDetails.Purpose.Add(Type("CatalogRef.Users"));
		EndIf;
		AssignmentsArray = New Array;
		For Each Type In ProfileDetails.Purpose Do
			If TypeOf(Type) = Type("TypeDescription") Then
				Types = Type.Types();
			Else
				Types = CommonClientServer.ValueInArray(Type);
			EndIf;
			For Each Type In Types Do
				If TypeOf(Type) <> Type("Type")
				 Or Not Common.IsReference(Type)
				 Or Not Metadata.DefinedTypes.User.Type.ContainsType(Type)
				 Or Type <> Type("CatalogRef.Users")
				   AND Not Metadata.DefinedTypes.ExternalUser.Type.ContainsType(Type) Then
					Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
						           |Đâđ║đ░đĚđ░đŻđż đŻđÁđ┤đżđ┐ĐâĐüĐéđŞđ╝đżđÁ đŻđ░đĚđŻđ░ĐçđÁđŻđŞđÁ ""%2 (%3)"".
						           |đ×đÂđŞđ┤đ░đÁĐéĐüĐĆ đŻđ░đĚđŻđ░ĐçđÁđŻđŞđÁ, đ║đ░đ║ đĚđŻđ░ĐçđÁđŻđŞđÁ ĐéđŞđ┐đ░ ""đóđŞđ┐"" đ┤đ╗ĐĆ ĐüĐüĐőđ╗đ║đŞ,
						           |Đâđ║đ░đĚđ░đŻđŻđżđÁ đ▓ đżđ┐ĐÇđÁđ┤đÁđ╗ĐĆđÁđ╝đżđ╝ ĐéđŞđ┐đÁ đčđżđ╗ĐîđĚđżđ▓đ░ĐéđÁđ╗Đî đŞ
						           |Đâđ║đ░đĚđ░đŻđŻđżđÁ đ▓ đżđ┐ĐÇđÁđ┤đÁđ╗ĐĆđÁđ╝đżđ╝ ĐéđŞđ┐đÁ ExternalUser
						           |(đ║ĐÇđżđ╝đÁ ĐéđŞđ┐đ░ CatalogRef.Users).'; 
						           |en = 'Invalid purpose ""%2 (%3)""
						           |is specified in the description of profile ""%1.""
						           |The expected purpose is a value of ""Type"" type for the reference,
						           |which is specified in defined type User and 
						           |defined type ExternalUser
						           |(except for CatalogRef.Users type).'; 
						           |pl = 'W opisie profilu ""%1"" 
						           |okre┼Ťlony niewa┼╝ny cel ""%2 (%3)"".
						           |Oczekiwany cel jest warto┼Ťci─ů ""Typ"" wpisywan─ů dla odniesienia,
						           |wskazan─ů w okre┼Ťlanym typie U┼╝ytkownika i
						           |wskazana w okre┼Ťlanym typie ExternalUser
						           |(za wyj─ůtkiem typu CatalogRef.Users).';
						           |es_ES = 'El prop├│sito no v├ílido ""%2(%3)"" 
						           |se especifica en la descripci├│n del perfil ""%1."" 
						           |El prop├│sito esperado es un valor de tipo ""Tipo"" para la referencia, 
						           |que se especifica en el tipo definido Usuario y 
						           |tipo definido ExternalUser
						           |(excepto para el tipo Cat├ílogoRef.Users) .';
						           |es_CO = 'El prop├│sito no v├ílido ""%2(%3)"" 
						           |se especifica en la descripci├│n del perfil ""%1."" 
						           |El prop├│sito esperado es un valor de tipo ""Tipo"" para la referencia, 
						           |que se especifica en el tipo definido Usuario y 
						           |tipo definido ExternalUser
						           |(excepto para el tipo Cat├ílogoRef.Users) .';
						           |tr = '""%1""
						           | Profil a├ž─▒klamas─▒nda ge├žersiz bir atama ""%2"" (%3) belirtildi.
						           |Atama, Kullan─▒c─▒ tan─▒ml─▒ t├╝rde belirtilen ve Harici Kullan─▒c─▒ tan─▒ml─▒ t├╝rde
						           |(KatalogReferans.Kullan─▒c─▒lar t├╝r├╝ hari├ž) 
						           |belirtilen ba─člant─▒ i├žin 
						           |""T├╝r "" t├╝r├╝nde bir de─čer olarak bekleniyor.';
						           |it = '├ł specificato uno scopo non valido ""%2 (%3)""
						           | nella descrizione del profilo ""%1"".
						           |Lo scopo previsto ├Ę un valore di tipo ""Tipo"" per il riferimento
						           | specificato nel tipo definito User e 
						           |nel tipo definito ExternalUser
						           |(ad eccezione del tipo CatalogRef.Users).';
						           |de = 'Die Profilbeschreibung ""%1""
						           |zeigt eine ung├╝ltige Zuordnung ""%2 (%3)"" an.
						           |Es wird erwartet, dass die Zuordnung der Wert des Typs ""Type"" f├╝r die Referenz ist,
						           |die im definierten Benutzertyp angegeben und
						           |im definierten Typ ExternalUser
						           |angegeben ist (au├čer dem CatalogRef.Users).'"),
						?(ValueIsFilled(ProfileDetails.Name),
						  ProfileDetails.Name,
						  ProfileDetails.ID),
						  String(Type), String(TypeOf(Type)));
				EndIf;
				RefTypeDetails = New TypeDescription(CommonClientServer.ValueInArray(Type));
				Value = RefTypeDetails.AdjustValue(Undefined);
				AssignmentsArray.Add(Value);
			EndDo;
		EndDo;
		ProfileDetails.Purpose = AssignmentsArray;
		
		// Checking roles.
		ProfileAssignment = AccessManagementInternalClientServer.ProfileAssignment(ProfileDetails);
		UnavailableRoles = UsersInternalCached.UnavailableRoles(ProfileAssignment, False);
		
		For Each Role In ProfileDetails.Roles Do
			// Checking whether the metadata contains roles.
			If AllRoles.Get(Role) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1 (%2)""
					           |ĐÇđżđ╗Đî ""%3"" đŻđÁ đŻđ░đ╣đ┤đÁđŻđ░ đ▓ đ╝đÁĐéđ░đ┤đ░đŻđŻĐőĐů.'; 
					           |en = 'Role ""%3"" is not found in metadata
					           |in  description of the ""%1 (%2)"" profile.'; 
					           |pl = 'Rola ""%3"" nie zosta┼éa znaleziona w metadanych
					           |w opisie ""%1 (%2)""profilu.';
					           |es_ES = 'En la descripci├│n del perfil ""%1 (%2)""
					           |el rol ""%3"" no se ha encontrado en metadatos.';
					           |es_CO = 'En la descripci├│n del perfil ""%1 (%2)""
					           |el rol ""%3"" no se ha encontrado en metadatos.';
					           |tr = 'Profil a├ž─▒klamas─▒nda 
					           |""%1 (%2)"" rol├╝ ""%3"" meta veride bulunamad─▒.';
					           |it = 'Ruolo ""%3"" non trovato nei metadati
					           |nella descrizione del profilo ""%1 (%2)"".';
					           |de = 'In der Profilbeschreibung ""%1 (%2)""
					           |wurde die Rolle ""%3"" nicht in den Metadaten gefunden.'"),
					ProfileDetails.Name,
					ProfileDetails.ID,
					Role);
			EndIf;
			// Checking correspondence between the assignment of roles and a profile.
			If UnavailableRoles.Get(Role) <> Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1 (%2)""
					           |Đâđ║đ░đĚđ░đŻđ░ ĐÇđżđ╗Đî ""%3"", 
					           |đ║đżĐéđżĐÇđ░ĐĆ đŻđÁ ĐüđżđżĐéđ▓đÁĐéĐüĐéđ▓ĐâđÁĐé đŻđ░đĚđŻđ░ĐçđÁđŻđŞĐÄ đ┐ĐÇđżĐäđŞđ╗ĐĆ:
					           |""%4"".'; 
					           |en = 'Role ""%3"" that 
					           |does not correspond to the profile assignment:
					           |""%4
					           |is specified in description of profile ""%1 (%2)"".'; 
					           |pl = 'Rola ""%3"" , kt├│ra 
					           |nie odpowiada przypisaniu profilu:
					           |""%4
					           |jest okre┼Ťlona w opisie profilu ""%1 (%2)"".';
					           |es_ES = 'En la descripci├│n del perfil ""%1 (%2)""
					           |se ha indicado el rol ""%3""
					           |que no corresponde a la asignaci├│n del perfil:
					           |""%4"".';
					           |es_CO = 'En la descripci├│n del perfil ""%1 (%2)""
					           |se ha indicado el rol ""%3""
					           |que no corresponde a la asignaci├│n del perfil:
					           |""%4"".';
					           |tr = '""%1 (%2)"" profil a├ž─▒klamas─▒nda
					           |""%4"" profil amac─▒na uymayan
					           | ""%3"" rol├╝
					           |belirtilmi┼čtir.';
					           |it = 'Ruolo ""%3"" non
					           | corrispondente all''assegnazione del profilo:
					           |""%4
					           |├Ę indicato nella descrizione del profilo ""%1 (%2)"".';
					           |de = 'In der Profilbeschreibung ""%1 (%2)""
					           |wird die Rolle ""%3"" angegeben,
					           |die nicht dem Verwendungszweck des Profils entspricht:
					           |""%4"".'"),
					ProfileDetails.Name,
					ProfileDetails.ID,
					Role,
					ProfileAssignmentPresentation(ProfileAssignment));
			EndIf;
		EndDo;
		If Common.DataSeparationEnabled() Then
			// Filling in the list of unavailable roles in SaaS to determine if the supplied profiles need to be 
			// updated.
			ProfileDetails.Insert("RolesUnavailableInService",
				ProfileRolesUnavailableInService(ProfileDetails, ProfileAssignment));
		EndIf;
		
		If ProfilesProperties.Get(ProfileDetails.ID) <> Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'đčĐÇđżĐäđŞđ╗Đî Đü đŞđ┤đÁđŻĐéđŞĐäđŞđ║đ░ĐéđżĐÇđżđ╝ ""%1"" ĐâđÂđÁ ĐüĐâĐëđÁĐüĐéđ▓ĐâđÁĐé.'; en = 'Profile with ID ""%1"" already exists.'; pl = 'Profil z identyfikatorem ""%1"" ju┼╝ istnieje.';es_ES = 'Perfil con el identificador ""%1"" ya existe.';es_CO = 'Perfil con el identificador ""%1"" ya existe.';tr = '""%1"" kimlikli profil zaten mevcut.';it = 'Profilo con ID ""%1"" esiste gi├á.';de = 'Profil mit ID ""%1"" existiert bereits.'"),
				ProfileDetails.ID);
		EndIf;
		ProfilesProperties.Insert(ProfileDetails.ID, ProfileDetails);
		ProfilesDetailsArray.Add(ProfileDetails);
		If ValueIsFilled(ProfileDetails.Name) Then
			If ProfilesProperties.Get(ProfileDetails.Name) <> Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đčĐÇđżĐäđŞđ╗Đî Đü đŞđ╝đÁđŻđÁđ╝ ""%1"" ĐâđÂđÁ ĐüĐâĐëđÁĐüĐéđ▓ĐâđÁĐé.'; en = 'Profile with name ""%1"" already exists.'; pl = 'Profil o nazwie ""%1"" ju┼╝ istnieje.';es_ES = 'Perfil con el nombre ""%1"" ya existe.';es_CO = 'Perfil con el nombre ""%1"" ya existe.';tr = '""%1"" isimli profil zaten mevcut.';it = 'Profilo con il nome ""%1"" esiste gi├á.';de = 'Das Profil mit dem Namen ""%1"" existiert bereits.'"),
					ProfileDetails.Name);
			EndIf;
			ProfilesProperties.Insert(ProfileDetails.Name, ProfileDetails);
		EndIf;
		// Transformation of ValuesList to Mapping for recording.
		AccessKinds = New Map;
		For Each ListItem In ProfileDetails.AccessKinds Do
			AccessKindName       = ListItem.Value;
			AccessKindClarification = ListItem.Presentation;
			If AccessKindsProperties.ByNames.Get(AccessKindName) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |Đâđ║đ░đĚđ░đŻ đŻđÁĐüĐâĐëđÁĐüĐéđ▓ĐâĐÄĐëđŞđ╣ đ▓đŞđ┤ đ┤đżĐüĐéĐâđ┐đ░ ""%2"".'; 
					           |en = 'Non-existing access kind ""%2"" 
					           |is specified in description of profile ""%1"".'; 
					           |pl = 'W opisie profilu ""%1""
					           |wskazano nieistniej─ůcy rodzaj dost─Öpu ""%2"".';
					           |es_ES = 'En la descripci├│n del perfil ""%1""
					           |se ha indicado un tipo de acceso no existente ""%2"".';
					           |es_CO = 'En la descripci├│n del perfil ""%1""
					           |se ha indicado un tipo de acceso no existente ""%2"".';
					           |tr = 'Profil
					           |a├ž─▒klamas─▒nda ""%1"" ge├žersiz eri┼čim t├╝r├╝ ""%2"" belirlendi.';
					           |it = 'Una tipologia di accesso ""%2"" non esistente
					           |├Ę stata specificata nella descrizione del profilo ""%1"".';
					           |de = 'In der Profilbeschreibung ""%1""
					           |gibt es eine nicht vorhandene Zugriffsart ""%2"".'"),
					?(ValueIsFilled(ProfileDetails.Name),
					  ProfileDetails.Name,
					  ProfileDetails.ID),
					AccessKindName);
			EndIf;
			
			AccessKindMatchesProfileAssignment =
				AccessManagementInternalClientServer.AccessKindMatchesProfileAssignment(
					AccessKindName, ProfileAssignment);
			
			If Not AccessKindMatchesProfileAssignment Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |Đâđ║đ░đĚđ░đŻ đ▓đŞđ┤ đ┤đżĐüĐéĐâđ┐đ░ ""%2""
					           |đ║đżĐéđżĐÇĐőđ╣ đŻđÁ ĐüđżđżĐéđ▓đÁĐéĐüĐéđ▓ĐâđÁĐé đŻđ░đĚđŻđ░ĐçđÁđŻđŞĐÄ đ┐ĐÇđżĐäđŞđ╗ĐĆ:
					           |""%3"".'; 
					           |en = 'Access kind ""%2"" that
					           |does not correspond to profile assignment ""%3"" 
					           |is specified in the 
					           |""%1"" profile description.'; 
					           |pl = 'Rodzaj dost─Öpu""%2"", kt├│ry
					           |nie odpowiada przypisaniu profilu""%3"" 
					           |jest okre┼Ťlony w 
					           |""%1""opisie profilu.';
					           |es_ES = 'En la descripci├│n del perfil ""%1""
					           |se ha indicado un tipo de acceso ""%2""
					           |que corresponde al destino de perfil:
					           |""%3"".';
					           |es_CO = 'En la descripci├│n del perfil ""%1""
					           |se ha indicado un tipo de acceso ""%2""
					           |que corresponde al destino de perfil:
					           |""%3"".';
					           |tr = '""%1"" 
					           | profil a├ž─▒klamas─▒nda, profilin amac─▒na uygun olmayan ""%2""
					           |eri┼čim hakk─▒ belirtilmi┼čtir: 
					           |""%3"".';
					           |it = 'Tipo di accesso ""%2"" non
					           |corrispondente all''assegnazione del profilo ""%3""
					           |indicato nella descrizione del profilo 
					           |""%1"".';
					           |de = 'In der Beschreibung des Profils ""%1""
					           |wird die Art des Zugriffs ""%2""
					           |angegeben, die nicht dem Zweck des Profils:
					           |""%3"" entspricht.'"),
					?(ValueIsFilled(ProfileDetails.Name),
					  ProfileDetails.Name,
					  ProfileDetails.ID),
					AccessKindName,
					ProfileAssignmentPresentation(ProfileAssignment));
			EndIf;
			If AccessKindClarification <> ""
			   AND AccessKindClarification <> "AllDeniedByDefault"
			   AND AccessKindClarification <> "PresetAccessKind"
			   AND AccessKindClarification <> "AllAllowedByDefault" Then
				
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |đ┤đ╗ĐĆ đ▓đŞđ┤đ░ đ┤đżĐüĐéĐâđ┐đ░ ""%2"" Đâđ║đ░đĚđ░đŻđż đŻđÁđŞđĚđ▓đÁĐüĐéđŻđżđÁ ĐâĐéđżĐçđŻđÁđŻđŞđÁ ""%3"".
					           |
					           |đöđżđ┐ĐâĐüĐéđŞđ╝Đő Đéđżđ╗Đîđ║đż Đüđ╗đÁđ┤ĐâĐÄĐëđŞđÁ ĐâĐéđżĐçđŻđÁđŻđŞĐĆ:
					           |- ""AllDeniedByDefault"",
					           |- ""AllAllowedByDefault"",
					           |- ""PresetAccessKind"".'; 
					           |en = 'Unknown clarification ""%3"" 
					           |is specified in the description of the ""%1"" profile for access kind ""%2.""
					           |
					           |Only the following clarifications are allowed:
					           |- AllDeniedByDefault
					           |- AllAllowedByDefault
					           |- PresetAccessKind'; 
					           |pl = 'Nieznane wyja┼Ťnienie ""%3"" 
					           |jest okre┼Ťlona w opisie ""%1"" profilu dla rodzaju dost─Öpu ""%2.""
					           |
					           |S─ů dozwolone tylko nast─Öpuj─ůce wyja┼Ťnienia:
					           |- AllDeniedByDefault
					           |- AllAllowedByDefault
					           |- PresetAccessKind';
					           |es_ES = 'En la descripci├│n del perfil ""%3""
					           |para el tipo de acceso ""%1"" el refinador desconocido ""%2"" est├í especificado.""
					           |
					           |Solo los siguientes refinadores son v├ílidos:
					           |-┬áAllDeniedByDefault
					           |- AllAllowedByDefault
					           |- PresetAccessKind';
					           |es_CO = 'En la descripci├│n del perfil ""%3""
					           |para el tipo de acceso ""%1"" el refinador desconocido ""%2"" est├í especificado.""
					           |
					           |Solo los siguientes refinadores son v├ílidos:
					           |-┬áAllDeniedByDefault
					           |- AllAllowedByDefault
					           |- PresetAccessKind';
					           |tr = '""%2"" eri┼čim t├╝r├╝ne ait profil a├ž─▒klamas─▒nda ""%1""
					           |bilinmeyen ar─▒t─▒c─▒ ""%3"" belirtilmi┼čtir.
					           |
					           | Sadece a┼ča─č─▒daki ar─▒t─▒c─▒lar ge├žerlidir: 
					           |- ""Ba┼člang─▒├žtaYasaklananlar"" veya """" 
					           |- "" ""Ba┼člang─▒├žta─░zinVerilenler"", 
					           |- ""├ľn ayar"".';
					           |it = 'Precisazione sconosciuta ""%3""
					           |indicato nella descrizione del profilo ""%1"" per tipo di accesso ""%2"".
					           |
					           |Sono permesse solo le seguenti precisazioni:
					           |- AllDeniedByDefault
					           |- AllAllowedByDefault
					           |- PresetAccessKind';
					           |de = 'Unbekannte Klarstellung ""%3""
					           |ist in der Beschreibung des ""%1"" Profils f├╝r die Zugriffsart ""%2"" angegeben.
					           |
					           |Nur folgende Klarstellungen sind erlaubt:
					           |- AllDeniedByDefault
					           |- AllAllowedByDefault
					           |- PresetAccessKind'"),
					?(ValueIsFilled(ProfileDetails.Name),
					  ProfileDetails.Name,
					  ProfileDetails.ID),
					AccessKindName,
					AccessKindClarification);
			EndIf;
			AccessKinds.Insert(AccessKindName, AccessKindClarification);
		EndDo;
		ProfileDetails.AccessKinds = AccessKinds;
		
		// Deleting duplicate values.
		AccessValues = New Array;
		AccessValuesTable = New ValueTable;
		AccessValuesTable.Columns.Add("AccessKind",      Metadata.DefinedTypes.AccessValue.Type);
		AccessValuesTable.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
		
		For Each ListItem In ProfileDetails.AccessValues Do
			Filter = New Structure;
			Filter.Insert("AccessKind",      ListItem.Value);
			Filter.Insert("AccessValue", ListItem.Presentation);
			AccessKind      = Filter.AccessKind;
			AccessValue = Filter.AccessValue;
			
			AccessKindProperties = AccessKindsProperties.ByNames.Get(AccessKind);
			If AccessKindProperties = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |Đâđ║đ░đĚđ░đŻ đŻđÁĐüĐâĐëđÁĐüĐéđ▓ĐâĐÄĐëđŞđ╣ đ▓đŞđ┤ đ┤đżĐüĐéĐâđ┐đ░ ""%2""
					           |đ┤đ╗ĐĆ đĚđŻđ░ĐçđÁđŻđŞĐĆ đ┤đżĐüĐéĐâđ┐đ░
					           |""%3"".'; 
					           |en = 'Non-existing access kind ""%2"" 
					           | is specified
					           |in description of the ""%1"" profile
					           |for access value ""%3"".'; 
					           |pl = 'Nieistniej─ůcy rodzaj dost─Öpu ""%2"" 
					           | jest okre┼Ťlony
					           |w opisie ""%1"" profilu
					           |dla warto┼Ťci dost─Öpu ""%3"".';
					           |es_ES = 'En la descripci├│n del perfil ""%1""
					           |se ha indicado un tipo de acceso no existente ""%2""
					           | para el valor de acceso
					           |""%3"".';
					           |es_CO = 'En la descripci├│n del perfil ""%1""
					           |se ha indicado un tipo de acceso no existente ""%2""
					           | para el valor de acceso
					           |""%3"".';
					           |tr = 'Profil a├ž─▒klamas─▒nda ""%1"" 
					           |eri┼čim de─čeri
					           |""%2"" i├žin ""%3"" 
					           |ge├žersiz eri┼čim t├╝r├╝ belirlendi.';
					           |it = 'Tipo di accesso ""%2"" non esistente
					           | indicato
					           |nella descrizione del profilo ""%1""
					           |per il valore di accesso ""%3"".';
					           |de = 'In der Profilbeschreibung ""%1""
					           |gibt es eine nicht vorhandene Zugriffsart ""%2""
					           |f├╝r den Zugriffswert
					           |""%3"".'"),
					?(ValueIsFilled(ProfileDetails.Name),
					  ProfileDetails.Name,
					  ProfileDetails.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			MetadataObject = Undefined;
			PointPosition = StrFind(AccessValue, ".");
			If PointPosition > 0 Then
				MetadataObjectKind = Left(AccessValue, PointPosition - 1);
				RowBalance = Mid(AccessValue, PointPosition + 1);
				PointPosition = StrFind(RowBalance, ".");
				If PointPosition > 0 Then
					MetadataObjectName = Left(RowBalance, PointPosition - 1);
					FullMetadataObjectName = MetadataObjectKind + "." + MetadataObjectName;
					MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
				EndIf;
			EndIf;
			
			If MetadataObject = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |đ┤đ╗ĐĆ đ▓đŞđ┤đ░ đ┤đżĐüĐéĐâđ┐đ░ ""%2""
					           |đŻđÁ ĐüĐâĐëđÁĐüĐéđ▓ĐâđÁĐé ĐéđŞđ┐ Đâđ║đ░đĚđ░đŻđŻđżđ│đż đĚđŻđ░ĐçđÁđŻđŞĐĆ đ┤đżĐüĐéĐâđ┐đ░
					           |""%3"".'; 
					           |en = 'Specified access type ""%3"" 
					           |for access kind ""%2"" 
					           |does not exist in description of the 
					           |""%1"" profile.'; 
					           |pl = 'Okre┼Ťlony rodzaj dost─Öpu ""%3"" 
					           |dla rodzaju dost─Öpu""%2"" 
					           |nie istnieje w opisie 
					           |""%1"" profilu.';
					           |es_ES = 'En la descripci├│n del perfil ""%1""
					           |para el tipo de acceso ""%2""
					           |no existe tipo del valor indicado de acceso
					           |""%3"".';
					           |es_CO = 'En la descripci├│n del perfil ""%1""
					           |para el tipo de acceso ""%2""
					           |no existe tipo del valor indicado de acceso
					           |""%3"".';
					           |tr = '""%2"" 
					           |profil a├ž─▒klamas─▒nda ""%1"" 
					           |eri┼čim t├╝r├╝ne ait ""%3""
					           | belirtilmi┼č eri┼čim de─čeri mevcut de─čildir.';
					           |it = 'Tipo di accesso ""%3"" indicato
					           |per tipi di accesso ""%2""
					           |non esiste nella descrizione del profilo 
					           |""%1"".';
					           |de = 'In der Profilbeschreibung ""%1""
					           |f├╝r Zugriffstyp ""%2""
					           |gibt es keine Art des angegebenen Zugriffswertes
					           |""%3"".'"),
					?(ValueIsFilled(ProfileDetails.Name),
					  ProfileDetails.Name,
					  ProfileDetails.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			Try
				AccessValuesBlankRef = Common.ObjectManagerByFullName(
					FullMetadataObjectName).EmptyRef();
			Except
				AccessValuesBlankRef = Undefined;
			EndTry;
			
			If AccessValuesBlankRef = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |đ┤đ╗ĐĆ đ▓đŞđ┤đ░ đ┤đżĐüĐéĐâđ┐đ░ ""%2""
					           |Đâđ║đ░đĚđ░đŻ đŻđÁ ĐüĐüĐőđ╗đżĐçđŻĐőđ╣ ĐéđŞđ┐ đĚđŻđ░ĐçđÁđŻđŞĐĆ đ┤đżĐüĐéĐâđ┐đ░
					           |""%3"".'; 
					           |en = 'Non-reference access value type ""%3""
					           | is specified in description of the ""%1"" profile
					           |for access kind
					           |""%2"".'; 
					           |pl = 'Typ warto┼Ťci dost─Öpu bez odniesienia ""%3""
					           | jest okre┼Ťlony w opisie ""%1"" profilu
					           |dla rodzaju dost─Öpu
					           |""%2"".';
					           |es_ES = 'En la descripci├│n del perfil ""%1""
					           |para el tipo de acceso ""%2""
					           |est├í indicado un tipo de valor de acceso no enlace
					           |""%3"".';
					           |es_CO = 'En la descripci├│n del perfil ""%1""
					           |para el tipo de acceso ""%2""
					           |est├í indicado un tipo de valor de acceso no enlace
					           |""%3"".';
					           |tr = '""%2"" 
					           |profil a├ž─▒klamas─▒nda ""%1"" 
					           |eri┼čim t├╝r├╝ne ait ""%3 
					           |referans t├╝r├╝ de─čeri belirlenmedi.';
					           |it = 'Tipo di valore di accesso non di riferimento ""%3""
					           |indicato nella descrizione del profilo ""%1""
					           |per tipo di accesso
					           |""%2"".';
					           |de = 'In der Profilbeschreibung ""%1""
					           |f├╝r die Zugriffsart ""%2""
					           |ist keine Referenzart des Zugriffswertes
					           |""%3""angegeben.'"),
					?(ValueIsFilled(ProfileDetails.Name),
					  ProfileDetails.Name,
					  ProfileDetails.ID),
					AccessKind,
					AccessValue);
			EndIf;
			AccessValueType = TypeOf(AccessValuesBlankRef);
			
			AccessKindPropertiesByType = AccessKindsProperties.ByValuesTypes.Get(AccessValueType);
			If AccessKindPropertiesByType = Undefined
			 OR AccessKindPropertiesByType.Name <> AccessKind Then
				
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |Đâđ║đ░đĚđ░đŻđż đĚđŻđ░ĐçđÁđŻđŞđÁ đ┤đżĐüĐéĐâđ┐đ░ ""%3""
					           |ĐéđŞđ┐đ░, đ║đżĐéđżĐÇĐőđ╣ đŻđÁ Đâđ║đ░đĚđ░đŻ đ▓ Đüđ▓đżđ╣ĐüĐéđ▓đ░Đů đ▓đŞđ┤đ░ đ┤đżĐüĐéĐâđ┐đ░ ""%2"".'; 
					           |en = 'Access value ""%3""
					           | of the type not specified in properties of access kind ""%2""
					           | is specified in description of profile ""%1"".'; 
					           |pl = 'Warto┼Ť─ç typu dost─Öpu ""%3""
					           | nie jest okre┼Ťlona we w┼éa┼Ťciwo┼Ťciach rodzaju dost─Öpu ""%2""
					           | jest okre┼Ťlona w opisie profilu ""%1"".';
					           |es_ES = 'En la descripci├│n del perfil ""%1""
					           |se ha indicado un valor de acceso ""%3""
					           |del tipo que se ha indicado en las propiedades del tipo de acceso ""%2"".';
					           |es_CO = 'En la descripci├│n del perfil ""%1""
					           |se ha indicado un valor de acceso ""%3""
					           |del tipo que se ha indicado en las propiedades del tipo de acceso ""%2"".';
					           |tr = 'Profil a├ž─▒klamas─▒nda ""%1""
					           | eri┼čim t├╝r├╝ ""%3"" ├Âzelliklerinde belirlenmeyen "
" t├╝r├╝n├╝n %2 eri┼čim de─čeri belirlendi.';
					           |it = 'Valore di accesso ""%3""
					           |del tipo non indicato nelle propriet├á del tipo di accesso ""%2""
					           | indicato nella descrizione del profilo ""%1"".';
					           |de = 'Die Profilbeschreibung ""%1""
					           |gibt den Zugriffswert ""%3""
					           |des Typs an, der nicht in den Eigenschaften der Zugriffsart ""%2"" angegeben ist.'"),
					?(ValueIsFilled(ProfileDetails.Name),
					  ProfileDetails.Name,
					  ProfileDetails.ID),
					AccessKind,
					AccessValue);
			EndIf;
			
			If AccessValuesTable.FindRows(Filter).Count() > 0 Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đĺ đżđ┐đŞĐüđ░đŻđŞđŞ đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |đ┤đ╗ĐĆ đ▓đŞđ┤đ░ đ┤đżĐüĐéĐâđ┐đ░ ""%2""
					           |đ┐đżđ▓ĐéđżĐÇđŻđż Đâđ║đ░đĚđ░đŻđż đĚđŻđ░ĐçđÁđŻđŞđÁ đ┤đżĐüĐéĐâđ┐đ░
					           |""%3"".'; 
					           |en = 'Access value ""%3""
					           | is specified repeatedly in description of profile ""%1""
					           | for access kind 
					           |""%2"".'; 
					           |pl = 'Warto┼Ť─ç dost─Öpu""%3""
					           | jest wielokrotnie okre┼Ťlona w opisie profilu ""%1""
					           | dla rodzaju dost─Öpu
					           |""%2"".';
					           |es_ES = 'En la descripci├│n del perfil ""%1""
					           |para el tipo de acceso ""%2""
					           |se ha indicado una vez m├ís el valor de acceso 
					           |""%3"".';
					           |es_CO = 'En la descripci├│n del perfil ""%1""
					           |para el tipo de acceso ""%2""
					           |se ha indicado una vez m├ís el valor de acceso 
					           |""%3"".';
					           |tr = '""%1"" profil a├ž─▒klamas─▒nda %3 eri┼čim t├╝r├╝ i├žin "
" 
					           |eri┼čim de─čeri ""%2"" 
					           |tekrar belirlendi.';
					           |it = 'Valore di accesso ""%3""
					           |indicato pi├╣ volte nella descrizione del profilo ""%1""
					           |per tipo di accesso 
					           |""%2"".';
					           |de = 'In der Profilbeschreibung ""%1""
					           |f├╝r Zugriffsart ""%2""
					           |wird der Zugriffswert
					           |""%3"" erneut angegeben.'"),
					?(ValueIsFilled(ProfileDetails.Name),
					  ProfileDetails.Name,
					  ProfileDetails.ID),
					AccessKind,
					AccessValue);
			EndIf;
			AccessValues.Add(Filter);
		EndDo;
		ProfileDetails.AccessValues = AccessValues;
	EndDo;
	
	SuppliedProfiles = New Structure;
	SuppliedProfiles.Insert("UpdateParameters",    UpdateParameters);
	SuppliedProfiles.Insert("ProfilesDetails",       ProfilesProperties);
	SuppliedProfiles.Insert("ProfilesDetailsArray", ProfilesDetailsArray);
	
	Return Common.FixedData(SuppliedProfiles);
	
EndFunction

// For the SuppliedProfiles procedure.
Function ProfileAssignmentPresentation(ProfileAssignment)
	
	If ProfileAssignment = "BothForUsersAndExternalUsers" Then
		Return NStr("ru = 'đíđżđ▓đ╝đÁĐüĐéđŻđż đ┤đ╗ĐĆ đ┐đżđ╗ĐîđĚđżđ▓đ░ĐéđÁđ╗đÁđ╣ đŞ đ▓đŻđÁĐłđŻđŞĐů đ┐đżđ╗ĐîđĚđżđ▓đ░ĐéđÁđ╗đÁđ╣'; en = 'Shared by users and external users'; pl = 'Udost─Öpnione przez u┼╝ytkownik├│w i u┼╝ytkownik├│w zewn─Ötrznych';es_ES = 'Para usuarios y usuarios externos';es_CO = 'Para usuarios y usuarios externos';tr = 'Kullan─▒c─▒lar ve harici kullan─▒c─▒lar i├žin ortak';it = 'Condiviso da utenti e utenti esterni';de = 'Gemeinsam f├╝r Benutzer und externe Benutzer'");
		
	ElsIf ProfileAssignment = "ForExternalUsers" Then
		Return NStr("ru = 'đöđ╗ĐĆ đ▓đŻđÁĐłđŻđŞĐů đ┐đżđ╗ĐîđĚđżđ▓đ░ĐéđÁđ╗đÁđ╣'; en = 'For external users'; pl = 'Dla u┼╝ytkownik├│w zewn─Ötrznych';es_ES = 'Para los usuarios externos';es_CO = 'Para los usuarios externos';tr = 'Harici kullan─▒c─▒lar i├žin';it = 'Per utenti esterni';de = 'F├╝r externe Benutzer'");
	EndIf;
	
	Return NStr("ru = 'đöđ╗ĐĆ đ┐đżđ╗ĐîđĚđżđ▓đ░ĐéđÁđ╗đÁđ╣'; en = 'For users'; pl = 'Dla u┼╝ytkownik├│w';es_ES = 'Para usuarios';es_CO = 'Para usuarios';tr = 'Kullan─▒c─▒lar i├žin';it = 'Per utenti';de = 'F├╝r Benutzer'");
	
EndFunction

Function PredefinedProfilesMatch(NewProfiles, OldProfiles, HasDeletedItems)
	
	If TypeOf(NewProfiles) <> TypeOf(OldProfiles) Then
		HasDeletedItems = True;
		Return False;
	EndIf;
	
	PredefinedProfilesMatch =
		NewProfiles.Count() = OldProfiles.Count();
	
	For Each Profile In OldProfiles Do
		If NewProfiles.Find(Profile) = Undefined Then
			PredefinedProfilesMatch = False;
			HasDeletedItems = True;
			Break;
		EndIf;
	EndDo;
	
	Return PredefinedProfilesMatch;
	
EndFunction

// Replaces an existing supplied access group profile by its description or creates a new one.
//
// Parameters:
//  ProfileProperties - FixedStructure - profile properties matching the structure returned by the 
//                    NewAccessGroupsProfileDetails function of the AccessManagement common module.
// 
// Returns:
//  Boolean. True - a profile is changed.
//
Function UpdateAccessGroupsProfile(ProfileProperties, DoNotUpdateUsersRoles = False)
	
	ProfileChanged = False;
	
	ProfileReference = SuppliedProfileByID(ProfileProperties.ID);
	If ProfileReference = Undefined Then
		
		If ValueIsFilled(ProfileProperties.Name) Then
			Query = New Query;
			Query.Text =
			"SELECT
			|	AccessGroupProfiles.Ref AS Ref,
			|	AccessGroupProfiles.PredefinedDataName AS PredefinedDataName
			|FROM
			|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
			|WHERE
			|	AccessGroupProfiles.Predefined = TRUE";
			Selection = Query.Execute().Select();
			
			While Selection.Next() Do
				PredefinedItemName = Selection.PredefinedDataName;
				If Upper(ProfileProperties.Name) = Upper(PredefinedItemName) Then
					ProfileReference = Selection.Ref;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If ProfileReference = Undefined Then
			// The supplied profile is not found and must be created.
			ProfileObject = CreateItem();
		Else
			// The supplied profile is associated with a predefined item.
			ProfileObject = ProfileReference.GetObject();
		EndIf;
		
		ProfileObject.SuppliedDataID =
			New UUID(ProfileProperties.ID);
		
		ProfileChanged = True;
	Else
		ProfileObject = ProfileReference.GetObject();
		ProfileChanged = SuppliedProfileChanged(ProfileObject);
	EndIf;
	
	If ProfileChanged Then
		
		If Not InfobaseUpdate.InfobaseUpdateInProgress()
		   AND Not InfobaseUpdate.IsCallFromUpdateHandler() Then
			
			LockDataForEdit(ProfileObject.Ref, ProfileObject.DataVersion);
		EndIf;
		
		ProfileObject.Description = ProfileProperties.Description;
		
		ProfileObject.Roles.Clear();
		For each Role In ProfileRolesDetails(ProfileProperties) Do
			RoleMetadata = Metadata.Roles.Find(Role);
			If RoleMetadata = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'đčĐÇđŞ đżđ▒đŻđżđ▓đ╗đÁđŻđŞđŞ đ┐đżĐüĐéđ░đ▓đ╗ĐĆđÁđ╝đżđ│đż đ┐ĐÇđżĐäđŞđ╗ĐĆ ""%1""
					           |ĐÇđżđ╗Đî ""%2"" đŻđÁ đŻđ░đ╣đ┤đÁđŻđ░ đ▓ đ╝đÁĐéđ░đ┤đ░đŻđŻĐőĐů.'; 
					           |en = 'The ""%2"" role was not found 
					           |in the metadata while updating supplied profile ""%1"".'; 
					           |pl = 'Podczas aktualizacji dostarczanego profilu ""%1""
					           | rola ""%2"" nie zosta┼éa znaleziona w metadanych.';
					           |es_ES = 'Al actualizar el perfil suministrado ""%1""
					           | el rol ""%2"" no se ha encontrado en metadatos.';
					           |es_CO = 'Al actualizar el perfil suministrado ""%1""
					           | el rol ""%2"" no se ha encontrado en metadatos.';
					           |tr = 'Sa─članan profil g├╝ncellenmesinde meta veride 
					           |%1rol ""%2"" bulunamad─▒.';
					           |it = 'Il ruolo ""%2"" non ├Ę stato trovato 
					           |nei metadati durante l''aggiornamento del profilo fornito ""%1"".';
					           |de = 'Bei der Aktualisierung des ausgelieferten Profils ""%1""
					           |wird die Rolle ""%2"" in den Metadaten nicht gefunden.'"),
					ProfileProperties.Description,
					Role);
			EndIf;
			ProfileObject.Roles.Add().Role =
				Common.MetadataObjectID(RoleMetadata);
		EndDo;
		
		ProfileObject.AccessKinds.Clear();
		For each AccessKindDetails In ProfileProperties.AccessKinds Do
			AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessKindDetails.Key);
			Row = ProfileObject.AccessKinds.Add();
			Row.AccessKind        = AccessKindProperties.Ref;
			Row.PresetAccessKind = AccessKindDetails.Value = "PresetAccessKind";
			Row.AllAllowed      = AccessKindDetails.Value = "AllAllowedByDefault";
		EndDo;
		
		ProfileObject.AccessValues.Clear();
		For each AccessValueDetails In ProfileProperties.AccessValues Do
			AccessKindProperties = AccessManagementInternal.AccessKindProperties(AccessValueDetails.AccessKind);
			ValueRow = ProfileObject.AccessValues.Add();
			ValueRow.AccessKind = AccessKindProperties.Ref;
			Query = New Query(StrReplace("SELECT Value(%1) AS Value", "%1", AccessValueDetails.AccessValue));
			ValueRow.AccessValue = Query.Execute().Unload()[0].Value;
		EndDo;
		
		ProfileObject.Purpose.Clear();
		For each AssignmentType In ProfileProperties.Purpose Do
			AssignmentRow = ProfileObject.Purpose.Add();
			AssignmentRow.UsersType = AssignmentType;
		EndDo;
		
		If DoNotUpdateUsersRoles Then
			ProfileObject.AdditionalProperties.Insert("DoNotUpdateUsersRoles");
		EndIf;
		
		InfobaseUpdate.WriteObject(ProfileObject);
		
		If Not InfobaseUpdate.InfobaseUpdateInProgress()
		   AND Not InfobaseUpdate.IsCallFromUpdateHandler() Then
			
			UnlockDataForEdit(ProfileObject.Ref);
		EndIf;
		
	EndIf;
	
	Return ProfileChanged;
	
EndFunction

Function ProfileRolesDetails(ProfileDetails)
	
	If Not Common.DataSeparationEnabled() Then
		Return ProfileDetails.Roles;
	EndIf;
	
	ProfileAssignment = AccessManagementInternalClientServer.ProfileAssignment(ProfileDetails);
	UnavailableRoles = UsersInternalCached.UnavailableRoles(ProfileAssignment);
	
	ProfileRolesDetails = New Array;
	
	For Each Role In ProfileDetails.Roles Do
		If UnavailableRoles.Get(Role) = Undefined Then
			ProfileRolesDetails.Add(Role);
		EndIf;
	EndDo;
	
	Return New FixedArray(ProfileRolesDetails);
	
EndFunction

Function ProfileRolesUnavailableInService(ProfileDetails, ProfileAssignment)
	
	UnavailableRoles = UsersInternalCached.UnavailableRoles(ProfileAssignment, True);
	UnavailableProfileRoles = New Map;
	
	For Each Role In ProfileDetails.Roles Do
		If UnavailableRoles.Get(Role) <> Undefined Then
			UnavailableProfileRoles.Insert(Role, True);
		EndIf;
	EndDo;
	
	Return New FixedMap(UnavailableProfileRoles);
	
EndFunction

#EndRegion

#EndIf
