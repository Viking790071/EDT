	
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Object.Ref = Catalogs.UserGroups.EmptyRef()
	   AND Object.Parent = Catalogs.UserGroups.AllUsers Then
		
		Object.Parent = Catalogs.UserGroups.EmptyRef();
	EndIf;
	
	If Object.Ref = Catalogs.UserGroups.AllUsers Then
		ReadOnly = True;
	EndIf;
	
	FillUserStatuses();
	
	UpdateInvalidUsersList(True);
	SetPropertiesAvailability(ThisObject);
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillUserStatuses();
	
	UsersInternal.AfterChangeUserOrUserGroupInForm();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_UserGroups", New Structure, Object.Ref);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ParentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("SelectParent");
	
	OpenForm("Catalog.UserGroups.ChoiceForm", FormParameters, Items.Parent);
	
EndProcedure

#EndRegion

#Region CompositionFormTableItemsEventHandlers

&AtClient
Procedure CompositionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Object.Content.Clear();
	If TypeOf(ValueSelected) = Type("Array") Then
		For each Value In ValueSelected Do
			UserChoiceProcessing(Value);
		EndDo;
	Else
		UserChoiceProcessing(ValueSelected);
	EndIf;
	FillUserStatuses();
	Items.Content.Refresh();
	SetPropertiesAvailability(ThisObject);
	
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

&AtClient
Procedure CompositionOnChange(Item)
	SetPropertiesAvailability(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PickUsers(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CloseOnChoice", False);
	FormParameters.Insert("MultipleChoice", True);
	FormParameters.Insert("AdvancedPick", True);
	FormParameters.Insert("ExtendedPickFormParameters", ExtendedPickFormParameters());
	
	OpenForm("Catalog.Users.ChoiceForm", FormParameters, Items.Content);

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

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure SetPropertiesAvailability(Form)
	
	Items = Form.Items;
	
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
	
	Items.CompositionMoveUp.Enabled         = MoveCommandsAvailability;
	Items.CompositionMoveDown.Enabled          = MoveCommandsAvailability;
	Items.CompositionContextMenuMoveUp.Enabled = MoveCommandsAvailability;
	Items.CompositionContextMenuMoveDown.Enabled  = MoveCommandsAvailability;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.User.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Content.Invalid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtClient
Procedure UserChoiceProcessing(SelectedValue)
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Users") Then
		Object.Content.Add().User = SelectedValue;
	EndIf;
	
EndProcedure

&AtServer
Function MoveUserToGroup(UsersArray, NewParentGroup)
	
	MovedUsersArray = New Array;
	UnmovedUsersArray = New Array;
	For Each UserRef In UsersArray Do
		
		FilterParameters = New Structure("User", UserRef);
		If TypeOf(UserRef) = Type("CatalogRef.Users")
			AND Object.Content.FindRows(FilterParameters).Count() = 0 Then
			Object.Content.Add().User = UserRef;
			MovedUsersArray.Add(UserRef);
		EndIf;
		
	EndDo;
	
	Return UsersInternal.CreateUserMessage(
		MovedUsersArray, NewParentGroup, False, UnmovedUsersArray);
	
EndFunction

&AtServer
Function ExtendedPickFormParameters()
	
	SelectedUsers = New ValueTable;
	SelectedUsers.Columns.Add("User");
	SelectedUsers.Columns.Add("PictureNumber");
	
	GroupMembers = Object.Content.Unload(, "User");
	
	For each Item In GroupMembers Do
		
		SelectedUsersRow = SelectedUsers.Add();
		SelectedUsersRow.User = Item.User;
		
	EndDo;
	
	PickFormHeader = NStr("ru = 'Подбор участников группы пользователей'; en = 'Select group members'; pl = 'Wybierz uczestników grupy użytkowników';es_ES = 'Seleccionar participantes del grupo de usuarios';es_CO = 'Seleccionar participantes del grupo de usuarios';tr = 'Kullanıcı grubun katılımcılarını seçin';it = 'Seleziona i membri del gruppo.';de = 'Wählen Sie Teilnehmer der Benutzergruppe aus'");
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
			Common.ObjectAttributeValue(GroupCompositionRow.User, "Invalid");
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
	
	Items.Content.Refresh();
	
EndProcedure

&AtServer
Procedure CompositionSortRows(SortType)
	
	If Not Items.ShowInvalidUsers.Check Then
		Items.Content.RowFilter = New FixedStructure();
	EndIf;
	
	If SortType = "Ascending" Then
		Object.Content.Sort("User Asc");
	Else
		Object.Content.Sort("User Desc");
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

#EndRegion
