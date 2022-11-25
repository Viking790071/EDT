
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.User <> Undefined Then
		UsersArray = New Array;
		UsersArray.Add(Parameters.User);
		
		ExternalUsers = ?(
			TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers"), True, False);
		
		Items.FormWriteAndClose.Title = NStr("ru = 'Записать'; en = 'Save'; pl = 'Zapisz';es_ES = 'Guardar';es_CO = 'Guardar';tr = 'Sakla';it = 'Salva';de = 'Speichern'");
		
		OpenFromUserProfileMode = True;
	Else
		UsersArray = Parameters.Users;
		ExternalUsers = Parameters.ExternalUsers;
		OpenFromUserProfileMode = False;
	EndIf;
	
	UsersCount = UsersArray.Count();
	If UsersCount = 0 Then
		Raise NStr("ru = 'Не выбрано ни одного пользователя.'; en = 'No users are selected.'; pl = 'Nie wybrano użytkownika.';es_ES = 'Ningún usuario seleccionado.';es_CO = 'Ningún usuario seleccionado.';tr = 'Hiçbir kullanıcı seçilmedi.';it = 'Nessun utente selezionato.';de = 'Kein Benutzer ist ausgewählt.'");
	EndIf;
	
	UsersType = Undefined;
	For Each UserFromArray In UsersArray Do
		If UsersType = Undefined Then
			UsersType = TypeOf(UserFromArray);
		EndIf;
		UserTypeFromArray = TypeOf(UserFromArray);
		
		If UserTypeFromArray <> Type("CatalogRef.Users")
		   AND UserTypeFromArray <> Type("CatalogRef.ExternalUsers") Then
			
			Raise NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot execute the command for the specified object.'; pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut çalıştırılamaz.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		EndIf;
		
		If UsersType <> UserTypeFromArray Then
			Raise NStr("ru = 'Команда не может быть выполнена сразу для двух разных типов пользователей.'; en = 'Cannot execute the command for two user types at once.'; pl = 'Nie można wykonać polecenia dla dwóch różnych typów użytkowników jednocześnie.';es_ES = 'No se puede ejecutar el comando para dos tipos de usuarios diferentes al mismo tiempo.';es_CO = 'No se puede ejecutar el comando para dos tipos de usuarios diferentes al mismo tiempo.';tr = 'Bir kerede iki farklı kullanıcı türü için komut çalıştırılamıyor.';it = 'Impossibile eseguire il comando per due tipi di utente contemporaneamente.';de = 'Der Befehl kann nicht gleichzeitig für zwei verschiedene Benutzerarten ausgeführt werden.'");
		EndIf;
	EndDo;
		
	If UsersCount > 1
	   AND Parameters.User = Undefined Then
		
		Title = NStr("ru = 'Группы пользователей'; en = 'User groups'; pl = 'Grupy użytkowników';es_ES = 'Grupos de usuario';es_CO = 'Grupos de usuario';tr = 'Kullanıcı grupları';it = 'Gruppi utente';de = 'Benutzergruppen'");
		Items.GroupsTreeCheckBox.ThreeState = True;
	EndIf;
	
	UsersList = New Structure;
	UsersList.Insert("UsersArray", UsersArray);
	UsersList.Insert("UsersCount", UsersCount);
	FillGroupTree();
	
	If GroupsTree.GetItems().Count() = 0 Then
		Items.GroupsOrWarning.CurrentPage = Items.Warning;
		Return;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		Items.FormWriteAndClose.Enabled = False;
		Items.FormRemoveFromAllGroups.Enabled = False;
		Items.GroupsTree.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If OpenFromUserProfileMode Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("WriteAndCloseBeginning", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region GroupTreeFormTableItemsEventHandlers

&AtClient
Procedure GroupTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Item.CurrentData.Group);
	
EndProcedure

&AtClient
Procedure GroupTreeMarkOnChange(Item)
	Modified = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	WriteAndCloseBeginning();
EndProcedure

&AtClient
Procedure ClearAll(Command)
	
	FillGroupTree(True);
	ExpandValueTree();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupsTreeCheckBox.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupsTree.ReadOnlyGroup");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);

EndProcedure

&AtClient
Procedure WriteAndCloseBeginning(Result = Undefined, AdditionalParameters = Undefined) Export
	
	NotifyUser = New Structure;
	NotifyUser.Insert("Message");
	NotifyUser.Insert("HasErrors");
	NotifyUser.Insert("FullMessageText");
	
	WriteChanges(NotifyUser);
	
	If NotifyUser.HasErrors = False Then
		If NotifyUser.Message <> Undefined Then
			ShowUserNotification(
				NStr("ru = 'Перемещение пользователей'; en = 'Move users'; pl = 'Przenieś użytkowników';es_ES = 'Mover a los usuarios';es_CO = 'Mover a los usuarios';tr = 'Kullanıcıları taşıyın';it = 'Spostare gli utenti';de = 'Verschieben Sie Benutzer'"), , NotifyUser.Message, PictureLib.Information32);
		EndIf;
	Else
		
		If NotifyUser.FullMessageText <> Undefined Then
			Report = New TextDocument;
			Report.AddLine(NotifyUser.FullMessageText);
			
			QuestionText = NotifyUser.Message;
			QuestionButtons = New ValueList;
			QuestionButtons.Add("Ok", NStr("ru='ОК'; en = 'OK'; pl = 'OK';es_ES = 'OK';es_CO = 'Ok';tr = 'Tamam';it = 'OK';de = 'Ok'"));
			QuestionButtons.Add("ShowReport", NStr("ru='Показать отчет'; en = 'View report'; pl = 'Pokaż sprawozdanie';es_ES = 'Mostrar el informe';es_CO = 'Mostrar el informe';tr = 'Raporu göster';it = 'Visualizza report';de = 'Bericht zeigen'"));
			Notification = New NotifyDescription("WriteAndCloseQuestionProcessing", ThisObject, Report);
			ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[0].Value);
		Else
			Notification = New NotifyDescription("WriteAndCloseWarningProcessing", ThisObject);
			ShowMessageBox(Notification, NotifyUser.Message);
		EndIf;
		
		Return;
	EndIf;
	
	Modified = False;
	WriteAndCloseCompletion();
	
EndProcedure

&AtServer
Procedure FillGroupTree(OnlyClearAll = False)
	
	GroupTreeDestination = FormAttributeToValue("GroupsTree");
	If Not OnlyClearAll Then
		GroupTreeDestination.Rows.Clear();
	EndIf;
	
	If OnlyClearAll Then
		
		HadChanges = False;
		FoundItems = GroupTreeDestination.Rows.FindRows(New Structure("Check", 1), True);
		For Each TreeRow In FoundItems Do
			If Not TreeRow.ReadOnlyGroup Then
				TreeRow.Check = 0;
				HadChanges = True;
			EndIf;
		EndDo;
		
		FoundItems = GroupTreeDestination.Rows.FindRows(New Structure("Check", 2), True);
		For Each TreeRow In FoundItems Do
			TreeRow.Check = 0;
			HadChanges = True;
		EndDo;
		
		If HadChanges Then
			Modified = True;
		EndIf;
		
		ValueToFormAttribute(GroupTreeDestination, "GroupsTree");
		Return;
	EndIf;
	
	UserGroups = Undefined;
	SubordinateGroups = New Array;
	ParentArray = New Array;
	
	If ExternalUsers Then
		EmptyGroup = Catalogs.ExternalUsersGroups.EmptyRef();
		GetExternalUserGroups(UserGroups);
	Else
		EmptyGroup = Catalogs.UserGroups.EmptyRef();
		GetUserGroups(UserGroups);
	EndIf;
	
	If UserGroups.Count() <= 1 Then
		Items.GroupsOrWarning.CurrentPage = Items.Warning;
		Return;
	EndIf;
	
	GetSubordinateGroups(UserGroups, SubordinateGroups, EmptyGroup);
	
	If TypeOf(UsersList.UsersArray[0]) = Type("CatalogRef.Users") Then
		UserType = "User";
	Else
		UserType = "ExternalUser";
	EndIf;
	
	While SubordinateGroups.Count() > 0 Do
		ParentArray.Clear();
		
		For Each Folder In SubordinateGroups Do
			
			If Folder.Parent = EmptyGroup Then
				NewGroupRow = GroupTreeDestination.Rows.Add();
				NewGroupRow.Group = Folder.Ref;
				NewGroupRow.Picture = ?(UserType = "User", 3, 9);
				
				If UsersList.UsersCount = 1 Then
					UserIndirectlyIncludedInGroup = False;
					UserRef = UsersList.UsersArray[0];
					
					If UserType = "ExternalUser" Then
						
						Type = TypeOf(UserRef.AuthorizationObject);
						RefTypeDetails = New TypeDescription(CommonClientServer.ValueInArray(Type));
						Value = RefTypeDetails.AdjustValue(Undefined);
						Assignment = Common.ObjectAttributeValue(Folder.Ref, "Purpose").Unload();
						
						Filter = New Structure;
						Filter.Insert("UsersType", Value);
						
						UserIndirectlyIncludedInGroup = Folder.AllAuthorizationObjects
							AND Assignment.FindRows(Filter).Count() <> 0;
						NewGroupRow.ReadOnlyGroup = UserIndirectlyIncludedInGroup;
					EndIf;
					
					FoundUser = Folder.Ref.Content.Find(UserRef, UserType);
					NewGroupRow.Check = ?(FoundUser <> Undefined Or UserIndirectlyIncludedInGroup, 1, 0);
				Else
					NewGroupRow.Check = 2;
				EndIf;
				
			Else
				ParentGroup = 
					GroupTreeDestination.Rows.FindRows(New Structure("Group", Folder.Parent), True);
				NewSubordinateGroupRow = ParentGroup[0].Rows.Add();
				NewSubordinateGroupRow.Group = Folder.Ref;
				NewSubordinateGroupRow.Picture = ?(UserType = "User", 3, 9);
				
				If UsersList.UsersCount = 1 Then
					NewSubordinateGroupRow.Check = ?(Folder.Ref.Content.Find(
						UsersList.UsersArray[0], UserType) = Undefined, 0, 1);
				Else
					NewSubordinateGroupRow.Check = 2;
				EndIf;
				
			EndIf;
			
			ParentArray.Add(Folder.Ref);
		EndDo;
		SubordinateGroups.Clear();
		
		For Each Item In ParentArray Do
			GetSubordinateGroups(UserGroups, SubordinateGroups, Item);
		EndDo;
		
	EndDo;
	
	GroupTreeDestination.Rows.Sort("Group Asc", True);
	ValueToFormAttribute(GroupTreeDestination, "GroupsTree");
	
EndProcedure

&AtServer
Procedure GetUserGroups(UserGroups)
	
	Query = New Query;
	Query.Text = "SELECT
	|	UserGroups.Ref,
	|	UserGroups.Parent
	|FROM
	|	Catalog.UserGroups AS UserGroups
	|WHERE
	|	UserGroups.DeletionMark <> TRUE";
	
	UserGroups = Query.Execute().Unload();
	
EndProcedure

&AtServer
Procedure GetExternalUserGroups(UserGroups)
	
	Query = New Query;
	Query.Text = "SELECT
	|	ExternalUsersGroups.Ref,
	|	ExternalUsersGroups.Parent,
	|	ExternalUsersGroups.AllAuthorizationObjects
	|FROM
	|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|WHERE
	|	ExternalUsersGroups.DeletionMark <> TRUE";
	
	UserGroups = Query.Execute().Unload();
	
EndProcedure

&AtServer
Procedure GetSubordinateGroups(UserGroups, SubordinateGroups, ParentGroup)
	
	FilterParameters = New Structure("Parent", ParentGroup);
	PickedRows = UserGroups.FindRows(FilterParameters);
	
	For Each Item In PickedRows Do
		
		If Item.Ref = Catalogs.UserGroups.AllUsers
			Or Item.Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			Continue;
		EndIf;
		
		SubordinateGroups.Add(Item);
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteChanges(NotifyUser)
	
	UsersArray = Undefined;
	NotMovedUsers = New Map;
	GroupTreeSource = GroupsTree.GetItems();
	RefillGroupComposition(GroupTreeSource, UsersArray, NotMovedUsers);
	GenerateMessageText(UsersArray, NotifyUser, NotMovedUsers)
	
EndProcedure

&AtServer
Procedure RefillGroupComposition(GroupTreeSource, MovedUsersArray, NotMovedUsers)
	
	UsersArray = UsersList.UsersArray;
	If MovedUsersArray = Undefined Then
		MovedUsersArray = New Array;
	EndIf;
	
	For Each TreeRow In GroupTreeSource Do
		
		If TreeRow.Check = 1
			AND Not TreeRow.ReadOnlyGroup Then
			
			For Each UserRef In UsersArray Do
				
				If TypeOf(UserRef) = Type("CatalogRef.Users") Then
					UserType = "User";
				Else
					UserType = "ExternalUser";
					CanMove = UsersInternal.CanMoveUser(TreeRow.Group, UserRef);
					
					If Not CanMove Then
						
						If NotMovedUsers.Get(UserRef) = Undefined Then
							NotMovedUsers.Insert(UserRef, New Array);
							NotMovedUsers[UserRef].Add(TreeRow.Group);
						Else
							NotMovedUsers[UserRef].Add(TreeRow.Group);
						EndIf;
						
						Continue;
					EndIf;
					
				EndIf;
				
				Add = ?(TreeRow.Group.Content.Find(
					UserRef, UserType) = Undefined, True, False);
				If Add Then
					UsersInternal.AddUserToGroup(TreeRow.Group, UserRef, UserType);
					
					If MovedUsersArray.Find(UserRef) = Undefined Then
						MovedUsersArray.Add(UserRef);
					EndIf;
					
				EndIf;
				
			EndDo;
			
		ElsIf TreeRow.Check = 0
			AND Not TreeRow.ReadOnlyGroup Then
			
			For Each UserRef In UsersArray Do
				
				If TypeOf(UserRef) = Type("CatalogRef.Users") Then
					UserType = "User";
				Else
					UserType = "ExternalUser";
				EndIf;
				
				Delete = ?(TreeRow.Group.Content.Find(
					UserRef, UserType) <> Undefined, True, False);
				If Delete Then
					UsersInternal.DeleteUserFromGroup(TreeRow.Group, UserRef, UserType);
					
					If MovedUsersArray.Find(UserRef) = Undefined Then
						MovedUsersArray.Add(UserRef);
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		TreeRowItems = TreeRow.GetItems();
		// Recursion
		RefillGroupComposition(TreeRowItems, MovedUsersArray, NotMovedUsers);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateMessageText(MovedUsersArray, NotifyUser, NotMovedUsers)
	
	UsersCount = MovedUsersArray.Count();
	NotMovedUsersCount = NotMovedUsers.Count();
	UserRow = "";
	
	If NotMovedUsersCount > 0 Then
		
		If NotMovedUsersCount = 1 Then
			For Each NotMovedUser In NotMovedUsers Do
				Subject = String(NotMovedUser.Key);
			EndDo;
			UserMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Пользователя ""%1"" не удалось включить в выбранные группы,
				           |т.к. у них различается тип или у групп установлен признак ""Все пользователи заданного типа"".'; 
				           |en = 'Cannot add user ""%1"" to the selected groups
				           |because they have different types or because the groups have ""All users of the specified types"" option selected.'; 
				           |pl = 'Użytkownika ""%1"" nie udało się
				           |dołączyć do wybranej grupy, ponieważ różnią się typami lub dla grup określono znak ""Wszyscy użytkownicy określonego typu"".';
				           |es_ES = 'Usuario ""%1"" no se ha podido
				           |incluir en el grupo seleccionado, porque ellos tienen varios tipos, o los grupos tienen la señal ""Todos usuario del tipo especificado"" instalada.';
				           |es_CO = 'Usuario ""%1"" no se ha podido
				           |incluir en el grupo seleccionado, porque ellos tienen varios tipos, o los grupos tienen la señal ""Todos usuario del tipo especificado"" instalada.';
				           |tr = 'Kullanıcı ""%1"" farklı gruplara sahip olduklarından 
				           |veya grupların ""Belirtilen türdeki tüm kullanıcılar"" işaretinin yüklü olması nedeniyle seçili grupta yer almayı başaramadı.';
				           |it = 'L''utente ""%1"" non può essere incluso nei gruppi selezionati,
				           |perché i gruppi hanno tipi diversi oppure hanno la proprietà ""Tutti gli utenti del tipo specificato"".';
				           |de = 'Benutzer ""%1"" konnte nicht
				           |in die ausgewählte Gruppe aufnehmen, da sie unterschiedliche Typen haben oder die Gruppen das Zeichen ""Alle Benutzer des angegebenen Typs"" installiert haben.'"),
				Subject);
		Else
			Subject = Format(NotMovedUsersCount, "NFD=0") + " "
				+ UsersInternalClientServer.IntegerSubject(NotMovedUsersCount,
					"", NStr("ru = 'пользователю,пользователям,пользователям,,,,,,0'; en = 'user, users,,,0'; pl = 'użytkownik, użytkownicy,,,0';es_ES = 'usuario, usuarios,,,0';es_CO = 'usuario, usuarios,,,0';tr = 'kullanıcı, kullanıcılar, kullanıcılar,,,,,,0';it = 'utente, utenti,,,0';de = 'Benutzer, Benutzer, Benutzer,,,,,,0'"));
			UserMessage =
				NStr("ru = 'Не всех пользователей удалось включить в выбранные группы,
				           |т.к. у них различается тип или у групп установлен признак ""Все пользователи заданного типа"".'; 
				           |en = 'Cannot add some users to the selected groups
				           |because they have different types or because the groups have ""All users of the specified types"" option selected.'; 
				           |pl = 'Nie wszystkich użytkowników udało się dołączyć do
				           |wybranej grupy, ponieważ różnią się typami lub dla grup określono znak ""Wszyscy użytkownicy określonego typu"".';
				           |es_ES = 'No todos los usuarios se han podido incluir en
				           |el grupo seleccionado, porque ellos tienen tipos diferentes, o los grupos tienen la señal ""Todos usuarios del tipo especificado"" instalada.';
				           |es_CO = 'No todos los usuarios se han podido incluir en
				           |el grupo seleccionado, porque ellos tienen tipos diferentes, o los grupos tienen la señal ""Todos usuarios del tipo especificado"" instalada.';
				           |tr = 'Tüm kullanıcılar farklı
				           |gruplara sahip olduklarından veya grupların ""Belirtilen türdeki tüm kullanıcılar"" işaretinin yüklü olması nedeniyle seçili gruba dahil etmeyi başaramadı.';
				           |it = 'Non`è stato possibile includere tutti gli utenti nei gruppi selezionati,
				           |perché i gruppi hanno tipi diversi oppure hanno la proprietà ""Tutti gli utenti del tipo specificato"".';
				           |de = 'Nicht alle Benutzer konnten in die
				           |ausgewählte Gruppe aufnehmen, da sie unterschiedliche Typen haben oder die Gruppen das Zeichen ""Alle Benutzer des angegebenen Typs"" installiert haben.'");
			For Each NotMovedUser In NotMovedUsers Do
				UserRow = UserRow + String(NotMovedUser.Key)
					+ " : " + StrConcat(NotMovedUser.Value, ",") + Chars.LF;
			EndDo;
			NotifyUser.FullMessageText =
				NStr("ru = 'Следующие пользователи не были включены в группы:'; en = 'The following users were not added to the groups:'; pl = 'Następujących użytkowników nie udało się dołączyć do grup:';es_ES = 'Los siguientes usuarios no se han incluido en los grupos:';es_CO = 'Los siguientes usuarios no se han incluido en los grupos:';tr = 'Aşağıdaki kullanıcılar gruplara dahil edilmedi:';it = 'I seguenti utenti non sono stati inclusi nei gruppi:';de = 'Folgende Benutzer wurden nicht in Gruppen aufgenommen:'")
				+ Chars.LF + Chars.LF + UserRow;
		EndIf;
		
		NotifyUser.Message = UserMessage;
		NotifyUser.HasErrors = True;
		Return;
		
	ElsIf UsersCount = 1 Then
		UserDescription = Common.ObjectAttributeValue(
			MovedUsersArray[0], "Description");
		
		NotifyUser.Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Изменен состав групп у пользователя ""%1""'; en = 'The list of groups is modified for user ""%1"".'; pl = 'Grupy użytkowników ""%1"" zostały zmienione';es_ES = 'Grupos del usuario ""%1"" se han cambiado';es_CO = 'Grupos del usuario ""%1"" se han cambiado';tr = '""%1"" kullanıcısı için grup listesi değiştirildi.';it = 'Modificata la composizione dei gruppi dell''utente ""%1"".';de = 'Benutzergruppen ""%1"" werden geändert'"),
			UserDescription);
			
	ElsIf UsersCount > 1 Then
		StringObject = Format(UsersCount, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(UsersCount,
				"", NStr("ru = 'пользователю,пользователям,пользователям,,,,,,0'; en = 'user, users,,,0'; pl = 'użytkownik, użytkownicy,,,0';es_ES = 'usuario, usuarios,,,0';es_CO = 'usuario, usuarios,,,0';tr = 'kullanıcı, kullanıcılar, kullanıcılar,,,,,,0';it = 'utente, utenti,,,0';de = 'Benutzer, Benutzer, Benutzer,,,,,,0'"));
		
		NotifyUser.Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Изменен состав групп у %1'; en = 'The list of groups is modified for %1.'; pl = 'Grupy %1 są zmienione';es_ES = 'Grupos de %1 se han cambiado';es_CO = 'Grupos de %1 se han cambiado';tr = '%1 için grup listesi değiştirildi.';it = 'Modificata la composizione dei gruppi a %1.';de = 'Gruppen von %1 sind geändert'"), StringObject);
	EndIf;
	
	NotifyUser.HasErrors = False;
	
EndProcedure

&AtClient
Procedure ExpandValueTree()
	
	Rows = GroupsTree.GetItems();
	For Each Row In Rows Do
		Items.GroupsTree.Expand(Row.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure WriteAndCloseQuestionProcessing(Response, Report) Export
	
	If Response = "Ok" Then
		Return;
	Else
		Report.Show(NStr("ru = 'Пользователи, не включенные в группы'; en = 'Users not included in the groups'; pl = 'Użytkownicy nie zostali dołączeni do grup';es_ES = 'Usuarios no incluidos en los grupos';es_CO = 'Usuarios no incluidos en los grupos';tr = 'Kullanıcılar gruplara dahil değil';it = 'Utenti non inclusi nei gruppi';de = 'Benutzer, die nicht in Gruppen enthalten'"));
		Return;
	EndIf;
	
	Modified = False;
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure WriteAndCloseWarningProcessing(AdditionalParameters) Export
	
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure WriteAndCloseCompletion()
	
	Notify("ArrangeUsersInGroups");
	If ExternalUsers Then
		Notify("Write_ExternalUserGroups");
	Else
		Notify("Write_UserGroups");
	EndIf;
	
	If Not OpenFromUserProfileMode Then
		Close();
	Else
		FillGroupTree();
		ExpandValueTree();
	EndIf;
	
EndProcedure

#EndRegion
