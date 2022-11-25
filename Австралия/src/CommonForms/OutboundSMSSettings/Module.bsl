
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Owner = Common.MetadataObjectID("Constant.SMSProvider");
	SetPrivilegedMode(True);
	ProviderSettings = Common.ReadDataFromSecureStorage(Owner, "Password, Username, SenderName");
	SetPrivilegedMode(False);
	SMSMessageSenderUsername = ProviderSettings.Username;
	SenderName = ProviderSettings.SenderName;
	SMSMessageSenderPassword = ?(ValueIsFilled(ProviderSettings.Password), ThisObject.UUID, "");
	
	FillServiceDetails();
	
	Items.SMSMessageSenderUsername.Title = ServiceDetails.UsernamePresentation;
	Items.SMSMessageSenderPassword.Title = ServiceDetails.PasswordPresentation;	
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	InternetAddress = ServiceDetails.InternetAddress;
	SendSMSMessagesClientOverridable.OnGetProviderInternetAddress(ConstantsSet.SMSProvider, InternetAddress);
	Items.ServiceDetails.Visible = Not IsBlankString(InternetAddress);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	RefreshReusableValues();
	Notify("Write_SMSSendingSettings", WriteParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	SetPrivilegedMode(True);
	Owner = Common.MetadataObjectID("Constant.SMSProvider");
	If SMSMessageSenderPassword <> String(ThisObject.UUID) Then
		Common.WriteDataToSecureStorage(Owner, SMSMessageSenderPassword);
	EndIf;
	Common.WriteDataToSecureStorage(Owner, SMSMessageSenderUsername, "Username");
	Common.WriteDataToSecureStorage(Owner, SenderName, "SenderName");
	SetPrivilegedMode(False);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SMSMessageProviderOnChange(Item)
	SMSMessageSenderUsername = "";
	SMSMessageSenderPassword = "";
	SenderName = "";
	FillServiceDetails();
	Items.SMSMessageSenderUsername.Title = ServiceDetails.UsernamePresentation;
	Items.SMSMessageSenderPassword.Title = ServiceDetails.PasswordPresentation;
EndProcedure

&AtClient
Procedure ServiceDetailsClick(Item)
	InternetAddress = ServiceDetails.InternetAddress;
	SendSMSMessagesClientOverridable.OnGetProviderInternetAddress(ConstantsSet.SMSProvider, InternetAddress);
	If Not IsBlankString(InternetAddress) Then
		CommonClient.OpenURL(InternetAddress);
	EndIf;
EndProcedure

&AtServer
Procedure FillServiceDetails()
	ServiceDetails = New Structure;
	ServiceDetails.Insert("InternetAddress", "");
	ServiceDetails.Insert("UsernamePresentation", NStr("ru = 'Логин'; en = 'Username'; pl = 'Nazwa użytkownika';es_ES = 'Nombre de usuario';es_CO = 'Nombre de usuario';tr = 'Kullanıcı adı';it = 'Nome utente';de = 'Login'"));
	ServiceDetails.Insert("PasswordPresentation", NStr("ru = 'Пароль'; en = 'Password'; pl = 'Hasło';es_ES = 'Contraseña';es_CO = 'Contraseña';tr = 'Parola';it = 'Password';de = 'Passwort'"));
	
EndProcedure

#EndRegion
