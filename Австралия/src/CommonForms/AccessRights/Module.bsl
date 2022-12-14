
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	IBUserFull = Users.IsFullUser();
	OwnAccess = Parameters.User = Users.AuthorizedUser();
	
	IBUserEmployeeResponsible =
		NOT IBUserFull
		AND AccessRight("Edit", Metadata.Catalogs.AccessGroups);
	
	Items.AccessGroupsContextMenuChangeGroup.Visible =
		IBUserFull
		OR IBUserEmployeeResponsible;
	
	Items.FormAccessRightsReport.Visible =
		IBUserFull
		OR Parameters.User = Users.AuthorizedUser();
	
	// Setting commands for a regular user.
	Items.FormAddToGroup.Visible   = IBUserEmployeeResponsible;
	Items.FormRemoveFromGroup.Visible = IBUserEmployeeResponsible;
	Items.FormChangeGroup.Visible    = IBUserEmployeeResponsible;
	
	// Setting commands for a user with full rights.
	Items.AccessGroupsAddToGroup.Visible   = IBUserFull;
	Items.AccessGroupsRemoveFromGroup.Visible = IBUserFull;
	Items.AccessGroupsChangeGroup.Visible    = IBUserFull;
	
	// Setting the page tab display.
	Items.AccessGroupsAndRoles.PagesRepresentation =
		?(IBUserFull,
		  FormPagesRepresentation.TabsOnTop,
		  FormPagesRepresentation.None);
	
	// Setting the command bar display for a full user.
	Items.AccessGroups.CommandBarLocation =
		?(IBUserFull,
		  FormItemCommandBarLabelLocation.Top,
		  FormItemCommandBarLabelLocation.None);
	
	// Setting a role view for a user with full rights.
	Items.RolesRepresentation.Visible = IBUserFull;
	
	If IBUserFull
	 OR IBUserEmployeeResponsible
	 OR OwnAccess Then
		
		OutputAccessGroups();
	Else
		// Regular users cannot view other user access settings.
		Items.AccessGroupsAddToGroup.Visible   = False;
		Items.AccessGroupsRemoveFromGroup.Visible = False;
		
		Items.AccessGroupsAndRoles.Visible         = False;
		Items.InsufficientViewRights.Visible = True;
	EndIf;
	
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate");
	ProcessRolesInterface("SetRolesReadOnly", True);
	
	If Common.IsStandaloneWorkplace() Then
		Items.FormAddToGroup.Enabled   = False;
		Items.FormRemoveFromGroup.Enabled = False;
		Items.AccessGroupsAddToGroup.Enabled   = False;
		Items.AccessGroupsRemoveFromGroup.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_AccessGroups")
	 OR Upper(EventName) = Upper("Write_AccessGroupProfiles")
	 OR Upper(EventName) = Upper("Write_UserGroups")
	 OR Upper(EventName) = Upper("Write_ExternalUserGroups") Then
		
		OutputAccessGroups();
		UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region AccessGroupsFormTableItemsEventHandlers

&AtClient
Procedure AccessGroupsOnActivateRow(Item)
	
	CurrentData   = Items.AccessGroups.CurrentData;
	CurrentParent = Items.AccessGroups.CurrentParent;
	
	If CurrentData = Undefined Then
		
		AccessGroupChanged = ValueIsFilled(CurrentAccessGroup);
		CurrentAccessGroup  = Undefined;
	Else
		NewAccessGroup    = ?(CurrentParent = Undefined, CurrentData.AccessGroup, CurrentParent.AccessGroup);
		AccessGroupChanged = CurrentAccessGroup <> NewAccessGroup;
		CurrentAccessGroup  = NewAccessGroup;
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessGroupsChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If AccessGroups.FindByID(RowSelected) <> Undefined Then
		
		If Items.FormChangeGroup.Visible
		 OR Items.AccessGroupsChangeGroup.Visible Then
			
			ChangeGroup(Items.FormChangeGroup);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AddToGroup(Command)
	
	FormParameters = New Structure;
	Selected = New Array;
	
	For each AccessGroupDetails In AccessGroups Do
		Selected.Add(AccessGroupDetails.AccessGroup);
	EndDo;
	
	FormParameters.Insert("Selected",         Selected);
	FormParameters.Insert("GroupUser", Parameters.User);
	
	OpenForm("Catalog.AccessGroups.Form.SelectGroupsByEmployeeResponsible", FormParameters, ThisObject,
		,,, New NotifyDescription("IncludeExcludeFromGroup", ThisObject, True));
	
EndProcedure

&AtClient
Procedure RemoveFromGroup(Command)
	
	If NOT ValueIsFilled(CurrentAccessGroup) Then
		ShowMessageBox(, NStr("ru = '???????????? ?????????????? ???? ??????????????.'; en = 'No access group is selected.'; pl = 'Nie wybrano grupy dost??pu.';es_ES = 'Grupo de acceso no est?? seleccionado.';es_CO = 'Grupo de acceso no est?? seleccionado.';tr = 'Eri??im grubu se??ilmedi.';it = 'Nessun gruppo di accesso ?? selezionato.';de = 'Zugriffsgruppe ist nicht ausgew??hlt.'"));
		Return;
	EndIf;
	
	IncludeExcludeFromGroup(CurrentAccessGroup, False);
	
EndProcedure

&AtClient
Procedure ChangeGroup(Command)
	
	FormParameters = New Structure;
	
	If NOT ValueIsFilled(CurrentAccessGroup) Then
		ShowMessageBox(, NStr("ru = '???????????? ?????????????? ???? ??????????????.'; en = 'No access group is selected.'; pl = 'Nie wybrano grupy dost??pu.';es_ES = 'Grupo de acceso no est?? seleccionado.';es_CO = 'Grupo de acceso no est?? seleccionado.';tr = 'Eri??im grubu se??ilmedi.';it = 'Nessun gruppo di accesso ?? selezionato.';de = 'Zugriffsgruppe ist nicht ausgew??hlt.'"));
		Return;
		
	ElsIf IBUserFull
	      OR IBUserEmployeeResponsible
	          AND GroupUsersChangeAllowed(CurrentAccessGroup) Then
		
		FormParameters.Insert("Key", CurrentAccessGroup);
		OpenForm("Catalog.AccessGroups.ObjectForm", FormParameters);
	Else
		ShowMessageBox(,
			NStr("ru = '???????????????????????? ???????? ?????? ???????????????????????????? ???????????? ??????????????.
			           |?????????????????????????? ???????????? ?????????????? ?????????? ?????????????????????????? ???? ???????????????????? ???????????? ?????????????? ?? ??????????????????????????.'; 
			           |en = 'Insufficient rights to edit the access group.
			           |Only an employee responsible for access group members and administrator can edit the access group.'; 
			           |pl = 'Niewystarczaj??ce uprawnienia do edytowania grupy dost??pu.
			           |Osoba odpowiedzialna za dost??p do grupy i administrator grupy mo??e edytowa?? grup?? dost??pu.';
			           |es_ES = 'Insuficientes derechos para editar el grupo de acceso.
			           |Persona responsable de los participantes del grupo de acceso y el administrador pueden editar el grupo de acceso.';
			           |es_CO = 'Insuficientes derechos para editar el grupo de acceso.
			           |Persona responsable de los participantes del grupo de acceso y el administrador pueden editar el grupo de acceso.';
			           |tr = 'Eri??im grubunu d??zenlemek i??in yetersiz haklar. 
			           |Eri??im grubundan sorumlu ki??i, kat??l??mc??lar?? ve y??neticisi eri??im grubunu d??zenleyebilir.';
			           |it = 'Permessi insufficienti per modificare il gruppo di accesso.
			           |Solo un dipendente responsabile per l''accesso del gruppo membie e amministratore pu?? modificare il gruppo di accesso.';
			           |de = 'Unzureichende Rechte zum Bearbeiten der Zugriffsgruppe.
			           |Verantwortliche f??r die Zugangsgruppen-Teilnehmer und den Administrator k??nnen die Zugangsgruppe bearbeiten.'"));
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure Update(Command)
	
	OutputAccessGroups();
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure AccessRightsReport(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("User", Parameters.User);
	
	OpenForm("Report.AccessRights.Form", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure RolesBySubsystemsGroup(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure IncludeExcludeFromGroup(AccessGroup, IncludeInAccessGroup) Export
	
	If TypeOf(AccessGroup) <> Type("CatalogRef.AccessGroups")
	  OR NOT ValueIsFilled(AccessGroup) Then
		
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AccessGroup", AccessGroup);
	AdditionalParameters.Insert("IncludeInAccessGroup", IncludeInAccessGroup);
	
	If StandardSubsystemsClient.ClientRunParameters().DataSeparationEnabled
	   AND AccessGroup = PredefinedValue("Catalog.AccessGroups.Administrators") Then
		
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription(
				"IncludeExcludeFromGroupCompletion", ThisObject, AdditionalParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	Else
		IncludeExcludeFromGroupCompletion(Null, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure IncludeExcludeFromGroupCompletion(SaaSUserNewPassword, AdditionalParameters) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	If SaaSUserNewPassword <> Null Then
		ServiceUserPassword = SaaSUserNewPassword;
	EndIf;
	
	ErrorDescription = "";
	
	ChangeGroupContent(
		AdditionalParameters.AccessGroup,
		AdditionalParameters.IncludeInAccessGroup,
		ErrorDescription);
	
	If ValueIsFilled(ErrorDescription) Then
		ShowMessageBox(, ErrorDescription);
	Else
		NotifyChanged(AdditionalParameters.AccessGroup);
		Notify("Write_AccessGroups", New Structure, AdditionalParameters.AccessGroup);
	EndIf;
	
EndProcedure

&AtServer
Procedure OutputAccessGroups()
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If IBUserFull OR OwnAccess Then
		SetPrivilegedMode(True);
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED
	|	AccessGroups.Ref
	|INTO AllowedAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups";
	Query.Execute();
	
	SetPrivilegedMode(True);
	
	Query.Text =
	"SELECT
	|	AllowedAccessGroups.Ref
	|FROM
	|	AllowedAccessGroups AS AllowedAccessGroups
	|WHERE
	|	(NOT AllowedAccessGroups.Ref.DeletionMark)
	|	AND (NOT AllowedAccessGroups.Ref.Profile.DeletionMark)";
	AllowedAccessGroups = Query.Execute().Unload();
	AllowedAccessGroups.Indexes.Add("Ref");
	
	Query.SetParameter("User", Parameters.User);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.Description AS Description,
	|	AccessGroups.Profile.Description AS ProfileDescription,
	|	AccessGroups.Comment AS Comment,
	|	AccessGroups.EmployeeResponsible AS EmployeeResponsible
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	NOT AccessGroups.DeletionMark
	|	AND NOT AccessGroups.Profile.DeletionMark
	|	AND TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				Catalog.AccessGroups.Users AS AccessGroupsUsers
	|			WHERE
	|				AccessGroupsUsers.Ref = AccessGroups.Ref
	|				AND NOT(AccessGroupsUsers.User <> &User
	|						AND NOT AccessGroupsUsers.User IN
	|								(SELECT
	|									UserGroupCompositions.UsersGroup
	|								FROM
	|									InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|								WHERE
	|									UserGroupCompositions.User = &User)))
	|
	|ORDER BY
	|	AccessGroups.Description";
	
	AllAccessGroups = Query.Execute().Unload();
	
	// Setting an access group presentation.
	// Removing the current user from the access group if they directly belong to it.
	HasProhibitedGroups = False;
	Index = AllAccessGroups.Count()-1;
	
	While Index >= 0 Do
		Row = AllAccessGroups[Index];
		
		If AllowedAccessGroups.Find(Row.AccessGroup, "Ref") = Undefined Then
			AllAccessGroups.Delete(Index);
			HasProhibitedGroups = True;
		EndIf;
		Index = Index - 1;
	EndDo;
	
	ValueToFormAttribute(AllAccessGroups, "AccessGroups");
	Items.HasHiddenAccessGroupsWarning.Visible = HasProhibitedGroups;
	
	If NOT ValueIsFilled(CurrentAccessGroup) Then
		
		If AccessGroups.Count() > 0 Then
			CurrentAccessGroup = AccessGroups[0].AccessGroup;
		EndIf;
	EndIf;
	
	For each AccessGroupDetails In AccessGroups Do
		
		If AccessGroupDetails.AccessGroup = CurrentAccessGroup Then
			Items.AccessGroups.CurrentRow = AccessGroupDetails.GetID();
			Break;
		EndIf;
	EndDo;
	
	If IBUserFull Then
		FillRoles();
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeGroupContent(Val AccessGroup, Val Add, ErrorDescription = "")
	
	If NOT GroupUsersChangeAllowed(AccessGroup) Then
		If Add Then
			ErrorDescription =
				NStr("ru = '???????????????????? ???????????????? ???????????????????????? ?? ???????????? ??????????????,
				           |?????? ?????? ?????????????? ????????????????????????
				           |???? ?????????????????????????? ???? ???????????????????? ???????????? ?????????????? ??
				           |???? ???????????????????????? ??????????????????????????.'; 
				           |en = 'Cannot include the user in the access group
				           |as the current user
				           |is not responsible for the access group members and
				           |not an administrator.'; 
				           |pl = 'Nie mo??na w????czy?? u??ytkownika do grupy dost??pu,
				           |poniewa?? bie????cy u??ytkownik
				           |nie jest osob?? odpowiedzialn?? za cz??onk??w grupy dost??pu ani
				           |pe??noprawnym administratorem.';
				           |es_ES = 'Es imposible incluir el usuario en el grupo de acceso,
				           |porque el usuario actual
				           |no es responsable por los participantes del grupo de acceso y
				           |no es administrador de derechos completos.';
				           |es_CO = 'Es imposible incluir el usuario en el grupo de acceso,
				           |porque el usuario actual
				           |no es responsable por los participantes del grupo de acceso y
				           |no es administrador de derechos completos.';
				           |tr = 'Kullan??c??y?? bir eri??im grubuna dahil etmek m??mk??n de??ildir, 
				           |????nk?? mevcut 
				           |kullan??c?? eri??im grubunun ??yelerinden 
				           |sorumlu olan tam yetkili bir y??netici de??ildir.';
				           |it = 'Impossibile includere l''utente nel gruppo di accesso
				           |, poich?? l''utente corrente
				           |non ?? responsabile per i membri del gruppo di accesso
				           |e non ?? un amministratore.';
				           |de = 'Es ist nicht m??glich, einen Benutzer in die Zugriffsgruppe aufzunehmen,
				           |da der aktuelle Benutzer
				           |nicht f??r die Mitglieder der Zugriffsgruppe verantwortlich ist und
				           |kein vollwertiger Administrator ist.'");
		Else
			ErrorDescription =
				NStr("ru = '???????????????????? ?????????????????? ???????????????????????? ???? ???????????? ??????????????,
				           |?????? ?????? ?????????????? ????????????????????????
				           |???? ?????????????????????????? ???? ???????????????????? ???????????? ?????????????? ??
				           |???? ???????????????????????? ??????????????????????????.'; 
				           |en = 'Cannot exclude the user from the access group
				           |as the current user 
				           |is not responsible for the access group members and
				           |not an administrator.'; 
				           |pl = 'Nie mo??na wykluczy?? u??ytkownika z grupy dost??pu,
				           |poniewa?? bie????cy u??ytkownik
				           |nie jest osob?? odpowiedzialn?? za cz??onk??w grupy dost??pu ani
				           |pe??noprawnym administratorem.';
				           |es_ES = 'Es imposible excluir el usuario del grupo de acceso,
				           |porque el usuario actual
				           |no es responsable por los participantes del grupo de acceso y
				           |no es administrador de derechos completos.';
				           |es_CO = 'Es imposible excluir el usuario del grupo de acceso,
				           |porque el usuario actual
				           |no es responsable por los participantes del grupo de acceso y
				           |no es administrador de derechos completos.';
				           |tr = 'Kullan??c??, eri??im grubundan ????kar??lam??yor
				           |????nk?? mevcut kullan??c??
				           |eri??im grubu ??yelerinden sorumlu
				           |veya y??netici de??il.';
				           |it = 'Impossibile escludere l''utente dal gruppo di accesso
				           |, poich?? l''utente corrente 
				           |non ?? responsabile per i membri del gruppo di accesso
				           |e non ?? un amministratore.';
				           |de = 'Es ist nicht m??glich, einen Benutzer von der Zugriffsgruppe auszuschlie??en,
				           |da der aktuelle Benutzer
				           |nicht f??r die Mitglieder der Zugriffsgruppe verantwortlich ist und der Administrator
				           |kein vollst??ndiger Administrator ist.'");
		EndIf;
		Return;
	EndIf;
	
	If NOT Add AND NOT UserIncludedInAccessGroup(CurrentAccessGroup) Then
		ErrorDescription =
			NStr("ru = '???????????????????? ?????????????????? ???????????????????????? ???? ???????????? ??????????????,
			           |?????? ?????? ???? ?????????????? ?? ?????? ????????????????.'; 
			           |en = 'Cannot exclude the user from the access group
			           |as the user is not a direct member of the group.'; 
			           |pl = 'Nie mo??na wykluczy?? u??ytkownika z grupy dost??pu,
			           |poniewa?? jest on do niej w????czony po??rednio.';
			           |es_ES = 'Es imposible excluir el usuario del grupo de acceso,
			           |, porque est?? incluido en el grupo indirectamente.';
			           |es_CO = 'Es imposible excluir el usuario del grupo de acceso,
			           |, porque est?? incluido en el grupo indirectamente.';
			           |tr = 'Kullan??c??, eri??im grubuna dolayl?? olarak dahil oldu??undan, bu eri??im grubundan
			           | ????kar??lamaz.';
			           |it = '?? impossibile escludere un utente da un gruppo di accesso,
			           |poich?? egli ?? indirettamente incluso in esso.';
			           |de = 'Es ist nicht m??glich, einen Benutzer von einer Zugriffsgruppe auszuschlie??en,
			           |da er indirekt darin enthalten ist.'");
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled()
	   AND AccessGroup = Catalogs.AccessGroups.Administrators
	   AND Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ActionsWithSaaSUser = ModuleUsersInternalSaaS.GetActionsWithSaaSUser();
		
		If NOT ActionsWithSaaSUser.ChangeAdministrativeAccess Then
			Raise
				NStr("ru = '???? ???????????????????? ???????? ?????????????? ?????? ?????????????????? ?????????????? ??????????????????????????????.'; en = 'You are not authorized to change the administrators.'; pl = 'Niewystarczaj??ce uprawnienia dost??pu do edytowania administrator??w.';es_ES = 'Insuficientes derechos de acceso para editar los administradores.';es_CO = 'Insuficientes derechos de acceso para editar los administradores.';tr = 'Y??neticileri d??zenlemek i??in yetersiz eri??im haklar??.';it = 'Non siete autorizzati a modificare gli amministratori.';de = 'Unzureichende Zugriffsrechte zum Bearbeiten von Administratoren.'");
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	AccessGroupObject = AccessGroup.GetObject();
	LockDataForEdit(AccessGroupObject.Ref, AccessGroupObject.DataVersion);
	If Add Then
		If AccessGroupObject.Users.Find(Parameters.User, "User") = Undefined Then
			AccessGroupObject.Users.Add().User = Parameters.User;
		EndIf;
	Else
		TSRow = AccessGroupObject.Users.Find(Parameters.User, "User");
		If TSRow <> Undefined Then
			AccessGroupObject.Users.Delete(TSRow);
		EndIf;
	EndIf;
	
	If AccessGroupObject.Ref = Catalogs.AccessGroups.Administrators Then
		
		If Common.DataSeparationEnabled() Then
			AccessGroupObject.AdditionalProperties.Insert(
				"ServiceUserPassword", ServiceUserPassword);
		Else
			AccessManagementInternal.CheckAdministratorsAccessGroupForIBUser(
				AccessGroupObject.Users, ErrorDescription);
			
			If ValueIsFilled(ErrorDescription) Then
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	Try
		AccessGroupObject.Write();
	Except
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
	UnlockDataForEdit(AccessGroupObject.Ref);
	
	CurrentAccessGroup = AccessGroupObject.Ref;
	
	AccessManagementInternal.AfterChangeRightsSettingsInForm();
	
EndProcedure

&AtServer
Function GroupUsersChangeAllowed(AccessGroup)
	
	If IBUserFull Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessGroup",              AccessGroup);
	Query.SetParameter("AuthorizedUser", Users.AuthorizedUser());
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.User = &AuthorizedUser)
	|			AND (UserGroupCompositions.UsersGroup = AccessGroups.EmployeeResponsible)
	|			AND (AccessGroups.Ref = &AccessGroup)";
	
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Function UserIncludedInAccessGroup(AccessGroup)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("AccessGroup", AccessGroup);
	Query.SetParameter("User", Parameters.User);
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.Ref = &AccessGroup
	|	AND AccessGroupsUsers.User = &User";
	
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure FillRoles()
	
	Query = New Query;
	Query.SetParameter("User", Parameters.User);
	
	If TypeOf(Parameters.User) = Type("CatalogRef.Users")
	 OR TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers") Then
		
		Query.Text =
		"SELECT DISTINCT 
		|	Roles.Role AS Role
		|FROM
		|	Catalog.AccessGroupProfiles.Roles AS Roles
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
		|			INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|			ON (UserGroupCompositions.User = &User)
		|				AND (UserGroupCompositions.UsersGroup = AccessGroupsUsers.User)
		|				AND (NOT AccessGroupsUsers.Ref.DeletionMark)
		|		ON Roles.Ref = AccessGroupsUsers.Ref.Profile
		|			AND (NOT Roles.Ref.DeletionMark)";
	Else
		// User group or External user group.
		Query.Text =
		"SELECT DISTINCT
		|	Roles.Role AS Role
		|FROM
		|	Catalog.AccessGroupProfiles.Roles AS Roles
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
		|		ON (AccessGroupsUsers.User = &User)
		|			AND (NOT AccessGroupsUsers.Ref.DeletionMark)
		|			AND Roles.Ref = AccessGroupsUsers.Ref.Profile
		|			AND (NOT Roles.Ref.DeletionMark)";
	EndIf;
	
	ProcessRolesInterface("FillRoles", Query.Execute().Unload());
	
	Filter = New Structure("Role", "FullRights");
	If ReadRoles.FindRows(Filter).Count() > 0 Then
		
		Filter = New Structure("Role", "SystemAdministrator");
		If ReadRoles.FindRows(Filter).Count() > 0 Then
			
			ReadRoles.Clear();
			ReadRoles.Add().Role = "FullRights";
			ReadRoles.Add().Role = "SystemAdministrator";
		Else
			ReadRoles.Clear();
			ReadRoles.Add().Role = "FullRights";
		EndIf;
	EndIf;
	
	ProcessRolesInterface("RefreshRoleTree");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form",            ThisObject);
	ActionParameters.Insert("RolesCollection",   ReadRoles);
	
	If TypeOf(Parameters.User) = Type("CatalogRef.Users")
	   AND Users.IsFullUser(Parameters.User, False, False) Then
		
		RolesAssignment = "ForAdministrators";
		
	ElsIf TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers")
	      Or TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsersGroups") Then
		
		RolesAssignment = "ForExternalUsers";
	Else
		RolesAssignment = "ForUsers";
	EndIf;
	
	ActionParameters.Insert("RolesAssignment", RolesAssignment);
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

#EndRegion
