#Region Internal

///////////////////////////////////////////////////////////////////////////////
// Main procedures and functions.

// The procedure is called during application startup to check whether authorization is possible and 
// to call the filling of CurrentUser and CurrentExternalUser session parameter values.
// The function is also called upon entering a data area.
//
// Returns:
//  String - blank string - an authorization is successfully completed.
//           Populated lines - error details.
//                             1C:Enterprise should be stopped at application startup.
//                             
//
Function AuthenticateCurrentUser(OnStart = False, RegisterInLog = False) Export
	
	If Not OnStart Then
		RefreshReusableValues();
	EndIf;
	
	SetPrivilegedMode(True);
	
	CurrentIBUser = InfoBaseUsers.CurrentUser();
	IsExternalUser = ValueIsFilled(Catalogs.ExternalUsers.FindByAttribute(
		"IBUserID", CurrentIBUser.UUID));
	CheckUserRights(CurrentIBUser, "OnStart", IsExternalUser);
	
	If IsBlankString(CurrentIBUser.Name) Then
		// Authorizing the default user.
		Try
			Values = CurrentUserSessionParameterValues();
		Except
			ErrorInformation = ErrorInfo();
			Return AuthorizationErrorBriefPresentationAfterRegisterInLog(ErrorInformation,
				NStr("ru = 'Не удалось установить параметр сеанса CurrentUser по причине:
				           |""%1"".
				           |
				           |Обратитесь к администратору.'; 
				           |en = 'Cannot set session parameter CurrentUser. Reason:
				           |%1
				           |
				           |Please contact the administrator.'; 
				           |pl = 'Nie udało się ustawić parametr sesji CurrentUser. Powód:
				           |""%1"".
				           |
				           |Skontaktuj się z administratorem.';
				           |es_ES = 'No se ha podido instalar el parámetro de la sesión CurrentUser a causa de:
				           |""%1"".
				           |
				           |Diríjase al administrador.';
				           |es_CO = 'No se ha podido instalar el parámetro de la sesión CurrentUser a causa de:
				           |""%1"".
				           |
				           |Diríjase al administrador.';
				           |tr = 'GeçerliKullanıcı oturum parametresi aşağıdaki nedenle belirlenemedi: 
				           |""%1"". 
				           |
				           | Yöneticiye başvurun.';
				           |it = 'Impossibile impostare i parametri sessione CurrentUser. Motivo:
				           |%1
				           |
				           ||nSi prega di contattare l''amministratore.';
				           |de = 'Der Sitzungsparameter Aktueller Benutzer konnte wegen:
				           |""%1"" nicht gesetzt werden.
				           |
				           |Wenden Sie sich an den Administrator.'"),
				RegisterInLog);
		EndTry;
		If TypeOf(Values) = Type("String") Then
			Return AuthorizationErrorBriefPresentationAfterRegisterInLog(Values, , RegisterInLog);
		EndIf;
		Return SessionParametersSettingResult(RegisterInLog);
	EndIf;
	
	StandardProcessing = True;
	SaaSIntegration.OnAuthorizeNewIBUser(CurrentIBUser, StandardProcessing);
	
	If Not StandardProcessing Then
		Return "";
	EndIf;
	
	FoundUser = Undefined;
	If UserByIDExists(
	       CurrentIBUser.UUID, , FoundUser) Then
		
		// IBUser is found in the catalog.
		If OnStart AND AdministratorRolesAvailable() Then
			SSLSubsystemsIntegration.OnCreateAdministrator(FoundUser,
				NStr("ru = 'При авторизации у пользователя найдены роли администратора.'; en = 'Administrator roles were detected during the user authorization.'; pl = 'Podczas autoryzacji wykryto, że użytkownik posiada role administratora.';es_ES = 'Al autorizar al usuario se le han encontrado los roles de administrador.';es_CO = 'Al autorizar al usuario se le han encontrado los roles de administrador.';tr = 'Kullanıcı yetkilendirildiğinde yönetici rolleri bulundu.';it = 'Durante l''autorizzazione sono stati trovati ruoli di amministratore per l''utente.';de = 'Bei der Autorisierung wurden beim Benutzer Administrator-Rollen gefunden.'"));
		EndIf;
		Return SessionParametersSettingResult(RegisterInLog);
	EndIf;
	
	// Creating Administrator or informing that authorization failed
	IBUsers = InfoBaseUsers.GetUsers();
	
	If IBUsers.Count() > 1
	   AND Not AdministratorRolesAvailable()
	   AND Not AccessRight("Administration", Metadata, CurrentIBUser) Then
		
		// Authorizing user without administrative privileges, which is created earlier in Designer.
		Return AuthorizationErrorBriefPresentationAfterRegisterInLog(
			UserNotFoundInCatalogMessageText(CurrentIBUser.Name),
			, RegisterInLog);
	EndIf;
	
	// Authorizing user with administrative privileges, which is created earlier in Designer.
	If Not AdministratorRolesAvailable() Then
		Return AuthorizationErrorBriefPresentationAfterRegisterInLog(
			NStr("ru = 'Запуск от имени пользователя с правом Администрирование невозможен,
			           |так как он не зарегистрирован в списке пользователей.
			           |
			           |Для ведения списка и настройки прав пользователей предназначен список Пользователи,
			           |режим конфигурирования 1С:Предприятия для этого использовать не следует.'; 
			           |en = 'Cannot start a session on behalf of the user with ""Administration"" right
			           |because this user is not in the user list.
			           |
			           |To manage users and their rights, use the Users list
			           |and do not use Designer.'; 
			           |pl = 'Nie można uruchomić w imieniu użytkownika 
			           |z uprawnieniami administratora, ponieważ nie są oni zarejestrowani na liście użytkowników.
			           |
			           |Aby zachować listę i ustawienia uprawnień użytkowników,
			           |użyj listy Użytkownicy, tryb konfiguracji 1C:Enterprise nie powinien być używany.';
			           |es_ES = 'No se puede iniciar como el usuario con
			           |el derecho de Administración, como no están registrados en la lista de usuarios.
			           |
			           |Para mantener una lista y la configuración de los derechos de usuarios,
			           |utilizar la lista de Usuarios, el modo de la configuración de la 1C:Empresa no tiene que utilizarse.';
			           |es_CO = 'No se puede iniciar como el usuario con
			           |el derecho de Administración, como no están registrados en la lista de usuarios.
			           |
			           |Para mantener una lista y la configuración de los derechos de usuarios,
			           |utilizar la lista de Usuarios, el modo de la configuración de la 1C:Empresa no tiene que utilizarse.';
			           |tr = 'Kullanıcı listesinde kullanıcı olarak kayıtlı olmadıkları için 
			           |Yönetici olarak kullanıcı olarak başlatılamıyor. 
			           |Bir liste ve kullanıcı hakları ayarını korumak için, 
			           |Kullanıcılar listesini kullanın, 
			           |1C: İşletme yapılandırma modu kullanılmamalıdır.';
			           |it = 'L''avvio per conto dell''utente con il diritto Amministrazione non è possibile,
			           |dal momento che non è registrato nell''elenco degli utenti.
			           |
			           |Per il mantenimento dell''elenco e per l''impostazione dei diritti degli utenti si usa l''elenco Utenti,
			           |il regime di configurazione 1C: Enterprise non dovrebbe essere usato.';
			           |de = 'Kann nicht als Benutzer mit dem
			           |Administrationsrecht starten, da er nicht in der Benutzerliste registriert sind.
			           |
			           |Verwenden Sie zum Verwalten von Benutzern und seinen Rechten die
			           |Benutzerliste, der Designer sollte nicht verwendet werden.'"),
			, RegisterInLog);
	EndIf;
	
	Try
		User = Users.CreateAdministrator(CurrentIBUser);
	Except
		ErrorInformation = ErrorInfo();
		Return AuthorizationErrorBriefPresentationAfterRegisterInLog(ErrorInformation,
			NStr("ru = 'Не удалось выполнить автоматическую регистрацию администратора в списке по причине:
			           |""%1"".
			           |
			           |Для ведения списка и настройки прав пользователей предназначен список Пользователи,
			           |режим конфигурирования 1С:Предприятия для этого использовать не следует.'; 
			           |en = 'Cannot automatically register the administrator in the list. Reason:
			           |""%1"".
			           |
			           |Please use the Users list and do not use Designer
			           |to manage users and their rights.'; 
			           |pl = 'Nie udało się wykonać automatyczną rejestrację administratora w liście z powodu:
			           |""%1"".
			           |
			           |Do prowadzenia listy i ustawienia uprawnień użytkowników przeznaczony jest lista Użytkownicy,
			           |tryb konfiguracji 1C:Enterprise dla tego używać nie należy.';
			           |es_ES = 'No se ha podido realizar el registro automático del administrador en la lista a causa de:
			           |""%1"".
			           |
			           |Para llevar la lista y los ajustes de los derechos de usuarios se ha destinado la lista Usuarios
			           |no hay que usar el modo de configurar de 1C:Enterprise para esto.';
			           |es_CO = 'No se ha podido realizar el registro automático del administrador en la lista a causa de:
			           |""%1"".
			           |
			           |Para llevar la lista y los ajustes de los derechos de usuarios se ha destinado la lista Usuarios
			           |no hay que usar el modo de configurar de 1C:Enterprise para esto.';
			           |tr = 'Yönetici listeye otomatik olarak kaydedilemiyor. Nedeni:
			           |""%1"".
			           |
			           |Kullanıcıları ve yetkilerini yönetmek için lütfen Designer''ı değil,
			           |Kullanıcılar listesini kullanın.';
			           |it = 'Non è stato possibile effettuare la registrazione automatica dell''amministratore nell''elenco a causa di:
			           | ""%1"".
			           |
			           |Per la gestione dell''elenco e per la configurazione dei diritti degli utenti è predisposto l''elenco Utenti,
			           |non bisognerebbe usare il regime di configurazione di 1C: Enterprise per questioni del genere.';
			           |de = 'Der Administrator konnte sich aufgrund von:
			           |""%1"" nicht automatisch in der Liste registrieren.
			           |
			           |Verwenden Sie die Liste Benutzer, um die Liste zu verwalten und Benutzerrechte zu konfigurieren,
			           |der Konfigurationsmodus 1C:Enterprise sollte dafür nicht verwendet werden.'"),
			RegisterInLog);
	EndTry;
	
	Comment =
		NStr("ru = 'Выполнен запуск от имени пользователя с ролью ""Полные права"",
		           |который не зарегистрирован в списке пользователей.
		           |Выполнена автоматическая регистрация в списке пользователей.
		           |
		           |Для ведения списка и настройки прав пользователей предназначен список Пользователи,
		           |режим конфигурирования 1С:Предприятия для этого использовать не следует.'; 
		           |en = 'Session started on behalf of the user with ""Full access"" role
		           |that was not in the user list.
		           |The user is added to the list.
		           |
		           |To manage users and their rights, use the Users list
		           |and do not use Designer.'; 
		           |pl = 'Wykonane uruchomienie w imieniu użytkownika z rolą ""Pełne prawa"",
		           |który nie jest zarejestrowany na liście użytkowników.
		           |Wykonana jest automatyczna rejestracja na liście użytkowników.
		           |
		           |Do prowadzenia listy i ustawienia uprawnień użytkowników przeznaczony jest lista Użytkownicy,
		           |tryb konfiguracji 1C: Enterprise dla tego używać nie należy.';
		           |es_ES = 'Se ha realizado el inicio del nombre de usuario con el rol ""Derechos completos""
		           |que no está registrado en la lista de usuarios.
		           |Se ha realizado el registro automático en la lista de usuarios.
		           |
		           |Para llevar y los ajustes de usuarios está destinada Usuarios
		           |no hay que usar el modo de configurar de 1C:Enterprise para esto.';
		           |es_CO = 'Se ha realizado el inicio del nombre de usuario con el rol ""Derechos completos""
		           |que no está registrado en la lista de usuarios.
		           |Se ha realizado el registro automático en la lista de usuarios.
		           |
		           |Para llevar y los ajustes de usuarios está destinada Usuarios
		           |no hay que usar el modo de configurar de 1C:Enterprise para esto.';
		           |tr = 'Kullanıcı listesinde kayıtlı olmayan 
		           |""Tam haklar"" rolüyle kullanıcı adına başlar. 
		           |Kullanıcı listesinde otomatik kayıt yapılır. 
		           |
		           |Bir liste ve kullanıcı hakları ayarını korumak için, 
		           |Kullanıcılar listesini kullanın, 1C: İşletme yapılandırma modu kullanılmamalıdır.';
		           |it = 'Il programma è stato avviato a nome di un utente con ruolo ""Pieni diritti""
		           |che non è registrato nell''elenco degli utenti.
		           |È stata effettuata una registrazione automatica nell''elenco degli utenti.
		           |
		           |Per la gestione dell''elenco e la configurazione dei permessi degli utenti è presupposto l''elenco Utenti,
		           |il regime di configurazione 1C: Enterprise non è da utilizzare per cose simili.';
		           |de = 'Wurde als Benutzer mit der Rolle ""Volle Rechte"" gestartet,
		           |der nicht in der Liste der Benutzer registriert ist.
		           |Die automatische Registrierung in der Liste der Benutzer wird durchgeführt.
		           |
		           |Verwenden Sie die Liste Benutzer, um die Liste zu verwalten und Benutzerrechte zu konfigurieren,
		           |der Konfigurationsmodus 1C:Enterprise sollte dafür nicht verwendet werden.'");
	
	SSLSubsystemsIntegration.AfterWriteAdministratorOnAuthorization(Comment);
	
	WriteLogEvent(
		NStr("ru = 'Пользователи.Администратор зарегистрирован в справочнике Пользователи'; en = 'Users.Administrator registered in Users catalog'; pl = 'Użytkownicy. Administrator jest zarejestrowany w katalogu Użytkownicy';es_ES = 'Usuarios.Administrador se ha registrado en el catálogo de Usuarios';es_CO = 'Usuarios.Administrador se ha registrado en el catálogo de Usuarios';tr = 'Kullanıcılar. Yönetici Kullanıcı kataloğunda kayıtlı';it = 'Utenti.Amministratore è stato registrato nell''elenco Utenti';de = 'Benutzer. Der Administrator ist im Benutzerkatalog registriert'",
		     CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Warning,
		Metadata.Catalogs.Users,
		User,
		Comment);
	
	Return SessionParametersSettingResult(RegisterInLog);
	
EndFunction

// Specifies that a nonstandard method of setting infobase user roles is used.
Function CannotEditRoles() Export
	
	Return UsersInternalCached.Settings().EditRoles <> True;
	
EndFunction

// Checks that the ExternalUser determined type contains references to authorization objects, and 
// not the String type.
//
Function ExternalUsersEmbedded() Export
	
	Return UsersInternalCached.BlankRefsOfAuthorizationObjectTypes().Count() > 0;
	
EndFunction

// Sets initial settings for an infobase user.
//
// Parameters:
//  Username - String - name of an infobase user, for whom settings are saved.
//  IsExternalUser - Boolean - specify True if the infobase user corresponds to an external user 
//                                    (the ExternalUsers item in the directory).
//
Procedure SetInitialSettings(Val Username, IsExternalUser = False) Export
	
	SystemInfo = New SystemInfo;
	
	CurrentMode = Metadata.InterfaceCompatibilityMode;
	Taxi = (CurrentMode = Metadata.ObjectProperties.InterfaceCompatibilityMode.Taxi
		OR CurrentMode = Metadata.ObjectProperties.InterfaceCompatibilityMode.TaxiEnableVersion8_2);
	
	ClientSettings = New ClientSettings;
	ClientSettings.ShowNavigationAndActionsPanels = False;
	ClientSettings.ShowSectionsPanel = True;
	ClientSettings.ApplicationFormsOpenningMode = ApplicationFormsOpenningMode.Tabs;
	
	TaxiSettings = Undefined;
	InterfaceSettings = New CommandInterfaceSettings;
	
	If Taxi Then
		ClientSettings.ClientApplicationInterfaceVariant = ClientApplicationInterfaceVariant.Taxi;
		
		InterfaceSettings.SectionsPanelRepresentation = SectionsPanelRepresentation.PictureAndText;
		
		TaxiSettings = New ClientApplicationInterfaceSettings;
		CompositionSettings = New ClientApplicationInterfaceContentSettings;
		LeftGroup = New ClientApplicationInterfaceContentSettingsGroup;
		LeftGroup.Add(New ClientApplicationInterfaceContentSettingsItem("ToolsPanel"));
		LeftGroup.Add(New ClientApplicationInterfaceContentSettingsItem("SectionsPanel"));
		CompositionSettings.Left.Add(LeftGroup);
		TaxiSettings.SetContent(CompositionSettings);
	Else
		InterfaceSettings.SectionsPanelRepresentation = SectionsPanelRepresentation.Text;
	EndIf;
	
	InitialSettings = New Structure;
	InitialSettings.Insert("ClientSettings",    ClientSettings);
	InitialSettings.Insert("InterfaceSettings", InterfaceSettings);
	InitialSettings.Insert("TaxiSettings",      TaxiSettings);
	InitialSettings.Insert("IsExternalUser", IsExternalUser);
	
	UsersOverridable.OnSetInitialSettings(InitialSettings);
	
	If InitialSettings.ClientSettings <> Undefined Then
		SystemSettingsStorage.Save("Common/ClientSettings", "",
			InitialSettings.ClientSettings, , Username);
	EndIf;
	
	If InitialSettings.InterfaceSettings <> Undefined Then
		SystemSettingsStorage.Save("Common/SectionsPanel/CommandInterfaceSettings", "",
			InitialSettings.InterfaceSettings, , Username);
	EndIf;
		
	If InitialSettings.TaxiSettings <> Undefined Then
		SystemSettingsStorage.Save("Common/ClientApplicationInterfaceSettings", "",
			InitialSettings.TaxiSettings, , Username);
	EndIf;
		
EndProcedure

// Returns error text if the current user has neither the basic rights role nor the administrator role.
// Registers the error in the log.
//
Function ErrorInsufficientRightsForAuthorization(RegisterInLog = True) Export
	
	If IsInRole(Metadata.Roles.FullRights) Then // Do not change to RolesAvailable.
		Return "";
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		BasicRightsRoleName = Metadata.Roles.BasicSSLRightsForExternalUsers.Name;
	Else
		BasicRightsRoleName = Metadata.Roles.BasicSSLRights.Name;
	EndIf;
	
	If IsInRole(BasicRightsRoleName) Then // Do not change to RolesAvailable.
		Return "";
	EndIf;
	
	Return AuthorizationErrorBriefPresentationAfterRegisterInLog(
		NStr("ru = 'Недостаточно прав для входа в программу.
		           |
		           |Обратитесь к администратору.'; 
		           |en = 'Insufficient rights to sign in.
		           |
		           |Please contact the administrator.'; 
		           |pl = 'Nie masz wystarczających uprawnień, aby wejść do programu.
		           |
		           |Skontaktuj się z administratorem.';
		           |es_ES = 'Insuficientes derechos para entrar en el programa.
		           |
		           |Diríjase al administrador.';
		           |es_CO = 'Insuficientes derechos para entrar en el programa.
		           |
		           |Diríjase al administrador.';
		           |tr = 'Uygulamaya giriş için haklar yetersiz. 
		           |
		           | Yöneticiye başvurun.';
		           |it = 'Permessi insufficienti per accedere al programma.
		           |
		           |Rivolgetevi all''amministratore.';
		           |de = 'Zu wenig Zugriffsrechte auf das Programm.
		           |
		           |Wenden Sie sich an den Administrator.'"),
		, RegisterInLog);
	
EndFunction

// Only for a call from the CheckDisableStartupLogicRight procedure of the 
// StandardSubsystemsServerCall common module.
//
Procedure CheckCurrentUserRightsOnAuthorization() Export
	
	CheckUserRights(InfoBaseUsers.CurrentUser(),
		"OnStart", UsersClientServer.IsExternalUserSession());
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For role interface in managed forms.

// For internal use only.
//
Procedure ProcessRolesInterface(Action, Parameters) Export
	
	If Action = "SetRolesReadOnly" Then
		SetRolesReadOnly(Parameters);
		
	ElsIf Action = "SetUpRoleInterfaceOnLoadSettings" Then
		SetUpRoleInterfaceOnLoadSettings(Parameters);
		
	ElsIf Action = "SetUpRoleInterfaceOnFormCreate" Then
		SetUpRoleInterfaceOnCreateForm(Parameters);
		
	ElsIf Action = "SetUpRoleInterfaceOnReadAtServer" Then
		SetUpRoleInterfaceOnReadAtServer(Parameters);
		
	ElsIf Action = "SelectedRolesOnly" Then
		SelectedRolesOnly(Parameters);
		
	ElsIf Action = "GroupBySubsystems" Then
		GroupBySubsystems(Parameters);
		
	ElsIf Action = "RefreshRoleTree" Then
		UpdateRoleTree(Parameters);
		
	ElsIf Action = "UpdateRoleComposition" Then
		UpdateRoleComposition(Parameters);
		
	ElsIf Action = "FillRoles" Then
		FillRoles(Parameters);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка в процедуре UsersInternal.ProcessRolesInterface()
			           |Неверное значение параметра Action: ""%1"".'; 
			           |en = 'Error in procedure UsersInternal.ProcessRolesInterface().
			           |Invalid value of Action parameter: ""%1"".'; 
			           |pl = 'Błąd w procedurze UsersInternal.ProcessRolesInterface().
			           |Niepoprawna wartość parametru Działanie: ""%1"".';
			           |es_ES = 'Error en el procedimiento UsersInternal.ProcessRolesInterface().
			           |Valor incorrecto del parámetro Acción: ""%1"".';
			           |es_CO = 'Error en el procedimiento UsersInternal.ProcessRolesInterface().
			           |Valor incorrecto del parámetro Acción: ""%1"".';
			           |tr = 'KullanıcıServisi.RolArayüzüİşlemcisi () 
			           |prosedüründe bir hata oluştu. Eylem parametresinin yanlış değeri: %1.';
			           |it = 'Errore nella procedura UsersInternal.ProcessRolesInterface().
			           |Valore del parametro Action non valido: ""%1"".';
			           |de = 'Fehler in der Prozedur BenutzerService.BearbeitenSchnittstelleRollen()
			           |Ungültiger Wert für den Aktionsparameter: ""%1"".'"),
			Action);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions.

// Returns a value table with all configuration role names.
//
// Returns:
//  FixedStructure with the following properties:
//      Array - FixedArray - role names.
//      Map - FixedMap - role names with the True value.
//      ValueTable - ValueStorage - contains ValueTable with the following columns:
//                        Name - String - a role name.
//
Function AllRoles() Export
	
	Return UsersInternalCached.AllRoles();
	
EndFunction

// Returns user properties for an infobase user with empty name.
Function UnspecifiedUserProperties() Export
	
	SetPrivilegedMode(True);
	
	Properties = New Structure;
	
	// Reference to found catalog object that matches an unspecified user.
	// 
	Properties.Insert("Ref", Undefined);
	
	// Reference that is used for search and creation of  unspecified user in the Users catalog.
	// 
	Properties.Insert("StandardRef", Catalogs.Users.GetRef(
		New UUID("aa00559e-ad84-4494-88fd-f0826edc46f0")));
	
	// Full name that is set in the Users catalog item when creating an unspecified user.
	// 
	Properties.Insert("FullName", Users.UnspecifiedUserFullName());
	
	// Full name that is used to search for an unspecified user using the old method. Is used to support 
	// old versions of unspecified user. This name does not required changing.
	//  This name does not required changing.
	Properties.Insert("FullNameForSearch", NStr("ru = '<Не указано>'; en = '<Not specified>'; pl = '<Nieokreślono>';es_ES = '<No especificado>';es_CO = '<No especificado>';tr = '<Belirtilmedi>';it = '<Non specificato>';de = '<Nicht eingegeben>'"));
	
	// Searching for infobase user by UUID.
	Query = New Query;
	Query.SetParameter("Ref", Properties.StandardRef);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref = &Ref";
	
	BeginTransaction();
	Try
		If Query.Execute().IsEmpty() Then
			Query.SetParameter("FullName", Properties.FullNameForSearch);
			Query.Text =
			"SELECT TOP 1
			|	Users.Ref
			|FROM
			|	Catalog.Users AS Users
			|WHERE
			|	Users.Description = &FullName";
			Result = Query.Execute();
			
			If NOT Result.IsEmpty() Then
				Selection = Result.Select();
				Selection.Next();
				Properties.Ref = Selection.Ref;
			EndIf;
		Else
			Properties.Ref = Properties.StandardRef;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Properties;
	
EndFunction

// Defines if the item with the specified infobase user UUID exists in the Users or ExternalUsers 
// catalog.
// 
//  The function is used to check the IBUser mapping only
// one item of the Users and ExternalUsers catalogs.
//
// Parameters:
//  UUID - an infobase user ID.
//
//  RefToCurrent - CatalogRef.Users,
//                     CatalogRef.ExternalUsers - exclude the specified ref from the search.
//                       
//                     Undefined - search among all catalog items.
//
//  FoundUser (return value):
//                     Undefined - user does not exist.
//                     CatalogRef.Users,
//                     CatalogRef.ExternalUsers if user is found.
//
//  ServiceUserID - Boolean.
//                     False - check IBUserID.
//                     True - check ServiceUserID.
//
// Returns:
//  Boolean.
//
Function UserByIDExists(UUID,
                                               RefToCurrent = Undefined,
                                               FoundUser = Undefined,
                                               ServiceUserID = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("RefToCurrent", RefToCurrent);
	Query.SetParameter("UUID", UUID);
	Query.Text = 
	"SELECT
	|	Users.Ref AS User
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID = &UUID
	|	AND Users.Ref <> &RefToCurrent
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID = &UUID
	|	AND ExternalUsers.Ref <> &RefToCurrent";
	
	Result = False;
	FoundUser = Undefined;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		FoundUser = Selection.User;
		Result = True;
		Users.FindAmbiguousIBUsers(Undefined, UUID);
	EndIf;
	
	Return Result;
	
EndFunction

// For internal use only.
//
Procedure UpdateAssignmentOnCreateAtServer(Form, AddUsers = True, ExternalUsersOnly = False) Export
	
	Assignment = Form.Object.Purpose;
	
	If Not ExternalUsers.UseExternalUsers() Then
		Assignment.Clear();
		NewRow = Assignment.Add();
		Form.Items.SelectPurpose.Parent.Visible = False;
		NewRow.UsersType = Catalogs.Users.EmptyRef();
	EndIf;
	
	If AddUsers AND Assignment.Count() = 0 Then
		If ExternalUsersOnly Then
			BlankRefs = UsersInternalCached.BlankRefsOfAuthorizationObjectTypes();
			For Each BlankRef In BlankRefs Do
				NewRow = Assignment.Add();
				NewRow.UsersType = BlankRef;
			EndDo;
		Else
			NewRow = Assignment.Add();
			NewRow.UsersType = Catalogs.Users.EmptyRef();
		EndIf;
	EndIf;
	
	If Assignment.Count() <> 0 Then
		PresentationsArray = New Array;
		Index = Assignment.Count() - 1;
		While Index >= 0 Do
			UsersType = Assignment.Get(Index).UsersType;
			If UsersType = Undefined Then
				Assignment.Delete(Index);
			Else
				PresentationsArray.Add(UsersType.Metadata().Synonym);
			EndIf;
			Index = Index - 1;
		EndDo;
		Form.Items.SelectPurpose.Title = StrConcat(PresentationsArray, ", ");
	EndIf;
	
EndProcedure

// Calls the BeforeWriteIBUser event, checks the rights taking into account the data separation mode, 
// and writes the specified infobase user.
//
// Parameters:
//  IBUser - InfobaseUser - an object that is required to be written.
//  IsExternalUser - Boolean - specify True if the infobase user corresponds to an external user 
//                                    (the ExternalUsers item in the directory).
//
Procedure WriteInfobaseUser(InfobaseUser, IsExternalUser = False) Export
	
	SaaSIntegration.BeforeWriteIBUser(InfobaseUser);
	
	CheckUserRights(InfobaseUser, "BeforeWrite", IsExternalUser);
	InfobaseUpdateInternal.SetShowDetailsToNewUserFlag(InfobaseUser.Name);
	InfobaseUser.Write();
	
EndProcedure

// Checks whether roles assignments are filled correctly as well as the rights in the role assignments.
Procedure CheckRoleAssignment(RolesAssignment = Undefined, CheckAll = False, ErrorsList = Undefined) Export
	
	If RolesAssignment = Undefined Then
		RolesAssignment = UsersInternalCached.RolesAssignment();
	EndIf;
	
	ErrorTitle =
		NStr("ru = 'Ошибка в процедуре OnDefineRoleAssignment общего модуля UsersOverridable.'; en = 'Error in procedure OnDefineRoleAssignment of UsersOverridable common module.'; pl = 'Błąd w procedurze OnDefineRoleAssignment wspólnego modułu UsersOverridable.';es_ES = 'Error en el procedimiento OnDefineRoleAssignment del módulo común OnDefineRoleAssignment.';es_CO = 'Error en el procedimiento OnDefineRoleAssignment del módulo común OnDefineRoleAssignment.';tr = 'KullanıcılarYenidenBelirlenen ortak modülünün RolAtamaBelirlenmesi prosedüründe bir hata oluştu.';it = 'Errore nella procedura OnDefineRoleAssignment del modulo generale UsersOverridable.';de = 'Fehler in der Prozedur BeimZuweisenVonRollen des gemeinsamen Moduls BenutzerNeubestimmbar.'");
	
	ErrorText = "";
	
	Assignment = New Structure;
	For Each RolesAssignmentDetails In RolesAssignment Do
		Roles = New Map;
		For Each KeyAndValue In RolesAssignmentDetails.Value Do
			Role = Metadata.Roles.Find(KeyAndValue.Key);
			If Role = Undefined Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'В метаданных не найдена роль ""%1"",
						           |указанная в назначении %2.'; 
						           |en = 'Role ""%1"" specified in assignment %2
						           |is not found in the metadata.'; 
						           |pl = 'W metadanych nie znaleziono rolę ""%1"",
						           |określona w nominacji %2.';
						           |es_ES = 'En los metadatos no se ha encontrado el rol ""%1""
						           |se ha indicado en la asignación %2.';
						           |es_CO = 'En los metadatos no se ha encontrado el rol ""%1""
						           |se ha indicado en la asignación %2.';
						           |tr = 'Metaverilerde, %1 amacında belirtilen rol "
" bulunamadı %2.';
						           |it = 'Il ruolo ""%1"" specificato nell''assegnazione %2
						           |non è stato trovato nei metadati.';
						           |de = '
						           |Die in der %2 Zuweisung angegebene Rolle ""%1"" wird in den Metadaten nicht gefunden.'"),
						KeyAndValue.Key, RolesAssignmentDetails.Key);
				If ErrorsList = Undefined Then
					ErrorText = ErrorText + Chars.LF + Chars.LF + ErrorDescription;
				Else
					ErrorsList.Add(Undefined, ErrorDescription);
				EndIf;
				Continue;
			EndIf;
			Roles.Insert(Role, True);
			For Each AssignmentDetails In Assignment Do
				If AssignmentDetails.Value.Get(Role) = Undefined Then
					Continue;
				EndIf;
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Роль ""%1"" указана более чем в одном назначении:
					           |%2, %3.'; 
					           |en = 'Role ""%1"" is specified in multiple assignments:
					           |%2 and %3.'; 
					           |pl = 'Rola ""%1"" podana w więcej niż jednej nominacji:
					           |%2, %3.';
					           |es_ES = 'El rol ""%1"" está indicado más de una asignación:
					           |%2, %3.';
					           |es_CO = 'El rol ""%1"" está indicado más de una asignación:
					           |%2, %3.';
					           |tr = '""%1"" rolü birden fazla amaçta belirtilmiştir: 
					           |%2, %3.';
					           |it = 'Il ruolo ""%1"" è indicato in più di uno scopo:
					           |%2, %3.';
					           |de = 'Die Rolle von ""%1"" wird in mehr als einer Bezeichnung angegeben:
					           |%2,%3.'"),
					Role.Name, RolesAssignmentDetails.Key, AssignmentDetails.Key);
				If ErrorsList = Undefined Then
					ErrorText = ErrorText + Chars.LF + Chars.LF + ErrorDescription;
				Else
					ErrorsList.Add(Role, ErrorDescription);
				EndIf;
			EndDo;
		EndDo;
		Assignment.Insert(RolesAssignmentDetails.Key, Roles);
	EndDo;
	
	// Checking roles of external users.
	UnavailableRights = New Array;
	UnavailableRights.Add("Administration");
	UnavailableRights.Add("ConfigurationExtensionsAdministration");
	UnavailableRights.Add("UpdateDataBaseConfiguration");
	UnavailableRights.Add("DataAdministration");
	
	CheckRoleRightsList(UnavailableRights, Assignment.ForExternalUsersOnly, ErrorText,
		NStr("ru = 'При проверке ролей только для внешних пользователей найдены ошибки:'; en = 'Errors were found while checking external user roles:'; pl = 'Podczas sprawdzania ról tylko dla użytkowników zewnętrznych znaleziono błędy:';es_ES = 'Al comprobar los roles para los usuarios externos se han encontrado los errores:';es_CO = 'Al comprobar los roles para los usuarios externos se han encontrado los errores:';tr = 'Roller doğrulanırken yalnızca harici kullanıcılar için hatalar bulundu:';it = 'Durante il controllo dei ruoli solo per gli utenti esterni sono stati trovati degli errori:';de = 'Bei der Prüfung von Rollen nur für externe Benutzer wurden Fehler gefunden:'"), ErrorsList);
	
	CheckRoleRightsList(UnavailableRights, Assignment.BothForUsersAndExternalUsers, ErrorText,
		NStr("ru = 'При проверке ролей совместно для пользователей и внешних пользователей найдены ошибки:'; en = 'Errors were found while checking both user and external user roles:'; pl = 'Podczas sprawdzania ról dla użytkowników i użytkowników zewnętrznych znaleziono błędy:';es_ES = 'Al comprobar los roles junto con los usuarios y los usuarios externos se han encontrado errores:';es_CO = 'Al comprobar los roles junto con los usuarios y los usuarios externos se han encontrado errores:';tr = 'Roller doğrulanırken kullanıcılar ve harici kullanıcılar için hatalar bulundu:';it = 'Durante il controllo dei ruoli sia per gli utenti che per gli utenti esterni sono stati trovati degli errori:';de = 'Bei der Überprüfung von gemeinsamen Rollen für Benutzer und externe Benutzer wurden Fehler gefunden:'"), ErrorsList);
	
	// Checking user roles.
	If Common.DataSeparationEnabled() Or CheckAll Then
		Roles = New Map;
		For Each Role In Metadata.Roles Do
			If Assignment.ForSystemAdministratorsOnly.Get(Role) <> Undefined
			 Or Assignment.ForSystemUsersOnly.Get(Role) <> Undefined Then
				Continue;
			EndIf;
			Roles.Insert(Role, True);
		EndDo;
		UnavailableRights = New Array;
		UnavailableRights.Add("Administration");
		UnavailableRights.Add("ConfigurationExtensionsAdministration");
		UnavailableRights.Add("UpdateDataBaseConfiguration");
		UnavailableRights.Add("ThickClient");
		UnavailableRights.Add("ExternalConnection");
		UnavailableRights.Add("Automation");
		UnavailableRights.Add("InteractiveOpenExtDataProcessors");
		UnavailableRights.Add("InteractiveOpenExtReports");
		UnavailableRights.Add("AllFunctionsMode");
		
		SharedData = SharedData();
		CheckRoleRightsList(UnavailableRights, Roles, ErrorText,
			NStr("ru = 'При проверке ролей для пользователей приложения найдены ошибки:'; en = 'Errors were found while checking application user roles:'; pl = 'Podczas sprawdzania ról dla użytkowników aplikacji znaleziono błędy:';es_ES = 'Al comprobar los roles para el usuarios de la aplicación se han encontrado errores:';es_CO = 'Al comprobar los roles para el usuarios de la aplicación se han encontrado errores:';tr = 'Roller doğrulanırken uygulama kullanıcıları için hatalar bulundu:';it = 'Durante il controllo dei ruoli per gli utenti dell''applicazione sono stati trovati degli errori:';de = 'Bei der Überprüfung von Rollen für Anwendungsbenutzer wurden Fehler gefunden:'"), ErrorsList, SharedData);
	EndIf;
	If Not Common.DataSeparationEnabled() Or CheckAll Then
		Roles = New Map;
		For Each Role In Metadata.Roles Do
			If Assignment.ForSystemAdministratorsOnly.Get(Role) <> Undefined
			 Or Assignment.ForExternalUsersOnly.Get(Role) <> Undefined Then
				Continue;
			EndIf;
			Roles.Insert(Role, True);
		EndDo;
		UnavailableRights = New Array;
		UnavailableRights.Add("Administration");
		UnavailableRights.Add("ConfigurationExtensionsAdministration");
		UnavailableRights.Add("UpdateDataBaseConfiguration");
		
		CheckRoleRightsList(UnavailableRights, Roles, ErrorText,
			NStr("ru = 'При проверке ролей для пользователей найдены ошибки:'; en = 'Errors were found while checking user roles:'; pl = 'Podczas sprawdzania ról dla użytkowników znaleziono błędy:';es_ES = 'Al comprobar los roles de usuarios se han encontrado errores:';es_CO = 'Al comprobar los roles de usuarios se han encontrado errores:';tr = 'Roller doğrulanırken kullanıcılar için hatalar bulundu:';it = 'Durante il controllo dei ruoli per gli utenti sono stati trovati degli errori:';de = 'Bei der Überprüfung von Rollen für Benutzer wurden Fehler gefunden:'"), ErrorsList);
		
		CheckRoleRightsList(UnavailableRights, Assignment.BothForUsersAndExternalUsers, ErrorText,
			NStr("ru = 'При проверке ролей совместно для пользователей и внешних пользователей найдены ошибки:'; en = 'Errors were found while checking both user and external user roles:'; pl = 'Podczas sprawdzania ról dla użytkowników i użytkowników zewnętrznych znaleziono błędy:';es_ES = 'Al comprobar los roles junto con los usuarios y los usuarios externos se han encontrado errores:';es_CO = 'Al comprobar los roles junto con los usuarios y los usuarios externos se han encontrado errores:';tr = 'Roller doğrulanırken kullanıcılar ve harici kullanıcılar için hatalar bulundu:';it = 'Durante il controllo dei ruoli sia per gli utenti che per gli utenti esterni sono stati trovati degli errori:';de = 'Bei der Überprüfung von gemeinsamen Rollen für Benutzer und externe Benutzer wurden Fehler gefunden:'"), ErrorsList);
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorTitle + ErrorText;
	EndIf;
	
EndProcedure

// Includes destination user in the users group of the source user.
Procedure CopyUserGroups(Source, Destination) Export
	
	ExternalUser = (TypeOf(Source) = Type("CatalogRef.ExternalUsers"));
	
	Query = New Query;
	If ExternalUser Then
		Query.Text = 
			"SELECT
			|	UserGroupsComposition.Ref AS UsersGroup
			|FROM
			|	Catalog.ExternalUsersGroups.Content AS UserGroupsComposition
			|WHERE
			|	UserGroupsComposition.ExternalUser = &User";
	Else
		Query.Text = 
			"SELECT
			|	UserGroupsComposition.Ref AS UsersGroup
			|FROM
			|	Catalog.UserGroups.Content AS UserGroupsComposition
			|WHERE
			|	UserGroupsComposition.User = &User";
	EndIf;
	Query.SetParameter("User", Source);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	Lock = New DataLock();
	LockItem = Lock.Add("Catalog.UserGroups");
	LockItem.DataSource = QueryResult;
	BeginTransaction();
	Try
		While Selection.Next() Do
			UserGroupObject = Selection.UsersGroup.GetObject();
			Row = UserGroupObject.Content.Add();
			If ExternalUser Then
				Row.ExternalUser = Destination;
			Else
				Row.User = Destination;
			EndIf;
			
			UserGroupObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Universal procedures and functions.

// Returns a reference to an old (or new) object
//
// Parameters:
//  Object - CatalogObject, ...
//  IsNew - Boolean (Return value).
//
Function ObjectRef(Val Object, IsNew = Undefined) Export
	
	Ref = Object.Ref;
	IsNew = NOT ValueIsFilled(Ref);
	
	If IsNew Then
		Ref = Object.GetNewObjectRef();
		
		If NOT ValueIsFilled(Ref) Then
			
			Manager = Common.ObjectManagerByRef(Object.Ref);
			Ref = Manager.GetRef();
			Object.SetNewObjectRef(Ref);
		EndIf;
	EndIf;
	
	Return Ref;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters, Cancel, IsCallBeforeStart) Export
	
	If Not IsCallBeforeStart Then
		SecurityWarningKey = SecurityWarningKeyOnStart();
		If ValueIsFilled(SecurityWarningKey) Then
			Parameters.Insert("SecurityWarningKey", SecurityWarningKey);
		EndIf;
		Return;
	EndIf;
	
	RegisterInLog = Parameters.RetrievedClientParameters <> Undefined
		AND Not Parameters.RetrievedClientParameters.Property("AuthorizationError");
	
	AuthorizationError = AuthenticateCurrentUser(True, RegisterInLog);
	
	If Not ValueIsFilled(AuthorizationError) Then
		DisableInactiveAndOverdueUsers(True, AuthorizationError, RegisterInLog);
	EndIf;
	
	If Not ValueIsFilled(AuthorizationError) Then
		CheckCanSignIn(AuthorizationError);
	EndIf;
	
	If Not ValueIsFilled(AuthorizationError) Then
		If PasswordChangeRequired(AuthorizationError, True, RegisterInLog) Then
			Parameters.Insert("PasswordChangeRequired");
			StandardSubsystemsServerCall.HideDesktopOnStart();
		EndIf;
	EndIf;
	
	If ValueIsFilled(AuthorizationError) Then
		Parameters.Insert("AuthorizationError", AuthorizationError);
		Cancel = True;
	EndIf;
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ExternalUsers.FullName(), "AttributesToSkipInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.ExternalUsersGroups.FullName(), "AttributesToSkipInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.Users.FullName(), "AttributesToSkipInBatchProcessing");
EndProcedure

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("CurrentUser",        "UsersInternal.SessionParametersSetting");
	Handlers.Insert("CurrentExternalUser", "UsersInternal.SessionParametersSetting");
	Handlers.Insert("AuthorizedUser", "UsersInternal.SessionParametersSetting");
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKinds. 
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name                    = "Users";
	AccessKind.Presentation          = NStr("ru = 'Пользователи'; en = 'Users'; pl = 'Użytkownicy';es_ES = 'Usuarios';es_CO = 'Usuarios';tr = 'Kullanıcılar';it = 'Utenti';de = 'Benutzer'");
	AccessKind.ValuesType            = Type("CatalogRef.Users");
	AccessKind.ValuesGroupsType       = Type("CatalogRef.UserGroups");
	AccessKind.MultipleValuesGroups = True; // Should be True, special case.
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name                    = "ExternalUsers";
	AccessKind.Presentation          = NStr("ru = 'Внешние пользователи'; en = 'External users'; pl = 'Użytkownicy zewnętrzni';es_ES = 'Usuarios externos';es_CO = 'Usuarios externos';tr = 'Harici kullanıcılar';it = 'Utenti esterni';de = 'Externe Benutzer'");
	AccessKind.ValuesType            = Type("CatalogRef.ExternalUsers");
	AccessKind.ValuesGroupsType       = Type("CatalogRef.ExternalUsersGroups");
	AccessKind.MultipleValuesGroups = True; // Should be True, special case.
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.ExternalUsers, True);
	Lists.Insert(Metadata.Catalogs.ExternalUsersGroups, True);
	Lists.Insert(Metadata.Catalogs.Users, True);
	
EndProcedure

// See StandardSubsystemsServerCall.OnExecuteStandardPeriodicChecksOnServer 
Procedure OnExecuteStandardDinamicChecksAtServer(Parameters) Export
	
	Parameters.Insert("AuthorizationDenied", False);
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	// Checking whether the account has expired, and it is necessary to exit application.
	
	SetPrivilegedMode(True);
	
	DisableInactiveAndOverdueUsers(True);
	
	PasswordChangeRequired(); // Update the date of the latest activity. 
	
	InfobaseUser = InfoBaseUsers.FindByUUID(
		InfoBaseUsers.CurrentUser().UUID);
	
	If InfobaseUser = Undefined Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			SessionWithoutSeparators = ModuleSaaS.SessionWithoutSeparators();
		Else
			SessionWithoutSeparators = True;
		EndIf;
		
		If Not Common.DataSeparationEnabled()
		 Or Not SessionWithoutSeparators Then
			
			Parameters.AuthorizationDenied = True;
		EndIf;
		
	ElsIf InfobaseUser.StandardAuthentication = False
	        AND InfobaseUser.OSAuthentication          = False
	        AND InfobaseUser.OpenIDAuthentication      = False Then
	
		Parameters.AuthorizationDenied = True;
	EndIf;
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Cannot import to the ExternalUsers catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.ExternalUsers.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
	// Cannot import to the Users catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.Users.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;

	
EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters. 
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	
	StandardAuthentication = 0;
	OSAuthentication = 0;
	OpenIDAuthentication = 0;
	CanSignIn = 0;
	For Each UserDetails In InfoBaseUsers.GetUsers() Do
		StandardAuthentication = StandardAuthentication + UserDetails.StandardAuthentication;
		OSAuthentication = OSAuthentication + UserDetails.OSAuthentication;
		OpenIDAuthentication = OpenIDAuthentication + UserDetails.OpenIDAuthentication;
		CanSignIn = CanSignIn + (UserDetails.StandardAuthentication
			Or UserDetails.OSAuthentication Or UserDetails.OpenIDAuthentication);
	EndDo;
	
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.Users.StandardAuthentication", StandardAuthentication);
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.Users.OSAuthentication", OSAuthentication);
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.Users.OpenIDAuthentication", OpenIDAuthentication);
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.Users.CanSignIn", CanSignIn);

	QueryText = 
	"SELECT
	|	COUNT(1) AS Count
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Invalid";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.Users.Invalid", Selection.Count);
	
	Settings = UsersInternalCached.Settings().Users;
	ExtendedAuthorizationSettingsUsage = Settings.PasswordMustMeetComplexityRequirements
		Or ValueIsFilled(Settings.MinPasswordLength)
		Or ValueIsFilled(Settings.MaxPasswordLifetime)
		Or ValueIsFilled(Settings.MinPasswordLifetime)
		Or ValueIsFilled(Settings.DenyReusingRecentPasswords)
		Or ValueIsFilled(Settings.InactivityPeriodBeforeDenyingAuthorization)
		Or ValueIsFilled(Settings.InactivityPeriodActivationDate);
	
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics(
		"Catalog.Users.ExtendedAuthorizationSettingsUsage",
		ExtendedAuthorizationSettingsUsage);
	
	QueryText = 
	"SELECT
	|	COUNT(1) AS Count
	|FROM
	|	InformationRegister.UsersInfo AS UsersInfo
	|WHERE
	|	UsersInfo.LastActivityDate >= &SliceDate";
	
	Query = New Query(QueryText);
	Query.SetParameter("SliceDate", BegOfDay(CurrentSessionDate() - 30 *60*60*24)); // 30 days.
	Selection = Query.Execute().Select();
	Selection.Next();
	
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.Users.Active", Selection.Count);
	
	QueryText = 
	"SELECT
	|	UsersInfo.LastUsedClient AS ClientUsed,
	|	COUNT(1) AS Count
	|FROM
	|	InformationRegister.UsersInfo AS UsersInfo
	|
	|GROUP BY
	|	UsersInfo.LastUsedClient";
	
	MetadataNamesMap = New Map;
	MetadataNamesMap.Insert("Catalog.Users", QueryText);
	ModuleMonitoringCenter.WriteConfigurationStatistics(MetadataNamesMap);
	
EndProcedure

// See ExportImportDataOverridable.AfterDataImport. 
Procedure AfterImportData(Container) Export
	
	// Reset the decision made by the administrator in the Security warning form.
	If Not Common.DataSeparationEnabled() Then
		AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
		
		If TypeOf(AdministrationParameters.OpenExternalReportsAndDataProcessorsDecisionMade) <> Type("Boolean")
		 Or AdministrationParameters.OpenExternalReportsAndDataProcessorsDecisionMade Then
			
			AdministrationParameters.OpenExternalReportsAndDataProcessorsDecisionMade = False;
			StandardSubsystemsServer.SetAdministrationParameters(AdministrationParameters);
		EndIf;
	EndIf;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.2";
	Handler.Procedure = "UsersInternal.FillUserIDs";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.15";
	Handler.Procedure = "InformationRegisters.UserGroupCompositions.UpdateRegisterData";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.5";
	Handler.Procedure = "InformationRegisters.UserGroupCompositions.UpdateRegisterData";
	
	Handler = Handlers.Add();
	Handler.Version = "1.1.1.2";
	Handler.Procedure = "Users.IfUserGroupsExistSetUsage";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "UsersInternal.ConvertRoleNamesToIDs";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.8";
	Handler.Procedure = "InformationRegisters.UserGroupCompositions.UpdateRegisterData";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.16";
	Handler.InitialFilling = True;
	Handler.Procedure = "UsersInternal.UpdatePredefinedUserContactInformationKinds";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.4.19";
	Handler.Procedure = "UsersInternal.MoveExternalUserGroupsToRoot";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.3";
	Handler.Procedure = "UsersInternal.FillUserAuthenticationProperties";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.42";
	Handler.Procedure = "UsersInternal.AddSystemAdministratorRoleForUsersWithFullAccess";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.16";
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "UsersInternal.ClearShowInListAttributeForAllIBUsers";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.37";
	Handler.InitialFilling = True;
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "UsersInternal.FillExternalUserGroupsAssignment";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.2.30";
	Handler.InitialFilling = True;
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "UsersInternal.MoveDesignerPasswordLengthAndComplexitySettings";
	
	If Common.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.Version = "2.4.1.1";
		Handler.SharedData = True;
		Handler.ExecutionMode = "Seamless";
		Handler.Procedure = "UsersInternal.AddOpenExternalReportsAndDataProcessorsRightForAdministrators";
	Else
		Handler = Handlers.Add();
		Handler.Version = "2.4.1.1";
		Handler.ExecutionMode = "Seamless";
		Handler.Procedure = "UsersInternal.RenameExternalReportAndDataProcessorOpeningSolutionStorageKey";
		Handler.ExecuteInMandatoryGroup = True;
		Handler.Priority = 1;
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	Parameters.Insert("IsFullUser", Users.IsFullUser());
	
EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(Array) Export
	
	Array.Add(Metadata.InformationRegisters.UserGroupCompositions.FullName());
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave. 
Procedure OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient) Export
	
	OnSendData(DataItem, ItemSend, True);
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToMaster. 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	OnSendData(DataItem, ItemSend, False);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave. 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender) Export
	
	OnGetData(DataItem, GetItem, SendBack, True);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster. 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender) Export
	
	OnGetData(DataItem, GetItem, SendBack, False);
	
EndProcedure

// See StandardSubsystemsServer.AfterGetData. 
Procedure AfterGetData(Sender, Cancel, GetFromMasterNode) Export
	
	UpdateExternalUsersRoles();
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If Common.DataSeparationEnabled() Then
		Return; // To-dos are not shown in SaaS mode.
	EndIf;
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not Users.IsFullUser(, True)
		Or ModuleToDoListServer.UserTaskDisabled("InvalidUsersInfo") Then
		Return;
	EndIf;
	
	InvalidUsers = UsersAddedInDesigner();
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.Users.FullName());
	
	For Each Section In Sections Do
		
		UserID = "InvalidUsersInfo" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID  = UserID;
		UserTask.HasUserTasks       = InvalidUsers > 0;
		UserTask.Count     = InvalidUsers;
		UserTask.Presentation  = NStr("ru = 'Некорректные сведения о пользователях'; en = 'Invalid users data'; pl = 'Niepoprawne informacje o użytkownikach';es_ES = 'Información incorrecta sobre los usuarios';es_CO = 'Información incorrecta sobre los usuarios';tr = 'Kullanıcılar hakkında yanlış bilgi';it = 'Dati utenti non validi';de = 'Falsche Informationen zu Benutzern'");
		UserTask.Form          = "Catalog.Users.Form.InfobaseUsers";
		UserTask.Owner       = Section;
		
	EndDo;
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionsKinds. 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	AdditionToDetails =
	"
	|Catalog.ExternalUsers.Read.ExternalUsers
	|Catalog.ExternalUsers.Update.ExternalUsers
	|Catalog.ExternalUsersGroups.Read.ExternalUsers
	|Catalog.UserGroups.Read.Users
	|Catalog.Users.Read.Users
	|Catalog.Users.Update.Users
	|InformationRegister.UserGroupCompositions.Read.ExternalUsers
	|InformationRegister.UserGroupCompositions.Read.Users
	|";
	
	Details = Details + AdditionToDetails;
	
EndProcedure

// The Data exchange subsystem event handlers.

// See DataExchangeOverridable.OnSetUpSubordinateDIBNode. 
Procedure OnSetUpSubordinateDIBNode() Export
	
	ClearNonExistingIBUsersIDs();
	
EndProcedure

// Event handlers of the ReportsOptions subsystem.

// See ReportsOptionsOverridable.CustomizeReportOptions. 
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.UsersInfo);
EndProcedure

// SaaS.JobQueue subsystem's event handlers.

// See JobQueueOverridable.OnReceiveTemplateList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.MonitorUserActivities.Name);
	
EndProcedure

// Event handlers of the AttachableCommands subsystem.

// See GenerationOverridable.OnDefineObjectsWithGenerateObjectCommands. 
Procedure OnDefineObjectsWithCreationBasedOnCommands(Objects) Export
	
	Objects.Add(Metadata.Catalogs.Users);
	
EndProcedure

// Event handlers of the Users subsystem.

// See the ChangeActionsOnForm procedure in the UsersOverridable common module.
Procedure OnDefineActionsInForm(Ref, FormActions) Export
	
	SSLSubsystemsIntegration.OnDefineActionsInForm(Ref, FormActions);
	UsersOverridable.ChangeFormActions(Ref, FormActions);
	
EndProcedure

#EndRegion

#Region Private

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	
	If ParameterName <> "CurrentUser"
	   AND ParameterName <> "CurrentExternalUser"
	   AND ParameterName <> "AuthorizedUser" Then
		
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Try
		Values = CurrentUserSessionParameterValues();
	Except
		ErrorInformation = ErrorInfo();
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось установить параметр сеанса CurrentUser по причине:
			           |""%1"".
			           |
			           |Обратитесь к администратору.'; 
			           |en = 'Cannot set session parameter CurrentUser. Reason:
			           |%1
			           |
			           |Please contact the administrator.'; 
			           |pl = 'Nie udało się ustawić parametr sesji CurrentUser. Reason:
			           |%1
			           |
			           |Skontaktuj się z administratorem..';
			           |es_ES = 'No se ha podido instalar el parámetro de la sesión CurrentUser a causa de:
			           |""%1"".
			           |
			           |Diríjase al administrador.';
			           |es_CO = 'No se ha podido instalar el parámetro de la sesión CurrentUser a causa de:
			           |""%1"".
			           |
			           |Diríjase al administrador.';
			           |tr = 'GeçerliKullanıcı oturum parametresi aşağıdaki nedenle belirlenemedi: 
			           |""%1"". 
			           |
			           | Yöneticiye başvurun.';
			           |it = 'Impossibile impostare i parametri sessione CurrentUser. Motivo:
			           |%1
			           |
			           |Si prega di contattare l''amministratore.';
			           |de = 'Der Sitzungsparameter Aktueller Benutzer konnte wegen:
			           |""%1"" nicht gesetzt werden.
			           |
			           |Wenden Sie sich an den Administrator.'"),
			DetailErrorDescription(ErrorInformation));
	EndTry;
	
	If TypeOf(Values) = Type("String") Then
		Raise Values;
	EndIf;
	
	SessionParameters.CurrentUser        = Values.CurrentUser;
	SessionParameters.CurrentExternalUser = Values.CurrentExternalUser;
	
	If ValueIsFilled(Values.CurrentUser) Then
		SessionParameters.AuthorizedUser = Values.CurrentUser;
	Else
		SessionParameters.AuthorizedUser = Values.CurrentExternalUser;
	EndIf;
	
	SpecifiedParameters.Add("CurrentUser");
	SpecifiedParameters.Add("CurrentExternalUser");
	SpecifiedParameters.Add("AuthorizedUser");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// Runs external user presentation update when its authorization object presentation is changed.
// 
//
// The following authorization object types must be included in the event subscription
// "Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type".
// For example: "CatalogObject.Individuals", "CatalogObject.Counterparties".
//
Procedure UpdateExternalUserPresentationOnWrite(Val Object, Cancel) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Object) Then
		Return;
	EndIf;
	
	UpdateExternalUserPresentation(Object.Ref);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Scheduled job use.

// UsersActivityMonitor scheduled job handler.
Procedure MonitorUserActivities() Export
	
	Common.OnStartExecuteScheduledJob(
		Metadata.ScheduledJobs.MonitorUserActivities);
	
	DisableInactiveAndOverdueUsers();
	
EndProcedure

// Changes the usage of the UsersActivityMonitor scheduled job.
//
// Parameters:
//   Use - Boolean - True if the job must be enabled, otherwise, False.
//
Procedure ChangeUserActivityMonitoringJob(Usage) Export
	
	ScheduledJobsServer.SetPredefinedScheduledJobUsage(
		Metadata.ScheduledJobs.MonitorUserActivities, Usage);
	
EndProcedure

// Called when writing the user or external user, check validity period.
Procedure EnableUserActivityMonitoringJobIfRequired(User) Export
	
	SetPrivilegedMode(True);
	
	If Not UsersInternalCached.Settings().CommonAuthorizationSettings Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("User", User);
	Query.SetParameter("EmptyDate", '00010101');
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.UsersInfo AS UsersInfo
	|WHERE
	|	UsersInfo.User IN(&User)
	|	AND UsersInfo.ValidityPeriod <> &EmptyDate
	|	AND UsersInfo.AutomaticAuthorizationProhibitionDate = &EmptyDate";
	
	If Not Query.Execute().IsEmpty() Then
		ChangeUserActivityMonitoringJob(True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for operations with user authorization settings.

// See the Settings function in the UsersInternalCached common module.
Function AuthorizationSettings() Export
	
	Settings = New Structure;
	// Complexity requirements.
	Settings.Insert("PasswordMustMeetComplexityRequirements", False);
	Settings.Insert("MinPasswordLength", 0);
	// Validity period requirements.
	Settings.Insert("MaxPasswordLifetime", 0);
	Settings.Insert("MinPasswordLifetime", 0);
	Settings.Insert("DenyReusingRecentPasswords", 0);
	// The requirements for the periodic operation in the application.
	Settings.Insert("InactivityPeriodBeforeDenyingAuthorization", 0);
	Settings.Insert("InactivityPeriodActivationDate", '00010101');
	
	SettingsCopy = New FixedStructure(Settings);
	
	PreparedSettings = New Structure;
	PreparedSettings.Insert("Users", New Structure(SettingsCopy));
	PreparedSettings.Insert("ExternalUsers", Settings);
	
	SetPrivilegedMode(True);
	SavedSettings = Constants.UserAuthorizationSettings.Get().Get();
	SetPrivilegedMode(False);
	If TypeOf(SavedSettings) <> Type("Structure") Then
		Return PreparedSettings;
	EndIf;
	
	For Each PreparedSetting In PreparedSettings Do
		If Not SavedSettings.Property(PreparedSetting.Key)
		 Or TypeOf(SavedSettings[PreparedSetting.Key]) <> Type("Structure") Then
			Continue;
		EndIf;
		InitialSettings = PreparedSetting.Value;
		CurrentSettings = SavedSettings[PreparedSetting.Key];
		
		If TypeOf(CurrentSettings) = Type("Structure") Then
			For Each InitialSetting In InitialSettings Do
				
				If Not CurrentSettings.Property(InitialSetting.Key)
				 Or TypeOf(CurrentSettings[InitialSetting.Key]) <> TypeOf(InitialSetting.Value) Then
					
					Continue;
				EndIf;
				
				InitialSettings[InitialSetting.Key] = CurrentSettings[InitialSetting.Key];
			EndDo;
		EndIf;
	EndDo;
	
	Return PreparedSettings;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure and function for operations with password.

// Generates a new password matching the set rules of complexity checking .
// For easier memorization, a password is formed from syllables (consonant-vowel).
//
// Parameters:
//  PasswordParameters - Structure - returns from the PasswordParameters function.
//  RNG - RandomNumbersGenerator - if it is already used.
//                  - Undefined - create a new one.
//
// Returns:
//  String - a new password.
//
Function CreatePassword(PasswordParameters, RNG = Undefined) Export
	
	NewPassword = "";
	
	LowercaseConsonants               = PasswordParameters.LowercaseConsonants;
	UppercaseConsonants              = PasswordParameters.UppercaseConsonants;
	LowercaseConsonantsCount     = StrLen(LowercaseConsonants);
	UppercaseConsonantsCount    = StrLen(UppercaseConsonants);
	UseConsonants           = (LowercaseConsonantsCount > 0)
	                                  OR (UppercaseConsonantsCount > 0);
	
	LowercaseVowels                 = PasswordParameters.LowercaseVowels;
	UppercaseVowels                = PasswordParameters.UppercaseVowels;
	LowercaseVowelsCount       = StrLen(LowercaseVowels);
	UppercaseVowelsCount      = StrLen(UppercaseVowels);
	UseVowels             = (LowercaseVowelsCount > 0) 
	                                  OR (UppercaseVowelsCount > 0);
	
	Numbers                   = PasswordParameters.Digits;
	DigitCount          = StrLen(Numbers);
	UseNumbers       = (DigitCount > 0);
	
	SpecialChars             = PasswordParameters.SpecialChars;
	SpecialCharCount  = StrLen(SpecialChars);
	UseSpecialChars = (SpecialCharCount > 0);
	
	// Creating a random number generation.
	If RNG = Undefined Then
		RNG = New RandomNumberGenerator();
	EndIf;
	
	Counter = 0;
	
	MaxLength           = PasswordParameters.MaxLength;
	MinLength            = PasswordParameters.MinLength;
	
	// Determining the position of special characters and digits.
	If PasswordParameters.CheckComplexityConditions Then
		SetLowercase      = PasswordParameters.LowercaseLettersCheckExistence;
		SetUppercase     = PasswordParameters.UppercaseLettersCheckIfExist;
		SetDigit         = PasswordParameters.NumbersCheckExistence;
		SetSpecialChar    = PasswordParameters.SpecialCharsCheckExistense;
	Else
		SetLowercase      = (LowercaseVowelsCount > 0) 
		                          OR (LowercaseConsonantsCount > 0);
		SetUppercase     = (UppercaseVowelsCount > 0) 
		                          OR (UppercaseConsonantsCount > 0);
		SetDigit         = UseNumbers;
		SetSpecialChar    = UseSpecialChars;
	EndIf;
	
	While Counter < MaxLength Do
		
		// Start from the consonant.
		If UseConsonants Then
			If SetUppercase AND SetLowercase Then
				SearchString = LowercaseConsonants + UppercaseConsonants;
				UpperBoundary = LowercaseConsonantsCount + UppercaseConsonantsCount;
			ElsIf SetUppercase Then
				SearchString = UppercaseConsonants;
				UpperBoundary = UppercaseConsonantsCount;
			Else
				SearchString = LowercaseConsonants;
				UpperBoundary = LowercaseConsonantsCount;
			EndIf;
			If IsBlankString(SearchString) Then
				SearchString = LowercaseConsonants + UppercaseConsonants;
				UpperBoundary = LowercaseConsonantsCount + UppercaseConsonantsCount;
			EndIf;
			Char = Mid(SearchString, RNG.RandomNumber(1, UpperBoundary), 1);
			If Char = Upper(Char) Then
				If SetUppercase Then
					SetUppercase = (RNG.RandomNumber(0, 1) = 1);
				EndIf;
			Else
				SetLowercase = False;
			EndIf;
			NewPassword = NewPassword + Char;
			Counter     = Counter + 1;
			If Counter >= MinLength Then
				Break;
			EndIf;
		EndIf;
		
		// Adding vowels.
		If UseVowels Then
			If SetUppercase AND SetLowercase Then
				SearchString = LowercaseVowels + UppercaseVowels;
				UpperBoundary = LowercaseVowelsCount + UppercaseVowelsCount;
			ElsIf SetUppercase Then
				SearchString = UppercaseVowels;
				UpperBoundary = UppercaseVowelsCount;
			Else
				SearchString = LowercaseVowels;
				UpperBoundary = LowercaseVowelsCount;
			EndIf;
			If IsBlankString(SearchString) Then
				SearchString = LowercaseVowels + UppercaseVowels;
				UpperBoundary = LowercaseVowelsCount + UppercaseVowelsCount;
			EndIf;
			Char = Mid(SearchString, RNG.RandomNumber(1, UpperBoundary), 1);
			If Char = Upper(Char) Then
				SetUppercase = False;
			Else
				SetLowercase = False;
			EndIf;
			NewPassword = NewPassword + Char;
			Counter     = Counter + 1;
			If Counter >= MinLength Then
				Break;
			EndIf;
		EndIf;
	
		// Adding numbers.
		If UseNumbers AND SetDigit Then
			SetDigit = (RNG.RandomNumber(0, 1) = 1);
			Char          = Mid(Numbers, RNG.RandomNumber(1, DigitCount), 1);
			NewPassword     = NewPassword + Char;
			Counter         = Counter + 1;
			If Counter >= MinLength Then
				Break;
			EndIf;
		EndIf;
		
		// Adding special characters.
		If UseSpecialChars AND SetSpecialChar Then
			SetSpecialChar = (RNG.RandomNumber(0, 1) = 1);
			Char      = Mid(SpecialChars, RNG.RandomNumber(1, SpecialCharCount), 1);
			NewPassword = NewPassword + Char;
			Counter     = Counter + 1;
			If Counter >= MinLength Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	Return NewPassword;
	
EndFunction

// Returns standard parameters considering length and complexity.
//
// Parameters:
//  MinimumLength - Number - the password minimum length (7 by default).
//  Complex - Boolean - consider password complexity checking requirements.
//
// Returns:
//  Structure - parameters of password creation.
//
Function PasswordParameters(MinLength = 7, Complex = False) Export
	
	PasswordParameters = New Structure();
	PasswordParameters.Insert("MinLength",                MinLength);
	PasswordParameters.Insert("MaxLength",               99);
	PasswordParameters.Insert("LowercaseVowels",            "aeiouy"); 
	PasswordParameters.Insert("UppercaseVowels",           "AEIOUY");
	PasswordParameters.Insert("LowercaseConsonants",          "bcdfghjklmnpqrstvwxz");
	PasswordParameters.Insert("UppercaseConsonants",         "BCDFGHJKLMNPQRSTVWXZ");
	PasswordParameters.Insert("Digits",                           "0123456789");
	PasswordParameters.Insert("SpecialChars",                     " _.,!?");
	PasswordParameters.Insert("CheckComplexityConditions",       Complex);
	PasswordParameters.Insert("UppercaseLettersCheckIfExist",  True);
	PasswordParameters.Insert("LowercaseLettersCheckExistence",   True);
	PasswordParameters.Insert("NumbersCheckExistence",           True);
	PasswordParameters.Insert("SpecialCharsCheckExistense",     False);
	
	Return PasswordParameters;
	
EndFunction

// Checks for an account and rights required for changing a password.
//
// Parameters:
//  User - CatalogRef.Users,
//                 CatalogRef.ExternalUsers - a user to change the password.
//
//  AdditionalParameters - Structure - (return value) with the following properties:
//   * ErrorText - String - an error description, if you cannot change the password.
//   * IBUserID - UUID - an infobase user ID.
//   * IsCurrentIBUser    - Boolean - True if it is the current user.
//
// Returns:
//  Boolean - Fales, if you cannot change a password.
//
Function CanChangePassword(User, AdditionalParameters = Undefined) Export
	
	If TypeOf(AdditionalParameters) <> Type("Structure") Then
		AdditionalParameters = New Structure;
	EndIf;
	
	If Not AdditionalParameters.Property("IsInternalUser")
	   AND Common.DataSeparationEnabled()
	   AND Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ActionsWithSaaSUser = ModuleUsersInternalSaaS.GetActionsWithSaaSUser(
			User);
		
		If Not ActionsWithSaaSUser.ChangePassword Then
			AdditionalParameters.Insert("ErrorText", StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Сервис: Недостаточно прав для изменения пароля пользователя ""%1"".'; en = 'Service: insufficient rights to change the password for user ""%1.""'; pl = 'Serwis: Brak wystarczających uprawnień aby zmienić hasło użytkownika ""%1"".';es_ES = 'Servicio: Insuficientes derechos para cambiar la contraseña del usuario ""%1"".';es_CO = 'Servicio: Insuficientes derechos para cambiar la contraseña del usuario ""%1"".';tr = 'Servis: ""%1"" kullanıcı şifresinin değişikliği için haklar yetersizdir.';it = 'Servizio: Permessi insufficienti per modificare la password dell''utente ""%1"".';de = 'Service: Nicht genügend Rechte, um das Benutzerpasswort ""%1"" zu ändern.'"), User));
			Return False;
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	UserAttributes = Common.ObjectAttributesValues(
		User, "Ref, Invalid, IBUserID, Prepared");
	
	If UserAttributes.Ref <> User Then
		UserAttributes.Ref = Common.ObjectManagerByRef(User).EmptyRef();
		UserAttributes.Invalid = False;
		UserAttributes.Prepared = False;
		UserAttributes.IBUserID =
			New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;
	
	If AdditionalParameters.Property("CheckUserValidity")
	   AND UserAttributes.Invalid <> False Then
		
		AdditionalParameters.Insert("ErrorText", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Пользователь ""%1"" недействителен.'; en = 'User ""%1"" is invalid.'; pl = 'Użytkownik ""%1"" nieprawidłowy.';es_ES = 'El usuario ""%1"" no válido.';es_CO = 'El usuario ""%1"" no válido.';tr = '""%1"" kullanıcısı geçersizdir.';it = 'L''utente ""%1"" non è valido.';de = 'Der Benutzer ""%1"" ist ungültig.'"), User));
		Return False;
	EndIf;
	
	IBUserID = UserAttributes.IBUserID;
	InfobaseUser = InfoBaseUsers.FindByUUID(IBUserID);
	
	SetPrivilegedMode(False);
	
	If AdditionalParameters.Property("CheckIBUserExists")
	   AND InfobaseUser = Undefined Then
		
		AdditionalParameters.Insert("ErrorText", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не найдена учетная запись пользователя ""%1"".'; en = 'Account of user ""%1"" is not found.'; pl = 'Nie można znaleźć konta użytkownika ""%1"".';es_ES = 'No se ha encontrado la cuenta de usuario ""%1"".';es_CO = 'No se ha encontrado la cuenta de usuario ""%1"".';tr = '""%1"" kullanıcının hesabı bulunamadı.';it = 'L''account dell''utente ""%1"" non è stato trovato.';de = 'Benutzerkonto ""%1"" konnte nicht gefunden werden.'"), User));
		Return False;
	EndIf;
	
	AdditionalParameters.Insert("IBUserID", IBUserID);
	
	CurrentIBUserID = InfoBaseUsers.CurrentUser().UUID;
	AdditionalParameters.Insert("IsCurrentIBUser", IBUserID = CurrentIBUserID);
	
	AccessLevel = UserPropertiesAccessLevel(UserAttributes);
	
	If Not AdditionalParameters.IsCurrentIBUser
	   AND Not AccessLevel.AuthorizationSettings Then
		
		AdditionalParameters.Insert("ErrorText", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Недостаточно прав для изменения пароля пользователя ""%1"".'; en = 'Insufficient rights to change password for user ""%1"".'; pl = 'Za mało uprawnień do zmiany hasła użytkownika ""%1"".';es_ES = 'Insuficientes derechos para cambiar la contraseña del usuario ""%1"".';es_CO = 'Insuficientes derechos para cambiar la contraseña del usuario ""%1"".';tr = '""%1"" kullanıcı şifresinin değişikliği için haklar yetersizdir.';it = 'Permessi insufficienti per modificare la password dell''utente ""%1"".';de = 'Nicht genügend Rechte, um das Benutzerpasswort ""%1"" zu ändern.'"), User));
		Return False;
	EndIf;
	
	AdditionalParameters.Insert("PasswordIsSet",
		InfobaseUser <> Undefined AND InfobaseUser.PasswordIsSet);
	
	If InfobaseUser <> Undefined AND InfobaseUser.CannotChangePassword Then
		If AccessLevel.AuthorizationSettings Then
			If AdditionalParameters.Property("IncludeCannotChangePasswordProperty") Then
				AdditionalParameters.Insert("ErrorText", StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Установлен запрет изменения пароля пользователя ""%1"".'; en = 'User ""%1"" cannot change password.'; pl = 'Wprowadzono zakaz zmiany hasła użytkownika ""%1"".';es_ES = 'Está restringido cambiar la contraseña de usuario ""%1"".';es_CO = 'Está restringido cambiar la contraseña de usuario ""%1"".';tr = '""%1"" kullanıcı şifresinin değişikliği için yasak oluşturuldu.';it = 'L''utente ""%1"" non può modificare la password.';de = 'Das Verbot zum Ändern des Benutzerpassworts ""%1"" ist gesetzt.'"), User));
				Return False;
			EndIf;
		Else
			AdditionalParameters.Insert("ErrorText", StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Установлен запрет изменения пароля пользователя ""%1"".
				           |Обратитесь к администратору.'; 
				           |en = 'User ""%1"" cannot change password.
				           |Please contact the administrator.'; 
				           |pl = 'Wprowadzono zakaz zmiany hasła dla użytkownika ""%1"".
				           |Skontaktuj się z administratorem.';
				           |es_ES = 'Está restringido cambiar la contraseña de usuario ""%1"".
				           |Diríjase al administrador.';
				           |es_CO = 'Está restringido cambiar la contraseña de usuario ""%1"".
				           |Diríjase al administrador.';
				           |tr = '""%1"" kullanıcı şifresinin değişikliği için yasak oluşturuldu. 
				           | Yöneticiye başvurun.';
				           |it = 'L''utente ""%1"" non può cambiare la password.
				           |Si prega di contattare l''amministratore.';
				           |de = 'Das Verbot zum Ändern des Benutzerpassworts ""%1"" ist gesetzt.
				           |Wenden Sie sich an den Administrator.'"), User));
			Return False;
		EndIf;
	EndIf;
	
	If AdditionalParameters.Property("IncludeStandardAuthenticationProperty")
	   AND InfobaseUser <> Undefined
	   AND Not InfobaseUser.StandardAuthentication Then
		Return False;
	EndIf;
	
	// Checking minimum password expiration period.
	If AccessLevel.AuthorizationSettings Then
		Return True;
	EndIf;
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		AuthorizationSettings = UsersInternalCached.Settings().ExternalUsers;
	Else
		AuthorizationSettings = UsersInternalCached.Settings().Users;
	EndIf;
	
	If Not ValueIsFilled(AuthorizationSettings.MinPasswordLifetime) Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
	RecordSet.Filter.User.Set(User);
	RecordSet.Read();
	SetPrivilegedMode(False);
	
	If RecordSet.Count() = 0 Then
		Return True;
	EndIf;
	UserInfo = RecordSet[0];
	
	If Not ValueIsFilled(UserInfo.PasswordUsageStartDate) Then
		Return True;
	EndIf;
	
	CurrentSessionDateDayStart = BegOfDay(CurrentSessionDate());
	RemainingMinPasswordLifetime = AuthorizationSettings.MinPasswordLifetime
		- (CurrentSessionDateDayStart - UserInfo.PasswordUsageStartDate) / (24*60*60);
	
	If RemainingMinPasswordLifetime <= 0 Then
		Return True;
	EndIf;
	
	DaysCount = RemainingMinPasswordLifetime;
	
	NumberAndSubject = Format(DaysCount, "NG=") + " "
		+ UsersInternalClientServer.IntegerSubject(DaysCount,
			"", NStr("ru = 'день,дня,дней,,,,,,0'; en = 'day,days,,,0'; pl = 'dzień, dni,,,0';es_ES = 'día,días,,,0';es_CO = 'día,días,,,0';tr = 'gün, gün, gün,,,,,,0';it = 'giorno,giorni,,,0';de = 'Tag, Tag, Tage,,,,,, 0'"));
	
	AdditionalParameters.Insert("ErrorText", StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Пароль можно будет сменить только через %1.'; en = 'You can change the password in %1.'; pl = 'Hasło można zmienić tylko przez %1.';es_ES = 'Se puede cambiar la contraseña solo dentro de %1.';es_CO = 'Se puede cambiar la contraseña solo dentro de %1.';tr = 'Şifre yalnızca %1 sonra değiştirilebilir.';it = 'Non potete modificare la password in %1.';de = 'Passwort kann nur durch %1 geändert werden.'"), NumberAndSubject));
	
	Return False;
	
EndFunction

// For the Users and ExternalUsers document item forms.
Procedure ReadUserInfo(Form) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	User = Form.Object.Ref;
	
	If Not ValueIsFilled(User) Then
		Return;
	EndIf;
	
	AccessLevel = UserPropertiesAccessLevel(Form.Object);
	
	RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
	RecordSet.Filter.User.Set(User);
	RecordSet.Read();
	
	Form.UserMustChangePasswordOnAuthorization             = False;
	Form.UnlimitedValidityPeriod                    = False;
	Form.ValidityPeriod                               = Undefined;
	Form.InactivityPeriodBeforeDenyingAuthorization = 0;
	
	If RecordSet.Count() > 0 Then
		
		If AccessLevel.ListManagement
		 Or AccessLevel.ChangeCurrent Then
		
			FillPropertyValues(Form, RecordSet[0],
				"UserMustChangePasswordOnAuthorization,
				|UnlimitedValidityPeriod,
				|ValidityPeriod,
				|InactivityPeriodBeforeDenyingAuthorization");
		Else
			Form.UserMustChangePasswordOnAuthorization = RecordSet[0].UserMustChangePasswordOnAuthorization;
		EndIf;
	EndIf;
	
EndProcedure

// For the Users and ExternalUsers document item forms.
Procedure WriteUserInfo(Form, CurrentObject) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AccessLevel = UserPropertiesAccessLevel(CurrentObject);
	
	User = CurrentObject.Ref;
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.UsersInfo");
	LockItem.SetValue("User", User);
	BeginTransaction();
	Try
		Lock.Lock();
		RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
		RecordSet.Filter.User.Set(User);
		RecordSet.Read();
		If RecordSet.Count() = 0 Then
			UserInfo = RecordSet.Add();
			UserInfo.User = User;
		Else
			UserInfo = RecordSet[0];
		EndIf;
		
		If AccessLevel.AuthorizationSettings Then
			FillPropertyValues(UserInfo, Form,
				"UserMustChangePasswordOnAuthorization,
				|UnlimitedValidityPeriod,
				|ValidityPeriod,
				|InactivityPeriodBeforeDenyingAuthorization");
		Else
			UserInfo.UserMustChangePasswordOnAuthorization = Form.UserMustChangePasswordOnAuthorization;
		EndIf;
		
		RecordSet.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For the ChangePassword form and before writing infobase user.
// Check the new password, previous password and, in case of success, registers the new password in 
// the list of used passwords, and also sets it if the call is made from the ChangePassword form.
// 
// 
// Parameters:
//  Parameters - Structure - with the following properties:
//   * User - CatalogRef.Users,
//                    CatalogRef.ExternalUsers - when calling from the ChangePassword form.
//                  - CatalogObject.Users,
//                    CatalogRef.ExternalUsers - when writing an object.
//
//   * NewPassword - String - a password that is planned to be set by the infobase user.
//   * PreviousPassword - String - a password that is set for the infobase user (to check).
//
//   * OnAuthorization - Boolean - can be True when calling from the ChangePassword form.
//   * CheckOnly - Boolean - can be True when calling from the ChangePassword form.
//   * OldPasswordMatch - Boolean - (return value) - if False, then it does not match.
//
//   * ServiceUserPassword - String - the password of the current user, when called from the 
//                                          ChangePassword form, is reset on error.
//
// Returns:
//  String - the error text, if it is not a blank row.
//
Function ProcessNewPassword(Parameters) Export
	
	NewPassword  = Parameters.NewPassword;
	OldPassword = Parameters.OldPassword;
	
	AdditionalParameters = New Structure;
	
	If TypeOf(Parameters.User) = Type("CatalogObject.Users")
	 Or TypeOf(Parameters.User) = Type("CatalogObject.ExternalUsers") Then
		
		ObjectRef = Parameters.User.Ref;
		User  = ObjectRef(Parameters.User);
		CallFromChangePasswordForm = False;
		
		If TypeOf(Parameters.User) = Type("CatalogObject.Users")
		   AND Parameters.User.Internal Then
			
			AdditionalParameters.Insert("IsInternalUser");
		EndIf;
	Else
		ObjectRef = Parameters.User;
		User  = Parameters.User;
		CallFromChangePasswordForm = True;
	EndIf;
	
	Parameters.Insert("OldPasswordMatch", False);
	
	If Not CanChangePassword(ObjectRef, AdditionalParameters) Then
		Return AdditionalParameters.ErrorText;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If AdditionalParameters.IsCurrentIBUser
	   AND AdditionalParameters.PasswordIsSet
	   AND (CallFromChangePasswordForm Or OldPassword <> Undefined) Then
		
		PasswordHashString(OldPassword,
			AdditionalParameters.IBUserID, Parameters.OldPasswordMatch);
		
		If Not Parameters.OldPasswordMatch Then
			Return NStr("ru = 'Старый пароль указан неверно.'; en = 'The previous password is incorrect.'; pl = 'Stare hasło jest nieprawidłowe.';es_ES = 'La contraseña antigua está indicada incorrectamente.';es_CO = 'La contraseña antigua está indicada incorrectamente.';tr = 'Eski şifre yanlış belirtilmiştir.';it = 'La password precedente non è corretta.';de = 'Das alte Passwort ist ungültig.'");
		EndIf;
	EndIf;
	
	If UsersInternalCached.Settings().CommonAuthorizationSettings Then
		If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			AuthorizationSettings = UsersInternalCached.Settings().ExternalUsers;
		Else
			AuthorizationSettings = UsersInternalCached.Settings().Users;
		EndIf;
		
		ErrorText = PasswordLengthOrComplexityError(NewPassword,
			AuthorizationSettings.MinPasswordLength,
			AuthorizationSettings.PasswordMustMeetComplexityRequirements);
		
		If ValueIsFilled(ErrorText) Then
			Return ErrorText;
		EndIf;
	EndIf;
	
	ErrorText = PasswordLengthOrComplexityError(NewPassword,
		GetUserPasswordMinLength(),
		GetUserPasswordStrengthCheck());
	
	If ValueIsFilled(ErrorText) Then
		If Not UsersInternalCached.Settings().CommonAuthorizationSettings Then
			Return ErrorText;
		EndIf;
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1
			           |
			           |Ограничение установлено в конфигураторе в меню ""Администрирование"" пункт ""Параметры информационной базы ..."".
			           |Следует очистить минимальную длину и требование сложности пароля в конфигураторе и
			           |задать настройки входа пользователей в настройках программы.'; 
			           |en = '%1
			           |
			           |The restriction is set in Designer (""Administration""—""Infobase parameters"").
			           |Clear the minimum password length and complexity in Designer and
			           |specify the authorization settings in the application settings.'; 
			           |pl = '%1
			           |
			           |Ograniczenie ustawia się w Konfiguratorze w punkcie menu ""Administracja"" ""Parametry bazy informacji ..."".
			           |Należy usunąć minimalną długość i wymaganie złożoności hasła w konfiguratorze i
			           | określić ustawienia logowania użytkownika w ustawieniach programu.';
			           |es_ES = '%1
			           |
			           |La restricción está especificada en el configurador en el menú ""Administración"" del punto ""Parámetros de la base de información ..."".
			           |Hay que eliminar la longitud máxima y la exigencia de la dificultad de la contraseña en el configurador y
			           |especificar los ajustes de entrada de usuarios en los ajustes del programa.';
			           |es_CO = '%1
			           |
			           |La restricción está especificada en el configurador en el menú ""Administración"" del punto ""Parámetros de la base de información ..."".
			           |Hay que eliminar la longitud máxima y la exigencia de la dificultad de la contraseña en el configurador y
			           |especificar los ajustes de entrada de usuarios en los ajustes del programa.';
			           |tr = '%1
			           |
			           |Kısıtlama, ""Yönetim"" menüsünde ""Infobase parametreleri"" maddesinde belirlenmiştir.
			           |Yapılandırıcıdaki minimum uzunluğunu ve şifre karmaşıklığı gereksinimini kaldırın ve
			           |uygulama ayarlarında kullanıcı giriş ayarlarını belirleyin.';
			           |it = '%1
			           |
			           |La limitazione è impostata in Designer (""Amministrazione"" - ""Parametri Infobase"").
			           |Cancellare la lunghezza e la complessità minima della password in Designer
			           |e specificare le impostazioni di autorizzazione nell''applicazione.';
			           |de = '%1
			           |
			           |Die Einschränkung wird im Konfigurator im Menü ""Administration"" unter dem Punkt ""Informationsbasisparameter..."" eingestellt.
			           |Löschen Sie die Mindestlänge und die Komplexität des Passworts im Konfigurator und
			           |legen Sie die Einstellungen für die Benutzeranmeldung in den Programmeinstellungen fest.'"),
			ErrorText);
	EndIf;
	
	ErrorText = "";
	PasswordHash = PasswordHashString(NewPassword);
	
	Lock = New DataLock;
	LockItem = Lock.Add(Metadata.FindByType(TypeOf(User)).FullName());
	LockItem.SetValue("Ref", User);
	LockItem = Lock.Add("InformationRegister.UsersInfo");
	LockItem.SetValue("User", User);
	BeginTransaction();
	Try
		Lock.Lock();
		RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
		RecordSet.Filter.User.Set(User);
		RecordSet.Read();
		If RecordSet.Count() = 0 Then
			UserInfo = RecordSet.Add();
			UserInfo.User = User;
		Else
			UserInfo = RecordSet[0];
		EndIf;
		PreviousPasswords = UserInfo.PreviousPasswords.Get();
		If PreviousPasswords = Undefined Then
			PreviousPasswords = New Array;
		EndIf;
		
		If UsersInternalCached.Settings().CommonAuthorizationSettings
		   AND ValueIsFilled(AuthorizationSettings.DenyReusingRecentPasswords)
		   AND PreviousPasswords.Find(PasswordHash) <> Undefined Then
			
			ErrorText = NStr("ru = 'Новый пароль использовался ранее.'; en = 'The new password has been used before.'; pl = 'Nowe hasło zostało użyte wcześniej.';es_ES = 'La contraseña nueva ha sido usada anteriormente.';es_CO = 'La contraseña nueva ha sido usada anteriormente.';tr = 'Yeni parola daha önce kullanılmıştır.';it = 'La nuova password è stata usata in precedenza.';de = 'Das neue Passwort wurde bereits früher verwendet.'");
			
		ElsIf Not (CallFromChangePasswordForm AND Parameters.CheckOnly) Then
			
			If CallFromChangePasswordForm Then
				IBUserDetails = New Structure;
				IBUserDetails.Insert("Action", "Write");
				IBUserDetails.Insert("Password", NewPassword);
				
				CurrentObject = User.GetObject();
				CurrentObject.AdditionalProperties.Insert("IBUserDetails",
					IBUserDetails);
				
				If Parameters.OnAuthorization Then
					CurrentObject.AdditionalProperties.Insert("ChangePasswordOnAuthorization");
				EndIf;
				If Common.DataSeparationEnabled() Then
					If AdditionalParameters.IsCurrentIBUser Then
						CurrentObject.AdditionalProperties.Insert("ServiceUserPassword",
							OldPassword);
					Else
						CurrentObject.AdditionalProperties.Insert("ServiceUserPassword",
							Parameters.ServiceUserPassword);
					EndIf;
					CurrentObject.AdditionalProperties.Insert("SynchronizeWithService", True);
				EndIf;
				Try
					CurrentObject.Write();
				Except
					Parameters.ServiceUserPassword = Undefined;
					Raise;
				EndTry;
			Else
				UserInfo.PasswordUsageStartDate = Undefined;
				If Parameters.User.AdditionalProperties.Property("ChangePasswordOnAuthorization") Then
					UserInfo.UserMustChangePasswordOnAuthorization = False;
				EndIf;
				If UsersInternalCached.Settings().CommonAuthorizationSettings
				   AND ValueIsFilled(AuthorizationSettings.DenyReusingRecentPasswords) Then
				
					PreviousPasswords.Add(PasswordHash);
					While PreviousPasswords.Count() > AuthorizationSettings.DenyReusingRecentPasswords Do
						PreviousPasswords.Delete(0);
					EndDo;
				Else
					PreviousPasswords.Clear();
				EndIf;
				UserInfo.PreviousPasswords = New ValueStorage(PreviousPasswords);
				RecordSet.Write();
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInformation = ErrorInfo();
		If CallFromChangePasswordForm Then
			WriteLogEvent(
				NStr("ru = 'Пользователи.Ошибка смены пароля'; en = 'Users.Password change error'; pl = 'Użytkownicy.Błąd podczas zmiany hasła';es_ES = 'Usuarios.Error de cambiar la contraseña';es_CO = 'Usuarios.Error de cambiar la contraseña';tr = 'Kullanıcılar. Şifre değiştirme hatası';it = 'Utenti.Errore di modifica password';de = 'Benutzer.Fehler beim Ändern des Passworts'",
				     CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.FindByType(TypeOf(User)),
				User,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось сменить пароль пользователя ""%1"" по причине:
					           |%2'; 
					           |en = 'Cannot change password for user ""%1"". Reason:
					           |%2'; 
					           |pl = 'Nie można zmienić hasła użytkownika ""%1"" z powodu:
					           |%2';
					           |es_ES = 'No se ha podido cambiar la contraseña de usuario ""%1"" a causa de:
					           |%2';
					           |es_CO = 'No se ha podido cambiar la contraseña de usuario ""%1"" a causa de:
					           |%2';
					           |tr = '""%1"" kullanıcı şifresi 
					           |%2 nedeniyle silinemedi';
					           |it = 'Impossibile la modifica password per l''utente ""%1"". Motivo:
					           |%2';
					           |de = 'Das Benutzerpasswort ""%1"" konnte aus diesem Grund nicht geändert werden:
					           |%2'"),
					User, DetailErrorDescription(ErrorInformation)));
			Parameters.Insert("ErrorSavedToEventLog");
		EndIf;
		Raise;
	EndTry;
	
	Return ErrorText;
	
EndFunction

// For the ChangePassword and CanSetNewPassword forms.
Function NewPasswordHint() Export
	
	Return
		NStr("ru = 'Надежный пароль:
		           |- имеет не менее 7 символов;
		           |- содержит любые 3 из 4-х типов символов: заглавные
		           |  буквы, строчные буквы, цифры, специальные символы;
		           |- не совпадает логином.'; 
		           |en = 'A secure password:
		           |- Has at least 7 characters.
		           |- Contains at least 3 out of 4 character types: uppercase
		           |and lowercase letters, numbers, and special characters.
		           |- Is not identical to the username.'; 
		           |pl = 'Silne hasło:
		           |- zawiera co najmniej 7 znaków; 
		           |- zawiera dowolne 3 z 4 typów znaków: wielkie
		           | litery, małe litery, cyfry, znaki specjalne;
		           | - nie pasuje do nazwy (dla danych wejściowych).';
		           |es_ES = 'Contraseña segura:
		           |- tiene no menos de 7 símbolos;
		           |- contiene unos 3 de 4 tipos de símbolos: letras
		           | mayúsculas, letras minúsculas, cifras, símbolos especiales;
		           |- no coincide con el nombre (para entrar).';
		           |es_CO = 'Contraseña segura:
		           |- tiene no menos de 7 símbolos;
		           |- contiene unos 3 de 4 tipos de símbolos: letras
		           | mayúsculas, letras minúsculas, cifras, símbolos especiales;
		           |- no coincide con el nombre (para entrar).';
		           |tr = 'Güvenli şifre: - 
		           |en az 7 karakterden oluşur;
		           |-4 karakter türünden herhangi 3''nü içerir: büyük harfler, 
		           |küçük harfler, sayılar, özel karakterler; 
		           |- adıyla eşleşmez (giriş için).';
		           |it = 'Una password sicura::
		           |- ha non meno di 7 caratteri;
		           |-contiene 3 di questi 4 tipi di caratteri: lettere
		           | maiuscole, lettere minuscole, numeri, caratteri speciali;
		           |- non corrisponde all''username (per l''accesso).';
		           |de = 'Ein sicheres Passwort:
		           |- hat mindestens 7 Zeichen;
		           |- enthält 3 der 4 Zeichentypen: Groß
		           |buchstaben, Kleinbuchstaben, Zahlen, Sonderzeichen;
		           |- entspricht nicht dem Namen (für die Anmeldung).'");
	
EndFunction

// For the Users and ExternalUsers document item forms.
Function HintUserMustChangePasswordOnAuthorization(ForExternalUsers) Export
	
	IsFullUser = Users.IsFullUser(, False);
	
	Tooltip = New Array;
	Tooltip.Add(NStr("ru = 'Требования к длине и сложности пароля задаются отдельно.'; en = 'Requirements to the password length and complexity are specified separately.'; pl = 'Wymagania dotyczące długości i złożoności hasła są ustalane osobno.';es_ES = 'Las exigencias de la longitud y de la complicación de la contraseña se especifican separadamente.';es_CO = 'Las exigencias de la longitud y de la complicación de la contraseña se especifican separadamente.';tr = 'Şifrenin uzunluğu ve karmaşıklığı ile ilgili gereksinimler ayrı belirlenir.';it = 'Le specifiche per la lunghezza e complessità della password sono specificate separatamente.';de = 'Die Anforderungen an die Länge und Komplexität des Passworts werden separat festgelegt.'"));
	Tooltip.Add(Chars.LF);
	
	If Not IsFullUser Then
		Tooltip.Add(NStr("ru = 'За подробностями обратитесь к администратору.'; en = 'For details, contact the administrator.'; pl = 'Aby uzyskać szczegółowe informacje, skontaktuj się z administratorem.';es_ES = 'Para saber los detalles diríjase al administrador.';es_CO = 'Para saber los detalles diríjase al administrador.';tr = 'Detaylı bilgi için yöneticiye başvurun.';it = 'Per dettagli, contattare l''amministratore.';de = 'Wenden Sie sich für weitere Informationen an den Administrator.'"));
		Return New FormattedString(Tooltip);
	EndIf;
	
	Tooltip.Add(NStr("ru = 'См.'; en = 'See'; pl = 'Zobacz';es_ES = 'Véase.';es_CO = 'Véase.';tr = 'Bkz.';it = 'Vedere';de = 'Siehe'"));
	Tooltip.Add(" ");
	
	If Not UsersInternalCached.Settings().CommonAuthorizationSettings Then
		Tooltip.Add(NStr("ru = 'Параметры информационной базы в конфигураторе в меню Администрирование.'; en = 'the infobase parameters in Designer (""Administration"" menu).'; pl = 'Parametry bazy informacyjnej w konfiguratorze w menu Administracja.';es_ES = 'Los parámetros de la base de información en el configurador en el menú Administración.';es_CO = 'Los parámetros de la base de información en el configurador en el menú Administración.';tr = 'Yönetim menüsündeki yapılandırmacıda bulunan veri tabanın parametreleri.';it = 'i parametri infobase in ""Configuratore"" (Menu ""Amministratore"").';de = 'Informationsbasisparameter im Konfigurator im Menü Administration.'"));
		Return New FormattedString(Tooltip);
	EndIf;
	
	If ForExternalUsers Then
		Ref = NStr("ru = 'Настройки входа внешних пользователей'; en = 'External user authorization settings'; pl = 'Ustawienia wejścia użytkowników zewnętrznych';es_ES = 'Ajustes de la entrada de los usuarios externos';es_CO = 'Ajustes de la entrada de los usuarios externos';tr = 'Dış kullanıcıların oturum açma ayarları';it = 'Impostazioni autorizzazione utente esterno';de = 'Einstellungen für die Anmeldung externer Benutzer'");
	Else
		Ref = NStr("ru = 'Настройки входа пользователей'; en = 'Users authorization settings'; pl = 'Ustawienia wejścia użytkowników';es_ES = 'Ajustes de la entrada de usuarios';es_CO = 'Ajustes de la entrada de usuarios';tr = 'Kullanıcı oturum açma ayarları';it = 'Impostazioni autorizzazioni utenti';de = 'Einstellungen für die Benutzeranmeldung'");
	EndIf;
	
	Tooltip.Add(New FormattedString(Ref,,,, "UserAuthorizationSettings"));
	
	If Metadata.Subsystems.Find("Administration") <> Undefined Then
		Tooltip.Add(" ");
		Tooltip.Add(NStr("ru = 'в разделе Администрирование,
			|пункт Настройки прав и пользователей.'; 
			|en = 'in section ""Administration"",
			|""Users and rights settings.""'; 
			|pl = 'w sekcji Administracja,
			|element Ustawienia praw i użytkowników.';
			|es_ES = 'en el apartado Administración,
			|el apartado Ajustes de derechos y usuarios.';
			|es_CO = 'en el apartado Administración,
			|el apartado Ajustes de derechos y usuarios.';
			|tr = '""Yönetim"" bölümünde,
			|Kullanıcı ve yetki ayarları.';
			|it = 'Nella sezione ""Amministrazione"",
			|""Impostazioni utenti e permessi"".';
			|de = 'im Abschnitt ""Einstellungen"",
			|unter dem Punkt ""Benutzer- und Rechteeinstellungen"".'"));
	Else
		Tooltip.Add(".");
	EndIf;
	
	Return New FormattedString(Tooltip);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for user operations.

// For internal use only.
Function AuthorizedUser() Export
	
	SetPrivilegedMode(True);
	
	If Not Common.SeparatedDataUsageAvailable() Then
		ErrorText = CurrentUserUnavailableInSessionWithoutSeparatorsMessageText();
		Raise ErrorText;
	EndIf;
	
	Return ?(ValueIsFilled(SessionParameters.CurrentUser),
	          SessionParameters.CurrentUser,
	          SessionParameters.CurrentExternalUser);
	
EndFunction

// Returns a password hash.
//
// Parameters:
//  Password - String - a password.
//
//  IBUserID - UUID - an infobase user. The method compares the user's password hash with the 
//                                retrieved value and then puts the comparison result to the 
//                                Identical parameter.
//
//  Matches - Boolean - (return value) - see comment to the parameter.
//                                IBUserID.
// Returns:
//  String - a password hash.
//
Function PasswordHashString(Val Password,
                                        Val IBUserID = Undefined,
                                        Matches = False) Export
	
	If Common.DataSeparationEnabled() Then
		DataHashing = New DataHashing(HashFunction.SHA1);
		DataHashing.Append(Password);
		
		PasswordHash = Base64String(DataHashing.HashSum);
		
		DataHashing = New DataHashing(HashFunction.SHA1);
		DataHashing.Append(Upper(Password));
		
		PasswordHash = PasswordHash + ","
			+ Base64String(DataHashing.HashSum);
	Else
		CurrentComplexityCheck = GetUserPasswordStrengthCheck();
		CurrentMinLength  = GetUserPasswordMinLength();
		
		BeginTransaction();
		Try
			If CurrentMinLength > 0 Then
				SetUserPasswordMinLength(0);
			EndIf;
			If CurrentComplexityCheck Then
				SetUserPasswordStrengthCheck(False);
			EndIf;
			
			If Not ValueIsFilled(UserName())
			   AND InfoBaseUsers.GetUsers().Count() = 0 Then
				
				TemporaryIBAdministrator = InfoBaseUsers.CreateUser();
				TemporaryIBAdministrator.StandardAuthentication = True;
				TemporaryIBAdministrator.Roles.Add(Metadata.Roles.Administration);
				TemporaryIBAdministrator.Name = NStr("ru = 'Временный первый администратор'; en = 'Temporary first administrator'; pl = 'Tymczasowy pierwszy administrator';es_ES = 'Primer administrador temporal';es_CO = 'Primer administrador temporal';tr = 'Geçici birinci yönetici';it = 'Primo amministratore temporaneo';de = 'Temporärer Erst-Administrator'")
					+ " (" + String(New UUID) + ")";
				TemporaryIBAdministrator.Write();
			Else
				TemporaryIBAdministrator = Undefined;
			EndIf;
			
			TemporaryIBUser = InfoBaseUsers.CreateUser();
			TemporaryIBUser.StandardAuthentication = False;
			TemporaryIBUser.Password = Password;
			
			TemporaryIBUser.Name = NStr("ru = 'Временный пользователь'; en = 'Temporary user'; pl = 'Tymczasowy użytkownik';es_ES = 'Usuario temporal';es_CO = 'Usuario temporal';tr = 'Geçici kullanıcı';it = 'Utente temporaneo';de = 'Temporärer Benutzer'")
				+ " (" + String(New UUID) + ")";
			
			TemporaryIBUser.Write();
			
			TemporaryIBUser = InfoBaseUsers.FindByUUID(
				TemporaryIBUser.UUID);
			
			PasswordHash = TemporaryIBUser.StoredPasswordValue;
			
			TemporaryIBUser.Delete();
			
			If TemporaryIBAdministrator <> Undefined Then
				TemporaryIBAdministrator.Delete();
			EndIf;
			
			If CurrentMinLength > 0 Then
				SetUserPasswordMinLength(CurrentMinLength);
			EndIf;
			If CurrentComplexityCheck Then
				SetUserPasswordStrengthCheck(True);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			If CurrentMinLength <> GetUserPasswordMinLength() Then
				SetUserPasswordMinLength(CurrentMinLength);
			EndIf;
			If CurrentComplexityCheck <> GetUserPasswordStrengthCheck() Then
				SetUserPasswordStrengthCheck(CurrentComplexityCheck);
			EndIf;
			Raise;
		EndTry;
	EndIf;
	
	If TypeOf(IBUserID) = Type("UUID") Then
		
		InfobaseUser = InfoBaseUsers.FindByUUID(
			IBUserID);
		
		If TypeOf(InfobaseUser) = Type("InfoBaseUser") Then
			Matches = (PasswordHash = InfobaseUser.StoredPasswordValue);
		EndIf;
	EndIf;
	
	Return PasswordHash;
	
EndFunction

// Returns the current access level for changing infobase user properties.
// 
// Parameters:
//  ObjectDetails - CatalogObject.Users -
//                  - CatalogObject.ExternalUsers -
//                  - FormDataStructure - crated from objects specified above.
//
//  ProcessingParameters - Undefined - if Undefined, get data from object description, otherwise get 
//                       data from processing parameters.
//
// Returns:
//  Structure - with the following properties:
//   * SystemAdministrator - Boolean - any action on any user or its infobase user.
//   * FullRights - Boolean - the same rights as for FullAdministrator, except the FullAdministrator right.
//   * ListManagement - Boolean - adding and changing users:
//                                   - For new users without the right to sign in to the application, 
//                                     any property can be edited except for granting the right to sign in.
//                                   - For users with the right to sign in to the application, any 
//                                     property can be edited, except for granting the right to sign 
//                                     in and the authentication settings (see below).
//   * ChangeAuthorizationPermission - Boolean - changing the "Can sign in" flag.
//   * DisableAuthorizationApproval - Boolean - clearing the "Can sign in" flag.
//   * AuthorizationSettings - Boolean - changing the infobase user properties: Name, OSUser, and 
//                                    the properties of OpenIDAuthentication, StandardAuthentication,
//                                    OSAuthentication, and Roles catalog items (if role editing is not prohibited at the development stage).
//   * ChangeCurrentUser - changing Password and Language properties of the current user.
//   * NoAccess - Boolean - the access levels listed above are not available.
//
Function UserPropertiesAccessLevel(ObjectDetails, ProcessingParameters = Undefined) Export
	
	AccessLevel = New Structure;
	
	// Full administrator (all data).
	AccessLevel.Insert("SystemAdministrator", Users.IsFullUser(, True));
	
	// Full access user (business data)
	AccessLevel.Insert("FullRights", Users.IsFullUser());
	
	If TypeOf(ObjectDetails.Ref) = Type("CatalogRef.Users") Then
		// The person responsible for the list of users.
		AccessLevel.Insert("ListManagement",
			AccessRight("Insert", Metadata.Catalogs.Users)
			AND (AccessLevel.FullRights
			   Or Not Users.IsFullUser(ObjectDetails.Ref)));
		// User of the current infobase user.
		AccessLevel.Insert("ChangeCurrent",
			AccessLevel.FullRights
			Or AccessRight("Update", Metadata.Catalogs.Users)
			  AND ObjectDetails.Ref = Users.AuthorizedUser());
		
	ElsIf TypeOf(ObjectDetails.Ref) = Type("CatalogRef.ExternalUsers") Then
		// The person responsible for the list of external users.
		AccessLevel.Insert("ListManagement",
			AccessRight("Insert", Metadata.Catalogs.ExternalUsers)
			AND (AccessLevel.FullRights
			   Or Not Users.IsFullUser(ObjectDetails.Ref)));
		// External user of the current infobase user.
		AccessLevel.Insert("ChangeCurrent",
			AccessLevel.FullRights
			Or AccessRight("Update", Metadata.Catalogs.ExternalUsers)
			  AND ObjectDetails.Ref = Users.AuthorizedUser());
	EndIf;
	
	If ProcessingParameters = Undefined Then
		SetPrivilegedMode(True);
		If ValueIsFilled(ObjectDetails.IBUserID) Then
			InfobaseUser = InfoBaseUsers.FindByUUID(
				ObjectDetails.IBUserID);
		Else
			InfobaseUser = Undefined;
		EndIf;
		UserWithoutAuthorizationSettingsOrPrepared =
			    InfobaseUser = Undefined
			Or ObjectDetails.Prepared
			    AND Not Users.CanSignIn(InfobaseUser);
		SetPrivilegedMode(False);
	Else
		UserWithoutAuthorizationSettingsOrPrepared =
			    Not ProcessingParameters.OldIBUserExists
			Or ProcessingParameters.OldUser.Prepared
			    AND Not Users.CanSignIn(ProcessingParameters.PreviousIBUserDetails);
	EndIf;
	
	AccessLevel.Insert("ChangeAuthorizationPermission",
		    AccessLevel.SystemAdministrator
		Or AccessLevel.FullRights
		  AND Not Users.IsFullUser(ObjectDetails.Ref, True));
	
	AccessLevel.Insert("DisableAuthorizationApproval",
		    AccessLevel.SystemAdministrator
		Or AccessLevel.FullRights
		  AND Not Users.IsFullUser(ObjectDetails.Ref, True)
		Or AccessLevel.ListManagement);
	
	AccessLevel.Insert("AuthorizationSettings",
		    AccessLevel.SystemAdministrator
		Or AccessLevel.FullRights
		  AND Not Users.IsFullUser(ObjectDetails.Ref, True)
		Or AccessLevel.ListManagement
		  AND UserWithoutAuthorizationSettingsOrPrepared);
	
	AccessLevel.Insert("NoAccess",
		  NOT AccessLevel.SystemAdministrator
		AND NOT AccessLevel.FullRights
		AND NOT AccessLevel.ListManagement
		AND NOT AccessLevel.ChangeCurrent
		AND NOT AccessLevel.AuthorizationSettings);
	
	Return AccessLevel;
	
EndFunction

// Checks whether the access level of the specified user is above the level of the current user.
Function UserAccessLevelAbove(UserDetails, CurrentAccessLevel) Export
	
	If TypeOf(UserDetails) = Type("CatalogRef.Users")
	 Or TypeOf(UserDetails) = Type("CatalogRef.ExternalUsers") Then
		
		Return Users.IsFullUser(UserDetails, True, False)
		      AND Not CurrentAccessLevel.SystemAdministrator
		    Or Users.IsFullUser(UserDetails, False, False)
		      AND Not CurrentAccessLevel.FullRights;
	Else
		Return UserDetails.Roles.Find("SystemAdministrator") <> Undefined
		      AND Not CurrentAccessLevel.SystemAdministrator
		    Or UserDetails.Roles.Find("FullRights") <> Undefined
		      AND Not CurrentAccessLevel.FullRights;
	EndIf;
	
EndFunction

// The procedure is called in BeforeWrite handler of User or ExternalUser catalog.
Procedure StartIBUserProcessing(UserObject,
                                        ProcessingParameters,
                                        DeleteUserFromCatalog = False) Export
	
	ProcessingParameters = New Structure;
	AdditionalProperties = UserObject.AdditionalProperties;
	
	ProcessingParameters.Insert("DeleteUserFromCatalog", DeleteUserFromCatalog);
	ProcessingParameters.Insert("InsufficientRightsMessageText",
		NStr("ru = 'Недостаточно прав для изменения пользователя информационной базы.'; en = 'Insufficient rights to change infobase user.'; pl = 'Niewystarczające uprawnienia do zmiany użytkownika na serwisie bazy informacyjnej.';es_ES = 'Insuficientes derechos para cambiar el usuario de la infobase.';es_CO = 'Insuficientes derechos para cambiar el usuario de la infobase.';tr = 'Veritabanı kullanıcısını değiştirmek için yetersiz haklar.';it = 'Autorizzazioni insufficienti per modificare l''utente InfoBase.';de = 'Unzureichende Rechte zum Ändern des infobase-Benutzers.'"));
	
	If AdditionalProperties.Property("CopyingValue")
	   AND ValueIsFilled(AdditionalProperties.CopyingValue)
	   AND TypeOf(AdditionalProperties.CopyingValue) = TypeOf(UserObject.Ref) Then
		
		ProcessingParameters.Insert("CopyingValue", AdditionalProperties.CopyingValue);
	EndIf;
	
	// Catalog attributes that are set automatically (checking that they are not changed)
	AutoAttributes = New Structure;
	AutoAttributes.Insert("IBUserID");
	AutoAttributes.Insert("IBUserProperies");
	ProcessingParameters.Insert("AutoAttributes", AutoAttributes);
	
	// Catalog attributes that cannot be changed in event subscriptions (checking initial values)
	AttributesToLock = New Structure;
	AttributesToLock.Insert("Internal", False); // Value for external user.
	AttributesToLock.Insert("DeletionMark");
	AttributesToLock.Insert("Invalid");
	AttributesToLock.Insert("Prepared");
	ProcessingParameters.Insert("AttributesToLock", AttributesToLock);
	
	RememberUserProperties(UserObject, ProcessingParameters);
	
	AccessLevel = UserPropertiesAccessLevel(UserObject, ProcessingParameters);
	ProcessingParameters.Insert("AccessLevel", AccessLevel);
	
	// BeforeStartIBUserProcessing - SaaS mode support.
	If Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.BeforeStartIBUserProcessing(UserObject, ProcessingParameters);
	EndIf;
	
	If ProcessingParameters.OldUser.Prepared <> UserObject.Prepared
	   AND Not AccessLevel.ChangeAuthorizationPermission Then
		
		Raise ProcessingParameters.InsufficientRightsMessageText;
	EndIf;
	
	// Support of interactive deletion mark and batch modification of DeletionMark and NotValid attributes.
	If ProcessingParameters.OldIBUserExists
	   AND Users.CanSignIn(ProcessingParameters.PreviousIBUserDetails)
	   AND Not AdditionalProperties.Property("IBUserDetails")
	   AND (  ProcessingParameters.OldUser.DeletionMark = False
	      AND UserObject.DeletionMark = True
	    Or ProcessingParameters.OldUser.Invalid = False
	      AND UserObject.Invalid  = True) Then
		
		AdditionalProperties.Insert("IBUserDetails", New Structure);
		AdditionalProperties.IBUserDetails.Insert("Action", "Write");
		AdditionalProperties.IBUserDetails.Insert("CanSignIn", False);
	EndIf;
	
	// Support for the update of the full name of the infobase user when changing description.
	If ProcessingParameters.OldIBUserExists
	   AND Not AdditionalProperties.Property("IBUserDetails")
	   AND ProcessingParameters.PreviousIBUserDetails.FullName
	     <> UserObject.Description Then
		
		AdditionalProperties.Insert("IBUserDetails", New Structure);
		AdditionalProperties.IBUserDetails.Insert("Action", "Write");
	EndIf;
	
	If NOT AdditionalProperties.Property("IBUserDetails") Then
		If AccessLevel.ListManagement
		   AND Not ProcessingParameters.OldIBUserExists
		   AND ValueIsFilled(UserObject.IBUserID) Then
			// Clearing infobase user ID.
			UserObject.IBUserID = Undefined;
			ProcessingParameters.AutoAttributes.IBUserID =
				UserObject.IBUserID;
		EndIf;
		Return;
	EndIf;
	IBUserDetails = AdditionalProperties.IBUserDetails;
	
	If NOT IBUserDetails.Property("Action") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |В параметре IBUserDetails не указано свойство Action.'; 
			           |en = 'Cannot save user ""%1"".
			           |The Action property is not specified in IBUserDetails parameter.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika%1.
			           | W parametrze IBUserDetails właściwość Action nie jest określona.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |En el parámetro IBUserDescription la propiedad de Acción no está especificada.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |En el parámetro IBUserDescription la propiedad de Acción no está especificada.';
			           |tr = 'Kullanıcı kaydedilirken bir hata oluştu %1. 
			           |IBKullanıcıAçıklaması parametresinde Eylem özelliği belirtilmemiş.';
			           |it = 'Errore durante la scrittura dell''utente ""%1"".
			           |Nel parametro DescrizioneUtenteDB non è indicata la proprietà Azione.';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten %1.
			           |Im Parameter IBBenutzerbeschreibung wurde die Aktion-Eigenschaft nicht angegeben.'"),
			UserObject.Ref);
	EndIf;
	
	If IBUserDetails.Action <> "Write"
	   AND IBUserDetails.Action <> "Delete" Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |В параметре IBUserDetails указано
			           |неверное значение ""%2"" свойства Action.'; 
			           |en = 'Cannot save user ""%1"".
			           |Invalid value ""%2"" of property Action
			           |is specified in IBUserDetails parameter.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika %1.
			           |W IBUserDetails
			           |parametr podano niepoprawną wartość %2 właściwości Action.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |En el parámetro
			           |IBUserDescription el valor incorrecto está especificado %2 de la propiedad de Acción.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |En el parámetro
			           |IBUserDescription el valor incorrecto está especificado %2 de la propiedad de Acción.';
			           |tr = 'Kullanıcı yazılırken bir hata oluştu %1. 
			           |IBKullanıcıAçıklaması 
			           |parametresinde Eylem %2özelliği yanlış belirlendi.';
			           |it = 'Errore durante la scrittura dell''utente ""%1"".
			           |Nel parametro DescrizioneUtenteB è indicato
			           |un valore non valido ""%2"" della proprietà Azione.';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten %1.
			           |Im IBBenutzerbeschreibung
			           |Parameter wurde ein falscher Wert der Aktion-Eigenschaft angegeben %2.'"),
			UserObject.Ref,
			IBUserDetails.Action);
	EndIf;
	ProcessingParameters.Insert("Action", IBUserDetails.Action);
	
	SaaSIntegration.OnStartIBUserProcessing(ProcessingParameters, IBUserDetails);
	
	If Not ProcessingParameters.Property("Action") Then
		Return;
	EndIf;
	
	If AccessLevel.NoAccess Then
		Raise ProcessingParameters.InsufficientRightsMessageText;
	EndIf;
	
	If IBUserDetails.Action = "Delete" Then
		
		If Not AccessLevel.ChangeAuthorizationPermission Then
			Raise ProcessingParameters.InsufficientRightsMessageText;
		EndIf;
		
	ElsIf Not AccessLevel.ListManagement Then // Action = "Write"
		
		If Not AccessLevel.ChangeCurrent
		 Or Not ProcessingParameters.OldIBUserCurrent Then
			
			Raise ProcessingParameters.InsufficientRightsMessageText;
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If IBUserDetails.Action = "Write"
	   AND IBUserDetails.Property("UUID")
	   AND ValueIsFilled(IBUserDetails.UUID)
	   AND IBUserDetails.UUID
	     <> ProcessingParameters.OldUser.IBUserID Then
		
		ProcessingParameters.Insert("IBUserSetting");
		
		If ProcessingParameters.OldIBUserExists Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при записи пользователя ""%1"".
				           |Нельзя сопоставить пользователя ИБ с пользователем в справочнике,
				           |с которым уже сопоставлен другой пользователем ИБ.'; 
				           |en = 'Cannot save user ""%1"".
				           |Cannot map the infobase user to the catalog user 
				           |as the catalog user is already mapped to another infobase user.'; 
				           |pl = 'Błąd podczas zapisu użytkownika ""%1"".
				           |Nie można porównać użytkownika IB i użytkownika w wykazie,
				           | z którym już porównano innego użytkownika IB.';
				           |es_ES = 'Ha ocurrido un error al guardar el usuario ""%1"".
				           |Usted no puede emparejar el usuario de la infobase con el usuario en el catálogo
				           |con otro usuario de la infobase ya se había emparejado.';
				           |es_CO = 'Ha ocurrido un error al guardar el usuario ""%1"".
				           |Usted no puede emparejar el usuario de la infobase con el usuario en el catálogo
				           |con otro usuario de la infobase ya se había emparejado.';
				           |tr = 'Kullanıcı kaydedilirken bir hata oluştu %1. 
				           |VT kullanıcısını, başka bir VT kullanıcısının önceden eşleştirildiği dizindeki 
				           |kullanıcıyla eşleştiremezsiniz.';
				           |it = 'Errore durante la scrittura dell''utente ""%1"".
				           |Non è possibile associare un utente del DB ad un utente nell''elenco,
				           |al quale è già associato un altro utente del DB.';
				           |de = 'Fehler bei der Benutzereingabe ""%1"".
				           |Es ist nicht möglich, einen Benutzer der IB mit einem Benutzer in einem Verzeichnis zu verknüpfen,
				           |dem bereits ein anderer Benutzer der IB zugeordnet ist.'"),
				UserObject.Description);
		EndIf;
		
		FoundUser = Undefined;
		
		If UserByIDExists(
			IBUserDetails.UUID,
			UserObject.Ref,
			FoundUser) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при записи пользователя ""%1"".
				           |Нельзя сопоставить пользователя ИБ с этим пользователем в справочнике,
				           |так как он уже сопоставлен с другим пользователем в справочнике
				           |""%2"".'; 
				           |en = 'Cannot save user ""%1"".
				           |Cannot map the infobase user to the catalog user
				           |as the infobase user is already mapped to another catalog user:
				           |""%2""'; 
				           |pl = 'Błąd podczas zapisu użytkownika ""%1"".
				           |Nie można porównać użytkownika IB z tym użytkownikiem w wykazie,
				           |ponieważ jest już porównany z innym użytkownikiem w wykazie
				           |""%2"".';
				           |es_ES = 'Ha ocurrido un error al guardar el usuario ""%1"".
				           |Usted no puede emparejar el usuario de la infobase con este usuario en el catálogo
				           |, porque ya se había emparejado con otro usuario en el directorio
				           |""%2"".';
				           |es_CO = 'Ha ocurrido un error al guardar el usuario ""%1"".
				           |Usted no puede emparejar el usuario de la infobase con este usuario en el catálogo
				           |, porque ya se había emparejado con otro usuario en el directorio
				           |""%2"".';
				           |tr = 'Kullanıcı kaydedilirken bir hata oluştu ""%1"". 
				           |VT kullanıcısı, "
" rehberindeki başka kullanıcı ile daha önce eşleştirildiği için 
				           |""%2""rehberindeki bu kullanıcı ile eşleştirilemez.';
				           |it = 'Errore durante la scrittura dell''utente ""%1"".
				           |Non è possibile associare un utente del DB con questo utente dell''elenco
				           |poiché esso è già associato ad un altro utente nell''elenco
				           |""%2"".';
				           |de = 'Fehler bei der Benutzereingabe ""%1"".
				           |Es ist nicht möglich, den Benutzer der IB diesem Benutzer im Verzeichnis zuzuordnen,
				           |da er bereits einem anderen Benutzer im Verzeichnis
				           |""%2"" zugeordnet ist.'"),
				FoundUser,
				UserObject.Description);
		EndIf;
		
		If Not AccessLevel.FullRights Then
			Raise ProcessingParameters.InsufficientRightsMessageText;
		EndIf;
	EndIf;
	
	If IBUserDetails.Action = "Write" Then
		
		// Checking if user can change users with full access.
		If ProcessingParameters.OldIBUserExists
		   AND UserAccessLevelAbove(ProcessingParameters.PreviousIBUserDetails, AccessLevel) Then
			
			Raise ProcessingParameters.InsufficientRightsMessageText;
		EndIf;
		
		// Checking if unavailable properties can be changed
		If Not AccessLevel.FullRights Then
			ValidProperties = New Structure;
			ValidProperties.Insert("UUID"); // Checked above
			
			If AccessLevel.ChangeCurrent Then
				ValidProperties.Insert("Password");
				ValidProperties.Insert("Language");
			EndIf;
			
			If AccessLevel.ListManagement Then
				ValidProperties.Insert("FullName");
				ValidProperties.Insert("ShowInList");
				ValidProperties.Insert("CannotChangePassword");
				ValidProperties.Insert("Language");
				ValidProperties.Insert("RunMode");
			EndIf;
			
			If AccessLevel.AuthorizationSettings Then
				ValidProperties.Insert("Name");
				ValidProperties.Insert("StandardAuthentication");
				ValidProperties.Insert("Password");
				ValidProperties.Insert("OSAuthentication");
				ValidProperties.Insert("OSUser");
				ValidProperties.Insert("OpenIDAuthentication");
				ValidProperties.Insert("Roles");
			EndIf;
			
			AllProperties = Users.NewIBUserDetails();
			
			For Each KeyAndValue In IBUserDetails Do
				
				If AllProperties.Property(KeyAndValue.Key)
				   AND Not ValidProperties.Property(KeyAndValue.Key) Then
					
					Raise ProcessingParameters.InsufficientRightsMessageText;
				EndIf;
			EndDo;
		EndIf;
		
		WriteIBUser(UserObject, ProcessingParameters);
	Else
		DeleteIBUser(UserObject, ProcessingParameters);
	EndIf;
	
	// Updating value of the attribute that is checked during the writing
	ProcessingParameters.AutoAttributes.IBUserID =
		UserObject.IBUserID;
	
	NewIBUserDetails = Users.IBUserProperies(UserObject.IBUserID);
	If NewIBUserDetails <> Undefined Then
		
		ProcessingParameters.Insert("NewIBUserExists", True);
		ProcessingParameters.Insert("NewIBUserDetails", NewIBUserDetails);
		
		// Checking if user can change users with full access.
		If ProcessingParameters.OldIBUserExists
		   AND UserAccessLevelAbove(ProcessingParameters.NewIBUserDetails, AccessLevel) Then
			
			Raise ProcessingParameters.InsufficientRightsMessageText;
		EndIf;
	Else
		ProcessingParameters.Insert("NewIBUserExists", False);
	EndIf;
	
	// AfterStartIBUserProcessing - SaaS mode support.
	If Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.AfterStartIBUserProcessing(UserObject, ProcessingParameters);
	EndIf;
	
	If ProcessingParameters.Property("CreateAdministrator") Then
		SetPrivilegedMode(True);
		SSLSubsystemsIntegration.OnCreateAdministrator(ObjectRef(UserObject),
			ProcessingParameters.CreateAdministrator);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

// The procedure is called in the OnWrite handler in User or ExternalUser catalog.
Procedure EndIBUserProcessing(UserObject, ProcessingParameters) Export
	
	CheckUserAttributeChanges(UserObject, ProcessingParameters);
	
	// BeforeCompleteIBUserProcessing - SaaS mode support.
	If Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.BeforeEndIBUserProcessing(UserObject, ProcessingParameters);
	EndIf;
	
	If NOT ProcessingParameters.Property("Action") Then
		Return;
	EndIf;
	
	UpdateRoles = True;
	
	// OnCompleteIBUserProcessing - SaaS mode support.
	If Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ModuleUsersInternalSaaS.OnEndIBUserProcessing(
			UserObject, ProcessingParameters, UpdateRoles);
	EndIf;
	
	If ProcessingParameters.Property("IBUserSetting") AND UpdateRoles Then
		ServiceUserPassword = Undefined;
		If UserObject.AdditionalProperties.Property("ServiceUserPassword") Then
			ServiceUserPassword = UserObject.AdditionalProperties.ServiceUserPassword;
		EndIf;
		
		SSLSubsystemsIntegration.AfterSetIBUser(UserObject.Ref,
			ServiceUserPassword);
	EndIf;
	
	If ProcessingParameters.Action = "Write"
	   AND Users.CanSignIn(ProcessingParameters.NewIBUserDetails) Then
		
		SetPrivilegedMode(True);
		UpdateInfoOnUserAllowedToSignIn(UserObject.Ref,
			Not ProcessingParameters.OldIBUserExists
			Or Not Users.CanSignIn(ProcessingParameters.PreviousIBUserDetails));
		SetPrivilegedMode(False);
	EndIf;
	
	CopyIBUserSettings(UserObject, ProcessingParameters);
	
EndProcedure

// The procedure is called when processing the IBUserProperties user property in a catalog.
// 
// Parameters:
//  UserDetails - CatalogObject.Users, CatalogObject.ExternalUsers,
//                           FormDataStructure, contains the IBUserProperies property.
//                         - CatalogRef.Users, CatalogRef.ExternalUsers - from the object that 
//                           requires to read the IBUserProperies.
//  CanAuthorize - Boolean - if False is specified, but True is saved, then authentication 
//                           properties are certainly False, because they were removed in the configurator.
//
// Returns:
//  Structure.
//
Function StoredIBUserProperties(UserDetails, CanSignIn = False) Export
	
	Properties = New Structure;
	Properties.Insert("CanSignIn",    False);
	Properties.Insert("StandardAuthentication", False);
	Properties.Insert("OpenIDAuthentication",      False);
	Properties.Insert("OSAuthentication",          False);
	
	If TypeOf(UserDetails) = Type("CatalogRef.Users")
	 Or TypeOf(UserDetails) = Type("CatalogRef.ExternalUsers") Then
		
		PropertyStorage = Common.ObjectAttributeValue(
			UserDetails, "IBUserProperies");
	Else
		PropertyStorage = UserDetails.IBUserProperies;
	EndIf;
	
	If TypeOf(PropertyStorage) <> Type("ValueStorage") Then
		Return Properties;
	EndIf;
	
	SavedProperties = PropertyStorage.Get();
	
	If TypeOf(SavedProperties) <> Type("Structure") Then
		Return Properties;
	EndIf;
	
	For each KeyAndValue In Properties Do
		If SavedProperties.Property(KeyAndValue.Key)
		   AND TypeOf(SavedProperties[KeyAndValue.Key]) = Type("Boolean") Then
			
			Properties[KeyAndValue.Key] = SavedProperties[KeyAndValue.Key];
		EndIf;
	EndDo;
	
	If Properties.CanSignIn AND Not CanSignIn Then
		Properties.Insert("StandardAuthentication", False);
		Properties.Insert("OpenIDAuthentication",      False);
		Properties.Insert("OSAuthentication",          False);
	EndIf;
	
	Return Properties;
	
EndFunction

// Cannot be called from background jobs with empty user.
Function CreateFirstAdministratorRequired(Val IBUserDetails,
                                              Text = Undefined) Export
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	CurrentIBUser = InfoBaseUsers.CurrentUser();
	
	If NOT ValueIsFilled(CurrentIBUser.Name)
	   AND InfoBaseUsers.GetUsers().Count() = 0 Then
		
		If TypeOf(IBUserDetails) = Type("Structure") Then
			// Checking before writing user or infobase user without administrative privileges.
			
			If IBUserDetails.Property("Roles") Then
				Roles = IBUserDetails.Roles;
			Else
				Roles = New Array;
			EndIf;
			
			If CannotEditRoles()
				OR Roles.Find("FullRights") = Undefined
				OR Roles.Find("SystemAdministrator") = Undefined Then
				
				// Preparing text of the question that is displayed when writing the first administrator.
				Text =
					NStr("ru = 'В список пользователей программы добавляется первый пользователь, поэтому ему
					           |автоматически будут назначены роли ""Администратор системы"" и ""Полные права"".
					           |Продолжить?'; 
					           |en = 'You are adding the first user to the list of application users.
					           |Therefore, the user will be automatically granted ""Full access"" and ""System administrator"" roles.
					           |Do you want to continue?'; 
					           |pl = 'Do listy użytkowników programu zostanie dodany pierwszy użytkownik, więc do niego
					           | automatycznie zostaną przypisane role ""Administrator systemu"" i ""Pełne prawa"".
					           |Kontynuować?';
					           |es_ES = 'En la lista de usuarios del programa se añade el primer usuario por eso se le
					           |asignarán automáticamente los roles ""Administrador del sistema"" y ""Derechos completos"".
					           |¿Continuar?';
					           |es_CO = 'En la lista de usuarios del programa se añade el primer usuario por eso se le
					           |asignarán automáticamente los roles ""Administrador del sistema"" y ""Derechos completos"".
					           |¿Continuar?';
					           |tr = 'Uygulama kullanıcıların listesine ilk kullanıcı eklendiğinden dolayı, 
					           |kendisine ""Sistem yöneticisi"" ve ""Tam haklar"" rolleri otomatik olarak atanacaktır. 
					           | Devam et?';
					           |it = 'Nell''elenco degli utenti del programma è stato aggiunto il primo utente, perciò ad esso
					           |verranno assegnati automaticamente i ruoli ""Amministratore di sistema"" e ""Pieni diritti"".
					           |Continuare?';
					           |de = 'Der erste Benutzer wird der Liste der Benutzer des Programms hinzugefügt, so dass ihm
					           |automatisch die Rollen ""Systemadministrator"" und ""Volle Rechte"" zugewiesen werden.
					           |Fortsetzen?'");
				
				If NOT CannotEditRoles() Then
					Return True;
				EndIf;
				
				SSLSubsystemsIntegration.OnDefineQuestionTextBeforeWriteFirstAdministrator(Text);
				
				Return True;
			EndIf;
		Else
			// Checking user rights before writing an external user
			Text = NStr("ru = 'Первый пользователь информационной базы должен иметь полные права.
			                   |Внешний пользователь не может быть полноправным.
			                   |Сначала создайте администратора в справочнике Пользователи.'; 
			                   |en = 'The first infobase user must have the full access right.
			                   |External users cannot have this right.
			                   |Before creating an external user, create an administrator in the Users catalog.'; 
			                   |pl = 'Pierwszy użytkownik bazy informacyjnej musi posiadać pełne uprawnienia. 
			                   |Użytkownik zewnętrzny nie może posiadać pełnych uprawnień.
			                   | Najpierw utwórz administratora w katalogu Użytkownicy.';
			                   |es_ES = 'El primer usuario de la aplicación tiene que ser un administrador con el rol de ""Acceso completo"".
			                   |Este rol no puede otorgarse a los usuarios externos.
			                   |Por favor, crear el primer usuario en el catálogo de Usuarios.';
			                   |es_CO = 'El primer usuario de la aplicación tiene que ser un administrador con el rol de ""Acceso completo"".
			                   |Este rol no puede otorgarse a los usuarios externos.
			                   |Por favor, crear el primer usuario en el catálogo de Usuarios.';
			                   |tr = 'İlk uygulama kullanıcısı ""Tam erişim"" rolüne sahip bir yönetici olmalıdır. 
			                   |Bu rol harici kullanıcılara verilemez. 
			                   |Lütfen Kullanıcılar kataloğunda ilk kullanıcıyı oluşturun.';
			                   |it = 'Il primo utente dell''infobase deve avere diritto di accesso completo.
			                   |Gli utenti esterni non possono avere questi diritti.
			                   |Prima di creare un utente esterno, crea un amministratore nel catalogo Utenti.';
			                   |de = 'Der erste Anwendungsbenutzer muss ein Administrator mit der Rolle ""Vollzugriff"" sein.
			                   |Diese Rolle kann nicht für externe Benutzer vergeben werden.
			                   |Bitte erstellen Sie den ersten Benutzer im Benutzerkatalog.'");
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Checks availability of administrator roles based on SaaS mode.
Function AdministratorRolesAvailable(InfobaseUser = Undefined) Export
	
	If InfobaseUser = Undefined
	 Or InfobaseUser = InfoBaseUsers.CurrentUser() Then
	
		Return IsInRole(Metadata.Roles.FullRights)          // Do not change to RolesAvailable.
		     AND (IsInRole(Metadata.Roles.SystemAdministrator) // Do not change to RolesAvailable.
		        Or Common.DataSeparationEnabled() );
	EndIf;
	
	Return InfobaseUser.Roles.Contains(Metadata.Roles.FullRights)
	     AND (InfobaseUser.Roles.Contains(Metadata.Roles.SystemAdministrator)
	        Or Common.DataSeparationEnabled() );
	
EndFunction

// Creates a user <Not specifier>.
//
// Returns:
//  CatalogRef.Users - a reference to the <Not specified> user.
// 
Function CreateUnspecifiedUser() Export
	
	UnspecifiedUserProperties = UnspecifiedUserProperties();
	
	If Common.RefExists(UnspecifiedUserProperties.StandardRef) Then
		
		Return UnspecifiedUserProperties.StandardRef;
		
	Else
		
		NewUser = Catalogs.Users.CreateItem();
		NewUser.Internal = True;
		NewUser.Description = UnspecifiedUserProperties.FullName;
		NewUser.SetNewObjectRef(UnspecifiedUserProperties.StandardRef);
		NewUser.DataExchange.Load = True;
		NewUser.Write();
		
		Return NewUser.Ref;
		
	EndIf;
	
EndFunction

// Checks whether the infobase user description structure is filled correctly.
// If errors are found, sets the Cancel parameter to True and sends error messages.
// 
//
// Parameters:
//  IBUserDetails - Structure - infobase user description, the fillnig of which needs to be checked.
//                 
//
//  Cancel - Boolean - a flag of cancelling the operation.
//                 It is set if errors are found.
//
// Returns:
//  Boolean - if True, errors are not found.
//
Function CheckIBUserDetails(Val IBUserDetails, Cancel) Export
	
	If IBUserDetails.Property("Name") Then
		Name = IBUserDetails.Name;
		
		If IsBlankString(Name) Then
			// The settings storage uses only the first 64 characters of the infobase user name.
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не заполнено Имя (для входа).'; en = 'The username is required.'; pl = 'Nie wprowadzono loginu.';es_ES = 'Nombre de usuario no introducido.';es_CO = 'Nombre de usuario no introducido.';tr = 'İsim (giriş için) girilmedi.';it = 'Il nome utente è richiesto';de = 'Login ist nicht eingetragen.'"),
				,
				"Name",
				,
				Cancel);
			
		ElsIf StrLen(Name) > 64 Then
			// Web authentication uses the ":" character as a separator between a user name and a password.
			// 
			CommonClientServer.MessageToUser(
				NStr("ru = 'Имя (для входа) превышает 64 символа.'; en = 'The username exceeds 64 characters.'; pl = 'Login nie może przekraczać 64 znaków.';es_ES = 'Nombre de usuario no puede exceder 64 símbolos.';es_CO = 'Nombre de usuario no puede exceder 64 símbolos.';tr = 'Kullanıcı adı 64 karakterden uzun olamaz.';it = 'Il nome utente eccede 64 caratteri.';de = 'Login darf 64 Zeichen nicht überschreiten.'"),
				,
				"Name",
				,
				Cancel);
			
		ElsIf StrFind(Name, ":") > 0 Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Имя (для входа) содержит запрещенный символ "":"".'; en = 'The username contains an illegal character "":"".'; pl = 'Login zawiera nieprawidłowy znak "":"".';es_ES = 'Nombre de usuario contiene símbolos inválidos "":"".';es_CO = 'Nombre de usuario contiene símbolos inválidos "":"".';tr = 'Kullanıcı adı yanlış karakter "":"" içeriyor.';it = 'Il nome utente contiene un carattere vietato "":"".';de = 'Login enthält ungültige Zeichen "":"".'"),
				,
				"Name",
				,
				Cancel);
				
		Else
			SetPrivilegedMode(True);
			InfobaseUser = InfoBaseUsers.FindByName(Name);
			SetPrivilegedMode(False);
			
			If InfobaseUser <> Undefined
			   AND InfobaseUser.UUID
			     <> IBUserDetails.IBUserID Then
				
				FoundUser = Undefined;
				UserByIDExists(
					InfobaseUser.UUID, , FoundUser);
				
				If FoundUser = Undefined
				 OR NOT Users.IsFullUser() Then
					
					ErrorText = NStr("ru = 'Имя (для входа) уже занято.'; en = 'The username is not unique.'; pl = 'Login jest już używany.';es_ES = 'Nombre de usuario ya está en uso.';es_CO = 'Nombre de usuario ya está en uso.';tr = 'Kullanıcı adı benzersiz değil.';it = 'Il nome utente non è univoco.';de = 'Login wird bereits verwendet.'");
				Else
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Имя (для входа) уже занято для пользователя ""%1"".'; en = 'The username is not unique. It belongs to user ""%1"".'; pl = 'Login jest już używany przez użytkownika ""%1"".';es_ES = 'Nombre de usuario ya se utiliza por el usuario ""%1"".';es_CO = 'Nombre de usuario ya se utiliza por el usuario ""%1"".';tr = 'İsim ""%1"" kullanıcı tarafından zaten kullanılıyor.';it = 'Il nome utente non è univoco. Appartiene all''utente ""%1"".';de = 'Der Login wird bereits vom Benutzer ""%1"" verwendet.'"),
						String(FoundUser));
				EndIf;
				
				CommonClientServer.MessageToUser(
					ErrorText, , "Name", , Cancel);
			EndIf;
		EndIf;
	EndIf;
	
	If IBUserDetails.Property("OSUser") Then
		
		If Not IsBlankString(IBUserDetails.OSUser)
		   AND Not StandardSubsystemsServer.IsTrainingPlatform() Then
			
			SetPrivilegedMode(True);
			Try
				InfobaseUser = InfoBaseUsers.CreateUser();
				InfobaseUser.OSUser = IBUserDetails.OSUser;
			Except
				CommonClientServer.MessageToUser(
					NStr("ru = 'Пользователь ОС должен быть в формате
					           |""\\ИмяДомена\ИмяПользователя"".'; 
					           |en = 'The operating system username must have the following format:
					           |\\DomainName\Username.'; 
					           |pl = 'Użytkownik OS musi być w formacie:
					           |\\DomainName\Username.';
					           |es_ES = 'El usuario del OS debe ser en el formato
					           |\\DomainName\Username.';
					           |es_CO = 'El usuario del OS debe ser en el formato
					           |\\DomainName\Username.';
					           |tr = 'OS kullanıcısının biçimi 
					           |""//Alan adı/KullanıcıAdı"" olmalıdır.';
					           |it = 'Il nome utente sistema operativo deve avere il seguente formato:
					           |\\NomeDominio\NomeUtente';
					           |de = 'Der Betriebssystem-Benutzer muss im Format
					           |""\\\NameDomain\NameBenutzer"" vorliegen.'"),
					,
					"OSUser",
					,
					Cancel);
			EndTry;
			SetPrivilegedMode(False);
		EndIf;
		
	EndIf;
	
	Return NOT Cancel;
	
EndFunction

// Updates the content of user groups based on the hierarchy from the "User group content" 
// information register.
//  The register data is used in the user list form and in the user selection form.
//  Register data can be used to improve query performance,
// because work with the hierarchy is not required.
//
// Parameters:
//  UsersGroup - CatalogRef.UsersGroups.
//
//  User - Undefined - for all users.
//               - An array of values CatalogRef.Users - for the specified users.
//               - CatalogRef.Users - for the specified user.
//
//  ItemsToChange - Undefined - no actions.
//                     - Array (return value) - fills in the array with users for which there are 
//                       changes.
//
//  ModifiedGroups - Undefined - no actions.
//                     - Array (return value) - fills in the array with user groups for which there 
//                       are changes.
//
Procedure UpdateUserGroupComposition(Val UsersGroup,
                                            Val User       = Undefined,
                                            Val ItemsToChange = Undefined,
                                            Val ModifiedGroups   = Undefined) Export
	
	If NOT ValueIsFilled(UsersGroup) Then
		Return;
	EndIf;
	
	If TypeOf(User) = Type("Array") AND User.Count() = 0 Then
		Return;
	EndIf;
	
	If ItemsToChange = Undefined Then
		CurrentItemsToChange = New Map;
	Else
		CurrentItemsToChange = ItemsToChange;
	EndIf;
	
	If ModifiedGroups = Undefined Then
		CurrentModifiedGroups = New Map;
	Else
		CurrentModifiedGroups = ModifiedGroups;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If UsersGroup = Catalogs.UserGroups.AllUsers Then
			
			UpdateAllUsersGroupComposition(
				User, , CurrentItemsToChange, CurrentModifiedGroups);
		Else
			UpdateHierarchicalUserGroupCompositions(
				UsersGroup,
				User,
				CurrentItemsToChange,
				CurrentModifiedGroups);
		EndIf;
		
		If ItemsToChange = Undefined
		   AND ModifiedGroups   = Undefined Then
			
			AfterUserGroupsUpdate(
				CurrentItemsToChange, CurrentModifiedGroups);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates the Used resource when DeletionMark or NotValid attribute is changed
//
// Parameters:
//  UserOrGroup - CatalogRef.Users,
//                        - CatalogRef.ExternalUsers,
//                        - CatalogRef.UserGroups,
//                        - CatalogRef.ExternalUserGroups.
//
//  ItemsToChange - Array - (return value) - fills in the array with users or external users, for 
//                       which there are changes.
//
//  ModifiedGroups - Array - (return value) - fills in the array with user groups  or external user 
//                       groups, for which there are changes.
//
Procedure UpdateUserGroupCompositionUsage(Val UserOrGroup,
                                                           Val ItemsToChange,
                                                           Val ModifiedGroups) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("UserOrGroup", UserOrGroup);
	Query.Text =
	"SELECT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.User,
	|	CASE
	|		WHEN UserGroupCompositions.UsersGroup.DeletionMark
	|			THEN FALSE
	|		WHEN UserGroupCompositions.User.DeletionMark
	|			THEN FALSE
	|		WHEN UserGroupCompositions.User.Invalid
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Used
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	&Filter
	|	AND CASE
	|			WHEN UserGroupCompositions.UsersGroup.DeletionMark
	|				THEN FALSE
	|			WHEN UserGroupCompositions.User.DeletionMark
	|				THEN FALSE
	|			WHEN UserGroupCompositions.User.Invalid
	|				THEN FALSE
	|			ELSE TRUE
	|		END <> UserGroupCompositions.Used";
	
	If TypeOf(UserOrGroup) = Type("CatalogRef.Users")
	 OR TypeOf(UserOrGroup) = Type("CatalogRef.ExternalUsers") Then
		
		Query.Text = StrReplace(Query.Text, "&Filter",
			"UserGroupCompositions.User = &UserOrGroup");
	Else
		Query.Text = StrReplace(Query.Text, "&Filter",
			"UserGroupCompositions.UsersGroup = &UserOrGroup");
	EndIf;
	
	SingleRecordSet = InformationRegisters.UserGroupCompositions.CreateRecordSet();
	Record = SingleRecordSet.Add();
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			SingleRecordSet.Filter.UsersGroup.Set(Selection.UsersGroup);
			SingleRecordSet.Filter.User.Set(Selection.User);
			
			Record.UsersGroup = Selection.UsersGroup;
			Record.User        = Selection.User;
			Record.Used        = Selection.Used;
			
			SingleRecordSet.Write();
			
			ModifiedGroups.Insert(Selection.UsersGroup);
			ItemsToChange.Insert(Selection.User);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use only.
Procedure AfterUserGroupsUpdate(ItemsToChange, ModifiedGroups) Export
	
	If ItemsToChange.Count() = 0 Then
		Return;
	EndIf;
	
	ItemsToChangeArray = New Array;
	
	For each KeyAndValue In ItemsToChange Do
		ItemsToChangeArray.Add(KeyAndValue.Key);
	EndDo;
	
	ModifiedGroupsArray = New Array;
	For each KeyAndValue In ModifiedGroups Do
		ModifiedGroupsArray.Add(KeyAndValue.Key);
	EndDo;
	
	SSLSubsystemsIntegration.AfterUserGroupsUpdate(ItemsToChangeArray,
		ModifiedGroupsArray);
	
EndProcedure

// For internal use only.
Procedure AfterChangeUserOrUserGroupInForm() Export
	
	SSLSubsystemsIntegration.AfterChangeUserOrGroupInForm();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for external user operations.

// Updates the content of external user groups based on the hierarchy from the "User group content" 
// information register.
//  The register data is used in the external user list form and the external user selection form.
//  Data can be used to improve performance,
// because work with the hierarchy in query language is not required.
//
// Parameters:
//  ExternalUsersGroup - CatalogRef.ExternalUsersGroups
//                        If AllExternalUsers group is specified, all automatic groups are updated 
//                        according to the authorization object types.
//
//  ExternalUser - Undefined - for all external users.
//                      - An array of values CatalogRef.ExternalUsers - for the specified external 
//                          users.
//                      - CatalogRef.ExternalUsers - for the specified external user.
//
//  ItemsToChange - Undefined - no actions.
//                      - Array (return value) - fills in the array with external users for which 
//                        there are changes.
//
//  ModifiedGroups - Undefined - no actions.
//                     - Array (return value) - fills in the array with groups of external users for 
//                       which there are changes.
//
Procedure UpdateExternalUserGroupCompositions(Val ExternalUsersGroup,
                                                   Val ExternalUser = Undefined,
                                                   Val ItemsToChange  = Undefined,
                                                   Val ModifiedGroups    = Undefined) Export
	
	If NOT ValueIsFilled(ExternalUsersGroup) Then
		Return;
	EndIf;
	
	If TypeOf(ExternalUser) = Type("Array") AND ExternalUser.Count() = 0 Then
		Return;
	EndIf;
	
	If ItemsToChange = Undefined Then
		CurrentItemsToChange = New Map;
	Else
		CurrentItemsToChange = ItemsToChange;
	EndIf;
	
	If ModifiedGroups = Undefined Then
		CurrentModifiedGroups = New Map;
	Else
		CurrentModifiedGroups = ModifiedGroups;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If ExternalUsersGroup = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			UpdateAllUsersGroupComposition(
				ExternalUser, True, CurrentItemsToChange, CurrentModifiedGroups);
			
			UpdateGroupCompositionsByAuthorizationObjectType(
				Undefined, ExternalUser, CurrentItemsToChange, CurrentModifiedGroups);
			
		Else
			AllAuthorizationObjects = Common.ObjectAttributeValue(ExternalUsersGroup,
				"AllAuthorizationObjects");
			AllAuthorizationObjects = ?(AllAuthorizationObjects = Undefined, False, AllAuthorizationObjects);
			
			If AllAuthorizationObjects Then
				UpdateGroupCompositionsByAuthorizationObjectType(
					ExternalUsersGroup,
					ExternalUser,
					CurrentItemsToChange,
					CurrentModifiedGroups);
			Else
				UpdateHierarchicalUserGroupCompositions(
					ExternalUsersGroup,
					ExternalUser,
					CurrentItemsToChange,
					CurrentModifiedGroups);
			EndIf;
		EndIf;
		
		If ItemsToChange = Undefined
		   AND ModifiedGroups   = Undefined Then
			
			AfterUpdateExternalUserGroupCompositions(
				CurrentItemsToChange, CurrentModifiedGroups);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use only.
Procedure AfterUpdateExternalUserGroupCompositions(ItemsToChange, ModifiedGroups) Export
	
	If ItemsToChange.Count() = 0 Then
		Return;
	EndIf;
	
	ItemsToChangeArray = New Array;
	For each KeyAndValue In ItemsToChange Do
		ItemsToChangeArray.Add(KeyAndValue.Key);
	EndDo;
	
	UpdateExternalUsersRoles(ItemsToChangeArray);
	
	ModifiedGroupsArray = New Array;
	For each KeyAndValue In ModifiedGroups Do
		ModifiedGroupsArray.Add(KeyAndValue.Key);
	EndDo;
	
	SSLSubsystemsIntegration.AfterUserGroupsUpdate(ItemsToChangeArray,
		ModifiedGroupsArray);
	
EndProcedure

// Updates the list of roles for infobase users that match external users.
//  Roles of external users are defined by their external user groups, except external users whose 
// roles are specified directly.
// 
//  Required only when role editing is enabled, for example, if
// the Access management subsystem is implemented, the procedure is not required.
// 
// Parameters:
//  ExternalUsersArray - Undefined - all external users.
//                               CatalogRef.ExternalUsersGroup,
//                               Array with elements of the CatalogRef.ExternalUsers type.
//
Procedure UpdateExternalUsersRoles(Val ExternalUsersArray = Undefined) Export
	
	If CannotEditRoles() Then
		// Roles are set using another algorithm, for example, the algorithm from AccessManagement subsystem.
		Return;
	EndIf;
	
	If TypeOf(ExternalUsersArray) = Type("Array")
	   AND ExternalUsersArray.Count() = 0 Then
		
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		If TypeOf(ExternalUsersArray) <> Type("Array") Then
			
			If ExternalUsersArray = Undefined Then
				ExternalUsersGroup = Catalogs.ExternalUsersGroups.AllExternalUsers;
			Else
				ExternalUsersGroup = ExternalUsersArray;
			EndIf;
			
			Query = New Query;
			Query.SetParameter("ExternalUsersGroup", ExternalUsersGroup);
			Query.Text =
			"SELECT
			|	UserGroupCompositions.User
			|FROM
			|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
			|WHERE
			|	UserGroupCompositions.UsersGroup = &ExternalUsersGroup";
			
			ExternalUsersArray = Query.Execute().Unload().UnloadColumn("User");
		EndIf;
		
		Users.FindAmbiguousIBUsers(Undefined);
		
		IBUsersIDs = New Map;
		
		Query = New Query;
		Query.SetParameter("ExternalUsers", ExternalUsersArray);
		Query.Text =
		"SELECT
		|	ExternalUsers.Ref AS ExternalUser,
		|	ExternalUsers.IBUserID
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.Ref IN(&ExternalUsers)
		|	AND (NOT ExternalUsers.SetRolesDirectly)";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			IBUsersIDs.Insert(
				Selection.ExternalUser, Selection.IBUserID);
		EndDo;
		
		// Preparing a table of external user old roles
		PreviousExternalUserRoles = New ValueTable;
		
		PreviousExternalUserRoles.Columns.Add(
			"ExternalUser", New TypeDescription("CatalogRef.ExternalUsers"));
		
		PreviousExternalUserRoles.Columns.Add(
			"Role", New TypeDescription("String", , New StringQualifiers(200)));
		
		CurrentNumber = ExternalUsersArray.Count() - 1;
		While CurrentNumber >= 0 Do
			
			// Checking if user processing is required.
			InfobaseUser = Undefined;
			IBUserID = IBUsersIDs[ExternalUsersArray[CurrentNumber]];
			If IBUserID <> Undefined Then
				
				InfobaseUser = InfoBaseUsers.FindByUUID(
					IBUserID);
			EndIf;
			
			If InfobaseUser = Undefined
			 OR IsBlankString(InfobaseUser.Name) Then
				
				ExternalUsersArray.Delete(CurrentNumber);
			Else
				For each Role In InfobaseUser.Roles Do
					PreviousExternalUserRole = PreviousExternalUserRoles.Add();
					PreviousExternalUserRole.ExternalUser = ExternalUsersArray[CurrentNumber];
					PreviousExternalUserRole.Role = Role.Name;
				EndDo;
			EndIf;
			CurrentNumber = CurrentNumber - 1;
		EndDo;
		
		// Preparing a list of roles that are missing from the metadata and need to be reset
		Query = New Query;
		Query.TempTablesManager = New TempTablesManager;
		Query.SetParameter("ExternalUsers", ExternalUsersArray);
		Query.SetParameter("AllRoles", AllRoles().Table.Get());
		Query.SetParameter("OldExternalUserRoles", PreviousExternalUserRoles);
		Query.SetParameter("UseExternalUsers",
			GetFunctionalOption("UseExternalUsers"));
		Query.Text =
		"SELECT
		|	OldExternalUserRoles.ExternalUser,
		|	OldExternalUserRoles.Role
		|INTO OldExternalUserRoles
		|FROM
		|	&OldExternalUserRoles AS OldExternalUserRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllRoles.Name
		|INTO AllRoles
		|FROM
		|	&AllRoles AS AllRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	UserGroupCompositions.UsersGroup AS ExternalUsersGroup,
		|	UserGroupCompositions.User AS ExternalUser,
		|	Roles.Role.Name AS Role
		|INTO AllNewExternalUserRoles
		|FROM
		|	Catalog.ExternalUsersGroups.Roles AS Roles
		|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|		ON (UserGroupCompositions.User IN (&ExternalUsers))
		|			AND (UserGroupCompositions.UsersGroup = Roles.Ref)
		|			AND (&UseExternalUsers = TRUE)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	AllNewExternalUserRoles.ExternalUser,
		|	AllNewExternalUserRoles.Role
		|INTO NewExternalUserRoles
		|FROM
		|	AllNewExternalUserRoles AS AllNewExternalUserRoles
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OldExternalUserRoles.ExternalUser
		|INTO ModifiedExternalUsers
		|FROM
		|	OldExternalUserRoles AS OldExternalUserRoles
		|		LEFT JOIN NewExternalUserRoles AS NewExternalUserRoles
		|		ON (NewExternalUserRoles.ExternalUser = OldExternalUserRoles.ExternalUser)
		|			AND (NewExternalUserRoles.Role = OldExternalUserRoles.Role)
		|WHERE
		|	NewExternalUserRoles.Role IS NULL 
		|
		|UNION
		|
		|SELECT
		|	NewExternalUserRoles.ExternalUser
		|FROM
		|	NewExternalUserRoles AS NewExternalUserRoles
		|		LEFT JOIN OldExternalUserRoles AS OldExternalUserRoles
		|		ON NewExternalUserRoles.ExternalUser = OldExternalUserRoles.ExternalUser
		|			AND NewExternalUserRoles.Role = OldExternalUserRoles.Role
		|WHERE
		|	OldExternalUserRoles.Role IS NULL 
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllNewExternalUserRoles.ExternalUsersGroup,
		|	AllNewExternalUserRoles.ExternalUser,
		|	AllNewExternalUserRoles.Role
		|FROM
		|	AllNewExternalUserRoles AS AllNewExternalUserRoles
		|WHERE
		|	NOT TRUE IN
		|				(SELECT TOP 1
		|					TRUE AS TrueValue
		|				FROM
		|					AllRoles AS AllRoles
		|				WHERE
		|					AllRoles.Name = AllNewExternalUserRoles.Role)";
		
		// Registering role name errors in access group profiles
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru= 'При обновлении ролей внешнего пользователя
				          |""%1""
				          |роль ""%2""
				          |группы внешних пользователей ""%3""
				          |не найдена в метаданных.'; 
				          |en = 'When updating the roles of external user 
				          |""%1"",
				          |role ""%2""
				          |of external user group ""%3""
				          |is not found in the metadata.'; 
				          |pl = 'Podczas aktualizacji ról użytkownika zewnętrznego
				          |""%1""
				          |rola ""%2""
				          |grupy użytkowników zewnętrznych ""%3""
				          |nie znaleziono w metadanych.';
				          |es_ES = 'Al actualizar los roles del usuario externo 
				          |""%1""
				          |el rol ""%2""
				          |del grupo de los usuarios externos ""%3""
				          |no se ha encontrado en los metadatos.';
				          |es_CO = 'Al actualizar los roles del usuario externo 
				          |""%1""
				          |el rol ""%2""
				          |del grupo de los usuarios externos ""%3""
				          |no se ha encontrado en los metadatos.';
				          |tr = 'Harici kullanıcı rolleri güncellenirken 
				          |""%1"" 
				          | ""%2""
				          | harici kullanıcı grubun rolü ""%3""
				          | metaverilerde bulunamadı.';
				          |it = 'Durante l''aggiornamento dei ruoli dell''utento esterno
				          |""%1"",
				          |il ruolo ""%2""
				          |del gruppo dell''utente esterno ""%3""
				          |non è stato trovato nei metadati.';
				          |de = 'Beim Aktualisieren der externen Benutzerrollen
				          |""%1""
				          |wird die Rolle ""%2""
				          |der externen Benutzergruppe ""%3""
				          |in den Metadaten nicht gefunden.'"),
				TrimAll(Selection.ExternalUser.Description),
				Selection.Role,
				String(Selection.ExternalUsersGroup));
			
			WriteLogEvent(
				NStr("ru = 'Пользователи.Роль не найдена в метаданных'; en = 'Users.Role is not found in the metadata.'; pl = 'Użytkownicy.Rola nie została znaleziona w metadanych';es_ES = 'Usuarios.Rol no se ha encontrado en los metadatos';es_CO = 'Usuarios.Rol no se ha encontrado en los metadatos';tr = 'Kullanıcılar. Rol meta verilerde bulunamadı';it = 'Utenti.Ruolo non trovato nei metadati.';de = 'Benutzer. Die Rolle wurde in Metadaten nicht gefunden'",
				     CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				MessageText,
				EventLogEntryTransactionMode.Transactional);
		EndDo;
		
		// Updating infobase user roles
		Query.Text =
		"SELECT
		|	ModifiedExternalUsersAndRoles.ExternalUser,
		|	ModifiedExternalUsersAndRoles.Role
		|FROM
		|	(SELECT
		|		NewExternalUserRoles.ExternalUser AS ExternalUser,
		|		NewExternalUserRoles.Role AS Role
		|	FROM
		|		NewExternalUserRoles AS NewExternalUserRoles
		|	WHERE
		|		NewExternalUserRoles.ExternalUser IN
		|				(SELECT
		|					ModifiedExternalUsers.ExternalUser
		|				FROM
		|					ModifiedExternalUsers AS ModifiedExternalUsers)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ExternalUsers.Ref,
		|		""""
		|	FROM
		|		Catalog.ExternalUsers AS ExternalUsers
		|	WHERE
		|		ExternalUsers.Ref IN
		|				(SELECT
		|					ModifiedExternalUsers.ExternalUser
		|				FROM
		|					ModifiedExternalUsers AS ModifiedExternalUsers)) AS ModifiedExternalUsersAndRoles
		|
		|ORDER BY
		|	ModifiedExternalUsersAndRoles.ExternalUser,
		|	ModifiedExternalUsersAndRoles.Role";
		Selection = Query.Execute().Select();
		
		InfobaseUser = Undefined;
		While Selection.Next() Do
			If ValueIsFilled(Selection.Role) Then
				InfobaseUser.Roles.Add(Metadata.Roles[Selection.Role]);
				Continue;
			EndIf;
			If InfobaseUser <> Undefined Then
				InfobaseUser.Write();
			EndIf;
			
			InfobaseUser = InfoBaseUsers.FindByUUID(
				IBUsersIDs[Selection.ExternalUser]);
			
			InfobaseUser.Roles.Clear();
		EndDo;
		If InfobaseUser <> Undefined Then
			InfobaseUser.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Checks that the infobase object is used as the authorization object of any external user except 
// the specified external user (if it is specified).
//
Function AuthorizationObjectIsInUse(Val AuthorizationObjectRef,
                                      Val CurrentExternalUserRef,
                                      FoundExternalUser = Undefined,
                                      CanAddExternalUser = False,
                                      ErrorText = "") Export
	
	CanAddExternalUser = AccessRight(
		"Insert", Metadata.Catalogs.ExternalUsers);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.AuthorizationObject = &AuthorizationObjectRef
	|	AND ExternalUsers.Ref <> &CurrentExternalUserRef";
	Query.SetParameter("CurrentExternalUserRef", CurrentExternalUserRef);
	Query.SetParameter("AuthorizationObjectRef", AuthorizationObjectRef);
	
	BeginTransaction();
	Try
		Table = Query.Execute().Unload();
		If Table.Count() > 0 Then
			FoundExternalUser = Table[0].Ref;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Result = Table.Count() > 0;
	If Result Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Уже существует внешний пользователь, связанный с объектом ""%1"".'; en = 'An external user mapped to object ""%1"" already exists.'; pl = 'Zewnętrzny użytkownik powiązany z obiektem ""%1"" już istnieje.';es_ES = 'Usuario externo relacionado con el objeto ""%1"" ya existe.';es_CO = 'Usuario externo relacionado con el objeto ""%1"" ya existe.';tr = '""%1"" Nesnesine ilişkin harici kullanıcı zaten var.';it = 'Esiste già un utente esterno associato all''oggetto ""%1"".';de = 'Externer Benutzer, der sich auf das Objekt ""%1"" bezieht, existiert bereits.'"),
			AuthorizationObjectRef);
		EndIf;
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operations with infobase user settings.

// Copies settings from a source user to a destination user. If the value of the Transfer parameter 
// = True, the settings of the source user are deleted.
//
// Parameters:
// UsernameSource - String - name of an infobase user that will copy files.
//
// UsernameDestination - name of an infobase user to whom settings will be written.
//
// Move - Boolean - if True, settings are moved from one user to another. If False, settings are 
//                           copied from one user to another.
//
Procedure CopyUserSettings(UserNameSource, UserNameDestination, Move = False) Export
	
	// Moving user report settings.
	CopySettings(ReportsUserSettingsStorage, UserNameSource, UserNameDestination, Move);
	// Moving appearance settings
	CopySettings(SystemSettingsStorage,UserNameSource, UserNameDestination, Move);
	// Moving custom user settings
	CopySettings(CommonSettingsStorage, UserNameSource, UserNameDestination, Move);
	// Form data settings transfer.
	CopySettings(FormDataSettingsStorage, UserNameSource, UserNameDestination, Move);
	// Moving settings of quick access to additional reports and data processors
	If Not Move Then
		CopyOtherUserSettings(UserNameSource, UserNameDestination);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for moving users between groups.

// Moves a user from one group to another.
//
// Parameters:
//  UsersArray - Array - users that need to be moved to the new group.
//  SourceGroup - CatalogRef.UsersGroups - a group, from which users are transferred.
//                        
//  DestinationGroup - CatalogRef.UsersGroups - a group, to which users are transferred.
//                        
//  Move - Boolean - if True, the users are removed from the source group.
//
// Returns:
//  Row - a message about the result of moving.
//
Function MoveUserToNewGroup(UsersArray, SourceGroup,
												DestinationGroup, Move) Export
	
	If DestinationGroup = Undefined
		Or DestinationGroup = SourceGroup Then
		Return Undefined;
	EndIf;
	MovedUsersArray = New Array;
	UnmovedUsersArray = New Array;
	
	For Each UserRef In UsersArray Do
		
		If TypeOf(UserRef) <> Type("CatalogRef.Users")
			AND TypeOf(UserRef) <> Type("CatalogRef.ExternalUsers") Then
			Continue;
		EndIf;
		
		If Not CanMoveUser(DestinationGroup, UserRef) Then
			UnmovedUsersArray.Add(UserRef);
			Continue;
		EndIf;
		
		If TypeOf(UserRef) = Type("CatalogRef.Users") Then
			CompositionColumnName = "User";
		Else
			CompositionColumnName = "ExternalUser";
		EndIf;
		
		// If the user being moved is not included in the destination group, moving that user.
		If DestinationGroup = Catalogs.UserGroups.AllUsers
			Or DestinationGroup = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			If Move Then
				DeleteUserFromGroup(SourceGroup, UserRef, CompositionColumnName);
			EndIf;
			MovedUsersArray.Add(UserRef);
			
		ElsIf DestinationGroup.Content.Find(UserRef, CompositionColumnName) = Undefined Then
			
			AddUserToGroup(DestinationGroup, UserRef, CompositionColumnName);
			
			// Removing the user from the source group.
			If Move Then
				DeleteUserFromGroup(SourceGroup, UserRef, CompositionColumnName);
			EndIf;
			
			MovedUsersArray.Add(UserRef);
		EndIf;
		
	EndDo;
	
	UserMessage = CreateUserMessage(
		MovedUsersArray, DestinationGroup, Move, UnmovedUsersArray, SourceGroup);
	
	If MovedUsersArray.Count() = 0 AND UnmovedUsersArray.Count() = 0 Then
		If UsersArray.Count() = 1 Then
			MessageText = NStr("ru = 'Пользователь ""%1"" уже включен в группу ""%2"".'; en = 'User ""%1"" is already included in group ""%2.""'; pl = 'Użytkownik ""%1"" jest już członkiem grupy ""%2"".';es_ES = 'Usuario ""%1"" ya es un miembro del grupo ""%2"".';es_CO = 'Usuario ""%1"" ya es un miembro del grupo ""%2"".';tr = '""%1"" Kullanıcısı zaten ""%2"" grubunun bir üyesidir.';it = 'L''utente ""%1"" è già incluso nel gruppo ""%2"".';de = 'Benutzer ""%1"" ist bereits ein Mitglied der Gruppe ""%2"".'");
			UserToMoveName = Common.ObjectAttributeValue(UsersArray[0], "Description");
		Else
			MessageText = NStr("ru = 'Все выбранные пользователи уже включены в группу ""%2"".'; en = 'All selected users are already included in group ""%2.""'; pl = 'Wszyscy wybrani użytkownicy są już dołączeni do grupy ""%2"".';es_ES = 'Todos los usuarios seleccionado ya están incluidos en el grupo ""%2"".';es_CO = 'Todos los usuarios seleccionado ya están incluidos en el grupo ""%2"".';tr = 'Seçilen tüm kullanıcılar zaten ""%2"" grubuna dahil.';it = 'Tutti gli utenti selezionati sono già inclusi nel gruppo ""%2"".';de = 'Alle ausgewählten Benutzer sind bereits in der Gruppe ""%2"" enthalten.'");
			UserToMoveName = "";
		EndIf;
		GroupDescription = Common.ObjectAttributeValue(DestinationGroup, "Description");
		UserMessage.Message = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
			UserToMoveName, GroupDescription);
		UserMessage.HasErrors = True;
		Return UserMessage;
	EndIf;
	
	Return UserMessage;
	
EndFunction

// Checks if an external user can be included in a group.
//
// Parameters:
//  GroupsDestination - CatalogRef.UserGroups - a group, to which users are added.
//                       
//  UserRef - CatalogRef.User - a user to add to the group.
//                       
//
// Returns:
//  Boolean - if False, user cannot be added to the group.
//
Function CanMoveUser(DestinationGroup, UserRef) Export
	
	If TypeOf(UserRef) = Type("CatalogRef.ExternalUsers") Then
		
		DestinationGroupProperties = Common.ObjectAttributesValues(
			DestinationGroup, "Purpose, AllAuthorizationObjects");
		
		If DestinationGroupProperties.AllAuthorizationObjects Then
			Return False;
		EndIf;
		
		DestinationGroupPurpose = DestinationGroupProperties.Purpose.Unload();
		
		ExternalUserType = TypeOf(Common.ObjectAttributeValue(
			UserRef, "AuthorizationObject"));
		RefTypeDetails = New TypeDescription(CommonClientServer.ValueInArray(ExternalUserType));
		Value = RefTypeDetails.AdjustValue(Undefined);
		
		Filter = New Structure("UsersType", Value);
		If DestinationGroupPurpose.FindRows(Filter).Count() <> 1 Then
			Return False;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

// Adds a user to a group.
//
// Parameters:
//  DestinationGroup - CatalogRef.UsersGroups - a group, to which user is transferred.
//                       
//  UserRef - CatalogRef.User - a user to add to the group.
//                       
//  UserType - String - ExternalUser or User.
//
Procedure AddUserToGroup(DestinationGroup, UserRef, UserType) Export
	
	BeginTransaction();
	Try
		
		DestinationGroupObject = DestinationGroup.GetObject();
		CompositionRow = DestinationGroupObject.Content.Add();
		If UserType = "ExternalUser" Then
			CompositionRow.ExternalUser = UserRef;
		Else
			CompositionRow.User = UserRef;
		EndIf;
		
		DestinationGroupObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Removes a user from a group.
//
// Parameters:
//  DestinationGroup - CatalogRef.UsersGroups - a group, from which user is removed.
//                       
//  UserRef - CatalogRef.User - a user to add to the group.
//                       
//  UserType - String - ExternalUser or User.
//
Procedure DeleteUserFromGroup(OwnerGroup, UserRef, UserType) Export
	
	BeginTransaction();
	Try
		
		OwnerGroupObject = OwnerGroup.GetObject();
		If OwnerGroupObject.Content.Count() <> 0 Then
			OwnerGroupObject.Content.Delete(OwnerGroupObject.Content.Find(UserRef, UserType));
			OwnerGroupObject.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Generates a message about the result of moving a user.
//
// Parameters:
//  UsersArray - Array - users that need to be moved to the new group.
//  DestinationGroup - CatalogRef.UsersGroups - a group, to which users are transferred.
//                        
//  Move - Boolean - if True, the users are removed from the source group.
//  UnmovedUsersArray - Array - users, that cannot be placed to the group.
//  SourceGroup - CatalogRef.UsersGroups - a group, from which users are transferred.
//                        
//
// Returns:
//  Row - a message to user.
//
Function CreateUserMessage(UsersArray, DestinationGroup,
	                                      Move, UnmovedUsersArray, SourceGroup = Undefined) Export
	
	UsersCount = UsersArray.Count();
	GroupDescription = Common.ObjectAttributeValue(DestinationGroup, "Description");
	UserMessage = Undefined;
	NotMovedUsersCount = UnmovedUsersArray.Count();
	
	NotifyUser = New Structure;
	NotifyUser.Insert("Message");
	NotifyUser.Insert("HasErrors");
	NotifyUser.Insert("Users");
	
	If NotMovedUsersCount > 0 Then
		
		DestinationGroupProperties = Common.ObjectAttributesValues(
			DestinationGroup, "Purpose, Description");
		
		GroupDescription = DestinationGroupProperties.Description;
		ExternalUserGroupPurpose = DestinationGroupProperties.Purpose.Unload();
		
		PresentationsArray = New Array;
		For Each AssignmentRow In ExternalUserGroupPurpose Do
			
			PresentationsArray.Add(Lower(Metadata.FindByType(
				TypeOf(AssignmentRow.UsersType)).Synonym));
			
		EndDo;
		
		AuthorizationObjectTypePresentation = StrConcat(PresentationsArray, ", ");
		
		If NotMovedUsersCount = 1 Then
			
			NotMovedUserProperties = Common.ObjectAttributesValues(
				UnmovedUsersArray[0], "Description, AuthorizationObject");
			
			Subject = NotMovedUserProperties.Description;
			
			ExternalUserType = TypeOf(NotMovedUserProperties.AuthorizationObject);
			RefTypeDetails = New TypeDescription(CommonClientServer.ValueInArray(ExternalUserType));
			Value = RefTypeDetails.AdjustValue(Undefined);
		
			Filter = New Structure("UsersType", Value);
			UserTypeMatchesGroup = (ExternalUserGroupPurpose.FindRows(Filter).Count() = 1);
			
			NotifyUser.Users = Undefined;
			
			If UserTypeMatchesGroup Then
				UserMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Пользователь ""%1"" не может быть включен в группу ""%2"",
					           |т.к. у группы стоит признак ""Все пользователи заданного типа"".'; 
					           |en = 'Cannot add user ""%1"" to group ""%2""
					           |because the group has ""All users of the specified types"" option selected.'; 
					           |pl = 'Użytkownik ""%1"" nie może zostać włączony do grupy ""%2"",
					           | ponieważ grupa ma oznakę ""Wszyscy użytkownicy określonego typu"".';
					           |es_ES = 'El usuario ""%1"" no puede estar incluido en el grupo ""%2"",
					           |porque el grupo tiene el atributo ""Todos los uaurios del tipo especificado"".';
					           |es_CO = 'El usuario ""%1"" no puede estar incluido en el grupo ""%2"",
					           |porque el grupo tiene el atributo ""Todos los uaurios del tipo especificado"".';
					           |tr = '""%1"" kullanıcı, ""%2"" grubuna dahil edilemez, 
					           | çünkü grupta ""Belirlenen türdeki tüm kullanıcılar"" özelliği mevcuttur.';
					           |it = 'L''utente ""%1"" non può essere incluso nel gruppo ""%2""
					           |poiché il gruppo ha la proprietà ""Tutti gli uenti del tipo indicato"".';
					           |de = 'Der Benutzer ""%1"" kann nicht in die Gruppe ""%2"" aufgenommen werden
					           |da die Gruppe das Attribut ""Alle Benutzer des gegebenen Typs"" hat.'"),
					Subject, GroupDescription) + Chars.LF;
			Else
				UserMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Пользователь ""%1"" не может быть включен в группу ""%2"",
					           |т.к. в состав ее участников входят только %3.'; 
					           |en = 'Cannot add user ""%1"" to group ""%2""
					           |because the group contains only %3.'; 
					           |pl = 'Użytkownik ""%1"" nie może zostać włączony do grupy ""%2"",
					           | ponieważ grupa obejmuje tylko %3.';
					           |es_ES = 'El usuario ""%1"" no puede estar incluido en el grupo ""%2"",
					           |porque sus participantes solo son %3.';
					           |es_CO = 'El usuario ""%1"" no puede estar incluido en el grupo ""%2"",
					           |porque sus participantes solo son %3.';
					           |tr = '""%1"" kullanıcısı ""%2"" grubuna dahil edilemez, 
					           | çünkü sadece %3 onun üyeleri arasına dahil edilmiştir.';
					           |it = 'L''utente ""%1"" non può essere incluso nel gruppo ""%2""
					           |poiché nella composizione dei suoi membri ci sono solo %3.';
					           |de = 'Benutzer ""%1"" kann nicht in die Gruppe ""%2"" aufgenommen werden,
					           |da seine Teilnehmer nur %3 sind.'"),
					Subject, GroupDescription, AuthorizationObjectTypePresentation) + Chars.LF;
			EndIf;
		Else
			NotifyUser.Users = StrConcat(UnmovedUsersArray, Chars.LF);
			
			UserMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не все пользователи могут быть включены в группу ""%1"",
				           |т.к. в состав ее участников входят только %2
				           |или у группы стоит признак ""Все пользователи заданного типа"".'; 
				           |en = 'Cannot add some users to group ""%1""
				           |because the group contains only %2
				           |or it has ""All users of the specified types"" option selected.'; 
				           |pl = 'Nie wszyscy użytkownicy mogą być włączeni do grupy ""%1"",
				           | ponieważ grupa obejmuje tylko %2
				           | lub grupa ma oznakę ""Wszyscy użytkownicy określonego typu"".';
				           |es_ES = 'No todos los usuarios pueden estar incluidos en el grupo ""%1"",
				           |porque solo están incluidos en el contenido de sus participantes %2
				           |o el grupo tiene una casilla ""Todos los usuarios del tipo especificado"".';
				           |es_CO = 'No todos los usuarios pueden estar incluidos en el grupo ""%1"",
				           |porque solo están incluidos en el contenido de sus participantes %2
				           |o el grupo tiene una casilla ""Todos los usuarios del tipo especificado"".';
				           |tr = 'Tüm kullanıcılar, yalnızca 
				           | üyelerinin içeriğinde yer aldığından dolayı %2 gruba dahil edilemez 
				           | %1veya grupta ""Belirtilen türde tüm kullanıcılar"" onay kutusu bulunur.';
				           |it = 'Non tutti gli utenti possono essere inclusi nel gruppo ""%1""
				           |poiché nella composizione dei suoi membri ci sono solo%2
				           |oppure il gruppo ha la proprietà ""Tutti gli utenti del tipo indicato"".';
				           |de = 'Nicht alle Benutzer können in die Gruppe ""%1"" aufgenommen werden,
				           |da seine Teilnehmer nur %2
				           |sind oder die Gruppe das Attribut ""Alle Benutzer eines bestimmten Typs"" hat.'"),
				GroupDescription,
				AuthorizationObjectTypePresentation);
		EndIf;
		
		NotifyUser.Message = UserMessage;
		NotifyUser.HasErrors = True;
		
		Return NotifyUser;
	EndIf;
	
	If UsersCount = 1 Then
		
		StringObject = Common.ObjectAttributeValue(UsersArray[0], "Description");
		
		If DestinationGroup = Catalogs.UserGroups.AllUsers
		 Or DestinationGroup = Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			ActionString = NStr("ru = 'исключен из группы'; en = 'removed from group'; pl = 'wykluczony z grupy';es_ES = 'excluidos del grupo';es_CO = 'excluidos del grupo';tr = 'gruptan çıkarıldı';it = 'rimosso dal gruppo';de = 'aus der Gruppe ausgeschlossen'");
			GroupDescription = Common.ObjectAttributeValue(SourceGroup, "Description");
			
		ElsIf Move Then
			ActionString = NStr("ru = 'перемещен в группу'; en = 'moved to group'; pl = 'przeniesiony do grupy';es_ES = 'trasladados en el grupo';es_CO = 'trasladados en el grupo';tr = 'gruba transfer edildi';it = 'mosso nel gruppo';de = 'zur Gruppe verschoben'");
		Else
			ActionString = NStr("ru = 'включен в группу'; en = 'added to group'; pl = 'należący do grupy';es_ES = 'incluidos en el grupo';es_CO = 'incluidos en el grupo';tr = 'gruba dahil edildi';it = 'aggiunto al gruppo';de = 'in der Gruppe enthalten'");
		EndIf;
		
		UserMessage = NStr("ru = '""%1"" %2 ""%3""'; en = '""%1"" %2 ""%3""'; pl = '""%1"" %2 ""%3""';es_ES = '""%1"" %2 ""%3""';es_CO = '""%1"" %2 ""%3""';tr = '""%1"" %2 ""%3""';it = '""%1"" %2 ""%3""';de = '""%1"" %2 ""%3""'");
		
	ElsIf UsersCount > 1 Then
		
		StringObject = Format(UsersCount, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(UsersCount,
				"", NStr("ru = 'пользователь,пользователя,пользователей,,,,,,0'; en = 'user, users,,,0'; pl = 'użytkownik, użytkownicy,,,0';es_ES = 'usuario, usuarios,,,0';es_CO = 'usuario, usuarios,,,0';tr = 'kullanıcı, kullanıcılar, kullanıcılar,,,,,,0';it = 'utente, utenti,,,0';de = 'Benutzer, Benutzer, Benutzer,,,,,,0'"));
		
		If DestinationGroup = Catalogs.UserGroups.AllUsers Then
			ActionString = NStr("ru = 'исключен из группы'; en = 'removed from group'; pl = 'wykluczony z grupy';es_ES = 'excluidos del grupo';es_CO = 'excluidos del grupo';tr = 'gruptan çıkarıldı';it = 'rimosso dal gruppo';de = 'aus der Gruppe ausgeschlossen'");
			GroupDescription = Common.ObjectAttributeValue(SourceGroup, "Description");
			
		ElsIf Move Then
			ActionString = NStr("ru = 'перемещен в группу'; en = 'moved to group'; pl = 'przeniesiony do grupy';es_ES = 'trasladados en el grupo';es_CO = 'trasladados en el grupo';tr = 'gruba transfer edildi';it = 'mosso nel gruppo';de = 'zur Gruppe verschoben'");
		Else
			ActionString = NStr("ru = 'включен в группу'; en = 'added to group'; pl = 'należący do grupy';es_ES = 'incluidos en el grupo';es_CO = 'incluidos en el grupo';tr = 'gruba dahil edildi';it = 'aggiunto al gruppo';de = 'in der Gruppe enthalten'");
		EndIf;
		UserMessage = NStr("ru = '%1 %2 ""%3""'; en = '%1 %2 ""%3""'; pl = '%1 %2 ""%3""';es_ES = '%1 %2 ""%3""';es_CO = '%1 %2 ""%3""';tr = '%1 %2 ""%3""';it = '%1 %2 ""%3""';de = '%1 %2 ""%3""'");
	EndIf;
	
	If UserMessage <> Undefined Then
		UserMessage = StringFunctionsClientServer.SubstituteParametersToString(UserMessage,
			StringObject, ActionString, GroupDescription);
	EndIf;
	
	NotifyUser.Message = UserMessage;
	NotifyUser.HasErrors = False;
	
	Return NotifyUser;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Universal procedures and functions.

// Returns nonmatching values in a value table column.
//
// Parameters:
//  ColumnName - String - a name of a compared column.
//  Table1 - ValueTable.
//  Table2 - ValueTable.
//
// Returns:
//  Array of values that are only present in that column in a single table.
// 
Function ColumnValueDifferences(ColumnName, Table1, Table2) Export
	
	If TypeOf(Table1) <> Type("ValueTable")
	   AND TypeOf(Table2) <> Type("ValueTable") Then
		
		Return New Array;
	EndIf;
	
	If TypeOf(Table1) <> Type("ValueTable") Then
		Return Table2.UnloadColumn(ColumnName);
	EndIf;
	
	If TypeOf(Table2) <> Type("ValueTable") Then
		Return Table1.UnloadColumn(ColumnName);
	EndIf;
	
	Table11 = Table1.Copy(, ColumnName);
	Table11.GroupBy(ColumnName);
	
	Table22 = Table2.Copy(, ColumnName);
	Table22.GroupBy(ColumnName);
	
	For Each Row In Table22 Do
		NewRow = Table11.Add();
		NewRow[ColumnName] = Row[ColumnName];
	EndDo;
	
	Table11.Columns.Add("Flag");
	Table11.FillValues(1, "Flag");
	
	Table11.GroupBy(ColumnName, "Flag");
	
	Filter = New Structure("Flag", 1);
	Table = Table11.Copy(Table11.FindRows(Filter));
	
	Return Table.UnloadColumn(ColumnName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Called when the configuration is updated to version 1.0.5.2.
// It attempts to map or fill the IBUserID attribute
// for each Users catalog item.
//
Procedure FillUserIDs() Export
	
	SetPrivilegedMode(True);
	
	Users.FindAmbiguousIBUsers(Undefined);
	
	IBUsers = InfoBaseUsers.GetUsers();
	
	Query = New Query;
	
	Query.SetParameter("BlankID",
		New UUID("00000000-0000-0000-0000-000000000000") );
	
	Query.SetParameter("UnspecifiedUser",
		UnspecifiedUserProperties().Ref);
	
	Query.Text =
	"SELECT
	|	Users.IBUserID
	|FROM
	|	Catalog.Users AS Users
	|
	|UNION
	|
	|SELECT
	|	ExternalUsers.IBUserID
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Users.Ref AS Ref,
	|	Users.Description AS Description
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref <> &UnspecifiedUser
	|	AND Users.IBUserID = &BlankID";
	
	QueryResults = Query.ExecuteBatch();
	
	If QueryResults[1].IsEmpty() Then
		Return;
	EndIf;
	
	OccupiedIDs = QueryResults[0].Unload();
	OccupiedIDs.Indexes.Add("IBUserID");
	
	FullNameLength = Metadata.Catalogs.Users.DescriptionLength;
	AvailableUsers = QueryResults[1].Unload();
	AvailableUsers.Indexes.Add("Description");
	
	For each Row In AvailableUsers Do
		Row.Description = Upper(TrimAll(Row.Description));
	EndDo;
	
	For each InfobaseUser In IBUsers Do
		
		If OccupiedIDs.Find(
		      InfobaseUser.UUID,
		      "IBUserID") <> Undefined Then
			
			Continue;
		EndIf;
		
		UserFullName = Upper(TrimAll(Left(InfobaseUser.FullName, FullNameLength)));
		
		UserDetails = AvailableUsers.Find(UserFullName, "Description");
		If UserDetails <> Undefined Then
			UserObject = UserDetails.Ref.GetObject();
			UserObject.IBUserID = InfobaseUser.UUID;
			InfobaseUpdate.WriteData(UserObject);
		EndIf;
	EndDo;
	
EndProcedure

// Converts attribute DELETERole to attribute Role in External user group tabular section Roles.
// 
//
Procedure ConvertRoleNamesToIDs() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Roles.Ref AS Ref
	|FROM
	|	Catalog.ExternalUsersGroups.Roles AS Roles
	|WHERE
	|	NOT(Roles.Role <> VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|				AND Roles.DeleteRole = """")";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Index = Object.Roles.Count()-1;
		While Index >= 0 Do
			Row = Object.Roles[Index];
			If ValueIsFilled(Row.Role) Then
				Row.DeleteRole = "";
			ElsIf ValueIsFilled(Row.DeleteRole) Then
				RoleMetadata = Metadata.Roles.Find(Row.DeleteRole);
				If RoleMetadata <> Undefined Then
					Row.DeleteRole = "";
					Row.Role = Common.MetadataObjectID(
						RoleMetadata);
				Else
					Object.Roles.Delete(Index);
				EndIf;
			Else
				Object.Roles.Delete(Index);
			EndIf;
			Index = Index-1;
		EndDo;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// The procedure is called on update to SL version 2.1.3.1.
Procedure UpdatePredefinedUserContactInformationKinds() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return;
	EndIf;
	
	ModuleContactsManager = Common.CommonModule("ContactsManager");
	
	KindParameters = ModuleContactsManager.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind = "UserEmail";
	KindParameters.CanChangeEditMethod = True;
	KindParameters.AllowMultipleValueInput = True;
	KindParameters.Order = 1;
	ModuleContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ModuleContactsManager.ContactInformationKindParameters("Phone");
	KindParameters.Kind = "UserPhone";
	KindParameters.CanChangeEditMethod = True;
	KindParameters.AllowMultipleValueInput = True;
	KindParameters.Order = 2;
	ModuleContactsManager.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

// The procedure is called on update to SL version 2.1.4.1.
Procedure MoveExternalUserGroupsToRoot() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ExternalUsersGroups.Ref
	|FROM
	|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|WHERE
	|	ExternalUsersGroups.Parent.AllAuthorizationObjects = TRUE";
	
	Result = Query.Execute().Unload();
	
	For Each UserGroupRow In Result Do
		UsersGroup = UserGroupRow.Ref.GetObject();
		UsersGroup.Parent = Catalogs.ExternalUsersGroups.EmptyRef();
		InfobaseUpdate.WriteData(UsersGroup);
	EndDo;
	
EndProcedure

// The procedure is called on update to SL version 2.2.2.
Procedure FillUserAuthenticationProperties() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("BlankIBUserID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.IBUserID,
	|	Users.IBUserProperies
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID <> &BlankIBUserID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.IBUserID,
	|	ExternalUsers.IBUserProperies
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID <> &BlankIBUserID";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		InfobaseUser = InfoBaseUsers.FindByUUID(
			Selection.IBUserID);
		
		If InfobaseUser = Undefined
		 Or Not Users.CanSignIn(InfobaseUser) Then
			
			Continue;
		EndIf;
		
		UserObject = Selection.Ref.GetObject();
		StoredProperties = StoredIBUserProperties(UserObject);
		StoredProperties.CanSignIn    = True;
		StoredProperties.StandardAuthentication = InfobaseUser.StandardAuthentication;
		StoredProperties.OpenIDAuthentication      = InfobaseUser.OpenIDAuthentication;
		StoredProperties.OSAuthentication          = InfobaseUser.OSAuthentication;
		
		NewProperties = New ValueStorage(StoredProperties);
		If Not Common.DataMatch(UserObject.IBUserProperies, NewProperties) Then
			UserObject.IBUserProperies = NewProperties;
			InfobaseUpdate.WriteData(UserObject);
		EndIf;
	EndDo;
	
EndProcedure

// The procedure is called on update to SL version 2.2.2.4.
Procedure AddSystemAdministratorRoleForUsersWithFullAccess() Export
	
	If Not AccessRight("Administration", Metadata, Metadata.Roles.FullRights) Then
		Return;
	EndIf;
	
	If Not StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	AllIBUsers = InfoBaseUsers.GetUsers();
	
	For each InfobaseUser In AllIBUsers Do
		If Not InfobaseUser.Roles.Contains(Metadata.Roles.FullRights) Then
			Continue;
		EndIf;
		If InfobaseUser.Roles.Contains(Metadata.Roles.SystemAdministrator) Then
			Continue;
		EndIf;
		
		InfobaseUser.Roles.Add(Metadata.Roles.SystemAdministrator);
		InfobaseUser.Write();
	EndDo;
	
EndProcedure

// The procedure is called on update to SL version 2.3.1.16.
Procedure ClearShowInListAttributeForAllIBUsers() Export
	
	ValueManager = Constants.UseExternalUsers.CreateValueManager();
	ValueManager.Read();
	
	If ValueManager.Value = False Then
		Return;
	EndIf;
	
	ValueManager.ClearShowInListAttributeForAllIBUsers();
	
EndProcedure

// The procedure is called on update to SL version 2.3.1.37.
Procedure FillExternalUserGroupsAssignment() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExternalUsersGroups.Ref AS Ref
	|FROM
	|	Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|WHERE
	|	(ExternalUsersGroups.Predefined
	|			OR NOT ExternalUsersGroups.Ref IN
	|					(SELECT DISTINCT
	|						ExternalUsersGroups.Ref
	|					FROM
	|						Catalog.ExternalUsersGroups.Purpose AS ExternalUserGroupsAssignment))";
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		GroupObject = Selection.Ref.GetObject();
		
		If GroupObject.Predefined Or GroupObject.DeleteAuthorizationObjectsType = Undefined Then // any users
			
			BlankRefs = UsersInternalCached.BlankRefsOfAuthorizationObjectTypes();
			For Each BlankRef In BlankRefs Do
				NewRow = GroupObject.Purpose.Add();
				NewRow.UsersType = BlankRef;
			EndDo;
			
		Else
			
			NewRow = GroupObject.Purpose.Add();
			NewRow.UsersType = GroupObject.DeleteAuthorizationObjectsType;
			
		EndIf;
		
		InfobaseUpdate.WriteData(GroupObject);
		
	EndDo;
	
EndProcedure

// The procedure is called on update to SL version 2.3.2.30.
Procedure MoveDesignerPasswordLengthAndComplexitySettings() Export
	
	AllSettings = UsersInternalCached.Settings();
	
	If Not AllSettings.CommonAuthorizationSettings
	 Or GetUserPasswordMinLength() = 0
	   AND Not GetUserPasswordStrengthCheck()
	 Or AllSettings.Users.MinPasswordLength <> 0
	 Or AllSettings.Users.PasswordMustMeetComplexityRequirements <> 0
	 Or AllSettings.ExternalUsers.MinPasswordLength <> 0
	 Or AllSettings.ExternalUsers.PasswordMustMeetComplexityRequirements <> 0 Then
		
		Return;
	EndIf;
	
	Lock = New DataLock;
	LockItem  = Lock.Add("Constant.UserAuthorizationSettings");
	
	BeginTransaction();
	Try
		Lock.Lock();
		AuthorizationSettings = AuthorizationSettings();
		
		ComplexPassword          = GetUserPasswordStrengthCheck();
		MinPasswordLength = GetUserPasswordMinLength();
		
		AuthorizationSettings.Users.MinPasswordLength = MinPasswordLength;
		AuthorizationSettings.Users.PasswordMustMeetComplexityRequirements = ComplexPassword;
		If Constants.UseExternalUsers.Get() Then
			AuthorizationSettings.ExternalUsers.MinPasswordLength = MinPasswordLength;
			AuthorizationSettings.ExternalUsers.PasswordMustMeetComplexityRequirements = ComplexPassword;
		EndIf;
		
		Constants.UserAuthorizationSettings.Set(New ValueStorage(AuthorizationSettings));
		
		If GetUserPasswordMinLength() <> 0 Then
			SetUserPasswordMinLength(0);
		EndIf;
		If GetUserPasswordStrengthCheck() Then
			SetUserPasswordStrengthCheck(False);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// The procedure is called on update to SL version 2.4.1.1.
Procedure AddOpenExternalReportsAndDataProcessorsRightForAdministrators() Export
	
	RoleToAdd = Metadata.Roles.InteractiveOpenExtReportsAndDataProcessors;
	AdministratorRole = Metadata.Roles.SystemAdministrator;
	IBUsers = InfoBaseUsers.GetUsers();
	
	For Each InfobaseUser In IBUsers Do
		
		If InfobaseUser.Roles.Contains(AdministratorRole)
		   AND Not InfobaseUser.Roles.Contains(RoleToAdd) Then
			
			InfobaseUser.Roles.Add(RoleToAdd);
			InfobaseUser.Write();
		EndIf;
		
	EndDo;
	
EndProcedure

// The procedure is called on update to SL version 2.4.1.1.
Procedure RenameExternalReportAndDataProcessorOpeningSolutionStorageKey() Export
	
	Lock = New DataLock;
	Lock.Add("Constant.IBAdministrationParameters");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		IBAdministrationParameters = Constants.IBAdministrationParameters.Get().Get();
		
		If TypeOf(IBAdministrationParameters) = Type("Structure")
		   AND IBAdministrationParameters.Property("OpenExternalReportsAndDataProcessorsAllowed") Then
			
			If Not IBAdministrationParameters.Property("OpenExternalReportsAndDataProcessorsDecisionMade")
			   AND TypeOf(IBAdministrationParameters.OpenExternalReportsAndDataProcessorsAllowed) = Type("Boolean")
			   AND IBAdministrationParameters.OpenExternalReportsAndDataProcessorsAllowed Then
				
				IBAdministrationParameters.Insert("OpenExternalReportsAndDataProcessorsDecisionMade", True);
			EndIf;
			IBAdministrationParameters.Delete("OpenExternalReportsAndDataProcessorsAllowed");
			Constants.IBAdministrationParameters.Set(New ValueStorage(IBAdministrationParameters));
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Managing user settings.

// Called form the UsersSettings processing, and it generates a list of users settings.
// 
//
Procedure FillSettingsLists(Parameters, StorageAddress) Export
	
	If Parameters.InfoBaseUser <> UserName()
	   AND Not AccessRight("DataAdministration", Metadata) Then
		
		Raise NStr("ru = 'Недостаточно прав для получения настроек пользователя.'; en = 'Insufficient rights to view user settings.'; pl = 'Brak wystarczających uprawnień, aby uzyskać ustawienia użytkownika.';es_ES = 'Insuficientes derechos para recibir los ajustes del usuario.';es_CO = 'Insuficientes derechos para recibir los ajustes del usuario.';tr = 'Kullanıcı ayarlarını almak için haklar yetersizdir.';it = 'Permessi insufficienti per vedere le impostazioni utente.';de = 'Nicht genügend Rechte, um Benutzereinstellungen zu erhalten.'");
	EndIf;
	
	DataProcessors.UsersSettings.FillSettingsLists(Parameters);
	
	Result = New Structure;
	Result.Insert("InterfaceSettings");
	Result.Insert("ReportSettingsTree");
	Result.Insert("OtherSettingsTree");
	Result.Insert("UserReportOptions");
	
	FillPropertyValues(Result, Parameters);
	PutToTempStorage(Result, StorageAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other user settings.

Procedure OnGetOtherUserSettings(UserInfo, Settings) Export
	
	SSLSubsystemsIntegration.OnGetOtherSettings(UserInfo, Settings);
	UsersOverridable.OnGetOtherSettings(UserInfo, Settings);
	
EndProcedure

Procedure OnSaveOtherUserSettings(UserInfo, Settings) Export
	
	SSLSubsystemsIntegration.OnSaveOtherSetings(UserInfo, Settings);
	UsersOverridable.OnSaveOtherSetings(UserInfo, Settings);
	
EndProcedure

Procedure OnDeleteOtherUserSettings(UserInfo, Settings) Export
	
	SSLSubsystemsIntegration.OnDeleteOtherSettings(UserInfo, Settings);
	UsersOverridable.OnDeleteOtherSettings(UserInfo, Settings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

// At the first start of a subordinate node clears the infobase user IDs copied during the creation 
// of an initial image.
//
Procedure ClearNonExistingIBUsersIDs()
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	EmptyUniqueID = New UUID("00000000-0000-0000-0000-000000000000");
	
	Query = New Query;
	Query.SetParameter("EmptyUniqueID", EmptyUniqueID);
	
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.IBUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID <> &EmptyUniqueID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.IBUserID
	|FROM
	|	Catalog.Users AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID <> &EmptyUniqueID";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		InfobaseUser = InfoBaseUsers.FindByUUID(
			Selection.IBUserID);
		
		If InfobaseUser <> Undefined Then
			Continue;
		EndIf;
		
		CurrentObject = Selection.Ref.GetObject();
		CurrentObject.IBUserID = EmptyUniqueID;
		InfobaseUpdate.WriteData(CurrentObject);
	EndDo;
	
EndProcedure

// Updates the external user when the presentation of its authorization object is changed.
Procedure UpdateExternalUserPresentation(AuthorizationObjectRef)
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT TOP 1
	|	ExternalUsers.Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.AuthorizationObject = &AuthorizationObjectRef
	|	AND ExternalUsers.Description <> &NewAuthorizationObjectPresentation");
	Query.SetParameter("AuthorizationObjectRef", AuthorizationObjectRef);
	Query.SetParameter("NewAuthorizationObjectPresentation", String(AuthorizationObjectRef));
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute();
		
		If NOT QueryResult.IsEmpty() Then
			Selection = QueryResult.Select();
			Selection.Next();
			
			ExternalUserObject = Selection.Ref.GetObject();
			ExternalUserObject.Description = String(AuthorizationObjectRef);
			ExternalUserObject.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function CurrentUserInfoRecordErrorTextTemplate()
	
	Return
		NStr("ru = 'Не удалось записать сведения о текущем пользователе по причине:
		           |%1
		           |
		           |Обратитесь к администратору.'; 
		           |en = 'Cannot save the current user details. Reason:
		           |%1
		           |
		           |Please contact the administrator.'; 
		           |pl = 'Nie można zapisać aktualnych informacji o użytkowniku z powodu:
		           |%1
		           |
		           | Skontaktuj się z administratorem.';
		           |es_ES = 'No se ha podido guardar la información del usuario actual a causa de:
		           |%1
		           |
		           |Diríjase al administrador.';
		           |es_CO = 'No se ha podido guardar la información del usuario actual a causa de:
		           |%1
		           |
		           |Diríjase al administrador.';
		           |tr = 'Aşağıdaki nedenle mevcut kullanıcı hakkındaki bilgiler kaydedilemedi: 
		           |%1
		           |
		           | Yöneticiye başvurun.';
		           |it = 'Impossibile salvare i dettagli dell''utente corrente. Motivo:
		           |%1
		           |
		           |Si prega di contattare l''amministratore.';
		           |de = 'Konnte die Informationen über den aktuellen Benutzer nicht aufschreiben, weil:
		           |%1
		           |
		           |Kontaktieren Sie den Administrator.'");
	
EndFunction

Function AuthorizationNotCompletedMessageTextWithLineBreak()
	
	Return NStr("ru = 'Авторизация не выполнена. Работа системы будет завершена.'; en = 'The authorization was not completed. The application will be closed.'; pl = 'Autoryzacja nieudana. System zostanie zamknięty.';es_ES = 'Autorización no realizada. El uso del sistema será terminado.';es_CO = 'Autorización no realizada. El uso del sistema será terminado.';tr = 'Yetkilendirme yapılamadı. Sistemin çalışması tamamlanacaktır.';it = 'L''autorizzazione non è stata completata. L''applicazione verrà chiusa.';de = 'Autorisierung fehlgeschlagen. Das System wird heruntergefahren.'")
		+ Chars.LF + Chars.LF;
	
EndFunction

Function CurrentUserSessionParameterValues()
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return CurrentUserUnavailableInSessionWithoutSeparatorsMessageText();
	EndIf;
	
	ErrorTitle = NStr("ru = 'Не удалось установить параметр сеанса CurrentUser.'; en = 'Cannot set CurrentUser session parameter.'; pl = 'Nie można ustawić parametru sesji CurrentUser session.';es_ES = 'No se ha podido especificar el parámetro de la sesión CurrentUser.';es_CO = 'No se ha podido especificar el parámetro de la sesión CurrentUser.';tr = 'GeçerliKullanıcı oturumun parametresi belirlenemedi.';it = 'Non è stato possibile impostare il parametro della sessione UtenteCorrente.';de = 'Der Sitzungsparameter AktuellerBenutzer konnte nicht gesetzt werden.'") + Chars.LF;
	
	BeginTransaction();
	Try
		UserInfo = FindCurrentUserInCatalog();
		
		If UserInfo.CreateUser Then
			CreateCurrentUserInCatalog(UserInfo);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Not UserInfo.CreateUser
	   AND Not UserInfo.UserFound Then
		
		Return ErrorTitle + UserNotFoundInCatalogMessageText(
			UserInfo.UserName);
	EndIf;
	
	If UserInfo.CurrentUser        = Undefined
	 Or UserInfo.CurrentExternalUser = Undefined Then
		
		Return ErrorTitle + UserNotFoundInCatalogMessageText(
				UserInfo.UserName) + Chars.LF
			+ NStr("ru = 'Возникла внутренняя ошибка при поиске пользователя.'; en = 'Internal user search error.'; pl = 'Wystąpił błąd wewnętrzny podczas wyszukiwania użytkownika.';es_ES = 'Al buscar el usuario, ha ocurrido un error interno.';es_CO = 'Al buscar el usuario, ha ocurrido un error interno.';tr = 'Kullanıcıyı ararken bir iç hata oluştu.';it = 'Errore ricerca utente interno.';de = 'Bei der Suche nach dem Benutzer ist ein interner Fehler aufgetreten.'");
	EndIf;
	
	Values = New Structure;
	Values.Insert("CurrentUser",        UserInfo.CurrentUser);
	Values.Insert("CurrentExternalUser", UserInfo.CurrentExternalUser);
	
	Return Values;
	
EndFunction

Function CurrentUserUnavailableInSessionWithoutSeparatorsMessageText()
	
	Return
		NStr("ru = 'Недопустимое получение параметра сеанса CurrentUser
		           |в сеансе без указания всех разделителей.'; 
		           |en = 'Cannot get CurrentUser session parameter
		           |in a session that does not have all separators specified.'; 
		           |pl = 'Nieprawidłowe pobieranie parametru CurrentUser
		           |w sesji bez określania wszystkich ograniczników.';
		           |es_ES = 'Recibo del parámetro de la sesión CurrentUser
		           |inválido es una sesión sin especificar todos los separadores.';
		           |es_CO = 'Recibo del parámetro de la sesión CurrentUser
		           |inválido es una sesión sin especificar todos los separadores.';
		           |tr = 'Geçersiz MevcutKullanıcı oturumu parametre girişi, 
		           |tüm ayırıcıların belirlenmediği oturumdur.';
		           |it = 'Ottenimento non permesso del parametro della sessione UtenteCorrente
		           |nella sessione senza indicazione di tutti i separatori.';
		           |de = 'Es ist nicht zulässig, den Sitzungsparameter AktuellerBenutzer
		           |in der Sitzung zu empfangen, ohne alle Trennzeichen anzugeben.'");
	
EndFunction

Function FindCurrentUserInCatalog()
	
	Result = New Structure;
	Result.Insert("UserName",             Undefined);
	Result.Insert("UserFullName",       Undefined);
	Result.Insert("IBUserID", Undefined);
	Result.Insert("UserFound",          False);
	Result.Insert("CreateUser",         False);
	Result.Insert("NewRef",                Undefined);
	Result.Insert("Internal",                   False);
	Result.Insert("CurrentUser",         Undefined);
	Result.Insert("CurrentExternalUser",  Catalogs.ExternalUsers.EmptyRef());
	
	CurrentIBUser = InfoBaseUsers.CurrentUser();
	
	If IsBlankString(CurrentIBUser.Name) Then
		UnspecifiedUserProperties = UnspecifiedUserProperties();
		
		Result.UserName       = UnspecifiedUserProperties.FullName;
		Result.UserFullName = UnspecifiedUserProperties.FullName;
		Result.NewRef          = UnspecifiedUserProperties.StandardRef;
		
		If UnspecifiedUserProperties.Ref = Undefined Then
			Result.CreateUser = True;
			Result.Internal = True;
			Result.IBUserID = "";
		Else
			Result.UserFound = True;
			Result.CurrentUser = UnspecifiedUserProperties.Ref;
		EndIf;
		
		Return Result;
	EndIf;

	Result.UserName             = CurrentIBUser.Name;
	Result.IBUserID = CurrentIBUser.UUID;
	
	Users.FindAmbiguousIBUsers(Undefined, Result.IBUserID);
	
	Query = New Query;
	Query.Parameters.Insert("IBUserID", Result.IBUserID);
	
	Query.Text =
	"SELECT TOP 1
	|	ExternalUsers.Ref AS Ref
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID = &IBUserID";
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		If Not ExternalUsers.UseExternalUsers() Then
			Return NStr("ru = 'Внешние пользователи отключены.'; en = 'External users are disabled.'; pl = 'Użytkownicy zewnętrzni są wyłączeni.';es_ES = 'Usuarios externos desactivados.';es_CO = 'Usuarios externos desactivados.';tr = 'Dış kullanıcılar devre dışı.';it = 'Gli utenti esterni sono disabilitati.';de = 'Externe Benutzer sind deaktiviert.'");
		EndIf;
		
		Result.CurrentUser        = Catalogs.Users.EmptyRef();
		Result.CurrentExternalUser = Selection.Ref;
		
		Result.UserFound = True;
		Return Result;
	EndIf;

	Query.Text =
	"SELECT TOP 1
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID = &IBUserID";
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result.CurrentUser = Selection.Ref;
		Result.UserFound = True;
		Return Result;
	EndIf;
	
	SaaSIntegration.OnNoCurrentUserInCatalog(
		Result.CreateUser);
	
	If Not Result.CreateUser
	   AND Not AdministratorRolesAvailable() Then
		
		Return Result;
	EndIf;
	
	Result.IBUserID = CurrentIBUser.UUID;
	Result.UserFullName       = CurrentIBUser.FullName;
	
	If Result.CreateUser Then
		Return Result;
	EndIf;
	
	UserByDescription = UserRefByFullDescription(
		Result.UserFullName);
	
	If UserByDescription <> Undefined Then
		Result.UserFound  = True;
		Result.CurrentUser = UserByDescription;
	Else
		Result.CreateUser = True;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure CreateCurrentUserInCatalog(UserInfo)
	
	BeginTransaction();
	Try
		If UserInfo.NewRef = Undefined Then
			UserInfo.NewRef = Catalogs.Users.GetRef();
		EndIf;
		
		UserInfo.CurrentUser = UserInfo.NewRef;
		
		SessionParameters.CurrentUser        = UserInfo.CurrentUser;
		SessionParameters.CurrentExternalUser = UserInfo.CurrentExternalUser;
		SessionParameters.AuthorizedUser = UserInfo.CurrentUser;
		
		NewUser = Catalogs.Users.CreateItem();
		NewUser.Internal    = UserInfo.Internal;
		NewUser.Description = UserInfo.UserFullName;
		NewUser.SetNewObjectRef(UserInfo.NewRef);
		
		If ValueIsFilled(UserInfo.IBUserID) Then
			
			IBUserDetails = New Structure;
			IBUserDetails.Insert("Action", "Write");
			IBUserDetails.Insert("UUID",
				UserInfo.IBUserID);
			
			NewUser.AdditionalProperties.Insert(
				"IBUserDetails", IBUserDetails);
		EndIf;
		
		SaaSIntegration.OnAutoCreateCurrentUserInCatalog(
			NewUser);
		
		NewUser.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		ParametersToClear = New Array;
		ParametersToClear.Add("CurrentUser");
		ParametersToClear.Add("CurrentExternalUser");
		ParametersToClear.Add("AuthorizedUser");
		SessionParameters.Clear(ParametersToClear);
		Raise;
	EndTry;
	
EndProcedure

Function UserNotFoundInCatalogMessageText(Username)
	
	If ExternalUsers.UseExternalUsers() Then
		ErrorMessageTemplate =
			NStr("ru = 'Пользователь ""%1"" не найден в справочниках
			           |""Пользователи"" и ""Внешние пользователи"".
			           |
			           |Обратитесь к администратору.'; 
			           |en = 'User ""%1"" is not found in
			           |""Users"" and ""External users"" catalogs.
			           |
			           |Please contact the administrator.'; 
			           |pl = 'Użytkownik ""%1"" nie został znaleziony w katalogach 
			           |""Użytkownicy"" i ""Użytkownicy zewnętrzni"". 
			           |
			           |Skontaktuj się z administratorem.';
			           |es_ES = 'El usuario ""%1"" no se ha encontrado en los catálogos 
			           |""Usuarios"" y ""Usuarios externos"". 
			           |
			           |Diríjase al administrador.';
			           |es_CO = 'El usuario ""%1"" no se ha encontrado en los catálogos 
			           |""Usuarios"" y ""Usuarios externos"". 
			           |
			           |Diríjase al administrador.';
			           |tr = '""%1"" kullanıcı 
			           | ""Kullanıcılar"" ve ""Harici kullanıcılar"" rehberlerinde bulunamadı. 
			           |
			           | Yöneticinize başvurun.';
			           |it = 'L''utente ""%1"" non è stato
			           |trovato nella directory ""Utenti"" e ""Utenti esterni"".
			           |
			           |Si prega di contattare l''amministratore.';
			           |de = 'Der Benutzer ""%1"" ist in den Katalogen
			           |""Benutzer"" und ""Externe Benutzer"" nicht enthalten.
			           |
			           |Wenden Sie sich an den Administrator.'");
	Else
		ErrorMessageTemplate =
			NStr("ru = 'Пользователь ""%1"" не найден в справочнике ""Пользователи"".
			           |
			           |Обратитесь к администратору.'; 
			           |en = 'User ""%1"" is not found in ""Users"" catalog.
			           |
			           |Please contact the administrator.'; 
			           |pl = 'Użytkownik ""%1"" nie został znaleziony w katalogu ""Użytkownicy"".
			           |
			           |Skontaktuj się z administratorem.';
			           |es_ES = 'El usuario ""%1"" no se ha encontrado en el catálogo ""Usuarios"".
			           |
			           |Diríjase al administrador.';
			           |es_CO = 'El usuario ""%1"" no se ha encontrado en el catálogo ""Usuarios"".
			           |
			           |Diríjase al administrador.';
			           |tr = '""%1"" Kullanıcısı ""Kullanıcılar"" rehberinde bulunamadı. 
			           |
			           | Yöneticinize başvurun.';
			           |it = 'L''utente ""%1"" non è stato trovato nella directory ""Utenti"".
			           |
			           |Si prega di contattare l''amministratore.';
			           |de = 'Benutzer ""%1"" wurde nicht im Verzeichnis ""Benutzer"" gefunden.
			           |
			           |Bitte wenden Sie sich an den Administrator.'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate, Username);
	
EndFunction

Function UserRefByFullDescription(FullName)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.IBUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Description = &FullName";
	
	Query.SetParameter("FullName", FullName);
	
	Result = Undefined;
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute();
		If NOT QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			Selection.Next();
			
			If NOT Users.IBUserOccupied(Selection.IBUserID) Then
				Result = Selection.Ref;
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
	
EndFunction

Function SessionParametersSettingResult(RegisterInLog)
	
	Try
		Users.AuthorizedUser();
	Except
		ErrorInformation = ErrorInfo();
		Return AuthorizationErrorBriefPresentationAfterRegisterInLog(ErrorInformation,
			, RegisterInLog);
	EndTry;
	
	Return "";
	
EndFunction

Function AuthorizationErrorBriefPresentationAfterRegisterInLog(ErrorInformation, ErrorTemplate = "", RegisterInLog = True)
	
	If TypeOf(ErrorInformation) = Type("ErrorInfo") Then
		BriefPresentation   = BriefErrorDescription(ErrorInformation);
		DetailedPresentation = DetailErrorDescription(ErrorInformation);
	Else
		BriefPresentation   = ErrorInformation;
		DetailedPresentation = ErrorInformation;
	EndIf;
	
	If ValueIsFilled(ErrorTemplate) Then
		BriefPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			ErrorTemplate, BriefErrorDescription(ErrorInformation));
		
		DetailedPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			ErrorTemplate, DetailErrorDescription(ErrorInformation));
	EndIf;
	
	BriefPresentation   = AuthorizationNotCompletedMessageTextWithLineBreak() + BriefPresentation;
	DetailedPresentation = AuthorizationNotCompletedMessageTextWithLineBreak() + DetailedPresentation;
	
	If RegisterInLog Then
		WriteLogEvent(
			NStr("ru = 'Пользователи.Ошибка входа в программу'; en = 'Users.Authorization error'; pl = 'Użytkownicy.Błąd podczas wprowadzania programu';es_ES = 'Usuarios.Error de entrar en el programa';es_CO = 'Usuarios.Error de entrar en el programa';tr = 'Kullanıcılar. Uygulamaya giriş hatası';it = 'Utenti.Errore autorizzazione';de = 'Benutzer.Fehler bei der Eingabe des Programms'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailedPresentation);
	EndIf;
	
	Return BriefPresentation;
	
EndFunction

// The function is used in the following procedures: UpdateUsersGroupsContents,
// UpdateExternalUserGroupCompositions.
//
// Parameters:
//  Table - a full name of metadata object.
//
// Returns:
//  ValueTable - a table with the following columns:
//   * Reference - a reference to catalog item.
//   * Parent - a reference to the parent item of the catalog.
//
Function ReferencesInParentHierarchy(Table)
	
	// Preparing parent group content.
	Query = New Query;
	Query.Text =
	"SELECT
	|	ParentsReferences.Ref AS Ref,
	|	ParentsReferences.Parent AS Parent
	|FROM
	|	&Table AS ParentsReferences";
	Query.Text = StrReplace(Query.Text, "&Table", Table);
	
	ParentsRefs = Query.Execute().Unload();
	ParentsRefs.Indexes.Add("Parent");
	ReferencesInParentHierarchy = ParentsRefs.Copy(New Array);
	
	For each RefDetails In ParentsRefs Do
		NewRow = ReferencesInParentHierarchy.Add();
		NewRow.Parent = RefDetails.Ref;
		NewRow.Ref   = RefDetails.Ref;
		
		FillRefsInParentHierarchy(RefDetails.Ref, RefDetails.Ref, ParentsRefs, ReferencesInParentHierarchy);
	EndDo;
	
	Return ReferencesInParentHierarchy;
	
EndFunction

Procedure FillRefsInParentHierarchy(Val Parent, Val CurrentParent, Val ParentsRefs, Val ReferencesInParentHierarchy)
	
	ParentRefs = ParentsRefs.FindRows(New Structure("Parent", CurrentParent));
	
	For each RefDetails In ParentRefs Do
		NewRow = ReferencesInParentHierarchy.Add();
		NewRow.Parent = Parent;
		NewRow.Ref   = RefDetails.Ref;
		
		FillRefsInParentHierarchy(Parent, RefDetails.Ref, ParentsRefs, ReferencesInParentHierarchy);
	EndDo;
	
EndProcedure

// The function is used in the following procedures: UpdateUsersGroupsContents,
// UpdateExternalUserGroupCompositions.
//
Procedure UpdateAllUsersGroupComposition(User,
                                              UpdateExternalUserGroup = False,
                                              ItemsToChange = Undefined,
                                              ModifiedGroups   = Undefined)
	
	If UpdateExternalUserGroup Then
		AllUsersGroup = Catalogs.ExternalUsersGroups.AllExternalUsers;
	Else
		AllUsersGroup = Catalogs.UserGroups.AllUsers;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("AllUsersGroup", AllUsersGroup);
	
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	CASE
	|		WHEN Users.DeletionMark
	|			THEN FALSE
	|		WHEN Users.Invalid
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Used
	|INTO Users
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	&FilterUser
	|
	|INDEX BY
	|	Users.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&AllUsersGroup AS UsersGroup,
	|	Users.Ref AS User,
	|	Users.Used
	|FROM
	|	Users AS Users
	|		LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.UsersGroup = &AllUsersGroup)
	|			AND (UserGroupCompositions.User = Users.Ref)
	|			AND (UserGroupCompositions.Used = Users.Used)
	|WHERE
	|	UserGroupCompositions.User IS NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	Users.Ref,
	|	Users.Ref,
	|	Users.Used
	|FROM
	|	Users AS Users
	|		LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.UsersGroup = Users.Ref)
	|			AND (UserGroupCompositions.User = Users.Ref)
	|			AND (UserGroupCompositions.Used = Users.Used)
	|WHERE
	|	UserGroupCompositions.User IS NULL ";
	
	If UpdateExternalUserGroup Then
		Query.Text = StrReplace(Query.Text, "Catalog.Users", "Catalog.ExternalUsers");
	EndIf;
	
	If User = Undefined Then
		Query.Text = StrReplace(Query.Text, "&FilterUser", "TRUE");
	Else
		Query.SetParameter("User", User);
		Query.Text = StrReplace(
			Query.Text, "&FilterUser", "Users.Ref IN (&User)");
	EndIf;
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		RecordSet = InformationRegisters.UserGroupCompositions.CreateRecordSet();
		Record = RecordSet.Add();
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			RecordSet.Filter.UsersGroup.Set(Selection.UsersGroup);
			RecordSet.Filter.User.Set(Selection.User);
			FillPropertyValues(Record, Selection);
			RecordSet.Write(); // Adding missing records about relations.
			
			If ItemsToChange <> Undefined Then
				ItemsToChange.Insert(Selection.User);
			EndIf;
		EndDo;
		
		If ModifiedGroups <> Undefined Then
			ModifiedGroups.Insert(AllUsersGroup);
		EndIf;
	EndIf;
	
EndProcedure

// Used in the UpdateExternalUserGroupCompositions procedure.
Procedure UpdateGroupCompositionsByAuthorizationObjectType(ExternalUsersGroup,
		ExternalUser, ItemsToChange, ModifiedGroups)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExternalUsersGroups.Ref AS UsersGroup,
	|	ExternalUsers.Ref AS User,
	|	CASE
	|		WHEN ExternalUsersGroups.DeletionMark
	|			THEN FALSE
	|		WHEN ExternalUsers.DeletionMark
	|			THEN FALSE
	|		WHEN ExternalUsers.Invalid
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Used
	|INTO NewCompositions
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|		INNER JOIN Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|		ON (ExternalUsersGroups.AllAuthorizationObjects = TRUE)
	|			AND (&FilterExternalUserGroups1)
	|			AND (TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					Catalog.ExternalUsersGroups.Purpose AS UsersTypes
	|				WHERE
	|					UsersTypes.Ref = ExternalUsersGroups.Ref
	|					AND VALUETYPE(UsersTypes.UsersType) = VALUETYPE(ExternalUsers.AuthorizationObject)))
	|			AND (&FilterExternalUser1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.User
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		LEFT JOIN NewCompositions AS NewCompositions
	|		ON UserGroupCompositions.UsersGroup = NewCompositions.UsersGroup
	|			AND UserGroupCompositions.User = NewCompositions.User
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups)
	|	AND CAST(UserGroupCompositions.UsersGroup AS Catalog.ExternalUsersGroups).AllAuthorizationObjects = TRUE
	|	AND &FilterExternalUserGroups2
	|	AND &FilterExternalUser2
	|	AND NewCompositions.User IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NewCompositions.UsersGroup,
	|	NewCompositions.User,
	|	NewCompositions.Used
	|FROM
	|	NewCompositions AS NewCompositions
	|		LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.UsersGroup = NewCompositions.UsersGroup)
	|			AND (UserGroupCompositions.User = NewCompositions.User)
	|			AND (UserGroupCompositions.Used = NewCompositions.Used)
	|WHERE
	|	UserGroupCompositions.User IS NULL ";
	
	If ExternalUsersGroup = Undefined Then
		Query.Text = StrReplace(Query.Text, "&FilterExternalUserGroups1", "TRUE");
		Query.Text = StrReplace(Query.Text, "&FilterExternalUserGroups2", "TRUE");
	Else
		Query.SetParameter("ExternalUsersGroup", ExternalUsersGroup);
		Query.Text = StrReplace(
			Query.Text,
			"&FilterExternalUserGroups1",
			"ExternalUsersGroups.Ref IN (&ExternalUsersGroup)");
		Query.Text = StrReplace(
			Query.Text,
			"&FilterExternalUserGroups2",
			"UserGroupCompositions.UsersGroup IN (&ExternalUsersGroup)");
	EndIf;
	
	If ExternalUser = Undefined Then
		Query.Text = StrReplace(Query.Text, "&FilterExternalUser1", "TRUE");
		Query.Text = StrReplace(Query.Text, "&FilterExternalUser2", "TRUE");
	Else
		Query.SetParameter("ExternalUser", ExternalUser);
		Query.Text = StrReplace(
			Query.Text,
			"&FilterExternalUser1",
			"ExternalUsers.Ref IN (&ExternalUser)");
		Query.Text = StrReplace(
			Query.Text,
			"&FilterExternalUser2",
			"UserGroupCompositions.User IN (&ExternalUser)");
	EndIf;
	
	QueriesResults = Query.ExecuteBatch();
	
	If NOT QueriesResults[1].IsEmpty() Then
		RecordSet = InformationRegisters.UserGroupCompositions.CreateRecordSet();
		Selection = QueriesResults[1].Select();
		
		While Selection.Next() Do
			RecordSet.Filter.UsersGroup.Set(Selection.UsersGroup);
			RecordSet.Filter.User.Set(Selection.User);
			RecordSet.Write(); // Deleting unnecessary records about relations
			
			If ItemsToChange <> Undefined Then
				ItemsToChange.Insert(Selection.User);
			EndIf;
			
			If ModifiedGroups <> Undefined
			   AND TypeOf(Selection.UsersGroup)
			     = Type("CatalogRef.ExternalUsersGroups") Then
				
				ModifiedGroups.Insert(Selection.UsersGroup);
			EndIf;
		EndDo;
	EndIf;
	
	If NOT QueriesResults[2].IsEmpty() Then
		RecordSet = InformationRegisters.UserGroupCompositions.CreateRecordSet();
		Record = RecordSet.Add();
		Selection = QueriesResults[2].Select();
		
		While Selection.Next() Do
			RecordSet.Filter.UsersGroup.Set(Selection.UsersGroup);
			RecordSet.Filter.User.Set(Selection.User);
			FillPropertyValues(Record, Selection);
			RecordSet.Write(); // Adding missing records about relations.
			
			If ItemsToChange <> Undefined Then
				ItemsToChange.Insert(Selection.User);
			EndIf;
			
			If ModifiedGroups <> Undefined
			   AND TypeOf(Selection.UsersGroup)
			     = Type("CatalogRef.ExternalUsersGroups") Then
				
				ModifiedGroups.Insert(Selection.UsersGroup);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// The function is used in the following procedures: UpdateUsersGroupsContents,
// UpdateExternalUserGroupCompositions.
//
Procedure UpdateHierarchicalUserGroupCompositions(UsersGroup,
                                                         User,
                                                         ItemsToChange = Undefined,
                                                         ModifiedGroups   = Undefined)
	
	UpdateExternalUserGroups =
		TypeOf(UsersGroup) <> Type("CatalogRef.UserGroups");
	
	// Preparation user groups in parent hierarchy.
	Query = New Query;
	Query.Text =
	"SELECT
	|	ReferencesInParentHierarchy.Parent,
	|	ReferencesInParentHierarchy.Ref
	|INTO ReferencesInParentHierarchy
	|FROM
	|	&ReferencesInParentHierarchy AS ReferencesInParentHierarchy";
	
	Query.SetParameter("ReferencesInParentHierarchy", ReferencesInParentHierarchy(
		?(UpdateExternalUserGroups,
		  "Catalog.ExternalUsersGroups",
		  "Catalog.UserGroups") ));
	
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	// Preparing a query for the loop
	Query.Text =
	"SELECT
	|	UserGroupCompositions.User,
	|	UserGroupCompositions.Used
	|INTO UserGroupCompositions
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	&FilterUserInRegister
	|	AND UserGroupCompositions.UsersGroup = &UsersGroup
	|
	|INDEX BY
	|	UserGroupCompositions.User,
	|	UserGroupCompositions.Used
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserGroupsComposition.User AS User,
	|	MAX(CASE
	|			WHEN UserGroupsComposition.Ref.DeletionMark
	|				THEN FALSE
	|			WHEN UserGroupsComposition.User.DeletionMark
	|				THEN FALSE
	|			WHEN UserGroupsComposition.User.Invalid
	|				THEN FALSE
	|			ELSE TRUE
	|		END) AS Used
	|INTO UserGroupsNewCompositions
	|FROM
	|	Catalog.UserGroups.Content AS UserGroupsComposition
	|		INNER JOIN ReferencesInParentHierarchy AS ReferencesInParentHierarchy
	|		ON (ReferencesInParentHierarchy.Ref = UserGroupsComposition.Ref)
	|			AND (ReferencesInParentHierarchy.Parent = &UsersGroup)
	|			AND (&FilterUserInCatalog)
	|
	|GROUP BY
	|	UserGroupsComposition.User
	|
	|INDEX BY
	|	User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UserGroupCompositions.User
	|FROM
	|	UserGroupCompositions AS UserGroupCompositions
	|		LEFT JOIN UserGroupsNewCompositions AS UserGroupsNewCompositions
	|		ON UserGroupCompositions.User = UserGroupsNewCompositions.User
	|WHERE
	|	UserGroupsNewCompositions.User IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	&UsersGroup AS UsersGroup,
	|	UserGroupsNewCompositions.User,
	|	UserGroupsNewCompositions.Used
	|FROM
	|	UserGroupsNewCompositions AS UserGroupsNewCompositions
	|		LEFT JOIN UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.User = UserGroupsNewCompositions.User)
	|			AND (UserGroupCompositions.Used = UserGroupsNewCompositions.Used)
	|WHERE
	|	UserGroupCompositions.User IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UserGroups.Parent AS Parent
	|FROM
	|	Catalog.UserGroups AS UserGroups
	|WHERE
	|	UserGroups.Ref = &UsersGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP UserGroupCompositions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP UserGroupsNewCompositions";
	
	If User = Undefined Then
		FilterUserInRegister    = "TRUE";
		FilterUserInCatalog = "TRUE";
	Else
		Query.SetParameter("User", User);
		FilterUserInRegister    = "UserGroupCompositions.User IN (&User)";
		FilterUserInCatalog = "UserGroupsComposition.User IN (&User)";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&FilterUserInRegister",    FilterUserInRegister);
	Query.Text = StrReplace(Query.Text, "&FilterUserInCatalog", FilterUserInCatalog);
	
	If UpdateExternalUserGroups Then
		
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.UserGroups",
			"Catalog.ExternalUsersGroups");
		
		Query.Text = StrReplace(
			Query.Text,
			"UserGroupsComposition.User",
			"UserGroupsComposition.ExternalUser");
	EndIf;
	
	// Actions for current user group and parent groups
	While ValueIsFilled(UsersGroup) Do
		
		Query.SetParameter("UsersGroup", UsersGroup);
		
		QueryResults = Query.ExecuteBatch();
		
		If NOT QueryResults[2].IsEmpty() Then
			RecordSet = InformationRegisters.UserGroupCompositions.CreateRecordSet();
			Selection = QueryResults[2].Select();
			
			While Selection.Next() Do
				RecordSet.Filter.User.Set(Selection.User);
				RecordSet.Filter.UsersGroup.Set(UsersGroup);
				RecordSet.Write(); // Deleting unnecessary records about relations
				
				If ItemsToChange <> Undefined Then
					ItemsToChange.Insert(Selection.User);
				EndIf;
				
				If ModifiedGroups <> Undefined Then
					ModifiedGroups.Insert(UsersGroup);
				EndIf;
			EndDo;
		EndIf;
		
		If NOT QueryResults[3].IsEmpty() Then
			RecordSet = InformationRegisters.UserGroupCompositions.CreateRecordSet();
			Record = RecordSet.Add();
			Selection = QueryResults[3].Select();
			
			While Selection.Next() Do
				RecordSet.Filter.User.Set(Selection.User);
				RecordSet.Filter.UsersGroup.Set(Selection.UsersGroup);
				FillPropertyValues(Record, Selection);
				RecordSet.Write(); // Adding missing records about relations.
				
				If ItemsToChange <> Undefined Then
					ItemsToChange.Insert(Selection.User);
				EndIf;
				
				If ModifiedGroups <> Undefined Then
					ModifiedGroups.Insert(Selection.UsersGroup);
				EndIf;
			EndDo;
		EndIf;
		
		If NOT QueryResults[4].IsEmpty() Then
			Selection = QueryResults[4].Select();
			Selection.Next();
			UsersGroup = Selection.Parent;
		Else
			UsersGroup = Undefined;
		EndIf;
	EndDo;
	
EndProcedure

// Checks the rights of the specified infobase user.
//
// Parameters:
//  IBUser - InfobaseUser - a checked user.
//  CheckMode - String - OnWrite or OnStart.
//  IsExternalUser - Boolean - checks rights for external user.
//
Procedure CheckUserRights(InfobaseUser, CheckMode, IsExternalUser)
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	If DataSeparationEnabled AND InfobaseUser.DataSeparation.Count() = 0 Then
		Return; // Do not check unseparated users in SaaS.
	EndIf;
	
	If Not DataSeparationEnabled AND CheckMode = "OnStart" AND Not IsExternalUser Then
		Return; // Do not check user rights in the local mode.
	EndIf;
	
	
	UnavailableRoles = UsersInternalCached.UnavailableRolesByUserType(IsExternalUser);
	
	RolesToCheck = New ValueTable;
	RolesToCheck.Columns.Add("Role", New TypeDescription("MetadataObject"));
	For Each Role In InfobaseUser.Roles Do
		RolesToCheck.Add().Role = Role;
	EndDo;
	RolesToCheck.Indexes.Add("Role");
	
	If Not DataSeparationEnabled AND CheckMode = "BeforeWrite" Then
		
		PreviousIBUser = InfoBaseUsers.FindByUUID(
			InfobaseUser.UUID);
		
		If PreviousIBUser <> Undefined Then
			For Each Role In PreviousIBUser.Roles Do
				Row = RolesToCheck.Find(Role, "Role");
				If Row <> Undefined Then
					RolesToCheck.Delete(Row);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	UnavailableRolesToAdd = "";
	RolesAssignment = Undefined;
	
	For Each RoleDetails In RolesToCheck Do
		Role = RoleDetails.Role;
		RoleName = Role.Name;
		
		If UnavailableRoles.Get(RoleName) = Undefined Then
			Continue;
		EndIf;
		
		If RolesAssignment = Undefined Then
			RolesAssignment = UsersInternalCached.RolesAssignment();
		EndIf;
		
		If RolesAssignment.ForSystemAdministratorsOnly.Get(RoleName) <> Undefined Then
			TemplateText = NStr("ru = '""%1"" (предназначена только для администраторов системы)'; en = '""%1"" (for system administrators only)'; pl = '""%1"" (przeznaczony tylko dla administratorów systemu)';es_ES = '""%1"" (está especializado solo para los administradores del sistema)';es_CO = '""%1"" (está especializado solo para los administradores del sistema)';tr = '""%1"" (sadece sistem yöneticileri için)';it = '""%1"" (solo per amministratori di sistemaI)';de = '""%1"" (nur für Systemadministratoren gedacht)'");
		
		ElsIf DataSeparationEnabled
		        AND RolesAssignment.ForSystemUsersOnly.Get(RoleName) <> Undefined Then
			
			TemplateText = NStr("ru = '""%1"" (предназначена только для пользователей системы)'; en = '""%1"" (for system users only)'; pl = '""%1"" (tylko dla użytkowników systemu)';es_ES = '""%1"" (está especializado solo para los usuarios del sistema)';es_CO = '""%1"" (está especializado solo para los usuarios del sistema)';tr = '""%1"" (sadece sistem kullanıcıları için)';it = '""%1"" (solo per utenti di sistema)';de = '""%1"" (nur für Systembenutzer gedacht)'");
			
		ElsIf RolesAssignment.ForExternalUsersOnly.Get(RoleName) <> Undefined Then
			TemplateText = NStr("ru = '""%1"" (предназначена только для внешних пользователей)'; en = '""%1"" (for external users only)'; pl = '""%1"" (tylko dla użytkowników zewnętrznych)';es_ES = '""%1"" (está especializado solo para los usuarios externos)';es_CO = '""%1"" (está especializado solo para los usuarios externos)';tr = '""%1"" (sadece harici kullanıcılar için)';it = '""%1"" (solo per utenti esterni)';de = '""%1"" (nur für externe Benutzer gedacht)'");
			
		Else // It is an external user.
			TemplateText = NStr("ru = '""%1"" (предназначена только для пользователей)'; en = '""%1"" (for users only)'; pl = '""%1"" (tylko dla użytkowników)';es_ES = '""%1"" (está especializado solo para los usuarios)';es_CO = '""%1"" (está especializado solo para los usuarios)';tr = '""%1"" (sadece kullanıcılar için)';it = '""%1"" (solo per utenti)';de = '""%1"" (nur für Benutzer gedacht)'");
		EndIf;
		
		UnavailableRolesToAdd = UnavailableRolesToAdd
			+ StringFunctionsClientServer.SubstituteParametersToString(TemplateText, Role.Presentation()) + Chars.LF;;
	EndDo;
	
	UnavailableRolesToAdd = TrimAll(UnavailableRolesToAdd);
	
	If Not ValueIsFilled(UnavailableRolesToAdd) Then
		Return;
	EndIf;
	
	EventName = NStr("ru = 'Пользователи.Ошибка при установке ролей пользователю ИБ'; en = 'Users.Error setting roles for infobase user'; pl = 'Użytkownicy. Wystąpił błąd podczas przypisywania ról do użytkownika w bazie informacyjnej';es_ES = 'Usuarios.Ha ocurrido un error al asignar los roles al usuario de la infobase';es_CO = 'Usuarios.Ha ocurrido un error al asignar los roles al usuario de la infobase';tr = 'Kullanıcılar. Veritabanındaki kullanıcısına roller atanırken bir hata oluştu';it = 'Utenti.Errore nell''impostazione dei ruoli all''utente del Db';de = 'Benutzer. Beim Zuweisen von Rollen an den Benutzer der Infobase ist ein Fehler aufgetreten'",
	     CommonClientServer.DefaultLanguageCode());
	
	If CheckMode = "OnStart" Then
		If StrLineCount(UnavailableRolesToAdd) = 1 Then
			AuthorizationRegistrationText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Попытка входа пользователя %1 с недоступной ролью:
				           |%2.'; 
				           |en = 'Authorization denied for user %1. The user has an unavailable role:
				           |%2'; 
				           |pl = 'Próba zalogowania użytkownika %1 z niedostępną rolą:
				           |%2.';
				           |es_ES = 'Prueba de entrada del usuario %1 con el rol no disponible:
				           |%2.';
				           |es_CO = 'Prueba de entrada del usuario %1 con el rol no disponible:
				           |%2.';
				           |tr = 'Erişilemeyen bir rolle %1kullanıcı oturum açma girişimi:
				           |%2.';
				           |it = 'Autorizzazione vietata per l''utente %1. L''utente ha un ruolo non disponibile:
				           |%2';
				           |de = 'Versuch, den Benutzer %1 mit einer unzugänglichen Rolle anzumelden:
				           |%2.'"),
			InfobaseUser.FullName, UnavailableRolesToAdd);
		Else
			AuthorizationRegistrationText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Попытка входа пользователя %1 с недоступными ролями:
				           |%2.'; 
				           |en = 'Authorization denied for user %1. The user has unavailable roles:
				           |%2'; 
				           |pl = 'Próba zalogowania użytkownika %1 z niedostępnymi rolami:
				           |%2.';
				           |es_ES = 'Prueba de entrada del usuario %1 con los roles no disponibles:
				           |%2.';
				           |es_CO = 'Prueba de entrada del usuario %1 con los roles no disponibles:
				           |%2.';
				           |tr = 'Erişilemeyen rollerle %1 kullanıcı oturum açma girişimi:
				           |%2.';
				           |it = 'Tentativo di accesso dell''utente %1 con dei ruoli non disponibili:
				           |%2';
				           |de = 'Versuch, den Benutzer %1 mit unzugänglichen Rollen anzumelden:
				           |%2.'"),
			InfobaseUser.FullName, UnavailableRolesToAdd);
		EndIf;
		WriteLogEvent(EventName, EventLogLevel.Error, , InfobaseUser,
			AuthorizationRegistrationText);
		
		AuthorizationMessageText =
			NStr("ru = 'Невозможно выполнить вход из-за наличия недоступных ролей.
			           |Обратитесь к администратору.'; 
			           |en = 'Authorization denied due to unavailable roles.
			           |Please contact the administrator.'; 
			           |pl = 'Nie można się zalogować z powodu niedostępności ról.
			           |Skontaktuj się z administratorem.';
			           |es_ES = 'No se puede entrar a causa de los roles no disponibles.
			           |Diríjase al administrador.';
			           |es_CO = 'No se puede entrar a causa de los roles no disponibles.
			           |Diríjase al administrador.';
			           |tr = 'Erişilemeyen rollerden dolayı giriş yapılamadı. 
			           | Yöneticinize başvurun.';
			           |it = 'Non è stato possibile eseguire l''accesso a causa del possesso di ruoli non disponibili.
			           |Rivolgetevi all''amministratore.';
			           |de = 'Anmeldung aufgrund nicht verfügbarer Rollen nicht möglich.
			           |Wenden Sie sich an den Administrator.'");
		Raise AuthorizationMessageText;
	EndIf;
	
	If StrLineCount(UnavailableRolesToAdd) = 1 AND ValueIsFilled(UnavailableRolesToAdd) Then
		AddingRegistrationText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Попытка назначить пользователю %1 недоступную роль:
			           |%2.'; 
			           |en = 'Cannot assign the following unavailable role to user %1:
			           |%2.'; 
			           |pl = 'Próba przypisania użytkownikowi %1 niedostępnej roli:
			           |%2.';
			           |es_ES = 'Prueba de asignar al usuario %1un rol no disponible:
			           |%2.';
			           |es_CO = 'Prueba de asignar al usuario %1un rol no disponible:
			           |%2.';
			           |tr = '%1 kullanıcısına erişilmeyen rolü atama girişimi: 
			           |%2.';
			           |it = 'Impossibile assegnare il seguente ruolo non disponibile all''utente %1:
			           |%2.';
			           |de = 'Versuch, dem Benutzer %1 eine unzugängliche Rolle zuzuweisen:
			           |%2.'"),
			InfobaseUser.FullName, UnavailableRolesToAdd);
			
	ElsIf StrLineCount(UnavailableRolesToAdd) > 1 Then
		AddingRegistrationText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Попытка назначить пользователю %1 недоступные роли:
			           |%2.'; 
			           |en = 'Cannot assign the following unavailable roles to user %1:
			           |%2'; 
			           |pl = 'Próba przypisania użytkownikowi %1 niedostępnych ról:
			           |%2';
			           |es_ES = 'Prueba de asignar al usuario %1unos roles no disponibles:
			           |%2.';
			           |es_CO = 'Prueba de asignar al usuario %1unos roles no disponibles:
			           |%2.';
			           |tr = '%1 kullanıcısına erişilmeyen rolleri atama girişimi: 
			           |%2.';
			           |it = 'Impossibile assegnare i seguenti ruoli non disponibili all''utente %1:
			           |%2.';
			           |de = 'Versuch, dem Benutzer %1 nicht verfügbare Rollen zuzuweisen:
			           |%2.'"),
			InfobaseUser.FullName, UnavailableRolesToAdd);
	Else
		AddingRegistrationText = "";
	EndIf;
	
	WriteLogEvent(EventName, EventLogLevel.Error, , InfobaseUser,
		AddingRegistrationText);
	
	If StrLineCount(UnavailableRolesToAdd) = 1 AND ValueIsFilled(UnavailableRolesToAdd) Then
		AddingMessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Пользователю ""%1"" невозможно назначить недоступную роль:
			           |%2.'; 
			           |en = 'Cannot assign the following unavailable role to user ""%1"":
			           |%2.'; 
			           |pl = 'Użytkownikowi ""%1"" nie można przypisać niedostępnej roli:
			           |%2.';
			           |es_ES = 'Al usuario ""%1"" no se le puede asignar un rol no disponible:
			           |%2.';
			           |es_CO = 'Al usuario ""%1"" no se le puede asignar un rol no disponible:
			           |%2.';
			           |tr = '%1Kullanıcısına erişilmeyen rol atanamaz: 
			           |%2.';
			           |it = 'Impossibile assegnare il seguente ruolo non disponibile all''utente %1:
			           |%2.';
			           |de = 'Dem Benutzer ""%1"" kann keine nicht verfügbare Rolle zugewiesen werden:
			           |%2.'"),
			InfobaseUser.FullName, UnavailableRolesToAdd);
		
	ElsIf StrLineCount(UnavailableRolesToAdd) > 1 Then
		AddingMessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Пользователю ""%1"" невозможно назначить недоступные роли:
			           |%2.'; 
			           |en = 'Cannot assign the following unavailable roles to user ""%1"":
			           |%2'; 
			           |pl = 'Użytkownikowi ""%1"" nie można przypisać niedostępnych ról:
			           |%2';
			           |es_ES = 'Al usuario ""%1"" no se le puede asignar unos roles no disponibles:
			           |%2.';
			           |es_CO = 'Al usuario ""%1"" no se le puede asignar unos roles no disponibles:
			           |%2.';
			           |tr = '%1Kullanıcısına erişilmeyen rolleri atanamaz: 
			           |%2.';
			           |it = 'Impossibile assegnare i seguenti ruoli non disponibili all''utente %1:
			           |%2.';
			           |de = 'Benutzer ""%1"" können keine nicht verfügbaren Rollen zugewiesen werden:
			           |%2.'"),
			InfobaseUser.FullName, UnavailableRolesToAdd);
	Else
		AddingMessageText = "";
	EndIf;
	
	Raise AddingMessageText;
	
EndProcedure

Function SettingsList(IBUserName, SettingsManager)
	
	SettingsTable = New ValueTable;
	SettingsTable.Columns.Add("ObjectKey");
	SettingsTable.Columns.Add("SettingsKey");
	
	Filter = New Structure;
	Filter.Insert("User", IBUserName);
	
	SettingsSelection = SettingsManager.Select(Filter);
	Ignore = False;
	While NextSettingsItem(SettingsSelection, Ignore) Do
		
		If Ignore Then
			Continue;
		EndIf;
		
		NewRow = SettingsTable.Add();
		NewRow.ObjectKey = SettingsSelection.ObjectKey;
		NewRow.SettingsKey = SettingsSelection.SettingsKey;
	EndDo;
	
	Return SettingsTable;
	
EndFunction

Function NextSettingsItem(SettingsSelection, Ignore) 
	
	Try 
		Ignore = False;
		Return SettingsSelection.Next();
	Except
		Ignore = True;
		Return True;
	EndTry;
	
EndFunction

Procedure CopySettings(SettingsManager, UserNameSource, UserNameDestination, Move)
	
	SettingsTable = SettingsList(UserNameSource, SettingsManager);
	
	For Each Setting In SettingsTable Do
		ObjectKey = Setting.ObjectKey;
		SettingsKey = Setting.SettingsKey;
		Value = SettingsManager.Load(ObjectKey, SettingsKey, , UserNameSource);
		SettingsDetails = SettingsManager.GetDescription(ObjectKey, SettingsKey, UserNameSource);
		SettingsManager.Save(ObjectKey, SettingsKey, Value,
			SettingsDetails, UserNameDestination);
		If Move Then
			SettingsManager.Delete(ObjectKey, SettingsKey, UserNameSource);
		EndIf;
	EndDo;
	
EndProcedure

Procedure CopyOtherUserSettings(UserNameSource, UserNameDestination)
	
	UserSourceRef = Users.FindByName(UserNameSource);
	UserDestinationRef = Users.FindByName(UserNameDestination);
	SourceUserInfo = New Structure;
	SourceUserInfo.Insert("UserRef", UserSourceRef);
	SourceUserInfo.Insert("InfobaseUserName", UserNameSource);
	
	DestinationUserInfo = New Structure;
	DestinationUserInfo.Insert("UserRef", UserDestinationRef);
	DestinationUserInfo.Insert("InfobaseUserName", UserNameDestination);
	
	// Getting other settings.
	OtherUserSettings = New Structure;
	OnGetOtherUserSettings(SourceUserInfo, OtherUserSettings);
	Keys = New ValueList;
	OtherSettingsArray = New Array;
	If OtherUserSettings.Count() <> 0 Then
		
		For Each OtherSetting In OtherUserSettings Do
			OtherSettingsStructure = New Structure;
			If OtherSetting.Key = "QuickAccessSetting" Then
				SettingsList = OtherSetting.Value.SettingsList;
				For Each Item In SettingsList Do
					Keys.Add(Item.Object, Item.ID);
				EndDo;
				OtherSettingsStructure.Insert("SettingID", "QuickAccessSetting");
				OtherSettingsStructure.Insert("SettingValue", Keys);
			Else
				OtherSettingsStructure.Insert("SettingID", OtherSetting.Key);
				OtherSettingsStructure.Insert("SettingValue", OtherSetting.Value.SettingsList);
			EndIf;
			OnSaveOtherUserSettings(DestinationUserInfo, OtherSettingsStructure);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure CopyIBUserSettings(UserObject, ProcessingParameters)
	
	If NOT ProcessingParameters.Property("CopyingValue")
	 OR NOT ProcessingParameters.NewIBUserExists Then
		
		Return;
	EndIf;
	
	NewIBUserName = ProcessingParameters.NewIBUserDetails.Name;
	
	SourceIBUserID = Common.ObjectAttributeValue(
		ProcessingParameters.CopyingValue, "IBUserID");
	
	If NOT ValueIsFilled(SourceIBUserID) Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	SourceIBUserDetails = Users.IBUserProperies(SourceIBUserID);
	If SourceIBUserDetails = Undefined Then
		Return;
	EndIf;
	SetPrivilegedMode(False);
	
	SourceIBUserName = SourceIBUserDetails.Name;
	
	// Copy settings.
	CopyUserSettings(SourceIBUserName, NewIBUserName, False);
	
EndProcedure

Procedure CheckRoleRightsList(UnavailableRights, RolesDetails, GeneralErrorText, ErrorTitle, ErrorsList, SharedData = Undefined)
	
	ErrorText = "";
	
	For Each RoleDetails In RolesDetails Do
		Role = RoleDetails.Key;
		For Each UnavailableRight In UnavailableRights Do
			If AccessRight(UnavailableRight, Metadata, Role) Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Роль ""%1"" содержит недоступное право %2.'; en = 'Role ""%1"" contains unavailable right %2.'; pl = 'Rola ""%1"" zawiera niedostępne prawo %2.';es_ES = 'El rol ""%1"" contiene un derecho no disponible %2.';es_CO = 'El rol ""%1"" contiene un derecho no disponible %2.';tr = 'Rol ""%1"" erişilmeyen hak içerir %2.';it = 'Il ruolo ""%1"" contiene un permesso non disponibile %2.';de = 'Die Rolle ""%1"" enthält ein nicht verfügbares Recht %2.'"),
					Role, UnavailableRight);
				If ErrorsList = Undefined Then
					ErrorText = ErrorText + Chars.LF + ErrorDescription;
				Else
					ErrorsList.Add(Role, ErrorTitle + Chars.LF + ErrorDescription);
				EndIf;
			EndIf;
		EndDo;
		If SharedData = Undefined Then
			Continue;
		EndIf;
		For Each DataProperties In SharedData Do
			MetadataObject = DataProperties.Value;
			If Not AccessRight("Read", MetadataObject, Role) Then
				Continue;
			EndIf;
			If AccessRight("Update", MetadataObject, Role) Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Роль ""%1"" содержит право Изменение неразделенного объекта %2.'; en = 'Role ""%1"" contains the ""Update"" right for shared object %2.'; pl = 'Rola ""%1"" zawiera prawo do Modyfikacji niepodzielonego obiektu %2.';es_ES = 'El rol ""%1"" contiene un derecho Cambio del objeto no distribuido %2.';es_CO = 'El rol ""%1"" contiene un derecho Cambio del objeto no distribuido %2.';tr = '""%1"" rolü %2 ortak nesnesi için ""Güncelleme"" yetkisine sahip.';it = 'Il ruolo ""%1"" contiene il permesso Modifica di un oggetto non condiviso %2.';de = 'Die Rolle ""%1"" enthält das Recht, ein ungeteiltes Objekt zu ändern %2.'"),
					Role, MetadataObject.FullName());
				If ErrorsList = Undefined Then
					ErrorText = ErrorText + Chars.LF + ErrorDescription;
				Else
					ErrorsList.Add(MetadataObject, ErrorTitle + Chars.LF + ErrorDescription);
				EndIf;
			EndIf;
			If DataProperties.Presentation = "" Then
				Continue; // Not a reference object of metadata.
			EndIf;
			If AccessRight("Insert", MetadataObject, Role) Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Роль ""%1"" содержит право Добавление неразделенного объекта %2.'; en = 'Role ""%1"" contains the ""Insert"" right for shared object %2.'; pl = 'Rola ""%1"" zawiera prawo do dodania niepodzielonego obiektu %2.';es_ES = 'El rol ""%1"" contiene un derecho Adición del objeto no distribuido %2.';es_CO = 'El rol ""%1"" contiene un derecho Adición del objeto no distribuido %2.';tr = 'Rol ""%1"" Bölünmeyen nesnenin eklenmesi %2 hakkını içerir.';it = 'Il ruolo ""%1"" contiene il permesso Aggiunta di un oggetto non condiviso %2.';de = 'Die Rolle ""%1"" enthält das Recht, ein ungeteiltes Objekt hinzuzufügen %2.'"),
					Role, MetadataObject.FullName());
				If ErrorsList = Undefined Then
					ErrorText = ErrorText + Chars.LF + ErrorDescription;
				Else
					ErrorsList.Add(MetadataObject, ErrorTitle + Chars.LF + ErrorDescription);
				EndIf;
			EndIf;
			If AccessRight("Delete", MetadataObject, Role) Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Роль ""%1"" содержит право Удаление неразделенного объекта %2.'; en = 'Role ""%1"" contains the ""Delete"" right for shared object %2.'; pl = 'Rola ""%1"" zawiera prawo do usunięcia niepodzielonego obiektu %2.';es_ES = 'El rol ""%1"" contiene un derecho Eliminación del objeto no distribuido %2.';es_CO = 'El rol ""%1"" contiene un derecho Eliminación del objeto no distribuido %2.';tr = '""%1"" rolü %2 ortak nesnesi için ""Silme"" hakkına sahip.';it = 'Il ruolo ""%1"" contiene il permesso Rimozione di un oggetto non condiviso %2.';de = 'Die Rolle ""%1"" enthält das Recht, ein ungeteiltes Objekt zu löschen %2.'"),
					Role, MetadataObject.FullName());
				If ErrorsList = Undefined Then
					ErrorText = ErrorText + Chars.LF + ErrorDescription;
				Else
					ErrorsList.Add(MetadataObject, ErrorTitle + Chars.LF + ErrorDescription);
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If ValueIsFilled(ErrorText) Then
		GeneralErrorText = GeneralErrorText + Chars.LF + Chars.LF
			+ ErrorTitle + ErrorText;
	EndIf;
	
EndProcedure

Function SharedData()
	
	If Not Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		Return Undefined;
	EndIf;
	
	List = New ValueList;
	
	MetadataKinds = New Array;
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ExchangePlans,             True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Constants,               False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Catalogs,             True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Sequences,      False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Documents,               True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfCharacteristicTypes, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfAccounts,             True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfCalculationTypes,       True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.BusinessProcesses,          True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Tasks,                  True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.InformationRegisters,        False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.AccumulationRegisters,      False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.AccountingRegisters,     False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.CalculationRegisters,         False));
	
	SetPrivilegedMode(True);
	
	ModuleSaaSCached = Common.CommonModule("SaaSCached");
	DataModel = ModuleSaaSCached.GetDataAreaModel();
	
	SeparatedMetadataObjects = New Map;
	For Each DataModelItem In DataModel Do
		MetadataObject = Metadata.FindByFullName(DataModelItem.Key);
		SeparatedMetadataObjects.Insert(MetadataObject, True);
	EndDo;
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	SeparatedDataUsageAvailable = Common.SeparatedDataUsageAvailable();
	
	For Each KindDetails In MetadataKinds Do // By metadata type.
		For Each MetadataObject In KindDetails.Kind Do // By kind objects.
			If SeparatedMetadataObjects.Get(MetadataObject) <> Undefined Then
				Continue;
			EndIf;
			If SeparatedDataUsageAvailable Then
				ConfigurationExtension = MetadataObject.ConfigurationExtension();
				If ConfigurationExtension <> Undefined
				   AND (Not DataSeparationEnabled
				      Or ConfigurationExtension.Scope = ConfigurationExtensionScope.DataSeparation) Then
					Continue;
				EndIf;
			EndIf;
			List.Add(MetadataObject, ?(KindDetails.Reference, "Reference", ""));
		EndDo;
	EndDo;
	
	Return List;
	
EndFunction

Function SecurityWarningKeyOnStart()
	
	If IsBlankString(InfoBaseUsers.CurrentUser().Name) Then
		Return Undefined; // In the base without users warning is not required. 
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Return Undefined; // In SaaS warning is not required.
	EndIf;
	
	If PrivilegedMode() Then
		Return Undefined; // With the /UsePrivilegedMode startup key, warning is not required. 
	EndIf;
	
	If Common.IsSubordinateDIBNode()
		AND Not Common.IsStandaloneWorkplace() Then
		Return Undefined; // In subordinate nodes warning is not required.
	EndIf;
	
	SetPrivilegedMode(True);
	If Not PrivilegedMode() Then
		Return Undefined; // In safe mode warning is not required.
	EndIf;
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	DecisionMade = AdministrationParameters.OpenExternalReportsAndDataProcessorsDecisionMade;
	If TypeOf(DecisionMade) <> Type("Boolean") Then
		DecisionMade = False;
	EndIf;
	SetPrivilegedMode(False);
	
	IsSystemAdministrator = Users.IsFullUser(, True, False);
	If IsSystemAdministrator AND Not DecisionMade Then
		Return "AfterUpdate";
	EndIf;
	
	If DecisionMade Then
		If AccessRight("InteractiveOpenExtDataProcessors", Metadata)
		 Or AccessRight("InteractiveOpenExtReports", Metadata) Then
			
			UserAccepts = Common.CommonSettingsStorageLoad(
				"SecurityWarning", "UserAccepts", False);
			
			If Not UserAccepts Then
				Return "AfterObtainRight";
			EndIf;
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures used for data exchange.

// Overrides default behavior during data export
// IBUserID attribute is not moved.
//
Procedure OnSendData(DataItem, ItemSend, Subordinate)
	
	If ItemSend = DataItemSend.Delete
	 OR ItemSend = DataItemSend.Ignore Then
		
		// Standard data processor cannot be overridden.
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.Users")
	      OR TypeOf(DataItem) = Type("CatalogObject.ExternalUsers") Then
		
		DataItem.IBUserID =
			New UUID("00000000-0000-0000-0000-000000000000");
		
		DataItem.Prepared = False;
		DataItem.IBUserProperies = New ValueStorage(Undefined);
	EndIf;
	
EndProcedure

// Redefines standard behavior during data import.
// The IBUserID attribute is not moved, because it always refers to the user of the current infobase 
// or it is not filled.
//
Procedure OnGetData(DataItem, GetItem, SendBack, FromSubordinate)
	
	If GetItem = DataItemReceive.Ignore Then
		
		// Standard data processor cannot be overridden.
		
	ElsIf TypeOf(DataItem) = Type("ConstantValueManager.UseUserGroups")
	      OR TypeOf(DataItem) = Type("ConstantValueManager.UseExternalUsers")
	      OR TypeOf(DataItem) = Type("CatalogObject.Users")
	      OR TypeOf(DataItem) = Type("CatalogObject.UserGroups")
	      OR TypeOf(DataItem) = Type("CatalogObject.ExternalUsers")
	      OR TypeOf(DataItem) = Type("CatalogObject.ExternalUsersGroups")
	      OR TypeOf(DataItem) = Type("InformationRegisterRecordSet.UserGroupCompositions") Then
		
		If FromSubordinate AND Common.DataSeparationEnabled() Then
			
			// Getting data from a standalone workplace is skipped. Data is sent back to the standalone 
			// workplace to establish data mapping between the nodes.
			SendBack = True;
			GetItem = DataItemReceive.Ignore;
			
		ElsIf TypeOf(DataItem) = Type("CatalogObject.Users")
		      OR TypeOf(DataItem) = Type("CatalogObject.ExternalUsers") Then
			
			PropertiesList =
				"IBUserID,
				|Prepared,
				|IBUserProperies";
			
			FillPropertyValues(DataItem, Common.ObjectAttributesValues(
				DataItem.Ref, PropertiesList));
			
		ElsIf TypeOf(DataItem) = Type("ObjectDeletion") Then
			
			If TypeOf(DataItem.Ref) = Type("CatalogRef.Users")
			 OR TypeOf(DataItem.Ref) = Type("CatalogRef.ExternalUsers") Then
				
				ObjectReceived = False;
				Try
					Object = DataItem.Ref.GetObject();
				Except
					ObjectReceived = True;
				EndTry;
				
				If ObjectReceived Then
					Object.CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange();
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// This method is required by the following procedures:
// - OnAddClientParametersOnStart,
// - OnExecuteStandardPeriodicChecksOnServer.

// Updates the last operation date and checks whether it is necessary to change a password.
Function PasswordChangeRequired(ErrorDescription = "", OnStart = False, RegisterInLog = True)
	
	If Common.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	InfobaseUser = InfoBaseUsers.CurrentUser();
	If Not ValueIsFilled(InfobaseUser.Name) Then
		Return False;
	EndIf;
	
	// Updating the date of the last sign-in of a user.
	SetPrivilegedMode(True);
	CurrentUser = Users.AuthorizedUser();
	CurrentSessionDateDayStart = BegOfDay(CurrentSessionDate());
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.UsersInfo");
	LockItem.SetValue("User", CurrentUser);
	BeginTransaction();
	Try
		Lock.Lock();
		RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
		RecordSet.Filter.User.Set(CurrentUser);
		RecordSet.Read();
		If RecordSet.Count() = 0 Then
			UserInfo = RecordSet.Add();
			UserInfo.User = CurrentUser;
		Else
			UserInfo = RecordSet[0];
		EndIf;
		Write = False;
		If UserInfo.LastActivityDate <> CurrentSessionDateDayStart Then
			UserInfo.LastActivityDate = CurrentSessionDateDayStart;
			Write = True;
		EndIf;
		ClientUsed = StandardSubsystemsServer.ClientParametersAtServer().Get("ClientUsed");
		If UserInfo.LastUsedClient <> ClientUsed Then
			UserInfo.LastUsedClient = ClientUsed;
			Write = True;
		EndIf;
		If Not ValueIsFilled(UserInfo.PasswordUsageStartDate)
		 Or UserInfo.PasswordUsageStartDate > CurrentSessionDateDayStart Then
			UserInfo.PasswordUsageStartDate = CurrentSessionDateDayStart;
			Write = True;
		EndIf;
		If ValueIsFilled(UserInfo.AutomaticAuthorizationProhibitionDate) Then
			UserInfo.AutomaticAuthorizationProhibitionDate = Undefined;
			Write = True;
		EndIf;
		If Write Then
			RecordSet.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInformation = ErrorInfo();
		ErrorTextTemplate = CurrentUserInfoRecordErrorTextTemplate();
		If OnStart Then
			ErrorDescription = AuthorizationNotCompletedMessageTextWithLineBreak()
				+ StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
					BriefErrorDescription(ErrorInformation));
			
			If RegisterInLog Then
				WriteLogEvent(
					NStr("ru = 'Пользователи.Ошибка входа в программу'; en = 'Users.Authorization error'; pl = 'Użytkownicy.Błąd podczas wprowadzania programu';es_ES = 'Usuarios.Error de entrar en el programa';es_CO = 'Usuarios.Error de entrar en el programa';tr = 'Kullanıcılar. Uygulamaya giriş hatası';it = 'Utenti.Errore autorizzazione';de = 'Benutzer.Fehler bei der Eingabe des Programms'",
					     CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.FindByType(TypeOf(CurrentUser)),
					CurrentUser,
					StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
						DetailErrorDescription(ErrorInformation)));
			EndIf;
		Else
			If RegisterInLog Then
				WriteLogEvent(
					NStr("ru = 'Пользователи.Ошибка обновления даты последней активности'; en = 'Users.Last activity date update error'; pl = 'Użytkownicy. Błąd podczas aktualizacji daty ostatniej aktywności';es_ES = 'Usuarios.Error de actualizar la fecha de la última actividad';es_CO = 'Usuarios.Error de actualizar la fecha de la última actividad';tr = 'Kullanıcılar. Son aktivite tarihi güncelleme hatası';it = 'Utenti.Data ultima attività errore aggiornamento';de = 'Benutzer.Fehler beim Aktualisieren des Datums der letzten Aktivität'",
					     CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.FindByType(TypeOf(CurrentUser)),
					CurrentUser,
					StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
						DetailErrorDescription(ErrorInformation)));
			EndIf;
		EndIf;
		Return False;
	EndTry;
	SetPrivilegedMode(False);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IncludeCannotChangePasswordProperty");
	AdditionalParameters.Insert("IncludeStandardAuthenticationProperty");
	If Not CanChangePassword(CurrentUser, AdditionalParameters) Then
		Return False;
	EndIf;
	
	If UserInfo.UserMustChangePasswordOnAuthorization Then
		Return True;
	EndIf;
	
	If Not UsersInternalCached.Settings().CommonAuthorizationSettings Then
		Return False;
	EndIf;
	
	If TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsers") Then
		AuthorizationSettings = UsersInternalCached.Settings().ExternalUsers;
	Else
		AuthorizationSettings = UsersInternalCached.Settings().Users;
	EndIf;
	
	If Not ValueIsFilled(AuthorizationSettings.MaxPasswordLifetime) Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(UserInfo.PasswordUsageStartDate) Then
		Return False;
	EndIf;
	
	RemainingMaxPasswordLifetime = AuthorizationSettings.MaxPasswordLifetime
		- (CurrentSessionDateDayStart - UserInfo.PasswordUsageStartDate) / (24*60*60);
	
	Return RemainingMaxPasswordLifetime <= 0;
	
EndFunction

// This method is required by ProcessNewPassword function.
Function PasswordLengthOrComplexityError(Password, Val MinPasswordLength, ComplexPassword)
	
	If ComplexPassword AND MinPasswordLength < 7 Then
		MinPasswordLength = 7;
	EndIf;
	If StrLen(Password) < MinPasswordLength Then
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Количество символов нового пароля должно быть не менее %1.'; en = 'The new password must contain at least %1 characters.'; pl = 'Ilość znaków nowego hasła musi wynosić co najmniej %1.';es_ES = 'La cantidad d símbolos de la contraseña nueva debe ser no menos de %1.';es_CO = 'La cantidad d símbolos de la contraseña nueva debe ser no menos de %1.';tr = 'Yeni şifredeki karakter sayısı en az %1 olmalıdır.';it = 'La nuova password deve contenere almento %1 caratteri.';de = 'Die Anzahl der Zeichen im neuen Passwort muss mindestens %1 betragen.'"),
			Format(MinPasswordLength, "NG="));
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Return ""; // Password complexity check in split mode is not available.
	EndIf;
	
	If ComplexPassword AND Not PasswordMeetsComplexityRequirements(Password) Then
		Return NStr("ru = 'Пароль не отвечает требованиям сложности.'; en = 'The password does not meet the password complexity requirements.'; pl = 'Hasło nie spełnia wymagań złożoności.';es_ES = 'La contraseña no corresponde a las exigencias de la dificultad.';es_CO = 'La contraseña no corresponde a las exigencias de la dificultad.';tr = 'Şifre karmaşıklık gereksinimlerine uygun değildir.';it = 'La password non risponde ai requisiti di complessità.';de = 'Das Passwort entspricht nicht den Anforderungen der Komplexität.'")
			+ Chars.LF + Chars.LF
			+ NewPasswordHint();
	EndIf;
	
EndFunction

// This method is required by PasswordLengthOrComplexityError function.
// Checks password for complexity requirements implemented in 1C:Enterprise.
//
// Parameters:
//  Password - String - a password to be checked.
//
// Returns:
//  Boolean - True if it matches.
//
Function PasswordMeetsComplexityRequirements(Password)
	
	SetPrivilegedMode(True);
	
	CurrentComplexityCheck = GetUserPasswordStrengthCheck();
	CurrentMinLength  = GetUserPasswordMinLength();
	
	BeginTransaction();
	Try
		If CurrentMinLength > 0 Then
			SetUserPasswordMinLength(0);
		EndIf;
		If CurrentComplexityCheck Then
			SetUserPasswordStrengthCheck(False);
		EndIf;
		
		If Not ValueIsFilled(UserName())
		   AND InfoBaseUsers.GetUsers().Count() = 0 Then
			
			TemporaryIBAdministrator = InfoBaseUsers.CreateUser();
			TemporaryIBAdministrator.StandardAuthentication = True;
			TemporaryIBAdministrator.Roles.Add(Metadata.Roles.Administration);
			TemporaryIBAdministrator.Name = NStr("ru = 'Временный первый администратор'; en = 'Temporary first administrator'; pl = 'Tymczasowy pierwszy administrator';es_ES = 'Primer administrador temporal';es_CO = 'Primer administrador temporal';tr = 'Geçici birinci yönetici';it = 'Primo amministratore temporaneo';de = 'Temporärer Erst-Administrator'")
				+ " (" + String(New UUID) + ")";
			TemporaryIBAdministrator.Write();
		Else
			TemporaryIBAdministrator = Undefined;
		EndIf;
		
		TemporaryIBUser = InfoBaseUsers.CreateUser();
		TemporaryIBUser.StandardAuthentication = True;
		TemporaryIBUser.Password = Password;
		
		TemporaryIBUser.Name = NStr("ru = 'Временный пользователь'; en = 'Temporary user'; pl = 'Tymczasowy użytkownik';es_ES = 'Usuario temporal';es_CO = 'Usuario temporal';tr = 'Geçici kullanıcı';it = 'Utente temporaneo';de = 'Temporärer Benutzer'")
			+ " (" + String(New UUID) + ")";
		
		TemporaryIBUser.Write();
		
		TemporaryIBUser = InfoBaseUsers.FindByUUID(
			TemporaryIBUser.UUID);
		
		SetUserPasswordStrengthCheck(True);
		Meets = True;
		Try
			TemporaryIBUser.Password = Password;
			TemporaryIBUser.Write();
		Except
			Meets = False;
		EndTry;
		
		TemporaryIBUser.Delete();
		
		If TemporaryIBAdministrator <> Undefined Then
			TemporaryIBAdministrator.Delete();
		EndIf;
		
		If CurrentMinLength > 0 Then
			SetUserPasswordMinLength(CurrentMinLength);
		EndIf;
		If Not CurrentComplexityCheck Then
			SetUserPasswordStrengthCheck(False);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInformation = ErrorInfo();
		
		If CurrentMinLength <> GetUserPasswordMinLength() Then
			SetUserPasswordMinLength(CurrentMinLength);
		EndIf;
		If CurrentComplexityCheck <> GetUserPasswordStrengthCheck() Then
			SetUserPasswordStrengthCheck(CurrentComplexityCheck);
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось проверить отвечает ли пароль требованиям сложности по причине:
			           |%1'; 
			           |en = 'Cannot check whether the password complies with the complexity requirements. Reason:
			           |%1'; 
			           |pl = 'Nie można było sprawdzić, czy hasło spełnia wymagania złożoności z tego powodu:
			           |%1';
			           |es_ES = 'No se ha podido comprobar si la contraseña corresponde a las exigencias de la dificultad a causa de:
			           |%1';
			           |es_CO = 'No se ha podido comprobar si la contraseña corresponde a las exigencias de la dificultad a causa de:
			           |%1';
			           |tr = 'Parola karmaşıklık gereksinimlerini neden karşılamadığı doğrulanamadı: 
			           |%1';
			           |it = 'Impossibile contorllare se la password risponde ai criteri di complessità. Motivo:
			           |%1';
			           |de = 'Es konnte nicht überprüft werden, ob das Passwort den Anforderungen der Komplexität entspricht, weil:
			           |%1'"),
			BriefErrorDescription(ErrorInformation));
	EndTry;
	
	Return Meets;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// This method is required by StartIBUserProcessing procedure.

Procedure RememberUserProperties(UserObject, ProcessingParameters)
	
	Fields =
	"Ref,
	|IBUserID,
	|ServiceUserID,
	|IBUserProperies,
	|Prepared,
	|DeletionMark,
	|Invalid";
	
	If TypeOf(UserObject) = Type("CatalogObject.Users") Then
		Fields = Fields + ",
		|Internal";
	EndIf;
	
	OldUser = Common.ObjectAttributesValues(UserObject.Ref, Fields);
	
	If TypeOf(UserObject) <> Type("CatalogObject.Users") Then
		OldUser.Insert("Internal", False);
	EndIf;
	
	If UserObject.IsNew() Or UserObject.Ref <> OldUser.Ref Then
		OldUser.IBUserID =
			New UUID("00000000-0000-0000-0000-000000000000");
		OldUser.ServiceUserID =
			New UUID("00000000-0000-0000-0000-000000000000");
		OldUser.IBUserProperies    = New ValueStorage(Undefined);
		OldUser.Prepared               = False;
		OldUser.DeletionMark           = False;
		OldUser.Invalid            = False;
	EndIf;
	ProcessingParameters.Insert("OldUser", OldUser);
	
	// Properties of old infobase user (if it exists).
	SetPrivilegedMode(True);
	
	PreviousIBUserDetails = Users.IBUserProperies(OldUser.IBUserID);
	ProcessingParameters.Insert("OldIBUserExists", PreviousIBUserDetails <> Undefined);
	ProcessingParameters.Insert("OldIBUserCurrent", False);
	
	If ProcessingParameters.OldIBUserExists Then
		ProcessingParameters.Insert("PreviousIBUserDetails", PreviousIBUserDetails);
		
		If PreviousIBUserDetails.UUID =
				InfoBaseUsers.CurrentUser().UUID Then
		
			ProcessingParameters.Insert("OldIBUserCurrent", True);
		EndIf;
	EndIf;
	SetPrivilegedMode(False);
	
	// Initial filling of auto attribute field values with old user values.
	FillPropertyValues(ProcessingParameters.AutoAttributes, OldUser);
	
	// Initial filling of locked attribute fields with new user values.
	FillPropertyValues(ProcessingParameters.AttributesToLock, UserObject);
	
EndProcedure

Procedure WriteIBUser(UserObject, ProcessingParameters)
	
	AdditionalProperties = UserObject.AdditionalProperties;
	IBUserDetails = AdditionalProperties.IBUserDetails;
	OldUser     = ProcessingParameters.OldUser;
	AutoAttributes          = ProcessingParameters.AutoAttributes;
	
	If IBUserDetails.Count() = 0 Then
		Return;
	EndIf;
	
	CreateNewIBUser = False;
	
	If IBUserDetails.Property("UUID")
	   AND ValueIsFilled(IBUserDetails.UUID)
	   AND IBUserDetails.UUID
	     <> ProcessingParameters.OldUser.IBUserID Then
		
		IBUserID = IBUserDetails.UUID;
		
	ElsIf ValueIsFilled(OldUser.IBUserID) Then
		IBUserID = OldUser.IBUserID;
		CreateNewIBUser = NOT ProcessingParameters.OldIBUserExists;
	Else
		IBUserID = New UUID("00000000-0000-0000-0000-000000000000");
		CreateNewIBUser = True;
	EndIf;
	
	// Filling automatic properties for infobase user.
	IBUserDetails.Insert("FullName", UserObject.Description);
	
	StoredProperties = StoredIBUserProperties(UserObject);
	If ProcessingParameters.OldIBUserExists Then
		PreviousAuthentication = ProcessingParameters.PreviousIBUserDetails;
		If Users.CanSignIn(PreviousAuthentication) Then
			StoredProperties.StandardAuthentication = PreviousAuthentication.StandardAuthentication;
			StoredProperties.OpenIDAuthentication      = PreviousAuthentication.OpenIDAuthentication;
			StoredProperties.OSAuthentication          = PreviousAuthentication.OSAuthentication;
			UserObject.IBUserProperies = New ValueStorage(StoredProperties);
			AutoAttributes.IBUserProperies = UserObject.IBUserProperies;
		EndIf;
	Else
		PreviousAuthentication = New Structure;
		PreviousAuthentication.Insert("StandardAuthentication", False);
		PreviousAuthentication.Insert("OSAuthentication",          False);
		PreviousAuthentication.Insert("OpenIDAuthentication",      False);
		StoredProperties.StandardAuthentication = False;
		StoredProperties.OpenIDAuthentication      = False;
		StoredProperties.OSAuthentication          = False;
		UserObject.IBUserProperies = New ValueStorage(StoredProperties);
		AutoAttributes.IBUserProperies = UserObject.IBUserProperies;
	EndIf;
	
	If IBUserDetails.Property("StandardAuthentication") Then
		StoredProperties.StandardAuthentication = IBUserDetails.StandardAuthentication;
		UserObject.IBUserProperies = New ValueStorage(StoredProperties);
		AutoAttributes.IBUserProperies = UserObject.IBUserProperies;
	EndIf;
	
	If IBUserDetails.Property("OSAuthentication") Then
		StoredProperties.OSAuthentication = IBUserDetails.OSAuthentication;
		UserObject.IBUserProperies = New ValueStorage(StoredProperties);
		AutoAttributes.IBUserProperies = UserObject.IBUserProperies;
	EndIf;
	
	If IBUserDetails.Property("OpenIDAuthentication") Then
		StoredProperties.OpenIDAuthentication = IBUserDetails.OpenIDAuthentication;
		UserObject.IBUserProperies = New ValueStorage(StoredProperties);
		AutoAttributes.IBUserProperies = UserObject.IBUserProperies;
	EndIf;
	
	SetStoredAuthentication = Undefined;
	If IBUserDetails.Property("CanSignIn") Then
		SetStoredAuthentication = IBUserDetails.CanSignIn = True;
	
	ElsIf IBUserDetails.Property("StandardAuthentication")
	        AND IBUserDetails.StandardAuthentication = True
	      OR IBUserDetails.Property("OSAuthentication")
	        AND IBUserDetails.OSAuthentication = True
	      OR IBUserDetails.Property("OpenIDAuthentication")
	        AND IBUserDetails.OpenIDAuthentication = True Then
		
		SetStoredAuthentication = True;
	EndIf;
	
	If SetStoredAuthentication = Undefined Then
		NewAuthentication = PreviousAuthentication;
	Else
		If SetStoredAuthentication Then
			IBUserDetails.Insert("StandardAuthentication", StoredProperties.StandardAuthentication);
			IBUserDetails.Insert("OpenIDAuthentication",      StoredProperties.OpenIDAuthentication);
			IBUserDetails.Insert("OSAuthentication",          StoredProperties.OSAuthentication);
		Else
			IBUserDetails.Insert("StandardAuthentication", False);
			IBUserDetails.Insert("OSAuthentication",          False);
			IBUserDetails.Insert("OpenIDAuthentication",      False);
		EndIf;
		NewAuthentication = IBUserDetails;
	EndIf;
	
	If StoredProperties.CanSignIn <> Users.CanSignIn(NewAuthentication) Then
		StoredProperties.CanSignIn = Users.CanSignIn(NewAuthentication);
		UserObject.IBUserProperies = New ValueStorage(StoredProperties);
		AutoAttributes.IBUserProperies = UserObject.IBUserProperies;
	EndIf;
	
	// Checking whether editing the right to sign in to the application is allowed.
	If Users.CanSignIn(NewAuthentication)
	  <> Users.CanSignIn(PreviousAuthentication) Then
	
		If Users.CanSignIn(NewAuthentication)
		   AND Not ProcessingParameters.AccessLevel.ChangeAuthorizationPermission
		 Or Not Users.CanSignIn(NewAuthentication)
		   AND Not ProcessingParameters.AccessLevel.DisableAuthorizationApproval Then
			
			Raise ProcessingParameters.InsufficientRightsMessageText;
		EndIf;
	EndIf;
	
	If IBUserDetails.Property("Password")
	   AND IBUserDetails.Password <> Undefined Then
		
		ExecutionParameters = New Structure;
		ExecutionParameters.Insert("User", UserObject);
		ExecutionParameters.Insert("NewPassword",  IBUserDetails.Password);
		ExecutionParameters.Insert("OldPassword", Undefined);
		
		IBUserDetails.Property("OldPassword", ExecutionParameters.OldPassword);
		
		ErrorText = ProcessNewPassword(ExecutionParameters);
		If ValueIsFilled(ErrorText) Then
			Raise ErrorText;
		EndIf;
	EndIf;
	
	// Trying to write an infobase user
	Users.SetIBUserProperies(IBUserID, IBUserDetails, 
		CreateNewIBUser, TypeOf(UserObject) = Type("CatalogObject.ExternalUsers"));
	InfobaseUser = IBUserDetails.InfobaseUser;
	
	If UserObject.AdditionalProperties.Property("CreateAdministrator")
	   AND ValueIsFilled(UserObject.AdditionalProperties.CreateAdministrator)
	   AND AdministratorRolesAvailable(InfobaseUser) Then
		
		ProcessingParameters.Insert("CreateAdministrator",
			UserObject.AdditionalProperties.CreateAdministrator);
	EndIf;
	
	If CreateNewIBUser Then
		IBUserDetails.Insert("ActionResult", "IBUserAdded");
		IBUserID = IBUserDetails.UUID;
		ProcessingParameters.Insert("IBUserSetting");
		
		If Not ProcessingParameters.AccessLevel.ChangeAuthorizationPermission
		   AND ProcessingParameters.AccessLevel.ListManagement
		   AND Not Users.CanSignIn(InfobaseUser) Then
			
			UserObject.Prepared = True;
			ProcessingParameters.AttributesToLock.Prepared = True;
		EndIf;
	Else
		IBUserDetails.Insert("ActionResult", "IBUserChanged");
		
		If Users.CanSignIn(InfobaseUser) Then
			UserObject.Prepared = False;
			ProcessingParameters.AttributesToLock.Prepared = False;
		EndIf;
	EndIf;
	
	UserObject.IBUserID = IBUserID;
	
	IBUserDetails.Insert("UUID", IBUserID);
	
EndProcedure

Function DeleteIBUser(UserObject, ProcessingParameters)
	
	IBUserDetails = UserObject.AdditionalProperties.IBUserDetails;
	OldUser     = ProcessingParameters.OldUser;
	
	// Clearing infobase user ID.
	UserObject.IBUserID = Undefined;
	
	If ProcessingParameters.OldIBUserExists Then
		
		SetPrivilegedMode(True);
		Users.DeleteIBUser(OldUser.IBUserID);
			
		// Setting ID for the infobase user to be removed by the Delete operation
		IBUserDetails.Insert("UUID", OldUser.IBUserID);
		IBUserDetails.Insert("ActionResult", "IBUserDeleted");
		
	ElsIf ValueIsFilled(OldUser.IBUserID) Then
		IBUserDetails.Insert("ActionResult", "MappingToNonExistingIBUserCleared");
	Else
		IBUserDetails.Insert("ActionResult", "IBUserDeletionNotRequired");
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// This method is required by EndIBUserProcessing procedure.

Procedure CheckUserAttributeChanges(UserObject, ProcessingParameters)
	
	OldUser   = ProcessingParameters.OldUser;
	AutoAttributes        = ProcessingParameters.AutoAttributes;
	AttributesToLock = ProcessingParameters.AttributesToLock;
	
	If TypeOf(UserObject) = Type("CatalogObject.Users")
	   AND AttributesToLock.Internal <> UserObject.Internal Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |Реквизит Служебный не допускается изменять в подписках на события.'; 
			           |en = 'Cannot save user ""%1"".
			           |The Internal attribute cannot be changed in event subscriptions.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika %1.
			           | Atrybut Service nie może być zmieniony w subskrypcjach na wydarzeniach.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |Atributo de servicio no está permitido para cambiar en las suscripciones para los eventos.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |Atributo de servicio no está permitido para cambiar en las suscripciones para los eventos.';
			           |tr = 'Kullanıcı kaydedilemiyor %1. 
			           |Olay aboneliklerde hizmet özniteliğinin değişmesine izin verilmiyor.';
			           |it = 'Impossibile salvare l''utente ""%1"".
			           |Il requisito di servizio non può essere modificato nelle registrazioni dell''evento.';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten%1.
			           |Das Serviceattribut darf in den Abonnements für die Ereignisse nicht geändert werden.'"),
			UserObject.Ref);
	EndIf;
	
	If AttributesToLock.Prepared <> UserObject.Prepared Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |Реквизит Подготовлен не допускается изменять в подписках на события.'; 
			           |en = 'Cannot save user ""%1"".
			           |The Prepared attribute cannot be changed in event subscriptions.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika%1.
			           | Atrybut Prepared nie może być zmieniony w subskrypcjach wydarzeń.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |Atributo preparado no puede cambiarse en las suscripciones de eventos.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |Atributo preparado no puede cambiarse en las suscripciones de eventos.';
			           |tr = '%1Kullanıcı yazılırken bir hata oluştu. 
			           |Hazırlanan özellik, etkinlik aboneliklerinde değiştirilemez.';
			           |it = 'Impossibile salvare l''utente ""%1"".
			           |Il requisito Preparato non può essere modificato nelle registrazioni dell''evento.';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten%1.
			           |Das vorbereitete Attribut kann in den Ereignisabonnements nicht geändert werden.'"),
			UserObject.Ref);
	EndIf;
	
	If AutoAttributes.IBUserID <> UserObject.IBUserID Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |Реквизит IBUserID не допускается изменять.
			           |Обновление реквизита выполняется автоматически.'; 
			           |en = 'Cannot save user ""%1"".
			           |The IBUserID attribute cannot be changed.
			           |This attribute is always updated automatically.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika""%1"".
			           |Atrybut IBUserID nie może być zmieniony.
			           |Aktualizacja atrybutu jest wykonywana automatycznie.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |Atributo InfobaseUserID no puede cambiarse.
			           |Actualización del atributo se ha realizado automáticamente.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |Atributo InfobaseUserID no puede cambiarse.
			           |Actualización del atributo se ha realizado automáticamente.';
			           |tr = 'Kullanıcı yazılırken bir hata %1 oluştu. 
			           |VeritabanıKullanıcısıID özniteliğini değiştirmeye izin verilmiyor. 
			           |Öznitelik güncelleme otomatik olarak gerçekleştirilir.';
			           |it = 'Impossibile salvare l''utente ""%1"".
			           |Il requisito IBUserID non può essere modificato.
			           |Questo requisito si aggiorna sempre automaticamente.';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten%1.
			           |Das Attribut InfobaseBenutzerID kann nicht geändert werden.
			           |Die Attributaktualisierung wird automatisch durchgeführt.'"),
			UserObject.Ref);
	EndIf;
	
	If Not Common.DataMatch(AutoAttributes.IBUserProperies,
				UserObject.IBUserProperies) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |Реквизит IBUserProperties не допускается изменять.
			           |Обновление реквизита выполняется автоматически.'; 
			           |en = 'Cannot save user ""%1"".
			           |The IBUserProperties attribute cannot be changed.
			           |This attribute is always updated automatically.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika""%1"".
			           |Atrybut IBUserProperties nie może byś zmieniony.
			           |Aktualizacja atrybutu jest wykonywana automatycznie.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |Atributo InfobaseUserID no puede cambiarse.
			           |Actualización del atributo se ha realizado automáticamente.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |Atributo InfobaseUserID no puede cambiarse.
			           |Actualización del atributo se ha realizado automáticamente.';
			           |tr = 'Kullanıcı kaydedilirken bir hata %1 oluştu. 
			           |VeriTabanıKullanıcısıID özniteliğini değiştirmeye izin verilmiyor. 
			           |Öznitelik güncelleme otomatik olarak gerçekleştirilir.';
			           |it = 'Impossibile salvare l''utente ""%1"".
			           |Il requisito IBUserProperties non può essere modificato.
			           |Questo requisito si aggiorna sempre automaticamente.';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten%1.
			           |Das Attribut InfobaseBenutzereigenschaften kann nicht geändert werden.
			           |Die Attributaktualisierung wird automatisch durchgeführt.'"),
			UserObject.Ref);
	EndIf;
	
	SetPrivilegedMode(True);
	
	If OldUser.DeletionMark = False
	   AND UserObject.DeletionMark = True
	   AND Users.CanSignIn(UserObject.IBUserID) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |Нельзя помечать на удаление пользователя, которому разрешен вход в программу.'; 
			           |en = 'Cannot save user ""%1"".
			           |A user that is allowed to sign in cannot be marked for deletion.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika %1.
			           |Nie można oznaczyć do usunięcia użytkownika, który może zalogować się do aplikacji.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |Usted no puede marcar para borrar un usuario que tiene permiso de iniciar la sesión en la aplicación.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |Usted no puede marcar para borrar un usuario que tiene permiso de iniciar la sesión en la aplicación.';
			           |tr = 'Kullanıcı kaydedilirken bir hata oluştu%1. 
			           |Uygulamaya giriş yapmasına izin verilen bir kullanıcı silme işlemi için işaretlenemez.';
			           |it = 'Errore durante la registrazione dell''utente ""%1"".
			           |Non è possibile contrassegnare per la cancellazione un utente a cui è permesso l''accesso al programma.';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten%1.
			           |Sie können einen Benutzer, der sich an der Anwendung anmelden darf, nicht zum Löschen markieren.'"),
			UserObject.Ref);
	EndIf;
	
	If OldUser.Invalid = False
	   AND UserObject.Invalid = True
	   AND Users.CanSignIn(UserObject.IBUserID) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |Нельзя пометить недействительным пользователя, которому разрешен вход в программу.'; 
			           |en = 'Cannot save user ""%1"".
			           |A user that is allowed to sign in cannot be marked invalid.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika %1.
			           |Nie można oznaczyć użytkownika, który ma zezwolenie na logowanie, jako nieprawidłowego.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |No se puede marcar como inválido el usuario que tiene permiso de iniciar la sesión en la aplicación.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |No se puede marcar como inválido el usuario que tiene permiso de iniciar la sesión en la aplicación.';
			           |tr = 'Kullanıcı kaydedilirken bir hata oluştu%1. 
			           |Uygulamada geçersiz olarak oturum açmasına izin verilen kullanıcıyı işaretlemek için kullanılamaz.';
			           |it = 'Errore durante la registrazione dell''utente ""%1"".
			           |Non è possibile contrassegnare come inattivo un utente a cui è permesso l''accesso al programma.';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten%1.
			           |Benutzer, der sich als ungültig anmelden kann, kann nicht markiert werden.'"),
			UserObject.Ref);
	EndIf;
	
	If OldUser.Prepared = False
	   AND UserObject.Prepared = True
	   AND Users.CanSignIn(UserObject.IBUserID) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |Нельзя пометить подготовленным пользователя, которому разрешен вход в программу.'; 
			           |en = 'Cannot save user ""%1"".
			           |A user that is allowed to sign in cannot be marked ""requires approval.""'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika %1.
			           |Nie można oznaczyć jako gotowego użytkownika, który może zalogować się do aplikacji.';
			           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
			           |No se puede marcar como preparado un usuario que tiene permiso de iniciar la sesión en la aplicación.';
			           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
			           |No se puede marcar como preparado un usuario que tiene permiso de iniciar la sesión en la aplicación.';
			           |tr = 'Kullanıcı kaydedilirken bir hata oluştu%1. 
			           |Uygulamada oturum açmasına izin verilen bir kullanıcı hazır olarak işaretlenemiyor.';
			           |it = 'Errore durante la registrazione dell''utente ""%1"".
			           |Non è possibile contrassegnare come preparato un utente a cui è permesso l''accesso al programma';
			           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten%1.
			           |Ein Benutzer, der sich in der Anwendung anmelden darf, kann nicht als bereit markiert werden.'"),
			UserObject.Ref);
	EndIf;
	
EndProcedure

Procedure UpdateInfoOnUserAllowedToSignIn(User, CanSignIn)
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.UsersInfo");
	LockItem.SetValue("User", User);
	
	RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
	RecordSet.Filter.User.Set(User);
	
	BeginTransaction();
	Try
		Lock.Lock();
		RecordSet.Read();
		If RecordSet.Count() = 0 Then
			RecordSet.Add();
			RecordSet[0].User = User;
		EndIf;
		Write = False;
		If ValueIsFilled(RecordSet[0].AutomaticAuthorizationProhibitionDate) Then
			Write = True;
			RecordSet[0].AutomaticAuthorizationProhibitionDate = Undefined;
		EndIf;
		If CanSignIn
		   AND RecordSet[0].AuthorizationAllowedDate <> BegOfDay(CurrentSessionDate()) Then
			Write = True;
			RecordSet[0].AuthorizationAllowedDate = BegOfDay(CurrentSessionDate());
		EndIf;
		If Write Then
			RecordSet.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// This method is required by MonitorUserActivities procedure.

Procedure DisableInactiveAndOverdueUsers(ForAuthorizedUsersOnly = False,
			ErrorDescription = "", RegisterInLog = True)
	
	SetPrivilegedMode(True);
	
	Settings = UsersInternalCached.Settings();
	If Not Settings.CommonAuthorizationSettings Then
		If Not ForAuthorizedUsersOnly Then
			ChangeUserActivityMonitoringJob(False);
		EndIf;
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("EmptyDate",                                 '00010101');
	Query.SetParameter("CurrentSessionDateDayStart",                 BegOfDay(CurrentSessionDate()));
	Query.SetParameter("UserOverdueActivationDate",        Settings.Users.InactivityPeriodActivationDate);
	Query.SetParameter("UserInactivityPeriod",               Settings.Users.InactivityPeriodBeforeDenyingAuthorization);
	Query.SetParameter("ExternalUserOverdueActivationDate", Settings.ExternalUsers.InactivityPeriodActivationDate);
	Query.SetParameter("ExternalUserInactivityPeriod",        Settings.ExternalUsers.InactivityPeriodBeforeDenyingAuthorization);
	
	Query.Text =
	"SELECT
	|	Users.Ref AS User,
	|	CASE
	|		WHEN ISNULL(UsersInfo.ValidityPeriod, &EmptyDate) <> &EmptyDate
	|			THEN ISNULL(UsersInfo.ValidityPeriod, &EmptyDate) <= &CurrentSessionDateDayStart
	|		ELSE FALSE
	|	END AS ValidityPeriodExpired
	|FROM
	|	Catalog.Users AS Users
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = Users.Ref)
	|WHERE
	|	&FilterUsers
	|	AND ISNULL(UsersInfo.UnlimitedValidityPeriod, FALSE) = FALSE
	|	AND ISNULL(UsersInfo.AutomaticAuthorizationProhibitionDate, &EmptyDate) = &EmptyDate
	|	AND CASE
	|			WHEN ISNULL(UsersInfo.ValidityPeriod, &EmptyDate) <> &EmptyDate
	|				THEN ISNULL(UsersInfo.ValidityPeriod, &EmptyDate) <= &CurrentSessionDateDayStart
	|			WHEN ISNULL(UsersInfo.InactivityPeriodBeforeDenyingAuthorization, 0) <> 0
	|				THEN CASE
	|						WHEN ISNULL(UsersInfo.LastActivityDate, &EmptyDate) = &EmptyDate
	|							THEN CASE
	|									WHEN ISNULL(UsersInfo.AuthorizationAllowedDate, &EmptyDate) = &EmptyDate
	|										THEN &CurrentSessionDateDayStart > DATEADD(&UserOverdueActivationDate, DAY, UsersInfo.InactivityPeriodBeforeDenyingAuthorization)
	|									ELSE &CurrentSessionDateDayStart > DATEADD(UsersInfo.AuthorizationAllowedDate, DAY, UsersInfo.InactivityPeriodBeforeDenyingAuthorization)
	|								END
	|						WHEN &CurrentSessionDateDayStart > DATEADD(ISNULL(UsersInfo.LastActivityDate, &EmptyDate), DAY, UsersInfo.InactivityPeriodBeforeDenyingAuthorization)
	|							THEN TRUE
	|						ELSE FALSE
	|					END
	|			ELSE CASE
	|					WHEN &UserInactivityPeriod = 0
	|						THEN FALSE
	|					WHEN ISNULL(UsersInfo.LastActivityDate, &EmptyDate) = &EmptyDate
	|						THEN CASE
	|								WHEN ISNULL(UsersInfo.AuthorizationAllowedDate, &EmptyDate) = &EmptyDate
	|									THEN &CurrentSessionDateDayStart > DATEADD(&UserOverdueActivationDate, DAY, &UserInactivityPeriod)
	|								ELSE &CurrentSessionDateDayStart > DATEADD(UsersInfo.AuthorizationAllowedDate, DAY, &UserInactivityPeriod)
	|							END
	|					WHEN &CurrentSessionDateDayStart > DATEADD(ISNULL(UsersInfo.LastActivityDate, &EmptyDate), DAY, &UserInactivityPeriod)
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		END
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	CASE
	|		WHEN ISNULL(UsersInfo.ValidityPeriod, &EmptyDate) <> &EmptyDate
	|			THEN ISNULL(UsersInfo.ValidityPeriod, &EmptyDate) <= &CurrentSessionDateDayStart
	|		ELSE FALSE
	|	END
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = ExternalUsers.Ref)
	|WHERE
	|	&FilterExternalUsers
	|	AND ISNULL(UsersInfo.UnlimitedValidityPeriod, FALSE) = FALSE
	|	AND ISNULL(UsersInfo.AutomaticAuthorizationProhibitionDate, &EmptyDate) = &EmptyDate
	|	AND CASE
	|			WHEN ISNULL(UsersInfo.ValidityPeriod, &EmptyDate) <> &EmptyDate
	|				THEN ISNULL(UsersInfo.ValidityPeriod, &EmptyDate) <= &CurrentSessionDateDayStart
	|			WHEN ISNULL(UsersInfo.InactivityPeriodBeforeDenyingAuthorization, 0) <> 0
	|				THEN CASE
	|						WHEN ISNULL(UsersInfo.LastActivityDate, &EmptyDate) = &EmptyDate
	|							THEN CASE
	|									WHEN ISNULL(UsersInfo.AuthorizationAllowedDate, &EmptyDate) = &EmptyDate
	|										THEN &CurrentSessionDateDayStart > DATEADD(&ExternalUserOverdueActivationDate, DAY, UsersInfo.InactivityPeriodBeforeDenyingAuthorization)
	|									ELSE &CurrentSessionDateDayStart > DATEADD(UsersInfo.AuthorizationAllowedDate, DAY, UsersInfo.InactivityPeriodBeforeDenyingAuthorization)
	|								END
	|						WHEN &CurrentSessionDateDayStart > DATEADD(ISNULL(UsersInfo.LastActivityDate, &EmptyDate), DAY, UsersInfo.InactivityPeriodBeforeDenyingAuthorization)
	|							THEN TRUE
	|						ELSE FALSE
	|					END
	|			ELSE CASE
	|					WHEN &ExternalUserInactivityPeriod = 0
	|						THEN FALSE
	|					WHEN ISNULL(UsersInfo.LastActivityDate, &EmptyDate) = &EmptyDate
	|						THEN CASE
	|								WHEN ISNULL(UsersInfo.AuthorizationAllowedDate, &EmptyDate) = &EmptyDate
	|									THEN &CurrentSessionDateDayStart > DATEADD(&ExternalUserOverdueActivationDate, DAY, &ExternalUserInactivityPeriod)
	|								ELSE &CurrentSessionDateDayStart > DATEADD(UsersInfo.AuthorizationAllowedDate, DAY, &ExternalUserInactivityPeriod)
	|							END
	|					WHEN &CurrentSessionDateDayStart > DATEADD(ISNULL(UsersInfo.LastActivityDate, &EmptyDate), DAY, &ExternalUserInactivityPeriod)
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		END";
	If ForAuthorizedUsersOnly Then
		Query.SetParameter("User", Users.AuthorizedUser());
		FilterUsers        = "Users.Ref = &User";
		FilterExternalUsers = "ExternalUsers.Ref = &User";
	Else
		FilterUsers        = "TRUE";
		FilterExternalUsers = "TRUE";
	EndIf;
	Query.Text = StrReplace(Query.Text, "&FilterUsers",        FilterUsers);
	Query.Text = StrReplace(Query.Text, "&FilterExternalUsers", FilterExternalUsers);
	
	Selection = Query.Execute().Select();
	
	ErrorInformation = Undefined;
	While Selection.Next() Do
		User = Selection.User;
		If NOT Selection.ValidityPeriodExpired
		   AND Users.IsFullUser(User,, False) Then
			Continue;
		EndIf;
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.UsersInfo");
		LockItem.SetValue("User", User);
		BeginTransaction();
		Try
			Lock.Lock();
			IBUserID = Common.ObjectAttributeValue(User,
				"IBUserID");
			InfobaseUser = Undefined;
			If TypeOf(IBUserID) = Type("UUID") Then
				InfobaseUser = InfoBaseUsers.FindByUUID(
					IBUserID);
			EndIf;
			If InfobaseUser <> Undefined
			   AND (    InfobaseUser.StandardAuthentication
			      Or InfobaseUser.OSAuthentication
			      Or InfobaseUser.OpenIDAuthentication) Then
				
				PropertiesToUpdate = New Structure;
				PropertiesToUpdate.Insert("StandardAuthentication", False);
				PropertiesToUpdate.Insert("OSAuthentication",          False);
				PropertiesToUpdate.Insert("OpenIDAuthentication",      False);
				
				Users.SetIBUserProperies(InfobaseUser.UUID,
					PropertiesToUpdate, False, TypeOf(User) = Type("CatalogRef.ExternalUsers"));
			EndIf;
			RecordSet = InformationRegisters.UsersInfo.CreateRecordSet();
			RecordSet.Filter.User.Set(User);
			RecordSet.Read();
			If RecordSet.Count() = 0 Then
				UserInfo = RecordSet.Add();
				UserInfo.User = User;
			Else
				UserInfo = RecordSet[0];
			EndIf;
			UserInfo.AutomaticAuthorizationProhibitionDate = BegOfDay(CurrentSessionDate());
			RecordSet.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			ErrorInformation = ErrorInfo();
			
			ErrorTextTemplate = CurrentUserInfoRecordErrorTextTemplate();
			ErrorDescription = AuthorizationNotCompletedMessageTextWithLineBreak()
				+ StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
					BriefErrorDescription(ErrorInformation));
			
			If RegisterInLog Then
				If Selection.ValidityPeriodExpired Then
					CommentTemplate =
						NStr("ru = 'Не удалось снять пользователю ""%1"" признак
						           |""Вход в программу разрешен"" в связи с окончанием срока действия по причине:
						           |%2'; 
						           |en = 'Cannot clear the ""Can sign in"" flag
						           |for user ""%1"" with expired password. Reason:
						           |%2'; 
						           |pl = 'Nie powiodło się użytkownikowi ""%1"" usunąć atrybutu 
						           |""Logowanie się do programu dozwolone"" z powodu wygaśnięcia terminu ważności z powodu:
						           |%2';
						           |es_ES = 'No se ha podido quitar el atributo del usuario ""%1"
"La entrada en el programa está permitida"" a causa de la expiración del período de vigencia porque:
						           |%2';
						           |es_CO = 'No se ha podido quitar el atributo del usuario ""%1"
"La entrada en el programa está permitida"" a causa de la expiración del período de vigencia porque:
						           |%2';
						           |tr = '""%1"" kullanıcı, aşağıdaki nedenle geçerlilik süresi %2sona erdiğinden dolayı ""Uygulamaya girişe izin verildi"" belirtisi kaldıramadı: 
						           |
						           |';
						           |it = 'Impossibile rimuovere il flag ""Può accedere""
						           |per l''utente ""%1"" con password scaduta. Motivo:
						           |%2';
						           |de = 'Der Benutzer ""%1"" konnte das Zeichen
						           |""Login in das Programm ist erlaubt"" wegen des Ablaufs der Gültigkeitsdauer nicht entfernen, weil:
						           |%2'");
				Else
					CommentTemplate =
						NStr("ru = 'Не удалось снять пользователю ""%1"" признак
						           |""Вход в программу разрешен"" в связи с отсутствием работы
						           |в программе более установленного срока по причине:
						           |%2'; 
						           |en = 'Cannot clear the ""Can sign in"" flag
						           |for user ""%1"" with inactivity timeout reached.
						           |Reason:
						           |%2'; 
						           |pl = 'Nie powiodło się użytkownikowi ""%1"" usunąć atrybutu 
						           |""Logowanie się do programu dozwolone"" z powodu braku pracy
						           | w programie ponad ustalony maksymalnie termin z powodu:
						           |%2';
						           |es_ES = 'No se ha podido quitar el atributo del usuario ""%1"
"La entrada en el programa está permitida"" a causa de ausencia del trabajo
						           |en el programa más del período especificado a causa de:
						           |%2';
						           |es_CO = 'No se ha podido quitar el atributo del usuario ""%1"
"La entrada en el programa está permitida"" a causa de ausencia del trabajo
						           |en el programa más del período especificado a causa de:
						           |%2';
						           |tr = '""%1"" kullanıcı, aşağıdaki nedenle daha fazla 
						           |belirlenen süresinin uygulamada olmadığından dolayı geçerlilik süresi %2sona erdiğinden dolayı ""Uygulamaya girişe izin verildi"" belirtisi kaldıramadı: 
						           |
						           |';
						           |it = 'Non è stato possibile rimuovere la proprietà
						           |""Accesso al programma permesso"" all''utente ""%1"" a causa della mancanza di lavoro
						           |nel programma per una durata maggiore di quella indicata a causa di:
						           |%2';
						           |de = 'Der Benutzer ""%1"" konnte das Zeichen
						           |""Login in das Programm ist erlaubt"" nicht entfernen, da er längere Zeit nicht
						           |im Programm gearbeitet hat, weil:
						           |%2'");
				EndIf;
				WriteLogEvent(
					NStr("ru = 'Пользователи.Ошибка автоматического запрещения входа в программу'; en = 'Users.Automatic authorization denial error'; pl = 'Użytkownicy.Błąd w automatycznym zakazie wejścia do programu';es_ES = 'Usuarios.Error de restringir automáticamente entrar en el programa';es_CO = 'Usuarios.Error de restringir automáticamente entrar en el programa';tr = 'Kullanıcılar. Uygulamaya giriş otomatik olarak yasaklanmıştır';it = 'Utente. Errore automatico di accesso negato';de = 'Benutzer.Fehler beim automatischen Verbot des Eintritts in das Programm'",
					     CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					Metadata.FindByType(TypeOf(User)),
					User,
					StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate,
						User, DetailErrorDescription(ErrorInformation)));
			EndIf;
		EndTry;
	EndDo;
	
	If ForAuthorizedUsersOnly Then
		Return;
	EndIf;
	
	If ErrorInformation <> Undefined
	 Or ValueIsFilled(Settings.Users.InactivityPeriodBeforeDenyingAuthorization)
	 Or ValueIsFilled(Settings.ExternalUsers.InactivityPeriodBeforeDenyingAuthorization) Then
		// To check inactive period in the application, cannot disable job.
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("EmptyDate", '00010101');
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.UsersInfo AS UsersInfo
	|WHERE
	|	 UsersInfo.ValidityPeriod <> &EmptyDate
	|	AND UsersInfo.AutomaticAuthorizationProhibitionDate = &EmptyDate";
	
	If Query.Execute().IsEmpty() Then
		ChangeUserActivityMonitoringJob(False);
	EndIf;
	
EndProcedure

Procedure CheckCanSignIn(AuthorizationError)
	
	SetPrivilegedMode(True);
	
	ID = InfoBaseUsers.CurrentUser().UUID;
	InfobaseUser = InfoBaseUsers.FindByUUID(ID);
	
	If InfobaseUser = Undefined
	 Or Users.CanSignIn(InfobaseUser) Then
		Return;
	EndIf;
	
	AuthorizationError = AuthorizationNotCompletedMessageTextWithLineBreak()
		+ NStr("ru = 'Ваша учетная запись отключена. Обратитесь к администратору.'; en = 'Your account is disabled. Please contact the administrator.'; pl = 'Twoje konto zostało wyłączone. Skontaktuj się z administratorem.';es_ES = 'Su cuenta está desactivada. Diríjase al administrador.';es_CO = 'Su cuenta está desactivada. Diríjase al administrador.';tr = 'Hesabınız kapatılmıştır. Yöneticiye başvurun.';it = 'Il vostro account è disabilitato. Rivolgetevi all''amministratore.';de = 'Ihr Konto ist deaktiviert. Wenden Sie sich an den Administrator.'");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// This method is required by ProcessRolesInterface procedure.

Procedure FillRoles(Parameters)
	
	ReadRoles = Parameters.MainParameter;
	RolesCollection  = Parameters.RolesCollection;
	
	RolesCollection.Clear();
	AddedRoles = New Map;
	
	If TypeOf(ReadRoles) = Type("Array") Then
		For Each Role In ReadRoles Do
			If AddedRoles.Get(Role) <> Undefined Then
				Continue;
			EndIf;
			AddedRoles.Insert(Role, True);
			RolesCollection.Add().Role = Role;
		EndDo;
	Else
		RoleIDs = New Array;
		For Each Row In ReadRoles Do
			If TypeOf(Row.Role) = Type("CatalogRef.MetadataObjectIDs")
			 Or TypeOf(Row.Role) = Type("CatalogRef.ExtensionObjectIDs") Then
				RoleIDs.Add(Row.Role);
			EndIf;
		EndDo;
		ReadRoles = Catalogs.MetadataObjectIDs.MetadataObjectsByIDs(
			RoleIDs, True);
		
		For Each RoleDetails In ReadRoles Do
			If TypeOf(RoleDetails.Value) <> Type("MetadataObject") Then
				Role = RoleDetails.Key;
				RoleName = Common.ObjectAttributeValue(Role, "Name");
				RoleName = ?(RoleName = Undefined, "(" + Role.UUID() + ")", RoleName);
				RoleName = ?(Left(RoleName, 1) = "?", RoleName, "? " + TrimL(RoleName));
				RolesCollection.Add().Role = TrimAll(RoleName);
			Else
				RolesCollection.Add().Role = RoleDetails.Value.Name;
			EndIf;
		EndDo;
	EndIf;
	
	UpdateRoleTree(Parameters);
	
EndProcedure

Procedure SetUpRoleInterfaceOnCreateForm(Parameters)
	
	Form    = Parameters.Form;
	Items = Form.Items;
	
	// Conditional appearance of unavailable roles.
	ConditionalAppearanceItem = Form.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.ErrorNoteText.Value;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Roles.IsUnavailableRole");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Roles");
	FieldAppearanceItem.Use = True;
	
	// Conditional appearance of non-existing roles.
	ConditionalAppearanceItem = Form.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Roles.IsNonExistingRole");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Roles");
	FieldAppearanceItem.Use = True;
	
	SetUpRoleInterfaceOnReadAtServer(Parameters);
	
EndProcedure

Procedure SetUpRoleInterfaceOnReadAtServer(Parameters)
	
	Form    = Parameters.Form;
	Items = Form.Items;
	
	// Setting initial values before importing data from the settings on the server for the case where 
	// data is not written and is not being loaded.
	Form.ShowRoleSubsystems = False;
	Items.RolesShowRolesSubsystems.Check = False;
	
	// Showing all roles for a new item, or selected roles for an existing item.
	If Items.Find("RolesShowSelectedRolesOnly") <> Undefined Then
		Items.RolesShowSelectedRolesOnly.Check = Parameters.MainParameter;
	EndIf;
	
	UpdateRoleTree(Parameters);
	
EndProcedure

Procedure SetUpRoleInterfaceOnLoadSettings(Parameters)
	
	Settings = Parameters.MainParameter;
	Form     = Parameters.Form;
	Items  = Form.Items;
	
	ShowRoleSubsystems = Form.ShowRoleSubsystems;
	
	If Settings["ShowRoleSubsystems"] = False Then
		Form.ShowRoleSubsystems = False;
		Items.RolesShowRolesSubsystems.Check = False;
	Else
		Form.ShowRoleSubsystems = True;
		Items.RolesShowRolesSubsystems.Check = True;
	EndIf;
	
	If ShowRoleSubsystems <> Form.ShowRoleSubsystems Then
		UpdateRoleTree(Parameters);
	EndIf;
	
EndProcedure

Procedure SetRolesReadOnly(Parameters)
	
	Items               = Parameters.Form.Items;
	RolesReadOnly    = Parameters.MainParameter;
	
	If RolesReadOnly <> Undefined Then
		
		Items.Roles.ReadOnly = RolesReadOnly;
		
		If Items.Find("RolesSelectAll") <> Undefined Then
			Items.RolesSelectAll.Enabled = NOT RolesReadOnly;
		EndIf;
		If Items.Find("RolesClearAll") <> Undefined Then
			Items.RolesClearAll.Enabled = NOT RolesReadOnly;
		EndIf;
	EndIf;
	
EndProcedure

Procedure SelectedRolesOnly(Parameters)
	
	Parameters.Form.Items.RolesShowSelectedRolesOnly.Check =
		NOT Parameters.Form.Items.RolesShowSelectedRolesOnly.Check;
	
	UpdateRoleTree(Parameters);
	
EndProcedure

Procedure GroupBySubsystems(Parameters)
	
	Parameters.Form.ShowRoleSubsystems = NOT Parameters.Form.ShowRoleSubsystems;
	Parameters.Form.Items.RolesShowRolesSubsystems.Check = Parameters.Form.ShowRoleSubsystems;
	
	UpdateRoleTree(Parameters);
	
EndProcedure

Procedure UpdateRoleTree(Parameters)
	
	Form           = Parameters.Form;
	Items        = Form.Items;
	Roles            = Form.Roles;
	RolesCollection  = Parameters.RolesCollection;
	RolesAssignment = Parameters.RolesAssignment;
	
	HideFullAccessRole = Parameters.Property("HideFullAccessRole")
	                      AND Parameters.HideFullAccessRole = True;
	
	If Items.Find("RolesShowSelectedRolesOnly") <> Undefined Then
		If NOT Items.RolesShowSelectedRolesOnly.Enabled Then
			Items.RolesShowSelectedRolesOnly.Check = True;
		EndIf;
		ShowSelectedRolesOnly = Items.RolesShowSelectedRolesOnly.Check;
	Else
		ShowSelectedRolesOnly = True;
	EndIf;
	
	ShowRoleSubsystems = Parameters.Form.ShowRoleSubsystems;
	
	// Remembering the current row
	CurrentSubsystem = "";
	CurrentRole       = "";
	
	If Items.Roles.CurrentRow <> Undefined Then
		CurrentData = Roles.FindByID(Items.Roles.CurrentRow);
		
		If CurrentData = Undefined Then
			Items.Roles.CurrentRow = Undefined;
			
		ElsIf CurrentData.IsRole Then
			CurrentRole       = CurrentData.Name;
			CurrentSubsystem = ?(CurrentData.GetParent() = Undefined, "",
				CurrentData.GetParent().Name);
		Else
			CurrentRole       = "";
			CurrentSubsystem = CurrentData.Name;
		EndIf;
	EndIf;
	
	RoleTree = UsersInternalCached.RoleTree(
		ShowRoleSubsystems, RolesAssignment).Get();
	
	RoleTree.Columns.Add("IsUnavailableRole",    New TypeDescription("Boolean"));
	RoleTree.Columns.Add("IsNonExistingRole", New TypeDescription("Boolean"));
	AddNonexistentAndUnavailableRoleNames(Parameters, RoleTree);
	
	RoleTree.Columns.Add("Check",       New TypeDescription("Boolean"));
	RoleTree.Columns.Add("PictureNumber", New TypeDescription("Number"));
	PrepareRoleTree(RoleTree.Rows, HideFullAccessRole, ShowSelectedRolesOnly,
		Parameters.RolesCollection);
	
	Parameters.Form.ValueToFormAttribute(RoleTree, "Roles");
	
	Items.Roles.Representation = ?(RoleTree.Rows.Find(False, "IsRole") = Undefined,
		TableRepresentation.List, TableRepresentation.Tree);
	
	// Restoring the current row.
	Filter = New Structure("IsRole, Name", False, CurrentSubsystem);
	FoundRows = RoleTree.Rows.FindRows(Filter, True);
	If FoundRows.Count() <> 0 Then
		SubsystemDetails = FoundRows[0];
		
		SubsystemIndex = ?(SubsystemDetails.Parent = Undefined,
			RoleTree.Rows, SubsystemDetails.Parent.Rows).IndexOf(SubsystemDetails);
		
		SubsystemRow = TreeItemCollectionFormData(Roles,
			SubsystemDetails).Get(SubsystemIndex);
		
		If ValueIsFilled(CurrentRole) Then
			Filter = New Structure("IsRole, Name", True, CurrentRole);
			FoundRows = SubsystemDetails.Rows.FindRows(Filter);
			If FoundRows.Count() <> 0 Then
				RoleDetails = FoundRows[0];
				Items.Roles.CurrentRow = SubsystemRow.GetItems().Get(
					SubsystemDetails.Rows.IndexOf(RoleDetails)).GetID();
			Else
				Items.Roles.CurrentRow = SubsystemRow.GetID();
			EndIf;
		Else
			Items.Roles.CurrentRow = SubsystemRow.GetID();
		EndIf;
	Else
		Filter = New Structure("IsRole, Name", True, CurrentRole);
		FoundRows = RoleTree.Rows.FindRows(Filter, True);
		If FoundRows.Count() <> 0 Then
			RoleDetails = FoundRows[0];
			
			RoleIndex = ?(RoleDetails.Parent = Undefined,
				RoleTree.Rows, RoleDetails.Parent.Rows).IndexOf(RoleDetails);
			
			RoleRow = TreeItemCollectionFormData(Roles, RoleDetails).Get(RoleIndex);
			Items.Roles.CurrentRow = RoleRow.GetID();
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddNonexistentAndUnavailableRoleNames(Parameters, RoleTree)
	
	RolesCollection  = Parameters.RolesCollection;
	AllRoles = AllRoles().Map;
	
	UnavailableRoles    = New ValueList;
	NonexistentRoles = New ValueList;
	
	// Adding nonexistent roles
	For each Row In RolesCollection Do
		Filter = New Structure("IsRole, Name", True, Row.Role);
		If RoleTree.Rows.FindRows(Filter, True).Count() > 0 Then
			Continue;
		EndIf;
		Synonym = AllRoles.Get(Row.Role);
		If Synonym = Undefined Then
			NonexistentRoles.Add(Row.Role,
				?(Left(Row.Role, 1) = "?", Row.Role, "? " + Row.Role));
		Else
			UnavailableRoles.Add(Row.Role, Synonym);
		EndIf;
	EndDo;
	
	UnavailableRoles.SortByPresentation();
	For Each RoleDetails In UnavailableRoles Do
		Index = UnavailableRoles.IndexOf(RoleDetails);
		TreeRow = RoleTree.Rows.Insert(Index);
		TreeRow.Name     = RoleDetails.Value;
		TreeRow.Synonym = RoleDetails.Presentation;
		TreeRow.IsRole = True;
		TreeRow.IsUnavailableRole = True;
	EndDo;
	
	NonexistentRoles.SortByPresentation();
	For Each RoleDetails In NonexistentRoles Do
		Index = NonexistentRoles.IndexOf(RoleDetails);
		TreeRow = RoleTree.Rows.Insert(Index);
		TreeRow.Name     = RoleDetails.Value;
		TreeRow.Synonym = RoleDetails.Presentation;
		TreeRow.IsRole = True;
		TreeRow.IsNonExistingRole = True;
	EndDo;
	
EndProcedure

Procedure PrepareRoleTree(Val Collection, Val HideFullAccessRole, Val ShowSelectedRolesOnly, RolesCollection)
	
	Index = Collection.Count()-1;
	
	While Index >= 0 Do
		Row = Collection[Index];
		
		PrepareRoleTree(Row.Rows, HideFullAccessRole, ShowSelectedRolesOnly,
			RolesCollection);
		
		If Row.IsRole Then
			If HideFullAccessRole
			   AND (    Upper(Row.Name) = Upper("FullRights")
			      OR Upper(Row.Name) = Upper("SystemAdministrator")) Then
				Collection.Delete(Index);
			Else
				Row.PictureNumber = 7;
				Row.Check = RolesCollection.FindRows(
					New Structure("Role", Row.Name)).Count() > 0;
				
				If ShowSelectedRolesOnly AND NOT Row.Check Then
					Collection.Delete(Index);
				EndIf;
			EndIf;
		Else
			If Row.Rows.Count() = 0 Then
				Collection.Delete(Index);
			Else
				Row.PictureNumber = 6;
				Row.Check = Row.Rows.FindRows(
					New Structure("Check", False)).Count() = 0;
			EndIf;
		EndIf;
		
		Index = Index-1;
	EndDo;
	
EndProcedure

Function TreeItemCollectionFormData(Val TreeFormData, Val ValueTreeRow)
	
	If ValueTreeRow.Parent = Undefined Then
		TreeItemCollectionFormData = TreeFormData.GetItems();
	Else
		ParentIndex = ?(ValueTreeRow.Parent.Parent = Undefined,
			ValueTreeRow.Owner().Rows, ValueTreeRow.Parent.Parent.Rows).IndexOf(
				ValueTreeRow.Parent);
			
		TreeItemCollectionFormData = TreeItemCollectionFormData(TreeFormData,
			ValueTreeRow.Parent).Get(ParentIndex).GetItems();
	EndIf;
	
	Return TreeItemCollectionFormData;
	
EndFunction

Procedure UpdateRoleComposition(Parameters)
	
	Roles                        = Parameters.Form.Roles;
	ShowSelectedRolesOnly = Parameters.Form.Items.RolesShowSelectedRolesOnly.Check;
	RolesAssignment             = Parameters.RolesAssignment;
	
	AllRoles         = AllRoles().Array;
	UnavailableRoles = UsersInternalCached.UnavailableRoles(RolesAssignment);
	
	If Parameters.MainParameter = "EnableAll" Then
		RowID = Undefined;
		Add            = True;
		
	ElsIf Parameters.MainParameter = "DisableAll" Then
		RowID = Undefined;
		Add            = False;
	Else
		RowID = Parameters.Form.Items.Roles.CurrentRow;
	EndIf;
	
	If RowID = Undefined Then
		
		AdministrativeAccessEnabled = Parameters.RolesCollection.FindRows(
			New Structure("Role", "FullRights")).Count() > 0;
		
		// Processing all
		RolesCollection = Parameters.RolesCollection;
		RolesCollection.Clear();
		If Add Then
			For Each RoleName In AllRoles Do
				
				If RoleName = "FullRights"
				 Or RoleName = "SystemAdministrator"
				 Or UnavailableRoles.Get(RoleName) <> Undefined
				 Or Upper(Left(RoleName, StrLen("Delete"))) = Upper("Delete") Then
					
					Continue;
				EndIf;
				RolesCollection.Add().Role = RoleName;
			EndDo;
		EndIf;
		
		If Parameters.Property("AdministrativeAccessChangeProhibition")
			AND Parameters.AdministrativeAccessChangeProhibition Then
			
			AdministrativeAccessWasEnabled = Parameters.RolesCollection.FindRows(
				New Structure("Role", "FullRights")).Count() > 0;
			
			If AdministrativeAccessWasEnabled AND NOT AdministrativeAccessEnabled Then
				Filter = New Structure("Role", "FullRights");
				Parameters.RolesCollection.FindRows(Filter).Delete(0);
				
			ElsIf AdministrativeAccessEnabled AND NOT AdministrativeAccessWasEnabled Then
				RolesCollection.Add().Role = "FullRights";
			EndIf;
		EndIf;
		
		If ShowSelectedRolesOnly Then
			If RolesCollection.Count() > 0 Then
				UpdateRoleTree(Parameters);
			Else
				Roles.GetItems().Clear();
			EndIf;
			
			Return;
		EndIf;
	Else
		CurrentData = Roles.FindByID(RowID);
		If CurrentData.IsRole Then
			AddDeleteRole(Parameters, CurrentData.Name, CurrentData.Check);
		Else
			AddDeleteSubsystemRoles(Parameters, CurrentData.GetItems(), CurrentData.Check);
		EndIf;
	EndIf;
	
	UpdateSelectedRoleMarks(Parameters, Roles.GetItems());
	
	Modified = True;
	
EndProcedure

Procedure AddDeleteRole(Parameters, Val Role, Val Add)
	
	FoundRoles = Parameters.RolesCollection.FindRows(New Structure("Role", Role));
	
	If Add Then
		If FoundRoles.Count() = 0 Then
			Parameters.RolesCollection.Add().Role = Role;
		EndIf;
	Else
		If FoundRoles.Count() > 0 Then
			Parameters.RolesCollection.Delete(FoundRoles[0]);
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddDeleteSubsystemRoles(Parameters, Val Collection, Val Add)
	
	For each Row In Collection Do
		If Row.IsRole Then
			AddDeleteRole(Parameters, Row.Name, Add);
		Else
			AddDeleteSubsystemRoles(Parameters, Row.GetItems(), Add);
		EndIf;
	EndDo;
	
EndProcedure

Procedure UpdateSelectedRoleMarks(Parameters, Val Collection)
	
	ShowSelectedRolesOnly = Parameters.Form.Items.RolesShowSelectedRolesOnly.Check;
	
	Index = Collection.Count()-1;
	
	While Index >= 0 Do
		Row = Collection[Index];
		
		If Row.IsRole Then
			Filter = New Structure("Role", Row.Name);
			Row.Check = Parameters.RolesCollection.FindRows(Filter).Count() > 0;
			If ShowSelectedRolesOnly AND NOT Row.Check Then
				Collection.Delete(Index);
			EndIf;
		Else
			UpdateSelectedRoleMarks(Parameters, Row.GetItems());
			If Row.GetItems().Count() = 0 Then
				Collection.Delete(Index);
			Else
				Row.Check = True;
				For each Item In Row.GetItems() Do
					If NOT Item.Check Then
						Row.Check = False;
						Break;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
		Index = Index-1;
	EndDo;
	
EndProcedure

Function UsersAddedInDesigner()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.Description AS FullName,
	|	Users.IBUserID,
	|	FALSE AS IsExternalUser
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID <> &EmptyUniqueID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.Description,
	|	ExternalUsers.IBUserID,
	|	TRUE
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID <> &EmptyUniqueID";
	
	Query.SetParameter("EmptyUniqueID", New UUID("00000000-0000-0000-0000-000000000000"));
	
	DataExported = Query.Execute().Unload();
	DataExported.Indexes.Add("IBUserID");
	
	IBUsers = InfoBaseUsers.GetUsers();
	UsersAddedInDesignerCount = 0;
	
	For Each InfobaseUser In IBUsers Do
		
		Row = DataExported.Find(InfobaseUser.UUID, "IBUserID");
		If Row = Undefined Then
			UsersAddedInDesignerCount = UsersAddedInDesignerCount + 1;
		EndIf;
		
	EndDo;
	
	Return UsersAddedInDesignerCount;
	
EndFunction

#EndRegion
