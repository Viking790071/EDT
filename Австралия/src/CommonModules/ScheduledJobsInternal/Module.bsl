#Region Internal

// Checks whether the scheduled job is enabled according to functional options.
//
// Parameters:
//  Job - MetadataObject:ScheduledJob - scheduled job.
//  JobDependencies - ValueTable - table of scheduled jobs dependencies returned by the 
//    ScheduledJobsInternal.ScheduledJobsDependentOnFunctionalOptions method.
//    If it is not specified, it is generated automatically.
//
// Returns:
//  Usage - Boolean - True if the scheduled job is used.
//
Function ScheduledJobAvailableByFunctionalOptions(Job, JobDependencies = Undefined) Export
	
	If JobDependencies = Undefined Then
		JobDependencies = ScheduledJobsDependentOnFunctionalOptions();
	EndIf;
	
	DisableInSubordinateDIBNode = False;
	DisableInStandaloneWorkplace = False;
	Usage                = Undefined;
	IsSubordinateDIBNode        = Common.IsSubordinateDIBNode();
	IsSeparatedMode          = Common.DataSeparationEnabled();
	IsStandaloneWorkplace = Common.IsStandaloneWorkplace();
	
	FoundRows = JobDependencies.FindRows(New Structure("ScheduledJob", Job));
	
	For Each DependencyString In FoundRows Do
		If IsSeparatedMode AND DependencyString.AvailableSaaS = False Then
			Return False;
		EndIf;
		
		DisableInSubordinateDIBNode = (DependencyString.AvailableInSubordinateDIBNode = False) AND IsSubordinateDIBNode;
		DisableInStandaloneWorkplace = (DependencyString.AvailableAtStandaloneWorkstation = False) AND IsStandaloneWorkplace;
		
		If DisableInSubordinateDIBNode Or DisableInStandaloneWorkplace Then
			Return False;
		EndIf;
		
		If DependencyString.FunctionalOption = Undefined Then
			Continue;
		EndIf;
		
		FOValue = GetFunctionalOption(DependencyString.FunctionalOption.Name);
		
		If Usage = Undefined Then
			Usage = FOValue;
		ElsIf DependencyString.DependenceByT Then
			Usage = Usage AND FOValue;
		Else
			Usage = Usage Or FOValue;
		EndIf;
	EndDo;
	
	If Usage = Undefined Then
		Return True;
	Else
		Return Usage;
	EndIf;
	
EndFunction

// Checks whether the infobase was moved, or restored from a backup.
// If the location of the infobase is changed, the scheduled job is canceled which is recorded to 
// the event log.
//
// Parameters:
//  Job - MetadataObject:ScheduledJob - scheduled job.
//  JobDependencies - ValueTable - table of scheduled jobs dependencies returned by the 
//    ScheduledJobsInternal.ScheduledJobsDependentOnFunctionalOptions method.
//    If it is not specified, it is generated automatically.
//
Procedure CheckCanOperateWithExternalResources(ScheduledJob, JobDependencies = Undefined) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	JobStartAllowed = Common.SystemSettingsStorageLoad("ScheduledJobs", ScheduledJob.MethodName);
	If JobStartAllowed = True Then
		Return;
	EndIf;
	
	If JobDependencies = Undefined Then
		JobDependencies = ScheduledJobsDependentOnFunctionalOptions();
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("ScheduledJob", ScheduledJob);
	Filter.Insert("UseExternalResources", True);
	
	FoundRows = JobDependencies.FindRows(Filter);
	If FoundRows.Count() = 0 Then
		Return;
	EndIf;
	
	If Not OperationsWithExternalResourcesLocked() Then
		Return;
	EndIf;
	
	LockParameters = Constants.ExternalResourceAccessLockParameters.Get().Get();
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			DataArea = ModuleSaaS.SessionSeparatorValue();
			MethodName = ScheduledJob.MethodName;
			
			JobParameters = New Structure;
			JobParameters.Insert("DataArea", DataArea);
			JobParameters.Insert("MethodName", MethodName);
			JobParameters.Insert("Use", True);
			ModuleJobQueue = Common.CommonModule("JobQueue");
			JobsList = ModuleJobQueue.GetJobs(JobParameters);
			
			JobParameters = New Structure("Use", False);
			For Each Job In JobsList Do
				ModuleJobQueue.ChangeJob(Job.ID, JobParameters);
				LockParameters.DisabledJobs.Add(Job.ID);
			EndDo;
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Приложение было перемещено.
			|Регламентное задание ""%1"", работающее с внешними ресурсами, отключено.'; 
			|en = 'The application was transferred.
			|Scheduled job ""%1"" working with external resources is disabled.'; 
			|pl = 'Aplikacja została przeniesiona.
			|Planowe zadanie ""%1"",działające z zewnętrznymi zasobami, zostało wyłączone.';
			|es_ES = 'La aplicación ha sido trasladada.
			|La tarea programada ""%1"", que usa los recursos externos, ha sido desactivada.';
			|es_CO = 'La aplicación ha sido trasladada.
			|La tarea programada ""%1"", que usa los recursos externos, ha sido desactivada.';
			|tr = 'Uygulama taşındı.
			|Dış kaynaklarla çalışan Standart görev ""%1"", kapatıldı.';
			|it = 'L''applicazione è stata trasferita.
			|Il task programmato ""%1"" che interagisce con le risorse esterne è disattivato.';
			|de = 'Die Anwendung wurde verschoben.
			|Die Routineaufgabe ""%1"", die mit externen Ressourcen arbeitet, ist deaktiviert.'"), ScheduledJob.Synonym);
		
	Else
		
		Filter = New Structure;
		Filter.Insert("Metadata", ScheduledJob);
		Filter.Insert("Use", True);
		JobArray = ScheduledJobs.GetScheduledJobs(Filter);
		
		For Each Job In JobArray Do
			
			Job.Use = False;
			Job.Write();
			
			LockParameters.DisabledJobs.Add(Job.UUID);
			
		EndDo;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Изменилась строка соединения информационной базы.
			|Возможно информационная база была перемещена.
			|Регламентное задание ""%1"" отключено.'; 
			|en = 'Infobase connection string was changed.
			|Perhaps, the infobase was transferred.
			|Scheduled job ""%1"" is disabled.'; 
			|pl = 'Zmienił się ciąg połączenia bazy informacyjnej.
			|Możliwie, że baza informacyjna została przeniesiona.
			|Planowe zadanie ""%1"" zostało wyłączone.';
			|es_ES = 'Se ha cambiado la línea de conexión de la base de información.
			|Es posible que la base de información ha sido trasladada.
			|La tarea programada ""%1"" ha sido desactivada.';
			|es_CO = 'Se ha cambiado la línea de conexión de la base de información.
			|Es posible que la base de información ha sido trasladada.
			|La tarea programada ""%1"" ha sido desactivada.';
			|tr = 'Veritabanın bağlantı satırı değişti.
			|Veritabanı taşınmış olabilir.
			|Standart görev ""%1"" devre dışı bırakıldı.';
			|it = 'La riga di connessione dell''infobase è cambiata.
			|Probabilmente l''infobase è stato trasferito.
			|Il task programmato ""%1"" è disattivato.';
			|de = 'Die Verbindungszeichenfolge der Informationsdatenbank wurde geändert.
			|Möglicherweise wurde die Informationsbasis verschoben.
			|Die Routineaufgabe ""%1"" ist deaktiviert.'"), ScheduledJob.Synonym);
		
	EndIf;
	
	ValueStorage = New ValueStorage(LockParameters);
	Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
	
EndProcedure

// Generates a table of dependencies of scheduled jobs on functional options.
//
// Returns:
//  Dependencies - ValueTable - a table of values with the following columns:
//    * ScheduledJob - MetadataObject:ScheduledJob - scheduled job.
//    * FunctionalOption - MetadataObject:FunctionalOption - functional option the scheduled job 
//        depends on.
//    * DependenceByT - Boolean - if the scheduled job depends on more than one functional option 
//        and you want to enable it only when all functional options are enabled, specify True for 
//        each dependency.
//        
//        The default value is False - if one or more functional options are enabled, the scheduled 
//        job is also enabled.
//    * EnableOnEnableFunctionalOption - Boolean, Undefined - if False, the scheduled job will not 
//        be enabled if the functional option is enabled. Value
//        Undefined corresponds to True.
//        The default value is Undefined.
//    * AvailableInSubordinateDIBNode - Boolean, Undefined - True or Undefined if the scheduled job 
//        is available in the DIB node.
//        The default value is Undefined.
//    * AvailableInSaaS - Boolean, Undefined - True or Undefined if the scheduled job is available 
//        in the SaaS.
//        The default value is Undefined.
//    * UseExternalResources - Boolean - True if the scheduled job is operating with external 
//        resources (receiving emails, synchronizing data, etc.).
//        The default value is False.
//
Function ScheduledJobsDependentOnFunctionalOptions() Export
	
	Dependencies = New ValueTable;
	Dependencies.Columns.Add("ScheduledJob");
	Dependencies.Columns.Add("FunctionalOption");
	Dependencies.Columns.Add("DependenceByT", New TypeDescription("Boolean"));
	Dependencies.Columns.Add("AvailableSaaS");
	Dependencies.Columns.Add("AvailableInSubordinateDIBNode");
	Dependencies.Columns.Add("EnableOnEnableFunctionalOption");
	Dependencies.Columns.Add("AvailableAtStandaloneWorkstation");
	Dependencies.Columns.Add("UseExternalResources",  New TypeDescription("Boolean"));
	Dependencies.Columns.Add("IsParameterized",  New TypeDescription("Boolean"));
	
	SSLSubsystemsIntegration.OnDefineScheduledJobSettings(Dependencies);
	ScheduledJobsOverridable.OnDefineScheduledJobSettings(Dependencies);
	
	Dependencies.Sort("ScheduledJob");
	
	Return Dependencies;
	
EndFunction

// Allows operating with external resources after the infobase is moved.
//
Procedure AllowOperationsWithExternalResources(LockParameters = Undefined) Export
	
	If LockParameters = Undefined Then
		LockParameters = Constants.ExternalResourceAccessLockParameters.Get().Get();
	EndIf;
	
	Filter = New Structure("UUID");
	For Each JobID In LockParameters.DisabledJobs Do
		
		If Common.DataSeparationEnabled() Then
			If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
				If TypeOf(JobID) = Type("UUID") Then
					Continue;
				EndIf;
				ModuleSaaS = Common.CommonModule("SaaS");
				
				JobParameters = New Structure;
				JobParameters.Insert("DataArea", ModuleSaaS.SessionSeparatorValue());
				JobParameters.Insert("ID", JobID);
				JobParameters.Insert("Use", False);
				ModuleJobQueue = Common.CommonModule("JobQueue");
				JobsList = ModuleJobQueue.GetJobs(JobParameters);
				
				JobParameters = New Structure("Use", True);
				For Each Job In JobsList Do
					ModuleJobQueue.ChangeJob(Job.ID, JobParameters);
				EndDo;
			EndIf;
		Else
			Filter.UUID = JobID;
			FoundJobs = ScheduledJobs.GetScheduledJobs(Filter);
			
			For Each DisabledJob In FoundJobs Do
				DisabledJob.Use = True;
				DisabledJob.Write();
			EndDo;
		EndIf;
		
	EndDo;
	
	ConnectionString = InfoBaseConnectionString();
	IsFileInfobase = Common.FileInfobase(ConnectionString);
	
	LockParameters.IsFileInfobase = IsFileInfobase;
	LockParameters.ConnectionString = ConnectionString;
	LockParameters.OperationsWithExternalResourcesLocked = False;
	LockParameters.DisabledJobs.Clear();
	LockParameters.InfobaseID = FileInfobaseID(IsFileInfobase);
	LockParameters.DataSeparationEnabled = Common.DataSeparationEnabled();
	
	ValueStorage = New ValueStorage(LockParameters);
	Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
	
	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleNetworkDownloadClientServer = Common.CommonModule("ConversationsServiceServerCall");
		ModuleNetworkDownloadClientServer.Unlock();
	EndIf;
	
	SessionParameters.OperationsWithExternalResourcesLocked = False;
	
	RefreshReusableValues();
EndProcedure

// Denies operations with external resources.
//
Procedure DenyOperationsWithExternalResources() Export
	
	LockParameters = Constants.ExternalResourceAccessLockParameters.Get().Get();
	
	If LockParameters = Undefined Then
		InitializeOperationsWithExternalResourcesLockParameters(True);
	Else
		LockParameters.OperationsWithExternalResourcesLocked = True;
		ValueStorage = New ValueStorage(LockParameters);
		Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleNetworkDownloadClientServer = Common.CommonModule("ConversationsServiceServerCall");
		ModuleNetworkDownloadClientServer.Lock();
	EndIf;
	
	SessionParameters.OperationsWithExternalResourcesLocked = True;
	
	RefreshReusableValues();
	
EndProcedure

// Returns a flag showing that operations with external resources are locked.
//
// Returns:
//   Boolean - True if operations with external resources are locked.
//
Function OperationsWithExternalResourcesLocked() Export
	
	Return SessionParameters.OperationsWithExternalResourcesLocked;
	
EndFunction

// Sets a flag of scheduled jobs usage in the infobase depending on values of functional options.
// 
//
// Parameters:
//  EnableJobs - Boolean - if True, disabled scheduled jobs will be enabled when they become 
//                             available according to functional options. The default value is False.
//
Procedure SetScheduledJobsUsageByFunctionalOptions(EnableJobs = False) Export
	
	IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
	IsStandaloneWorkplace = Common.IsStandaloneWorkplace();
	
	DependentScheduledJobs = ScheduledJobsDependentOnFunctionalOptions();
	Jobs = DependentScheduledJobs.Copy(,"ScheduledJob");
	Jobs.GroupBy("ScheduledJob");
	
	For Each RowJob In Jobs Do
		
		Usage                    = Undefined;
		DisableJob                 = True;
		DisableInSubordinateDIBNode     = False;
		DisableInStandaloneWorkplace = False;
		
		FoundRows = DependentScheduledJobs.FindRows(New Structure("ScheduledJob", RowJob.ScheduledJob));
		
		For Each DependencyString In FoundRows Do
			DisableInSubordinateDIBNode = (DependencyString.AvailableInSubordinateDIBNode = False) AND IsSubordinateDIBNode;
			DisableInStandaloneWorkplace = (DependencyString.AvailableAtStandaloneWorkstation = False) AND IsStandaloneWorkplace;
			If DisableInSubordinateDIBNode Or DisableInStandaloneWorkplace Then
				Usage = False;
				Break;
			EndIf;
			
			If DependencyString.FunctionalOption = Undefined Then
				Continue;
			EndIf;
			
			FOValue = GetFunctionalOption(DependencyString.FunctionalOption.Name);
			
			If DependencyString.EnableOnEnableFunctionalOption = False Then
				If DisableJob Then
					DisableJob = Not FOValue;
				EndIf;
				FOValue = False;
			EndIf;
			
			If Usage = Undefined Then
				Usage = FOValue;
			ElsIf DependencyString.DependenceByT Then
				Usage = Usage AND FOValue;
			Else
				Usage = Usage Or FOValue;
			EndIf;
		EndDo;
		
		If Usage = Undefined
			Or (Usage AND Not EnableJobs) // Only disable scheduled jobs automatically on update.
			Or (Not Usage AND Not DisableJob) Then
			Continue;
		EndIf;
		
		JobsList = ScheduledJobsServer.FindJobs(New Structure("Metadata", RowJob.ScheduledJob));
		For Each ScheduledJob In JobsList Do
			JobParameters = New Structure("Use", Usage);
			ScheduledJobsServer.ChangeJob(ScheduledJob, JobParameters);
		EndDo;
		
	EndDo;
	
EndProcedure

// Determines whether the operations with external resources are locked.
//
Function ExternalResourceUsageLockSet(IsCallBeforeStart = False, ShowForm = False) Export
	
	SetPrivilegedMode(True);
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return False;
	EndIf;
	
	SavedParameters = Constants.ExternalResourceAccessLockParameters.Get().Get();
	
	If SavedParameters = Undefined Then
		If Not IsCallBeforeStart Then
			Return False;
		EndIf;
		
		Proceed = True;
		BeginTransaction();
		Try
			Lock = New DataLock;
			LockItem = Lock.Add("Constant.ExternalResourceAccessLockParameters");
			Lock.Lock();
			
			SavedParameters = Constants.ExternalResourceAccessLockParameters.Get().Get();
			If SavedParameters = Undefined Then
				InitializeOperationsWithExternalResourcesLockParameters();
				Proceed = False;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		If Not Proceed Then
			Return False;
		EndIf;
	EndIf;
	
	LockParameters = ExternalResourceAccessLockParameters();
	FillPropertyValues(LockParameters, SavedParameters);
	
	If LockParameters.OperationsWithExternalResourcesLocked = Undefined Then
		Return True; // If the flag was selected in the scheduled job.
	ElsIf LockParameters.OperationsWithExternalResourcesLocked = True Then
		Return Not ShowForm; // Lock of operations with external resources is confirmed by the administrator.
	EndIf;
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	// Infobase transfer is determined by the service manager in SaaS mode.
	If DataSeparationEnabled Then
		Return False;
	EndIf;
	
	If DataSeparationEnabled <> LockParameters.DataSeparationEnabled Then
		// Data separation is disabled.
		MessageText = NStr("ru = 'Информационная база была перемещена из приложения в Интернете.'; en = 'Infobase was transferred from an online application.'; pl = 'Baza informacji została przeniesiona z aplikacji w Internecie.';es_ES = 'La base de información ha sido trasladada de la aplicación en Internet.';es_CO = 'La base de información ha sido trasladada de la aplicación en Internet.';tr = 'Veritabanı çevrimiçi uygulamadan taşındı.';it = 'Il database è stato spostato dall''applicazione su Internet.';de = 'Die Informationsbasis wurde aus der Anwendung im Internet verschoben.'");
		SetFlagShowsNecessityOfLock(LockParameters, MessageText);
		Return True;
	EndIf;
	
	ConnectionString = InfoBaseConnectionString();
	IsFileInfobase = Common.FileInfobase(ConnectionString);
	
	If IsFileInfobase <> LockParameters.IsFileInfobase Then
		MessageText = ?(IsFileInfobase, NStr("ru = 'Информационная база была перемещена из клиент-серверного режима работы в файловый.'; en = 'Infobase was transferred from the client/server mode to the file mode.'; pl = 'Baza informacji została przeniesiona z trybu klient-serwer do trybu pracy w pliku.';es_ES = 'La base de información ha sido trasladada del modo de cliente-servidor al modo de archivo.';es_CO = 'La base de información ha sido trasladada del modo de cliente-servidor al modo de archivo.';tr = 'Veritabanı istemci-sunucu çalışma modundan dosya moduna taşındı.';it = 'Il database è stato spostato dal regime di lavoro client-server a quello a file.';de = 'Die Informationsbasis wurde vom Client-Server-Modus in den Datei-Modus verschoben.'"),
			NStr("ru = 'Информационная база была перемещена из файловый режима работы в клиент-серверный.'; en = 'Infobase was transferred from the file mode to the client/server mode.'; pl = 'Baza danych informacji została przeniesiona z trybu plików do trybu pracy w klient-serwer.';es_ES = 'La base de información ha sido trasladada del modo de archivo al modo de cliente-servidor.';es_CO = 'La base de información ha sido trasladada del modo de archivo al modo de cliente-servidor.';tr = 'Veritabanı dosya modundan istemci-sunucu çalışma moduna taşındı.';it = 'Il database è stato spostato dal regime di lavoro a file a quello client-server.';de = 'Die Informationsbasis wurde vom Datei-Modus in den Client-Server-Modus verschoben.'"));
		SetFlagShowsNecessityOfLock(LockParameters, MessageText);
		Return True;
	EndIf;
	
	// If the connection string matches, do not perform any further check.
	If ConnectionString = LockParameters.ConnectionString Then
		Return False;
	EndIf;
	
	If IsFileInfobase Then
		// For the infobase connection string can be different when connecting from different computers. 
		// Therefore, check whether the infobase has been moved using the file.
		CheckFileName = "DoNotCopy.txt";
		FilesFound = FindFiles(CommonClientServer.FileInfobaseDirectory(), CheckFileName);
		If FilesFound.Count() = 0 Then
			// Infobase directory does not contain check file.
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'В каталоге информационной базы отсутствует файл проверки %1.'; en = 'Infobase directory does not contain check file %1.'; pl = 'W katalogu bazy informacyjnej nie ma pliku weryfikacyjnego%1.';es_ES = 'En el catálogo de la base de información no hay archivo de prueba %1.';es_CO = 'En el catálogo de la base de información no hay archivo de prueba %1.';tr = 'Infobase dizini, %1 denetim dosyasını içermiyor.';it = 'La directory dell''infobase non contiene il file di controllo %1.';de = 'Im Verzeichnis der Informationsbasis befindet sich keine Prüfdatei %1.'"), CheckFileName);
			SetFlagShowsNecessityOfLock(LockParameters, MessageText);
			Return True;
		EndIf;
		TextReader = New TextReader(FilesFound[0].FullName);
		InfobaseID = TextReader.ReadLine();
		// There is a file, but the ID does not match the expected.
		If InfobaseID <> LockParameters.InfobaseID Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Идентификатор информационной базы в файле проверки %1 не соответствует идентификатору в текущей базе.'; en = 'The infobase ID in the check file %1 does not match the current base ID.'; pl = 'Identyfikator bazy informacyjnej w pliku kontrolnym %1 nie pasuje do identyfikatora w bieżącej bazie danych.';es_ES = 'El identificador de la base de información en el archivo de la prueba %1 no coincide al identificador en la base actual.';es_CO = 'El identificador de la base de información en el archivo de la prueba %1 no coincide al identificador en la base actual.';tr = '%1 denetim dosyasındaki Infobase kimliği mevcut Infobase kimliğiyle eşleşmiyor.';it = 'L''ID dell''infobase nel file di controllo %1 non coincide con l''ID dell''infobase attuale.';de = 'Die Kennung der Informationsbasis in der Prüfdatei %1 entspricht nicht der Kennung in der aktuellen Datenbank.'"), CheckFileName);
			SetFlagShowsNecessityOfLock(LockParameters, MessageText);
			Return True;
		EndIf;
	Else // Client/server infobase
		InfobaseName = Lower(StringFunctionsClientServer.ParametersFromString(ConnectionString).Ref);
		ServerName = Lower(StringFunctionsClientServer.ParametersFromString(ConnectionString).Srvr);
		SavedInfobaseName = Lower(StringFunctionsClientServer.ParametersFromString(LockParameters.ConnectionString).Ref);
		SavedServerName = Lower(StringFunctionsClientServer.ParametersFromString(LockParameters.ConnectionString).Srvr);
		
		If InfobaseName <> SavedInfobaseName
			Or ServerName <> SavedServerName Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Различаются имя информационной базы или имя компьютера.
					|Сохраненное имя базы: %1, текущее имя базы: %2.'; 
					|en = 'The infobase names or computer names differ.
					|Stored infobase name: %1. Current infobase name: %2.'; 
					|pl = 'Nazwa bazy informacyjnej lub nazwa komputera są różne.
					|Zapisana nazwa bazy: %1, aktualna nazwa bazy: %2.';
					|es_ES = 'Se diferencian el nombre de la base de información o el nombre del ordenador.
					|Nombre de la base guardado: %1, el nombre de la base actual: %2.';
					|es_CO = 'Se diferencian el nombre de la base de información o el nombre del ordenador.
					|Nombre de la base guardado: %1, el nombre de la base actual: %2.';
					|tr = 'Bilgi tabanı adı veya bilgisayar adı değişir. 
					|Kaydedilen taban adı: %1.geçerli taban adı:%2.';
					|it = 'Il nome dell''infobase o del computer è diverso.
					|Il nome infobase memorizzato: %1. Nome infobase corrente:%2.';
					|de = 'Der Name der Informationsbasis oder der Computername ist unterschiedlich.
					|Gespeicherter Datenbankname: %1, aktueller Datenbankname: %2.'"),
				SavedInfobaseName, InfobaseName);
			SetFlagShowsNecessityOfLock(LockParameters, MessageText);
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// The procedure enables or disables the scheduled jobs created in the infobase on functional option 
// change.
//
// Parameters:
//  Source - ConstantValueManager - constant stores the value of FO.
//  Cancel - Boolean - cancel while writing constant.
//
Procedure EnableScheduledJobOnChangeFunctionalOption(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	ChangeScheduledJobsUsageByFunctionalOptions(Source, Source.Value);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("OperationsWithExternalResourcesLocked",
		"ScheduledJobsInternal.SessionParametersSetting");
	
EndProcedure

// See ExportImportDataOverridable.AfterDataImport. 
Procedure AfterImportData(Container) Export
	If Common.DataSeparationEnabled() Then
		InitializeOperationsWithExternalResourcesLockParameters();
	EndIf;
EndProcedure

// See SaaSOverridable.OnFillIBParametersTable. 
Procedure OnFillIIBParametersTable(Val ParametersTable) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.AddConstantToIBParametersTable(ParametersTable, "MaxActiveBackgroundJobExecutionTime");
		ModuleSaaS.AddConstantToIBParametersTable(ParametersTable, "MaxActiveBackgroundJobCount");
	EndIf;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.24";
	Handler.Procedure = "ScheduledJobsInternal.SetScheduledJobsUsageByFunctionalOptions";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.3.12";
	Handler.InitialFilling = True;
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "ScheduledJobsInternal.UpdateExternalResourceAccessLockParameters";
	
EndProcedure

// See JobQueueOverridable.OnDetermineScheduledJobsUsage. 
Procedure OnDetermineScheduledJobsUsage(UsageTable) Export
	
	DependentScheduledJobs = ScheduledJobsDependentOnFunctionalOptions();
	
	FilterParameters = New Structure;
	FilterParameters.Insert("AvailableSaaS", False);
	SaaSJobsToDisable = DependentScheduledJobs.Copy(FilterParameters ,"ScheduledJob");
	For Each JobToDisable In SaaSJobsToDisable Do
		If UsageTable.Find(JobToDisable.ScheduledJob.Name, "ScheduledJob") <> Undefined Then
			Continue;
		EndIf;
		
		NewRow = UsageTable.Add();
		NewRow.ScheduledJob = JobToDisable.ScheduledJob.Name;
		NewRow.Use       = False;
	EndDo;
	
	FilterParameters.Insert("AvailableSaaS", True);
	SaaSJobsToEnable = DependentScheduledJobs.Copy(FilterParameters ,"ScheduledJob");
	For Each JobToEnable In SaaSJobsToEnable Do
		If UsageTable.Find(JobToEnable.ScheduledJob.Name, "ScheduledJob") <> Undefined Then
			Continue;
		EndIf;
		
		NewRow = UsageTable.Add();
		NewRow.ScheduledJob = JobToEnable.ScheduledJob.Name;
		NewRow.Use       = True;
	EndDo;
	
EndProcedure

// See DataExchangeOverridable.OnSetUpSubordinateDIBNode. 
Procedure OnSetUpSubordinateDIBNode() Export
	
	SetScheduledJobsUsageByFunctionalOptions();
	
EndProcedure

#EndRegion

#Region Private

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	If ParameterName = "OperationsWithExternalResourcesLocked" Then
		SessionParameters.OperationsWithExternalResourcesLocked = ExternalResourceUsageLockSet();
		SpecifiedParameters.Add("OperationsWithExternalResourcesLocked");
	EndIf;
	
EndProcedure

Function SettingValue(SettingName) Export
	
	Settings = DefaultSettings();
	ScheduledJobsOverridable.OnDefineSettings(Settings);
	
	Return Settings[SettingName];
	
EndFunction

// Contains the default settings.
//
// Returns:
//  Structure - a structure with the keys:
//    * UnlockCommandLocation - String - determines unlock command location for operations with 
//                                                     external resources.
//
Function DefaultSettings()
	
	SubsystemSettings = New Structure;
	SubsystemSettings.Insert("UnlockCommandPlacement",
		NStr("ru = 'Блокировку также можно снять позднее в разделе <b>Администрирование - Обслуживание</b>.'; en = 'You can also remove lock later in section <b>Administration - Service</b>.'; pl = 'Możesz także usunąć blokadę później w sekcji <b>Administracja - Obsługa</b>.';es_ES = 'Se puede quitar el bloqueo también más tarde en la sección <b>Administración - Servicio</b>.';es_CO = 'Se puede quitar el bloqueo también más tarde en la sección <b>Administración - Servicio</b>.';tr = 'Kilitleme, <b>Yönetim-bakım</b> bölümünde daha sonra da kaldırılabilir.';it = 'Potete togliere il blocco dopo nella seione <b>Amministrazione - Servizi</b>';de = 'Die Sperre kann auch später im Abschnitt <b>Administration - Service</b> aufgehoben werden.'"));
	
	Return SubsystemSettings;
	
EndFunction

// Throws an exception if the user does not have the administration right.
Procedure RaiseIfNoAdministrationRights() Export
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		If NOT Users.IsFullUser() Then
			Raise NStr("ru = 'Нарушение прав доступа.'; en = 'Access right violation.'; pl = 'Naruszenie praw dostępu.';es_ES = 'Violación del derecho de acceso.';es_CO = 'Violación del derecho de acceso.';tr = 'Erişim hakkı ihlali.';it = 'Violazione permessi di accesso.';de = 'Verletzung von Zugriffsrechten.'");
		EndIf;
	Else
		If NOT PrivilegedMode() Then
			VerifyAccessRights("Administration", Metadata);
		EndIf;
	EndIf;
	
EndProcedure

Function UpdatedScheduledJobTable(Parameters, StorageAddress) Export
	
	ScheduledJobID = Parameters.ScheduledJobID;
	Table                           = Parameters.Table;
	DisabledJobs                = Parameters.DisabledJobs;
	
	// Updating the ScheduledJobs table and the ChoiceList list of the scheduled job for filter.
	CurrentJobs = ScheduledJobs.GetScheduledJobs();
	DisabledJobs.Clear();
	
	ScheduledJobsParameters = ScheduledJobsDependentOnFunctionalOptions();
	FilterParameters        = New Structure;
	ParameterizedJobs = New Array;
	FilterParameters.Insert("IsParameterized", True);
	SearchResult = ScheduledJobsParameters.FindRows(FilterParameters);
	For Each ResultString In SearchResult Do
		ParameterizedJobs.Add(ResultString.ScheduledJob);
	EndDo;
	
	SaaSJobs = New Map;
	SaaSSubsystem = Metadata.Subsystems.StandardSubsystems.Subsystems.Find("SaaS");
	For Each MetadataObject In Metadata.ScheduledJobs Do
		If Not ScheduledJobAvailableByFunctionalOptions(MetadataObject, ScheduledJobsParameters) Then
			DisabledJobs.Add(MetadataObject.Name);
			Continue;
		EndIf;
		If NOT Common.DataSeparationEnabled() AND SaaSSubsystem <> Undefined Then
			If SaaSSubsystem.Content.Contains(MetadataObject) Then
				DisabledJobs.Add(MetadataObject.Name);
				Continue;
			EndIf;
			For each Subsystem In SaaSSubsystem.Subsystems Do
				If Subsystem.Content.Contains(MetadataObject) Then
					DisabledJobs.Add(MetadataObject.Name);
					Continue;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	If ScheduledJobID = Undefined Then
		
		Index = 0;
		For Each Job In CurrentJobs Do
			
			ID = String(Job.UUID);
			
			If Index >= Table.Count()
			 OR Table[Index].ID <> ID Then
				
				// Inserting a new job.
				ToUpdate = Table.Insert(Index);
				
				// Setting a unique ID.
				ToUpdate.ID = ID;
			Else
				ToUpdate = Table[Index];
			EndIf;
			
			If ParameterizedJobs.Find(Job.Metadata) <> Undefined Then
				ToUpdate.Parameterized = True;
			EndIf;
			
			UpdateScheduledJobTableRow(ToUpdate, Job);
			Index = Index + 1;
		EndDo;
	
		// Deleting unnecessary rows.
		While Index < Table.Count() Do
			Table.Delete(Index);
		EndDo;
	Else
		Job = ScheduledJobs.FindByUUID(
			New UUID(ScheduledJobID));
		
		Rows = Table.FindRows(
			New Structure("ID", ScheduledJobID));
		
		If Job <> Undefined
		   AND Rows.Count() > 0 Then
			
			RowJob = Rows[0];
			If ParameterizedJobs.Find(Job.Metadata) <> Undefined Then
				RowJob.Parameterized = True;
			EndIf;
			UpdateScheduledJobTableRow(RowJob, Job);
		EndIf;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Table", Table);
	Result.Insert("DisabledJobs", DisabledJobs);
	
	PutToTempStorage(Result, StorageAddress);
	
EndFunction

Procedure UpdateScheduledJobTableRow(Row, Job)
	
	FillPropertyValues(Row, Job);
	
	// Description adjustment
	Row.Description = ScheduledJobPresentation(Job);
	
	// Setting the Completion date and the Completion state by the last background procedure .
	LastBackgroundJobProperties = ScheduledJobsInternal
		.GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
	
	Row.JobName = Job.Metadata.Name;
	If LastBackgroundJobProperties = Undefined Then
		Row.StartDate          = TextUndefined();
		Row.EndDate       = TextUndefined();
		Row.ExecutionState = TextUndefined();
	Else
		Row.StartDate          = ?(ValueIsFilled(LastBackgroundJobProperties.Begin),
		                               LastBackgroundJobProperties.Begin,
		                               "<>");
		Row.EndDate       = ?(ValueIsFilled(LastBackgroundJobProperties.End),
		                               LastBackgroundJobProperties.End,
		                               "<>");
		Row.ExecutionState = LastBackgroundJobProperties.State;
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with scheduled jobs.

// It is intended for "manual" immediate execution of the scheduled job procedure either in the 
// client session (in the file infobase) or in the background job on the server (in the server infobase).
// It is used in any connection mode.
// The "manual" run mode does not affect the scheduled job execution according to the emergency and 
// main schedules, as the background job has no reference to the scheduled job.
// The BackgroundJob type does not allow such a reference, so the same rule is applied to file mode.
// 
// 
// Parameters:
//  Job - ScheduledJob, String - ScheduledJob UUID string.
//
// Returns:
//  Structure with the following properties:
//    * StartTime - Undefined, Date - for the file infobase, sets the passed time as the scheduled 
//                        job method start time.
//                        For the server infobase returns the background job start time upon completion.
//    * BackgroundJobID - String - for the server infobase, returns the running background job ID.
//
Function ExecuteScheduledJobManually(Val Job) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	ExecutionParameters = ScheduledJobExecutionParameters();
	ExecutionParameters.ProcedureAlreadyExecuting = False;
	Job = ScheduledJobsServer.GetScheduledJob(Job);
	
	ExecutionParameters.Started = False;
	LastBackgroundJobProperties = GetLastBackgroundJobForScheduledJobExecutionProperties(Job);
	
	If LastBackgroundJobProperties <> Undefined
	   AND LastBackgroundJobProperties.State = BackgroundJobState.Active Then
		
		ExecutionParameters.StartedAt  = LastBackgroundJobProperties.Begin;
		If ValueIsFilled(LastBackgroundJobProperties.Description) Then
			ExecutionParameters.BackgroundJobPresentation = LastBackgroundJobProperties.Description;
		Else
			ExecutionParameters.BackgroundJobPresentation = ScheduledJobPresentation(Job);
		EndIf;
	Else
		BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Запуск вручную: %1'; en = '%1 started manually'; pl = 'Uruchomienie ręczne: %1';es_ES = 'Iniciar manualmente: %1';es_CO = 'Iniciar manualmente: %1';tr = 'Manuel olarak başlat: %1';it = '%1 avviato manualmente';de = 'Manuell starten: %1'"), ScheduledJobPresentation(Job));
		// Time-consuming operations are not used, because the method of the scheduled job is called.
		BackgroundJob = BackgroundJobs.Execute(Job.Metadata.MethodName, Job.Parameters, String(Job.UUID), BackgroundJobDescription);
		ExecutionParameters.BackgroundJobID = String(BackgroundJob.UUID);
		ExecutionParameters.StartedAt = BackgroundJobs.FindByUUID(BackgroundJob.UUID).Begin;
		ExecutionParameters.Started = True;
	EndIf;
	
	ExecutionParameters.ProcedureAlreadyExecuting = NOT ExecutionParameters.Started;
	Return ExecutionParameters;
	
EndFunction

Function ScheduledJobExecutionParameters() 
	
	Result = New Structure;
	Result.Insert("StartedAt");
	Result.Insert("BackgroundJobID");
	Result.Insert("BackgroundJobPresentation");
	Result.Insert("ProcedureAlreadyExecuting");
	Result.Insert("Started");
	Return Result;
	
EndFunction

// Returns the scheduled job presentation, according to the blank details exception order:
// 
// Description, Metadata.Synonym, and Metadata.Name.
//
// Parameters:
//  Job - ScheduledJob, String - if a string, a UUID string.
//
// Returns:
//  String.
//
Function ScheduledJobPresentation(Val Job) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	If TypeOf(Job) = Type("ScheduledJob") Then
		ScheduledJob = Job;
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(New UUID(Job));
	EndIf;
	
	If ScheduledJob <> Undefined Then
		Presentation = ScheduledJob.Description;
		
		If IsBlankString(ScheduledJob.Description) Then
			Presentation = ScheduledJob.Metadata.Synonym;
			
			If IsBlankString(Presentation) Then
				Presentation = ScheduledJob.Metadata.Name;
			EndIf
		EndIf;
	Else
		Presentation = TextUndefined();
	EndIf;
	
	Return Presentation;
	
EndFunction

// Returns the text "<not defined>".
Function TextUndefined() Export
	
	Return NStr("ru = '<не определено>'; en = '<not defined>'; pl = '<nie określono>';es_ES = '<no determinado>';es_CO = '<not defined>';tr = '<belirlenmedi>';it = '<non definito>';de = '<nicht definiert>'");
	
EndFunction

// Returns a multiline String containing Messages and ErrorDescription, the last background job is 
// found by the scheduled job ID and there are messages/errors.
// 
//
// Parameters:
//  Job - ScheduledJob, String - UUID
//                 ScheduledJob string.
//
// Returns:
//  String.
//
Function ScheduledJobMessagesAndErrorDescriptions(Val Job) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);

	ScheduledJobID = ?(TypeOf(Job) = Type("ScheduledJob"), String(Job.UUID), Job);
	LastBackgroundJobProperties = GetLastBackgroundJobForScheduledJobExecutionProperties(ScheduledJobID);
	Return ?(LastBackgroundJobProperties = Undefined,
	          "",
	          BackgroundJobMessagesAndErrorDescriptions(LastBackgroundJobProperties.ID) );
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with background jobs.

// Cancels the background job if possible, i.e. if it is running on the server and is active.
//
// Parameters:
//  ID - BackgroundJob unique ID string.
// 
Procedure CancelBackgroundJob(ID) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	NewUUID = New UUID(ID);
	Filter = New Structure;
	Filter.Insert("UUID", NewUUID);
	BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
	If BackgroundJobArray.Count() = 1 Then
		BackgroundJob = BackgroundJobArray[0];
	Else
		Raise NStr("ru = 'Фоновое задание не найдено на сервере.'; en = 'The background job is not found on the server.'; pl = 'Na serwerze nie znaleziono zadania w tle.';es_ES = 'Tarea de fondo no encontrada en el servidor.';es_CO = 'Tarea de fondo no encontrada en el servidor.';tr = 'Arka plan işi sunucuda bulunamadı.';it = 'Il task di background non è stato trovato sul server.';de = 'Hintergrundjob wurde auf dem Server nicht gefunden.'");
	EndIf;
	
	If BackgroundJob.State <> BackgroundJobState.Active Then
		Raise NStr("ru = 'Задание не выполняется, его нельзя отменить.'; en = 'The job is not running, it cannot be cancelled.'; pl = 'Zadanie nie może byc zakończone, nie można go anulować.';es_ES = 'No se puede finalizar la tarea, no puede cancelarse.';es_CO = 'No se puede finalizar la tarea, no puede cancelarse.';tr = 'İş tamamlanamıyor, iptal edilemez.';it = 'Il task non è in esecuzione, non può essere annullato.';de = 'Der Job kann nicht abgeschlossen werden, er kann nicht abgebrochen werden.'");
	EndIf;
	
	BackgroundJob.Cancel();
	
EndProcedure

// For internal use only.
//
Function BkacgroundJobPropertyTableInBackground(Parameters, StorageAddress) Export
	
	PropertiesTable = BackgroundJobsProperties(Parameters.Filter);
	
	Result = New Structure;
	Result.Insert("PropertiesTable", PropertiesTable);
	
	PutToTempStorage(Result, StorageAddress);
	
EndFunction

// Returns a background job property table.
//  See the table structure in the EmptyBackgroundJobPropertyTable() function.
// 
// Parameters:
//  Filter - Structure - valid fields:
//                 ID, Key, State, Beginning, End,
//                 Description, MethodName, and ScheduledJob.
//
// Returns:
//  ValueTable returns a table after filter.
//
Function BackgroundJobsProperties(Filter = Undefined) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Table = NewBackgroundJobsProperties();
	
	If ValueIsFilled(Filter) AND Filter.Property("GetLastScheduledJobBackgroundJob") Then
		Filter.Delete("GetLastScheduledJobBackgroundJob");
		GetLast = True;
	Else
		GetLast = False;
	EndIf;
	
	ScheduledJob = Undefined;
	
	// Adding the history of background jobs received from the server.
	If ValueIsFilled(Filter) AND Filter.Property("ScheduledJobID") Then
		If Filter.ScheduledJobID <> "" Then
			ScheduledJob = ScheduledJobs.FindByUUID(
				New UUID(Filter.ScheduledJobID));
			CurrentFilter = New Structure("Key", Filter.ScheduledJobID);
			BackgroundJobsStartedManually = BackgroundJobs.GetBackgroundJobs(CurrentFilter);
			If ScheduledJob <> Undefined Then
				LastBackgroundJob = ScheduledJob.LastJob;
			EndIf;
			If NOT GetLast OR LastBackgroundJob = Undefined Then
				CurrentFilter = New Structure("ScheduledJob", ScheduledJob);
				AutomaticBackgroundJobs = BackgroundJobs.GetBackgroundJobs(CurrentFilter);
			EndIf;
			If GetLast Then
				If LastBackgroundJob = Undefined Then
					LastBackgroundJob = LastBackgroundJobInArray(AutomaticBackgroundJobs);
				EndIf;
				
				LastBackgroundJob = LastBackgroundJobInArray(
					BackgroundJobsStartedManually, LastBackgroundJob);
				
				If LastBackgroundJob <> Undefined Then
					BackgroundJobArray = New Array;
					BackgroundJobArray.Add(LastBackgroundJob);
					AddBackgroundJobProperties(BackgroundJobArray, Table);
				EndIf;
				Return Table;
			EndIf;
			AddBackgroundJobProperties(BackgroundJobsStartedManually, Table);
			AddBackgroundJobProperties(AutomaticBackgroundJobs, Table);
		Else
			BackgroundJobArray = New Array;
			AllScheduledJobIDs = New Map;
			For each CurrentJob In ScheduledJobs.GetScheduledJobs() Do
				AllScheduledJobIDs.Insert(
					String(CurrentJob.UUID), True);
			EndDo;
			AllBackgroundJobs = BackgroundJobs.GetBackgroundJobs();
			For each CurrentJob In AllBackgroundJobs Do
				If CurrentJob.ScheduledJob = Undefined
				   AND AllScheduledJobIDs[CurrentJob.Key] = Undefined Then
				
					BackgroundJobArray.Add(CurrentJob);
				EndIf;
			EndDo;
			AddBackgroundJobProperties(BackgroundJobArray, Table);
		EndIf;
	Else
		If NOT ValueIsFilled(Filter) Then
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs();
		Else
			If Filter.Property("ID") Then
				Filter.Insert("UUID", New UUID(Filter.ID));
				Filter.Delete("ID");
			EndIf;
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
			If Filter.Property("UUID") Then
				Filter.Insert("ID", String(Filter.UUID));
				Filter.Delete("UUID");
			EndIf;
		EndIf;
		AddBackgroundJobProperties(BackgroundJobArray, Table);
	EndIf;
	
	If ValueIsFilled(Filter) AND Filter.Property("ScheduledJobID") Then
		ScheduledJobsForProcessing = New Array;
		If Filter.ScheduledJobID <> "" Then
			If ScheduledJob = Undefined Then
				ScheduledJob = ScheduledJobs.FindByUUID(
					New UUID(Filter.ScheduledJobID));
			EndIf;
			If ScheduledJob <> Undefined Then
				ScheduledJobsForProcessing.Add(ScheduledJob);
			EndIf;
		EndIf;
	Else
		ScheduledJobsForProcessing = ScheduledJobs.GetScheduledJobs();
	EndIf;
	
	Table.Sort("Begin Desc, End Desc");
	
	// Filtering background jobs.
	If ValueIsFilled(Filter) Then
		Start    = Undefined;
		End     = Undefined;
		State = Undefined;
		If Filter.Property("Begin") Then
			Start = ?(ValueIsFilled(Filter.Begin), Filter.Begin, Undefined);
			Filter.Delete("Begin");
		EndIf;
		If Filter.Property("End") Then
			End = ?(ValueIsFilled(Filter.End), Filter.End, Undefined);
			Filter.Delete("End");
		EndIf;
		If Filter.Property("State") Then
			If TypeOf(Filter.State) = Type("Array") Then
				State = Filter.State;
				Filter.Delete("State");
			EndIf;
		EndIf;
		
		If Filter.Count() <> 0 Then
			Rows = Table.FindRows(Filter);
		Else
			Rows = Table;
		EndIf;
		// Performing additional filter by period and state (if the filter is defined).
		ItemNumber = Rows.Count() - 1;
		While ItemNumber >= 0 Do
			If Start    <> Undefined AND Start > Rows[ItemNumber].Begin
				Or End     <> Undefined AND End  < ?(ValueIsFilled(Rows[ItemNumber].End), Rows[ItemNumber].End, CurrentSessionDate())
				Or State <> Undefined AND State.Find(Rows[ItemNumber].State) = Undefined Then
				Rows.Delete(ItemNumber);
			EndIf;
			ItemNumber = ItemNumber - 1;
		EndDo;
		// Deleting unnecessary rows from the table.
		If TypeOf(Rows) = Type("Array") Then
			RowNumber = Table.Count() - 1;
			While RowNumber >= 0 Do
				If Rows.Find(Table[RowNumber]) = Undefined Then
					Table.Delete(Table[RowNumber]);
				EndIf;
				RowNumber = RowNumber - 1;
			EndDo;
		EndIf;
	EndIf;
	
	Return Table;
	
EndFunction

// Returns BackgroundJob properties by the unique ID string.
//
// Parameters:
//  ID - String - BackgroundJob UUID.
//  PropertyNames - string, if filled, returns a structure with the specified properties.
// 
// Returns:
//  ValueTableRow, Structure - BackgroundJob properties.
//
Function GetBackgroundJobProperties(ID, PropertyNames = "") Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Filter = New Structure("ID", ID);
	BackgroundJobPropertyTable = BackgroundJobsProperties(Filter);
	
	If BackgroundJobPropertyTable.Count() > 0 Then
		If ValueIsFilled(PropertyNames) Then
			Result = New Structure(PropertyNames);
			FillPropertyValues(Result, BackgroundJobPropertyTable[0]);
		Else
			Result = BackgroundJobPropertyTable[0];
		EndIf;
	Else
		Result = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the properties of the last background job executed with the scheduled job, if there is one.
// The procedure works both in file mode and client/server mode.
//
// Parameters:
//  ScheduledJob - ScheduledJob, String - ScheduledJob UUID string.
//
// Returns:
//  ValueTableRow, Undefined.
//
Function GetLastBackgroundJobForScheduledJobExecutionProperties(ScheduledJob) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	ScheduledJobID = ?(TypeOf(ScheduledJob) = Type("ScheduledJob"), String(ScheduledJob.UUID), ScheduledJob);
	Filter = New Structure;
	Filter.Insert("ScheduledJobID", ScheduledJobID);
	Filter.Insert("GetLastScheduledJobBackgroundJob");
	BackgroundJobPropertyTable = BackgroundJobsProperties(Filter);
	BackgroundJobPropertyTable.Sort("End Asc");
	
	If BackgroundJobPropertyTable.Count() = 0 Then
		BackgroundJobProperties = Undefined;
	ElsIf NOT ValueIsFilled(BackgroundJobPropertyTable[0].End) Then
		BackgroundJobProperties = BackgroundJobPropertyTable[0];
	Else
		BackgroundJobProperties = BackgroundJobPropertyTable[BackgroundJobPropertyTable.Count()-1];
	EndIf;
	
	Return BackgroundJobProperties;
	
EndFunction

// Returns a multiline String containing Messages and ErrorDescription if the background job is 
// found by the ID and there are messages/errors.
//
// Parameters:
//  Job - String - a BackgroundJob UUID string.
//
// Returns:
//  String.
//
Function BackgroundJobMessagesAndErrorDescriptions(ID, BackgroundJobProperties = Undefined) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	If BackgroundJobProperties = Undefined Then
		BackgroundJobProperties = GetBackgroundJobProperties(ID);
	EndIf;
	
	Row = "";
	If BackgroundJobProperties <> Undefined Then
		For each Message In BackgroundJobProperties.UserMessages Do
			Row = Row + ?(Row = "",
			                    "",
			                    "
			                    |
			                    |") + Message.Text;
		EndDo;
		If ValueIsFilled(BackgroundJobProperties.ErrorInformationDetails) Then
			Row = Row + ?(Row = "",
			                    BackgroundJobProperties.ErrorInformationDetails,
			                    "
			                    |
			                    |" + BackgroundJobProperties.ErrorInformationDetails);
		EndIf;
	EndIf;
	
	Return Row;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure ChangeScheduledJobsUsageByFunctionalOptions(Source, Val Usage)
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	SourceType = TypeOf(Source);
	FOStorage = Metadata.FindByType(SourceType);
	FunctionalOption = Undefined;
	IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
	IsStandaloneWorkplace = Common.IsStandaloneWorkplace();
	
	DependentScheduledJobs = ScheduledJobsDependentOnFunctionalOptions();
	
	FOList = DependentScheduledJobs.Copy(,"FunctionalOption");
	FOList.GroupBy("FunctionalOption");
	
	For Each FOString In FOList Do
		
		If FOString.FunctionalOption = Undefined Then
			Continue;
		EndIf;
		
		If FOString.FunctionalOption.Location = FOStorage Then
			FunctionalOption = FOString.FunctionalOption;
			Break;
		EndIf;
		
	EndDo;
	
	If FunctionalOption = Undefined
		Or GetFunctionalOption(FunctionalOption.Name) = Usage Then
		Return;
	EndIf;
	
	Jobs = DependentScheduledJobs.Copy(New Structure("FunctionalOption", FunctionalOption) ,"ScheduledJob");
	Jobs.GroupBy("ScheduledJob");
	
	For Each RowJob In Jobs Do
		
		UsageByFO                = Undefined;
		DisableJob                 = True;
		DisableInSubordinateDIBNode     = False;
		DisableInStandaloneWorkplace = False;
		
		FoundRows = DependentScheduledJobs.FindRows(New Structure("ScheduledJob", RowJob.ScheduledJob));
		
		For Each DependencyString In FoundRows Do
			DisableInSubordinateDIBNode = (DependencyString.AvailableInSubordinateDIBNode = False) AND IsSubordinateDIBNode;
			DisableInStandaloneWorkplace = (DependencyString.AvailableAtStandaloneWorkstation = False) AND IsStandaloneWorkplace;
			If DisableInSubordinateDIBNode Or DisableInStandaloneWorkplace Then
				Break;
			EndIf;
			
			If DependencyString.FunctionalOption = Undefined Then
				Continue;
			EndIf;
			
			If DependencyString.FunctionalOption = FunctionalOption Then
				FOValue = Usage;
			Else
				FOValue = GetFunctionalOption(DependencyString.FunctionalOption.Name);
			EndIf;
			
			If DependencyString.EnableOnEnableFunctionalOption = False Then
				If DisableJob Then
					DisableJob = Not FOValue;
				EndIf;
				FOValue = False;
			EndIf;
			
			If UsageByFO = Undefined Then
				UsageByFO = FOValue;
			ElsIf DependencyString.DependenceByT Then
				UsageByFO = UsageByFO AND FOValue;
			Else
				UsageByFO = UsageByFO Or FOValue;
			EndIf;
		EndDo;
		
		If DisableInSubordinateDIBNode Or DisableInStandaloneWorkplace Then
			Usage = False;
		Else
			If Usage <> UsageByFO Then
				Continue;
			EndIf;
			
			If Not Usage AND Not DisableJob Then
				Continue;
			EndIf;
		EndIf;
		
		JobsList = ScheduledJobsServer.FindJobs(New Structure("Metadata", RowJob.ScheduledJob));
		For Each ScheduledJob In JobsList Do
			JobParameters = New Structure("Use", Usage);
			ScheduledJobsServer.ChangeJob(ScheduledJob, JobParameters);
		EndDo;
		
	EndDo;
	
EndProcedure

// Returns a new background job property table.
//
// Returns:
//  ValueTable.
//
Function NewBackgroundJobsProperties()
	
	NewTable = New ValueTable;
	NewTable.Columns.Add("ID",                     New TypeDescription("String"));
	NewTable.Columns.Add("Description",                      New TypeDescription("String"));
	NewTable.Columns.Add("Key",                              New TypeDescription("String"));
	NewTable.Columns.Add("Begin",                            New TypeDescription("Date"));
	NewTable.Columns.Add("End",                             New TypeDescription("Date"));
	NewTable.Columns.Add("ScheduledJobID", New TypeDescription("String"));
	NewTable.Columns.Add("State",                         New TypeDescription("BackgroundJobState"));
	NewTable.Columns.Add("MethodName",                         New TypeDescription("String"));
	NewTable.Columns.Add("Location",                      New TypeDescription("String"));
	NewTable.Columns.Add("ErrorInformationDetails",        New TypeDescription("String"));
	NewTable.Columns.Add("StartAttempt",                    New TypeDescription("Number"));
	NewTable.Columns.Add("UserMessages",             New TypeDescription("Array"));
	NewTable.Columns.Add("SessionNumber",                       New TypeDescription("Number"));
	NewTable.Columns.Add("SessionStarted",                      New TypeDescription("Date"));
	NewTable.Indexes.Add("ID, Begin");
	
	Return NewTable;
	
EndFunction

Procedure AddBackgroundJobProperties(Val BackgroundJobArray, Val BackgroundJobPropertyTable)
	
	Index = BackgroundJobArray.Count() - 1;
	While Index >= 0 Do
		BackgroundJob = BackgroundJobArray[Index];
		Row = BackgroundJobPropertyTable.Add();
		FillPropertyValues(Row, BackgroundJob);
		Row.ID = BackgroundJob.UUID;
		ScheduledJob = BackgroundJob.ScheduledJob;
		
		If ScheduledJob = Undefined
		   AND StringFunctionsClientServer.IsUUID(BackgroundJob.Key) Then
			
			ScheduledJob = ScheduledJobs.FindByUUID(New UUID(BackgroundJob.Key));
		EndIf;
		Row.ScheduledJobID = ?(
			ScheduledJob = Undefined,
			"",
			ScheduledJob.UUID);
		
		Row.ErrorInformationDetails = ?(
			BackgroundJob.ErrorInfo = Undefined,
			"",
			DetailErrorDescription(BackgroundJob.ErrorInfo));
		
		Index = Index - 1;
	EndDo;
	
EndProcedure

Function LastBackgroundJobInArray(BackgroundJobArray, LastBackgroundJob = Undefined)
	
	For each CurrentBackgroundJob In BackgroundJobArray Do
		If LastBackgroundJob = Undefined Then
			LastBackgroundJob = CurrentBackgroundJob;
			Continue;
		EndIf;
		If ValueIsFilled(LastBackgroundJob.End) Then
			If NOT ValueIsFilled(CurrentBackgroundJob.End)
			 OR LastBackgroundJob.End < CurrentBackgroundJob.End Then
				LastBackgroundJob = CurrentBackgroundJob;
			EndIf;
		Else
			If NOT ValueIsFilled(CurrentBackgroundJob.End)
			   AND LastBackgroundJob.Begin < CurrentBackgroundJob.Begin Then
				LastBackgroundJob = CurrentBackgroundJob;
			EndIf;
		EndIf;
	EndDo;
	
	Return LastBackgroundJob;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Lock of operations with external resources.

// Creates a file to control the file infobase movement.
//
Function FileInfobaseID(IsFileInfobase)
	
	InfobaseID = "";
	If IsFileInfobase Then
		InfobaseID = String(New UUID);
		FileContent = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1
		|
		|Файл создан автоматически прикладным решением ""%2"".
		|Он содержит идентификатор информационной базы и позволяет определить, что эта информационная база была скопирована.
		|
		|При копировании файлов информационной базы, в том числе при создании резервной копии, не следует копировать этот файл.
		|Одновременное использование двух копий информационной базы с одинаковым идентификатором может привести к конфликтам
		|при синхронизации данных, отправке почты и другой работе с внешними ресурсами.
		|
		|Если файл отсутствует в каталоге с информационной базой, то программа запросит администратора, должна ли эта
		|информационная база работать с внешними ресурсами.'; 
		|en = '%1
		|
		|File is automatically created by application ""%2"".
		|It contains ID of the infobase and helps identify that this infobase was copied.
		|
		|When copying files of the infobase and creating a backup, do not copy this file.
		|Using both copies of the infobase with the same ID can lead to conflicts
		|when synchronizing data, sending emails and other operations with the external resources.
		|
		|If the file is missing in the directory with the infobase, then the application will ask the administrator if this
		|infobase shall operate with external resources.'; 
		|pl = '%1
		|
		|Plik utworzony automatycznie stosowanym rozwiązaniem ""%2"".
		|Zawiera on identyfikator bazy informacyjnej i pozwala ustalić, że ta baza informacyjna została skopiowana.
		|
		|Podczas kopiowania plików bazy informacyjnej, w tym podczas tworzenia kopii zapasowej, nie należy kopiować ten plik.
		|Jednoczesne korzystanie z dwóch kopii bazy informacyjnej z tym samym identyfikatorem może prowadzić do konfliktów
		|podczas synchronizacji danych, wysyłania poczty e-mail i innej pracy z zewnętrznymi zasobami.
		|
		|Jeśli plik nie istnieje w katalogu z bazy informacyjnej, program zapyta administratora, czy ta
		|informacyjna baza powinna pracować z zewnętrznymi zasobami.';
		|es_ES = '%1
		|
		|El archivo se ha creado automáticamente con la solución aplicada ""%2"".
		|Contiene el identificador de la base de información y permite comprender que esta base de información ha sido copiada.
		|
		|Al copiar los archivos de la base de información incluso al crear la copia de reserva no hay que copiar este archivo.
		|El uso simultáneo de dos copias de la base de información con el mismo identificador puede llevar a los conflictos
		| al sincronizar los datos, al enviar el correo y al usar otros recursos externos.
		|
		|Si no hay archivo en el catálogo de la base de información, el programa preguntará al administrador si esta
		|base de información debe usar los recursos externos.';
		|es_CO = '%1
		|
		|El archivo se ha creado automáticamente con la solución aplicada ""%2"".
		|Contiene el identificador de la base de información y permite comprender que esta base de información ha sido copiada.
		|
		|Al copiar los archivos de la base de información incluso al crear la copia de reserva no hay que copiar este archivo.
		|El uso simultáneo de dos copias de la base de información con el mismo identificador puede llevar a los conflictos
		| al sincronizar los datos, al enviar el correo y al usar otros recursos externos.
		|
		|Si no hay archivo en el catálogo de la base de información, el programa preguntará al administrador si esta
		|base de información debe usar los recursos externos.';
		|tr = '%1
		|
		|Dosya otomatik olarak uygulama çözümü ""%2"" tarafından oluşturulur. 
		|Bir veritabanı kimliği içerir ve bu veri tabanının kopyalandığını belirlemenizi sağlar. 
		|
		|Bir yedek oluştururken de dahil olmak üzere veritabanın dosyalarını kopyalarken, bu dosyayı kopyalamayın.
		| Aynı kimliğe sahip bir veri tabanının iki kopyasını eş zamanlı olarak kullanmak, veri senkronizasyonu, posta gönderme ve diğer dış kaynaklarla 
		|çakışmalara neden olabilir. 
		|
		|Dosya bilgi tabanı ile dizinde yoksa, program bu 
		|veritabanı dış kaynaklarla çalışıp çalışmadığını yöneticiye sorar.';
		|it = '%1
		|
		|Il file è creato automaticamente dall''applicazione ""%2"".
		|Contiene l''ID dell''infobase e consente di determinare che infobase è stato copiato.
		|
		|Non copiare questo file quando si compiano i file dell''infobase e si creano i backup.
		|L''utilizzo di due infobase con lo stesso ID può portare a conflitti
		|durante la sincronizzazione dei dati, invio delle email o altre operazioni con le risorse esterne.
		|
		|Se il file manca nella directory con l''infobase, allora l''applicazione chiederà all''amministratore se questo
		|infobase deve operare con risorse esterne.';
		|de = '%1
		|
		|Die Datei wird von der Anwendungslösung ""%2"" automatisch erstellt.
		|Sie enthält die Kennung der Informationsbasis und ermöglicht es Ihnen, festzustellen, ob diese Informationsbasis kopiert wurde.
		|
		|Beim Kopieren der Datenbankdateien, auch beim Erstellen einer Sicherung, sollten Sie diese Datei nicht kopieren.
		|Die gleichzeitige Verwendung von zwei Kopien der Datenbank mit der gleichen Kennung kann zu Konflikten
		|bei der Datensynchronisation, dem Versenden von E-Mails und anderen Arbeiten mit externen Ressourcen führen.
		|
		|Wenn sich die Datei nicht im Verzeichnis mit der Informationsbasis befindet, fragt das Programm den Administrator, ob
		|die Informationsbasis mit externen Ressourcen arbeiten soll.'"), InfobaseID, Metadata.Synonym);
		FileName = CommonClientServer.FileInfobaseDirectory() + "\DoNotCopy.txt";
		TextWriter = New TextWriter(FileName);
		Try
			TextWriter.Write(FileContent);
		Except
			TextWriter.Close();
			Raise;
		EndTry;
		TextWriter.Close();
	EndIf;
	
	Return InfobaseID;
	
EndFunction

// Sets the flag that shows whether it is necessary to lock operations with external resources.
//
Procedure SetFlagShowsNecessityOfLock(LockParameters, MessageText)
	
	LockParameters.OperationsWithExternalResourcesLocked = Undefined;
	ValueStorage = New ValueStorage(LockParameters);
	Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
	
	If Common.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleNetworkDownloadClientServer = Common.CommonModule("ConversationsServiceServerCall");
		ModuleNetworkDownloadClientServer.Lock();
	EndIf;
	
	WriteLogEvent(NStr("ru = 'Работа с внешними ресурсами заблокирована'; en = 'Operations with external resources have been locked'; pl = 'Praca z zasobami zewnętrznymi jest zablokowana';es_ES = 'El uso de los recursos externos ha sido bloqueado';es_CO = 'El uso de los recursos externos ha sido bloqueado';tr = 'Dış kaynaklarla çalışma kilitlendi';it = 'Le operazioni con risorse esterno sono state bloccate';de = 'Die Arbeit mit externen Ressourcen ist gesperrt.'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Warning, , , MessageText);
	
EndProcedure

// Initializes the OperationsWithExternalResourcesLockParameters constant.
//
Procedure InitializeOperationsWithExternalResourcesLockParameters(OperationsWithExternalResourcesLocked = False)
	
	LockParameters = ExternalResourceAccessLockParameters(OperationsWithExternalResourcesLocked, True);
	ValueStorage = New ValueStorage(LockParameters);
	Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
	
EndProcedure

Procedure UpdateExternalResourceAccessLockParameters() Export
	
	LockParameters = Constants.ExternalResourceAccessLockParameters.Get().Get();
	
	If LockParameters = Undefined Then
		InitializeOperationsWithExternalResourcesLockParameters();
	Else
		DataSeparationEnabled = Common.DataSeparationEnabled();
		LockParameters.Insert("DataSeparationEnabled", DataSeparationEnabled);
		If DataSeparationEnabled Then
			LockParameters.Insert("ConnectionString", "");
			LockParameters.Insert("ComputerName", "");
		EndIf;
		ValueStorage = New ValueStorage(LockParameters);
		Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
	EndIf;
	
EndProcedure

Function ExternalResourceAccessLockParameters(OperationsWithExternalResourcesLocked = False,
	InitializeLockParameters = False) Export
	
	ConnectionString = InfoBaseConnectionString();
	IsFileInfobase = Common.FileInfobase(ConnectionString);
	DataSeparationEnabled = Common.DataSeparationEnabled();
	InfobaseID = ?(InitializeLockParameters, FileInfobaseID(IsFileInfobase), "");
	
	LockParameters = New Structure;
	LockParameters.Insert("DataSeparationEnabled", DataSeparationEnabled);
	LockParameters.Insert("OperationsWithExternalResourcesLocked", OperationsWithExternalResourcesLocked);
	LockParameters.Insert("DisabledJobs", New Array);
	LockParameters.Insert("IsFileInfobase", IsFileInfobase);
	LockParameters.Insert("ConnectionString", ?(DataSeparationEnabled, "", ConnectionString));
	LockParameters.Insert("ComputerName", ?(DataSeparationEnabled, "", ComputerName()));
	LockParameters.Insert("CheckServerName", True);
	LockParameters.Insert("InfobaseID", InfobaseID);
	
	Return LockParameters;
	
EndFunction

#EndRegion
