#Region Internal

// Opens a form where a user can change a password.
Procedure OpenChangePasswordForm(User = Undefined, ContinuationHandler = Undefined, AdditionalParameters = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("ReturnPasswordAndDoNotSet", False);
	FormParameters.Insert("OldPassword", Undefined);
	If AdditionalParameters <> Undefined Then
		FillPropertyValues(FormParameters, AdditionalParameters);
	EndIf;
	FormParameters.Insert("User", User);
	
	OpenForm("CommonForm.ChangePassword", FormParameters,,,,, ContinuationHandler);
	
EndProcedure

// See UsersInternalSaaSClient.RequestPasswordForAuthenticationInService. 
Procedure RequestPasswordForAuthenticationInService(ContinuationHandler, OwnerForm = Undefined, ServiceUserPassword = Undefined) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		
		ModuleUsersInternalSaaSClient = CommonClient.CommonModule(
			"UsersInternalSaaSClient");
		
		ModuleUsersInternalSaaSClient.RequestPasswordForAuthenticationInService(
			ContinuationHandler, OwnerForm, ServiceUserPassword);
	EndIf;
	
EndProcedure

Procedure InstallInteractiveDataProcessorOnInsufficientRightsToSignInError(Parameters, ErrorDescription) Export
	
	Parameters.Cancel = True;
	Parameters.InteractiveHandler = New NotifyDescription(
		"InteractiveDataProcessorOnInsufficientRightsToSignInError", ThisObject, ErrorDescription);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For role interface in managed forms.

// For internal use only.
//
Procedure ExpandRoleSubsystems(Form, Unconditionally = True) Export
	
	Items = Form.Items;
	
	If NOT Unconditionally
	   AND NOT Items.RolesShowSelectedRolesOnly.Check Then
		
		Return;
	EndIf;
	
	// Expand all.
	For each Row In Form.Roles.GetItems() Do
		Items.Roles.Expand(Row.GetID(), True);
	EndDo;
	
EndProcedure

// For internal use only.
//
Function SelectPurpose(FormData, Header, SelectUsers = True, IsFilter = False, NotifyDescription = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FormData", FormData);
	AdditionalParameters.Insert("IsFilter", IsFilter);
	AdditionalParameters.Insert("NotifyDescription", NotifyDescription);
	
	OnCloseNotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject, AdditionalParameters);
	
	Assignment = ?(IsFilter, FormData.UsersKind, FormData.Object.Purpose);
	
	FormParameters = New Structure;
	FormParameters.Insert("Title", Header);
	FormParameters.Insert("Purpose", Assignment);
	FormParameters.Insert("SelectUsers", SelectUsers);
	FormParameters.Insert("IsFilter", IsFilter);
	OpenForm("CommonForm.SelectUsersTypes", FormParameters,,,,, OnCloseNotifyDescription);
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Idle handlers.

// Opens the security warning window.
Procedure ShowSecurityWarning() Export
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	varKey = CommonClientServer.StructureProperty(ClientRunParameters, "SecurityWarningKey");
	If ValueIsFilled(varKey) Then
		OpenForm("CommonForm.SecurityWarning", New Structure("Key", varKey));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.BeforeStart. 
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("ErrorInsufficientRightsForAuthorization") Then
		Parameters.RetrievedClientParameters.Insert("ErrorInsufficientRightsForAuthorization");
		InstallInteractiveDataProcessorOnInsufficientRightsToSignInError(Parameters,
			ClientParameters.ErrorInsufficientRightsForAuthorization);
	EndIf;
	
EndProcedure

// See CommonClientOverridable.BeforeStart. 
Procedure BeforeStart2(Parameters) Export
	
	// Checks user authorization result and generates an error message.
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("AuthorizationError") Then
		Parameters.RetrievedClientParameters.Insert("AuthorizationError");
		Parameters.Cancel = True;
		Parameters.InteractiveHandler = New NotifyDescription(
			"InteractiveHandlerOnAuthorizationError", ThisObject);
		Return;
	EndIf;
	
EndProcedure

// See CommonClientOverridable.BeforeStart. 
Procedure BeforeStart3(Parameters) Export
	
	// Requires to change a password if necessary.
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("PasswordChangeRequired") Then
		Parameters.InteractiveHandler = New NotifyDescription(
			"InteractiveHandlerOnChangePasswordOnStart", ThisObject);
		Return;
	EndIf;
	
EndProcedure

// See CommonClientOverridable.AfterStart. 
Procedure AfterStart() Export
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	varKey = CommonClientServer.StructureProperty(ClientRunParameters, "SecurityWarningKey");
	If ValueIsFilled(varKey) Then
		// Slight delay so that the platform has time to draw the current window, on top of which a warning window is displayed.
		AttachIdleHandler("ShowSecurityWarningAfterStart", 0.3, True);
	EndIf;
	
EndProcedure

// See StandardSubsystemsClient.OnExecuteStandardDynamicChecks 
Procedure OnExecuteStandardDynamicChecks(Parameters, ContinuationHandler) Export
	
	// Checks that the account has expired, and it is necessary to exit application.
	If Not Parameters.AuthorizationDenied Then
		ExecuteNotifyProcessing(ContinuationHandler);
		Return;
	EndIf;
	
	OpenForm("CommonForm.AuthorizationDenied");
	
EndProcedure

#EndRegion

#Region Private

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Warns the user about the error of the lack of rights to sign in to the application.
Procedure InteractiveDataProcessorOnInsufficientRightsToSignInError(Parameters, ErrorDescription) Export
	
	ShowMessageBox(
		New NotifyDescription("InteractiveDataProcessorOnInsufficientRightsToSignInErrorAfterWarning",
			ThisObject, Parameters),
		ErrorDescription);
	
EndProcedure

// Exit the application after warning the user about the error of the lack of rights to sign in to the application.
Procedure InteractiveDataProcessorOnInsufficientRightsToSignInErrorAfterWarning(Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Warns the user about an authentication error.
Procedure InteractiveHandlerOnAuthorizationError(Parameters, Context) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	StandardSubsystemsClient.ShowMessageBoxAndContinue(
		Parameters, ClientParameters.AuthorizationError);
	
EndProcedure

// Suggests the user to change a password or exit application.
Procedure InteractiveHandlerOnChangePasswordOnStart(Parameters, Context) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("OnAuthorization", True);
	
	OpenForm("CommonForm.ChangePassword", FormParameters,,,,, New NotifyDescription(
		"InteractiveDataProcessorOnChangePasswordOnStartCompletion", ThisObject, Parameters));
	
EndProcedure

// Continue the InteractiveDataProcessorOnChangePasswordOnStart procedure.
Procedure InteractiveDataProcessorOnChangePasswordOnStartCompletion(Result, Parameters) Export
	
	If Not ValueIsFilled(Result) Then
		Parameters.Cancel = True;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Writes the results of assignment selection in the form.
Procedure AfterAssignmentChoice(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = Undefined Then
		Return;
	EndIf;
	
	If Not AdditionalParameters.IsFilter Then
		Assignment = AdditionalParameters.FormData.Object.Purpose;
		Assignment.Clear();
	EndIf;
	
	SynonymArray = New Array;
	TypesArray = New Array;
	
	For Each Item In ClosingResult Do
		
		If Item.Check Then
			SynonymArray.Add(Item.Presentation);
			TypesArray.Add(Item.Value);
			If Not AdditionalParameters.IsFilter Then
				NewRow = Assignment.Add();
				NewRow.UsersType = Item.Value;
			EndIf;
		EndIf;
		
	EndDo;
	
	ItemTitle = StrConcat(SynonymArray, ", ");
	
	If AdditionalParameters.IsFilter Then
		AdditionalParameters.FormData.UsersKind = ItemTitle;
	Else
		AdditionalParameters.FormData.Items.SelectPurpose.Title = ItemTitle;
	EndIf;
	
	If AdditionalParameters.NotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.NotifyDescription, TypesArray);
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions for AppUserSettings data processor.

// Opens the report or form that is passed to it.
//
// Parameters:
//  CurrentItem - FormTable - a selected row of value tree.
//  User - String - a name of the infobase user.
//  CurrentUser - String - an infobase user name. To open the form, this value should match the 
//                                 value of the User parameter.
//  PersonalSettingsFormName - String - a path to open a form of personal settings.
//                                 The CommonForm.FormName kind.
Procedure OpenReportOrForm(CurrentItem, User, CurrentUser, PersonalSettingsFormName) Export
	
	ValueTreeItem = CurrentItem;
	If ValueTreeItem.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If User <> CurrentUser Then
		WarningText =
			NStr("ru = 'Для просмотра настроек другого пользователя необходимо
			           |запустить программу от его имени и открыть нужный отчет или форму.'; 
			           |en = 'To view settings of another user, restart the application
			           |on behalf of that user and open the report or form.'; 
			           |pl = 'Aby wyświetlić ustawienia innego użytkownika, należy
			           | uruchomić program w jego imieniu i otworzyć żądany raport lub formularz.';
			           |es_ES = 'Para ver los ajustes de otro usuario es necesario
			           |lanzar el programa de su nombre y abrir un informe o un formulario requerido.';
			           |es_CO = 'Para ver los ajustes de otro usuario es necesario
			           |lanzar el programa de su nombre y abrir un informe o un formulario requerido.';
			           |tr = 'Diğer kullanıcının ayarlarını görüntülemek için uygulama onun adı ile
			           |başlatılmalı ve gereken rapor veya form gönderilmelidir.';
			           |it = 'Per vedere le impostazioni di un altro utente, riavviare l''applicazione
			           |a nome di quell''utente e aprire il report o il modulo desiderato.';
			           |de = 'Um die Einstellungen eines anderen Benutzers einzusehen, sollten Sie
			           |das Programm in seinem Namen ausführen und den erforderlichen Bericht oder das Formular öffnen.'");
		ShowMessageBox(,WarningText);
		Return;
	EndIf;
	
	If ValueTreeItem.Name = "ReportSettingsTree" Then
		
		ObjectKey = ValueTreeItem.CurrentData.Keys[0].Value;
		ObjectKeyRowArray = StrSplit(ObjectKey, "/", False);
		OptionKey = ObjectKeyRowArray[1];
		ReportParameters = New Structure("VariantKey, UserSettingsKey", OptionKey, "");
		
		If ValueTreeItem.CurrentData.Type = "ReportSettings" Then
			UserSettingsKey = ValueTreeItem.CurrentData.Keys[0].Presentation;
			ReportParameters.Insert("UserSettingsKey", UserSettingsKey);
		EndIf;
		
		OpenForm(ObjectKeyRowArray[0] + ".Form", ReportParameters);
		Return;
		
	ElsIf ValueTreeItem.Name = "Interface" Then
		
		For Each ObjectKey In ValueTreeItem.CurrentData.Keys Do
			
			If ObjectKey.Check = True Then
				
				FormName = StrSplit(ObjectKey.Value, "/")[0];
				FormNameParts = StrSplit(FormName, ".");
				While FormNameParts.Count() > 4 Do
					FormNameParts.Delete(4);
				EndDo;
				FormName = StrConcat(FormNameParts, ".");
				OpenForm(FormName);
				Return;
			Else
				ItemParent = ValueTreeItem.CurrentData.GetParent();
				
				If ValueTreeItem.CurrentData.RowType = "DesktopSettings" Then
					ShowMessageBox(,
						NStr("ru = 'Для просмотра настроек рабочего стола перейдите к разделу
						           |""Рабочий стол"" в командном интерфейсе программы.'; 
						           |en = 'To view the desktop settings, go to ""Desktop"" section
						           | in the application command interface.'; 
						           |pl = 'Aby wyświetlić ustawienia pulpitu, przejdź do sekcji
						           |""Pulpit"" w interfejsie poleceń programu.';
						           |es_ES = 'Para ver los ajustes del escritorio, pase al apartado
						           |""Escritorio"" en la interfaz de comando del programa.';
						           |es_CO = 'Para ver los ajustes del escritorio, pase al apartado
						           |""Escritorio"" en la interfaz de comando del programa.';
						           |tr = 'Masaüstü ayarlarını görmek için, uygulamanın
						           |komut arayüzündeki ""Masaüstü"" bölümüne gidin.';
						           |it = 'Per visualizzare le impostazioni del desktop andate alla sezione
						           |""Desktop"" nell''interfaccia di comando del programma.';
						           |de = 'Um die Desktop-Einstellungen anzuzeigen, gehen Sie zum Abschnitt
						           |""Desktop"" in der Befehlsoberfläche des Programms.'"));
					Return;
				EndIf;
				
				If ValueTreeItem.CurrentData.RowType = "CommandInterfaceSettings" Then
					ShowMessageBox(,
						NStr("ru = 'Для просмотра настроек командного интерфейса
						           |выберите нужный раздел командного интерфейса программы.'; 
						           |en = 'To view the command interface settings,
						           |select a section in the application command interface.'; 
						           |pl = 'Aby wyświetlić ustawienia interfejsu poleceń,
						           |wybierz żądaną sekcję interfejsu poleceń aplikacji.';
						           |es_ES = 'Para ver las configuraciones de la interfaz de comandos, seleccionar la
						           |sección requerida de la interfaz de comandos de la aplicación.';
						           |es_CO = 'Para ver las configuraciones de la interfaz de comandos, seleccionar la
						           |sección requerida de la interfaz de comandos de la aplicación.';
						           |tr = 'Komut arayüz ayarlarını görüntülemek için, 
						           |uygulamanın komut arayüzün gerekli bölümünü seçin.';
						           |it = 'Per visualizzare le impostazioni dell''interfaccia di comando
						           |selezionate la relativa sezione dell''interfaccia di comando del programma.';
						           |de = 'Um die Einstellungen der Befehlsschnittstelle anzuzeigen, wählen Sie den
						           |erforderlichen Abschnitt der Befehlsschnittstelle der Anwendung aus.'"));
					Return;
				EndIf;
				
				If ItemParent <> Undefined Then
					WarningText =
						NStr("ru = 'Для просмотра данной настройки необходимо открыть ""%1"" 
						           |и затем перейти к форме ""%2"".'; 
						           |en = 'To view this setting, open ""%1""
						           |and go to the ""%2"" form.'; 
						           |pl = 'Aby wyświetlić to ustawienie, musisz otworzyć ""%1"" 
						           |, a następnie przejść do formularza ""%2"".';
						           |es_ES = 'Para ver este ajuste es necesario abrir ""%1"" 
						           |y después pasar al formulario ""%2"".';
						           |es_CO = 'Para ver este ajuste es necesario abrir ""%1"" 
						           |y después pasar al formulario ""%2"".';
						           |tr = 'Bu ayarı görüntülemek için ""%1"" 
						           | açın ve ardından ""%2"" formuna gidin.';
						           |it = 'Per visualizzare questa impostazione è necessario aprire ""%1""
						           | e poi passare al form ""%2"".';
						           |de = 'Um diese Einstellung anzuzeigen, ist es erforderlich das ""%1""
						           |zu öffnen und dann zum Formular ""%2"" zu gehen.'");
					WarningText = StringFunctionsClientServer.SubstituteParametersToString(WarningText,
						ItemParent.Settings, ValueTreeItem.CurrentData.Settings);
					ShowMessageBox(,WarningText);
					Return;
				EndIf;
				
			EndIf;
			
		EndDo;
		
		ShowMessageBox(,NStr("ru = 'Данную настройку невозможно просмотреть.'; en = 'This setting cannot be viewed.'; pl = 'Tego ustawienia nie można wyświetlić.';es_ES = 'Esta configuración no puede ser vista.';es_CO = 'Esta configuración no puede ser vista.';tr = 'Bu ayar görüntülenemiyor.';it = 'Questa impostazione non può essere visualizzato.';de = 'Diese Einstellung kann nicht angezeigt werden.'"));
		Return;
		
	ElsIf ValueTreeItem.Name = "OtherSettings" Then
		
		If ValueTreeItem.CurrentData.Type = "PersonalSettings"
			AND PersonalSettingsFormName <> "" Then
			OpenForm(PersonalSettingsFormName);
			Return;
		EndIf;
		
		ShowMessageBox(,NStr("ru = 'Данную настройку невозможно просмотреть.'; en = 'This setting cannot be viewed.'; pl = 'Tego ustawienia nie można wyświetlić.';es_ES = 'Esta configuración no puede ser vista.';es_CO = 'Esta configuración no puede ser vista.';tr = 'Bu ayar görüntülenemiyor.';it = 'Questa impostazione non può essere visualizzato.';de = 'Diese Einstellung kann nicht angezeigt werden.'"));
		Return;
		
	EndIf;
	
	ShowMessageBox(,NStr("ru = 'Выберите настройку для просмотра.'; en = 'Select a setting to view.'; pl = 'Wybierz ustawienie do wyświetlania.';es_ES = 'Seleccionar una configuración para ver.';es_CO = 'Seleccionar una configuración para ver.';tr = 'Görüntülemek için bir ayar seçin.';it = 'Selezionate un''impostazione da visualizzare.';de = 'Wählen Sie eine Einstellung zum Anzeigen aus.'"));
	
EndProcedure

// Generates a message to display after settings are copied.
//
// Parameters:
//  SettingPresentation - String - a setting name. It is used when a single setting is copied.
//  SettingsCount - Number - settings count. It is used when multiple settings are copied.
//  SettingsCopiedToNote - String - to whom settings are copied.
//
// Returns:
//  String - a note text when copying settings.
//
Function GenerateNoteOnCopy(SettingPresentation, SettingsCount, SettingsCopiedToNote) Export
	
	If SettingsCount = 1 Then
		
		If StrLen(SettingPresentation) > 24 Then
			SettingPresentation = Left(SettingPresentation, 24) + "...";
		EndIf;
		
		NotificationComment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '""%1"" скопирована %2'; en = '""%1"" copied to %2.'; pl = '""%1"" skopiowana %2';es_ES = '""%1"" está copiado %2';es_CO = '""%1"" está copiado %2';tr = '""%1"" kopyalandı %2';it = '%1 copiate in %2';de = '""%1"" wird kopiert %2'"),
			SettingPresentation,
			SettingsCopiedToNote);
	Else
		SubjectInWords = Format(SettingsCount, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(SettingsCount,
				"", NStr("ru = 'настройка,настройки,настроек,,,,,,0'; en = 'setting,settings,,,0'; pl = 'ustawienia,ustawienia,,,0';es_ES = 'ajuste,ajustes,,,0';es_CO = 'ajuste,ajustes,,,0';tr = 'ayar, ayarlar, ayarlar,,,,,,0';it = 'impostazione,impostazioni,,,0';de = 'Einstellung, Einstellungen, Einstellungen,,,,,,0'"));
		
		NotificationComment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Скопировано %1 %2'; en = '%1 copied to %2.'; pl = 'Skopiowano %1 %2';es_ES = 'Copiado %1 %2';es_CO = 'Copiado %1 %2';tr = 'Kopyalandı %1 %2';it = '%1 copiate in %2';de = 'Kopiert %1 %2'"),
			SubjectInWords,
			SettingsCopiedToNote);
	EndIf;
	
	Return NotificationComment;
	
EndFunction

// Generates a string that describes the destination users.
//
// Parameters:
//  UsersCount - Number - used if value is greater than 1.
//  User - String - a user name. It is used if the number of users is 1.
//                            
//
// Returns:
//  String - a note about the target user.
//
Function UsersNote(UsersCount, User) Export
	
	If UsersCount = 1 Then
		SettingsCopiedToNote = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'пользователю ""%1""'; en = 'user ""%1""'; pl = 'użytkownik ""%1""';es_ES = 'usuario ""%1""';es_CO = 'usuario ""%1""';tr = 'kullanıcı ""%1""';it = 'Utente""%1""';de = 'Benutzer ""%1""'"), User);
	Else
		SettingsCopiedToNote = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1 пользователям'; en = '%1 users.'; pl = '%1 użytkowników';es_ES = '%1 usuarios';es_CO = '%1 usuarios';tr = '%1 Kullanıcılar';it = '%1 utenti';de = '%1 Benutzer'"), UsersCount);
	EndIf;
	
	Return SettingsCopiedToNote;
	
EndFunction

#EndRegion
