
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	OnAuthorization        = Parameters.OnAuthorization;
	ReturnPasswordAndDoNotSet = Parameters.ReturnPasswordAndDoNotSet;
	OldPassword              = Parameters.OldPassword;
	
	If ReturnPasswordAndDoNotSet Or ValueIsFilled(Parameters.User) Then
		User = Parameters.User;
	Else
		User = Users.AuthorizedUser();
	EndIf;
	
	AdditionalParameters = New Structure;
	If Not ReturnPasswordAndDoNotSet Then
		AdditionalParameters.Insert("CheckUserValidity");
		AdditionalParameters.Insert("CheckIBUserExists");
	EndIf;
	If Not UsersInternal.CanChangePassword(User, AdditionalParameters) Then
		ErrorText = AdditionalParameters.ErrorText;
		Return;
	EndIf;
	IsCurrentIBUser = AdditionalParameters.IsCurrentIBUser;
	
	If Not ReturnPasswordAndDoNotSet Then
		Try
			LockDataForEdit(User, , UUID);
		Except
			ErrorInformation = ErrorInfo();
			If Not OnAuthorization Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось открыть форму смены пароля по причине:
					           |
					           |%1'; 
					           |en = 'Cannot open the password change form. Reason:
					           |
					           |%1'; 
					           |pl = 'Otwieranie formularza zmiany hasła nie powiodło się z powodu:
					           |
					           |%1';
					           |es_ES = 'No se ha podido abrir el formulario del cambio de la contraseña a causa de:
					           |
					           |%1';
					           |es_CO = 'No se ha podido abrir el formulario del cambio de la contraseña a causa de:
					           |
					           |%1';
					           |tr = 'Parola değiştirme formu açılamadı. Nedeni:
					           |
					           |%1';
					           |it = 'Non è possibile aprire il modulo di modifica password. Motivo:
					           |
					           |%1';
					           |de = 'Das Passwortänderungsformular konnte aus dem folgenden Grund nicht geöffnet werden:
					           |
					           |%1'"),
					BriefErrorDescription(ErrorInformation));
				Return;
			EndIf;
		EndTry;
	EndIf;
	
	If OnAuthorization Then
		If AdditionalParameters.PasswordIsSet Then
			FormAssignmentKey = "ChangePasswordOnAuthorization";
		Else
			FormAssignmentKey = "SetPasswordOnAuthorization";
			Items.AuthorizationNote.Title =
				NStr("ru = 'Для входа в программу нужно установить пароль.'; en = 'To sign in, set a password.'; pl = 'Aby wejść do programu, należy ustawić hasło.';es_ES = 'Para entrar en el programa hay que establecer la contraseña.';es_CO = 'Para entrar en el programa hay que establecer la contraseña.';tr = 'Uygulamaya girmek için şifre belirlenmelidir.';it = 'Per accedere, impostare una password.';de = 'Für den Zugang zum Programm muss ein Passwort festgelegt werden.'")
		EndIf;
	Else
		If Not AdditionalParameters.IsCurrentIBUser
		 Or Not AdditionalParameters.PasswordIsSet Then
			
			FormAssignmentKey = "SetPassword";
		EndIf;
		Items.AuthorizationNote.Visible = False;
		Items.FormCloseForm.Title = NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'");
	EndIf;
	
	StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, FormAssignmentKey, , False);
	
	If Not AdditionalParameters.IsCurrentIBUser
	 Or Not AdditionalParameters.PasswordIsSet Then
		
		Items.OldPassword.Visible = False;
		AutoTitle = False;
		Title = NStr("ru = 'Установка пароля'; en = 'Set password'; pl = 'Ustawianie hasła';es_ES = 'Especificar la contraseña';es_CO = 'Especificar la contraseña';tr = 'Şifre belirle';it = 'Imposta password';de = 'Passwort einstellen'");
		
	ElsIf Parameters.OldPassword <> Undefined Then
		CurrentItem = Items.NewPassword;
	EndIf;
	
	Items.NewPassword.ToolTip  = UsersInternal.NewPasswordHint();
	Items.NewPassword2.ToolTip = UsersInternal.NewPasswordHint();
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "CreatePassword", "Title", NStr("ru ='Создать'; en = 'Create'; pl = 'Utwórz';es_ES = 'Crear';es_CO = 'Crear';tr = 'Oluştur';it = 'Crea';de = 'Erstellen'"));
		CommonClientServer.SetFormItemProperty(Items, "FormCloseForm", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "CommandBarForm", "HorizontalAlign", ItemHorizontalLocation.Center);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(ErrorText) Then
		Cancel = True;
		StandardSubsystemsClient.SetFormStorage(ThisObject, True);
		AttachIdleHandler("ShowErrorTextAndNotifyAboutClosing", 0.1, True);
	Else
		CheckPasswordConformation();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PasswordOnChange(Item)
	
	CheckPasswordConformation();
	
EndProcedure

&AtClient
Procedure PasswordChangeEditedText(Item, Text, StandardProcessing)
	
	#If Not Webclient Then
		CheckPasswordConformation(Item);
	#EndIf
	
EndProcedure

&AtClient
Procedure ShowNewPasswordOnChange(Item)
	
	ShowNewPasswordOnChangeAtServer();
	CheckPasswordConformation();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreatePassword(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ForExternalUser",
		TypeOf(User) = Type("CatalogRef.ExternalUsers"));
	
	OpenForm("CommonForm.NewPassword", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SetPassword(Command)
	
	If Not ShowNewPassword AND NewPassword <> ConfirmPassword Then
		CurrentItem = Items.ConfirmPassword;
		Items.ConfirmPassword.SelectedText = Items.ConfirmPassword.EditText;
		ShowMessageBox(, NStr("ru = 'Подтверждение пароля указано некорректно.'; en = 'The passwords do not match.'; pl = 'Potwierdzenie hasła podano nieprawidłowo.';es_ES = 'La confirmación de la contraseña se ha indicado incorrectamente.';es_CO = 'La confirmación de la contraseña se ha indicado incorrectamente.';tr = 'Şifre yanlış doğrulanmış.';it = 'Le passwords non corrispondono.';de = 'Die Passwort-Bestätigung ist nicht korrekt.'"));
		Return;
	EndIf;
	
	If Not ReturnPasswordAndDoNotSet
	   AND Not IsCurrentIBUser
	   AND StandardSubsystemsClient.ClientRunParameters().DataSeparationEnabled
	   AND ServiceUserPassword = Undefined Then
		
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription("SetPasswordCompletion", ThisObject),
			ThisObject,
			ServiceUserPassword);
	Else
		SetPasswordCompletion(Null, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ShowErrorTextAndNotifyAboutClosing()
	
	StandardSubsystemsClient.SetFormStorage(ThisObject, False);
	
	ShowMessageBox(New NotifyDescription(
		"ShowErrorTextAndNotifyAboutClosingCompletion", ThisObject), ErrorText);
	
EndProcedure

&AtClient
Procedure ShowErrorTextAndNotifyAboutClosingCompletion(Context) Export
	
	If ThisObject.OnCloseNotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(ThisObject.OnCloseNotifyDescription);
		ThisObject.OnCloseNotifyDescription = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckPasswordConformation(PasswordField = Undefined)
	
	If ShowNewPassword Then
		PasswordMatches = True;
	
	ElsIf PasswordField = Items.NewPassword
	      Or PasswordField = Items.NewPassword2 Then
		
		PasswordMatches = (PasswordField.EditText = ConfirmPassword);
		
	ElsIf PasswordField = Items.ConfirmPassword Then
		PasswordMatches = (NewPassword = PasswordField.EditText);
	Else
		PasswordMatches = (NewPassword = ConfirmPassword);
	EndIf;
	
	Items.ErrorsGroup.CurrentPage = ?(PasswordMatches,
		Items.BlankPage, Items.ErrorPage);
	
EndProcedure

&AtServer
Procedure ShowNewPasswordOnChangeAtServer()
	
	Items.ConfirmPassword.Enabled = Not ShowNewPassword;
	
	Items.NewPassword.Visible  = Not ShowNewPassword;
	Items.NewPassword2.Visible =    ShowNewPassword;
	
	If ShowNewPassword Then
		ConfirmPassword = "";
	EndIf;
	
EndProcedure

// The procedure that follows SetPassword procedure.
&AtClient
Procedure SetPasswordCompletion(SaaSUserNewPassword, Context) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	If SaaSUserNewPassword <> Null Then
		ServiceUserPassword = SaaSUserNewPassword;
	EndIf;
	
	ErrorText = SetPasswordAtServer();
	If Not ValueIsFilled(ErrorText) Then
		Result = New Structure;
		If ReturnPasswordAndDoNotSet Then
			Result.Insert("NewPassword",  NewPassword);
			Result.Insert("OldPassword", ?(Items.OldPassword.Visible, OldPassword, Undefined));
		Else
			Result.Insert("BlankPasswordSet", NewPassword = "");
		EndIf;
		Close(Result);
	Else
		ShowMessageBox(, ErrorText);
	EndIf;
	
EndProcedure

&AtServer
Function SetPasswordAtServer()
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("User",              User);
	ExecutionParameters.Insert("NewPassword",               NewPassword);
	ExecutionParameters.Insert("OldPassword",              OldPassword);
	ExecutionParameters.Insert("OnAuthorization",        OnAuthorization);
	ExecutionParameters.Insert("ServiceUserPassword", ServiceUserPassword);
	ExecutionParameters.Insert("CheckOnly",           ReturnPasswordAndDoNotSet);
	
	Try
		ErrorText = UsersInternal.ProcessNewPassword(ExecutionParameters);
	Except
		ErrorInformation = ErrorInfo();
		If ExecutionParameters.Property("ErrorSavedToEventLog") Then
			ErrorText = BriefErrorDescription(ErrorInformation);
		Else
			Raise;
		EndIf;
	EndTry;
	
	If Not ValueIsFilled(ErrorText) Then
		Return "";
	EndIf;
	
	If Not ExecutionParameters.OldPasswordMatch Then
		CurrentItem = Items.OldPassword;
		OldPassword = "";
	EndIf;
	
	ServiceUserPassword = ExecutionParameters.ServiceUserPassword;
	
	Return ErrorText;
	
EndFunction

#EndRegion
