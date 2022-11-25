
// Procedure - command handler BalanceEntering.
//
&AtClient
Procedure BalanceEntering(Command)
	
	If DriveServer.InfobaseUserWithFullAccess(,, False) Then
		OpenFormBalanceEntering();
	Else
		MessageText = NStr("en = 'Only user with the ""Administrator"" access right profile can perform this action.'; ru = 'Выполнить это действие может только пользователь с профилем прав доступа ""Администратор"".';pl = 'Tylko użytkownik, który ma prawo dostępu ""Administrator"", może wykonać tę operację.';es_ES = 'Solo el usuario con el perfil del derecho de acceso ""Administrador"" puede realizar esta acción.';es_CO = 'Solo el usuario con el perfil del derecho de acceso ""Administrador"" puede realizar esta acción.';tr = 'Sadece ""Yönetici"" erişim hakkı profiline sahip kullanıcı bu işlemi gerçekleştirebilir.';it = 'Solo utente con diritto di accesso del profilo ""Amministratore"" può eseguire questa azione.';de = 'Nur Benutzer mit dem Zugriffsrechteprofil ""Administrator"" können diese Aktion durchführen.'");
		ShowMessageBox(Undefined,MessageText);
	EndIf;
	
EndProcedure

// Procedure - command handler FillInformationAboutCompany.
//
&AtClient
Procedure FillInformationAboutCompany(Command)
	
	If DriveServer.InfobaseUserWithFullAccess(,, False) Then
		OpenFormFillingInformationAboutCompany();
	Else
		MessageText = NStr("en = 'Only user with the ""Administrator"" access right profile can perform this action.'; ru = 'Выполнить это действие может только пользователь с профилем прав доступа ""Администратор"".';pl = 'Tylko użytkownik, który ma prawo dostępu ""Administrator"", może wykonać tę operację.';es_ES = 'Solo el usuario con el perfil del derecho de acceso ""Administrador"" puede realizar esta acción.';es_CO = 'Solo el usuario con el perfil del derecho de acceso ""Administrador"" puede realizar esta acción.';tr = 'Sadece ""Yönetici"" erişim hakkı profiline sahip kullanıcı bu işlemi gerçekleştirebilir.';it = 'Solo un utente con profilo con diritto di accesso ""Amministratore"" può eseguire questa azione.';de = 'Nur Benutzer mit dem Zugriffsrechteprofil ""Administrator"" können diese Aktion durchführen.'");
		ShowMessageBox(Undefined,MessageText);
	EndIf;
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Constants.CompanyInformationIsFilled.Get() Then
		Items.FillInformationAboutCompanyStatus.Picture = PictureLib.Done;
	Else
		Items.FillInformationAboutCompanyStatus.Picture = PictureLib.GoToNext;
	EndIf;
	
	If Constants.OpeningBalanceIsFilled.Get() Then
		Items.BalanceEnteringStatus.Picture = PictureLib.Done;
	Else
		Items.BalanceEnteringStatus.Picture = PictureLib.GoToNext;
	EndIf;
	
EndProcedure

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetButtonParameters();
	
EndProcedure

// Procedure sets button parameters.
//
&AtClient
Procedure SetButtonParameters()
	
	If Items.FillInformationAboutCompanyStatus.Picture = PictureLib.Done Then
		Items.FillInformationAboutCompany.Title = NStr("en = 'Change'; ru = 'Изменить';pl = 'Zmień';es_ES = 'Cambiar';es_CO = 'Cambiar';tr = 'Değiştir';it = 'Modificare';de = 'Ändern'");
	EndIf;                                                                    
	
	If Items.BalanceEnteringStatus.Picture = PictureLib.Done Then
		Items.BalanceEntering.Title = NStr("en = 'Change'; ru = 'Изменить';pl = 'Zmień';es_ES = 'Cambiar';es_CO = 'Cambiar';tr = 'Değiştir';it = 'Modificare';de = 'Ändern'");
	EndIf;
	
EndProcedure

// Procedure opens the form for filling the data of the company.
//
&AtClient
Procedure OpenFormFillingInformationAboutCompany()
	
	Notification = New NotifyDescription("OpenFormFillingInformationAboutCompanyCompletion",ThisForm);
	OpenForm("CommonForm.CompanyInformationFillingWizard",,,,,,Notification);
	
EndProcedure

&AtClient
Procedure OpenFormFillingInformationAboutCompanyCompletion(CompletedFilling,Parameters) Export
	
	If ValueIsFilled(CompletedFilling) AND CompletedFilling Then
		Items.FillInformationAboutCompanyStatus.Picture = PictureLib.Done;
		SetButtonParameters();
	EndIf;
	
	SettingsModified = False;
	DriveServerCall.ConfigureUserDesktop(SettingsModified);
	If SettingsModified Then
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure opens the form for entering the balances.
//
&AtClient
Procedure OpenFormBalanceEntering()
	
	Notification = New NotifyDescription("OpenFormInputBalancesCompletion",ThisForm);
	OpenForm("CommonForm.OpeningBalanceFillingWizard",,,,,,Notification);
	
EndProcedure

&AtClient
Procedure OpenFormInputBalancesCompletion(CompletedFilling,Parameters) Export
	
	If ValueIsFilled(CompletedFilling) AND CompletedFilling Then
		Items.BalanceEnteringStatus.Picture = PictureLib.Done;
		SetButtonParameters();
	EndIf;
	
	SettingsModified = False;
	DriveServerCall.ConfigureUserDesktop(SettingsModified);
	If SettingsModified Then
		RefreshInterface();
	EndIf;
	
EndProcedure
