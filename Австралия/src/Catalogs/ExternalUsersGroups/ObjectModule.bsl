#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var PreviousParent; // Value of the group parent before changes, to be used in OnWrite event handler.
                      // 

Var ExternalUserGroupPreviousComposition; // External user group content before changes to use in OnWrite event handler.
                                              // 
                                              // 

Var ExternalUserGroupPreviousRolesComposition; // External users group roles content before changes, to be used in OnWrite event handler.
                                                   // 
                                                   // 

Var AllAuthorizationObjectsPreviousValue; // AllAuthorizationObjects attribute value before change to use in OnWrite event handler.
                                           // 
                                           // 

Var IsNew; // Shows whether a new object was written.
                // Used in OnWrite event handler.

#EndRegion

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If AdditionalProperties.Property("VerifiedObjectAttributes") Then
		VerifiedObjectAttributes = AdditionalProperties.VerifiedObjectAttributes;
	Else
		VerifiedObjectAttributes = New Array;
	EndIf;
	
	Errors = Undefined;
	
	// Checking the parent.
	ErrorText = ParentCheckErrorText();
	If ValueIsFilled(ErrorText) Then
		CommonClientServer.AddUserError(Errors,
			"Object.Parent", ErrorText, "");
	EndIf;
	
	// Checking for unfilled and duplicate external users.
	VerifiedObjectAttributes.Add("Content.ExternalUser");
	
	// Checking the group purpose.
	ErrorText = PurposeCheckErrorText();
	If ValueIsFilled(ErrorText) Then
		CommonClientServer.AddUserError(Errors,
			"Object.Purpose", ErrorText, "");
	EndIf;
	VerifiedObjectAttributes.Add("Purpose");
	
	For each CurrentRow In Content Do
		RowNumber = Content.IndexOf(CurrentRow);
		
		// Checking whether the value is filled.
		If NOT ValueIsFilled(CurrentRow.ExternalUser) Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("ru = 'Внешний пользователь не выбран.'; en = 'The external user is not specified.'; pl = 'Użytkownik zewnętrzny nie jest wybrany.';es_ES = 'Usuario externo no está seleccionado.';es_CO = 'Usuario externo no está seleccionado.';tr = 'Harici kullanıcı seçilmedi.';it = 'L''utente esterno non è specificato.';de = 'Externer Benutzer ist nicht ausgewählt.'"),
				"Object.Content",
				RowNumber,
				NStr("ru = 'Внешний пользователь в строке %1 не выбран.'; en = 'The external user is not specified in line #%1.'; pl = 'Użytkownik zewnętrzny w wierszu %1 nie został wybrany.';es_ES = 'Usuario externo en la línea %1 no se ha seleccionado.';es_CO = 'Usuario externo en la línea %1 no se ha seleccionado.';tr = '%1Satırında harici kullanıcı seçilmedi.';it = 'L''utente esterno non è specificato nella linea #%1.';de = 'Externer Benutzer in Zeile %1 wurde nicht ausgewählt.'"));
			Continue;
		EndIf;
		
		// Checking for duplicate values.
		FoundValues = Content.FindRows(New Structure("ExternalUser", CurrentRow.ExternalUser));
		If FoundValues.Count() > 1 Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("ru = 'Внешний пользователь повторяется.'; en = 'Duplicate external user.'; pl = 'Użytkownik zewnętrzny powtarza się.';es_ES = 'Usuario externo está repetido.';es_CO = 'Usuario externo está repetido.';tr = 'Harici kullanıcı tekrarlandı.';it = 'Duplica utente esterno.';de = 'Externer Benutzer wird wiederholt.'"),
				"Object.Content",
				RowNumber,
				NStr("ru = 'Внешний пользователь в строке %1 повторяется.'; en = 'Duplicate external user in line #%1.'; pl = 'Użytkownik zewnętrzny w wierszu %1 powtarza się.';es_ES = 'Usuario externo en la línea %1 está repetido.';es_CO = 'Usuario externo en la línea %1 está repetido.';tr = '%1Satırında harici kullanıcı tekrarlandı.';it = 'Duplica utente esterno in linea #%1.';de = 'Externer Benutzer in der Zeile %1 wird wiederholt.'"));
		EndIf;
	EndDo;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, VerifiedObjectAttributes);
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT UsersInternal.CannotEditRoles() Then
		QueryResult = Common.ObjectAttributeValue(Ref, "Roles");
		If TypeOf(QueryResult) = Type("QueryResult") Then
			ExternalUserGroupPreviousRolesComposition = QueryResult.Unload();
		Else
			ExternalUserGroupPreviousRolesComposition = Roles.Unload(New Array);
		EndIf;
	EndIf;
	
	IsNew = IsNew();
	
	If Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		FillPurposeWithAllExternalUsersTypes();
		AllAuthorizationObjects  = False;
	EndIf;
	
	ErrorText = ParentCheckErrorText();
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
	If Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		If Content.Count() > 0 Then
			Raise
				NStr("ru = 'Добавление участников в предопределенную группу ""Все внешние пользователи"" запрещено.'; en = 'Cannot add members to the predefined group ""All external users.""'; pl = 'Dodawanie uczestników do wcześniej zdefiniowanej grupy ""Wszyscy użytkownicy zewnętrzni"" jest zabronione.';es_ES = 'Añadir participantes al grupo predefinido ""Todos usuarios externos"" está prohibido.';es_CO = 'Añadir participantes al grupo predefinido ""Todos usuarios externos"" está prohibido.';tr = 'Öntanımlı ""Tüm harici kullanıcılar"" grubuna yeni üyeler eklenemez.';it = 'L''aggiunta degli utenti al gruppo predefinito ""Tutti utenti esterni"" è proibita';de = 'Das Hinzufügen von Teilnehmern zur vordefinierten Gruppe ""Alle externen Benutzer"" ist verboten.'");
		EndIf;
	Else
		ErrorText = PurposeCheckErrorText();
		If ValueIsFilled(ErrorText) Then
			Raise ErrorText;
		EndIf;
		
		PreviousValues = Common.ObjectAttributesValues(
			Ref, "AllAuthorizationObjects, Parent");
		
		PreviousParent                      = PreviousValues.Parent;
		AllAuthorizationObjectsPreviousValue = PreviousValues.AllAuthorizationObjects;
		
		If ValueIsFilled(Ref)
		   AND Ref <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			QueryResult = Common.ObjectAttributeValue(Ref, "Content");
			If TypeOf(QueryResult) = Type("QueryResult") Then
				ExternalUserGroupPreviousComposition = QueryResult.Unload();
			Else
				ExternalUserGroupPreviousComposition = Content.Unload(New Array);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If UsersInternal.CannotEditRoles() Then
		IsExternalUserGroupRoleCompositionChanged = False;
		
	Else
		IsExternalUserGroupRoleCompositionChanged =
			UsersInternal.ColumnValueDifferences(
				"Role",
				Roles.Unload(),
				ExternalUserGroupPreviousRolesComposition).Count() <> 0;
	EndIf;
	
	ItemsToChange = New Map;
	ModifiedGroups   = New Map;
	
	If Ref <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
		
		If AllAuthorizationObjects
		 OR AllAuthorizationObjectsPreviousValue = True Then
			
			UsersInternal.UpdateExternalUserGroupCompositions(
				Ref, , ItemsToChange, ModifiedGroups);
		Else
			CompositionChanges = UsersInternal.ColumnValueDifferences(
				"ExternalUser",
				Content.Unload(),
				ExternalUserGroupPreviousComposition);
			
			UsersInternal.UpdateExternalUserGroupCompositions(
				Ref, CompositionChanges, ItemsToChange, ModifiedGroups);
			
			If PreviousParent <> Parent Then
				
				If ValueIsFilled(Parent) Then
					UsersInternal.UpdateExternalUserGroupCompositions(
						Parent, , ItemsToChange, ModifiedGroups);
				EndIf;
				
				If ValueIsFilled(PreviousParent) Then
					UsersInternal.UpdateExternalUserGroupCompositions(
						PreviousParent, , ItemsToChange, ModifiedGroups);
				EndIf;
			EndIf;
		EndIf;
		
		UsersInternal.UpdateUserGroupCompositionUsage(
			Ref, ItemsToChange, ModifiedGroups);
	EndIf;
	
	If IsExternalUserGroupRoleCompositionChanged Then
		UsersInternal.UpdateExternalUsersRoles(Ref);
	EndIf;
	
	UsersInternal.AfterUpdateExternalUserGroupCompositions(
		ItemsToChange, ModifiedGroups);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillPurposeWithAllExternalUsersTypes()
	
	Purpose.Clear();
	
	BlankRefs = UsersInternalCached.BlankRefsOfAuthorizationObjectTypes();
	For Each BlankRef In BlankRefs Do
		NewRow = Purpose.Add();
		NewRow.UsersType = BlankRef;
	EndDo;
	
EndProcedure

Function ParentCheckErrorText()
	
	If Parent = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		Return
			NStr("ru = 'Предопределенная группа ""Все внешние пользователи"" не может быть родителем.'; en = 'Cannot use the predefined group ""All external users"" as a parent.'; pl = 'Wstępnie zdefiniowana grupa ""Wszyscy użytkownicy zewnętrzni"" nie może być grupą nadrzędną.';es_ES = 'Grupo predefinido ""Todos usuarios externos"" no puede ser un grupo original.';es_CO = 'Grupo predefinido ""Todos usuarios externos"" no puede ser un grupo original.';tr = 'Öntanımlı ""Tüm harici kullanıcılar"" grubu üst grup olarak kullanılamaz.';it = 'Il gruppo predefinito ""Tutti utenti esterni"" non può essere padre.';de = 'Die vordefinierte Gruppe ""Alle externen Benutzer"" darf keine übergeordnete Gruppe sein.'");
	EndIf;
	
	If Ref = Catalogs.ExternalUsersGroups.AllExternalUsers Then
		If Not Parent.IsEmpty() Then
			Return
				NStr("ru = 'Предопределенная группа ""Все внешние пользователи"" не может быть перемещена.'; en = 'Cannot move the predefined group ""All external users.""'; pl = 'Predefiniowana grupa ""Wszyscy użytkownicy zewnętrzni"" nie może zostać przeniesiona.';es_ES = 'Grupo predefinido ""Todos usuarios externos"" no puede moverse.';es_CO = 'Grupo predefinido ""Todos usuarios externos"" no puede moverse.';tr = 'Öntanımlı ""Tüm harici kullanıcılar"" grubu taşınamaz.';it = 'Il gruppo predefinito ""Tutti utenti esterni"" non può essere spostato';de = 'Vordefinierte Gruppe ""Alle externen Benutzer"" kann nicht verschoben werden.'");
		EndIf;
	Else
		If Parent = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			Return
				NStr("ru = 'Невозможно добавить подгруппу к предопределенной группе ""Все внешние пользователи"".'; en = 'Cannot add a subgroup to the predefined group ""All external users.""'; pl = 'Nie można dodać podgrupy do wstępnie zdefiniowanej grupy ""Wszyscy użytkownicy zewnętrzni"".';es_ES = 'No se puede añadir un subgrupo al grupo predefinido ""Todos usuarios externos"".';es_CO = 'No se puede añadir un subgrupo al grupo predefinido ""Todos usuarios externos"".';tr = 'Öntanımlı ""Tüm harici kullanıcılar"" grubuna alt grup eklenemez.';it = 'Impossibile aggiungere il sottogruppo al gruppo predefinito ""Tutti utenti esterni""';de = 'Die Untergruppe kann der vordefinierten Gruppe ""Alle externen Benutzer"" nicht hinzugefügt werden.'");
			
		ElsIf Parent.AllAuthorizationObjects Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Невозможно добавить подгруппу к группе ""%1"",
				           |так как в число ее участников входят все пользователи.'; 
				           |en = 'Cannot add a subgroup to the group ""%1""
				           |because it includes all users.'; 
				           |pl = 'Nie można dodać podgrupy do grupy ""%1"",
				           |ponieważ obejmuje ona wszystkich użytkowników.';
				           |es_ES = 'No se puede añadir un subgrupo al grupo ""%1"",
				           |porque este incluye a todos usuarios.';
				           |es_CO = 'No se puede añadir un subgrupo al grupo ""%1"",
				           |porque este incluye a todos usuarios.';
				           |tr = '""%1"" grubuna tüm kullanıcılar dahil edildiği için, 
				           |alt grup eklenemez.';
				           |it = 'Impossibile aggiungere il sottogruppo al gruppo ""%1"",
				           |perché tutti gli utenti ne fanno parte.';
				           |de = 'Es ist nicht möglich, eine Untergruppe zur Gruppe ""%1"" hinzuzufügen,
				           |da alle Benutzer Mitglieder dieser Gruppe sind.'"), Parent);
		EndIf;
		
		If AllAuthorizationObjects AND ValueIsFilled(Parent) Then
			Return
				NStr("ru = 'Невозможно переместить группу, в число участников которой входят все пользователи.'; en = 'Cannot move a group that includes all users.'; pl = 'Nie można przenieść grupy zawierającej wszystkich użytkowników.';es_ES = 'No se puede mover el grupo que incluye a todos usuarios.';es_CO = 'No se puede mover el grupo que incluye a todos usuarios.';tr = 'Tüm kullanıcıları içeren grup taşınamaz.';it = 'Impossibile muovere un gruppo che include tutti gli utenti.';de = 'Die Gruppe, die alle Benutzer enthält, kann nicht verschoben werden.'");
		EndIf;
	EndIf;
	
	Return "";
	
EndFunction

Function PurposeCheckErrorText()
	
	// Checking whether the group purpose is filled.
	If Purpose.Count() = 0 Then
		Return NStr("ru = 'Не указан тип участников группы.'; en = 'The type of group members is not specified.'; pl = 'Nie wskazano rodzaju członków grupy.';es_ES = 'El tipo de los participantes del grupo no se ha especificado.';es_CO = 'El tipo de los participantes del grupo no se ha especificado.';tr = 'Grup üyelerin türü belirtilmedi.';it = 'Il tipo di membri del gruppo non è stato specificato.';de = 'Der Typ der Gruppenmitglieder ist nicht angegeben.'");
	EndIf;
	
	// Checking whether the group of all authorization objects of the specified type is unique.
	If AllAuthorizationObjects Then
		
		// Checking whether the purpose matches the "All external users" group.
		AllExternalUsersGroup = Catalogs.ExternalUsersGroups.AllExternalUsers;
		AllExternalUsersPurpose = Common.ObjectAttributeValue(
			AllExternalUsersGroup, "Purpose").Unload().UnloadColumn("UsersType");
		PurposesArray = Purpose.UnloadColumn("UsersType");
		
		If CommonClientServer.ValueListsAreEqual(AllExternalUsersPurpose, PurposesArray) Then
			Return
				NStr("ru = 'Невозможно создать группу, совпадающую по назначению
				           |с предопределенной группой ""Все внешние пользователи"".'; 
				           |en = 'Cannot create a group having the same purpose
				           | as the predefined group ""All external users.""'; 
				           |pl = 'Nie można utworzyć grupy o tym samym celu,
				           | co wstępnie zdefiniowana grupa ""Wszyscy użytkownicy zewnętrzni"".';
				           |es_ES = 'Es imposible crear un grupo que coincide por el valor
				           |con el grupo predeterminado ""Todos los usuarios externos"".';
				           |es_CO = 'Es imposible crear un grupo que coincide por el valor
				           |con el grupo predeterminado ""Todos los usuarios externos"".';
				           |tr = 'Öntanımlı ""Tüm harici kullanıcılar"" grubu ile
				           | aynı amaca sahip grup oluşturulamaz.';
				           |it = 'Impossibile creare il gruppo, la cui assegnazione corrisponde
				           |con il gruppo predefinito ""Tutti gli utenti esterni""';
				           |de = 'Es ist nicht möglich, eine Gruppe zu erstellen,
				           |die mit der vordefinierten Gruppe ""Alle externen Benutzer"" übereinstimmt.'");
		EndIf;
		
		Query = New Query;
		Query.SetParameter("Ref", Ref);
		Query.SetParameter("UsersTypes", Purpose.Unload());
		
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
		|	PRESENTATION(ExternalUsersGroups.Ref) AS RefPresentation
		|FROM
		|	Catalog.ExternalUsersGroups.Purpose AS ExternalUsersGroups
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				UsersTypes AS UsersTypes
		|			WHERE
		|				ExternalUsersGroups.Ref <> &Ref
		|				AND ExternalUsersGroups.Ref.AllAuthorizationObjects
		|				AND VALUETYPE(UsersTypes.UsersType) = VALUETYPE(ExternalUsersGroups.UsersType))";
		
		QueryResult = Query.Execute();
		If NOT QueryResult.IsEmpty() Then
		
			Selection = QueryResult.Select();
			Selection.Next();
			
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Уже существует группа ""%1"",
				           |в число участников которой входят все пользователи указанных типов.'; 
				           |en = 'An existing group ""%1""
				           | includes all users of the specified types.'; 
				           |pl = 'Grupa ""%1"", 
				           |do której należą wszyscy użytkownicy wskazanych rodzajów, już istnieje.';
				           |es_ES = 'El grupo ""%1"" ya existe e
				           |incluye a todos usuarios del tipo.';
				           |es_CO = 'El grupo ""%1"" ya existe e
				           |incluye a todos usuarios del tipo.';
				           |tr = '""%1"" grup zaten var ve 
				           | belirtilen türünden tüm kullanıcıları içermektedir.';
				           |it = 'Esiste già il gruppo ""%1"",
				           |, i membri del quale sono tutti gli utenti dei tipi indicati.';
				           |de = 'Es gibt bereits eine Gruppe von ""%1"",
				           |zu deren Mitgliedern alle Benutzer dieses Typs gehören.'"),
				Selection.RefPresentation);
		EndIf;
	EndIf;
	
	// Checking whether authorization object type is equal to the parent type (Undefined parent type is 
	// allowed).
	If ValueIsFilled(Parent) Then
		
		ParentUsersType = Common.ObjectAttributeValue(
			Parent, "Purpose").Unload().UnloadColumn("UsersType");
		UsersType = Purpose.UnloadColumn("UsersType");
		
		For Each UserType In UsersType Do
			If ParentUsersType.Find(UserType) = Undefined Then
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Тип участников группы должен быть как у вышестоящей
					           |группы внешних пользователей ""%1"".'; 
					           |en = 'The group members type must be identical to the members type
					           |of the parent external user group ""%1.""'; 
					           |pl = 'Rodzaj członków grupy powinien być taki sam, jak w wyższej
					           |grupie użytkowników zewnętrznych ""%1"".';
					           |es_ES = 'El tipo de los participantes del grupo debe ser como para el grupo superior
					           | de los usuarios externos ""%1"".';
					           |es_CO = 'El tipo de los participantes del grupo debe ser como para el grupo superior
					           | de los usuarios externos ""%1"".';
					           |tr = '""%1"" Grup üyelerinin türü, "
" harici kullanıcı grubundaki gibi olmalıdır.';
					           |it = 'Il tipo di partecipanti del gruppo deve corrispondere al gruppo soprastante 
					           |degli utenti esterni"" %1""';
					           |de = 'Die Ansicht der Gruppenmitglieder sollte die gleiche sein wie die der übergeordneten
					           |Gruppe der externen Benutzer ""%1"".'"), Parent);
			EndIf;
		EndDo;
	EndIf;
	
	// Checking whether the external user group has subordinate groups (if its member type is set to 
	// "All users with specified type").
	If AllAuthorizationObjects
		AND ValueIsFilled(Ref) Then
		Query = New Query;
		Query.SetParameter("Ref", Ref);
		Query.Text =
		"SELECT
		|	PRESENTATION(ExternalUsersGroups.Ref) AS RefPresentation
		|FROM
		|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
		|WHERE
		|	ExternalUsersGroups.Parent = &Ref";
		
		QueryResult = Query.Execute();
		If NOT QueryResult.IsEmpty() Then
			Return
				NStr("ru = 'Невозможно изменить тип участников группы,
				           |так как у нее имеются подгруппы.'; 
				           |en = 'Cannot change the type of group 
				           | members as the group contains subgroups.'; 
				           |pl = 'Nie można zmienić rodzaju uczestników grupy,
				           |ponieważ ma ona podgrupy.';
				           |es_ES = 'No se puede cambiar un tipo de participantes del grupo
				           |porque tiene subgrupos.';
				           |es_CO = 'No se puede cambiar un tipo de participantes del grupo
				           |porque tiene subgrupos.';
				           |tr = '"
" grubu alt gruplara sahip olduğundan dolayı katılımcıların türü değiştirilemez.';
				           |it = 'Impossibile modificare il tipo dei membri del gruppo
				           |poiché il gruppo ha dei sottogruppi.';
				           |de = 'Es ist nicht möglich, das Erscheinungsbild der Gruppenmitglieder zu ändern,
				           |da es Untergruppen gibt.'");
		EndIf;
	EndIf;
	
	// Checking whether no subordinate items with another type are available before changing 
	// authorization object type (so that type can be cleared).
	If ValueIsFilled(Ref) Then
		
		Query = New Query;
		Query.SetParameter("Ref", Ref);
		Query.SetParameter("UsersTypes", Purpose);
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
		|	PRESENTATION(ExternalUserGroupsAssignment.Ref) AS RefPresentation
		|FROM
		|	Catalog.ExternalUsersGroups.Purpose AS ExternalUserGroupsAssignment
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				UsersTypes AS UsersTypes
		|			WHERE
		|				ExternalUserGroupsAssignment.Ref.Parent = &Ref
		|				AND VALUETYPE(ExternalUserGroupsAssignment.UsersType) <> VALUETYPE(UsersTypes.UsersType))";
		
		QueryResult = Query.Execute();
		If NOT QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			Selection.Next();
			
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Невозможно изменить тип участников группы,
				           |так как у нее имеется подгруппа ""%1"" с другим назначением участников.'; 
				           |en = 'Cannot change the type of group members
				           |as the group contains the subgroup ""%1"" with different member types.'; 
				           |pl = 'Zmiana rodzaju członków grupy nie jest możliwa,
				           |ponieważ posiada ona podgrupę ""%1"" z innym przydziałem członków.';
				           |es_ES = 'Es necesario cambiar el tipo de los participantes del grupo
				           |porque tiene un subgrupo ""%1"" con otra asignación de usuarios.';
				           |es_CO = 'Es necesario cambiar el tipo de los participantes del grupo
				           |porque tiene un subgrupo ""%1"" con otra asignación de usuarios.';
				           |tr = 'Grup, farklı üye türlerine sahip ""%1"" alt grubunu içerdiğinden
				           |grup üyelerinin türü değiştirilemiyor.';
				           |it = 'Impossibile modificare il tipo dei partecipanti del gruppo
				           |poiché il gruppo ha un sottogruppo ""%1"" con un''assegnazione diversa dei partecipanti.';
				           |de = 'Es ist nicht möglich, das Erscheinungsbild von Gruppenmitgliedern zu ändern,
				           |da sie eine Untergruppe ""%1"" mit einer anderen Teilnehmerzuordnung hat.'"),
				Selection.RefPresentation);
		EndIf;
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion

#EndIf