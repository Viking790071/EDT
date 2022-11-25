#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Receives configuration update settings from general settings storage.
Function GetSettingsStructureOfAssistant() Export
	
	Schedule = Undefined;
	Settings = Common.CommonSettingsStorageLoad("ConfigurationUpdate", "ConfigurationUpdateOptions");
	
	If Settings = Undefined Then
		OldSettingsCount = 0;
	ElsIf TypeOf(Settings) = Type("Structure") OR TypeOf(Settings) = Type("Map") Then
		OldSettingsCount = Settings.Count();
	Else
		OldSettingsCount = 0;
	EndIf;
	Settings = ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(Settings);
	// If new settings appeared, they should be saved.
	If Settings.Count() > OldSettingsCount Then
		SetPrivilegedMode(True);
		WriteStructureOfAssistantSettings(Settings);	
		SetPrivilegedMode(False);
	EndIf;
	// If schedule is saved in the early versions and the
	// UpdateUpdatePresenceCheckSchedule update handler has not worked, then...
	If Settings <> Undefined AND Settings.Property("ScheduleOfUpdateExistsCheck", Schedule) 
		AND TypeOf(Schedule) = Type("JobSchedule") Then
		Settings.ScheduleOfUpdateExistsCheck = CommonClientServer.ScheduleToStructure(Schedule);
	EndIf;
	Return Settings;
	
EndFunction

// Saves user authentication parameters (login and password) on 1C custom website.
//
// Parameters:
//     SavedParameters - Structure - saved values:
//         * Login  - String - Internet Support user login;
//         * Password - String - password of the online support user.
// 
Procedure SaveAuthenticationParametersOnSite(SavedParameters) Export
	
	CommonClientServer.Validate(True, 
		NStr("en = 'Invalid procedure call.'; ru = 'Недопустимый вызов процедуры.';pl = 'Nieprawidłowe wywołanie procedury.';es_ES = 'Llamada de procedimiento inválida.';es_CO = 'Llamada de procedimiento inválida.';tr = 'Geçersiz prosedür çağrısı.';it = 'Chiamata della procedura non valida.';de = 'Ungültiger Prozeduraufruf.'"), "AddressClassifierService.SaveAuthenticationParametersOnSite");
		
	If SavedParameters <> Undefined Then
		Common.CommonSettingsStorageSave("AuthenticationAtUsersWebsite", "UserCode", SavedParameters.Login);
		Common.CommonSettingsStorageSave("AuthenticationAtUsersWebsite", "Password", SavedParameters.Password);
	Else	
		Common.CommonSettingsStorageDelete("AuthenticationAtUsersWebsite", "UserCode", UserName());
		Common.CommonSettingsStorageDelete("AuthenticationAtUsersWebsite", "Password", UserName());
	EndIf;
			
EndProcedure

// Writes the settings of update assistant to common settings storage.
Procedure WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, MessagesForEventLogMonitor = Undefined) Export
	
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLogMonitor);
	
	Common.CommonSettingsStorageSave(
		"ConfigurationUpdate", 
		"ConfigurationUpdateOptions", 
		ConfigurationUpdateOptions);
		
	AuthenticationParameters = New Structure("Login,Password");
	ConfigurationUpdateOptions.Property("UpdateServerUserCode", AuthenticationParameters.Login);
	ConfigurationUpdateOptions.Property("UpdatesServerPassword", AuthenticationParameters.Password);
	DataProcessors.InstallUpdates.SaveAuthenticationParametersOnSite(AuthenticationParameters);
	
EndProcedure

// Returns event name for events log monitor record.
Function EventLogEvent() Export
	Return NStr("en = 'Update configuration'; ru = 'Обновление конфигурации';pl = 'Aktualizacja konfiguracji';es_ES = 'Actualizar la configuración';es_CO = 'Actualizar la configuración';tr = 'Yapılandırmayı güncelle';it = 'Aggiornamento di configurazione ';de = 'Update Konfiguration'", CommonClientServer.DefaultLanguageCode());
EndFunction

// Check whether application is run as external user and delete exception in this case.
//
// Parameters:
//  MessageText  - String - exception text. If it is
// not specified, text is used by default.
//
// Useful example:
//    AbortExecutionIfExternalUserIsAuthorized();
//    ... next is the code fragment that relies only on
// the execution from a "normal" user.
//
Procedure AbortExecuteIfExternalUserAuthorized(Val MessageText = "") Export
	
	SetPrivilegedMode(True);
	
	If UsersClientServer.IsExternalUserSession() Then
		
		ErrorMessage = MessageText;
		
		If IsBlankString(ErrorMessage) Then
			ErrorMessage = NStr("en = 'This operation is not available for external system user.'; ru = 'Данная операция не доступна внешнему пользователю системы.';pl = 'Ta operacja nie jest dostępna dla zewnętrznego użytkownika systemu.';es_ES = 'Esta operación no se encuentra disponible para el usuario del sistema externo.';es_CO = 'Esta operación no se encuentra disponible para el usuario del sistema externo.';tr = 'Bu işlem harici sistem kullanıcısı için mevcut değildir.';it = 'Questa operazione non è disponibile per l''utente sistema esterno.';de = 'Diese Operation ist für externe Systembenutzer nicht verfügbar.'");
		EndIf;
		
		Raise ErrorMessage;
		
	EndIf;
	
EndProcedure

// Clears all settings of the configuration update.
Procedure ResetStatusOfConfigurationUpdate() Export
	
	Constants.ConfigurationUpdateStatus.Set(New ValueStorage(Undefined));
	
EndProcedure

// It returns online support user login and password saved in the infobase.
//
// Returns:
//   Structure    - current value:
//     * Login     - String - Internet Support user login;
//     * Password    - String - password of the online support user.
//   Undefined - if the parameters have not been entered yet.
//
Function AuthenticationParametersOnSite() Export
	
	Result = New Structure("Login,Password");
	Result.Login = Common.CommonSettingsStorageLoad("AuthenticationAtUsersWebsite", "UserCode", "");
	Result.Password = Common.CommonSettingsStorageLoad("AuthenticationAtUsersWebsite", "Password", "");
	Return ?(Result.Login <> "", Result, Undefined);
	
EndFunction

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParameters(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable()
		OR CommonClientServer.IsLinuxClient() Then
		Return;
	EndIf;
	
	Parameters.Insert("NamesSubsystems",		StandardSubsystemsCached.SubsystemNames());
	Parameters.Insert("CanUseSeparatedData",	CommonCached.SeparatedDataUsageAvailable());
	Parameters.Insert("DataSeparationEnabled",	CommonCached.DataSeparationEnabled());
	
	Parameters.Insert("InterfaceOptions",		CommonCached.InterfaceOptions());
	
	AddCommonClientParameters(Parameters);
	
	Parameters.Insert("ConfigurationName",		Metadata.Name);
	Parameters.Insert("ConfigurationSynonym",	Metadata.Synonym);
	Parameters.Insert("ConfigurationVersion",	Metadata.Version);
	Parameters.Insert("DetailedInformation",	Metadata.DetailedInformation);
	Parameters.Insert("MainLanguageCode",		Metadata.DefaultLanguage.LanguageCode);
	
	Parameters.Insert("AskConfirmationOnExit",	StandardSubsystemsServer.AskConfirmationOnExit());
	
	// Parameters for external users connections.
	Parameters.Insert("UserInfo",			GetInformationAboutUser());
	Parameters.Insert("COMConnectorName",	CommonClientServer.COMConnectorName());
	
	SessionDate = CurrentSessionDate();
	UniversalSessionDate = ToUniversalTime(SessionDate, SessionTimeZone());
	// Write the server time for the subsequent its replacement for difference with the client.
	Parameters.Insert("SessionTimeOffset",			SessionDate);
	Parameters.Insert("AdjustmentToUniversalTime",	UniversalSessionDate - SessionDate);
	
	Parameters.Insert("InfobaseUserWithFullAccess", Users.IsFullUser());
	Parameters.Insert("IsTrainingPlatform", StandardSubsystemsServer.IsTrainingPlatform());
	
	Parameters.Insert("UpdateSettings", New FixedStructure(GetUpdateSettings()));

EndProcedure

// Fills in the parameters structure that are
// required for work of the client code during the configuration start and later when you work with it. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddCommonClientParameters(Parameters) 
	
	If Not Parameters.DataSeparationEnabled Or Parameters.CanUseSeparatedData Then
		
		SetPrivilegedMode(True);
		Parameters.Insert("AuthorizedUser", Users.AuthorizedUser());
		Parameters.Insert("UserPresentation", String(Parameters.AuthorizedUser));
		Parameters.Insert("ApplicationCaption", TrimAll(Constants.SystemTitle.Get()));
		SetPrivilegedMode(False);
		
	EndIf;
	
	Parameters.Insert("IsMasterNode", Not Common.IsSubordinateDIBNode());
	Parameters.Insert("FileInfobase", Common.FileInfobase());
	
	Parameters.Insert("SiteConfigurationUpdateRequiredRIB",
		Common.SubordinateDIBNodeConfigurationUpdateRequired());
	
	Parameters.Insert("ThisIsBasicConfigurationVersion", StandardSubsystemsServer.IsBaseConfigurationVersion());
	
EndProcedure

Function GetInformationAboutUser()
	
	// Calculate the actual name of the user even if it was previously changed in the current session;
	// For example, to connect to the current IB through the external connection from this session;
	// IN all other cases it is enough to get InfobaseUsers.CurrentUser().
	CurrentUser = InfobaseUsers.FindByUUID(
		InfobaseUsers.CurrentUser().UUID);
	
	If CurrentUser = Undefined Then
		CurrentUser = InfobaseUsers.CurrentUser();
	EndIf;
	
	Information = New Structure;
	Information.Insert("Name",                       CurrentUser.Name);
	Information.Insert("FullName",                 CurrentUser.FullName);
	Information.Insert("PasswordIsSet",          CurrentUser.PasswordIsSet);
	Information.Insert("OpenIDAuthentication",      CurrentUser.OpenIDAuthentication);
	Information.Insert("StandardAuthentication", CurrentUser.StandardAuthentication);
	Information.Insert("OSAuthentication",          CurrentUser.OSAuthentication);
	
	Return Information;
	
EndFunction

// Receive update global settings for 1C:Enterprise session.
//
Function GetUpdateSettings() Export
	
	IsAccessForUpdate = CheckAccessForUpdate();
	HasAccessForChecksUpdate = CheckAccessForUpdateCheck();
	
	ConfigurationChanged = ?(IsAccessForUpdate Or HasAccessForChecksUpdate, ConfigurationChanged(), False);
	
	StructureSettings = Common.CommonSettingsStorageLoad("ConfigurationUpdate", "ConfigurationUpdateOptions");
	
	Settings = New Structure;
	Settings.Insert("ConfigurationShortName",                  DataProcessors.InstallUpdates.ConfigurationShortName(StructureSettings));
	Settings.Insert("ServerAddressForVerificationOfUpdateAvailability", ServerAddressForVerificationOfUpdateAvailability(StructureSettings));
	Settings.Insert("UpdatesDirectory",                        UpdatesDirectory(StructureSettings));
	Settings.Insert("AddressOfResourceForVerificationOfUpdateAvailability", AddressOfResourceForVerificationOfUpdateAvailability(StructureSettings));
	Settings.Insert("LegalityCheckServiceAddress",          LegalityCheckServiceAddress());
	Settings.Insert("ConfigurationChanged",                     ConfigurationChanged);
	Settings.Insert("CheckPastBaseUpdate",           	ConfigurationUpdate.ConfigurationUpdateSuccessful() <> Undefined);
	Settings.Insert("IsAccessForUpdate",                  IsAccessForUpdate);
	Settings.Insert("HasAccessForChecksUpdate",          HasAccessForChecksUpdate);
	
	Settings.Insert("ConfigurationUpdateOptions", GetSettingsStructureOfAssistant());
	
	Return Settings;
	
EndFunction

// Receive short name (identifier) of configuration.
//
// Returns:
//   String   - short configuration name.
Function ConfigurationShortName(StructureSettings) Export
	
	Value = ConfigurationUpdateOverridable.ConfigurationShortName();
	If Not ValueIsFilled(Value) Then
		Value = Metadata.Name;
	EndIf;
	ConfigurationUpdateOverridable.WhenDeterminingConfigurationShortName(Value);
	
	Value = Value + "/";
	
	// Determine configuration edition.
	VersionSubstrings = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Metadata.Version, ".");
	If VersionSubstrings.Count() > 1 Then
		Value = Value + VersionSubstrings[0] + VersionSubstrings[1] + "/";
	EndIf;
	// Determine platform version.
	System_Info = New SystemInfo;
	VersionSubstrings = StringFunctionsClientServer.SplitStringIntoSubstringsArray(System_Info.AppVersion, ".");
	Value = Value + VersionSubstrings[0] + VersionSubstrings[1] + "/";
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseSettingValueConfigurationShortName", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.ConfigurationShortName;
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

// Receive address of configuration vendor web
// server where information about available updates is located.
// 
// Returns:
//   String   - web server address.
// 
// Example of implementation:
// 
// Return "localhost"; // local web server for testing.
//
Function ServerAddressForVerificationOfUpdateAvailability(StructureSettings)
	
	Value = ConfigurationUpdateOverridable.ServerAddressForVerificationOfUpdateAvailability();
	If Not ValueIsFilled(Value) Then
		Value = "https://files.1ci.com"; // Value by default
	EndIf;
	ConfigurationUpdateOverridable.WhenDeterminingServerAddressForUpdatesCheck(Value);
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseCheckForUpdatesServerSettingValue", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.ServerAddressForVerificationOfUpdateAvailability;
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

Function UpdatesDirectory(StructureSettings)
	
	Value = ConfigurationUpdateOverridable.UpdatesDirectory();
	If Not ValueIsFilled(Value) Then
		// Value by default
		Value = ConfigurationUpdateClientServer.AddFinalPathSeparator(Metadata.UpdateCatalogAddress);
	EndIf;
	
	ConfigurationUpdateOverridable.WhenDeterminingUpdatesDirectoryAddress(Value);
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseSettingValueUpdateDirectory", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.UpdatesDirectory;
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

Function LegalityCheckServiceAddress()
	
	Value = "";  // Value by default
	
	StructureSettings = Common.CommonSettingsStorageLoad(
		"ConfigurationUpdate",
		"ConfigurationUpdateOptions");
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseSettingValueLegalityCheckServiceAddress", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.LegalityCheckServiceAddress;
		EndIf;	
	EndIf;	
	
	Return Value;
	
EndFunction

Function AddressOfResourceForVerificationOfUpdateAvailability(StructureSettings)
	
	Value = ConfigurationUpdateOverridable.AddressOfResourceForVerificationOfUpdateAvailability();
	If Not ValueIsFilled(Value) Then
		Value = "/updates/"; // Value by default
	EndIf;
	ConfigurationUpdateOverridable.WhenDeterminingResourceAddressForUpdatesCheck(Value);
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseCheckForUpdatesPathSettingValue", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.AddressOfResourceForVerificationOfUpdateAvailability;
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

// Check whether there is an access to the InstallUpdates subsystem.
Function CheckAccessForUpdate()
	Return Users.IsFullUser(, True);
EndFunction

// Returns check box of update by the current user availability.
Function CheckAccessForUpdateCheck() Export
	
	Return Users.RolesAvailable("CheckForAvailableConfigurationUpdates")
	      AND TypeOf(Users.AuthorizedUser()) = Type("CatalogRef.Users");
	
EndFunction

#EndRegion

#EndIf