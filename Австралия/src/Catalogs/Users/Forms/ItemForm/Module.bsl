#Region Variables

&AtClient
Var WriteParametersOnFirstAdministratorCheck;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		
		CanChangeUsers = True;
		If Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
			ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
			CanChangeUsers = ModuleUsersInternalSaaS.CanChangeUsers();
		EndIf;
		
		If NOT CanChangeUsers Then
			If Object.Ref.IsEmpty() Then
				Raise
					NStr("ru = 'В демонстрационном режиме не поддерживается
					           |создание новых пользователей.'; 
					           |en = 'The demo does not support adding users.
					           |'; 
					           |pl = 'W trybie demonstracyjnym nie jest obsługiwane
					           |tworzenie nowych użytkowników.';
					           |es_ES = 'Nuevos usuarios no pueden
					           |crearse en el modo demo.';
					           |es_CO = 'Nuevos usuarios no pueden
					           |crearse en el modo demo.';
					           |tr = 'Demo modunda yeni kullanıcılar 
					           |oluşturulamıyor.';
					           |it = 'La demo non supporta l''aggiunta di utenti.
					           |';
					           |de = 'Der Demo-Modus unterstützt nicht
					           |das Anlegen neuer Benutzer.'");
			EndIf;
			ReadOnly = True;
		EndIf;
		
		If Object.Ref <> Users.AuthorizedUser() Then
			Items.Indent.Visible = False;
			Items.PasswordExistsLabel.Visible = False;
			Items.ChangePassword.Visible = False;
		EndIf;
		Items.InfobaseUserOpenIDAuthentication.Visible      = False;
		Items.InfobaseUserStandardAuthentication.Visible = False;
		Items.UserMustChangePasswordOnAuthorization.Visible = False;
		Items.InfobaseUserCannotChangePassword.Visible = False;
		Items.OSAuthenticationProperties.Visible  = False;
		Items.InfobaseUserRunMode.Visible = False;
	EndIf;
	
	If StandardSubsystemsServer.IsTrainingPlatform() Then
		Items.OSAuthenticationProperties.ReadOnly = True;
	EndIf;
	
	// Filling auxiliary data.
	
	// Filling the run mode selection list.
	For each RunMode In ClientRunMode Do
		ValueFullName = GetPredefinedValueFullName(RunMode);
		ValueName = Mid(ValueFullName, StrFind(ValueFullName, ".") + 1);
		Items.InfobaseUserRunMode.ChoiceList.Add(ValueName, String(RunMode));
	EndDo;
	Items.InfobaseUserRunMode.ChoiceList.SortByPresentation();
	
	// Filling the language selection list.
	If Metadata.Languages.Count() < 2 Then
		Items.InfobaseUserLanguage.Visible = False;
	Else
		For each LanguageMetadata In Metadata.Languages Do
			Items.InfobaseUserLanguage.ChoiceList.Add(
				LanguageMetadata.Name, LanguageMetadata.Synonym);
		EndDo;
	EndIf;
	
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(Object);
	
	// Preparing for execution of interactive actions according to the form opening scenarios.
	SetPrivilegedMode(True);
	
	If NOT ValueIsFilled(Object.Ref) Then
		// Creating an item.
		If Parameters.NewUserGroup <> Catalogs.UserGroups.AllUsers Then
			NewUserGroup = Parameters.NewUserGroup;
		EndIf;
		
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Copying the item.
			CopyingValue = Parameters.CopyingValue;
			Object.Description = "";
			
			If Not UsersInternal.UserAccessLevelAbove(CopyingValue, AccessLevel) Then
				ReadIBUser(ValueIsFilled(CopyingValue.IBUserID));
			Else
				ReadIBUser();
			EndIf;
			
			If Not AccessLevel.ChangeAuthorizationPermission Then
				CanSignIn = False;
				CanSignInDirectChangeValue = False;
			EndIf;
		Else
			// Adding the item.
			
			// Reading initial infobase user property values.
			ReadIBUser();
			
			If Not ValueIsFilled(Parameters.IBUserID) Then
				InfobaseUserStandardAuthentication = True;
				
				If Common.DataSeparationEnabled() Then
					InfobaseUserShowInList = False;
					InfobaseUserOpenIDAuthentication = True;
				EndIf;
				
				If AccessLevel.ChangeAuthorizationPermission Then
					CanSignIn = True;
					CanSignInDirectChangeValue = True;
				EndIf;
			EndIf;
		EndIf;
	Else
		// Opening an existing item.
		ReadIBUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", IBUserExists);
	InitialIBUserDetails = InitialIBUserDetails();
	SynchronizationWithServiceRequired = Object.Ref.IsEmpty();
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ModuleContactsManager.OnCreateAtServer(ThisObject, Object, "ContactInformation");
		OverrideContactInformationEditingSaaS();
	EndIf;
	
	GeneralFormSetup(Object, True);
	
	If Common.IsStandaloneWorkplace() Then
		Items.HeaderGroup.ReadOnly = True;
		Items.ContactInformation.ReadOnly = True;
		Items.AdditionalAttributesPage.ReadOnly = True;
		Items.CommentPage.ReadOnly = True;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation")
		AND ActionsWithSaaSUser <> Undefined Then
			ModuleContactsManager = Common.CommonModule("ContactsManager");
			ModuleContactsManager.SetContactInformationItemAvailability(ThisObject,
				DetermineContactInformationItemsAvailability());
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	
	PrepareOptionalAttribute("Individual");
	PrepareOptionalAttribute("Department");
	
	RefreshShowInChoiceListAttributeVisibility();
	
	If Not UsersInternalCached.Settings().CommonAuthorizationSettings Then
		Items.ChangeRestrictionGroup.Visible = False;
	EndIf;
	
	Items.UserMustChangePasswordOnAuthorization.ExtendedTooltip.Title =
		UsersInternal.HintUserMustChangePasswordOnAuthorization(False);
		
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommonClientServer.SetFormItemProperty(Items, "FormWriteAndClose", "Picture", PictureLib.WriteAndClose);
		CommonClientServer.SetFormItemProperty(Items, "FormWriteAndClose", "Representation", ButtonRepresentation.Picture);
		
		Items.Comment.InputHint = NStr("ru ='Произвольный текст'; en = 'Custom text'; pl = 'Dowolny tekst, opis, komentarz';es_ES = 'Texto libre';es_CO = 'Texto libre';tr = 'İsteğe bağlı metin';it = 'Testo personalizzato';de = 'Freitext'");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If WebClient Then
	Items.InfobaseUserOSUser.ChoiceButton = False;
	#EndIf
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	
	If Upper(EventName) = Upper("Write_ConstantsSet")
	   AND Upper(Source) = Upper("UseExternalUsers") Then
		
		AttachIdleHandler("ExternalUsersUsageOnChange", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ModuleContactsManager.OnReadAtServer(ThisObject, CurrentObject, "ContactInformation");
	EndIf;
	
	GeneralFormSetup(CurrentObject);
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	QuestionTitle = NStr("ru = 'Запись пользователя информационной базы'; en = 'Save infobase user'; pl = 'Zapis użytkownika bazy informacyjnej';es_ES = 'Registro del usuario de la infobase';es_CO = 'Registro del usuario de la infobase';tr = 'Veritabanı kullanıcı kayıtları';it = 'Salva utente infobase';de = 'Infobase-Benutzerdatensatz'");
	
	// Copying user rights.
	If ValueIsFilled(CopyingValue)
	   AND Not ValueIsFilled(Object.Ref)
	   AND CommonClient.SubsystemExists("StandardSubsystems.AccessManagement")
	   AND (Not WriteParameters.Property("DoNotCopyUserRights")
	      AND Not WriteParameters.Property("CopyUserRights")) Then
		
		Cancel = True;
		ShowQueryBox(
			New NotifyDescription("AfterAnswerToQuestionAboutCopyingRights", ThisObject, WriteParameters),
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Скопировать также права пользователя ""%1""?'; en = 'Do you want to copy the rights of the user ""%1""?'; pl = 'Skopiować również uprawnienia użytkownika ""%1""?';es_ES = '¿Copiar también los derechos de usuario ""%1""?';es_CO = '¿Copiar también los derechos de usuario ""%1""?';tr = '""%1"" kullanıcısının hakları kopyalansın mı?';it = 'Volete copiare i permessi dell''utente ""%1""?';de = 'Kopieren Sie auch die Benutzerrechte ""%1""?'"), String(CopyingValue)),
			QuestionDialogMode.YesNo,
			,
			,
			QuestionTitle);
		Return;
	EndIf;
	
	If CanSignIn Then
		
		If FormActions.Roles = "Edit"
		   AND InfobaseUserRoles.Count() = 0 Then
			
			If NOT WriteParameters.Property("WithEmptyRoleList") Then
				Cancel = True;
				ShowQueryBox(
					New NotifyDescription("AfterAnswerToQuestionAboutWritingWithEmptyRoleList", ThisObject, WriteParameters),
					NStr("ru = 'Пользователю информационной базы не установлено ни одной роли. Продолжить?'; en = 'No roles are assigned to the infobase user. Do you want to continue?'; pl = 'Użytkownikowi bazy informacyjnej nie przypisano żadnej roli. Kontynuować?';es_ES = 'Usuario de la infobase no se ha asignado a ningún rol. ¿Continuar?';es_CO = 'Usuario de la infobase no se ha asignado a ningún rol. ¿Continuar?';tr = 'Infobase kullanıcısına hiçbir rol atanmadı. Devam etmek istiyor musunuz?';it = 'Nessun ruolo è stato assegnato all''utente infobase. Volete continuare?';de = 'Infobase-Benutzer wurde keine Rolle zugewiesen. Fortsetzen?'"),
					QuestionDialogMode.YesNo,
					,
					,
					QuestionTitle);
				Return;
			EndIf;
		EndIf;
		
		// Processing the first administrator creation.
		If NOT WriteParameters.Property("WithFirstAdministratorAdding") Then
			Cancel = True;
			WriteParametersOnFirstAdministratorCheck = WriteParameters;
			AttachIdleHandler("CheckFirstAdministrator", 0.1, True);
			Return;
		EndIf;
	EndIf;
	
	If StandardSubsystemsClient.ClientRunParameters().DataSeparationEnabled
		AND SynchronizationWithServiceRequired
		AND ServiceUserPassword = Undefined Then
		
		Cancel = True;
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription("AfterServiceAuthenticationPasswordRequestBeforeWrite", ThisObject, WriteParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.AdditionalProperties.Insert("CopyingValue", CopyingValue);
	
	CurrentObject.AdditionalProperties.Insert("ServiceUserPassword", ServiceUserPassword);
	CurrentObject.AdditionalProperties.Insert("SynchronizeWithService", SynchronizationWithServiceRequired);
	
	If IBUserWritingRequired(ThisObject) Then
		
		IBUserDetails = IBUserDetails();
		
		If ValueIsFilled(Object.IBUserID) Then
			IBUserDetails.Insert("UUID", Object.IBUserID);
		EndIf;
		IBUserDetails.Insert("Action", "Write");
		
		CurrentObject.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
		
		If WriteParameters.Property("WithFirstAdministratorAdding") Then
			CurrentObject.AdditionalProperties.Insert("CreateAdministrator",
				NStr("ru = 'Первый пользователь информационной базы назначается администратором.'; en = 'The first infobase user is granted administrator rights.'; pl = 'Pierwszy użytkownik bazy informacyjnej jest wyznaczany na administratora.';es_ES = 'El primer usuario de la base de información se nombra por el administrador.';es_CO = 'El primer usuario de la base de información se nombra por el administrador.';tr = 'İlk Infobase kullanıcısına yönetici yetkileri verilir.';it = 'Il primo utente infobase ha permessi di accesso da amministratore.';de = 'Der erste Benutzer der Informationsbasis wird vom Administrator ernannt.'"));
		EndIf;
	EndIf;
	
	If FormActions.ItemProperties <> "Edit" Then
		FillPropertyValues(CurrentObject, Common.ObjectAttributesValues(
			CurrentObject.Ref, "Description, DeletionMark"));
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert("NewUserGroup", NewUserGroup);
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		If NOT Cancel AND FormActions.ContactInformation = "Edit" Then
			ModuleContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	SetPrivilegedMode(True);
	UsersInternal.WriteUserInfo(ThisObject, CurrentObject);
	SetPrivilegedMode(False);
	
	If WriteParameters.Property("CopyUserRights") Then
		Source = CopyingValue;
		Destination = CurrentObject.Ref;
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnCopyRightsToNewUser(Source, Destination);
		UsersInternal.CopyUserGroups(Source, Destination);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SynchronizationWithServiceRequired = False;
	
	If IBUserWritingRequired(ThisObject) Then
		WriteParameters.Insert(
			CurrentObject.AdditionalProperties.IBUserDetails.ActionResult);
	EndIf;
	
	GeneralFormSetup(CurrentObject, , WriteParameters);
	
	UpdateEmailChangeMethodSaaS();
	
	UsersInternal.AfterChangeUserOrUserGroupInForm();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Users", New Structure, Object.Ref);
	
	If WriteParameters.Property("IBUserAdded") Then
		Notify("IBUserAdded", WriteParameters.IBUserAdded, ThisObject);
		
	ElsIf WriteParameters.Property("IBUserChanged") Then
		Notify("IBUserChanged", WriteParameters.IBUserChanged, ThisObject);
		
	ElsIf WriteParameters.Property("IBUserDeleted") Then
		Notify("IBUserDeleted", WriteParameters.IBUserDeleted, ThisObject);
		
	ElsIf WriteParameters.Property("MappingToNonExistingIBUserCleared") Then
		Notify(
			"MappingToNonExistingIBUserCleared",
			WriteParameters.MappingToNonExistingIBUserCleared,
			ThisObject);
	EndIf;
	
	If ValueIsFilled(NewUserGroup) Then
		NotifyChanged(NewUserGroup);
		Notify("Write_UserGroups", New Structure, NewUserGroup);
		NewUserGroup = Undefined;
	EndIf;
	
	If WriteParameters.Property("WriteAndClose") Then
		AttachIdleHandler("CloseForm", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If IBUserWritingRequired(ThisObject) Then
		IBUserDetails = IBUserDetails();
		IBUserDetails.Insert("IBUserID", Object.IBUserID);
		UsersInternal.CheckIBUserDetails(IBUserDetails, Cancel);
	EndIf;
	
	If CanSignIn
	   AND ValueIsFilled(ValidityPeriod)
	   AND ValidityPeriod <= BegOfDay(CurrentSessionDate()) Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Ограничение должно быть до завтра или более.'; en = 'The password expiration date must be tomorrow or later.'; pl = 'Data ważności hasła musi być jutro lub później.';es_ES = 'La restricción debe ser hasta mañana o más.';es_CO = 'La restricción debe ser hasta mañana o más.';tr = 'Kısıtlama yarına kadar veya daha fazla olmalıdır.';it = 'La data di scadenza della password deve essere domani o in seguito.';de = 'Das Passwort soll bis morgen oder später gelten.'"),, "CanSignIn",, Cancel);
	EndIf;
	
	// Checking whether the metadata contains roles.
	If Not Items.Roles.ReadOnly Then
		Errors = Undefined;
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
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" в строке %1 не найдена в метаданных.'; en = 'Role ""%1"" in line %1 is not found in the metadata.'; pl = 'Rola ""%1"" w wierszu %1 nie została znaleziona w metadanych.';es_ES = 'El rol ""%1"" en la línea %1 no se ha encontrado en los metadatos.';es_CO = 'El rol ""%1"" en la línea %1 no se ha encontrado en los metadatos.';tr = '%1 satırındaki ""%1"" rolü metaverilerde bulunamadı.';it = 'Il ruolo ""%1"" nella riga %1 non è stato trovato nei metadati.';de = 'Die Rolle ""%1"" in der Zeile %1 wurde in den Metadaten nicht gefunden.'"), Row.Synonym));
			EndIf;
			If Row.IsUnavailableRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" недоступна для пользователей.'; en = 'Role ""%1"" is unavailable to users.'; pl = 'Rola ""%1"" nie jest dostępna dla użytkowników.';es_ES = 'El rol ""%1"" no está disponible para los usuarios.';es_CO = 'El rol ""%1"" no está disponible para los usuarios.';tr = '""%1"" rolü kullanıcılar için kullanılamaz.';it = 'Il ruolo ""%1"" non è disponibile per gli utenti.';de = 'Die Rolle ""%1"" ist für Benutzer nicht verfügbar.'"), Row.Synonym),
					"Roles",
					TreeItems.IndexOf(Row),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" в строке %1 недоступна для пользователей.'; en = 'Role ""%1"" in line %1 is unavailable to users.'; pl = 'Rola ""%1"" w wierszu %1 nie jest dostępna dla użytkowników.';es_ES = 'El rol ""%1"" en la línea %1 no está disponible para los usuarios.';es_CO = 'El rol ""%1"" en la línea %1 no está disponible para los usuarios.';tr = '%1 satırındaki ""%1"" rolü kullanıcılara açık değildir.';it = 'Il ruolo ""%1"" nella riga %1 non è disponibile agli utenti.';de = 'Die Rolle ""%1"" in der Zeile %1 ist den Benutzern nicht verfügbar.'"), Row.Synonym));
			EndIf;
		EndDo;
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ModuleContactsManager.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
		If Common.DataSeparationEnabled() Then
			CheckEmailFilling(Cancel);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FillFromIBUser(Command)
	
	FillFieldsByIBUserAtServer();
	
EndProcedure

&AtClient
Procedure DescriptionOnChange(Item)
	
	UpdateUsername(ThisObject, True);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure InvalidOnChange(Item)
	
	If Object.Invalid Then
		CanSignIn = False;
	Else
		CanSignIn = CanSignInDirectChangeValue
			AND (InfobaseUserOpenIDAuthentication
			   Or InfobaseUserStandardAuthentication
			   Or InfobaseUserOSAuthentication);
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure CanSignInOnChange(Item)
	
	If Object.DeletionMark AND CanSignIn Then
		CanSignIn = False;
		ShowMessageBox(,
			NStr("ru = 'Чтобы разрешить вход в программу, требуется снять
			           |пометку на удаление с этого пользователя.'; 
			           |en = 'To allow signing in to the application,
			           |clear the deletion mark from the user.'; 
			           |pl = 'Aby zezwolić na wejście do programu, należy usunąć
			           |zaznaczenie do usunięcia z tego użytkownika.';
			           |es_ES = 'Para permitir el inicio de la sesión, se requiere quitar
			           |la marca de borrar de este usuario.';
			           |es_CO = 'Para permitir el inicio de la sesión, se requiere quitar
			           |la marca de borrar de este usuario.';
			           |tr = 'Uygulamaya girebilmek için, kullanıcının silinme işareti 
			           |kaldırılmalıdır.';
			           |it = 'Per permettere l''accesso all''applicazione,
			           |rimuovere il contrassegno di eliminazione dall''utente.';
			           |de = 'Um sich am Programm anmelden zu können, müssen Sie
			           |das Deinstallationsfeld für diesen Benutzer deaktivieren.'"));
		Return;
	EndIf;
	
	UpdateUsername(ThisObject);
	
	If CanSignIn
	   AND NOT InfobaseUserOpenIDAuthentication
	   AND NOT InfobaseUserStandardAuthentication
	   AND NOT InfobaseUserOSAuthentication Then
	
		InfobaseUserStandardAuthentication = True;
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
	If Not AccessLevel.ChangeAuthorizationPermission
	   AND Not CanSignIn Then
		
		ShowMessageBox(,
			NStr("ru = 'После записи вход в программу сможет разрешить только администратор.'; en = 'Once you save the changes, only administrator can allow signing in to the application.'; pl = 'Po zapisaniu tylko administrator może zezwolić na logowanie.';es_ES = 'Después de haber guardado, solo el administrador puede permitir el inicio de sesión.';es_CO = 'Después de haber guardado, solo el administrador puede permitir el inicio de sesión.';tr = 'Kaydedildikten sonra uygulamaya giriş izni yalnızca yönetici tarafından verilebilecektir.';it = 'Una volta salvate le modifiche, sole gli amministratori possono permettere l''autenticazione nell''applicazione.';de = 'Nach dem Speichern kann nur der Administrator die Anmeldung zulassen.'"));
	EndIf;
	
	CanSignInDirectChangeValue = CanSignIn;
	
EndProcedure

&AtClient
Procedure ChangeAuthorizationRestriction(Command)
	
	OpenForm("Catalog.Users.Form.AuthorizationRestriction",, ThisObject,,,,
		New NotifyDescription("ChangeAuthorizationRestrictionCompletion", ThisObject));
	
EndProcedure

&AtClient
Procedure IBUserNameOnChange(Item)
	
	InfobaseUserName = TrimAll(InfobaseUserName);
	IBUserNameDirectChangeValue = InfobaseUserName;
	
	SetPropertiesAvailability(ThisObject);
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserStandardAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure UserMustChangePasswordOnAuthorizationOnChange(Item)
	
	If UserMustChangePasswordOnAuthorization Then
		InfobaseUserCannotChangePassword = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure IBUserShowInChoiceListOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserCannotChangePasswordOnChange(Item)
	
	If InfobaseUserCannotChangePassword Then
		UserMustChangePasswordOnAuthorization = False;
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserOpenIDAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure IBUserOSAuthenticationOnChange(Item)
	
	AuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure IBUserOSUserOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserOSUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	#If NOT WebClient AND NOT MobileClient Then
		OpenForm("Catalog.Users.Form.SelectOperatingSystemUser", , Item);
	#EndIf
	
EndProcedure

&AtClient
Procedure IBUserLanguageOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserRunModeOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure IBUserRunModeClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure PageOnChangePage(Item, CurrentPage)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		AND CurrentPage.Name = "AdditionalAttributesPage"
		AND Not ThisObject.PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UserMustChangePasswordOnAuthorizationExtendedTooltipURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	
	OpenForm("CommonForm.UserAuthorizationSettings", , ThisObject);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Providing contact information support.

&AtClient
Procedure Attachable_EmailOnChange(Item)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
		
	ModuleContactsManagerClient.OnChange(ThisObject, Item);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
	If NOT Object.Ref.IsEmpty() Then
		Return;
	EndIf;
	
	CITable = ThisObject.ContactInformationAdditionalAttributeDetails;
	
	EmailRow = CITable.FindRows(New Structure("Kind",
		ContactInformationKindUserEmail()))[0];
	
	If ValueIsFilled(ThisObject[EmailRow.AttributeName]) Then
		InfobaseUserPassword = "" + New UUID + "qQ";
		CheckPasswordSet(ThisObject, True);
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_EmailClearing(Item, StandardProcessing)
	
	If Not Item.TextEdit Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	
	ModuleContactsManagerClient.Clearing(ThisObject, Item.Name);
	
EndProcedure

&AtClient
Procedure Attachable_PhoneOnChange(Item)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	
	ModuleContactsManagerClient.OnChange(ThisObject, Item);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_EmailStartChoice(Item)
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	If ServiceUserPassword = Undefined Then
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription("Attachable_EmailStartChoiceCompletion", ThisObject),
			ThisObject,
			ServiceUserPassword);
	Else
		Attachable_EmailStartChoiceCompletion(Null, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_EmailStartChoiceCompletion(SaaSUserNewPassword, Context) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	If SaaSUserNewPassword <> Null Then
		ServiceUserPassword = SaaSUserNewPassword;
	EndIf;
	
	CITable = ThisObject.ContactInformationAdditionalAttributeDetails;
	
	Filter = New Structure("Kind", ContactInformationKindUserEmail());
	
	EmailRow = CITable.FindRows(Filter)[0];
	
	FormParameters = New Structure;
	FormParameters.Insert("ServiceUserPassword", ServiceUserPassword);
	FormParameters.Insert("OldEmail",  ThisObject[EmailRow.AttributeName]);
	FormParameters.Insert("User", Object.Ref);
	
	Try
		OpenForm("Catalog.Users.Form.EmailAddressChange", FormParameters, ThisObject,,,,
			New NotifyDescription("AfterChangeEmailAddress", ThisObject));
	Except
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.OnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnClick(Item, StandardProcessing)
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.Clearing(ThisObject, Item.Name);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.ExecuteCommand(ThisObject, Command.Name);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.AutoComplete(Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ModuleContactsManagerClient =
		CommonClient.CommonModule("ContactsManagerClient");
	ModuleContactsManagerClient.ChoiceProcessing(ThisObject, SelectedValue, Item.Name, StandardProcessing);
	
EndProcedure

#EndRegion

#Region RolesFormTableItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	TableRow = Items.Roles.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If TableRow.Check AND TableRow.Name = "InteractiveOpenExtReportsAndDataProcessors" Then
		Notification = New NotifyDescription("RolesMarkOnChangeAfterConfirm", ThisObject);
		FormParameters = New Structure("Key", "BeforeSelectRole");
		OpenForm("CommonForm.SecurityWarning", FormParameters, , , , , Notification);
	Else
		If TableRow.Name = "FullRights" Then
			DetermineNecessityForSynchronizationWithService(ThisObject);
		EndIf;
		ProcessRolesInterface("UpdateRoleComposition");
	EndIf;
	
EndProcedure

&AtClient
Procedure RolesMarkOnChangeAfterConfirm(Response, ExecutionParameters) Export
	TableRow = Items.Roles.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If Response = "Continue" Then
		ProcessRolesInterface("UpdateRoleComposition");
	Else
		TableRow.Check = False;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

&AtClient
Procedure ChangePassword(Command)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ReturnPasswordAndDoNotSet", True);
	AdditionalParameters.Insert("OldPassword", IBUserPreviousPassword);
	
	UsersInternalClient.OpenChangePasswordForm(Object.Ref, New NotifyDescription(
		"ChangePasswordAfterGetPassword", ThisObject), AdditionalParameters);
	
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

////////////////////////////////////////////////////////////////////////////////
// Support of additional attributes.

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesCheckBox.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Roles.Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("ru = 'ПолныеПрава'; en = 'Full rights'; pl = 'Pełny dostęp';es_ES = 'FullRights';es_CO = 'FullRights';tr = 'Tüm yetkiler';it = 'Permessi completi';de = 'VolleRechte'");

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesCheckBox.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RolesSynonym.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Roles.Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("ru = 'ПолныеПрава'; en = 'Full rights'; pl = 'Pełny dostęp';es_ES = 'FullRights';es_CO = 'FullRights';tr = 'Tüm yetkiler';it = 'Permessi completi';de = 'VolleRechte'");

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleCellTextColor);

EndProcedure

&AtClient
Procedure ExternalUsersUsageOnChange()
	
	RefreshShowInChoiceListAttributeVisibility();
	
EndProcedure

&AtServer
Procedure RefreshShowInChoiceListAttributeVisibility()
	
	Items.InfobaseUserShowInList.Visible =
		  Not Common.DataSeparationEnabled()
		AND Not GetFunctionalOption("UseExternalUsers")
	
EndProcedure

&AtServer
Procedure GeneralFormSetup(CurrentObject, OnCreateAtServer = False, WriteParameters = Undefined)
	
	If InitialIBUserDetails = Undefined Then
		Return; // OnReadAtServer before OnCreateAtServer.
	EndIf;
	
	If Not OnCreateAtServer Then
		ReadIBUser();
	EndIf;
	
	SetPrivilegedMode(True);
	UsersInternal.ReadUserInfo(ThisObject);
	SetPrivilegedMode(False);
	
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(CurrentObject);
	
	DefineActionsInForm();
	
	FindUserAndIBUserDifferences(WriteParameters);
	
	ProcessRolesInterface("SetRolesReadOnly",
		    UsersInternal.CannotEditRoles()
		Or FormActions.Roles <> "Edit"
		Or Not AccessLevel.AuthorizationSettings);
	
	If Common.DataSeparationEnabled()
	   AND Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ActionsWithSaaSUser = ModuleUsersInternalSaaS.GetActionsWithSaaSUser(
			CurrentObject.Ref);
	EndIf;
	
	// Setting up viewing options.
	Items.ContactInformation.Visible   = ValueIsFilled(FormActions.ContactInformation);
	Items.IBUserProperies.Visible = ValueIsFilled(FormActions.IBUserProperies);
	
	OutputRoleList = ValueIsFilled(FormActions.Roles);
	Items.RolesRepresentation.Visible = OutputRoleList;
	Items.OneCEnterpriseAuthenticationProperties.Representation =
		?(OutputRoleList, UsualGroupRepresentation.None, UsualGroupRepresentation.NormalSeparation);
	
	Items.CheckAuthorizationSettingsRecommendation.Visible =
		  AccessLevel.ChangeAuthorizationPermission
		AND CurrentObject.Prepared
		AND Not CanSignInOnRead;
	
	// Setting editing options.
	If CurrentObject.Internal Then
		ReadOnly = True;
	EndIf;
	Items.InternalUserGroup.Visible = CurrentObject.Internal;
	
	ReadOnly = ReadOnly
		OR FormActions.Roles                   <> "Edit"
		  AND FormActions.ItemProperties       <> "Edit"
		  AND FormActions.ContactInformation   <> "Edit"
		  AND FormActions.IBUserProperies <> "Edit";
	
	UsersInternalClientServer.SetWriteAndCloseButtonAvailability(ThisObject);
	
	Items.Description.ReadOnly =
		Not (FormActions.ItemProperties = "Edit" AND AccessLevel.ListManagement);
	
	Items.Invalid.ReadOnly = Items.Description.ReadOnly;
	Items.Individual.ReadOnly = Items.Description.ReadOnly;
	Items.Department.ReadOnly  = Items.Description.ReadOnly;
	
	Items.MainProperties.ReadOnly =
		Not (  FormActions.IBUserProperies = "Edit"
		    AND (AccessLevel.ListManagement Or AccessLevel.ChangeCurrent));
	
	Items.IBUserName1.ReadOnly                      = Not AccessLevel.AuthorizationSettings;
	Items.IBUserName2.ReadOnly                      = Not AccessLevel.AuthorizationSettings;
	Items.InfobaseUserStandardAuthentication.ReadOnly = Not AccessLevel.AuthorizationSettings;
	Items.InfobaseUserOpenIDAuthentication.ReadOnly      = Not AccessLevel.AuthorizationSettings;
	Items.InfobaseUserOSAuthentication.ReadOnly          = Not AccessLevel.AuthorizationSettings;
	Items.InfobaseUserOSUser.ReadOnly            = Not AccessLevel.AuthorizationSettings;
	
	Items.InfobaseUserShowInList.ReadOnly = Not AccessLevel.ListManagement;
	Items.UserMustChangePasswordOnAuthorization.ReadOnly        = Not AccessLevel.ListManagement;
	Items.InfobaseUserCannotChangePassword.ReadOnly = Not AccessLevel.ListManagement;
	Items.InfobaseUserRunMode.ReadOnly            = Not AccessLevel.ListManagement;
	
	Items.InfobaseUserLanguage.ReadOnly = Not AccessLevel.ListManagement;
	
	Items.Comment.ReadOnly =
		Not (FormActions.ItemProperties = "Edit" AND AccessLevel.ListManagement);
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtServer
Procedure PrepareOptionalAttribute(AttributeName)
	
	If TypeOf(Object[AttributeName]) = Type("String") Then
		Items[AttributeName].Visible = False;
	Else
		DepartmentTypes = Metadata.DefinedTypes[AttributeName].Type.Types();
		If DepartmentTypes.Count() = 1 AND Common.IsReference(DepartmentTypes[0]) Then
			MetadataObject = Metadata.FindByType(DepartmentTypes[0]);
			Items[AttributeName].Title = ObjectPresentation(MetadataObject);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function ObjectPresentation(MetadataObject)
	
	If ValueIsFilled(MetadataObject.ObjectPresentation) Then
		Return MetadataObject.ObjectPresentation;
	EndIf;
	
	Return MetadataObject.Presentation();
	
EndFunction

// The BeforeWrite event handler continuation.
&AtClient
Procedure AfterServiceAuthenticationPasswordRequestBeforeWrite(SaaSUserNewPassword, WriteParameters) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = SaaSUserNewPassword;
	
	Try
		Write(WriteParameters);
	Except
		ServiceUserPassword = Undefined;
		Raise;
	EndTry;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateUsername(Form, DescriptionOnChange = False)
	
	Items = Form.Items;
	Object   = Form.Object;
	
	If Form.IBUserExists Then
		Return;
	EndIf;
	
	ShortName = UsersInternalClientServer.GetIBUserShortName(Form.Object.Description);
	
	If Items.NameMarkIncompleteToggle.CurrentPage = Items.NameWithoutMarkIncomplete Then
		
		If Not ValueIsFilled(Form.IBUserNameDirectChangeValue)
		   AND Form.InfobaseUserName = ShortName Then
			
			Form.InfobaseUserName = "";
		EndIf;
	Else
		If DescriptionOnChange
		 Or Not ValueIsFilled(Form.InfobaseUserName) Then
			
			Form.InfobaseUserName = ShortName;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AuthenticationOnChange()
	
	SetPropertiesAvailability(ThisObject);
	
	If NOT InfobaseUserOpenIDAuthentication
	   AND NOT InfobaseUserStandardAuthentication
	   AND NOT InfobaseUserOSAuthentication Then
	
		CanSignIn = False;
		
	ElsIf Not CanSignIn Then
		CanSignIn = CanSignInDirectChangeValue;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterChangeEmailAddress(Result, Context) Export
	
	If Result = "" Then
		ServiceUserPassword = Undefined;
	EndIf;
	
EndProcedure

// The procedure that follows ChangePassword procedure.
&AtClient
Procedure ChangePasswordAfterGetPassword(Result, Context) Export
	
	If Not ValueIsFilled(Result) Then
		Return;
	EndIf;
	
	InfobaseUserPassword       = Result.NewPassword;
	IBUserPreviousPassword = Result.OldPassword;
	
	If Result.OldPassword <> Undefined Then
		ServiceUserPassword = Result.OldPassword;
	EndIf;
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
	CheckPasswordSet(ThisObject, ValueIsFilled(InfobaseUserPassword));
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure CheckPasswordSet(Form, PasswordSet)
	
	UsersInternalClientServer.CheckPasswordSet(Form, PasswordSet);
	
EndProcedure

&AtServer
Procedure DefineActionsInForm()
	
	FormActions = New Structure;
	
	// "", "View," "Edit."
	FormActions.Insert("Roles", "");
	
	// "", "View," "Edit."
	FormActions.Insert("ContactInformation", "View");
	
	// "", "ViewAll", "Edit".
	FormActions.Insert("IBUserProperies", "");
	
	// "", "View," "Edit."
	FormActions.Insert("ItemProperties", "View");
	
	If Not AccessLevel.SystemAdministrator
	   AND AccessLevel.FullRights
	   AND Users.IsFullUser(Object.Ref, True) Then
		
		// The system administrator is read-only.
		FormActions.Roles                   = "View";
		FormActions.IBUserProperies = "View";
	
	ElsIf AccessLevel.SystemAdministrator
	      OR AccessLevel.FullRights Then
		
		FormActions.Roles                   = "Edit";
		FormActions.ContactInformation   = "Edit";
		FormActions.IBUserProperies = "Edit";
		FormActions.ItemProperties       = "Edit";
	Else
		If AccessLevel.ChangeCurrent Then
			FormActions.IBUserProperies = "Edit";
			FormActions.ContactInformation   = "Edit";
		EndIf;
		
		If AccessLevel.ListManagement Then
			// The person responsible for the list of users and user groups.
			// Typically this is a person who executes employment, transfer, and reassignment orders, as well as 
			//  division, department, and work group creation orders.
			FormActions.IBUserProperies = "Edit";
			FormActions.ContactInformation   = "Edit";
			FormActions.ItemProperties       = "Edit";
			
			If AccessLevel.AuthorizationSettings Then
				FormActions.Roles = "Edit";
			EndIf;
			If Users.IsFullUser(Object.Ref) Then
				FormActions.Roles = "View";
			EndIf;
		EndIf;
	EndIf;
	
	UsersInternal.OnDefineActionsInForm(Object.Ref, FormActions);
	
	// Checking action names in the form.
	If StrFind(", View, Edit,", ", " + FormActions.Roles + ",") = 0 Then
		FormActions.Roles = "";
		
	ElsIf FormActions.Roles = "Edit"
	        AND UsersInternal.CannotEditRoles() Then
		
		FormActions.Roles = "View";
	EndIf;
	
	If StrFind(", View, Edit,", ", " + FormActions.ContactInformation + ",") = 0 Then
		FormActions.ContactInformation = "";
	EndIf;
	
	If StrFind(", View, ViewAll, Edit, EditOwn, EditAll,",
	           ", " + FormActions.IBUserProperies + ",") = 0 Then
		
		FormActions.IBUserProperies = "";
		
	Else // For backward compatibility.
		If StrFind(FormActions.IBUserProperies, "View") Then
			FormActions.IBUserProperies = "View";
			
		ElsIf StrFind(FormActions.IBUserProperies, "Edit") Then
			FormActions.IBUserProperies = "Edit";
		EndIf;
	EndIf;
	
	If StrFind(", View, Edit,", ", " + FormActions.ItemProperties + ",") = 0 Then
		FormActions.ItemProperties = "";
	EndIf;
	
	If Object.Internal Then
		If FormActions.Roles = "Edit" Then
			FormActions.Roles = "View";
		EndIf;
		
		If FormActions.ContactInformation = "Edit" Then
			FormActions.ContactInformation = "View";
		EndIf;
		
		If FormActions.IBUserProperies = "Edit" Then
			FormActions.IBUserProperies = "View";
		EndIf;
		
		If FormActions.ItemProperties = "Edit" Then
			FormActions.ItemProperties = "View";
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function IBUserDetails(ForFirstAdministratorCheck = False)
	
	If AccessLevel.ListManagement
	   AND FormActions.ItemProperties = "Edit" Then
		
		InfobaseUserFullName = Object.Description;
	EndIf;
	
	If AccessLevel.SystemAdministrator
	 Or AccessLevel.FullRights Then
		
		Result = Users.NewIBUserDetails();
		Users.CopyIBUserProperties(
			Result,
			ThisObject,
			,
			"UUID,
			|Roles",
			"InfobaseUser");
		
		Result.Insert("CanSignIn", CanSignIn);
	Else
		Result = New Structure;
		
		If AccessLevel.ChangeCurrent Then
			Result.Insert("Password", InfobaseUserPassword);
			Result.Insert("Language",   InfobaseUserLanguage);
		EndIf;
		
		If AccessLevel.ListManagement Then
			Result.Insert("CanSignIn",  CanSignIn);
			Result.Insert("ShowInList", InfobaseUserShowInList
				AND Not GetFunctionalOption("UseExternalUsers"));
			Result.Insert("CannotChangePassword", InfobaseUserCannotChangePassword);
			Result.Insert("Language",                    InfobaseUserLanguage);
			Result.Insert("RunMode",            InfobaseUserRunMode);
			
			If FormActions.ItemProperties = "Edit" Then
				Result.Insert("FullName", InfobaseUserFullName);
			EndIf;
		EndIf;
		
		If AccessLevel.AuthorizationSettings Then
			Result.Insert("StandardAuthentication", InfobaseUserStandardAuthentication);
			Result.Insert("Name",                       InfobaseUserName);
			Result.Insert("Password",                    InfobaseUserPassword);
			Result.Insert("OpenIDAuthentication",      InfobaseUserOpenIDAuthentication);
			Result.Insert("OSAuthentication",          InfobaseUserOSAuthentication);
			Result.Insert("OSUser",            InfobaseUserOSUser);
		EndIf;
	EndIf;
	
	If Not AccessLevel.AuthorizationSettings Then
		Return Result;
	EndIf;
	
	If Not UsersInternal.CannotEditRoles() Then
		CurrentRoles = InfobaseUserRoles.Unload(, "Role").UnloadColumn("Role");
		Result.Insert("Roles", CurrentRoles);
	EndIf;
	
	If ForFirstAdministratorCheck Then
		Return Result;
	EndIf;
	
	// Adding roles required to create the first administrator.
	If UsersInternal.CreateFirstAdministratorRequired(Result) Then
		
		If Result.Property("Roles") AND Result.Roles <> Undefined Then
			AdministratorRoles = Result.Roles;
		Else
			AdministratorRoles = New Array;
		EndIf;
		
		If AdministratorRoles.Find("FullRights") = Undefined Then
			AdministratorRoles.Add("FullRights");
		EndIf;
		
		If AdministratorRoles.Find("SystemAdministrator") = Undefined Then
			AdministratorRoles.Add("SystemAdministrator");
		EndIf;
		Result.Insert("Roles", AdministratorRoles);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function CreateFirstAdministratorRequired(QuestionText = Undefined)
	
	Return UsersInternal.CreateFirstAdministratorRequired(
		IBUserDetails(True), QuestionText);
	
EndFunction

&AtClientAtServerNoContext
Procedure DetermineNecessityForSynchronizationWithService(Form)
	
	Form.SynchronizationWithServiceRequired = True;
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutWritingWithEmptyRoleList(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("WithEmptyRoleList");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFirstAdministrator() 
	
	WriteParameters = WriteParametersOnFirstAdministratorCheck;
	WriteParametersOnFirstAdministratorCheck = Undefined;
	
	QuestionText = "";
	If Not CreateFirstAdministratorRequired(QuestionText) Then
		WriteParameters.Insert("WithFirstAdministratorAdding");
		Try
			Write(WriteParameters);
		Except
			ServiceUserPassword = Undefined;
			Raise;
		EndTry;
		Return;
	EndIf;
	
	QuestionTitle = NStr("ru = 'Запись пользователя информационной базы'; en = 'Save infobase user'; pl = 'Zapis użytkownika bazy informacyjnej';es_ES = 'Registro del usuario de la infobase';es_CO = 'Registro del usuario de la infobase';tr = 'Veritabanı kullanıcı kayıtları';it = 'Salva utente infobase';de = 'Infobase-Benutzerdatensatz'");
	ShowQueryBox(
		New NotifyDescription("AfterFirstAdministratorCreationConfirmation", ThisObject, WriteParameters),
		QuestionText, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

&AtClient
Procedure AfterFirstAdministratorCreationConfirmation(Response, WriteParameters) Export
	
	If Response <> DialogReturnCode.No Then
		WriteParameters.Insert("WithFirstAdministratorAdding");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutCopyingRights(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("CopyUserRights");
	Else
		WriteParameters.Insert("DoNotCopyUserRights");
	EndIf;
	Write(WriteParameters);
	
EndProcedure

&AtClient
Procedure CloseForm()
	
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Providing contact information support.

&AtServer
Procedure Attachable_UpdateContactInformation(Result) Export
	
	ContactsManager.UpdateContactInformation(ThisObject, Object, Result);
	
EndProcedure

&AtServer
Procedure OverrideContactInformationEditingSaaS()
	
	If NOT Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ContactInformation = ThisObject.ContactInformationAdditionalAttributeDetails;
	
	EmailRow = ContactInformation.FindRows(New Structure("Kind", Catalogs["ContactInformationKinds"].UserEmail))[0];
	EmailItem = Items[EmailRow.AttributeName];
	EmailItem.SetAction("OnChange", "Attachable_EmailOnChange");
	EmailItem.SetAction("Clearing",      "Attachable_EmailClearing");
	EmailItem.AutoMarkIncomplete = True;
	
	EmailItem.ChoiceButton = ValueIsFilled(Object.Ref) AND ValueIsFilled(ThisObject[EmailRow.AttributeName]);
	EmailItem.TextEdit = Not EmailItem.ChoiceButton;
	EmailItem.SetAction("StartChoice", "Attachable_EmailStartChoice");
	
	PhoneRow = ContactInformation.FindRows(New Structure("Kind", Catalogs["ContactInformationKinds"].UserPhone))[0];
	PhoneItem = Items[PhoneRow.AttributeName];
	PhoneItem.SetAction("OnChange", "Attachable_PhoneOnChange");
	
EndProcedure

&AtServer
Procedure UpdateEmailChangeMethodSaaS()
	
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ContactInformation = ThisObject.ContactInformationAdditionalAttributeDetails;
	
	EmailRow = ContactInformation.FindRows(New Structure("Kind", Catalogs["ContactInformationKinds"].UserEmail))[0];
	EmailItem = Items[EmailRow.AttributeName];
	
	EmailItem.ChoiceButton = ValueIsFilled(Object.Ref) AND ValueIsFilled(ThisObject[EmailRow.AttributeName]);
	EmailItem.TextEdit = Not EmailItem.ChoiceButton;
	
EndProcedure

&AtClientAtServerNoContext
Function ContactInformationKindUserEmail()
	
	PredefinedValueName = "Catalog." + "ContactInformationKinds" + ".UserEmail";
	
	Return PredefinedValue(PredefinedValueName);
	
EndFunction

&AtServer
Procedure CheckEmailFilling(Cancel)
	
	CITable = ThisObject.ContactInformationAdditionalAttributeDetails;
	
	EmailRow = CITable.FindRows(New Structure("Kind",
		ContactInformationKindUserEmail()))[0];
	
	If ValueIsFilled(ThisObject[EmailRow.AttributeName]) Then
		Return;
	EndIf;
	
	CommonClientServer.MessageToUser(
		NStr("ru = 'Не заполнен адрес электронной почты'; en = 'The email address is blank.'; pl = 'Nie wypełniono adresu poczty elektronicznej';es_ES = 'La dirección de correo electrónico no rellenada';es_CO = 'La dirección de correo electrónico no rellenada';tr = 'E-posta adresi boş.';it = 'L''indirizzo email è vuoto.';de = 'Nicht ausgefüllte E-Mail-Adresse'"),,
		EmailRow.AttributeName,, Cancel);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Support of additional attributes.

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Processes an infobase user

&AtServer
Function InitialIBUserDetails()
	
	SetPrivilegedMode(True);
	
	If InitialIBUserDetails <> Undefined Then
		InitialIBUserDetails.Roles = New Array;
		Return InitialIBUserDetails;
	EndIf;
	
	IBUserDetails = Users.NewIBUserDetails();
	
	If Common.DataSeparationEnabled() Then
		IBUserDetails.ShowInList = False;
	Else
		IBUserDetails.ShowInList =
			NOT Constants.UseExternalUsers.Get();
	EndIf;
	IBUserDetails.StandardAuthentication = True;
	IBUserDetails.Roles = New Array;
	
	Return IBUserDetails;
	
EndFunction

&AtServer
Procedure ReadIBUser(OnCopyItem = False)
	
	SetPrivilegedMode(True);
	
	ReadProperties      = Undefined;
	IBUserDetails   = InitialIBUserDetails();
	IBUserExists = False;
	IBUserMain   = False;
	CanSignIn   = False;
	CanSignInDirectChangeValue = False;
	
	If OnCopyItem Then
		
		ReadProperties = Users.IBUserProperies(Parameters.CopyingValue.IBUserID);
		If ReadProperties <> Undefined Then
			
			// Mapping an infobase user to a catalog user.
			If Users.CanSignIn(ReadProperties) Then
				CanSignIn = True;
				CanSignInDirectChangeValue = True;
			EndIf;
			
			// Copying infobase user properties and roles.
			FillPropertyValues(
				IBUserDetails,
				ReadProperties,
				"CannotChangePassword,
				|ShowInList,
				|DefaultInterface,
				|RunMode" + ?(Not Items.InfobaseUserLanguage.Visible, "", ",
				|Language") + ?(UsersInternal.CannotEditRoles(), "", ",
				|Roles"));
		EndIf;
		Object.IBUserID = Undefined;
		CheckPasswordSet(ThisObject, False);
	Else
		ReadProperties = Users.IBUserProperies(Object.IBUserID);
		If ReadProperties <> Undefined Then
		
			IBUserExists = True;
			IBUserMain = True;
		
		ElsIf Parameters.Property("IBUserID")
		        AND ValueIsFilled(Parameters.IBUserID) Then
			
			Object.IBUserID = Parameters.IBUserID;
			ReadProperties = Users.IBUserProperies(Object.IBUserID);
			If ReadProperties <> Undefined Then
				
				IBUserExists = True;
				If Object.Description <> ReadProperties.FullName Then
					Object.Description = ReadProperties.FullName;
					Modified = True;
				EndIf;
			EndIf;
		EndIf;
		
		If IBUserExists Then
			
			If Users.CanSignIn(ReadProperties) Then
				CanSignIn = True;
				CanSignInDirectChangeValue = True;
			EndIf;
			
			FillPropertyValues(
				IBUserDetails,
				ReadProperties,
				"Name,
				|FullName,
				|OpenIDAuthentication,
				|StandardAuthentication,
				|ShowInList,
				|CannotChangePassword,
				|OSAuthentication,
				|OSUser,
				|DefaultInterface,
				|RunMode" + ?(Not Items.InfobaseUserLanguage.Visible, "", ",
				|Language") + ?(UsersInternal.CannotEditRoles(), "", ",
				|Roles"));
		EndIf;
		
		If ReadProperties = Undefined Then
			CheckPasswordSet(ThisObject, False);
		Else
			CheckPasswordSet(ThisObject, ReadProperties.PasswordIsSet);
		EndIf;
	EndIf;
	
	Users.CopyIBUserProperties(
		ThisObject,
		IBUserDetails,
		,
		"UUID,
		|Roles" + ?(GetFunctionalOption("UseExternalUsers"), ",
		|ShowInList", ""),
		"InfobaseUser");
	
	If IBUserMain AND Not CanSignIn Then
		StoredProperties = UsersInternal.StoredIBUserProperties(Object.Ref);
		InfobaseUserOpenIDAuthentication      = StoredProperties.OpenIDAuthentication;
		InfobaseUserStandardAuthentication = StoredProperties.StandardAuthentication;
		InfobaseUserOSAuthentication          = StoredProperties.OSAuthentication;
	EndIf;
	
	ProcessRolesInterface("FillRoles", IBUserDetails.Roles);
	
	CanSignInOnRead = CanSignIn;
	
EndProcedure

&AtServer
Procedure FindUserAndIBUserDifferences(WriteParameters = Undefined)
	
	// Checking whether the FullName infobase user property matches the Description user attribute.
	// 
	
	ShowDifference = True;
	ShowDifferenceResolvingCommands = False;
	
	If NOT IBUserExists Then
		ShowDifference = False;
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		Object.Description = InfobaseUserFullName;
		ShowDifference = False;
		
	ElsIf AccessLevel.ListManagement Then
		
		PropertiesToResolve = New Array;
		
		If InfobaseUserFullName <> Object.Description Then
			ShowDifferenceResolvingCommands =
				    ShowDifferenceResolvingCommands
				Or FormActions.ItemProperties = "Edit";
			
			PropertiesToResolve.Insert(0, StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Полное имя ""%1""'; en = 'Full name: ""%1""'; pl = 'Imię i nazwisko ""%1""';es_ES = 'Nombre completo ""%1""';es_CO = 'Nombre completo ""%1""';tr = 'Tam isim ""%1""';it = 'Nome completo: ""%1""';de = 'Vollständiger Name ""%1""'"),
				InfobaseUserFullName));
		EndIf;
		
		If PropertiesToResolve.Count() > 0 Then
			PropertiesToResolveString = "";
			CurrentRow = "";
			For each PropertyToResolve In PropertiesToResolve Do
				If StrLen(CurrentRow + PropertyToResolve) > 90 Then
					PropertiesToResolveString = PropertiesToResolveString + TrimR(CurrentRow) + ", " + Chars.LF;
					CurrentRow = "";
				EndIf;
				CurrentRow = CurrentRow + ?(ValueIsFilled(CurrentRow), ", ", "") + PropertyToResolve;
			EndDo;
			If ValueIsFilled(CurrentRow) Then
				PropertiesToResolveString = PropertiesToResolveString + CurrentRow;
			EndIf;
			If ShowDifferenceResolvingCommands Then
				Recommendation = Chars.LF
					+ NStr("ru = 'Нажмите ""Записать"", чтобы устранить различия и не выводить это предупреждение.'; en = 'To resolve the differences and not to show this message again, click ""Save"".'; pl = 'Kliknij ""Zapisz"", aby usunąć różnice i nie pokazywać ponownie tego komunikatu.';es_ES = 'Hacer clic en ""Inscribir"" para solucionar las diferencias y no mostrar este mensaje de nuevo.';es_CO = 'Hacer clic en ""Inscribir"" para solucionar las diferencias y no mostrar este mensaje de nuevo.';tr = 'Farklıları gidermek ve bu uyarıyı tekrar göstermemek için ""Kayıt"" ''a tıklayın.';it = 'Per risolvere le differenze e non mostrare questo messaggio di nuovo, premere ""Salva""';de = 'Klicken Sie auf ""Speichern"", um die Unterschiede zu beheben und diese Nachricht nicht mehr anzuzeigen.'");
			
			ElsIf Not Users.IsFullUser() Then
				Recommendation = Chars.LF
					+ NStr("ru = 'Обратитесь к администратору, чтобы устранить различия.'; en = 'To resolve the differences, contact your system administrator.'; pl = 'Skontaktuj się z administratorem, aby usunąć różnice.';es_ES = 'Contactar su administrador para resolver las diferencias.';es_CO = 'Contactar su administrador para resolver las diferencias.';tr = 'Farklılıkları gidermek için yöneticinize başvurun.';it = 'Per risolvere le differenze, contatta il tuo amministratore di sistema.';de = 'Wenden Sie sich an Ihren Administrator, um die Unterschiede zu beheben.'");
			Else
				Recommendation = "";
			EndIf;
			Items.PropertiesMismatchNote.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Следующие свойства пользователя информационной базы отличаются от указанных в этой форме:
				           |%1.'; 
				           |en = 'The following infobase user properties differ from the properties specified in the form:
				           |%1.'; 
				           |pl = 'Następujące właściwości użytkownika w bazie danych różnią się od podanych w tym formularzu:
				           |%1.';
				           |es_ES = 'Las siguientes propiedades del usuario de la infobase son distintas de aquellas especificadas en este formulario:
				           |%1.';
				           |es_CO = 'Las siguientes propiedades del usuario de la infobase son distintas de aquellas especificadas en este formulario:
				           |%1.';
				           |tr = 'Veritabanı kullanıcısının aşağıdaki özellikleri, bu formda belirtilenlerden farklıdır: 
				           |%1';
				           |it = 'Le seguenti proprietà utente database differiscono dalle proprietà specificate nel modulo:
				           |%1.';
				           |de = 'Die folgenden Eigenschaften des Informationsbasisbenutzers unterscheiden sich von den in dieser Form angegebenen:
				           |%1.'"),
				PropertiesToResolveString) + Recommendation;
		Else
			ShowDifference = False;
		EndIf;
	Else
		ShowDifference = False;
	EndIf;
	
	Items.PropertiesMismatchProcessing.Visible   = ShowDifference;
	Items.ResolveDifferencesCommandProperties.Visible = ShowDifferenceResolvingCommands;
	Items.PropertiesMismatchNote.VerticalAlign = ?(ValueIsFilled(Recommendation),
		ItemVerticalAlign.Top, ItemVerticalAlign.Center);
	
	// Determining the mapping between a nonexistent infobase user and a catalog user.
	HasNewMappingToNonExistingIBUser
		= NOT IBUserExists
		AND ValueIsFilled(Object.IBUserID);
	
	If WriteParameters <> Undefined
	   AND HasMappingToNonexistentIBUser
	   AND NOT HasNewMappingToNonExistingIBUser Then
		
		WriteParameters.Insert("MappingToNonExistingIBUserCleared", Object.Ref);
	EndIf;
	HasMappingToNonexistentIBUser = HasNewMappingToNonExistingIBUser;
	
	If AccessLevel.ListManagement Then
		Items.MappingMismatchProcessing.Visible = HasMappingToNonexistentIBUser;
	Else
		// Cannot change the mapping.
		Items.MappingMismatchProcessing.Visible = False;
	EndIf;
	
	If FormActions.ItemProperties = "Edit" Then
		Recommendation = Chars.LF
			+ NStr("ru = 'Нажмите ""Записать"", чтобы устранить проблему и не выводить это предупреждение.'; en = 'To eliminate the issue and not to show this message again, click ""Save"".'; pl = 'Aby wyeliminować problem i nie pokazywać go ponownie, kliknij ""Zapisz"".';es_ES = 'Haga clic en ""Guardar"" para solucionar el problema y no mostrar este aviso.';es_CO = 'Haga clic en ""Guardar"" para solucionar el problema y no mostrar este aviso.';tr = 'Sorunu ortadan kaldırmak ve bu uyarıyı tekrar göstermemek için ""Kayıt"" ''a tıklayın.';it = 'Per eleminare questo problema e non mostrare questo messaggio di nuovo, premere ""Salva"".';de = 'Drücken Sie ""Speichern"", um das Problem zu beheben und diese Warnung nicht anzuzeigen.'");
		
	ElsIf Not Users.IsFullUser() Then
		Recommendation = Chars.LF
			+ NStr("ru = 'Обратитесь к администратору, чтобы устранить различия.'; en = 'To resolve the differences, contact your system administrator.'; pl = 'Skontaktuj się z administratorem, aby usunąć różnice.';es_ES = 'Contactar su administrador para resolver las diferencias.';es_CO = 'Contactar su administrador para resolver las diferencias.';tr = 'Farklılıkları gidermek için yöneticinize başvurun.';it = 'Per risolvere le differenze, contatta il tuo amministratore di sistema.';de = 'Wenden Sie sich an Ihren Administrator, um die Unterschiede zu beheben.'");
	Else
		Recommendation = "";
	EndIf;
	
	Items.MappingMismatchNote.Title =
		NStr("ru = 'Пользователь информационной базы не найден.'; en = 'The infobase user is not found.'; pl = 'Użytkownik bazy informacyjnej nie został znaleziony.';es_ES = 'Usuario de la infobase no encontrado.';es_CO = 'Usuario de la infobase no encontrado.';tr = 'Veritabanı kullanıcısı bulunamadı.';it = 'L''utente infobase non è stato trovato.';de = 'Der Benutzer der Informationsbasis wurde nicht gefunden.'") + Recommendation;
	
EndProcedure

&AtServer
Procedure FillFieldsByIBUserAtServer()
	
	If AccessLevel.ListManagement
	   AND FormActions.ItemProperties = "Edit" Then
		
		Object.Description = InfobaseUserFullName;
	EndIf;
	
	FindUserAndIBUserDifferences();
	
	SetPropertiesAvailability(ThisObject);
	
	DetermineNecessityForSynchronizationWithService(ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initial filling, fill checks, and availability of properties.

&AtClientAtServerNoContext
Procedure SetPropertiesAvailability(Form)
	
	Items       = Form.Items;
	Object         = Form.Object;
	FormActions = Form.FormActions;
	AccessLevel = Form.AccessLevel;
	ActionsWithSaaSUser = Form.ActionsWithSaaSUser;
	
	// Setting editing options.
	Items.CanSignIn.ReadOnly =
		Not (  Items.MainProperties.ReadOnly = False
		    AND (    AccessLevel.ChangeAuthorizationPermission
		       Or AccessLevel.DisableAuthorizationApproval AND Form.CanSignInOnRead));
	
	Items.ChangePassword.Enabled =
		(    AccessLevel.AuthorizationSettings
		 Or AccessLevel.ChangeCurrent
		   AND Not Form.InfobaseUserCannotChangePassword)
		AND Not Object.Internal;
	
	// Specifying whether filling is necessary.
	If IBUserWritingRequired(Form, False) Then
		NewPage = Items.NameWithMarkIncomplete;
	Else
		NewPage = Items.NameWithoutMarkIncomplete;
	EndIf;
	
	If Items.NameMarkIncompleteToggle.CurrentPage <> NewPage Then
		Items.NameMarkIncompleteToggle.CurrentPage = NewPage;
	EndIf;
	UpdateUsername(Form);
	
	// Setting availability of related items.
	Items.CanSignIn.Enabled    = Not Object.Invalid;
	Items.MainProperties.Enabled          = Not Object.Invalid;
	Items.ChangeRestrictionGroup.Enabled = Not Object.Invalid
	                                               AND Not Items.Description.ReadOnly;
	
	Items.OneCEnterpriseAuthenticationParameters.Enabled = Form.InfobaseUserStandardAuthentication;
	Items.InfobaseUserOSUser.Enabled         = Form.InfobaseUserOSAuthentication;
	
	// Adjusting SaaS settings.
	If ActionsWithSaaSUser <> Undefined Then
		
		// Contact information can be edited.
		Filter = New Structure("Kind", ContactInformationKindUserEmail());
		FoundRows = Form.ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		If FoundRows <> Undefined Then
			EmailFilled = ValueIsFilled(Form[FoundRows[0].AttributeName]);
		Else
			EmailFilled = False;
		EndIf;
		
		If Object.Ref.IsEmpty() AND EmailFilled Then
			CanChangePassword = False;
		Else
			CanChangePassword = ActionsWithSaaSUser.ChangePassword;
		EndIf;
		
		Items.ChangePassword.Enabled = Items.ChangePassword.Enabled AND CanChangePassword;
		
		Items.IBUserName1.ReadOnly = Items.IBUserName1.ReadOnly
			OR NOT ActionsWithSaaSUser.ChangeName;
		
		Items.IBUserName2.ReadOnly = Items.IBUserName2.ReadOnly
			OR NOT ActionsWithSaaSUser.ChangeName;
		
		Items.Description.ReadOnly = Items.Description.ReadOnly 
			OR NOT ActionsWithSaaSUser.ChangeFullName;
		
		Items.CanSignIn.Enabled = Items.CanSignIn.Enabled
			AND ActionsWithSaaSUser.ChangeAccess;
		
		Items.Invalid.Enabled = Items.Invalid.Enabled
			AND ActionsWithSaaSUser.ChangeAccess;
		
		Form.AdministrativeAccessChangeProhibition =
			NOT ActionsWithSaaSUser.ChangeAdministrativeAccess;
	EndIf;
	
	UsersInternalClientServer.UpdateLifetimeRestriction(Form);
	
EndProcedure

&AtServer
Function DetermineContactInformationItemsAvailability()
	
	Result = New Map;
	For Each ContactInformationRow In ThisObject.ContactInformationAdditionalAttributeDetails Do
		ContactInformationKindActions = ActionsWithSaaSUser.ContactInformation.Get(ContactInformationRow.Kind);
		If ContactInformationKindActions = Undefined Then
			// Service manager does not manage whether this kind of contact information can be edited.
			Continue;
		EndIf;
		ContactInformationItem = Items[ContactInformationRow.AttributeName];
		Result.Insert(ContactInformationRow.Kind,
			Not ContactInformationItem.ReadOnly
			AND ContactInformationKindActions.Update);
	EndDo;
	
	Return Result;
	
EndFunction

// The procedure that follows ChangeAuthorizationRestriction.
&AtClient
Procedure ChangeAuthorizationRestrictionCompletion(Result, Context) Export
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Function IBUserWritingRequired(Form, UseStandardName = True)
	
	If Form.FormActions.IBUserProperies <> "Edit" Then
		Return False;
	EndIf;
	
	Template = Form.InitialIBUserDetails;
	
	CurrentName = "";
	If Not UseStandardName Then
		ShortName = UsersInternalClientServer.GetIBUserShortName(
			Form.Object.Description);
		
		If Form.InfobaseUserName = ShortName Then
			CurrentName = ShortName;
		EndIf;
	EndIf;
	
	If Form.IBUserExists
	 OR Form.CanSignIn
	 OR Form.InfobaseUserName                       <> CurrentName
	 OR Form.InfobaseUserStandardAuthentication <> Template.StandardAuthentication
	 OR Form.InfobaseUserShowInList   <> Template.ShowInList
	 OR Form.InfobaseUserCannotChangePassword   <> Template.CannotChangePassword
	 OR Form.InfobaseUserPassword                    <> Undefined
	 OR Form.InfobaseUserOSAuthentication          <> Template.OSAuthentication
	 OR Form.InfobaseUserOSUser            <> ""
	 OR Form.InfobaseUserOpenIDAuthentication      <> Template.OpenIDAuthentication
	 OR Form.InfobaseUserRunMode              <> Template.RunMode
	 OR Form.InfobaseUserLanguage                      <> Template.Language
	 OR Form.InfobaseUserRoles.Count()         <> 0 Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form",            ThisObject);
	ActionParameters.Insert("RolesCollection",   InfobaseUserRoles);
	ActionParameters.Insert("AdministrativeAccessChangeProhibition",
		AdministrativeAccessChangeProhibition);
	
	ActionParameters.Insert("RolesAssignment", "ForAdministrators");
	
	AdministrativeAccessEnabled = InfobaseUserRoles.FindRows(
		New Structure("Role", "FullRights")).Count() > 0;
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
	AdministrativeAccessWasEnabled = InfobaseUserRoles.FindRows(
		New Structure("Role", "FullRights")).Count() > 0;
	
	If AdministrativeAccessWasEnabled <> AdministrativeAccessEnabled Then
		DetermineNecessityForSynchronizationWithService(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion
