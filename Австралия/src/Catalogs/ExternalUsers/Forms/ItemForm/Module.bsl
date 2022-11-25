
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not UsersInternal.ExternalUsersEmbedded() Then
		Items.AuthorizationObject.Enabled = False;
	EndIf;
	
	// Filling auxiliary data.
	
	CannotEditRoles = UsersInternal.CannotEditRoles();
	
	// Filling the language selection list.
	If Metadata.Languages.Count() < 2 Then
		Items.InfobaseUserLanguage.Visible = False;
	Else
		For each LanguageMetadata In Metadata.Languages Do
			Items.InfobaseUserLanguage.ChoiceList.Add(
				LanguageMetadata.Name, LanguageMetadata.Synonym);
		EndDo;
	EndIf;
	
	// Preparing for execution of interactive actions according to the form opening scenarios.
	AccessLevel = UsersInternal.UserPropertiesAccessLevel(Object);
	
	SetPrivilegedMode(True);
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		// Creating an item.
		If Parameters.NewExternalUserGroup
		         <> Catalogs.ExternalUsersGroups.AllExternalUsers Then
			
			NewExternalUserGroup = Parameters.NewExternalUserGroup;
		EndIf;
		
		If ValueIsFilled(Parameters.CopyingValue) Then
			// Copying the item.
			CopyingValue = Parameters.CopyingValue;
			Object.Description      = "";
			Object.AuthorizationObject = Undefined;
			Object.DeletePassword     = "";
			
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
			If Parameters.Property("NewExternalUserAuthorizationObject") Then
				
				Object.AuthorizationObject = Parameters.NewExternalUserAuthorizationObject;
				AuthorizationObjectSetOnOpen = ValueIsFilled(Object.AuthorizationObject);
				AuthorizationObjectOnChangeAtClientAtServer(ThisObject, Object);
				
			ElsIf ValueIsFilled(NewExternalUserGroup) Then
				
				ExternalUserGroupPurpose = Common.ObjectAttributeValue(
					NewExternalUserGroup, "Purpose").Unload();
				
				SingleUserType = ExternalUserGroupPurpose.Count() = 1;
				
				If SingleUserType Then
					Object.AuthorizationObject = ExternalUserGroupPurpose[0].UsersType;
				EndIf;
				
				Items.AuthorizationObject.ChooseType = Not SingleUserType;
			EndIf;
			
			// Reading initial infobase user property values.
			ReadIBUser();
			
			If Not ValueIsFilled(Parameters.IBUserID) Then
				InfobaseUserStandardAuthentication = True;
				
				If AccessLevel.ChangeAuthorizationPermission Then
					CanSignIn = True;
					CanSignInDirectChangeValue = True;
				EndIf;
			EndIf;
		EndIf;
		
		If AccessLevel.ListManagement
		   AND Object.AuthorizationObject <> Undefined Then
			
			InfobaseUserName = UsersInternalClientServer.GetIBUserShortName(
				CurrentAuthorizationObjectPresentation);
			
			InfobaseUserFullName = Object.Description;
		EndIf;
	Else
		// Opening an existing item.
		ReadIBUser();
	EndIf;
	
	SetPrivilegedMode(False);
	
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", True);
	InitialIBUserDetails = InitialIBUserDetails();
	
	GeneralFormSetup(Object, True);
	
	If Common.IsStandaloneWorkplace() Then
		Items.HeaderGroup.ReadOnly = True;
		Items.AdditionalAttributesPage.ReadOnly = True;
		Items.CommentPage.ReadOnly = True;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	
	If Not UsersInternalCached.Settings().CommonAuthorizationSettings Then
		Items.ChangeRestrictionGroup.Visible = False;
	EndIf;
	
	Items.UserMustChangePasswordOnAuthorization.ExtendedTooltip.Title =
		UsersInternal.HintUserMustChangePasswordOnAuthorization(True);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
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
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
	GeneralFormSetup(CurrentObject);
	
	CurrentAuthorizationObjectPresentation = String(Object.AuthorizationObject);
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure ProcessRoleInterfaceSetRoleViewOnly(CurrentObject = Undefined)
	
	If CurrentObject = Undefined Then
		CurrentObject = Object;
	EndIf;
	
	ProcessRolesInterface("SetRolesReadOnly",
		    CannotEditRoles
		Or FormActions.Roles <> "Edit"
		Or Not AccessLevel.AuthorizationSettings
		Or Not CurrentObject.SetRolesDirectly);
	
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
	
	ProcessRoleInterfaceSetRoleViewOnly(CurrentObject);
	
	// Making the properties always visible.
	Items.IBUserProperies.Visible =
		ValueIsFilled(FormActions.IBUserProperies);
	
	Items.RolesRepresentation.Visible =
		ValueIsFilled(FormActions.Roles);
	
	Items.SetRolesDirectly.Visible =
		ValueIsFilled(FormActions.Roles) AND NOT UsersInternal.CannotEditRoles();
	
	UpdateDisplayedUserType();
	
	ReadOnly = ReadOnly
		OR FormActions.Roles                   <> "Edit"
		  AND FormActions.ItemProperties       <> "Edit"
		  AND FormActions.IBUserProperies <> "Edit";
	
	UsersInternalClientServer.SetWriteAndCloseButtonAvailability(ThisObject);
	
	Items.CheckAuthorizationSettingsRecommendation.Visible =
		  AccessLevel.ChangeAuthorizationPermission
		AND CurrentObject.Prepared
		AND Not CanSignInOnRead;
	
	SetPropertiesAvailability(ThisObject);
	
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
	
	If FormActions.Roles = "Edit"
	   AND Object.SetRolesDirectly
	   AND InfobaseUserRoles.Count() = 0 Then
		
		If NOT WriteParameters.Property("WithEmptyRoleList") Then
			Cancel = True;
			ShowQueryBox(
				New NotifyDescription("AfterAnswerToQuestionAboutWritingWithEmptyRoleList", ThisObject, WriteParameters),
				NStr("ru = 'Пользователю информационной базы не установлено ни одной роли. Продолжить?'; en = 'No roles are assigned to the infobase user. Do you want to continue?'; pl = 'Użytkownikowi bazy informacyjnej nie przypisano żadnej roli. Kontynuować?';es_ES = 'Usuario de la infobase no se ha asignado a ningún rol. ¿Continuar?';es_CO = 'Usuario de la infobase no se ha asignado a ningún rol. ¿Continuar?';tr = 'Veritabanın kullanıcısı için herhangi bir rol atanmadı. Devam etmek istiyor musunuz?';it = 'Nessun ruolo è stato assegnato all''utente infobase. Volete continuare?';de = 'Infobase-Benutzer wurde keine Rolle zugewiesen. Fortsetzen?'"),
				QuestionDialogMode.YesNo,
				,
				,
				NStr("ru = 'Запись пользователя информационной базы'; en = 'Save infobase user'; pl = 'Zapis użytkownika bazy informacyjnej';es_ES = 'Registro del usuario de la infobase';es_CO = 'Registro del usuario de la infobase';tr = 'Veritabanı kullanıcı kayıtları';it = 'Salva utente infobase';de = 'Infobase-Benutzerdatensatz'"));
			Return;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.AdditionalProperties.Insert("CopyingValue", CopyingValue);
	
	UpdateDisplayedUserType();
	// Auto updating external user description.
	SetPrivilegedMode(True);
	CurrentAuthorizationObjectPresentation = String(CurrentObject.AuthorizationObject);
	SetPrivilegedMode(False);
	Object.Description        = CurrentAuthorizationObjectPresentation;
	CurrentObject.Description = CurrentAuthorizationObjectPresentation;
	
	If IBUserWritingRequired(ThisObject) Then
		
		IBUserDetails = IBUserDetails();
		
		If ValueIsFilled(Object.IBUserID) Then
			IBUserDetails.Insert("UUID", Object.IBUserID);
		EndIf;
		IBUserDetails.Insert("Action", "Write");
		
		CurrentObject.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
	EndIf;
	
	If FormActions.ItemProperties <> "Edit" Then
		FillPropertyValues(CurrentObject, Common.ObjectAttributesValues(
			CurrentObject.Ref, "DeletionMark"));
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert(
		"NewExternalUserGroup", NewExternalUserGroup);
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	SetPrivilegedMode(True);
	UsersInternal.WriteUserInfo(ThisObject, CurrentObject);
	
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
	
	If IBUserWritingRequired(ThisObject) Then
		WriteParameters.Insert(
			CurrentObject.AdditionalProperties.IBUserDetails.ActionResult);
	EndIf;
	
	GeneralFormSetup(CurrentObject, , WriteParameters);
	
	UsersInternal.AfterChangeUserOrUserGroupInForm();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ExternalUsers", New Structure, Object.Ref);
	NotifyChanged(Object.AuthorizationObject);
	
	If WriteParameters.Property("IBUserAdded") Then
		Notify("IBUserAdded", WriteParameters.IBUserAdded, ThisObject);
		
	ElsIf WriteParameters.Property("IBUserChanged") Then
		Notify("IBUserChanged", WriteParameters.IBUserChanged, ThisObject);
		
	ElsIf WriteParameters.Property("IBUserDeleted") Then
		Notify("IBUserDeleted", WriteParameters.IBUserDeleted, ThisObject);
		
	ElsIf WriteParameters.Property("MappingToNonExistingIBUserCleared") Then
		
		Notify(
			"MappingToNonExistingIBUserCleared",
			WriteParameters.MappingToNonExistingIBUserCleared, ThisObject);
	EndIf;
	
	If ValueIsFilled(NewExternalUserGroup) Then
		NotifyChanged(NewExternalUserGroup);
		
		Notify(
			"Write_ExternalUserGroups",
			New Structure,
			NewExternalUserGroup);
		
		NewExternalUserGroup = Undefined;
	EndIf;
	
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
	If WriteParameters.Property("WriteAndClose") Then
		AttachIdleHandler("CloseForm", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	ErrorText = "";
	If UsersInternal.AuthorizationObjectIsInUse(
	         Object.AuthorizationObject, Object.Ref, , , ErrorText) Then
		
		CommonClientServer.MessageToUser(
			ErrorText, , "Object.AuthorizationObject", , Cancel);
	EndIf;
	
	If CanSignIn
	   AND ValueIsFilled(ValidityPeriod)
	   AND ValidityPeriod <= BegOfDay(CurrentSessionDate()) Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Ограничение должно быть до завтра или более.'; en = 'The password expiration date must be tomorrow or later.'; pl = 'Data ważności hasła musi być jutro lub później.';es_ES = 'La restricción debe ser hasta mañana o más.';es_CO = 'La restricción debe ser hasta mañana o más.';tr = 'Kısıtlama yarına kadar veya daha fazla olmalıdır.';it = 'La data di scadenza della password deve essere domani o in seguito.';de = 'Das Passwort soll bis morgen oder später gelten.'"),, "CanSignIn",, Cancel);
	EndIf;
	
	If IBUserWritingRequired(ThisObject) Then
		IBUserDetails = IBUserDetails();
		IBUserDetails.Insert("IBUserID", Object.IBUserID);
		UsersInternal.CheckIBUserDetails(IBUserDetails, Cancel);
		
		MessageText = "";
		If UsersInternal.CreateFirstAdministratorRequired(Undefined, MessageText) Then
			CommonClientServer.MessageToUser(
				MessageText, , "CanSignIn", , Cancel);
		EndIf;
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
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" в строке %%1 не найдена в метаданных.'; en = 'Role ""%1"" in line #%%1 is not found in the metadata.'; pl = 'Rola ""%1"" w wierszu %%1 nie została znaleziona w metadanych.';es_ES = 'El rol ""%1"" en la línea %%1 no se ha encontrado en los metadatos.';es_CO = 'El rol ""%1"" en la línea %%1 no se ha encontrado en los metadatos.';tr = '%%1 Satırdaki rol %1 meta veride bulunamadı.';it = 'Il ruolo ""%1"" nella linea #%%1 non è stato trovato nei metadati.';de = 'Die Rolle ""%1"" in der %%1-Zeile wurde in den Metadaten nicht gefunden.'"), Row.Synonym));
			EndIf;
			If Row.IsUnavailableRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" недоступна для внешних пользователей.'; en = 'Role ""%1"" is unavailable to external users.'; pl = 'Rola ""%1"" nie jest dostępna dla użytkowników zewnętrznych.';es_ES = 'El rol ""%1"" no está disponible para los usuarios externos.';es_CO = 'El rol ""%1"" no está disponible para los usuarios externos.';tr = '""%1"" rolü harici kullanıcılar için kullanılamaz.';it = 'Il ruolo""%1"" non è disponibile per gli utenti esterni.';de = 'Die Rolle ""%1"" ist für externe Benutzer nicht verfügbar.'"), Row.Synonym),
					"Roles",
					TreeItems.IndexOf(Row),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" в строке %%1 недоступна для внешних пользователей.'; en = 'Role ""%1"" in line #%%1 is unavailable to external users.'; pl = 'Rola ""%1"" w wierszu %%1 nie jest dostępna dla użytkowników zewnętrznych.';es_ES = 'El rol ""%1"" en la línea %%1 no está disponible para los usuarios externos.';es_CO = 'El rol ""%1"" en la línea %%1 no está disponible para los usuarios externos.';tr = '%%1 satırındaki rol ""%1"" harici kullanıcılar için kullanılamaz.';it = 'Il ruolo ""%1"" nella linea #%%1 non è disponibile per gli utenti esterni.';de = 'Die Rolle ""%1"" in der Zeile %%1 ist für externe Benutzer nicht verfügbar.'"), Row.Synonym));
			EndIf;
		EndDo;
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AuthorizationObjectOnChange(Item)
	
	AuthorizationObjectOnChangeAtClientAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure InvalidOnChange(Item)
	
	If Object.Invalid Then
		CanSignIn = False;
	Else
		CanSignIn = CanSignInDirectChangeValue
			AND (InfobaseUserOpenIDAuthentication
			   Or InfobaseUserStandardAuthentication);
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure CanSignInOnChange(Item)
	
	If Object.DeletionMark AND CanSignIn Then
		CanSignIn = False;
		ShowMessageBox(,
			NStr("ru = 'Чтобы разрешить вход в программу, требуется снять
			           |пометку на удаление с этого внешнего пользователя.'; 
			           |en = 'To allow signing in to the application, clear the 
			           | deletion mark from the external user.'; 
			           |pl = 'Aby umożliwić logowanie, oczyść znacznik
			           |usunięcia dla użytkownika zewnętrznego.';
			           |es_ES = 'Para permitir el inicio de la sesión, se requiere quitar
			           |la marca de borrar para el usuario externo.';
			           |es_CO = 'Para permitir el inicio de la sesión, se requiere quitar
			           |la marca de borrar para el usuario externo.';
			           |tr = 'Uygulamaya girebilmek için, harici kullanıcının silinme işareti 
			           |kaldırılmalıdır.';
			           |it = 'Per permettere di accedere all''applicazione, rimuovere il
			           |contrassegno di eliminazione dell''utente esterno.';
			           |de = 'Um sich am Programm anmelden zu können, entfernen Sie die
			           |Löschmarkierung dieses externen Benutzers.'"));
		Return;
	EndIf;
	
	UpdateUsername(ThisObject);
	
	If CanSignIn
	   AND NOT InfobaseUserOpenIDAuthentication
	   AND NOT InfobaseUserStandardAuthentication Then
	
		InfobaseUserStandardAuthentication = True;
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	
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
Procedure IBUserLanguageOnChange(Item)
	
	SetPropertiesAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure SetRolesDirectlyOnChange(Item)
	
	If Not Object.SetRolesDirectly Then
		ReadIBUserRoles();
		UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	EndIf;
	
	SetPropertiesAvailability(ThisObject);
	ProcessRoleInterfaceSetRoleViewOnly();
	
EndProcedure

&AtClient
Procedure MainAndCommentPagesOnCurrentPageChange(Item, CurrentPage)
	
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
	FormParameters = New Structure;
	FormParameters.Insert("ShowExternalUsersSettings", True);
	
	OpenForm("CommonForm.UserAuthorizationSettings", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region RolesFormTableItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	If Items.Roles.CurrentData <> Undefined Then
		ProcessRolesInterface("UpdateRoleComposition");
	EndIf;
	
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

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure UpdateUsername(Form, DescriptionOnChange = False)
	
	Items = Form.Items;
	Object   = Form.Object;
	
	If Form.IBUserExists Then
		Return;
	EndIf;
	
	ShortName = UsersInternalClientServer.GetIBUserShortName(
		Form.CurrentAuthorizationObjectPresentation);
	
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
	   AND NOT InfobaseUserStandardAuthentication Then
	
		CanSignIn = False;
		
	ElsIf Not CanSignIn Then
		CanSignIn = CanSignInDirectChangeValue;
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
	FormActions.Insert("IBUserProperies", "");
	
	// "", "View," "Edit."
	FormActions.Insert("ItemProperties", "View");
	
	If AccessLevel.ChangeCurrent Or AccessLevel.ListManagement Then
		FormActions.IBUserProperies = "Edit";
	EndIf;
	
	If AccessLevel.ListManagement Then
		FormActions.ItemProperties = "Edit";
	EndIf;
	
	If AccessLevel.FullRights Then
		FormActions.Roles = "Edit";
	EndIf;
	
	If NOT ValueIsFilled(Object.Ref)
	   AND NOT ValueIsFilled(Object.AuthorizationObject) Then
		
		FormActions.ItemProperties = "Edit";
	EndIf;
	
	UsersInternal.OnDefineActionsInForm(Object.Ref, FormActions);
	
	// Checking action names in the form.
	If StrFind(", View, Edit,", ", " + FormActions.Roles + ",") = 0 Then
		FormActions.Roles = "";
		
	ElsIf FormActions.Roles = "Edit"
	        AND UsersInternal.CannotEditRoles() Then
		
		FormActions.Roles = "View";
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
	
EndProcedure

&AtServer
Function IBUserDetails()
	
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
			Result.Insert("CannotChangePassword", InfobaseUserCannotChangePassword);
			Result.Insert("Language",                    InfobaseUserLanguage);
			Result.Insert("FullName",               InfobaseUserFullName);
		EndIf;
		
		If AccessLevel.AuthorizationSettings Then
			Result.Insert("StandardAuthentication", InfobaseUserStandardAuthentication);
			Result.Insert("Password",                    InfobaseUserPassword);
			Result.Insert("Name",                       InfobaseUserName);
			Result.Insert("OpenIDAuthentication",      InfobaseUserOpenIDAuthentication);
		EndIf;
	EndIf;
	
	If AccessLevel.AuthorizationSettings
	   AND Not UsersInternal.CannotEditRoles()
	   AND Object.SetRolesDirectly Then
		
		CurrentRoles = InfobaseUserRoles.Unload(, "Role").UnloadColumn("Role");
		Result.Insert("Roles", CurrentRoles);
	EndIf;
	
	If AccessLevel.ListManagement Then
		Result.Insert("ShowInList", False);
		Result.Insert("RunMode", "Auto");
	EndIf;
	
	If AccessLevel.FullRights Then
		Result.Insert("OSAuthentication", False);
		Result.Insert("OSUser", "");
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Procedure AuthorizationObjectOnChangeAtClientAtServer(Form, Object)
	
	If Object.AuthorizationObject = Undefined Then
		Object.AuthorizationObject = Form.AuthorizationObjectsType;
	EndIf;
	
	If Form.CurrentAuthorizationObjectPresentation <> String(Object.AuthorizationObject) Then
		Form.CurrentAuthorizationObjectPresentation = String(Object.AuthorizationObject);
		UpdateUsername(Form, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateDisplayedUserType()
	
	If Common.IsReference(TypeOf(Object.AuthorizationObject)) Then
		Items.AuthorizationObject.Title = Metadata.FindByType(TypeOf(Object.AuthorizationObject)).ObjectPresentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutWritingWithEmptyRoleList(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("WithEmptyRoleList");
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
Procedure ReadIBUserRoles()
	
	IBUserProperies = Users.IBUserProperies(Object.IBUserID);
	If IBUserProperies = Undefined Then
		IBUserProperies = Users.NewIBUserDetails();
	EndIf;	
	ProcessRolesInterface("FillRoles", IBUserProperies.Roles);
	
EndProcedure

&AtServer
Function InitialIBUserDetails()
	
	If InitialIBUserDetails <> Undefined Then
		InitialIBUserDetails.Roles = New Array;
		Return InitialIBUserDetails;
	EndIf;
	
	IBUserDetails = Users.NewIBUserDetails();
	IBUserDetails.ShowInList = False;
	IBUserDetails.StandardAuthentication = True;
	IBUserDetails.Roles = New Array;
	
	Return IBUserDetails;
	
EndFunction

&AtServer
Procedure ReadIBUser(OnCopyItem = False)
	
	SetPrivilegedMode(True);
	
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
					ReadProperties.FullName = Object.Description;
					Modified = True;
				EndIf;
				If ReadProperties.OSAuthentication Then
					ReadProperties.OSAuthentication = False;
					Modified = True;
				EndIf;
				If ValueIsFilled(ReadProperties.OSUser) Then
					ReadProperties.OSUser = "";
					Modified = True;
				EndIf;
			EndIf;
		EndIf;
		
		If IBUserExists Then
			
			If Not Items.InfobaseUserLanguage.Visible Then
				ReadProperties.Language = IBUserDetails.Language;
			EndIf;
			
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
		|Roles",
		"InfobaseUser");
	
	If IBUserMain AND Not CanSignIn Then
		StoredProperties = UsersInternal.StoredIBUserProperties(Object.Ref);
		InfobaseUserOpenIDAuthentication      = StoredProperties.OpenIDAuthentication;
		InfobaseUserStandardAuthentication = StoredProperties.StandardAuthentication;
	EndIf;
	
	ProcessRolesInterface("FillRoles", IBUserDetails.Roles);
	
	CanSignInOnRead = CanSignIn;
	
EndProcedure

&AtServer
Procedure FindUserAndIBUserDifferences(WriteParameters = Undefined)
	
	// Checking whether the FullName infobase user property matches the Description external user 
	// attribute. Also checking the default property values.
	
	ShowDifference = True;
	ShowDifferenceResolvingCommands = False;
	
	If NOT IBUserExists Then
		ShowDifference = False;
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		InfobaseUserFullName = Object.Description;
		ShowDifference = False;
		
	ElsIf AccessLevel.ListManagement Then
		
		PropertiesToResolve = New Array;
		HasDifferencesResolvableWithoutAdministrator = False;
		
		If InfobaseUserOSAuthentication <> False Then
			PropertiesToResolve.Add(NStr("ru = 'Аутентификация ОС (включена)'; en = 'OS authentication (enabled)'; pl = 'Autoryzacja przez system operacyjny (włączone)';es_ES = 'Autenticación del sistema operativo (activado)';es_CO = 'Autenticación del sistema operativo (activado)';tr = 'OS kimlik doğrulama (açık)';it = 'Autenticazione OS (permessa)';de = 'Betriebssystemauthentifizierung (aktiviert)'"));
		EndIf;
		
		If ValueIsFilled(PropertiesToResolve) Then
			ShowDifferenceResolvingCommands =
				  AccessLevel.AuthorizationSettings
				AND FormActions.IBUserProperies = "Edit";
		EndIf;
		
		If InfobaseUserFullName <> Object.Description Then
			HasDifferencesResolvableWithoutAdministrator = True;
			
			PropertiesToResolve.Insert(0, StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Полное имя ""%1""'; en = 'Full name: ""%1""'; pl = 'Imię i nazwisko ""%1""';es_ES = 'Nombre completo ""%1""';es_CO = 'Nombre completo ""%1""';tr = 'Tam isim ""%1""';it = 'Nome completo: ""%1""';de = 'Vollständiger Name ""%1""'"),
				InfobaseUserFullName));
		EndIf;
		
		If InfobaseUserOSUser <> "" Then
			PropertiesToResolve.Add(NStr("ru = 'Пользователь ОС (указан)'; en = 'OS user (specified)'; pl = 'Użytkownik systemu operacyjnego (określony)';es_ES = 'Usuario del sistema operativo (especificado)';es_CO = 'Usuario del sistema operativo (especificado)';tr = 'OS kullanıcı (belirlenmiş)';it = 'Utente OS (specificare)';de = 'Betriebssystembenutzer (angegeben)'"));
		EndIf;
		
		If InfobaseUserShowInList Then
			HasDifferencesResolvableWithoutAdministrator = True;
			PropertiesToResolve.Add(NStr("ru = 'Показывать в списке выбора (включено)'; en = 'Show in selection list (enabled)'; pl = 'Pokazywać w liście wyboru (włączone)';es_ES = 'Mostrar en la lista de selección (activado)';es_CO = 'Mostrar en la lista de selección (activado)';tr = 'Seçim listesinde göster (açık)';it = 'Mostrare nell''elenco di selezione (abilitato)';de = 'In der Auswahlliste anzeigen (aktiviert)'"));
		EndIf;
		
		If InfobaseUserRunMode <> "Auto" Then
			HasDifferencesResolvableWithoutAdministrator = True;
			PropertiesToResolve.Add(NStr("ru = 'Режим запуска (не Авто)'; en = 'Run mode (not Auto)'; pl = 'Tryb uruchamiania (nie Auto)';es_ES = 'Empezar el modo (no Auto)';es_CO = 'Empezar el modo (no Auto)';tr = 'Başlatma modu (Oto değil)';it = 'Modalità di avvio (non Auto)';de = 'Startmodus (nicht Auto)'"));
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
			If ShowDifferenceResolvingCommands
			 Or HasDifferencesResolvableWithoutAdministrator
			   AND FormActions.ItemProperties = "Edit" Then
				
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
	
	Items.PropertiesMismatchProcessing.Visible = ShowDifference;
	Items.PropertiesMismatchNote.VerticalAlign = ?(ValueIsFilled(Recommendation),
		ItemVerticalAlign.Top, ItemVerticalAlign.Center);
	
	// Checking the mapping of a nonexistent infobase user to a catalog user.
	HasNewMappingToNonExistingIBUser =
		NOT IBUserExists AND ValueIsFilled(Object.IBUserID);
	
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
		NStr("ru = 'Пользователь информационной базы не найден.'; en = 'The infobase user is not found.'; pl = 'Użytkownik bazy informacyjnej nie został znaleziony.';es_ES = 'Usuario de la infobase no encontrado.';es_CO = 'Usuario de la infobase no encontrado.';tr = 'Infobase kullanıcısı bulunamadı.';it = 'L''utente infobase non è stato trovato.';de = 'Der Benutzer der Informationsbasis wurde nicht gefunden.'") + Recommendation;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initial filling, fill checks, and availability of properties.

&AtClientAtServerNoContext
Procedure SetPropertiesAvailability(Form)
	
	Items       = Form.Items;
	Object         = Form.Object;
	FormActions = Form.FormActions;
	AccessLevel = Form.AccessLevel;
	
	// Setting editing options.
	Items.AuthorizationObject.ReadOnly
		=   FormActions.ItemProperties <> "Edit"
		Or Form.AuthorizationObjectSetOnOpen
		Or   ValueIsFilled(Object.Ref)
		    AND ValueIsFilled(Object.AuthorizationObject);
	
	Items.Invalid.ReadOnly =
		Not (FormActions.ItemProperties = "Edit" AND AccessLevel.ListManagement);
	
	Items.MainProperties.ReadOnly =
		Not (  FormActions.IBUserProperies = "Edit"
		    AND (AccessLevel.ListManagement Or AccessLevel.ChangeCurrent));
	
	Items.CanSignIn.ReadOnly =
		Not (  Items.MainProperties.ReadOnly = False
		    AND (    AccessLevel.ChangeAuthorizationPermission
		       Or AccessLevel.DisableAuthorizationApproval AND Form.CanSignInOnRead));
	
	Items.IBUserName1.ReadOnly                      = Not AccessLevel.AuthorizationSettings;
	Items.IBUserName2.ReadOnly                      = Not AccessLevel.AuthorizationSettings;
	Items.InfobaseUserStandardAuthentication.ReadOnly = Not AccessLevel.AuthorizationSettings;
	Items.InfobaseUserOpenIDAuthentication.ReadOnly      = Not AccessLevel.AuthorizationSettings;
	Items.SetRolesDirectly.ReadOnly           = Not AccessLevel.AuthorizationSettings;
	
	Items.UserMustChangePasswordOnAuthorization.ReadOnly        = Not AccessLevel.ListManagement;
	Items.InfobaseUserCannotChangePassword.ReadOnly = Not AccessLevel.ListManagement;
	
	Items.ChangePassword.Enabled =
		(    AccessLevel.AuthorizationSettings
		 Or AccessLevel.ChangeCurrent
		   AND Not Form.InfobaseUserCannotChangePassword);
	
	Items.Comment.ReadOnly =
		Not (FormActions.ItemProperties = "Edit" AND AccessLevel.ListManagement);
	
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
	Items.CanSignIn.Enabled         = Not Object.Invalid;
	Items.MainProperties.Enabled               = Not Object.Invalid;
	Items.EditOrViewRoles.Enabled = Not Object.Invalid;
	Items.ChangeRestrictionGroup.Enabled      = Not Object.Invalid
	                                                    AND Not Items.Invalid.ReadOnly;
	
	Items.OneCEnterpriseAuthenticationParameters.Enabled =
		Form.InfobaseUserStandardAuthentication;
	
	UsersInternalClientServer.UpdateLifetimeRestriction(Form);
	
EndProcedure

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
			Form.CurrentAuthorizationObjectPresentation);
		
		If Form.InfobaseUserName = ShortName Then
			CurrentName = ShortName;
		EndIf;
	EndIf;
	
	If Form.IBUserExists
	 OR Form.CanSignIn
	 OR Form.InfobaseUserName                       <> CurrentName
	 OR Form.InfobaseUserStandardAuthentication <> Template.StandardAuthentication
	 OR Form.InfobaseUserCannotChangePassword   <> Template.CannotChangePassword
	 OR Form.InfobaseUserPassword                    <> Undefined
	 OR Form.InfobaseUserOpenIDAuthentication      <> Template.OpenIDAuthentication
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
	ActionParameters.Insert("RolesAssignment",  "ForExternalUsers");
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

#EndRegion
