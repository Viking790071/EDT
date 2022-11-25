#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	FillObjectWithDefaultValues();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not UseForSending AND Not UseForReceiving Then
		CheckedAttributes.Clear();
		CheckedAttributes.Add("Description");
		Return;
	EndIf;
	
	NotCheckedAttributeArray = New Array;
	
	If Not UseForSending Then
		NotCheckedAttributeArray.Add("OutgoingMailServer");
	EndIf;
	
	If Not UseForReceiving Then
		NotCheckedAttributeArray.Add("IncomingMailServer");
	EndIf;
		
	If Not IsBlankString(EmailAddress) AND Not CommonClientServer.EmailAddressMeetsRequirements(EmailAddress, True) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Почтовый адрес заполнен неверно.'; en = 'Postal address is filled in incorrectly.'; pl = 'Nieprawidłowy adres pocztowy.';es_ES = 'Dirección postal incorrecta.';es_CO = 'Dirección postal incorrecta.';tr = 'Posta adresi yanlış dolduruldu.';it = 'L''indirizzo postale è compilato non correttamente.';de = 'Falsche Postanschrift.'"), ThisObject, "EmailAddress");
		NotCheckedAttributeArray.Add("EmailAddress");
		Cancel = True;
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NotCheckedAttributeArray);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	Common.DeleteDataFromSecureStorage(Ref);
	SetPrivilegedMode(False);
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If User <> TrimAll(User) Then
		User = TrimAll(User);
	EndIf;
	
	If SMTPUser <> TrimAll(SMTPUser) Then
		SMTPUser = TrimAll(SMTPUser);
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotCheckSettingsForChanges") AND Not Ref.IsEmpty() Then
		PasswordCheckIsRequired = Catalogs.EmailAccounts.PasswordCheckIsRequired(Ref, ThisObject);
		If PasswordCheckIsRequired Then
			PasswordCheck = Undefined;
			If Not AdditionalProperties.Property("Password", PasswordCheck) Or Not PasswordCorrect(PasswordCheck) Then
				ErrorMessageText = NStr("ru = 'Не подтвержден пароль для изменения настроек учетной записи.'; en = 'Password required to change account settings is not confirmed.'; pl = 'Nie potwierdzono hasła do zmiany ustawień konta.';es_ES = 'No está comprobada la contraseña para cambiar los ajustes de la cuenta.';es_CO = 'No está comprobada la contraseña para cambiar los ajustes de la cuenta.';tr = 'Hesap ayarlarını değiştirmek için şifre doğrulanmadı.';it = 'Richiesta la password per la modifica impostazioni account non confermate.';de = 'Nicht bestätigtes Passwort zum Ändern der Kontoeinstellungen.'");
				Raise ErrorMessageText;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure FillObjectWithDefaultValues() Export
	
	UserName = NStr("ru = '1С:Предприятие'; en = '1C:Enterprise'; pl = '1C:Enterprise';es_ES = '1C:Empresa';es_CO = '1C:Empresa';tr = '1C:Enterprise';it = '1C: Enterprise';de = '1C:Enterprise'");
	UseForReceiving = False;
	UseForSending = False;
	KeepMessageCopiesAtServer = False;
	KeepMailAtServerPeriod = 0;
	Timeout = 30;
	IncomingMailServerPort = 110;
	OutgoingMailServerPort = 25;
	ProtocolForIncomingMail = "POP";
	
EndProcedure

Function PasswordCorrect(PasswordCheck)
	SetPrivilegedMode(True);
	Passwords = Common.ReadDataFromSecureStorage(Ref, "Password,SMTPPassword");
	SetPrivilegedMode(False);
	
	PasswordsToCheck = New Array;
	If ValueIsFilled(Passwords.Password) Then
		PasswordsToCheck.Add(Passwords.Password);
	EndIf;
	If ValueIsFilled(Passwords.SMTPPassword) Then
		PasswordsToCheck.Add(Passwords.SMTPPassword);
	EndIf;
	
	For Each PasswordToCheck In PasswordsToCheck Do
		If PasswordCheck <> PasswordToCheck Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

#EndRegion

#EndIf
