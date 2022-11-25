// ------------------------------------------------------------------------------
// PARAMETER SPECIFICATION PASSED TO FORM
//
// UserAccount  - CatalogRef.EmailAccounts
//
// RETURN VALUE
//
// Undefined - user refused to enter the password.
// Structure  - 
//            key "Status", Boolean - true or false depending on the
//            success of call key "Password", string - in case if the True status
//            contains the password key "ErrorMessage" - in case if the True status
//                                       contains the message text about an error.
//
// ------------------------------------------------------------------------------
// FORM FUNCTIONING SPECIFICATION
//
//   If in the passed accounts list there is more, than
// one record, then the possibility of account selection will
// appear on the form, that will sent an email message.
//
// ------------------------------------------------------------------------------

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("CheckAbilityToSendAndReceive", CheckAbilityToSendAndReceive);
	
	If Parameters.UserAccount.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;
	
	UserAccount = Parameters.UserAccount;
	Result = ImportPassword();
	
	If ValueIsFilled(Result) Then
		Password = Result;
		PasswordConfirmation = Result;
		StorePassword = True;
	Else
		Password = "";
		PasswordConfirmation = "";
		StorePassword = False;
	EndIf;
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Items.StorePassword.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SavePasswordAndContinueExecute()
	
	If Password <> PasswordConfirmation Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Password and password confirmation do not match'; ru = 'Пароль и подтверждение пароля не совпадают';pl = 'Hasło i potwierdzenie hasła nie są identyczne';es_ES = 'Contraseña y la confirmación de la contraseña no coinciden';es_CO = 'Contraseña y la confirmación de la contraseña no coinciden';tr = 'Şifre ve şifre onayı uyumlu değil';it = 'La password e la password di conferma non coincidono.';de = 'Passwort und Passwortbestätigung stimmen nicht überein'"), , "Password");
		Return;
	EndIf;
	
	If StorePassword Then
		SavePassword(Password);
	Else
		SavePassword(Undefined);
	EndIf;
	
	If CheckAbilityToSendAndReceive Then
		NotifyDescription = New NotifyDescription("SavePasswordAndContinueToExecuteEnd", ThisObject, Password);
		EmailOperationsClientDrive.CheckCanSendReceiveEmail(NotifyDescription, UserAccount);
		Return;
	EndIf;
	
	SavePasswordAndContinueToExecuteEnd(Password);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SavePassword(Value)
	
	Common.CommonSettingsStorageSave(
		"AccountPasswordConfirmationForm",
		UserAccount,
		Value);
	
EndProcedure

&AtServer
Function ImportPassword()
	
	Return Common.CommonSettingsStorageLoad("AccountPasswordConfirmationForm", UserAccount);
	
EndFunction

&AtClient
Procedure SavePasswordAndContinueToExecuteEnd(Password) Export
	
	NotifyChoice(Password);
	
EndProcedure

#EndRegion
