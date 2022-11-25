#Region Variables

&AtClient
Var PermissionsReceived;

&AtClient
Var FillCheckingWriteParameters;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.LockOwner Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	CanReceiveEmails = EmailOperationsInternal.SubsystemSettings().CanReceiveEmails;
	Items.UseAccount.ShowTitle = CanReceiveEmails;
	Items.ForReceiving.Visible = CanReceiveEmails;
	Items.KeepMessagesOnServer.Visible = CanReceiveEmails;
	If Not CanReceiveEmails Then
		Items.ForSending.Title = NStr("ru = 'Использовать для отправки писем'; en = 'Use to send emails'; pl = 'Używaj do wysyłania wiadomości';es_ES = 'Usar para enviar el correo';es_CO = 'Usar para enviar el correo';tr = 'E-posta göndermek için kullan';it = 'Utilizzare per l''invio email';de = 'Verwendung zum Versenden von E-Mails'");
	EndIf;
	Items.Receiving.Enabled = CanReceiveEmails Or Object.SignInBeforeSendingRequired;
	Items.Protocol.Enabled = CanReceiveEmails;
	
	If Object.Ref.IsEmpty() Then
		Object.UseForSending = True;
		Object.UseForReceiving = CanReceiveEmails;
	EndIf;
	
	DeleteMailFromServer = Object.KeepMailAtServerPeriod > 0;
	If Not DeleteMailFromServer Then
		Object.KeepMailAtServerPeriod = 10;
	EndIf;
	
	If NOT Object.Ref.IsEmpty() Then
		SetPrivilegedMode(True);
		Passwords = Common.ReadDataFromSecureStorage(Object.Ref, "Password, SMTPPassword");
		SetPrivilegedMode(False);
		Password = ?(ValueIsFilled(Passwords.Password), ThisObject.UUID, "");
		SMTPPassword = ?(ValueIsFilled(Passwords.SMTPPassword), ThisObject.UUID, "");
	EndIf;
	
	Items.FormWriteAndClose.Enabled = Not ReadOnly;
	
	ThisIsPersonalAccount = ValueIsFilled(Object.AccountOwner);
	Items.AccountUser.Enabled = ThisIsPersonalAccount;
	UserAccountKind = ?(ThisIsPersonalAccount, "SingleUser", "AllUsers");
	Items.AccountAvailabilityGroup.Enabled = Users.IsFullUser();
	AccountOwner = Object.AccountOwner;
	
	AuthorizationRequiredOnSendMail = ValueIsFilled(Object.SMTPUser);
	Items.AuthorizationOnSendMail.Enabled = AuthorizationRequiredOnSendMail;
	
	EncryptOnSendMail = ?(Object.UseSecureConnectionForOutgoingMail, "SSL", "Auto");
	EncryptOnReceiveMail = ?(Object.UseSecureConnectionForIncomingMail, "SSL", "Auto");
	
	AuthorizationMethodOnSendMail = ?(Object.SignInBeforeSendingRequired, "POP", "SMTP");
	
	AttributesRequiringPasswordToChange = Catalogs.EmailAccounts.AttributesRequiringPasswordToChange();
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	If PasswordChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Password);
		SetPrivilegedMode(False);
	EndIf;
	
	If SMTPPasswordChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, SMTPPassword, "SMTPPassword");
		SetPrivilegedMode(False);
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If UserAccountKind = "SingleUser" AND Not ValueIsFilled(Object.AccountOwner) Then 
		Cancel = True;
		MessageText = NStr("ru = 'Не выбран владелец учетной записи.'; en = 'Account owner is not selected.'; pl = 'Nie wybrano właściciela konta.';es_ES = 'No se ha seleccionado el propietario de la cuenta.';es_CO = 'No se ha seleccionado el propietario de la cuenta.';tr = 'Hesap sahibi seçilmedi.';it = 'Il proprietario dell''account non è selezionato';de = 'Der Kontoinhaber ist nicht ausgewählt.'");
		CommonClientServer.MessageToUser(MessageText, , "Object.AccountOwner");
	EndIf;
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	CurrentObject.AdditionalProperties.Insert("Password", PasswordCheck);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	NotifyDescription = New NotifyDescription("BeforeCloseConfirmationReceived", ThisObject);
	CommonClient.ShowFormClosingConfirmation(NotifyDescription, Cancel, Exit);
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not DeleteMailFromServer Then
		Object.KeepMailAtServerPeriod = 0;
	EndIf;
	
	If Object.ProtocolForIncomingMail = "IMAP" Then
		Object.KeepMessageCopiesAtServer = True;
		Object.KeepMailAtServerPeriod = 0;
	EndIf;
	
	If Not FillingCheckExecuted(WriteParameters) Then
		Cancel = True;
		Return;
	EndIf;
	
	If PermissionsReceived <> True Then
		ClosingNotification = New NotifyDescription("GetPermitsEnd", ThisObject, WriteParameters);
		
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			ObjectData = New Structure("Ref,UseForSending,OutgoingMailServer,OutgoingMailServerPort,UseForReceiving,
				|ProtocolForIncomingMail,IncomingMailServer,IncomingMailServerPort");
			FillPropertyValues(ObjectData, Object);
			Query = CreateRequestToUseExternalResources(ObjectData);
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(
				CommonClientServer.ValueInArray(Query), ThisObject, ClosingNotification);
		Else
			ExecuteNotifyProcessing(ClosingNotification, DialogReturnCode.OK);
		EndIf;
		
		Cancel = True;
		Return;
	EndIf;
	
	If UserAccountKind = "AllUsers" AND ValueIsFilled(Object.AccountOwner) Then
		Object.AccountOwner = Undefined;
	EndIf;
	
	AttributeValuesBeforeWrite = New Structure(AttributesRequiringPasswordToChange);
	FillPropertyValues(AttributeValuesBeforeWrite, Object);
	
	PasswordCheckIsRequired = PasswordCheckIsRequired(Object.Ref, AttributeValuesBeforeWrite);
	
	If Not WriteParameters.Property("PasswordEntered") AND PasswordCheckIsRequired Then
		Cancel = True;
		PromptForPassword(WriteParameters);
		Return;
	EndIf;
	
	PermissionsReceived = False;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_EmailAccount",,Object.Ref);
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
	AccountOwner = Object.AccountOwner;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetItemsEnabled();
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProtocolOnChange(Item)
	
	If Object.ProtocolForIncomingMail = "IMAP" Then
		If StrStartsWith(Object.IncomingMailServer, "pop.") Then
			Object.IncomingMailServer = "imap." + Mid(Object.IncomingMailServer, 5);
		EndIf
	Else
		If IsBlankString(Object.ProtocolForIncomingMail) Then
			Object.ProtocolForIncomingMail = "POP";
		EndIf;
		If StrStartsWith(Object.IncomingMailServer, "imap.") Then
			Object.IncomingMailServer = "pop." + Mid(Object.IncomingMailServer, 6);
		EndIf;
	EndIf;
	
	ConnectIncomingMailPort();
	SetItemsEnabled();
EndProcedure

&AtClient
Procedure IncomingMailServerOnChange(Item)
	Object.IncomingMailServer = TrimAll(Lower(Object.IncomingMailServer));
EndProcedure

&AtClient
Procedure OutgoingMailServerOnChange(Item)
	Object.OutgoingMailServer = TrimAll(Lower(Object.OutgoingMailServer));
EndProcedure

&AtClient
Procedure EmailAddressOnChange(Item)
	Object.EmailAddress = TrimAll(Object.EmailAddress);
EndProcedure

&AtClient
Procedure KeepEmailCopiesOnServerOnChange(Item)
	SetItemsEnabled();
EndProcedure

&AtClient
Procedure DeleteEmailsFromServerOnChange(Item)
	SetItemsEnabled();
EndProcedure

&AtClient
Procedure PasswordForReceivingEmailsOnChange(Item)
	PasswordChanged = True;
EndProcedure

&AtClient
Procedure PasswordForSendingEmailsOnChange(Item)
	SMTPPasswordChanged = True;
EndProcedure

&AtClient
Procedure AccountOwnerOnChange(Item)
	Items.AccountUser.Enabled = UserAccountKind = "SingleUser";
	NotifyOfChangesAccountOwner();
EndProcedure

&AtClient
Procedure AccountUserOnChange(Item)
	NotifyOfChangesAccountOwner();
EndProcedure

&AtClient
Procedure AuthorizationRequiredBeforeSendingOnChange(Item)
	Items.Receiving.Enabled = CanReceiveEmails Or Object.SignInBeforeSendingRequired;
EndProcedure

&AtClient
Procedure AuthorizationRequiredOnSendingEmailsOnChange(Item)
	Items.AuthorizationOnSendMail.Enabled = AuthorizationRequiredOnSendMail;
EndProcedure

&AtClient
Procedure EncryptOnSendingEmailsOnChange(Item)
	Object.UseSecureConnectionForOutgoingMail = EncryptOnSendMail = "SSL";
	ConnectOutgoingMailPort();
EndProcedure

&AtClient
Procedure EncryptOnReceivingEmailsOnChange(Item)
	Object.UseSecureConnectionForIncomingMail = EncryptOnReceiveMail = "SSL";
	ConnectIncomingMailPort();
EndProcedure

&AtClient
Procedure AuthorizationMethodForSendingEmailOnChange(Item)
	Object.SignInBeforeSendingRequired = ?(AuthorizationMethodOnSendMail = "POP", True, False);
	Items.UsernameAndPasswordOnSendMail.Enabled = Not Object.SignInBeforeSendingRequired;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ConnectIncomingMailPort()
	If Object.ProtocolForIncomingMail = "IMAP" Then
		If Object.UseSecureConnectionForIncomingMail Then
			Object.IncomingMailServerPort = 993;
		Else
			Object.IncomingMailServerPort = 143;
		EndIf;
	Else
		If Object.UseSecureConnectionForIncomingMail Then
			Object.IncomingMailServerPort = 995;
		Else
			Object.IncomingMailServerPort = 110;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ConnectOutgoingMailPort()
	If Object.UseSecureConnectionForOutgoingMail Then
		Object.OutgoingMailServerPort = 465;
	Else
		Object.OutgoingMailServerPort = 25;
	EndIf;
EndProcedure

&AtClient
Procedure BeforeCloseConfirmationReceived(QuestionResult, AdditionalParameters) Export
	Write(New Structure("WriteAndClose"));
EndProcedure

&AtClient
Procedure SetItemsEnabled()
	POPIsUsed = Object.ProtocolForIncomingMail = "POP";
	Items.POPBeforeSMTP.Visible = POPIsUsed;
	Items.KeepMessagesOnServer.Visible = POPIsUsed AND CanReceiveEmails;
	
	Items.MailRetentionPeriodSetting.Enabled = Object.KeepMessageCopiesAtServer;
	Items.KeepMailAtServerPeriod.Enabled = DeleteMailFromServer;
EndProcedure

&AtClient
Procedure GetPermitsEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		PermissionsReceived = True;
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateRequestToUseExternalResources(Object)
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	Return ModuleSafeModeManager.RequestToUseExternalResources(
		Permissions(Object), Object.Ref);
	
EndFunction

&AtServerNoContext
Function Permissions(Object)
	
	Result = New Array;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	If Object.UseForSending Then
		Result.Add(
			ModuleSafeModeManager.PermissionToUseInternetResource(
				"SMTP",
				Object.OutgoingMailServer,
				Object.OutgoingMailServerPort,
				NStr("ru = 'Электронная почта.'; en = 'Email.'; pl = 'E-mail.';es_ES = 'Correo electrónico.';es_CO = 'Correo electrónico.';tr = 'E-posta.';it = 'E-mail.';de = 'E-Mail.'")));
	EndIf;
	
	If Object.UseForReceiving Then
		Result.Add(
			ModuleSafeModeManager.PermissionToUseInternetResource(
				Object.ProtocolForIncomingMail,
				Object.IncomingMailServer,
				Object.IncomingMailServerPort,
				NStr("ru = 'Электронная почта.'; en = 'Email.'; pl = 'E-mail.';es_ES = 'Correo electrónico.';es_CO = 'Correo electrónico.';tr = 'E-posta.';it = 'E-mail.';de = 'E-Mail.'")));
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure PromptForPassword(WriteParameters)
	PasswordCheck = "";
	NotifyDescription = New NotifyDescription("AfterPasswordEnter", ThisObject, WriteParameters);
	OpenForm("Catalog.EmailAccounts.Form.CheckAccountAccess", ,
		ThisObject, , , , NotifyDescription);
EndProcedure

&AtClient
Procedure AfterPasswordEnter(Password, WriteParameters) Export
	If TypeOf(Password) = Type("String") Then
		WriteParameters.Insert("PasswordEntered");
		PasswordCheck = Password;
		Write(WriteParameters);
	EndIf;
EndProcedure

&AtClient
Procedure NotifyOfChangesAccountOwner()
	Notify("OnChangeEmailAccountKind", UserAccountKind = "SingleUser", ThisObject);
EndProcedure

&AtClient
Function FillingCheckExecuted(WriteParameters)
	If WriteParameters.Property("FillingCheckExecuted") Then
		Return True;
	EndIf;
	
	FillCheckingWriteParameters = WriteParameters;
	AttachIdleHandler("CheckFillingAndWrite", 0.1, True);
	
	Return False;
EndFunction

&AtClient
Procedure CheckFillingAndWrite()
	If CheckFilling() Then
		FillCheckingWriteParameters.Insert("FillingCheckExecuted");
		Write(FillCheckingWriteParameters);
	EndIf;
EndProcedure

&AtServerNoContext
Function PasswordCheckIsRequired(Ref, AttributeValues)
	Return Catalogs.EmailAccounts.PasswordCheckIsRequired(Ref, AttributeValues);
EndFunction

#EndRegion
