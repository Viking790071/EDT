
#Region Internal

// Returns a flag that shows whether user modification is available.
//
// Returns:
// Boolean - True if user modification is available, False otherwise.
//
Function CanChangeUsers() Export
	
	Return Constants.InfobaseUsageMode.Get() 
		<> Enums.InfobaseUsageModes.Demo;
	
EndFunction

// Returns available actions for the current user with the specified SaaS user.
// 
//
// Parameters:
//  User - CatalogRef.Users - user for whom available actions are required.
//    If this parameter not specified, the function checks available actions for the current user.
//   
//  ServiceUserPassword - String - SaaS password of the current user.
//   
//  
Function GetActionsWithSaaSUser(Val User = Undefined) Export
	
	If User = Undefined Then
		User = Users.CurrentUser();
	EndIf;
	
	If CanChangeUsers() Then
		
		If InfoBaseUsers.CurrentUser().DataSeparation.Count() = 0 Then
			
			If Users.IsFullUser(, True) Then
				
				Return ActionsWithNewSaaSUser();
				
			Else
			
				Return ActionsWithSaaSUserWhenUserSetupUnavailable();
				
			EndIf;
			
		ElsIf IsExistingUserCurrentDataArea(User) Then
			
			Return ActionsWithExsistingSaaSUser(User);
			
		Else
			
			If HasRightToAddUsers() Then
				Return ActionsWithNewSaaSUser();
			Else
				Raise NStr("ru = 'Недостаточно прав доступа для добавления новых пользователей'; en = 'Insufficient access rights for adding users'; pl = 'Niewystarczające prawa dostępu do dodania użytkowników';es_ES = 'Insuficientes derechos de acceso para añadir usuarios';es_CO = 'Insuficientes derechos de acceso para añadir usuarios';tr = 'Kullanıcı eklemek için erişim yetkisi yetersiz';it = 'Autorizzazioni insufficienti per aggiungere nuovi utenti';de = 'Unzureichende Zugriffsrechte zum Hinzufügen von Benutzern'");
			EndIf;
			
		EndIf;
		
	Else
		
		Return ActionsWithSaaSUserWhenUserSetupUnavailable();
		
	EndIf;
	
EndFunction

// Generates a request for changing SaaS user email address.
// 
//
// Parameters:
//  NewEmailAddress - String - new email address of the user.
//  User - CatalogRef.Users - the user whose email address is changed.
//   
//  ServiceUserPassword - String - user password for service manager.
//   
//
Procedure CreateEmailAddressChangeRequest(Val NewEmailAddress, Val User, Val ServiceUserPassword) Export
	
	SetPrivilegedMode(True);
	Proxy = SaaS.GetServiceManagerProxy(ServiceUserPassword);
	SetPrivilegedMode(False);
	
	ErrorInformation = Undefined;
	Proxy.RequestEmailChange(
		Common.ObjectAttributeValue(User, "ServiceUserID"), 
		NewEmailAddress, 
		ErrorInformation);
	HandleWebServiceErrorInfo(ErrorInformation, "RequestEmailChange"); // Do not localize the operation name.
	
EndProcedure

// Creates or updates a SaaS user record.
// 
// Parameters:
//  User - CatalogRef.Users/CatalogObject.Users
//  CreateServiceUser - Boolean - if True create new SaaS user, if False update existing.
//   
//  ServiceUserPassword - String - user password for service manager.
//   
//
Procedure WriteSaaSUser(Val User, Val CreateServiceUser, Val ServiceUserPassword) Export
	
	If TypeOf(User) = Type("CatalogRef.Users") Then
		UserObject = User.GetObject();
	Else
		UserObject = User;
	EndIf;
	
	SetPrivilegedMode(True);
	Proxy = SaaS.GetServiceManagerProxy(ServiceUserPassword);
	SetPrivilegedMode(False);
	
	If ValueIsFilled(UserObject.IBUserID) Then
		InfobaseUser = InfoBaseUsers.FindByUUID(UserObject.IBUserID);
		AccessAllowed = InfobaseUser <> Undefined AND Users.CanSignIn(InfobaseUser);
	Else
		AccessAllowed = False;
	EndIf;
	
	SaaSUser = Proxy.XDTOFactory.Create(
		Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/ApplicationUsers", "User"));
	SaaSUser.Zone = SaaS.SessionSeparatorValue();
	SaaSUser.UserServiceID = UserObject.ServiceUserID;
	SaaSUser.FullName = UserObject.Description;
	SaaSUser.Name = InfobaseUser.Name;
	SaaSUser.StoredPasswordValue = InfobaseUser.StoredPasswordValue;
	SaaSUser.Language = GetLanguageCode(InfobaseUser.Language);
	SaaSUser.Access = AccessAllowed;
	SaaSUser.AdmininstrativeAccess = AccessAllowed AND InfobaseUser.Roles.Contains(Metadata.Roles.FullRights);
	
	ContactInformation = Proxy.XDTOFactory.Create(
		Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/ApplicationUsers", "ContactsList"));
		
	CIWriterType = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/ApplicationUsers", "ContactsItem");
	
	For each CIRow In UserObject.ContactInformation Do
		CIKindXDTO = SaaSCached.ContactInformationKindAndXDTOUserMap().Get(CIRow.Kind);
		If CIKindXDTO = Undefined Then
			Continue;
		EndIf;
		
		CIWriter = Proxy.XDTOFactory.Create(CIWriterType);
		CIWriter.ContactType = CIKindXDTO;
		CIWriter.Value = CIRow.Presentation;
		CIWriter.Parts = CIRow.FieldsValues;
		
		ContactInformation.Item.Add(CIWriter);
	EndDo;
	
	SaaSUser.Contacts = ContactInformation;
	
	ErrorInformation = Undefined;
	If CreateServiceUser Then
		Proxy.CreateUser(SaaSUser, ErrorInformation);
		HandleWebServiceErrorInfo(ErrorInformation, "CreateUser"); // Do not localize the operation name.
	Else
		Proxy.UpdateUser(SaaSUser, ErrorInformation);
		HandleWebServiceErrorInfo(ErrorInformation, "UpdateUser"); // Do not localize the operation name.
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// Processing infobase user when writing Users or ExternalUsers catalog items.

// The procedure is called from the StartIBUserProcessing() procedure to add SaaS support.
Procedure BeforeStartIBUserProcessing(UserObject, ProcessingParameters) Export
	
	If Not SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AdditionalProperties = UserObject.AdditionalProperties;
	OldUser     = ProcessingParameters.OldUser;
	AutoAttributes          = ProcessingParameters.AutoAttributes;
	
	If TypeOf(UserObject) = Type("CatalogObject.ExternalUsers")
	   AND SaaS.DataSeparationEnabled() Then
		
		Raise NStr("ru = 'Внешние пользователи не поддерживаются в модели сервиса.'; en = 'External users are not supported in SaaS mode.'; pl = 'Użytkownicy zewnętrzni nie są obsługiwani w SaaS.';es_ES = 'Usuarios externos no admitidos en SaaS.';es_CO = 'Usuarios externos no admitidos en SaaS.';tr = 'Harici kullanıcılar SaaS''de desteklenmez.';it = 'Gli utenti esterni non sono supportati nel modello di servizio.';de = 'Externe Benutzer werden in SaaS nicht unterstützt.'");
	EndIf;
	
	AutoAttributes.Insert("ServiceUserID", OldUser.ServiceUserID);
	
	If AdditionalProperties.Property("RemoteAdministrationChannelMessageProcessing") Then
		
		If NOT SaaS.SessionWithoutSeparators() Then
			Raise
				NStr("ru = 'Обновление пользователя по сообщению
				           |канала удаленного администрирования
				           |доступно только неразделенным пользователям.'; 
				           |en = 'User update on administration
				           |remote channel message
				           |is available only to undivided users.'; 
				           |pl = 'Aktualizowanie użytkownika za pomocą wiadomości
				           | zdalnego kanału administracyjnego
				           | jest dostępne tylko dla nieseparowanych użytkowników.';
				           |es_ES = 'La actualización de usuario por mensaje
				           |del canal remoto de administración
				           |está disponible solo a los usuarios no divididos.';
				           |es_CO = 'La actualización de usuario por mensaje
				           |del canal remoto de administración
				           |está disponible solo a los usuarios no divididos.';
				           |tr = 'Uzaktan yönetim kanalı iletisiyle kullanıcı 
				           |güncelleştirmesi yalnızca karşılıksız 
				           |kullanıcılar tarafından kullanılabilir.';
				           |it = 'Aggiornamento dell''utente sul
				           |messaggio del canale remoto
				           |di amministrazione è disponibile solo per gli utenti non separati.';
				           |de = 'Die Benutzeraktualisierung über den
				           |Kanal der Remote-Administration
				           |ist nur für ungeteilte Benutzer verfügbar.'");
		EndIf;
		
		ProcessingParameters.Insert("RemoteAdministrationChannelMessageProcessing");
		AutoAttributes.ServiceUserID = UserObject.ServiceUserID;
		
	ElsIf NOT UserObject.Internal Then
		UpdateDetailsSaasManagerWebService();
	EndIf;
	
	If ValueIsFilled(AutoAttributes.ServiceUserID)
	   AND AutoAttributes.ServiceUserID <> OldUser.ServiceUserID Then
		
		If ValueIsFilled(OldUser.ServiceUserID) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при записи пользователя ""%1"".
				           |Нельзя изменять уже установленный идентификатор
				           |пользователя сервиса в элементе справочника.'; 
				           |en = 'An error occurred when writing the ""%1"" user.
				           |Cannot change a set service user ID
				           |in the catalog item.'; 
				           |pl = 'Błąd podczas zapisywania użytkownika ""%1"".
				           | Nie można zmienić identyfikatora
				           |usługi użytkownika usługi, który już ustawiono w elemencie katalogu.';
				           |es_ES = 'Ha ocurrido un error al grabar el usuario ""%1"".
				           |Usted no puede modificar el identificador
				           |del usuario de servicio ya establecido en un artículo del catálogo.';
				           |es_CO = 'Ha ocurrido un error al grabar el usuario ""%1"".
				           |Usted no puede modificar el identificador
				           |del usuario de servicio ya establecido en un artículo del catálogo.';
				           |tr = 'Kullanıcı yazılırken bir hata oluştu ""%1"". 
				           |Bir katalog öğesinde önceden ayarlanmış servis kullanıcı kimliğini 
				           |değiştiremezsiniz.';
				           |it = 'Si è verificato un errore durante la scrittura dell''utente ""%1"".
				           |Impossibile modificare l''ID
				           |di servizio dell''utente impostato nell''elemento del catalogo.';
				           |de = 'Fehler bei der Benutzereingabe ""%1"".
				           |Sie können die bereits eingestellte Service-Benutzerkennung
				           |im Verzeichniselement nicht ändern.'"),
				UserObject.Description);
			
		EndIf;
		
		FoundUser = Undefined;
		
		If UsersInternal.UserByIDExists(
				AutoAttributes.ServiceUserID,
				UserObject.Ref,
				FoundUser,
				True) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при записи пользователя ""%1"".
				           |Нельзя устанавливать идентификатор
				           |пользователя сервиса ""%2""
				           |в этот элемент справочника, т.к. он
				           |уже используется в элементе ""%3"".'; 
				           |en = 'An error occurred when writing the ""%1"" user.
				           |Cannot set
				           |an ID of the ""%2"" service user
				           |in this catalog item because it
				           |is already used in the ""%3"" item.'; 
				           |pl = 'Wystąpił błąd podczas zapisywania użytkownika %1.
				           |Nie można ustawić
				           |identyfikatora 
				           |użytkownika usługi ""%2"" do tego elementu katalogu ponieważ
				           | jest on już używany w elemencie ""%3"".';
				           |es_ES = 'Ha ocurrido un error al grabar el usuario %1.
				           |Usted no puede
				           |establecer el identificador del usuario
				           |de servicio ""%2"" para este artículo del catálogo, porque ya se
				           |utiliza en el artículo ""%3"".';
				           |es_CO = 'Ha ocurrido un error al grabar el usuario %1.
				           |Usted no puede
				           |establecer el identificador del usuario
				           |de servicio ""%2"" para este artículo del catálogo, porque ya se
				           |utiliza en el artículo ""%3"".';
				           |tr = '""%1"" kullanıcısı kaydedilirken hata oluştu.
				           |""%2"" servis kullanıcısının ID''si
				           |bu katalog öğesinde belirlenemiyor
				           |çünkü ""%3"" öğesinde
				           |zaten kullanılıyor.';
				           |it = 'Si è verificato un errore durante la scrittura dell''utente ""%1"".
				           |Impossibile impostare
				           |un ID dell''utente del servizio ""%2""
				           |in questo elemento del catalogo
				           |perché è già usato nell''elemento ""%3"".';
				           |de = 'Beim Schreiben des Benutzers ist ein Fehler aufgetreten %1.
				           |Sie können nicht
				           |die Service
				           |benutzer-ID ""%2"" auf diesen Katalogartikel setzen, da
				           |er bereits verwendet wird im Element ""%3"".'"),
				UserObject.Description,
				AutoAttributes.ServiceUserID,
				FoundUser);
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is called from the StartIBUserProcessing() procedure to add SaaS support.
Procedure AfterStartIBUserProcessing(UserObject, ProcessingParameters) Export
	
	If Not SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AutoAttributes = ProcessingParameters.AutoAttributes;
	
	ProcessingParameters.Insert("CreateServiceUser", False);
	
	If ProcessingParameters.NewIBUserExists
	   AND SaaS.DataSeparationEnabled() Then
		
		If NOT ValueIsFilled(AutoAttributes.ServiceUserID) Then
			
			ProcessingParameters.Insert("CreateServiceUser", True);
			UserObject.ServiceUserID = New UUID;
			
			// Updating value of the attribute that is checked during the writing
			AutoAttributes.ServiceUserID = UserObject.ServiceUserID;
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is called from the EndIBUserProcessing() procedure to add SaaS support.
Procedure BeforeEndIBUserProcessing(UserObject, ProcessingParameters) Export
	
	If Not SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	AutoAttributes = ProcessingParameters.AutoAttributes;
	
	If AutoAttributes.ServiceUserID <> UserObject.ServiceUserID Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при записи пользователя ""%1"".
			           |Реквизит ServiceUserID не допускается изменять.
			           |Обновление реквизита выполняется автоматически.'; 
			           |en = 'An error occurred when writing user ""%1"". Attribute
			           |ServiceUserID cannot be changed.
			           |The attribute gets updated automatically.'; 
			           |pl = 'Wystąpił błąd podczas zapisywania użytkownika%1.
			           | Zmiana atrybutu ServiceUserID jest niedozwolona.
			           |Aktualizacja atrybutu jest wykonywana automatycznie.';
			           |es_ES = 'Ha ocurrido un error al guardar el usuario ""%1"". 
			           |Cambio del atributo ServiceUserID no está permitido.
			           |Actualización del atributo se ha realizado automáticamente.';
			           |es_CO = 'Ha ocurrido un error al guardar el usuario ""%1"". 
			           |Cambio del atributo ServiceUserID no está permitido.
			           |Actualización del atributo se ha realizado automáticamente.';
			           |tr = '""%1"" kullanıcısı kaydedilirken hata oluştu.
			           |ServiceUserID özelliği değiştirilemez.
			           |Bu özellik otomatik olarak güncellenir.';
			           |it = 'Si è verificato un errore durante la scrittura dell''utente ""%1"". Il requisito
			           |ServiceUserID non può essere modificato.
			           |Il requisito si aggiorna automaticamente.';
			           |de = 'Beim Schreiben des Benutzers ""%1"" ist ein Fehler aufgetreten.
			           |AttributeServiceUserID kann nicht geändert werden.
			           |Das Attribut wird automatisch aktualisiert.'"),
			UserObject.Ref);
	EndIf;
	
EndProcedure

// The procedure is called from the EndIBUserProcessing() procedure to add SaaS support.
Procedure OnEndIBUserProcessing(UserObject, ProcessingParameters, UpdateRoles) Export
	
	If Not SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If ProcessingParameters.Property("RemoteAdministrationChannelMessageProcessing") Then
		UpdateRoles = False;
	EndIf;
	
	IBUserDetails = UserObject.AdditionalProperties.IBUserDetails;
	
	If SaaS.DataSeparationEnabled()
	   AND TypeOf(UserObject) = Type("CatalogObject.Users")
	   AND IBUserDetails.Property("ActionResult")
	   AND NOT UserObject.Internal Then
		
		If IBUserDetails.ActionResult = "IBUserDeleted" Then
			
			SetPrivilegedMode(True);
			CancelSaaSUserAccess(UserObject);
			SetPrivilegedMode(False);
			
		Else // IBUserAdded or IBUserChanged.
			UpdateSaaSUser(UserObject, ProcessingParameters.CreateServiceUser);
			
			If Not ProcessingParameters.Property("RemoteAdministrationChannelMessageProcessing")
			   AND ProcessingParameters.CreateServiceUser Then
				
				SaaSOverridable.SetDefaultRights(UserObject.Ref);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
//
// Returns:
//   Structure - actions with SaaS user, see NewActionsWithSaaSUser. 
//
Function ActionsWithSaaSUserWhenUserSetupUnavailable()
	
	ActionsWithSaaSUser = NewActionsWithSaaSUser();
	ActionsWithSaaSUser.ChangePassword = False;
	ActionsWithSaaSUser.ChangeName = False;
	ActionsWithSaaSUser.ChangeFullName = False;
	ActionsWithSaaSUser.ChangeAccess = False;
	ActionsWithSaaSUser.ChangeAdministrativeAccess = False;
	
	ActionsWithCI = ActionsWithSaaSUser.ContactInformation;
	For each KeyAndValue In SaaSCached.ContactInformationKindAndXDTOUserMap() Do
		ActionsWithCI[KeyAndValue.Key].Update = False;
	EndDo;
	
	Return ActionsWithSaaSUser;
	
EndFunction

// For internal use only.
//
// Parameters:
//   User - CatalogRef.Users - a user.
//
// Returns:
//   Structure - actions with SaaS user, see NewActionsWithSaaSUser. 
//
Function ActionsWithExsistingSaaSUser(Val User)
	
	SetPrivilegedMode(True);
	Proxy = SaaS.GetServiceManagerProxy();
	SetPrivilegedMode(False);
	
	AccessObjects = PrepareUserAccessObjects(Proxy.XDTOFactory, User);
	
	ErrorInformation = Undefined;
	ObjectsAccessRightsXDTO = Proxy.GetObjectsAccessRights(AccessObjects, 
		CurrentUserServiceID(), ErrorInformation);
	HandleWebServiceErrorInfo(ErrorInformation, "GetObjectsAccessRights"); // Do not localize the operation name.
	
	Return ObjectsAccessRightsXDTOInActionsWithSaaSUser(Proxy.XDTOFactory, ObjectsAccessRightsXDTO);
	
EndFunction

// For internal use only.
//
// Returns:
//   Structure - actions with SaaS user, see NewActionsWithSaaSUser. 
//
Function ActionsWithNewSaaSUser()
	
	ActionsWithSaaSUser = NewActionsWithSaaSUser();
	ActionsWithSaaSUser.ChangePassword = True;
	ActionsWithSaaSUser.ChangeName = True;
	ActionsWithSaaSUser.ChangeFullName = True;
	ActionsWithSaaSUser.ChangeAccess = True;
	ActionsWithSaaSUser.ChangeAdministrativeAccess = True;
	
	ActionsWithCI = ActionsWithSaaSUser.ContactInformation; 
	For each KeyAndValue In SaaSCached.ContactInformationKindAndXDTOUserMap() Do
		ActionsWithCI[KeyAndValue.Key].Update = True;
	EndDo;
	
	Return ActionsWithSaaSUser;
	
EndFunction

// For internal use only.
//
// Returns:
//   Boolean - True, if user has the right.
//
Function HasRightToAddUsers()
	
	SetPrivilegedMode(True);
	Proxy = SaaS.GetServiceManagerProxy();
	SetPrivilegedMode(False);
	
	DataArea = Proxy.XDTOFactory.Create(
		Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "Zone"));
	DataArea.Zone = SaaS.SessionSeparatorValue();
	
	ErrorInformation = Undefined;
	AccessRightsXDTO = Proxy.GetAccessRights(DataArea, 
		CurrentUserServiceID(), ErrorInformation);
	HandleWebServiceErrorInfo(ErrorInformation, "GetAccessRights"); // Do not localize the operation name.
	
	For each RightsListItem In AccessRightsXDTO.Item Do
		If RightsListItem.AccessRight = "CreateUser" Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// For internal use only.
Procedure UpdateDetailsSaasManagerWebService()
	
	If NOT SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	// The cache must be filled before writing a user to the infobase.
	SaaS.GetServiceManagerProxy();
	SetPrivilegedMode(False);
	
EndProcedure

// For the OnEndIBUserProcessing procedure.
Procedure UpdateSaaSUser(UserObject, CreateServiceUser)
	
	If NOT UserObject.AdditionalProperties.Property("SynchronizeWithService")
		OR NOT UserObject.AdditionalProperties.SynchronizeWithService Then
		
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	WriteSaaSUser(UserObject, 
		CreateServiceUser, 
		UserObject.AdditionalProperties.ServiceUserPassword);
	
EndProcedure

// For internal use only.
Function GetSaaSUsers(ServiceUserPassword) Export
	
	SetPrivilegedMode(True);
	Proxy = SaaS.GetServiceManagerProxy(ServiceUserPassword);
	SetPrivilegedMode(False);
	
	ErrorInformation = Undefined;
	
	Try
		
		UsersList = Proxy.GetUsersList(SaaS.SessionSeparatorValue(), );
		
	Except
		
		ServiceUserPassword = Undefined;
		Raise;
		
	EndTry;
	
	HandleWebServiceErrorInfo(ErrorInformation, "GetUsersList"); // Do not localize the operation name.
	
	Result = New ValueTable;
	Result.Columns.Add("ID", New TypeDescription("UUID"));
	Result.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("FullName", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Access", New TypeDescription("Boolean"));
	
	For each UserInformation In UsersList.Item Do
		UserRow = Result.Add();
		UserRow.ID = UserInformation.UserServiceID;
		UserRow.Name = UserInformation.Name;
		UserRow.FullName = UserInformation.FullName;
		UserRow.Access = UserInformation.Access;
	EndDo;
	
	Return Result;
	
EndFunction

// For internal use only.
Procedure GrantSaaSUserAccess(Val ServiceUserID, Val ServiceUserPassword) Export
	
	SetPrivilegedMode(True);
	Proxy = SaaS.GetServiceManagerProxy(ServiceUserPassword);
	SetPrivilegedMode(False);
	
	ErrorInformation = Undefined;
	Proxy.GrantUserAccess(
		SaaS.SessionSeparatorValue(),
		ServiceUserID, 
		ErrorInformation);
	HandleWebServiceErrorInfo(ErrorInformation, "GrantUserAccess"); // Do not localize the operation name.
	
EndProcedure

// For the OnEndIBUserProcessing procedure.
Procedure CancelSaaSUserAccess(UserObject)
	
	If NOT ValueIsFilled(UserObject.ServiceUserID) Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		ModuleToCall = Common.CommonModule("ApplicationManagementMessagesInterface");
		Message = MessagesSaaS.NewMessage(
			ModuleToCall.MessageCancelUserAccess());
		
		Message.Body.Zone = SaaS.SessionSeparatorValue();
		Message.Body.UserServiceID = UserObject.ServiceUserID;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaS.ServiceManagerEndpoint());
			
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Checks whether the user passed to the function matches the current infobase user in the current 
// data area.
//
// Parameters:
//  User - CatalogRef.Users;
//
// Returns: Boolean.
//
Function IsExistingUserCurrentDataArea(Val User)
	
	SetPrivilegedMode(True);
	
	If ValueIsFilled(User) Then
		
		If ValueIsFilled(User.IBUserID) Then
			
			If InfoBaseUsers.FindByUUID(User.IBUserID) <> Undefined Then
				
				Return True;
				
			Else
				
				Return False;
				
			EndIf;
			
		Else
			
			Return False;
			
		EndIf;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Function CurrentUserServiceID()
	
	Return Common.ObjectAttributeValue(Users.CurrentUser(), "ServiceUserID");
	
EndFunction

Function NewActionsWithSaaSUser()
	
	ActionsWithSaaSUser = New Structure;
	ActionsWithSaaSUser.Insert("ChangePassword", False);
	ActionsWithSaaSUser.Insert("ChangeName", False);
	ActionsWithSaaSUser.Insert("ChangeFullName", False);
	ActionsWithSaaSUser.Insert("ChangeAccess", False);
	ActionsWithSaaSUser.Insert("ChangeAdministrativeAccess", False);
	
	ActionsWithCI = New Map;
	For each KeyAndValue In SaaSCached.ContactInformationKindAndXDTOUserMap() Do
		ActionsWithCI.Insert(KeyAndValue.Key, New Structure("Update", False));
	EndDo;
	// Key - CIKind, Value - structure of rights.
	ActionsWithSaaSUser.Insert("ContactInformation", ActionsWithCI);
	
	Return ActionsWithSaaSUser;
	
EndFunction

Function PrepareUserAccessObjects(Factory, User)
	
	UserInformation = Factory.Create(
		Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "User"));
	UserInformation.Zone = SaaS.SessionSeparatorValue();
	UserInformation.UserServiceID = Common.ObjectAttributeValue(User, "ServiceUserID");
	
	ObjectsList = Factory.Create(
		Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "ObjectsList"));
		
	ObjectsList.Item.Add(UserInformation);
	
	UserCIType = Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "UserContact");
	
	For each KeyAndValue In SaaSCached.ContactInformationKindAndXDTOUserMap() Do
		CIKind = Factory.Create(UserCIType);
		CIKind.UserServiceID = Common.ObjectAttributeValue(User, "ServiceUserID");
		CIKind.ContactType = KeyAndValue.Value;
		ObjectsList.Item.Add(CIKind);
	EndDo;
	
	Return ObjectsList;
	
EndFunction

Function ObjectsAccessRightsXDTOInActionsWithSaaSUser(Factory, ObjectsAccessRightsXDTO)
	
	UserInformationType = Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "User");
	UserCIType = Factory.Type("http://www.1c.ru/SaaS/ApplicationAccess", "UserContact");
	
	ActionsWithSaaSUser = NewActionsWithSaaSUser();
	ActionsWithCI = ActionsWithSaaSUser.ContactInformation;
	
	For each ObjectAccessRightsXDTO In ObjectsAccessRightsXDTO.Item Do
		
		If ObjectAccessRightsXDTO.Object.Type() = UserInformationType Then
			
			For each RightsListItem In ObjectAccessRightsXDTO.AccessRights.Item Do
				ActionWithUser = SaaSCached.
					XDTORightAndServiceUserActionMap().Get(RightsListItem.AccessRight);
				ActionsWithSaaSUser[ActionWithUser] = True;
			EndDo;
			
		ElsIf ObjectAccessRightsXDTO.Object.Type() = UserCIType Then
			CIKind = SaaSCached.XDTOContactInformationKindAndUserContactInformationKindMap().Get(
				ObjectAccessRightsXDTO.Object.ContactType);
			If CIKind = Undefined Then
				MessageTemplate = NStr("ru = 'Получен неизвестный вид контактной информации: %1'; en = 'Unknown contact information kind was received: %1'; pl = 'Otrzymano nieznany rodzaj informacji kontaktowych: %1';es_ES = 'Tipo de la información de contacto desconocido se ha recibido: %1';es_CO = 'Tipo de la información de contacto desconocido se ha recibido: %1';tr = 'Bilinmeyen iletişim bilgileri alındı:%1';it = 'Tipo sconosciuto informazioni di contatto è stato ottenuto:%1';de = 'Unbekannte Kontaktinformationen wurden empfangen: %1'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ObjectAccessRightsXDTO.Object.ContactType);
				Raise(MessageText);
			EndIf;
			
			ActionsWithCIKind = ActionsWithCI[CIKind];
			
			For each RightsListItem In ObjectAccessRightsXDTO.AccessRights.Item Do
				If RightsListItem.AccessRight = "Change" Then
					ActionsWithCIKind.Update = True;
				EndIf;
			EndDo;
		Else
			MessageTemplate = NStr("ru = 'Получен неизвестный тип объектов доступа: %1'; en = 'Unknown access object type received: %1'; pl = 'Otrzymano nieznany typ obiektu dostępu: %1';es_ES = 'Tipo del objeto de acceso desconocido recibido: %1';es_CO = 'Tipo del objeto de acceso desconocido recibido: %1';tr = 'Bilinmeyen erişim nesnesi türü alındı: %1';it = 'Sconosciuto tipo di oggetto di accesso è stato ricevuto:%1';de = 'Unbekannter Zugriffsobjekttyp erhalten: %1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, SaaS.XDTOTypePresentation(ObjectAccessRightsXDTO.Object.Type()));
			Raise(MessageText);
		EndIf;
		
	EndDo;
	
	Return ActionsWithSaaSUser;
	
EndFunction

Function GetLanguageCode(Val Language)
	
	If Language = Undefined Then
		Return "";
	Else
		Return Language.LanguageCode;
	EndIf;
	
EndFunction

// Handles web service errors.
// If the passed error info is not empty, writes the error details to the event log and raises an 
// exception with the brief error description.
// 
//
Procedure HandleWebServiceErrorInfo(Val ErrorInformation, Val OperationName)
	
	SaaS.HandleWebServiceErrorInfo(
		ErrorInformation,
		Metadata.Subsystems.StandardSubsystems.Subsystems.SaaS.Subsystems.UsersSaaS.Name,
		"ManageApplication", // Do not localize.
		OperationName);
	
EndProcedure

#EndRegion
