
#Region Internal

// Calculates the next job start time.
// 
// Parameters:
// Schedule                  - JobSchedule - a schedule.
//                               
// TimeZone				 - String.
// LastRunStartDate - Date - start date of the last start of scheduled job.
//                               If the date is set, it will be used to check conditions such as
//                               DaysRepeatPeriod, WeeksPeriod, RepeatPeriodInDay.
//                               If the date is not set, the job is considered to have never started 
//                               and these conditions are not checked.
// 
// Returns:
// Date - Next job start time calculated.
// 
Function GetScheduledJobStartTime(Val Schedule, Val TimeZone, 
		Val LastRunStartDate = '00010101', Val LastStartCompletedOn = '00010101') Export
	
	If IsBlankString(TimeZone) Then
		TimeZone = Undefined;
	EndIf;
	
	If ValueIsFilled(LastRunStartDate) Then 
		LastRunStartDate = ToLocalTime(LastRunStartDate, TimeZone);
	EndIf;
	
	If ValueIsFilled(LastStartCompletedOn) Then
		LastStartCompletedOn = ToLocalTime(LastStartCompletedOn, TimeZone);
	EndIf;
	
	CalculationDate = ToLocalTime(CurrentUniversalDate(), TimeZone);
	
	FoundDate = NextScheduleExecutionDate(Schedule, CalculationDate, LastRunStartDate, LastStartCompletedOn);
	
	If ValueIsFilled(FoundDate) Then
		Return ToUniversalTime(FoundDate, TimeZone);
	Else
		Return FoundDate;
	EndIf;
	
EndFunction

// Returns manager of the JobQueue catalog.
Function CatalogJobQueue() Export
	
	Return Common.ObjectManagerByFullName("Catalog.JobQueue");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "JobQueueInternal.SetScheduledJobsUsage";
	Handler.SharedData = True;
	Handler.Priority = 50;
	Handler.ExclusiveMode = False;
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "JobQueueInternal.MoveQueueJobsToUnseparatedData";
	Handler.SharedData = True;
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 80;
	Handler.ExclusiveMode = True;
	
	If SaaS.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.Version = "2.4.6.105";
		Handler.Procedure = "JobQueueInternal.ScheduleIdleTasts";
		Handler.SharedData = True;
		Handler.ExecutionMode = "Seamless";
	EndIf;
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Cannot import to the JobQueue catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.JobQueue.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
	// Cannot import to the QueueJobTemplates catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.QueueJobTemplates.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See SaaSOverridable.OnEnableDataSeparation. 
Procedure OnEnableSeparationByDataAreas() Export
	
	SetScheduledJobsUsage();
	
	If Constants.MaxActiveBackgroundJobExecutionTime.Get() = 0 Then
		Constants.MaxActiveBackgroundJobExecutionTime.Set(600);
	EndIf;
	
	If Constants.MaxActiveBackgroundJobCount.Get() = 0 Then
		Constants.MaxActiveBackgroundJobCount.Set(1);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Generates execution schedule for jobs in JobQueue information register.
// 
Procedure JobProcessingPlanning() Export
	
	If NOT SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// OnScheduledJobStart is not called because the necessary actions are executed privately.
	// 
	
	// Selecting events with Executing, Completed, NotScheduled, or ExecutionError status.
	Query = New Query;
	
	JobCatalogs = JobsQueueInternalCached.GetJobCatalogs();
	QueryText = "";
	For Each CatalogJob In JobCatalogs Do
		
		If Not IsBlankString(QueryText) Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		If SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(CatalogJob.CreateItem().Metadata().FullName(), SaaS.AuxiliaryDataSeparator()) Then
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersToString(
			"SELECT
			|	PositionInQueue.DataAreaAuxiliaryData AS DataArea,
			|	PositionInQueue.Ref AS ID,
			|	ISNULL(PositionInQueue.Template, UNDEFINED) AS Template,
			|	ISNULL(TimeZones.Value, """") AS TimeZone,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.Schedule
			|		ELSE PositionInQueue.Template.Schedule
			|	END AS Schedule,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.RestartCountOnFailure
			|		ELSE PositionInQueue.Template.RestartCountOnFailure
			|	END AS RestartCountOnFailure,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.RestartIntervalOnFailure
			|		ELSE PositionInQueue.Template.RestartIntervalOnFailure
			|	END AS RestartIntervalOnFailure
			|FROM
			|	%1 AS PositionInQueue
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
			|		ON PositionInQueue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
			|WHERE
			|	PositionInQueue.JobState IN (VALUE(Enum.JobsStates.Running), VALUE(Enum.JobsStates.Completed), VALUE(Enum.JobsStates.NotScheduled), VALUE(Enum.JobsStates.ExecutionError))"
			, CatalogJob.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersToString(
			"SELECT
			|	-1 AS DataArea,
			|	PositionInQueue.Ref AS ID,
			|	UNDEFINED AS Template,
			|	"""" AS TimeZone,
			|	PositionInQueue.Schedule AS Schedule,
			|	PositionInQueue.RestartCountOnFailure AS RestartCountOnFailure,
			|	PositionInQueue.RestartIntervalOnFailure AS RestartIntervalOnFailure
			|FROM
			|	%1 AS PositionInQueue
			|WHERE
			|	PositionInQueue.JobState IN (VALUE(Enum.JobsStates.Running), VALUE(Enum.JobsStates.Completed), VALUE(Enum.JobsStates.NotScheduled), VALUE(Enum.JobsStates.ExecutionError))"
			, CatalogJob.EmptyRef().Metadata().FullName());
			
		EndIf;
		
	EndDo;
	
	Query.Text = QueryText;
	Result = SaaS.ExecuteQueryOutsideTransaction(Query);
	Selection = Result.Select();
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
	Else
		ModuleSaaS = Undefined;
	EndIf;
	
	While Selection.Next() Do
		
		Try
			LockDataForEdit(Selection.ID);
		Except
			// The record is locked, proceed to the next record.
			Continue;
		EndTry;
		
		// Checking for data area lock.
		If ModuleSaaS <> Undefined
			AND Selection.DataArea <> -1 
			AND ModuleSaaS.DataAreaLocked(Selection.DataArea) Then
			
			// The area is locked, proceeding to the next record.
			Continue;
		EndIf;
		
		// Rescheduling the completed scheduled jobs and failed background jobs; deleting the completed background jobs.
		ScheduleJob(Selection);
		
		UnlockDataForEdit(Selection.ID);
		
	EndDo;

	// Calculating the required number of active background jobs.
	BackgroundJobsToStartCount = ActiveBackgroundJobCountToStart();
	
	// Starting active background jobs.
	StartActiveBackgroundJob(BackgroundJobsToStartCount);
	
EndProcedure

// Executes jobs from JobQueue information register.
// 
// Parameters:
// BackgroundJobKey - UUID - the key is required to find active background jobs.
//                       
//
Procedure ProcessJobQueue(BackgroundJobKey) Export
	
	// OnScheduledJobStart is not called because the necessary actions are executed privately.
	// 
	
	FoundBackgroundJob = BackgroundJobs.GetBackgroundJobs(New Structure("Key", BackgroundJobKey));
	If FoundBackgroundJob.Count() = 1 Then
		ActiveBackgroundJob = FoundBackgroundJob[0];
	Else
		Return;
	EndIf;
	
	CanExecute = True;
	ExecutionStarted = CurrentUniversalDate();
	
	MaxActiveBackgroundJobExecutionTime = 
		Constants.MaxActiveBackgroundJobExecutionTime.Get();
	MaxActiveBackgroundJobCount =
		Constants.MaxActiveBackgroundJobCount.Get();
	
	Query = New Query;
	
	JobCatalogs = JobsQueueInternalCached.GetJobCatalogs();
	QueryText = "";
	LockQueryText = "";
	For Each CatalogJob In JobCatalogs Do
		
		FirstRow = IsBlankString(QueryText);
		
		If Not FirstRow Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		If SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(CatalogJob.CreateItem().Metadata().FullName(), SaaS.AuxiliaryDataSeparator()) Then
			
			If IsBlankString(LockQueryText) Then
				
				LockQueryText = 
				"SELECT
				|	Locks.DataAreaAuxiliaryData AS DataAreaAuxiliaryData
				|INTO Locks
				|FROM
				|	InformationRegister.DataAreaSessionLocks AS Locks
				|WHERE
				|	(Locks.LockStart = DATETIME(1, 1, 1)
				|			OR Locks.LockStart <= &CurrentUniversalDate)
				|	AND (Locks.LockEnd = DATETIME(1, 1, 1)
				|			OR Locks.LockEnd >= &CurrentUniversalDate)
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|";
				
			EndIf;
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersToString(
			"SELECT
			|	PositionInQueue.DataAreaAuxiliaryData AS DataArea,
			|	PositionInQueue.Ref AS ID,
			|	PositionInQueue.Use AS Use,
			|	PositionInQueue.ScheduledStartTime AS ScheduledStartTime,
			|	PositionInQueue.ActiveBackgroundJob AS ActiveBackgroundJob,
			|	PositionInQueue.ExclusiveExecution AS ExclusiveExecution,
			|	PositionInQueue.AttemptNumber AS AttemptNumber,
			|	PositionInQueue.Template AS Template,
			|	ISNULL(PositionInQueue.Template.Ref, UNDEFINED) AS TemplateRef,
			|	ISNULL(TimeZones.Value, """") AS TimeZone,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.Schedule
			|		ELSE PositionInQueue.Template.Schedule
			|	END AS Schedule,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.MethodName
			|		ELSE PositionInQueue.Template.MethodName
			|	END AS MethodName,
			|	PositionInQueue.Parameters AS Parameters,
			|	PositionInQueue.LastRunStartDate AS LastRunStartDate,
			|	PositionInQueue.LastStartCompletedOn AS LastStartCompletedOn
			|FROM
			|	%1 AS PositionInQueue
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
			|		ON PositionInQueue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
			|WHERE
			|	PositionInQueue.Use
			|	AND PositionInQueue.ScheduledStartTime <= &CurrentUniversalDate
			|	AND PositionInQueue.JobState = VALUE(Enum.JobsStates.Scheduled)
			|	AND PositionInQueue.ExclusiveExecution
			|
			|UNION ALL
			|
			|SELECT
			|	PositionInQueue.DataAreaAuxiliaryData,
			|	PositionInQueue.Ref,
			|	PositionInQueue.Use,
			|	PositionInQueue.ScheduledStartTime,
			|	PositionInQueue.ActiveBackgroundJob,
			|	PositionInQueue.ExclusiveExecution,
			|	PositionInQueue.AttemptNumber,
			|	PositionInQueue.Template,
			|	ISNULL(PositionInQueue.Template.Ref, UNDEFINED),
			|	ISNULL(TimeZones.Value, """"),
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.Schedule
			|		ELSE PositionInQueue.Template.Schedule
			|	END,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.MethodName
			|		ELSE PositionInQueue.Template.MethodName
			|	END,
			|	PositionInQueue.Parameters,
			|	PositionInQueue.LastRunStartDate,
			|	PositionInQueue.LastStartCompletedOn
			|FROM
			|	%1 AS PositionInQueue
			|		LEFT JOIN Locks AS Locks
			|		ON PositionInQueue.DataAreaAuxiliaryData = Locks.DataAreaAuxiliaryData
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
			|		ON PositionInQueue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
			|WHERE
			|	PositionInQueue.Use
			|	AND PositionInQueue.ScheduledStartTime <= &CurrentUniversalDate
			|	AND PositionInQueue.JobState = VALUE(Enum.JobsStates.Scheduled)
			|	AND NOT PositionInQueue.ExclusiveExecution
			|	AND Locks.DataAreaAuxiliaryData IS NULL "
			, CatalogJob.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersToString(
			"SELECT
			|	-1 AS DataArea,
			|	PositionInQueue.Ref AS ID,
			|	PositionInQueue.Use AS Use,
			|	PositionInQueue.ScheduledStartTime AS ScheduledStartTime,
			|	PositionInQueue.ActiveBackgroundJob AS ActiveBackgroundJob,
			|	PositionInQueue.ExclusiveExecution AS ExclusiveExecution,
			|	PositionInQueue.AttemptNumber AS AttemptNumber,
			|	UNDEFINED AS Template,
			|	UNDEFINED AS TemplateRef,
			|	"""" AS TimeZone,
			|	PositionInQueue.Schedule AS Schedule,
			|	PositionInQueue.MethodName AS MethodName,
			|	PositionInQueue.Parameters AS Parameters,
			|	PositionInQueue.LastRunStartDate AS LastRunStartDate,
			|	PositionInQueue.LastStartCompletedOn AS LastStartCompletedOn
			|FROM %1 AS PositionInQueue
			|WHERE
			|	PositionInQueue.Use
			|	AND PositionInQueue.ScheduledStartTime <= &CurrentUniversalDate
			|	AND PositionInQueue.JobState = VALUE(Enum.JobsStates.Scheduled)"
			, CatalogJob.EmptyRef().Metadata().FullName());
			
		EndIf;
		
	EndDo;
	
	QueryText = LockQueryText +
		"SELECT TOP 111
		|	NestedQuery.DataArea AS DataArea,
		|	NestedQuery.ID AS ID,
		|	NestedQuery.Use AS Use,
		|	NestedQuery.ScheduledStartTime AS ScheduledStartTime,
		|	NestedQuery.ActiveBackgroundJob AS ActiveBackgroundJob,
		|	NestedQuery.ExclusiveExecution AS ExclusiveExecution,
		|	NestedQuery.AttemptNumber AS AttemptNumber,
		|	NestedQuery.Template AS Template,
		|	NestedQuery.TemplateRef AS TemplateRef,
		|	NestedQuery.TimeZone AS TimeZone,
		|	NestedQuery.Schedule AS Schedule,
		|	NestedQuery.MethodName AS MethodName,
		|	NestedQuery.Parameters AS Parameters,
		|	NestedQuery.LastRunStartDate AS LastRunStartDate,
		|	NestedQuery.LastStartCompletedOn AS LastStartCompletedOn
		|FROM
		|	(" +  QueryText + ") AS NestedQuery
		|
		|ORDER BY
		|	ExclusiveExecution DESC,
		|	ScheduledStartTime,
		|	NestedQuery.LastStartCompletedOn,
		|	ID"; 
	
	Query.Text = QueryText;
	SelectionSizeText = Format(MaxActiveBackgroundJobCount * 3, "NZ=; NG=");
	Query.Text = StrReplace(Query.Text, "111", SelectionSizeText);
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
	Else
		ModuleSaaS = Undefined;
	EndIf;
	
	While CanExecute Do 
		Query.SetParameter("CurrentUniversalDate", CurrentUniversalDate());
		
		Selection = SaaS.ExecuteQueryOutsideTransaction(Query).Select();
		
		LockSet = False;
		While Selection.Next() Do 
			Try
				
				LockDataForEdit(Selection.ID);
				
				// Checking for data area lock.
				If ModuleSaaS <> Undefined
					AND Selection.DataArea <> -1 
					AND ModuleSaaS.DataAreaLocked(Selection.DataArea) Then
					
					UnlockDataForEdit(Selection.ID);
					
					// The area is locked, proceeding to the next record.
					Continue;
				EndIf;
				
				If ValueIsFilled(Selection.Template)
						AND Selection.TemplateRef = Undefined Then
					
					MessageTemplate = NStr("ru = 'На найден шаблон задания очереди с идентификатором %1'; en = 'Queue creation template with ID %1 not found'; pl = 'Nie znaleziono szablony zadania kolejki z identyfikatorem %1';es_ES = 'Modelo de la tarea de la cola con el identificador %1 no se ha encontrado';es_CO = 'Modelo de la tarea de la cola con el identificador %1 no se ha encontrado';tr = '%1Kimliği olan sıraya ait iş şablonu bulunamadı';it = 'Modello di coda con ID %1 non trovato';de = 'Job-Vorlage der Warteschlange mit ID %1 wurde nicht gefunden'");
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Selection.Template);
					WriteLogEvent(NStr("ru = 'Очередь заданий.Выполнение'; en = 'Job queue.Execution'; pl = 'Kolejka zadań. Wykonanie';es_ES = 'Cola de tareas.Ejecución';es_CO = 'Cola de tareas.Ejecución';tr = 'İş kuyruğu. Yürütme';it = 'Coda di processi.Esecuzione';de = 'Jobwarteschlange. Ausführung'", 
						CommonClientServer.DefaultLanguageCode()), 
						EventLogLevel.Error,
						,
						,
						MessageText);
					
					UnlockDataForEdit(Selection.ID);
					Continue;
				EndIf;
				
				LockSet = True;
				Break;
			Except
				// Locking failed.
				LockSet = False;
			EndTry;
		EndDo;
		
		If Not LockSet Then 
			Return;
		EndIf;
		
		Schedule = Selection.Schedule.Get();
		If Schedule <> Undefined Then
			// Checking for compliance with acceptable queue interval.
			TimeZone = Selection.TimeZone;
			
			If IsBlankString(TimeZone) Then
				TimeZone = Undefined;
			EndIf;
			
			AreaTime = ToLocalTime(CurrentUniversalDate(), TimeZone);
			Overdue = NOT Schedule.ExecutionRequired(AreaTime);
		Else
			Overdue = False;
		EndIf;
		
		If Overdue Then
			// Job needs rescheduling.
			BeginTransaction();
			Try
				Lock = New DataLock;
				LockItem = Lock.Add(Selection.ID.Metadata().FullName());
				LockItem.SetValue("Ref", Selection.ID);
				
				If Selection.DataArea <> -1 Then
					SaaS.SetSessionSeparation(True, Selection.DataArea);
				EndIf;
				Lock.Lock();
				
				Job = Selection.ID.GetObject();
				Job.JobState = Enums.JobsStates.NotScheduled;
				SaaS.WriteAuxiliaryData(Job);
				CommitTransaction();
			Except
				RollbackTransaction();
				SaaS.SetSessionSeparation(False);
				Raise;
			EndTry;
			SaaS.SetSessionSeparation(False);
		Else
			ExecuteQueueJob(Selection.ID, ActiveBackgroundJob, Selection.Template, Selection.MethodName);
		EndIf;
		
		UnlockDataForEdit(Selection.ID);
		
		// Checking if further execution is allowed.
		ExecutionDuration = CurrentUniversalDate() - ExecutionStarted;
		If ExecutionDuration > MaxActiveBackgroundJobExecutionTime Then
			CanExecute = False;
		EndIf;
	EndDo;
	
EndProcedure

// An internal procedure called to execute job error handler whenever the job execution process 
// fails to complete the job.
//
// Parameters:
// Job - CatalogRef - reference to a job that requires error handler execution.
// JobFailureInformation - ErrorInformation - information about job error.
//
Procedure HandleError(Val Job, Val JobFailureInfo = Undefined) Export
	
	ErrorHandlerParameters = GetErrorHandlerParameters(Job, JobFailureInfo);
	
	If ErrorHandlerParameters.HandlerExists Then
		
		Try
			
			ExecuteConfigurationMethod(ErrorHandlerParameters.MethodName, ErrorHandlerParameters.HandlerCallParameters);
			
		Except
			
			CommentTemplate = NStr("ru = 'Ошибка при выполнении обработчика ошибок
				|Псевдоним метода: %1
				|Метод обработчика ошибок: %2
				|По причине:
				|%3'; 
				|en = 'An error occurred when executing the error handler.
				|Method alias: %1
				|Method of the error handler: %2
				|Due to:
				|%3'; 
				|pl = 'Błąd podczas wykonania programu przetwarzania błędów
				|Alias metody: %1
				|Metoda programu przetwarzania błędów: %2
				|Z powodu:
				|%3';
				|es_ES = 'Error al realizar el procesador de errores
				|El seudónimo del método: %1
				|Método del procesador de errores: %2
				|A causa de:
				|%3';
				|es_CO = 'Error al realizar el procesador de errores
				|El seudónimo del método: %1
				|Método del procesador de errores: %2
				|A causa de:
				|%3';
				|tr = 'Hata işleyicisi yürütülürken hata yöntemi
				| Diğer ad: %1
				|Hata işleyicisi yöntemi: %2
				|Nedeni:
				|%3';
				|it = 'Si è verificato un errore durante l''esecuzione di elaboratore di errori.
				|Pseudonimo del metodo: %1
				|Metodo di gestore di errori: %2
				|A causa di:
				|%3';
				|de = 'Fehler beim Ausführen des Fehlerhandlers
				|Methoden-Alias: %1
				|Fehlerbehandlungsmethode: %2
				|Aufgrund von:
				|%3'");
			CommentText = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate,
				ErrorHandlerParameters.JobMethodName,
				ErrorHandlerParameters.MethodName,
				DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("ru = 'Очередь регламентных заданий.Ошибка обработчика ошибок'; en = 'Scheduled job queue.Error handler error'; pl = 'Kolejka zaplanowanych zadań. Wystąpił błąd procedury obsługi błędów';es_ES = 'Cola de tareas programadas. Ha ocurrido un error del manipulador de errores';es_CO = 'Cola de tareas programadas. Ha ocurrido un error del manipulador de errores';tr = 'Zamanlanmış iş kuyruğu. Hata işleyicisinin bir hatası oluştu';it = 'Coda di task programmati. Errore del gestore di errori';de = 'Geplante Jobwarteschlange. Ein Fehler des Fehlerhandlers ist aufgetreten'", 
					CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				CommentText);
				
		EndTry;
			
	EndIf;
	
	If Common.RefExists(Job)
		AND Job.JobState = Enums.JobsStates.ErrorHandlerOnFailure Then
	
		JobObject = Job.GetObject();
		JobObject.JobState = Enums.JobsStates.ExecutionError;
		SaaS.WriteAuxiliaryData(JobObject);
	
	EndIf;
	
EndProcedure

// Internal procedure that cancels both error handler jobs and own jobs. Required whenever 
// HandleError job execution fails.
//
// Parameters:
// CallParameters - Array - parameter array sent to the failed job being handled is only used to 
//                            determine the failed job.
// ErrorInformation - ErrorDescription - not used. Included only because this parameter is mandatory 
//                                       for the error handler.
// RecursionCounter - Number - used to count the created job cancellation jobs.
//
Procedure CancelErrorHandlerJobs(Val CallParameters, Val ErrorInformation = Undefined, Val RecursionCounter = 1) Export
	
	BeginTransaction();
	Try
		
		JobReference = CallParameters.Parameters[0];
		
		If Not Common.RefExists(JobReference) Then
		
			RollbackTransaction();
			Return;
		
		EndIf;
		
		Job = JobReference.GetObject();
		
		LockDataForEdit(JobReference);
		
		Job.JobState = Enums.JobsStates.ExecutionError;
		SaaS.WriteAuxiliaryData(Job);
		
		ErrorHandlerParameters = GetErrorHandlerParameters(Job);
		If ErrorHandlerParameters.MethodName = "JobQueueInternal.CancelErrorHandlerJobs" Then
			
			CancelErrorHandlerJobs(ErrorHandlerParameters.HandlerCallParameters[0], ErrorInformation, RecursionCounter + 1);
			
		Else
			
			CommentTemplate = NStr("ru = 'Был выполнен обработчик снятие заданий.
			|Псевдоним метода: %1
			|Уровень рекурсии: %2'; 
			|en = 'Handler of ending jobs was executed.
			|Method alias: %1
			|Recursion level: %2'; 
			|pl = 'Został wykonany program przetwarzania usunięcie zadań.
			|Alias metody: %1
			|Poziom rekursji: %2';
			|es_ES = 'Procesador de eliminación de tareas se ha ejecutado.
			|Alias del método:%1
			| Nivel de recursión: %2';
			|es_CO = 'Procesador de eliminación de tareas se ha ejecutado.
			|Alias del método:%1
			| Nivel de recursión: %2';
			|tr = 'İş kaldırma işleyicisi uygulandı. 
			|Yöntem takma adı: 
			|%1Yineleme düzeyi:%2';
			|it = 'Il gestore di fine task è stato eseguito.
			|Pseudonimo del metodo: %1
			|Livello di ricorsione: %2';
			|de = 'Der Task-Handler wurde ausgeführt.
			|Methoden-Alias: %1
			|Rekursionsebene: %2'");
			CommentText = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate,
				ErrorHandlerParameters.JobMethodName,
				RecursionCounter);
				
			WriteLogEvent(
				NStr("ru = 'Очередь регламентных заданий.Снятие заданий обработки ошибок'; en = 'Scheduled job queue.Cancel error handler jobs'; pl = 'Kolejka zaplanowanych zadań. Zakończ zadania przetwarzania błędów';es_ES = 'Cola de tareas programadas. Terminar las tareas de procesamiento de error';es_CO = 'Cola de tareas programadas. Terminar las tareas de procesamiento de error';tr = 'Zamanlanmış iş kuyruğu. Hata işlemenin son işleri';it = 'Coda di task programmati. Cancellare task di gestione errori';de = 'Geplante Jobwarteschlange. Beendet Jobs der Fehlerverarbeitung'",
					CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Information,
				,
				,
				CommentText);
			
		EndIf;
			
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
	
	EndTry;
	
	UnlockDataForEdit(JobReference);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Returns the next schedule execution date.
//
// Parameters:
//  Schedule - JobSchedule - a schedule.
//   
//  DateToCheck - Date - nearest date that can be scheduled for execution.
//   
//  LastRunStartDate - Date - start date of the last start of job.
//    If the date is set, it will be used to check conditions such as DaysRepeatPeriod, WeeksPeriod, 
//   RepeatPeriodInDay.
//   If the date is not set, the job is considered to have never started and these conditions are 
//   not checked.
//  LastStartCompletedOn - Date - end date of the last start of job.
//    If the date is set, it will be used to check the RepeatPause condition.
//    If the date is not set, the job is considered to have never completed and these conditions are 
//   not checked.
//  MaxPlanningHorizon - Number - maximum number of seconds relative to DateToCheck allowed for 
//   scheduling.
//   Increasing this value can result in longer calculation time for large schedules.
//   
//
// Returns:
//  Date - next schedule execution date.
//
Function NextScheduleExecutionDate(Val Schedule, Val DateToCheck, 
	Val LastRunStartDate = Undefined, Val LastStartCompletedOn = Undefined, 
	Val MaxPlanningHorizon = Undefined)
	
	If MaxPlanningHorizon = Undefined Then
		MaxPlanningHorizon = 366 * 86400 * 10;
	EndIf;
	
	InitialDateToCheck = DateToCheck;
	BeginTimeOfLastStart = '00010101' + (LastRunStartDate - BegOfDay(LastRunStartDate));
	
	// Boundary dates
	If ValueIsFilled(Schedule.EndDate)
		AND DateToCheck > Schedule.EndDate Then
		
		// Daily execution interval has ended.
		Return '00010101';
	EndIf;
		
	If DateToCheck < Schedule.BeginDate Then
		DateToCheck = Schedule.BeginDate;
	EndIf;
	
	CanChangeDay = True;
	
	// Periodicity management
	If ValueIsFilled(LastRunStartDate) Then
		
		// Weekly period
		If Schedule.WeeksPeriod > 1
			AND (BegOfWeek(DateToCheck) - BegOfWeek(LastRunStartDate)) / (7 * 86400) < Schedule.WeeksPeriod Then
		
			DateToCheck = BegOfWeek(LastRunStartDate) + 7 * 86400 * Schedule.WeeksPeriod;
		EndIf;
		
		// Daily period
		If Schedule.DaysRepeatPeriod = 0 Then
			If BegOfDay(DateToCheck) <> BegOfDay(LastRunStartDate) Then
				// Job already completed, repetition not set.
				Return '00010101';
			EndIf;
			
			CanChangeDay = False;
		EndIf;
		
		If Schedule.DaysRepeatPeriod > 1
			AND BegOfDay(DateToCheck) - BegOfDay(LastRunStartDate) < (Schedule.DaysRepeatPeriod - 1)* 86400 Then
			
			DateToCheck = BegOfDay(LastRunStartDate) + Schedule.DaysRepeatPeriod * 86400;
		EndIf;
		
		// If a job is repeated once per day (but not more often), shift it to the next day following the last launch.
		If Schedule.DaysRepeatPeriod = 1 AND Schedule.RepeatPeriodInDay = 0 Then
			DateToCheck = Max(DateToCheck, BegOfDay(LastRunStartDate+86400));
		EndIf;

	EndIf;
	
	// Allowed start interval management.
	ChangeMonth = False;
	ChangeDay = False;
	While True Do
		
		If DateToCheck - InitialDateToCheck > MaxPlanningHorizon Then
			// Postpone planning
			Return '00010101';
		EndIf;
		
		If NOT CanChangeDay
			AND (ChangeDay OR ChangeMonth) Then
			
			// Job already completed, repetition not set.
			Return '00010101';
		EndIf;
		
		// Months
		While ChangeMonth
			OR Schedule.Months.Count() > 0 
			AND Schedule.Months.Find(Month(DateToCheck)) = Undefined Do
			
			ChangeMonth = False;
			
			// Advance to next month
			DateToCheck = BegOfMonth(AddMonth(DateToCheck, 1));
		EndDo;
		
		// Day of the month
		DaysInMonth = Day(EndOfMonth(DateToCheck));
		If Schedule.DayInMonth <> 0 Then
			
			CurrentDay = Day(DateToCheck);
			
			If Schedule.DayInMonth > 0 
				AND (DaysInMonth < Schedule.DayInMonth OR CurrentDay > Schedule.DayInMonth)
				OR Schedule.DayInMonth < 0 
				AND (DaysInMonth < -Schedule.DayInMonth OR CurrentDay > DaysInMonth - -Schedule.DayInMonth) Then
				
				// This month does not include this day, or this day has already passed.
				ChangeMonth = True;
				Continue;
			EndIf;
			
			If Schedule.DayInMonth > 0 Then
				DateToCheck = BegOfMonth(DateToCheck) + (Schedule.DayInMonth - 1) * 86400;
			EndIf;
			
			If Schedule.DayInMonth < 0 Then
				DateToCheck = BegOfDay(EndOfMonth(DateToCheck)) - (-Schedule.DayInMonth -1) * 86400;
			EndIf;
		EndIf;
		
		// Day of week in the month
		If Schedule.WeekDayInMonth <> 0 Then
			If Schedule.WeekDayInMonth > 0 Then
				WeekStartDay = (Schedule.WeekDayInMonth - 1) * 7 + 1;
			EndIf;
			If Schedule.WeekDayInMonth < 0 Then
				WeekStartDay = DaysInMonth - (-Schedule.WeekDayInMonth) * 7 + 1;
			EndIf;
			
			WeekEndDay = Min(WeekStartDay + 6, DaysInMonth);
			
			If Day(DateToCheck) > WeekEndDay 
				OR WeekStartDay > DaysInMonth Then
				// This month does not include this week, or this week has already passed.
				ChangeMonth = True;
				Continue;
			EndIf;
			
			If Day(DateToCheck) < WeekStartDay Then
				If Schedule.DayInMonth <> 0 Then
					
					// The day is fixed and inappropriate.
					ChangeMonth = True;
					Continue;
				EndIf;
				DateToCheck = BegOfMonth(DateToCheck) + (WeekStartDay - 1) * 86400;
			EndIf;
		EndIf;
		
		// Day of the week
		While ChangeDay
			OR Schedule.WeekDays.Find(WeekDay(DateToCheck)) = Undefined
			AND Schedule.WeekDays.Count() > 0 Do
			
			ChangeDay = False;
			
			If Schedule.DayInMonth <> 0 Then
				// The day is fixed and inappropriate.
				ChangeMonth = True;
				Break;
			EndIf;
			
			If Day(DateToCheck) = DaysInMonth Then
				// The month is over
				ChangeMonth = True;
				Break;
			EndIf;
			
			If Schedule.WeekDayInMonth <> 0
				AND Day(DateToCheck) = WeekEndDay Then
				
				// The week is over
				ChangeMonth = True;
				Break;
			EndIf;
			
			DateToCheck = BegOfDay(DateToCheck) + 86400;
		EndDo;
		If ChangeMonth Then
			Continue;
		EndIf;
		
		// Time management
		TimeToCheck = '00010101' + (DateToCheck - BegOfDay(DateToCheck));
		
		If Schedule.DetailedDailySchedules.Count() = 0 Then
			DetailedSchedules = New Array;
			DetailedSchedules.Add(Schedule);


		Else
			DetailedSchedules = Schedule.DetailedDailySchedules;


		EndIf;
		
		// If we have an interval including midnight, split it into two intervals.
		Index = 0;
		While Index < DetailedSchedules.Count() Do
			
			DaySchedule = DetailedSchedules[Index];
			
			If NOT ValueIsFilled(DaySchedule.BeginTime) OR NOT ValueIsFilled(DaySchedule.EndTime) Then
				Index = Index + 1;
				Continue;
			EndIf;
			
			If DaySchedule.BeginTime > DaySchedule.EndTime Then
				
				DailyScheduleFirstHalf = New JobSchedule();
				FillPropertyValues(DailyScheduleFirstHalf,DaySchedule);
				DailyScheduleFirstHalf.BeginTime = BegOfDay(DailyScheduleFirstHalf.BeginTime);
				DetailedSchedules.Add(DailyScheduleFirstHalf);
				
				DailyScheduleSecondHalf = New JobSchedule();
				FillPropertyValues(DailyScheduleSecondHalf,DaySchedule);
				DailyScheduleSecondHalf.EndTime = EndOfDay(DailyScheduleSecondHalf.BeginTime);
				DetailedSchedules.Add(DailyScheduleSecondHalf);
				
				DetailedSchedules.Delete(Index);
				
			Else
				
				Index = Index + 1;
				
			EndIf;
		
		EndDo;
		
		For Index = 0 To DetailedSchedules.UBound() Do
			DaySchedule = DetailedSchedules[Index];
			
			// Boundary times
			If ValueIsFilled(DaySchedule.BeginTime)
				AND TimeToCheck < DaySchedule.BeginTime Then
				
				TimeToCheck = DaySchedule.BeginTime;
			EndIf;
			
			If ValueIsFilled(DaySchedule.EndTime)
				AND TimeToCheck > DaySchedule.EndTime Then
				
				If Index < DetailedSchedules.UBound() Then
					// More daily schedules available
					Continue;
				EndIf;
				
				// Appropriate time is over for this day.
				ChangeDay = True;
				Break;
			EndIf;
			
			// Repetition periodicity during the day.
			If ValueIsFilled(LastRunStartDate) Then
				
				If DaySchedule.RepeatPeriodInDay = 0
					AND BegOfDay(DateToCheck) = BegOfDay(LastRunStartDate)
					AND (NOT ValueIsFilled(DaySchedule.BeginTime) 
						OR ValueIsFilled(DaySchedule.BeginTime) AND BeginTimeOfLastStart >= DaySchedule.BeginTime)
					AND (NOT ValueIsFilled(DaySchedule.EndTime) 
						OR ValueIsFilled(DaySchedule.EndTime) AND BeginTimeOfLastStart <= DaySchedule.EndTime) Then
					
					// Job already completed during this interval (daily schedule), repetition not set.
					If Index < DetailedSchedules.UBound() Then
						Continue;
					EndIf;
					
					ChangeDay = True;
					Break;
				EndIf;
				
				If BegOfDay(DateToCheck) = BegOfDay(LastRunStartDate)
					AND TimeToCheck - BeginTimeOfLastStart < DaySchedule.RepeatPeriodInDay Then
					
					NewTimeToCheck = BeginTimeOfLastStart + DaySchedule.RepeatPeriodInDay;
					
					If ValueIsFilled(DaySchedule.EndTime) AND NewTimeToCheck > DaySchedule.EndTime
						OR BegOfDay(NewTimeToCheck) <> BegOfDay(TimeToCheck) Then
						
						// The time is out of the allowed interval
						If Index < DetailedSchedules.UBound() Then
							Continue;
						EndIf;
						
						ChangeDay = True;
						Break;
					EndIf;
					
					TimeToCheck = NewTimeToCheck;
					
				EndIf;
				
			EndIf;
			
			// Pause
			If ValueIsFilled(LastStartCompletedOn) 
				AND ValueIsFilled(DaySchedule.RepeatPause) Then
				
				EndTimeOfTheLastLaunch = '00010101' + (LastStartCompletedOn - BegOfDay(LastStartCompletedOn));
				
				If BegOfDay(DateToCheck) = BegOfDay(LastRunStartDate)
					AND TimeToCheck - EndTimeOfTheLastLaunch < DaySchedule.RepeatPause Then
					
					NewTimeToCheck = EndTimeOfTheLastLaunch + DaySchedule.RepeatPause;
					
					If ValueIsFilled(DaySchedule.EndTime) AND NewTimeToCheck > DaySchedule.EndTime
						OR BegOfDay(NewTimeToCheck) <> BegOfDay(TimeToCheck) Then
						
						// The time is out of the allowed interval
						If Index < DetailedSchedules.UBound() Then
							Continue;
						EndIf;
						
						ChangeDay = True;
						Break;
					EndIf;
					
					TimeToCheck = NewTimeToCheck;
					
				EndIf;
			EndIf;
			
			// Appropriate time found
			Break;
			
		EndDo;
		
		If ChangeDay Then
			Continue;
		EndIf;
		
		If ValueIsFilled(Schedule.CompletionTime)
			AND TimeToCheck > Schedule.CompletionTime Then
			// Too late for execution on this day.
			ChangeDay = True;
			Continue;
		EndIf;
		
		DateToCheck = BegOfDay(DateToCheck) + (TimeToCheck - BegOfDay(TimeToCheck));
		
		Return DateToCheck;
		
	EndDo;
	
EndFunction

// This method is used to call job handler and error handler methods.
//
// Parameters:
// MethodName - String - name of the method that is called.
// Parameters - Array - values of parameters sent to method, according to parameter order in the 
//                       called method.
//
Procedure ExecuteConfigurationMethod(MethodName, Parameters = Undefined)

	If SaaS.DataSeparationEnabled() AND SaaS.SeparatedDataUsageAvailable() Then
		SeparatorSet = True;
		SeparatorValue = SaaS.SessionSeparatorValue();
	Else
		SeparatorSet = False;
	EndIf;
	
	If TransactionActive() Then
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Перед стартом выполнения обработчика %1 есть активные транзакции.'; en = 'There are active transactions before the %1 handler can start.'; pl = 'Przed startem wykonania programu przetwarzania %1 są aktywne transakcje.';es_ES = 'Hay transacciones activas antes de que el manipulador %1 pueda iniciarse.';es_CO = 'Hay transacciones activas antes de que el manipulador %1 pueda iniciarse.';tr = 'İşleyici başlamadan önce%1 aktif işlemler var.';it = 'Ci sono transazioni attive prima che il gestore %1 possa cominciare.';de = 'Vor dem Start der Handler-Ausführung %1 gibt es aktive Transaktionen.'"),
				MethodName);
			
		WriteLogEvent(NStr("ru = 'Очередь регламентных заданий.Выполнение'; en = 'Scheduled job queue.Execution'; pl = 'Kolejka zaplanowanych zadań. Wykonanie';es_ES = 'Cola de tareas programadas.Cumplimiento';es_CO = 'Cola de tareas programadas.Cumplimiento';tr = 'Zamanlanmış iş kuyruğu. Yerine getirme';it = 'Coda di task programmati. Esecuzione';de = 'Geplante Jobwarteschlange. Erfüllung'", 
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorMessageText);
			
		Raise ErrorMessageText;
		
	EndIf;
	
	Try
		
		Common.ExecuteConfigurationMethod(MethodName, Parameters);
		
		If TransactionActive() Then
		
			While TransactionActive() Do
				RollbackTransaction();
			EndDo;
			
			MessageTemplate = NStr("ru = 'По завершении выполнения обработчика %1 не была закрыта транзакция'; en = 'Unclosed transaction found upon handler %1 execution'; pl = 'Transakcja nie została zamknięta po zakończeniu procedury obsługi %1';es_ES = 'Transacción no se ha cerrado después de que el manipulador %1 se ha finalizado';es_CO = 'Transacción no se ha cerrado después de que el manipulador %1 se ha finalizado';tr = 'İşlemci işlendikten sonra işlem %1 kapatılmadı';it = 'Rilevata transazione non chiusa dopo l''esecuzione del gestore %1';de = 'Die Transaktion wurde nach Abschluss des Handlers %1 nicht beendet'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, MethodName);
			WriteLogEvent(NStr("ru = 'Очередь регламентных заданий.Выполнение'; en = 'Scheduled job queue.Execution'; pl = 'Kolejka zaplanowanych zadań. Wykonanie';es_ES = 'Cola de tareas programadas.Cumplimiento';es_CO = 'Cola de tareas programadas.Cumplimiento';tr = 'Zamanlanmış iş kuyruğu. Yerine getirme';it = 'Coda di task programmati. Esecuzione';de = 'Geplante Jobwarteschlange. Erfüllung'", 
				CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error, 
				,
				, 
				MessageText);
			
		EndIf;
		
		If Not(SeparatorSet) AND SaaS.SessionSeparatorUsage() Then
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'По завершении выполнения обработчика %1 не было выключено разделение сеанса.'; en = 'Session separation was not disabled after the %1 handler finished.'; pl = 'Po zakończeniu wykonania programu przetwarzania %1 nie był wyłączony podział sesji.';es_ES = 'Separación de la sesión no se ha desactivado después de que el manipulador %1 se ha finalizado.';es_CO = 'Separación de la sesión no se ha desactivado después de que el manipulador %1 se ha finalizado.';tr = 'İşleyici %1 bittikten sonra oturum ayrımı devre dışı bırakılmadı.';it = 'La separazione di sessione non è stata disabilitata dopo l''esecuzione del gestore %1.';de = 'Die Sitzungstrennung wurde nicht deaktiviert, als der Handler %1 ausgeführt wurde.'"),
				MethodName);
			
			WriteLogEvent(NStr("ru = 'Очередь регламентных заданий.Выполнение'; en = 'Scheduled job queue.Execution'; pl = 'Kolejka zaplanowanych zadań. Wykonanie';es_ES = 'Cola de tareas programadas.Cumplimiento';es_CO = 'Cola de tareas programadas.Cumplimiento';tr = 'Zamanlanmış iş kuyruğu. Yerine getirme';it = 'Coda di task programmati. Esecuzione';de = 'Geplante Jobwarteschlange. Erfüllung'", 
				CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorMessageText);
			
			SaaS.SetSessionSeparation(False);
			
		ElsIf SeparatorSet AND SeparatorValue <> SaaS.SessionSeparatorValue() Then
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'По завершении выполнения обработчика %1 было изменено значение разделителя сеанса.'; en = 'Session separator value was changed after the %1 handler finished.'; pl = 'Po zakończeniu wykonania programu przetwarzania %1 została zmieniona wartość separatora sesji.';es_ES = 'El valor del separador de sesiones se ha cambiado después de que el manipulador %1 se ha finalizado.';es_CO = 'El valor del separador de sesiones se ha cambiado después de que el manipulador %1 se ha finalizado.';tr = 'İşleyici bittikten sonra oturum ayırıcı değeri %1 değiştirildi.';it = 'Il valore del separatore di sessione è stato modificato dopo l''esecuzione di gestore %1.';de = 'Nach Abschluss des Handlers %1 wurde der Sitzungstrenneichenwert geändert.'"),
				MethodName);
			
			WriteLogEvent(NStr("ru = 'Очередь регламентных заданий.Выполнение'; en = 'Scheduled job queue.Execution'; pl = 'Kolejka zaplanowanych zadań. Wykonanie';es_ES = 'Cola de tareas programadas.Cumplimiento';es_CO = 'Cola de tareas programadas.Cumplimiento';tr = 'Zamanlanmış iş kuyruğu. Yerine getirme';it = 'Coda di task programmati. Esecuzione';de = 'Geplante Jobwarteschlange. Erfüllung'", 
				CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorMessageText);
			
			SaaS.SetSessionSeparation(True,SeparatorValue);
			
		EndIf;
		
		
	Except
		
		While TransactionActive() Do
			RollbackTransaction();
		EndDo;
		
		If Not(SeparatorSet) AND SaaS.SessionSeparatorUsage() Then
			SaaS.SetSessionSeparation(False);
		ElsIf SeparatorSet AND SeparatorValue <> SaaS.SessionSeparatorValue() Then
			SaaS.SetSessionSeparation(True,SeparatorValue);
		EndIf;
		
		Raise;
		
	EndTry;
	
EndProcedure

// Generates and returns error information by the text of its details.
Function ErrorInformationConstructor(ErrorText)

	Try
			
		Raise ErrorText;
			
	Except
		Information = ErrorInfo();
	EndTry;
	
	Return Information;

EndFunction

// Receives error handler start parameters via job reference.
//
// Parameters:
//  Job - CatalogRef.JobQueue or CatalogRef.DataAreaJobQueue -
//             Reference to job used to get the error handler parameters.
//
// Returns:
//   Structure - error handler start parameters.
//      MethodName - string containing the name of error handler method to be executed.
//      JobMethodName - string containing the name of job method that was to be executed,
//      HandlerCallParameters - array containing parameters to be sent to the error handler procedure.
//      HandlerExists - boolean, error handler exists for this job.
//      Job - CatalogRef.JobQueue or CatalogRef.DataAreaJobQueue -
//                Reference to job sent as input parameter.
//
Function GetErrorHandlerParameters(Val Job,Val JobFailureInfo = Undefined)

	Result = New Structure("MethodName,JobMethodName,HandlerCallParameters,HandlerExists,Job");
	Result.Job = Job.Ref;
	
	If SaaS.IsSeparatedMetadataObject(Job.Metadata().FullName(), 
			SaaS.AuxiliaryDataSeparator()) 
		AND ValueIsFilled(Job.Template) Then
		
		Result.JobMethodName = Job.Template.MethodName;
		
	Else
		
		Result.JobMethodName = Job.MethodName;
		
	EndIf;
	
	ErrorHandlerMethodName = 
		JobsQueueInternalCached.MapBetweenErrorHandlersAndAliases().Get(Upper(Result.JobMethodName));
	Result.MethodName = ErrorHandlerMethodName;
	Result.HandlerExists = ValueIsFilled(Result.MethodName);
	If Result.HandlerExists Then
		JobParameters = New Structure;
		JobParameters.Insert("Parameters", Job.Parameters.Get());
		JobParameters.Insert("AttemptNumber", Job.AttemptNumber);
		JobParameters.Insert("RestartCountOnFailure", Job.RestartCountOnFailure);
		JobParameters.Insert("LastRunStartDate", Job.LastRunStartDate);
		
		If JobFailureInfo = Undefined Then
			
			ActiveBackgroundJob = BackgroundJobs.FindByUUID(Job.ActiveBackgroundJob);
			
			If ActiveBackgroundJob <> Undefined AND ActiveBackgroundJob.ErrorInfo <> Undefined Then
				
				JobFailureInfo = ActiveBackgroundJob.ErrorInfo;
				
			EndIf;
			
		EndIf;
		
		If JobFailureInfo = Undefined Then
			
			JobFailureInfo = ErrorInformationConstructor(NStr("ru = 'Задание завершилось с неизвестной ошибкой, возможно вызванной падением рабочего процесса.'; en = 'Job was completed with an unknown error, it could have been caused by the process failure.'; pl = 'Zadanie zostało zakończone z nieznanym błędem, który mógł być spowodowany awarią procesu.';es_ES = 'Tarea se ha finalizado con un error desconocido, el fallo del proceso puede ser la causa.';es_CO = 'Tarea se ha finalizado con un error desconocido, el fallo del proceso puede ser la causa.';tr = 'İş, bilinmeyen bir hatayla tamamlandı, işlem başarısızlığından kaynaklanmış olabilir.';it = 'Il processo è terminato con un errore sconosciuto, probabilmente causato da una caduta nel flusso di lavoro.';de = 'Der Auftrag wurde mit einem unbekannten Fehler abgeschlossen, der möglicherweise durch den Prozessfehler verursacht wurde.'"));
			
		EndIf;
		
		HandlerCallParameters = New Array;
		HandlerCallParameters.Add(JobParameters);
		HandlerCallParameters.Add(JobFailureInfo);
		
		Result.HandlerCallParameters = HandlerCallParameters;
	Else
		Result.HandlerCallParameters = Undefined;
	EndIf;

	Return Result;
	
EndFunction

// Generates and returns a table containing names of scheduled jobs with usage flag.
//
// Returns:
// ValueTable - table to be filled with scheduled jobs and usage flag.
// 	
//
Function ScheduledJobsUsage()
	
	UsageTable = New ValueTable;
	UsageTable.Columns.Add("ScheduledJob", New TypeDescription("String"));
	UsageTable.Columns.Add("Use", New TypeDescription("Boolean"));
	
	// Mandatory for this subsystem.
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "JobProcessingPlanning";
	NewRow.Use       = True;
	
	SSLSubsystemsIntegration.OnDetermineScheduledJobsUsage(UsageTable);
	JobsQueueOverridable.OnDetermineScheduledJobsUsage(UsageTable);
	
	Return UsageTable;
	
EndFunction

Function ActiveBackgroundJobsCount()
	
	Filter = New Structure("Description, State", GetActiveBackgroundJobDescription(), BackgroundJobState.Active); 
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter); 
	
	RunningBackgroundJobsCount = ActiveBackgroundJobs.Count();
	
	Return RunningBackgroundJobsCount;
	
EndFunction

// Calculates the required number of active background jobs.
// 
Function ActiveBackgroundJobCountToStart()
	
	RunningBackgroundJobsCount = ActiveBackgroundJobsCount();
	
	ActiveBackgroundJobCountToStart = 
		Constants.MaxActiveBackgroundJobCount.Get() - RunningBackgroundJobsCount;
	
	If ActiveBackgroundJobCountToStart < 0 Then
		ActiveBackgroundJobCountToStart = 0;
	EndIf;

	Return ActiveBackgroundJobCountToStart;
	
EndFunction

// Starts the required number of background jobs.
// 
// Parameters:
// BackgroundJobsToStartCount - Number - number of background jobs to be started.
//                                       
//
Procedure StartActiveBackgroundJob(BackgroundJobsToStartCount) 
	
	For Index = 1 To BackgroundJobsToStartCount Do
		varKey = New UUID;
		Parameters = New Array;
		Parameters.Add(varKey);
		BackgroundJobs.Execute("JobQueueInternal.ProcessJobQueue", Parameters, varKey, GetActiveBackgroundJobDescription());
	EndDo;
	
EndProcedure

Function GetActiveBackgroundJobDescription()
	
	Return "RunningBackgroundJob_5340185be5b240538bc73d9f18ef8df1";
	
EndFunction

Procedure WriteExecutionControlEventLog(Val EventName, Val WritingJob, Val Comment = "")
	
	If NOT IsBlankString(Comment) Then
		
		Comment = Comment + Chars.LF;
		
	EndIf;
	
	If TypeOf(WritingJob) = Type("CatalogRef.JobQueue") Then
		
		MethodName = Common.ObjectAttributeValue(WritingJob, "MethodName");
		
	Else
		
		MethodDetails = Common.ObjectAttributesValues(WritingJob, "MethodName, Template");
		
		If ValueIsFilled(MethodDetails.Template) Then
			
			MethodName = NStr("ru = 'Шаблон:'; en = 'Template:'; pl = 'Szablon:';es_ES = 'Plantilla:';es_CO = 'Plantilla:';tr = 'Şablon:';it = 'Modello:';de = 'Vorlage:'") + MethodDetails.Template;
			
		Else
			
			MethodName = MethodDetails.MethodName;
			
		EndIf;
		
	EndIf;
	
	WriteLogEvent(EventName, EventLogLevel.Information, ,
		String(WritingJob.UUID()), Comment + MethodName + ";"
			+ ?(SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(WritingJob.Metadata().FullName(),
				SaaS.AuxiliaryDataSeparator()),
				Format(WritingJob.DataAreaAuxiliaryData, "NZ=0; NG="), "-1"));
	
EndProcedure

// Executes handler for a job not based on a template.
// 
// Parameters:
// Alias - String - alias of method to be executed.
// Parameters - Array - parameters are sent to MethodName according to the array item order.
// 
// 
Procedure ExecuteJobHandler(Template, Alias, Parameters)
	
	MethodName = JobsQueueInternalCached.MapBetweenMethodNamesAndAliases().Get(Upper(Alias));
	If MethodName = Undefined Then
		MessageTemplate = NStr("ru = 'Метод %1 не разрешен к вызову через очередь заданий.'; en = 'Method %1 cannot be called via job queue.'; pl = 'Metoda %1 nie może być wywołana za pomocą kolejki zadań.';es_ES = 'Método %1 no puede llamarse a través de la cola de tareas.';es_CO = 'Método %1 no puede llamarse a través de la cola de tareas.';tr = 'Yöntem%1, iş kuyruğu aracılığıyla çağrılmaz.';it = 'Il metodo %1 non può essere chiamato tramite coda di processo.';de = 'Die Methode %1 kann nicht über die Jobwarteschlange aufgerufen werden.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Alias);
		Raise(MessageText);
	EndIf;
	
	ExecuteConfigurationMethod(MethodName,Parameters);
	
EndProcedure

Procedure ScheduleJob(Val Selection)
	
	If ValueIsFilled(Selection.TimeZone) Then
		TimeZone = Selection.TimeZone;
	Else
		TimeZone = Undefined;
	EndIf;
	
	If Selection.DataArea <> -1 Then
		
		Try
		
			SaaS.SetSessionSeparation(True, Selection.DataArea);
		
		Except
			
			SaaS.SetSessionSeparation(False);
			
			MessageTemplate =
			    NStr("ru = 'Задание очереди с именем метода %1 в области %2 не запланировано по причине:
				|%3'; 
				|en = 'Queue job with method name %1 in the %2 area is not scheduled due to:
				|%3'; 
				|pl = 'Zadanie kolejki pod nazwą metody %1 w obszarze %2 nie jest zaplanowane z powodu:
				|%3';
				|es_ES = 'La tarea de la cola con el nombre del método %1 en el área %2 no está planificada a causa de:
				|%3';
				|es_CO = 'La tarea de la cola con el nombre del método %1 en el área %2 no está planificada a causa de:
				|%3';
				|tr = 'Bir yöntem adı olan bir %1sıra atama%2 kapsam için bir nedenle zamanlanmadı:
				|%3';
				|it = 'Il task in coda con nome del metodo %1 nell''area %2 non è stato programmato a causa di:
				|%3';
				|de = 'Eine Warteschlange mit einem Methodennamen %1 im Bereich %2 wird aus folgenden Gründen nicht geplant:
				|%3'");
				
			If ValueIsFilled(Selection.Template) Then
				
				MethodName = Common.ObjectAttributeValue(Selection.Template, "MethodName");
				
			Else
				
				MethodName = Common.ObjectAttributeValue(Selection.ID, "MethodName");
				
			EndIf;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, MethodName, Selection.DataArea, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(
			    NStr("ru = 'Очередь заданий.Планирование'; en = 'Job queue.Scheduling'; pl = 'Kolejka zadań. Planowanie';es_ES = 'Cola de tareas.Planificación';es_CO = 'Cola de tareas.Planificación';tr = 'İş kuyruğu. Planlama';it = 'Coda processo.Pianificazione';de = 'Jobwarteschlange. Planung'",
			    CommonClientServer.DefaultLanguageCode()), 
			    EventLogLevel.Error,,,
				MessageText);
			
			Return;
			
		EndTry;
		
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add(Selection.ID.Metadata().FullName());
		LockItem.SetValue("Ref", Selection.ID);
		Lock.Lock();
		
		If NOT Common.RefExists(Selection.ID) Then
			RollbackTransaction();
			Return;
		EndIf;
		
		Job = Selection.ID.GetObject();
		
		If SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(Job.Metadata().FullName(), SaaS.AuxiliaryDataSeparator()) Then
			
			If ValueIsFilled(Job.Template)
				AND Selection.Template = Undefined Then
				
				MessageTemplate = NStr("ru = 'На найден шаблон задания очереди  %1'; en = 'Job template of job queue %1 is not found'; pl = 'Nie znaleziono szablonu kolejki zadań %1';es_ES = 'El modelo de la tarea de la cola no se ha encontrado %1';es_CO = 'El modelo de la tarea de la cola no se ha encontrado %1';tr = 'Sıra%1 iş şablonu bulunamadı';it = 'Modello di task nella coda di task %1 non è stato trovato';de = 'Die Vorlage der Jobwarteschlange %1 wurde nicht gefunden'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Job.Template);
				
				WriteLogEvent(NStr("ru = 'Очередь заданий.Планирование'; en = 'Job queue.Scheduling'; pl = 'Kolejka zadań. Planowanie';es_ES = 'Cola de tareas.Planificación';es_CO = 'Cola de tareas.Planificación';tr = 'İş kuyruğu. Planlama';it = 'Coda processo.Pianificazione';de = 'Jobwarteschlange. Planung'", 
					CommonClientServer.DefaultLanguageCode()), 
					EventLogLevel.Error,
					,
					,
					MessageText);
				
				SaaS.SetSessionSeparation(False);
				RollbackTransaction();
				Return;
				
			EndIf;
			
		EndIf;
			
		If Job.JobState = Enums.JobsStates.ExecutionError
			AND Job.AttemptNumber < Selection.RestartCountOnFailure Then // Restart attempt
			
			If ValueIsFilled(Job.LastStartCompletedOn) Then
				RestartReferencePoint = Job.LastStartCompletedOn;
			Else
				RestartReferencePoint = Job.LastRunStartDate;
			EndIf;
			
			Job.ScheduledStartTime = RestartReferencePoint + Selection.RestartIntervalOnFailure;
			Job.AttemptNumber                 = Job.AttemptNumber + 1;
			Job.JobState             = Enums.JobsStates.Scheduled;
			Job.ActiveBackgroundJob    = Undefined;
			SaaS.WriteAuxiliaryData(Job);
			
		// Job not completed, scheduling the error handler.
		ElsIf Job.JobState = Enums.JobsStates.Running Then
			
			WriteExecutionControlEventLog(NStr("ru = 'Очередь регламентных заданий.Завершено с ошибками'; en = 'Scheduled job queue.Completed with errors'; pl = 'Kolejka zaplanowanych zadań. Zakończono z błędami';es_ES = 'Cola de tareas programadas. Finalizado con errores';es_CO = 'Cola de tareas programadas. Finalizado con errores';tr = 'Zamanlanmış iş kuyruğu. Hatalarla tamamlandı';it = 'Coda di task programmati. Completato con errori';de = 'Geplante Jobwarteschlange. Mit Fehlern abgeschlossen'", 
				CommonClientServer.DefaultLanguageCode()), Selection.ID, 
				NStr("ru = 'Исполняющее задание было принудительно завершено'; en = 'Active job was aborted'; pl = 'Aktywne zadanie zostało przymusowo zakończone';es_ES = 'Tarea activa se ha finalizado a la fuerza';es_CO = 'Tarea activa se ha finalizado a la fuerza';tr = 'Aktif iş zorla sonlandırıldı';it = 'Il task in esecuzione è stato interrotto';de = 'Der aktive Job wurde zwangsweise beendet'"));
				
			// Scheduling a one-time job for error handler execution.
			HandlerParameters = GetErrorHandlerParameters(Job);
			If HandlerParameters.HandlerExists Then
				
				NewJob = Catalogs[Job.Metadata().Name].CreateItem();
				NewJob.ScheduledStartTime = CurrentUniversalDate();
				NewJob.Use = True;
				NewJob.JobState = Enums.JobsStates.Scheduled;
				CallParameters = New Array;
				CallParameters.Add(Job.Ref);
				NewJob.Parameters = New ValueStorage(CallParameters);
				NewJob.MethodName = "JobQueueInternal.HandleError";
				If SaaS.IsSeparatedMetadataObject(Job.Metadata(),"DataAreaAuxiliaryData") Then
					NewJob.DataAreaAuxiliaryData = Job.DataAreaAuxiliaryData;
				EndIf;
				SaaS.WriteAuxiliaryData(NewJob);
				
				// Pausing the job until the error handler execution is complete.
				Job.JobState = Enums.JobsStates.ErrorHandlerOnFailure;
				
			Else
				
				Job.JobState = Enums.JobsStates.ExecutionError;
				
			EndIf;
			
				SaaS.WriteAuxiliaryData(Job);
			
		Else
			Schedule = Selection.Schedule.Get();
			
			If Schedule = Undefined Or (Job.JobState = Enums.JobsStates.Completed
				AND Schedule.DaysRepeatPeriod = 0 AND Schedule.RepeatPeriodInDay = 0) Then
				
				If SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(
							Job.Metadata().FullName(),
							SaaS.AuxiliaryDataSeparator()) Then
					If Schedule = Undefined AND ValueIsFilled(Job.Template) Then // Job by template without schedule.
						
						MessageTemplate = NStr("ru = 'Для шаблон заданий очереди  %1 не найдено расписание'; en = 'Schedule is not found for queue job template %1'; pl = 'Dla szablonu zadań kolejki %1 nie znaleziono harmonogramu';es_ES = 'El horario no se ha encontrado para el modelo %1 de la tarea de la cola';es_CO = 'El horario no se ha encontrado para el modelo %1 de la tarea de la cola';tr = 'Sıra iş şablonu %1 için zamanlama bulunamadı';it = 'Nessuna programmazione trovata per il modello di task in coda %1';de = 'Kein Zeitplan für die Jobwarteschlange %1 gefunden'");
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Job.Template);
						WriteLogEvent(NStr("ru = 'Очередь заданий.Планирование'; en = 'Job queue.Scheduling'; pl = 'Kolejka zadań. Planowanie';es_ES = 'Cola de tareas.Planificación';es_CO = 'Cola de tareas.Planificación';tr = 'İş kuyruğu. Planlama';it = 'Coda processo.Pianificazione';de = 'Jobwarteschlange. Planung'", 
							CommonClientServer.DefaultLanguageCode()), 
							EventLogLevel.Error,
							,
							,
							MessageText);
						
						SaaS.SetSessionSeparation(False);
						RollbackTransaction();
						Return;
						
					EndIf;
				EndIf;
				
				// One-time job
				Job.DataExchange.Load = True;
				Job.Delete();
				
			Else
				
				Job.ScheduledStartTime = GetScheduledJobStartTime(
					Schedule, TimeZone, Job.LastRunStartDate, Job.LastStartCompletedOn);
				Job.AttemptNumber = 0;
				If ValueIsFilled(Job.ScheduledStartTime) Then
					Job.JobState = Enums.JobsStates.Scheduled;
				Else
					Job.JobState = Enums.JobsStates.NotActive;
				EndIf;
				Job.ActiveBackgroundJob = Undefined;
				SaaS.WriteAuxiliaryData(Job);
				
			EndIf;
		EndIf;
		
		SaaS.SetSessionSeparation(False);
		CommitTransaction();
		
	Except

		RollbackTransaction();
		SaaS.SetSessionSeparation(False);
		
		MessageTemplate =
		    NStr("ru = 'Задание очереди с именем метода %1 не запланировано по причине:
			|%2'; 
			|en = 'Queue job with the %1 method name is not planned due to:
			|%2'; 
			|pl = 'Zadanie kolejki pod nazwą metody %1 nie jest zaplanowane z powodu:
			|%2';
			|es_ES = 'La tarea de la cola con el nombre del método %1 en el área no está planificada a causa de:
			|%2';
			|es_CO = 'La tarea de la cola con el nombre del método %1 en el área no está planificada a causa de:
			|%2';
			|tr = 'Bir yöntem adı olan bir %1sıra atama%2 kapsam için bir nedenle zamanlanmadı:
			|';
			|it = 'Task in coda con il nome del metodo %1 non è stato programmato a causa di:
			|%2';
			|de = 'Eine Jobwarteschlange mit einem Methodennamen %1 wird aus folgenden Gründen nicht geplant:
			|%2'");
			
		If ValueIsFilled(Selection.Template) Then
			
			MethodName = Common.ObjectAttributeValue(Selection.Template, "MethodName");
			
		Else
			
			MethodName = Common.ObjectAttributeValue(Selection.ID, "MethodName");
			
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, MethodName, DetailErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
		    NStr("ru = 'Очередь заданий.Планирование'; en = 'Job queue.Scheduling'; pl = 'Kolejka zadań. Planowanie';es_ES = 'Cola de tareas.Planificación';es_CO = 'Cola de tareas.Planificación';tr = 'İş kuyruğu. Planlama';it = 'Coda processo.Pianificazione';de = 'Jobwarteschlange. Planung'",
		    CommonClientServer.DefaultLanguageCode()), 
		    EventLogLevel.Error,,,
			MessageText);
		
		Return;
		
	EndTry;
	
EndProcedure

Procedure ExecuteQueueJob(Val Ref, Val ActiveBackgroundJob, 
		Val Template, Val MethodName)
	
	DataArea = Undefined;
	If SaaSCached.IsSeparatedConfiguration() Then
		ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
		RedefinedDataArea = ModuleJobQueueInternalDataSeparation.DefineDataAreaForJob(Ref);
		If RedefinedDataArea <> Undefined Then
			DataArea = RedefinedDataArea;
		EndIf;
	EndIf;
	
	If DataArea = Undefined Then
		DataArea = -1;
	EndIf;
	
	BeginTransaction();
	Try
		
		If DataArea <> -1 Then
			SaaS.SetSessionSeparation(True, DataArea);
		EndIf;
		
		Lock = New DataLock;
		LockItem = Lock.Add(Ref.Metadata().FullName());
		LockItem.SetValue("Ref", Ref);
		Lock.Lock();
		
		Job = Ref.GetObject();
		
		If Job.JobState = Enums.JobsStates.Scheduled
			AND Job.Use
			AND Job.ScheduledStartTime <= CurrentUniversalDate() Then 
			
			Job.JobState = Enums.JobsStates.Running;
			Job.ActiveBackgroundJob = ActiveBackgroundJob.UUID;
			Job.LastRunStartDate = CurrentUniversalDate();
			Job.LastStartCompletedOn = Undefined;
			SaaS.WriteAuxiliaryData(Job);
			
			CommitTransaction();
			
		Else
			
			SaaS.SetSessionSeparation(False);
			CommitTransaction();
			Return;
			
		EndIf;
		
	Except
		
		RollbackTransaction();
		SaaS.SetSessionSeparation(False);
		Raise;
		
	EndTry;
	
	// Executing job
	ExecutedSuccessfully = False;
	JobFailureInfo = Undefined;
	Try
		WriteExecutionControlEventLog(NStr("ru = 'Очередь регламентных заданий.Старт'; en = 'Scheduled job queue.Start'; pl = 'Kolejka zaplanowanych zadań. Start';es_ES = 'Cola de tareas programadas.Inicio';es_CO = 'Cola de tareas programadas.Inicio';tr = 'Zamanlanmış iş kuyruğu. Başlatma';it = 'Coda delle attività pianificate. Inizio';de = 'Geplante Jobwarteschlange. Anfang'", 
			CommonClientServer.DefaultLanguageCode()), Ref);
		
		If ValueIsFilled(Template) Then
			ExecuteConfigurationMethod(MethodName);
		Else
			ExecuteJobHandler(Template, MethodName, Job.Parameters.Get());
		EndIf;
		
		ExecutedSuccessfully = True;
		
		WriteExecutionControlEventLog(NStr("ru = 'Очередь регламентных заданий.Завершено успешно'; en = 'Scheduled job queue.Completed successfully'; pl = 'Kolejka zaplanowanych zadań. Zakończono pomyślnie';es_ES = 'Cola de tarea programadas. Finalizado con éxito';es_CO = 'Cola de tarea programadas. Finalizado con éxito';tr = 'Zamanlanmış iş kuyruğu. Zamanında tamamlandı';it = 'Coda di task programmati. Completato con successo';de = 'Geplante Jobwarteschlange. Erfolgreich abgeschlossen'", 
			CommonClientServer.DefaultLanguageCode()), Ref);
		
	Except
			
		While TransactionActive() Do
			
			RollbackTransaction();
			
		EndDo;
		
		CommentTemplate =
			NStr("ru = 'Не удалось выполнить обработчик %1 по причине:
			           |%2'; 
			           |en = 'Cannot execute the %1 handler due to:
			           |%2'; 
			           |pl = 'Nie udało się wykonać program przetwarzania %1 z powodu:
			           |%2';
			           |es_ES = 'No se ha podido realizar el procesador %1a causa de:
			           |%2';
			           |es_CO = 'No se ha podido realizar el procesador %1a causa de:
			           |%2';
			           |tr = '%1 işleyici aşağıdaki nedenle yürütülemedi: 
			           |%2';
			           |it = 'Impossibile eseguire gestore %1 a causa di:
			           |%2';
			           |de = 'Der Handler %1 konnte aus diesem Grund nicht ausgeführt werden:
			           |%2'");
		
		JobFailureInfo = ErrorInfo();
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, MethodName, DetailErrorDescription(JobFailureInfo));
		
		WriteExecutionControlEventLog(NStr("ru = 'Очередь регламентных заданий.Завершено с ошибками'; en = 'Scheduled job queue.Completed with errors'; pl = 'Kolejka zaplanowanych zadań. Zakończono z błędami';es_ES = 'Cola de tareas programadas. Finalizado con errores';es_CO = 'Cola de tareas programadas. Finalizado con errores';tr = 'Zamanlanmış iş kuyruğu. Hatalarla tamamlandı';it = 'Coda di task programmati. Completato con errori';de = 'Geplante Jobwarteschlange. Mit Fehlern abgeschlossen'",
			CommonClientServer.DefaultLanguageCode()), Ref,
			DetailErrorDescription(JobFailureInfo));
		
		WriteLogEvent(NStr("ru = 'Очередь регламентных заданий.Завершено с ошибками'; en = 'Scheduled job queue.Completed with errors'; pl = 'Kolejka zaplanowanych zadań. Zakończono z błędami';es_ES = 'Cola de tareas programadas. Finalizado con errores';es_CO = 'Cola de tareas programadas. Finalizado con errores';tr = 'Zamanlanmış iş kuyruğu. Hatalarla tamamlandı';it = 'Coda di task programmati. Completato con errori';de = 'Geplante Jobwarteschlange. Mit Fehlern abgeschlossen'",
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			ActiveBackgroundJob,
			ErrorMessageText);
		
	EndTry;
		
	If NOT ExecutedSuccessfully Then
		
		// Calling error handlers
		HandleError(Ref, JobFailureInfo);
		
	EndIf;
	
	BeginTransaction();
	Try
		
		If Common.RefExists(Ref) Then // Otherwise - job could be deleted in the handler.
			
			Lock = New DataLock;
			LockItem = Lock.Add(Ref.Metadata().FullName());
			LockItem.SetValue("Ref", Ref);
			Lock.Lock();
			
			Job = Ref.GetObject();
			Job.LastStartCompletedOn = CurrentUniversalDate();
			
			If ExecutedSuccessfully Then
				Job.JobState = Enums.JobsStates.Completed;
			Else
				Job.JobState = Enums.JobsStates.ExecutionError;
			EndIf;
			SaaS.WriteAuxiliaryData(Job);
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		SaaS.SetSessionSeparation(False);
		Raise;
		
	EndTry;
	
	SaaS.SetSessionSeparation(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Disables scheduled jobs used in local mode only; enables scheduled jobs used in SaaS only.
// 
//
Procedure SetScheduledJobsUsage() Export
	
	SaaSScheduledJobUsageTable = ScheduledJobsUsage();
	
	For Each Row In SaaSScheduledJobUsageTable Do
		
		If SaaS.DataSeparationEnabled() Then
			
			// Enable scheduled jobs intended for use in SaaS.
			// Disable scheduled jobs intended for use in local mode.
			RequiredUsage = Row.Use;
			
		Else
			
			If Row.Use Then
				// Disable scheduled jobs intended for use in SaaS.
				RequiredUsage = False;
			Else
				// Do not change job settings intended for use in local mode.
				Continue;
			EndIf;
			
		EndIf;
		
		Filter = New Structure("Metadata", Metadata.ScheduledJobs[Row.ScheduledJob]);
		FoundScheduledJobs = ScheduledJobs.GetScheduledJobs(Filter);
		
		For Each ScheduledJob In FoundScheduledJobs Do
			
			If ScheduledJob.Use <> RequiredUsage Then
				ScheduledJob.Use = RequiredUsage;
				ScheduledJob.Write();
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Moves jobs from JobQueue information register to JobQueue catalog.
Procedure MoveQueueJobsToUnseparatedData() Export
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock();
		CatalogLock = Lock.Add("Catalog.JobQueue");
		Lock.Lock();
		
		QueryText = 
		"SELECT
		|	DeleteJobQueue.Use,
		|	DeleteJobQueue.ScheduledStartTime,
		|	DeleteJobQueue.JobState,
		|	DeleteJobQueue.ActiveBackgroundJob,
		|	DeleteJobQueue.ExclusiveExecution,
		|	DeleteJobQueue.Template,
		|	DeleteJobQueue.AttemptNumber,
		|	DeleteJobQueue.DeleteScheduledJob,
		|	DeleteJobQueue.MethodName,
		|	DeleteJobQueue.Parameters,
		|	DeleteJobQueue.LastRunStartDate,
		|	DeleteJobQueue.Key,
		|	DeleteJobQueue.RestartIntervalOnFailure,
		|	DeleteJobQueue.Schedule,
		|	DeleteJobQueue.RestartCountOnFailure,
		|	DeleteJobQueue.ID
		|FROM
		|	InformationRegister.DeleteJobQueue AS DeleteJobQueue
		|WHERE
		|	DeleteJobQueue.DataArea = -1";
		Query = New Query(QueryText);
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			JobRef = Catalogs.JobQueue.GetRef(
				New UUID(Selection.ID));
			
			If Common.RefExists(JobRef) Then
				NewJob = JobRef.GetObject();
			Else
				NewJob = Catalogs.JobQueue.CreateItem();
			EndIf;
			
			FillPropertyValues(NewJob, Selection);
			SaaS.WriteAuxiliaryData(NewJob);
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Procedure ScheduleIdleTasts() Export
	
	Query = New Query;
	
	JobCatalogs = JobsQueueInternalCached.GetJobCatalogs();
	QueryText = "";
	For Each CatalogJob In JobCatalogs Do
		
		If Not IsBlankString(QueryText) Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
			
		EndIf;
		
		If SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(CatalogJob.CreateItem().Metadata().FullName(), SaaS.AuxiliaryDataSeparator()) Then
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersToString(
			"SELECT
			|	PositionInQueue.DataAreaAuxiliaryData AS DataArea,
			|	PositionInQueue.Ref AS ID,
			|	ISNULL(PositionInQueue.Template, UNDEFINED) AS Template,
			|	ISNULL(TimeZones.Value, """") AS TimeZone,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.Schedule
			|		ELSE PositionInQueue.Template.Schedule
			|	END AS Schedule,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.RestartCountOnFailure
			|		ELSE PositionInQueue.Template.RestartCountOnFailure
			|	END AS RestartCountOnFailure,
			|	CASE
			|		WHEN PositionInQueue.Template = VALUE(Catalog.QueueJobTemplates.EmptyRef)
			|			THEN PositionInQueue.RestartIntervalOnFailure
			|		ELSE PositionInQueue.Template.RestartIntervalOnFailure
			|	END AS RestartIntervalOnFailure
			|FROM
			|	%1 AS PositionInQueue
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
			|		ON PositionInQueue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
			|WHERE
			|	PositionInQueue.JobState = VALUE(Enum.JobsStates.NotActive)
			|	AND PositionInQueue.Use"
			, CatalogJob.EmptyRef().Metadata().FullName());
			
		Else
			
			QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersToString(
			"SELECT
			|	-1 AS DataArea,
			|	PositionInQueue.Ref AS ID,
			|	UNDEFINED AS Template,
			|	"""" AS TimeZone,
			|	PositionInQueue.Schedule AS Schedule,
			|	PositionInQueue.RestartCountOnFailure AS RestartCountOnFailure,
			|	PositionInQueue.RestartIntervalOnFailure AS RestartIntervalOnFailure
			|FROM
			|	%1 AS PositionInQueue
			|WHERE
			|	PositionInQueue.JobState = VALUE(Enum.JobsStates.NotActive)
			|	AND PositionInQueue.Use"
			, CatalogJob.EmptyRef().Metadata().FullName());
			
		EndIf;
		
	EndDo;
	
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ValueIsFilled(Selection.TimeZone) Then
			TimeZone = Selection.TimeZone;
		Else
			TimeZone = Undefined;
		EndIf;
		
		If ValueIsFilled(Selection.Template) Then
			MethodName = Common.ObjectAttributeValue(Selection.Template, "MethodName");
		Else
			MethodName = Common.ObjectAttributeValue(Selection.ID, "MethodName");
		EndIf;
		
		BeginTransaction();
		Try
			
			Lock = New DataLock;
			LockItem = Lock.Add(Selection.ID.Metadata().FullName());
			LockItem.SetValue("Ref", Selection.ID);
			Lock.Lock();
			
			Job = Selection.ID.GetObject();
			
			Schedule = Selection.Schedule.Get();
			
			// If these are periodic jobs (not one-time)
			If (Schedule <> Undefined AND (Schedule.DaysRepeatPeriod <> 0 Or Schedule.RepeatPeriodInDay <> 0)) Then
				
				Job.ScheduledStartTime = GetScheduledJobStartTime(
					Schedule, TimeZone, Job.LastRunStartDate, Job.LastStartCompletedOn);
				Job.AttemptNumber = 0;
				If ValueIsFilled(Job.ScheduledStartTime) Then
					Job.JobState = Enums.JobsStates.Scheduled;
				Else
					Job.JobState = Enums.JobsStates.NotActive;
				EndIf;
				Job.ActiveBackgroundJob = Undefined;
				Job.DataExchange.Load = True;
				Job.Write();
				
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			MessageText = NStr("ru = 'Задание не удалось обновить
                                   |DataArea: %1
                                   |Имя метода: %2'; 
                                   |en = 'Cannot update job
                                   |DataArea: %1
                                   |Method name: %2'; 
                                   |pl = 'Zadanie nie udało się aktualizować
                                   |DataArea: %1
                                   |Nazwa metody: %2';
                                   |es_ES = 'La tarea no se ha podido actualziar
                                   |DataArea: %1
                                   | Nombre del método: %2';
                                   |es_CO = 'La tarea no se ha podido actualziar
                                   |DataArea: %1
                                   | Nombre del método: %2';
                                   |tr = 'Görev yenilenemedi 
                                   | DataArea: %1
                                   | Yöntem adı: %2';
                                   |it = 'Impossibile aggiornare task
                                   |DataArea: %1
                                   |Nome del metodo: %2';
                                   |de = 'Der Job
                                   |kann nicht aktualisiert werden DataArea: %1
                                   |Name der Methode: %2'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, String(Selection.DataArea), MethodName);
			
			WriteLogEvent(
				NStr("ru = 'Обновление очереди заданий'; en = 'Job queue update'; pl = 'Aktualizacja kolejki zadań';es_ES = 'Actualización de la cola de tareas';es_CO = 'Actualización de la cola de tareas';tr = 'Görev sırası güncellenmesi';it = 'Aggiornamento della coda di task';de = 'Aktualisieren der Jobwarteschlange'",
				CommonClientServer.DefaultLanguageCode()), 
				EventLogLevel.Error,,,
				MessageText);
	
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion
