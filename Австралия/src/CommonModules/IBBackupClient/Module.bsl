#Region Public

// Opens backup form.
//
// Parameters:
//    Parameters - Structure - backup form parameters.
//
Procedure OpenBackupForm(Parameters = Undefined) Export
	
	OpenForm("DataProcessor.IBBackup.Form.DataBackup", Parameters);
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.OnStart. 
Procedure OnStart(Parameters) Export
	
	If Not CommonClientServer.IsWindowsClient() Or CommonClientServer.IsWebClient() Then
		Return;
	EndIf;
	
	RunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If RunParameters.DataSeparationEnabled Then
		Return;
	EndIf;
	
	FixedIBBackupParameters = Undefined;
	If Not RunParameters.Property("IBBackup", FixedIBBackupParameters) Then
		Return;
	EndIf;
	If TypeOf(FixedIBBackupParameters) <> Type("FixedStructure") Then
		Return;
	EndIf;
	
	// Filling global variables.
	FillGlobalVariableValues(FixedIBBackupParameters);
	
	CheckIBBackup(FixedIBBackupParameters);
	
	If FixedIBBackupParameters.BackupRestored Then
		NotificationText = NStr("ru = 'Восстановление данных проведено успешно.'; en = 'Data is restored successfully.'; pl = 'Odzyskiwanie danych zakończone pomyślnie.';es_ES = 'Datos se han restablecido con éxito.';es_CO = 'Datos se han restablecido con éxito.';tr = 'Veri başarıyla geri yüklendi.';it = 'I dati vengono ripristinato correttamente.';de = 'Die Daten werden erfolgreich wiederhergestellt.'");
		ShowUserNotification(NStr("ru = 'Данные восстановлены.'; en = 'Data is restored.'; pl = 'Dane zostały odzyskane.';es_ES = 'Datos se han restablecido.';es_CO = 'Datos se han restablecido.';tr = 'Veri geri yüklendi.';it = 'I dati viene ripristinato.';de = 'Die Daten werden wiederhergestellt.'"), , NotificationText);
	EndIf;
	
	NotificationOption = FixedIBBackupParameters.NotificationParameter;
	
	If NotificationOption = "DoNotNotify" Then
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ToDoList") Then
		ShowWarning = False;
		IBBackupClientOverridable.OnDetermineBackupWarningRequired(ShowWarning);
	Else
		ShowWarning = True;
	EndIf;
	
	If ShowWarning
		AND (NotificationOption = "Overdue" Or NotificationOption = "NotConfiguredYet") Then
		NotifyUserOfBackup(NotificationOption);
	EndIf;
	
	AttachIdleBackupHandler();
	
EndProcedure

// See CommonClientOverridable.BeforeExit. 
Procedure BeforeExit(Cancel, Warnings) Export
	
	#If WebClient OR MobileClient Then
		Return;
	#EndIf
	
	If Not CommonClientServer.IsWindowsClient() Then
		Return;
	EndIf;
	
	Parameters = StandardSubsystemsClient.ClientParameter();
	If Parameters.DataSeparationEnabled Or Not Parameters.FileInfobase Then
		Return;
	EndIf;
	
	If Not Parameters.IBBackupOnExit.NotificationRolesAvailable
		Or Not Parameters.IBBackupOnExit.ExecuteOnExit Then
		Return;
	EndIf;
	
	WarningParameters = StandardSubsystemsClient.WarningOnExit();
	WarningParameters.CheckBoxText = NStr("ru = 'Выполнить резервное копирование'; en = 'Back up'; pl = 'Utworzyć kopię zapasową.';es_ES = 'Crear una copia de respaldo';es_CO = 'Crear una copia de respaldo';tr = 'Yedekleyin';it = 'Eseguire il backup';de = 'Sichern'");
	WarningParameters.Priority = 50;
	WarningParameters.WarningText = NStr("ru = 'Не выполнено резервное копирование при завершении работы.'; en = 'Cannot execute backup on exiting the application.'; pl = 'Kopia zapasowa danych nie została utworzona.';es_ES = 'No se ha creado una copia de respaldo de los datos.';es_CO = 'No se ha creado una copia de respaldo de los datos.';tr = 'Veri yedeklenmedi.';it = 'Impossibile eseguire il backup alla chiusura dell''applicazione.';de = 'Die Daten wurden nicht gesichert.'");
	
	ActionIfFlagSet = WarningParameters.ActionIfFlagSet;
	ActionIfFlagSet.Form = "DataProcessor.IBBackup.Form.DataBackup";
	FormParameters = New Structure();
	FormParameters.Insert("RunMode", "ExecuteOnExit");
	ActionIfFlagSet.FormParameters = FormParameters;
	
	Warnings.Add(WarningParameters);
	
EndProcedure

// See SSLSubsystemsIntegrationClient.OnCheckIfCanBackUpInUserMode. 
Procedure OnCheckIfCanBackUpInUserMode(Result) Export
	
	If CommonClient.FileInfobase() Then
		Result = True;
	EndIf;
	
EndProcedure

// See SSLSubsystemsIntegrationClient.OnPromptUserForBackup. 
Procedure OnPromptUserForBackup() Export
	
	OpenBackupForm();
	
EndProcedure

#EndRegion

#Region Private

// Filling global variables.
Procedure FillGlobalVariableValues(FixedIBBackupParameters) Export
	
	ParameterName = "StandardSubsystems.IBParameters";
	ApplicationParameters.Insert(ParameterName, New Structure);
	ApplicationParameters[ParameterName].Insert("ProcessRunning");
	ApplicationParameters[ParameterName].Insert("MinDateOfNextAutomaticBackup");
	ApplicationParameters[ParameterName].Insert("LatestBackupDate");
	ApplicationParameters[ParameterName].Insert("NotificationParameter");
	
	FillPropertyValues(ApplicationParameters[ParameterName], FixedIBBackupParameters);
	ApplicationParameters[ParameterName].Insert("ScheduleValue", CommonClientServer.StructureToSchedule(FixedIBBackupParameters.CopyingSchedule));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Checks whether it is necessary to start automatic backup during user working, as well as repeat 
// notification after ignoring the initial one.
//
Procedure StartIdleHandler() Export
	
	If Not CommonClientServer.IsWindowsClient() Or CommonClientServer.IsWebClient() Then
		Return;
	EndIf;
	
	If CommonClient.FileInfobase()
	   AND NecessityOfAutomaticBackup() Then
		
		BackUp();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ToDoList") Then
		ShowWarning = False;
		IBBackupClientOverridable.OnDetermineBackupWarningRequired(ShowWarning);
	Else
		ShowWarning = True;
	EndIf;
	
	NotificationOption = ApplicationParameters["StandardSubsystems.IBParameters"].NotificationParameter;
	If ShowWarning
		AND (NotificationOption = "Overdue" Or NotificationOption = "NotConfiguredYet") Then
		NotifyUserOfBackup(NotificationOption);
	EndIf;
	
EndProcedure

// Checks whether the automatic backup is required.
//
// Returns - Boolean - True if necessary, otherwise False.
//
Function NecessityOfAutomaticBackup()
	Var ScheduleValue;
	
	IBParameters = ApplicationParameters["StandardSubsystems.IBParameters"];
	If IBParameters = Undefined Then
		Return False;
	EndIf;
	
	If IBParameters.ProcessRunning
		OR NOT IBParameters.Property("MinDateOfNextAutomaticBackup")
		OR NOT IBParameters.Property("ScheduleValue", ScheduleValue)
		OR NOT IBParameters.Property("LatestBackupDate") Then
		Return False;
	EndIf;
	
	If ScheduleValue = Undefined Then
		Return False;
	EndIf;
	
	CheckDate = CommonClient.SessionDate();
	
	NextCopyingDate = IBParameters.MinDateOfNextAutomaticBackup;
	If NextCopyingDate = '29990101' Or NextCopyingDate > CheckDate Then
		Return False;
	EndIf;
	
	Return ScheduleValue.ExecutionRequired(CheckDate, IBParameters.LatestBackupDate);
EndFunction

// Starts backup on schedule.
// 
Procedure BackUp()
	
	Buttons = New ValueList;
	Buttons.Add("Yes", NStr("ru = 'Да'; en = 'Yes'; pl = 'Tak';es_ES = 'Sí';es_CO = 'Sí';tr = 'Evet';it = 'Sì';de = 'Ja'"));
	Buttons.Add("No", NStr("ru = 'Нет'; en = 'No'; pl = 'Nie';es_ES = 'No';es_CO = 'No';tr = 'Hayır';it = 'No';de = 'Nr.'"));
	Buttons.Add("Defer", NStr("ru = 'Отложить на 15 минут'; en = 'Defer for 15 minutes'; pl = 'Odłóż na 15 minut';es_ES = 'Aplazar para 15 minutos';es_CO = 'Aplazar para 15 minutos';tr = '15 dakika ertele';it = 'Ritarda di 15 minuti';de = 'Um 15 Minuten verschieben'"));
	
	NotifyDescription = New NotifyDescription("CreateBackupCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("ru = 'Все готово для выполнения резервного копирования по расписанию.
		|Выполнить резервное копирование сейчас?'; 
		|en = 'Ready to back up on schedule. 
		|Back up now?'; 
		|pl = 'Wszystko jest gotowe do wykonania kopii zapasowej według harmonogramu.
		| Utwórz kopię zapasową już teraz?';
		|es_ES = 'Todo está listo para crear una copia de respaldo según el horario.
		|¿Crear una copia de respaldo ahora?';
		|es_CO = 'Todo está listo para crear una copia de respaldo según el horario.
		|¿Crear una copia de respaldo ahora?';
		|tr = 'Her şey zamanlanmış yedeklemeyi gerçekleştirmek için hazırdır. 
		|Şimdi yedekle?';
		|it = 'Pronto per creare il backup programmato. 
		|Creare il backup?';
		|de = 'Alles ist bereit für den geplanten Backup.
		|Backup jetzt ausführen?'"),
		Buttons, 30, "Yes", NStr("ru = 'Резервное копирование по расписанию'; en = 'Backup on schedule'; pl = 'Zaplanowana kopia zapasowa';es_ES = 'Copia de respaldo según el horario';es_CO = 'Copia de respaldo según el horario';tr = 'Zamanlanmış yedeklenme';it = 'Backup su pianificazione';de = 'Geplante Backups'"), "Yes");
	
EndProcedure

Procedure CreateBackupCompletion(QuestionResult, AdditionalParameters) Export
	
	CreateBackup = QuestionResult = "Yes" Or QuestionResult = DialogReturnCode.Timeout;
	DeferBackup = QuestionResult = "Defer";
	
	NextAutomaticCopyingDate = IBBackupServerCall.NextAutomaticCopyingDate(
		DeferBackup);
	FillPropertyValues(ApplicationParameters["StandardSubsystems.IBParameters"],
		NextAutomaticCopyingDate);
	
	If CreateBackup Then
		FormParameters = New Structure("RunMode", "ExecuteNow");
		OpenForm("DataProcessor.IBBackup.Form.DataBackup", FormParameters);
	EndIf;
	
EndProcedure

// Deletes backups according to selected settings.
//
Procedure DeleteConfigurationBackups() Export
	
	// Clear catalog with backups.
	FixedIBBackupParameters = StandardSubsystemsClient.ClientRunParameters().IBBackup;
	StorageDirectory = FixedIBBackupParameters.BackupsStorageDirectory;
	DeletionParameters = FixedIBBackupParameters.DeletionParameters;
	
	If DeletionParameters.RestrictionType <> "StoreAll" AND StorageDirectory <> Undefined Then
		
		Try
			File = New File(StorageDirectory);
			If NOT File.IsDirectory() Then
				Return;
			EndIf;
			
			FilesArray = FindFiles(StorageDirectory, "backup????_??_??_??_??_??*", False);
			DeletedFileList = New Array;
			
			// Delete backups.
			If DeletionParameters.RestrictionType = "ByPeriod" Then
				For Each ItemFile In FilesArray Do
					CurrentDate = CommonClient.SessionDate();
					ValueInSeconds = NumberOfSecondsInPeriod(DeletionParameters.ValueInUOMs, DeletionParameters.PeriodUOM);
					Deletion = ((CurrentDate - ValueInSeconds) > ItemFile.GetModificationTime());
					If Deletion Then
						DeletedFileList.Add(ItemFile);
					EndIf;
				EndDo;
				
			ElsIf FilesArray.Count() >= DeletionParameters.CopyCount Then
				FileList = New ValueList;
				FileList.LoadValues(FilesArray);
				
				For Each File In FileList Do
					File.Value = File.Value.GetModificationTime();
				EndDo;
				
				FileList.SortByValue(SortDirection.Desc);
				LastArchiveDate = FileList[DeletionParameters.CopyCount-1].Value;
				
				For Each ItemFile In FilesArray Do
					
					If ItemFile.GetModificationTime() <= LastArchiveDate Then
						DeletedFileList.Add(ItemFile);
					EndIf;
					
				EndDo;
				
			EndIf;
			
			For Each DeletedFile In DeletedFileList Do
				DeleteFiles(DeletedFile.FullName);
			EndDo;
			
		Except
			
			EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
				NStr("ru = 'Не удалось провести очистку каталога с резервными копиями.'; en = 'Cannot clear directory with backups.'; pl = 'Nie można oczyścić katalogu z kopiami zapasowymi.';es_ES = 'No se puede borrar un directorio con copias de respaldo.';es_CO = 'No se puede borrar un directorio con copias de respaldo.';tr = 'Yedeklemeli bir dizin temizlenemiyor.';it = 'Impossibile cancellare la directory con i backup.';de = 'Ein Verzeichnis mit Sicherungen kann nicht gelöscht werden.'") + Chars.LF 
				+ DetailErrorDescription(ErrorInfo()),,True);
			
		EndTry;
		
	EndIf;
	
EndProcedure

// Checks on application startup whether it is the first start after backup.
// If yes, it displays a handler form with backup results.
//
// Parameters:
//	Parameters - Structure - backup parameters.
//
Procedure CheckIBBackup(Parameters)
	
	If Not Parameters.BackupCreated Then
		Return;
	EndIf;
	
	If Parameters.LastBackupManualStart Then
		
		FormParameters = New Structure();
		FormParameters.Insert("RunMode", ?(Parameters.CopyingResult, "CompletedSuccessfully", "NotCompleted"));
		FormParameters.Insert("BackupFileName", Parameters.BackupFileName);
		OpenForm("DataProcessor.IBBackup.Form.DataBackup", FormParameters);
		
	Else
		
		ShowUserNotification(NStr("ru = 'Резервное копирование'; en = 'Backup'; pl = 'Kopia zapasowa';es_ES = 'Copia de respaldo';es_CO = 'Copia de respaldo';tr = 'Yedek';it = 'Creazione backup';de = 'Datensicherung'"),
			"e1cib/command/CommonCommand.ShowBackupResult",
			NStr("ru = 'Резервное копирование проведено успешно'; en = 'Backup successful'; pl = 'Tworzenie kopii zapasowej przeprowadzone pomyślnie';es_ES = 'Creación de una copia de respaldo se ha realizados con éxito';es_CO = 'Creación de una copia de respaldo se ha realizados con éxito';tr = 'Yedekleme başarıyla gerçekleştirildi';it = 'Backup eseguito con successo';de = 'Backup wurde erfolgreich durchgeführt'"), PictureLib.Information32);
		IBBackupServerCall.SetSettingValue("BackupCreated", False);
		
	EndIf;
	
EndProcedure

// Shows a notification according to results of backup parameters analysis.
//
// Parameters:
//   NotificationOption - String - check result for notifications.
//
Procedure NotifyUserOfBackup(NotificationOption)
	
	NoteText = "";
	If NotificationOption = "Overdue" Then
		
		NoteText = NStr("ru = 'Автоматическое резервное копирование не было выполнено.'; en = 'Automatic backup was not performed.'; pl = 'Automatyczne tworzenie kopii zapasowej nie zostało wykonane.';es_ES = 'Copia de respaldo automática no se ha ejecutado.';es_CO = 'Copia de respaldo automática no se ha ejecutado.';tr = 'Otomatik yedekleme gerçekleştirilmedi.';it = 'Il backup automatico non è stato eseguito.';de = 'Die automatische Sicherung wurde nicht ausgeführt.'"); 
		ShowUserNotification(NStr("ru = 'Резервное копирование'; en = 'Backup'; pl = 'Kopia zapasowa';es_ES = 'Copia de respaldo';es_CO = 'Copia de respaldo';tr = 'Yedek';it = 'Creazione backup';de = 'Sicherungskopie'"),
			"e1cib/app/DataProcessor.IBBackup", NoteText, PictureLib.Warning32);
		
	ElsIf NotificationOption = "NotConfiguredYet" Then
		
		SettingFormName = "e1cib/app/DataProcessor.IBBackupSetup/";
		NoteText = NStr("ru = 'Рекомендуется настроить резервное копирование информационной базы.'; en = 'We recommend that you configure backup for the infobase.'; pl = 'Zaleca się skonfigurować rezerwowe kopiowanie bazy informacyjnej.';es_ES = 'Nosotros recomendamos configurar la creación de una copia de respaldo para la infobase.';es_CO = 'Nosotros recomendamos configurar la creación de una copia de respaldo para la infobase.';tr = 'Veritabanı için yedeklemeyi yapılandırmanızı öneririz.';it = 'Si consiglia di configurare il backup per l''infobase.';de = 'Wir empfehlen, dass Sie die Sicherung für die Infobase konfigurieren.'"); 
		ShowUserNotification(NStr("ru = 'Резервное копирование'; en = 'Backup'; pl = 'Kopia zapasowa';es_ES = 'Copia de respaldo';es_CO = 'Copia de respaldo';tr = 'Yedek';it = 'Creazione backup';de = 'Sicherungskopie'"),
			SettingFormName, NoteText, PictureLib.Warning32);
			
	EndIf;
	
	CurrentDate = CommonClient.SessionDate();
	IBBackupServerCall.SetLastNotificationDate(CurrentDate);
	
EndProcedure

// Returns an event type of the event log for the current subsystem.
//
// Returns - String - an event type of the event log.
//
Function EventLogEvent() Export
	
	Return NStr("ru = 'Резервное копирование информационной базы'; en = 'Infobase backup'; pl = 'Rezerwowe kopiowanie bazy informacyjnej';es_ES = 'Copia de respaldo de la infobase';es_CO = 'Copia de respaldo de la infobase';tr = 'Veritabanı yedeği';it = 'Backup Infobase';de = 'Infobase-Sicherung'",
		StandardSubsystemsClient.ClientParametersOnStart().DefaultLanguageCode);
	
EndFunction

// Returns backup script parameters.
//
// Returns - Structure - structure of the backup script.
//
Function ClientBackupParameters() Export
	#If NOT WebClient AND NOT MobileClient Then
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("ApplicationFileName", StandardSubsystemsClient.ApplicationExecutableFileName());
		ParametersStructure.Insert("EventLogEvent", NStr("ru = 'Резервное копирование ИБ'; en = 'Infobase backup'; pl = 'Rezerwowe kopiowanie bazy informacyjnej';es_ES = 'Copia de respaldo de la infobase';es_CO = 'Copia de respaldo de la infobase';tr = 'Veritabanı yedeği';it = 'Backup Infobase';de = 'Infobase-Sicherung'"));
		
		// Calling TempFilesDir instead of GetTempFileName as the directory cannot be deleted automatically 
		// on client application exit.
		TempFilesDirForUpdate = TempFilesDir() + "1Cv8Backup." + Format(CommonClient.SessionDate(), "DF=yymmddHHmmss") + "\";
		ParametersStructure.Insert("TempFilesDirForUpdate", TempFilesDirForUpdate);
		
		Return ParametersStructure;
	#EndIf
EndFunction

// Getting user authentication parameters for update.
// Creates a virtual user if necessary.
//
// Returns
//  Structure - parameters of a virtual user.
//
Function UpdateAdministratorAuthenticationParameters(AdministratorPassword) Export
	
	Result = New Structure("UserName, UserPassword, StringForConnection, InfobaseConnectionString");
	
	CurrentConnections = IBConnectionsServerCall.ConnectionsInformation(True,
		ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
	Result.InfobaseConnectionString = CurrentConnections.InfobaseConnectionString;
	// Detects cases when role-based security is not provided by the application.
	// This means that any user can do everything in the application. 
	If Not CurrentConnections.HasActiveUsers Then
		Return Result;
	EndIf;
	
	Result.UserName    = StandardSubsystemsClient.ClientParametersOnStart().UserCurrentName;
	Result.UserPassword = StringUnicode(AdministratorPassword);
	Result.StringForConnection  = "Usr=""{0}"";Pwd=""{1}""";
	Return Result;
	
EndFunction

Function StringUnicode(Row) Export
	
	Result = "";
	
	For CharNumber = 1 To StrLen(Row) Do
		
		Char = Format(CharCode(Mid(Row, CharNumber, 1)), "NG=0");
		Char = StringFunctionsClientServer.SupplementString(Char, 4);
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Checks whether an add-in can be attached to the infobase.
//
Function CheckAccessToInfobase(AdministratorPassword) Export
	
	// The check is not performed in base application versions.
	// If the username and password are entered incorrectly, the update will fail.
	ConnectionResult = New Structure("AddInAttachmentError, BriefErrorDescription", False, "");
	ClientParametersOnStart = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientParametersOnStart.IsBaseConfigurationVersion Then
		Return ConnectionResult;
	EndIf;
	
	CommonClient.RegisterCOMConnector(False);
	
	ConnectionParameters = CommonClientServer.ParametersStructureForExternalConnection();
	ConnectionParameters.InfobaseDirectory = StrSplit(InfoBaseConnectionString(), """")[1];
	ConnectionParameters.UserName = ClientParametersOnStart.UserCurrentName;
	ConnectionParameters.UserPassword = AdministratorPassword;
	
	Result = CommonClientServer.EstablishExternalConnectionWithInfobase(ConnectionParameters);
	
	If Result.AddInAttachmentError Then
		
		EventLogClient.AddMessageForEventLog(
			EventLogEvent(),"Error", Result.DetailedErrorDescription, , True);
		
	EndIf;
	
	FillPropertyValues(ConnectionResult, Result);
	
	Return ConnectionResult;
	
EndFunction

// Attaching a global idle handler.
//
Procedure AttachIdleBackupHandler() Export
	
	AttachIdleHandler("BackupActionsHandler", 60);
	
EndProcedure

// Disable global idle handler.
//
Procedure DisableBackupIdleHandler() Export
	
	DetachIdleHandler("BackupActionsHandler");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function NumberOfSecondsInPeriod(Period, PeriodType)
	
	If PeriodType = "Day" Then
		Multiplier = 3600 * 24;
	ElsIf PeriodType = "Week" Then
		Multiplier = 3600 * 24 * 7; 
	ElsIf PeriodType = "Month" Then
		Multiplier = 3600 * 24 * 30;
	ElsIf PeriodType = "Year" Then
		Multiplier = 3600 * 24 * 365;
	EndIf;
	
	Return Multiplier * Period;
	
EndFunction

#If Not WebClient AND NOT MobileClient Then

Function IBBackupApplicationFilesEncoding() Export
	
	// wscript.exe can process only UTF-16 LE-encoded files.
	Return TextEncoding.UTF16;
	
EndFunction

#EndIf

#EndRegion
