
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	CopySettingsToRadioButtons = "SelectedUsers";
	SettingsToCopyRadioButton = "CopyAllSettings";
	FormOpeningMode = Parameters.FormOpeningMode;
	
	SettingsRecipientsUsers = New Structure;
	If Parameters.User <> Undefined Then
		UsersArray = New Array;
		UsersArray.Add(Parameters.User);
		SettingsRecipientsUsers.Insert("UsersArray", UsersArray);
		Items.SelectUsers.Title = String(Parameters.User);
		UsersCount = 1;
		PassedUserType = TypeOf(Parameters.User);
		Items.CopyToGroup.Enabled = False;
	Else
		UserRef = Users.CurrentUser();
	EndIf;
	
	If UserRef = Undefined Then
		Items.SettingsToCopyGroup.Enabled = False;
	EndIf;
	
	ClearSettingsSelectionHistory = True;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("UserSelection") Then
		SettingsRecipientsUsers = New Structure("UsersArray", Parameter.UsersDestination);
		
		UsersCount = Parameter.UsersDestination.Count();
		If UsersCount = 1 Then
			Items.SelectUsers.Title = String(Parameter.UsersDestination[0]);
		ElsIf UsersCount > 1 Then
			NumberAndSubject = Format(UsersCount, "NFD=0") + " "
				+ UsersInternalClientServer.IntegerSubject(UsersCount,
					"", NStr("ru = 'пользователь,пользователя,пользователей,,,,,,0'; en = 'user, users,,,0'; pl = 'użytkownik, użytkownicy,,,0';es_ES = 'usuario, usuarios,,,0';es_CO = 'usuario, usuarios,,,0';tr = 'kullanıcı, kullanıcılar, kullanıcılar,,,,,,0';it = 'utente, utenti,,,0';de = 'Benutzer, Benutzer, Benutzer,,,,,,0'"));
			Items.SelectUsers.Title = NumberAndSubject;
		EndIf;
		Items.SelectUsers.ToolTip = "";
		
	ElsIf Upper(EventName) = Upper("CopySettingsToActiveUsers") Then
		
		CopySettings(Parameter.Action);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedUsersType = Undefined;
	
	If UsersCount <> 0 Then
		UsersToHide = New ValueList;
		UsersToHide.LoadValues(SettingsRecipientsUsers.UsersArray);
	EndIf;
	
	FilterParameters = New Structure(
		"ChoiceMode, UsersToHide",
		True, UsersToHide);
	
	If PassedUserType = Undefined Then
		
		If UseExternalUsers Then
			UsersTypeSelection = New ValueList;
			UsersTypeSelection.Add("ExternalUsers", NStr("ru = 'Внешние пользователи'; en = 'External users'; pl = 'Użytkownicy zewnętrzni';es_ES = 'Usuarios externos';es_CO = 'Usuarios externos';tr = 'Harici kullanıcılar';it = 'Utenti esterni';de = 'Externe Benutzer'"));
			UsersTypeSelection.Add("Users", NStr("ru = 'Пользователи'; en = 'Users'; pl = 'Użytkownicy';es_ES = 'Usuarios';es_CO = 'Usuarios';tr = 'Kullanıcılar';it = 'Utenti';de = 'Benutzer'"));
			
			Notification = New NotifyDescription("UserStartChoiceCompletion", ThisObject, FilterParameters);
			UsersTypeSelection.ShowChooseItem(Notification);
			Return;
		Else
			SelectedUsersType = "Users";
		EndIf;
		
	EndIf;
	
	OpenUserSelectionForm(SelectedUsersType, FilterParameters);
	
EndProcedure

&AtClient
Procedure UserStartChoiceCompletion(SelectedOption, FilterParameters) Export
	
	If SelectedOption = Undefined Then
		Return;
	EndIf;
	SelectedUsersType = SelectedOption.Value;
	
	OpenUserSelectionForm(SelectedUsersType, FilterParameters);
	
EndProcedure

&AtClient
Procedure OpenUserSelectionForm(SelectedUsersType, FilterParameters)
	
	If SelectedUsersType = "Users"
		Or PassedUserType = Type("CatalogRef.Users") Then
		OpenForm("Catalog.Users.Form.ListForm", FilterParameters, Items.UserRef);
	ElsIf SelectedUsersType = "ExternalUsers"
		Or PassedUserType = Type("CatalogRef.ExternalUsers") Then
		OpenForm("Catalog.ExternalUsers.Form.ListForm", FilterParameters, Items.UserRef);
	EndIf;
	UserRefOld = UserRef;
	
EndProcedure

&AtClient
Procedure UserRefOnChange(Item)
	
	If UserRef <> Undefined
		AND IBUserName(UserRef) = Undefined Then
		ShowMessageBox(,NStr("ru = 'У выбранного пользователя нет настроек, которые можно было бы
				|скопировать, выберите другого пользователя.'; 
				|en = 'The selected user does not have any settings to copy.
				|Please select another user.'; 
				|pl = 'Wybrany użytkownik nie ma żadnych ustawień, które można 
				|skopiować, wybierz innego użytkownika.';
				|es_ES = 'El usuario seleccionado no tiene ajustes que se pueda
				|copiar, seleccione otro usuario.';
				|es_CO = 'El usuario seleccionado no tiene ajustes que se pueda
				|copiar, seleccione otro usuario.';
				|tr = 'Seçilen kullanıcı, 
				|başka bir kullanıcı seçmek için bir ayara sahip değildir.';
				|it = 'L''utente selezionato non ha alcuna impostazione da copiare.
				|Si prega di selezionare un altro utente.';
				|de = 'Der ausgewählte Benutzer hat keine Einstellungen, die
				|kopiert werden können, wählen Sie einen anderen Benutzer aus.'"));
		UserRef = UserRefOld;
		Return;
	EndIf;
	
	If UserRef <> Undefined
		AND SettingsRecipientsUsers.Property("UsersArray") Then
		
		If SettingsRecipientsUsers.UsersArray.Find(UserRef) <> Undefined Then
			ShowMessageBox(,NStr("ru = 'Нельзя копировать настройки пользователя самому себе,
					|выберите другого пользователя.'; 
					|en = 'Cannot copy user settings to that user.
					|Please select a different user.'; 
					|pl = 'Nie możesz skopiować ustawień użytkownika do siebie, 
					|wybierz innego użytkownika.';
					|es_ES = 'No se puede copiar los ajustes del usuario para sí mismo,
					|seleccione otro usuario.';
					|es_CO = 'No se puede copiar los ajustes del usuario para sí mismo,
					|seleccione otro usuario.';
					|tr = 'Kullanıcı ayarları bu kullanıcıya kopyalanamaz.
					|Lütfen, başka bir kullanıcı seçin.';
					|it = 'Impossibile copiare le impostazioni utenti a quell''utente.
					|Si prega di selezionarne un altro.';
					|de = 'Sie können die Einstellungen eines Benutzers nicht auf sich selbst kopieren,
					|wählen Sie einen anderen Benutzer aus.'"));
				UserRef = UserRefOld;
				Return;
		EndIf;
		
	EndIf;
	
	Items.SettingsToCopyGroup.Enabled = UserRef <> Undefined;
	
	SelectedSettings = Undefined;
	SettingsCount = 0;
	Items.SelectSettings.Title = NStr("ru='Выбрать'; en = 'Select'; pl = 'Wybierz';es_ES = 'Seleccionar';es_CO = 'Seleccionar';tr = 'Seç';it = 'Seleziona';de = 'Wählen'");
	
EndProcedure

&AtServer
Function IBUserName(UserRef)
	
	Return DataProcessors.UsersSettings.IBUserName(UserRef);
	
EndFunction

&AtClient
Procedure SelectSettings(Item)
	
	FormParameters = New Structure("User, SettingsOperation, ClearSettingsSelectionHistory",
		UserRef, "Copy", ClearSettingsSelectionHistory);
	OpenForm("DataProcessor.UsersSettings.Form.SettingsChoice", FormParameters, ThisObject,,,,
		New NotifyDescription("SelectSettingsAfterChoice", ThisObject));
	
EndProcedure

&AtClient
Procedure SelectUsers(Item)
	
	SelectedUsers = Undefined;
	SettingsRecipientsUsers.Property("UsersArray", SelectedUsers);
	
	FormParameters = New Structure;
	FormParameters.Insert("User",          UserRef);
	FormParameters.Insert("ActionType",           "Copy");
	FormParameters.Insert("SelectedUsers", SelectedUsers);
	
	OpenForm("DataProcessor.UsersSettings.Form.SelectUsers", FormParameters);
	
EndProcedure

&AtClient
Procedure CopySettingsToRadioButtonOnChange(Item)
	
	If CopySettingsToRadioButtons = "SelectedUsers" Then
		Items.SelectUsers.Enabled = True;
	Else
		Items.SelectUsers.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsToCopyRadioButtonOnChange(Item)
	
	If SettingsToCopyRadioButton = "CopySelectedSettings" Then
		Items.SelectSettings.Enabled = True;
	Else
		Items.SelectSettings.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Copy(Command)
	
	ClearMessages();
	
	If UserRef = Undefined Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Выберите пользователя, чьи настройки необходимо скопировать.'; en = 'Select the source user.'; pl = 'Wybierz użytkownika, którego ustawienia powinny zostać skopiowane';es_ES = 'Seleccionar un usuario cuyas configuraciones tienen que copiarse.';es_CO = 'Seleccionar un usuario cuyas configuraciones tienen que copiarse.';tr = 'Ayarları kopyalanması gereken bir kullanıcı seçin.';it = 'Seleziona l''utente fonte.';de = 'Wählen Sie einen Benutzer aus, dessen Einstellungen kopiert werden sollen.'"), , "UserRef");
		Return;
	EndIf;
	
	If UsersCount = 0 AND CopySettingsToRadioButtons <> "AllUsers" Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Выберите одного или несколько пользователей, которым необходимо скопировать настройки.'; en = 'Select one or several destination users.'; pl = 'Wybierz jednego lub wielu użytkowników, ustawienia których powinny zostać skopiowane.';es_ES = 'Seleccionar uno o usuarios múltiples cuyas configuraciones tienen que copiarse.';es_CO = 'Seleccionar uno o usuarios múltiples cuyas configuraciones tienen que copiarse.';tr = 'Ayarları kopyalanması gereken bir veya daha fazla kullanıcı seçin.';it = 'Seleziona uno più utenti di destinazione.';de = 'Wählen Sie einen oder mehrere Benutzer aus, die kopiert werden sollen.'"), , "Destination");
		Return;
	EndIf;
	
	If SettingsToCopyRadioButton = "CopySelectedSettings" AND SettingsCount = 0 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Выберите настройки, которые необходимо скопировать.'; en = 'Select the settings to copy.'; pl = 'Wybierz ustawienia, które powinni zostać skopiowane.';es_ES = 'Seleccionar las configuraciones para copiar.';es_CO = 'Seleccionar las configuraciones para copiar.';tr = 'Kopyalanacak ayarları seçin.';it = 'Seleziona le impostazioni da copiare';de = 'Wählen Sie Einstellungen, die kopiert werden sollen.'"), , "SettingsToCopyRadioButton");
		Return;
	EndIf;
	
	// If appearance settings are copied or all settings are copied, check whether they are applicable 
	// to the destination user and display the result (a message that settings are copied or a message explaining why they are not copied). If they work, display a message about it.
	OpenFormsToCopy = OpenFormsToCopy();
	CheckActiveUsers();
	If CheckResult = "HasActiveUsersRecipients"
		Or ValueIsFilled(OpenFormsToCopy) Then
		
		If SettingsToCopyRadioButton = "CopyAllSettings" 
			Or (SettingsToCopyRadioButton = "CopySelectedSettings"
			AND SelectedSettings.Interface.Count() <> 0) Then
			
			FormParameters = New Structure;
			FormParameters.Insert("Action", Command.Name);
			FormParameters.Insert("OpenFormsToCopy", OpenFormsToCopy);
			FormParameters.Insert("HasActiveUsersRecipients", CheckResult = "HasActiveUsersRecipients");
			OpenForm("DataProcessor.UsersSettings.Form.CopySettingsWarning", FormParameters);
			Return;
			
		EndIf;
		
	EndIf;
	CopySettings(Command.Name);
	
EndProcedure

&AtClient
Function OpenFormsToCopy()
	
	If SelectedSettings = Undefined Then
		Return "";
	EndIf;
	Settings = SelectedSettings.Interface;
	
	OpenFormsRow          = "";
	AllSettingsToCopyRow = "";
	For Each FormSettings In Settings Do
		For Each FormSettingsItem In FormSettings Do
			AllSettingsToCopyRow = AllSettingsToCopyRow + Chars.LF + FormSettingsItem.Value;
		EndDo;
	EndDo;
	
	OpenWindows = GetWindows();
	For Each OpenWindow In OpenWindows Do
		If OpenWindow.HomePage Or OpenWindow.IsMain Then
			Continue;
		EndIf;
		Content    = OpenWindow.Content;
		DefaultForm = Content.Get(0);
		
		OpenFormName = DefaultForm.FormName;
		If StrFind(OpenFormName, "DataProcessor.UsersSettings") > 0
			Or StrFind(OpenFormName, ".SSLAdministrationPanel.") > 0 Then
			Continue;
		EndIf;
		
		If StrFind(AllSettingsToCopyRow, OpenFormName) > 0 Then
			OpenFormsRow = ?(ValueIsFilled(OpenFormsRow),
				OpenFormsRow + Chars.LF + "- " + OpenWindow.Caption,
				NStr("ru = 'Открытые окна'; en = 'Open windows'; pl = 'Otwieranie okna';es_ES = 'Ventanas abiertas';es_CO = 'Ventanas abiertas';tr = 'Açık pencereler';it = 'Apri finestre';de = 'Fenster öffnen'") + ":" + Chars.LF + "- " + OpenWindow.Caption)
		EndIf;
		
	EndDo;
	
	Return OpenFormsRow;
	
EndFunction

#EndRegion

#Region Private

&AtClient
Procedure SelectSettingsAfterChoice(Parameter, Context) Export
	
	If TypeOf(Parameter) <> Type("Structure") Then
		Return;
	EndIf;
	
	SelectedSettings = New Structure;
	SelectedSettings.Insert("Interface",       Parameter.Interface);
	SelectedSettings.Insert("ReportSettings", Parameter.ReportSettings);
	SelectedSettings.Insert("OtherSettings",  Parameter.OtherSettings);
	
	SelectedSettings.Insert("ReportOptionTable",  Parameter.ReportOptionTable);
	SelectedSettings.Insert("SelectedReportsOptions", Parameter.SelectedReportsOptions);
	
	SelectedSettings.Insert("PersonalSettings",           Parameter.PersonalSettings);
	SelectedSettings.Insert("OtherUserSettings", Parameter.OtherUserSettings);
	
	SettingsCount = Parameter.SettingsCount;
	
	If SettingsCount = 0 Then
		TitleText = NStr("ru='Выбрать'; en = 'Select'; pl = 'Wybierz';es_ES = 'Seleccionar';es_CO = 'Seleccionar';tr = 'Seç';it = 'Seleziona';de = 'Wählen'");
	ElsIf SettingsCount = 1 Then
		SettingPresentation = Parameter.SettingsPresentations[0];
		TitleText = SettingPresentation;
	Else
		TitleText = Format(SettingsCount, "NFD=0") + " "
			+ UsersInternalClientServer.IntegerSubject(SettingsCount,
				"", NStr("ru = 'настройка,настройки,настроек,,,,,,0'; en = 'setting,settings,,,0'; pl = 'ustawienia,ustawienia,,,0';es_ES = 'ajuste,ajustes,,,0';es_CO = 'ajuste,ajustes,,,0';tr = 'ayar, ayarlar, ayarlar,,,,,,0';it = 'impostazione,impostazioni,,,0';de = 'Einstellung, Einstellungen, Einstellungen,,,,,,0'"));
	EndIf;
	
	Items.SelectSettings.Title = TitleText;
	Items.SelectSettings.ToolTip = "";
	
EndProcedure

&AtClient
Procedure CopySettings(CommandName)
	
	If CopySettingsToRadioButtons = "SelectedUsers" Then
		
		SettingsCopiedToNote = UsersInternalClient.UsersNote(
			UsersCount, SettingsRecipientsUsers.UsersArray[0]);
	Else
		SettingsCopiedToNote = NStr("ru = 'всем пользователям'; en = 'all users.'; pl = 'do wszystkich użytkowników';es_ES = 'para todos los usuarios';es_CO = 'para todos los usuarios';tr = 'tüm kullanıcılar için';it = 'tutti gli utenti.';de = 'allen Benutzern'");
	EndIf;
	
	NotificationText    = NStr("ru = 'Копирование настроек'; en = 'Copy settings'; pl = 'Skopiuj ustawienia';es_ES = 'Copiar configuraciones';es_CO = 'Copiar configuraciones';tr = 'Ayarları kopyala';it = 'Copiare impostazioni';de = 'Einstellungen kopieren'");
	NotificationPicture = PictureLib.Information32;
	
	If SettingsToCopyRadioButton = "CopySelectedSettings" Then
		Report = Undefined;
		CopySelectedSettings(Report);
		
		If Report <> Undefined Then
			QuestionText = NStr("ru = 'Не все варианты отчетов и настройки были скопированы.'; en = 'Some report options and settings are not copied.'; pl = 'Nie wszystkie opcje i ustawienia raportu zostały skopiowane.';es_ES = 'No todas las opciones del informe y las configuraciones se han copiado.';es_CO = 'No todas las opciones del informe y las configuraciones se han copiado.';tr = 'Bazı rapor seçenekleri ve ayarları kopyalanmadı.';it = 'Alcune varianti di report e impostazioni non sono state copiate.';de = 'Nicht alle Berichtsoptionen und -einstellungen wurden kopiert.'");
			QuestionButtons = New ValueList;
			QuestionButtons.Add("Ok", NStr("ru = 'ОК'; en = 'OK'; pl = 'OK';es_ES = 'OK';es_CO = 'Ok';tr = 'Tamam';it = 'OK';de = 'Ok'"));
			QuestionButtons.Add("ShowReport", NStr("ru = 'Показать отчет'; en = 'View report'; pl = 'Pokaż sprawozdanie';es_ES = 'Mostrar el informe';es_CO = 'Mostrar el informe';tr = 'Raporu göster';it = 'Visualizza report';de = 'Bericht zeigen'"));
			
			Notification = New NotifyDescription("CopySettingsShowQueryBox", ThisObject, Report);
			ShowQueryBox(Notification, QuestionText, QuestionButtons,, QuestionButtons[0].Value);
			Return;
		EndIf;
			
		If Report = Undefined Then
			NotificationComment = UsersInternalClient.GenerateNoteOnCopy(
				SettingPresentation, SettingsCount, SettingsCopiedToNote);
			
			ShowUserNotification(NotificationText, , NotificationComment, NotificationPicture);
		EndIf;
	Else
		SettingsCopied = CopyingAllSettings();
		If Not SettingsCopied Then
			
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Настройки не были скопированы, так как у пользователя ""%1"" не было сохранено ни одной настройки.'; en = 'The settings were not copied because user ""%1"" does not have any saved settings.'; pl = 'Ustawienia nie zostały skopiowane, ponieważ użytkownik ""%1"" nie zapisał żadnych ustawień.';es_ES = 'Configuraciones no se han copiado porque el usuario ""%1"" no ha guardado ninguna configuración.';es_CO = 'Configuraciones no se han copiado porque el usuario ""%1"" no ha guardado ninguna configuración.';tr = '""%1"" kullanıcısının kayıtlı ayarları olmadığından ayarlar kopyalanmadı.';it = 'Le impostazioni non sono state copiate, poiché l''utente ""%1"" non ha salvato alcuna impostazione.';de = 'Einstellungen wurden nicht kopiert, da der Benutzer ""%1"" keine Einstellungen gespeichert hat.'"),
				String(UserRef)));
			Return;
		EndIf;
		
		NotificationComment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Скопированы все настройки %1'; en = 'All settings are copied to %1.'; pl = 'Wszystkie ustawienia zostały skopiowane %1';es_ES = 'Todas las configuraciones copiadas %1';es_CO = 'Todas las configuraciones copiadas %1';tr = 'Tüm ayarlar kopyalandı %1';it = 'Tutte le impostazioni sono copiate in %1.';de = 'Alle Einstellungen wurden kopiert %1'"), SettingsCopiedToNote);
		
		ShowUserNotification(NotificationText, , NotificationComment, NotificationPicture);
	EndIf;
	
	// If this is copying settings from another user, notifying the AppUserSettings form
	If FormOpeningMode = "CopyFrom" Then
		Notify("SettingsCopied", True);
	EndIf;
	
	If CommandName = "CopyAndClose" Then
		Close();
	EndIf;
	
	Return;
	
EndProcedure

&AtClient
Procedure CopySettingsShowQueryBox(Response, Report) Export
	
	If Response = "Ok" Then
		Return;
	Else
		Report.ShowGroups = True;
		Report.ShowGrid = False;
		Report.ShowHeaders = False;
		Report.Show();
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure CopySelectedSettings(Report)
	
	User = DataProcessors.UsersSettings.IBUserName(UserRef);
	
	If CopySettingsToRadioButtons = "SelectedUsers" Then
		Destinations = SettingsRecipientsUsers.UsersArray;
	ElsIf CopySettingsToRadioButtons = "AllUsers" Then
		Destinations = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		DataProcessors.UsersSettings.UsersToCopy(UserRef, UsersTable,
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow In UsersTable Do
			Destinations.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	NotCopiedReportSettings = New ValueTable;
	NotCopiedReportSettings.Columns.Add("User");
	NotCopiedReportSettings.Columns.Add("ReportsList", New TypeDescription("ValueList"));
	
	If SelectedSettings.ReportSettings.Count() > 0 Then
		
		DataProcessors.UsersSettings.CopyReportAndPersonalSettings(ReportsUserSettingsStorage,
			User, Destinations, SelectedSettings.ReportSettings, NotCopiedReportSettings);
		
		DataProcessors.UsersSettings.CopyReportOptions(
			SelectedSettings.SelectedReportsOptions, SelectedSettings.ReportOptionTable, User, Destinations);
	EndIf;
		
	If SelectedSettings.Interface.Count() > 0 Then
		DataProcessors.UsersSettings.CopyInterfaceSettings(User, Destinations, SelectedSettings.Interface);
	EndIf;
	
	If SelectedSettings.OtherSettings.Count() > 0 Then
		DataProcessors.UsersSettings.CopyInterfaceSettings(User, Destinations, SelectedSettings.OtherSettings);
	EndIf;
	
	If SelectedSettings.PersonalSettings.Count() > 0 Then
		DataProcessors.UsersSettings.CopyReportAndPersonalSettings(CommonSettingsStorage,
			User, Destinations, SelectedSettings.PersonalSettings);
	EndIf;
	
	For Each OtherUserSettingsItem In SelectedSettings.OtherUserSettings Do
		For Each CatalogUser In Destinations Do
			UserInfo = New Structure;
			UserInfo.Insert("UserRef", CatalogUser);
			UserInfo.Insert("InfobaseUserName", 
				DataProcessors.UsersSettings.IBUserName(CatalogUser));
			UsersInternal.OnSaveOtherUserSettings(
				UserInfo, OtherUserSettingsItem);
		EndDo;
	EndDo;
	
	If NotCopiedReportSettings.Count() <> 0 Then
		Report = DataProcessors.UsersSettings.CreateReportOnCopyingSettings(
			NotCopiedReportSettings);
	EndIf;
	
EndProcedure

&AtServer
Function CopyingAllSettings()
	
	User = DataProcessors.UsersSettings.IBUserName(UserRef);
	
	If CopySettingsToRadioButtons = "SelectedUsers" Then
		Destinations = SettingsRecipientsUsers.UsersArray;
	Else
		Destinations = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		UsersTable = DataProcessors.UsersSettings.UsersToCopy(UserRef, UsersTable, 
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow In UsersTable Do
			Destinations.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	SettingsToCopy = New Array;
	SettingsToCopy.Add("ReportSettings");
	SettingsToCopy.Add("InterfaceSettings");
	SettingsToCopy.Add("PersonalSettings");
	SettingsToCopy.Add("Favorites");
	SettingsToCopy.Add("PrintSettings");
	SettingsToCopy.Add("OtherUserSettings");
	
	SettingsCopied = DataProcessors.UsersSettings.
		CopyUsersSettings(UserRef, Destinations, SettingsToCopy);
		
	Return SettingsCopied;
	
EndFunction

&AtServer
Procedure CheckActiveUsers()
	
	CurrentUser = Users.CurrentUser();
	If SettingsRecipientsUsers.Property("UsersArray") Then
		UsersArray = SettingsRecipientsUsers.UsersArray;
	EndIf;
	
	If CopySettingsToRadioButtons = "AllUsers" Then
		
		UsersArray = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		UsersTable = DataProcessors.UsersSettings.UsersToCopy(UserRef, UsersTable, 
			TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		
		For Each TableRow In UsersTable Do
			UsersArray.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	If UsersArray.Count() = 1 
		AND UsersArray[0] = CurrentUser Then
		
		CheckResult = "CurrentUserRecipient";
		Return;
		
	EndIf;
		
	HasActiveUsersRecipients = False;
	Sessions = GetInfoBaseSessions();
	For Each Recipient In UsersArray Do
		If Recipient = CurrentUser Then
			CheckResult = "CurrentUserAmongRecipients";
			Return;
		EndIf;
		For Each Session In Sessions Do
			If Recipient.IBUserID = Session.User.UUID Then
				HasActiveUsersRecipients = True;
			EndIf;
		EndDo;
	EndDo;
	
	CheckResult = ?(HasActiveUsersRecipients, "HasActiveUsersRecipients", "");
	
EndProcedure

#EndRegion
