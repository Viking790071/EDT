
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	UserType = TypeOf(Parameters.User);
	
	If UserType = Type("CatalogRef.ExternalUsers") Then
		AllUsersGroup = Catalogs.ExternalUsersGroups.AllExternalUsers;
	Else
		AllUsersGroup = Catalogs.UserGroups.AllUsers;
	EndIf;
	
	WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	UseGroups = GetFunctionalOption("UseUserGroups");
	SourceUser = Parameters.User;
	FillUserList(UserType, UseGroups);
	
	CopyAll   = (Parameters.ActionType = "CopyAll");
	SettingsClearing = (Parameters.ActionType = "Clearing");
	If SettingsClearing Then
		Title =
			NStr("ru = 'Выбор пользователей для очистки настроек'; en = 'Select users to clear settings'; pl = 'Wybierz użytkowników, aby oczyścić ustawienia';es_ES = 'Seleccionar usuario para eliminar las configuraciones';es_CO = 'Seleccionar usuario para eliminar las configuraciones';tr = 'Ayarları temizlemek için kullanıcıları seçin';it = 'Selezione utenti per cancellare le impostazioni';de = 'Wählen Sie die Benutzer aus, um die Einstellungen zu löschen'");
		Items.Label.Title =
			NStr("ru = 'Выберите пользователей, которым необходимо очистить настройки'; en = 'Select the users whose settings you want to clear:'; pl = 'Wybierz użytkowników, dla których należy oczyścić ustawienia';es_ES = 'Seleccionar usuarios para los cuales se requiere eliminar las configuraciones';es_CO = 'Seleccionar usuarios para los cuales se requiere eliminar las configuraciones';tr = 'Ayarları temizlemek için kimlerin gerekli olduğunu seçin';it = 'Seleziona gli utenti le cui impostazioni volete cancellare:';de = 'Wählen Sie Benutzer aus, für die Einstellungen gelöscht werden müssen'");
	EndIf;
	
	If Parameters.Property("SelectedUsers") Then
		AddCheckMarksToPassedUsers = True;
		
		If Parameters.SelectedUsers <> Undefined Then
			
			For Each SelectedUser In Parameters.SelectedUsers Do
				MarkUser(SelectedUser);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	Settings.Delete("AllUsersList");
	
	// If the form is opened from the "Clear application user settings" form or from the "Copy application user settings" form, do not save the settings.
	If AddCheckMarksToPassedUsers Then
		Return;
	EndIf;
	
	FilterParameters = New Structure("Check", True);
	MarkedUsersList = New ValueList;
	MarkedUsersArray = AllUsersList.FindRows(FilterParameters);
	
	For Each ArrayRow In MarkedUsersArray Do
		MarkedUsersList.Add(ArrayRow.User);
	EndDo;
	
	Settings.Insert("MarkedUsers", MarkedUsersList);
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	// If the form is opened from the "Application user settings clearing" form or from the "Application user settings copying" form, do not load the settings
	If AddCheckMarksToPassedUsers Then
		Settings.Delete("AllUsersList");
		Settings.Delete("MarkedUsers");
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	MarkedUsers = Settings.Get("MarkedUsers");
	
	If MarkedUsers = Undefined Then
		Return;
	EndIf;
	
	For Each MarkedUserRow In MarkedUsers Do
		
		UserRef = MarkedUserRow.Value;
		MarkUser(UserRef);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateGroupTitlesOnToggleCheckBox();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	SelectedGroup = Item.CurrentData;
	If SelectedGroup = Undefined Then
		Return;
	EndIf;
	
	ApplyGroupFilter(SelectedGroup);
	If UseGroups Then
		Items.ShowUsersFromSubgroupsGroup.CurrentPage = Items.SetPropertyGroup;
	Else
		Items.ShowUsersFromSubgroupsGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure UserListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Item.CurrentData.User);
	
EndProcedure

&AtClient
Procedure UserGroupsSelection(Item, RowSelected, Field, StandardProcessing)
	
	ShowValue(,Item.CurrentData.Group);
	
EndProcedure

&AtClient
Procedure ShowNestedGroupUsersOnChange(Item)
	
	SelectedUserGroup = Items.UserGroups.CurrentData;
	ApplyGroupFilter(SelectedUserGroup);
	
	// Updating group titles.
	ClearGroupTitles();
	UpdateGroupTitlesOnToggleCheckBox();
	
EndProcedure

&AtClient
Procedure UsersCheckBoxOnChange(Item)
	
	UserListRow = Item.Parent.Parent.CurrentData;
	UserListRow.Check = Not UserListRow.Check;
	ChangeMark(UserListRow, Not UserListRow.Check);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	UsersDestination = New Array;
	For Each Item In UsersList Do
		
		If Item.Check Then
			UsersDestination.Add(Item.User);
		EndIf;
		
	EndDo;
	
	If UsersDestination.Count() = 0 Then
		ShowMessageBox(,NStr("ru = 'Необходимо отметить одного или несколько пользователей.'; en = 'Please select one or several users.'; pl = 'Zaznacz jednego lub wielu użytkowników.';es_ES = 'Marcar uno o usuarios múltiples.';es_CO = 'Marcar uno o usuarios múltiples.';tr = 'Bir veya birden çok kullanıcıyı işaretleyin.';it = 'Per piacere selezionare uno o più utenti.';de = 'Markieren Sie einen oder mehrere Benutzer.'"));
		Return;
	EndIf;
	
	Result = New Structure("UsersDestination, CopyAll, SettingsClearing", 
		UsersDestination, CopyAll, SettingsClearing);
	Notify("UserSelection", Result);
	Close();
	
EndProcedure

&AtClient
Procedure SelectAll(Command)
	
	For Each UserListRow In UsersList Do
		ChangeMark(UserListRow, True);
	EndDo;
	
EndProcedure

&AtClient
Procedure AddCheckMarksToSelectedUsers(Command)
	
	SelectedItems = Items.UsersList.SelectedRows;
	
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Item In SelectedItems Do
		UserListRow = UsersList.FindByID(Item);
		ChangeMark(UserListRow, True);
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearAll(Command)
	
	For Each UserListRow In UsersList Do
		ChangeMark(UserListRow, False);
	EndDo;
EndProcedure

&AtClient
Procedure RemoveCheckMarksFromSelectedUsers(Command)
	
	SelectedItems = Items.UsersList.SelectedRows;
	
	If SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Item In SelectedItems Do
		UserListRow = UsersList.FindByID(Item);
		ChangeMark(UserListRow, False);
	EndDo;
	
EndProcedure

&AtClient
Procedure ModifyUserOrGroup(Command)
	
	CurrentValue = CurrentItem.CurrentData;
	
	If TypeOf(CurrentValue) = Type("FormDataCollectionItem") Then
		
		ShowValue(,CurrentValue.User);
		
	ElsIf TypeOf(CurrentValue) = Type("FormDataTreeItem") Then
		
		ShowValue(,CurrentValue.Group);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActiveUsers(Command)
	
	StandardSubsystemsClient.OpenActiveUserList();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersGroupsGroup.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UserGroups.MarkedUsersCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", New Font("Arial", 10, True));
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("UserGroups.GroupDescriptionAndUserMarkCount"));

EndProcedure

&AtServer
Procedure MarkUser(UserRef)
	
	For Each AllUsersListRow In AllUsersList Do
		
		If AllUsersListRow.User = UserRef Then
			AllUsersListRow.Check = True;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateGroupTitlesOnToggleCheckBox()
	
	For Each UsersGroup In UserGroups.GetItems() Do
		
		For Each UserListRow In AllUsersList Do
			
			If UserListRow.Check Then
				MarkValue = True;
				UserListRow.Check = False;
				UpdateGroupTitle(ThisObject, UsersGroup, UserListRow, MarkValue);
				UserListRow.Check = True;
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearGroupTitles()
	
	For Each UsersGroup In UserGroups.GetItems() Do
		ClearGroupTitle(UsersGroup);
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearGroupTitle(UsersGroup)
	
	UsersGroup.MarkedUsersCount = 0;
	SubordinateGroups = UsersGroup.GetItems();
	
	For Each SubordinateGroup In SubordinateGroups Do
	
		ClearGroupTitle(SubordinateGroup);
	
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeMark(UserListRow, MarkValue)
	
	If UseGroups Then
		
		UpdateGroupTitles(ThisObject, UserListRow, MarkValue);
		
		UserListRow.Check = MarkValue;
		Filter = New Structure("User", UserListRow.User); 
		FoundUsers = AllUsersList.FindRows(Filter);
		For Each FoundUser In FoundUsers Do
			FoundUser.Check = MarkValue;
		EndDo;
	Else
		UserListRow.Check = MarkValue;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateGroupTitles(Form, UserListRow, MarkValue)
	
	For Each UsersGroup In Form.UserGroups.GetItems() Do
		
		UpdateGroupTitle(Form, UsersGroup, UserListRow, MarkValue);
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateGroupTitle(Form, UsersGroup, UserListRow, MarkValue)
	
	UserRef = UserListRow.User;
	If Form.ShowUsersFromSubgroups 
		Or Form.AllUsersGroup = UsersGroup.Group Then
		Composition = UsersGroup.FullComposition;
	Else
		Composition = UsersGroup.Content;
	EndIf;
	MarkedUser = Composition.FindByValue(UserRef);
	
	If MarkedUser <> Undefined AND MarkValue <> UserListRow.Check Then
		MarkedUsersCount = UsersGroup.MarkedUsersCount;
		UsersGroup.MarkedUsersCount = ?(MarkValue, MarkedUsersCount + 1, MarkedUsersCount - 1);
		UsersGroup.GroupDescriptionAndUserMarkCount = 
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='%1 (%2)'; en = '%1 (%2)'; pl = '%1 (%2)';es_ES = '%1 (%2)';es_CO = '%1 (%2)';tr = '%1 (%2)';it = '%1 (%2)';de = '%1 (%2)'"), String(UsersGroup.Group), UsersGroup.MarkedUsersCount);
	EndIf;
	
	// Update the titles of all subgroups recursively.
	SubordinateGroups = UsersGroup.GetItems();
	For Each SubordinateGroup In SubordinateGroups Do
		UpdateGroupTitle(Form, SubordinateGroup, UserListRow, MarkValue);
	EndDo;
	
EndProcedure

&AtClient
Procedure ApplyGroupFilter(CurrentGroup)
	
	UsersList.Clear();
	If CurrentGroup = Undefined Then
		Return;
	EndIf;
	
	If ShowUsersFromSubgroups Then
		GroupComposition = CurrentGroup.FullComposition;
	Else
		GroupComposition = CurrentGroup.Content;
	EndIf;
	For Each Item In AllUsersList Do
		
		If GroupComposition.FindByValue(Item.User) <> Undefined
			Or AllUsersGroup = CurrentGroup.Group Then
			UserListLine = UsersList.Add();
			UserListLine.User = Item.User;
			UserListLine.Check = Item.Check;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillUserList(UserType, UseGroups);
	
	GroupsTree = FormAttributeToValue("UserGroups");
	AllUsersListTable = FormAttributeToValue("AllUsersList");
	UserListTable = FormAttributeToValue("UsersList");
	
	If UserType = Type("CatalogRef.ExternalUsers") Then
		ExternalUser = True;
	Else
		ExternalUser = False;
	EndIf;
	
	If UseGroups Then
		DataProcessors.UsersSettings.FillGroupTree(GroupsTree, ExternalUser);
		AllUsersListTable = DataProcessors.UsersSettings.UsersToCopy(
			SourceUser, AllUsersListTable, ExternalUser);
	Else
		UserListTable = DataProcessors.UsersSettings.UsersToCopy(
			SourceUser, UserListTable, ExternalUser);
	EndIf;
	
	GroupsTree.Rows.Sort("Group Asc");
	RowToMove = GroupsTree.Rows.Find(AllUsersGroup, "Group");
	
	If RowToMove <> Undefined Then
		RowIndex = GroupsTree.Rows.IndexOf(RowToMove);
		GroupsTree.Rows.Move(RowIndex, -RowIndex);
	EndIf;
	
	ValueToFormAttribute(GroupsTree, "UserGroups");
	ValueToFormAttribute(UserListTable, "UsersList");
	ValueToFormAttribute(AllUsersListTable, "AllUsersList");
	
EndProcedure

#EndRegion
