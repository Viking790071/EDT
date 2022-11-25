
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT ValueIsFilled(Object.Ref) Then
		ProcessRolesInterface("FillRoles", Object.Roles);
		ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", False);
	EndIf;
	
	// Preparing auxiliary data.
	
	If Not ValueIsFilled(Object.Ref) Then
		AllAuthorizationObjects = Common.ObjectAttributeValue(Object.Parent,
			"AllAuthorizationObjects");
		AllAuthorizationObjects = ?(AllAuthorizationObjects = Undefined, False, AllAuthorizationObjects);
		
		If AllAuthorizationObjects
		 Or Object.Parent = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			Object.Parent = Catalogs.ExternalUsersGroups.EmptyRef();
		EndIf;
		
	EndIf;
	
	SelectGroupMembersTypesAvailableForSelection();
	
	DefineActionsInForm();
	
	// Making the properties always visible.
	
	Items.Description.Visible     = ValueIsFilled(FormActions.ItemProperties);
	Items.Parent.Visible         = ValueIsFilled(FormActions.ItemProperties);
	Items.Comment.Visible      = ValueIsFilled(FormActions.ItemProperties);
	Items.Content.Visible           = ValueIsFilled(FormActions.GroupComposition);
	Items.RolesRepresentation.Visible = ValueIsFilled(FormActions.Roles);
	
	GroupMembers = ?(Object.AllAuthorizationObjects, "AllUsersOfSpecifiedTypes", "SelectedUsersOfSpecifiedTypes");
	
	IsAllExternalUsersGroup = 
		Object.Ref = Catalogs.ExternalUsersGroups.AllExternalUsers;
	
	If IsAllExternalUsersGroup Then
		Items.Description.ReadOnly = True;
		Items.Parent.ReadOnly     = True;
		Items.Comment.ReadOnly  = True;
		Items.ExternalUsersInGroup.ReadOnly = True;
	EndIf;
	
	If ReadOnly
	 OR NOT IsAllExternalUsersGroup
	     AND FormActions.Roles             <> "Edit"
	     AND FormActions.GroupComposition     <> "Edit"
	     AND FormActions.ItemProperties <> "Edit"
	 OR IsAllExternalUsersGroup
	   AND UsersInternal.CannotEditRoles() Then
		
		ReadOnly = True;
	EndIf;
	
	If FormActions.ItemProperties <> "Edit" Then
		Items.Description.ReadOnly = True;
		Items.Parent.ReadOnly     = True;
		Items.Comment.ReadOnly  = True;
	EndIf;
	
	If FormActions.GroupComposition <> "Edit" Then
		Items.ExternalUsersInGroup.ReadOnly = True;
	EndIf;
	
	ProcessRolesInterface(
		"SetRolesReadOnly",
		    UsersInternal.CannotEditRoles()
		OR FormActions.Roles <> "Edit");
	
	UpdateInvalidUsersList(True);
	FillUserStatuses();
	
	If ValueIsFilled(Object.Parent) AND FormAttributeToValue("Object").IsNew()  Then
		Object.Purpose.Load(Object.Parent.Purpose.Unload());
	EndIf;
	UsersInternal.UpdateAssignmentOnCreateAtServer(ThisObject, False);
	
	SetPropertiesAvailability(ThisObject);
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetUpRoleInterfaceOnReadAtServer", True);
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Filling object roles from the collection.
	CurrentObject.Roles.Clear();
	For each Row In RolesCollection Do
		CurrentObject.Roles.Add().Role = Common.MetadataObjectID(
			"Role." + Row.Role);
	EndDo;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillUserStatuses();
	
	UsersInternal.AfterChangeUserOrUserGroupInForm();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ExternalUserGroups", New Structure, Object.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	AttributesNotToCheck = New Array;
	VerifiedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking whether the metadata contains roles.
	VerifiedObjectAttributes.Add("Roles.Role");
	If Not Items.Roles.ReadOnly Then
		TreeItems = Roles.GetItems();
		For Each Row In TreeItems Do
			If Not Row.Check Then
				Continue;
			EndIf;
			If Row.IsNonExistingRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" не найдена в метаданных.'; en = 'Role ""%1"" is not found in the metadata.'; pl = 'Rola ""%1"" nie została znaleziona w metadanych.';es_ES = 'Rol ""%1"" no se ha encontrado en los metadatos.';es_CO = 'Rol ""%1"" no se ha encontrado en los metadatos.';tr = '""%1"" rolü meta veride bulunamadı.';it = 'Il ruolo ""%1"" non è stato trovato nei metadata.';de = 'Die Rolle ""%1"" wurde in den Metadaten nicht gefunden.'"), Row.Synonym),
					"Roles",
					TreeItems.IndexOf(Row),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" в строке %%1 не найдена в метаданных.'; en = 'Role ""%1"" in line #%%1 is not found in the metadata.'; pl = 'Rola ""%1"" w wierszu %%1 nie została znaleziona w metadanych.';es_ES = 'El rol ""%1"" en la línea %%1 no se ha encontrado en los metadatos.';es_CO = 'El rol ""%1"" en la línea %%1 no se ha encontrado en los metadatos.';tr = '%%1 Satırdaki rol %1 meta veride bulunamadı.';it = 'Il ruolo ""%1"" nella linea #%%1 non è stato trovato nei metadati.';de = 'Die Rolle ""%1"" in der %%1-Zeile wurde in den Metadaten nicht gefunden.'"), Row.Synonym));
			EndIf;
			If Row.IsUnavailableRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" недоступна для внешних пользователей.'; en = 'Role ""%1"" is unavailable to external users.'; pl = 'Rola ""%1"" nie jest dostępna dla użytkowników zewnętrznych.';es_ES = 'El rol ""%1"" no está disponible para los usuarios externos.';es_CO = 'El rol ""%1"" no está disponible para los usuarios externos.';tr = '""%1"" rolü harici kullanıcılar için kullanılamaz.';it = 'Il ruolo""%1"" non è disponibile per gli utenti esterni.';de = 'Die Rolle ""%1"" ist für externe Benutzer nicht verfügbar.'"), Row.Synonym),
					"Roles",
					TreeItems.IndexOf(Row),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" в строке %%1 недоступна для внешних пользователей.'; en = 'Role ""%1"" in line #%%1 is unavailable to external users.'; pl = 'Rola ""%1"" w wierszu %%1 nie jest dostępna dla użytkowników zewnętrznych.';es_ES = 'El rol ""%1"" en la línea %%1 no está disponible para los usuarios externos.';es_CO = 'El rol ""%1"" en la línea %%1 no está disponible para los usuarios externos.';tr = '%%1 satırındaki rol ""%1"" harici kullanıcılar için kullanılamaz.';it = 'Il ruolo ""%1"" nella linea #%%1 non è disponibile per gli utenti esterni.';de = 'Die Rolle ""%1"" in der Zeile %%1 ist für externe Benutzer nicht verfügbar.'"), Row.Synonym));
			EndIf;
		EndDo;
	EndIf;
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	AttributesNotToCheck.Add("Object");
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesNotToCheck);
	
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert(
		"VerifiedObjectAttributes", VerifiedObjectAttributes);
	
	If NOT CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MembersListOnChange(Item)
	
	Object.AllAuthorizationObjects = (GroupMembers = "AllUsersOfSpecifiedTypes");
	If Object.AllAuthorizationObjects Then
		Object.Content.Clear();
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure ParentOnChange(Item)
	
	Object.AllAuthorizationObjects = False;
	SelectGroupMembersTypesAvailableForSelection();
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("SelectParent");
	
	OpenForm("Catalog.ExternalUsersGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

#EndRegion

#Region RolesFormTableItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		ProcessRolesInterface("UpdateRoleComposition");
	EndIf;
	
EndProcedure

#EndRegion

#Region CompositionFormTableItemsEventHandlers

&AtClient
Procedure CompositionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Object.Content.Clear();
	If TypeOf(ValueSelected) = Type("Array") Then
		For each Value In ValueSelected Do
			ProcessExternalUserSelection(Value);
		EndDo;
	Else
		ProcessExternalUserSelection(ValueSelected);
	EndIf;
	FillUserStatuses();
	Items.Content.Refresh();
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure CompositionOnChange(Item)
	SetPropertiesAvailability(ThisObject);
EndProcedure

&AtClient
Procedure CompositionExternalUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectPickUsers(False);
	
EndProcedure

&AtClient
Procedure CompositionDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	UserMessage = MoveUserToGroup(DragParameters.Value, Object.Ref);
	If UserMessage <> Undefined Then
		ShowUserNotification(
			NStr("ru = 'Перемещение пользователей'; en = 'Move users'; pl = 'Przenieś użytkowników';es_ES = 'Mover a los usuarios';es_CO = 'Mover a los usuarios';tr = 'Kullanıcıları taşıyın';it = 'Spostare gli utenti';de = 'Verschieben Sie Benutzer'"), , UserMessage, PictureLib.Information32);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PickExternalUsers(Command)

	SelectPickUsers(True);
	
EndProcedure

&AtClient
Procedure ShowInvalidUsers(Command)
	
	UpdateInvalidUsersList(False);
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure SortAsc(Command)
	CompositionSortRows("Ascending");
EndProcedure

&AtClient
Procedure SortDesc(Command)
	CompositionSortRows("Descending");
EndProcedure

&AtClient
Procedure MoveUp(Command)
	CompositionMoveRow("Up");
EndProcedure

&AtClient
Procedure MoveDown(Command)
	CompositionMoveRow("Down");
EndProcedure

&AtClient
Procedure SelectPurpose(Command)
	
	NotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject);
	UsersInternalClient.SelectPurpose(ThisObject, NStr("ru = 'Выбор типа пользователей'; en = 'Select users type'; pl = 'Wybierz typ użytkowników';es_ES = 'Selección del tipo de usuario';es_CO = 'Selección del tipo de usuario';tr = 'Kullanıcı türünün seçimi';it = 'Seleziona tipo utenti';de = 'Auswahl des Benutzertyps'"), False, False, NotifyDescription);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure ShowSelectedRolesOnly(Command)
	
	ProcessRolesInterface("SelectedRolesOnly");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure RolesBySubsystemsGroup(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure AddRoles(Command)
	
	ProcessRolesInterface("UpdateRoleComposition", "EnableAll");
	
	UsersInternalClient.ExpandRoleSubsystems(ThisObject, False);
	
EndProcedure

&AtClient
Procedure RemoveRoles(Command)
	
	ProcessRolesInterface("UpdateRoleComposition", "DisableAll");
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CompositionExternalUser.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Content.Invalid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtServer
Function MoveUserToGroup(UsersArray, NewParentGroup)
	
	MovedUsersArray = New Array;
	UnmovedUsersArray = New Array;
	For Each UserRef In UsersArray Do
		
		FilterParameters = New Structure("ExternalUser", UserRef);
		If TypeOf(UserRef) = Type("CatalogRef.ExternalUsers")
			AND Object.Content.FindRows(FilterParameters).Count() = 0 Then
			Object.Content.Add().ExternalUser = UserRef;
			MovedUsersArray.Add(UserRef);
		EndIf;
		
	EndDo;
	
	Return UsersInternal.CreateUserMessage(
		MovedUsersArray, NewParentGroup, False, UnmovedUsersArray);
	
EndFunction

&AtServer
Procedure SelectGroupMembersTypesAvailableForSelection()
	
	If ValueIsFilled(Object.Parent)
		AND Object.Parent <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
		
		Items.UsersType.Enabled = False;
		GroupMembers = Items.GroupMembers.ChoiceList.FindByValue("SelectedUsersOfSpecifiedTypes").Value;
		
	Else
		
		Items.UsersType.Enabled = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineActionsInForm()
	
	FormActions = New Structure;
	
	// "", "View," "Edit."
	FormActions.Insert("Roles", "");
	
	// "", "View," "Edit."
	FormActions.Insert("GroupComposition", "");
	
	// "", "View," "Edit."
	FormActions.Insert("ItemProperties", "");
	
	If Users.IsFullUser()
	 OR AccessRight("Insert", Metadata.Catalogs.Users) Then
		// Administrator.
		FormActions.Roles             = "Edit";
		FormActions.GroupComposition     = "Edit";
		FormActions.ItemProperties = "Edit";
		
	ElsIf AccessRight("Edit", Metadata.Catalogs.ExternalUsersGroups) Then
		// Can manage external users.
		FormActions.Roles             = "";
		FormActions.GroupComposition     = "Edit";
		FormActions.ItemProperties = "Edit";
		
	Else
		// Can read external users.
		FormActions.Roles             = "";
		FormActions.GroupComposition     = "View";
		FormActions.ItemProperties = "View";
	EndIf;
	
	UsersInternal.OnDefineActionsInForm(Object.Ref, FormActions);
	
	// Checking action names in the form.
	If StrFind(", View, Edit,", ", " + FormActions.Roles + ",") = 0 Then
		FormActions.Roles = "";
	ElsIf UsersInternal.CannotEditRoles() Then
		FormActions.Roles = "";
	EndIf;
	If StrFind(", View, Edit,", ", " + FormActions.GroupComposition + ",") = 0 Then
		FormActions.IBUserProperies = "";
	EndIf;
	If StrFind(", View, Edit,", ", " + FormActions.ItemProperties + ",") = 0 Then
		FormActions.ItemProperties = "";
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetPropertiesAvailability(Form)
	
	Items = Form.Items;
	
	Items.Content.ReadOnly = Form.Object.AllAuthorizationObjects;
	
	CommandsAvailability =
		NOT Form.ReadOnly
		AND NOT Items.ExternalUsersInGroup.ReadOnly
		AND NOT Items.Content.ReadOnly
		AND Items.Content.Enabled
		AND Form.Object.Purpose.Count() <> 0;
	
	GroupComposition = Form.Object.Content;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Invalid", False);
	HasValidUsers = GroupComposition.FindRows(FilterParameters).Count() > 0;
	
	FilterParameters.Insert("Invalid", True);
	HasInvalidUsers = GroupComposition.FindRows(FilterParameters).Count() > 0;
	
	MoveCommandsAvailability =
		HasValidUsers
		Or (HasInvalidUsers
			AND Items.ShowInvalidUsers.Check);
	
	Items.Content.ReadOnly		                = Not CommandsAvailability;
	
	Items.CompositionPick.Enabled                = CommandsAvailability;
	Items.CompositionContextMenuPick.Enabled = CommandsAvailability;
	
	Items.CompositionSortAsc.Enabled = CommandsAvailability;
	Items.CompositionSortDesc.Enabled    = CommandsAvailability;
	
	Items.CompositionMoveUp.Enabled         = CommandsAvailability AND MoveCommandsAvailability;
	Items.CompositionMoveDown.Enabled          = CommandsAvailability AND MoveCommandsAvailability;
	Items.CompositionContextMenuMoveUp.Enabled = CommandsAvailability AND MoveCommandsAvailability;
	Items.CompositionContextMenuMoveDown.Enabled  = CommandsAvailability AND MoveCommandsAvailability;
	
EndProcedure

&AtServer
Procedure DeleteNontypicalExternalUsers()
	
	Query = New Query;
	Query.SetParameter("SelectedExternalUsers", Object.Content.Unload().UnloadColumn("ExternalUser"));
	Query.SetParameter("UsersTypes", Object.Purpose.Unload());
	
	Query.Text =
	"SELECT
	|	UsersTypes.UsersType
	|INTO UsersTypes
	|FROM
	|	&UsersTypes AS UsersTypes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	NOT FALSE IN
	|			(SELECT TOP 1
	|				FALSE
	|			FROM
	|				UsersTypes AS UsersTypes
	|			WHERE
	|				VALUETYPE(UsersTypes.UsersType) = VALUETYPE(ExternalUsers.AuthorizationObject))
	|	AND ExternalUsers.Ref IN(&SelectedExternalUsers)";
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			FoundRows = Object.Content.FindRows(
				New Structure("ExternalUser", Selection.Ref));
			
			For each FoundRow In FoundRows Do
				Object.Content.Delete(Object.Content.IndexOf(FoundRow));
			EndDo;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure SelectPickUsers(Select)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(
		Items.Content.CurrentData = Undefined,
		Undefined,
		Items.Content.CurrentData.ExternalUser));
	
	If Select Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("MultipleChoice", True);
		FormParameters.Insert("AdvancedPick", True);
		FormParameters.Insert("ExtendedPickFormParameters", ExtendedPickFormParameters());
	EndIf;
	
	BlankRefsArray = New Array;
	For Each AssignmentRow In Object.Purpose Do
		BlankRefsArray.Add(AssignmentRow.UsersType);
	EndDo;
	
	FormParameters.Insert("Purpose", BlankRefsArray);
	
	OpenForm(
		"Catalog.ExternalUsers.ChoiceForm",
		FormParameters,
		?(Select,
			Items.Content,
			Items.CompositionExternalUser));
	
EndProcedure

&AtClient
Procedure ProcessExternalUserSelection(SelectedValue)
	
	If TypeOf(SelectedValue) = Type("CatalogRef.ExternalUsers") Then
		Object.Content.Add().ExternalUser = SelectedValue;
	EndIf;
	
EndProcedure

&AtServer
Function ExtendedPickFormParameters()
	
	SelectedUsers = New ValueTable;
	SelectedUsers.Columns.Add("User");
	SelectedUsers.Columns.Add("PictureNumber");
	
	ExternalUsersGroupMembers = Object.Content.Unload(, "ExternalUser");
	
	For each Item In ExternalUsersGroupMembers Do
		
		SelectedUsersRow = SelectedUsers.Add();
		SelectedUsersRow.User = Item.ExternalUser;
		
	EndDo;
	
	PickFormHeader = NStr("ru = 'Подбор участников группы внешних пользователей'; en = 'Select external user group members'; pl = 'Wybierz uczestników zewnętrznej grupy użytkowników';es_ES = 'Seleccionar participantes del grupo de usuarios externos';es_CO = 'Seleccionar participantes del grupo de usuarios externos';tr = 'Harici kullanıcı grubunun üyelerini seçin';it = 'Selezione dei membri dei gruppi degli utenti esterni';de = 'Wählen Sie Teilnehmer der externen Benutzergruppe'");
	ExtendedPickFormParameters = 
		New Structure("PickFormHeader, SelectedUsers, CannotPickGroups",
		                 PickFormHeader, SelectedUsers, True);
	StorageAddress = PutToTempStorage(ExtendedPickFormParameters);
	Return StorageAddress;
	
EndFunction

&AtServer
Procedure FillUserStatuses()
	
	For Each GroupCompositionRow In Object.Content Do
		GroupCompositionRow.Invalid = 
			Common.ObjectAttributeValue(GroupCompositionRow.ExternalUser, "Invalid");
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateInvalidUsersList(BeforeOpenForm)
	
	Items.ShowInvalidUsers.Check = ?(BeforeOpenForm, False,
		NOT Items.ShowInvalidUsers.Check);
	
	Filter = New Structure;
	
	If Not Items.ShowInvalidUsers.Check Then
		Filter.Insert("Invalid", False);
		Items.Content.RowFilter = New FixedStructure(Filter);
	Else
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
EndProcedure

&AtServer
Procedure CompositionSortRows(SortType)
	If Not Items.ShowInvalidUsers.Check Then
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
	If SortType = "Ascending" Then
		Object.Content.Sort("ExternalUser Asc");
	Else
		Object.Content.Sort("ExternalUser Desc");
	EndIf;
	
	If Not Items.ShowInvalidUsers.Check Then
		Filter = New Structure;
		Filter.Insert("Invalid", False);
		Items.Content.RowFilter = New FixedStructure(Filter);
	EndIf;
EndProcedure

&AtServer
Procedure CompositionMoveRow(MovementDirection)
	
	Row = Object.Content.FindByID(Items.Content.CurrentRow);
	If Row = Undefined Then
		Return;
	EndIf;
	
	CurrentRowIndex = Row.LineNumber - 1;
	Offset = 0;
	
	While True Do
		Offset = Offset + ?(MovementDirection = "Up", -1, 1);
		
		If CurrentRowIndex + Offset < 0
		Or CurrentRowIndex + Offset >= Object.Content.Count() Then
			Return;
		EndIf;
		
		If Items.ShowInvalidUsers.Check
		 Or Object.Content[CurrentRowIndex + Offset].Invalid = False Then
			Break;
		EndIf;
	EndDo;
	
	Object.Content.Move(CurrentRowIndex, Offset);
	Items.Content.Refresh();
	
EndProcedure

&AtClient
Procedure AfterAssignmentChoice(TypesArray, AdditionalParameters) Export
	
	Modified = True;
	DeleteNontypicalExternalUsers();
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form",            ThisObject);
	ActionParameters.Insert("RolesCollection",   RolesCollection);
	ActionParameters.Insert("RolesAssignment",  "ForExternalUsers");
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

#EndRegion
