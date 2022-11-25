
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	UseExternalUsers = GetFunctionalOption("UseExternalUsers");
	UsersToClearSettings = New Structure;
	
	UsersToClearSettingsRadioButtons = "ToSelectedUsers";
	SettingsToClearRadioButton   = "ClearAll";
	ClearSettingsSelectionHistory     = True;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("UserSelection") Then
		
		If UsersToClearSettings <> Undefined Then
			Items.SelectSettings.Title = NStr("ru='Выбрать'; en = 'Select'; pl = 'Wybierz';es_ES = 'Seleccionar';es_CO = 'Seleccionar';tr = 'Seç';it = 'Seleziona';de = 'Wählen'");
			SelectedSettings = Undefined;
			SettingsCount = Undefined;
		EndIf;
			
		UsersToClearSettings = New Structure("UsersArray", Parameter.UsersDestination);
		
		UsersCount = Parameter.UsersDestination.Count();
		If UsersCount = 1 Then
			Items.SelectUsers.Title = String(Parameter.UsersDestination[0]);
			Items.SettingsToClearGroup.Enabled = True;
		ElsIf UsersCount > 1 Then
			NumberAndSubject = Format(UsersCount, "NFD=0") + " "
				+ UsersInternalClientServer.IntegerSubject(UsersCount,
					"", NStr("ru = 'пользователь,пользователя,пользователей,,,,,,0'; en = 'user, users,,,0'; pl = 'użytkownik, użytkownicy,,,0';es_ES = 'usuario, usuarios,,,0';es_CO = 'usuario, usuarios,,,0';tr = 'kullanıcı, kullanıcılar, kullanıcılar,,,,,,0';it = 'utente, utenti,,,0';de = 'Benutzer, Benutzer, Benutzer,,,,,,0'"));
			Items.SelectUsers.Title = NumberAndSubject;
			SettingsToClearRadioButton = "ClearAll";
		EndIf;
		Items.SelectUsers.ToolTip = "";
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WhoseSettingsToClearRadioButtonOnChange(Item)
	
	If SettingsToClearRadioButton = "ToSelectedUsers"
		AND UsersCount > 1
		Or UsersToClearSettingsRadioButtons = "AllUsers" Then
		SettingsToClearRadioButton = "ClearAll";
	EndIf;
	
	If UsersToClearSettingsRadioButtons = "ToSelectedUsers"
		AND UsersCount = 1
		Or UsersToClearSettingsRadioButtons = "AllUsers" Then
		Items.SettingsToClearGroup.Enabled = True;
	Else
		Items.SettingsToClearGroup.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsToClearRadioButtonOnChange(Item)
	
	If UsersToClearSettingsRadioButtons = "ToSelectedUsers"
		AND UsersCount > 1 
		Or UsersToClearSettingsRadioButtons = "AllUsers" Then
		SettingsToClearRadioButton = "ClearAll";
		Items.SelectSettings.Enabled = False;
		ShowMessageBox(,NStr("ru = 'Очистка отдельных настроек доступна только при выборе одного пользователя.'; en = 'Clearing individual settings is only available if you select a single user.'; pl = 'Czyszczenie oddzielnych ustawień jest dostępne tylko po wybraniu jednego użytkownika.';es_ES = 'Eliminación de las configuraciones separadas está disponible solo cuando un usuario está seleccionado.';es_CO = 'Eliminación de las configuraciones separadas está disponible solo cuando un usuario está seleccionado.';tr = 'Ayrı ayarların temizlenmesi sadece bir kullanıcı seçildiğinde kullanılabilir.';it = 'Cancellazione di impostazioni personalizzate è disponibile solo se si seleziona un singolo utente.';de = 'Die Bereinigung separater Einstellungen ist nur verfügbar, wenn ein Benutzer ausgewählt ist.'"));
	ElsIf SettingsToClearRadioButton = "ClearAll" Then
		Items.SelectSettings.Enabled = False;
	Else
		Items.SelectSettings.Enabled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseUsersClick(Item)
	
	If UseExternalUsers Then
		UsersTypeSelection = New ValueList;
		UsersTypeSelection.Add("ExternalUsers", NStr("ru = 'Внешние пользователи'; en = 'External users'; pl = 'Użytkownicy zewnętrzni';es_ES = 'Usuarios externos';es_CO = 'Usuarios externos';tr = 'Harici kullanıcılar';it = 'Utenti esterni';de = 'Externe Benutzer'"));
		UsersTypeSelection.Add("Users",        NStr("ru = 'Пользователи'; en = 'Users'; pl = 'Użytkownicy';es_ES = 'Usuarios';es_CO = 'Usuarios';tr = 'Kullanıcılar';it = 'Utenti';de = 'Benutzer'"));
		
		Notification = New NotifyDescription("SelectUsersClickSelectItem", ThisObject);
		UsersTypeSelection.ShowChooseItem(Notification);
		Return;
	EndIf;
	
	OpenUserSelectionForm(PredefinedValue("Catalog.Users.EmptyRef"));
	
EndProcedure

&AtClient
Procedure SelectSettings(Item)
	
	If UsersCount = 1 Then
		UserRef = UsersToClearSettings.UsersArray[0];
		FormParameters = New Structure("User, SettingsOperation, ClearSettingsSelectionHistory",
			UserRef, "Clearing", ClearSettingsSelectionHistory);
		OpenForm("DataProcessor.UsersSettings.Form.SettingsChoice", FormParameters, ThisObject,,,,
			New NotifyDescription("SelectSettingsAfterChoice", ThisObject));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Clear(Command)
	
	ClearMessages();
	SettingsClearing();
	
EndProcedure

&AtClient
Procedure ClearAndClose(Command)
	
	ClearMessages();
	SettingsCleared = SettingsClearing();
	If SettingsCleared Then
		CommonClient.RefreshApplicationInterface();
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectUsersClickSelectItem(SelectedOption, AdditionalParameters) Export
	
	If SelectedOption = Undefined Then
		Return;
	EndIf;
	
	If SelectedOption.Value = "Users" Then
		User = PredefinedValue("Catalog.Users.EmptyRef");
		
	ElsIf SelectedOption.Value = "ExternalUsers" Then
		User = PredefinedValue("Catalog.ExternalUsers.EmptyRef");
	EndIf;
	
	OpenUserSelectionForm(User);
	
EndProcedure

&AtClient
Procedure OpenUserSelectionForm(User)
	
	SelectedUsers = Undefined;
	UsersToClearSettings.Property("UsersArray", SelectedUsers);
	
	FormParameters = New Structure;
	FormParameters.Insert("User",          User);
	FormParameters.Insert("ActionType",           "Clearing");
	FormParameters.Insert("SelectedUsers", SelectedUsers);
	
	OpenForm("DataProcessor.UsersSettings.Form.SelectUsers", FormParameters);
	
EndProcedure

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
Function SettingsClearing()
	
	If UsersToClearSettingsRadioButtons = "ToSelectedUsers"
		AND UsersCount = 0 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Выберите пользователя или пользователей,
				|которым необходимо очистить настройки.'; 
				|en = 'Select the user or users
				|whose settings you want to clear.'; 
				|pl = 'Wybierz użytkownika lub użytkowników,
				|ustawienia których należy usunąć.';
				|es_ES = 'Seleccionar el usuario o usuarios
				|para los cuales es necesario eliminar los ajustes.';
				|es_CO = 'Seleccionar el usuario o usuarios
				|para los cuales es necesario eliminar los ajustes.';
				|tr = 'Ayarları temizlemek için 
				|gerekli olan kullanıcıyı veya kullanıcıları seçin.';
				|it = 'Seleziona l''utente o utenti
				|le cui impostazioni vuoi cancellare.';
				|de = 'Wählen Sie den oder die Benutzer aus,
				|die die Einstellungen löschen möchten.'"), , "Source");
		Return False;
	EndIf;
	
	If UsersToClearSettingsRadioButtons = "ToSelectedUsers" Then
			
		If UsersCount = 1 Then
			SettingsClearedForNote = NStr("ru = 'пользователя ""%1""'; en = 'user ""%1.""'; pl = 'użytkownik ""%1""';es_ES = 'usuario ""%1""';es_CO = 'usuario ""%1""';tr = 'kullanıcı ""%1""';it = 'Utente""%1""';de = 'Benutzer ""%1""'");
			SettingsClearedForNote = StringFunctionsClientServer.SubstituteParametersToString(
				SettingsClearedForNote, UsersToClearSettings.UsersArray[0]);
		Else
			SettingsClearedForNote = NStr("ru = '%1 пользователям'; en = '%1 users.'; pl = '%1 użytkowników';es_ES = '%1 usuarios';es_CO = '%1 usuarios';tr = '%1 Kullanıcılar';it = '%1 utenti';de = '%1 Benutzer'");
			SettingsClearedForNote = StringFunctionsClientServer.SubstituteParametersToString(SettingsClearedForNote, UsersCount);
		EndIf;
		
	Else
		SettingsClearedForNote = NStr("ru = 'всем пользователям'; en = 'all users.'; pl = 'do wszystkich użytkowników';es_ES = 'para todos los usuarios';es_CO = 'para todos los usuarios';tr = 'tüm kullanıcılar için';it = 'tutti gli utenti.';de = 'allen Benutzern'");
	EndIf;
	
	If SettingsToClearRadioButton = "CertainSettings"
		AND SettingsCount = 0 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Выберите настройки, которые необходимо очистить.'; en = 'Select the settings that you want to clear.'; pl = 'Wybierz ustawienia do oczyszczenia.';es_ES = 'Seleccionar las configuraciones para eliminar.';es_CO = 'Seleccionar las configuraciones para eliminar.';tr = 'Temizlenecek ayarları seçin.';it = 'Selezionare le impostazioni da cancellare.';de = 'Wählen Sie die Einstellungen, die gelöscht werden sollen.'"), , "SettingsToClearRadioButton");
		Return False;
	EndIf;
	
	If SettingsToClearRadioButton = "CertainSettings" Then
		ClearSelectedSettings();
		
		If SettingsCount = 1 Then
			
			If StrLen(SettingPresentation) > 24 Then
				SettingPresentation = Left(SettingPresentation, 24) + "...";
			EndIf;
			
			NoteText = NStr("ru = '""%1"" очищена у %2'; en = '""%1"" is cleared for %2'; pl = '""%1"" została oczyszczona dla %2';es_ES = '""%1"" está eliminado para %2';es_CO = '""%1"" está eliminado para %2';tr = '""%1"" %2 için temizlendi';it = '""%1"" cancellato per %2';de = '""%1"" ist verrechnet für %2'");
			NoteText = StringFunctionsClientServer.SubstituteParametersToString(NoteText, SettingPresentation, SettingsClearedForNote);
			
		Else
			SubjectInWords = Format(SettingsCount, "NFD=0") + " "
				+ UsersInternalClientServer.IntegerSubject(SettingsCount,
					"", NStr("ru = 'настройка,настройки,настроек,,,,,,0'; en = 'setting,settings,,,0'; pl = 'ustawienia,ustawienia,,,0';es_ES = 'ajuste,ajustes,,,0';es_CO = 'ajuste,ajustes,,,0';tr = 'ayar, ayarlar, ayarlar,,,,,,0';it = 'impostazione,impostazioni,,,0';de = 'Einstellung, Einstellungen, Einstellungen,,,,,,0'"));
			
			NoteText = NStr("ru = 'Очищено %1 у %2'; en = '%1 cleared for %2'; pl = '%1 jest oczyszczony dla %2';es_ES = '%1 está eliminado para %2';es_CO = '%1 está eliminado para %2';tr = '%1, %2 için temizlendi';it = '%1 annullata per %2';de = '%1 ist verrechnet für %2'");
			NoteText = StringFunctionsClientServer.SubstituteParametersToString(NoteText, SubjectInWords, SettingsClearedForNote);
		EndIf;
		
		ShowUserNotification(NStr("ru = 'Очистка настроек'; en = 'Clear settings'; pl = 'Oczyść ustawienia';es_ES = 'Eliminar configuraciones';es_CO = 'Eliminar configuraciones';tr = 'Temizleme ayarları';it = 'Cancellare impostazioni';de = 'Einstellungen löschen'"), , NoteText, PictureLib.Information32);
	ElsIf SettingsToClearRadioButton = "ClearAll" Then
		ClearAllSettings();
		
		NoteText = NStr("ru = 'Очищены все настройки %1'; en = 'All settings are cleared for %1'; pl = 'Wszystkie ustawienia %1 zostały oczyszczone';es_ES = 'Todas las configuraciones %1 están eliminadas';es_CO = 'Todas las configuraciones %1 están eliminadas';tr = 'Tüm ayarlar %1 temizlendi';it = 'Cancellate tutte le impostazioni %1';de = 'Alle Einstellungen %1 werden gelöscht'");
		NoteText = StringFunctionsClientServer.SubstituteParametersToString(NoteText, SettingsClearedForNote);
		ShowUserNotification(NStr("ru = 'Очистка настроек'; en = 'Clear settings'; pl = 'Oczyść ustawienia';es_ES = 'Eliminar configuraciones';es_CO = 'Eliminar configuraciones';tr = 'Temizleme ayarları';it = 'Cancellare impostazioni';de = 'Einstellungen löschen'"), , NoteText, PictureLib.Information32);
	EndIf;
	
	SettingsCount = 0;
	Items.SelectSettings.Title = NStr("ru='Выбрать'; en = 'Select'; pl = 'Wybierz';es_ES = 'Seleccionar';es_CO = 'Seleccionar';tr = 'Seç';it = 'Seleziona';de = 'Wählen'");
	Return True;
	
EndFunction

&AtServer
Procedure ClearSelectedSettings()
	
	Source = UsersToClearSettings.UsersArray[0];
	User = DataProcessors.UsersSettings.IBUserName(Source);
	UserInfo = New Structure;
	UserInfo.Insert("UserRef", Source);
	UserInfo.Insert("InfobaseUserName", User);
	
	If SelectedSettings.ReportSettings.Count() > 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(
			UserInfo, SelectedSettings.ReportSettings, "ReportsUserSettingsStorage");
		
		DataProcessors.UsersSettings.DeleteReportOptions(
			SelectedSettings.SelectedReportsOptions, SelectedSettings.ReportOptionTable, User);
	EndIf;
	
	If SelectedSettings.Interface.Count() > 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(
			UserInfo, SelectedSettings.Interface, "SystemSettingsStorage");
	EndIf;
	
	If SelectedSettings.OtherSettings.Count() > 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(
			UserInfo, SelectedSettings.OtherSettings, "SystemSettingsStorage");
	EndIf;
	
	If SelectedSettings.PersonalSettings.Count() > 0 Then
		DataProcessors.UsersSettings.DeleteSelectedSettings(
			UserInfo, SelectedSettings.PersonalSettings, "CommonSettingsStorage");
	EndIf;
	
	For Each OtherUserSettings In SelectedSettings.OtherUserSettings Do
		UsersInternal.OnDeleteOtherUserSettings(
			UserInfo, OtherUserSettings);
	EndDo;
	
EndProcedure

&AtServer
Procedure ClearAllSettings()
	
	SettingsArray = New Array;
	SettingsArray.Add("ReportSettings");
	SettingsArray.Add("InterfaceSettings");
	SettingsArray.Add("PersonalSettings");
	SettingsArray.Add("FormData");
	SettingsArray.Add("Favorites");
	SettingsArray.Add("PrintSettings");
	SettingsArray.Add("OtherUserSettings");
	
	If UsersToClearSettingsRadioButtons = "ToSelectedUsers" Then
		Sources = UsersToClearSettings.UsersArray;
	Else
		Sources = New Array;
		UsersTable = New ValueTable;
		UsersTable.Columns.Add("User");
		// Getting the list of all users.
		UsersTable = DataProcessors.UsersSettings.UsersToCopy("", UsersTable, False, True);
		
		For Each TableRow In UsersTable Do
			Sources.Add(TableRow.User);
		EndDo;
		
	EndIf;
	
	DataProcessors.UsersSettings.DeleteUserSettings(SettingsArray, Sources);
	
EndProcedure

#EndRegion
