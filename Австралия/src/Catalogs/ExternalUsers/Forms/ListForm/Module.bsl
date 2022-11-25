////////////////////////////////////////////////////////////////////////////////
//                          HOW TO USE THE FORM                               //
//
// Additional form opening parameters:
//
// ExtendedPick - Boolean - if True, open the extended form for picking users.
//   The extended form requires the
//  ExtendedPickFormParameters parameter.
// ExtendedPickFormParameters - String - reference to a structure that contains extended parameters 
//  for the form used for picking users. The structure is located in a temporary storage.
//  
//  Structure parameters:
//    PickFormTitle - String - the title of the form for picking users.
//    SelectedUsers - Array - an array of previously selected users.
//

#Region Variables

&AtClient
Var LastItem;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	// The initial setting value (before loading data from the settings).
	SelectHierarchy = True;
	
	FillStoredParameters();
	
	BlankRefsArray = Undefined;
	Parameters.Property("Purpose", BlankRefsArray);
	FillDynamicListParameters(BlankRefsArray);
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
	ElsIf Users.IsFullUser() Then
		// Adding the filter by users added by the person responsible for the list.
		CommonClientServer.SetDynamicListFilterItem(
			ExternalUsersList, "Prepared", True, ,
			NStr("ru = 'Подготовленные ответственным за список'; en = 'Prepared by person responsible for the list'; pl = 'Przygotowane przez osobę odpowiedzialną za listę';es_ES = 'Preparado por el responsable de la lista';es_CO = 'Preparado por el responsable de la lista';tr = 'Liste sorumlusu tarafından hazırlananlar';it = 'Preparato dalla persona responsabile per l''elenco';de = 'Erstellt durch den Verantwortlichen der Liste'"), False,
			DataCompositionSettingsItemViewMode.Normal);
	EndIf;
	
	// If the parameter value is True, hiding users with empty IDs.
	If Parameters.HideUsersWithoutMatchingIBUsers Then
		CommonClientServer.SetDynamicListFilterItem(
			ExternalUsersList,
			"IBUserID",
			New UUID("00000000-0000-0000-0000-000000000000"),
			DataCompositionComparisonType.NotEqual);
	EndIf;
	
	// Hiding the user passed from the user selection form.
	If TypeOf(Parameters.UsersToHide) = Type("ValueList") Then
		
		DCComparisonType = DataCompositionComparisonType.NotInList;
		CommonClientServer.SetDynamicListFilterItem(
			ExternalUsersList,
			"Ref",
			Parameters.UsersToHide,
			DCComparisonType);
	EndIf;
	
	ApplyConditionalAppearanceAndHideInvalidExternalUsers();
	SetExternalUserListParametersForSetPasswordCommand();
	SetAllExternalUsersGroupOrder(ExternalUsersGroups);
	
	StoredParameters.Insert("AdvancedPick", Parameters.AdvancedPick);
	Items.SelectedUsersAndGroups.Visible = StoredParameters.AdvancedPick;
	Items.UsersKind.Visible = Not StoredParameters.AdvancedPick;
	StoredParameters.Insert("UseGroups",
		GetFunctionalOption("UseUserGroups"));
	
	If Not AccessRight("Insert", Metadata.Catalogs.ExternalUsers) Then
		CommonClientServer.SetFormItemProperty(Items,
			"CreateExternalUser", "Visible", False);
	EndIf;
	
	If Not AccessRight("Edit", Metadata.Catalogs.ExternalUsersGroups) Then
		Items.ExternalUsersListContextMenuAssignGroups.Visible = False;
		Items.AssignGroups.Visible = False;
	EndIf;
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	If NOT Users.IsFullUser(, Not DataSeparationEnabled) Then
		If Items.Find("IBUsers") <> Undefined Then
			Items.IBUsers.Visible = False;
		EndIf;
		Items.ExternalUsersInfo.Visible = False;
	EndIf;
	
	If Parameters.ChoiceMode Then
		
		If Items.Find("IBUsers") <> Undefined Then
			Items.IBUsers.Visible = False;
		EndIf;
		Items.ExternalUsersInfo.Visible = False;
		Items.ExternalUsersGroups.ChoiceMode =
			StoredParameters.SelectExternalUsersGroups;
		
		// Disabling dragging users in the "select users" and "pick users" forms.
		Items.ExternalUsersList.EnableStartDrag = False;
		
		If Parameters.Property("NonExistingIBUsersIDs") Then
			CommonClientServer.SetDynamicListFilterItem(
				ExternalUsersList, "IBUserID",
				Parameters.NonExistingIBUsersIDs,
				DataCompositionComparisonType.InList, , True,
				DataCompositionSettingsItemViewMode.Inaccessible);
		EndIf;
		
		If Parameters.CloseOnChoice = False Then
			// Pick mode.
			Items.ExternalUsersList.MultipleChoice = True;
			
			If StoredParameters.AdvancedPick Then
				StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "AdvancedPick");
				ChangeExtendedPickFormParameters();
			EndIf;
			
			If StoredParameters.SelectExternalUsersGroups Then
				Items.ExternalUsersGroups.MultipleChoice = True;
			EndIf;
		EndIf;
	Else
		Items.ExternalUsersList.ChoiceMode  = False;
		Items.ExternalUsersGroups.ChoiceMode = False;
		Items.Comments.Visible = False;
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectExternalUser", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectExternalUsersGroup", "Visible", False);
	EndIf;
	
	StoredParameters.Insert("AllUsersGroup",
		Catalogs.ExternalUsersGroups.AllExternalUsers);
	
	StoredParameters.Insert("CurrentRow", Parameters.CurrentRow);
	ConfigureUserGroupsUsageForm();
	StoredParameters.Delete("CurrentRow");
	
	If Not Common.SubsystemExists("StandardSubsystems.BatchEditObjects")
	 Or Not Users.IsFullUser() Then
		
		Items.FormEditSelectedItems.Visible = False;
		Items.ExternalUsersListContextMenuChangeSelectedItems.Visible = False;
	EndIf;
	
	ObjectDetails = New Structure;
	ObjectDetails.Insert("Ref", Catalogs.Users.EmptyRef());
	ObjectDetails.Insert("IBUserID", New UUID("00000000-0000-0000-0000-000000000000"));
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(ObjectDetails);
	
	If Not AccessLevel.ListManagement Then
		Items.FormSetPassword.Visible = False;
		Items.ExternalUsersListContextMenuSetPassword.Visible = False;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.ChoiceMode Then
		CurrentFormItemModificationCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_ExternalUserGroups")
	   AND Source = Items.ExternalUsersGroups.CurrentRow Then
		
		Items.ExternalUsersGroups.Refresh();
		Items.ExternalUsersList.Refresh();
		RefreshFormContentOnGroupChange(ThisObject);
		
	ElsIf Upper(EventName) = Upper("Write_ConstantsSet") Then
		
		If Upper(Source) = Upper("UseUserGroups") Then
			AttachIdleHandler("UserGroupsUsageOnChange", 0.1, True);
		EndIf;
		
	ElsIf Upper(EventName) = Upper("ArrangeUsersInGroups") Then
		
		Items.ExternalUsersList.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	If TypeOf(Settings["SelectHierarchy"]) = Type("Boolean") Then
		SelectHierarchy = Settings["SelectHierarchy"];
	EndIf;
	
	If NOT SelectHierarchy Then
		RefreshFormContentOnGroupChange(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SelectHierarchicallyOnChange(Item)
	
	RefreshFormContentOnGroupChange(ThisObject);
	
EndProcedure

&AtClient
Procedure ShowInvalidUsersOnChange(Item)
	ToggleInvalidUsersVisibility(ShowInvalidUsers);
EndProcedure

&AtClient
Procedure UsersKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject);
	UsersInternalClient.SelectPurpose(ThisObject, NStr("ru = 'Выбор типа пользователей'; en = 'Select users type'; pl = 'Wybierz typ użytkowników';es_ES = 'Selección del tipo de usuario';es_CO = 'Selección del tipo de usuario';tr = 'Kullanıcı türü seçimi';it = 'Seleziona tipo utenti';de = 'Auswahl des Benutzertyps'"), False, True, NotifyDescription);
	
EndProcedure

#EndRegion

#Region ExternalUserGroupsFormTableItemsEventHandlers

&AtClient
Procedure ExternalUserGroupsOnChange(Item)
	
	ListOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure ExternalUserGroupsOnActivateRow(Item)
	
	RefreshFormContentOnGroupChange(ThisObject);
	
EndProcedure

&AtClient
Procedure ExternalUserGroupsValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not StoredParameters.AdvancedPick Then
		NotifyChoice(Value);
	Else
		
		GetPicturesAndFillSelectedItemsList(Value);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExternalUserGroupsBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	If NOT Clone Then
		Cancel = True;
		FormParameters = New Structure;
		
		If ValueIsFilled(Items.ExternalUsersGroups.CurrentRow) Then
			
			FormParameters.Insert(
				"FillingValues",
				New Structure("Parent", Items.ExternalUsersGroups.CurrentRow));
		EndIf;
		
		OpenForm(
			"Catalog.ExternalUsersGroups.ObjectForm",
			FormParameters,
			Items.ExternalUsersGroups);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExternalUserGroupsDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ExternalUserGroupsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If SelectHierarchy Then
		ShowMessageBox(,
			NStr("ru = 'Для перетаскивания пользователя в группы необходимо отключить
			           |флажок ""Показывать пользователей нижестоящих групп"".'; 
			           |en = 'To allow dragging users to groups, clear the 
			           |""Show users that belong to subgroups"" check box.'; 
			           |pl = 'Aby przeciągać użytkowników do grup, należy wyłączyć
			           |zaznaczenie ""Pokaż użytkowników podporządkowanych grup"".';
			           |es_ES = 'Para arrastrar los nombres de usuario para los grupos quitar
			           |la casilla de verificación ""Mostrar los usuarios del grupo menor"".';
			           |es_CO = 'Para arrastrar los nombres de usuario para los grupos quitar
			           |la casilla de verificación ""Mostrar los usuarios del grupo menor"".';
			           |tr = 'Kullanıcıyı gruplara taşımak için, ""Alt grubun kullanıcılarını göster"" onay kutusu 
			           | temizlenmelidir.';
			           |it = 'Per permettere di trascinare gli utenti nei gruppi, deselezionare la casella di controllo
			           |""Mostra utenti che appartengono a sottogruppi"".';
			           |de = 'Um einen Benutzer in eine Gruppe zu ziehen, müssen Sie das
			           |Kontrollkästchen ""Benutzer der unteren Gruppen anzeigen"" deaktivieren.'"));
		Return;
	EndIf;
	
	If Items.ExternalUsersGroups.CurrentRow = Row
		Or Row = Undefined Then
		Return;
	EndIf;
	
	If DragParameters.Action = DragAction.Move Then
		Move = True;
	Else
		Move = False;
	EndIf;
	
	CurrentGroupRow = Items.ExternalUsersGroups.CurrentRow;
	GroupWithAllAuthorizationObjectsType = 
		Items.ExternalUsersGroups.RowData(CurrentGroupRow).AllAuthorizationObjects;
	
	If Row = StoredParameters.AllUsersGroup
		AND GroupWithAllAuthorizationObjectsType Then
		UserMessage = New Structure("Message, HasErrors, Users",
			NStr("ru = 'Из групп с типом участников ""Все пользователи заданного типа"" исключение пользователей невозможно.'; en = 'Users cannot be removed from groups with an ""All users of the specified types"" flag.'; pl = 'Nie można wykluczyć użytkowników z grup z typem uczestników ""Wszyscy użytkownicy określonego typu"".';es_ES = 'Usted no puede excluir los usuarios de los grupos con el tipo de participantes ""Todos usuarios del tipo especificado"".';es_CO = 'Usted no puede excluir los usuarios de los grupos con el tipo de participantes ""Todos usuarios del tipo especificado"".';tr = 'Üye türü ""Belirlenen türe ait tüm kullanıcılar"" olan gruplardan üye çıkarılamaz.';it = 'Gli utenti non possono essere rimossi da gruppi con un contrassegno ""Tutti gli utenti del tipo specifico""';de = 'Sie können Benutzer nicht aus Gruppen mit dem Typ Kontrollkästchen ""Alle Benutzer des angegebenen Typs"" ausschließen.'"),
			True,
			Undefined);
	Else
		GroupMarkedForDeletion = Items.ExternalUsersGroups.RowData(Row).DeletionMark;
		
		UsersCount = DragParameters.Value.Count();
		
		ActionExcludeUser = (StoredParameters.AllUsersGroup = Row);
		
		ActionWithUser = 
			?((StoredParameters.AllUsersGroup = CurrentGroupRow) OR GroupWithAllAuthorizationObjectsType,
			NStr("ru = 'добавить'; en = 'add'; pl = 'dodaj';es_ES = 'añadir';es_CO = 'añadir';tr = 'ekle';it = 'aggiungi';de = 'hinzufügen'"),
			?(Move, NStr("ru = 'Переместить'; en = 'move'; pl = 'przenieś';es_ES = 'Trasladar';es_CO = 'Trasladar';tr = 'taşı';it = 'sposta';de = 'Verschieben'"), NStr("ru = 'Скопировать'; en = 'copy'; pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'kopyala';it = 'copia';de = 'KOPIE'")));
		
		If GroupMarkedForDeletion Then
			ActionTemplate = ?(Move, NStr("ru = 'Группа ""%1"" помечена на удаление. %2'; en = 'Group ""%1"" is marked for deletion. %2'; pl = 'Grupa ""%1"" jest oznaczona do usunięcia. %2';es_ES = 'El grupo ""%1"" está marcado para borrar.%2';es_CO = 'El grupo ""%1"" está marcado para borrar.%2';tr = '""%1"" grubu silinmek üzere işaretlendi. %2';it = 'Il gruppo ""%1"" è contrassegnato per l''eliminazione. %2';de = 'Die Gruppe ""%1"" wird zum Löschen markiert. %2'"), 
				NStr("ru = 'Группа ""%1"" помечена на удаление. %2'; en = 'Group ""%1"" is marked for deletion. %2'; pl = 'Grupa ""%1"" jest oznaczona do usunięcia. %2';es_ES = 'El grupo ""%1"" está marcado para borrar.%2';es_CO = 'El grupo ""%1"" está marcado para borrar.%2';tr = '""%1"" grubu silinmek üzere işaretlendi. %2';it = 'Il gruppo ""%1"" è contrassegnato per l''eliminazione. %2';de = 'Die Gruppe ""%1"" wird zum Löschen markiert. %2'"));
			ActionWithUser = StringFunctionsClientServer.SubstituteParametersToString(ActionTemplate, String(Row), ActionWithUser);
		EndIf;
		
		If UsersCount = 1 Then
			If ActionExcludeUser Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Исключить пользователя ""%1"" из группы ""%2""?'; en = 'Do you want to exclude the user ""%1"" from the group ""%2""?'; pl = 'Wykluczyć użytkownika ""%1"" z grupy ""%2""?';es_ES = 'Excluir el usuario ""%1"" del grupo ""%2""?';es_CO = 'Excluir el usuario ""%1"" del grupo ""%2""?';tr = '""%1"" kullanıcısı ""%2"" grubundan çıkarılsın mı?';it = 'Volete escludere l''utente ""%1"" dal gruppo ""%2""?';de = 'Den Benutzer ""%1"" aus der Gruppe ""%2"" ausschließen?'"),
					String(DragParameters.Value[0]),
					String(Items.ExternalUsersGroups.CurrentRow));
				
			ElsIf Not GroupMarkedForDeletion Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '%1 пользователя ""%2"" в группу ""%3""?'; en = 'Do you want to %1 the user ""%2"" to the group ""%3""?'; pl = '%1 użytkownika ""%2"" do grupy ""%3""?';es_ES = '¿%1 usuario ""%2"" al grupo ""%3""?';es_CO = '¿%1 usuario ""%2"" al grupo ""%3""?';tr = '""%2"" kullanıcısını ""%3"" grubuna %1 istiyor musunuz?';it = 'Volete %1 l''utente""%2"" al gruppo ""%3""?';de = '%1 Benutzer ""%2"" zur Gruppe ""%3""?'"),
					ActionWithUser,
					String(DragParameters.Value[0]),
					String(Row));
			Else
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '%1 пользователя ""%2"" в эту группу?'; en = 'Do you want to %1 the user ""%2"" to this group?'; pl = '%1 użytkownika ""%2"" do tej grupy?';es_ES = '%1 usuario ""%2"" a este grupo?';es_CO = '%1 usuario ""%2"" a este grupo?';tr = '""%2"" kullanıcısını bu gruba %1 istiyor musunuz?';it = 'Volete %1 l''utente ""%2"" a questo gruppo?';de = '%1 Benutzer ""%2"" zu dieser Gruppe?'"),
					ActionWithUser,
					String(DragParameters.Value[0]));
			EndIf;
		Else
			If ActionExcludeUser Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Исключить пользователей (%1) из группы ""%2""?'; en = 'Do you want to exclude %1 users from the group ""%2""?'; pl = 'Czy chcesz wykluczyć %1 użytkowników z grupy ""%2""?';es_ES = 'Excluir usuarios (%1) del grupo ""%2""?';es_CO = 'Excluir usuarios (%1) del grupo ""%2""?';tr = '%1 kullanıcı ""%2"" grubundan çıkarılsın mı?';it = 'Volete escludere %1 utenti dal gruppo ""%2""?';de = 'Benutzer (%1) aus der Gruppe ""%2"" ausschließen?'"),
					UsersCount,
					String(Items.ExternalUsersGroups.CurrentRow));
				
			ElsIf Not GroupMarkedForDeletion Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '%1 пользователей (%2) в группу ""%3""?'; en = 'Do you want to %1 %2 users to the group ""%3""?'; pl = 'Czy chcesz %1 %2 użytkowników do grupy ""%3""?';es_ES = '¿%1 usuarios (%2) al grupo ""%3""?';es_CO = '¿%1 usuarios (%2) al grupo ""%3""?';tr = '%2 kullanıcıyı ""%3"" grubuna %1 istiyor musunuz?';it = 'Volete %1 %2 utenti al gruppo ""%3""?';de = '%1 Benutzer (%2) zur Gruppe ""%3""?'"),
					ActionWithUser,
					UsersCount,
					String(Row));
			Else
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '%1 пользователей (%2) в эту группу?'; en = 'Do you want to %1 %2 users to this group?'; pl = 'Czy chcesz %1 %2 użytkowników do tej grupy?';es_ES = '¿%1 usuarios (%2) a este grupo?';es_CO = '¿%1 usuarios (%2) a este grupo?';tr = '%2 kullanıcıyı bu gruba %1 istiyor musunuz?';it = 'Volete %1 %2 utenti a questo gruppo?';de = '%1 Benutzer (%2) zu dieser Gruppe?'"),
					ActionWithUser,
					UsersCount);
			EndIf;
		EndIf;
		
		AdditionalParameters = New Structure("DragParameters, Row, Move",
			DragParameters.Value, Row, Move);
		Notification = New NotifyDescription("ExternalUserGroupsDragQuestionProcessing", ThisObject, AdditionalParameters);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
		Return;
		
	EndIf;
	
	ExternalUserGroupsDragCompletion(UserMessage);
	
EndProcedure

#EndRegion

#Region ExternalUsersFormTableItemsEventHandlers

&AtClient
Procedure ExternalUsersListOnChange(Item)
	
	ListOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure ExternalUsersListOnActivateRow(Item)
	
	If StandardSubsystemsClient.IsDynamicListItem(Items.ExternalUsersList) Then
		CanChangePassword = Items.ExternalUsersList.CurrentData.CanChangePassword;
	Else
		CanChangePassword = False;
	EndIf;
	
	Items.FormSetPassword.Enabled = CanChangePassword;
	Items.ExternalUsersListContextMenuSetPassword.Enabled = CanChangePassword;
	
EndProcedure

&AtClient
Procedure ExternalUsersListValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not StoredParameters.AdvancedPick Then
		NotifyChoice(Value);
	Else
		GetPicturesAndFillSelectedItemsList(Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExternalUsersListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	
	FormParameters = New Structure(
		"NewExternalUserGroup", Items.ExternalUsersGroups.CurrentRow);
	
	If ValueIsFilled(StoredParameters.AuthorizationObjectFilter) Then
		
		FormParameters.Insert(
			"NewExternalUserAuthorizationObject",
			StoredParameters.AuthorizationObjectFilter);
	EndIf;
	
	If Clone AND Item.CurrentData <> Undefined Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	EndIf;
	
	OpenForm(
		"Catalog.ExternalUsers.ObjectForm",
		FormParameters,
		Items.ExternalUsersList);
	
EndProcedure

&AtClient
Procedure ExternalUsersListBeforeChange(Item, Cancel)
	
	Cancel = True;
	
	If Not ValueIsFilled(Item.CurrentRow) Then
		Return;
	EndIf;
	
	FormParameters = New Structure("Key", Item.CurrentRow);
	OpenForm("Catalog.ExternalUsers.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ExternalUsersListDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region SelectedUsersAndGroupsListFormTableItemsEventHandlers

&AtClient
Procedure SelectedUsersAndGroupsListChoice(Item, RowSelected, Field, StandardProcessing)
	
	DeleteFromSelectedItems();
	ThisObject.Modified = True;
	
EndProcedure

&AtClient
Procedure SelectedUsersAndGroupsListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateExternalUsersGroup(Command)
	
	CurrentData = Items.ExternalUsersGroups.CurrentData;
	If Not StandardSubsystemsClient.IsDynamicListItem(CurrentData) Then
		Return;
	EndIf;
	
	If CurrentData.AllAuthorizationObjects Then
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Невозможно добавить подгруппу к группе ""%1"", 
			           |так как в число ее участников входят все пользователи выбранных типов.'; 
			           |en = 'Cannot add a subgroup to the group ""%1"" as 
			           | it includes all users of the specified types.'; 
			           |pl = 'Do grupy ""%1"" nie można dodać podgrupy, 
			           |ponieważ należą do niej wszyscy użytkownicy wybranych rodzajów.';
			           |es_ES = 'No se puede añadir un subgrupo al ""%1"" grupo,
			           |porque este incluye a todos usuarios.';
			           |es_CO = 'No se puede añadir un subgrupo al ""%1"" grupo,
			           |porque este incluye a todos usuarios.';
			           |tr = '""%1"" grubuna seçilmiş türden tüm kullanıcılar dahil edildiği için, 
			           |alt grup eklenemez.';
			           |it = 'Non è possibile aggiungere un sottogruppo al gruppo "" %1"" 
			           | perché l''elenco dei partecipanti comprende tutti gli utenti dei tipi selezionati.';
			           |de = 'Es ist nicht möglich, eine Untergruppe zur Gruppe ""%1"" hinzuzufügen,
			           |da alle Benutzer der ausgewählten Typen deren Mitglieder sind.'"),
			CurrentData.Description));
		Return;
	EndIf;
		
	Items.ExternalUsersGroups.AddRow();
	
EndProcedure

&AtClient
Procedure AssignGroups(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("Users", Items.ExternalUsersList.SelectedRows);
	FormParameters.Insert("ExternalUsers", True);
	
	OpenForm("CommonForm.UserGroups", FormParameters);
	
EndProcedure

&AtClient
Procedure SetPassword(Command)
	
	CurrentData = Items.ExternalUsersList.CurrentData;
	
	If StandardSubsystemsClient.IsDynamicListItem(CurrentData) Then
		UsersInternalClient.OpenChangePasswordForm(CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndAndClose(Command)
	
	If StoredParameters.AdvancedPick Then
		UsersArray = SelectionResult();
		NotifyChoice(UsersArray);
		ThisObject.Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectUserCommand(Command)
	
	UsersArray = Items.ExternalUsersList.SelectedRows;
	GetPicturesAndFillSelectedItemsList(UsersArray);
	
EndProcedure

&AtClient
Procedure CancelUserOrGroupSelection(Command)
	
		DeleteFromSelectedItems();
	
EndProcedure

&AtClient
Procedure ClearSelectedUsersAndGroupsList(Command)
	
	DeleteFromSelectedItems(True);
	
EndProcedure

&AtClient
Procedure SelectGroup(Command)
	
	GroupsArray = Items.ExternalUsersGroups.SelectedRows;
	GetPicturesAndFillSelectedItemsList(GroupsArray);
	
EndProcedure

&AtClient
Procedure ExternalUsersInfo(Command)
	
	OpenForm(
		"Report.UsersInfo.ObjectForm",
		New Structure("VariantKey", "ExternalUsersInfo"),
		ThisObject,
		"ExternalUsersInfo");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Support of batch object change.

&AtClient
Procedure ChangeSelectedItems(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		ModuleBatchEditObjectsClient = CommonClient.CommonModule("BatchEditObjectsClient");
		ModuleBatchEditObjectsClient.ChangeSelectedItems(Items.ExternalUsersList, ExternalUsersList);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillStoredParameters()
	
	StoredParameters = New Structure;
	StoredParameters.Insert("SelectExternalUsersGroups", Parameters.SelectExternalUsersGroups);
	
	If Parameters.Filter.Property("AuthorizationObject") Then
		StoredParameters.Insert("AuthorizationObjectFilter", Parameters.Filter.AuthorizationObject);
	Else
		StoredParameters.Insert("AuthorizationObjectFilter", Undefined);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillDynamicListParameters(BlankRefsArray = Undefined)
	
	Used = BlankRefsArray <> Undefined AND BlankRefsArray.Count() <> 0;
	
	CommonClientServer.SetDynamicListFilterItem(
		ExternalUsersGroups, "Ref.Purpose.UsersType",
		BlankRefsArray, DataCompositionComparisonType.InList, , Used);
	
	TypesArray = New Array;
	If Used Then
		For Each Item In BlankRefsArray Do
			TypesArray.Add(TypeOf(Item));
		EndDo;
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		ExternalUsersList, "AuthorizationObjectType",
		TypesArray, DataCompositionComparisonType.InList, , Used);
	
EndProcedure

&AtServer
Procedure ApplyConditionalAppearanceAndHideInvalidExternalUsers()
	
	// Conditional appearance.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("ExternalUsersList.Invalid");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("ExternalUsersList");
	FieldAppearanceItem.Use = True;
	
	// Hiding.
	CommonClientServer.SetDynamicListFilterItem(
		ExternalUsersList, "Invalid", False, , , True);
	
EndProcedure

&AtServer
Procedure SetExternalUserListParametersForSetPasswordCommand()
	
	UpdateDataCompositionParameterValue(ExternalUsersList, "CurrentIBUserID",
		InfoBaseUsers.CurrentUser().UUID);
	
	UpdateDataCompositionParameterValue(ExternalUsersList, "EmptyUniqueID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	UpdateDataCompositionParameterValue(ExternalUsersList, "CanChangeOwnPasswordOnly",
		Not Users.IsFullUser());
	
EndProcedure

&AtServer
Procedure SetAllExternalUsersGroupOrder(List)
	
	Var Order;
	
	// Order.
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Predefined");
	OrderItem.OrderType = DataCompositionSortDirection.Desc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Description");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
EndProcedure

&AtClient
Procedure CurrentFormItemModificationCheck()
	
	If CurrentItem <> LastItem Then
		CurrentFormItemOnChange();
		LastItem = CurrentItem;
	EndIf;
	
#If WebClient Then
	AttachIdleHandler("CurrentFormItemModificationCheck", 0.7, True);
#Else
	AttachIdleHandler("CurrentFormItemModificationCheck", 0.1, True);
#EndIf
	
EndProcedure

&AtClient
Procedure CurrentFormItemOnChange()
	
	If CurrentItem = Items.ExternalUsersGroups Then
		Items.Comments.CurrentPage = Items.GroupComment;
		
	ElsIf CurrentItem = Items.ExternalUsersList Then
		Items.Comments.CurrentPage = Items.UserComment;
		
	EndIf
	
EndProcedure

&AtServer
Procedure DeleteFromSelectedItems(DeleteAll = False)
	
	If DeleteAll Then
		SelectedUsersAndGroups.Clear();
		UpdateSelectedUsersAndGroupsListTitle();
		Return;
	EndIf;
	
	ListItemsArray = Items.SelectedUsersAndGroupsList.SelectedRows;
	For Each ListItem In ListItemsArray Do
		SelectedUsersAndGroups.Delete(SelectedUsersAndGroups.FindByID(ListItem));
	EndDo;
	
	UpdateSelectedUsersAndGroupsListTitle();
	
EndProcedure

&AtClient
Procedure GetPicturesAndFillSelectedItemsList(SelectedItemsArray)
	
	SelectedItemsAndPictures = New Array;
	For Each SelectedItem In SelectedItemsArray Do
		
		If TypeOf(SelectedItem) = Type("CatalogRef.ExternalUsers") Then
			PictureNumber = Items.ExternalUsersList.RowData(SelectedItem).PictureNumber;
		Else
			PictureNumber = Items.ExternalUsersGroups.RowData(SelectedItem).PictureNumber;
		EndIf;
		
		SelectedItemsAndPictures.Add(
			New Structure("SelectedItem, PictureNumber", SelectedItem, PictureNumber));
	EndDo;
	
	FillSelectedUsersAndGroupsList(SelectedItemsAndPictures);
	
EndProcedure

&AtServer
Function SelectionResult()
	
	SelectedUsersValueTable = SelectedUsersAndGroups.Unload( , "User");
	UsersArray = SelectedUsersValueTable.UnloadColumn("User");
	Return UsersArray;
	
EndFunction

&AtServer
Procedure ChangeExtendedPickFormParameters()
	
	// Loading the list of selected users.
	ExtendedPickFormParameters = GetFromTempStorage(Parameters.ExtendedPickFormParameters);
	SelectedUsersAndGroups.Load(ExtendedPickFormParameters.SelectedUsers);
	StoredParameters.Insert("PickFormHeader", ExtendedPickFormParameters.PickFormHeader);
	Users.FillUserPictureNumbers(SelectedUsersAndGroups, "User", "PictureNumber");
	// Setting parameters of the extended pick form.
	Items.EndAndClose.Visible                      = True;
	Items.SelectUserGroup.Visible              = True;
	// Making the list of selected users visible.
	Items.SelectedUsersAndGroups.Visible           = True;
	UseUserGroups = GetFunctionalOption("UseUserGroups");
	Items.SelectGroupGroup.Visible                    = UseUserGroups;
	If UseUserGroups Then
		Items.GroupsAndUsers.Group                 = ChildFormItemsGroup.Vertical;
		Items.ExternalUsersList.Height                = 5;
		Items.ExternalUsersGroups.Height               = 3;
		ThisObject.Height                                        = 17;
		// Making the titles of UsersList and UserGroups lists visible.
		Items.ExternalUsersGroups.TitleLocation   = FormItemTitleLocation.Top;
		Items.ExternalUsersList.TitleLocation    = FormItemTitleLocation.Top;
		Items.ExternalUsersList.Title             = NStr("ru = 'Пользователи в группе'; en = 'Users in group'; pl = 'Użytkowników w grupie';es_ES = 'Usuarios en el grupo';es_CO = 'Usuarios en el grupo';tr = 'Gruptaki kullanıcılar';it = 'Utenti in gruppo';de = 'Benutzer in der Gruppe'");
		If ExtendedPickFormParameters.Property("CannotPickGroups") Then
			Items.SelectGroup.Visible                     = False;
		EndIf;
	Else
		Items.CancelUserSelection.Visible             = True;
		Items.ClearSelectedItemsList.Visible               = True;
	EndIf;
	
	// Adding the number of selected users to the title of the list of selected users and groups.
	UpdateSelectedUsersAndGroupsListTitle();
	
EndProcedure

&AtServer
Procedure UpdateSelectedUsersAndGroupsListTitle()
	
	If StoredParameters.UseGroups Then
		SelectedUsersAndGroupsTitle = NStr("ru = 'Выбранные пользователи и группы (%1)'; en = 'Selected users and groups (%1)'; pl = 'Wybrani użytkownicy i grupy (%1)';es_ES = 'Usuarios y grupos seleccionados (%1)';es_CO = 'Usuarios y grupos seleccionados (%1)';tr = 'Seçilmiş kullanıcılar ve gruplar (%1)';it = 'Utenti e gruppi selezionati (%1)';de = 'Ausgewählte Benutzer und Gruppen (%1)'");
	Else
		SelectedUsersAndGroupsTitle = NStr("ru = 'Выбранные пользователи (%1)'; en = 'Selected users (%1)'; pl = 'Wybrani użytkownicy (%1)';es_ES = 'Usuarios seleccionados (%1)';es_CO = 'Usuarios seleccionados (%1)';tr = 'Seçilmiş kullanıcılar (%1)';it = 'Utenti selezionati (%1)';de = 'Ausgewählte Benutzer (%1)'");
	EndIf;
	
	UsersCount = SelectedUsersAndGroups.Count();
	If UsersCount <> 0 Then
		Items.SelectedUsersAndGroupsList.Title = StringFunctionsClientServer.SubstituteParametersToString(
			SelectedUsersAndGroupsTitle, UsersCount);
	Else
		
		If StoredParameters.UseGroups Then
			Items.SelectedUsersAndGroupsList.Title = NStr("ru = 'Выбранные пользователи и группы'; en = 'Selected users and groups'; pl = 'Wybrani użytkownicy i grupy';es_ES = 'Usuarios y grupos seleccionados';es_CO = 'Usuarios y grupos seleccionados';tr = 'Seçilmiş kullanıcılar ve gruplar';it = 'Utenti e gruppi selezionati';de = 'Ausgewählte Benutzer und Gruppen'");
		Else
			Items.SelectedUsersAndGroupsList.Title = NStr("ru = 'Выбранные пользователи'; en = 'Selected users'; pl = 'Wybrani użytkownicy';es_ES = 'Usuarios seleccionados';es_CO = 'Usuarios seleccionados';tr = 'Seçilmiş kullanıcılar';it = 'Utenti selezionati';de = 'Ausgewählte Benutzer'");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSelectedUsersAndGroupsList(SelectedItemsAndPictures)
	
	For Each ArrayRow In SelectedItemsAndPictures Do
		
		SelectedUserOrGroup = ArrayRow.SelectedItem;
		PictureNumber = ArrayRow.PictureNumber;
		
		FilterParameters = New Structure("User", SelectedUserOrGroup);
		ItemsFound = SelectedUsersAndGroups.FindRows(FilterParameters);
		If ItemsFound.Count() = 0 Then
			
			SelectedUsersRow = SelectedUsersAndGroups.Add();
			SelectedUsersRow.User = SelectedUserOrGroup;
			SelectedUsersRow.PictureNumber = PictureNumber;
			ThisObject.Modified = True;
			
		EndIf;
		
	EndDo;
	
	SelectedUsersAndGroups.Sort("User Asc");
	UpdateSelectedUsersAndGroupsListTitle();
	
EndProcedure

&AtClient
Procedure UserGroupsUsageOnChange()
	
	ConfigureUserGroupsUsageForm(True);
	
EndProcedure

&AtServer
Procedure ConfigureUserGroupsUsageForm(GroupUsageChanged = False)
	
	If GroupUsageChanged Then
		StoredParameters.Insert("UseGroups", GetFunctionalOption("UseUserGroups"));
	EndIf;
	
	If StoredParameters.Property("CurrentRow") Then
		
		If TypeOf(Parameters.CurrentRow) = Type("CatalogRef.ExternalUsersGroups") Then
			
			If StoredParameters.UseGroups Then
				Items.ExternalUsersGroups.CurrentRow = StoredParameters.CurrentRow;
			Else
				Parameters.CurrentRow = Undefined;
			EndIf;
		Else
			CurrentItem = Items.ExternalUsersList;
			
			Items.ExternalUsersGroups.CurrentRow =
				Catalogs.ExternalUsersGroups.AllExternalUsers;
		EndIf;
	Else
		If NOT StoredParameters.UseGroups
		   AND Items.ExternalUsersGroups.CurrentRow
		     <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			Items.ExternalUsersGroups.CurrentRow =
				Catalogs.ExternalUsersGroups.AllExternalUsers;
		EndIf;
	EndIf;
	
	Items.SelectHierarchy.Visible =
		StoredParameters.UseGroups;
	
	If StoredParameters.AdvancedPick Then
		Items.AssignGroups.Visible = False;
	Else
		Items.AssignGroups.Visible = StoredParameters.UseGroups;
	EndIf;
	
	Items.CreateExternalUsersGroup.Visible =
		AccessRight("Insert", Metadata.Catalogs.ExternalUsersGroups)
		AND StoredParameters.UseGroups;
	
	SelectExternalUsersGroups = StoredParameters.SelectExternalUsersGroups
	                               AND StoredParameters.UseGroups
	                               AND Parameters.ChoiceMode;
	
	If Parameters.ChoiceMode Then
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectExternalUsersGroup", "Visible", ?(StoredParameters.AdvancedPick,
				False, SelectExternalUsersGroups));
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectExternalUser", "DefaultButton", ?(StoredParameters.AdvancedPick,
				False, Not SelectExternalUsersGroups));
		
		CommonClientServer.SetFormItemProperty(Items,
			"SelectExternalUser", "Visible", Not StoredParameters.AdvancedPick);
		
		AutoTitle = False;
		
		If Parameters.CloseOnChoice = False Then
			// Pick mode.
			
			If SelectExternalUsersGroups Then
				
				If StoredParameters.AdvancedPick Then
					Title = StoredParameters.PickFormHeader;
				Else
					Title = NStr("ru = 'Подбор внешних пользователей и групп'; en = 'Select external users and groups'; pl = 'Wybór zewnętrznych użytkowników i grup';es_ES = 'Seleccionar usuarios externos y grupos';es_CO = 'Seleccionar usuarios externos y grupos';tr = 'Harici kullanıcıları ve grupları seçin';it = 'Selezione utenti esterni e gruppi';de = 'Wählen Sie externe Benutzer und Gruppen aus'");
				EndIf;
				
				CommonClientServer.SetFormItemProperty(Items,
					"SelectExternalUser", "Title", NStr("ru = 'Выбрать внешних пользователей'; en = 'Select external users'; pl = 'Wybór zewnętrznych użytkowników';es_ES = 'Seleccionar usuarios externos';es_CO = 'Seleccionar usuarios externos';tr = 'Harici kullanıcıları seçin';it = 'Selezione utenti esterni';de = 'Wählen Sie externe Benutzer aus'"));
				
				CommonClientServer.SetFormItemProperty(Items,
					"SelectExternalUsersGroup", "Title", NStr("ru = 'Выбрать группы'; en = 'Select groups'; pl = 'Wybierz grupy';es_ES = 'Seleccionar grupos';es_CO = 'Seleccionar grupos';tr = 'Grupları seçin';it = 'Selezione gruppi';de = 'Gruppen auswählen'"));
			Else
				If StoredParameters.AdvancedPick Then
					Title = StoredParameters.PickFormHeader;
				Else
					Title = NStr("ru = 'Выбрать внешних пользователей'; en = 'Select external users'; pl = 'Wybór zewnętrznych użytkowników';es_ES = 'Seleccionar usuarios externos';es_CO = 'Seleccionar usuarios externos';tr = 'Harici kullanıcıları seçin';it = 'Selezione utenti esterni';de = 'Wählen Sie externe Benutzer aus'");
				EndIf;
			EndIf;
		Else
			// Selection mode.
			If SelectExternalUsersGroups Then
				Title = NStr("ru = 'Выбор внешнего пользователя или группы'; en = 'Select external user or a group'; pl = 'Wybór zewnętrznego użytkownika lub grupy';es_ES = 'Seleccionar el usuario externo o el grupo';es_CO = 'Seleccionar el usuario externo o el grupo';tr = 'Harici kullanıcı veya grup seçin';it = 'Selezionare un utente esterno o un gruppo';de = 'Wählen Sie einen externen Benutzer oder eine Gruppe aus'");
				
				CommonClientServer.SetFormItemProperty(Items,
					"SelectExternalUser", "Title", NStr("ru = 'Выбрать внешнего пользователя'; en = 'Select external user'; pl = 'Wybór użytkownika zewnętrznego';es_ES = 'Seleccionar el usuario interno';es_CO = 'Seleccionar el usuario interno';tr = 'Harici kullanıcıyı seçin';it = 'Seleziona utente esterno';de = 'Wählen Sie einen internen Benutzer aus'"));
			Else
				Title = NStr("ru = 'Выбрать внешнего пользователя'; en = 'Select external user'; pl = 'Wybór użytkownika zewnętrznego';es_ES = 'Seleccionar el usuario interno';es_CO = 'Seleccionar el usuario interno';tr = 'Harici kullanıcıyı seçin';it = 'Seleziona utente esterno';de = 'Wählen Sie einen internen Benutzer aus'");
			EndIf;
		EndIf;
	EndIf;
	
	RefreshFormContentOnGroupChange(ThisObject);
	
	// Upon the functional option change, force refresh the form view without calling the 
	// RefreshInterface command.
	Items.ExternalUsersGroups.Visible = False;
	Items.ExternalUsersGroups.Visible = True;
	
EndProcedure

&AtServer
Function MoveUserToNewGroup(UsersArray, NewParentGroup, Move)
	
	If NewParentGroup = Undefined Then
		Return Undefined;
	EndIf;
	
	CurrentParentGroup = Items.ExternalUsersGroups.CurrentRow;
	UserMessage = UsersInternal.MoveUserToNewGroup(
		UsersArray, CurrentParentGroup, NewParentGroup, Move);
	
	Items.ExternalUsersList.Refresh();
	Items.ExternalUsersGroups.Refresh();
	
	Return UserMessage;
	
EndFunction

&AtClient
Procedure ToggleInvalidUsersVisibility(ShowInvalidUsers)
	
	CommonClientServer.SetDynamicListFilterItem(
		ExternalUsersList, "Invalid", False, , ,
		NOT ShowInvalidUsers);
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshFormContentOnGroupChange(Form)
	
	Items = Form.Items;
	AllExternalUsersGroup = PredefinedValue(
		"Catalog.ExternalUsersGroups.AllExternalUsers");
	
	If NOT Form.StoredParameters.UseGroups
	 OR Items.ExternalUsersGroups.CurrentRow = AllExternalUsersGroup Then
		
		UpdateDataCompositionParameterValue(Form.ExternalUsersList,
			"AllExternalUsers", True);
		
		UpdateDataCompositionParameterValue(Form.ExternalUsersList,
			"SelectHierarchy", True);
		
		UpdateDataCompositionParameterValue(Form.ExternalUsersList,
			"ExternalUsersGroup", AllExternalUsersGroup);
	Else
		UpdateDataCompositionParameterValue(Form.ExternalUsersList,
			"AllExternalUsers", False);
		
	#If Server Then
		If ValueIsFilled(Items.ExternalUsersGroups.CurrentRow) Then
			CurrentData = Common.ObjectAttributesValues(
				Items.ExternalUsersGroups.CurrentRow, "AllAuthorizationObjects");
		Else
			CurrentData = Undefined;
		EndIf;
	#Else
		CurrentData = Items.ExternalUsersGroups.CurrentData;
	#EndIf
		
		If CurrentData <> Undefined
		   AND Not CurrentData.Property("RowGroup")
		   AND CurrentData.AllAuthorizationObjects Then
			
			UpdateDataCompositionParameterValue(Form.ExternalUsersList,
				"SelectHierarchy", True);
		Else
			UpdateDataCompositionParameterValue(Form.ExternalUsersList,
				"SelectHierarchy", Form.SelectHierarchy);
		EndIf;
		
		UpdateDataCompositionParameterValue(Form.ExternalUsersList,
			"ExternalUsersGroup", Items.ExternalUsersGroups.CurrentRow);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateDataCompositionParameterValue(Val ParametersOwner,
                                                    Val ParameterName,
                                                    Val ParameterValue)
	
	For each Parameter In ParametersOwner.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			
			If Parameter.Use
			   AND Parameter.Value = ParameterValue Then
				
				Return;
			EndIf;
			Break;
			
		EndIf;
	EndDo;
	
	ParametersOwner.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure

&AtServerNoContext
Procedure ListOnChangeAtServer()
	
	UsersInternal.AfterChangeUserOrUserGroupInForm();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Dragging users.

&AtClient
Procedure ExternalUserGroupsDragQuestionProcessing(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	UserMessage = MoveUserToNewGroup(
		AdditionalParameters.DragParameters, AdditionalParameters.Row, AdditionalParameters.Move);
	ExternalUserGroupsDragCompletion(UserMessage);
	
EndProcedure

&AtClient
Procedure ExternalUserGroupsDragCompletion(UserMessage)
	
	If UserMessage.Message = Undefined Then
		Return;
	EndIf;
	
	Notify("Write_ExternalUserGroups");
	
	If UserMessage.HasErrors = False Then
		ShowUserNotification(
			NStr("ru = 'Перемещение пользователей'; en = 'Move users'; pl = 'Przenieś użytkowników';es_ES = 'Mover a los usuarios';es_CO = 'Mover a los usuarios';tr = 'Kullanıcıları taşıyın';it = 'Spostare gli utenti';de = 'Verschieben Sie Benutzer'"), , UserMessage.Message, PictureLib.Information32);
	Else
		StandardSubsystemsClient.ShowQuestionToUser(Undefined, 
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1
				|Следующие пользователи не были включены в выбранную группу:
				|%2'; 
				|en = '%1
				|The following users were not included into the selected group: 
				|%2'; 
				|pl = '%1
				|Następujący użytkownicy nie zostali włączeni do wybranej grupy:
				|%2';
				|es_ES = '%1
				|Los usuarios siguiente no han sido incluidos en el grupo seleccionado:
				|%2';
				|es_CO = '%1
				|Los usuarios siguiente no han sido incluidos en el grupo seleccionado:
				|%2';
				|tr = '%1
				|Aşağıdaki kullanıcılar seçilmiş gruba dahil edilmedi: 
				|%2';
				|it = '%1
				|I seguenti utenti non sono inclusi nel gruppo selezionato: 
				|%2';
				|de = '%1
				|Die folgenden Benutzer wurden nicht in die ausgewählte Gruppe aufgenommen:
				|%2'"), UserMessage.Message, UserMessage.Users), QuestionDialogMode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAssignmentChoice(TypesArray, AdditionalParameters) Export
	
	FillDynamicListParameters(TypesArray);
	
EndProcedure

&AtClient
Procedure UsersKindClear(Item, StandardProcessing)
	
	FillDynamicListParameters();
	
EndProcedure

#EndRegion
