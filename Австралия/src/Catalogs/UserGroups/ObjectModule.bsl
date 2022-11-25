#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var PreviousParent; // Value of the group parent before changes, to be used in OnWrite event handler.
                      // 

Var PreviousUserGroupComposition; // User group content (list of users) before changes, to be used in OnWrite event handler.
                                       // 
                                       // 

Var IsNew; // Shows whether a new object was written.
                // Used in OnWrite event handler.

#EndRegion

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	VerifiedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking the parent.
	If Parent = Catalogs.UserGroups.AllUsers Then
		CommonClientServer.AddUserError(Errors,
			"Object.Parent",
			NStr("ru = 'Предопределенная группа ""Все пользователи"" не может быть родителем.'; en = 'Cannot use the predefined group ""All users"" as a parent.'; pl = 'Wstępnie zdefiniowana grupa ""Wszyscy użytkownicy"" nie może być grupą nadrzędną.';es_ES = 'Grupo predefinido ""Todos usuarios"" no puede ser el grupo original.';es_CO = 'Grupo predefinido ""Todos usuarios"" no puede ser el grupo original.';tr = 'Öntanımlı ""Tüm kullanıcılar"" grubu üst grup olarak kullanılamaz.';it = 'Non è possibile utilizzare il gruppo predefinito ""Tutti gli utenti"" come un genitore.';de = 'Die vordefinierte Gruppe ""Alle Benutzer"" darf keine übergeordnete Gruppe sein.'"),
			"");
	EndIf;
	
	// Checking for unfilled and duplicate users.
	VerifiedObjectAttributes.Add("Content.User");
	
	For each CurrentRow In Content Do;
		RowNumber = Content.IndexOf(CurrentRow);
		
		// Checking whether the value is filled.
		If NOT ValueIsFilled(CurrentRow.User) Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("ru = 'Пользователь не выбран.'; en = 'User is not selected.'; pl = 'Użytkownik nie jest wybrany.';es_ES = 'Usuario no seleccionado.';es_CO = 'Usuario no seleccionado.';tr = 'Kullanıcı seçilmedi.';it = 'L''utente non è selezionato.';de = 'Benutzer ist nicht ausgewählt.'"),
				"Object.Content",
				RowNumber,
				NStr("ru = 'Пользователь в строке %1 не выбран.'; en = 'User is not selected in line #%1.'; pl = 'W wierszu %1 nie wybrano użytkownika.';es_ES = 'Usuario en la línea %1 no está seleccionado.';es_CO = 'Usuario en la línea %1 no está seleccionado.';tr = '%1 satırındaki kullanıcı seçilmedi.';it = 'L''utente non è selezionato nella linea #%1.';de = 'Benutzer in Zeile Nr %1 ist nicht ausgewählt.'"));
			Continue;
		EndIf;
		
		// Checking for duplicate values.
		FoundValues = Content.FindRows(New Structure("User", CurrentRow.User));
		If FoundValues.Count() > 1 Then
			CommonClientServer.AddUserError(Errors,
				"Object.Content[%1].User",
				NStr("ru = 'Пользователь повторяется.'; en = 'Duplicate user.'; pl = 'Użytkownik powtarza się.';es_ES = 'Usuario repetido.';es_CO = 'Usuario repetido.';tr = 'Kullanıcı tekrarlandı.';it = 'Utente duplicato.';de = 'Benutzer wird wiederholt.'"),
				"Object.Content",
				RowNumber,
				NStr("ru = 'Пользователь в строке %1 повторяется.'; en = 'Duplicate user in line #%1.'; pl = 'Użytkownik w wierszu %1 powtarza się.';es_ES = 'Usuario en la línea %1 está repetido.';es_CO = 'Usuario en la línea %1 está repetido.';tr = '%1 satırındaki kullanıcı tekrarlandı.';it = 'Utente duplicato nella linea #%1.';de = 'Benutzer in Zeile%1 wird wiederholt.'"));
		EndIf;
	EndDo;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, VerifiedObjectAttributes);
	
EndProcedure

// Cancels actions that cannot be performed on the "All users" group.
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	If Ref = Catalogs.UserGroups.AllUsers Then
		If NOT Parent.IsEmpty() Then
			Raise
				NStr("ru = 'Предопределенная группа ""Все пользователи""
				           |может быть только в корне.'; 
				           |en = 'The position of the predefined group ""All users"" cannot be changed.
				           |It is the root of the group tree.'; 
				           |pl = 'Predefiniowana grupa ""Wszyscy użytkownicy""
				           |może znajdować się tylko w katalogu głównym.';
				           |es_ES = 'Grupo predefinido ""Todos los usuarios""
				           |puede estar solo en la raíz.';
				           |es_CO = 'Grupo predefinido ""Todos los usuarios""
				           |puede estar solo en la raíz.';
				           |tr = 'Ön tanımlı ""Tüm kullanıcılar"" grubu 
				           |sadece kökte olabilir.';
				           |it = 'Il gruppo d''accesso predefinito ""Tutti gli utenti""
				           |può essere solo alla radice.';
				           |de = 'Die vordefinierte Gruppe ""Alle Benutzer""
				           |kann nur im Stammverzeichnis sein.'");
		EndIf;
		If Content.Count() > 0 Then
			Raise
				NStr("ru = 'Добавление пользователей в группу
				           |""Все пользователи"" не поддерживается.'; 
				           |en = 'Cannot add users to group
				           |""All users.""'; 
				           |pl = 'Dodawanie użytkowników do folderu
				           |""Wszyscy użytkownicy"" nie jest obsługiwane.';
				           |es_ES = 'Añadir los usuarios en el grupo
				           |""Todos los usuarios"" no se admite.';
				           |es_CO = 'Añadir los usuarios en el grupo
				           |""Todos los usuarios"" no se admite.';
				           |tr = 'Kullanıcıların ""Tüm kullanıcılar"" 
				           |klasörüne ekleme işlemi desteklenmiyor.';
				           |it = 'Impossibile aggiungere utenti al gruppo
				           |""Tutti gli utenti"".';
				           |de = 'Das Hinzufügen von Benutzern zur Gruppe
				           |""Alle Benutzer"" wird nicht unterstützt.'");
		EndIf;
	Else
		If Parent = Catalogs.UserGroups.AllUsers Then
			Raise
				NStr("ru = 'Предопределенная группа ""Все пользователи""
				           |не может быть родителем.'; 
				           |en = 'Cannot use the predefined group ""All users""
				           |as a parent.'; 
				           |pl = 'Wstępnie zdefiniowana grupa ""Wszyscy użytkownicy""
				           |nie może być grupą nadrzędną.';
				           |es_ES = 'El grupo predeterminado ""Todos los usuarios""
				           |no puede ser padre.';
				           |es_CO = 'El grupo predeterminado ""Todos los usuarios""
				           |no puede ser padre.';
				           |tr = 'Ön tanımlı ""Tüm kullanıcılar"" 
				           |grubu ana grup olamaz.';
				           |it = 'Il gruppo predefinito ""Tutti gli utenti""
				           |non può essere padre.';
				           |de = 'Die vordefinierte Gruppe ""Alle Benutzer""
				           |kann nicht übergeordnet sein.'");
		EndIf;
		
		PreviousParent = ?(
			Ref.IsEmpty(),
			Undefined,
			Common.ObjectAttributeValue(Ref, "Parent"));
			
		If ValueIsFilled(Ref)
		   AND Ref <> Catalogs.UserGroups.AllUsers Then
			
			PreviousUserGroupComposition =
				Common.ObjectAttributeValue(Ref, "Content").Unload();
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ItemsToChange = New Map;
	ModifiedGroups   = New Map;
	
	If Ref <> Catalogs.UserGroups.AllUsers Then
		
		CompositionChanges = UsersInternal.ColumnValueDifferences(
			"User",
			Content.Unload(),
			PreviousUserGroupComposition);
		
		UsersInternal.UpdateUserGroupComposition(
			Ref, CompositionChanges, ItemsToChange, ModifiedGroups);
		
		If PreviousParent <> Parent Then
			
			If ValueIsFilled(Parent) Then
				UsersInternal.UpdateUserGroupComposition(
					Parent, , ItemsToChange, ModifiedGroups);
			EndIf;
			
			If ValueIsFilled(PreviousParent) Then
				UsersInternal.UpdateUserGroupComposition(
					PreviousParent, , ItemsToChange, ModifiedGroups);
			EndIf;
		EndIf;
		
		UsersInternal.UpdateUserGroupCompositionUsage(
			Ref, ItemsToChange, ModifiedGroups);
		
		If Not Users.IsFullUser() Then
			CheckChangeCompositionRight(CompositionChanges);
		EndIf;
	EndIf;
	
	UsersInternal.AfterUserGroupsUpdate(
		ItemsToChange, ModifiedGroups);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckChangeCompositionRight(CompositionChanges)
	
	Query = New Query;
	Query.SetParameter("Users", CompositionChanges);
	Query.Text =
	"SELECT
	|	Users.Description AS Description
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref IN(&Users)
	|	AND NOT Users.Prepared";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	ErrorText =
		NStr("ru = 'Недостаточно прав доступа.
		           |
		           |В состав участников групп пользователей можно добавлять и удалять только
		           |новых (добавленных) пользователей, у которых включен признак Подготовлен.
		           |
		           |Запрещено добавлять и удалять существующих пользователей:'; 
		           |en = 'Insufficient access rights.
		           |
		           |Only new (added) users marked as ""Requires approval"" can be added to or removed from
		           |the list of group members.
		           |
		           |You cannot add or remove the following users:'; 
		           |pl = 'Niewystarczające prawa dostępu.
		           |
		           |Tylko nowych (dodanych) użytkowników oznaczonych jako ""Wymaga zatwierdzenia"" można dodać lub
		           |usunąć z listy członków grupy.
		           |
		           |Nie można dodawać ani usuwać następujących użytkowników:';
		           |es_ES = 'Insuficientes derechos de acceso.
		           |
		           |En el conjunto de los participantes de los grupos de usuarios se puede añadir y eliminar solo
		           |los usuarios nuevos (añadidos) que tienen el atributo Preparado activado.
		           |
		           |Está prohibido añadir y eliminar los usuarios existentes:';
		           |es_CO = 'Insuficientes derechos de acceso.
		           |
		           |En el conjunto de los participantes de los grupos de usuarios se puede añadir y eliminar solo
		           |los usuarios nuevos (añadidos) que tienen el atributo Preparado activado.
		           |
		           |Está prohibido añadir y eliminar los usuarios existentes:';
		           |tr = 'Yeterli erişim izni yok. 
		           |
		           |Kullanıcı grubu katılımcılarına yalnızca 
		           |yeni (eklenen) kullanıcıları ekleyebilir ve silebilirsiniz. 
		           |
		           |Mevcut kullanıcıları eklemek veya kaldırmak yasaktır:';
		           |it = 'Diritti di accesso insufficienti.
		           |
		           |Solo gli utenti nuovi (aggiunti) contrassegnati come ""In attesa di approvazione"" possono essere aggiunti o rimossi dall''elenco
		           |dei membri del gruppo.
		           |
		           |Impossibile aggiungere o rimuovere i seguenti utenti:';
		           |de = 'Nicht genügend Zugriffsrechte.
		           |
		           |Sie können nur
		           |neue (hinzugefügte) Benutzer hinzufügen und löschen, wenn das Attribut Vorbereitet für die Teilnehmer von Benutzergruppen aktiviert ist.
		           |
		           |Es ist verboten, bestehende Benutzer hinzuzufügen oder zu löschen:'");
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		ErrorText = ErrorText + Chars.LF + Selection.Description;
	EndDo;
	
	Raise ErrorText;
	
EndProcedure

#EndRegion

#EndIf
