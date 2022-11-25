#Region Public

// Returns a flag that shows whether external users are enabled  in the application (the 
// UseExternalUsers functional option value).
//
// Returns:
//  Boolean - if True, external users are allowed.
//
Function UseExternalUsers() Export
	
	Return GetFunctionalOption("UseExternalUsers");
	
EndFunction

// See UsersClientServer.CurrentExternalUser. 
Function CurrentExternalUser() Export
	
	Return UsersClientServer.CurrentExternalUser();
	
EndFunction

// Returns a reference to the external user authorization object from the infobase.
// Authorization object is a reference to an infobase object (for example, a counterparty or an 
// individual) associated with an external user.
//
// Parameters:
//  ExternalUser - Undefined - the current external user.
//                      - CatalogRef.ExternalUsers - the specified external user.
//
// Returns:
//  Ref - authorization object of one of the types specified in the property. 
//           "Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObjects.Type".
//
Function GetExternalUserAuthorizationObject(ExternalUser = Undefined) Export
	
	If ExternalUser = Undefined Then
		ExternalUser = UsersClientServer.CurrentExternalUser();
	EndIf;
	
	AuthorizationObject = Common.ObjectAttributesValues(ExternalUser, "AuthorizationObject").AuthorizationObject;
	
	If ValueIsFilled(AuthorizationObject) Then
		If UsersInternal.AuthorizationObjectIsInUse(AuthorizationObject, ExternalUser) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка в базе данных:
				           |Объект авторизации ""%1"" (%2)
				           |установлен для нескольких внешних пользователей.'; 
				           |en = 'Database error:
				           |Authorization object ""%1"" (%2)
				           |is set for multiple external users.'; 
				           |pl = 'Błąd bazy danych:
				           |Obiekt autoryzacji ""%1"" (%2)
				           |jest ustawiony dla kilku użytkowników zewnętrznych.';
				           |es_ES = 'Error de la base de datos:
				           |Objeto de autorización ""%1"" (%2)
				           |está establecido para varios usuarios externos.';
				           |es_CO = 'Error de la base de datos:
				           |Objeto de autorización ""%1"" (%2)
				           |está establecido para varios usuarios externos.';
				           |tr = 'Veritabanı hatası:
				           |Yetkilendirme nesnesi ""%1"" (%2)
				           |birkaç harici kullanıcı için ayarlandı.';
				           |it = 'Errore di database:
				           |L''autorizzazione all''oggetto ""%1"" (%2)
				           |è impostata per utenti esterni multipli.';
				           |de = 'Datenbankfehler:
				           |Das Autorisierungsobjekt ""%1"" (%2)
				           |ist für mehrere externe Benutzer eingestellt.'"),
				AuthorizationObject,
				TypeOf(AuthorizationObject));
		EndIf;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка в базе данных:
			           |Для внешнего пользователя ""%1"" не задан объект авторизации.'; 
			           |en = 'Database error:
			           |No authorization object is specified for external user ""%1"".'; 
			           |pl = 'Błąd w bazie danych: 
			           |Dla zewnętrznego użytkownika ""%1"" nie jest zadany autoryzacji.';
			           |es_ES = 'Error de la base de datos:
			           |Para el usuario externo ""%1"" el objeto de autorización no está establecido.';
			           |es_CO = 'Error de la base de datos:
			           |Para el usuario externo ""%1"" el objeto de autorización no está establecido.';
			           |tr = 'Veritabanı hatası:
			           |Harici kullanıcı için yetkilendirme nesnesi ayarlanmamış ""%1"".';
			           |it = 'Errore database:
			           |Non è indicato nessun oggetto di autorizzazione per l''utente esterno ""%1"".';
			           |de = 'Fehler in der Datenbank:
			           |Dem externen Benutzer ""%1"" ist kein Berechtigungsobjekt zugeordnet.'"),
			ExternalUser);
	EndIf;
	
	Return AuthorizationObject;
	
EndFunction

// It specifies how external users listed as authorization objects in the ExternalUsers catalog are 
// displayed in catalog lists (partners, respondents, and so on).
//
// Parameters:
//  Form - ClientApplicationForm - calling object.
//
Procedure ShowExternalUsersListView(Form) Export
	
	If AccessRight("Read", Metadata.Catalogs.ExternalUsers) Then
		Return;
	EndIf;
	
	// Hiding unavailable information items.
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(Form.List.QueryText);
	Sources = QuerySchema.QueryBatch[0].Operators[0].Sources;
	For Index = 0 To Sources.Count() - 1 Do
		If Sources[Index].Source.TableName = "Catalog.ExternalUsers" Then
			Sources.Delete(Index);
		EndIf;
	EndDo;
	Form.List.QueryText = QuerySchema.GetQueryText();
	
EndProcedure

// Gets a data structure about the authorized external user
//
// Returns:
//  Structure - contains information about the authorized external user.
//
Function ExternalUserAuthorizationData() Export
	
	SetPrivilegedMode(True);
	
	ExternalUser = UsersClientServer.CurrentExternalUser();
	If Not ValueIsFilled(ExternalUser) Then
		Return New Structure;
	EndIf;
	
	IsCounterpartyAuthorization = True;
	AuthorizedCounterparty 		= Catalogs.Counterparties.EmptyRef();
	AuthorizedContactPerson 	= Catalogs.ContactPersons.EmptyRef();
	
	AuthorizationObject = GetExternalUserAuthorizationObject(ExternalUser);
	
	If TypeOf(AuthorizationObject) = Type("CatalogRef.Counterparties") Then
		AuthorizedCounterparty = AuthorizationObject;
	ElsIf TypeOf(AuthorizationObject) = Type("CatalogRef.ContactPersons") Then
		IsCounterpartyAuthorization = False;
		AuthorizedContactPerson = AuthorizationObject;
		AuthorizedCounterparty = Common.ObjectAttributeValue(AuthorizationObject, "Owner");
	Else
		Return New Structure;
	EndIf;
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("IsCounterpartyAuthorization", 	IsCounterpartyAuthorization);
	ReturnStructure.Insert("AuthorizedCounterparty", 		AuthorizedCounterparty);
	ReturnStructure.Insert("AuthorizedContactPerson", 		AuthorizedContactPerson);
	
	Return ReturnStructure;
	
EndFunction

#EndRegion
