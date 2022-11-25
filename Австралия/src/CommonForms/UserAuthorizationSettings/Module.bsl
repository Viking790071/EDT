#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ShowExternalUsersSettings = Parameters.ShowExternalUsersSettings;
	
	RecommendedSettings = New Structure;
	RecommendedSettings.Insert("MinPasswordLength", 8);
	RecommendedSettings.Insert("MaxPasswordLifetime", 30);
	RecommendedSettings.Insert("MinPasswordLifetime", 1);
	RecommendedSettings.Insert("DenyReusingRecentPasswords", 10);
	RecommendedSettings.Insert("InactivityPeriodBeforeDenyingAuthorization", 45);
	
	If ShowExternalUsersSettings Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "ExternalUsers");
		AutoTitle = False;
		Title = NStr("ru = 'Настройки входа внешних пользователей'; en = 'External user authorization settings'; pl = 'Ustawienia wejścia użytkowników zewnętrznych';es_ES = 'Ajustes de la entrada de los usuarios externos';es_CO = 'Ajustes de la entrada de los usuarios externos';tr = 'Dış kullanıcıların oturum açma ayarları';it = 'Impostazioni autorizzazione utente esterno';de = 'Einstellungen für die Anmeldung externer Benutzer'");
		FillPropertyValues(ThisObject, UsersInternal.AuthorizationSettings().ExternalUsers);
	Else
		FillPropertyValues(ThisObject, UsersInternal.AuthorizationSettings().Users);
	EndIf;
	
	For Each KeyAndValue In RecommendedSettings Do
		If ValueIsFilled(ThisObject[KeyAndValue.Key]) Then
			ThisObject[KeyAndValue.Key + "Enable"] = True;
		Else
			ThisObject[KeyAndValue.Key] = KeyAndValue.Value;
			Items[KeyAndValue.Key].Enabled = False;
		EndIf;
	EndDo;
	
	If GetUserPasswordStrengthCheck() Then
		ClearDesignerSettingsQuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Установлена минимальная длина паролей %1 и требование сложности паролей в конфигураторе
			           |в меню ""Администрирование"" в пункте ""Параметры информационной базы ..."".
			           |
			           |Требуется очистить минимальную длину и требование сложности пароля, заданные в конфигураторе,
			           |чтобы корректно использовать настройки входа.'; 
			           |en = 'Minimum password length %1 and password complexity requirement are specified in Designer
			           |(in ""Administration""—""Infobase parameters"").
			           |
			           |To have the settings specified here take effect,
			           |clear the minimum length and password complexity specified in Designer.'; 
			           |pl = 'Ustawiono minimalną długość haseł %1 i wymaganie złożoności haseł w kreatorze
			           |(w menu ""Administrowanie"" w punkcie ""Parametry bazy informacyjnej..."").
			           |
			           |Jest konieczne oczyszczenie minimalnej długości i wymagania złożoności hasła, określonych w kreatorze,
			           |żeby prawidłowo korzystać z ustawień wejścia.';
			           |es_ES = 'Se ha especificado la longitud mínima de las contraseñas %1 y la exigencias de la complejidad de las contraseñas en el configurador
			           |en el menú ""Administración"" en el apartado ""Parámetros de la base de información..."".
			           |
			           |se requiere limpiar la longitud mínima y la exigencia de la complejidad de la contraseña establecidas en el configurador
			           |para usar correctamente los ajustes de entrada.';
			           |es_CO = 'Se ha especificado la longitud mínima de las contraseñas %1 y la exigencias de la complejidad de las contraseñas en el configurador
			           |en el menú ""Administración"" en el apartado ""Parámetros de la base de información..."".
			           |
			           |se requiere limpiar la longitud mínima y la exigencia de la complejidad de la contraseña establecidas en el configurador
			           |para usar correctamente los ajustes de entrada.';
			           |tr = 'Minimum parola uzunluğu ve ""Bilgi tabanı seçenekleri"" %1bölümünde ""Yönetim"" menüsü yapılandırmasında parola karmaşıklığı gereksinimi belirlendi ..."" 
			           |
			           |Oturum açma ayarlarını doğru bir şekilde kullanmak için yapılandırıcıda belirtilen minimum uzunluğu ve 
			           |
			           |parola karmaşıklığı gereksinimini temizlemek gerekir.';
			           |it = 'I requisiti di lunghezza minima della password %1e di complessità della password sono specificati in Designer
			           |(in ""Amministrazione"" - ""Parametri Infobase"").
			           |
			           |Per fare in modo che le impostazioni specificate abbiano effetto
			           |cancellare la lunghezza minima e la complessità della password specificate in Designer.';
			           |de = 'Die minimale Länge der Passwörter %1 und die Anforderung der Passwortkomplexität im Konfigurator
			           |des Menüs ""Administration"" im Punkt ""Informationsbasisparameter..."" werden eingestellt.
			           |
			           |Es ist notwendig, die im Konfigurator angegebene Mindestlänge und Passwortkomplexität zu löschen,
			           |um die Anmeldeeinstellungen korrekt zu verwenden.'"),
			GetUserPasswordMinLength());
		
	ElsIf GetUserPasswordMinLength() > 0 Then
		ClearDesignerSettingsQuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Установлена минимальная длина паролей %1 в конфигураторе
			           |в меню ""Администрирование"" в пункте ""Параметры информационной базы ..."".
			           |
			           |Требуется очистить минимальную длину, заданную в конфигураторе,
			           |чтобы корректно использовать настройки входа.'; 
			           |en = 'Minimum password length %1 is specified in Designer
			           |(in ""Administration""—""Infobase parameters"").
			           |
			           |To have the settings specified here take effect,
			           |clear the minimum length specified in Designer.'; 
			           |pl = 'Ustawiono minimalną długość haseł %1 w kreatorze
			           |(w menu ""Administrowanie"" w punkcie ""Parametry bazy informacyjnej"").
			           |
			           |Jest konieczne oczyszczenie minimalnej długości, określonej w kreatorze,
			           |żeby prawidłowo korzystać z ustawień wejścia.';
			           |es_ES = 'Se ha especificado la longitud mínima de las contraseñas %1 en el configurador
			           |en el menú ""Administración"" en el apartado ""Parámetros de la base de información..."".
			           |
			           |se requiere limpiar la longitud mínima establecida en el configurador
			           |para usar correctamente los ajustes de entrada.';
			           |es_CO = 'Se ha especificado la longitud mínima de las contraseñas %1 en el configurador
			           |en el menú ""Administración"" en el apartado ""Parámetros de la base de información..."".
			           |
			           |se requiere limpiar la longitud mínima establecida en el configurador
			           |para usar correctamente los ajustes de entrada.';
			           |tr = 'Minimum parola uzunluğu ""Bilgi tabanı seçenekleri"" %1bölümünde ""Yönetim"" menüsü yapılandırmasında belirlendi ..."" 
			           |
			           |Oturum açma ayarlarını doğru bir şekilde kullanmak için yapılandırıcıda belirtilen minimum uzunluğu ve 
			           |
			           |parola karmaşıklığı gereksinimini temizlemek gerekir.';
			           |it = 'Lunghezza minima della password %1 indicata in Designer
			           |(in ""Amministrazione""-""Parametri infobase"").
			           |
			           |Perché le impostazioni qui indicate abbiano effetto,
			           |cancellare la lunghezza minima indicata in Designer.';
			           |de = 'Die Mindestlänge der Passwörter %1 im Konfigurator
			           |des Menüs ""Administration"" im Punkt ""Informationsbasisparameter..."" ist eingestellt.
			           |
			           |Sie müssen die im Konfigurator angegebene Mindestlänge löschen,
			           |um die Eingangseinstellungen korrekt zu verwenden.'"),
			GetUserPasswordMinLength());
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "FormWriteAndClose", "Title", NStr("ru ='ОК'; en = 'OK'; pl = 'OK';es_ES = 'OK';es_CO = 'Ok';tr = 'Tamam';it = 'OK';de = 'Ok'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(ClearDesignerSettingsQuestionText) Then
		Cancel = True;
		Buttons = New ValueList;
		Buttons.Add("Clear", NStr("ru = 'Очистить'; en = 'Clear'; pl = 'Wyczyść';es_ES = 'Eliminar';es_CO = 'Eliminar';tr = 'Temizle';it = 'Annulla';de = 'Löschen'"));
		Buttons.Add("Cancel",   NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
		ShowQueryBox(New NotifyDescription("OnOpenAfterAnswerToQuestion", ThisObject),
			ClearDesignerSettingsQuestionText, Buttons);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PasswordMustMeetComplexityRequirementsOnChange(Item)
	
	If MinPasswordLength < 7 Then
		MinPasswordLength = 7;
	EndIf;
	
EndProcedure

&AtClient
Procedure MinPasswordLengthOnChange(Item)
	
	If MinPasswordLength < 7
	  AND PasswordMustMeetComplexityRequirements Then
		
		MinPasswordLength = 7;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingEnableOnChange(Item)
	
	SettingName = Left(Item.Name, StrLen(Item.Name) - StrLen("Enable"));
	
	If ThisObject[Item.Name] = False Then
		ThisObject[SettingName] = RecommendedSettings[SettingName];
	EndIf;
	
	Items[SettingName].Enabled = ThisObject[Item.Name];
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAtServer();
	Notify("Write_ConstantsSet", New Structure, "UserAuthorizationSettings");
	Close();
	
EndProcedure

#EndRegion

#Region Private

// The procedure that follows OnOpen procedure.
&AtClient
Procedure OnOpenAfterAnswerToQuestion(Response, Context) Export
	
	If Response <> "Clear" Then
		Return;
	EndIf;
	
	ClearDesignerSettingsQuestionText = "";
	
	ClearDesignerSettings();
	
	Open();
	
EndProcedure

&AtServer
Procedure WriteAtServer()
	
	Lock = New DataLock;
	LockItem  = Lock.Add("Constant.UserAuthorizationSettings");
	
	BeginTransaction();
	Try
		Lock.Lock();
		AuthorizationSettings = UsersInternal.AuthorizationSettings();
		
		If ShowExternalUsersSettings Then
			Settings = AuthorizationSettings.ExternalUsers;
		Else
			Settings = AuthorizationSettings.Users;
		EndIf;
		
		Settings.PasswordMustMeetComplexityRequirements = PasswordMustMeetComplexityRequirements;
		
		If Not ValueIsFilled(InactivityPeriodBeforeDenyingAuthorization) Then
			Settings.InactivityPeriodActivationDate = '00010101';
			
		ElsIf Not ValueIsFilled(Settings.InactivityPeriodActivationDate) Then
			Settings.InactivityPeriodActivationDate = BegOfDay(CurrentSessionDate());
		EndIf;
		
		For Each KeyAndValue In RecommendedSettings Do
			If ThisObject[KeyAndValue.Key + "Enable"] Then
				Settings[KeyAndValue.Key] = ThisObject[KeyAndValue.Key];
			Else
				Settings[KeyAndValue.Key] = 0;
			EndIf;
		EndDo;
		
		Constants.UserAuthorizationSettings.Set(New ValueStorage(AuthorizationSettings));
		
		If ValueIsFilled(AuthorizationSettings.Users.InactivityPeriodBeforeDenyingAuthorization)
		 Or ValueIsFilled(AuthorizationSettings.ExternalUsers.InactivityPeriodBeforeDenyingAuthorization) Then
			
			SetPrivilegedMode(True);
			UsersInternal.ChangeUserActivityMonitoringJob(True);
			SetPrivilegedMode(False);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	RefreshReusableValues();
	
EndProcedure

&AtServer
Procedure ClearDesignerSettings()
	
	BeginTransaction();
	Try
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

#EndRegion
