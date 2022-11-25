
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT ValueIsFilled(Parameters.User) Then
		If AccessManagementInternal.SimplifiedAccessRightsSetupInterface() Then
			Raise
				NStr("ru = 'Чтобы открыть отчет, откройте карточку пользователя,
				           |перейдите по ссылке ""Права доступа"", нажмите на кнопку ""Отчет по правам доступа"".'; 
				           |en = 'To open the report, open the user profile,
				           |click ""Access rights"", and then click ""Access rights report"".'; 
				           |pl = 'Aby otworzyć raport, otwórz kartę użytkownika,
				           |kliknij link ""Prawa dostępu"", a następnie ""Raport o prawach dostępu"".';
				           |es_ES = 'Para abrir el informe, abrir la tarjeta de usuario,
				           |hacer clic en el enlace ""Derechos de acceso"", y después hacer clic en ""Informe de derechos de acceso"".';
				           |es_CO = 'Para abrir el informe, abrir la tarjeta de usuario,
				           |hacer clic en el enlace ""Derechos de acceso"", y después hacer clic en ""Informe de derechos de acceso"".';
				           |tr = 'Raporu açmak için kullanıcı kartını açın, 
				           |""Erişim hakları"" bağlantısını tıklayın ve ardından ""Erişim hakları raporu"" ''nu tıklayın.';
				           |it = 'Per aprire il report, aprire profilo utente,
				           |cliccare su ""Diritti di accesso"", poi cliccare su ""Rapporto diritti di accesso"".';
				           |de = 'Um den Bericht zu öffnen, öffnen Sie das Benutzerprofil,
				           |klicken Sie auf den Link ""Zugriffsrechte"" und dann auf ""Zugriffsrechte Bericht"".'");
		Else
			Raise
				NStr("ru = 'Чтобы открыть отчет откройте карточку пользователя или группы пользователей,
				           |перейдите по ссылке ""Права доступа"", нажмите на кнопку ""Отчет по правам доступа"".'; 
				           |en = 'To open the report, open the user profile or user group profile, 
				           |click ""Access rights"", and then click ""Access rights report"".'; 
				           |pl = 'Aby otworzyć raport, otwórz kartę użytkownika lub grupy użytkowników,
				           |kliknij link ""Prawa dostępu"", a następnie ""Raport o prawach dostępu"".';
				           |es_ES = 'Para abrir el informe, abrir la tarjeta de usuario o la tarjeta del grupo de usuarios,
				           |hacer clic en el enlace ""Derechos de acceso"", y después hacer clic en ""Informe de derechos de acceso"".';
				           |es_CO = 'Para abrir el informe, abrir la tarjeta de usuario o la tarjeta del grupo de usuarios,
				           |hacer clic en el enlace ""Derechos de acceso"", y después hacer clic en ""Informe de derechos de acceso"".';
				           |tr = 'Raporu açmak için kullanıcı kartını veya kullanıcı grubu kartını açın, 
				           |""Erişim hakları"" bağlantısını tıklayın ve ardından ""Erişim hakları raporu"" ''nu tıklayın.';
				           |it = 'Per aprire il report, aprire profilo utente o profilo del gruppo utenti,
				           |cliccare su ""Diritti di accesso"", poi cliccare su ""Rapporto diritti di accesso"".';
				           |de = 'Um den Bericht zu öffnen, öffnen Sie das Benutzerprofil oder das Benutzergruppenprofil,
				           |klicken Sie auf ""Zugriffsrechte"" und dann auf ""Zugriffsrechte Bericht"".'");
		EndIf;
	EndIf;
	
	If Parameters.User <> Users.AuthorizedUser()
	   AND NOT Users.IsFullUser() Then
		
		Raise NStr("ru = 'Недостаточно прав для просмотра отчета.'; en = 'Insufficient rights to view the report.'; pl = 'Niewystarczające uprawnienia do przeglądania raportu.';es_ES = 'Insuficientes derechos para ver el informe.';es_CO = 'Insuficientes derechos para ver el informe.';tr = 'Raporu görmek için yetersiz haklar.';it = 'Non ci sono abbastanza diritti per visualizzare il report.';de = 'Unzureichende Rechte zum Anzeigen des Berichts.'");
	EndIf;
	
	Items.AccessRightsDetailedInfo.Visible =
		NOT AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
	
	OutputReport(Parameters.User);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DocumentDetailsProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Details) = Type("String")
		AND StrStartsWith(Details, "OpenListForm: ") Then
		
		StandardProcessing = False;
		OpenForm(Mid(Details, StrLen("OpenListForm: ") + 1) + ".ListForm");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Generate(Command)
	
	OutputReport(Parameters.User);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure OutputReport(UserOrGroup)
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	InformationRegisters.RolesRights.CheckRegisterData();
	
	OutputGroupRights = TypeOf(Parameters.User) = Type("CatalogRef.UserGroups")
	              OR TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsersGroups");
	SimplifiedInterface = AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
	
	Document = New SpreadsheetDocument;
	Template = FormAttributeToValue("Report").GetTemplate("Template");
	
	Properties = New Structure;
	Properties.Insert("Ref", UserOrGroup);
	
	OutputReportHeader(Template, Properties, UserOrGroup);
	
	// Displaying the infobase user properties for a user and an external user.
	If NOT OutputGroupRights Then
		OutputIBUserProperties(Template, UserOrGroup);
	EndIf;
	
	// The report on administrator rights.
	If TypeOf(UserOrGroup) = Type("CatalogRef.Users")
		OR TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
		
		SetPrivilegedMode(True);
		InfobaseUser = InfoBaseUsers.FindByUUID(
			Common.ObjectAttributeValue(UserOrGroup, "IBUserID"));
		SetPrivilegedMode(False);
		
		If Users.IsFullUser(InfobaseUser, True) Then
			
			Area = Template.GetArea("FullUser");
			Document.Put(Area, 1);
			Return;
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	QueryResults = SelectInfoOnAccessRights(AvailableRights, OutputGroupRights, UserOrGroup);
	
	Document.StartRowAutoGrouping();
	
	If AccessRightsDetailedInfo Then
		OutputDetailedInfoOnAccessRights(Template, UserOrGroup, QueryResults[3], Properties);
		OutputRolesByProfiles(Template, UserOrGroup, QueryResults[5], Properties);
	EndIf;
	
	OutputAvailableForView(AvailableRights, Template, QueryResults[9], SimplifiedInterface);
	OutputAvailableForEdit(AvailableRights, Template, QueryResults[10], SimplifiedInterface);
	OutputRightsToSeparateObjects(AvailableRights, Template, QueryResults[6], OutputGroupRights);
	
	Document.EndRowAutoGrouping();
	
EndProcedure

&AtServer
Function SelectInfoOnAccessRights(Val AvailableRights, Val OutputGroupRights, Val UserOrGroup)
	
	Query = New Query;
	Query.SetParameter("User",        UserOrGroup);
	Query.SetParameter("OutputGroupRights",     OutputGroupRights);
	Query.SetParameter("AccessRestrictionKinds", MetadataObjectsRightsRestrictionsKinds());
	Query.SetParameter("RightsSettingsOwnersTypes", AvailableRights.OwnersTypes);
	Query.SetParameter("ExtensionsRolesRights", AccessManagementInternal.ExtensionsRolesRights());
	
	Query.Text =
	"SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.Insert AS Insert,
	|	ExtensionsRolesRights.Update AS UpdateRight,
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
	|	ExtensionsRolesRights.UpdateRight AS UpdateRight,
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
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.Profile AS Profile,
	|	AccessGroupsUsers.User AS User,
	|	CASE
	|		WHEN VALUETYPE(AccessGroupsUsers.User) <> TYPE(Catalog.Users)
	|				AND VALUETYPE(AccessGroupsUsers.User) <> TYPE(Catalog.ExternalUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS GroupParticipation
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON AccessGroups.Ref = AccessGroupsUsers.Ref
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroups.Profile.DeletionMark)
	|			AND (CASE
	|				WHEN &OutputGroupRights
	|					THEN AccessGroupsUsers.User = &User
	|				ELSE TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|						WHERE
	|							UserGroupCompositions.UsersGroup = AccessGroupsUsers.User
	|							AND UserGroupCompositions.User = &User)
	|			END)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserAccessGroups.AccessGroup AS AccessGroup,
	|	PRESENTATION(UserAccessGroups.AccessGroup) AS PresentationAccessGroups,
	|	UserAccessGroups.User AS Member,
	|	UserAccessGroups.User.Description AS ParticipantPresentation,
	|	UserAccessGroups.GroupParticipation AS GroupParticipation,
	|	UserAccessGroups.AccessGroup.EmployeeResponsible AS EmployeeResponsible,
	|	UserAccessGroups.AccessGroup.EmployeeResponsible.Description AS EmployeeResponsiblePresentation,
	|	UserAccessGroups.AccessGroup.Comment AS Comment,
	|	UserAccessGroups.AccessGroup.Profile AS Profile,
	|	PRESENTATION(UserAccessGroups.AccessGroup.Profile) AS ProfilePresentation
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|TOTALS
	|	MAX(Member)
	|BY
	|	AccessGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UserAccessGroups.Profile AS Profile
	|INTO UserProfiles
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserProfiles.Profile AS Profile,
	|	PRESENTATION(UserProfiles.Profile) AS ProfilePresentation,
	|	ProfileRoles.Role.Name AS Role,
	|	ProfileRoles.Role.Synonym AS RolePresentation
	|FROM
	|	UserProfiles AS UserProfiles
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|		ON UserProfiles.Profile = ProfileRoles.Ref
	|TOTALS
	|	MAX(Profile),
	|	MAX(ProfilePresentation),
	|	MAX(Role),
	|	MAX(RolePresentation)
	|BY
	|	Profile,
	|	Role
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	VALUETYPE(ObjectsRightsSettings.Object) AS ObjectsType,
	|	ObjectsRightsSettings.Object AS Object,
	|	ISNULL(SettingsInheritance.Inherit, TRUE) AS Inherit,
	|	CASE
	|		WHEN VALUETYPE(ObjectsRightsSettings.User) <> TYPE(Catalog.Users)
	|				AND VALUETYPE(ObjectsRightsSettings.User) <> TYPE(Catalog.ExternalUsers)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS GroupParticipation,
	|	ObjectsRightsSettings.User AS User,
	|	ObjectsRightsSettings.User.Description AS UserDescription,
	|	ObjectsRightsSettings.UserRight AS UserRight,
	|	ObjectsRightsSettings.RightIsProhibited AS RightIsProhibited,
	|	ObjectsRightsSettings.InheritanceIsAllowed AS InheritanceIsAllowed
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS ObjectsRightsSettings
	|		LEFT JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|		ON (SettingsInheritance.Object = ObjectsRightsSettings.Object)
	|			AND (SettingsInheritance.Parent = ObjectsRightsSettings.Object)
	|WHERE
	|	CASE
	|			WHEN &OutputGroupRights
	|				THEN ObjectsRightsSettings.User = &User
	|			ELSE TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|					WHERE
	|						UserGroupCompositions.UsersGroup = ObjectsRightsSettings.User
	|						AND UserGroupCompositions.User = &User)
	|		END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUETYPE(SettingsInheritance.Object),
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Inherit,
	|	FALSE,
	|	UNDEFINED,
	|	"""",
	|	"""",
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|		LEFT JOIN InformationRegister.ObjectsRightsSettings AS ObjectsRightsSettings
	|		ON (ObjectsRightsSettings.Object = SettingsInheritance.Object)
	|			AND (ObjectsRightsSettings.Object = SettingsInheritance.Parent)
	|WHERE
	|	SettingsInheritance.Object = SettingsInheritance.Parent
	|	AND SettingsInheritance.Inherit = FALSE
	|	AND ObjectsRightsSettings.Object IS NULL
	|TOTALS
	|	MAX(Inherit),
	|	MAX(GroupParticipation),
	|	MAX(User),
	|	MAX(UserDescription),
	|	MAX(InheritanceIsAllowed)
	|BY
	|	ObjectsType,
	|	Object,
	|	User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessRestrictionKinds.Table AS Table,
	|	AccessRestrictionKinds.UserRight AS UserRight,
	|	AccessRestrictionKinds.AccessKind AS AccessKind,
	|	AccessRestrictionKinds.Presentation AS AccessKindPresentation
	|INTO AccessRestrictionKinds
	|FROM
	|	&AccessRestrictionKinds AS AccessRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserAccessGroups.Profile AS Profile,
	|	UserAccessGroups.AccessGroup AS AccessGroup,
	|	ISNULL(AccessGroupsAccessKinds.AccessKind, UNDEFINED) AS AccessKind,
	|	ISNULL(AccessGroupsAccessKinds.AllAllowed, FALSE) AS AllAllowed,
	|	ISNULL(AccessGroupsAccessValues.AccessValue, UNDEFINED) AS AccessValue
	|INTO AccessKindsAndValues
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		LEFT JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON (AccessGroupsAccessKinds.Ref = UserAccessGroups.AccessGroup)
	|		LEFT JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON (AccessGroupsAccessValues.Ref = AccessGroupsAccessKinds.Ref)
	|			AND (AccessGroupsAccessValues.AccessKind = AccessGroupsAccessKinds.AccessKind)
	|
	|UNION
	|
	|SELECT
	|	UserAccessGroups.Profile,
	|	UserAccessGroups.AccessGroup,
	|	AccessGroupProfilesAccessKinds.AccessKind,
	|	AccessGroupProfilesAccessKinds.AllAllowed,
	|	ISNULL(AccessGroupProfilesAccessValues.AccessValue, UNDEFINED)
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS AccessGroupProfilesAccessKinds
	|		ON (AccessGroupProfilesAccessKinds.Ref = UserAccessGroups.Profile)
	|		LEFT JOIN Catalog.AccessGroupProfiles.AccessValues AS AccessGroupProfilesAccessValues
	|		ON (AccessGroupProfilesAccessValues.Ref = AccessGroupProfilesAccessKinds.Ref)
	|			AND (AccessGroupProfilesAccessValues.AccessKind = AccessGroupProfilesAccessKinds.AccessKind)
	|WHERE
	|	AccessGroupProfilesAccessKinds.PresetAccessKind
	|
	|UNION
	|
	|SELECT
	|	UserAccessGroups.Profile,
	|	UserAccessGroups.AccessGroup,
	|	AccessKindsRightsSettings.EmptyRefValue,
	|	FALSE,
	|	UNDEFINED
	|FROM
	|	UserAccessGroups AS UserAccessGroups
	|		INNER JOIN Catalog.MetadataObjectIDs AS AccessKindsRightsSettings
	|		ON (AccessKindsRightsSettings.EmptyRefValue IN (&RightsSettingsOwnersTypes))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfileRolesRights.Table.Parent.Name AS ObjectsKind,
	|	ProfileRolesRights.Table.Parent.Synonym AS ObjectsKindPresentation,
	|	ProfileRolesRights.Table.Parent.CollectionOrder AS ObjectKindOrder,
	|	ProfileRolesRights.Table.FullName AS Table,
	|	ProfileRolesRights.Table.Name AS Object,
	|	ProfileRolesRights.Table.Synonym AS ObjectPresentation,
	|	ProfileRolesRights.Profile AS Profile,
	|	ProfileRolesRights.Profile.Description AS ProfilePresentation,
	|	ProfileRolesRights.Role.Name AS Role,
	|	ProfileRolesRights.Role.Synonym AS RolePresentation,
	|	ProfileRolesRights.RolesKind AS RolesKind,
	|	ProfileRolesRights.ReadWithoutRestriction AS ReadWithoutRestriction,
	|	ProfileRolesRights.View AS View,
	|	ProfileRolesRights.AccessGroup AS AccessGroup,
	|	ProfileRolesRights.AccessGroup.Description AS PresentationAccessGroups,
	|	ProfileRolesRights.AccessKind AS AccessKind,
	|	ProfileRolesRights.AccessKindPresentation AS AccessKindPresentation,
	|	ProfileRolesRights.AllAllowed AS AllAllowed,
	|	ProfileRolesRights.AccessValue AS AccessValue,
	|	PRESENTATION(ProfileRolesRights.AccessValue) AS AccessValuePresentation
	|FROM
	|	(SELECT
	|		RolesRights.MetadataObject AS Table,
	|		ProfileRoles.Ref AS Profile,
	|		CASE
	|			WHEN RolesRights.View
	|					AND RolesRights.ReadWithoutRestriction
	|				THEN 0
	|			WHEN NOT RolesRights.View
	|					AND RolesRights.ReadWithoutRestriction
	|				THEN 1
	|			WHEN RolesRights.View
	|					AND NOT RolesRights.ReadWithoutRestriction
	|				THEN 2
	|			ELSE 3
	|		END AS RolesKind,
	|		RolesRights.Role AS Role,
	|		RolesRights.ReadWithoutRestriction AS ReadWithoutRestriction,
	|		RolesRights.View AS View,
	|		UNDEFINED AS AccessGroup,
	|		UNDEFINED AS AccessKind,
	|		"""" AS AccessKindPresentation,
	|		UNDEFINED AS AllAllowed,
	|		UNDEFINED AS AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfileRoles.Role
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfileRoles.Role
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.UserRight = ""Read"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)) AS ProfileRolesRights
	|TOTALS
	|	MAX(ObjectsKindPresentation),
	|	MAX(ObjectKindOrder),
	|	MAX(Table),
	|	MAX(ObjectPresentation),
	|	MAX(ProfilePresentation),
	|	MAX(RolePresentation),
	|	MAX(ReadWithoutRestriction),
	|	MAX(View),
	|	MAX(PresentationAccessGroups),
	|	MAX(AccessKindPresentation),
	|	MAX(AllAllowed)
	|BY
	|	ObjectsKind,
	|	Object,
	|	Profile,
	|	RolesKind,
	|	Role,
	|	AccessGroup,
	|	AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfileRolesRights.Table.Parent.Name AS ObjectsKind,
	|	ProfileRolesRights.Table.Parent.Synonym AS ObjectsKindPresentation,
	|	ProfileRolesRights.Table.Parent.CollectionOrder AS ObjectKindOrder,
	|	ProfileRolesRights.Table.FullName AS Table,
	|	ProfileRolesRights.Table.Name AS Object,
	|	ProfileRolesRights.Table.Synonym AS ObjectPresentation,
	|	ProfileRolesRights.Profile AS Profile,
	|	ProfileRolesRights.Profile.Description AS ProfilePresentation,
	|	ProfileRolesRights.Role.Name AS Role,
	|	ProfileRolesRights.Role.Synonym AS RolePresentation,
	|	ProfileRolesRights.RolesKind AS RolesKind,
	|	ProfileRolesRights.Insert AS Insert,
	|	ProfileRolesRights.UpdateRight AS UpdateRight,
	|	ProfileRolesRights.InsertWithoutRestriction AS InsertWithoutRestriction,
	|	ProfileRolesRights.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|	ProfileRolesRights.InteractiveInsert AS InteractiveInsert,
	|	ProfileRolesRights.Edit AS Edit,
	|	ProfileRolesRights.AccessGroup AS AccessGroup,
	|	ProfileRolesRights.AccessGroup.Description AS PresentationAccessGroups,
	|	ProfileRolesRights.AccessKind AS AccessKind,
	|	ProfileRolesRights.AccessKindPresentation AS AccessKindPresentation,
	|	ProfileRolesRights.AllAllowed AS AllAllowed,
	|	ProfileRolesRights.AccessValue AS AccessValue,
	|	PRESENTATION(ProfileRolesRights.AccessValue) AS AccessValuePresentation
	|FROM
	|	(SELECT
	|		RolesRights.MetadataObject AS Table,
	|		ProfileRoles.Ref AS Profile,
	|		CASE
	|			WHEN RolesRights.InsertWithoutRestriction
	|					AND RolesRights.UpdateWithoutRestriction
	|				THEN 0
	|			WHEN NOT RolesRights.InsertWithoutRestriction
	|					AND RolesRights.UpdateWithoutRestriction
	|				THEN 100
	|			WHEN RolesRights.InsertWithoutRestriction
	|					AND NOT RolesRights.UpdateWithoutRestriction
	|				THEN 200
	|			ELSE 300
	|		END + CASE
	|			WHEN RolesRights.Insert
	|					AND RolesRights.UpdateRight
	|				THEN 0
	|			WHEN NOT RolesRights.Insert
	|					AND RolesRights.UpdateRight
	|				THEN 10
	|			WHEN RolesRights.Insert
	|					AND NOT RolesRights.UpdateRight
	|				THEN 20
	|			ELSE 30
	|		END + CASE
	|			WHEN RolesRights.InteractiveInsert
	|					AND RolesRights.Edit
	|				THEN 0
	|			WHEN NOT RolesRights.InteractiveInsert
	|					AND RolesRights.Edit
	|				THEN 1
	|			WHEN RolesRights.InteractiveInsert
	|					AND NOT RolesRights.Edit
	|				THEN 2
	|			ELSE 3
	|		END AS RolesKind,
	|		RolesRights.Role AS Role,
	|		RolesRights.Insert AS Insert,
	|		RolesRights.UpdateRight AS UpdateRight,
	|		RolesRights.InsertWithoutRestriction AS InsertWithoutRestriction,
	|		RolesRights.UpdateWithoutRestriction AS UpdateWithoutRestriction,
	|		RolesRights.InteractiveInsert AS InteractiveInsert,
	|		RolesRights.Edit AS Edit,
	|		UNDEFINED AS AccessGroup,
	|		UNDEFINED AS AccessKind,
	|		"""" AS AccessKindPresentation,
	|		UNDEFINED AS AllAllowed,
	|		UNDEFINED AS AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfileRoles.Role
	|				AND (RolesRights.Insert
	|					OR RolesRights.UpdateRight)
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfileRoles.Role
	|				AND (RolesRights.Insert)
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.UserRight = ""Insert"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)
	|	
	|	UNION
	|	
	|	SELECT
	|		RolesRights.MetadataObject,
	|		UserProfiles.Profile,
	|		1000,
	|		"""",
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		AccessKindsAndValues.AccessGroup,
	|		ISNULL(AccessRestrictionKinds.AccessKind, UNDEFINED),
	|		ISNULL(AccessRestrictionKinds.AccessKindPresentation, """"),
	|		AccessKindsAndValues.AllAllowed,
	|		AccessKindsAndValues.AccessValue
	|	FROM
	|		RolesRights AS RolesRights
	|			INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|				INNER JOIN UserProfiles AS UserProfiles
	|				ON ProfileRoles.Ref = UserProfiles.Profile
	|			ON RolesRights.Role = ProfileRoles.Role
	|				AND (RolesRights.UpdateRight)
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (UserProfiles.Profile = AccessKindsAndValues.Profile)
	|			LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			ON (AccessRestrictionKinds.Table = RolesRights.MetadataObject)
	|				AND (AccessRestrictionKinds.UserRight = ""Update"")
	|				AND (AccessRestrictionKinds.AccessKind = AccessKindsAndValues.AccessKind)) AS ProfileRolesRights
	|TOTALS
	|	MAX(ObjectsKindPresentation),
	|	MAX(ObjectKindOrder),
	|	MAX(Table),
	|	MAX(ObjectPresentation),
	|	MAX(ProfilePresentation),
	|	MAX(RolePresentation),
	|	MAX(Insert),
	|	MAX(UpdateRight),
	|	MAX(InsertWithoutRestriction),
	|	MAX(UpdateWithoutRestriction),
	|	MAX(InteractiveInsert),
	|	MAX(Edit),
	|	MAX(PresentationAccessGroups),
	|	MAX(AccessKindPresentation),
	|	MAX(AllAllowed)
	|BY
	|	ObjectsKind,
	|	Object,
	|	Profile,
	|	RolesKind,
	|	Role,
	|	AccessGroup,
	|	AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsAndValues.Profile AS Profile,
	|	AccessKindsAndValues.AccessGroup AS AccessGroup,
	|	AccessKindsAndValues.AccessKind AS AccessKind,
	|	AccessKindsAndValues.AllAllowed AS AllAllowed,
	|	AccessKindsAndValues.AccessValue AS AccessValue
	|FROM
	|	AccessKindsAndValues AS AccessKindsAndValues";
	
	Return Query.ExecuteBatch();

EndFunction

&AtServer
Procedure OutputAvailableForView(Val AvailableRights, Val Template, Val QueryResult, Val SimplifiedInterface)
	
	IndentArea = Template.GetArea("Indent");
	RightsObjects = QueryResult.Unload(QueryResultIteration.ByGroups);
	
	RightsObjects.Rows.Sort(
		"ObjectKindOrder Asc,
		|ObjectPresentation Asc,
		|ProfilePresentation Asc,
		|RolesKind Asc,
		|RolePresentation Asc,
		|PresentationAccessGroups Asc,
		|AccessKindPresentation Asc,
		|AccessValuePresentation Asc",
		True);
	
	Area = Template.GetArea("ObjectsRightsGroup");
	Area.Parameters.ObjectsRightsGroupPresentation = NStr("ru = 'Просмотр объектов'; en = 'View objects'; pl = 'Przeglądanie obiektów';es_ES = 'Ver los objetos';es_CO = 'Ver los objetos';tr = 'Nesneleri görüntüle';it = 'Visualizza oggetti';de = 'Ansicht Objekte'");
	Document.Put(Area, 1);
	Area = Template.GetArea("ViewObjectsLegend");
	Document.Put(Area, 2);
	
	RightsSettingsOwners = AvailableRights.ByRefsTypes;
	
	For each ObjectsKindDetails In RightsObjects.Rows Do
		Area = Template.GetArea("ObjectRightsTableTitle");
		If SimplifiedInterface Then
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("ru = 'Профили'; en = 'Profiles'; pl = 'Profile';es_ES = 'Perfiles';es_CO = 'Perfiles';tr = 'Profiller';it = 'Profili';de = 'Profile'");
		Else
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("ru = 'Группы доступа'; en = 'Access groups'; pl = 'Grupy dostępu';es_ES = 'Grupos de acceso';es_CO = 'Grupos de acceso';tr = 'Erişim grupları';it = 'Gruppi di accesso';de = 'Zugriffsgruppen'");
		EndIf;
		Area.Parameters.Fill(ObjectsKindDetails);
		Document.Put(Area, 2);
		
		Area = Template.GetArea("ObjectRightsTableTitleAddl");
		If AccessRightsDetailedInfo Then
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("ru = '(профиль, роли)'; en = '(profile, roles)'; pl = '(profile, role)';es_ES = '(perfil, roles)';es_CO = '(perfil, roles)';tr = '(profil, roller)';it = '(profilo, ruoli)';de = '(Profil, Rollen)'");
		Else
			Area.Parameters.ProfilesOrAccessGroupsPresentation = "";
		EndIf;
		Area.Parameters.Fill(ObjectsKindDetails);
		Document.Put(Area, 3);
		
		For each ObjectDetails In ObjectsKindDetails.Rows Do
			ObjectAreaInitialString = Undefined;
			ObjectAreaEndRow  = Undefined;
			Area = Template.GetArea("ObjectRightsTableString");
			
			Area.Parameters.OpenListForm = "OpenListForm: " + ObjectDetails.Table;
			
			If ObjectDetails.ReadWithoutRestriction Then
				If ObjectDetails.View Then
					ObjectPresentationClarification = NStr("ru = '(просмотр, не ограничен)'; en = '(view, not restricted)'; pl = '(widok, bez ograniczeń)';es_ES = '(ver, no limitado)';es_CO = '(ver, no limitado)';tr = '(görünüm, sınırlı değil)';it = '(visualizzazione, non limitata)';de = '(Ansicht, nicht begrenzt)'");
				Else
					ObjectPresentationClarification = NStr("ru = '(просмотр*, не ограничен)'; en = '(view*, not restricted)'; pl = '(widok*, bez ograniczeń)';es_ES = '(ver*, no limitado)';es_CO = '(ver*, no limitado)';tr = '(görünüm *, sınırlı değil)';it = '(visualizzazione*, non limitata)';de = '(Ansicht*, nicht begrenzt)'");
				EndIf;
			Else
				If ObjectDetails.View Then
					ObjectPresentationClarification = NStr("ru = '(просмотр, ограничен)'; en = '(view, restricted)'; pl = '(widok, ograniczony)';es_ES = '(ver, limitado)';es_CO = '(ver, limitado)';tr = '(görünüm, sınırlı)';it = '(visualizzazione, ristretta)';de = '(Ansicht, begrenzt)'");
				Else
					ObjectPresentationClarification = NStr("ru = '(просмотр*, ограничен)'; en = '(view*, restricted)'; pl = '(widok*, ograniczony)';es_ES = '(ver*, limitado)';es_CO = '(ver*, limitado)';tr = '(görünüm *, sınırlı)';it = '(visualizzazione* ristretta)';de = '(Ansicht*, begrenzt)'");
				EndIf;
			EndIf;
			
			Area.Parameters.ObjectPresentation =
			ObjectDetails.ObjectPresentation + Chars.LF + ObjectPresentationClarification;
			
			For each ProfileDetails In ObjectDetails.Rows Do
				ProfileRolesPresentation = "";
				RolesCount = 0;
				AllRolesWithRestriction = True;
				For each RoleKindDetails In ProfileDetails.Rows Do
					If RoleKindDetails.RolesKind < 1000 Then
						// Description of the role with or without restrictions.
						For each RoleDetails In RoleKindDetails.Rows Do
							
							If RoleKindDetails.ReadWithoutRestriction Then
								AllRolesWithRestriction = False;
							EndIf;
							
							If NOT AccessRightsDetailedInfo Then
								Continue;
							EndIf;
							
							If RoleKindDetails.Rows.Count() > 1
								AND RoleKindDetails.Rows.IndexOf(RoleDetails)
								< RoleKindDetails.Rows.Count()-1 Then
								
								ProfileRolesPresentation
								= ProfileRolesPresentation
								+ RoleDetails.RolePresentation + ",";
								
								RolesCount = RolesCount + 1;
							EndIf;
							
							If RoleKindDetails.Rows.IndexOf(RoleDetails) =
								RoleKindDetails.Rows.Count()-1 Then
								
								ProfileRolesPresentation
								= ProfileRolesPresentation
								+ RoleDetails.RolePresentation
								+ ",";
								
								RolesCount = RolesCount + 1;
							EndIf;
							ProfileRolesPresentation = ProfileRolesPresentation + Chars.LF;
						EndDo;
					ElsIf RoleKindDetails.Rows[0].Rows.Count() > 0 Then
						// Description of access restrictions for roles with restrictions.
						For each AccessGroupDetails In RoleKindDetails.Rows[0].Rows Do
							Index = AccessGroupDetails.Rows.Count()-1;
							While Index >= 0 Do
								If AccessGroupDetails.Rows[Index].AccessKind = Undefined Then
									AccessGroupDetails.Rows.Delete(Index);
								EndIf;
								Index = Index-1;
							EndDo;
							AccessGroupAreaInitialRow = Undefined;
							If Area = Undefined Then
								Area = Template.GetArea("ObjectRightsTableString");
							EndIf;
							If SimplifiedInterface Then
								Area.Parameters.ProfileOrAccessGroup = ProfileDetails.AccessGroup;
								
								Area.Parameters.ProfileOrAccessGroupPresentation =
								ProfileDetails.PresentationAccessGroups;
							Else
								Area.Parameters.ProfileOrAccessGroup = AccessGroupDetails.AccessGroup;
								If AccessRightsDetailedInfo Then
									ProfileRolesPresentation = TrimAll(ProfileRolesPresentation);
									
									If ValueIsFilled(ProfileRolesPresentation)
										AND StrEndsWith(ProfileRolesPresentation, ",") Then
										
										ProfileRolesPresentation = Left(
										ProfileRolesPresentation,
										StrLen(ProfileRolesPresentation) - 1);
									EndIf;
									
									If RolesCount > 1 Then
										PresentationClarificationAccessGroups =
										NStr("ru = '(профиль: %1, роли:
										|%2)'; 
										|en = '(profile: %1, roles:
										|%2)'; 
										|pl = '(profil: %1, role:
										|%2)';
										|es_ES = '(perfil: %1, roles: 
										|%2)';
										|es_CO = '(perfil: %1, roles: 
										|%2)';
										|tr = '(profil:%1, roller :
										|%2)';
										|it = '(profilo: %1, ruoli:
										|%2)';
										|de = '(Profil: %1, Rollen:
										|%2)'")
									Else
										PresentationClarificationAccessGroups =
										NStr("ru = '(профиль: %1, роль:
										|%2)'; 
										|en = '(profile: %1, role:
										|%2)'; 
										|pl = '(profil: %1, rola:
										|%2)';
										|es_ES = '(perfil: %1, rol;
										|%2)';
										|es_CO = '(perfil: %1, rol;
										|%2)';
										|tr = '(profil:%1, roller :
										|%2)';
										|it = '(profilo: %1, ruolo:
										|%2)';
										|de = '(Profil: %1, Rolle:
										|%2)'")
									EndIf;
									
									Area.Parameters.ProfileOrAccessGroupPresentation =
									AccessGroupDetails.PresentationAccessGroups
									+ Chars.LF
									+ StringFunctionsClientServer.SubstituteParametersToString(PresentationClarificationAccessGroups,
									ProfileDetails.ProfilePresentation,
									TrimAll(ProfileRolesPresentation));
								Else
									Area.Parameters.ProfileOrAccessGroupPresentation =
									AccessGroupDetails.PresentationAccessGroups;
								EndIf;
							EndIf;
							If AllRolesWithRestriction Then
								If GetFunctionalOption("LimitAccessAtRecordLevel") Then
									For each AccessKindDetails In AccessGroupDetails.Rows Do
										Index = AccessKindDetails.Rows.Count()-1;
										While Index >= 0 Do
											If AccessKindDetails.Rows[Index].AccessValue = Undefined Then
												AccessKindDetails.Rows.Delete(Index);
											EndIf;
											Index = Index-1;
										EndDo;
										// Getting a new area if the access kind is not the first one.
										If Area = Undefined Then
											Area = Template.GetArea("ObjectRightsTableString");
										EndIf;
										
										Area.Parameters.AccessKind = AccessKindDetails.AccessKind;
										
										Area.Parameters.AccessKindPresentation = StringFunctionsClientServer.SubstituteParametersToString(
										AccessKindPresentationTemplate(
										AccessKindDetails, RightsSettingsOwners),
										AccessKindDetails.AccessKindPresentation);
										
										OutputArea(
											Document,
											Area,
											3,
											ObjectAreaInitialString,
											ObjectAreaEndRow,
											AccessGroupAreaInitialRow);
										
										For each AccessValueDetails In AccessKindDetails.Rows Do
											Area = Template.GetArea("ObjectRightsTableStringAccessValues");
											
											Area.Parameters.AccessValuePresentation = AccessValueDetails.AccessValuePresentation;
											
											Area.Parameters.AccessValue =	AccessValueDetails.AccessValue;
											
											OutputArea(
												Document,
												Area,
												3,
												ObjectAreaInitialString,
												ObjectAreaEndRow,
												AccessGroupAreaInitialRow);
										EndDo;
									EndDo;
								EndIf;
							EndIf;
							If Area <> Undefined Then
								OutputArea(
									Document,
									Area,
									3,
									ObjectAreaInitialString,
									ObjectAreaEndRow,
									AccessGroupAreaInitialRow);
							EndIf;
							// Setting boundaries for access kinds of the current access group.
							SetKindsAndAccessValuesBoundaries(
								Document,
								AccessGroupAreaInitialRow,
								ObjectAreaEndRow);
								// Merging access group cells and setting boundaries.
								MergeCellsSetBoundaries(
								Document,
								AccessGroupAreaInitialRow,
								ObjectAreaEndRow,
								3);
						EndDo;
					EndIf;
				EndDo;
			EndDo;
			// Merging object cells and setting boundaries.
			MergeCellsSetBoundaries(
				Document,
				ObjectAreaInitialString,
				ObjectAreaEndRow,
				2);
		EndDo;
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
	EndDo;
	Document.Put(IndentArea, 2);
	Document.Put(IndentArea, 2);

EndProcedure

&AtServer
Procedure OutputAvailableForEdit(Val AvailableRights, Val Template, Val QueryResult, Val SimplifiedInterface)
	
	IndentArea = Template.GetArea("Indent");
	RightsObjects = QueryResult.Unload(QueryResultIteration.ByGroups);
	RightsObjects.Rows.Sort(
		"ObjectKindOrder Asc,
		|ObjectPresentation Asc,
		|ProfilePresentation Asc,
		|RolesKind Asc,
		|RolePresentation Asc,
		|PresentationAccessGroups Asc,
		|AccessKindPresentation Asc,
		|AccessValuePresentation Asc",
		True);
	
	Area = Template.GetArea("ObjectsRightsGroup");
	Area.Parameters.ObjectsRightsGroupPresentation = NStr("ru = 'Редактирование объектов'; en = 'Object editing'; pl = 'Edycja obiektów';es_ES = 'Edición de objetos';es_CO = 'Edición de objetos';tr = 'Nesne düzenleme';it = 'la modifica dell''oggetto';de = 'Objektbearbeitung'");
	Document.Put(Area, 1);
	Area = Template.GetArea("ObjectsEditLegend");
	Document.Put(Area, 2);
	
	For each ObjectsKindDetails In RightsObjects.Rows Do
		Area = Template.GetArea("ObjectRightsTableTitle");
		If SimplifiedInterface Then
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("ru = 'Профили'; en = 'Profiles'; pl = 'Profile';es_ES = 'Perfiles';es_CO = 'Perfiles';tr = 'Profiller';it = 'Profili';de = 'Profile'");
		Else
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("ru = 'Группы доступа'; en = 'Access groups'; pl = 'Grupy dostępu';es_ES = 'Grupos de acceso';es_CO = 'Grupos de acceso';tr = 'Erişim grupları';it = 'Gruppi di accesso';de = 'Zugriffsgruppen'");
		EndIf;
		Area.Parameters.Fill(ObjectsKindDetails);
		Document.Put(Area, 2);
		
		Area = Template.GetArea("ObjectRightsTableTitleAddl");
		If AccessRightsDetailedInfo Then
			Area.Parameters.ProfilesOrAccessGroupsPresentation = NStr("ru = '(профиль, роли)'; en = '(profile, roles)'; pl = '(profile, role)';es_ES = '(perfil, roles)';es_CO = '(perfil, roles)';tr = '(profil, roller)';it = '(profilo, ruoli)';de = '(Profil, Rollen)'");
		Else
			Area.Parameters.ProfilesOrAccessGroupsPresentation = "";
		EndIf;
		Area.Parameters.Fill(ObjectsKindDetails);
		Document.Put(Area, 3);
		
		InsertUsed = Upper(Left(ObjectsKindDetails.ObjectsKind, StrLen("Register"))) <> Upper("Register");
		
		For each ObjectDetails In ObjectsKindDetails.Rows Do
			ObjectAreaInitialString = Undefined;
			ObjectAreaEndRow  = Undefined;
			Area = Template.GetArea("ObjectRightsTableString");
			
			Area.Parameters.OpenListForm = "OpenListForm: " + ObjectDetails.Table;
			
			If InsertUsed Then
				If ObjectDetails.Insert AND ObjectDetails.UpdateRight Then
					If ObjectDetails.InsertWithoutRestriction AND ObjectDetails.UpdateWithoutRestriction Then
						If ObjectDetails.InteractiveInsert AND ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление, не ограничено
								|изменение, не ограничено)'; 
								|en = '(Insert, unrestricted
								|Update, unrestricted)'; 
								|pl = '(dodawanie, bez ograniczeń
								|, modyfikacja, bez ograniczeń)';
								|es_ES = '(adición, modificación
								|no limitada, no limitado)';
								|es_CO = '(adición, modificación
								|no limitada, no limitado)';
								|tr = '(ekleme, sınırlı olmayan 
								|modifikasyon, sınırlı değil)';
								|it = '(aggiungi, 
								|non ristretto)';
								|de = '(Hinzufügen, nicht begrenzte
								|Modifikation, nicht begrenzt)'");
						ElsIf NOT ObjectDetails.InteractiveInsert AND ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление*, не ограничено
								|изменение, не ограничено)'; 
								|en = '(Insert*, unrestricted
								|Update, unrestricted)'; 
								|pl = '(dodawanie*, bez ograniczeń
								|, modyfikacja, bez ograniczeń)';
								|es_ES = '(adición*, modificación
								|no limitada, no limitado)';
								|es_CO = '(adición*, modificación
								|no limitada, no limitado)';
								|tr = '(* ekleme, sınırlı olmayan 
								|modifikasyon, sınırlı değil)';
								|it = '(aggiungi*, 
								|non ristretto)';
								|de = '(Hinzufügen*, nicht begrenzte
								|Modifikation, nicht begrenzt)'");
						ElsIf ObjectDetails.InteractiveInsert AND NOT ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление, не ограничено
								|изменение*, не ограничено)'; 
								|en = '(Insert, unrestricted
								|Update*, unrestricted)'; 
								|pl = '(dodawanie, bez ograniczeń
								|modyfikacja*, bez ograniczeń)';
								|es_ES = '(adición, modificación*
								|no limitada, no limitado)';
								|es_CO = '(adición, modificación*
								|no limitada, no limitado)';
								|tr = '(ekleme, sınırlı olmayan 
								|modifikasyon*, sınırlı değil)';
								|it = '(aggiungi, 
								|*non ristretto)';
								|de = '(Hinzufügen, nicht begrenzte
								|Modifikation*, nicht begrenzt)'");
						Else // NOT ObjectDetails.InteractiveInsert AND NOT ObjectDetails.Edit
							ObjectPresentationClarification = NStr("ru = '(добавление*, не ограничено
								|изменение*, не ограничено)'; 
								|en = '(Insert*, unrestricted
								|Update*, unrestricted)'; 
								|pl = '(dodawanie*, bez ograniczeń
								|modyfikacja*, bez ograniczeń)';
								|es_ES = '(adición*, modificación*
								|no limitada, no limitado)';
								|es_CO = '(adición*, modificación*
								|no limitada, no limitado)';
								|tr = '(ekleme*, sınırlı olmayan 
								|modifikasyon*, sınırlı değil)';
								|it = '(aggiungi*, 
								|*non ristretto)';
								|de = '(Hinzufügen*, nicht begrenzte
								|Modifikation*, nicht begrenzt)'");
						EndIf;
					ElsIf NOT ObjectDetails.InsertWithoutRestriction AND ObjectDetails.UpdateWithoutRestriction Then
						If ObjectDetails.InteractiveInsert AND ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление, ограничено
								|изменение, не ограничено)'; 
								|en = '(Insert, restricted
								|Update, unrestricted)'; 
								|pl = '(dodawanie, ograniczone
								|, modyfikacja, bez ograniczeń)';
								|es_ES = '(adición, modificación
								|limitada, no limitado)';
								|es_CO = '(adición, modificación
								|limitada, no limitado)';
								|tr = '(ekleme, sınırlı 
								|modifikasyon, sınırlı değil)';
								|it = '(Inserimento, limitato
								|Aggiornamento, non limitato)';
								|de = '(Hinzufügen, begrenzte
								|Modifikation, nicht begrenzt)'");
						ElsIf NOT ObjectDetails.InteractiveInsert AND ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление*, ограничено
								|изменение, не ограничено)'; 
								|en = '(Insert*, restricted
								|Update, unrestricted)'; 
								|pl = '(dodawanie*, ograniczone
								|, modyfikacja, bez ograniczeń)';
								|es_ES = '(adición*, modificación
								|limitada, no limitado)';
								|es_CO = '(adición*, modificación
								|limitada, no limitado)';
								|tr = '(* ekleme, sınırlı 
								|modifikasyon, sınırlı değil)';
								|it = '(aggiungi*, 
								|non ristretto)';
								|de = '(Hinzufügen*, begrenzte
								|Modifikation, nicht begrenzt)'");
						ElsIf ObjectDetails.InteractiveInsert AND NOT ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление, ограничено
								|изменение*, не ограничено)'; 
								|en = '(Insert, restricted
								|Update*, unrestricted)'; 
								|pl = '(dodawanie, ograniczone
								|, modyfikacja*, bez ograniczeń)';
								|es_ES = '(adición, modificación*
								|limitada, no limitado)';
								|es_CO = '(adición, modificación*
								|limitada, no limitado)';
								|tr = '(ekleme, sınırlı 
								|modifikasyon*, sınırlı değil)';
								|it = '(aggiungi, 
								|*non ristretto)';
								|de = '(Hinzufügen, begrenzte
								|Modifikation*, nicht begrenzt)'");
						Else // NOT ObjectDetails.InteractiveInsert AND NOT ObjectDetails.Edit
							ObjectPresentationClarification = NStr("ru = '(добавление*, ограничено
								|изменение*, не ограничено)'; 
								|en = '(Insert*, restricted
								|Update*, unrestricted)'; 
								|pl = '(dodawanie*, ograniczone
								|, modyfikacja*, bez ograniczeń)';
								|es_ES = '(adición*, modificación*
								|limitada, no limitado)';
								|es_CO = '(adición*, modificación*
								|limitada, no limitado)';
								|tr = '(ekleme, sınırlı 
								|modifikasyon*, sınırlı değil)';
								|it = '(aggiungi*,
								| *non ristretto)';
								|de = '(Hinzufügen*, begrenzte
								|Modifikation*, nicht begrenzt)'");
						EndIf;
					ElsIf ObjectDetails.InsertWithoutRestriction AND NOT ObjectDetails.UpdateWithoutRestriction Then
						If ObjectDetails.InteractiveInsert AND ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление, не ограничено
								|изменение, ограничено)'; 
								|en = '(Insert, unrestricted
								|Update, restricted)'; 
								|pl = '(dodawanie, bez ograniczeń
								|, modyfikacja*, ograniczona)';
								|es_ES = '(adición, modificación
								|no limitada, limitado)';
								|es_CO = '(adición, modificación
								|no limitada, limitado)';
								|tr = '(ekleme, sınırlı olmayan 
								|modifikasyon, sınırlı)';
								|it = '(inserire, non ristretto
								|Aggiornare, ristretto)';
								|de = '(Hinzufügen, nicht begrenzte
								|Modifikation, begrenzt)'");
						ElsIf NOT ObjectDetails.InteractiveInsert AND ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление*, не ограничено
								|изменение, ограничено)'; 
								|en = '(Insert*, unrestricted
								|Update, restricted)'; 
								|pl = '(dodawanie*, bez ograniczeń
								|, modyfikacja, ograniczona)';
								|es_ES = '(adición, modificación
								|no limitada, limitado)';
								|es_CO = '(adición, modificación
								|no limitada, limitado)';
								|tr = '(*ekleme, sınırlı olmayan 
								|modifikasyon, sınırlı)';
								|it = '(aggiungi*, 
								|non ristretto)';
								|de = '(Hinzufügen*, nicht begrenzte
								|Modifikation, begrenzt)'");
						ElsIf ObjectDetails.InteractiveInsert AND NOT ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление, не ограничено
								|изменение*, ограничено)'; 
								|en = '(Insert, unrestricted
								|Update*, restricted)'; 
								|pl = '(dodawanie, bez ograniczeń
								|, modyfikacja*, ograniczona)';
								|es_ES = '(adición, modificación*
								|no limitada, limitado)';
								|es_CO = '(adición, modificación*
								|no limitada, limitado)';
								|tr = '(ekleme, sınırlı olmayan 
								|modifikasyon*, sınırlı)';
								|it = '(aggiungi, 
								|*non ristretto)';
								|de = '(Hinzufügen, nicht begrenzte
								|Modifikation*, begrenzt)'");
						Else // NOT ObjectDetails.InteractiveInsert AND NOT ObjectDetails.Edit
							ObjectPresentationClarification = NStr("ru = '(добавление*, не ограничено
								|изменение*, ограничено)'; 
								|en = '(Insert*, unrestricted
								|Update*, restricted)'; 
								|pl = '(dodawanie*, bez ograniczeń
								|, modyfikacja*, ograniczona)';
								|es_ES = '(adición, modificación*
								|no limitada, limitado)';
								|es_CO = '(adición, modificación*
								|no limitada, limitado)';
								|tr = '(ekleme*, sınırlı olmayan 
								|modifikasyon*, sınırlı)';
								|it = '(aggiungi*, 
								|*non ristretto)';
								|de = '(Hinzufügen*, nicht begrenzte
								|Modifikation*, begrenzt)'");
						EndIf;
					Else // NOT ObjectDetails.InsertWithoutRestriction AND NOT ObjectDetails.UpdateWithoutRestriction
						If ObjectDetails.InteractiveInsert AND ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление, ограничено
								|изменение, ограничено)'; 
								|en = '(Insert, restricted
								|Update, restricted)'; 
								|pl = '(dodawanie, ograniczone
								|, modyfikacja, ograniczona)';
								|es_ES = '(adición, modificación
								|limitada, limitado)';
								|es_CO = '(adición, modificación
								|limitada, limitado)';
								|tr = '(ekleme, sınırlı 
								|modifikasyon, sınırlı)';
								|it = '(aggiungi*, 
								|non ristretto)';
								|de = '(Hinzufügen, begrenzte
								|Modifikation, begrenzt)'");
						ElsIf NOT ObjectDetails.InteractiveInsert AND ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление*, ограничено
								|изменение, ограничено)'; 
								|en = '(Insert*, restricted
								|Update, restricted)'; 
								|pl = '(dodawanie*, ograniczone
								|, modyfikacja, ograniczona)';
								|es_ES = '(adición*, modificación
								|limitada, limitado)';
								|es_CO = '(adición*, modificación
								|limitada, limitado)';
								|tr = '(* ekleme, sınırlı 
								|modifikasyon, sınırlı)';
								|it = '(aggiungi*, 
								|non ristretto)';
								|de = '(Hinzufügen*, begrenzte
								|Modifikation, begrenzt)'");
						ElsIf ObjectDetails.InteractiveInsert AND NOT ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление, ограничено
								|изменение*, ограничено)'; 
								|en = '(Insert, restricted
								|Update*, restricted)'; 
								|pl = '(dodawanie, ograniczone
								|, modyfikacja*, ograniczona)';
								|es_ES = '(adición, modificación*
								|limitada, limitado)';
								|es_CO = '(adición, modificación*
								|limitada, limitado)';
								|tr = '(ekleme, sınırlı 
								|modifikasyon*, sınırlı)';
								|it = '(aggiungi, 
								|*non ristretto)';
								|de = '(Hinzufügen, begrenzte
								|Modifikation*, begrenzt)'");
						Else // NOT ObjectDetails.InteractiveInsert AND NOT ObjectDetails.Edit
							ObjectPresentationClarification = NStr("ru = '(добавление*, ограничено
								|изменение*, ограничено)'; 
								|en = '(Insert*, restricted
								|Update*, restricted)'; 
								|pl = '(dodawanie*, ograniczone
								|, modyfikacja*, ograniczona)';
								|es_ES = '(adición*, modificación*
								|limitada, limitado)';
								|es_CO = '(adición*, modificación*
								|limitada, limitado)';
								|tr = '(ekleme*, sınırlı 
								|modifikasyon*, sınırlı)';
								|it = '(Inserire*, ristretto
								|Aggiornamento*, ristretto)';
								|de = '(Hinzufügen*, begrenzte
								|Modifikation*, begrenzt)'");
						EndIf;
					EndIf;
					
				ElsIf NOT ObjectDetails.Insert AND ObjectDetails.UpdateRight Then
					
					If ObjectDetails.UpdateWithoutRestriction Then
						If ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление не доступно
								|изменение, не ограничено)'; 
								|en = '(Insert is not available 
								|Update, unrestricted)'; 
								|pl = '(dodawanie niedostępne
								|, modyfikacja, nieograniczona)';
								|es_ES = '(adición no se encuentra disponible
								|modificación, no limitado)';
								|es_CO = '(adición no se encuentra disponible
								|modificación, no limitado)';
								|tr = '(ekleme mevcut değil, 
								|modifikasyon, sınırlı değil)';
								|it = '(Inserimento non disponibile 
								|Aggiornamento, non limitato)';
								|de = '(Hinzufügen ist nicht verfügbare
								|Modifikation, nicht begrenzt)'");
						Else // NOT ObjectDetails.Edit
							ObjectPresentationClarification = NStr("ru = '(добавление не доступно
								|изменение*, не ограничено)'; 
								|en = '(Insert is not available 
								|Update*, unrestricted)'; 
								|pl = '(dodawanie niedostępne
								|, modyfikacja*, nieograniczona)';
								|es_ES = '(adición no se encuentra disponible
								|modificación*, no limitado)';
								|es_CO = '(adición no se encuentra disponible
								|modificación*, no limitado)';
								|tr = '(ekleme mevcut değil, 
								|modifikasyon*, sınırlı değil)';
								|it = '(Inserimento non disponibile, 
								|Aggiornamento*, non limitato)';
								|de = '(Hinzufügen ist nicht verfügbare
								|Modifikation*, nicht begrenzt)'");
						EndIf;
					Else // NOT ObjectDetails.UpdateWithoutRestriction
						If ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(добавление не доступно
								|изменение, ограничено)'; 
								|en = '(Insert is not available
								|Update, restricted)'; 
								|pl = '(dodawanie niedostępne
								|, modyfikacja, ograniczona)';
								|es_ES = '(adición no se encuentra disponible
								|modificación, limitado)';
								|es_CO = '(adición no se encuentra disponible
								|modificación, limitado)';
								|tr = '(ekleme mevcut değil, 
								|modifikasyon, sınırlı)';
								|it = '(Inserimento non disponibile
								|Aggiornamento, limitato)';
								|de = '(Hinzufügen ist nicht verfügbare
								|Modifikation, begrenzt)'");
						Else // NOT ObjectDetails.Edit
							ObjectPresentationClarification = NStr("ru = '(добавление не доступно
								|изменение*, ограничено)'; 
								|en = '(Insert is not available 
								|Update*, restricted)'; 
								|pl = '(dodawanie niedostępne
								|, modyfikacja*, ograniczona)';
								|es_ES = '(adición no se encuentra disponible
								|modificación*, limitado)';
								|es_CO = '(adición no se encuentra disponible
								|modificación*, limitado)';
								|tr = '(ekleme mevcut değil, 
								|modifikasyon*, sınırlı)';
								|it = '(Inserimento non disponibile 
								|Aggiornamento*, limitato)';
								|de = '(Hinzufügen ist nicht verfügbare
								|Modifikation*, begrenzt)'");
						EndIf;
					EndIf;
					
				Else // NOT ObjectDetails.Insert AND NOT ObjectDetails.Update
					ObjectPresentationClarification = NStr("ru = '(добавление не доступно
						|изменение не доступно)'; 
						|en = '(Insert is not available 
						|Update is not available)'; 
						|pl = '(dodawanie niedostępne
						|, modyfikacja niedostępna)';
						|es_ES = '(adición no se encuentra disponible
						|modificación no se encuentra disponible)';
						|es_CO = '(adición no se encuentra disponible
						|modificación no se encuentra disponible)';
						|tr = '(ekleme mevcut değil, 
						|modifikasyon mevcut değil)';
						|it = '(Inserimento non disponibile 
						|Aggiornamento non disponibile)';
						|de = '(Hinzufügen ist nicht verfügbar
						|Modifikation ist nicht verfügbar)'");
				EndIf;
			Else
				If ObjectDetails.UpdateRight Then
					If ObjectDetails.UpdateWithoutRestriction Then
						If ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(изменение, не ограничено)'; en = '(Update, unrestricted)'; pl = '(zmiana, nieograniczone)';es_ES = '(cambio, no limitado)';es_CO = '(cambio, no limitado)';tr = '(değişiklik, sınırlı değil)';it = '(modifica, non ristretta)';de = '(Änderung*, nicht begrenzt)'");
						Else // NOT ObjectDetails.Edit
							ObjectPresentationClarification = NStr("ru = '(изменение*, не ограничено)'; en = '(Update*, unrestricted)'; pl = '(zmiana *, nieograniczone)';es_ES = '(cambio *, no limitado)';es_CO = '(cambio *, no limitado)';tr = '(değişiklik *, sınırlı değil)';it = '(modifica*, non ristretta)';de = '(Änderung, nicht begrenzt)'");
						EndIf;
					Else
						If ObjectDetails.Edit Then
							ObjectPresentationClarification = NStr("ru = '(изменение, ограничено)'; en = '(Update, restricted)'; pl = '(zmiana, ograniczone)';es_ES = '(cambio, limitado)';es_CO = '(cambio, limitado)';tr = '(değişiklik, sınırlı)';it = '(Aggiornato, ristretto)';de = '(Änderung, begrenzt)'");
						Else // NOT ObjectDetails.Edit
							ObjectPresentationClarification = NStr("ru = '(изменение*, ограничено)'; en = '(Update*, restricted)'; pl = '(zmiana *, ograniczone)';es_ES = '(cambio *, limitado)';es_CO = '(cambio *, limitado)';tr = '(değişiklik *, sınırlı)';it = '(Aggiornato, ristretto)';de = '(Änderung*, begrenzt)'");
						EndIf;
					EndIf;
				Else // NOT ObjectDetails.UpdateWithRestriction
					ObjectPresentationClarification = NStr("ru = '(изменение не доступно)'; en = '(Update not available)'; pl = '(zmiana niedostępna)';es_ES = '(cambio no se encuentra disponible)';es_CO = '(cambio no se encuentra disponible)';tr = '(değişiklik mevcut değil)';it = '(Aggiornamento non disponibile)';de = '(Änderung ist nicht verfügbar)'");
				EndIf;
			EndIf;
			
			Area.Parameters.ObjectPresentation =
				ObjectDetails.ObjectPresentation + Chars.LF + ObjectPresentationClarification;
			
			For each ProfileDetails In ObjectDetails.Rows Do
				ProfileRolesPresentation = "";
				RolesCount = 0;
				AllRolesWithRestriction = True;
				For each RoleKindDetails In ProfileDetails.Rows Do
					If RoleKindDetails.RolesKind < 1000 Then
						// Description of the role with or without restrictions.
						For each RoleDetails In RoleKindDetails.Rows Do
							
							If RoleKindDetails.InsertWithoutRestriction
								AND RoleKindDetails.UpdateWithoutRestriction Then
								
								AllRolesWithRestriction = False;
							EndIf;
							
							If NOT AccessRightsDetailedInfo Then
								Continue;
							EndIf;
							
							If RoleKindDetails.Rows.Count() > 1
								AND RoleKindDetails.Rows.IndexOf(RoleDetails)
								< RoleKindDetails.Rows.Count()-1 Then
								
								ProfileRolesPresentation =
								ProfileRolesPresentation + RoleDetails.RolePresentation + ",";
								
								RolesCount = RolesCount + 1;
							EndIf;
							
							If RoleKindDetails.Rows.IndexOf(RoleDetails) =
								RoleKindDetails.Rows.Count()-1 Then
								
								ProfileRolesPresentation =
								ProfileRolesPresentation + RoleDetails.RolePresentation + ",";
								
								RolesCount = RolesCount + 1;
							EndIf;
							ProfileRolesPresentation = ProfileRolesPresentation + Chars.LF;
						EndDo;
					ElsIf RoleKindDetails.Rows[0].Rows.Count() > 0 Then
						// Description of access restrictions for roles with restrictions.
						For each AccessGroupDetails In RoleKindDetails.Rows[0].Rows Do
							Index = AccessGroupDetails.Rows.Count()-1;
							While Index >= 0 Do
								If AccessGroupDetails.Rows[Index].AccessKind = Undefined Then
									AccessGroupDetails.Rows.Delete(Index);
								EndIf;
								Index = Index-1;
							EndDo;
							AccessGroupAreaInitialRow = Undefined;
							If Area = Undefined Then
								Area = Template.GetArea("ObjectRightsTableString");
							EndIf;
							If SimplifiedInterface Then
								Area.Parameters.ProfileOrAccessGroup = ProfileDetails.AccessGroup;
								Area.Parameters.ProfileOrAccessGroupPresentation = ProfileDetails.PresentationAccessGroups;
							Else
								Area.Parameters.ProfileOrAccessGroup = AccessGroupDetails.AccessGroup;
								If AccessRightsDetailedInfo Then
									ProfileRolesPresentation = TrimAll(ProfileRolesPresentation);
									
									If ValueIsFilled(ProfileRolesPresentation)
										AND StrEndsWith(ProfileRolesPresentation, ",") Then
										
										ProfileRolesPresentation = Left(
										ProfileRolesPresentation,
										StrLen(ProfileRolesPresentation)-1);
									EndIf;
									If RolesCount > 1 Then
										PresentationClarificationAccessGroups =
										NStr("ru = '(профиль: %1, роли:
											|%2)'; 
											|en = '(profile: %1, roles:
											|%2)'; 
											|pl = '(profil: %1, role:
											|%2)';
											|es_ES = '(perfil: %1, roles: 
											|%2)';
											|es_CO = '(perfil: %1, roles: 
											|%2)';
											|tr = '(profil:%1, roller :
											|%2)';
											|it = '(profilo: %1, ruoli:
											|%2)';
											|de = '(Profil: %1, Rollen:
											|%2)'")
									Else
										PresentationClarificationAccessGroups =
										NStr("ru = '(профиль: %1, роль:
											|%2)'; 
											|en = '(profile: %1, role:
											|%2)'; 
											|pl = '(profil: %1, rola:
											|%2)';
											|es_ES = '(perfil: %1, rol;
											|%2)';
											|es_CO = '(perfil: %1, rol;
											|%2)';
											|tr = '(profil:%1, roller :
											|%2)';
											|it = '(profilo: %1, ruolo:
											|%2)';
											|de = '(Profil: %1, Rolle:
											|%2)'")
									EndIf;
									
									Area.Parameters.ProfileOrAccessGroupPresentation = AccessGroupDetails.PresentationAccessGroups
										+ Chars.LF 
										+ StringFunctionsClientServer.SubstituteParametersToString(PresentationClarificationAccessGroups,
											ProfileDetails.ProfilePresentation, TrimAll(ProfileRolesPresentation));
								Else
									Area.Parameters.ProfileOrAccessGroupPresentation =
									AccessGroupDetails.PresentationAccessGroups;
								EndIf;
							EndIf;
							If AllRolesWithRestriction Then
								If GetFunctionalOption("LimitAccessAtRecordLevel") Then
									For each AccessKindDetails In AccessGroupDetails.Rows Do
										Index = AccessKindDetails.Rows.Count()-1;
										While Index >= 0 Do
											If AccessKindDetails.Rows[Index].AccessValue = Undefined Then
												AccessKindDetails.Rows.Delete(Index);
											EndIf;
											Index = Index-1;
										EndDo;
										// Getting a new area if the access kind is not the first one.
										If Area = Undefined Then
											Area = Template.GetArea("ObjectRightsTableString");
										EndIf;
										
										Area.Parameters.AccessKind = AccessKindDetails.AccessKind;
										Area.Parameters.AccessKindPresentation = StringFunctionsClientServer.SubstituteParametersToString(
											AccessKindPresentationTemplate(AccessKindDetails, AvailableRights.ByRefsTypes),
											AccessKindDetails.AccessKindPresentation);
										
										OutputArea(
											Document,
											Area,
											3,
											ObjectAreaInitialString,
											ObjectAreaEndRow,
											AccessGroupAreaInitialRow);
										
										For each AccessValueDetails In AccessKindDetails.Rows Do
											Area = Template.GetArea("ObjectRightsTableStringAccessValues");
											Area.Parameters.AccessValuePresentation = AccessValueDetails.AccessValuePresentation;
											Area.Parameters.AccessValue = AccessValueDetails.AccessValue;
											
											OutputArea(
												Document,
												Area,
												3,
												ObjectAreaInitialString,
												ObjectAreaEndRow,
												AccessGroupAreaInitialRow);
										EndDo;
									EndDo;
								EndIf;
							EndIf;
							If Area <> Undefined Then
								OutputArea(
									Document,
									Area,
									3,
									ObjectAreaInitialString,
									ObjectAreaEndRow,
									AccessGroupAreaInitialRow);
							EndIf;
							// Setting boundaries for access kinds of the current access group.
							SetKindsAndAccessValuesBoundaries(
								Document,
								AccessGroupAreaInitialRow,
								ObjectAreaEndRow);
							
							// Merging access group cells and setting boundaries.
							MergeCellsSetBoundaries(
								Document,
								AccessGroupAreaInitialRow,
								ObjectAreaEndRow,
								3);
						EndDo;
					EndIf;
				EndDo;
			EndDo;
			// Merging object cells and setting boundaries.
			MergeCellsSetBoundaries(
				Document,
				ObjectAreaInitialString,
				ObjectAreaEndRow,
				2);
		EndDo;
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
	EndDo;
	Document.Put(IndentArea, 2);
	Document.Put(IndentArea, 2);

EndProcedure

&AtServer
Procedure OutputRightsToSeparateObjects(Val AvailableRights, Val Template, Val QueryResult, Val OutputGroupRights)
	
	IndentArea = Template.GetArea("Indent");
	
	RightsSettings = QueryResult.Unload(QueryResultIteration.ByGroups);
	RightsSettings.Columns.Add("FullNameObjectsType");
	RightsSettings.Columns.Add("ObjectsKindPresentation");
	RightsSettings.Columns.Add("FullDescr");
	
	For each ObjectsTypeDetails In RightsSettings.Rows Do
		TypeMetadata = Metadata.FindByType(ObjectsTypeDetails.ObjectsType);
		ObjectsTypeDetails.FullNameObjectsType      = TypeMetadata.FullName();
		ObjectsTypeDetails.ObjectsKindPresentation = TypeMetadata.Presentation();
	EndDo;
	RightsSettings.Rows.Sort("ObjectsKindPresentation Asc");
	
	For each ObjectsTypeDetails In RightsSettings.Rows Do
		
		RightsDetails = AvailableRights.ByRefsTypes.Get(ObjectsTypeDetails.ObjectsType);
		
		If AvailableRights.HierarchicalTables.Get(ObjectsTypeDetails.ObjectsType) = Undefined Then
			ObjectsTypeRootItems = Undefined;
		Else
			ObjectsTypeRootItems = ObjectsTypeRootItems(ObjectsTypeDetails.ObjectsType);
		EndIf;
		
		For each ObjectDetails In ObjectsTypeDetails.Rows Do
			ObjectDetails.FullDescr = ObjectDetails.Object.FullDescr();
		EndDo;
		ObjectsTypeDetails.Rows.Sort("FullDescr Asc");
		
		Area = Template.GetArea("RightsSettingsGroup");
		Area.Parameters.Fill(ObjectsTypeDetails);
		Document.Put(Area, 1);
		
		// Legend output
		Area = Template.GetArea("RightsSettingsLegendHeader");
		Document.Put(Area, 2);
		For each RightDetails In RightsDetails Do
			Area = Template.GetArea("RightsSettingsLegendString");
			Area.Parameters.Title = StrReplace(RightDetails.Title, Chars.LF, " ");
			Area.Parameters.ToolTip = StrReplace(RightDetails.ToolTip, Chars.LF, " ");
			Document.Put(Area, 2);
		EndDo;
		
		TitleForSubfolders =
			NStr("ru = 'Для
			           |подпапок'; 
			           |en = 'For
			           |subfolders'; 
			           |pl = 'Do
			           |podfolderów';
			           |es_ES = 'Para
			           |subcarpetas';
			           |es_CO = 'Para
			           |subcarpetas';
			           |tr = 'Alt klasörler
			           |için';
			           |it = 'Per
			           |sottocartelle';
			           |de = 'Für
			           |Unterordner'");
		TooltipForSubfolders = NStr("ru = 'Права не только для текущей папки, но и для ее нижестоящих папок'; en = 'Rights both for the current folder and its subfolders'; pl = 'Prawa nie tylko do bieżącego folderu, ale także do jego podfolderów';es_ES = 'Derechos no solo para la carpeta actual, sino también para sus subcarpetas';es_CO = 'Derechos no solo para la carpeta actual, sino también para sus subcarpetas';tr = 'Haklar sadece geçerli klasör için değil, aynı zamanda alt klasörler için de';it = 'Diritti non solo per la cartella corrente, ma anche per le sue cartelle downstream';de = 'Die Rechte gelten nicht nur für den aktuellen Ordner, sondern auch für seine Unterordner'");
		
		Area = Template.GetArea("RightsSettingsLegendString");
		Area.Parameters.Title = StrReplace(TitleForSubfolders, Chars.LF, " ");
		Area.Parameters.ToolTip = StrReplace(TooltipForSubfolders, Chars.LF, " ");
		Document.Put(Area, 2);
		
		TitleSettingReceivedFromGroup = NStr("ru = 'Настройка прав получена от группы'; en = 'Right setting is received from group'; pl = 'Ustawienia praw uzyskane z grupy';es_ES = 'Configuración de derechos recibida del grupo';es_CO = 'Configuración de derechos recibida del grupo';tr = 'Haklar ayarı gruptan alındı';it = 'Impostazioni diritti ricevute dal gruppo';de = 'Rechteeinstellung von Gruppe erhalten'");
		
		Area = Template.GetArea("RightsSettingsLegendStringInheritance");
		Area.Parameters.ToolTip = NStr("ru = 'Наследование прав от вышестоящих папок'; en = 'Right inheritance from parent folders'; pl = 'Dziedziczenie praw powyższych folderów';es_ES = 'Herencia de derechos de las carpetas iniciales';es_CO = 'Herencia de derechos de las carpetas iniciales';tr = 'Giriş klasörlerinden hak devralma';it = 'Diritti ereditati dalla cartella genitore';de = 'Rechtevererbung von Upstream-Ordnern'");
		Document.Put(Area, 2);
		
		Document.Put(IndentArea, 2);
		
		// Preparation of a row template
		HeaderTemplate  = New SpreadsheetDocument;
		RowTemplate = New SpreadsheetDocument;
		OutputUserGroups = ObjectsTypeDetails.GroupParticipation AND NOT OutputGroupRights;
		ColumnsCount = RightsDetails.Count() + ?(OutputUserGroups, 2, 1);
		
		For ColumnNumber = 1 To ColumnsCount Do
			NewHeaderCell  = Template.GetArea("RightsSettingsDetailsCellHeader");
			HeaderCell = HeaderTemplate.Join(NewHeaderCell);
			HeaderCell.HorizontalAlign = HorizontalAlign.Center;
			NewRowCell = Template.GetArea("RightsSettingsDetailsCellRows");
			RowCell = RowTemplate.Join(NewRowCell);
			RowCell.HorizontalAlign = HorizontalAlign.Center;
		EndDo;
		
		If OutputUserGroups Then
			HeaderCell.HorizontalAlign  = HorizontalAlign.Left;
			RowCell.HorizontalAlign = HorizontalAlign.Left;
		EndIf;
		
		// Displaying a table header
		CellNumberForSubfolders = "R1C" + Format(RightsDetails.Count()+1, "NG=");
		
		HeaderTemplate.Area(CellNumberForSubfolders).Text = TitleForSubfolders;
		HeaderTemplate.Area(CellNumberForSubfolders).ColumnWidth =
			MaxStringLength(HeaderTemplate.Area(CellNumberForSubfolders).Text);
		
		Offset = 1;
		
		CurrentAreaNumber = Offset;
		For each RightDetails In RightsDetails Do
			CellNumber = "R1C" + Format(CurrentAreaNumber, "NG=");
			HeaderTemplate.Area(CellNumber).Text = RightDetails.Title;
			HeaderTemplate.Area(CellNumber).ColumnWidth = MaxStringLength(RightDetails.Title);
			CurrentAreaNumber = CurrentAreaNumber + 1;
			
			RowTemplate.Area(CellNumber).ColumnWidth = HeaderTemplate.Area(CellNumber).ColumnWidth;
		EndDo;
		
		If OutputUserGroups Then
			CellNumberForGroup = "R1C" + Format(ColumnsCount, "NG=");
			HeaderTemplate.Area(CellNumberForGroup).Text = TitleSettingReceivedFromGroup;
			HeaderTemplate.Area(CellNumberForGroup).ColumnWidth = 35;
		EndIf;
		Document.Put(HeaderTemplate, 2);
		
		TextYes  = NStr("ru = 'Да'; en = 'Yes'; pl = 'Tak';es_ES = 'Sí';es_CO = 'Sí';tr = 'Evet';it = 'Sì';de = 'Ja'");
		TextNo = NStr("ru = 'Нет'; en = 'No'; pl = 'Nie';es_ES = 'No';es_CO = 'No';tr = 'Hayır';it = 'No';de = 'Nr.'");
		
		// Displaying table rows
		For each ObjectDetails In ObjectsTypeDetails.Rows Do
			
			If ObjectsTypeRootItems = Undefined
			 OR ObjectsTypeRootItems.Get(ObjectDetails.Object) <> Undefined Then
				Area = Template.GetArea("RightsSettingsDetailsObject");
				
			ElsIf ObjectDetails.Inherit Then
				Area = Template.GetArea("RightsSettingsDetailsObjectInheritYes");
			Else
				Area = Template.GetArea("RightsSettingsDetailsObjectInheritNo");
			EndIf;
			
			Area.Parameters.Fill(ObjectDetails);
			Document.Put(Area, 2);
			For each UserDetails In ObjectDetails.Rows Do
				
				For RightAreaNumber = 1 To ColumnsCount Do
					CellNumber = "R1C" + Format(RightAreaNumber, "NG=");
					RowTemplate.Area(CellNumber).Text = "";
				EndDo;
				
				If TypeOf(UserDetails.InheritanceIsAllowed) = Type("Boolean") Then
					RowTemplate.Area(CellNumberForSubfolders).Text = ?(
						UserDetails.InheritanceIsAllowed, TextYes, TextNo);
				EndIf;
				
				OwnerRights = AvailableRights.ByTypes.Get(ObjectsTypeDetails.ObjectsType);
				For each CurrentRightDetails In UserDetails.Rows Do
					OwnerRight = OwnerRights.Get(CurrentRightDetails.UserRight);
					If OwnerRight <> Undefined Then
						RightAreaNumber = OwnerRight.RightIndex + Offset;
						CellNumber = "R1C" + Format(RightAreaNumber, "NG=");
						RowTemplate.Area(CellNumber).Text = ?(
							CurrentRightDetails.RightIsProhibited, TextNo, TextYes);
					EndIf;
				EndDo;
				If OutputUserGroups Then
					If UserDetails.GroupParticipation Then
						RowTemplate.Area(CellNumberForGroup).Text =
							UserDetails.UserDescription;
						RowTemplate.Area(CellNumberForGroup).DetailsParameter = "User";
						RowTemplate.Parameters.User = UserDetails.User;
					EndIf;
				EndIf;
				RowTemplate.Area(CellNumberForGroup).ColumnWidth = 35;
				Document.Put(RowTemplate, 2);
			EndDo;
		EndDo;
	EndDo;
	
EndProcedure
	
&AtServer
Procedure OutputReportHeader(Val Template, Properties, Val UserOrGroup)
	
	If TypeOf(UserOrGroup) = Type("CatalogRef.Users") Then
		Properties.Insert("ReportHeader",             NStr("ru = 'Отчет по правам пользователя'; en = 'User rights report'; pl = 'Raport o prawach użytkownika';es_ES = 'Informe de derechos de usuario';es_CO = 'Informe de derechos de usuario';tr = 'Kullanıcı hakları raporu';it = 'Report sui diritti degli utenti';de = 'Benutzerrechte Bericht'"));
		Properties.Insert("RolesByProfilesGroup",   NStr("ru = 'Роли пользователя по профилям'; en = 'User roles by profiles'; pl = 'Role użytkowników według profili';es_ES = 'Roles de usuarios por perfiles';es_CO = 'Roles de usuarios por perfiles';tr = 'Profillere göre kullanıcı rolleri';it = 'Ruoli utente per profili';de = 'Benutzerrollen nach Profilen'"));
		Properties.Insert("ObjectPresentation",        NStr("ru = 'Пользователь: %1'; en = 'User: %1'; pl = 'Użytkownik: %1';es_ES = 'Usuario: %1';es_CO = 'Usuario: %1';tr = 'Kullanıcı: %1';it = 'Utente: %1';de = 'Benutzer: %1'"));
		
	ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
		Properties.Insert("ReportHeader",             NStr("ru = 'Отчет по правам внешнего пользователя'; en = 'External user rights report'; pl = 'Raport o prawach użytkownika zewnętrznego';es_ES = 'Informe de derechos de usuarios externos';es_CO = 'Informe de derechos de usuarios externos';tr = 'Dış kullanıcı hakları raporu';it = 'Report esterno diritti utente';de = 'Bericht über externe Benutzerrechte'"));
		Properties.Insert("RolesByProfilesGroup",   NStr("ru = 'Роли внешнего пользователя по профилям'; en = 'External user roles by profiles'; pl = 'Role użytkowników zewnętrznych według profili';es_ES = 'Roles de usuarios externos por perfiles';es_CO = 'Roles de usuarios externos por perfiles';tr = 'Harici kullanıcının rolleri profillere göre';it = 'Ruoli utente esterni per profilo';de = 'Rollen von externen Benutzern nach Profilen'"));
		Properties.Insert("ObjectPresentation",        NStr("ru = 'Внешний пользователь: %1'; en = 'External user: %1'; pl = 'Użytkownik zewnętrzny: %1';es_ES = 'Usuario externo: %1';es_CO = 'Usuario externo: %1';tr = 'Dış kullanıcı: %1';it = 'Utente esterno: %1';de = 'Externer Benutzer: %1'"));
		
	ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.UserGroups") Then
		Properties.Insert("ReportHeader",             NStr("ru = 'Отчет по правам группы пользователей'; en = 'User group rights report'; pl = 'Raport o prawach grupy użytkowników';es_ES = 'Informe de derechos de grupos de usuarios';es_CO = 'Informe de derechos de grupos de usuarios';tr = 'Kullanıcı grubu hakları raporu';it = 'Report sui diritti di gruppo utente';de = 'Benutzergruppenrechte Bericht'"));
		Properties.Insert("RolesByProfilesGroup",   NStr("ru = 'Роли группы пользователей по профилям'; en = 'User group roles by profiles'; pl = 'Role grupy użytkowników według profili';es_ES = 'Roles de grupos de usuarios por perfiles';es_CO = 'Roles de grupos de usuarios por perfiles';tr = 'Profillere göre kullanıcı grubu rolleri';it = 'Ruoli di gruppo di utenti profilati';de = 'Benutzergruppenrollen nach Profilen'"));
		Properties.Insert("ObjectPresentation",        NStr("ru = 'Группа пользователей: %1'; en = 'User group: %1'; pl = 'Grupa użytkowników: %1';es_ES = 'Grupo de usuarios: %1';es_CO = 'Grupo de usuarios: %1';tr = 'Kullanıcı grubu: %1';it = 'Gruppo utenti: %1';de = 'Benutzergruppe: %1'"));
	Else
		Properties.Insert("ReportHeader",             NStr("ru = 'Отчет по правам группы внешних пользователей'; en = 'External user group rights report'; pl = 'Raport o prawach grupy użytkowników zewnętrznych';es_ES = 'Informe de los derechos del grupo de usuarios externos';es_CO = 'Informe de los derechos del grupo de usuarios externos';tr = 'Harici kullanıcıların grup hakları hakkında rapor';it = 'Report sui diritti degli utenti esterni';de = 'Bericht über Gruppenrechte von externen Benutzern'"));
		Properties.Insert("RolesByProfilesGroup",   NStr("ru = 'Роли группы внешних пользователей по профилям'; en = 'External user group roles by profiles'; pl = 'Role grupy użytkowników zewnętrznych według profili';es_ES = 'Roles del grupo de usuarios externos por perfiles';es_CO = 'Roles del grupo de usuarios externos por perfiles';tr = 'Harici kullanıcı grubunun profillere göre rolleri';it = 'Ruoli del gruppo utenti esterni per profili';de = 'Rollen der externen Benutzergruppe nach Profilen'"));
		Properties.Insert("ObjectPresentation",        NStr("ru = 'Группа внешних пользователей: %1'; en = 'External user group: %1'; pl = 'Grupa użytkowników zewnętrznych: %1';es_ES = 'Grupo de usuarios externos: %1';es_CO = 'Grupo de usuarios externos: %1';tr = 'Harici kullanıcı grubu: %1';it = 'Gruppo utenti esterni: %1';de = 'Externe Benutzergruppe: %1'"));
	EndIf;
	
	Properties.ObjectPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		Properties.ObjectPresentation, String(UserOrGroup));
	
	// Displaying a title.
	Area = Template.GetArea("Title");
	Area.Parameters.Fill(Properties);
	Document.Put(Area);

EndProcedure

&AtServer
Procedure OutputIBUserProperties(Val Template, Val UserOrGroup)
	
	Document.StartRowAutoGrouping();
	Document.Put(Template.GetArea("IBUserPropertiesGroup"), 1,, True);
	Area = Template.GetArea("IBUserPropertiesDetails1");
	
	SetPrivilegedMode(True);
	IBUserProperies = Users.IBUserProperies(
		Common.ObjectAttributeValue(UserOrGroup, "IBUserID"));
	SetPrivilegedMode(False);
	
	If IBUserProperies <> Undefined Then
		Area.Parameters.CanSignIn = Users.CanSignIn(
		IBUserProperies);
		
		Document.Put(Area, 2);
		
		Area = Template.GetArea("IBUserPropertiesDetails2");
		Area.Parameters.Fill(IBUserProperies);
		
		Area.Parameters.PresentationLanguage =
		LanguagePresentation(IBUserProperies.Language);
		
		Area.Parameters.RunModePresentation =
		RunModePresentation(IBUserProperies.RunMode);
		
		If NOT ValueIsFilled(IBUserProperies.OSUser) Then
			Area.Parameters.OSUser = NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nieokreślono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmemiş';it = 'Non specificato';de = 'Keine Angabe'");
		EndIf;
		Document.Put(Area, 2);
	Else
		Area.Parameters.CanSignIn = False;
		Document.Put(Area, 2);
	EndIf;
	Document.EndRowAutoGrouping();

EndProcedure

&AtServer
Procedure OutputDetailedInfoOnAccessRights(Val Template, UserOrGroup, Val QueryResult, Properties)
	
	IndentArea = Template.GetArea("Indent");
	
	// Displaying access groups.
	AccessGroupsDetails = QueryResult.Unload(QueryResultIteration.ByGroups).Rows;
	
	OnePersonalGroup
	= AccessGroupsDetails.Count() = 1
	AND ValueIsFilled(AccessGroupsDetails[0].Member);
	
	Area = Template.GetArea("AllAccessGroupsGroup");
	Area.Parameters.Fill(Properties);
	
	If OnePersonalGroup Then
		If TypeOf(UserOrGroup) = Type("CatalogRef.Users") Then
			AccessPresentation = NStr("ru = 'Ограничения доступа пользователя'; en = 'User access restrictions'; pl = 'Ograniczenia dostępu użytkownika';es_ES = 'Limitaciones del acceso del usuario';es_CO = 'Limitaciones del acceso del usuario';tr = 'Kullanıcı erişim sınırlamaları';it = 'Limitazioni accesso utente';de = 'Einschränkungen des Benutzerzugriffs'");
			
		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
			AccessPresentation = NStr("ru = 'Ограничения доступа внешнего пользователя'; en = 'External user access restrictions'; pl = 'Ograniczenia dostępu użytkownika zewnętrznego';es_ES = 'Restricciones de acceso del usuario externo';es_CO = 'Restricciones de acceso del usuario externo';tr = 'Harici kullanıcının erişim kısıtlamaları';it = 'Limitazioni accesso utente esterno';de = 'Zugriffsbeschränkungen für externe Benutzer'");
			
		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.UserGroups") Then
			AccessPresentation = NStr("ru = 'Ограничения доступа группы пользователей'; en = 'User group access restrictions'; pl = 'Ograniczenia dostępu grupy użytkowników';es_ES = 'Restricciones de acceso del grupo de usuarios';es_CO = 'Restricciones de acceso del grupo de usuarios';tr = 'Kullanıcı grubunun erişim kısıtlamaları';it = 'Limitazioni accesso del gruppo utenti';de = 'Zugriffsbeschränkungen der Benutzergruppe'");
		Else
			AccessPresentation = NStr("ru = 'Ограничения доступа группы внешних пользователей'; en = 'External user group access restrictions'; pl = 'Ograniczenia dostępu grupy użytkowników zewnętrznych';es_ES = 'Restricciones de acceso del grupo de usuarios externos';es_CO = 'Restricciones de acceso del grupo de usuarios externos';tr = 'Harici kullanıcı grubu erişim kısıtlamaları';it = 'Limitazioni accesso del gruppo utenti esterni';de = 'Zugriffsbeschränkungen der externen Benutzergruppe'");
		EndIf;
	Else
		If TypeOf(UserOrGroup) = Type("CatalogRef.Users") Then
			AccessPresentation = NStr("ru = 'Группы доступа пользователя'; en = 'User access groups'; pl = 'Grupa dostępu użytkownika';es_ES = 'Grupos de acceso de usuarios';es_CO = 'Grupos de acceso de usuarios';tr = 'Kullanıcı erişim grupları';it = 'Gruppi di accesso per l''utente';de = 'Benutzerzugriffsgruppen'");
			
		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
			AccessPresentation = NStr("ru = 'Группы доступа внешнего пользователя'; en = 'External user access groups'; pl = 'Grupy dostepu użytkownika zewnętrznego';es_ES = 'Grupos de acceso de usuarios externos';es_CO = 'Grupos de acceso de usuarios externos';tr = 'Harici kullanıcı erişim grupları';it = 'Gruppi di accesso utente esterno';de = 'Gruppen mit externem Benutzerzugriff'");
			
		ElsIf TypeOf(UserOrGroup) = Type("CatalogRef.UserGroups") Then
			AccessPresentation = NStr("ru = 'Группы доступа группы пользователей'; en = 'User group access groups'; pl = 'Grupy dostępu grup użytkowników';es_ES = 'Grupos de usuarios de grupos de acceso';es_CO = 'Grupos de usuarios de grupos de acceso';tr = 'Erişim grupları kullanıcı grupları';it = 'Gruppi di accesso del gruppo utente';de = 'Zugriff auf Gruppen von Benutzergruppen'");
		Else
			AccessPresentation = NStr("ru = 'Группы доступа группы внешних пользователей'; en = 'External user group access groups'; pl = 'Grupy dostępu grup użytkowników zewnętrznych';es_ES = 'Grupos de usuarios externos de grupos de acceso';es_CO = 'Grupos de usuarios externos de grupos de acceso';tr = 'Harici kullanıcı gruplarına erişim grupları';it = 'Gruppi di accesso del gruppo utente esterno';de = 'Gruppe von externen Benutzern Zugriffsgruppe'");
		EndIf;
	EndIf;
	
	Area.Parameters.AccessPresentation = AccessPresentation;
	
	Document.Put(Area, 1);
	Document.Put(IndentArea, 2);
	
	For each AccessGroupDetails In AccessGroupsDetails Do
		If NOT OnePersonalGroup Then
			Area = Template.GetArea("AccessGroupGroup");
			Area.Parameters.Fill(AccessGroupDetails);
			Document.Put(Area, 2);
		EndIf;
		// Displaying group membership.
		If AccessGroupDetails.Rows.Count() = 1
			AND AccessGroupDetails.Rows[0].Member = UserOrGroup Then
			// User belongs to the access group explicitly, display is not required.
			// 
		Else
			Area = Template.GetArea("AccessGroupDetailsUserIsInGroup");
			Document.Put(Area, 3);
			If AccessGroupDetails.Rows.Find(UserOrGroup, "Member") <> Undefined Then
				Area = Template.GetArea("AccessGroupDetailsUserIsInGroupExplicitly");
				Document.Put(Area, 3);
			EndIf;
			Filter = New Structure("GroupParticipation", True);
			UserGroupsDetails = AccessGroupDetails.Rows.FindRows(Filter);
			If UserGroupsDetails.Count() > 0 Then
				
				Area = Template.GetArea(
				"AccessGroupDetailsUserIsInGroupAsUserGroupMember");
				
				Document.Put(Area, 3);
				For each UserGroupDetails In UserGroupsDetails Do
					
					Area = Template.GetArea(
					"AccessGroupDetailsUserIsInGroupAsMemberPresentation");
					
					Area.Parameters.Fill(UserGroupDetails);
					Document.Put(Area, 3);
				EndDo;
			EndIf;
		EndIf;
		
		If NOT OnePersonalGroup Then
			// Displaying a profile.
			Area = Template.GetArea("AccessGroupDetailsProfile");
			Area.Parameters.Fill(AccessGroupDetails);
			Document.Put(Area, 3);
		EndIf;
		
		// Displaying the employee responsible for the list of group members.
		If NOT OnePersonalGroup AND ValueIsFilled(AccessGroupDetails.EmployeeResponsible) Then
			Area = Template.GetArea("AccessGroupDetailsEmployeeResponsible");
			Area.Parameters.Fill(AccessGroupDetails);
			Document.Put(Area, 3);
		EndIf;
		
		// Displaying description.
		If NOT OnePersonalGroup AND ValueIsFilled(AccessGroupDetails.Comment) Then
			Area = Template.GetArea("AccessGroupDetailsComment");
			Area.Parameters.Fill(AccessGroupDetails);
			Document.Put(Area, 3);
		EndIf;
		
		Document.Put(IndentArea, 3);
		Document.Put(IndentArea, 3);
	EndDo;
	
EndProcedure

&AtServer
Procedure OutputRolesByProfiles(Val Template, UserOrGroup, Val QueryResult, Properties)
	
	IndentArea = Template.GetArea("Indent");
	RolesByProfiles = QueryResult.Unload(QueryResultIteration.ByGroups);
	RolesByProfiles.Rows.Sort("ProfilePresentation Asc, RolePresentation Asc");
	
	If RolesByProfiles.Rows.Count() > 0 Then
		Area = Template.GetArea("RolesByProfilesGroup");
		Area.Parameters.Fill(Properties);
		Document.Put(Area, 1);
		Document.Put(IndentArea, 2);
		
		For each ProfileDetails In RolesByProfiles.Rows Do
			Area = Template.GetArea("RolesByProfilesProfilePresentation");
			Area.Parameters.Fill(ProfileDetails);
			Document.Put(Area, 2);
			For each RoleDetails In ProfileDetails.Rows Do
				Area = Template.GetArea("RolesByProfilesRolePresentation");
				Area.Parameters.Fill(RoleDetails);
				Document.Put(Area, 3);
			EndDo;
		EndDo;
	EndIf;
	Document.Put(IndentArea, 2);
	Document.Put(IndentArea, 2);
	
EndProcedure

&AtServer
Function AccessKindPresentationTemplate(AccessKindDetails, RightsSettingsOwners)
	
	If AccessKindDetails.Rows.Count() = 0 Then
		If RightsSettingsOwners.Get(TypeOf(AccessKindDetails.AccessKind)) <> Undefined Then
			AccessKindPresentationTemplate = "%1";
			
		ElsIf AccessKindDetails.AllAllowed Then
			If AccessKindDetails.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("ru = '%1 (без запрещенных, текущий пользователь всегда разрешен)'; en = '%1 (none denied, current user is always allowed)'; pl = '%1 (bez zakazów, bieżący użytkownik zawsze dozwolony)';es_ES = '%1 (no prohibido, el usuario actual está siempre permitido)';es_CO = '%1 (no prohibido, el usuario actual está siempre permitido)';tr = '%1(yasaklanmamış, geçerli kullanıcıya her zaman izin verilir)';it = '%1 ( senza divieti, l''utente corrente ha sempre l''autorizzazione)';de = '%1 (nicht verboten, der aktuelle Benutzer ist immer erlaubt)'");
				
			ElsIf AccessKindDetails.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("ru = '%1 (без запрещенных, текущий внешний пользователь всегда разрешен)'; en = '%1 (none denied, current external user is always allowed)'; pl = '%1 (bez zakazów, bieżący użytkownik zewnętrzny zawsze dozwolony)';es_ES = '%1 (no prohibido, el usuario externo actual está siempre permitido)';es_CO = '%1 (no prohibido, el usuario externo actual está siempre permitido)';tr = '%1(yasaklanmamış, geçerli dış kullanıcıya her zaman izin verilir)';it = '%1 ( senza divieti, l''utente esterno corrente ha sempre l''autorizzazione)';de = '%1(nicht verboten, der aktuelle externe Benutzer ist immer erlaubt)'");
			Else
				AccessKindPresentationTemplate = NStr("ru = '%1 (без запрещенных)'; en = '%1 (none denied)'; pl = '%1 (bez zakazów)';es_ES = '%1 (sin prohibidos)';es_CO = '%1 (sin prohibidos)';tr = '%1 (yasaksız)';it = '%1 (nessun divieto)';de = '%1 (ohne verboten)'");
			EndIf;
		Else
			If AccessKindDetails.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("ru = '%1 (без разрешенных, текущий пользователь всегда разрешен)'; en = '%1 (none allowed, current user is always allowed)'; pl = '%1 (bez zezwoleń, bieżący użytkownik zawsze dozwolony)';es_ES = '%1 (sin permitidos, el usuario actual está siempre permitido)';es_CO = '%1 (sin permitidos, el usuario actual está siempre permitido)';tr = '%1(izin verilmiş, geçerli kullanıcısız her zaman izin verilir)';it = '%1 ( senza divieti, l''utente corrente ha sempre l''autorizzazione)';de = '%1 (ohne erlaubt, aktueller Benutzer ist immer erlaubt)'");
				
			ElsIf AccessKindDetails.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("ru = '%1 (без разрешенных, текущий внешний пользователь всегда разрешен)'; en = '%1 (none allowed, current external user is always allowed)'; pl = '%1 (bez zezwoleń, bieżący użytkownik zawsze dozwolony)';es_ES = '%1 (no permitido, el usuario externo actual está siempre permitido)';es_CO = '%1 (no permitido, el usuario externo actual está siempre permitido)';tr = '%1(yasaklanmamış, geçerli dış kullanıcıya her zaman izin verilir)';it = '%1 (senza divieti, l''utente esterno corrente ha sempre l''autorizzazione)';de = '%1 (nicht erlaubt, der aktuelle externe Benutzer ist immer erlaubt)'");
			Else
				AccessKindPresentationTemplate = NStr("ru = '%1 (без разрешенных)'; en = '%1 (none allowed)'; pl = '%1 (bez zezwoleń)';es_ES = '%1 (sin permitidos)';es_CO = '%1 (sin permitidos)';tr = '%1 (yasaksız)';it = '%1 (nessun permesso)';de = '%1 (ohne erlaubt)'");
			EndIf;
		EndIf;
	Else
		If AccessKindDetails.AllAllowed Then
			If AccessKindDetails.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("ru = '%1 (запрещенные, текущий пользователь всегда разрешен):'; en = '%1 (denied, current user is always allowed):'; pl = '%1 (zabronione, bieżący użytkownik zawsze dozwolony):';es_ES = '%1 (prohibido, el usuario actual está siempre permitido):';es_CO = '%1 (prohibido, el usuario actual está siempre permitido):';tr = '%1(yasaklanmış, geçerli kullanıcıya her zaman izin verilir)';it = '%1 (vietato, l''utente corrente è sempre permesso):';de = '%1 (verboten, der aktuelle Benutzer ist immer erlaubt):'");
				
			ElsIf AccessKindDetails.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("ru = '%1 (запрещенные, текущий внешний пользователь всегда разрешен):'; en = '%1 (denied, current external user is always allowed):'; pl = '%1 (zabronione, bieżący użytkownik zewnętrzny zawsze dozwolony):';es_ES = '%1 (prohibido, el usuario externo actual está siempre permitido):';es_CO = '%1 (prohibido, el usuario externo actual está siempre permitido):';tr = '%1(yasaklanmış, geçerli dış kullanıcıya her zaman izin verilir)';it = '%1 (vietati, l''utente esterno corrente ha sempre l''autorizzazione):';de = '%1 (verboten, der aktuelle externe Benutzer ist immer erlaubt):'");
			Else
				AccessKindPresentationTemplate = NStr("ru = '%1 (запрещенные):'; en = '%1 (denied):'; pl = '%1 (zabronione):';es_ES = '%1 (prohibido):';es_CO = '%1 (prohibido):';tr = '%1 (yasaklanmış):';it = '%1 (vietato):';de = '%1 (verboten):'");
			EndIf;
		Else
			If AccessKindDetails.AccessKind = Catalogs.Users.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("ru = '%1 (разрешенные, текущий пользователь всегда разрешен):'; en = '%1 (allowed, current user is always allowed):'; pl = '%1 (dozwolone, bieżący użytkownik zawsze dozwolony):';es_ES = '%1 (permitido, el usuario actual está siempre permitido):';es_CO = '%1 (permitido, el usuario actual está siempre permitido):';tr = '%1(yasaklanmamış, geçerli kullanıcıya her zaman izin verilir)';it = '%1 ( concessi, l''utente corrente ha sempre l''autorizzazione):';de = '%1 (erlaubt, der aktuelle Benutzer ist immer erlaubt):'");
				
			ElsIf AccessKindDetails.AccessKind = Catalogs.ExternalUsers.EmptyRef() Then
				AccessKindPresentationTemplate =
					NStr("ru = '%1 (разрешенные, текущий внешний пользователь всегда разрешен):'; en = '%1 (allowed, current external user is always allowed):'; pl = '%1 (dozwolone, bieżący użytkownik zewnętrzny zawsze dozwolony):';es_ES = '%1 (permitido, el usuario externo actual está siempre permitido):';es_CO = '%1 (permitido, el usuario externo actual está siempre permitido):';tr = '%1(yasaklanmamış, geçerli kullanıcıya her zaman izin verilir)';it = '%1 (concessi, l''utente esterno corrente ha sempre l''autorizzazione):';de = '%1 (erlaubt, der aktuelle externe Benutzer ist immer erlaubt):'");
			Else
				AccessKindPresentationTemplate = NStr("ru = '%1 (разрешенные):'; en = '%1 (allowed):'; pl = '%1 (dozwolone):';es_ES = '%1 (permitido):';es_CO = '%1 (permitido):';tr = '%1 (izin verilir)';it = '%1 (vietati):';de = '%1 (erlaubt):'");
			EndIf;
		EndIf;
	EndIf;
	
	Return AccessKindPresentationTemplate;
	
EndFunction

&AtServer
Procedure OutputArea(Val Document,
                         Area,
                         Level,
                         ObjectAreaInitialString,
                         ObjectAreaEndRow,
                         AccessGroupAreaInitialRow)
	
	If ObjectAreaInitialString = Undefined Then
		ObjectAreaInitialString = Document.Put(Area, Level);
		ObjectAreaEndRow        = ObjectAreaInitialString;
	Else
		ObjectAreaEndRow = Document.Put(Area);
	EndIf;
	
	If AccessGroupAreaInitialRow = Undefined Then
		AccessGroupAreaInitialRow = ObjectAreaEndRow;
	EndIf;
	
	Area = Undefined;
	
EndProcedure

&AtServer
Procedure MergeCellsSetBoundaries(Val Document,
                                            Val InitialAreaString,
                                            Val EndAreaRow,
                                            Val ColumnNumber)
	
	Area = Document.Area(
		InitialAreaString.Top,
		ColumnNumber,
		EndAreaRow.Bottom,
		ColumnNumber);
	
	Area.Merge();
	
	BoundaryString = New Line(SpreadsheetDocumentCellLineType.Dotted);
	
	Area.TopBorder = BoundaryString;
	Area.BottomBorder  = BoundaryString;
	
EndProcedure
	
&AtServer
Procedure SetKindsAndAccessValuesBoundaries(Val Document,
                                                 Val AccessGroupAreaInitialRow,
                                                 Val ObjectAreaEndRow)
	
	BoundaryString = New Line(SpreadsheetDocumentCellLineType.Dotted);
	
	Area = Document.Area(
		AccessGroupAreaInitialRow.Top,
		4,
		AccessGroupAreaInitialRow.Top,
		5);
	
	Area.TopBorder = BoundaryString;
	
	Area = Document.Area(
		ObjectAreaEndRow.Bottom,
		4,
		ObjectAreaEndRow.Bottom,
		5);
	
	Area.BottomBorder = BoundaryString;
	
EndProcedure

&AtServer
Function RunModePresentation(RunMode)
	
	If RunMode = "Auto" Then
		RunModePresentation = NStr("ru = 'Авто'; en = 'Auto'; pl = 'Auto';es_ES = 'Auto';es_CO = 'Auto';tr = 'Oto';it = 'Auto';de = 'Auto'");
		
	ElsIf RunMode = "OrdinaryApplication" Then
		RunModePresentation = NStr("ru = 'Обычное приложение'; en = 'Standard application'; pl = 'Standardowa aplikacja';es_ES = 'Aplicación estándar';es_CO = 'Aplicación estándar';tr = 'Standart uygulama';it = 'Applicazione standard';de = 'Standardanwendung'");
		
	ElsIf RunMode = "ManagedApplication" Then
		RunModePresentation = NStr("ru = 'Управляемое приложение'; en = 'Managed application'; pl = 'Aplikacja zarządzana';es_ES = 'Aplicación gestionada';es_CO = 'Aplicación gestionada';tr = 'Yönetilen uygulama';it = 'Applicazione gestita';de = 'Steuerbare Applikation'");
	Else
		RunModePresentation = "";
	EndIf;
	
	Return RunModePresentation;
	
EndFunction

&AtServer
Function LanguagePresentation(Language)
	
	LanguagePresentation = "";
	
	For each LanguageMetadata In Metadata.Languages Do
	
		If LanguageMetadata.Name = Language Then
			LanguagePresentation = LanguageMetadata.Synonym;
			Break;
		EndIf;
	EndDo;
	
	Return LanguagePresentation;
	
EndFunction

// MetadataObjectsRightsRestrictionsKinds function returns a value table containing access 
// restriction kind by each metadata object right.
// 
//  If no record is returned for a right, no restrictions exist for this right.
//
// Returns:
//  ValueTable:
//    AccessKind - Ref - a blank reference of the main access kind value type.
//    Presentation - String - an access kind presentation.
//    Table - CatalogRef.MetadataObjectsIDs, for example, CatalogRef.Counterparties.
//                    
//    Right - Row: "Read", "Update".
//
&AtServer
Function MetadataObjectsRightsRestrictionsKinds()
	
	Cache = AccessManagementInternalCached.MetadataObjectsRightsRestrictionsKinds();
	
	If CurrentSessionDate() < Cache.UpdateDate + 60*30 Then
		Return Cache.Table;
	EndIf;
	
	AccessKindsValuesTypes =
		AccessManagementInternalCached.ValuesTypesOfAccessKindsAndRightsSettingsOwners().Get();
	
	Query = New Query;
	Query.SetParameter("PermanentRestrictionKinds",
		AccessManagementInternalCached.PermanentMetadataObjectsRightsRestrictionsKinds());
	
	Query.SetParameter("AccessKindsValuesTypes", AccessKindsValuesTypes);
	
	UsedAccessKinds = AccessKindsValuesTypes.Copy(, "AccessKind");
	
	UsedAccessKinds.GroupBy("AccessKind");
	UsedAccessKinds.Columns.Add("Presentation", New TypeDescription("String", , New StringQualifiers(150)));
	
	Index = UsedAccessKinds.Count()-1;
	While Index >= 0 Do
		Row = UsedAccessKinds[Index];
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(Row.AccessKind);
		
		If AccessKindProperties = Undefined Then
			RightsSettingsOwnerMetadata = Metadata.FindByType(TypeOf(Row.AccessKind));
			If RightsSettingsOwnerMetadata = Undefined Then
				Row.Presentation = NStr("ru = 'Неизвестный вид доступа'; en = 'Unknown access kind'; pl = 'Nieznany rodzaj dostępu';es_ES = 'Tipo de acceso desconocido';es_CO = 'Tipo de acceso desconocido';tr = 'Bilinmeyen erişim türü';it = 'Sconosciuta modalità di accesso';de = 'Unbekannte Zugang Art'");
			Else
				Row.Presentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Настройки прав на %1'; en = 'Rights settings for %1'; pl = 'Ustaw prawa użytkownika do %1';es_ES = 'Establecer los derechos de usuario para %1';es_CO = 'Establecer los derechos de usuario para %1';tr = 'Kullanıcı ayarları %1 için ayarla';it = 'Permessi di accesso per %1';de = 'Benutzerrechte setzen auf %1'"),
					RightsSettingsOwnerMetadata.Presentation());
			EndIf;
		ElsIf AccessManagementInternal.AccessKindUsed(Row.AccessKind) Then
			Row.Presentation = AccessKindProperties.Presentation;
		Else
			UsedAccessKinds.Delete(Row);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.Text =
	"SELECT
	|	PermanentRestrictionKinds.Table,
	|	PermanentRestrictionKinds.UserRight,
	|	PermanentRestrictionKinds.AccessKind,
	|	PermanentRestrictionKinds.ObjectTable
	|INTO PermanentRestrictionKinds
	|FROM
	|	&PermanentRestrictionKinds AS PermanentRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsValuesTypes.AccessKind,
	|	AccessKindsValuesTypes.ValuesType
	|INTO AccessKindsValuesTypes
	|FROM
	|	&AccessKindsValuesTypes AS AccessKindsValuesTypes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UsedAccessKinds.AccessKind,
	|	UsedAccessKinds.Presentation
	|INTO UsedAccessKinds
	|FROM
	|	&UsedAccessKinds AS UsedAccessKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PermanentRestrictionKinds.Table,
	|	""Read"" AS UserRight,
	|	VALUETYPE(RowsSets.AccessValue) AS ValuesType
	|INTO VariableRestrictionKinds
	|FROM
	|	InformationRegister.AccessValuesSets AS SetsNumbers
	|		INNER JOIN PermanentRestrictionKinds AS PermanentRestrictionKinds
	|		ON (PermanentRestrictionKinds.UserRight = ""Read"")
	|			AND (PermanentRestrictionKinds.AccessKind = UNDEFINED)
	|			AND (VALUETYPE(SetsNumbers.Object) = VALUETYPE(PermanentRestrictionKinds.ObjectTable))
	|			AND (SetsNumbers.Read)
	|		INNER JOIN InformationRegister.AccessValuesSets AS RowsSets
	|		ON (RowsSets.Object = SetsNumbers.Object)
	|			AND (RowsSets.SetNumber = SetsNumbers.SetNumber)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	PermanentRestrictionKinds.Table,
	|	""Update"",
	|	VALUETYPE(RowsSets.AccessValue)
	|FROM
	|	InformationRegister.AccessValuesSets AS SetsNumbers
	|		INNER JOIN PermanentRestrictionKinds AS PermanentRestrictionKinds
	|		ON (PermanentRestrictionKinds.UserRight = ""Update"")
	|			AND (PermanentRestrictionKinds.AccessKind = UNDEFINED)
	|			AND (VALUETYPE(SetsNumbers.Object) = VALUETYPE(PermanentRestrictionKinds.ObjectTable))
	|			AND (SetsNumbers.Update)
	|		INNER JOIN InformationRegister.AccessValuesSets AS RowsSets
	|		ON (RowsSets.Object = SetsNumbers.Object)
	|			AND (RowsSets.SetNumber = SetsNumbers.SetNumber)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PermanentRestrictionKinds.Table,
	|	PermanentRestrictionKinds.UserRight,
	|	AccessKindsValuesTypes.AccessKind
	|INTO AllRightRestrictionsKinds
	|FROM
	|	PermanentRestrictionKinds AS PermanentRestrictionKinds
	|		INNER JOIN AccessKindsValuesTypes AS AccessKindsValuesTypes
	|		ON PermanentRestrictionKinds.AccessKind = AccessKindsValuesTypes.AccessKind
	|			AND (PermanentRestrictionKinds.AccessKind <> UNDEFINED)
	|
	|UNION
	|
	|SELECT
	|	VariableRestrictionKinds.Table,
	|	VariableRestrictionKinds.UserRight,
	|	AccessKindsValuesTypes.AccessKind
	|FROM
	|	VariableRestrictionKinds AS VariableRestrictionKinds
	|		INNER JOIN AccessKindsValuesTypes AS AccessKindsValuesTypes
	|		ON (VariableRestrictionKinds.ValuesType = VALUETYPE(AccessKindsValuesTypes.ValuesType))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllRightRestrictionsKinds.Table,
	|	AllRightRestrictionsKinds.UserRight,
	|	AllRightRestrictionsKinds.AccessKind,
	|	UsedAccessKinds.Presentation
	|FROM
	|	AllRightRestrictionsKinds AS AllRightRestrictionsKinds
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON AllRightRestrictionsKinds.AccessKind = UsedAccessKinds.AccessKind";
	
	DataExported = Query.Execute().Unload();
	
	Cache.Table = DataExported;
	Cache.UpdateDate = CurrentSessionDate();
	
	Return DataExported;
	
EndFunction

&AtServer
Function MaxStringLength(MultilineString, InitialLength = 5)
	
	For RowNumber = 1 To StrLineCount(MultilineString) Do
		SubstringLength = StrLen(StrGetLine(MultilineString, RowNumber));
		If InitialLength < SubstringLength Then
			InitialLength = SubstringLength;
		EndIf;
	EndDo;
	
	Return InitialLength + 1;
	
EndFunction

&AtServer
Function ObjectsTypeRootItems(ObjectsType)
	
	TableName = Metadata.FindByType(ObjectsType).FullName();
	
	Query = New Query;
	Query.SetParameter("EmptyRef",
		Common.ObjectManagerByFullName(TableName).EmptyRef());
	
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Parent = &EmptyRef";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", TableName);
	Selection = Query.Execute().Select();
	
	RootItems = New Map;
	While Selection.Next() Do
		RootItems.Insert(Selection.Ref, True);
	EndDo;
	
	Return RootItems;
	
EndFunction

#EndRegion
