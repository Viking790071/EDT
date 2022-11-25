#Region Public

// The processing of incoming messages of type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}PlanZoneBackup.
//
// Parameters:
//  DataAreaCode - Number - code of data area,
//  BackupID - UUID - backup ID,
//  BackupEventTime - Date - date and time of backup,
//  Forcibly - Boolean - forced backup creation flag.
//
Procedure ScheduleAreaBackingUp(Val DataAreaCode,
		Val BackupID, Val BackupEventTime,
		Val Forcibly) Export
	
	ExportParameters = DataAreaBackup.CreateEmptyExportParameters();
	ExportParameters.DataArea = DataAreaCode;
	ExportParameters.BackupID = BackupID;
	ExportParameters.StartedAt = ToLocalTime(BackupEventTime, // Converting universal time to local time
		// Because the job queue requires the local time.
		SaaS.GetDataAreaTimeZone(DataAreaCode));
	ExportParameters.Forcibly = Forcibly;
	ExportParameters.OnDemand = False;
	
	DataAreaBackup.ScheduleArchivingInQueue(ExportParameters);
	
EndProcedure

// The processing of incoming messages of type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelZoneBackup.
//
// Parameters:
//  DataAreaCode - Number - code of data area,
//  BackupID - UUID - backup ID.
//
Procedure CancelAreaBackingUp(Val DataAreaCode, Val BackupID) Export
	
	CancellationParameters = New Structure("DataArea, BackupID", DataAreaCode, BackupID);
	DataAreaBackup.CancelAreaBackingUp(CancellationParameters);
	
EndProcedure

// The processing of incoming messages of type
// {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}UpdateScheduledZoneBackupSettings.
//
// Parameters:
//  DataArea - Number - value of the data area separator.
//  Settings - Structure - new backup settings.
Procedure UpdatePeriodicBackupSettings(Val DataArea, Val Settings) Export
	
	CreationParameters = New Structure;
	CreationParameters.Insert("CreateDaily");
	CreationParameters.Insert("CreateMonthly");
	CreationParameters.Insert("CreateAnnual");
	CreationParameters.Insert("WhenUsersActiveOnly");
	CreationParameters.Insert("MonthlyBackupCreationDay");
	CreationParameters.Insert("MonthOfEarlyBackup");
	CreationParameters.Insert("YearlyBackupCreationDay");
	FillPropertyValues(CreationParameters, Settings);
	
	CreationState = New Structure;
	CreationState.Insert("LastDailyBackupCreationDate");
	CreationState.Insert("LastMonthlyBackupCreationDate");
	CreationState.Insert("LastYearlyBackupCreationDate");
	FillPropertyValues(CreationState, Settings);
	
	MethodParameters = New Array;
	MethodParameters.Add(New FixedStructure(CreationParameters));
	MethodParameters.Add(New FixedStructure(CreationState));
	
	Schedule = New JobSchedule;
	Schedule.BeginTime = Settings.BackupsCreationIntervalStart;
	Schedule.EndTime = Settings.BackupsCreationIntervalEnd;
	Schedule.DaysRepeatPeriod = 1;
	
	JobParameters = New Structure;
	JobParameters.Insert("Parameters", MethodParameters);
	JobParameters.Insert("Schedule", Schedule);
	
	JobFilter = New Structure;
	JobFilter.Insert("DataArea", DataArea);
	JobFilter.Insert("MethodName", "DataAreaBackup.DataBackup");
	JobFilter.Insert("Key", "1");
	
	BeginTransaction();
	Try
		Jobs = JobQueue.GetJobs(JobFilter);
		If Jobs.Count() > 0 Then
			JobQueue.ChangeJob(Jobs[0].ID, JobParameters);
		Else
			JobParameters.Insert("DataArea", DataArea);
			JobParameters.Insert("MethodName", "DataAreaBackup.DataBackup");
			JobParameters.Insert("Key", "1");
			JobParameters.Insert("RestartCountOnFailure", 3);
			JobParameters.Insert("RestartIntervalOnFailure", 600); // 10 minutes
			JobQueue.AddJob(JobParameters);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// The processing of incoming messages of type {http://www.1c.ru/SaaS/ManageZonesBackup/a.b.c.d}CancelScheduledZoneBackup.
//
// Parameters:
//  DataArea - Number - value of the data area separator.
Procedure CancelPeriodicBackup(Val DataArea) Export
	
	JobFilter = New Structure;
	JobFilter.Insert("DataArea", DataArea);
	JobFilter.Insert("MethodName", "DataAreaBackup.DataBackup");
	JobFilter.Insert("Key", "1");
	
	BeginTransaction();
	Try
		Jobs = JobQueue.GetJobs(JobFilter);
		If Jobs.Count() > 0 Then
			JobQueue.DeleteJob(Jobs[0].ID);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion
