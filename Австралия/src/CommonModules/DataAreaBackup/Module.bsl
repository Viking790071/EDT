#Region Public

////////////////////////////////////////////////////////////////////////////////
// Message exchange

// Returns the usage status of the data area backup.
//
// Returns:
//   Boolean - True if backup is used.
//
Function BackupUsed() Export
	
	SetPrivilegedMode(True);
	Return Constants.BackupSupported.Get();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Active users in data area.

// Sets user activity flag in the current area.
// The flag is the value of the LastClientSessionStartDate constant with Usage of split data set to Independent and Shared.
//
Procedure SetUserActivityInAreaFlag() Export
	
	If NOT SaaSCached.IsSeparatedConfiguration()
		OR NOT SaaS.SeparatedDataUsageAvailable()
		OR CurrentRunMode() = Undefined
		OR NOT GetFunctionalOption("BackupSupported")
		OR SaaS.DataAreaLocked(SaaS.SessionSeparatorValue()) Then
		
		Return;
		
	EndIf;
	
	SetAreaActivityFlag(); // For backward compatibility
	
	StartDate = CurrentUniversalDate();
	
	If StartDate - Constants.LastClientSessionStartDate.Get() < 3600 Then
		Return;
	EndIf;
	
	Constants.LastClientSessionStartDate.Set(StartDate);
	
EndProcedure

// Returns mapping between Russian names of application system settings fields and English from XDTO 
// package ZoneBackupControl service Manager.
// (type: {http://www.1c.ru/SaaS/1.0/XMLSchema/ZoneBackupControl}Settings).
//
// Returns:
//   FixedMap - mapping between Russian names of settings fields and English.
//
Function MapBetweenSMSettingsAndAppSettings() Export
	
	Return DataAreasBackupCached.MapBetweenSMSettingsAndAppSettings();
	
EndFunction

// Determines whether the application supports backup creation.
//
// Returns:
//  Boolean - True if the application supports backup creation.
//
Function ServiceManagerSupportsBackup() Export
	
	Return DataAreasBackupCached.ServiceManagerSupportsBackup();
	
EndFunction

// Returns backup control web service proxy.
// 
// Returns:
//   WSProxy - service manager proxy.
// 
Function BackupControlProxy() Export
	
	Return DataAreasBackupCached.BackupControlProxy();
	
EndFunction

// Returns the subsystem name to be used in the names of log events.
//  
//
// Returns:
//   String - the subsystem name.
//
Function SubsystemNameForEventLogEvents() Export
	
	Return Metadata.Subsystems.StandardSubsystems.Subsystems.SaaS.Subsystems.DataAreaBackup.Name;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Background jobs

// Returns the description of the background job that exports areas to files.
//
// Returns:
//   String - the description of the background job.
//
Function BackgroundBackupDescription() Export
	
	Return NStr("ru = 'Резервное копирование области данных'; en = 'Data area backup'; pl = 'Tworzenie kopii zapasowych obszaru danych';es_ES = 'Copia de respaldo del área de datos';es_CO = 'Copia de respaldo del área de datos';tr = 'Veri alanı yedekleme';it = 'Backup Area dati';de = 'Daten sichern'", CommonClientServer.DefaultLanguageCode());
	
EndFunction


#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	Parameters.Insert("DataAreaBackup", GetFunctionalOption("BackupSupported"));
	
EndProcedure

// See JobQueueOverridable.OnDefineHandlerAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("DataAreaBackup.ExportAreaToSMStorage");
	NameAndAliasMap.Insert("DataAreaBackup.DataBackup");
	
EndProcedure

// See CommonOverridable.OnDefineSupportedInterfaceVersions. 
Procedure OnDefineSupportedInterfaceVersions(Val SupportedVersionStructure) Export
	
	VersionsArray = New Array;
	VersionsArray.Add("1.0.1.1");
	VersionsArray.Add("1.0.1.2");
	SupportedVersionStructure.Insert("DataAreaBackup", VersionsArray);
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "DataAreaBackup.MoveBackupPlanningStateToAuxiliaryData";
	Handler.SharedData = True;
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.BackUpDataArea);
	Types.Add(Metadata.Constants.LastClientSessionStartDate);
	
EndProcedure

// See SaaSOverridable.OnFillIBParametersTable. 
Procedure OnFillIIBParametersTable(ParametersTable) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		CurParameterString = ModuleSaaS.AddConstantToIBParametersTable(ParametersTable, "BackupSupported");
	EndIf;
	
EndProcedure

// See JobQueueOverridable.OnDefineErrorHandlers. 
Procedure OnDefineErrorHandlers(ErrorHandlers) Export
	
	ErrorHandlers.Insert(
		"DataAreaBackup.DataBackup",
		"DataAreaBackup.BackupCreationError");
	
EndProcedure

// See MessageInterfacesSaaSOverridable.FillIncomingMessageHandlers. 
Procedure RecordingIncomingMessageInterfaces(HandlerArray) Export
	
	HandlerArray.Add(MessagesBackupManagementInterface);
	
EndProcedure

// See MessageInterfacesSaaSOverridable.FillOutgoingMessageHandlers. 
Procedure RecordingOutgoingMessageInterfaces(HandlerArray) Export
	
	HandlerArray.Add(MessagesBackupControlInterface);
	
EndProcedure

// Returns the method name of the background job that exports areas to files.
//
// Returns:
//   String - the method name.
//
Function BackgroundBackupMethodName() Export
	
	Return "DataAreaBackup.ExportAreaToSMStorage";
	
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Active users in data area.

// Sets or clears user activity flag in the current area.
// The flag is the value of the BackUpDataArea constant with Usage of split data set to Independent and Shared.
// Obsolete.
//
// Parameters:
// DataArea - Number; Undefined - Separator value. Undefined means the value of the current data 
//                 area separator.
// State - Boolean - True if the flag is set; False if cleared.
//
Procedure SetAreaActivityFlag(Val DataArea = Undefined, Val State = True)
	
	If DataArea = Undefined Then
		If SaaS.SeparatedDataUsageAvailable() Then
			DataArea = SaaS.SessionSeparatorValue();
		Else
			Raise NStr("ru = 'При вызове процедуры SetAreaActivityFlag из неразделенного сеанса параметр DataArea является обязательным.'; en = 'The DataArea parameter is required while calling the SetAreaActivityFlag procedure from the undivided session.'; pl = 'Podczas wywoływania procedury DataArea z nieudanego parametru sesji SetAreaActivityFlag jest obowiązkowe.';es_ES = 'Se requiere el parámetro DataArea durante la llamada del procedimiento SetActivityFlagInZone desde una sesión no dividida.';es_CO = 'Se requiere el parámetro DataArea durante la llamada del procedimiento SetActivityFlagInZone desde una sesión no dividida.';tr = 'Parametre DataArea , bölünmemiş oturumdan SetAreaActivityFlag prosedürünü çağırırken gereklidir.';it = 'Il parametro DataArea è richiesto durante la chiamata della procedura SetAreaActivityFlag dalla sessione ininterrotta.';de = 'Der DataArea-Parameter wird beim Aufruf der SetAreaActivityFlag-Prozedur aus der ungeteilten Sitzung benötigt.'");
		EndIf;
	Else
		If NOT SaaS.SessionWithoutSeparators()
				AND DataArea <> SaaS.SessionSeparatorValue() Then
			
			Raise(NStr("ru = 'Запрещено работать с данными области кроме текущей'; en = 'Cannot access data that belongs to another area'; pl = 'Praca z danymi obszaru poza bieżącym jest zabroniona';es_ES = 'Trabajo con los datos del área aparte del corriente está prohibido';es_CO = 'Trabajo con los datos del área aparte del corriente está prohibido';tr = 'Geçerli olanın dışındaki alan verileri ile çalışmak yasaktır.';it = 'Non è possibile accedere a dati che appartengono a un''altra area';de = 'Es ist verboten, mit Daten des Bereichs außerhalb des aktuellen Bereichs zu arbeiten'"));
			
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If State Then
		ValueManager = Constants.BackUpDataArea.CreateValueManager();
		ValueManager.DataAreaAuxiliaryData = DataArea;
		ValueManager.Read();
		If ValueManager.Value Then
			Return;
		EndIf;
	EndIf;
	
	ActivityFlag = Constants.BackUpDataArea.CreateValueManager();
	ActivityFlag.DataAreaAuxiliaryData = DataArea;
	ActivityFlag.Value = State;
	SaaS.WriteAuxiliaryData(ActivityFlag);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exporting data areas.

// Creates an area backup in accordance with the area backup settings.
// 
//
// Parameters:
//  CreationParameters - FixedStructure - backup creation parameters, which match the backup 
//   settings.
//  CreationState - FixedStructure - the state of backup creation in area.
//   
//
Procedure DataBackup(Val CreationParameters, Val CreationState) Export
	
	ExecutionStarted = CurrentUniversalDate();
	
	BackupCreationConditions = New Array;
	
	Parameters = New Structure;
	Parameters.Insert("Type", "DailyBackup");
	Parameters.Insert("Enabled", "CreateDaily");
	Parameters.Insert("Periodicity", "Day");
	Parameters.Insert("CreationDate", "LastDailyBackupCreationDate");
	Parameters.Insert("Day", Undefined);
	Parameters.Insert("Month", Undefined);
	BackupCreationConditions.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("Type", "MonthlyBackup");
	Parameters.Insert("Enabled", "CreateMonthly");
	Parameters.Insert("Periodicity", "Month");
	Parameters.Insert("CreationDate", "LastMonthlyBackupCreationDate");
	Parameters.Insert("Day", "MonthlyBackupCreationDay");
	Parameters.Insert("Month", Undefined);
	BackupCreationConditions.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("Type", "YearlyBackup");
	Parameters.Insert("Enabled", "CreateAnnual");
	Parameters.Insert("Periodicity", "Year");
	Parameters.Insert("CreationDate", "LastYearlyBackupCreationDate");
	Parameters.Insert("Day", "YearlyBackupCreationDay");
	Parameters.Insert("Month", "MonthOfEarlyBackup");
	BackupCreationConditions.Add(Parameters);
	
	CreationRequired = False;
	CurrentDate = CurrentUniversalDate();
	
	LastSession = Constants.LastClientSessionStartDate.Get();
	
	CreateUnconditionally = NOT CreationParameters.WhenUsersActiveOnly;
	
	PeriodicityFlags = New Structure;
	For each PeriodicityParameters In BackupCreationConditions Do
		
		PeriodicityFlags.Insert(PeriodicityParameters.Type, False);
		
		If NOT CreationParameters[PeriodicityParameters.Enabled] Then
			// Backups with this periodicity are disabled in the settings.
			Continue;
		EndIf;
		
		PreviousBackupCreationDate = CreationState[PeriodicityParameters.CreationDate];
		
		If Year(CurrentDate) = Year(PreviousBackupCreationDate) Then
			If PeriodicityParameters.Periodicity = "Year" Then
				// The year has not changed yet
				Continue;
			EndIf;
		EndIf;
		
		If Month(CurrentDate) = Month(PreviousBackupCreationDate) Then
			If PeriodicityParameters.Periodicity = "Month" Then
				// The month has not changed yet
				Continue;
			EndIf;
		EndIf;
		
		If Day(CurrentDate) = Day(PreviousBackupCreationDate) Then
			// The day has not changed yet
			Continue;
		EndIf;
		
		If PeriodicityParameters.Day <> Undefined
			AND Day(CurrentDate) < CreationParameters[PeriodicityParameters.Day] Then
			
			// The backup day has not come yet.
			Continue;
		EndIf;
		
		If PeriodicityParameters.Month <> Undefined
			AND Month(CurrentDate) < CreationParameters[PeriodicityParameters.Month] Then
			
			// The backup month has not come yet.
			Continue;
		EndIf;
		
		If NOT CreateUnconditionally
			AND ValueIsFilled(PreviousBackupCreationDate)
			AND LastSession < PreviousBackupCreationDate Then
			
			// Users did not enter the area since the backup creation.
			Continue;
		EndIf;
		
		CreationRequired = True;
		PeriodicityFlags.Insert(PeriodicityParameters.Type, True);
		
	EndDo;
	
	If NOT CreationRequired Then
		WriteLogEvent(
			EventLogEvent() + "." 
				+ NStr("ru = 'Пропуск создания'; en = 'Skipping backup creation'; pl = 'Pomiń tworzenie';es_ES = 'Saltar la creación';es_CO = 'Saltar la creación';tr = 'Oluşturmayı geç';it = 'Saltare creazione backup';de = 'Skip creation'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Information);
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not Common.SubsystemExists("CloudTechnology.SaaS.ExportImportDataAreas") Then
		
		SaaS.RaiseNoCTLSubsystemException("CloudTechnology.SaaS.ExportImportDataAreas");
		
	EndIf;
	
	ModuleExportImportDataAreas = Common.CommonModule("ExportImportDataAreas");
	
	ArchiveName = Undefined;
	
	Try
	
		ArchiveName = ModuleExportImportDataAreas.ExportCurrentDataAreaToArchive();
		
		BackupCreationDate = CurrentUniversalDate();
		
		ArchiveDescription = New File(ArchiveName);
		FileSize = ArchiveDescription.Size();
		
		FileID = SaaS.PutFileInServiceManagerStorage(ArchiveDescription);
		
		Try
			DeleteFiles(ArchiveName);
		Except
			// If a file cannot be deleted, backup creation must not be interrupted.
			WriteLogEvent(NStr("ru = 'Создание резервной копии области данных.Не удалось удалить временный файл'; en = 'Backing up data area. Cannot delete temporary file.'; pl = 'Tworzenie kopii zapasowej obszaru danych.Nie można usunąć pliku tymczasowego';es_ES = 'Crear la copia de respaldo del área de datos.No se ha podido eliminar el archivo temporal';es_CO = 'Crear la copia de respaldo del área de datos.No se ha podido eliminar el archivo temporal';tr = 'Yedek veri alanı oluştur. Geçici dosya silinemedi';it = 'Creazione back up dell''area dati. Impossibile eliminare il file temporaneo.';de = 'Erstellen Sie ein Backup des Datenbereichs. Die temporäre Datei konnte nicht gelöscht werden'", CommonClientServer.DefaultLanguageCode()), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		BackupID = New UUID;
		
		MessageParameters = New Structure;
		MessageParameters.Insert("DataArea", SaaS.SessionSeparatorValue());
		MessageParameters.Insert("BackupID", BackupID);
		MessageParameters.Insert("FileID", FileID);
		MessageParameters.Insert("CreationDate", BackupCreationDate);
		For each KeyAndValue In PeriodicityFlags Do
			MessageParameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		
		SendAreaBackupCreatedMessage(MessageParameters);
		
		// Refreshing status in the parameters.
		JobsFilter = New Structure;
		JobsFilter.Insert("MethodName", "DataAreaBackup.DataBackup");
		JobsFilter.Insert("Key", "1");
		Jobs = JobQueue.GetJobs(JobsFilter);
		If Jobs.Count() > 0 Then
			Job = Jobs[0].ID;
			
			MethodParameters = New Array;
			MethodParameters.Add(CreationParameters);
			
			UpdatedState = New Structure;
			For each PeriodicityParameters In BackupCreationConditions Do
				If PeriodicityFlags[PeriodicityParameters.Type] Then
					StatusDate = BackupCreationDate;
				Else
					StatusDate = CreationState[PeriodicityParameters.CreationDate];
				EndIf;
				
				UpdatedState.Insert(PeriodicityParameters.CreationDate, StatusDate);
			EndDo;
			
			MethodParameters.Add(New FixedStructure(UpdatedState));
			
			JobParameters = New Structure;
			JobParameters.Insert("Parameters", MethodParameters);
			JobQueue.ChangeJob(Job, JobParameters);
		EndIf;
		
		EventParameters = New Structure;
		For each KeyAndValue In PeriodicityFlags Do
			EventParameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		EventParameters.Insert("BackupID", BackupID);
		EventParameters.Insert("FileId", FileID);
		EventParameters.Insert("Size", FileSize);
		EventParameters.Insert("Duration", CurrentUniversalDate() - ExecutionStarted);
		
		WriteEventToLog(
			NStr("ru = 'Создание'; en = 'Create'; pl = 'Utwórz';es_ES = 'Crear';es_CO = 'Crear';tr = 'Oluştur';it = 'Crea';de = 'Erstellen'", CommonClientServer.DefaultLanguageCode()),
			EventParameters);
			
	Except
		
		WriteLogEvent(NStr("ru = 'Создание резервной копии области данных'; en = 'Creating data area backup'; pl = 'Tworzenie kopii zapasowych obszaru danych';es_ES = 'Copia de respaldo del área de datos';es_CO = 'Copia de respaldo del área de datos';tr = 'Veri alanı yedekleme';it = 'Creazione backup area dati';de = 'Datenbereichssicherung'", CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			If ArchiveName <> Undefined Then
				DeleteFiles(ArchiveName);
			EndIf;
		Except
			// If a file cannot be deleted, backup creation must not be interrupted.
			WriteLogEvent(NStr("ru = 'Создание резервной копии области данных.Не удалось удалить временный файл'; en = 'Backing up data area. Cannot delete temporary file.'; pl = 'Tworzenie kopii zapasowej obszaru danych.Nie można usunąć pliku tymczasowego';es_ES = 'Crear la copia de respaldo del área de datos.No se ha podido eliminar el archivo temporal';es_CO = 'Crear la copia de respaldo del área de datos.No se ha podido eliminar el archivo temporal';tr = 'Yedek veri alanı oluştur. Geçici dosya silinemedi';it = 'Creazione back up dell''area dati. Impossibile eliminare il file temporaneo.';de = 'Erstellen Sie ein Backup des Datenbereichs. Die temporäre Datei konnte nicht gelöscht werden'", CommonClientServer.DefaultLanguageCode()), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
			
	EndTry;
	
EndProcedure

// When the number of attempts to backup copy is exhausted, writes in the event log a message that 
// the copy was not created.
//
// Parameters:
//  JobParameters - Structure - structure properties, see JobQueueOverridable.OnDefineErrorHandlers.
//    
//
Procedure BackupCreationError(Val JobParameters, Val ErrorInformation) Export
	
	If JobParameters.AttemptNumber < JobParameters.RestartCountOnFailure Then
		CommentTemplate = NStr("ru = 'При создании резервной копии области %1 произошла ошибка.
			|Номер попытки: %2
			|По причине:
			|%3'; 
			|en = 'When creating backup for area %1, an error occurred.
			|Attempt number: %2
			|Due to:
			|%3'; 
			|pl = 'Podczas tworzenia obszaru %1 kopii zapasowej wystąpił błąd.
			|Numer próby: %2
			|Z powodu:
			|%3';
			|es_ES = 'Ha ocurrido un error al crear la copia de respaldo del área%1.
			|Número de intento: %2
			|A causa de:
			|%3';
			|es_CO = 'Ha ocurrido un error al crear la copia de respaldo del área%1.
			|Número de intento: %2
			|A causa de:
			|%3';
			|tr = 'Alan yedeği oluşturulurken bir hata oluştu %1. 
			|Deneme sayısı: %2
			| Nedeni:
			|%3';
			|it = 'Si è verificato un errore durante la creazione del backup per l''area %1.
			|Tentativo numero:%2
			|A causa di:
			|%3';
			|de = 'Beim Erstellen einer Bereichssicherung %1 ist ein Fehler aufgetreten.
			|Versuchsnummer: %2
			|Aus dem folgenden Grund:
			|%3'");
		Level = EventLogLevel.Warning;
		Event = NStr("ru = 'Ошибка итерации создания'; en = 'Backup creation attempt error'; pl = 'Błąd iteracji tworzenia';es_ES = 'Error de iteración de creación';es_CO = 'Error de iteración de creación';tr = 'Oluşturma yineleme hatası';it = 'Errore di tentativo di creazione di backup';de = 'Erstellungsiterationsfehler'", CommonClientServer.DefaultLanguageCode());
	Else
		CommentTemplate = NStr("ru = 'При создании резервной копии области %1 произошла невосстановимая ошибка.
			|Номер попытки: %2
			|По причине:
			|%3'; 
			|en = 'When creating backup for area %1, an unrecoverable error occurred.
			|Attempt number: %2
			|Due to:
			|%3'; 
			|pl = 'Podczas tworzenia obszaru %1 kopii zapasowej wystąpił błąd niespójności.
			|Numer próby: %2
			|Z powodu:
			|%3';
			|es_ES = 'Ha ocurrido un error grave al crear la copia de respaldo del área %1.
			|Número de intento: %2
			|A causa de:
			|%3';
			|es_CO = 'Ha ocurrido un error grave al crear la copia de respaldo del área %1.
			|Número de intento: %2
			|A causa de:
			|%3';
			|tr = 'Alan yedeği oluşturulurken düzenlenemez bir hata oluştu %1. 
			|Deneme sayısı: %2
			|Nedeni:
			|%3';
			|it = 'Si è verificato un errore critico durante la creazione del backup per l''area %1.
			|Tentativo numero: %2
			|A causa di:
			|%3';
			|de = 'Beim Erstellen eines Bereichs-Backups %1 ist ein nicht behebbarer Fehler aufgetreten.
			|Versuchsnummer: %2
			|Aus dem folgenden Grund:
			|%3'");
		Level = EventLogLevel.Error;
		Event = NStr("ru = 'Ошибка создания'; en = 'Creation error'; pl = 'Błąd tworzenia';es_ES = 'Error de creación';es_CO = 'Error de creación';tr = 'Oluşturma hatası';it = 'Errore di creazione';de = 'Erstellungsfehler'", CommonClientServer.DefaultLanguageCode());
	EndIf;
	
	CommentText = StringFunctionsClientServer.SubstituteParametersToString(
		CommentTemplate,
		Format(SaaS.SessionSeparatorValue(), "NZ=0; NG="),
		JobParameters.AttemptNumber,
		DetailErrorDescription(ErrorInformation));
		
	WriteLogEvent(
		EventLogEvent() + "." + Event,
		Level,
		,
		,
		CommentText);
	
EndProcedure

// Schedules data area backup creation.
// 
// Parameters:
//  ExportParameters - Structure, key list see CreateEmptyExportParameters(). 
//   
Procedure ScheduleArchivingInQueue(Val ExportParameters) Export
	
	If Not Users.IsFullUser() Then
		Raise(NStr("ru = 'Не достаточно прав для выполнения операции'; en = 'Insufficient rights for the operation'; pl = 'Niewystarczające uprawnienia do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operación';es_CO = 'Insuficientes derechos para realizar la operación';tr = 'İşlemi gerçekleştirmek için yetersiz haklar';it = 'Permessi insufficienti per l''operazione';de = 'Nicht genügend Rechte auf Ausführen der Operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	MethodParameters = New Array;
	MethodParameters.Add(ExportParameters);
	MethodParameters.Add(Undefined);
	
	JobParameters = New Structure;
	JobParameters.Insert("MethodName", BackgroundBackupMethodName());
	JobParameters.Insert("Key", "" + ExportParameters.BackupID);
	JobParameters.Insert("DataArea", ExportParameters.DataArea);
	
	// Searching for active jobs with the same key.
	ActiveJobs = JobQueue.GetJobs(JobParameters);
	
	If ActiveJobs.Count() = 0 Then
		
		// Planning execution of the new.
		
		JobParameters.Insert("Parameters", MethodParameters);
		JobParameters.Insert("ScheduledStartTime", ExportParameters.StartedAt);
		
		JobQueue.AddJob(JobParameters);
	Else
		If ActiveJobs[0].JobState <> Enums.JobsStates.Scheduled Then
			// The job is already completed or is running.
			Return;
		EndIf;
		
		JobParameters.Delete("DataArea");
		
		JobParameters.Insert("Use", True);
		JobParameters.Insert("Parameters", MethodParameters);
		JobParameters.Insert("ScheduledStartTime", ExportParameters.StartedAt);
		
		JobQueue.ChangeJob(ActiveJobs[0].ID, JobParameters);
	EndIf;
	
EndProcedure

// Creates a data export file in the specified area and puts it in a service manager storage.
//
// Parameters:
// Parameters - Structure:
// 	- DataArea - Number.
//	- CopyID - UUID; Undefined.
//  - StartTime - Date - area backup start time.
//	- Forcibly - Boolean - flag from the service manager: create backup regardless of the user activity.
//	- OnDemand - Boolean - flag of the interactive backup start. If from MS, always False.
//	- FileID - UUID - export file ID in MS storage.
//	- AttemptNumber - Number - attempts counter. Initial value: 1.
//
Procedure ExportAreaToSMStorage(Val Parameters, ResultAddress = Undefined) Export
	
	If NOT Users.IsFullUser() Then
		Raise(NStr("ru = 'Нарушение прав доступа'; en = 'Access right violation'; pl = 'Naruszenie praw dostępu';es_ES = 'Violación del derecho de acceso';es_CO = 'Violación del derecho de acceso';tr = 'Erişim hakkı ihlali';it = 'Violazione di accesso a destra';de = 'Zugriffsrechtsverletzung'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not ExportRequired(Parameters) Then
		SendAreaBackupSkippedMessage(Parameters);
		Return;
	EndIf;
	
	If Not Common.SubsystemExists("CloudTechnology.SaaS.ExportImportDataAreas") Then
		
		SaaS.RaiseNoCTLSubsystemException("CloudTechnology.SaaS.ExportImportDataAreas");
		
	EndIf;
	
	ModuleExportImportDataAreas = Common.CommonModule("ExportImportDataAreas");
	
	ArchiveName = Undefined;
	
	Try
		
		ArchiveName = ModuleExportImportDataAreas.ExportCurrentDataAreaToArchive();
		FileID = SaaS.PutFileInServiceManagerStorage(New File(ArchiveName));
		Try
			DeleteFiles(ArchiveName);
		Except
			// If a file cannot be deleted, backup creation must not be interrupted.
			WriteLogEvent(NStr("ru = 'Создание резервной копии области данных.Не удалось удалить временный файл'; en = 'Backing up data area. Cannot delete temporary file.'; pl = 'Tworzenie kopii zapasowej obszaru danych.Nie można usunąć pliku tymczasowego';es_ES = 'Crear la copia de respaldo del área de datos.No se ha podido eliminar el archivo temporal';es_CO = 'Crear la copia de respaldo del área de datos.No se ha podido eliminar el archivo temporal';tr = 'Yedek veri alanı oluştur. Geçici dosya silinemedi';it = 'Creazione back up dell''area dati. Impossibile eliminare il file temporaneo.';de = 'Erstellen Sie ein Backup des Datenbereichs. Die temporäre Datei konnte nicht gelöscht werden'", CommonClientServer.DefaultLanguageCode()), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		BeginTransaction();
		
		Try
			
			Parameters.Insert("FileID", FileID);
			Parameters.Insert("CreationDate", CurrentUniversalDate());
			SendAreaBackupCreatedMessage(Parameters);
			If ValueIsFilled(ResultAddress) Then
				PutToTempStorage(FileID, ResultAddress);
			EndIf;
			SetAreaActivityFlag(Parameters.DataArea, False);
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			Raise;
			
		EndTry;
		
	Except
		
		WriteLogEvent(NStr("ru = 'Создание резервной копии области данных'; en = 'Creating data area backup'; pl = 'Tworzenie kopii zapasowych obszaru danych';es_ES = 'Copia de respaldo del área de datos';es_CO = 'Copia de respaldo del área de datos';tr = 'Veri alanı yedekleme';it = 'Creazione backup area dati';de = 'Datenbereichssicherung'", CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			If ArchiveName <> Undefined Then
				DeleteFiles(ArchiveName);
			EndIf;
		Except
			// If a file cannot be deleted, backup creation must not be interrupted.
			WriteLogEvent(NStr("ru = 'Создание резервной копии области данных.Не удалось удалить временный файл'; en = 'Backing up data area. Cannot delete temporary file.'; pl = 'Tworzenie kopii zapasowej obszaru danych.Nie można usunąć pliku tymczasowego';es_ES = 'Crear la copia de respaldo del área de datos.No se ha podido eliminar el archivo temporal';es_CO = 'Crear la copia de respaldo del área de datos.No se ha podido eliminar el archivo temporal';tr = 'Yedek veri alanı oluştur. Geçici dosya silinemedi';it = 'Creazione back up dell''area dati. Impossibile eliminare il file temporaneo.';de = 'Erstellen Sie ein Backup des Datenbereichs. Die temporäre Datei konnte nicht gelöscht werden'", CommonClientServer.DefaultLanguageCode()), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
		If Parameters.OnDemand Then
			Raise;
		Else	
			If Parameters.AttemptNumber > 3 Then
				SendAreaBackupErrorMessage(Parameters);
				Raise;
			Else	
				// Job cancel.
				CancelAreaBackingUp(Parameters);
				
				// Rescheduling: current area time + 10 minutes.
				Parameters.AttemptNumber = Parameters.AttemptNumber + 1;
				RestartMoment = CurrentAreaDate(Parameters.DataArea); // Current area time.
				RestartMoment = RestartMoment + 10 * 60; // 10 minutes later.
				Parameters.Insert("StartedAt", RestartMoment);
				ScheduleArchivingInQueue(Parameters);
			EndIf;
		EndIf;
	EndTry;
	
EndProcedure

Function CurrentAreaDate(Val DataArea)
	
	TimeZone = SaaS.GetDataAreaTimeZone(DataArea);
	Return ToLocalTime(CurrentUniversalDate(), TimeZone);
	
EndFunction

Function ExportRequired(Val ExportParameters)
	
	If NOT SaaS.SessionWithoutSeparators()
		AND ExportParameters.DataArea <> SaaS.SessionSeparatorValue() Then
		
		Raise(NStr("ru = 'Запрещено работать с данными области кроме текущей'; en = 'Cannot access data that belongs to another area'; pl = 'Praca z danymi obszaru poza bieżącym jest zabroniona';es_ES = 'Trabajo con los datos del área aparte del corriente está prohibido';es_CO = 'Trabajo con los datos del área aparte del corriente está prohibido';tr = 'Geçerli olanın dışındaki alan verileri ile çalışmak yasaktır.';it = 'Non è possibile accedere a dati che appartengono a un''altra area';de = 'Es ist verboten, mit Daten des Bereichs außerhalb des aktuellen Bereichs zu arbeiten'"));
	EndIf;
	
	Result = ExportParameters.Forcibly;
	
	If Not Result Then
		
		Manager = Constants.BackUpDataArea.CreateValueManager();
		Manager.DataAreaAuxiliaryData = ExportParameters.DataArea;
		Manager.Read();
		Result = Manager.Value;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Creates a blank structure of a necessary format.
//
// Returns:
// Structure:
// 	- DataArea - Number.
//	- CopyID - UUID; Undefined.
//  - StartTime - Date - area backup start time.
//	- Forcibly - Boolean - flag from the service manager: create backup regardless of the user activity.
//	- OnDemand - Boolean - flag of the interactive backup start. If from MS, always False.
//	- FileID - UUID - export file ID in MS storage.
//	- AttemptNumber - Number - attempts counter. Initial value: 1.
//
Function CreateEmptyExportParameters() Export
	
	ExportParameters = New Structure;
	ExportParameters.Insert("DataArea");
	ExportParameters.Insert("BackupID");
	ExportParameters.Insert("StartedAt");
	ExportParameters.Insert("Forcibly");
	ExportParameters.Insert("OnDemand");
	ExportParameters.Insert("FileID");
	ExportParameters.Insert("AttemptNumber", 1);
	Return ExportParameters;
	
EndFunction

// Cancels previously scheduled backup creation.
//
// CancellationParameters - Structure
//  DataArea - Number - data area where backup to be cancelled.
//  CopyID - UUID - ID of the backup to be cancelled.
//
Procedure CancelAreaBackingUp(Val CancellationParameters) Export
	
	If Not Users.IsFullUser() Then
		Raise(NStr("ru = 'Не достаточно прав для выполнения операции'; en = 'Insufficient rights for the operation'; pl = 'Niewystarczające uprawnienia do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operación';es_CO = 'Insuficientes derechos para realizar la operación';tr = 'İşlemi gerçekleştirmek için yetersiz haklar';it = 'Permessi insufficienti per l''operazione';de = 'Nicht genügend Rechte auf Ausführen der Operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	MethodName = BackgroundBackupMethodName();
	
	Filter = New Structure("MethodName, Key, DataArea", 
		MethodName, "" + CancellationParameters.BackupID, CancellationParameters.DataArea);
	Jobs = JobQueue.GetJobs(Filter);
	
	For Each Job In Jobs Do
		JobQueue.DeleteJob(Job.ID);
	EndDo;
	
EndProcedure

// Notifies about successful backup of the current area.
//
Procedure SendAreaBackupCreatedMessage(Val MessageParameters)
	
	BeginTransaction();
	
	Try
		
		Message = MessagesSaaS.NewMessage(
			MessagesBackupControlInterface.AreaBackupCreatedMessage());
		
		Body = Message.Body;
		
		Body.Zone = MessageParameters.DataArea;
		Body.BackupId = MessageParameters.BackupID;
		Body.FileId = MessageParameters.FileID;
		Body.Date = MessageParameters.CreationDate;
		If MessageParameters.Property("DailyBackup") Then
			Body.Daily = MessageParameters.DailyBackup;
			Body.Monthly = MessageParameters.MonthlyBackup;
			Body.Yearly = MessageParameters.YearlyBackup;
		Else
			Body.Daily = False;
			Body.Monthly = False;
			Body.Yearly = False;
		EndIf;
		Body.ConfigurationVersion = Metadata.Version;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaS.ServiceManagerEndpoint());
			
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Schedules area backup in the applied base.
//
Procedure SendAreaBackupErrorMessage(Val MessageParameters)
	
	BeginTransaction();
	Try
		
		Message = MessagesSaaS.NewMessage(
			MessagesBackupControlInterface.AreaBackupErrorMessage());
		
		Message.Body.Zone = MessageParameters.DataArea;
		Message.Body.BackupId = MessageParameters.BackupID;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaS.ServiceManagerEndpoint());
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Schedules area backup in the applied base.
//
Procedure SendAreaBackupSkippedMessage(Val MessageParameters)
	
	BeginTransaction();
	Try
		
		Message = MessagesSaaS.NewMessage(
			MessagesBackupControlInterface.AreaBackupSkippedMessage());
		
		Message.Body.Zone = MessageParameters.DataArea;
		Message.Body.BackupId = MessageParameters.BackupID;
		
		MessagesSaaS.SendMessage(
			Message,
			SaaS.ServiceManagerEndpoint());
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Function EventLogEvent()
	
	Return NStr("ru = 'Резервное копирование приложений'; en = 'Application backup'; pl = 'Kopia zapasowa aplikacji';es_ES = 'Copia de respaldo de la aplicación';es_CO = 'Copia de respaldo de la aplicación';tr = 'Uygulama yedekleme';it = 'Applicazione di backup';de = 'Anwendungssicherung'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Procedure WriteEventToLog(Val Event, Val Parameters)
	
	WriteLogEvent(
		EventLogEvent() + "." + Event,
		EventLogLevel.Information,
		,
		,
		Common.ValueToXMLString(Parameters));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with backup settings.

// Returns the data area backup settings structure.
//
// Parameters:
// DataArea - Number; Undefined - if Undefined, returns the system settings.
//
// Returns:
// Structure - settings structure.
//	See DataAreaBackupCached.MapBetweenSMSettingsAndAppSettings(). 
//
Function GetAreaBackupSettings(Val DataArea = Undefined) Export
	
	If NOT SaaS.SessionWithoutSeparators()
		AND DataArea <> SaaS.SessionSeparatorValue() 
		AND DataArea <> Undefined Then
		
		Raise(NStr("ru = 'Запрещено работать с данными области кроме текущей'; en = 'Cannot access data that belongs to another area'; pl = 'Praca z danymi obszaru poza bieżącym jest zabroniona';es_ES = 'Trabajo con los datos del área aparte del corriente está prohibido';es_CO = 'Trabajo con los datos del área aparte del corriente está prohibido';tr = 'Geçerli olanın dışındaki alan verileri ile çalışmak yasaktır.';it = 'Non è possibile accedere a dati che appartengono a un''altra area';de = 'Es ist verboten, mit Daten des Bereichs außerhalb des aktuellen Bereichs zu arbeiten'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Proxy = DataAreasBackupCached.BackupControlProxy();
	
	XDTOSettings = Undefined;
	ErrorMessage = Undefined;
	If DataArea = Undefined Then
		ActionCompleted = Proxy.GetDefaultSettings(XDTOSettings, ErrorMessage);
	Else
		ActionCompleted = Proxy.GetSettings(DataArea, XDTOSettings, ErrorMessage);
	EndIf;
	
	If NOT ActionCompleted Then
		MessageTemplate = NStr("ru = 'Ошибка при получении настроек резервного копирования:
			|%1'; 
			|en = 'An error occurred when receiving backup settings:
			|%1'; 
			|pl = 'Błąd podczas pobierania ustawień kopii zapasowej:
			|%1';
			|es_ES = 'Ha ocurrido un error al recibir los ajustes de la copia de respaldo:
			|%1';
			|es_CO = 'Ha ocurrido un error al recibir los ajustes de la copia de respaldo:
			|%1';
			|tr = 'Yedekleme 
			|alınırken bir hata oluştu:%1';
			|it = 'Si è verificato un errore durante la ricezione delle impostazioni di backup:
			|%1';
			|de = 'Fehler beim Empfangen von Backup-Einstellungen:
			|%1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ErrorMessage);
		Raise(MessageText);
	EndIf;
	
	Return XDTOSettingsToStructure(XDTOSettings);
	
EndFunction	

// Writes data area backup settings to the service manager storage.
//
// Parameters:
// DataArea - Number.
// BackupSettings - Structure.
//
// Returns:
// Boolean - flag specifying whether data was written successfully.
//
Procedure SetAreaBackupSettings(Val DataArea, Val BackupSettings) Export
	
	If NOT SaaS.SessionWithoutSeparators()
		AND DataArea <> SaaS.SessionSeparatorValue() Then
		
		Raise(NStr("ru = 'Запрещено работать с данными области кроме текущей'; en = 'Cannot access data that belongs to another area'; pl = 'Praca z danymi obszaru poza bieżącym jest zabroniona';es_ES = 'Trabajo con los datos del área aparte del corriente está prohibido';es_CO = 'Trabajo con los datos del área aparte del corriente está prohibido';tr = 'Geçerli olanın dışındaki alan verileri ile çalışmak yasaktır.';it = 'Non è possibile accedere a dati che appartengono a un''altra area';de = 'Es ist verboten, mit Daten des Bereichs außerhalb des aktuellen Bereichs zu arbeiten'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Proxy = DataAreasBackupCached.BackupControlProxy();
	
	Type = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ZoneBackupControl", "Settings");
	XDTOSettings = Proxy.XDTOFactory.Create(Type);
	
	NameMap = DataAreasBackupCached.MapBetweenSMSettingsAndAppSettings();
	For Each SettingsNamePair In NameMap Do
		XDTOSettings[SettingsNamePair.Key] = BackupSettings[SettingsNamePair.Value];
	EndDo;
	
	ErrorMessage = Undefined;
	If NOT Proxy.SetSettings(DataArea, XDTOSettings, ErrorMessage) Then
		MessageTemplate = NStr("ru = 'Ошибка при сохранении настроек резервного копирования:
                                |%1'; 
                                |en = 'An error occurred when saving backup settings:
                                |%1'; 
                                |pl = 'Błąd podczas zapisywania ustawień kopii zapasowej:
                                |%1';
                                |es_ES = 'Ha ocurrido un error al guardar los ajustes de la copia de respaldo:
                                |%1';
                                |es_CO = 'Ha ocurrido un error al guardar los ajustes de la copia de respaldo:
                                |%1';
                                |tr = 'Yedekleme 
                                |alınırken bir hata oluştu:%1';
                                |it = 'Si è verificato un errore durante il salvataggio delle impostazioni di backup:
                                |%1';
                                |de = 'Fehler beim Speichern der Backup-Einstellungen:
                                |%1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ErrorMessage);
		Raise(MessageText);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Type conversion

Function XDTOSettingsToStructure(Val XDTOSettings)
	
	If XDTOSettings = Undefined Then
		Return Undefined;
	EndIf;	
	
	Result = New Structure;
	NameMap = DataAreasBackupCached.MapBetweenSMSettingsAndAppSettings();
	For Each SettingsNamePair In NameMap Do
		If XDTOSettings.IsSet(SettingsNamePair.Key) Then
			Result.Insert(SettingsNamePair.Value, XDTOSettings[SettingsNamePair.Key]);
		EndIf;
	EndDo;
	Return  Result; 
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Transfers data from DELETE register to the values of a BackUpDataArea shared constant.
// 
//
Procedure MoveBackupPlanningStateToAuxiliaryData() Export
	
	If Not SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		QueryText = 
		"SELECT
		|	DeleteAreasForBackup.DataArea
		|FROM
		|	InformationRegister.DeleteAreasForBackup AS DeleteAreasForBackup";
		Query = New Query(QueryText);
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			PlanningState = Constants.BackUpDataArea.CreateValueManager();
			PlanningState.DataAreaAuxiliaryData = Selection.DataArea;
			PlanningState.Value = True;
			PlanningState.Write();
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion
