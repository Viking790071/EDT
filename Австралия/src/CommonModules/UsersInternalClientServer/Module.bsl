#Region Internal

// Returns the string of the day, days kind.
//
// Parameters:
//   Number - Number - an integer to which to add numeration item.
//   FormatString - String - see the parameter of the same name of the NumberInWords method, for 
//                                          example, DE=True.
//   NumerationItemParameters - String - see the parameter of the same name of the NumberInWords 
//                                          method, for example, NStr("en= day, days,,,0'").
//
//  Returns:
//   String.
//
Function IntegerSubject(Number, FormatString, NumerationItemParameters) Export
	
	Integer = Int(Number);
	
	If NOT ValueIsFilled(FormatString) Then
		FormatString = NStr("en = 'L = en_US'; ru = 'L = ru_RU'; pl = 'L = pl_PL';es_ES = 'L = en_US';es_CO = 'L = en_US';tr = 'Dil = İngilizce_ABD';it = 'L = en_US';de = 'L = en_US'");
	EndIf;
	
	NumberInWords = NumberInWords(Integer, FormatString, NStr("ru = ',,,,,,,,0'; en = ',,,,0'; pl = ',,,,0';es_ES = ',,,,0';es_CO = ',,,,0';tr = ',,,,0';it = ',,,,0';de = ',,,,0'"));
	
	SubjectAndNumberInWords = NumberInWords(Integer, FormatString, NumerationItemParameters);
	
	Return StrReplace(SubjectAndNumberInWords, NumberInWords, "");
	
EndFunction

// Determines the WriteAndClose button availability in the forms where it is required to ask the 
// user a question BeforeWrite the object on the client setting Cancel = True and re-calling the 
// method of the Write form.
//
// To call the procedure on the client, the RightToEditObject attribute of the Arbitrary type should 
// be added to the form.
// This attribute is initialized when it is first called on the server (from the event handler of 
// the OnCreateAtServer form) and then it is used when it is called on the client, when the 
// properties of the ReadOnly form are changed.
// 
// Parameters:
//  Form - ClientApplicationForm - a form of items of a catalog, document, ...
//  MainAttribute - String - a name of the form attribute containing the object structure.
//  ItemName - String - a name of the form item with the WriteAndClose button.
//
Procedure SetWriteAndCloseButtonAvailability(Form, MainAttribute = "Object", ItemName = "FormWriteAndClose") Export
	
	Rights = New Structure("EditObjectRight");
	FillPropertyValues(Rights, Form);
	
	If Rights.EditObjectRight = Undefined Then
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Rights.EditObjectRight = AccessRight("Edit", Form[MainAttribute].Ref.Metadata());
		FillPropertyValues(Form, Rights);
	#EndIf
	EndIf;
	
	ButtonAvailability = Not Form.ReadOnly AND Rights.EditObjectRight;
	If Form.Items[ItemName].Enabled <> ButtonAvailability Then
		Form.Items[ItemName].Enabled = ButtonAvailability;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Generates the user name based on the  full name.
Function GetIBUserShortName(Val FullName) Export
	
	Separators = New Array;
	Separators.Add(" ");
	Separators.Add(".");
	
	ShortName = "";
	For Counter = 1 To 3 Do
		
		If Counter <> 1 Then
			ShortName = ShortName + Upper(Left(FullName, 1));
		EndIf;
		
		SeparatorPosition = 0;
		For each Separator In Separators Do
			CurrentSeparatorPosition = StrFind(FullName, Separator);
			If CurrentSeparatorPosition > 0
			   AND (    SeparatorPosition = 0
			      OR SeparatorPosition > CurrentSeparatorPosition ) Then
				SeparatorPosition = CurrentSeparatorPosition;
			EndIf;
		EndDo;
		
		If SeparatorPosition = 0 Then
			If Counter = 1 Then
				ShortName = FullName;
			EndIf;
			Break;
		EndIf;
		
		If Counter = 1 Then
			ShortName = Left(FullName, SeparatorPosition - 1);
		EndIf;
		
		FullName = Right(FullName, StrLen(FullName) - SeparatorPosition);
		While Separators.Find(Left(FullName, 1)) <> Undefined Do
			FullName = Mid(FullName, 2);
		EndDo;
	EndDo;
	
	Return ShortName;
	
EndFunction

// For the Users and ExternalUsers catalogs item form.
Procedure UpdateLifetimeRestriction(Form) Export
	
	Items = Form.Items;
	
	Items.ChangeAuthorizationRestriction.Visible =
		Items.IBUserProperies.Visible AND Form.AccessLevel.ListManagement;
	
	If Not Items.IBUserProperies.Visible Then
		Items.CanSignIn.Title = "";
		Return;
	EndIf;
	
	Items.ChangeAuthorizationRestriction.Enabled = Form.AccessLevel.AuthorizationSettings;
	
	TitleWithRestriction = "";
	
	If Form.UnlimitedValidityPeriod Then
		TitleWithRestriction = NStr("ru = 'Вход в программу разрешен (без ограничения срока)'; en = 'Can sign in (no expiration period)'; pl = 'Wejście do programu jest dozwolone (bez ograniczeń czasowych)';es_ES = 'La entrada en el programa está permitida (sin restricción del período)';es_CO = 'La entrada en el programa está permitida (sin restricción del período)';tr = 'Uygulamaya giriş yasaklandı (süre kısıtlaması olmadan)';it = 'L''accesso al programma è permesso (senza un limite di tempo)';de = 'Der Login in das Programm ist erlaubt (zeitlich unbegrenzt).'");
		
	ElsIf ValueIsFilled(Form.ValidityPeriod) Then
		TitleWithRestriction = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Вход в программу разрешен (до %1)'; en = 'Can sign in (till %1)'; pl = 'Logowanie do programu jest dozwolone (do %1)';es_ES = 'La entrada en el programa está permitida (hasta %1)';es_CO = 'La entrada en el programa está permitida (hasta %1)';tr = 'Uygulamaya girişe izin verildi (%1 kadar)';it = 'L''accesso al programma è permesso (fino a %1)';de = 'Der Login in das Programm ist erlaubt (bis %1)'"),
			Format(Form.ValidityPeriod, "DLF=D"));
			
	ElsIf ValueIsFilled(Form.InactivityPeriodBeforeDenyingAuthorization) Then
		TitleWithRestriction = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Вход в программу разрешен (запретить, если не работает более %1)'; en = 'Can sign in (revoke access after inactivity period: %1)'; pl = 'Wejście do programu jest dozwolone (zabroń, jeśli nie pracuje ponad %1)';es_ES = 'La entrada en el programa está permitida (prohibir si no lo usa más de %1)';es_CO = 'La entrada en el programa está permitida (prohibir si no lo usa más de %1)';tr = 'Uygulamaya girişe izin verildi (%1''den fazla çalışmaması durumunda yasakla)';it = 'Può accedere (revocare accesso dopo periodo di inattività: %1)';de = 'Der Login in das Programm ist erlaubt (verboten, wenn es seit %1 nicht mehr arbeitet)'"),
			Format(Form.InactivityPeriodBeforeDenyingAuthorization, "NG=") + " "
				+ IntegerSubject(Form.InactivityPeriodBeforeDenyingAuthorization,
					"", NStr("ru = 'день,дня,дней,,,,,,0'; en = 'day,days,,,0'; pl = 'dzień, dni,,,0';es_ES = 'día,días,,,0';es_CO = 'día,días,,,0';tr = 'gün, gün, gün,,,,,,0';it = 'giorno,giorni,,,0';de = 'Tag, Tag, Tage,,,,,, 0'")));
	EndIf;
	
	If ValueIsFilled(TitleWithRestriction) Then
		Items.CanSignIn.Title = TitleWithRestriction;
		Items.ChangeAuthorizationRestriction.Title = NStr("ru = 'Изменить ограничение'; en = 'Edit authentication restrictions'; pl = 'Edytuj ograniczenia uwierzytelniania';es_ES = 'Cambiar la restricción';es_CO = 'Cambiar la restricción';tr = 'Kısıtlamayı değiştir';it = 'Modifica restrizioni di autenticazione';de = 'Einschränkung der Änderung'");
	Else
		Items.CanSignIn.Title = "";
		Items.ChangeAuthorizationRestriction.Title = NStr("ru = 'Установить ограничение'; en = 'Set authentication restriction'; pl = 'Ustaw ograniczenie autoryzacji';es_ES = 'Establecer la restricción';es_CO = 'Establecer la restricción';tr = 'Kısıtla';it = 'Imposta restrizioni all''autenticazione';de = 'Setzen Sie ein Limit'");
	EndIf;
	
EndProcedure

// For the Users and ExternalUsers catalogs item form.
Procedure CheckPasswordSet(Form, PasswordSet) Export
	
	Items = Form.Items;
	
	If PasswordSet Then
		Items.PasswordExistsLabel.Title = NStr("ru = 'Пароль установлен'; en = 'The password is set.'; pl = 'Hasło ustawione';es_ES = 'Contraseña establecida';es_CO = 'Contraseña establecida';tr = 'Şifre belirlendi';it = 'La password è stata impostata.';de = 'Passwort gesetzt'");
		Items.UserMustChangePasswordOnAuthorization.Title =
			NStr("ru = 'Потребовать смену пароля при входе'; en = 'Require password change upon authorization'; pl = 'Wymagaj zmiany hasła po zalogowaniu';es_ES = 'Requerir el cambio de la contraseña al entrar';es_CO = 'Requerir el cambio de la contraseña al entrar';tr = 'Oturum açma sırasında şifre değişikliği talep et';it = 'Richiedi la modifica della password dopo l''autorizzazione';de = 'Passwortänderung bei der Anmeldung anfordern'");
	Else
		Items.PasswordExistsLabel.Title = NStr("ru = 'Пустой пароль'; en = 'Blank password'; pl = 'Puste hasło';es_ES = 'Contraseña vacía';es_CO = 'Contraseña vacía';tr = 'Boş şifre';it = 'Password vuota';de = 'Leeres Passwort'");
		Items.UserMustChangePasswordOnAuthorization.Title =
			NStr("ru = 'Потребовать установку пароля при входе'; en = 'Require to set a password upon authorization'; pl = 'Wymagać ustawienie hasła podczas autoryzacji';es_ES = 'Requerir especificar la contraseña al entrar';es_CO = 'Requerir especificar la contraseña al entrar';tr = 'Oturum açma sırasında şifre belirlenmesini talep et';it = 'Richiede di impostare una password all''autorizzazione';de = 'Erfordert Passworteinstellung bei der Anmeldung'");
	EndIf;
	
	If PasswordSet
	   AND Form.Object.Ref = UsersClientServer.AuthorizedUser() Then
		
		Items.ChangePassword.Title = NStr("ru = 'Сменить пароль...'; en = 'Change password...'; pl = 'Zmień hasło...';es_ES = 'Cambiar la contraseña...';es_CO = 'Cambiar la contraseña...';tr = 'Parola değiştir...';it = 'Modifica password...';de = 'Ändern Sie das Passwort...'");
	Else
		Items.ChangePassword.Title = NStr("ru = 'Установить пароль...'; en = 'Set password...'; pl = 'Ustaw hasło...';es_ES = 'Establecer la contraseña...';es_CO = 'Establecer la contraseña...';tr = 'Parola belirle...';it = 'Imposta password...';de = 'Ein Passwort festlegen...'");
	EndIf;
	
EndProcedure

#EndRegion
