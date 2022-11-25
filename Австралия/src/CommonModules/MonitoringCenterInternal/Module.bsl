#Region Internal

Function GetScheduledJobExternalCall(ScheduledJobName, CreateNew2 = True) Export
	Return GetScheduledJob(ScheduledJobName, CreateNew2);
EndFunction

Procedure SetDefaultScheduleExternalCall(Job) Export
	SetDefaultSchedule(Job);
EndProcedure

Procedure DeleteScheduledJobExternalCall(ScheduledJobName) Export
	DeleteScheduledJob(ScheduledJobName);
EndProcedure

Function SetMonitoringCenterParameterExternalCall(Parameter, Value) Export
	Return SetMonitoringCenterParameter(Parameter, Value);	
EndFunction

Function GetDefaultParametersExternalCall() Export
	Return GetDefaultParameters();
EndFunction

Function GetMonitoringCenterParametersExternalCall(Parameters = Undefined) Export
	Return GetMonitoringCenterParameters(Parameters);
EndFunction

Function SetMonitoringCenterParametersExternalCall(NewParameters) Export
	SetMonitoringCenterParameters(NewParameters);
EndFunction

Function StartDiscoveryPackageSending() Export
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ProcedureParameters = New Structure("Iterator, TestPackageSending, GetID", 0, False, True);
	RunResult = TimeConsumingOperations.ExecuteInBackground("MonitoringCenterInternal.SendTestPackage", ProcedureParameters, ExecutionParameters);
	Return RunResult;
EndFunction

Procedure OnDefineScheduledJobSettings(Dependencies) Export
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.StatisticsDataCollectionAndSending;
	Dependence.UseExternalResources = True;
	
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.ErrorReportCollectionAndSending;
	Dependence.UseExternalResources = True;
EndProcedure

Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "MonitoringCenterInternal.InitialFilling";
	
	Handler = Handlers.Add();
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	Handler.Version = "3.0.1.331";
	Handler.Procedure = "MonitoringCenterInternal.AddInfobaseIDPermanent";
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion() And Not SeparationByDataAreasEnabled() Then
		Handler = Handlers.Add();
		Handler.ExecutionMode = "Deferred";
		Handler.Version          = "2.4.4.79";
		Handler.Comment     = NStr("en = 'Enables the option of sending information about using the application to 1С International company. You can disable this option in Settings/Online user support and services/Monitoring center'; ru = 'Включает отправку сведений об использовании программы в компанию ""1С International"". Отключить отправку сведений можно в разделе Администрирование / Интернет-поддержка и сервисы / Центр мониторинга';pl = 'Włącza opcje wysyłania informacji dotyczących użycia aplikacji do 1C International company. Możesz wyłączyć tę opcję w Ustawienia/Pomoc online i usługi/Centrum monitorowania';es_ES = 'Activa la opción de enviar información sobre el uso de la aplicación a 1С International Company. Puede desactivar esta opción en Ajustes/Soporte y servicios al usuario en línea/Centro de control';es_CO = 'Activa la opción de enviar información sobre el uso de la aplicación a 1С International Company. Puede desactivar esta opción en Ajustes/Soporte y servicios al usuario en línea/Centro de control';tr = 'Uygulamayı kullanarak 1C International şirketine bilgi gönderme seçeneğini etkinleştirir. Ayarlar/Çevrimiçi kullanıcı desteği ve servisler/İzleme merkezi''nde bu seçeneği devre dışı bırakabilirsiniz';it = 'Attiva l''opzione di invio informazioni sull''utilizzo dell''applicazione a 1C International. È possibile disattivare questa opzione in Opzioni/Supporto e servizi utente online/Centro di monitoraggio';de = 'Aktiviert Option für Senden von Informationen über die Anwendung an 1C International company. Sie können diese Option in Einstellungen/Unterstützung von Benutzern und Services Online/Überwachungszentrum deaktivieren'");
		Handler.ID   = New UUID("68c8c60c-5b23-436a-9555-a6f24a6b1ffd");
		Handler.Procedure       = "MonitoringCenterInternal.EnableSendingInfo";
		Handler.DeferredProcessingQueue          = 1;
		Handler.UpdateDataFillingProcedure = "MonitoringCenterInternal.EnableSendingInfoFilling";
		Handler.ObjectsToRead                     = "Constant.MonitoringCenterParameters";
		Handler.ObjectsToChange                   = "Constant.MonitoringCenterParameters, ScheduledJob.StatisticsDataCollectionAndSending";
	EndIf;
	
EndProcedure

Procedure OnAddClientParametersOnStart(Parameters) Export
	
	ClientRunParameters = New Structure("SessionTimeZone, UserHash, RegisterBusinessStatistics,
											|PromptForFullDump, PromptForFullDumpDisplayed, DumpsInformation,
											|RequestForGettingDumps,SendingRequest,RequestForGettingContacts,
											|RequestForGettingContactsDisplayed");
	
	UserUUID = String(InfoBaseUsers.CurrentUser().UUID);
	SessionNumber = Format(InfoBaseSessionNumber(), "NG=0");
	UserHash = Common.CheckSumString(UserUUID + SessionNumber);
	
	RegisterBusinessStatistics = GetMonitoringCenterParameters("RegisterBusinessStatistics");
	RequestForGettingContacts = GetMonitoringCenterParameters("ContactInformationRequest") = 3;
	NotificationOfDumpsParameters = NotificationOfDumpsParameters();
	
	IsFullUser = Users.IsFullUser(, True);
	
	MonitoringCenterSettings = New Structure;
	MonitoringCenterSettings.Insert("EnableNotifications", True);
	MonitoringCenterOverridable.OnDefineSettings(MonitoringCenterSettings);
	
	ClientRunParameters.PromptForFullDump = IsFullUser And MonitoringCenterSettings.EnableNotifications;	
	ClientRunParameters.PromptForFullDumpDisplayed = False;
	ClientRunParameters.RequestForGettingDumps = NotificationOfDumpsParameters.RequestForGettingDumps;
	ClientRunParameters.SendingRequest = NotificationOfDumpsParameters.SendingRequest;
	ClientRunParameters.DumpsInformation = NotificationOfDumpsParameters.DumpsInformation;
	ClientRunParameters.SessionTimeZone = SessionTimeZone();
	ClientRunParameters.UserHash = UserHash;
	ClientRunParameters.RegisterBusinessStatistics = RegisterBusinessStatistics;
	ClientRunParameters.RequestForGettingContacts = RequestForGettingContacts;
	ClientRunParameters.RequestForGettingContactsDisplayed = False;
		
	Parameters.Insert("MonitoringCenter", New FixedStructure(ClientRunParameters));
	
	WriteUserActivity(UserHash);
	
EndProcedure

Procedure OnExecuteStandardDinamicChecksAtServer(Parameters) Export
	
	If Parameters["ClientInformation"]["ClientParameters1"]["RegisterBusinessStatistics"] Then
	
		RegisterBusinessStatistics = GetMonitoringCenterParameters("RegisterBusinessStatistics");
			
		ParametersNew = New Map(Parameters);
		ParametersNew.Insert("RegisterBusinessStatistics", RegisterBusinessStatistics);
		
		BackgroundJobKey = "OnExecuteStandardDinamicChecksAtServerInBackground" + Parameters["ClientInformation"]["ClientParameters1"]["UserHash"];
		
		Filter = New Structure;
		Filter.Insert("Key", BackgroundJobKey);
		Filter.Insert("State", BackgroundJobState.Active);
		ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
		
		If ActiveBackgroundJobs.Count() = 0 Then
			
			BackgroundJobParameters = New Array;
			BackgroundJobParameters.Add(Parameters);
			BackgroundJobs.Execute("MonitoringCenterInternal.OnExecuteStandardDinamicChecksAtServerInBackground",
				BackgroundJobParameters,
				BackgroundJobKey,
				"MonitoringCenterInternal.OnExecuteStandardDinamicChecksAtServer");
		EndIf;
		
		Parameters = New FixedMap(ParametersNew);
		
	EndIf;
	
	If Parameters["ClientInformation"]["ClientParameters1"]["PromptForFullDump"] Then
		
		NotificationOfDumpsParameters = NotificationOfDumpsParameters();
		
		RequestForGettingDumps = NotificationOfDumpsParameters.RequestForGettingDumps
								And Not Parameters.Get("PromptForFullDumpDisplayed") = True;
		RequestForGettingContacts = GetMonitoringCenterParameters("ContactInformationRequest") = 3
								And Not Parameters.Get("RequestForGettingContactsDisplayed") = True;
		
		ParametersNew = New Map(Parameters);
		ParametersNew.Insert("RequestForGettingDumps", RequestForGettingDumps);
		ParametersNew.Insert("DumpsSendingRequest", NotificationOfDumpsParameters.SendingRequest);
		ParametersNew.Insert("DumpsInformation", NotificationOfDumpsParameters.DumpsInformation);
		ParametersNew.Insert("RequestForGettingContacts", RequestForGettingContacts);
		Parameters = New FixedMap(ParametersNew);
		
	EndIf;
	
	MonitoringCenterParameters = New Structure("TestPackageSent,ApplicationInformationProcessingCenter,EnableMonitoringCenter");
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If Not MonitoringCenterParameters.TestPackageSent And Not SeparationByDataAreasEnabled() Then
		
		If MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("TestPackageSent", True);
			SetPrivilegedMode(False);
		Else
			BackgroundJobKey = "TestPackageSending";
			
			Filter = New Structure;
			Filter.Insert("Key", BackgroundJobKey);
			Filter.Insert("State", BackgroundJobState.Active);
			ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
			If ActiveBackgroundJobs.Count() = 0 Then                                                                      
				ProcedureParameters = New Structure("Iterator, TestPackageSending, GetID", 0, True, False);
				ParametersArray = New Array;
				ParametersArray.Add(ProcedureParameters);
				ParametersArray.Add(Undefined);				
				BackgroundJobs.Execute("MonitoringCenterInternal.SendTestPackage",
					ParametersArray,
					BackgroundJobKey,
					NStr("ru = 'Центр мониторинга: отправка тестового пакета';
						|en = 'Monitoring center: send test package';pl = 'Centrum monitorowania: wysyłanie pakietu testowego';es_ES = 'Centro de control: enviar el paquete de prueba';es_CO = 'Centro de control: enviar el paquete de prueba';tr = 'İzleme merkezi: test paketi gönder';it = 'Centro di monitoraggio: inviare pacchetto di prova';de = 'Überwachungszentrum: Testpaket senden'"));
			EndIf;
		EndIf;
	EndIf;
	
	If Common.FileInfobase() Then
		MonitoringCenterParameters = New Structure("SendDumpsFiles,DumpOption,DumpCollectingEnd,FullDumpsCollectionEnabled");
		MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
			
		StartErrorReportsCollectionAndSending = Not MonitoringCenterParameters.SendDumpsFiles = 0
												And Not IsBlankString(MonitoringCenterParameters.DumpOption)
												And CurrentUniversalDate() < MonitoringCenterParameters.DumpCollectingEnd;
												
		If StartErrorReportsCollectionAndSending Then
			ID = Parameters["ClientInformation"]["ClientParameters1"]["UserHash"];
			BackgroundJobKey = "CollectAndSendServerErrorReportsInBackground" + ID;
			
			Filter = New Structure;
			Filter.Insert("Key", BackgroundJobKey);
			Filter.Insert("State", BackgroundJobState.Active);
			ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
			
			If ActiveBackgroundJobs.Count() = 0 Then
				BackgroundJobParameters = New Array;
				BackgroundJobParameters.Add(True);
				BackgroundJobParameters.Add(ID);
				BackgroundJobs.Execute("MonitoringCenterInternal.CollectAndSendDumps",
					BackgroundJobParameters,
					BackgroundJobKey,
					NStr("ru = 'Сбор и отправка отчетов об ошибках';
						|en = 'Collect and send error reports';pl = 'Zbieraj i wysyłaj raporty o błądach';es_ES = 'Recoger y enviar informes de errores';es_CO = 'Recoger y enviar informes de errores';tr = 'Hata raporlarını topla ve gönder';it = 'Raccogliere e inviare report di errore';de = 'Fehlerberichte sammeln und senden'"));
				EndIf;
		Else
			If MonitoringCenterParameters.FullDumpsCollectionEnabled[ComputerName()] = True Then
				StopFullDumpsCollection();
			EndIf;
		EndIf;	
	EndIf;
		
EndProcedure

Procedure OnExecuteStandardDinamicChecksAtServerInBackground(Parameters) Export
	
	WriteClientScreensStatistics(Parameters);
	WriteSystemInformation(Parameters);
	WriteClientInformation(Parameters);
	WriteDataFromClient(Parameters);
	
EndProcedure

Procedure OnFillToDoList(ToDoList) Export
	
	If Not Users.IsFullUser(, True) Then
		Return;
	EndIf;
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	
	Sections = ModuleToDoListServer.SectionsForObject("DataProcessor.MonitoringCenterSettings");
	If Sections.Count() = 0 Then
		AdministrationSection = Metadata.Subsystems.Find("Administration");
		If AdministrationSection = Undefined Then
			Return;
		EndIf;
		Sections.Add(AdministrationSection);
	EndIf;
	
	RequestForGettingDumps = MonitoringCenterParameters.SendDumpsFiles = 2 And MonitoringCenterParameters.BasicChecksPassed;
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = "RequestForGettingDumps";
		ToDoItem.HasUserTasks       = RequestForGettingDumps;
		ToDoItem.Important         = True;
		ToDoItem.HideInSettings = True;
		ToDoItem.Owner       = Section;
		ToDoItem.Presentation  = NStr("ru = 'Предоставить отчеты об ошибках';
									|en = 'Provide error reports';pl = 'Prześlij raporty o błędach';es_ES = 'Proporcionar informes de errores';es_CO = 'Proporcionar informes de errores';tr = 'Hata raporları sağla';it = 'Fornire report di errore';de = 'Fehlerberichte bieten'");
		ToDoItem.Count     = 0;
		ToDoItem.ToolTip      = NStr("ru = 'Зарегистрированы аварийные завершения работы программы. Пожалуйста, расскажите нам об этой проблеме.';
									|en = 'Abnormal application terminations were registered. Please contact us on this issue.';pl = 'Dane o nieprawidłowych zakończeniach aplikacji zostały zarejestrowane. Powiadom nas o tej problemie.';es_ES = 'Se han registrado terminaciones anormales de la aplicación. Por favor, póngase en contacto con nosotros sobre esta cuestión.';es_CO = 'Se han registrado terminaciones anormales de la aplicación. Por favor, póngase en contacto con nosotros sobre esta cuestión.';tr = 'Anormal uygulama sonlandırmaları kaydedildi. Lütfen, bu konuda bizimle iletişime geçin.';it = 'Sono state registrate conclusioni non standard dell''applicazione. Contattaci per questo problema.';de = 'Abnormale Beendungen der Anwendung wurden registriert. Bitte kontaktieren Sie uns diesbezüglich.'");
		ToDoItem.FormParameters = New Structure("Variant", "Query");
		ToDoItem.Form          = "DataProcessor.MonitoringCenterSettings.Form.RequestForErrorReportsCollectionAndSending";
	EndDo;

	HasDumps = MonitoringCenterParameters.Property("DumpInstances") And MonitoringCenterParameters.DumpInstances.Count();
	SendingRequest = MonitoringCenterParameters.SendDumpsFiles = 1
						And Not IsBlankString(MonitoringCenterParameters.DumpOption)
						And HasDumps
						And MonitoringCenterParameters.RequestConfirmationBeforeSending
						And MonitoringCenterParameters.DumpType = "3"
						And Not IsBlankString(MonitoringCenterParameters.DumpsInformation)
						And MonitoringCenterParameters.BasicChecksPassed;
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = "DumpsSendingRequest";
		ToDoItem.HasUserTasks       = SendingRequest;
		ToDoItem.Important         = False;
		ToDoItem.Owner       = Section;
		ToDoItem.Presentation  = NStr("ru = 'Отправить отчеты об ошибках';
									|en = 'Send error reports';pl = 'Wyślij raporty o błędach';es_ES = 'Enviar informe de errores';es_CO = 'Enviar informe de errores';tr = 'Hata raporları gönder';it = 'Inviare report di errore';de = 'Fehlerberichte senden'");
		ToDoItem.Count     = 0;
		ToDoItem.ToolTip      = NStr("ru = 'Отчеты об аварийном завершении собраны и подготовлены. Пожалуйста, согласуйте их отправку.';
									|en = 'Crash reports are collected and prepared. Please approve reports submission.';pl = 'Raporty o awaryjnych zakończeniach zostały zebrane i przygotowane. Zatwierdź przesyłanie raportów.';es_ES = 'Se recogen y preparan los informes de colisión. Por favor, apruebe la presentación de los informes.';es_CO = 'Se recogen y preparan los informes de colisión. Por favor, apruebe la presentación de los informes.';tr = 'Kilitlenme raporları toplandı ve hazırlandı. Lütfen, rapor gönderimini onaylayın.';it = 'I report sugli arresti anomali sono raccolti e preparati. Approvare la trasmissione dei report.';de = 'Absturzberichte sind gesammelt und vorbereitet. Bitte genehmigen Sie Einreichen von Berichten.'");
		ToDoItem.FormParameters = New Structure;
		ToDoItem.Form          = "DataProcessor.MonitoringCenterSettings.Form.RequestForSendingErrorReports";
	EndDo;
	
	HasContactInformationRequest = MonitoringCenterParameters.ContactInformationRequest = 3;
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = "ContactInformationRequest";
		ToDoItem.HasUserTasks       = HasContactInformationRequest;
		ToDoItem.Important         = True;
		ToDoItem.Owner       = Section;
		ToDoItem.Presentation  = NStr("ru = 'Сообщить о проблемах производительности';
									|en = 'Inform of performance issues';pl = 'Zgłoś problemy z wydajnością';es_ES = 'Informar de los problemas de eficiencia';es_CO = 'Informar de los problemas de eficiencia';tr = 'Performans sorunlarını bildir';it = 'Informazioni su problemi di prestazione';de = 'Leistungsprobleme melden'");
		ToDoItem.Count     = 0;
		ToDoItem.ToolTip      = NStr("ru = 'Обнаружены проблемы производительности. Пожалуйста, расскажите нам об этих проблемах.';
									|en = 'Performance issues are detected. Contact us on this issue.';pl = 'Wykryto problemy z wydajnością. Powiadom nas o tej problemie.';es_ES = 'Se detectan problemas de rendimiento. Póngase en contacto con nosotros sobre este tema.';es_CO = 'Se detectan problemas de rendimiento. Póngase en contacto con nosotros sobre este tema.';tr = 'Performans sorunları tespit edildi. Bu konuyla ilgili olarak bizimle iletişime geçin.';it = 'Rilevati problemi di prestazione. Contattaci per questo problema.';de = 'Leistungsprobleme sind aufgefunden. Bitte kontaktieren Sie uns diesbezüglich.'");
		ToDoItem.FormParameters = New Structure("OnRequest", True);
		ToDoItem.Form          = "DataProcessor.MonitoringCenterSettings.Form.SendContactInformation";
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

#Region WorkWithScheduledJobs

Function GetScheduledJob(ScheduledJobName, CreateNew2 = True)
	Result = Undefined;
	
	SetPrivilegedMode(True);
	Jobs = ScheduledJobs.GetScheduledJobs(New Structure("Metadata", ScheduledJobName));
	If Jobs.Count() = 0 Then
		If CreateNew2 Then
			Job = ScheduledJobs.CreateScheduledJob(Metadata["ScheduledJobs"][ScheduledJobName]);
			Job.Use = True;
			Job.Write();
			Result = Job;
		EndIf;
	Else
		Result = Jobs[0];
	EndIf;
	
	Return Result;
EndFunction

Procedure SetDefaultSchedule(Job)
	Job.Schedule.DaysRepeatPeriod = 1;
	Job.Schedule.RepeatPeriodInDay = 60*59*12;
	Job.Write();
EndProcedure

Procedure DeleteScheduledJob(ScheduledJobName)
	ScheduledJob = GetScheduledJob(ScheduledJobName, False);
	If ScheduledJob <> Undefined Then
		ScheduledJob.Delete();
	EndIf;
EndProcedure

Procedure MonitoringCenterScheduledJob() Export
	
	SetPrivilegedMode(True);
	LaunchParameterStr = SessionParameters.ClientParametersAtServer.Get("LaunchParameter"); 
	SetPrivilegedMode(False);
	
	If StrFind(LaunchParameterStr, "WithoutSendingStatistics") > 0 Then
		Return;
	EndIf;
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.StatisticsDataCollectionAndSending);
	
	PerformanceMonitorRecordRequired = False;
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	StartDate = CurrentUniversalDate();
	MonitoringCenterParameters = New Structure();
	
	MonitoringCenterParameters.Insert("EnableMonitoringCenter");
	MonitoringCenterParameters.Insert("ApplicationInformationProcessingCenter");
	MonitoringCenterParameters.Insert("RegisterDumps");
	MonitoringCenterParameters.Insert("DumpRegistrationNextCreation");
	MonitoringCenterParameters.Insert("DumpRegistrationCreationPeriod");
	
	MonitoringCenterParameters.Insert("RegisterBusinessStatistics");
	MonitoringCenterParameters.Insert("BusinessStatisticsNextSnapshot");
	MonitoringCenterParameters.Insert("BusinessStatisticsSnapshotPeriod");
	
	MonitoringCenterParameters.Insert("RegisterConfigurationStatistics");
	MonitoringCenterParameters.Insert("RegisterConfigurationSettings");
	MonitoringCenterParameters.Insert("ConfigurationStatisticsNextGeneration");
	MonitoringCenterParameters.Insert("ConfigurationStatisticsGenerationPeriod");
	
	MonitoringCenterParameters.Insert("RegisterEventLogErrors");
	MonitoringCenterParameters.Insert("EventLogErrorsNextGeneration");
	MonitoringCenterParameters.Insert("EventLogErrorsGenerationPeriod");
	MonitoringCenterParameters.Insert("EventLogErrorsCount");
	MonitoringCenterParameters.Insert("EventLogErrorsEvents");
	
	MonitoringCenterParameters.Insert("SendDataNextGeneration");
	MonitoringCenterParameters.Insert("SendDataGenerationPeriod");
	MonitoringCenterParameters.Insert("NotificationDate2");
	MonitoringCenterParameters.Insert("ForceSendMinidumps");
	MonitoringCenterParameters.Insert("UserResponseTimeout");
	MonitoringCenterParameters.Insert("DiscoveryPackageSent");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If MonitoringCenterParameters.EnableMonitoringCenter And Not MonitoringCenterParameters.DiscoveryPackageSent Then
		ProcedureParameters = New Structure("Iterator, TestPackageSending, GetID", 0, False, True);
		SendTestPackage(ProcedureParameters, New UUID);
		Return;
	EndIf;
		
	If (MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter) And IsMasterNode() Then
		If MonitoringCenterParameters.RegisterDumps And StartDate >= MonitoringCenterParameters.DumpRegistrationNextCreation Then
			Try
				DumpsRegistration();
			Except
				Comment = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(
					NStr("ru = 'Центр мониторинга - регистрация дампов';
						|en = 'Monitoring center - dump registration';pl = 'Centrum monitorowania - rejestracja zrzutu';es_ES = 'Centro de control - registro de volcado';es_CO = 'Centro de control - registro de volcado';tr = 'İzleme merkezi - döküm kaydı';it = 'Centro di monitoraggio - registrazione dump';de = 'Überwachungszentrum - Dump-Registrieren'",
					CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					Comment);
				SetMonitoringCenterParameter("RegisterDumps", False);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.DumpsRegistration.Error", 1, Comment);
			EndTry;
			
			MonitoringCenterParameters.DumpRegistrationNextCreation =
			CurrentUniversalDate()
			+ MonitoringCenterParameters.DumpRegistrationCreationPeriod;
			
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If MonitoringCenterParameters.RegisterBusinessStatistics And StartDate >= MonitoringCenterParameters.BusinessStatisticsNextSnapshot Then
			Try
				StatisticsOperationsRegistration();
			Except
				Comment = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(
					NStr("ru = 'Центр мониторинга - регистрация операций статистики';
						|en = 'Monitoring center - register statistics operations';pl = 'Centrum monitorowania - rejestracja operacji statystyk';es_ES = 'Centro de control - registro de operaciones estadísticas';es_CO = 'Centro de control - registro de operaciones estadísticas';tr = 'İzleme merkezi - istatistik işlemlerini kaydet';it = 'Centro di monitoraggio - registrare operazioni statistiche';de = 'Überwachungszentrum - Operationen der Statistik registrieren'",
					CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.StatisticsOperationsRegistration.Error", 1, Comment);
			EndTry;
						
			MonitoringCenterParameters.BusinessStatisticsNextSnapshot = CurrentUniversalDate()
				+ MonitoringCenterParameters.BusinessStatisticsSnapshotPeriod;
			
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If (MonitoringCenterParameters.RegisterConfigurationStatistics Or MonitoringCenterParameters.RegisterConfigurationSettings) And StartDate >= MonitoringCenterParameters.ConfigurationStatisticsNextGeneration Then
			Try
				CollectConfigurationStatistics(New Structure("RegisterConfigurationStatistics, RegisterConfigurationSettings", MonitoringCenterParameters.RegisterConfigurationStatistics, MonitoringCenterParameters.RegisterConfigurationSettings));
			Except
				Comment = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(
					NStr("ru = 'Центр мониторинга - собрать статистику конфигурации';
						|en = 'Monitoring center - obtain configuration statistics';pl = 'Centrum monitorowania - zbieraj statystyki konfiguracji';es_ES = 'Centro de control - obtener estadísticas de configuración';es_CO = 'Centro de control - obtener estadísticas de configuración';tr = 'İzleme merkezi - yapılandırma istatistiklerini al';it = 'Centro di monitoraggio - ottenere configurazioni statistiche';de = 'Überwachungszentrum - Konfigurationsstatistik erhalten'",
					CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.CollectConfigurationStatistics.Error", 1, Comment);
			EndTry;
				
			MonitoringCenterParameters.ConfigurationStatisticsNextGeneration = CurrentUniversalDate()
				+ MonitoringCenterParameters.ConfigurationStatisticsGenerationPeriod;
			
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If MonitoringCenterParameters.RegisterEventLogErrors And StartDate >= MonitoringCenterParameters.EventLogErrorsNextGeneration Then
			Try
				CollectEventLogErrors(MonitoringCenterParameters);
			Except
				Comment = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(
					NStr("ru = 'Центр мониторинга - собрать ошибки из журнала регистрации';
						|en = 'Monitoring center - obtain errors from the Event log';pl = 'Centrum monitorowania - zbieraj błędy z dziennika rejestracji';es_ES = 'Centro de control - obtener errores del registro de eventos';es_CO = 'Centro de control - obtener errores del registro de eventos';tr = 'İzleme merkezi - Olay günlüğünden hataları al';it = 'Centro di monitoraggio - ottenere errori dal Registro degli eventi';de = 'Überwachungszentrum - Fehler aus dem Ereignisprotokoll erhalten'",
					CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.CollectEventLogErrors.Error", 1, Comment);
			EndTry;
				
			MonitoringCenterParameters.EventLogErrorsNextGeneration = CurrentUniversalDate()
				+ MonitoringCenterParameters.EventLogErrorsGenerationPeriod;
			
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If StartDate >= MonitoringCenterParameters.SendDataNextGeneration Then
			Try
				CreatePackageToSend();
			Except
				Comment = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(
					NStr("ru = 'Центр мониторинга - сформировать пакет для отправки';
						|en = 'Monitoring center - generate a package for sending';pl = 'Centrum monitorowania - wygeneruj pakiet do wysyłki';es_ES = 'Centro de control - generar un paquete para enviar';es_CO = 'Centro de control - generar un paquete para enviar';tr = 'İzleme merkezi - gönderim için paket oluştur';it = 'Centro di monitoraggio - creare un pacchetto per l''invio';de = 'Überwachungszentrum - Paket zum Senden generieren'",
					CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.CreatePackageToSend.Error", 1, Comment);
			EndTry;
			
			Try
				HTTPResponse = SendMonitoringData();
				If HTTPResponse.StatusCode = 200 Then
					// All Ok
				EndIf;
			Except
				Comment = DetailErrorDescription(ErrorInfo());
				WriteLogEvent(
					NStr("ru = 'Центр мониторинга - отправить данные мониторинга';
						|en = 'Monitoring center - send monitoring data';pl = 'Centrum monitorowania - wyślij dane o monitorowaniu';es_ES = 'Centro de control - envío de datos de control';es_CO = 'Centro de control - envío de datos de control';tr = 'İzleme merkezi - izleme verilerini gönder';it = 'Centro di monitoraggio - inviare dati di monitoraggio';de = 'Überwachungszentrum - Überwachungsdaten senden'",
					CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.SendMonitoringData.Error", 1, Comment);
			EndTry;
			
			MonitoringCenterParameters.SendDataNextGeneration = CurrentUniversalDate()
				+ GetMonitoringCenterParameters("SendDataGenerationPeriod");
				
			MonitoringCenterParameters.Delete("DumpRegistrationNextCreation");
			MonitoringCenterParameters.Delete("DumpRegistrationCreationPeriod");
			
			MonitoringCenterParameters.Delete("BusinessStatisticsNextSnapshot");
			MonitoringCenterParameters.Delete("BusinessStatisticsSnapshotPeriod");
			
			MonitoringCenterParameters.Delete("ConfigurationStatisticsNextGeneration");
			MonitoringCenterParameters.Delete("ConfigurationStatisticsGenerationPeriod");
			
			MonitoringCenterParameters.Delete("EventLogErrorsNextGeneration");
			MonitoringCenterParameters.Delete("EventLogErrorsGenerationPeriod");
			
			PerformanceMonitorRecordRequired = True;
			
			SetAdditionalErrorHandlingInformation();
		EndIf;
		
		MonitoringCenterParameters.Delete("RegisterDumps");
		MonitoringCenterParameters.Delete("RegisterBusinessStatistics");
		MonitoringCenterParameters.Delete("RegisterConfigurationStatistics");
		MonitoringCenterParameters.Delete("RegisterConfigurationSettings");
		MonitoringCenterParameters.Delete("SendDataGenerationPeriod");
		MonitoringCenterParameters.Delete("RegisterEventLogErrors");
		
		SetMonitoringCenterParameters(MonitoringCenterParameters);
	Else
		DeleteScheduledJob("StatisticsDataCollectionAndSending");
	EndIf;
	
	MonitoringCenterParameters.Insert("SendDumpsFiles");
	MonitoringCenterParameters.Insert("DumpOption");
	MonitoringCenterParameters.Insert("DumpCollectingEnd");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	StartErrorReportsCollectionAndSending = Not MonitoringCenterParameters.SendDumpsFiles = 0
											And Not IsBlankString(MonitoringCenterParameters.DumpOption)
											And StartDate < MonitoringCenterParameters.DumpCollectingEnd;
	If StartErrorReportsCollectionAndSending Then
		
		If Not ValueIsFilled(MonitoringCenterParameters.NotificationDate2) Then
			SetMonitoringCenterParameter("NotificationDate2", StartDate);
		ElsIf StartDate > MonitoringCenterParameters.NotificationDate2 + MonitoringCenterParameters.UserResponseTimeout * 86400
			And MonitoringCenterParameters.ForceSendMinidumps = 2 Then
			SetMonitoringCenterParameter("ForceSendMinidumps", 1);	
			MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.DumpsRegistration.ForcedMinidumpSendingEnabled", 1);
		EndIf;
		
		If Not Common.FileInfobase() Then
			ScheduledJob = GetScheduledJob("ErrorReportCollectionAndSending", False);
			If ScheduledJob = Undefined Then
				ScheduledJob = GetScheduledJob("ErrorReportCollectionAndSending", True);
				SetDefaultSchedule(ScheduledJob);
			EndIf;
		EndIf;
	EndIf;
	
	If PerformanceMonitorExists And PerformanceMonitorRecordRequired Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterCollectAndSubmitStatisticalData", BeginTime);
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithBusinessStatistics

Procedure ParseStatisticsOperationsBuffer(CurrentDate)
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("AggregationPeriodMinor, AggregationPeriod"));
	AggregationPeriod = MonitoringCenterParameters.AggregationPeriodMinor;
	DeletionPeriod = MonitoringCenterParameters.AggregationPeriod;
				
	ProcessRecordsUntil = Date(1, 1, 1) + Int((CurrentDate - Date(1, 1, 1))/AggregationPeriod)*AggregationPeriod;
			
	QueryResultOperations = InformationRegisters.StatisticsOperationsClipboard.GetAggregatedOperationsRecords(ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
	QueryResultComment = InformationRegisters.StatisticsOperationsClipboard.GetAggregatedRecordsComment(ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
	QueryResultAreas = InformationRegisters.StatisticsOperationsClipboard.GetAggregatedRecordsStatisticsAreas(ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
	BeginTransaction();
	Try
		InformationRegisters.MeasurementsStatisticsOperations.WriteMeasurements(QueryResultOperations);
		InformationRegisters.MeasurementsStatisticsComments.WriteMeasurements(QueryResultComment);
		InformationRegisters.MeasurementsStatisticsAreas.WriteMeasurements(QueryResultAreas);
		
		InformationRegisters.StatisticsOperationsClipboard.DeleteRecords(ProcessRecordsUntil);	
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(EventLogEventMonitoringCenterParseStatisticsOperationsBuffer(), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
		Raise Error;
	EndTry;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterAnalyzeStatisticsOperationBuffer", BeginTime);
	EndIf;
EndProcedure

Procedure AggregateStatisticsOperationsMeasurements(CurrentDate)
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("AggregationPeriodMinor, AggregationPeriod, AggregationBoundary"));
	AggregationPeriod = MonitoringCenterParameters.AggregationPeriodMinor;
	DeletionPeriod = MonitoringCenterParameters.AggregationPeriod;
	
	AggregationBoundary = MonitoringCenterParameters.AggregationBoundary;
	ProcessRecordsUntil = Date(1, 1, 1) + Int((CurrentDate - Date(1, 1, 1))/AggregationPeriod)*AggregationPeriod;
	
	If ProcessRecordsUntil > AggregationBoundary Then
		BeginTransaction();
		Try
			QueryResultOperationsAggregated = InformationRegisters.MeasurementsStatisticsOperations.GetAggregatedRecords(AggregationBoundary, ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
			QueryResultCommentAggregated = InformationRegisters.MeasurementsStatisticsComments.GetAggregatedRecords(AggregationBoundary, ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
			QueryResultAreasAggregated = InformationRegisters.MeasurementsStatisticsAreas.GetAggregatedRecords(AggregationBoundary, ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
			
			InformationRegisters.MeasurementsStatisticsOperations.DeleteRecords(AggregationBoundary, ProcessRecordsUntil);
			InformationRegisters.MeasurementsStatisticsComments.DeleteRecords(AggregationBoundary, ProcessRecordsUntil);
			InformationRegisters.MeasurementsStatisticsAreas.DeleteRecords(AggregationBoundary, ProcessRecordsUntil);
			
			InformationRegisters.MeasurementsStatisticsOperations.WriteMeasurements(QueryResultOperationsAggregated);
			InformationRegisters.MeasurementsStatisticsComments.WriteMeasurements(QueryResultCommentAggregated);
			InformationRegisters.MeasurementsStatisticsAreas.WriteMeasurements(QueryResultAreasAggregated);
			
			SetMonitoringCenterParameter("AggregationBoundary", ProcessRecordsUntil);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Error = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(NStr("en = 'Monitoring center.Aggregate measurements of statistics operations '; ru = 'Центр мониторинга.Агрегировать замеры операций статистики'; pl = 'Centrum monitorowania.Zbieraj pomiary operacji statystyk ';es_ES = 'Centro de control. Mediciones agregadas de las operaciones estadísticas ';es_CO = 'Centro de control. Mediciones agregadas de las operaciones estadísticas ';tr = 'İzleme merkezi. İstatistik işlemlerinin toplu ölçümleri';it = 'Centro di monitoraggio.Misurazioni aggregate di operazioni statistiche ';de = 'Überwachungszentrum.Messungen von Operationen der Statistik zusammenfassen '", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
			Raise Error;
		EndTry;
	EndIf;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterAggregateStatisticsOperationsMeasurements", BeginTime);
	EndIf;
EndProcedure

Procedure StatisticsOperationsRegistration()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	CurrentDate = CurrentUniversalDate();
	
	ParseStatisticsOperationsBuffer(CurrentDate);
	AggregateStatisticsOperationsMeasurements(CurrentDate);
	DeleteObsoleteStatisticsOperationsData();
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterStatisticsOperationRegistration", BeginTime);
	EndIf;
EndProcedure

Procedure DeleteObsoleteStatisticsOperationsData()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("LastPackageDate, DeletionPeriod"));
	
	LastPackageDate = MonitoringCenterParameters.LastPackageDate;
	DeletionPeriod = MonitoringCenterParameters.DeletionPeriod;
	
	DeletionBoundary = Date(1,1,1) + Int((LastPackageDate - Date(1,1,1))/DeletionPeriod) * DeletionPeriod;
	
	BeginTransaction();
	Try
		InformationRegisters.MeasurementsStatisticsOperations.DeleteRecords(Date(1,1,1), DeletionBoundary);
		InformationRegisters.MeasurementsStatisticsComments.DeleteRecords(Date(1,1,1), DeletionBoundary);
		InformationRegisters.MeasurementsStatisticsAreas.DeleteRecords(Date(1,1,1), DeletionBoundary);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(NStr("en = 'Monitoring center.Delete obsolete data of statistics operations '; ru = 'Центр мониторинга.Удалить устаревшие данные операций статистики'; pl = 'Centrum monitorowania.Usuń przestarzałe dane operacji statystyk ';es_ES = 'Centro de control. Elimina los datos obsoletos de las operaciones estadísticas ';es_CO = 'Centro de control. Elimina los datos obsoletos de las operaciones estadísticas ';tr = 'İzleme merkezi. İstatistik işlemlerinin eski verilerini sil';it = 'Centro di monitoraggio.Eliminare dati obsoleti delle operazioni statistiche ';de = 'Überwachungszentrum.Veraltete Daten von Operationen der Statistik löschen '", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
		Raise Error;
	EndTry;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterDeleteOutdatedStatisticsOperationData", BeginTime);
	EndIf;
EndProcedure

#EndRegion

#Region WorkWithJSON

Function GenerateJSONStructure(SectionName, Data, AdditionalParameters = Undefined)
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Map;
	EndIf;
	
	StartDate = AdditionalParameters["StartDate"];
	EndDate = AdditionalParameters["EndDate"];
	AddlParameters = AdditionalParameters["AddlParameters"];
	IndexColumns = AdditionalParameters["IndexColumns"];
	
	If TypeOf(Data) = Type("QueryResult") Then
		JSONStructure = GenerateJSONStructureQueryResult(SectionName, Data, StartDate, EndDate, AddlParameters, IndexColumns);
	ElsIf TypeOf(Data) = Type("ValueTable") Then
		JSONStructure = GenerateJSONStructureValueTable(SectionName, Data, StartDate, EndDate, AddlParameters, IndexColumns);
	EndIf;
	
	Return JSONStructure;
EndFunction

Function GenerateJSONStructureQueryResult(SectionName, Data, StartDate, EndDate, AddlParameters, IndexColumns)
	JSONStructure = New Map;
	
	Section3 = New Structure;
	
	
	If StartDate <> Undefined Then
		Section3.Insert("date_start", StartDate);
	EndIf;
	
	If EndDate <> Undefined Then
		Section3.Insert("date_end", EndDate);
	EndIf;
	
	If AddlParameters <> Undefined Then
		For Each Parameter In AddlParameters Do
			Section3.Insert(Parameter.Key, Parameter.Value);
		EndDo;
	EndIf;
			
	Rows = New Array;
	Selection = Data.Select();
	CollectionsStructures = New Structure;
	CollectionsMaps = New Map; 
	ColumnsToExclude = New Map;
	If IndexColumns <> Undefined Then
		ValuesIndexes = New Map;
		For Each CurColumn In IndexColumns Do
			ValuesIndexes.Insert(CurColumn.Key, New Map);
			If CurColumn.Value.Count() Then
				CollectionsMaps.Insert(CurColumn.Key, New Map);
				ObjectStructure = New Structure;
				For Each Record In CurColumn.Value Do
					ObjectStructure.Insert(Record.Key);
					ColumnsToExclude.Insert(Record.Key, True);
				EndDo;
				CollectionsStructures.Insert(CurColumn.Key, ObjectStructure);
			EndIf;
		EndDo;
	EndIf;
	
	Columns = New Array;
	For Each CurColumn In Data.Columns Do
		If ColumnsToExclude[CurColumn.Name] = True Then
			Continue;
		EndIf;
		Columns.Add(CurColumn.Name);
	EndDo;
	Section3.Insert("columns", Columns);
	
	While Selection.Next() Do
		String = New Array;
		For Each CurColumn In Columns Do
			ValueToAdd = Selection[CurColumn];
			If IndexColumns <> Undefined And IndexColumns[CurColumn] <> Undefined Then
				If IndexColumns[CurColumn][ValueToAdd] = Undefined Then
					ValueIndex = IndexColumns[CurColumn].Count() + 1;
					IndexColumns[CurColumn].Insert(ValueToAdd, ValueIndex);
					ValuesIndexes[CurColumn].Insert(Format(ValueIndex, "NG=0"), ValueToAdd);
				EndIf;
				
				ValueToAdd = IndexColumns[CurColumn][ValueToAdd];
			EndIf;
			
			If CollectionsStructures.Property(CurColumn) 
				And CollectionsMaps[CurColumn][Selection[CurColumn]] = Undefined Then
				ObjectMap = New Map;
				For Each Record In CollectionsStructures[CurColumn] Do
					ObjectMap.Insert(Record.Key, Selection[Record.Key]);
				EndDo;
				CollectionsMaps[CurColumn].Insert(Selection[CurColumn], ObjectMap);
			EndIf;
			
			String.Add(ValueToAdd);
		EndDo;
		Rows.Add(String);
	EndDo;
	
	For Each Record In CollectionsMaps Do
		Section3.Insert(Record.Key, Record.Value);
	EndDo;
	Section3.Insert("columnsValueIndex", ValuesIndexes);
	Section3.Insert("rows", Rows);
	
	JSONStructure.Insert(SectionName, Section3);
	
	Return JSONStructure;
EndFunction

Function GenerateJSONStructureValueTable(SectionName, Data, StartDate, EndDate, AddlParameters, IndexColumns)
	JSONStructure = New Map;
	
	Section3 = New Structure;
	
	
	If StartDate <> Undefined Then
		Section3.Insert("date_start", StartDate);
	EndIf;
	
	If EndDate <> Undefined Then
		Section3.Insert("date_end", EndDate);
	EndIf;
	
	If AddlParameters <> Undefined Then
		For Each Parameter In AddlParameters Do
			Section3.Insert(Parameter.Key, Parameter.Value);
		EndDo;
	EndIf;
			
	Rows = New Array;
	CollectionsStructures = New Structure;
	CollectionsMaps = New Map; 
	ColumnsToExclude = New Map;
	If IndexColumns <> Undefined Then
		ValuesIndexes = New Map;
		For Each CurColumn In IndexColumns Do
			ValuesIndexes.Insert(CurColumn.Key, New Map);
			If CurColumn.Value.Count() Then
				CollectionsMaps.Insert(CurColumn.Key, New Map);
				ObjectStructure = New Structure;
				For Each Record In CurColumn.Value Do
					ObjectStructure.Insert(Record.Key);
					ColumnsToExclude.Insert(Record.Key, True);
				EndDo;
				CollectionsStructures.Insert(CurColumn.Key, ObjectStructure);
			EndIf;
		EndDo;
	EndIf;
	
	Columns = New Array;
	For Each CurColumn In Data.Columns Do
		If ColumnsToExclude[CurColumn.Name] = True Then
			Continue;
		EndIf;
		Columns.Add(CurColumn.Name);
	EndDo;
	Section3.Insert("columns", Columns);
	
	For Each Selection In Data Do
		String = New Array;
		For Each CurColumn In Columns Do
			ValueToAdd = Selection[CurColumn];
			If IndexColumns <> Undefined And IndexColumns[CurColumn] <> Undefined Then
				If IndexColumns[CurColumn][ValueToAdd] = Undefined Then
					ValueIndex = IndexColumns[CurColumn].Count() + 1;
					IndexColumns[CurColumn].Insert(ValueToAdd, ValueIndex);
					ValuesIndexes[CurColumn].Insert(Format(ValueIndex, "NG=0"), ValueToAdd);
				EndIf;
				
				ValueToAdd = IndexColumns[CurColumn][ValueToAdd];
			EndIf;
			
			If CollectionsStructures.Property(CurColumn) 
				And CollectionsMaps[CurColumn][Selection[CurColumn]] = Undefined Then
				ObjectMap = New Map;
				For Each Record In CollectionsStructures[CurColumn] Do
					ObjectMap.Insert(Record.Key, Selection[Record.Key]);
				EndDo;
				CollectionsMaps[CurColumn].Insert(Selection[CurColumn], ObjectMap);
			EndIf;
			
			String.Add(ValueToAdd);
		EndDo;
		Rows.Add(String);
	EndDo;
	
	For Each Record In CollectionsMaps Do
		Section3.Insert(Record.Key, Record.Value);
	EndDo;
	Section3.Insert("columnsValueIndex", ValuesIndexes);
	Section3.Insert("rows", Rows);
	
	JSONStructure.Insert(SectionName, Section3);
	
	Return JSONStructure;
EndFunction

Function GenerateJSONStructureForSending(Parameters)
	StartDate = Parameters.StartDate;
	EndDate = Parameters.EndDate;
	
	TopDumpsQuantity = Parameters.TopDumpsQuantity;
	TopApdex = Parameters.TopApdex;
	TopApdexTech = Parameters.TopApdexTech;
	DeletionPeriod = Parameters.DeletionPeriod;
	
	MonitoringCenterParameters = New Structure();
	MonitoringCenterParameters.Insert("InfoBaseID");
	MonitoringCenterParameters.Insert("InfobaseIDPermanent");
	MonitoringCenterParameters.Insert("RegisterSystemInformation");
	MonitoringCenterParameters.Insert("RegisterSubsystemVersions");
	MonitoringCenterParameters.Insert("RegisterDumps");
	MonitoringCenterParameters.Insert("RegisterBusinessStatistics");
	MonitoringCenterParameters.Insert("RegisterConfigurationStatistics");
	MonitoringCenterParameters.Insert("RegisterConfigurationSettings");
	MonitoringCenterParameters.Insert("RegisterEventLogErrors");
	MonitoringCenterParameters.Insert("RegisterPerformance");
	MonitoringCenterParameters.Insert("RegisterTechnologicalPerformance");
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If MonitoringCenterParameters.RegisterSystemInformation Then
		Info = GetSystemInformation();
	EndIf;
	
	If MonitoringCenterParameters.RegisterSubsystemVersions Then
		Subsystems = SubsystemsVersions();
	EndIf;
	
	If MonitoringCenterParameters.RegisterDumps Then
		TopDumps = InformationRegisters.PlatformDumps.GetTopOptions(StartDate, EndDate, TopDumpsQuantity);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		AdditionalParameters.Insert("EndDate", EndDate);
		DUMPSSection = GenerateJSONStructure("dumps", TopDumps, AdditionalParameters);
	EndIf;
	
	If MonitoringCenterParameters.RegisterBusinessStatistics Then
		
		QueryResult = InformationRegisters.MeasurementsStatisticsOperations.GetMeasurements(StartDate, EndDate, DeletionPeriod);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		AdditionalParameters.Insert("EndDate", EndDate);
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsOperationsSection = GenerateJSONStructure("OperationStatistics", QueryResult, AdditionalParameters);
		StatisticsOperationsSection["OperationStatistics"].Insert("AggregationPeriod", DeletionPeriod);
		
		QueryResult = InformationRegisters.MeasurementsStatisticsComments.GetMeasurements(StartDate, EndDate, DeletionPeriod);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		IndexColumns.Insert("StatisticsComment", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		AdditionalParameters.Insert("EndDate", EndDate);
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsCommentsSection = GenerateJSONStructure("CommentsStatistics", QueryResult, AdditionalParameters);
		
		StatisticsCommentsSection["CommentsStatistics"]["columnsValueIndex"].Delete("StatisticsOperation");
		StatisticsCommentsSection["CommentsStatistics"]["columnsValueIndex"].Delete("Period");
		StatisticsCommentsSection["CommentsStatistics"].Insert("AggregationPeriod", DeletionPeriod);
		
		QueryResult = InformationRegisters.MeasurementsStatisticsAreas.GetMeasurements(StartDate, EndDate, DeletionPeriod);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		IndexColumns.Insert("StatisticsArea", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		AdditionalParameters.Insert("EndDate", EndDate);
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsAreasSection = GenerateJSONStructure("StatisticalAreas", QueryResult, AdditionalParameters);
		StatisticsAreasSection["StatisticalAreas"]["columnsValueIndex"].Delete("StatisticsOperation");
		StatisticsAreasSection["StatisticalAreas"]["columnsValueIndex"].Delete("Period");
		StatisticsAreasSection["StatisticalAreas"].Insert("AggregationPeriod", DeletionPeriod);
		
		QueryResult = InformationRegisters.StatisticsMeasurements.GetHourMeasurements(StartDate, EndDate);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsOperationsSectionClientHour = GenerateJSONStructure("OperationStatisticsClientHour", QueryResult, AdditionalParameters);
		
		QueryResult = InformationRegisters.StatisticsMeasurements.GetDayMeasurements(StartDate, EndDate);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsOperationsSectionClientDay = GenerateJSONStructure("OperationStatisticsClientDay", QueryResult, AdditionalParameters);
		
	EndIf;
	
	SeparationByDataAreasEnabled = SeparationByDataAreasEnabled();
	
	#Region StatisticsConfigurationSection
	If MonitoringCenterParameters.RegisterConfigurationStatistics Then
		If SeparationByDataAreasEnabled Then
			QueryResultNames = InformationRegisters.ConfigurationStatistics.GetStatisticsNames(0);
			ValueTableNames = QueryResultNames.Unload();
			
			Array = New Array;
			CheckDigit100 = New NumberQualifiers(10, 0, AllowedSign.Nonnegative);
			Array.Add(Type("Number"));
			TypesDetailsNumber100 = New TypeDescription(Array, CheckDigit100,,,);
			ValueTableNames.Columns.Add("RowIndex", TypesDetailsNumber100);
			MetadataNamesStructure = New Map;
			For Each CurRow In ValueTableNames Do
				RowIndex = ValueTableNames.IndexOf(CurRow);
				CurRow.RowIndex = RowIndex;
				MetadataNamesStructure.Insert(RowIndex, CurRow.StatisticsOperationDescription); 
			EndDo;
			
			ConfigurationStatisticsSection = New Structure("StatisticsConfiguration", New Structure);
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("MetadataName", Metadata.Name);
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("WorkingMode", ?(Common.FileInfobase(), "F", "S"));
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("DivisionByRegions", SeparationByDataAreasEnabled);
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("MetadataIndexName", New Map);
			For Each CurRow In ValueTableNames Do
				ConfigurationStatisticsSection.StatisticsConfiguration.MetadataIndexName.Insert(String(CurRow.RowIndex), CurRow.StatisticsOperationDescription);
			EndDo;
						
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("StatisticsConfigurationByRegions", New Map);
			DataAreasResult = InformationRegisters.ConfigurationStatistics.GetDataAreasQueryResult();
			Selection = DataAreasResult.Select();
			While Selection.Next() Do
				DataAreaString = String(Selection.DataArea);
				DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaString);
				
				If InformationRegisters.StatisticsAreas.CollectConfigurationStatistics(DataAreaString) Then
					QueryResult = InformationRegisters.ConfigurationStatistics.GetStatistics(0, ValueTableNames, DataAreaRef);
					AreaConfigurationStatistics = GenerateJSONStructure(DataAreaString, QueryResult);
					ConfigurationStatisticsSection.StatisticsConfiguration.StatisticsConfigurationByRegions.Insert(DataAreaString, AreaConfigurationStatistics[DataAreaString]); 
				EndIf;
			EndDo;
			DataOnUsedExtensions = New Structure;
		Else
			QueryResult = InformationRegisters.ConfigurationStatistics.GetStatistics(0);
			AddlParameters = New Structure("MetadataName", Metadata.Name);
			AddlParameters.Insert("WorkingMode", ?(Common.FileInfobase(), "F", "S"));
			AddlParameters.Insert("DivisionByRegions", SeparationByDataAreasEnabled);
			AddlParameters.Insert("CompatibilityMode", String(Metadata.CompatibilityMode));
			AddlParameters.Insert("InterfaceCompatibilityMode", String(Metadata.InterfaceCompatibilityMode));
			AddlParameters.Insert("ModalityUseMode", String(Metadata.ModalityUseMode));
			DataOnUsedExtensions = DataOnUsedExtensions();
			DataOnRolesUsage = DataOnRolesUsage();
			AddlParameters.Insert("UsingExtensions", DataOnUsedExtensions.ExtensionsUsage);
			
			AdditionalParameters = New Map;
			AdditionalParameters.Insert("StartDate", StartDate);
			AdditionalParameters.Insert("AddlParameters", AddlParameters);
			ConfigurationStatisticsSection = GenerateJSONStructure("StatisticsConfiguration", QueryResult, AdditionalParameters);
		EndIf;
	EndIf;
	#EndRegion
	
	#Region OptionsSection
	If MonitoringCenterParameters.RegisterConfigurationSettings Then
		If SeparationByDataAreasEnabled Then
			QueryResultNames = InformationRegisters.ConfigurationStatistics.GetStatisticsNames(1);
			ValueTableNames = QueryResultNames.Unload();
			
			Array = New Array;
			CheckDigit100 = New NumberQualifiers(10, 0, AllowedSign.Nonnegative);
			Array.Add(Type("Number"));
			TypesDetailsNumber100 = New TypeDescription(Array, CheckDigit100,,,);
			ValueTableNames.Columns.Add("RowIndex", TypesDetailsNumber100);
			MetadataNamesStructure = New Map;
			For Each CurRow In ValueTableNames Do
				RowIndex = ValueTableNames.IndexOf(CurRow);
				CurRow.RowIndex = RowIndex;
				MetadataNamesStructure.Insert(RowIndex, CurRow.StatisticsOperationDescription); 
			EndDo;
			
			ConfigurationSettingSection = New Structure("Options", New Structure);
			ConfigurationSettingSection.Options.Insert("MetadataName", Metadata.Name);
			ConfigurationSettingSection.Options.Insert("WorkingMode", ?(Common.FileInfobase(), "F", "S"));
			ConfigurationSettingSection.Options.Insert("DivisionByRegions", SeparationByDataAreasEnabled);
			ConfigurationSettingSection.Options.Insert("MetadataIndexName", New Map);
			For Each CurRow In ValueTableNames Do
				ConfigurationSettingSection.Options.MetadataIndexName.Insert(String(CurRow.RowIndex), CurRow.StatisticsOperationDescription);
			EndDo;
			
			ConfigurationSettingSection.Options.Insert("OptionsByRegions", New Map);
			DataAreasResult = InformationRegisters.ConfigurationStatistics.GetDataAreasQueryResult();
			Selection = DataAreasResult.Select();
			While Selection.Next() Do
				DataAreaString = String(Selection.DataArea);
				DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaString);
				
				If InformationRegisters.StatisticsAreas.CollectConfigurationStatistics(DataAreaString) Then
					QueryResult = InformationRegisters.ConfigurationStatistics.GetStatistics(1, ValueTableNames, DataAreaRef);
					AreaConfigurationStatistics = GenerateJSONStructure(DataAreaString, QueryResult);
					ConfigurationSettingSection.Options.OptionsByRegions.Insert(DataAreaString, AreaConfigurationStatistics[DataAreaString]); 
				EndIf;
			EndDo;
		Else
			QueryResult = InformationRegisters.ConfigurationStatistics.GetStatistics(1);
			AddlParameters = New Structure("MetadataName", Metadata.Name);
			AddlParameters.Insert("WorkingMode", ?(Common.FileInfobase(), 0, 1));
			
			AdditionalParameters = New Map;
			AdditionalParameters.Insert("StartDate", StartDate);
			AdditionalParameters.Insert("AddlParameters", AddlParameters);
			ConfigurationSettingSection = GenerateJSONStructure("Options", QueryResult, AdditionalParameters);
		EndIf;
	EndIf;
	#EndRegion
	
	#Region EventLogErrorsSection
	
	If MonitoringCenterParameters.RegisterEventLogErrors Then
		
		QueryResult = InformationRegisters.StatisticsEventLogErrors.GetStatistics();
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		EventLogErrorsSection = GenerateJSONStructure("EventLogErrors", QueryResult, AdditionalParameters);
		
	EndIf;
	
	#EndRegion
		
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		
		If MonitoringCenterParameters.RegisterPerformance Then
			QueryResult = ModulePerformanceMonitorInternal.GetAPDEXTop(StartDate, EndDate, DeletionPeriod, TopApdex);
			IndexColumns = New Map;
			IndexColumns.Insert("Period", New Map);
			KeyOperationCollection = New Map;
			KeyOperationCollection.Insert("KOD");
			KeyOperationCollection.Insert("KON");
			IndexColumns.Insert("KOHash", KeyOperationCollection);
						
			AdditionalParameters = New Map;
			AdditionalParameters.Insert("StartDate", StartDate);
			AdditionalParameters.Insert("EndDate", AddlParameters);
			AdditionalParameters.Insert("IndexColumns", IndexColumns);
			TopAPDEXSection = GenerateJSONStructure("TopApdex", QueryResult, AdditionalParameters);	
			TopAPDEXSection["TopApdex"].Insert("AggregationPeriod", DeletionPeriod);
		EndIf;
		
		If MonitoringCenterParameters.RegisterTechnologicalPerformance Then
			QueryResult = ModulePerformanceMonitorInternal.GetTopTechnologicalAPDEX(StartDate, EndDate, DeletionPeriod, TopApdexTech);
			IndexColumns = New Map;
			IndexColumns.Insert("Period", New Map);
			KeyOperationCollection = New Map;
			KeyOperationCollection.Insert("KOD");
			KeyOperationCollection.Insert("KON");
			IndexColumns.Insert("KOHash", KeyOperationCollection);
			
			AdditionalParameters = New Map;
			AdditionalParameters.Insert("StartDate", StartDate);
			AdditionalParameters.Insert("EndDate", AddlParameters);
			AdditionalParameters.Insert("IndexColumns", IndexColumns);
			TopAPDEXSectionInternal = GenerateJSONStructure("TopApdexTechnology", QueryResult, AdditionalParameters);
			TopAPDEXSectionInternal["TopApdexTechnology"].Insert("AggregationPeriod", DeletionPeriod);
		EndIf;
	EndIf;
	
	InfoBaseID = String(MonitoringCenterParameters.InfoBaseID);
	InfobaseIDPermanent = String(MonitoringCenterParameters.InfobaseIDPermanent);
	JSONStructure = New Structure;
	JSONStructure.Insert("ib",  InfoBaseID);
	JSONStructure.Insert("ibConst",  InfobaseIDPermanent);
	JSONStructure.Insert("versionPacket",  "1.0.5.0");
	JSONStructure.Insert("datePacket",  CurrentUniversalDate());
	
	If MonitoringCenterParameters.RegisterSystemInformation Then
		JSONStructure.Insert("info",  Info);
	EndIf;
	
	If MonitoringCenterParameters.RegisterSubsystemVersions Then
		JSONStructure.Insert("versions",  Subsystems);
	EndIf;
		
	If MonitoringCenterParameters.RegisterDumps Then
		JSONStructure.Insert("dumps", DUMPSSection["dumps"]);
		DataOnFullDumps = New Structure;
		DataOnFullDumps.Insert("SendingResult", Parameters.SendingResult);
		DataOnFullDumps.Insert("SendDumpsFiles", Parameters.SendDumpsFiles);
		DataOnFullDumps.Insert("RequestConfirmationBeforeSending", Parameters.RequestConfirmationBeforeSending);
		JSONStructure.Insert("FullDumps", DataOnFullDumps);		
	EndIf;
	
	If MonitoringCenterParameters.RegisterBusinessStatistics Then
		BusinessStatistics = New Structure;
		BusinessStatistics.Insert("OperationStatistics", StatisticsOperationsSection["OperationStatistics"]);
		BusinessStatistics.Insert("CommentsStatistics", StatisticsCommentsSection["CommentsStatistics"]);
		BusinessStatistics.Insert("StatisticalAreas", StatisticsAreasSection["StatisticalAreas"]);
		BusinessStatistics.Insert("OperationStatisticsClientHour", StatisticsOperationsSectionClientHour["OperationStatisticsClientHour"]);
		BusinessStatistics.Insert("OperationStatisticsClientDay", StatisticsOperationsSectionClientDay["OperationStatisticsClientDay"]);
		JSONStructure.Insert("business", BusinessStatistics);
	EndIf;
	
	If MonitoringCenterParameters.RegisterConfigurationStatistics Then
		JSONStructure.Insert("config", ConfigurationStatisticsSection["StatisticsConfiguration"]);
		JSONStructure.Insert("extensionsInfo", DataOnUsedExtensions);
		JSONStructure.Insert("statisticOfRoles", DataOnRolesUsage);
	EndIf;
	
	If MonitoringCenterParameters.RegisterConfigurationSettings Then
		JSONStructure.Insert("options", ConfigurationSettingSection["Options"]);
	EndIf;
	
	If MonitoringCenterParameters.RegisterEventLogErrors Then
		JSONStructure.Insert("eventLogErrors", EventLogErrorsSection["EventLogErrors"]);
	EndIf;
		
	If PerformanceMonitorExists Then
		If MonitoringCenterParameters.RegisterPerformance Then
			JSONStructure.Insert("perf", TopAPDEXSection["TopApdex"]);
		EndIf;
		
		If MonitoringCenterParameters.RegisterTechnologicalPerformance Then
			JSONStructure.Insert("internal_perf", TopAPDEXSectionInternal["TopApdexTechnology"]);
		EndIf;
	EndIf;
	
	If Parameters.ContactInformationChanged 
		And (Parameters.ContactInformationRequest = 0 
		Or Parameters.ContactInformationRequest = 1) Then
		ContactInformation = New Structure;
		ContactInformation.Insert("ContactInformationRequest", Parameters.ContactInformationRequest);
		ContactInformation.Insert("ContactInformation", Parameters.ContactInformation);
		ContactInformation.Insert("ContactInformationComment1", Parameters.ContactInformationComment1);
		ContactInformation.Insert("PortalUsername", Parameters.PortalUsername);
		JSONStructure.Insert("contacts", ContactInformation);
	EndIf;
	
	Return JSONStructure;
EndFunction

Function JSONStringToStructure(JSONString)
	JSONReader = New JSONReader();
	JSONReader.SetString(JSONString);
	
	JSONStructure = ReadJSON(JSONReader);
	
	Return JSONStructure;
EndFunction

Function JSONStructureToString(JSONStructure) Export
	JSONWriter = New JSONWriter;
	JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
	WriteJSON(JSONWriter, JSONStructure);
		
	Return JSONWriter.Close();
EndFunction

#EndRegion

#Region WorkWithHTTPService

Function HTTPServiceSendDataInternal(Parameters)
	
	SecureConnection = Undefined;
	If Parameters.SecureConnection Then
		SecureConnection = CommonClientServer.NewSecureConnection();
	EndIf;
	
	InternetProxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternetClientServer");
		InternetProxy = ModuleNetworkDownload.GetProxy("https");
	EndIf;
	
	HTTPConnection = New HTTPConnection(
		Parameters.Server, Parameters.Port,,,
		InternetProxy,
		Parameters.Timeout,
		SecureConnection);
		
	HTTPRequest = New HTTPRequest(Parameters.ResourceAddress);
	
	If Parameters.DataType = "Text" Then
		HTTPRequest.SetBodyFromString(Parameters.Data);
	ElsIf Parameters.DataType = "ZIP" Then
		ArchiveFileName = WriteDataToArchive(Parameters.Data);
		ArchiveBinaryData = New BinaryData(ArchiveFileName);
		HTTPRequest.SetBodyFromBinaryData(ArchiveBinaryData);
	ElsIf Parameters.DataType = "BinaryData" Then
		ArchiveBinaryData = New BinaryData(Parameters.Data);
		HTTPRequest.SetBodyFromBinaryData(ArchiveBinaryData);
	EndIf;
	
	Try
		If Parameters.Method = "POST" Then
			HTTPResponse = HTTPConnection.Post(HTTPRequest);
		ElsIf Parameters.Method = "GET" Then
			HTTPResponse = HTTPConnection.Get(HTTPRequest);
		EndIf;
		
		HTTPResponseStructure = HTTPResponseToStructure(HTTPResponse);
		
		If HTTPResponseStructure.StatusCode = 200 Then
			If Parameters.DataType = "ZIP" Then
				DeleteFiles(ArchiveFileName);
			ElsIf Parameters.DataType = "BinaryData" Then
				DeleteFiles(Parameters.Data);
			EndIf;
		EndIf;
	Except
		HTTPResponseStructure = New Structure("StatusCode", 105);
	EndTry;
	
	Return HTTPResponseStructure;
EndFunction

Function WriteDataToArchive(Data)
	DataFileName = GetTempFileName("txt");
	ArchiveFileName = GetTempFileName("zip");
	
	TextWriter = New TextWriter(DataFileName);
	TextWriter.Write(Data);
	TextWriter.Close();
	
	ZipArchive = New ZipFileWriter(ArchiveFileName,,,ZIPCompressionMethod.Deflate,ZIPCompressionLevel.Maximum);
	ZipArchive.Add(DataFileName, ZIPStorePathMode.DontStorePath);
	ZipArchive.Write();
	
	DeleteFiles(DataFileName);
	
	Return ArchiveFileName; 
EndFunction

Function HTTPResponseToStructure(Response)
	Result = New Structure;
	
	Result.Insert("StatusCode", Response.StatusCode);
	Result.Insert("Headers",  New Map);
	For Each Parameter In Response.Headers Do
		Result.Headers.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	If Response.Headers["Content-Type"] <> Undefined Then
		MIMEType = Response.Headers["Content-Type"];
		If StrFind(MIMEType, "text/plain") > 0 Then
			Body = Response.GetBodyAsString();
			Result.Insert("Body", Body);
		ElsIf StrFind(MIMEType, "text/html") > 0 Then
			Body = Response.GetBodyAsString();
			Result.Insert("Body", Body);
		ElsIf StrFind(MIMEType, "application/json") Then
			Body = Response.GetBodyAsString();
			Result.Insert("Body", Body);
		Else
			Body = "Not known ContentType = " + MIMEType + ". See. <Function HTTPResponseToStructure(Response) Export1>";
			Result.Insert("Body", Body);
		EndIf;
	EndIf;	
	
	Return Result;
EndFunction

#EndRegion

#Region WorkWithDumpsRegistration

Procedure DumpsRegistration()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	DumpType = GetMonitoringCenterParameters("DumpType");
	DumpsDirectory = GetDumpsDirectory(DumpType);
	
	If DumpsDirectory.Path <> Undefined Then
		CheckIfNotificationOfDumpsIsRequired(DumpsDirectory.Path);
		If DumpsDirectory.DeleteDumps Then
			DumpsToDelete = InformationRegisters.PlatformDumps.GetDumpsToDelete();
			
			For Each DumpToDelete In DumpsToDelete Do
				File = New File(DumpToDelete.FileName);
				If File.Exist() Then
					Try
						DeleteFiles(File.FullName);
						DumpToDelete.FileName = "";
						InformationRegisters.PlatformDumps.ChangeRecord(DumpToDelete);
					Except
						WriteLogEvent(EventLogEventMonitoringCenterDumpDeletion(), EventLogLevel.Error,,,
						DetailErrorDescription(ErrorInfo()));
					EndTry;
				Else
					DumpToDelete.FileName = "";
					InformationRegisters.PlatformDumps.ChangeRecord(DumpToDelete);
				EndIf;
			EndDo;
		EndIf;
		
		DumpsFiles = FindFiles(DumpsDirectory.Path, "*.mdmp");
		DumpsFilesNames = New Array;
		For Each DumpFile In DumpsFiles Do
			DumpsFilesNames.Add(DumpFile.FullName);
		EndDo;
		
		DumpsFilesRegistered = InformationRegisters.PlatformDumps.GetRegisteredDumps(DumpsFilesNames);
		
		For Each DumpFile In DumpsFiles Do
			If DumpsFilesRegistered[DumpFile.FullName] = Undefined Then 
				DumpNew = New Structure;
				DumpStructure = DumpDetails(DumpFile.Description);
				
				DumpNew.Insert("RegistrationDate", CurrentUniversalDateInMilliseconds());
				DumpNew.Insert("DumpOption", DumpStructure.Process + "_" + DumpStructure.PlatformVersion + "_" + DumpStructure.Offset);
				DumpNew.Insert("PlatformVersion", PlatformVersionToNumber(DumpStructure.PlatformVersion));
				DumpNew.Insert("FileName", DumpFile.FullName);
				
				InformationRegisters.PlatformDumps.ChangeRecord(DumpNew);
			EndIf;
		EndDo;
	Else
		SetMonitoringCenterParameter("RegisterDumps", False);
	EndIf;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterDumpRegistration", BeginTime);
	EndIf;
EndProcedure

#EndRegion

#Region WorkWithConfigurationStatistics

Procedure CollectConfigurationStatistics(MonitoringCenterParameters = Undefined)
	If MonitoringCenterParameters = Undefined Then
		MonitoringCenterParameters.Insert("RegisterConfigurationStatistics");
		MonitoringCenterParameters.Insert("RegisterConfigurationSettings");
		MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	EndIf;
	
	#Region BaseConfigurationStatistics
	
	If MonitoringCenterParameters.RegisterConfigurationStatistics Or MonitoringCenterParameters.RegisterConfigurationSettings Then
		
		PerformanceMonitorRecordRequired = False;
		
		InformationRegisters.ConfigurationStatistics.ClearConfigurationStatistics();
		
		PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
		If PerformanceMonitorExists Then
			ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
			BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
		EndIf;
		
		If MonitoringCenterParameters.RegisterConfigurationStatistics Then
			InformationRegisters.ConfigurationStatistics.WriteConfigurationStatistics();
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If MonitoringCenterParameters.RegisterConfigurationSettings Then
			InformationRegisters.ConfigurationStatistics.WriteConfigurationSettings();
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If PerformanceMonitorExists And PerformanceMonitorRecordRequired Then
			ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterCollectConfigurationStatisticalDataBasic", BeginTime);
		EndIf;
	EndIf;
	
	#EndRegion
	
	#Region ConfigurationStatisticsStandardSubsystems
	
	If MonitoringCenterParameters.RegisterConfigurationStatistics Then
		If PerformanceMonitorExists Then
			BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
		EndIf;
		
		SeparationByDataAreasEnabled = SeparationByDataAreasEnabled();
		If SeparationByDataAreasEnabled Then
			DataAreasQueryResult = InformationRegisters.ConfigurationStatistics.GetDataAreasQueryResult();
			Selection = DataAreasQueryResult.Select();
			While Selection.Next() Do
				DataAreaString = String(Selection.DataArea);
				If InformationRegisters.StatisticsAreas.CollectConfigurationStatistics(DataAreaString) Then
					Try
						SetSessionSeparation(True, Selection.DataArea);
					Except
						Info = ErrorInfo();
						WriteLogEvent(NStr("ru = 'Центр мониторинга.Статистика конфигурации переопределяемая';
														|en = 'Monitoring center.Configuration statistics overridable ';pl = 'Centrum monitorowania.Statystyki konfiguracji predefiniowane ';es_ES = 'Centro de control. Estadísticas de configuración anulables ';es_CO = 'Centro de control. Estadísticas de configuración anulables ';tr = 'İzleme merkezi. Yapılandırma istatistikleri overridable';it = 'Centro di monitoraggio.Configurazione statistiche overridable ';de = 'Überwachungszentrum.Konfigurationsstatistik Overridable '", CommonClientServer.DefaultLanguageCode()),
						EventLogLevel.Error,
						,,
						NStr("ru = 'Не удалось установить разделение сеанса.Область данных';
							|en = 'Cannot set the session separation.Data area';pl = 'Nie można ustawić podziału sesji. Obszar danych';es_ES = 'No se puede ajustar la separación de la sesión. Área de datos';es_CO = 'No se puede ajustar la separación de la sesión. Área de datos';tr = 'Oturum ayırma ayarlanamıyor. Veri alanı';it = 'Impossibile impostare la separazione di sessione. Area dati';de = 'Fehler beim Festlegen der Trennung der Sitzung.Datenbereich'", CommonClientServer.DefaultLanguageCode()) + " = " + Format(Selection.DataArea, "NG=0")
						+ Chars.LF + DetailErrorDescription(Info));
						
						SetSessionSeparation(False);
						Continue;
					EndTry;
					SSLSubsystemsIntegration.OnCollectConfigurationStatisticsParameters();
					MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters();
					SetSessionSeparation(False);
				EndIf;
			EndDo;
		Else
			SSLSubsystemsIntegration.OnCollectConfigurationStatisticsParameters();
			MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters();
		EndIf;
		
		If PerformanceMonitorExists Then
			ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterCollectConfigurationStatisticalDataStandardSubsystems", BeginTime);
		EndIf;
	EndIf;
	
	#EndRegion
	
EndProcedure

#EndRegion

#Region WorkWithPackagesToSend

Procedure CreatePackageToSend(UpdateInstalled = False)
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	CurDate = CurrentUniversalDate(); 
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	
	Parameters = New Structure;
	Parameters.Insert("StartDate", Date(1,1,1) + Int((MonitoringCenterParameters.LastPackageDate - Date(1,1,1))/MonitoringCenterParameters.DeletionPeriod) * MonitoringCenterParameters.DeletionPeriod);
	Parameters.Insert("EndDate", Date(1,1,1) + Int((CurDate - Date(1,1,1))/MonitoringCenterParameters.DeletionPeriod) * MonitoringCenterParameters.DeletionPeriod - 1);
	Parameters.Insert("TopDumpsQuantity", 5);
	Parameters.Insert("TopApdex", MonitoringCenterParameters.TopApdex);
	Parameters.Insert("TopApdexTech", MonitoringCenterParameters.TopApdexTech);
	Parameters.Insert("DeletionPeriod", MonitoringCenterParameters.DeletionPeriod);
	Parameters.Insert("SendingResult", MonitoringCenterParameters.SendingResult);
	Parameters.Insert("SendDumpsFiles", MonitoringCenterParameters.SendDumpsFiles);
	Parameters.Insert("RequestConfirmationBeforeSending", MonitoringCenterParameters.RequestConfirmationBeforeSending);
	Parameters.Insert("ContactInformationRequest", MonitoringCenterParameters.ContactInformationRequest);
	Parameters.Insert("ContactInformation", MonitoringCenterParameters.ContactInformation);
	Parameters.Insert("ContactInformationComment1", MonitoringCenterParameters.ContactInformationComment1);
	Parameters.Insert("PortalUsername", MonitoringCenterParameters.PortalUsername);
	Parameters.Insert("ContactInformationChanged", MonitoringCenterParameters.ContactInformationChanged);
		
	BeginTransaction();
	Try
		If UpdateInstalled Then
			JSONStructure = GenerateJSONStructureForUpdateInstalledSending(MonitoringCenterParameters);
		Else
			JSONStructure = GenerateJSONStructureForSending(Parameters);
		EndIf;
		InformationRegisters.PackagesToSend.WriteNewPackage(CurDate, JSONStructure, MonitoringCenterParameters.LastPackageNumber + 1);
		
		MonitoringCenterParametersRecord = New Structure("LastPackageDate, LastPackageNumber");
		MonitoringCenterParametersRecord.LastPackageDate = CurDate;
		MonitoringCenterParametersRecord.LastPackageNumber = MonitoringCenterParameters.LastPackageNumber + 1;
		SetMonitoringCenterParameters(MonitoringCenterParametersRecord);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(NStr("ru = 'Центр мониторинга.Формирование пакета для отправки';
										|en = 'Monitoring center.Generate a package for sending';pl = 'Centrum monitorowania. Wygeneruj pakiet do wysyłki';es_ES = 'Centro de control. Generar un paquete para enviar';es_CO = 'Centro de control. Generar un paquete para enviar';tr = 'İzleme merkezi. Gönderim için paket oluştur';it = 'Centro di monitoraggio.Creare un pacchetto per l''invio';de = 'Überwachungszentrum.Paket zum Senden generieren'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
		Raise Error;
	EndTry;
	
	InformationRegisters.PackagesToSend.DeleteOldPackages();
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterGeneratePackageToSend", BeginTime);
	EndIf;
EndProcedure

Function SendMonitoringData(TestPackage = False, UpdateInstalled = False)
	Parameters = GetSendServiceParameters();
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	NumbersOfPackagesToSend = InformationRegisters.PackagesToSend.GetPackagesNumbers();
	For Each PackageNumber In NumbersOfPackagesToSend Do
		Package = InformationRegisters.PackagesToSend.GetPackage(PackageNumber);
		If Package <> Undefined Then
						
			PackageHash = Package.PackageHash;
			PackageForSendingNumber = Format(Package.PackageNumber, "NZ=0; NG=0");
			ID = String(Parameters.InfoBaseID);
			
			If Parameters.SecureConnection Then
				JoinType = "https";
			Else
				JoinType = "http";
			EndIf;
												
			ResourceAddress = Parameters.ResourceAddress;
			If Right(ResourceAddress, 1) <> "/" Then
				ResourceAddress = ResourceAddress + "/";
			EndIf;
			ResourceAddress = ResourceAddress + ID + "/" + PackageForSendingNumber + "/" + PackageHash;
			
			HTTPParameters = New Structure;
			HTTPParameters.Insert("Server", Parameters.Server);
			HTTPParameters.Insert("ResourceAddress", ResourceAddress);
			HTTPParameters.Insert("Data", Package.PackageBody);
			HTTPParameters.Insert("Port", Parameters.Port);
			HTTPParameters.Insert("SecureConnection", Parameters.SecureConnection);	
			HTTPParameters.Insert("Method", "POST");
			HTTPParameters.Insert("DataType", "Text");
			HTTPParameters.Insert("Timeout", 60);
			
			HTTPResponse = HTTPServiceSendDataInternal(HTTPParameters);
			
			If HTTPResponse.StatusCode = 200 Then
				AnswerParameters = JSONStringToStructure(HTTPResponse.Body);
				If Not TestPackage And Not UpdateInstalled Then
					SetSendingParameters(AnswerParameters);
				ElsIf TestPackage Then
					If AnswerParameters.Property("foundCopy") And AnswerParameters.foundCopy Then
						PerformActionsOnDetectCopy();
					Else
						SetMonitoringCenterParameter("DiscoveryPackageSent", True);
					EndIf;
				EndIf;
				InformationRegisters.PackagesToSend.DeletePackage(PackageNumber);
			Else
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterSubmitMonitoringData", BeginTime);
	EndIf;
	
	Return HTTPResponse;
EndFunction

#EndRegion

#Region WorkWithMonitoringCenterParameters

Function RunPerformanceMeasurements()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitorServerCallCached = Common.CommonModule("PerformanceMonitorServerCallCached");
		RunPerformanceMeasurements = ModulePerformanceMonitorServerCallCached.RunPerformanceMeasurements();
	Else
		RunPerformanceMeasurements = Undefined;
	EndIf;
	
	Return RunPerformanceMeasurements;
EndFunction

Function GetDefaultParameters()
	ConstantParameters = New Structure;
	ConstantParameters.Insert("EnableMonitoringCenter", False);
	ConstantParameters.Insert("ApplicationInformationProcessingCenter", False);
	
	InfoBaseID = New UUID();
	ConstantParameters.Insert("InfoBaseID", InfoBaseID);
	ConstantParameters.Insert("InfobaseIDPermanent", InfoBaseID);
	
	ConstantParameters.Insert("RegisterSystemInformation", False);
	ConstantParameters.Insert("RegisterSubsystemVersions", False);
	
	ConstantParameters.Insert("DumpRegistrationNextCreation", Date(1,1,1));
	ConstantParameters.Insert("DumpRegistrationCreationPeriod", 600);
	ConstantParameters.Insert("RegisterDumps", False);
	
	ConstantParameters.Insert("AggregationPeriodMinor", 60);
	ConstantParameters.Insert("AggregationPeriod", 600);
	ConstantParameters.Insert("DeletionPeriod", 3600);
	ConstantParameters.Insert("AggregationBoundary", Date(1,1,1));
	ConstantParameters.Insert("BusinessStatisticsNextSnapshot", Date(1,1,1));
	ConstantParameters.Insert("BusinessStatisticsSnapshotPeriod", 600);
	ConstantParameters.Insert("RegisterBusinessStatistics", False);
	
	ConstantParameters.Insert("ConfigurationStatisticsNextGeneration", Date(1,1,1));
	ConstantParameters.Insert("ConfigurationStatisticsGenerationPeriod", 86400);
	ConstantParameters.Insert("RegisterConfigurationStatistics", False);
	ConstantParameters.Insert("RegisterConfigurationSettings", False);
	
	ConstantParameters.Insert("EventLogErrorsNextGeneration", Date(1,1,1));
	ConstantParameters.Insert("EventLogErrorsGenerationPeriod", 86400);
	ConstantParameters.Insert("EventLogErrorsCount", 500);
	ConstantParameters.Insert("EventLogErrorsEvents", DriveServer.DriveLicenseErrorEventName());
	ConstantParameters.Insert("RegisterEventLogErrors", False);
	
	ConstantParameters.Insert("PerformanceMonitorEnabled", 0);
	
	ConstantParameters.Insert("RegisterPerformance", False);
	ConstantParameters.Insert("TopApdex", 10);
	ConstantParameters.Insert("RegisterTechnologicalPerformance", False);
	ConstantParameters.Insert("TopApdexTech", 10);
	ConstantParameters.Insert("RunPerformanceMeasurements", RunPerformanceMeasurements());
	
	ConstantParameters.Insert("SendDataNextGeneration", Date(1,1,1));
	ConstantParameters.Insert("SendDataGenerationPeriod", 607800);
	ConstantParameters.Insert("LastPackageDate", Date(1,1,1));
	ConstantParameters.Insert("LastPackageNumber", 0);
	ConstantParameters.Insert("PackagesToSend", 3);
	ConstantParameters.Insert("Server", "");
	ConstantParameters.Insert("ResourceAddress", "");
	ConstantParameters.Insert("DumpsResourceAddress", "");
	ConstantParameters.Insert("Port", 443);
	ConstantParameters.Insert("SecureConnection", True);
	
	ConstantParameters.Insert("SendDumpsFiles", 2);
	ConstantParameters.Insert("DumpOption", "");
	
	ConstantParameters.Insert("BasicChecksPassed", False); 
	ConstantParameters.Insert("RequestConfirmationBeforeSending", True);
	ConstantParameters.Insert("SendingResult", "");
	ConstantParameters.Insert("DumpsInformation", "");
	ConstantParameters.Insert("SpaceReserveDisabled", 40);
	ConstantParameters.Insert("SpaceReserveEnabled", 20);
	ConstantParameters.Insert("DumpCollectingEnd", Date(2017,1,1));
	
	ConstantParameters.Insert("FullDumpsCollectionEnabled", New Map);
	ConstantParameters.Insert("DumpInstances", New Map);
	ConstantParameters.Insert("DumpInstancesApproved", New Map);
	
	ConstantParameters.Insert("DumpsCheckDepth", 604800);
	ConstantParameters.Insert("MinDumpsCount", 10000);
	ConstantParameters.Insert("DumpCheckNext", Date(1,1,1));
	ConstantParameters.Insert("DumpsCheckFrequency", 14400);
	
	ConstantParameters.Insert("DumpType", "0");
	
	ConstantParameters.Insert("UserResponseTimeout", 14);
	ConstantParameters.Insert("ForceSendMinidumps", 0);
	ConstantParameters.Insert("NotificationDate2", Date(1,1,1));
	
	ConstantParameters.Insert("TestPackageSent", False);
	ConstantParameters.Insert("TestPackageSendingAttemptCount", 0);
	
	ConstantParameters.Insert("DiscoveryPackageSent", False);
	
	ConstantParameters.Insert("SetErrorHandlingSettingsForcibly", False);
	ConstantParameters.Insert("ErrorMessageDisplayVariant", "Auto");
	ConstantParameters.Insert("ErrorRegistrationServiceURL", "");
	ConstantParameters.Insert("SendAReport", "Auto");
	ConstantParameters.Insert("IncludeDetailErrorDescriptionInReport", "Auto");
	ConstantParameters.Insert("IncludeInfobaseInformationInReport", "Auto");
	
	ConstantParameters.Insert("ContactInformationRequest", 2);
	ConstantParameters.Insert("ContactInformation", "");
	ConstantParameters.Insert("ContactInformationComment1", "");
	ConstantParameters.Insert("PortalUsername", "");
	ConstantParameters.Insert("ContactInformationChanged", False);
	
	ConstantParameters.Insert("UpdateInstalled", False);
	
	Return ConstantParameters; 
EndFunction

Function GetMonitoringCenterParameters(Parameters = Undefined) Export
	
	ConstantParameters = Constants.MonitoringCenterParameters.Get().Get();
	If ConstantParameters = Undefined Then
		ConstantParameters = New Structure;
	EndIf;
	
	DefaultParameters = GetDefaultParameters();
	
	For Each CurParameter In DefaultParameters Do
		If Not ConstantParameters.Property(CurParameter.Key) Then
			ConstantParameters.Insert(CurParameter.Key, CurParameter.Value);
		EndIf;
	EndDo;
	
	If ConstantParameters = Undefined Then
		ConstantParameters = DefaultParameters;
	EndIf;
	
	If Parameters = Undefined Then
		Parameters = ConstantParameters;
		Parameters.Insert("Server", Constants.MonitoringCenterServer.Get());
		Parameters.Insert("Port", Constants.MonitoringCenterPort.Get());
	Else
		If TypeOf(Parameters) = Type("Structure") Then
			For Each CurParameter In Parameters Do
				Parameters[CurParameter.Key] = ConstantParameters[CurParameter.Key];
			EndDo;
			If Parameters.Property("Server") Then
				Parameters.Server = Constants.MonitoringCenterServer.Get();
			EndIf;
			If Parameters.Property("Port") Then
				Parameters.Port = Constants.MonitoringCenterPort.Get();
			EndIf;
		ElsIf TypeOf(Parameters) = Type("String") Then
			If Parameters = "Server" Then
				Parameters.Server = Constants.MonitoringCenterServer.Get();
			ElsIf Parameters = "Port" Then
				Parameters.Port = Constants.MonitoringCenterPort.Get();
			Else
				Parameters = ConstantParameters[Parameters];
			EndIf;
		EndIf;
	EndIf;
	
	ConstantParameters.Insert("RunPerformanceMeasurements", RunPerformanceMeasurements());
	
	Return Parameters;
	
EndFunction

Function SetSendingParameters(Parameters)
	SendOptions = New Structure;
	SendOptions.Insert("PerformanceMonitorEnabled");
	SendOptions.Insert("RunPerformanceMeasurements");
	SendOptions.Insert("SetErrorHandlingSettingsForcibly");
	GetMonitoringCenterParameters(SendOptions);
	
	SendOptions.Insert("RegisterSystemInformation", False);
	SendOptions.Insert("RegisterSubsystemVersions", False);
	SendOptions.Insert("RegisterDumps", False);
	SendOptions.Insert("RegisterBusinessStatistics", False);
	SendOptions.Insert("RegisterConfigurationStatistics", False);
	SendOptions.Insert("RegisterConfigurationSettings", False);
	SendOptions.Insert("RegisterPerformance", False);
	SendOptions.Insert("RegisterTechnologicalPerformance", False);
	SendOptions.Insert("RegisterEventLogErrors", False);
	SendOptions.Insert("SendingResult", "");
	SendOptions.Insert("DiscoveryPackageSent", True);
	SendOptions.Insert("ContactInformationChanged", False);
	
	ParametersMap = New Structure;
	ParametersMap.Insert("info", "RegisterSystemInformation");
	ParametersMap.Insert("versions", "RegisterSubsystemVersions");
	ParametersMap.Insert("dumps", "RegisterDumps");
	ParametersMap.Insert("business", "RegisterBusinessStatistics");
	ParametersMap.Insert("config", "RegisterConfigurationStatistics");
	ParametersMap.Insert("options", "RegisterConfigurationSettings");
	ParametersMap.Insert("perf", "RegisterPerformance");
	ParametersMap.Insert("internal_perf", "RegisterTechnologicalPerformance");
	ParametersMap.Insert("eventLogErrors", "RegisterEventLogErrors");
	
	Settings = Parameters.packetProperties;
	For Each CurSetting In Settings Do
		If ParametersMap.Property(CurSetting) Then
			Var_Key = ParametersMap[CurSetting];
			
			If SendOptions.Property(Var_Key) Then
				SendOptions[Var_Key] = True;
			EndIf;
		EndIf;
	EndDo;
	
	If Parameters.Property("settings") Then
		NewSettings = Parameters.settings;
		NewSettings = StrReplace(NewSettings, ";", Chars.LF);
		DefaultSettings = GetDefaultParameters();
		For CurRow = 1 To StrLineCount(NewSettings) Do
			CurSetting = StrGetLine(NewSettings, CurRow);
			CurSetting = StrReplace(CurSetting, "=", Chars.LF);
			
			Var_Key = StrGetLine(CurSetting, 1);
			Var_Key = KeyForIncomingSettings(Var_Key);
			Value = StrGetLine(CurSetting, 2);
			
			If DefaultSettings.Property(Var_Key) Then
				If TypeOf(DefaultSettings[Var_Key]) = Type("Number") Then
					DetailsNumber = New TypeDescription("Number");
					CastedValue = DetailsNumber.AdjustValue(Value);
					If Format(CastedValue, "NZ=0; NG=") = Value Then
						SendOptions.Insert(Var_Key, CastedValue);
					EndIf;
				ElsIf TypeOf(DefaultSettings[Var_Key]) = Type("String") Then
					SendOptions.Insert(Var_Key, Value);
				ElsIf TypeOf(DefaultSettings[Var_Key]) = Type("Boolean") Then
					DetailsBoolean = New TypeDescription("Boolean");
					CastedValue = DetailsBoolean.AdjustValue(Value);
					If Format(CastedValue, "BF=false; BT=true") = Value Then
						SendOptions.Insert(Var_Key, CastedValue);
					EndIf;
				ElsIf TypeOf(DefaultSettings[Var_Key]) = Type("Date") Then
					DetailsDate = New TypeDescription("Date");
					CastedValue = DetailsDate.AdjustValue(Value);
					If Format(CastedValue, "DF=yyyyMMddHHmmss") = Value Then
						SendOptions.Insert(Var_Key, CastedValue);
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If Parameters.Property("deliveryIntervalHours") Then
		SendOptions.Insert("SendDataGenerationPeriod", Parameters.deliveryIntervalHours * 60 * 60);
	EndIf;
	
	If SendOptions["RegisterPerformance"] Or SendOptions["RegisterTechnologicalPerformance"] Then
	
		If SendOptions.RunPerformanceMeasurements = Undefined Then
			SendOptions.PerformanceMonitorEnabled = 0;
	
		ElsIf SendOptions.PerformanceMonitorEnabled = 0 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 1;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 0 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 3;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 1;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 2 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 3;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 2 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 3 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		EndIf;
	Else
		
		If SendOptions.RunPerformanceMeasurements = Undefined Then
			SendOptions.PerformanceMonitorEnabled = 0;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 0 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 0;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 0 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 0;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 0;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 2 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 0;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 2 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		
		ElsIf SendOptions.PerformanceMonitorEnabled = 3 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		EndIf;
	EndIf;
	
	If Parameters.Property("foundCopy") And Parameters.foundCopy Then
		PerformActionsOnDetectCopy();
		SendOptions.Insert("DiscoveryPackageSent", False);
	EndIf;
	
	SavedSendingParameters = New Structure;
	SavedSendingParameters.Insert("SetErrorHandlingSettingsForcibly");
	SavedSendingParameters.Insert("ErrorMessageDisplayVariant"); 
	SavedSendingParameters.Insert("ErrorRegistrationServiceURL");
	SavedSendingParameters.Insert("SendAReport");
	SavedSendingParameters.Insert("IncludeDetailErrorDescriptionInReport");
	SavedSendingParameters.Insert("IncludeInfobaseInformationInReport");
	GetMonitoringCenterParameters(SavedSendingParameters);
	ProcessingResult = SettingErrorHandlingSettings(SavedSendingParameters, SendOptions);
	For Each KeyAndRecord In ProcessingResult Do
		SendOptions.Insert(KeyAndRecord.Key, KeyAndRecord.Value);	
	EndDo;

	BeginTransaction();
	Try
		If SendOptions.PerformanceMonitorEnabled = 0 And Not SendOptions.RunPerformanceMeasurements = Undefined Then
			ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
			ModulePerformanceMonitor.EnablePerformanceMeasurements(False);
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And Not SendOptions.RunPerformanceMeasurements = Undefined Then
			ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");	
			ModulePerformanceMonitor.EnablePerformanceMeasurements(True);
		EndIf;
		
		SetMonitoringCenterParameters(SendOptions);
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(NStr("ru = 'Центр мониторинга.Установка параметров отправки';
										|en = 'Monitoring center.Set sending parameters';pl = 'Centrum monitorowania.Ustaw parametry wysyłania';es_ES = 'Centro de Control. Configurar los parámetros de envío';es_CO = 'Centro de Control. Configurar los parámetros de envío';tr = 'İzleme merkezi. Gönderim parametrelerini ayarla';it = 'Centro di monitoraggio.Impostare parametri di invio';de = 'Überwachungszentrum.Sendeparameter festlegen'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
		Raise Error;
	EndTry;
	
	Return SendOptions;
	
EndFunction

Function KeyForIncomingSettings(Var_Key)
	Map = New Map;
	Map.Insert("SetErrorProcessingSettingsForcibly","SetErrorHandlingSettingsForcibly");
	Map.Insert("ErrorMessageDisplayVariant","ErrorMessageDisplayVariant");
	Map.Insert("ErrorRegistrationServiceURL","ErrorRegistrationServiceURL");
	Map.Insert("SendReport","SendAReport");
	Map.Insert("IncludeDetailErrorDescriptionInReport","IncludeDetailErrorDescriptionInReport");
	Map.Insert("IncludeInfobaseInformationInReport","IncludeInfobaseInformationInReport");	
	Value = Map.Get(Var_Key);
	If Value = Undefined Then
		Return Var_Key
	EndIf;
	Return Value;
EndFunction

Function SetMonitoringCenterParameters(NewParameters)
	
	Error = "Successfully";
	Block = New DataLock;
	Block.Add("Constant.MonitoringCenterParameters");
	Block.Add("Constant.MonitoringCenterServer");
	Block.Add("Constant.MonitoringCenterPort");
	
	BeginTransaction();
	
	Try
		Block.Lock();
		
		If NewParameters.Property("Server") Then
			Constants.MonitoringCenterServer.Set(NewParameters.Server);
		EndIf;
		If NewParameters.Property("Port") Then
			Constants.MonitoringCenterPort.Set(NewParameters.Port);
			If NewParameters.Port = 443 Then
				NewParameters.Insert("SecureConnection", True);
			EndIf;
		EndIf;
		
		Parameters = GetMonitoringCenterParameters();
		
		If NewParameters.Property("RunPerformanceMeasurements") Then
			NewParameters.Delete("RunPerformanceMeasurements");
		EndIf;
		
		For Each CurParameter In NewParameters Do
			If Not Parameters.Property(CurParameter.Key) Then
				Parameters.Insert(CurParameter.Key);
			EndIf;
			
			Parameters[CurParameter.Key] = CurParameter.Value;
		EndDo;
		
		Store = New ValueStorage(Parameters);
		Constants.MonitoringCenterParameters.Set(Store);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(NStr("ru = 'Центр мониторинга.Установка параметров центра мониторинга';
										|en = 'Monitoring center.Set monitoring center parameters';pl = 'Centrum monitorowania.Ustaw parametry centrum monitorowania';es_ES = 'Centro de Control. Establecer los parámetros del centro de control';es_CO = 'Centro de Control. Establecer los parámetros del centro de control';tr = 'İzleme merkezi. İzleme merkezi parametrelerini ayarla';it = 'Centro di monitoraggio.Impostare parametri centro di monitoraggio';de = 'Überwachungszentrum. Parameter des Überwachungszentrums festlegen'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
		Raise Error;
	EndTry;
	
	Return Error;
	
EndFunction

Procedure DeleteMonitoringCenterParameters()
	Try
		Parameters = New Structure;
		Store = New ValueStorage(Parameters);
		Constants.MonitoringCenterParameters.Set(Store);
	Except
		Error = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(NStr("ru = 'Центр мониторинга.Удалить параметры центра мониторинга';
										|en = 'Monitoring center.Delete monitoring center parameters ';pl = 'Centrum monitorowania.Usuń parametry centrum monitorowania ';es_ES = 'Centro de Control. Eliminar los parámetros del centro de control ';es_CO = 'Centro de Control. Eliminar los parámetros del centro de control ';tr = 'İzleme merkezi. İzleme merkezi parametrelerini sil';it = 'Centro di monitoraggio.Eliminare parametri centro di monitoraggio ';de = 'Überwachungszentrum. Parameter des Überwachungszentrums löschen '", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
		Raise Error;
	EndTry;
EndProcedure

Function SetMonitoringCenterParameter(Parameter, Value)
	
	Error = "Successfully";
	Block = New DataLock;
	Block.Add("Constant.MonitoringCenterParameters");
	Block.Add("Constant.MonitoringCenterServer");
	Block.Add("Constant.MonitoringCenterPort");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		If Parameter = "Server" Then
			Constants.MonitoringCenterServer.Set(Value);
		ElsIf Parameter = "Port" Then
			Constants.MonitoringCenterPort.Set(Value);
			If Value = 443 Then
				SetMonitoringCenterParameter("SecureConnection", True);
			EndIf;
		Else
			Parameters = GetMonitoringCenterParameters();
			If Not Parameters.Property(Parameter) Then
				Parameters.Insert(Parameter);
			EndIf;
			
			Parameters[Parameter] = Value;
			
			Store = New ValueStorage(Parameters);
			Constants.MonitoringCenterParameters.Set(Store);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(NStr("ru = 'Центр мониторинга.Установка параметров центра мониторинга';
										|en = 'Monitoring center.Set monitoring center parameters';pl = 'Centrum monitorowania.Ustaw parametry centrum monitorowania';es_ES = 'Centro de Control. Establecer los parámetros del centro de control';es_CO = 'Centro de Control. Establecer los parámetros del centro de control';tr = 'İzleme merkezi. İzleme merkezi parametrelerini ayarla';it = 'Centro di monitoraggio.Impostare parametri centro di monitoraggio';de = 'Überwachungszentrum. Parameter des Überwachungszentrums festlegen'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
		Raise Error;
	EndTry;
	
	Return Error;
	
EndFunction

Function GetSendServiceParameters()
	ServiceParameters = New Structure;
	
	ServiceParameters.Insert("EnableMonitoringCenter");
	ServiceParameters.Insert("ApplicationInformationProcessingCenter");
	ServiceParameters.Insert("InfoBaseID");
	ServiceParameters.Insert("Server");
	ServiceParameters.Insert("ResourceAddress");
	ServiceParameters.Insert("DumpsResourceAddress");
	ServiceParameters.Insert("Port");
	ServiceParameters.Insert("SecureConnection");
	
	GetMonitoringCenterParameters(ServiceParameters);
	
	ServiceParameters.Delete("EnableMonitoringCenter");
	ServiceParameters.Delete("ApplicationInformationProcessingCenter");
	
	Return ServiceParameters;
EndFunction

Function SetDefaultSendServiceParametersExternalCall(WithServerAndPort = False) Export
	SetDefaultSendServiceParameters(WithServerAndPort);
EndFunction

Procedure SetDefaultSendServiceParameters(WithServerAndPort = False)
	
	ServiceParameters = New Structure;
	ServiceParameters.Insert("ResourceAddress", "PultQMC/hs/PultQMC/v1/packet");
	ServiceParameters.Insert("DumpsResourceAddress", "PultQMC/hs/PultQMC/v1/dump/");
	
	If WithServerAndPort Then
		ServiceParameters.Insert("Server", "78.47.173.63");
		ServiceParameters.Insert("Port", 443);
		ServiceParameters.Insert("SecureConnection", True);
	EndIf;
	
	SetMonitoringCenterParameters(ServiceParameters);
	
EndProcedure

#EndRegion

#Region WorkWithSettingsFile

Function GetDumpsDirectory(DumpType = "0", StopCollectingFull = False) Export
	SettingsDirectory = GetTechnologicalLogSettingsDirectory();
	DumpsDirectory = FindDumpsDirectory(SettingsDirectory, DumpType, StopCollectingFull);
	
	Return DumpsDirectory;
EndFunction

Function GeneratePathWithSeparator(Path)
	If ValueIsFilled(Path) Then
		PathSeparator = GetServerPathSeparator();
		If Right(Path, 1) <> PathSeparator Then
			Path = Path + PathSeparator;
		EndIf;
	EndIf;
	
	Return Path;
EndFunction

Function FindDumpsDirectory(SettingsDirectory, DumpType, StopCollectingFull) 
	DumpsDirectory = New Structure("Path, DeleteDumps, ErrorDescription", "", False, "");
	
	SettingsFileName = "logcfg.xml";
	DirectoryPath = GeneratePathWithSeparator(SettingsDirectory.Path);
	
	FullDumpsCollectionEnabled = GetMonitoringCenterParameters("FullDumpsCollectionEnabled")[ComputerName()];
		
	File = New File(DirectoryPath + SettingsFileName);
	If File.Exist() Then
		Try
			XMLReader = New XMLReader;
			XMLReader.OpenFile(File.FullName, New XMLReaderSettings(,,,,,,,True, True));
			While XMLReader.Read() Do
				If XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.HasName And Upper(XMLReader.Description) = "DUMP" Then
					DumpsParameters = New Structure;
					If XMLReader.AttributeCount() > 0 Then
						While XMLReader.ReadAttribute() Do
							DumpsParameters.Insert(XMLReader.LocalName, XMLReader.Value);
						EndDo;
					EndIf;
				EndIf;
			EndDo;
		Except
			Message = NStr("ru = 'Ошибка чтения файла настроек технологического журнала';
							|en = 'An error occurred when reading a setting file of the technological log';pl = 'Błąd odczytu pliku konfiguracji dziennika technologicznego';es_ES = 'Se ha producido un error al leer un archivo de configuración del registro tecnológico';es_CO = 'Se ha producido un error al leer un archivo de configuración del registro tecnológico';tr = 'Teknik kaydın ayar dosyası okunurken hata oluştu';it = 'Si è verificato un errore durante la lettura di un file di impostazione del registro tecnologico';de = 'Fehler ist beim Lesen einer Einstellungsdatei im technologischen Logbuch aufgetregen'");
			Message = Message + " """ +File.FullName + """." + Chars.LF;
			Message = Message + NStr("ru = 'Скорее всего файл поврежден. Регистрация дампов не возможна. Удалите поврежденный файл или восстановите настройки.';
										|en = 'The file is likely corrupt. Cannot register dumps. Delete the corrupt file or reset settings.';pl = 'Prawdopodobnie plik jest uszkodzony. Nie można zarejestrować zrzutów. Usuń uszkodzony plik lub zresetuj ustawienia.';es_ES = 'Es probable que el archivo esté corrupto. No se pueden registrar los volcados. Elimine el archivo corrupto o restablezca la configuración.';es_CO = 'Es probable que el archivo esté corrupto. No se pueden registrar los volcados. Elimine el archivo corrupto o restablezca la configuración.';tr = 'Dosya bozuk olabilir. Dökümler oluşturulamıyor. Bozuk dosyayı silin veya ayarları sıfırlayın.';it = 'Il file è probabilmente corrotto. Impossibile registrare dump. Eliminare il file corrotto o ripristinare le impostazioni.';de = 'Die Datei ist wahrscheinlich defekt. Fehler beim Registrieren von Dumps. Löschen Sie die defekte Datei oder setzen die Einstellungen zurück.'");
			
			WriteLogEvent(NStr("ru = 'Центр мониторинга';
											|en = 'Monitoring center';pl = 'Centrum monitorowania';es_ES = 'Centro del control';es_CO = 'Centro del control';tr = 'İzleme merkezi';it = 'Centro di monitoraggio';de = 'Überwachungszentrum'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Warning,,,Message);
			
			DumpsDirectory.Path = Undefined;
			DumpsDirectory.ErrorDescription = NStr("ru = 'Ошибка чтения файла настроек технологического журнала';
												|en = 'An error occurred when reading a setting file of the technological log';pl = 'Błąd odczytu pliku konfiguracji dziennika technologicznego';es_ES = 'Se ha producido un error al leer un archivo de configuración del registro tecnológico';es_CO = 'Se ha producido un error al leer un archivo de configuración del registro tecnológico';tr = 'Teknik kaydın ayar dosyası okunurken hata oluştu';it = 'Si è verificato un errore durante la lettura di un file di impostazione del registro tecnologico';de = 'Fehler ist beim Lesen einer Einstellungsdatei im technologischen Logbuch aufgetregen'");
			Return DumpsDirectory;
		EndTry;
		
		If DumpsParameters <> Undefined Then
			If Not DumpsParameters.Property("location") Or Not DumpsParameters.Property("create") Or Not DumpsParameters.Property("type") Then
				Message = NStr("ru = 'Ошибка секции сбора дампов в файле настроек технологического журнала';
								|en = 'Dump collection section error in the setting file of technological log';pl = 'Błąd sekcji zbierania zrzutów w pliku ustawień lub dziennika technologicznego';es_ES = 'Error en la sección de recogida de datos en el archivo de configuración del registro tecnológico';es_CO = 'Error en la sección de recogida de datos en el archivo de configuración del registro tecnológico';tr = 'Teknik kaydın ayar dosyasında döküm toplama bölümü hatası';it = 'Errore nella sezione di raccolta dei dump nel file di impostazione del registro tecnologico';de = 'Fehler von Dump-Sammelabschnitt in der Einstellungsdatei oder im technologischen Logbuch'");
				Message = Message + " """ +File.FullName + """." + Chars.LF;
				Message = Message + NStr("ru = 'Регистрация дампов не возможна. Удалите файл или восстановите настройки.';
											|en = 'Cannot register dumps. Remove the file or restore the settings.';pl = 'Nie można zarejestrować zrzutów. Usuń plik lub przywróć ustawienia.';es_ES = 'No se pueden registrar los volcados. Elimine el archivo o restaure la configuración.';es_CO = 'No se pueden registrar los volcados. Elimine el archivo o restaure la configuración.';tr = 'Dökümler kaydedilemiyor. Dosyayı kaldırın veya ayarları geri yükleyin.';it = 'Impossibile registrare dump. Rimuovere il file o ripristinare le impostazioni.';de = 'Fehler beim Registrieren von Dumps. Entfernen Sie die Datei oder stellen die Einstellungen wieder her.'");
				XMLReader.Close();
				
				WriteLogEvent(NStr("ru = 'Центр мониторинга';
												|en = 'Monitoring center';pl = 'Centrum monitorowania';es_ES = 'Centro del control';es_CO = 'Centro del control';tr = 'İzleme merkezi';it = 'Centro di monitoraggio';de = 'Überwachungszentrum'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Warning,,,Message);
				
				DumpsDirectory.Path = Undefined;
				DumpsDirectory.ErrorDescription = NStr("ru = 'Ошибка секции сбора дампов в файле настроек технологического журнала';
													|en = 'Dump collection section error in the setting file of technological log';pl = 'Błąd sekcji zbierania zrzutów w pliku ustawień lub dziennika technologicznego';es_ES = 'Error en la sección de recogida de datos en el archivo de configuración del registro tecnológico';es_CO = 'Error en la sección de recogida de datos en el archivo de configuración del registro tecnológico';tr = 'Teknik kaydın ayar dosyasında döküm toplama bölümü hatası';it = 'Errore nella sezione di raccolta dei dump nel file di impostazione del registro tecnologico';de = 'Fehler von Dump-Sammelabschnitt in der Einstellungsdatei oder im technologischen Logbuch'");
				Return DumpsDirectory;
			EndIf;
		EndIf;
				
		If DumpsParameters <> Undefined Then
			DumpsDirectory.Path = GeneratePathWithSeparator(DumpsParameters.Location);
			If StrFind(DumpsDirectory.Path, "80af5716-b134-4b1c-a38d-4658d1ac4196") > 0 And Not FullDumpsCollectionEnabled = True Then
				DumpsDirectory.DeleteDumps = True;
			EndIf;
			XMLReader.Close();
			
			If StrFind(DumpsDirectory.Path, "80af5716-b134-4b1c-a38d-4658d1ac4196") > 0 Then
				If DumpsParameters.type <> DumpType Then
					CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType);
				ElsIf Not DumpsParameters.Property("externaldump") Then
					CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType);
				ElsIf DumpsParameters.externaldump <> "1" Then
					CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType);
				EndIf;
			EndIf;
		Else
			XMLReader.Close();
			CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType);
		EndIf;
			
	Else
		DumpsDirectory.Path = CreateDumpsCollectionSettingsFile(DirectoryPath, DumpType);
		If Not FullDumpsCollectionEnabled = True Then
			DumpsDirectory.DeleteDumps = True;
		EndIf;
		If DumpsDirectory.Path = Undefined Then
			DumpsDirectory.ErrorDescription = NStr("ru = 'Ошибка создания файла настроек технологического журнала. Регистрация дампов не возможна.';
												|en = 'An error occurred while creating the setting file of the technological log. Cannot register dumps.';pl = 'Błąd podczas utworzenia pliku ustawień dziennika technologicznego. Nie można zarejestrować zrzutów.';es_ES = 'Se ha producido un error al crear el archivo de configuración del registro tecnológico. No se pueden registrar los volcados.';es_CO = 'Se ha producido un error al crear el archivo de configuración del registro tecnológico. No se pueden registrar los volcados.';tr = 'Teknik kaydın ayar dosyası oluşturulurken hata oluştu. Dökümler kaydedilemiyor.';it = 'Si è verificato un errore durante la creazione del file di impostazione del registro tecnologico. Impossibile registrare dump.';de = 'Fehler ist beim Erstellen der Einstellungsdatei im technologischen Logbuch aufgetreten. Fehler beim Registrieren von Dumps.'");
		EndIf;
	EndIf;
	
	Return DumpsDirectory;
EndFunction

Function CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType)
	
	ID = "80af5716-b134-4b1c-a38d-4658d1ac4196";
	
	XMLReader.OpenFile(File.FullName, New XMLReaderSettings(,,,,,,,False, False));
	
	DOMBuilder = New DOMBuilder;
	DOMDocument = DOMBuilder.Read(XMLReader);
	DOMDocument.Normalize();
	XMLReader.Close();
		If DOMDocument.HasChildNodes() Then
		FirstChild = DOMDocument.FirstChild;
		If Upper(FirstChild.NodeName) = "CONFIG" Then
			DefaultPath = StrFind(DumpsDirectory.Path, ID) > 0;
			If IsBlankString(DumpsDirectory.Path) Or DefaultPath Then
				DumpsDirectory.Path = GeneratePathWithSeparator(GeneratePathWithSeparator(TempFilesDir() + "Dumps") + ID);
			EndIf;
			DumpsDirectory.DeleteDumps = True;
			
			ItemsDumps = DOMDocument.GetElementByTagName("dump");
			If ItemsDumps.Count() = 0 Then
				
				ItemDumps = DOMDocument.CreateElement("dump");
				ItemDumps.SetAttribute("location", DumpsDirectory.Path);
				ItemDumps.SetAttribute("create", "1");
				ItemDumps.SetAttribute("type", DumpType);
				ItemDumps.SetAttribute("externaldump", "1");
				FirstChild.AppendChild(ItemDumps);
			Else
				For Each CurItem In ItemsDumps Do
					CurItem.SetAttribute("externaldump", "1");
					CurItem.SetAttribute("type", DumpType);
					CurItem.SetAttribute("location", DumpsDirectory.Path);
				EndDo;
			EndIf;
			
			Try
				XMLWriter = New XMLWriter;
				DOMWriter = New DOMWriter; 
				XMLWriter.OpenFile(File.FullName, New XMLWriterSettings(,,True,True));
				DOMWriter.Write(DOMDocument, XMLWriter);
				XMLWriter.Close();
			Except
				Message = NStr("ru = 'Ошибка записи файла настроек технологического журнала. Регистрация дампов не возможна.';
								|en = 'An error occurred while writing the setting file of the technological log. Cannot register dumps.';pl = 'Błąd podczas zapisywania pliku ustawień dziennika technologicznego. Nie można zarejestrować zrzutów.';es_ES = 'Se ha producido un error al escribir el archivo de configuración del registro tecnológico. No se pueden registrar los volcados.';es_CO = 'Se ha producido un error al escribir el archivo de configuración del registro tecnológico. No se pueden registrar los volcados.';tr = 'Teknik kaydın ayar dosyası kaydedilirken hata oluştu. Dökümler kaydedilemiyor.';it = 'Si è verificato un errore durante la scrittura del file di impostazione del registro tecnologico. Impossibile registrare dump.';de = 'Fehler ist beim Speichern der Einstellungsdatei im technologischen Logbuch aufgetreten. Fehler beim Registrieren von Dumps.'");
				Message = Message + " """ +File.FullName + """." + Chars.LF;
				Message = Message + DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(NStr("ru = 'Центр мониторинга - регистрация дампов';
												|en = 'Monitoring center - dump registration';pl = 'Centrum monitorowania - rejestracja zrzutu';es_ES = 'Centro de control - registro de volcado';es_CO = 'Centro de control - registro de volcado';tr = 'İzleme merkezi - döküm kaydı';it = 'Centro di monitoraggio - registrazione dump';de = 'Überwachungszentrum - Dump-Registrieren'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Warning,,,Message);
				
				DumpsDirectory.Path = Undefined;
				DumpsDirectory.ErrorDescription = NStr("ru = 'Ошибка записи файла настроек технологического журнала. Регистрация дампов не возможна.';
													|en = 'An error occurred while writing the setting file of the technological log. Cannot register dumps.';pl = 'Błąd podczas zapisywania pliku ustawień dziennika technologicznego. Nie można zarejestrować zrzutów.';es_ES = 'Se ha producido un error al escribir el archivo de configuración del registro tecnológico. No se pueden registrar los volcados.';es_CO = 'Se ha producido un error al escribir el archivo de configuración del registro tecnológico. No se pueden registrar los volcados.';tr = 'Teknik kaydın ayar dosyası kaydedilirken hata oluştu. Dökümler kaydedilemiyor.';it = 'Si è verificato un errore durante la scrittura del file di impostazione del registro tecnologico. Impossibile registrare dump.';de = 'Fehler ist beim Speichern der Einstellungsdatei im technologischen Logbuch aufgetreten. Fehler beim Registrieren von Dumps.'");
				Return DumpsDirectory;
			EndTry;
		EndIf;
	EndIf;
EndFunction

Function CreateDumpsCollectionSettingsFile(DirectoryPath, DumpType)
	SettingsFileName = "logcfg.xml";
	
	ID = "80af5716-b134-4b1c-a38d-4658d1ac4196";
	DumpsDirectory = GeneratePathWithSeparator(GeneratePathWithSeparator(TempFilesDir() + "Dumps") + ID);
	
	Try
		XMLWriter = New XMLWriter;
		XMLWriter.OpenFile(DirectoryPath + SettingsFileName);
		DumpsCollection =
		"<config xmlns=""http://v8.1c.ru/v8/tech-log"">
		|	<dump location=""" + DumpsDirectory + """ create=""1"" type=""" + DumpType + """ externaldump=""1""/>
		|</config>";
		XMLWriter.WriteRaw(DumpsCollection);
		XMLWriter.Close();
	Except
		Message = NStr("ru = 'Ошибка создания файла настроек технологического журнала. Регистрация дампов не возможна.';
						|en = 'An error occurred while creating the setting file of the technological log. Cannot register dumps.';pl = 'Błąd podczas utworzenia pliku ustawień dziennika technologicznego. Nie można zarejestrować zrzutów.';es_ES = 'Se ha producido un error al crear el archivo de configuración del registro tecnológico. No se pueden registrar los volcados.';es_CO = 'Se ha producido un error al crear el archivo de configuración del registro tecnológico. No se pueden registrar los volcados.';tr = 'Teknik kaydın ayar dosyası oluşturulurken hata oluştu. Dökümler kaydedilemiyor.';it = 'Si è verificato un errore durante la creazione del file di impostazione del registro tecnologico. Impossibile registrare dump.';de = 'Fehler ist beim Erstellen der Einstellungsdatei im technologischen Logbuch aufgetreten. Fehler beim Registrieren von Dumps.'");
		Message = Message + " """ +DirectoryPath + SettingsFileName + """." + Chars.LF;
		Message = Message + DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(NStr("ru = 'Центр мониторинга';
										|en = 'Monitoring center';pl = 'Centrum monitorowania';es_ES = 'Centro del control';es_CO = 'Centro del control';tr = 'İzleme merkezi';it = 'Centro di monitoraggio';de = 'Überwachungszentrum'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Warning,,,Message);
		
		DumpsDirectory = Undefined;
		
	EndTry;
	
	Return DumpsDirectory;
EndFunction

Function GetTechnologicalLogSettingsDirectory()
	SettingsDirectory = New Structure("Path, Exists, ErrorDescription", "", False, "");
	
	SettingsDirectories = New Array;
	
	SettingsFileName = "logcfg.xml";
	SettingsConfigurationFileName = "conf.cfg";
	
	BinDir = GeneratePathWithSeparator(BinDir());
		
	SearchForDirectory = True;
	Counter = 0;
	DirectoryPath = GeneratePathWithSeparator(BinDir + "conf");
	While SearchForDirectory = True Do
		If SettingsDirectories.Find(DirectoryPath) <> Undefined Then
			SettingsDirectory.Path = "";
			SettingsDirectory.Exists = False;
			SettingsDirectory.ErrorDescription = NStr("ru = 'Обнаружена циклическая ссылка';
													|en = 'Circular ref is found';pl = 'Wykryto odnośnik cykliczny';es_ES = 'No se ha encontrado la referencia circular';es_CO = 'No se ha encontrado la referencia circular';tr = 'Döngüsel referans bulundu';it = 'Rif circolare trovato';de = 'Zirkelbezug ist aufgefunden'", CommonClientServer.DefaultLanguageCode());
			
			SearchForDirectory = False;
		Else
			FullSettingsFileName = DirectoryPath + SettingsFileName;
			SettingsFile = New File(FullSettingsFileName);
			If SettingsFile.Exist() Then
				SettingsDirectory.Path = DirectoryPath;
				SettingsDirectory.Exists = True;
				SettingsDirectory.ErrorDescription = "";
				
				SearchForDirectory = False;
			Else
				SettingsDirectories.Add(DirectoryPath);
				
				FullSettingsConfigurationFileName = DirectoryPath + SettingsConfigurationFileName;
				SettingsConfigurationFile = New File(FullSettingsConfigurationFileName);
				If SettingsConfigurationFile.Exist() Then
					DirectoryPath = GetDirectoryFromSettingsConfigurationFile(SettingsConfigurationFile);
					If DirectoryPath.Exists Then
						DirectoryPath = GeneratePathWithSeparator(DirectoryPath.Path);
					Else
						SettingsDirectory.Path = DirectoryPath.Path;
						SettingsDirectory.Exists = DirectoryPath.Exists;
						SettingsDirectory.ErrorDescription = DirectoryPath.ErrorDescription;
						
						SearchForDirectory = False;
					EndIf;
				Else
					SettingsDirectory.Path = "";
					SettingsDirectory.Exists = False;
					SettingsDirectory.ErrorDescription = NStr("ru = 'Файл конфигурации настроек в каталоге не существует';
															|en = 'The setting configuration file does not exist in the directory.';pl = 'Plik konfiguracji ustawień nie istnieje w katalogu.';es_ES = 'El archivo de configuración de ajustes no existe en el catálogo.';es_CO = 'El archivo de configuración de ajustes no existe en el catálogo.';tr = 'Ayar yapılandırma dosyası dizinde mevcut değil.';it = 'Il file di impostazione di configurazione non esiste nella directory.';de = 'Die Einstellungskonfigurationsdatei existiert im Verzeichnis nicht.'", 
						CommonClientServer.DefaultLanguageCode()) + " " + DirectoryPath;
					
					SearchForDirectory = False;
				EndIf;
			EndIf;
		EndIf;
		
		Counter = Counter + 1;
		
		If Counter >= 100 Then
			SearchForDirectory = False;
		EndIf;
	EndDo;
	
	Return SettingsDirectory;
EndFunction

Function GetDirectoryFromSettingsConfigurationFile(SettingsConfigurationFile)
	SettingsDirectory = New Structure("Path, Exists, ErrorDescription", "", False, "");
	
	SearchString = "ConfLocation=";
	SearchStringLength = StrLen(SearchString);
	
	Text = New TextReader(SettingsConfigurationFile.FullName);
	Data = Text.Read();
	
	SearchIndex = StrFind(Data, SearchString);
	If SearchIndex > 0 Then
		DataBuffer1 = Right(Data, StrLen(Data) - (SearchIndex + SearchStringLength - 1));
		SearchIndex = StrFind(DataBuffer1, Chars.LF);
		If SearchIndex > 0 Then
			SettingsDirectory.Path = GeneratePathWithSeparator(Left(DataBuffer1, SearchIndex - 1));
		Else
			SettingsDirectory.Path = GeneratePathWithSeparator(DataBuffer1);
		EndIf;
		SettingsDirectory.Exists = True;
		SettingsDirectory.ErrorDescription = "";
	Else
		SettingsDirectory.Path = GeneratePathWithSeparator(SettingsConfigurationFile.Path);
		SettingsDirectory.Exists = False;
		SettingsDirectory.ErrorDescription = NStr("ru = 'Не найдена секция ConfLocation в файле';
												|en = 'The ConfLocation section is not found in the file';pl = 'Nie znaleziono sekcji ConfLocation w pliku';es_ES = 'La sección ConfLocation no se encuentra en el archivo';es_CO = 'La sección ConfLocation no se encuentra en el archivo';tr = 'Dosyada ConfLocation bölümü bulunamadı';it = 'La sezione ConfLocation non è stata trovata nel file';de = 'Der Abschnitt ConfLocation ist in der Datei nicht gefunden'", CommonClientServer.DefaultLanguageCode()) + " " + SettingsConfigurationFile.FullName;
	EndIf;
		
	Return SettingsDirectory;
EndFunction

#EndRegion

#Region WorkWithDumps

Function DumpDetails(Val FileName)
	FileName = StrReplace(FileName, "_", Chars.LF);
	
	DumpStructure = New Structure;
	If StrLineCount(FileName) >= 3  Then
		DumpStructure.Insert("Process", StrGetLine(FileName, 1));
		DumpStructure.Insert("PlatformVersion", StrGetLine(FileName, 2));
		DumpStructure.Insert("Offset", StrGetLine(FileName, 3));
	Else
		SysInfo = New SystemInfo;
		DumpStructure.Insert("Process", "userdump");
		DumpStructure.Insert("PlatformVersion", SysInfo.AppVersion);
		DumpStructure.Insert("Offset", "ffffffff");
	EndIf;
	
	Return DumpStructure;
EndFunction

Function PlatformVersionToNumber(Version) Export
	PlatformVersion = StrReplace(Version, ".", Chars.LF);
	PlatformVersionNumber = Number(Left(StrGetLine(PlatformVersion, 1) + "000000", 6)
		+ Left(StrGetLine(PlatformVersion, 2) + "000000", 6)
		+ Left(StrGetLine(PlatformVersion, 3) + "000000", 6)
		+ Left(StrGetLine(PlatformVersion, 4) + "000000", 6));
	
	Return PlatformVersionNumber;
EndFunction

#EndRegion

#Region WorkWithSystemInformation
Function GetSystemInformation()
	SysInfo = New SystemInfo;
	
	Result = New Structure;
	Result.Insert("ComputerName", Common.CheckSumString(ComputerName()));
	Result.Insert("OSVersion", String(SysInfo.OSVersion));
	Result.Insert("AppVersion", String(SysInfo.AppVersion));
	Result.Insert("ClientID", String(SysInfo.ClientID));
	Result.Insert("RAM", String(SysInfo.RAM));
	Result.Insert("Processor", String(SysInfo.Processor));
	Result.Insert("PlatformType", String(SysInfo.PlatformType));
	Result.Insert("CurrentLanguage", String(CurrentLanguage()));
	Result.Insert("CurrentLocaleCode", String(CurrentLocaleCode()));
	Result.Insert("CurrentSystemLanguage", String(CurrentSystemLanguage()));
	Result.Insert("CurrentRunMode", String(CurrentRunMode()));
	Result.Insert("SessionTimeZone", String(SessionTimeZone()));
	
	Return Result;
EndFunction

Function SubsystemsVersions()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SubsystemsVersions.SubsystemName AS SubsystemName,
	|	SubsystemsVersions.Version AS Version
	|FROM
	|	InformationRegister.SubsystemsVersions AS SubsystemsVersions";
	
	Result = Query.Execute();
	
	Subsystems = New Structure;
	Selection = Result.Select();
	While Selection.Next() Do
		Subsystems.Insert(Selection.SubsystemName, Selection.Version);
	EndDo;
	
	Return Subsystems;
EndFunction

#EndRegion

#Region WorkWithConfigurationExtensions

Function DataOnUsedExtensions()

	ExtensionStructure = New Structure;
	
	ExtensionsArray = ConfigurationExtensions.Get();
	ExtensionsUsed = ExtensionsArray.Count()>0;
	ExtensionStructure.Insert("ExtensionsUsage", ExtensionsUsed);
	
	If Not ExtensionsUsed Then
		Return ExtensionStructure;
	EndIf;
	
	ExtensionsDetailsArray = New Array;	
	For Each Extension In ExtensionsArray Do
		ExtensionDetails = New Structure("Description, Version, Purpose, SafeMode, UnsafeActionProtection, Synonym");
		FillPropertyValues(ExtensionDetails, Extension);
		ExtensionDetails.Insert("UnsafeActionProtection", ?(ExtensionDetails.UnsafeActionProtection = Undefined, False, ExtensionDetails.UnsafeActionProtection.UnsafeOperationWarnings));
		ExtensionDetails.Insert("Purpose", String(ExtensionDetails.Purpose));		
		ExtensionsDetailsArray.Add(ExtensionDetails);
	EndDo;
	
	ExtensionStructure.Insert("ExtensionsDetails1", ExtensionsDetailsArray);	
	
	ExtensionsMetadata = New Map;
	MetadataDetails = MetadataDetails();
	For Each StrWrite In MetadataDetails Do
		AddExtensionsInformation(StrWrite.Key, StrWrite.Value, ExtensionsMetadata);
	EndDo;
	
	ExtensionStructure.Insert("ExtensionsMetadata", ExtensionsMetadata);
	
	Return ExtensionStructure;
	
EndFunction

Procedure AddExtensionsInformation(ObjectClass, ObjectArchitecture, ExtensionsMetadata)
	For Each MetadataObject In Metadata[ObjectClass] Do

		For Each StructureItem In ObjectArchitecture Do
			If StructureItem.Value = "Recursively" Then
				AddExtensionsInformationRecursively(MetadataObject, StructureItem.Key, ObjectArchitecture, ExtensionsMetadata);
			EndIf;
			For Each SubordinateObject In MetadataObject[StructureItem.Key] Do
				ObjectExtension = SubordinateObject.ConfigurationExtension(); 
				If ObjectExtension = Undefined Then
					Continue;
				EndIf;		
				ExtensionsMetadata.Insert(SubordinateObject.FullName(), ObjectExtension.Description);
			EndDo;
		EndDo;
		
		ObjectExtension = MetadataObject.ConfigurationExtension(); 
		If ObjectExtension = Undefined Then
			If MetadataObject.ChangedByConfigurationExtensions() Then
				ExtensionsMetadata.Insert(MetadataObject.FullName(), True);		
			EndIf;
			Continue;
		EndIf;		
		ExtensionsMetadata.Insert(MetadataObject.FullName(), ObjectExtension.Description);
	EndDo;

EndProcedure

Procedure AddExtensionsInformationRecursively(Object, RecursiveAttributeName, ObjectArchitecture, ExtensionsMetadata)
	For Each RecursiveObject In Object[RecursiveAttributeName] Do
		For Each StructureItem In ObjectArchitecture Do
			If StructureItem.Value = "Recursively" Then
				AddExtensionsInformationRecursively(RecursiveObject, StructureItem.Key, ObjectArchitecture, ExtensionsMetadata);
			EndIf;
			For Each SubordinateObject In RecursiveObject[StructureItem.Key] Do
				ObjectExtension = SubordinateObject.ConfigurationExtension();
				If ObjectExtension = Undefined Then
					Continue;
				EndIf;		
				ExtensionsMetadata.Insert(SubordinateObject.FullName(), ObjectExtension.Description);
			EndDo;
		EndDo;
		
		ObjectExtension = RecursiveObject.ConfigurationExtension();
		If ObjectExtension = Undefined Then
			Continue;
		EndIf;		
		ExtensionsMetadata.Insert(RecursiveObject.FullName(), ObjectExtension.Description);	
	EndDo;
EndProcedure
 
Function MetadataDetails()
	MetadataDetails = New Map;
	MetadataDetails.Insert("Subsystems", New Structure("Subsystems", "Recursively"));
	MetadataDetails.Insert("CommonModules", New Structure);
	MetadataDetails.Insert("SessionParameters", New Structure);
	MetadataDetails.Insert("CommonAttributes", New Structure);
	MetadataDetails.Insert("CommonAttributes", New Structure);
	MetadataDetails.Insert("ExchangePlans", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("FilterCriteria", New Structure("Forms, Commands"));
	MetadataDetails.Insert("EventSubscriptions", New Structure);
	MetadataDetails.Insert("ScheduledJobs", New Structure);
	MetadataDetails.Insert("FunctionalOptions", New Structure);
	MetadataDetails.Insert("FunctionalOptionsParameters", New Structure);
	MetadataDetails.Insert("DefinedTypes", New Structure);
	MetadataDetails.Insert("SettingsStorages", New Structure("Forms, Templates"));
	MetadataDetails.Insert("CommonForms", New Structure);
	MetadataDetails.Insert("CommonCommands", New Structure);
	MetadataDetails.Insert("CommandGroups", New Structure);
	MetadataDetails.Insert("CommonTemplates", New Structure);
	MetadataDetails.Insert("CommonPictures", New Structure);
	MetadataDetails.Insert("XDTOPackages", New Structure);
	MetadataDetails.Insert("WebServices", New Structure);
	MetadataDetails.Insert("HTTPServices", New Structure);
	MetadataDetails.Insert("WSReferences", New Structure);
	MetadataDetails.Insert("StyleItems", New Structure);
	MetadataDetails.Insert("Languages", New Structure);	
	MetadataDetails.Insert("Constants", New Structure);
	MetadataDetails.Insert("Catalogs", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("Documents", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("DocumentJournals", New Structure("Columns, Forms, Commands, Templates"));
	MetadataDetails.Insert("Enums", New Structure("EnumValues, Forms, Commands, Templates"));
	MetadataDetails.Insert("Reports", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("DataProcessors", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("ChartsOfCharacteristicTypes", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("ChartsOfAccounts", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("ChartsOfCalculationTypes", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("InformationRegisters", New Structure("Dimensions, Resources, Attributes, Forms, Commands, Templates"));
	MetadataDetails.Insert("AccumulationRegisters", New Structure("Dimensions, Resources, Attributes, Forms, Commands, Templates"));
	MetadataDetails.Insert("AccountingRegisters", New Structure("Dimensions, Resources, Attributes, Forms, Commands, Templates"));
	MetadataDetails.Insert("CalculationRegisters", New Structure("Dimensions, Resources, Attributes, Forms, Commands, Templates"));
	MetadataDetails.Insert("BusinessProcesses", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("Tasks", New Structure("AddressingAttributes, Attributes, TabularSections, Forms, Commands, Templates"));
	
	Return MetadataDetails;
EndFunction

#EndRegion

#Region WorkWithAccessRightsSubsystem

Function DataOnRolesUsage()
	DataOnRolesUsage = New Structure;
	
	Query = New Query(RolesUsageQueryText());
	Query.SetParameter("EmptyUID", CommonClientServer.BlankUUID());
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	ResultPackage = Query.ExecuteBatch();
	
	IndexColumns = New Map;
	IndexColumns.Insert("ProfileUID", New Map);
	IndexColumns.Insert("RoleDescription", New Map);
	AdditionalParameters = New Map;
	AdditionalParameters.Insert("IndexColumns", IndexColumns);
	
	ProfilesRoles = ResultPackage[8].Unload();
	ProfilesRoles.Columns.Add("ProfileUID", New TypeDescription("String"));
	For Each String In ProfilesRoles Do
		String.ProfileUID = String(String.Profile.UUID());
	EndDo;
	ProfilesRoles.Columns.Delete("Profile");
	
	ProfilesRolesStructure = GenerateJSONStructure("RolesOfProfiles", ProfilesRoles, AdditionalParameters);
	DataOnRolesUsage.Insert("RolesOfProfiles", ProfilesRolesStructure["RolesOfProfiles"]);
	
	IndexColumns = New Map;
	IndexColumns.Insert("ProfileUID", New Map);
	IndexColumns.Insert("Description", New Map);
	IndexColumns.Insert("SuppliedDataID", New Map);
	AdditionalParameters = New Map;
	AdditionalParameters.Insert("IndexColumns", IndexColumns);
	
	ProfilesData = ResultPackage[7].Unload();
	ProfilesData.Columns.Add("ProfileUID", New TypeDescription("String"));
	ProfilesData.Columns.Add("SuppliedDataIDRow", New TypeDescription("String"));
	For Each String In ProfilesData Do
		String.SuppliedDataIDRow = String(String.SuppliedDataID);
		String.ProfileUID = String(String.Profile.UUID());
	EndDo;
	ProfilesData.Columns.Delete("SuppliedDataID");
	ProfilesData.Columns.SuppliedDataIDRow.Name = "SuppliedDataID";
	ProfilesData.Columns.Delete("Profile");
	
	Profiles = GenerateJSONStructure("Profiles", ProfilesData, AdditionalParameters);
	DataOnRolesUsage.Insert("Profiles", Profiles["Profiles"]);
	
	Return DataOnRolesUsage;
EndFunction

Function RolesUsageQueryText()
	
	Return
	"SELECT
	|	UserGroupCompositions.UsersGroup AS UsersGroup,
	|	UsersInfo.User AS User,
	|	CASE
	|		WHEN DATEDIFF(UsersInfo.LastActivityDate, &CurrentDate, DAY) <= 7
	|			THEN 1
	|		ELSE 0
	|	END AS ActivePerWeek,
	|	CASE
	|		WHEN DATEDIFF(UsersInfo.LastActivityDate, &CurrentDate, DAY) <= 30
	|			THEN 1
	|		ELSE 0
	|	END AS ActivePerMonth
	|INTO TT_GroupCompositionsAndActivity
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON UserGroupCompositions.User = UsersInfo.User
	|WHERE
	|	UserGroupCompositions.Used
	|	AND NOT UserGroupCompositions.User.IBUserID = &EmptyUID
	|
	|INDEX BY
	|	UsersGroup,
	|	User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupProfiles.Ref AS Profile,
	|	AccessGroupProfiles.SuppliedDataID AS SuppliedDataID,
	|	AccessGroupProfiles.SuppliedProfileChanged AS SuppliedProfileChanged,
	|	AccessGroupProfiles.Description AS Description,
	|	AccessGroupsUsers.Ref AS AccessGroup,
	|	AccessGroupsUsers.Ref.User = VALUE(Catalog.Users.EmptyRef)
	|		OR AccessGroupsUsers.Ref.User = VALUE(Catalog.ExternalUsers.EmptyRef)
	|		OR AccessGroupsUsers.Ref.User = Undefined AS CommonAccessGroup,
	|	AccessGroupsUsers.User AS UserTS,
	|	UserGroupCompositions.User AS UserIR,
	|	UserGroupCompositions.ActivePerWeek AS ActivePerWeek,
	|	UserGroupCompositions.ActivePerMonth AS ActivePerMonth
	|INTO TT_ProfileData
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		INNER JOIN TT_GroupCompositionsAndActivity AS UserGroupCompositions
	|		ON AccessGroupsUsers.User = UserGroupCompositions.UsersGroup
	|		INNER JOIN Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|		ON (AccessGroupProfiles.Ref = AccessGroupsUsers.Ref.Profile)
	|			И (NOT AccessGroupsUsers.Ref.Profile.DeletionMark)
	|WHERE
	|	NOT AccessGroupsUsers.Ref.Profile.DeletionMark
	|
	|GROUP BY
	|	AccessGroupProfiles.Ref,
	|	AccessGroupProfiles.Description,
	|	AccessGroupsUsers.User,
	|	UserGroupCompositions.User,
	|	UserGroupCompositions.ActivePerWeek,
	|	UserGroupCompositions.ActivePerMonth,
	|	AccessGroupsUsers.Ref,
	|	AccessGroupsUsers.Ref.User = VALUE(Catalog.Users.EmptyRef)
	|		OR AccessGroupsUsers.Ref.User = VALUE(Catalog.ExternalUsers.EmptyRef)
	|		OR AccessGroupsUsers.Ref.User = Undefined,
	|	AccessGroupProfiles.SuppliedDataID,
	|	AccessGroupProfiles.SuppliedProfileChanged
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_ProfileData.Profile AS Profile,
	|	TT_ProfileData.Description AS Description,
	|	TT_ProfileData.SuppliedDataID AS SuppliedDataID,
	|	TT_ProfileData.SuppliedProfileChanged AS SuppliedProfileChanged
	|INTO Profiles
	|FROM
	|	TT_ProfileData AS TT_ProfileData
	|
	|INDEX BY
	|	Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Profile AS Profile,
	|	SUM(CASE
	|			WHEN NOT AccessGroupProfilesAccessKinds.AccessKind ЕСТЬ NULL
	|				THEN 1
	|			ELSE 0
	|		END) AS AccessKindTotal,
	|	SUM(CASE
	|			WHEN ISNULL(AccessGroupProfilesAccessKinds.PresetAccessKind, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS PresetAccessKindTotal
	|INTO TT_AccessKinds
	|FROM
	|	Profiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroupProfiles.AccessKinds AS AccessGroupProfilesAccessKinds
	|		ON Profiles.Profile = AccessGroupProfilesAccessKinds.Ref
	|
	|GROUP BY
	|	Profiles.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Nested.Profile AS Profile,
	|	COUNT(DISTINCT Nested.AccessGroup) AS AccessGroup,
	|	SUM(CASE
	|			WHEN NOT Nested.CommonAccessGroup
	|				THEN 1
	|			ELSE 0
	|		END) AS PersonalGroup
	|INTO TT_AccessGroups
	|FROM
	|	(SELECT
	|		TT_ProfileData.Profile AS Profile,
	|		TT_ProfileData.AccessGroup AS AccessGroup,
	|		TT_ProfileData.CommonAccessGroup AS CommonAccessGroup
	|	FROM
	|		TT_ProfileData AS TT_ProfileData
	|	
	|	GROUP BY
	|		TT_ProfileData.Profile,
	|		TT_ProfileData.AccessGroup,
	|		TT_ProfileData.CommonAccessGroup) AS Nested
	|
	|GROUP BY
	|	Nested.Profile
	|
	|INDEX BY
	|	Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Nested.Profile AS Profile,
	|	SUM(CASE
	|			WHEN Nested.UserTS REFS Catalog.UserGroups
	|				THEN 1
	|			ELSE 0
	|		END) AS UserGroups,
	|	SUM(CASE
	|			WHEN Nested.UserTS REFS Catalog.ExternalUsersGroups
	|				THEN 1
	|			ELSE 0
	|		END) AS ExternalUsersGroups
	|INTO TT_UserGroups
	|FROM
	|	(SELECT
	|		TT_ProfileData.Profile AS Profile,
	|		TT_ProfileData.UserTS AS UserTS
	|	FROM
	|		TT_ProfileData AS TT_ProfileData
	|	
	|	GROUP BY
	|		TT_ProfileData.Profile,
	|		TT_ProfileData.UserTS) AS Nested
	|
	|GROUP BY
	|	Nested.Profile
	|
	|INDEX BY
	|	Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Nested.Profile AS Profile,
	|	SUM(CASE
	|			WHEN Nested.UserIR REFS Catalog.Users
	|				THEN 1
	|			ELSE 0
	|		END) AS Users,
	|	SUM(CASE
	|			WHEN Nested.UserIR REFS Catalog.ExternalUsers
	|				THEN 1
	|			ELSE 0
	|		END) AS ExternalUsers,
	|	SUM(Nested.ActivePerWeek) AS ActivePerWeek,
	|	SUM(Nested.ActivePerMonth) AS ActivePerMonth
	|INTO TT_ProfileUsers
	|FROM
	|	(SELECT
	|		TT_ProfileData.Profile AS Profile,
	|		TT_ProfileData.UserIR AS UserIR,
	|		SUM(TT_ProfileData.ActivePerWeek) AS ActivePerWeek,
	|		SUM(TT_ProfileData.ActivePerMonth) AS ActivePerMonth
	|	FROM
	|		TT_ProfileData AS TT_ProfileData
	|	
	|	GROUP BY
	|		TT_ProfileData.Profile,
	|		TT_ProfileData.UserIR) AS Nested
	|
	|GROUP BY
	|	Nested.Profile
	|
	|INDEX BY
	|	Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Profile AS Profile,
	|	Profiles.Description AS Description,
	|	Profiles.SuppliedDataID AS SuppliedDataID,
	|	Profiles.SuppliedProfileChanged AS SuppliedProfileChanged,
	|	ISNULL(TT_AccessGroups.AccessGroup, 0) AS AccessGroup,
	|	ISNULL(TT_AccessGroups.PersonalGroup, 0) AS PersonalGroup,
	|	ISNULL(TT_UserGroups.UserGroups, 0) AS UserGroups,
	|	ISNULL(TT_UserGroups.ExternalUsersGroups, 0) AS ExternalUsersGroups,
	|	ISNULL(TT_ProfileUsers.Users, 0) AS Users,
	|	ISNULL(TT_ProfileUsers.ExternalUsers, 0) AS ExternalUsers,
	|	ISNULL(TT_ProfileUsers.ActivePerWeek, 0) AS ActivePerWeek,
	|	ISNULL(TT_ProfileUsers.ActivePerMonth, 0) AS ActivePerMonth,
	|	ISNULL(TT_AccessKinds.AccessKindTotal, 0) AS AccessKindTotal,
	|	ISNULL(TT_AccessKinds.PresetAccessKindTotal, 0) AS PresetAccessKindTotal
	|FROM
	|	Profiles AS Profiles
	|		LEFT JOIN TT_ProfileUsers AS TT_ProfileUsers
	|		ON Profiles.Profile = TT_ProfileUsers.Profile
	|		LEFT JOIN TT_UserGroups AS TT_UserGroups
	|		ON Profiles.Profile = TT_UserGroups.Profile
	|		LEFT JOIN TT_AccessGroups AS TT_AccessGroups
	|		ON Profiles.Profile = TT_AccessGroups.Profile
	|		LEFT JOIN TT_AccessKinds AS TT_AccessKinds
	|		ON Profiles.Profile = TT_AccessKinds.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Profiles.Profile AS Profile,
	|	ISNULL(AccessGroupProfilesRoles.Role.Description, """") AS RoleDescription
	|FROM
	|	Profiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		ON Profiles.Profile = AccessGroupProfilesRoles.Ref
	|			И (Profiles.SuppliedDataID = &EmptyUID
	|				OR Profiles.SuppliedProfileChanged)
	|
	|ORDER BY
	|	Profile";
	
КонецФункции

#EndRegion

#Region WorkInSeparationByDataAreasMode

Function SeparationByDataAreasEnabled() Export
	
	If Common.SubsystemExists("SaaSTechnology.Core") Then
		SaaSCommonModule = Common.CommonModule("SaaS");
		SeparationByDataAreasEnabled = SaaSCommonModule.DataSeparationEnabled();
	Else
		SeparationByDataAreasEnabled = False;
	EndIf;
	
	Return SeparationByDataAreasEnabled;
	
EndFunction

#EndRegion

#Region WorkInDIBMode

Function IsMasterNode()
	SetPrivilegedMode(True);
	
	Return Not ExchangePlans.MasterNode() <> Undefined;
EndFunction

#EndRegion

#Region CommonFunctions

Function EventLogEventMonitoringCenterDumpDeletion()
	Return NStr("ru = 'Центр мониторинга.Удаление дампа';
				|en = 'Monitoring center.Removing the dump';pl = 'Centrum monitorowania.Usunięcie zrzutu';es_ES = 'Centro de control. Borrado del volcado';es_CO = 'Centro de control. Borrado del volcado';tr = 'İzleme merkezi. Döküm siliniyor';it = 'Centro di monitoraggio.Rimuovere dump';de = 'Überwachungszentrum.Entfernen von Dump'", CommonClientServer.DefaultLanguageCode());
EndFunction

Function EventLogEventMonitoringCenterParseStatisticsOperationsBuffer()
	Return NStr("ru = 'Центр мониторинга.Разобрать буфер операций статистики';
				|en = 'Monitoring center.Parse the buffer of statistics operations ';pl = 'Centrum monitorowania.Przeanalizuj bufor operacji statystyk ';es_ES = 'Centro de control. Analizar el buffer de operaciones estadísticas ';es_CO = 'Centro de control. Analizar el buffer de operaciones estadísticas ';tr = 'İzleme merkezi. İstatistik işlemlerinin arabelleğini ayrıştır';it = 'Centro di monitoraggio.Smontare buffer delle operazioni statistiche ';de = 'Überwachungszentrum.Puffer von Operationen der Statistik analysieren '", CommonClientServer.DefaultLanguageCode());
EndFunction
#EndRegion

#Region ClientInformation

Procedure WriteClientScreensStatistics(Parameters)
	
	Screens = Parameters["ClientInformation"]["ClientScreens"]; 
	UserHash = Parameters["ClientInformation"]["ClientParameters1"]["UserHash"];
	
	For Each CurScreen In Screens Do
		
		StatisticsOperationName = "ClientStatistics.SystemInformation.MonitorResolution." + CurScreen;
		MonitoringCenter.WriteBusinessStatisticsOperationDay(StatisticsOperationName, UserHash, 1);
		
		StatisticsOperationName = StatisticsOperationName + "." + Parameters["ClientInformation"]["SystemInformation"]["UserAgentInformation"]; 
		MonitoringCenter.WriteBusinessStatisticsOperationDay(StatisticsOperationName, UserHash, 1);
		
	EndDo;
	
	MonitorCountString = Format(Screens.Count(), "NG=0");
	MonitoringCenter.WriteBusinessStatisticsOperationDay("ClientStatistics.SystemInformation.MonitorCount." + MonitorCountString, UserHash, 1);
	
EndProcedure

Procedure WriteSystemInformation(Parameters)
	
	UserHash = Parameters["ClientInformation"]["ClientParameters1"]["UserHash"];
	
	For Each CurSystemInfo In Parameters["ClientInformation"]["SystemInformation"] Do
		StatisticsOperationName = "ClientStatistics.SystemInformation." + CurSystemInfo.Key + "." + CurSystemInfo.Value;
		MonitoringCenter.WriteBusinessStatisticsOperationDay(StatisticsOperationName, UserHash, 1);
	EndDo;
	
EndProcedure

Procedure WriteClientInformation(Parameters)
	
	UserHash = Parameters["ClientInformation"]["ClientParameters1"]["UserHash"];
	
	WriteUserActivity(UserHash);
	
	StatisticsOperationName = "ClientStatistics.ActiveWindows";
	Value =  Parameters["ClientInformation"]["ActiveWindows"];
	MonitoringCenter.WriteBusinessStatisticsOperationHour(StatisticsOperationName, UserHash, Value);
	
EndProcedure

Procedure WriteUserActivity(UserHash)
	StatisticsOperationName = "ClientStatistics.ActiveUsers";
	MonitoringCenter.WriteBusinessStatisticsOperationHour(StatisticsOperationName, UserHash, 1);
EndProcedure

Procedure WriteDataFromClient(Parameters)
	
	CurDate = CurrentUniversalDate();
	
	Measurements = Parameters["Measurements"];
	For Each MeasurementsOfType In Measurements Do
		
		EntryType = MeasurementsOfType.Key;
		
		If EntryType = 0 Then
			WriteDataFromClientExact(MeasurementsOfType.Value);
		Else
			WriteDataFromClientUnique(MeasurementsOfType.Value, EntryType, CurDate);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WriteDataFromClientExact(Measurements)
	
	InformationRegisters.StatisticsOperationsClipboard.WriteBusinessStatisticsOperations(Measurements);
			
EndProcedure

Procedure WriteDataFromClientUnique(Measurements, EntryType, CurDate)
	
	If EntryType = 1 Then
		RecordPeriod = BegOfHour(CurDate);
	ElsIf EntryType = 2 Then
		RecordPeriod = BegOfDay(CurDate);
	EndIf;
	
	WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType, RecordPeriod");
	For Each CurMeasurement In Measurements Do
		
		WriteParameters.OperationName = CurMeasurement.Value.StatisticsOperation;
		WriteParameters.UniqueKey = CurMeasurement.Value.Key;
		WriteParameters.Value = CurMeasurement.Value.Value;
		WriteParameters.Replace = CurMeasurement.Value.Replace;
		WriteParameters.EntryType = EntryType;
		WriteParameters.RecordPeriod = RecordPeriod;
		
		WriteBusinessStatisticsOperationInternal(WriteParameters);	
		
	EndDo;
	
EndProcedure

#EndRegion

Procedure InitialFilling() Export
	
	If SeparationByDataAreasEnabled() Then
		Return;
	EndIf;
	
	IsNewBase = (Constants.MonitoringCenterParameters.Get().Get() = Undefined);
	
	CurDate = CurrentUniversalDate();
	
	EnableMonitoringCenter = GetMonitoringCenterParameters("EnableMonitoringCenter");
	
	DeleteMonitoringCenterParameters();
	MonitoringCenterParameters = GetDefaultParameters();
	
	If Common.FileInfobase() Then
		MonitoringCenterParameters.BusinessStatisticsSnapshotPeriod = 3600;
	EndIf;
	
	MonitoringCenterParameters.DumpRegistrationNextCreation = CurDate + MonitoringCenterParameters.DumpRegistrationCreationPeriod;
	MonitoringCenterParameters.BusinessStatisticsNextSnapshot = CurDate + MonitoringCenterParameters.BusinessStatisticsSnapshotPeriod;
	MonitoringCenterParameters.ConfigurationStatisticsNextGeneration = CurDate + MonitoringCenterParameters.ConfigurationStatisticsGenerationPeriod;
	MonitoringCenterParameters.EventLogErrorsNextGeneration = CurDate + MonitoringCenterParameters.EventLogErrorsGenerationPeriod;
	
	RNG = New RandomNumberGenerator(CurrentUniversalDateInMilliseconds());
	SendingDelta = RNG.RandomNumber(0, 86400);
	MonitoringCenterParameters.SendDataNextGeneration = CurDate + SendingDelta;
	
	MonitoringCenterParameters.AggregationPeriodMinor = 600;
	MonitoringCenterParameters.AggregationPeriod = 3600;
	MonitoringCenterParameters.DeletionPeriod = 86400;
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		MonitoringCenterParameters.EnableMonitoringCenter = True;
	Else
		If IsNewBase Then
			EnableMonitoringCenter = True;
			ScheduledJob = GetScheduledJobExternalCall("StatisticsDataCollectionAndSending", True);
			SetDefaultScheduleExternalCall(ScheduledJob);
		EndIf;
		MonitoringCenterParameters.EnableMonitoringCenter = EnableMonitoringCenter;
	EndIf;
	
	SetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If EnableMonitoringCenter Then
		SetDefaultSendServiceParameters();
	EndIf;
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		ScheduledJob = GetScheduledJob("StatisticsDataCollectionAndSending", True);
		SetDefaultSchedule(ScheduledJob);
	EndIf;
	
EndProcedure

Procedure AddInfobaseIDPermanent() Export
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	MonitoringCenterParameters.Insert("InfobaseIDPermanent", MonitoringCenterParameters.InfoBaseID);
	SetMonitoringCenterParameters(MonitoringCenterParameters);
	
EndProcedure

Procedure EnableSendingInfo(Parameters) Export
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter"));
	
	If MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter Then
		Parameters.ProcessingCompleted = True;
		Return;
	EndIf;
	MonitoringCenterParameters = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter", True, False);
	SetMonitoringCenterParameters(MonitoringCenterParameters);
	ScheduledJob = GetScheduledJob("StatisticsDataCollectionAndSending", True);
	SetDefaultSchedule(ScheduledJob);
	
	Parameters.ProcessingCompleted = True;
EndProcedure

Procedure EnableSendingInfoFilling(Parameters) Export
	
EndProcedure

Procedure WriteBusinessStatisticsOperationInternal(WriteParameters) Export
	
	RecordPeriod = WriteParameters.RecordPeriod;
	EntryType = WriteParameters.EntryType;
	Var_Key = WriteParameters.UniqueKey;
	StatisticsOperation = MonitoringCenterCached.GetStatisticsOperationRef(WriteParameters.OperationName);
	Value = WriteParameters.Value;
	Replace = WriteParameters.Replace;
	
	InformationRegisters.StatisticsMeasurements.WriteBusinessStatisticsOperation(RecordPeriod, EntryType, Var_Key, StatisticsOperation, Value, Replace);
	
EndProcedure

Procedure PerformActionsOnDetectCopy()
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	MonitoringCenterParameters.InfoBaseID = New UUID();
	MonitoringCenterParameters.LastPackageNumber = 0;
	
	SetMonitoringCenterParameters(MonitoringCenterParameters);
	
	InformationRegisters.PackagesToSend.Clear();
	
EndProcedure

Procedure SetSessionSeparation(Use, DataArea = Undefined)
	
	If Common.SubsystemExists("SaaSTechnology.Core") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		ModuleSaaS.SetSessionSeparation(Use, DataArea);
	EndIf;
	
EndProcedure

Function NotificationOfDumpsParameters()
	ParametersToGet = New Structure;
	ParametersToGet.Insert("SendDumpsFiles");
	ParametersToGet.Insert("BasicChecksPassed");
	ParametersToGet.Insert("DumpInstances");
	ParametersToGet.Insert("DumpOption");
	ParametersToGet.Insert("DumpType");
	ParametersToGet.Insert("RequestConfirmationBeforeSending");
	ParametersToGet.Insert("DumpsInformation");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(ParametersToGet);
	
	RequestForGettingDumps = MonitoringCenterParameters.SendDumpsFiles = 2
								And MonitoringCenterParameters.BasicChecksPassed;
									
	HasDumps = MonitoringCenterParameters.Property("DumpInstances") And MonitoringCenterParameters.DumpInstances.Count();
	SendingRequest = MonitoringCenterParameters.SendDumpsFiles = 1
						And Not IsBlankString(MonitoringCenterParameters.DumpOption)
						And HasDumps
						And MonitoringCenterParameters.RequestConfirmationBeforeSending
						And MonitoringCenterParameters.DumpType = "3"
						And Not IsBlankString(MonitoringCenterParameters.DumpsInformation)
						And MonitoringCenterParameters.BasicChecksPassed;
						
	NotificationOfDumpsParameters = New Structure;
	NotificationOfDumpsParameters.Insert("RequestForGettingDumps", RequestForGettingDumps);
	NotificationOfDumpsParameters.Insert("SendingRequest", SendingRequest);
	NotificationOfDumpsParameters.Insert("DumpsInformation", MonitoringCenterParameters.DumpsInformation);
	
	Return NotificationOfDumpsParameters;
EndFunction

#Region DumpsCollectionAndSending

Procedure CollectAndSendDumps(FromClientAtServer = False, JobID = "") Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ErrorReportCollectionAndSending);
	
	DumpsCollectionAndSendingParameters = GetMonitoringCenterParameters();
	DumpOption = DumpsCollectionAndSendingParameters.DumpOption;
	ComputerName = ComputerName();
	DumpTypeChanged = False;
	
	If DumpsCollectionAndSendingParameters.SendDumpsFiles = 0 Then
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("SendingResult", NStr("ru = 'Пользователь отказал в предоставлении дампов.';
																		|en = 'User refused to submit dumps.';pl = 'Użytkownik odmówił przesyłania zrzutów.';es_ES = 'El usuario se negó a enviar los volcados.';es_CO = 'El usuario se negó a enviar los volcados.';tr = 'Kullanıcı döküm göndermeyi reddetti.';it = 'L''utente ha rifiutati di trasmettere dump.';de = 'Der Benutzer lehnte Einreichen von Dumps ab.'"));
		SetPrivilegedMode(False);
		StopFullDumpsCollection();
		Return;
	EndIf;
	
	If IsBlankString(DumpOption) Then
		Return;
	EndIf;
	
	If CurrentSessionDate() >= DumpsCollectionAndSendingParameters.DumpCollectingEnd Then
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("SendingResult", NStr("ru = 'Сбор дампов прекращен по таймауту.';
																		|en = 'Dump collection timed out.';pl = 'Przekroczono limit czasu zbierania zrzutów.';es_ES = 'La recogida del volcado ha pasado.';es_CO = 'La recogida del volcado ha pasado.';tr = 'Döküm toplama zaman aşımına uğradı.';it = 'Collezione dump scaduta.';de = 'Dump-Sammeln abgelaufen.'"));	
		SetPrivilegedMode(False);
		StopFullDumpsCollection();
		Return;
	EndIf;
	
	If Not IsMasterNode() Then 
		Return;
	EndIf;
	
	DumpRequirement = DumpIsRequired(DumpOption, DumpOption);
	
	If Not DumpRequirement.Required2 Then
		StopFullDumpsCollection();
		Return;
	Else
		If DumpRequirement.DumpType <> DumpsCollectionAndSendingParameters.DumpType 
			And (DumpRequirement.DumpType = "0" 
				Or DumpsCollectionAndSendingParameters.SendDumpsFiles = 1 
				And DumpRequirement.DumpType = "3") Then			
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("DumpType", DumpRequirement.DumpType);
			DumpsCollectionAndSendingParameters.DumpType = DumpRequirement.DumpType;
			SetPrivilegedMode(False);
			DumpTypeChanged = True;
		EndIf;   		
	EndIf;
	
	DumpType = DumpsCollectionAndSendingParameters.DumpType;
	DumpsDirectory = GetDumpsDirectory(DumpType);
	DumpsCollectionAndSendingParameters.Insert("DumpsDirectory", DumpsDirectory.Path);
	If DumpsDirectory.Path = Undefined Then
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("SendingResult", DumpsDirectory.ErrorDescription);
		SetPrivilegedMode(False);
		StopFullDumpsCollection();
		Return;	
	Else
		If DumpsCollectionAndSendingParameters.SendDumpsFiles = 1
			Or DumpsCollectionAndSendingParameters.ForceSendMinidumps = 1
			And DumpsCollectionAndSendingParameters.DumpType = "0" Then
			DumpsCollectionAndSendingParameters.FullDumpsCollectionEnabled.Insert(ComputerName, True);
		EndIf;
	EndIf;
	
	SeparatorPosition = StrFind(DumpsDirectory.Path, GetServerPathSeparator());
	If SeparatorPosition = 0 Then
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("SendingResult", NStr("ru = 'Не удалось определить букву диска';
																		|en = 'Cannot determine the drive letter';pl = 'Nie można określić litery dysku';es_ES = 'No se puede determinar la letra de la unidad';es_CO = 'No se puede determinar la letra de la unidad';tr = 'Sürücü harfi belirlenemiyor';it = 'Impossibile determinare lettera unità';de = 'Fehler beim Ermitteln von Drive-Buchstabe'"));
		SetPrivilegedMode(False);
		StopFullDumpsCollection();
		Return;
	EndIf;
	DriveLetter = Left(DumpsDirectory.Path, SeparatorPosition-1);
	
	If DumpsCollectionAndSendingParameters.FullDumpsCollectionEnabled[ComputerName] = True Then
		
		If IsBlankString(JobID) Then
			JobID = "ExecutionAtServer";
		EndIf;
		
		If DumpTypeChanged Then
			FilesDeleted(DumpsDirectory.Path);
		Else
			CollectDumps(DumpsCollectionAndSendingParameters);
		EndIf;
		
		SendDumps(DumpsCollectionAndSendingParameters);
		
		MeasurementResult = FreeSpaceOnHardDrive(DriveLetter, FromClientAtServer);
		If Not MeasurementResult.Successfully Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("SendingResult", MeasurementResult.ErrorDescription);
			SetPrivilegedMode(False);
			StopFullDumpsCollection();
			Return;
		EndIf;
		
		If MeasurementResult.Value/1024 < DumpsCollectionAndSendingParameters.SpaceReserveEnabled
			And DumpType = "3" Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("SendingResult", NStr("ru = 'Недостаточно свободного места для хранения дампов. Сбор дампов будет отключен.';
																			|en = 'There is not enough free space to store dumps. Dump collection will be disabled.';pl = 'Niewystarczająco miejsca do przechowywania zrzutów. Zbieranie zrzutów zostanie wyłączone.';es_ES = 'No hay suficiente espacio libre para almacenar los volcados. La recogida de volcados se desactivará.';es_CO = 'No hay suficiente espacio libre para almacenar los volcados. La recogida de volcados se desactivará.';tr = 'Dökümleri saklamak için yeterli alan yok. Döküm toplama devre dışı bırakılacak.';it = 'Non vi è spazio sufficiente per salvare i dump. La raccolta di dump sarà disattivata.';de = 'Es gibt nicht genügend freien Speicherplatz für Speichern von Dumps. Dump-Sammeln wird deaktiviert.'"));	
			SetPrivilegedMode(False);
			StopFullDumpsCollection();
			Return;
		EndIf;
		
		FullDumpsCollectionEnabled = GetMonitoringCenterParameters("FullDumpsCollectionEnabled");
		FullDumpsCollectionEnabled.Insert(ComputerName, True);
		SetPrivilegedMode(True);
		SetMonitoringCenterParameters(New Structure("BasicChecksPassed, FullDumpsCollectionEnabled, SendingResult", True, FullDumpsCollectionEnabled, ""));
		SetPrivilegedMode(False);
		
	Else
		MeasurementResult = FreeSpaceOnHardDrive(DriveLetter, FromClientAtServer);
		If Not MeasurementResult.Successfully Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("SendingResult", MeasurementResult.ErrorDescription);
			SetPrivilegedMode(False);
			StopFullDumpsCollection();
			Return;
		EndIf;
		
		If MeasurementResult.Value/1024 < DumpsCollectionAndSendingParameters.SpaceReserveDisabled
			And DumpType = "3" Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("SendingResult", NStr("ru = 'Недостаточно свободного места для сбора дампов.';
																			|en = 'There is not enough free space to collect dumps.';pl = 'Niewystarczająco miejsca do zbierania zrzutów.';es_ES = 'No hay suficiente espacio libre para recoger los volcados.';es_CO = 'No hay suficiente espacio libre para recoger los volcados.';tr = 'Dökümleri toplamak için yeterli alan yok.';it = 'Non vi è abbastanza spazio libero per raccogliere i dump.';de = 'Es gibt nicht genügend freien Speicherplatz für Sammeln von Dumps.'"));	
			SetPrivilegedMode(False);
			StopFullDumpsCollection();
			Return;
		EndIf;
		
		SetPrivilegedMode(True);
		SetMonitoringCenterParameters(New Structure("BasicChecksPassed, SendingResult", True, ""));
		SetPrivilegedMode(False);
				
		
	EndIf;
	
	DeleteObsoleteFiles(DumpOption, DumpsDirectory.Path);
			
EndProcedure

Procedure CollectDumps(Parameters)
	
	DumpsDirectory = Parameters.DumpsDirectory;
	
	PropertyName = ?(Parameters.RequestConfirmationBeforeSending And Parameters.DumpType = "3", "DumpInstances", "DumpInstancesApproved");
	
	If Not Parameters.Property(PropertyName) Then
		Parameters.Insert(PropertyName, New Map);	
	EndIf;
	
	ComputerName = ComputerName();
		
	DumpsFiles = FindFiles(DumpsDirectory, "*.mdmp");
	HasChanges = False;
	For Each DumpFile In DumpsFiles Do	    
		
		If StrFind(DumpFile.BaseName, "00000000") > 0 Then
			FilesDeleted(DumpFile.FullName);
			Continue;
		EndIf;
		
		DumpStructure = DumpDetails(DumpFile.Description);
	 	
		DumpOption = DumpStructure.Process + "_" + DumpStructure.PlatformVersion + "_" + DumpStructure.Offset;
						
		DumpRequirement = DumpIsRequired(DumpOption, Parameters.DumpOption, Parameters.DumpType);
		If DumpRequirement.Required2 Then
			
			ArchiveName = DumpsDirectory + DumpOption + ".zip"; 
			
			ZipFileWriter = New ZipFileWriter();
			ZipFileWriter.Open(ArchiveName,,,ZIPCompressionMethod.Deflate);
			ZipFileWriter.Add(DumpFile.FullName);
			ZipFileWriter.Write();
			
			ArchiveFile1 = New File(ArchiveName);
			Size = Round(ArchiveFile1.Size()/1024/1024,3);
			
			DumpData = New Structure;
			DumpData.Insert("FullName", ArchiveName);
			DumpData.Insert("Size", Size);
			DumpData.Insert("ComputerName", ComputerName);
			
			Parameters[PropertyName].Insert(DumpOption, DumpData);
			
			HasChanges = True;
			
		EndIf;
		
		FilesDeleted(DumpFile.FullName);
		
	EndDo;
	
	If HasChanges Then 
		MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure(PropertyName));
		For Each Record In Parameters[PropertyName] Do
			MonitoringCenterParameters[PropertyName].Insert(Record.Key, Record.Value);	
		EndDo;
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter(PropertyName, MonitoringCenterParameters[PropertyName]);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

Procedure SendDumps(Parameters)
	
	Parameters.Insert("DumpInstancesApproved", GetMonitoringCenterParameters("DumpInstancesApproved"));
	
	If Parameters.RequestConfirmationBeforeSending And Parameters.DumpType = "3" Then
		
		If Parameters.Property("DumpInstances") And Parameters.DumpInstances.Count() Then
	
			TemplateRequestForSending = NStr("ru = 'Для отправки подготовлены отчеты об ошибках (%1 шт.)
		                             |Общий объем данных: %2 МБ.
		                             |Отправить указанные файлы для анализа в фирму ""1С""?';
									|en = 'Error reports (%1 pcs.) are ready to be sent
									|Total data volume: %2 MB.
									|Send the specified files for analysis to 1C company?';pl = 'Raporty o błędach (%1 szt.) są gotowe do wysyłki
		                             |Łączna objętość danych: %2 MB.
		                             |Wyślij określone pliki do analizy do firmy 1C company?';
		                             |es_ES = 'Los informes de error (%1 pcs.) están listos para ser enviados
		                             |Volumen total de datos: %2 MB.
		                             |¿Envío de los archivos especificados para su análisis a 1C Company?';
		                             |es_CO = 'Los informes de error (%1 pcs.) están listos para ser enviados
		                             |Volumen total de datos: %2 MB.
		                             |¿Envío de los archivos especificados para su análisis a 1C Company?';
		                             |tr = 'Hata raporları (%1 adet) gönderime hazır
		                             |Toplam veri hacmi: %2 MB.
		                             |Belirtilen dosyalar analiz için 1C şirketine gönderilsin mi?';
		                             |it = 'I report di errore (%1 pz.) sono pronti per essere inviati
		                             |Volume totale dati: %2 MB.
		                             |Inviare i file indicati per l''analisi a 1C company?';
		                             |de = 'Fehlerbericht (%1 St.) sind für Senden bereit
		                             |Gesamtdatenvolumen: %2 MB.
		                             |Die bezeichneten Dateien für Analysieren bei 1C company senden?'");	
			
			TotalSpace = 0;
			TotalPieces = 0;
						
			For Each Record In Parameters.DumpInstances Do
				
				DumpOption = Record.Key;
				DumpData = Record.Value;
				
				DumpRequirement = DumpIsRequired(DumpOption, Parameters.DumpOption, Parameters.DumpType);
				If DumpRequirement.Required2 Then
					TotalPieces = TotalPieces + 1;
					TotalSpace = TotalSpace + DumpData.Size;
				Else
					FilesDeleted(DumpData.FullName);
				EndIf;
				
			EndDo;
			
			RequestForSending = StringFunctionsClientServer.SubstituteParametersToString(TemplateRequestForSending, TotalPieces, Format(TotalSpace,"NFD=; NZ=0"));
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("DumpsInformation", RequestForSending);
			SetPrivilegedMode(False);
			
		EndIf;
		
	Else
		For Each Record In Parameters.DumpInstances Do
			Parameters.DumpInstancesApproved.Insert(Record.Key, Record.Value);
		EndDo;
		
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("DumpInstancesApproved", Parameters.DumpInstancesApproved);
		SetPrivilegedMode(False);
		
	EndIf;             
	
	ComputerName = ComputerName();
	RequiredDump = Parameters.DumpOption;
	
	ArrayOfSent = New Array;
	For Each Record In Parameters.DumpInstancesApproved Do
		If ComputerName <> Record.Value.ComputerName Then
			Continue;
		EndIf;
		If DumpSending(Record.Key, Record.Value, RequiredDump, Parameters.DumpType) Then
			ArrayOfSent.Add(Record.Key);
		EndIf;
	EndDo;
	
	HasChanges = False;
	Parameters.Insert("DumpInstancesApproved", GetMonitoringCenterParameters("DumpInstancesApproved"));
	For Each Item In ArrayOfSent Do
		Parameters.DumpInstancesApproved.Delete(Item);
		HasChanges = True;
	EndDo;
	If HasChanges Then 
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("DumpInstancesApproved", Parameters.DumpInstancesApproved);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

Procedure StopFullDumpsCollection()
	
	Stopped = True;
	
	NewParameters = New Structure;
	NewParameters.Insert("DumpOption", "");
	NewParameters.Insert("DumpInstances", New Map);
	NewParameters.Insert("DumpInstancesApproved", New Map);
	NewParameters.Insert("DumpsInformation", "");
	NewParameters.Insert("DumpType", "0");
	NewParameters.Insert("NotificationDate2", Date(1,1,1));
	NewParameters.Insert("BasicChecksPassed", False);
	
	Try
		SetPrivilegedMode(True);
		SetMonitoringCenterParameters(NewParameters);
		SetPrivilegedMode(False);
	Except
		Stopped = False;
	EndTry;
	
	DumpsDirectory = GetDumpsDirectory("0", True);
	If DumpsDirectory.Path = Undefined Then
		Stopped = False;
	EndIf;
	If DumpsDirectory.Path <> Undefined Then
		If Not FilesDeleted(DumpsDirectory.Path) Then
			Stopped = False;	
		EndIf;
	EndIf;	 
	
	If Stopped Then
		FullDumpsCollectionEnabled = GetMonitoringCenterParameters("FullDumpsCollectionEnabled");
		FullDumpsCollectionEnabled.Delete(ComputerName());
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("FullDumpsCollectionEnabled", FullDumpsCollectionEnabled); 
		SetPrivilegedMode(False);
		DeleteScheduledJob("ErrorReportCollectionAndSending");
	EndIf;
	
EndProcedure

Procedure DeleteObsoleteFiles(RequiredDump, PathToDirectory)
	
	FilesArray = FindFiles(PathToDirectory,"*");
	For Each File In FilesArray Do             		
		DumpStructure = DumpDetails(File.Description);	 	
		DumpOption = DumpStructure.Process + "_" + DumpStructure.PlatformVersion + "_" + DumpStructure.Offset;
		If DumpOption = RequiredDump Then
			Continue;
		EndIf;
		
		If File.Exist() And CurrentSessionDate() - File.GetModificationTime() > 3*86400 Then
			FilesDeleted(File.FullName);
		EndIf;
		
	EndDo;
	
EndProcedure

Function FreeSpaceOnHardDrive(DriveLetter, FromClientAtServer)
	
	QueryResult = New Structure;
	QueryResult.Insert("Value", 0);
	QueryResult.Insert("Successfully", True);
	QueryResult.Insert("ErrorDescription", ""); 
	
	CommandLine = "typeperf ""\LogicalDisk(" + DriveLetter + ")\Free Megabytes"" -sc 1";
	
	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	ApplicationStartupParameters.ExecutionEncoding = "OEM";
	
	RunResult = CommonClientServer.StartApplication(CommandLine, ApplicationStartupParameters);
	
	ErrorStream = RunResult.ErrorStream;
	OutputStream = RunResult.OutputStream;
	
	If ValueIsFilled(ErrorStream) Then 
		QueryResult.Successfully = False;
		QueryResult.ErrorDescription = NStr("ru = 'Ошибка при выполнении команды typeperf';
												|en = 'typeperf command error.';pl = 'błąd podczas wykonania polecenia typeperf.';es_ES = 'error del comando typeperf.';es_CO = 'error del comando typeperf.';tr = 'typeperf komut hatası.';it = 'Errore comando typeperf.';de = 'typeperf Befehlsfehler.'");
	Else 
		RowsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(OutputStream, Chars.LF, True, True);
		If RowsArray.Count() >= 2 Then
			SearchRow = RowsArray[1];
			SubstringsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(SearchRow, ",", True, True);
			If SubstringsArray.Count() >= 2 Then
				SearchRow = SubstringsArray[1];
				SearchRow = StrReplace(SearchRow,"""","");
				Try
					QueryResult.Value = Number(SearchRow);
					MonitoringCenter.WriteBusinessStatisticsOperationDay(
						"ClientStatistics.SystemInformation.FreeOnDisk." + DriveLetter, "", QueryResult.Value, True);
				Except
					QueryResult.Successfully = False;
					QueryResult.ErrorDescription = DetailErrorDescription(ErrorInfo());
				EndTry;
			EndIf;
		Else
			QueryResult.Successfully = False;
			QueryResult.ErrorDescription = NStr("ru = 'Не удалось разобрать результат typeperf';
													|en = 'Cannot parse the result typeperf';pl = 'Nie udało się przeanalizować wyniku typeperf';es_ES = 'No se puede analizar el resultado typeperf';es_CO = 'No se puede analizar el resultado typeperf';tr = 'typeperf sonucu ayrıştırılamıyor';it = 'Impossibile smontare il risultato typeperf';de = 'Fehler beim Zerlegen von Ergebnissen von typeperf'");
		EndIf;
	EndIf;
	
	Return QueryResult;
	
EndFunction

Function DumpIsRequired(DumpOption, RequestedDump, DumpType = "")
	
	Result = New Structure("Required2, DumpType", False, DumpType);
	RequiredDumps = RequiredDumps(DumpOption);
	
	If Not RequiredDumps.RequestSuccessful Then
		If DumpOption = RequestedDump Then
			Result.Required2 = True;
			Result.DumpType = "3";
		EndIf;
	Else
		If Not IsBlankString(DumpType) Then
			If DumpType = "0" And RequiredDumps.MiniDump Then
				Result.Required2 = True;
			ElsIf DumpType = "3" And RequiredDumps.FullDump Then
				Result.Required2 = True;
			EndIf;
		Else
			If RequiredDumps.MiniDump Then
				Result.Required2 = True;
				Result.DumpType = "0";
			ElsIf RequiredDumps.FullDump Then
				Result.Required2 = True;
				Result.DumpType = "3";
			EndIf;
		EndIf;
	EndIf;  
	
	Return Result;
	
EndFunction

Function RequiredDumps(DumpOption)
	Result = New Structure("RequestSuccessful, MiniDump, FullDump", False, False, False);
	
	Parameters = GetSendServiceParameters(); 
		
	ResourceAddress = Parameters.DumpsResourceAddress;
	If Right(ResourceAddress, 1) <> "/" Then
		ResourceAddress = ResourceAddress + "/";
	EndIf;
	
	GUID = String(Parameters.InfoBaseID);
	ResourceAddress = ResourceAddress + "IsDumpNeeded" + "/" + GUID + "/" + DumpOption + "/json";
	
	HTTPParameters = New Structure;
	HTTPParameters.Insert("Server", Parameters.Server);
	HTTPParameters.Insert("ResourceAddress", ResourceAddress);
	HTTPParameters.Insert("Data", "");
	HTTPParameters.Insert("Port", Parameters.Port);
	HTTPParameters.Insert("SecureConnection", Parameters.SecureConnection);	
	HTTPParameters.Insert("Method", "GET");
	HTTPParameters.Insert("DataType", "");
	HTTPParameters.Insert("Timeout", 60);
	
	HTTPResponse = HTTPServiceSendDataInternal(HTTPParameters);
	
	If HTTPResponse.StatusCode = 200 Then
		Response1 = JSONStringToStructure(HTTPResponse.Body);
		Result.MiniDump = Response1.MiniDump;
		Result.FullDump = Response1.FullDump;
		Result.RequestSuccessful = True;
	EndIf;
	
	Return Result;
EndFunction 

Function CanLoadDump(DumpOption, DumpType)
	
	Result = False;
	
	Parameters = GetSendServiceParameters(); 
		
	ResourceAddress = Parameters.DumpsResourceAddress;
	If Right(ResourceAddress, 1) <> "/" Then
		ResourceAddress = ResourceAddress + "/";
	EndIf;
	
	GUID = String(Parameters.InfoBaseID);
	ResourceAddress = ResourceAddress + "CanLoadDump" + "/" + GUID + "/" + DumpOption + "/" + DumpType;
	
	HTTPParameters = New Structure;
	HTTPParameters.Insert("Server", Parameters.Server);
	HTTPParameters.Insert("ResourceAddress", ResourceAddress);
	HTTPParameters.Insert("Data", "");
	HTTPParameters.Insert("Port", Parameters.Port);
	HTTPParameters.Insert("SecureConnection", Parameters.SecureConnection);	
	HTTPParameters.Insert("Method", "GET");
	HTTPParameters.Insert("DataType", "");
	HTTPParameters.Insert("Timeout", 60);
	
	HTTPResponse = HTTPServiceSendDataInternal(HTTPParameters);
	
	If HTTPResponse.StatusCode = 200 Then
		Result = HTTPResponse.Body = "true";
	EndIf;
		
	Return Result;
	
EndFunction

Function DumpSending(DumpOption, Data, RequiredDump, DumpType)
	
	SendingResult = False;
	
	File = New File(Data.FullName);
	If Not File.Exist() Then
		Return True;
	EndIf;
	
	DumpRequirement = DumpIsRequired(DumpOption, RequiredDump, DumpType);
	If Not DumpRequirement.Required2 Then
		FilesDeleted(Data.FullName);
		Return True;
	EndIf;
	
	If Not CanLoadDump(DumpOption, DumpType) Then
		Return False;
	EndIf;
	
	Parameters = GetSendServiceParameters();
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	GUID = String(Parameters.InfoBaseID);
	Hash1 = New DataHashing(HashFunction.CRC32);
	Hash1.AppendFile(Data.FullName);
	DumpHashSum = Format(Hash1.HashSum,"NG=0"); 
	
	ResourceAddress = Parameters.DumpsResourceAddress;
	If Right(ResourceAddress, 1) <> "/" Then
		ResourceAddress = ResourceAddress + "/";
	EndIf;
	
	ResourceAddress = ResourceAddress + "LoadDump" + "/" + GUID + "/" + DumpOption + "/" + DumpHashSum + "/" + DumpType;
	
	HTTPParameters = New Structure;
	HTTPParameters.Insert("Server", Parameters.Server);
	HTTPParameters.Insert("ResourceAddress", ResourceAddress);
	HTTPParameters.Insert("Data", Data.FullName);
	HTTPParameters.Insert("Port", Parameters.Port);
	HTTPParameters.Insert("SecureConnection", Parameters.SecureConnection);	
	HTTPParameters.Insert("Method", "POST");
	HTTPParameters.Insert("DataType", "BinaryData");
	HTTPParameters.Insert("Timeout", 0);
	
	HTTPResponse = HTTPServiceSendDataInternal(HTTPParameters);
	
	If HTTPResponse.StatusCode = 200 Then
		SendingResult = HTTPResponse.Body = "true";	
	EndIf;
		
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterSubmitErrorReport", BeginTime);
	EndIf;
	
	Return SendingResult;
		
EndFunction

Function FilesDeleted(Path, Mask = "")
	Try
		DeleteFiles(Path, Mask)
	Except
		Return False;
	EndTry;
	Return True;
EndFunction

Procedure CheckIfNotificationOfDumpsIsRequired(DumpsDirectoryPath)
	
	MonitoringCenterParameters = New Structure();
	MonitoringCenterParameters.Insert("SendDumpsFiles");
	MonitoringCenterParameters.Insert("DumpOption");
	MonitoringCenterParameters.Insert("DumpCollectingEnd");
	MonitoringCenterParameters.Insert("DumpsCheckDepth");
	MonitoringCenterParameters.Insert("MinDumpsCount");
	MonitoringCenterParameters.Insert("DumpCheckNext");
	MonitoringCenterParameters.Insert("DumpsCheckFrequency");
	MonitoringCenterParameters.Insert("DumpType");
	MonitoringCenterParameters.Insert("SpaceReserveDisabled");
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If MonitoringCenterParameters.SendDumpsFiles = 0 Then
		Return;
	EndIf;
	
	CurrentDate = CurrentUniversalDate();
	If Not MonitoringCenterParameters.SendDumpsFiles = 0
		And Not IsBlankString(MonitoringCenterParameters.DumpOption)
		And CurrentDate < MonitoringCenterParameters.DumpCollectingEnd Then
		Return;
	EndIf;  
	
	If MonitoringCenterParameters.DumpCheckNext > CurrentDate Then
		Return;
	EndIf;
	
	SetMonitoringCenterParameter("DumpCheckNext", CurrentDate + MonitoringCenterParameters.DumpsCheckFrequency);
	
	StartDate = CurrentDate - MonitoringCenterParameters.DumpsCheckDepth;
	
	SysInfo = New SystemInfo;
	
	TopDumps = InformationRegisters.PlatformDumps.GetTopOptions(StartDate, CurrentDate, 10, SysInfo.AppVersion);
	Selection = TopDumps.Select();
	While Selection.Next() Do
		If Selection.OptionsCount >=	MonitoringCenterParameters.MinDumpsCount Then
			DumpRequirement = DumpIsRequired(Selection.DumpOption, "");
			If DumpRequirement.Required2 Then
				If DumpRequirement.DumpType = "3" Then
					SeparatorPosition = StrFind(DumpsDirectoryPath, GetServerPathSeparator());
					If SeparatorPosition = 0 Then
						Continue;	
					EndIf;
					DriveLetter = Left(DumpsDirectoryPath, SeparatorPosition-1);
					MeasurementResult = FreeSpaceOnHardDrive(DriveLetter, False);
					If Not MeasurementResult.Successfully Then
						Continue;
					EndIf;
					If MeasurementResult.Value/1024 < MonitoringCenterParameters.SpaceReserveDisabled Then
						Continue;
					EndIf;
				EndIf;
				
				NewParameters = New Structure;
				NewParameters.Insert("DumpOption", Selection.DumpOption);
				NewParameters.Insert("DumpCollectingEnd", BegOfDay(CurrentDate)+30*86400);
				If MonitoringCenterParameters.SendDumpsFiles = 1 Then
					NewParameters.Insert("DumpType", DumpRequirement.DumpType);
				Else
					NewParameters.Insert("DumpType", "0");
				EndIf;
				SetMonitoringCenterParameters(NewParameters);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.DumpsRegistration.NotifyAdministrator", 1);
								
				Break;
				
			EndIf;
		Else
			Break;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region TestPackageSending

Procedure SendTestPackage(ExecutionParameters, ResultAddress) Export
	
	SetPrivilegedMode(True);
	
	ExecutionResult = New Structure("Successfully, BriefErrorDescription", True, "");
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	NewParameters = New Structure;
	NewParameters.Insert("RegisterSystemInformation", False);
	NewParameters.Insert("RegisterSubsystemVersions", False);
	NewParameters.Insert("RegisterDumps", False);
	NewParameters.Insert("RegisterBusinessStatistics", False);
	NewParameters.Insert("RegisterConfigurationStatistics", False);
	NewParameters.Insert("RegisterConfigurationSettings", False);
	NewParameters.Insert("RegisterPerformance", False);
	NewParameters.Insert("RegisterTechnologicalPerformance", False);
	SetMonitoringCenterParameters(NewParameters);
	
	StartDate2 = CurrentUniversalDate();
	MonitoringCenterParameters = New Structure();
	MonitoringCenterParameters.Insert("TestPackageSent");
	MonitoringCenterParameters.Insert("TestPackageSendingAttemptCount");
	MonitoringCenterParameters.Insert("SendDataNextGeneration");
	MonitoringCenterParameters.Insert("SendDataGenerationPeriod");
	MonitoringCenterParameters.Insert("EnableMonitoringCenter");
	MonitoringCenterParameters.Insert("ApplicationInformationProcessingCenter");
	MonitoringCenterParameters.Insert("DiscoveryPackageSent");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If TestPackageSendingPossible(MonitoringCenterParameters, StartDate2) And ExecutionParameters.TestPackageSending
		Or GetIDPossible(MonitoringCenterParameters) And ExecutionParameters.GetID Then
		
		Try
			CreatePackageToSend();
		Except
			ExecutionResult.Successfully = False;
			ExecutionResult.BriefErrorDescription = NStr("ru = 'Ошибка при формировании пакета.';
																	|en = 'An error occurred while generating the package.';pl = 'Błąd podczas wygenerowania pakietu.';es_ES = 'Se ha producido un error al generar el paquete.';es_CO = 'Se ha producido un error al generar el paquete.';tr = 'Paket oluşturulurken hata oluştu.';it = 'Si è verificato un errore durante la creazione del pacchetto.';de = 'Fehler beim Generieren des Pakets aufgetreten.'");
			Comment = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(
			NStr("ru = 'Центр мониторинга - сформировать тестовый пакет для отправки';
				|en = 'Monitoring center - generate test package to send';pl = 'Centrum monitorowania - wygeneruj pakiet testowy do wysyłki';es_ES = 'Centro de control - generar paquete de prueba para enviar';es_CO = 'Centro de control - generar paquete de prueba para enviar';tr = 'İzleme merkezi - gönderilecek test paketi oluştur';it = 'Centro di monitoraggio - creare pacchetto di prova da inviare';de = 'Überwachungszentrum - Testpaket zum Senden generieren'",
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			Comment);
		EndTry;
		
		Try
			HTTPResponse = SendMonitoringData(ExecutionParameters.TestPackageSending);
			If HTTPResponse.StatusCode = 200 Then
				MonitoringCenterParameters.TestPackageSent = True;
			Else
				ExecutionResult.Successfully = False;
				ExecutionResult.BriefErrorDescription = NStr("ru = 'Ошибка при отправке пакета.';
																		|en = 'An error occurred while sending a package.';pl = 'Błąd podczas wysyłki pakietu.';es_ES = 'Se ha producido un error al enviar un paquete.';es_CO = 'Se ha producido un error al enviar un paquete.';tr = 'Paket gönderilirken hata oluştu.';it = 'Si è verificato un errore durante l''invio del pacchetto.';de = 'Fehler beim Senden von Paket aufgetreten.'");
				Template = NStr("ru = 'Ошибка HTTP при отправке пакета. Код %1';
								|en = 'An HTTP error occurred while sending a package. Code %1';pl = 'Błąd HTTP podczas wysyłki pakietu. Kod %1';es_ES = 'Se ha producido un error HTTP al enviar un paquete. Código %1';es_CO = 'Se ha producido un error HTTP al enviar un paquete. Código %1';tr = 'Paket gönderilirken HTTP hatası oluştu. Kod %1';it = 'Si è verificato un errore HTTP durante l''invio del pacchetto. Codice %1';de = 'HTTP-Fehler beim Senden von Paket. Code %1'");
				Comment = StringFunctionsClientServer.SubstituteParametersToString(Template, HTTPResponse.StatusCode); 
				WriteLogEvent(
				NStr("ru = 'Центр мониторинга - отправить тестовые данные мониторинга';
					|en = 'Monitoring center - send monitoring test data';pl = 'Centrum monitorowania - wyślij testowe dane o monitorowaniu';es_ES = 'Centro de control - envío de datos de pruebas de control';es_CO = 'Centro de control - envío de datos de pruebas de control';tr = 'İzleme merkezi - izleme test verilerini gönder';it = 'Centro di monitoraggio - inviare i dati del test di monitoraggio';de = 'Überwachungszentrum - Testdaten von Überwachung senden'",
				CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				Comment);
			EndIf;
		Except
			ExecutionResult.Successfully = False;
			ExecutionResult.BriefErrorDescription = NStr("ru = 'Ошибка при отправке пакета.';
																	|en = 'An error occurred while sending a package.';pl = 'Błąd podczas wysyłki pakietu.';es_ES = 'Se ha producido un error al enviar un paquete.';es_CO = 'Se ha producido un error al enviar un paquete.';tr = 'Paket gönderilirken hata oluştu.';it = 'Si è verificato un errore durante l''invio del pacchetto.';de = 'Fehler beim Senden von Paket aufgetreten.'");
			Comment = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(
			NStr("ru = 'Центр мониторинга - отправить тестовые данные мониторинга';
				|en = 'Monitoring center - send monitoring test data';pl = 'Centrum monitorowania - wyślij testowe dane o monitorowaniu';es_ES = 'Centro de control - envío de datos de pruebas de control';es_CO = 'Centro de control - envío de datos de pruebas de control';tr = 'İzleme merkezi - izleme test verilerini gönder';it = 'Centro di monitoraggio - inviare i dati del test di monitoraggio';de = 'Überwachungszentrum - Testdaten von Überwachung senden'",
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			Comment);
			MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.SendMonitoringData.Error", 1, Comment);
		EndTry;
		
		If ExecutionResult.Successfully Then
			ExecutionParameters.Insert("Iterator", ExecutionParameters.Iterator + 1);
		EndIf;
		
		DiscoveryPackageSent = GetMonitoringCenterParameters("DiscoveryPackageSent");
		
		If ExecutionResult.Successfully And Not DiscoveryPackageSent And ExecutionParameters.Iterator < 2 Then
			SendTestPackage(ExecutionParameters, ResultAddress);
		ElsIf ExecutionResult.Successfully And DiscoveryPackageSent Then	
		
			If ExecutionParameters.GetID Then
				SetMonitoringCenterParameter("SendDataNextGeneration", CurrentUniversalDate() + 3600); 
				PutToTempStorage(ExecutionResult, ResultAddress);
				If PerformanceMonitorExists Then
					ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterHandshake", BeginTime);
				EndIf;
			EndIf; 			
		ElsIf ExecutionParameters.GetID And Not ExecutionResult.Successfully Then
			PutToTempStorage(ExecutionResult, ResultAddress);		
		EndIf;
		
		If ExecutionParameters.TestPackageSending Then
			MonitoringCenterParameters.SendDataNextGeneration = CurrentUniversalDate()
			+ GetMonitoringCenterParameters("SendDataGenerationPeriod");
			MonitoringCenterParameters.TestPackageSendingAttemptCount = MonitoringCenterParameters.TestPackageSendingAttemptCount + 1;
			
			MonitoringCenterParameters.Delete("SendDataGenerationPeriod");
			MonitoringCenterParameters.Delete("EnableMonitoringCenter");
			MonitoringCenterParameters.Delete("ApplicationInformationProcessingCenter");
			MonitoringCenterParameters.Delete("DiscoveryPackageSent");
			
			SetMonitoringCenterParameters(MonitoringCenterParameters);
		EndIf;
		
	ElsIf ExecutionParameters.GetID And MonitoringCenterParameters.DiscoveryPackageSent Then
		PutToTempStorage(ExecutionResult, ResultAddress);	
	EndIf;
		
	SetPrivilegedMode(False);
	
EndProcedure

Function TestPackageSendingPossible(MonitoringCenterParameters, StartDate2)
	Return Not MonitoringCenterParameters.TestPackageSent And MonitoringCenterParameters.TestPackageSendingAttemptCount < 3
		And IsMasterNode() And StartDate2 >= MonitoringCenterParameters.SendDataNextGeneration;
EndFunction

Function GetIDPossible(MonitoringCenterParameters)
	Return (MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter)
		And IsMasterNode() And MonitoringCenterParameters.DiscoveryPackageSent = False;
EndFunction

#EndRegion

#Region ConfiguringErrorHandling

Procedure SetAdditionalErrorHandlingInformation() Export
	InfoBaseID = MonitoringCenter.InfoBaseID();
	If Not ValueIsFilled(InfoBaseID) Then
		Return;
	EndIf;
	If Common.DataSeparationEnabled() And Common.SubsystemExists("SaaSTechnology.Core") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		DataArea = ModuleSaaS.SessionSeparatorValue();
	Else
		DataArea = 0;
	EndIf;
	Parameters = New Structure("CodeExecuted,ErrorProcessing", False, Undefined);
	CodeToExecute = "Parameters.ErrorProcessing = ErrorProcessing;					   
						|Parameters.CodeExecuted = True;";	
	Try
		Common.ExecuteInSafeMode(CodeToExecute, Parameters);
	Except
		// No needed
	EndTry;
	If Parameters.CodeExecuted Then		
		Try
			If SafeMode() = True Then
				SetSafeModeDisabled(True);
			EndIf;
			SetPrivilegedMode(True);
			CommonSettings1 = Parameters.ErrorProcessing.GetCommonSettings();					   
			SetPrivilegedMode(False);
			AdditionalInformation = New Structure;
			If ValueIsFilled(CommonSettings1.AdditionalReportInformation) Then
				JSONReader = New JSONReader();
				JSONReader.SetString(CommonSettings1.AdditionalReportInformation);
				AdditionalInformation = ReadJSON(JSONReader);
			EndIf;
			If AdditionalInformation.Property("guid") 
				And AdditionalInformation.guid = InfoBaseID Then
				Return;
			EndIf;
			AdditionalInformation.Insert("guid", InfoBaseID);
			AdditionalInformation.Insert("region", DataArea);
			JSONWriter = New JSONWriter;
			JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
			WriteJSON(JSONWriter, AdditionalInformation);                                  	
			CommonSettings1.AdditionalReportInformation = JSONWriter.Close();
			SetPrivilegedMode(True);
			Parameters.ErrorProcessing.SetCommonSettings(CommonSettings1);
			SetPrivilegedMode(False);			
		Except
			// No needed
		EndTry;		
	EndIf;
	
EndProcedure

Function SettingErrorHandlingSettings(SavedParameters1, ReceivedParameters)
	
	ProcessingResult = New Structure;
	
	Parameters = New Structure;
	Parameters.Insert("CodeExecuted", False);
	Parameters.Insert("ErrorProcessing", Undefined);
	Parameters.Insert("ErrorReportingMode", Undefined);
	Parameters.Insert("ErrorMessageDisplayVariant", Undefined);
	CodeToExecute = "Parameters.ErrorProcessing = ErrorProcessing;					   
						|Parameters.CodeExecuted = True;
						|Parameters.ErrorReportingMode = ErrorReportingMode;
						|Parameters.ErrorMessageDisplayVariant = ErrorMessageDisplayVariant;";
	Try
		Common.ExecuteInSafeMode(CodeToExecute, Parameters);
	Except
		// No needed
	EndTry;
	If Parameters.CodeExecuted Then		
		Try
			If SafeMode() = True Then
				SetSafeModeDisabled(True);
			EndIf;
			SetPrivilegedMode(True);
			CommonSettings1 = Parameters.ErrorProcessing.GetCommonSettings();					   
			EnumerationModeForSendingErrorInformation = Parameters.ErrorReportingMode;
			EnumerationOptionForDisplayingTheErrorMessage = Parameters.ErrorMessageDisplayVariant;
			SetPrivilegedMode(False);
			If CommonSettings1.ErrorRegistrationServiceURL = SavedParameters1.ErrorRegistrationServiceURL
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings1.ErrorRegistrationServiceURL = ReceivedParameters.ErrorRegistrationServiceURL;
			EndIf;
			If CommonSettings1.SendReport = EnumerationModeForSendingErrorInformation[SavedParameters1.SendAReport]
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings1.SendReport = EnumerationModeForSendingErrorInformation[ReceivedParameters.SendAReport];				
			EndIf;
			If CommonSettings1.MessageDisplayVariant = EnumerationOptionForDisplayingTheErrorMessage[SavedParameters1.ErrorMessageDisplayVariant]
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings1.MessageDisplayVariant = EnumerationOptionForDisplayingTheErrorMessage[ReceivedParameters.ErrorMessageDisplayVariant];
				ParametersForTheMessageText = New Structure("CommonSettings1", CommonSettings1);
				CodeToExecute = "MessageString = New FormattedString(NStr(""ru = 'K sorry, occurred unexpected thesituation'""), New Font(,,,,,,140));
				|ErrorMessageTexts = New ErrorMessageTexts(MessageString, MessageString);
				|Parameters.CommonSettings1.ErrorMessageTexts.Insert(ErrorCategory.OtherError, ErrorMessageTexts);";
				Common.ExecuteInSafeMode(CodeToExecute, ParametersForTheMessageText);
			EndIf;
			If CommonSettings1.IncludeDetailErrorDescriptionInReport = EnumerationModeForSendingErrorInformation[SavedParameters1.IncludeDetailErrorDescriptionInReport]
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings1.IncludeDetailErrorDescriptionInReport = EnumerationModeForSendingErrorInformation[ReceivedParameters.IncludeDetailErrorDescriptionInReport];
			EndIf;
			If CommonSettings1.IncludeInfobaseInformationInReport = EnumerationModeForSendingErrorInformation[SavedParameters1.IncludeInfobaseInformationInReport]
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings1.IncludeInfobaseInformationInReport = EnumerationModeForSendingErrorInformation[ReceivedParameters.IncludeInfobaseInformationInReport];
			EndIf;			
						
			SetPrivilegedMode(True);
			Parameters.ErrorProcessing.SetCommonSettings(CommonSettings1);
			SetPrivilegedMode(False);	
			
			ProcessingResult.Insert("SetErrorHandlingSettingsForcibly", ReceivedParameters.SetErrorHandlingSettingsForcibly);
			ProcessingResult.Insert("ErrorMessageDisplayVariant", ReceivedParameters.ErrorMessageDisplayVariant);
			ProcessingResult.Insert("ErrorRegistrationServiceURL", ReceivedParameters.ErrorRegistrationServiceURL);
			ProcessingResult.Insert("SendAReport", ReceivedParameters.SendAReport);
			ProcessingResult.Insert("IncludeDetailErrorDescriptionInReport", ReceivedParameters.IncludeDetailErrorDescriptionInReport);
			ProcessingResult.Insert("IncludeInfobaseInformationInReport", ReceivedParameters.IncludeInfobaseInformationInReport);
		Except
			// No needed
		EndTry;		
	EndIf;
	Return ProcessingResult;
	
EndFunction

#EndRegion

#Region WorkWithConfigurationStatistics

Procedure CollectEventLogErrors(MonitoringCenterParameters = Undefined)
	
	If MonitoringCenterParameters = Undefined Then
		MonitoringCenterParameters = New Structure("
		|RegisterEventLogErrors,
		|EventLogErrorsNextGeneration,
		|EventLogErrorsGenerationPeriod,
		|EventLogErrorsCount,
		|EventLogErrorsEvents");
		MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	EndIf;
	
	If MonitoringCenterParameters.RegisterEventLogErrors Then
		
		PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
		
		If PerformanceMonitorExists Then
			ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
			BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
		EndIf;
		
		InformationRegisters.StatisticsEventLogErrors.WriteEventLogErrorsStatistics(MonitoringCenterParameters);
		
		If PerformanceMonitorExists Then
			ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterCollectEventLogErrors", BeginTime);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region UpdateInstalledSending

Procedure SendUpdateInstalledPackage(ExecutionParameters, ResultAddress) Export
	
	SetPrivilegedMode(True);
	
	ExecutionResult = New Structure("Successfully, BriefErrorDescription", True, "");
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("UpdateInstalled");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(Parameters);
	
	If UpdateInstalledSendingPossible(MonitoringCenterParameters) Then
		
		Try
			CreatePackageToSend(True);
		Except
			ExecutionResult.Successfully = False;
			ExecutionResult.BriefErrorDescription = NStr("en = 'An error occurred while generating the package.'; ru = 'Ошибка при формировании пакета.';pl = 'Wystąpił błąd podczas generowania pakietu.';es_ES = 'Se ha producido un error al generar el paquete.';es_CO = 'Se ha producido un error al generar el paquete.';tr = 'Paket oluşturulurken hata oluştu.';it = 'Si è verificato un errore durante la creazione del pacchetto.';de = 'Fehler beim Generieren des Pakets aufgetreten.'");
			Comment = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(
				NStr("en = 'Monitoring center. Generate update installed package to send.'; ru = 'Центр мониторинга. Сформировать установочный пакет обновления для отправки.';pl = 'Centrum monitorowania. Wygeneruj aktualizację zainstalowanego pakietu do wysyłki.';es_ES = 'Centro de control. Genera la actualización del paquete instalado para enviarlo.';es_CO = 'Centro de control. Genera la actualización del paquete instalado para enviarlo.';tr = 'İzleme merkezi. Göndermek için güncelleme yüklenmiş paket oluştur.';it = 'Centro di monitoraggio. Generare aggiornamento del pacchetto installato da inviare.';de = 'Überwachungszentrum - Paket Aktualisierung installiert zum Senden generieren'",
					CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				Comment);
		EndTry;
		
		Try
			
			HTTPResponse = SendMonitoringData(False, True);
			If HTTPResponse.StatusCode = 200 Then
				MonitoringCenterParameters.UpdateInstalled = False;
			Else
				ExecutionResult.Successfully = False;
				ExecutionResult.BriefErrorDescription = NStr("en = 'An error occurred while sending a package.'; ru = 'Ошибка при отправке пакета.';pl = 'Wystąpił błąd podczas wysyłki pakietu.';es_ES = 'Se ha producido un error al enviar un paquete.';es_CO = 'Se ha producido un error al enviar un paquete.';tr = 'Paket gönderilirken hata oluştu.';it = 'Si è verificato un errore durante l''invio del pacchetto.';de = 'Fehler beim Senden von Paket aufgetreten.'");
				Template = NStr("en = 'An HTTP error occurred while sending a package. Code %1.'; ru = 'Ошибка HTTP при отправке пакета. Код %1.';pl = 'Błąd HTTP podczas wysyłki pakietu. Kod %1.';es_ES = 'Se ha producido un error HTTP al enviar un paquete. Código %1';es_CO = 'Se ha producido un error HTTP al enviar un paquete. Código %1';tr = 'Paket gönderilirken HTTP hatası oluştu. Kod %1.';it = 'Si è verificato un errore HTTP durante l''invio del pacchetto. Codice %1.';de = 'HTTP-Fehler beim Senden von Paket. Code %1.'");
				Comment = StringFunctionsClientServer.SubstituteParametersToString(Template, HTTPResponse.StatusCode); 
				WriteLogEvent(
					NStr("en = 'Monitoring center. Send monitoring update installed data.';ru = 'Центр мониторинга. Отправить данные установки обновления мониторинга.';pl = 'Centrum monitorowania. Wyślij zainstalowane dane dotyczące aktualizacji monitorowania.';es_ES = 'Centro de control. Envía los datos instalados de la actualización del monitoreo.';es_CO = 'Centro de control. Envía los datos instalados de la actualización del monitoreo.';tr = 'İzleme merkezi. İzleme güncellemesi yüklü verileri gönder.';it = 'Centro di monitoraggio. Inviare dati installati dell''aggiornamento di monitoraggio.';de = 'Überwachungszentrum. Überwachungsdaten Aktualisierung installiert senden.'",
						CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					Comment);
				EndIf;
				
		Except
			
			ExecutionResult.Successfully = False;
			ExecutionResult.BriefErrorDescription = NStr("en = 'An error occurred while sending a package.'; ru = 'Ошибка при отправке пакета.';pl = 'Wystąpił błąd podczas wysyłki pakietu.';es_ES = 'Se ha producido un error al enviar un paquete.';es_CO = 'Se ha producido un error al enviar un paquete.';tr = 'Paket gönderilirken hata oluştu.';it = 'Si è verificato un errore durante l''invio del pacchetto.';de = 'Fehler beim Senden von Paket aufgetreten.'");
			Comment = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(
				NStr("en = 'Monitoring center. Send monitoring update installed data.'; ru = 'Центр мониторинга. Отправить данные установки обновления мониторинга.';pl = 'Centrum monitorowania. Wyślij zainstalowane dane dotyczące aktualizacji monitorowania.';es_ES = 'Centro de control. Envía los datos instalados de la actualización del monitoreo.';es_CO = 'Centro de control. Envía los datos instalados de la actualización del monitoreo.';tr = 'İzleme merkezi. İzleme güncellemesi yüklü verileri gönder.';it = 'Centro di monitoraggio. Inviare dati installati dell''aggiornamento di monitoraggio.';de = 'Überwachungszentrum. Überwachungsdaten Aktualisierung installiert senden.'",
					CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				Comment);
			
		EndTry;
		
		If Not ExecutionResult.Successfully Then
			ExecutionParameters.Insert("Iterator", ExecutionParameters.Iterator + 1);
		EndIf;
		
		If Not ExecutionResult.Successfully And ExecutionParameters.Iterator < 2 Then
			SendUpdateInstalledPackage(ExecutionParameters, ResultAddress);
		ElsIf ExecutionResult.Successfully Then
			
			SetMonitoringCenterParameters(MonitoringCenterParameters);
			PutToTempStorage(ExecutionResult, ResultAddress);
			
			If PerformanceMonitorExists Then
				ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterHandshake", BeginTime);
			EndIf;
			
		ElsIf Not ExecutionResult.Successfully Then
			PutToTempStorage(ExecutionResult, ResultAddress);
		EndIf;
		
	Else
		PutToTempStorage(ExecutionResult, ResultAddress);
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

Function UpdateInstalledSendingPossible(MonitoringCenterParameters)
	Return MonitoringCenterParameters.UpdateInstalled And IsMasterNode();
EndFunction

Function GenerateJSONStructureForUpdateInstalledSending(MonitoringCenterParameters)
	
	InfoBaseID = String(MonitoringCenterParameters.InfoBaseID);
	InfobaseIDPermanent = String(MonitoringCenterParameters.InfobaseIDPermanent);
	
	JSONStructure = New Structure;
	JSONStructure.Insert("ib", InfoBaseID);
	JSONStructure.Insert("ibConst", InfobaseIDPermanent);
	JSONStructure.Insert("versionPacket", "1.0.5.0");
	JSONStructure.Insert("datePacket", CurrentUniversalDate());
	JSONStructure.Insert("allowSentStatistic", MonitoringCenterParameters.EnableMonitoringCenter);
	JSONStructure.Insert("updateInstalled", True);
	
	Return JSONStructure;
	
EndFunction

#EndRegion

#Region InfobaseUpdate

Procedure FillDefaultSendServiceParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("Server");
	Parameters.Insert("ResourceAddress");
	Parameters.Insert("Port");
	Parameters.Insert("SecureConnection");

	MonitoringCenterParameters = GetMonitoringCenterParameters(Parameters);
	
	If ValueIsFilled(MonitoringCenterParameters.Server) And ValueIsFilled(MonitoringCenterParameters.ResourceAddress)
		And MonitoringCenterParameters.Port <> 443 And Not MonitoringCenterParameters.SecureConnection Then
		
		Try
			SetMonitoringCenterParameter("Port", 443);
			SetMonitoringCenterParameter("SecureConnection", True);
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save monitoring center parameters. Details: %2'; ru = 'Не удалось сохранить параметры центра мониторинга. Подробнее: %2';pl = 'Nie można zapisać parametrów centrum monitorowania. Szczegóły: %2';es_ES = 'No se pueden guardar los parámetros del centro de control. Detalles: %2';es_CO = 'No se pueden guardar los parámetros del centro de control. Detalles: %2';tr = 'İzleme merkezi parametreleri kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile salvare i parametri del centro di monitoraggio. Dettagli: %2';de = 'Fehler beim Speichern von Parametern des Überwachungszentrums. Details: %2'"),
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
			
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

