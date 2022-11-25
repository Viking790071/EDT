#Region Internal

// Returns the initial filling of automatic backup settings.
//
// Parameters:
//	SaveParameters - shows whether parameters are saved to a settings storage.
//
// Returns - Structure - initial filling of backup parameters.
//
Function InitialBackupSettingsFilling(SaveParameters = True) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("RunAutomaticBackup", False);
	Parameters.Insert("BackupConfigured", False);
	
	Parameters.Insert("LastNotificationDate", '00010101');
	Parameters.Insert("LatestBackupDate", '00010101');
	Parameters.Insert("MinDateOfNextAutomaticBackup", '29990101');
	
	Parameters.Insert("CopyingSchedule", CommonClientServer.ScheduleToStructure(New JobSchedule));
	Parameters.Insert("BackupsStorageDirectory", "");
	Parameters.Insert("ManualBackupsStorageDirectory", ""); // Upon manual execution
	Parameters.Insert("BackupCreated", False);
	Parameters.Insert("BackupRestored", False);
	Parameters.Insert("CopyingResult", Undefined);
	Parameters.Insert("BackupFileName", "");
	Parameters.Insert("ExecutionOption", "Schedule");
	Parameters.Insert("ProcessRunning", False);
	Parameters.Insert("IBAdministrator", "");
	Parameters.Insert("IBAdministratorPassword", "");
	Parameters.Insert("DeletionParameters", DefaultBackupDeletionParameters());
	Parameters.Insert("LastBackupManualStart", True);
	
	If SaveParameters Then
		SetBackupParemeters(Parameters);
	EndIf;
	
	Return Parameters;
	
EndFunction

// Returns the current backup setting as a string.
// Two options of using functions: passing all parameters, or without parameters.
//
Function CurrentBackupSetting() Export
	
	BackupSettings = BackupSettings();
	If BackupSettings = Undefined Then
		Return NStr("ru = 'Для настройки резервного копирования необходимо обратиться к администратору.'; en = 'To configure backup, contact administrator.'; pl = 'Aby skonfigurować rezerwowe kopiowanie, skontaktuj się z administratorem.';es_ES = 'Para configurar la creación de una copia de respaldo, contactar el administrador.';es_CO = 'Para configurar la creación de una copia de respaldo, contactar el administrador.';tr = 'Yedeklemeyi yapılandırmak için yöneticiye başvurun.';it = 'Per configurare il backup, è necessario contattare l''amministratore.';de = 'Wenden Sie sich an den Administrator, um die Sicherung zu konfigurieren.'");
	EndIf;
	
	CurrentSetting = NStr("ru = 'Резервное копирование не настроено, информационная база подвергается риску потери данных.'; en = 'Backup is not configured. It can expose infobase to risks of data loss.'; pl = 'Tworzenie kopii zapasowych nie zostało skonfigurowane. Baza informacyjna może być narażona na utratę danych.';es_ES = 'La creación de una copia de respaldo no está configurada. Puede exponer la infobase a riesgos de pérdida de datos.';es_CO = 'La creación de una copia de respaldo no está configurada. Puede exponer la infobase a riesgos de pérdida de datos.';tr = 'Yedekleme yapılandırılmamış. Veritabanını veri kaybı risklerine maruz kalabilir.';it = 'Backup non è configurato. Si può esporre infobase a rischi di perdita dei dati.';de = 'Die Sicherung ist nicht konfiguriert. dies kann die Infobase dem Risiko von Datenverlust aussetzen.'");
	
	If Common.FileInfobase() Then
		
		If BackupSettings.RunAutomaticBackup Then
			
			If BackupSettings.ExecutionOption = "OnExit" Then
				CurrentSetting = NStr("ru = 'Резервное копирование выполняется регулярно при завершении работы.'; en = 'Backup is performed regularly on exiting the application.'; pl = 'Kopia zapasowa jest tworzona regularnie przy zakończeniu pracy aplikacji.';es_ES = 'Copia de respaldo se hace regularmente al cerrar la aplicación.';es_CO = 'Copia de respaldo se hace regularmente al cerrar la aplicación.';tr = 'Yedekleme işlem bitiminde düzenli olarak yapılır.';it = 'Backup eseguito regolarmente alla chiusura dell''applicazione.';de = 'Die Sicherung wird regelmäßig beim Schließen der Anwendung durchgeführt.'");
			ElsIf BackupSettings.ExecutionOption = "Schedule" Then // On schedule
				Schedule = CommonClientServer.StructureToSchedule(BackupSettings.CopyingSchedule);
				If Not IsBlankString(Schedule) Then
					CurrentSetting = NStr("ru = 'Резервное копирование выполняется регулярно по расписанию: %1'; en = 'Regular backup on schedule: %1'; pl = 'Regularne tworzenie kopii zapasowej według harmonogramu: %1';es_ES = 'Copia de respaldo regular a la hora programada: %1';es_CO = 'Copia de respaldo regular a la hora programada: %1';tr = 'Düzenli aralıklarla yedekleme:%1';it = 'Backup regolare nei tempi previsti: %1';de = 'Regelmäßige Sicherung nach Zeitplan: %1'");
					CurrentSetting = StringFunctionsClientServer.SubstituteParametersToString(CurrentSetting, Schedule);
				EndIf;
			EndIf;
			
		Else
			
			If BackupSettings.BackupConfigured Then
				CurrentSetting = NStr("ru = 'Резервное копирование не выполняется (организовано сторонними программами).'; en = 'Backup is not running (organized by external applications).'; pl = 'Tworzenie kopii zapasowych nie jest uruchomione (organizowane przez aplikacje zewnętrzne).';es_ES = 'Copia de respaldo no está lanzada (organizado por las aplicaciones externas).';es_CO = 'Copia de respaldo no está lanzada (organizado por las aplicaciones externas).';tr = 'Yedekleme çalışmıyor (harici uygulamalar tarafından düzenlenmiştir).';it = 'Backup non è in esecuzione (organizzato da applicazioni esterne).';de = 'Die Sicherung wird nicht ausgeführt (organisiert von externen Anwendungen).'");
			EndIf;
			
		EndIf;
		
	Else
		
		CurrentSetting = NStr("ru = 'Резервное копирование не выполняется (организовано средствами СУБД).'; en = 'Backup is not running (organized by DBMS resources).'; pl = 'Tworzenie kopii zapasowych nie jest uruchomione (organizowane przez źródła SZBD).';es_ES = 'Copia de respaldo no está lanzada (organizado por los recursos DBMS).';es_CO = 'Copia de respaldo no está lanzada (organizado por los recursos DBMS).';tr = 'Yedekleme çalışmıyor (DBMS kaynakları tarafından düzenlenmiş).';it = 'Backup non è in esecuzione (organizzato da risorse DBMS).';de = 'Die Sicherung wird nicht ausgeführt (organisiert von DBMS-Ressourcen).'");
		
	EndIf;
	
	Return CurrentSetting;
	
EndFunction

// Link for substitution in a formatted string for opening infobase backup data processor.
//
// Returns:
//   String - Link.
//
Function BackupDataProcessorURL() Export
	
	Return "e1cib/app/DataProcessor.IBBackup";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If CommonClientServer.IsWebClient()
		OR CommonClientServer.IsMobileClient()
		OR Common.DataSeparationEnabled() Then
		
		Return;
		
	EndIf;
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	DisabledNotificationOfBackupSettings = ModuleToDoListServer.UserTaskDisabled("SetUpBackup");
	DisabledNotificationOfBackupExecution = ModuleToDoListServer.UserTaskDisabled("CreateBackup");
	
	If Not AccessRight("View", Metadata.DataProcessors.IBBackupSetup)
		Or (DisabledNotificationOfBackupSettings
			AND DisabledNotificationOfBackupExecution) Then
		Return;
	EndIf;
	
	BackupSettings = BackupSettings();
	If BackupSettings = Undefined Then
		Return;
	EndIf;
	
	NotificationOption = BackupSettings.NotificationParameter;
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.DataProcessors.IBBackupSetup.FullName());
	
	For Each Section In Sections Do
		
		If Not DisabledNotificationOfBackupSettings Then
			
			BackupSettingFormName = ?(Common.FileInfobase(),
				"DataProcessor.IBBackupSetup.Form.BackupSetup",
				"DataProcessor.IBBackupSetup.Form.BackupSetupClientServer");
			
			UserTask = ToDoList.Add();
			UserTask.ID  = "SetUpBackup" + StrReplace(Section.FullName(), ".", "");
			UserTask.HasUserTasks       = NotificationOption = "NotConfiguredYet";
			UserTask.Presentation  = NStr("ru = 'Настроить резервное копирование'; en = 'Configure backup'; pl = 'Konfiguracja tworzenia kopii zapasowych';es_ES = 'Configurar la creación de una copia de respaldo';es_CO = 'Configurar la creación de una copia de respaldo';tr = 'Yedeklemeyi yapılandır';it = 'Configurare il backup';de = 'Konfigurieren Sie die Sicherung'");
			UserTask.Important         = True;
			UserTask.Form          = BackupSettingFormName;
			UserTask.Owner       = Section;
		EndIf;
		
		If Not DisabledNotificationOfBackupExecution Then
			UserTask = ToDoList.Add();
			UserTask.ID  = "CreateBackup" + StrReplace(Section.FullName(), ".", "");
			UserTask.HasUserTasks       = NotificationOption = "Overdue";
			UserTask.Presentation  = NStr("ru = 'Резервное копирование не выполнено'; en = 'Backup not completed'; pl = 'Tworzenie kopii zapasowej nie powiodło się';es_ES = 'La creación de una copia de respaldo no finalizada';es_CO = 'La creación de una copia de respaldo no finalizada';tr = 'Yedekleme tamamlanmadı';it = 'Backup non completato';de = 'Sicherung nicht abgeschlossen'");
			UserTask.Important         = True;
			UserTask.Form          = "DataProcessor.IBBackup.Form.DataBackup";
			UserTask.Owner       = Section;
		EndIf;
		
	EndDo;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	Parameters.Insert("IBBackup", BackupSettings(True));
	Parameters.Insert("IBBackupOnExit", ParametersOnExit());
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	Parameters.Insert("IBBackup", BackupSettings());
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.SharedData = True;
	Handler.Procedure = "IBBackupServer.UpdateBackupParameters_2_2_1_15";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.33";
	Handler.SharedData = True;
	Handler.Procedure = "IBBackupServer.UpdateBackupParameters_2_2_1_33";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.33";
	Handler.SharedData = True;
	Handler.Procedure = "IBBackupServer.UpdateBackupParameters_2_2_2_33";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.36";
	Handler.SharedData = True;
	Handler.Procedure = "IBBackupServer.UpdateBackupParameters_2_2_4_36";
	
EndProcedure

// See SafeModeManagerOverridable.OnEnableSecurityProfiles. 
Procedure OnEnableSecurityProfiles() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If BackupParameters.Property("IBAdministratorPassword") Then
		
		BackupParameters.IBAdministratorPassword = "";
		SetBackupParemeters(BackupParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Returns IBBackup subsystem parameters that are required on user exit.
// 
//
// Returns:
//	Structure - parameters.
//
Function ParametersOnExit()
	
	BackupSettings = BackupSettings();
	ExecuteOnExit = ?(BackupSettings = Undefined, False,
		BackupSettings.RunAutomaticBackup
		AND BackupSettings.ExecutionOption = "OnExit");
	
	ParametersOnExit = New Structure;
	ParametersOnExit.Insert("NotificationRolesAvailable",   Users.IsFullUser(,True));
	ParametersOnExit.Insert("ExecuteOnExit", ExecuteOnExit);
	
	Return ParametersOnExit;
	
EndFunction

// Returns period value over the specified time interval.
//
// Parameters:
//	TimeInterval - Number - time interval in seconds.
//	
// Returns - structure with fields:
//	PeriodType - String - period type: Day, Week, Month, or Year.
//	PeriodValue - Number - period length for specified type.
//
Function PeriodValueByTimeInterval(TimeInterval)
	
	ReturnedStructure = New Structure("PeriodType, PeriodValue", "Month", 1);
	
	If TimeInterval = Undefined Then 
		Return ReturnedStructure;
	EndIf;	
	
	If Int(TimeInterval / (3600 * 24 * 365)) > 0 Then 
		ReturnedStructure.PeriodType		= "Year";
		ReturnedStructure.PeriodValue	= TimeInterval / (3600 * 24 * 365);
		Return ReturnedStructure;
	EndIf;
	
	If Int(TimeInterval / (3600 * 24 * 30)) > 0 Then 
		ReturnedStructure.PeriodType		= "Month";
		ReturnedStructure.PeriodValue	= TimeInterval / (3600 * 24 * 30);
		Return ReturnedStructure;
	EndIf;
	
	If Int(TimeInterval / (3600 * 24 * 7)) > 0 Then 
		ReturnedStructure.PeriodType		= "Week";
		ReturnedStructure.PeriodValue	= TimeInterval / (3600 * 24 * 7);
		Return ReturnedStructure;
	EndIf;
	
	If Int(TimeInterval / (3600 * 24)) > 0 Then 
		ReturnedStructure.PeriodType		= "Day";
		ReturnedStructure.PeriodValue	= TimeInterval / (3600 * 24);
		Return ReturnedStructure;
	EndIf;
	
	Return ReturnedStructure;
	
EndFunction

// Returns saved backup parameters.
//
// Returns - Structure - backup parameters.
//
Function BackupParameters() Export
	
	Parameters = Common.CommonSettingsStorageLoad("BackupParameters", "");
	If Parameters = Undefined Then
		Parameters = InitialBackupSettingsFilling();
	Else
		AdjustBackupParameters(Parameters);
	EndIf;
	Return Parameters;
	
EndFunction

// Adjusts backup parameters.
// If current backup parameters do not contain the parameter that is present in the 
// "InitialBackupSettingsFilling" function, it is added with the default value.
//
// Parameters:
//	BackupParameters - Structure - infobase backup parameters.
//
Procedure AdjustBackupParameters(BackupParameters)
	
	ParametersChanged = False;
	
	Parameters = InitialBackupSettingsFilling(False);
	For Each StructureItem In Parameters Do
		ValueFound = Undefined;
		If BackupParameters.Property(StructureItem.Key, ValueFound) Then
			If ValueFound = Undefined AND StructureItem.Value <> Undefined Then
				BackupParameters.Insert(StructureItem.Key, StructureItem.Value);
				ParametersChanged = True;
			EndIf;
		Else
			If StructureItem.Value <> Undefined Then
				BackupParameters.Insert(StructureItem.Key, StructureItem.Value);
				ParametersChanged = True;
			EndIf;
		EndIf;
	EndDo;
	
	If Not ParametersChanged Then 
		Return;
	EndIf;
	
	SetBackupParemeters(BackupParameters);
	
EndProcedure

// Saves backup parameters.
//
// Parameters:
//	ParametersStructure - Structure - backup parameters.
//
Procedure SetBackupParemeters(ParametersStructure, CurrentUser = Undefined) Export
	Common.CommonSettingsStorageSave("BackupParameters", "", ParametersStructure);
	If CurrentUser <> Undefined Then
		CopyingParameters = New Structure("User", CurrentUser);
		Constants.BackupParameters.Set(New ValueStorage(CopyingParameters));
	EndIf;
EndProcedure

// Checks whether it is time to start automatic backup.
//
// Returns:
//   Boolean - True if it is time for backup.
//
Function NecessityOfAutomaticBackup()
	
	If Not Common.FileInfobase() Then
		Return False;
	EndIf;
	
	Parameters = BackupParameters();
	If Parameters = Undefined Then
		Return False;
	EndIf;
	Schedule = Parameters.CopyingSchedule;
	If Schedule = Undefined Then
		Return False;
	EndIf;
	
	If Parameters.Property("ProcessRunning") AND Parameters.ProcessRunning Then
		Return False;
	EndIf;
	
	CheckDate = CurrentSessionDate();
	NextCopyingDate = Parameters.MinDateOfNextAutomaticBackup;
	If NextCopyingDate = '29990101' Or NextCopyingDate > CheckDate Then
		Return False;
	EndIf;
	
	CheckStartDate = Parameters.LatestBackupDate;
	ScheduleValue = CommonClientServer.StructureToSchedule(Schedule);
	Return ScheduleValue.ExecutionRequired(CheckDate, CheckStartDate);
	
EndFunction

// Returns value of the "Backup status" setting in the result part.
// The procedure runs at application startup to show the backup results form.
//
Procedure SetBackupResult() Export
	
	ParametersStructure = BackupSettings();
	ParametersStructure.BackupCreated = False;
	SetBackupParemeters(ParametersStructure);
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then 
		ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
		ModuleMonitoringCenter.WriteBusinessStatisticsOperation("BackupCreated", 1);
	EndIf;
	
EndProcedure

// Sets the last user notification date.
//
// Parameters:
//	NotificationDate - Date - date and time the user was last notified of required backup.
//	                         
//
Procedure SetLastNotificationDate(NotificationDate) Export
	
	NotificationParameters = BackupParameters();
	NotificationParameters.LastNotificationDate = NotificationDate;
	SetBackupParemeters(NotificationParameters);
	
EndProcedure

// Sets the setting to backup parameters.
// 
// Parameters:
//	ItemName - String - a parameter name.
// 	ItemValue - Arbitrary type - a parameter value.
//
Procedure SetSettingValue(ItemName, ItemValue) Export
	
	SettingsStructure = BackupParameters();
	SettingsStructure.Insert(ItemName, ItemValue);
	SetBackupParemeters(SettingsStructure);
	
EndProcedure

// Returns structure with backup parameters.
// 
// Parameters:
//	WorkStart – Boolean – shows that the call is performed on application start.
//
// Returns:
//  Structure - backup parameters.
//
Function BackupSettings(WorkStart = False) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return Undefined; // Not logged in data area.
	EndIf;
	
	If Not Users.IsFullUser(,True) Then
		Return Undefined; // Current user does not have necessary permissions.
	EndIf;
	
	Result = BackupParameters();
	
	// Defining a user notification option
	NotificationOption = "DoNotNotify";
	NotifyOfBackupNecessity = CurrentSessionDate() >= (Result.LastNotificationDate + 3600 * 24);
	If UsedCloudArchive() Then 
		NotificationOption = "DoNotNotify";
	ElsIf Result.RunAutomaticBackup Then
		NotificationOption = ?(NecessityOfAutomaticBackup(), "Overdue", "Configured");
	ElsIf Not Result.BackupConfigured Then
		If NotifyOfBackupNecessity Then	
			BackupSettings = Constants.BackupParameters.Get().Get();
			If BackupSettings <> Undefined
				AND BackupSettings.User <> UsersClientServer.CurrentUser() Then
				NotificationOption = "DoNotNotify";
			Else
				NotificationOption = "NotConfiguredYet";
			EndIf;
		EndIf;
	EndIf;
	Result.Insert("NotificationParameter", NotificationOption);
	
	If Result.BackupCreated AND Result.CopyingResult  Then
		CurrentSessionDate = CurrentSessionDate();
		Result.LatestBackupDate = CurrentSessionDate;
		// Save the date of the last backup to common settings storage.
		ParametersStructure = BackupParameters();
		ParametersStructure.LatestBackupDate = CurrentSessionDate;
		SetBackupParemeters(ParametersStructure);
	EndIf;
	
	If Result.BackupRestored Then
		UpdateRestoreResult();
	EndIf;
	
	If WorkStart AND Result.ProcessRunning Then
		Result.ProcessRunning = False;
		SetSettingValue("ProcessRunning", False);
	EndIf;
	
	Return Result;
	
EndFunction

Function UsedCloudArchive()
	
	If Common.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchive = Common.CommonModule("CloudArchive");
		Return ModuleCloudArchive.CloudArchiveOperationsAllowed();
	EndIf;
	
	Return False;
	
EndFunction

// Updates restore result and backup parameters structure.
//
Procedure UpdateRestoreResult()
	
	ReturnStructure = BackupParameters();
	ReturnStructure.BackupRestored = False;
	SetBackupParemeters(ReturnStructure);
	
EndProcedure

// Returns information about current user.
//
Function UserInformation() Export
	
	UserInformation = New Structure("Name, PasswordRequired", "", False);
	UsedUsers = InfoBaseUsers.GetUsers().Count() > 0;
	
	If Not UsedUsers Then
		Return UserInformation;
	EndIf;
	
	CurrentUser = StandardSubsystemsServer.CurrentUser();
	PasswordRequired = CurrentUser.PasswordIsSet AND CurrentUser.StandardAuthentication;
	
	UserInformation.Name = CurrentUser.Name;
	UserInformation.PasswordRequired = PasswordRequired;
	
	Return UserInformation;
	
EndFunction

// Procedure called from a script via a COM connection.
// Writes the backup result to settings.
// 
// Parameters:
//	Result - Boolean - backup result.
//	BackupFileName - String - backup file name.
//
Procedure FinishBackup(Result, BackupFileName =  "") Export
	
	ResultStructure = BackupSettings();
	ResultStructure.BackupCreated = True;
	ResultStructure.CopyingResult = Result;
	ResultStructure.BackupFileName = BackupFileName;
	SetBackupParemeters(ResultStructure);
	
EndProcedure

// Called from the script via a COM connection to write the result of infobase reestore to settings.
// 
//
// Parameters:
//	Result - Boolean - a restore result.
//
Procedure CompleteRestore(Result) Export
	
	ResultStructure = BackupSettings();
	ResultStructure.BackupRestored = True;
	SetBackupParemeters(ResultStructure);
	
EndProcedure

Function DefaultBackupDeletionParameters()
	
	DeletionParameters = New Structure;
	
	DeletionParameters.Insert("RestrictionType", "ByPeriod");
	
	DeletionParameters.Insert("CopyCount", 10);
	
	DeletionParameters.Insert("PeriodUOM", "Month");
	DeletionParameters.Insert("ValueInUOMs", 6);
	
	Return DeletionParameters;
	
EndFunction

// Updates backup settings.
//
Procedure UpdateBackupParameters_2_2_1_15() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If Not BackupParameters.Property("CreateBackupOnExitingApplication")
		Or Not BackupParameters.Property("ConfiguredByUser") Then
		
		Return; // The parameters have already been updated.
		
	EndIf;
	
	SelectSettingItem = BackupParameters.SelectSettingItem;
	
	If SelectSettingItem = 3 Then
		SelectSettingItem = 0;
	ElsIf SelectSettingItem = 2 Then
		SelectSettingItem = 3;
	Else
		If BackupParameters.CreateBackupOnExitingApplication Then
			SelectSettingItem = 2;
		ElsIf BackupParameters.ConfiguredByUser AND ValueIsFilled(BackupParameters.CopyingSchedule) Then
			SelectSettingItem = 1;
		Else
			SelectSettingItem = 0;
		EndIf;
	EndIf;
	
	BackupParameters.SelectSettingItem = SelectSettingItem;
	
	ArrayOfParametersToDelete = New Array;
	ArrayOfParametersToDelete.Add("HourlyNotification ");
	ArrayOfParametersToDelete.Add("ConfiguredByUser ");
	ArrayOfParametersToDelete.Add("CreateBackupOnExitingApplication");
	ArrayOfParametersToDelete.Add("AutomaticBackup");
	ArrayOfParametersToDelete.Add("DeferredBackup");
	
	For Each ParameterToDelete In ArrayOfParametersToDelete Do
		
		If BackupParameters.Property(ParameterToDelete) Then
			
			BackupParameters.Delete(ParameterToDelete);
			
		EndIf;
		
	EndDo;
	
	SetBackupParemeters(BackupParameters);
	
EndProcedure

// Updates backup settings.
//
Procedure UpdateBackupParameters_2_2_1_33() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If BackupParameters.Property("DeletionParameters") Then
		
		Return; // The parameters have already been updated.
		
	EndIf;
	
	DeletionParameters = DefaultBackupDeletionParameters();
	DeletionParameters.Deletion = BackupParameters.Deletion;
	DeletionParameters.RestrictionType = ?(BackupParameters.DeleteByPeriod, "ByPeriod", "ByCount");
	
	If BackupParameters.DeleteByPeriod Then
		DeletionParameters.RestrictionType = "ByPeriod";
		PeriodValueSettings = PeriodValueByTimeInterval(BackupParameters.ParameterValue);
		DeletionParameters.PeriodUOM = PeriodValueSettings.PeriodType;
		DeletionParameters.ValueInUOMs = PeriodValueSettings.PeriodValue;
	Else
		DeletionParameters.RestrictionType = "ByCount";
		DeletionParameters.CopyCount = DeletionParameters.ParameterValue;
	EndIf;
	
	BackupParameters.Insert("DeletionParameters", DeletionParameters);
	
	ArrayOfParametersToDelete = New Array;
	ArrayOfParametersToDelete.Add("Deletion");
	ArrayOfParametersToDelete.Add("DeleteByPeriod ");
	ArrayOfParametersToDelete.Add("ParameterValue");
	ArrayOfParametersToDelete.Add("NotificationPeriod");
	
	For Each ParameterToDelete In ArrayOfParametersToDelete Do
		
		If BackupParameters.Property(ParameterToDelete) Then
			
			BackupParameters.Delete(ParameterToDelete);
			
		EndIf;
		
	EndDo;
	
	SetBackupParemeters(BackupParameters);
	
EndProcedure

// Updates backup settings.
//
Procedure UpdateBackupParameters_2_2_2_33() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If BackupParameters.Property("RunAutomaticBackup") Then
		
		Return; // The parameters have already been updated.
		
	EndIf;
	
	If BackupParameters.FirstRun Then
		
		BackupParameters.LatestBackupDate = Date(1, 1, 1);
		
	EndIf;
	
	If BackupParameters.SelectSettingItem = 2 Then
		ExecutionOption = "OnExit";
	Else
		ExecutionOption = "Schedule";
	EndIf;
	
	RunAutomaticBackup = (BackupParameters.SelectSettingItem = 1 Or BackupParameters.SelectSettingItem = 2);
	
	BackupParameters.Insert("RunAutomaticBackup", RunAutomaticBackup);
	BackupParameters.Insert("BackupConfigured", BackupParameters.SelectSettingItem <> 0);
	BackupParameters.Insert("ExecutionOption", ExecutionOption);
	BackupParameters.Insert("LastBackupManualStart", True);
	
	ArrayOfParametersToDelete = New Array;
	ArrayOfParametersToDelete.Add("SelectSettingItem");
	ArrayOfParametersToDelete.Add("FirstRun");
	
	For Each ParameterToDelete In ArrayOfParametersToDelete Do
		
		If BackupParameters.Property(ParameterToDelete) Then
			
			BackupParameters.Delete(ParameterToDelete);
			
		EndIf;
		
	EndDo;
	
	If BackupParameters.Property("DeletionParameters")
		AND BackupParameters.DeletionParameters.Property("Deletion") Then
		
		If Not BackupParameters.DeletionParameters.Deletion Then
			BackupParameters.DeletionParameters.RestrictionType = "StoreAll";
		EndIf;
		
		BackupParameters.DeletionParameters.Delete("Deletion");
		
	EndIf;
	
	SetBackupParemeters(BackupParameters);
	
EndProcedure

// Updates backup settings.
//
Procedure UpdateBackupParameters_2_2_4_36() Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	SavedUser = Undefined;
	For Each User In InfoBaseUsers.GetUsers() Do
		Settings = Common.CommonSettingsStorageLoad("BackupParameters", "",,, User.Name);
		
		If TypeOf(Settings) <> Type("Structure") Then
			Continue;
		EndIf;
		
		If Settings.Property("RunAutomaticBackup")
			AND Settings.RunAutomaticBackup Then
			SavedUser = User;
			Break;
		EndIf;
		
		If Settings.Property("BackupConfigured")
			AND Settings.BackupConfigured Then
			SavedUser = User;
		EndIf;
		
	EndDo;
	
	If SavedUser <> Undefined Then
		FoundUser = Undefined;
		UsersInternal.UserByIDExists(SavedUser.UUID,, FoundUser);
		If FoundUser <> Undefined Then
			Parameters = New Structure("User", FoundUser);
			Constants.BackupParameters.Set(New ValueStorage(Parameters));
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
